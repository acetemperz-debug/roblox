--!nonstrict
-- NPCPersonalitySystem
-- Turns "player picked choice X" into "the NPC feels Y and says Z".
--
-- Resolution order:
--   1. base deltas from the choice
--   2. personality like/dislike tag multipliers
--   3. difficulty multipliers and upgrade resistance
--   4. mood, call length and repetition penalties
--   5. quirk overrides (tech-savvy NPCs punish jargon, etc.)
--   6. pick a reaction category and a voice line for it

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Difficulty = require(Shared.Difficulty)
local Personalities = require(Shared.Personalities)

local NPCPersonalitySystem = {}

local function tagMultiplier(map, tags): number
	local mult = 1
	if not map then
		return mult
	end
	for _, tag in ipairs(tags) do
		if map[tag] then
			mult *= map[tag]
		end
	end
	return mult
end

local function hasTag(tags, wanted): boolean
	return Util.contains(tags, wanted)
end

-- Reaction categories map onto personality.voice keys.
local function chooseReaction(npc, personality, deltas, choice, random: Random): string
	local tags = choice.tags or {}

	-- Quirk: technically-minded callers call out jargon immediately.
	if personality.quirks and personality.quirks.exposesTechnical and hasTag(tags, "technical") then
		return "laugh"
	end
	if hasTag(tags, "aggressive") then
		return "angry"
	end
	if npc.suspicion >= 85 then
		return "accuse"
	end
	if npc.suspicion >= 60 then
		return random:NextNumber() < 0.5 and "nervous" or "question"
	end
	if personality.quirks and personality.quirks.pretendsToCooperate and npc.suspicion >= 30 then
		return "pretend"
	end
	if personality.quirks and personality.quirks.wastesTime and random:NextNumber() < 0.3 then
		return "waste"
	end
	if hasTag(tags, "absurd") or hasTag(tags, "humour") then
		if random:NextNumber() < 0.55 then
			return "laugh"
		end
	end
	if deltas.trust >= 10 then
		return "believe"
	end
	if deltas.trust <= 0 then
		return "question"
	end
	if npc.patience <= 25 then
		return "waste"
	end
	return random:NextNumber() < 0.5 and "believe" or "question"
end

local function voiceLine(personality, category: string, random: Random): string
	local lines = personality.voice and personality.voice[category]
	if not lines or #lines == 0 then
		lines = personality.voice and personality.voice.question
	end
	if not lines or #lines == 0 then
		return "..."
	end
	return Util.pick(lines, random)
end

