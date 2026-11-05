-- EnemyService: spawns, moves and damages enemies (foxes and the boss eagle).
-- Enemies are anchored placeholder models moved with PivotTo every frame,
-- which keeps them cheap and fully server-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BunnyGuardian"):WaitForChild("Shared"):WaitForChild("Config"))

local EnemyService = {}

export type Enemy = {
	Model: Model,
	Root: BasePart,
	Kind: string,
	Health: number,
	MaxHealth: number,
	Speed: number,
	Damage: number,
	AttackInterval: number,
	AttackRange: number,
	AttackTimer: number,
	Reward: number,
	HitRadius: number,
	HitHeight: number,
	Position: Vector3,
	Facing: Vector3,
	SlowFactor: number,
	SlowUntil: number,
	Phase: number,
	Dead: boolean,
	Bar: Frame?,
	-- eagle only
	State: string?,
	StateTimer: number,
	Angle: number,
	MinionTimer: number,
	DiveFrom: Vector3?,
	Wings: { { Part: BasePart, Offset: CFrame, Side: number } }?,
}

type InitOptions = {
	BurrowPosition: Vector3,
	EnemyFolder: Folder,
	EffectsFolder: Folder,
	GetFoxSpawn: () -> Vector3,
	GetWave: () -> number,
	OnBurrowDamaged: (amount: number, enemy: Enemy) -> (),
	OnKilled: (enemy: Enemy, killer: Player?) -> (),
	OnBossHealthChanged: (health: number, maxHealth: number) -> (),
}

local active: { [Model]: Enemy } = {}
local options: InitOptions
local initialized = false

local FOX_PIVOT_HEIGHT = 1.7

------------------------------------------------------------------------
-- Model builders
------------------------------------------------------------------------

local function addPart(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, className: string?): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function addHealthBar(root: BasePart, width: number, height: number): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.new(width, 0, 0.45, 0)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Adornee = root
	gui.Parent = root

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	return fill
end

