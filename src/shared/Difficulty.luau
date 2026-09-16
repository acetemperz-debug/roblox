--!nonstrict
-- Difficulty
-- Five difficulty presets. Higher difficulties hide information, raise suspicion
-- gain and open the door to nastier personalities and more random events.

local Difficulty = {}

Difficulty.Order = { "Easy", "Normal", "Hard", "Expert", "Nightmare" }

Difficulty.Levels = {
	Easy = {
		key = "Easy",
		label = "Easy",
		blurb = "Chatty, trusting callers. Meters fully visible.",
		minRankIndex = 1,
		suspicionMul = 0.75,
		trustMul = 1.20,
		patienceMul = 1.25,
		eventChanceMul = 0.5,
		rewardMul = 1.0,
		-- "full" = exact number, "vague" = worded band, "hidden" = no meter at all
		trustDisplay = "full",
		suspicionDisplay = "full",
		patienceDisplay = "full",
		-- Which personality tiers can appear on this difficulty.
		tiers = { Easy = 4, Normal = 1 },
		-- Extra suspicion added when the player repeats a tag too often.
		repeatPenalty = 1,
		order = 1,
	},
	Normal = {
		key = "Normal",
		label = "Normal",
		blurb = "A realistic mix of callers. Trust is shown as a rough band.",
		minRankIndex = 1,
		suspicionMul = 1.0,
		trustMul = 1.0,
		patienceMul = 1.0,
		eventChanceMul = 1.0,
		rewardMul = 1.15,
		trustDisplay = "vague",
		suspicionDisplay = "full",
		patienceDisplay = "full",
		tiers = { Easy = 2, Normal = 4, Hard = 1 },
		repeatPenalty = 2,
		order = 2,
	},
	Hard = {
		key = "Hard",
		label = "Hard",
		blurb = "Sharper callers, more interruptions, trust is hidden.",
		minRankIndex = 3,
		suspicionMul = 1.12,
		trustMul = 0.92,
		patienceMul = 0.85,
		eventChanceMul = 1.4,
		rewardMul = 1.35,
		trustDisplay = "hidden",
		suspicionDisplay = "vague",
		patienceDisplay = "full",
		tiers = { Easy = 1, Normal = 3, Hard = 4, Expert = 1 },
		repeatPenalty = 3,
		order = 3,
	},
	Expert = {
		key = "Expert",
		label = "Expert",
		blurb = "Everyone has heard of this scam. Nothing is shown to you.",
		minRankIndex = 5,
		suspicionMul = 1.18,
		trustMul = 0.86,
		patienceMul = 0.75,
		eventChanceMul = 1.8,
		rewardMul = 1.6,
		trustDisplay = "hidden",
		suspicionDisplay = "hidden",
		patienceDisplay = "vague",
		tiers = { Normal = 1, Hard = 3, Expert = 4, Nightmare = 1 },
		repeatPenalty = 4,
		order = 4,
	},
	Nightmare = {
		key = "Nightmare",
		label = "Nightmare",
		blurb = "Off-duty detectives, scambaiters and people who are simply better at this than you.",
		minRankIndex = 7,
		suspicionMul = 1.35,
		trustMul = 0.80,
		patienceMul = 0.65,
		eventChanceMul = 2.2,
		rewardMul = 2.0,
		trustDisplay = "hidden",
		suspicionDisplay = "hidden",
		patienceDisplay = "hidden",
		tiers = { Hard = 1, Expert = 3, Nightmare = 5 },
		repeatPenalty = 5,
		order = 5,
	},
}

function Difficulty.get(key: string)
	return Difficulty.Levels[key] or Difficulty.Levels.Normal
end

-- Turn an exact 0-100 value into a vague band for the "vague" display mode.
function Difficulty.band(value: number): string
	if value >= 85 then
		return "Very High"
	elseif value >= 65 then
		return "High"
	elseif value >= 40 then
		return "Moderate"
	elseif value >= 20 then
		return "Low"
	end
	return "Very Low"
end

return Difficulty
