--!nonstrict
-- Products
-- The Robux catalogue: Game Passes (permanent) and Developer Products
-- (consumable). Nothing here works until you create each item on the Roblox
-- Creator Dashboard and paste its ID into `assetId` below -- an assetId of 0
-- means "not configured", and the game shows the item as unavailable instead of
-- prompting a purchase that would fail.
--
-- Credit packs are granted with countAsEarnings = false, so bought Credits can
-- buy desk upgrades but never lifetime earnings. Rank, the earnings board and
-- the "Suspicious Wealth" achievement are all driven by earnings, so none of
-- them can be bought.
--
-- Design rule for this game: sell time and vanity, never outcomes. Paid items
-- must not reveal who is on the other end of the call, because reading the
-- caller is the entire skill on Hard and above. The difficulty leaderboards
-- count successful calls, which no paid multiplier can inflate.

local Products = {}

--------------------------------------------------------------------------------
-- Game Passes: bought once, owned forever.
--------------------------------------------------------------------------------

Products.GamePasses = {
	{
		id = "overtime_contract",
		assetId = 0,
		name = "Overtime Contract",
		blurb = "Double Credits from every call, forever. Does not affect the leaderboards.",
		suggestedRobux = 199,
		order = 1,
		-- Merged into the same bonus table the desk upgrades feed.
		effects = { rewardMul = 1.0 },
	},
	{
		id = "employee_of_month",
		assetId = 0,
		name = "Employee Of The Month",
		blurb = "A gold title over your head that everyone in the server can see. Purely for showing off.",
		suggestedRobux = 99,
		order = 2,
		cosmetic = true,
		title = { text = "EMPLOYEE OF THE MONTH", colour = Color3.fromRGB(244, 203, 96) },
	},
	{
		id = "corner_office",
		assetId = 0,
		name = "Corner Office",
		blurb = "Your own desk inside the glass manager's office. Take calls from up there.",
		suggestedRobux = 149,
		order = 3,
		cosmetic = true,
	},
	{
		id = "platinum_headset",
		assetId = 0,
		name = "Platinum Headset",
		blurb = "A cosmetic headset your character actually wears. No stats. None. It just looks expensive.",
		suggestedRobux = 79,
		order = 4,
		cosmetic = true,
	},
	{
		id = "alias_licence",
		assetId = 0,
		name = "Alias Licence",
		blurb = "Stop being Kevin. Pick your own fake technician name and it replaces Kevin everywhere in your dialogue.",
		suggestedRobux = 99,
		order = 5,
		cosmetic = true,
	},
}

--------------------------------------------------------------------------------
-- Developer Products: bought repeatedly, consumed.
--------------------------------------------------------------------------------
-- grant.kind tells MonetisationManager what to do on a successful receipt:
--   "credits"    add credits immediately
--   "boost"      start a timed reward multiplier
--   "consumable" add one to the player's inventory, used from the call screen

Products.DeveloperProducts = {
	{
		id = "coffee_refill",
		assetId = 0,
		name = "Coffee Refill",
		blurb = "Restores 40 Patience mid-call. The break room machine has been broken since 2019.",
		suggestedRobux = 25,
		order = 1,
		grant = { kind = "consumable", amount = 1 },
		use = { patience = 40 },
		useLabel = "Coffee",
		usableInCall = true,
	},
	{
		id = "supervisor_takeover",
		assetId = 0,
		name = "Supervisor Takeover",
		blurb = "Your floor lead handles the next interruption for you. Skips one random event.",
		suggestedRobux = 35,
		order = 2,
		grant = { kind = "consumable", amount = 1 },
		use = { skipNextEvent = true },
		useLabel = "Supervisor",
		usableInCall = true,
	},
	{
		id = "warm_lead",
		assetId = 0,
		name = "Warm Lead",
		blurb = "Your next caller is rolled one tier friendlier. Consumed automatically when the call starts.",
		suggestedRobux = 45,
		order = 3,
		grant = { kind = "consumable", amount = 1 },
		use = { warmLead = true },
		useLabel = "Warm Lead",
		usableInCall = false,
	},
	{
		id = "petty_cash",
		assetId = 0,
		name = "Petty Cash",
		blurb = "2,500 Call Centre Credits, straight into your account.",
		suggestedRobux = 49,
		order = 4,
		grant = { kind = "credits", amount = 2500 },
	},
	{
		id = "bonus_payslip",
		assetId = 0,
		name = "Bonus Payslip",
		blurb = "15,000 Call Centre Credits. HR has questions but is not asking them.",
		suggestedRobux = 199,
		order = 5,
		grant = { kind = "credits", amount = 15000 },
	},
	{
		id = "double_shift",
		assetId = 0,
		name = "Double Shift",
		blurb = "Double Credits for the next 30 minutes. Stacks its timer if you buy it again.",
		suggestedRobux = 99,
		order = 6,
		grant = { kind = "boost", multiplier = 1.0, seconds = 1800 },
	},
}

--------------------------------------------------------------------------------

Products.PassById = {}
for _, pass in ipairs(Products.GamePasses) do
	Products.PassById[pass.id] = pass
end

Products.ProductById = {}
for _, product in ipairs(Products.DeveloperProducts) do
	Products.ProductById[product.id] = product
end

-- Reverse lookups, built lazily because assetIds are edited by hand and may be 0.
function Products.passByAssetId(assetId: number)
	for _, pass in ipairs(Products.GamePasses) do
		if pass.assetId ~= 0 and pass.assetId == assetId then
			return pass
		end
	end
	return nil
end

function Products.productByAssetId(assetId: number)
	for _, product in ipairs(Products.DeveloperProducts) do
		if product.assetId ~= 0 and product.assetId == assetId then
			return product
		end
	end
	return nil
end

function Products.isConfigured(def): boolean
	return def ~= nil and def.assetId ~= nil and def.assetId ~= 0
end

-- Folds owned passes and any live boost into an existing bonus table (the one
-- Upgrades.aggregate produced), so CallManager and RewardManager stay unaware
-- that Robux exists.
function Products.applyBonuses(bonuses, premium)
	premium = premium or {}
	local owned = premium.passes or {}

	for _, pass in ipairs(Products.GamePasses) do
		if owned[pass.id] and pass.effects then
			for key, value in pairs(pass.effects) do
				if key == "suspicionResist" or key == "eventResist" then
					bonuses[key] = (bonuses[key] or 1) * value
				else
					bonuses[key] = (bonuses[key] or 0) + value
				end
			end
		end
	end

	if premium.boostExpires and premium.boostExpires > os.time() then
		bonuses.rewardMul = (bonuses.rewardMul or 1) + (premium.boostMultiplier or 1)
	end

	return bonuses
end

return Products
