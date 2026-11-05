-- CharacterService: turns every player into a cute heroic rabbit using simple
-- welded parts (ears, tail, nose, red hero scarf and cape).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BunnyGuardian"):WaitForChild("Shared"):WaitForChild("Config"))

local CharacterService = {}

local FUR = Color3.fromRGB(250, 248, 244)
local PINK = Color3.fromRGB(255, 170, 195)
local HERO_RED = Color3.fromRGB(220, 50, 60)

local function weldPart(parent: Model, anchor: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
	return part
end

local function paintFur(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Parent == character then
			child.Color = FUR
		elseif child:IsA("BodyColors") then
			child.HeadColor3 = FUR
			child.TorsoColor3 = FUR
			child.LeftArmColor3 = FUR
			child.RightArmColor3 = FUR
			child.LeftLegColor3 = FUR
			child.RightLegColor3 = FUR
		end
	end
end

local function addBunnyParts(character: Model)
	if character:FindFirstChild("BunnyParts") then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local lowerBack = (character:FindFirstChild("LowerTorso") or torso) :: BasePart?
	if not head or not torso or not lowerBack then
		return
	end

	local bunny = Instance.new("Model")
	bunny.Name = "BunnyParts"
	bunny.Parent = character

	local headTop = head.Size.Y / 2
	for _, side in { -1, 1 } do
		local earCFrame = head.CFrame * CFrame.new(side * 0.35, headTop + 0.95, 0) * CFrame.Angles(0, 0, math.rad(-side * 10))
		weldPart(bunny, head, side < 0 and "EarL" or "EarR", Vector3.new(0.45, 2, 0.22), earCFrame, FUR)
		weldPart(bunny, head, side < 0 and "EarInnerL" or "EarInnerR", Vector3.new(0.25, 1.6, 0.05), earCFrame * CFrame.new(0, -0.05, -0.12), PINK)
	end
	weldPart(bunny, head, "Nose", Vector3.new(0.25, 0.2, 0.15), head.CFrame * CFrame.new(0, -0.05, -head.Size.Z / 2 - 0.02), PINK)
	weldPart(bunny, head, "CheekL", Vector3.new(0.2, 0.2, 0.05), head.CFrame * CFrame.new(-0.35, -0.15, -head.Size.Z / 2 - 0.01), PINK, Enum.PartType.Ball)
	weldPart(bunny, head, "CheekR", Vector3.new(0.2, 0.2, 0.05), head.CFrame * CFrame.new(0.35, -0.15, -head.Size.Z / 2 - 0.01), PINK, Enum.PartType.Ball)

	-- Fluffy tail
	weldPart(bunny, lowerBack, "Tail", Vector3.new(0.9, 0.9, 0.9), lowerBack.CFrame * CFrame.new(0, -lowerBack.Size.Y / 4, lowerBack.Size.Z / 2 + 0.3), FUR, Enum.PartType.Ball)

	-- Hero scarf + cape
	weldPart(bunny, torso, "Scarf", Vector3.new(torso.Size.X + 0.15, 0.35, torso.Size.Z + 0.15), torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.1, 0), HERO_RED)
	weldPart(bunny, torso, "Cape", Vector3.new(torso.Size.X * 0.9, torso.Size.Y * 1.3, 0.1), torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.2, torso.Size.Z / 2 + 0.08) * CFrame.Angles(math.rad(-8), 0, 0), HERO_RED)
end

local function applyBunny(character: Model)
	if not character.Parent then
		return
	end
	paintFur(character)
	addBunnyParts(character)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = Config.Player.WalkSpeed
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.Player.JumpPower
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	character:WaitForChild("Head", 10)
	-- Fallback in case CharacterAppearanceLoaded already fired / never fires.
	task.delay(1.5, applyBunny, character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterAppearanceLoaded:Connect(applyBunny)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function CharacterService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CharacterService
