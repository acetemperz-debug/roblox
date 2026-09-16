--!nonstrict
-- Upgrades
-- Purchasable desk upgrades. Effects are summed by UpgradeManager into a single
-- bonus table that CallManager reads at the start of every call.
--
-- Effect keys:
--   startTrust        flat trust the NPC begins with
--   startSuspicion    flat suspicion modifier (negative is good)
--   suspicionResist   multiplier applied to suspicion gains (0.95 = 5% less)
--   rewardMul         multiplier on call payouts
--   patienceBonus     flat patience added to every NPC
--   easyChance        added chance of rolling an easier personality tier
--   timeBonus         extra seconds before the fast-call bonus expires
--   eventResist       multiplier on random-event chance

local Upgrades = {}

Upgrades.List = {
	{
		id = "headset_cheap",
		name = "Cheap Headset",
		blurb = "The microphone crackles. Somehow this makes you sound official.",
		cost = 250,
		order = 1,
		requiresRank = 1,
		effects = { startTrust = 2 },
	},
	{
		id = "headset_pro",
		name = "Professional Headset",
		blurb = "Noise cancelling. The NPC can no longer hear forty other people lying.",
		cost = 1200,
		order = 2,
		requiresRank = 2,
		requires = "headset_cheap",
		effects = { startTrust = 5, suspicionResist = 0.96 },
	},
	{
		id = "computer_better",
		name = "Better Computer",
		blurb = "Boots in under nine minutes. Revolutionary.",
		cost = 2000,
		order = 3,
		requiresRank = 2,
		effects = { rewardMul = 0.05, timeBonus = 15 },
	},
	{
		id = "dialler_fast",
		name = "Faster Dialler",
		blurb = "Connects to a caller before you have finished panicking.",
		cost = 3200,
		order = 4,
		requiresRank = 3,
		effects = { timeBonus = 30, easyChance = 0.03 },
	},
	{
		id = "coffee_machine",
		name = "Coffee Machine",
		blurb = "You are now legally a different person.",
		cost = 4500,
		order = 5,
		requiresRank = 3,
		effects = { patienceBonus = 8, suspicionResist = 0.97 },
	},
	{
		id = "air_conditioning",
		name = "Air Conditioning",
		blurb = "Stops you sounding like you are calling from inside a kettle.",
		cost = 6500,
		order = 6,
		requiresRank = 3,
		effects = { suspicionResist = 0.94, patienceBonus = 5 },
	},
	{
		id = "chair_luxury",
		name = "Luxury Office Chair",
		blurb = "Lumbar support for a man with no moral support.",
		cost = 9000,
		order = 7,
		requiresRank = 4,
		effects = { patienceBonus = 10, startTrust = 3 },
	},
	{
		id = "monitors_multi",
		name = "Multiple Monitors",
		blurb = "Four screens. Three of them show a solitaire game.",
		cost = 13000,
		order = 8,
		requiresRank = 4,
		requires = "computer_better",
		effects = { rewardMul = 0.08, eventResist = 0.9 },
	},
	{
		id = "rgb_setup",
		name = "RGB Gaming Setup",
		blurb = "Adds no functional benefit. Adds every functional benefit.",
		cost = 18000,
		order = 9,
		requiresRank = 5,
		effects = { rewardMul = 0.06, startTrust = 4, easyChance = 0.04 },
	},
	{
		id = "desk_manager",
		name = "Manager's Desk",
		blurb = "Twice the width, half the legitimacy.",
		cost = 26000,
		order = 10,
		requiresRank = 6,
		effects = { startTrust = 6, suspicionResist = 0.92, rewardMul = 0.1 },
	},
	{
		id = "headset_golden",
		name = "Golden Headset",
		blurb = "Solid gold. Extremely heavy. Cannot be worn for more than ten minutes.",
		cost = 55000,
		order = 11,
		requiresRank = 7,
		requires = "headset_pro",
		effects = { startTrust = 10, rewardMul = 0.15, patienceBonus = 6 },
	},
	{
		id = "office_executive",
		name = "Executive Office",
		blurb = "Glass walls so everyone can watch you fail privately.",
		cost = 120000,
		order = 12,
		requiresRank = 8,
		requires = "desk_manager",
		effects = { startTrust = 8, suspicionResist = 0.88, rewardMul = 0.2, easyChance = 0.05 },
	},
	{
		id = "voice_changer",
		name = "Deluxe Voice Modulator",
		blurb = "Makes you sound like a man who owns a filing cabinet.",
		cost = 42000,
		order = 13,
		requiresRank = 7,
		effects = { suspicionResist = 0.9, startTrust = 5 },
	},
	{
		id = "call_script_binder",
		name = "Laminated Script Binder",
		blurb = "Entirely fictional. Mostly pictures of cats. Comforting anyway.",
		cost = 7500,
		order = 14,
		requiresRank = 4,
		effects = { startTrust = 4, eventResist = 0.92 },
	},
}

Upgrades.ById = {}
for _, up in ipairs(Upgrades.List) do
	Upgrades.ById[up.id] = up
end

Upgrades.DefaultBonuses = {
	startTrust = 0,
	startSuspicion = 0,
	suspicionResist = 1,
	rewardMul = 1,
	patienceBonus = 0,
	easyChance = 0,
	timeBonus = 0,
	eventResist = 1,
}

-- Sum a list of owned upgrade ids into one bonus table.
function Upgrades.aggregate(owned): { [string]: number }
	local bonuses = table.clone(Upgrades.DefaultBonuses)
	for id, isOwned in pairs(owned or {}) do
		if isOwned then
			local def = Upgrades.ById[id]
			if def then
				for key, value in pairs(def.effects) do
					if key == "suspicionResist" or key == "eventResist" then
						bonuses[key] *= value
					elseif key == "rewardMul" then
						bonuses[key] += value
					else
						bonuses[key] += value
					end
				end
			end
		end
	end
	return bonuses
end

-- Can this player buy it right now? Returns ok, reason.
function Upgrades.canPurchase(def, data): (boolean, string)
	if not def then
		return false, "Unknown upgrade."
	end
	if data.upgrades[def.id] then
		return false, "Already owned."
	end
	if def.requires and not data.upgrades[def.requires] then
		local prereq = Upgrades.ById[def.requires]
		return false, "Requires " .. (prereq and prereq.name or def.requires) .. "."
	end
	if data.rankIndex < (def.requiresRank or 1) then
		return false, "Rank too low."
	end
	if data.credits < def.cost then
		return false, "Not enough Credits."
	end
	return true, ""
end

return Upgrades