local function buildFox(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Fox"
	local orange = Color3.fromRGB(226, 112, 40)
	local cream = Color3.fromRGB(250, 240, 225)
	local dark = Color3.fromRGB(45, 30, 25)

	local body = addPart(model, "Body", Vector3.new(2, 1.6, 3.2), CFrame.new(0, 0, 0), orange)
	addPart(model, "Belly", Vector3.new(1.6, 0.3, 2.6), CFrame.new(0, -0.7, 0), cream)
	addPart(model, "Head", Vector3.new(1.7, 1.5, 1.5), CFrame.new(0, 0.7, -2), orange)
	addPart(model, "Snout", Vector3.new(0.8, 0.6, 0.9), CFrame.new(0, 0.4, -3.1), cream)
	addPart(model, "Nose", Vector3.new(0.3, 0.3, 0.2), CFrame.new(0, 0.6, -3.6), dark)
	addPart(model, "EyeL", Vector3.new(0.25, 0.3, 0.1), CFrame.new(-0.42, 0.95, -2.76), dark)
	addPart(model, "EyeR", Vector3.new(0.25, 0.3, 0.1), CFrame.new(0.42, 0.95, -2.76), dark)
	addPart(model, "EarL", Vector3.new(0.3, 0.8, 0.6), CFrame.new(-0.55, 1.85, -2) * CFrame.Angles(0, math.rad(180), 0), orange, "WedgePart")
	addPart(model, "EarR", Vector3.new(0.3, 0.8, 0.6), CFrame.new(0.55, 1.85, -2) * CFrame.Angles(0, math.rad(180), 0), orange, "WedgePart")
	for _, x in { -0.7, 0.7 } do
		for _, z in { -1.1, 1.1 } do
			addPart(model, "Leg", Vector3.new(0.45, 1, 0.45), CFrame.new(x, -1.2, z), dark)
		end
	end
	addPart(model, "Tail", Vector3.new(0.9, 0.9, 2.2), CFrame.new(0, 0.4, 2.5) * CFrame.Angles(math.rad(25), 0, 0), orange)
	addPart(model, "TailTip", Vector3.new(0.92, 0.92, 0.6), CFrame.new(0, 0.85, 3.45) * CFrame.Angles(math.rad(25), 0, 0), cream)

	model.PrimaryPart = body
	return model, body
end

local function buildEagle(): (Model, BasePart, { { Part: BasePart, Offset: CFrame, Side: number } })
	local model = Instance.new("Model")
	model.Name = "BossEagle"
	local brown = Color3.fromRGB(92, 60, 36)
	local white = Color3.fromRGB(245, 245, 240)
	local yellow = Color3.fromRGB(250, 196, 40)
	local s = 1.6

	local body = addPart(model, "Body", Vector3.new(3, 3, 5) * s, CFrame.new(0, 0, 0), brown)
	addPart(model, "Head", Vector3.new(2.2, 2.2, 2.2) * s, CFrame.new(0, 1.3 * s, -3.1 * s), white)
	addPart(model, "Beak", Vector3.new(0.8, 0.9, 1.4) * s, CFrame.new(0, 1 * s, -4.6 * s) * CFrame.Angles(math.rad(180), 0, 0), yellow, "WedgePart")
	addPart(model, "EyeL", Vector3.new(0.3, 0.4, 0.2) * s, CFrame.new(-0.75 * s, 1.6 * s, -4.15 * s), Color3.fromRGB(20, 20, 20))
	addPart(model, "EyeR", Vector3.new(0.3, 0.4, 0.2) * s, CFrame.new(0.75 * s, 1.6 * s, -4.15 * s), Color3.fromRGB(20, 20, 20))
	addPart(model, "Brow", Vector3.new(2.3, 0.3, 0.3) * s, CFrame.new(0, 2 * s, -4.15 * s), brown)
	addPart(model, "Tail", Vector3.new(3, 0.5, 2.5) * s, CFrame.new(0, 0, 3.6 * s), white)
	addPart(model, "TalonL", Vector3.new(0.6, 1, 0.6) * s, CFrame.new(-0.8 * s, -1.9 * s, 0), yellow)
	addPart(model, "TalonR", Vector3.new(0.6, 1, 0.6) * s, CFrame.new(0.8 * s, -1.9 * s, 0), yellow)

	local wings = {}
	for _, side in { -1, 1 } do
		local offset = CFrame.new(side * 1.5 * s, 0.6 * s, 0)
		local wing = addPart(model, side < 0 and "WingL" or "WingR", Vector3.new(10, 0.5, 3.4) * s, offset * CFrame.new(side * 5 * s, 0, 0), brown)
		table.insert(wings, { Part = wing, Offset = offset, Side = side })
	end

	model.PrimaryPart = body
	return model, body, wings
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function updateBar(enemy: Enemy)
	local bar = enemy.Bar
	if not bar then
		return
	end
	local ratio = math.clamp(enemy.Health / enemy.MaxHealth, 0, 1)
	bar.Size = UDim2.fromScale(ratio, 1)
	bar.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(110, 220, 90), ratio)
end

local function flash(model: Model, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, 0.1)
end

local function poof(position: Vector3, color: Color3, size: number)
	local part = Instance.new("Part")
	part.Name = "Poof"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.3
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(position)
	part.Parent = options.EffectsFolder
	task.spawn(function()
		for i = 1, 10 do
			local grow = size * (1 + i * 0.12)
			part.Size = Vector3.new(grow, grow, grow)
			part.Transparency = 0.3 + i * 0.07
			task.wait(0.03)
		end
		part:Destroy()
	end)
end

local function register(model: Model, root: BasePart, enemy: Enemy)
	enemy.Bar = addHealthBar(root, enemy.Kind == "Eagle" and 8 or 3.5, enemy.Kind == "Eagle" and 6 or 3)
	model.Parent = options.EnemyFolder
	active[model] = enemy
end

local function flatDirection(from: Vector3, to: Vector3): (Vector3, number)
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local distance = delta.Magnitude
	if distance < 1e-3 then
		return Vector3.new(0, 0, -1), 0
	end
	return delta / distance, distance
end

------------------------------------------------------------------------
-- Spawning
------------------------------------------------------------------------

