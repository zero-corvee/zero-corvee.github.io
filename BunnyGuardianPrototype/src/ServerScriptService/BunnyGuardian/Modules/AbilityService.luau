-- AbilityService: server-authoritative abilities.
--   CarrotThrow   - fast single-target carrot projectile (free)
--   HurricaneKick - piercing green wind blade (costs mana)
--   EarCyclone    - swirling wind around the rabbit that slows and chips enemies

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BunnyGuardian = ReplicatedStorage:WaitForChild("BunnyGuardian")
local Config = require(BunnyGuardian:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = BunnyGuardian:WaitForChild("Remotes")

local PlayerDataService = require(script.Parent.PlayerDataService)
local EnemyService = require(script.Parent.EnemyService)

local AbilityService = {}

type Projectile = {
	Model: Model,
	Position: Vector3,
	Direction: Vector3,
	Speed: number,
	Traveled: number,
	Range: number,
	Damage: number,
	HitRadius: number,
	Pierce: boolean,
	Hit: { [any]: boolean },
	Owner: Player,
	SpinSpeed: number,
	Angle: number,
}

local projectiles: { Projectile } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local effectsFolder: Folder

------------------------------------------------------------------------
-- Visual builders
------------------------------------------------------------------------

local function fxPart(model: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?, transparency: number?, shape: Enum.PartType?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function buildCarrot(): Model
	local model = Instance.new("Model")
	model.Name = "Carrot"
	-- Built pointing along -Z (the model's forward).
	local body = fxPart(model, "Body", Vector3.new(0.55, 0.55, 1.8), Color3.fromRGB(245, 135, 30))
	body.CFrame = CFrame.new()
	local tip = fxPart(model, "Tip", Vector3.new(0.35, 0.35, 0.5), Color3.fromRGB(230, 110, 20))
	tip.CFrame = CFrame.new(0, 0, -1.1)
	local leaves = fxPart(model, "Leaves", Vector3.new(0.3, 0.7, 0.5), Color3.fromRGB(70, 180, 60))
	leaves.CFrame = CFrame.new(0, 0.2, 1.1)
	model.PrimaryPart = body
	return model
end

local function buildWindBlade(): Model
	local model = Instance.new("Model")
	model.Name = "WindBlade"
	local main = fxPart(model, "Blade", Vector3.new(8, 0.35, 1.6), Color3.fromRGB(90, 255, 120), Enum.Material.Neon, 0.15)
	main.CFrame = CFrame.new()
	local inner = fxPart(model, "Core", Vector3.new(5, 0.4, 0.9), Color3.fromRGB(210, 255, 220), Enum.Material.Neon, 0.1)
	inner.CFrame = CFrame.new(0, 0, -0.4)
	for _, side in { -1, 1 } do
		local wingTip = fxPart(model, "Tip", Vector3.new(2.4, 0.3, 1.1), Color3.fromRGB(90, 255, 120), Enum.Material.Neon, 0.3)
		wingTip.CFrame = CFrame.new(side * 4.6, 0, 0.7) * CFrame.Angles(0, math.rad(side * 30), 0)
	end
	model.PrimaryPart = main

	-- Trail for a sense of speed
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-3.5, 0, 0)
	a0.Parent = main
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(3.5, 0, 0)
	a1.Parent = main
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(120, 255, 140))
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.Parent = main
	return model
end

local function expandingRing(position: Vector3, color: Color3, fromSize: number, toSize: number, duration: number)
	local ring = fxPart(effectsFolder, "Ring", Vector3.new(0.3, fromSize, fromSize), color, Enum.Material.Neon, 0.3, Enum.PartType.Cylinder)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration do
			local alpha = (os.clock() - start) / duration
			local size = fromSize + (toSize - fromSize) * alpha
			ring.Size = Vector3.new(0.3, size, size)
			ring.Transparency = 0.3 + 0.7 * alpha
			RunService.Heartbeat:Wait()
		end
		ring:Destroy()
	end)
end

------------------------------------------------------------------------
-- Projectiles
------------------------------------------------------------------------

local function launch(model: Model, owner: Player, origin: Vector3, direction: Vector3, cfg: any, damage: number, pierce: boolean, spinSpeed: number)
	local projectile: Projectile = {
		Model = model,
		Position = origin,
		Direction = direction,
		Speed = cfg.Speed,
		Traveled = 0,
		Range = cfg.Range,
		Damage = damage,
		HitRadius = cfg.HitRadius,
		Pierce = pierce,
		Hit = {},
		Owner = owner,
		SpinSpeed = spinSpeed,
		Angle = 0,
	}
	model:PivotTo(CFrame.lookAt(origin, origin + direction))
	model.Parent = effectsFolder
	table.insert(projectiles, projectile)
end

