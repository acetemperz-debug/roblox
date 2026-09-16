--!nonstrict
-- CallManager
-- The core state machine: one live call per player. Owns the meters, the stage
-- progression, the timer and every end condition.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Difficulty = require(Shared.Difficulty)
local Ranks = require(Shared.Ranks)
local Net = require(Shared.Net)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local NPCGenerator = require(script.Parent.NPCGenerator)
local NPCPersonalitySystem = require(script.Parent.NPCPersonalitySystem)
local DialogueManager = require(script.Parent.DialogueManager)
local RandomEventManager = require(script.Parent.RandomEventManager)
local RewardManager = require(script.Parent.RewardManager)
local AchievementManager = require(script.Parent.AchievementManager)

local CallManager = {}

local calls: { [number]: any } = {}

CallManager.CallFinished = Instance.new("BindableEvent")

--------------------------------------------------------------------------------
-- View builders
--------------------------------------------------------------------------------

local function meterView(mode: string, value: number, maxValue: number)
	if mode == "hidden" then
		return { mode = "hidden", label = "???", ratio = 0 }
	elseif mode == "vague" then
		return { mode = "vague", label = Difficulty.band(value / maxValue * 100), ratio = 0 }
	end
	return { mode = "full", label = string.format("%d", math.floor(value + 0.5)), ratio = value / maxValue }
end

local function buildMeters(state)
	local level = Difficulty.get(state.difficultyKey)
	return {
		trust = meterView(level.trustDisplay, state.npc.trust, Config.Call.MaxTrust),
		suspicion = meterView(level.suspicionDisplay, state.npc.suspicion, Config.Call.MaxSuspicion),
		patience = meterView(level.patienceDisplay, state.npc.patience, Config.Call.MaxPatience),
	}
end

local function npcView(state)
	local npc = state.npc
	local level = Difficulty.get(state.difficultyKey)
	-- On higher difficulties the player gets less up-front information about
	-- who they are talking to and has to read the dialogue instead.
	local revealPersonality = level.order <= 2
	return {
		fullName = npc.fullName,
		initials = npc.initials,
		age = npc.age,
		town = npc.town,
		moodLabel = revealPersonality and npc.moodLabel or "Unknown",
		personalityName = revealPersonality and npc.personalityName or "Unknown caller",
		blurb = revealPersonality and npc.blurb or "You will have to work this one out yourself.",
		backstory = revealPersonality and npc.backstory or (npc.fullName .. ", " .. npc.age .. ", from " .. npc.town .. "."),
		tier = revealPersonality and npc.tier or "?",
		techKnowledge = revealPersonality and npc.techKnowledge or nil,
		portraitColour = npc.portraitColour,
	}
end