function EnemyService.SpawnFox(wave: number, position: Vector3): Enemy
	local cfg = Config.Enemies.Fox
	local model, root = buildFox()
	local health = cfg.BaseHealth + cfg.HealthPerWave * (wave - 1)
	local enemy: Enemy = {
		Model = model,
		Root = root,
		Kind = "Fox",
		Health = health,
		MaxHealth = health,
		Speed = cfg.BaseSpeed + cfg.SpeedPerWave * (wave - 1),
		Damage = cfg.Damage,
		AttackInterval = cfg.AttackInterval,
		AttackRange = cfg.AttackRange,
		AttackTimer = 0,
		Reward = cfg.Reward,
		HitRadius = cfg.HitRadius,
		HitHeight = cfg.HitHeight,
		Position = Vector3.new(position.X, FOX_PIVOT_HEIGHT, position.Z),
		Facing = Vector3.new(0, 0, -1),
		SlowFactor = 1,
		SlowUntil = 0,
		Phase = math.random() * math.pi,
		Dead = false,
		StateTimer = 0,
		Angle = 0,
		MinionTimer = 0,
	}
	enemy.Facing = flatDirection(enemy.Position, options.BurrowPosition)
	model:PivotTo(CFrame.lookAt(enemy.Position, enemy.Position + enemy.Facing))
	register(model, root, enemy)
	return enemy
end

function EnemyService.SpawnEagle(): Enemy
	local cfg = Config.Enemies.Eagle
	local model, root, wings = buildEagle()
	local start = options.BurrowPosition + Vector3.new(0, 40, -90)
	local enemy: Enemy = {
		Model = model,
		Root = root,
		Kind = "Eagle",
		Health = cfg.Health,
		MaxHealth = cfg.Health,
		Speed = 1,
		Damage = cfg.DiveDamage,
		AttackInterval = 0,
		AttackRange = 0,
		AttackTimer = 0,
		Reward = cfg.Reward,
		HitRadius = cfg.HitRadius,
		HitHeight = cfg.HitHeight,
		Position = start,
		Facing = Vector3.new(0, 0, 1),
		SlowFactor = 1,
		SlowUntil = 0,
		Phase = 0,
		Dead = false,
		State = "Circle",
		StateTimer = cfg.CircleTime,
		Angle = -math.pi / 2,
		MinionTimer = cfg.MinionInterval,
		Wings = wings,
	}
	model:PivotTo(CFrame.lookAt(start, start + enemy.Facing))
	register(model, root, enemy)
	options.OnBossHealthChanged(enemy.Health, enemy.MaxHealth)
	return enemy
end

------------------------------------------------------------------------
-- Combat API (used by AbilityService)
------------------------------------------------------------------------

