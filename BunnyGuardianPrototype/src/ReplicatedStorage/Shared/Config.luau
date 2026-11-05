--!strict
-- Bunny Guardian: Rise of the Rabbit
-- Shared tuning values used by both server and client.

local Config = {}

Config.GameName = "Bunny Guardian: Rise of the Rabbit"

Config.Burrow = {
	MaxHealth = 500,
	Position = Vector3.new(0, 0, 0),
	Radius = 7, -- foxes stop and attack at Radius + AttackRange
}

Config.Waves = {
	Total = 10,
	BossWave = 10,
	FirstIntermission = 12,
	Intermission = 8,
	RestartDelay = 10,
	WaveClearBonus = 10, -- coins per wave number, given to every player
}

function Config.FoxesForWave(wave: number): number
	if wave == Config.Waves.BossWave then
		return 8
	end
	return 3 + wave * 2
end

function Config.SpawnIntervalForWave(wave: number): number
	return math.max(0.6, 2.2 - wave * 0.15)
end

Config.Player = {
	WalkSpeed = 20,
	JumpPower = 55,
}

Config.Mana = {
	Max = 100,
	RegenPerSecond = 8,
}

Config.Abilities = {
	CarrotThrow = {
		DisplayName = "Carrot",
		KeyHint = "Click / F",
		Cooldown = 0.35,
		ManaCost = 0,
		Damage = 15,
		Speed = 90,
		Range = 110,
		HitRadius = 2.5,
	},
	HurricaneKick = {
		DisplayName = "Hurricane Kick",
		KeyHint = "Q",
		Cooldown = 1.2,
		ManaCost = 30,
		Damage = 45,
		Speed = 65,
		Range = 90,
		HitRadius = 4.5,
	},
	EarCyclone = {
		DisplayName = "Ear Cyclone",
		KeyHint = "E",
		Cooldown = 8,
		ManaCost = 0,
		Radius = 16,
		Duration = 4,
		TickRate = 0.5,
		DamagePerTick = 4,
		SlowFactor = 0.35, -- enemies move at 35% speed
		SlowDuration = 2.5,
	},
}

Config.AbilityOrder = { "CarrotThrow", "HurricaneKick", "EarCyclone" }

Config.Upgrades = {
	CarrotDamage = {
		DisplayName = "Carrot Power",
		Description = "+25% carrot damage",
		BaseCost = 15,
		CostGrowth = 1.4,
		MaxLevel = 10,
		PerLevel = 0.25,
	},
	KickDamage = {
		DisplayName = "Kick Power",
		Description = "+25% Hurricane Kick damage",
		BaseCost = 25,
		CostGrowth = 1.45,
		MaxLevel = 10,
		PerLevel = 0.25,
	},
	MaxMana = {
		DisplayName = "Mana Pool",
		Description = "+20 max mana, +2 mana/s",
		BaseCost = 20,
		CostGrowth = 1.4,
		MaxLevel = 8,
		PerLevel = 20,
		RegenPerLevel = 2,
	},
	RepairBurrow = {
		DisplayName = "Repair Burrow",
		Description = "Restore 100 burrow health",
		BaseCost = 30,
		CostGrowth = 1,
		MaxLevel = math.huge,
		Heal = 100,
	},
}

Config.UpgradeOrder = { "CarrotDamage", "KickDamage", "MaxMana", "RepairBurrow" }

function Config.GetUpgradeCost(upgradeId: string, level: number): number
	local upgrade = Config.Upgrades[upgradeId]
	if not upgrade then
		return math.huge
	end
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level + 0.5)
end

Config.Enemies = {
	Fox = {
		BaseHealth = 30,
		HealthPerWave = 10,
		BaseSpeed = 8,
		SpeedPerWave = 0.5,
		Damage = 5,
		AttackInterval = 1,
		AttackRange = 2.5,
		Reward = 5,
		HitRadius = 2,
		HitHeight = 3,
	},
	Eagle = {
		Health = 1500,
		Reward = 250,
		CircleRadius = 32,
		CircleHeight = 12,
		CircleSpeed = 0.6, -- radians per second
		CircleTime = 6, -- seconds between dives
		DiveTime = 1.4,
		DiveHeight = 5,
		DiveDamage = 30,
		MinionInterval = 12,
		MinionCount = 2,
		HitRadius = 6,
		HitHeight = 14,
	},
}

return Config
