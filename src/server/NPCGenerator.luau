--!nonstrict
-- NPCGenerator
-- Rolls a fresh caller: personality, name, age, mood, backstory, starting meters.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Difficulty = require(Shared.Difficulty)
local Personalities = require(Shared.Personalities)
local NPCNames = require(Shared.NPCNames)

local NPCGenerator = {}

-- Portrait colours are picked deterministically from the name so the same NPC
-- always looks the same within a call.
local PORTRAIT_COLOURS = {
	Color3.fromRGB(226, 135, 67),
	Color3.fromRGB(105, 168, 233),
	Color3.fromRGB(148, 196, 121),
	Color3.fromRGB(214, 121, 168),
	Color3.fromRGB(233, 196, 106),
	Color3.fromRGB(151, 137, 220),
	Color3.fromRGB(102, 194, 189),
	Color3.fromRGB(224, 108, 108),
}

local function pickTier(difficultyKey: string, bonuses, random: Random): string
	local level = Difficulty.get(difficultyKey)
	local pool = {}
	for tier, weight in pairs(level.tiers) do
		local w = weight
		-- "easyChance" upgrades bias the roll toward the gentler tiers.
		if tier == "Easy" or tier == "Normal" then
			w += (bonuses.easyChance or 0) * 10
		end
		table.insert(pool, { tier = tier, weight = w })
	end
	local choice = Util.weightedPick(pool, random)
	return choice and choice.tier or "Normal"
end

-- One step down the tier ladder. Used by the Warm Lead item.
local TIER_ORDER = { "Easy", "Normal", "Hard", "Expert", "Nightmare" }
local function friendlierTier(tier: string): string
	for index, name in ipairs(TIER_ORDER) do
		if name == tier then
			return TIER_ORDER[math.max(1, index - 1)]
		end
	end
	return tier
end

-- options: { warmLead: boolean? }
function NPCGenerator.generate(difficultyKey: string, bonuses, seed: number?, options)
	local random = Util.newRandom(seed)
	local level = Difficulty.get(difficultyKey)
	bonuses = bonuses or {}
	options = options or {}

	local tier = pickTier(difficultyKey, bonuses, random)
	if options.warmLead then
		tier = friendlierTier(tier)
	end
	local pool = Personalities.ofTier(tier)
	if #pool == 0 then
		pool = Personalities.ofTier("Normal")
	end
	local personality = Util.pick(pool, random)

	local firstName = Util.pick(NPCNames.First, random)
	local lastName = Util.pick(NPCNames.Last, random)
	local mood = Util.pick(NPCNames.Moods, random)
	local town = Util.pick(NPCNames.Towns, random)
	local job = Util.pick(NPCNames.Jobs, random)
	local backstory = Util.pick(NPCNames.Backstories, random)

	local age = random:NextInteger(personality.ageRange[1], personality.ageRange[2])
	local tech = random:NextInteger(personality.techRange[1], personality.techRange[2])

	local startTrust = personality.base.trust + (bonuses.startTrust or 0)
	local startSuspicion = personality.base.suspicion + mood.suspicion + (bonuses.startSuspicion or 0)
	local startPatience = personality.base.patience + mood.patience + (bonuses.patienceBonus or 0)

	startTrust = Util.clamp(startTrust, 0, Config.Call.MaxTrust)
	startSuspicion = Util.clamp(startSuspicion, 0, 90)
	startPatience = Util.clamp(startPatience * level.patienceMul, 10, Config.Call.MaxPatience)

	local colour = PORTRAIT_COLOURS[(#firstName + #lastName + age) % #PORTRAIT_COLOURS + 1]

	return {
		personalityId = personality.id,
		personalityName = personality.name,
		blurb = personality.blurb,
		tier = tier,
		firstName = firstName,
		lastName = lastName,
		fullName = firstName .. " " .. lastName,
		initials = string.sub(firstName, 1, 1) .. string.sub(lastName, 1, 1),
		age = age,
		techKnowledge = tech,
		job = job,
		town = town,
		moodId = mood.id,
		moodLabel = mood.label,
		backstory = string.format("%s, %d, a %s from %s who %s.", firstName, age, job, town, backstory),
		portraitColour = colour,

		trust = startTrust,
		suspicion = startSuspicion,
		patience = startPatience,

		quirks = Util.deepCopy(personality.quirks or {}),
		rewardMul = personality.reward or 1,
		warmLead = options.warmLead == true,
		seed = seed or random:NextInteger(1, 2 ^ 30),
	}
end

-- Small helper used by the UI: a one-line "who am I talking to" summary.
function NPCGenerator.describe(npc): string
	return string.format("%s (%d) - %s", npc.fullName, npc.age, npc.personalityName)
end

return NPCGenerator
