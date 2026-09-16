--!nonstrict
-- Ranks
-- Career progression. Ranks are earned from lifetime earnings and successful calls.

local Ranks = {}

Ranks.List = {
	{
		index = 1, id = "intern", name = "Intern",
		lifetime = 0, calls = 0,
		perks = { "Easy and Normal difficulty", "Basic dialogue options" },
		dialogueLevel = 1,
		rewardMul = 1.0,
	},
	{
		index = 2, id = "junior", name = "Junior Caller",
		lifetime = 1500, calls = 5,
		perks = { "Unlocks the Break Room", "+5% call rewards" },
		dialogueLevel = 1,
		rewardMul = 1.05,
	},
	{
		index = 3, id = "caller", name = "Caller",
		lifetime = 5000, calls = 15,
		perks = { "Unlocks Hard difficulty", "Unlocks advanced dialogue options" },
		dialogueLevel = 2,
		rewardMul = 1.10,
	},
	{
		index = 4, id = "senior", name = "Senior Caller",
		lifetime = 14000, calls = 30,
		perks = { "Unlocks the Senior Floor desks", "New NPC types" },
		dialogueLevel = 2,
		rewardMul = 1.15,
	},
	{
		index = 5, id = "leader", name = "Team Leader",
		lifetime = 32000, calls = 55,
		perks = { "Unlocks Expert difficulty", "Unlocks expert dialogue options" },
		dialogueLevel = 3,
		rewardMul = 1.22,
	},
	{
		index = 6, id = "floor", name = "Floor Manager",
		lifetime = 70000, calls = 90,
		perks = { "Unlocks the Manager's Office", "Cosmetic: clipboard" },
		dialogueLevel = 3,
		rewardMul = 1.30,
	},
	{
		index = 7, id = "operations", name = "Operations Manager",
		lifetime = 140000, calls = 140,
		perks = { "Unlocks Nightmare difficulty", "Unlocks legendary upgrades" },
		dialogueLevel = 4,
		rewardMul = 1.40,
	},
	{
		index = 8, id = "boss", name = "Call Centre Boss",
		lifetime = 300000, calls = 220,
		perks = { "Unlocks the Executive Floor", "Cosmetic: gold nameplate" },
		dialogueLevel = 4,
		rewardMul = 1.55,
	},
	{
		index = 9, id = "ceo", name = "Scam Empire CEO",
		lifetime = 750000, calls = 350,
		perks = { "Unlocks the Penthouse", "Cosmetic: absurd throne", "+80% call rewards" },
		dialogueLevel = 5,
		rewardMul = 1.80,
	},
}

Ranks.ById = {}
for _, rank in ipairs(Ranks.List) do
	Ranks.ById[rank.id] = rank
end

function Ranks.get(index: number)
	return Ranks.List[math.clamp(index, 1, #Ranks.List)]
end

-- Highest rank whose requirements the player meets.
function Ranks.evaluate(lifetimeEarnings: number, successfulCalls: number): number
	local best = 1
	for _, rank in ipairs(Ranks.List) do
		if lifetimeEarnings >= rank.lifetime and successfulCalls >= rank.calls then
			best = rank.index
		end
	end
	return best
end

function Ranks.next(index: number)
	return Ranks.List[index + 1]
end

return Ranks
