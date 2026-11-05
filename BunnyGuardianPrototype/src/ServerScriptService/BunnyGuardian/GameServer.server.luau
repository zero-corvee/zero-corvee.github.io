-- Bunny Guardian: Rise of the Rabbit - main server script.
-- Builds the garden, then runs the wave loop: intermission -> wave -> ...
-- -> boss eagle on wave 10 -> victory (or game over if the burrow falls).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BunnyGuardian = ReplicatedStorage:WaitForChild("BunnyGuardian")
local Config = require(BunnyGuardian:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = BunnyGuardian:WaitForChild("Remotes")
local GameState = BunnyGuardian:WaitForChild("GameState")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local Modules = script.Parent:WaitForChild("Modules")
local MapBuilder = require(Modules.MapBuilder)
local PlayerDataService = require(Modules.PlayerDataService)
local CharacterService = require(Modules.CharacterService)
local EnemyService = require(Modules.EnemyService)
local AbilityService = require(Modules.AbilityService)
local UpgradeService = require(Modules.UpgradeService)

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local map = MapBuilder.Build()
local burrowColor = map.Burrow.Color
local burrowHealth = Config.Burrow.MaxHealth
local burrowDestroyed = false
local currentWave = 0
local runId = 0
local remainingToSpawn = 0
local rng = Random.new()

GameState:SetAttribute("GameName", Config.GameName)
GameState:SetAttribute("TotalWaves", Config.Waves.Total)
GameState:SetAttribute("BossWave", Config.Waves.BossWave)
GameState:SetAttribute("Wave", 0)
GameState:SetAttribute("Status", "Waiting")
GameState:SetAttribute("Timer", 0)
GameState:SetAttribute("EnemiesLeft", 0)
GameState:SetAttribute("BurrowHealth", burrowHealth)
GameState:SetAttribute("BurrowMaxHealth", Config.Burrow.MaxHealth)
GameState:SetAttribute("BossActive", false)
GameState:SetAttribute("BossHealth", 0)
GameState:SetAttribute("BossMaxHealth", Config.Enemies.Eagle.Health)

local function notify(text: string, kind: string?)
	NotifyRemote:FireAllClients(text, kind or "info")
end

local function setStatus(status: string, timer: number?)
	GameState:SetAttribute("Status", status)
	GameState:SetAttribute("Timer", timer or 0)
end

local function setBurrowHealth(value: number)
	burrowHealth = math.clamp(value, 0, Config.Burrow.MaxHealth)
	GameState:SetAttribute("BurrowHealth", burrowHealth)
end

local function updateEnemiesLeft()
	GameState:SetAttribute("EnemiesLeft", remainingToSpawn + EnemyService.Count())
end

local function getFoxSpawn(): Vector3
	local base = map.FoxSpawns[rng:NextInteger(1, #map.FoxSpawns)]
	return base + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
end

------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------

PlayerDataService.Init()
CharacterService.Init()

EnemyService.Init({
	BurrowPosition = Config.Burrow.Position,
	EnemyFolder = map.EnemyFolder,
	EffectsFolder = map.EffectsFolder,
	GetFoxSpawn = getFoxSpawn,
	GetWave = function()
		return math.max(1, currentWave)
	end,
	OnBurrowDamaged = function(amount)
		if burrowDestroyed or GameState:GetAttribute("Status") ~= "Wave" then
			return
		end
		setBurrowHealth(burrowHealth - amount)
		-- quick red flash on the mound
		map.Burrow.Color = Color3.fromRGB(200, 70, 60)
		task.delay(0.12, function()
			map.Burrow.Color = burrowColor
		end)
		if burrowHealth <= 0 then
			burrowDestroyed = true -- the wave loop handles cleanup
		end
	end,
	OnKilled = function(enemy, killer)
		if killer then
			PlayerDataService.AddCoins(killer, enemy.Reward)
		end
		if enemy.Kind == "Eagle" then
			GameState:SetAttribute("BossActive", false)
			GameState:SetAttribute("BossHealth", 0)
			notify("The Great Eagle has been defeated!", "success")
			-- everyone shares the boss bounty
			for _, player in Players:GetPlayers() do
				if player ~= killer then
					PlayerDataService.AddCoins(player, math.floor(enemy.Reward / 2))
				end
			end
		end
		updateEnemiesLeft()
	end,
	OnBossHealthChanged = function(health, maxHealth)
		GameState:SetAttribute("BossHealth", health)
		GameState:SetAttribute("BossMaxHealth", maxHealth)
	end,
})

AbilityService.Init(map.EffectsFolder)

UpgradeService.Init({
	RepairBurrow = function(amount: number): boolean
		if burrowDestroyed or burrowHealth >= Config.Burrow.MaxHealth then
			return false
		end
		setBurrowHealth(burrowHealth + amount)
		return true
	end,
})

------------------------------------------------------------------------
-- Game flow
------------------------------------------------------------------------

local function countdown(status: string, seconds: number)
	for t = seconds, 1, -1 do
		setStatus(status, t)
		task.wait(1)
	end
end

local function resetGame()
	runId += 1
	EnemyService.ClearAll()
	AbilityService.ClearProjectiles()
	burrowDestroyed = false
	currentWave = 0
	remainingToSpawn = 0
	setBurrowHealth(Config.Burrow.MaxHealth)
	GameState:SetAttribute("Wave", 0)
	GameState:SetAttribute("BossActive", false)
	GameState:SetAttribute("BossHealth", 0)
	updateEnemiesLeft()
	PlayerDataService.ResetAll()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

-- Returns true if the wave was cleared, false if the burrow fell.
local function runWave(wave: number): boolean
	currentWave = wave
	local myRun = runId
	GameState:SetAttribute("Wave", wave)
	setStatus("Wave")

	local foxCount = Config.FoxesForWave(wave)
	remainingToSpawn = foxCount

	if wave == Config.Waves.BossWave then
		notify("WAVE " .. wave .. " - The Great Eagle swoops in!", "boss")
		GameState:SetAttribute("BossActive", true)
		EnemyService.SpawnEagle()
	else
		notify("Wave " .. wave .. " - The foxes are coming!", "warning")
	end
	updateEnemiesLeft()

	task.spawn(function()
		local interval = Config.SpawnIntervalForWave(wave)
		for _ = 1, foxCount do
			if burrowDestroyed or runId ~= myRun then
				return
			end
			EnemyService.SpawnFox(wave, getFoxSpawn())
			remainingToSpawn -= 1
			updateEnemiesLeft()
			task.wait(interval)
		end
	end)

	while not burrowDestroyed do
		updateEnemiesLeft()
		if remainingToSpawn <= 0 and EnemyService.Count() == 0 then
			return true
		end
		task.wait(0.25)
	end
	return false
end

local function gameLoop()
	while true do
		while #Players:GetPlayers() == 0 do
			setStatus("Waiting")
			task.wait(1)
		end

		local won = true
		for wave = 1, Config.Waves.Total do
			countdown("Intermission", if wave == 1 then Config.Waves.FirstIntermission else Config.Waves.Intermission)
			if not runWave(wave) then
				won = false
				break
			end
			local bonus = Config.Waves.WaveClearBonus * wave
			for _, player in Players:GetPlayers() do
				PlayerDataService.AddCoins(player, bonus)
			end
			if wave < Config.Waves.Total then
				notify("Wave " .. wave .. " cleared! +" .. bonus .. " coins", "success")
			end
		end

		runId += 1 -- stops any spawner still running
		if won then
			notify("VICTORY! The burrow is safe. You are the Bunny Guardian!", "success")
			countdown("Victory", Config.Waves.RestartDelay)
		else
			EnemyService.ClearAll()
			GameState:SetAttribute("BossActive", false)
			notify("The burrow has fallen... the foxes win this time.", "boss")
			countdown("GameOver", Config.Waves.RestartDelay)
		end
		resetGame()
	end
end

-- Make sure players joining mid-game get fresh data (handled by PlayerDataService)
-- and start the loop.
task.spawn(gameLoop)
