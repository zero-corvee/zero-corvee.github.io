-- AbilityInput: keyboard / mouse controls and aiming.
--   Left click or F : Carrot Throw (aims at the mouse)
--   Q               : Hurricane Kick (aims at the mouse)
--   E               : Ear Cyclone
-- On-screen buttons (from the HUD) fire in the direction the rabbit faces.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BunnyGuardian = ReplicatedStorage:WaitForChild("BunnyGuardian")
local Config = require(BunnyGuardian:WaitForChild("Shared"):WaitForChild("Config"))
local UseAbilityRemote = BunnyGuardian:WaitForChild("Remotes"):WaitForChild("UseAbility") :: RemoteEvent

local player = Players.LocalPlayer

local AbilityInput = {}

local KEYBINDS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.F] = "CarrotThrow",
	[Enum.KeyCode.Q] = "HurricaneKick",
	[Enum.KeyCode.E] = "EarCyclone",
	[Enum.KeyCode.ButtonR2] = "CarrotThrow",
	[Enum.KeyCode.ButtonX] = "HurricaneKick",
	[Enum.KeyCode.ButtonY] = "EarCyclone",
}

local function getRoot(): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function flatLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

local function getMouseAim(root: BasePart): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return flatLook(root)
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local map = Workspace:FindFirstChild("BunnyGuardianMap")
	local effects = map and map:FindFirstChild("Effects")
	if effects then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local target = if result then result.Position else ray.Origin + ray.Direction * 1000
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude < 0.5 then
		return flatLook(root)
	end
	return flat.Unit
end

local spinning = false
local function spinKick(root: BasePart, humanoid: Humanoid, direction: Vector3)
	if spinning then
		return
	end
	spinning = true
	humanoid.AutoRotate = false
	local start = os.clock()
	local duration = 0.3
	local baseYaw = math.atan2(-direction.X, -direction.Z)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - start) / duration)
		if not root.Parent then
			connection:Disconnect()
			spinning = false
			return
		end
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, baseYaw + alpha * math.pi * 2, 0)
		if alpha >= 1 then
			connection:Disconnect()
			humanoid.AutoRotate = true
			spinning = false
		end
	end)
end

local function isReady(abilityName: string): boolean
	local readyAt = player:GetAttribute("CD_" .. abilityName) or 0
	if readyAt > Workspace:GetServerTimeNow() then
		return false
	end
	local cfg = Config.Abilities[abilityName]
	return (player:GetAttribute("Mana") or 0) >= (cfg.ManaCost or 0)
end

-- useMouse = true aims at the cursor; otherwise fires where the rabbit faces.
function AbilityInput.Use(abilityName: string, useMouse: boolean?)
	local root, humanoid = getRoot()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if not isReady(abilityName) then
		return
	end
	local direction = if useMouse then getMouseAim(root) else flatLook(root)

	-- face the aim direction (the client owns its character's physics)
	if abilityName == "HurricaneKick" then
		spinKick(root, humanoid, direction)
	elseif abilityName == "CarrotThrow" then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end

	UseAbilityRemote:FireServer(abilityName, direction)
end

function AbilityInput.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			AbilityInput.Use("CarrotThrow", true)
			return
		end
		local abilityName = KEYBINDS[input.KeyCode]
		if abilityName then
			local isGamepad = input.UserInputType.Name:find("Gamepad") ~= nil
			AbilityInput.Use(abilityName, not isGamepad)
		end
	end)
end

return AbilityInput