-- callState fields used: elapsed, tagHistory, difficultyKey, bonuses, mistakes
function NPCPersonalitySystem.resolve(npc, choice, callState)
	local personality = Personalities.get(npc.personalityId)
	local level = Difficulty.get(callState.difficultyKey)
	local random = Util.newRandom()
	local tags = choice.tags or {}
	local bonuses = callState.bonuses or {}

	local trustDelta = choice.trust or 0
	local suspicionDelta = choice.suspicion or 0
	local patienceDelta = choice.patience or 0

	-- 2. personality affinity
	local likeMul = tagMultiplier(personality.likes, tags)
	local dislikeMul = tagMultiplier(personality.dislikes, tags)

	if trustDelta > 0 then
		trustDelta *= likeMul
		-- Disliked tags blunt good lines as well as adding suspicion.
		trustDelta /= math.max(1, dislikeMul * 0.6)
	else
		trustDelta *= dislikeMul
	end

	if suspicionDelta > 0 then
		suspicionDelta *= dislikeMul
		suspicionDelta /= math.max(1, likeMul * 0.5)
	else
		suspicionDelta *= likeMul
	end

	-- 3. difficulty + personality modifiers + upgrades
	trustDelta *= (personality.mods.trustMul or 1) * level.trustMul
	local suspicionMultiplier = ((personality.mods.suspicionMul or 1) * level.suspicionMul)
		^ Config.Call.SuspicionMultiplierSoftening
	suspicionDelta *= suspicionMultiplier
	if suspicionDelta > 0 then
		suspicionDelta *= (bonuses.suspicionResist or 1)
	end

	-- 4a. repetition: leaning on the same tag over and over stops working
	local repeats = 0
	for _, tag in ipairs(tags) do
		repeats = math.max(repeats, callState.tagHistory[tag] or 0)
	end
	if repeats >= 2 then
		local fatigue = math.min(0.6, (repeats - 1) * 0.15)
		if trustDelta > 0 then
			trustDelta *= (1 - fatigue)
		end
		suspicionDelta += level.repeatPenalty * (repeats - 1)
	end

	-- 4b. long calls make everyone twitchier
	local minutes = (callState.elapsed or 0) / 60
	if minutes > 3 then
		suspicionDelta += (minutes - 3) * 0.8
	end

	-- 4c. patience always drains a little per exchange
	patienceDelta -= 2 * (personality.mods.patienceDrain or 1)

	-- 5. quirks
	local exposed = false
	if personality.quirks then
		if personality.quirks.exposesTechnical and hasTag(tags, "technical") then
			suspicionDelta += 14
			trustDelta = math.min(trustDelta, 0)
		end
		if personality.quirks.knowsTheScript and (hasTag(tags, "urgency") or hasTag(tags, "authority")) then
			suspicionDelta += 8
		end
		-- One decisive "I've clocked you" roll per call, never per exchange, and
		-- only once the call has gone on long enough to be worth it.
		if personality.quirks.instantExposeChance
			and not callState.exposeRolled
			and callState.stage >= 3
			and random:NextNumber() < personality.quirks.instantExposeChance
		then
			callState.exposeRolled = true
			suspicionDelta += 35
			exposed = true
		end
		if personality.quirks.mirrorsPlayer then
			-- The rival call centre copies whatever you do back at you.
			trustDelta *= 0.5
			suspicionDelta *= 0.8
		end
	end

	-- Aggression is always punished, on top of everything above.
	local aggressive = hasTag(tags, "aggressive")
	if aggressive then
		suspicionDelta += 6
		patienceDelta -= 6
	end

	-- Global scaling. Without this a 14-exchange call always tops out at 100
	-- suspicion no matter how well it is played.
	trustDelta *= Config.Call.TrustScale
	if suspicionDelta > 0 then
		suspicionDelta *= Config.Call.SuspicionScale
	end

	-- A line that really lands buys back a little goodwill. Two routes into this,
	-- because a hostile personality's low trust multiplier would otherwise make
	-- the first route unreachable and leave the call mathematically unwinnable:
	--   1. the line landed hard in absolute terms
	--   2. the line hit tags this particular caller likes
	if trustDelta >= Config.Call.ReassureTrust then
		suspicionDelta -= Config.Call.ReassureAmount
	end
	if (choice.trust or 0) > 0 and likeMul > 1.2 then
		suspicionDelta -= Config.Call.ReassureAmount * math.min(2, likeMul - 1)
	end

	trustDelta = Util.round(trustDelta, 1)
	suspicionDelta = Util.round(suspicionDelta, 1)
	patienceDelta = Util.round(patienceDelta, 1)

	local deltas = { trust = trustDelta, suspicion = suspicionDelta, patience = patienceDelta }

	-- 6. reaction line
	local category = chooseReaction(npc, personality, deltas, choice, random)
	if exposed then
		category = "accuse"
	end
	local line = voiceLine(personality, category, random)

	return {
		deltas = deltas,
		category = category,
		line = line,
		exposed = exposed,
		aggressive = aggressive,
		mistake = suspicionDelta > 12 or trustDelta < 0,
	}
end

-- Line used when the NPC finally walks away.
function NPCPersonalitySystem.exitLine(npc, outcome: string): string
	local personality = Personalities.get(npc.personalityId)
	local random = Util.newRandom()
	if outcome == "success" then
		return voiceLine(personality, "believe", random)
	elseif outcome == "exposed" then
		return voiceLine(personality, "accuse", random)
	elseif outcome == "bored" then
		return voiceLine(personality, "waste", random)
	end
	return voiceLine(personality, "hangup", random)
end

function NPCPersonalitySystem.greeting(npc): string
	local personality = Personalities.get(npc.personalityId)
	return voiceLine(personality, "greet", Util.newRandom())
end

-- True when this personality can never be convinced (baiters, police, rivals).
function NPCPersonalitySystem.canSucceed(npc): boolean
	local personality = Personalities.get(npc.personalityId)
	return not (personality.quirks and personality.quirks.neverSucceeds)
end

return NPCPersonalitySystem
