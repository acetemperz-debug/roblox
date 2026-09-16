--!nonstrict
-- RandomEventManager
-- Decides when an interruption fires and hands back an event the player must
-- answer. Events use the same choice shape as normal dialogue.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Difficulty = require(Shared.Difficulty)
local RandomEvents = require(Shared.RandomEvents)

local RandomEventManager = {}

function RandomEventManager.shouldFire(callState): boolean
	if callState.eventCooldown > 0 then
		return false
	end
	local level = Difficulty.get(callState.difficultyKey)
	local chance = Config.Events.BaseChance * level.eventChanceMul * (callState.bonuses.eventResist or 1)
	-- Late in the call, interruptions get more likely.
	chance += math.min(0.1, (callState.elapsed or 0) / 6000)
	return Util.newRandom():NextNumber() < chance
end

function RandomEventManager.pick(npc, callState)
	local random = Util.newRandom()
	local candidates = {}
	for _, event in ipairs(RandomEvents.List) do
		local stageOk = callState.stage >= (event.minStage or 1) and callState.stage <= (event.maxStage or 7)
		local whitelistOk = not event.personalities or Util.contains(event.personalities, npc.personalityId)
		local blacklistOk = not event.excludes or not Util.contains(event.excludes, npc.personalityId)
		local unused = not callState.usedEvents[event.id]
		if stageOk and whitelistOk and blacklistOk and unused then
			local weight = event.weight or 1
			if event.personalities then
				weight *= 4
			end
			table.insert(candidates, { event = event, weight = weight })
		end
	end
	if #candidates == 0 then
		return nil
	end
	local picked = Util.weightedPick(candidates, random)
	return picked and picked.event or nil
end

function RandomEventManager.buildView(event, callState)
	local random = Util.newRandom()
	local choices = {}
	for index, choice in ipairs(event.choices) do
		local locked = (choice.minLevel or 1) > callState.dialogueLevel
		table.insert(choices, {
			index = index,
			text = choice.text,
			locked = locked,
			lockReason = locked and ("Unlocks at dialogue level " .. tostring(choice.minLevel)) or nil,
		})
	end
	return {
		situationId = event.id,
		isEvent = true,
		eventTitle = event.title,
		prompt = Util.pick(event.prompt, random),
		choices = choices,
	}
end

function RandomEventManager.count(): number
	return RandomEvents.count()
end

return RandomEventManager