local function kill(enemy: Enemy, killer: Player?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	active[enemy.Model] = nil
	poof(enemy.Root.Position, enemy.Kind == "Eagle" and Color3.fromRGB(255, 230, 120) or Color3.fromRGB(255, 200, 150), enemy.Kind == "Eagle" and 10 or 3)
	enemy.Model:Destroy()
	options.OnKilled(enemy, killer)
end

function EnemyService.Damage(enemy: Enemy, amount: number, attacker: Player?)
	if enemy.Dead or amount <= 0 then
		return
	end
	enemy.Health = math.max(0, enemy.Health - amount)
	updateBar(enemy)
	flash(enemy.Model, Color3.fromRGB(255, 255, 255))
	if enemy.Kind == "Eagle" then
		options.OnBossHealthChanged(enemy.Health, enemy.MaxHealth)
	end
	if enemy.Health <= 0 then
		kill(enemy, attacker)
	end
end

function EnemyService.Slow(enemy: Enemy, factor: number, duration: number)
	if enemy.Dead then
		return
	end
	local now = os.clock()
	enemy.SlowFactor = if now < enemy.SlowUntil then math.min(enemy.SlowFactor, factor) else factor
	enemy.SlowUntil = math.max(enemy.SlowUntil, now + duration)
end

-- Returns living enemies whose hit cylinder overlaps a sphere-ish probe.
function EnemyService.GetEnemiesNear(position: Vector3, radius: number): { Enemy }
	local result = {}
	for _, enemy in active do
		if not enemy.Dead then
			local flat = Vector3.new(enemy.Position.X - position.X, 0, enemy.Position.Z - position.Z).Magnitude
			if flat <= radius + enemy.HitRadius and math.abs(enemy.Position.Y - position.Y) <= enemy.HitHeight then
				table.insert(result, enemy)
			end
		end
	end
	return result
end

function EnemyService.Count(): number
	local n = 0
	for _ in active do
		n += 1
	end
	return n
end

function EnemyService.ClearAll()
	for model, enemy in active do
		enemy.Dead = true
		model:Destroy()
	end
	table.clear(active)
end

------------------------------------------------------------------------
-- Per-frame behaviour
------------------------------------------------------------------------

local function updateFox(enemy: Enemy, dt: number, speedMult: number)
	local dir, distance = flatDirection(enemy.Position, options.BurrowPosition)
	local stopDistance = Config.Burrow.Radius + enemy.AttackRange
	local bob = 0
	local lunge = 0
	if distance > stopDistance then
		local stepLength = math.min(enemy.Speed * speedMult * dt, distance - stopDistance)
		enemy.Position += dir * stepLength
		enemy.Phase += dt * enemy.Speed * speedMult * 1.2
		bob = math.abs(math.sin(enemy.Phase)) * 0.4
	else
		enemy.AttackTimer -= dt * speedMult
		if enemy.AttackTimer <= 0 then
			enemy.AttackTimer = enemy.AttackInterval
			options.OnBurrowDamaged(enemy.Damage, enemy)
		end
		-- quick lunge at the start of each attack
		local t = 1 - enemy.AttackTimer / enemy.AttackInterval
		lunge = if t < 0.25 then math.sin(t / 0.25 * math.pi) * 0.8 else 0
	end
	enemy.Facing = dir
	local pos = enemy.Position + Vector3.new(0, bob, 0) + dir * lunge
	enemy.Model:PivotTo(CFrame.lookAt(pos, pos + dir))
end

local function spawnMinions()
	local wave = options.GetWave()
	for _ = 1, Config.Enemies.Eagle.MinionCount do
		EnemyService.SpawnFox(wave, options.GetFoxSpawn())
	end
end

local function updateEagle(enemy: Enemy, dt: number, speedMult: number)
	local cfg = Config.Enemies.Eagle
	local burrow = options.BurrowPosition
	enemy.StateTimer -= dt * speedMult
	enemy.MinionTimer -= dt
	if enemy.MinionTimer <= 0 then
		enemy.MinionTimer = cfg.MinionInterval
		task.defer(spawnMinions) -- never add enemies while iterating
	end

	local lookDir = enemy.Facing
	if enemy.State == "Circle" then
		enemy.Angle += dt * cfg.CircleSpeed * speedMult
		local target = burrow + Vector3.new(math.cos(enemy.Angle) * cfg.CircleRadius, cfg.CircleHeight, math.sin(enemy.Angle) * cfg.CircleRadius)
		enemy.Position = enemy.Position:Lerp(target, math.min(1, dt * 2.5))
		lookDir = Vector3.new(-math.sin(enemy.Angle), 0, math.cos(enemy.Angle))
		if enemy.StateTimer <= 0 then
			enemy.State = "Dive"
			enemy.StateTimer = cfg.DiveTime
			enemy.DiveFrom = enemy.Position
		end
	elseif enemy.State == "Dive" then
		local from = enemy.DiveFrom or enemy.Position
		local outward = flatDirection(burrow, from)
		local target = burrow + outward * (Config.Burrow.Radius + 2) + Vector3.new(0, cfg.DiveHeight, 0)
		local alpha = math.clamp(1 - enemy.StateTimer / cfg.DiveTime, 0, 1)
		enemy.Position = from:Lerp(target, alpha * alpha)
		lookDir = flatDirection(from, burrow)
		if enemy.StateTimer <= 0 then
			options.OnBurrowDamaged(enemy.Damage, enemy)
			poof(target, Color3.fromRGB(200, 170, 120), 6)
			enemy.State = "Circle"
			enemy.StateTimer = cfg.CircleTime
		end
	end

	enemy.Facing = lookDir
	enemy.Phase += dt * 6 * speedMult
	enemy.Model:PivotTo(CFrame.lookAt(enemy.Position, enemy.Position + lookDir))

	-- flap wings around their shoulder joints
	local flap = math.sin(enemy.Phase) * math.rad(25)
	local rootCFrame = enemy.Root.CFrame
	for _, wing in enemy.Wings or {} do
		local s = 1.6
		wing.Part.CFrame = rootCFrame * wing.Offset * CFrame.Angles(0, 0, -wing.Side * flap) * CFrame.new(wing.Side * 5 * s, 0, 0)
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, enemy in active do
		if not enemy.Dead then
			local speedMult = if now < enemy.SlowUntil then enemy.SlowFactor else 1
			if enemy.Kind == "Eagle" then
				updateEagle(enemy, dt, speedMult)
			else
				updateFox(enemy, dt, speedMult)
			end
		end
	end
end

function EnemyService.Init(opts: InitOptions)
	assert(not initialized, "EnemyService already initialized")
	initialized = true
	options = opts
	RunService.Heartbeat:Connect(step)
end

return EnemyService