local function stepProjectiles(dt: number)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local done = false
		local distance = p.Speed * dt
		p.Position += p.Direction * distance
		p.Traveled += distance
		p.Angle += p.SpinSpeed * dt

		for _, enemy in EnemyService.GetEnemiesNear(p.Position, p.HitRadius) do
			if not p.Hit[enemy] then
				p.Hit[enemy] = true
				EnemyService.Damage(enemy, p.Damage, if p.Owner.Parent then p.Owner else nil)
				if not p.Pierce then
					done = true
					break
				end
			end
		end

		if done or p.Traveled >= p.Range then
			p.Model:Destroy()
			table.remove(projectiles, i)
		else
			p.Model:PivotTo(CFrame.lookAt(p.Position, p.Position + p.Direction) * CFrame.Angles(p.Angle, 0, 0))
		end
	end
end

------------------------------------------------------------------------
-- Ability handlers
------------------------------------------------------------------------

local handlers = {}

function handlers.CarrotThrow(player: Player, root: BasePart, direction: Vector3, cfg: any)
	local damage = cfg.Damage * PlayerDataService.GetDamageMultiplier(player, "CarrotDamage")
	launch(buildCarrot(), player, root.Position + direction * 2 + Vector3.new(0, 0.5, 0), direction, cfg, damage, false, 18)
end

function handlers.HurricaneKick(player: Player, root: BasePart, direction: Vector3, cfg: any)
	local damage = cfg.Damage * PlayerDataService.GetDamageMultiplier(player, "KickDamage")
	expandingRing(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(110, 255, 140), 3, 12, 0.35)
	launch(buildWindBlade(), player, root.Position + direction * 3, direction, cfg, damage, true, 0)
end

function handlers.EarCyclone(player: Player, root: BasePart, _direction: Vector3, cfg: any)
	local model = Instance.new("Model")
	model.Name = "EarCyclone"
	local column = fxPart(model, "Column", Vector3.new(7, cfg.Radius * 2, cfg.Radius * 2), Color3.fromRGB(200, 255, 230), Enum.Material.ForceField, 0.2, Enum.PartType.Cylinder)
	local floor = fxPart(model, "Floor", Vector3.new(0.2, cfg.Radius * 2, cfg.Radius * 2), Color3.fromRGB(140, 255, 190), Enum.Material.Neon, 0.75, Enum.PartType.Cylinder)
	local swirls = {}
	for i = 1, 4 do
		-- ear-shaped wind wisps orbiting the rabbit
		swirls[i] = fxPart(model, "Wisp", Vector3.new(0.6, 3.2, 1.2), Color3.fromRGB(235, 255, 245), Enum.Material.Neon, 0.25)
	end
	model.Parent = effectsFolder

	local start = os.clock()
	local nextTick = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= cfg.Duration or not root.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		local center = root.Position
		local ground = Vector3.new(center.X, center.Y - 2.6, center.Z)
		column.CFrame = CFrame.new(ground + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, elapsed * 6, math.rad(90))
		floor.CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		for i, wisp in swirls do
			local angle = elapsed * 7 + i * math.pi / 2
			local r = cfg.Radius * (0.45 + 0.4 * ((i % 2 == 0) and 1 or 0))
			local pos = ground + Vector3.new(math.cos(angle) * r, 2 + math.sin(elapsed * 4 + i), math.sin(angle) * r)
			wisp.CFrame = CFrame.lookAt(pos, ground + Vector3.new(0, pos.Y - ground.Y, 0)) * CFrame.Angles(0, 0, math.rad(20))
		end

		if elapsed >= nextTick then
			nextTick += cfg.TickRate
			for _, enemy in EnemyService.GetEnemiesNear(center, cfg.Radius) do
				EnemyService.Slow(enemy, cfg.SlowFactor, cfg.SlowDuration)
				EnemyService.Damage(enemy, cfg.DamagePerTick, if player.Parent then player else nil)
			end
		end
	end)
end

------------------------------------------------------------------------
-- Remote handling
------------------------------------------------------------------------

local function sanitizeDirection(value: any, root: BasePart): Vector3
	if typeof(value) == "Vector3" then
		local flat = Vector3.new(value.X, 0, value.Z)
		local magnitude = flat.Magnitude
		if magnitude == magnitude and magnitude > 0.01 and magnitude < math.huge then
			return flat / magnitude
		end
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function onUseAbility(player: Player, abilityName: any, aimDirection: any)
	if typeof(abilityName) ~= "string" then
		return
	end
	local cfg = Config.Abilities[abilityName]
	local handler = handlers[abilityName]
	if not cfg or not handler then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	if (playerCooldowns[abilityName] or 0) > now + 0.05 then
		return
	end
	if not PlayerDataService.TrySpendMana(player, cfg.ManaCost or 0) then
		return
	end

	local readyAt = now + cfg.Cooldown
	playerCooldowns[abilityName] = readyAt
	player:SetAttribute("CD_" .. abilityName, readyAt)

	handler(player, root, sanitizeDirection(aimDirection, root), cfg)
end

function AbilityService.ClearProjectiles()
	for _, p in projectiles do
		p.Model:Destroy()
	end
	table.clear(projectiles)
end

function AbilityService.Init(folder: Folder)
	effectsFolder = folder
	local useAbility = Remotes:WaitForChild("UseAbility") :: RemoteEvent
	useAbility.OnServerEvent:Connect(onUseAbility)
	RunService.Heartbeat:Connect(stepProjectiles)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return AbilityService
