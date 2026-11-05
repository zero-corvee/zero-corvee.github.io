-- PlayerDataService: coins, mana and upgrade levels.
-- Values are stored as Player attributes so the client HUD can read them
-- directly; only the server ever writes them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BunnyGuardian"):WaitForChild("Shared"):WaitForChild("Config"))

local PlayerDataService = {}

local function upgradeAttr(upgradeId: string): string
	return "Upgrade_" .. upgradeId
end

function PlayerDataService.GetUpgradeLevel(player: Player, upgradeId: string): number
	return player:GetAttribute(upgradeAttr(upgradeId)) or 0
end

function PlayerDataService.SetUpgradeLevel(player: Player, upgradeId: string, level: number)
	player:SetAttribute(upgradeAttr(upgradeId), level)
	if upgradeId == "MaxMana" then
		local maxMana = Config.Mana.Max + level * Config.Upgrades.MaxMana.PerLevel
		player:SetAttribute("MaxMana", maxMana)
	end
end

function PlayerDataService.GetDamageMultiplier(player: Player, upgradeId: string): number
	local upgrade = Config.Upgrades[upgradeId]
	if not upgrade or not upgrade.PerLevel then
		return 1
	end
	return 1 + PlayerDataService.GetUpgradeLevel(player, upgradeId) * upgrade.PerLevel
end

function PlayerDataService.GetCoins(player: Player): number
	return player:GetAttribute("Coins") or 0
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	player:SetAttribute("Coins", PlayerDataService.GetCoins(player) + amount)
end

function PlayerDataService.TrySpendCoins(player: Player, amount: number): boolean
	local coins = PlayerDataService.GetCoins(player)
	if coins < amount then
		return false
	end
	player:SetAttribute("Coins", coins - amount)
	return true
end

function PlayerDataService.TrySpendMana(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local mana = player:GetAttribute("Mana") or 0
	if mana < amount then
		return false
	end
	player:SetAttribute("Mana", mana - amount)
	return true
end

function PlayerDataService.Reset(player: Player)
	player:SetAttribute("Coins", 0)
	for upgradeId in Config.Upgrades do
		PlayerDataService.SetUpgradeLevel(player, upgradeId, 0)
	end
	player:SetAttribute("MaxMana", Config.Mana.Max)
	player:SetAttribute("Mana", Config.Mana.Max)
end

function PlayerDataService.ResetAll()
	for _, player in Players:GetPlayers() do
		PlayerDataService.Reset(player)
	end
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(PlayerDataService.Reset)
	for _, player in Players:GetPlayers() do
		PlayerDataService.Reset(player)
	end

	-- Mana regeneration
	task.spawn(function()
		local tick = 0.1
		while true do
			task.wait(tick)
			for _, player in Players:GetPlayers() do
				local maxMana = player:GetAttribute("MaxMana") or Config.Mana.Max
				local mana = player:GetAttribute("Mana") or 0
				if mana < maxMana then
					local regen = Config.Mana.RegenPerSecond
						+ PlayerDataService.GetUpgradeLevel(player, "MaxMana") * Config.Upgrades.MaxMana.RegenPerLevel
					player:SetAttribute("Mana", math.min(maxMana, mana + regen * tick))
				end
			end
		end
	end)
end

return PlayerDataService