local function stageLabel(stage: number): string
	local entry = Config.Stages[math.clamp(stage, 1, #Config.Stages)]
	return entry and entry.label or "Call"
end

local function buildView(state, extra)
	local view = {
		npc = npcView(state),
		difficulty = state.difficultyKey,
		stage = state.stage,
		stageLabel = stageLabel(state.stage),
		stageCount = Config.StageCount,
		stageProgress = math.clamp(state.stageProgress / Config.Call.ProgressPerStage, 0, 1),
		meters = buildMeters(state),
		elapsed = state.elapsed,
		prompt = state.currentView and state.currentView.prompt or "",
		choices = state.currentView and state.currentView.choices or {},
		eventTitle = state.currentView and state.currentView.eventTitle or nil,
		isEvent = state.currentView and state.currentView.isEvent or false,
		line = state.lastLine,
		reaction = state.lastReaction,
		feedback = state.lastFeedback,
	}
	for key, value in pairs(extra or {}) do
		view[key] = value
	end
	return view
end

--------------------------------------------------------------------------------
-- Call lifecycle
--------------------------------------------------------------------------------

local function presentNext(state)
	local player = state.player
	if state.ended then
		return
	end

	-- Random interruption, or a normal situation for this stage.
	local view
	if RandomEventManager.shouldFire(state) then
		local event = RandomEventManager.pick(state.npc, state)
		if event then
			state.usedEvents[event.id] = true
			state.currentSource = event
			state.currentIsEvent = true
			state.lastEventId = event.id
			state.eventCooldown = Config.Events.Cooldown
			if event.onHold then
				state.timesOnHold += 1
			end
			view = RandomEventManager.buildView(event, state)
		end
	end

	if not view then
		local situation = DialogueManager.nextSituation(state.stage, state.npc, state)
		if not situation then
			-- No content left for the stage: push forward rather than stall.
			state.stageProgress = Config.Call.ProgressPerStage
			CallManager.advanceStage(state)
			return
		end
		state.usedSituations[situation.id] = true
		state.currentSource = situation
		state.currentIsEvent = false
		state.eventCooldown = math.max(0, state.eventCooldown - 1)
		view = DialogueManager.buildView(situation, state)
	end

	state.currentView = view
	Net.event("CallUpdated"):FireClient(player, buildView(state))
end

function CallManager.advanceStage(state)
	state.stageProgress = 0
	state.stage += 1
	if state.stage > Config.StageCount then
		CallManager.resolve(state)
		return
	end
	presentNext(state)
end

function CallManager.finish(state, outcome: string, closingLine: string?)
	if state.ended then
		return
	end
	state.ended = true
	local player = state.player
	calls[player.UserId] = nil

	local duration = state.elapsed
	local result = {
		outcome = outcome,
		npc = state.npc,
		trust = state.npc.trust,
		suspicion = state.npc.suspicion,
		patience = state.npc.patience,
		duration = duration,
		perfect = state.perfect,
		difficultyKey = state.difficultyKey,
		bonuses = state.bonuses,
		timesOnHold = state.timesOnHold,
		stage = state.stage,
		aggressiveChoices = state.aggressiveChoices,
		lastEventId = state.lastEventId,
		survivedEvents = state.survivedEvents,
		difficulty = state.difficultyKey,
	}

	local reward, breakdown = RewardManager.award(player, result)
	local unlocked = AchievementManager.evaluate(player, result)

	local achievementViews = {}
	for _, a in ipairs(unlocked) do
		table.insert(achievementViews, { id = a.id, name = a.name, blurb = a.blurb, reward = a.reward })
	end

	local titles = {
		success = "Call Complete",
		exposed = "You Were Rumbled",
		hangup = "They Hung Up",
		bored = "They Lost Interest",
		timeout = "The Line Went Dead",
		abandoned = "You Hung Up",
	}

	Net.event("CallEnded"):FireClient(player, {
		outcome = outcome,
		title = titles[outcome] or "Call Over",
		closingLine = closingLine or NPCPersonalitySystem.exitLine(state.npc, outcome),
		npc = npcView(state),
		revealedPersonality = state.npc.personalityName,
		revealedBlurb = state.npc.blurb,
		trust = math.floor(state.npc.trust),
		suspicion = math.floor(state.npc.suspicion),
		duration = duration,
		stage = math.min(state.stage, Config.StageCount),
		stageLabel = stageLabel(state.stage),
		reward = reward,
		breakdown = breakdown,
		achievements = achievementViews,
		perfect = state.perfect,
	})

	CallManager.CallFinished:Fire(player, result, reward)
	PlayerDataManager.notify(player)
end

function CallManager.resolve(state)
	local npc = state.npc
	local canSucceed = NPCPersonalitySystem.canSucceed(npc)
	local threshold = Config.Call.TrustToSucceed

	if canSucceed and npc.trust >= threshold and npc.suspicion < Config.Call.HangUpSuspicion then
		CallManager.finish(state, "success", NPCPersonalitySystem.exitLine(npc, "success"))
	elseif not canSucceed then
		CallManager.finish(state, "exposed", NPCPersonalitySystem.exitLine(npc, "exposed"))
	else
		CallManager.finish(state, "hangup", NPCPersonalitySystem.exitLine(npc, "hangup"))
	end
end

--------------------------------------------------------------------------------
-- Player actions
--------------------------------------------------------------------------------

function CallManager.start(player: Player, difficultyKey: string): (boolean, string)
	if calls[player.UserId] then
		return false, "You are already on a call."
	end
	local data = PlayerDataManager.get(player)
	if not data then
		return false, "Your profile is still loading."
	end

	local level = Difficulty.get(difficultyKey)
	if data.rankIndex < level.minRankIndex then
		local needed = Ranks.get(level.minRankIndex)
		return false, level.label .. " difficulty unlocks at " .. needed.name .. "."
	end

	local bonuses = PlayerDataManager.getBonuses(player)
	local rank = Ranks.get(data.rankIndex)
	local npc = NPCGenerator.generate(level.key, bonuses)

	local state = {
		player = player,
		npc = npc,
		difficultyKey = level.key,
		bonuses = bonuses,
		dialogueLevel = rank.dialogueLevel,
		stage = 1,
		stageProgress = 0,
		elapsed = 0,
		startClock = os.clock(),
		usedSituations = {},
		usedEvents = {},
		tagHistory = {},
		survivedEvents = {},
		eventCooldown = 1,
		exposeRolled = false,
		perfect = true,
		aggressiveChoices = 0,
		mistakes = 0,
		timesOnHold = 0,
		ended = false,
		lastLine = NPCPersonalitySystem.greeting(npc),
		lastReaction = "greet",
	}
	calls[player.UserId] = state

	PlayerDataManager.setDifficulty(player, level.key)

	Net.event("CallStarted"):FireClient(player, buildView(state, {
		greeting = state.lastLine,
	}))

	presentNext(state)
	return true, ""
end

function CallManager.choose(player: Player, index: number)
	local state = calls[player.UserId]
	if not state or state.ended then
		return
	end
	local source = state.currentSource
	if not source then
		return
	end
	local choice = source.choices[index]
	if not choice then
		return
	end
	if (choice.minLevel or 1) > state.dialogueLevel then
		Net.event("Notify"):FireClient(player, {
			title = "Locked",
			body = "That line unlocks at a higher rank.",
			kind = "warn",
		})
		return
	end

	local outcome = NPCPersonalitySystem.resolve(state.npc, choice, state)

	-- Apply meters.
	local npc = state.npc
	npc.trust = Util.clamp(npc.trust + outcome.deltas.trust, 0, Config.Call.MaxTrust)
	npc.suspicion = Util.clamp(npc.suspicion + outcome.deltas.suspicion, 0, Config.Call.MaxSuspicion)
	npc.patience = Util.clamp(npc.patience + outcome.deltas.patience, 0, Config.Call.MaxPatience)

	-- Bookkeeping used by rewards and achievements.
	for _, tag in ipairs(choice.tags or {}) do
		state.tagHistory[tag] = (state.tagHistory[tag] or 0) + 1
	end
	if outcome.aggressive then
		state.aggressiveChoices += 1
	end
	if outcome.deltas.suspicion > 0 then
		state.perfect = false
	end
	if outcome.mistake then
		state.mistakes += 1
	end
	if state.currentIsEvent then
		state.survivedEvents[source.id] = outcome.deltas.suspicion <= 12
	end

	state.lastLine = outcome.line
	state.lastReaction = outcome.category

	local level = Difficulty.get(state.difficultyKey)
	state.lastFeedback = (level.trustDisplay == "full" or level.suspicionDisplay == "full") and {
		trust = level.trustDisplay == "full" and outcome.deltas.trust or nil,
		suspicion = level.suspicionDisplay == "full" and outcome.deltas.suspicion or nil,
	} or nil

	-- End conditions checked in priority order.
	if npc.suspicion >= Config.Call.HangUpSuspicion then
		Net.event("CallUpdated"):FireClient(player, buildView(state, { choices = {} }))
		task.wait(0.6)
		CallManager.finish(state, "exposed", NPCPersonalitySystem.exitLine(npc, "exposed"))
		return
	end
	if npc.patience <= 0 then
		Net.event("CallUpdated"):FireClient(player, buildView(state, { choices = {} }))
		task.wait(0.6)
		CallManager.finish(state, "bored", NPCPersonalitySystem.exitLine(npc, "bored"))
		return
	end

	-- Progress the stage.
	state.stageProgress += math.max(0, choice.progress or 0)
	if state.stageProgress >= Config.Call.ProgressPerStage then
		Net.event("CallUpdated"):FireClient(player, buildView(state, { choices = {} }))
		task.wait(0.35)
		CallManager.advanceStage(state)
		return
	end

	presentNext(state)
end

function CallManager.hangUp(player: Player)
	local state = calls[player.UserId]
	if not state or state.ended then
		return
	end
	CallManager.finish(state, "abandoned", "Line disconnected.")
end

function CallManager.getState(player: Player)
	return calls[player.UserId]
end

--------------------------------------------------------------------------------
-- Timer / patience drain
--------------------------------------------------------------------------------

function CallManager.beginRuntime()
	task.spawn(function()
		local accumulator = 0
		while true do
			local dt = task.wait(1)
			accumulator += dt
			for userId, state in pairs(calls) do
				if not state.ended then
					state.elapsed = os.clock() - state.startClock

					-- Patience drains with time as well as with choices.
					if accumulator >= Config.Call.PatienceTickSeconds then
						state.npc.patience = math.max(0, state.npc.patience - 1)
					end

					if state.npc.patience <= 0 then
						CallManager.finish(state, "bored", NPCPersonalitySystem.exitLine(state.npc, "bored"))
					elseif state.elapsed >= Config.Call.MaxCallSeconds then
						CallManager.finish(state, "timeout", "The line goes dead.")
					end
				end
			end
			if accumulator >= Config.Call.PatienceTickSeconds then
				accumulator = 0
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local state = calls[player.UserId]
		if state then
			state.ended = true
			calls[player.UserId] = nil
		end
	end)
end

return CallManager
