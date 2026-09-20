--!nonstrict
-- DialogueManager
-- Chooses which situation the NPC raises next and shapes the choice list the
-- client is allowed to see.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local DialogueLibrary = require(Shared.DialogueLibrary)

local DialogueManager = {}

local function eligible(situation, npc, callState): boolean
	if situation.minLevel and callState.dialogueLevel < situation.minLevel then
		return false
	end
	if situation.personalities and not Util.contains(situation.personalities, npc.personalityId) then
		return false
	end
	if situation.excludes and Util.contains(situation.excludes, npc.personalityId) then
		return false
	end
	if callState.usedSituations[situation.id] then
		return false
	end
	return true
end

-- Returns a situation table, or nil if the stage is exhausted.
function DialogueManager.nextSituation(stage: number, npc, callState)
	local random = Util.newRandom()
	local candidates = {}
	for _, situation in ipairs(DialogueLibrary.forStage(stage)) do
		if eligible(situation, npc, callState) then
			local weight = situation.weight or 1
			-- Personality-specific situations are strongly favoured when they fit.
			if situation.personalities then
				weight *= 3
			end
			table.insert(candidates, { situation = situation, weight = weight })
		end
	end

	if #candidates == 0 then
		-- Allow repeats rather than stalling the call.
		for _, situation in ipairs(DialogueLibrary.forStage(stage)) do
			if not situation.personalities or Util.contains(situation.personalities, npc.personalityId) then
				table.insert(candidates, { situation = situation, weight = situation.weight or 1 })
			end
		end
	end
	if #candidates == 0 then
		return nil
	end

	local picked = Util.weightedPick(candidates, random)
	return picked and picked.situation or nil
end

-- Build the view the client renders: prompt variant + up to four choices with
-- rank-locked options greyed out rather than hidden.
function DialogueManager.buildView(situation, callState)
	local random = Util.newRandom()
	local prompt = Util.pick(situation.prompt, random)

	local choices = {}
	for index, choice in ipairs(situation.choices) do
		local locked = (choice.minLevel or 1) > callState.dialogueLevel
		table.insert(choices, {
			index = index,
			text = choice.text,
			locked = locked,
			lockReason = locked and ("Unlocks at dialogue level " .. tostring(choice.minLevel)) or nil,
		})
		if #choices >= Config.Call.MaxChoices then
			break
		end
	end

	-- Situations are authored best-line-first, which made "always click the top
	-- one" a winning strategy. The displayed order is shuffled; `index` still
	-- points at the real choice, so nothing downstream cares.
	Util.shuffle(choices, random)

	return {
		situationId = situation.id,
		prompt = prompt,
		choices = choices,
	}
end

function DialogueManager.getChoice(situation, index: number)
	return situation.choices[index]
end

function DialogueManager.situationCount(): number
	return DialogueLibrary.count()
end

return DialogueManager
