-- UpgradeService: handles the upgrade buttons (server validated).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BunnyGuardian = ReplicatedStorage:WaitForChild("BunnyGuardian")
local Config = require(BunnyGuardian:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = BunnyGuardian:WaitForChild("Remotes")

local PlayerDataService = require(script.Parent.PlayerDataService)

local UpgradeService = {}

type InitOptions = {
	-- Heals the burrow; returns false if it is already at full health.
	RepairBurrow: (amount: number) -> boolean,
}

function UpgradeService.Init(opts: InitOptions)
	local buyRemote = Remotes:WaitForChild("BuyUpgrade") :: RemoteFunction

	buyRemote.OnServerInvoke = function(player: Player, upgradeId: any): (boolean, string)
		if typeof(upgradeId) ~= "string" then
			return false, "Invalid upgrade"
		end
		local upgrade = Config.Upgrades[upgradeId]
		if not upgrade then
			return false, "Invalid upgrade"
		end

		local level = PlayerDataService.GetUpgradeLevel(player, upgradeId)
		if level >= upgrade.MaxLevel then
			return false, upgrade.DisplayName .. " is maxed!"
		end

		local cost = Config.GetUpgradeCost(upgradeId, level)
		if PlayerDataService.GetCoins(player) < cost then
			return false, "Not enough coins (" .. cost .. " needed)"
		end

		if upgradeId == "RepairBurrow" then
			if not PlayerDataService.TrySpendCoins(player, cost) then
				return false, "Not enough coins"
			end
			if not opts.RepairBurrow(upgrade.Heal) then
				PlayerDataService.AddCoins(player, cost) -- refund
				return false, "The burrow is already at full health"
			end
			return true, "Burrow repaired!"
		end

		if not PlayerDataService.TrySpendCoins(player, cost) then
			return false, "Not enough coins"
		end
		PlayerDataService.SetUpgradeLevel(player, upgradeId, level + 1)
		return true, upgrade.DisplayName .. " upgraded to Lv " .. (level + 1) .. "!"
	end
end

return UpgradeService
