--!nonstrict
-- UpgradeManager
-- Validates and applies desk upgrade purchases.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Upgrades = require(Shared.Upgrades)

local PlayerDataManager = require(script.Parent.PlayerDataManager)

local UpgradeManager = {}

UpgradeManager.Purchased = Instance.new("BindableEvent")

function UpgradeManager.purchase(player: Player, upgradeId: string): (boolean, string)
	local data = PlayerDataManager.get(player)
	if not data then
		return false, "Profile still loading."
	end
	local def = Upgrades.ById[upgradeId]
	local ok, reason = Upgrades.canPurchase(def, data)
	if not ok then
		return false, reason
	end

	if not PlayerDataManager.spendCredits(player, def.cost) then
		return false, "Not enough Credits."
	end
	PlayerDataManager.grantUpgrade(player, def.id)
	UpgradeManager.Purchased:Fire(player, def)
	return true, def.name .. " installed at your desk."
end

-- Catalog view for the shop UI (cost, ownership and lock state per player).
function UpgradeManager.catalog(player: Player)
	local data = PlayerDataManager.get(player)
	local out = {}
	for _, def in ipairs(Upgrades.List) do
		local owned = data ~= nil and data.upgrades[def.id] == true
		local canBuy, reason = false, "Profile loading."
		if data then
			canBuy, reason = Upgrades.canPurchase(def, data)
		end
		local effects = {}
		for key, value in pairs(def.effects) do
			table.insert(effects, { key = key, value = value })
		end
		table.sort(effects, function(a, b)
			return a.key < b.key
		end)
		table.insert(out, {
			id = def.id,
			name = def.name,
			blurb = def.blurb,
			cost = def.cost,
			order = def.order,
			requiresRank = def.requiresRank or 1,
			requires = def.requires,
			effects = effects,
			owned = owned,
			canBuy = canBuy,
			reason = reason,
		})
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

return UpgradeManager
