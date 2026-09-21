--!nocheck
-- simulate.luau
-- Headless play-test. Runs whole calls through the real server modules using a
-- stubbed Roblox API, so balance and crashes can be checked outside Studio.
--
-- Run from the repository root:
--   luau tests/simulate.luau

-- The standalone luau CLI sandboxes each required file with its own globals,
-- so tests/bundle.py concatenates everything into one chunk and exposes the
-- loader as _BUNDLE_LOAD. Falling back to require keeps the file readable.
local loadModule = _BUNDLE_LOAD or require
local Stub = loadModule("./RobloxStub")
local services = Stub.install()

--------------------------------------------------------------------------------
-- Rebuild the Roblox instance tree the modules expect, then redirect `require`.
--------------------------------------------------------------------------------

local realRequire = loadModule

local SHARED = {
	"Config", "Util", "Net", "NPCNames", "Personalities", "DialogueLibrary",
	"RandomEvents", "Upgrades", "Ranks", "Achievements", "Difficulty", "Products",
	"Operation",
}
local SERVER = {
	"PlayerDataManager", "NPCGenerator", "NPCPersonalitySystem", "DialogueManager",
	"RandomEventManager", "RewardManager", "UpgradeManager", "AchievementManager",
	"CallManager", "LeaderboardManager", "EnvironmentBuilder", "OperationManager",
	"HeatManager", "TerminalAccess", "LeaderboardRank", "OfficeSessions", "OfficeManager",
}

local sharedFolder = Stub.newInstance("Folder")
sharedFolder.Name = "MacrosoftShared"
sharedFolder.Parent = services.ReplicatedStorage

local serverFolder = Stub.newInstance("Folder")
serverFolder.Name = "MacrosoftServer"

local paths = {}

for _, name in ipairs(SHARED) do
	local marker = { __module = name }
	paths[marker] = "../src/shared/" .. name
	sharedFolder[name] = marker
end
for _, name in ipairs(SERVER) do
	local marker = { __module = name }
	paths[marker] = "../src/server/" .. name
	serverFolder[name] = marker
end

local scriptStub = Stub.newInstance("Script")
scriptStub.Name = "Simulator"
scriptStub.Parent = serverFolder
script = scriptStub

local cache = {}

require = function(target)
	if type(target) == "string" then
		return realRequire(target)
	end
	local path = paths[target]
	if not path then
		error("simulator: unknown module target " .. tostring(target))
	end
	if cache[path] == nil then
		cache[path] = realRequire(path)
	end
	return cache[path]
end

--------------------------------------------------------------------------------

local Config = require(sharedFolder.Config)
local Personalities = require(sharedFolder.Personalities)
local DialogueLibrary = require(sharedFolder.DialogueLibrary)
local RandomEvents = require(sharedFolder.RandomEvents)
local Ranks = require(sharedFolder.Ranks)
local Achievements = require(sharedFolder.Achievements)
local Difficulty = require(sharedFolder.Difficulty)
local NPCNames = require(sharedFolder.NPCNames)
local Products = require(sharedFolder.Products)
local Upgrades = require(sharedFolder.Upgrades)
local Util = require(sharedFolder.Util)
local Operation = require(sharedFolder.Operation)

local PlayerDataManager = require(serverFolder.PlayerDataManager)
local CallManager = require(serverFolder.CallManager)
local NPCGenerator = require(serverFolder.NPCGenerator)
local LeaderboardManager = require(serverFolder.LeaderboardManager)
local OperationManager = require(serverFolder.OperationManager)
local RewardManager = require(serverFolder.RewardManager)
local HeatManager = require(serverFolder.HeatManager)

--------------------------------------------------------------------------------
-- Assertions on content volume (the design brief's minimums).
--------------------------------------------------------------------------------

local failures = 0
local function check(label, condition, detail)
	if condition then
		print(string.format("  ok   %s%s", label, detail and (" (" .. detail .. ")") or ""))
	else
		failures += 1
		print(string.format("  FAIL %s%s", label, detail and (" (" .. detail .. ")") or ""))
	end
end

print("Content checks")
check("20+ personalities", Personalities.count() >= 20, Personalities.count() .. " defined")
check("50+ dialogue situations", DialogueLibrary.count() >= 50, DialogueLibrary.count() .. " defined")
check("100+ first names", #NPCNames.First >= 100, #NPCNames.First .. " names")
check("10+ random events", RandomEvents.count() >= 10, RandomEvents.count() .. " events")
check("12+ upgrades", #Upgrades.List >= 12, #Upgrades.List .. " upgrades")
check("9 ranks", #Ranks.List == 9)
check("15+ achievements", #Achievements.List >= 15, #Achievements.List .. " achievements")
check("5 difficulties", #Difficulty.Order == 5)

-- Every stage 1..7 must have content, or calls would stall.
for stage = 1, Config.StageCount do
	check("stage " .. stage .. " has situations", #DialogueLibrary.forStage(stage) >= 4, #DialogueLibrary.forStage(stage) .. " situations")
end

-- Every personality must expose every voice category used by the resolver.
local categories = { "greet", "question", "believe", "nervous", "angry", "laugh", "hangup", "accuse", "pretend", "waste" }
local voiceOk = true
for _, personality in ipairs(Personalities.List) do
	for _, category in ipairs(categories) do
		local lines = personality.voice and personality.voice[category]
		if not lines or #lines == 0 then
			voiceOk = false
			print("       missing voice." .. category .. " on " .. personality.id)
		end
	end
end
check("all personalities have every voice category", voiceOk)

-- Robux catalogue integrity.
local storeIds = {}
local storeOk = true
for _, def in ipairs(Products.GamePasses) do
	if storeIds[def.id] then
		storeOk = false
		print("       duplicate product id " .. def.id)
	end
	storeIds[def.id] = true
	if def.assetId == nil then
		storeOk = false
		print("       " .. def.id .. " has no assetId field")
	end
end
for _, def in ipairs(Products.DeveloperProducts) do
	if storeIds[def.id] then
		storeOk = false
		print("       duplicate product id " .. def.id)
	end
	storeIds[def.id] = true
	if not def.grant or not def.grant.kind then
		storeOk = false
		print("       " .. def.id .. " has no grant kind")
	end
	if def.usableInCall and not def.use then
		storeOk = false
		print("       " .. def.id .. " is usable in call but grants no effect")
	end
end
check("store catalogue is well formed", storeOk, #Products.GamePasses .. " passes, " .. #Products.DeveloperProducts .. " products")

-- Paid items must never reveal the caller. Anything touching these keys would.
local FORBIDDEN_EFFECTS = { revealPersonality = true, revealTier = true, showTrust = true, showSuspicion = true }
local paidFair = true
for _, def in ipairs(Products.GamePasses) do
	for key in pairs(def.effects or {}) do
		if FORBIDDEN_EFFECTS[key] then
			paidFair = false
			print("       " .. def.id .. " sells information: " .. key)
		end
	end
end
check("no paid item sells information about the caller", paidFair)

-- Every difficulty needs its own global board.
local boardByDifficulty = {}
for _, board in ipairs(LeaderboardManager.Boards) do
	if board.difficulty then
		boardByDifficulty[board.difficulty] = board
	end
end
local boardsOk = true
for _, difficultyKey in ipairs(Difficulty.Order) do
	if not boardByDifficulty[difficultyKey] then
		boardsOk = false
		print("       no leaderboard for " .. difficultyKey)
	end
end
check("every difficulty has a global leaderboard", boardsOk, #LeaderboardManager.Boards .. " boards total")

-- The difficulty boards must read a stat no paid multiplier can inflate.
local sampleStats = { lifetimeEarnings = 999, successfulCalls = 3, successByDifficulty = { Hard = 7 } }
check("difficulty boards count wins, not credits", boardByDifficulty.Hard.value(sampleStats) == 7,
	"Hard board reads " .. tostring(boardByDifficulty.Hard.value(sampleStats)))

-- Upgrade prerequisites must point at real upgrades.
local prereqOk = true
for _, upgrade in ipairs(Upgrades.List) do
	if upgrade.requires and not Upgrades.ById[upgrade.requires] then
		prereqOk = false
		print("       bad prerequisite on " .. upgrade.id)
	end
end
check("upgrade prerequisites resolve", prereqOk)

--------------------------------------------------------------------------------
-- Play simulation
--------------------------------------------------------------------------------

local player = { UserId = 7, Name = "Simulant", DisplayName = "Simulant" }
PlayerDataManager.load(player)

-- Unlock everything so every difficulty can be exercised.
local profile = PlayerDataManager.get(player)
profile.stats.lifetimeEarnings = 1000000
profile.stats.successfulCalls = 400
PlayerDataManager.recalculateRank(player)

-- "best" plays the mechanically strongest line without knowing who is on the
-- other end. "reader" also weighs the caller's personality, which is what a
-- player does once they learn to listen to the dialogue.
local function scoreChoice(choice, personality)
	local trust = choice.trust or 0
	local suspicion = choice.suspicion or 0
	if personality then
		local likeMul, dislikeMul = 1, 1
		for _, tag in ipairs(choice.tags or {}) do
			likeMul *= (personality.likes and personality.likes[tag]) or 1
			dislikeMul *= (personality.dislikes and personality.dislikes[tag]) or 1
		end
		trust = trust > 0 and trust * likeMul or trust * dislikeMul
		suspicion = suspicion > 0 and suspicion * dislikeMul or suspicion * likeMul
	end
	return trust - suspicion * 1.2 + (choice.progress or 0) * 0.05
end

-- strategy: "best" picks the mechanically strongest line, "random" picks blind.
local function runCall(difficultyKey, strategy)
	local ok, reason = CallManager.start(player, difficultyKey)
	if not ok then
		return { outcome = "blocked", reason = reason }
	end

	local steps = 0
	while steps < 80 do
		local state = CallManager.getState(player)
		if not state then
			break
		end
		local source = state.currentSource
		if not source then
			break
		end

		local pickIndex = 1
		if strategy == "best" or strategy == "reader" then
			local personality = strategy == "reader" and Personalities.get(state.npc.personalityId) or nil
			local bestScore = -math.huge
			for index, choice in ipairs(source.choices) do
				local score = scoreChoice(choice, personality)
				if (choice.minLevel or 1) <= state.dialogueLevel and score > bestScore then
					bestScore = score
					pickIndex = index
				end
			end
		else
			local legal = {}
			for index, choice in ipairs(source.choices) do
				if (choice.minLevel or 1) <= state.dialogueLevel then
					table.insert(legal, index)
				end
			end
			pickIndex = legal[math.random(1, #legal)]
		end

		CallManager.choose(player, pickIndex)
		steps += 1
	end

	return { steps = steps }
end

local outcomes = {}
local seenPersonalities = {}
local seenSituations = {}
local rewards = { best = 0, random = 0, reader = 0 }
local counts = { best = 0, random = 0, reader = 0 }

local matrix = {}
local perPersonality = {}

CallManager.CallFinished.Event:Connect(function(_, result, reward)
	local key = result.outcome
	outcomes[key] = (outcomes[key] or 0) + 1
	seenPersonalities[result.npc.personalityId] = true
	rewards[__strategy] = rewards[__strategy] + reward
	counts[__strategy] = counts[__strategy] + 1

	if __strategy == "reader" then
		local row = perPersonality[result.npc.personalityId]
			or { calls = 0, success = 0, suspicion = 0, stage = 0, tier = result.npc.tier }
		row.calls += 1
		row.suspicion += result.suspicion
		row.stage += result.stage
		if result.outcome == "success" then
			row.success += 1
		end
		perPersonality[result.npc.personalityId] = row
	end

	local bucket = __strategy .. "/" .. result.difficultyKey
	matrix[bucket] = matrix[bucket] or { calls = 0, success = 0, trust = 0, suspicion = 0, stage = 0, exposed = 0, bored = 0 }
	local row = matrix[bucket]
	row.calls += 1
	row.trust += result.trust
	row.suspicion += result.suspicion
	row.stage += result.stage
	if result.outcome == "success" then
		row.success += 1
	elseif result.outcome == "exposed" then
		row.exposed += 1
	elseif result.outcome == "bored" then
		row.bored += 1
	end
end)

-- Track which situations appear so unreachable content shows up.
local DialogueManager = require(serverFolder.DialogueManager)
local originalNext = DialogueManager.nextSituation
DialogueManager.nextSituation = function(...)
	local situation = originalNext(...)
	if situation then
		seenSituations[situation.id] = true
	end
	return situation
end

print("")
print("Play simulation")
math.randomseed(20260916)
-- Seed the shared generator too, so a run is reproducible end to end.
Util.setSeed(20260916)

local CALLS_PER_DIFFICULTY = 80
for _, strategy in ipairs({ "reader", "best", "random" }) do
	__strategy = strategy
	for _, difficultyKey in ipairs(Difficulty.Order) do
		for _ = 1, CALLS_PER_DIFFICULTY do
			local result = runCall(difficultyKey, strategy)
			if result.outcome == "blocked" then
				print("  blocked: " .. tostring(result.reason))
			end
		end
	end
end

local total = 0
for _, count in pairs(outcomes) do
	total += count
end

print(string.format("  simulated %d calls", total))
for outcome, count in pairs(outcomes) do
	print(string.format("    %-10s %4d  (%.1f%%)", outcome, count, count / total * 100))
end

print("")
print(string.format("  %-20s %6s %8s %8s %8s %8s %8s", "strategy/difficulty", "calls", "win%", "exposed", "bored", "avgTrust", "avgStage"))
for _, strategy in ipairs({ "reader", "best", "random" }) do
	for _, difficultyKey in ipairs(Difficulty.Order) do
		local row = matrix[strategy .. "/" .. difficultyKey]
		if row then
			print(string.format(
				"  %-20s %6d %7.0f%% %8d %8d %8.1f %8.1f",
				strategy .. "/" .. difficultyKey,
				row.calls,
				row.success / row.calls * 100,
				row.exposed,
				row.bored,
				row.trust / row.calls,
				row.stage / row.calls
			))
		end
	end
end
print("")
print("  Personality-aware play, results per personality")
local rows = {}
for id, row in pairs(perPersonality) do
	table.insert(rows, { id = id, row = row })
end
table.sort(rows, function(a, b)
	return a.row.success / a.row.calls > b.row.success / b.row.calls
end)
for _, entry in ipairs(rows) do
	print(string.format(
		"    %-24s %-10s %4d calls  %5.0f%% win  avg suspicion %5.1f  avg stage %.1f",
		entry.id, entry.row.tier, entry.row.calls,
		entry.row.success / entry.row.calls * 100,
		entry.row.suspicion / entry.row.calls,
		entry.row.stage / entry.row.calls
	))
end
print("")

check("no call crashed", total == CALLS_PER_DIFFICULTY * #Difficulty.Order * 3, total .. " finished")
check("successes happen", (outcomes.success or 0) > 0)
check("failures happen", total - (outcomes.success or 0) > 0)
check(
	"skill beats luck",
	counts.best > 0 and counts.random > 0 and (rewards.best / counts.best) > (rewards.random / counts.random),
	string.format("best %.0f vs random %.0f credits per call", rewards.best / math.max(1, counts.best), rewards.random / math.max(1, counts.random))
)

-- The difficulty curve must actually be a curve.
local function winRate(strategy, difficultyKey)
	local row = matrix[strategy .. "/" .. difficultyKey]
	if not row or row.calls == 0 then
		return 0
	end
	return row.success / row.calls
end

local curveOk = true
local previous = 1.01
for _, difficultyKey in ipairs(Difficulty.Order) do
	local rate = winRate("reader", difficultyKey)
	if rate > previous then
		curveOk = false
		print("       " .. difficultyKey .. " is easier than the difficulty below it")
	end
	previous = rate
end
check("difficulty curve descends", curveOk)
check("Easy is beatable", winRate("reader", "Easy") >= 0.8, string.format("%.0f%%", winRate("reader", "Easy") * 100))
check("Hard is a real challenge", winRate("reader", "Hard") >= 0.4 and winRate("reader", "Hard") <= 0.9,
	string.format("%.0f%%", winRate("reader", "Hard") * 100))
check("Expert is punishing but possible", winRate("reader", "Expert") > 0.05 and winRate("reader", "Expert") < 0.6,
	string.format("%.0f%%", winRate("reader", "Expert") * 100))
check("Nightmare is nearly hopeless but not impossible", winRate("reader", "Nightmare") > 0,
	string.format("%.0f%%", winRate("reader", "Nightmare") * 100))
check("blind play loses on Normal and above", winRate("random", "Normal") < 0.35,
	string.format("%.0f%%", winRate("random", "Normal") * 100))

-- Every personality without the neverSucceeds quirk should be winnable at least
-- occasionally; a 0% archetype is a content bug, not a difficulty setting.
local unwinnable = {}
for id, row in pairs(perPersonality) do
	local personality = Personalities.get(id)
	local neverSucceeds = personality.quirks and personality.quirks.neverSucceeds
	if not neverSucceeds and row.calls >= 8 and row.success == 0 then
		table.insert(unwinnable, id .. " (0/" .. row.calls .. ")")
	end
end
check("every winnable personality wins sometimes", #unwinnable == 0, #unwinnable > 0 and table.concat(unwinnable, ", ") or "none stuck at 0%")

--------------------------------------------------------------------------------
-- Presentation: the answer must not be guessable from position
--------------------------------------------------------------------------------

print("")
print("Choice presentation")

local sampleSituation = DialogueLibrary.ById.intro_why_calling
local firstSeen = {}
local distinctFirst = 0
local sampleRuns = 400
for _ = 1, sampleRuns do
	local view = DialogueManager.buildView(sampleSituation, { dialogueLevel = 5 })
	local top = view.choices[1].index
	if not firstSeen[top] then
		distinctFirst += 1
	end
	firstSeen[top] = (firstSeen[top] or 0) + 1
end
check("every choice can appear first", distinctFirst == #sampleSituation.choices,
	distinctFirst .. " of " .. #sampleSituation.choices .. " ever led")
check("the authored best line is not always on top", (firstSeen[1] or 0) < sampleRuns * 0.45,
	string.format("led %.0f%% of the time", (firstSeen[1] or 0) / sampleRuns * 100))

-- Shuffling must not drop, duplicate or renumber anything.
local integrityOk = true
for _ = 1, 100 do
	local view = DialogueManager.buildView(sampleSituation, { dialogueLevel = 5 })
	if #view.choices ~= #sampleSituation.choices then
		integrityOk = false
	end
	local seenIndex = {}
	for _, choice in ipairs(view.choices) do
		if seenIndex[choice.index] or sampleSituation.choices[choice.index].text ~= choice.text then
			integrityOk = false
		end
		seenIndex[choice.index] = true
	end
end
check("shuffling keeps every choice exactly once, pointing at the right line", integrityOk)

--------------------------------------------------------------------------------
-- Tycoon layer: economy, heat and raids
--------------------------------------------------------------------------------

print("")
print("Operation economy")

local function opState(methodIndex, facilityIndex, staffId, staffCount, kitted)
	local op = Operation.defaultState()
	op.method = Operation.Methods[methodIndex].id
	op.facility = Operation.Facilities[facilityIndex].id
	if staffCount > 0 then
		op.staff[staffId] = staffCount
	end
	if kitted then
		for _, item in ipairs(Operation.Security) do
			op.security[item.id] = true
		end
		for _, item in ipairs(Operation.Tradecraft) do
			if item.requiresMethod <= methodIndex then
				op.tradecraft[item.id] = true
			end
		end
	end
	return op
end

-- Costs and payouts must climb with every tier, or a tier is pointless.
local ladderOk = true
for index = 2, #Operation.Methods do
	local previous, current = Operation.Methods[index - 1], Operation.Methods[index]
	if current.cost <= previous.cost or current.incomeMul <= previous.incomeMul or current.heatPerSecond <= previous.heatPerSecond then
		ladderOk = false
		print("       method ladder breaks at " .. current.id)
	end
end
for index = 2, #Operation.Employees do
	local previous, current = Operation.Employees[index - 1], Operation.Employees[index]
	if current.cost <= previous.cost or current.incomePerSecond <= previous.incomePerSecond then
		ladderOk = false
		print("       employee ladder breaks at " .. current.id)
	end
	if current.heatPerSecond >= previous.heatPerSecond then
		ladderOk = false
		print("       better staff should be quieter: " .. current.id)
	end
end
for index = 2, #Operation.Facilities do
	local previous, current = Operation.Facilities[index - 1], Operation.Facilities[index]
	if current.cost <= previous.cost or current.desks <= previous.desks then
		ladderOk = false
		print("       facility ladder breaks at " .. current.id)
	end
end
check("every ladder climbs", ladderOk)

-- Every employee must earn more than they cost to keep.
local wagesOk = true
for _, employee in ipairs(Operation.Employees) do
	if employee.incomePerSecond <= employee.wagePerSecond then
		wagesOk = false
		print("       " .. employee.id .. " costs more in wages than they bring in")
	end
end
check("no employee is a net loss", wagesOk)

-- A brand new player must not be raided for doing nothing much.
local starter = Operation.summarise(opState(1, 1, "work_experience", 3, false))
check("a starter operation never overheats", starter.heatRate <= 0,
	string.format("%.3f heat/s", starter.heatRate))

-- Every tier above the first must be dangerous bare and survivable kitted.
local curveOk = true
for index = 2, #Operation.Methods do
	local facility = math.min(index, #Operation.Facilities)
	local desks = Operation.Facilities[facility].desks
	local staffId = Operation.Employees[math.min(index, #Operation.Employees)].id

	local bare = Operation.summarise(opState(index, facility, staffId, desks, false))
	local kitted = Operation.summarise(opState(index, facility, staffId, desks, true))

	if bare.heatRate <= 0 then
		curveOk = false
		print("       " .. Operation.Methods[index].name .. " is safe with no security at all")
	end
	if kitted.heatRate >= bare.heatRate then
		curveOk = false
		print("       security does not help on " .. Operation.Methods[index].name)
	end
	if kitted.escapeChance <= bare.escapeChance then
		curveOk = false
		print("       security does not improve the raid odds on " .. Operation.Methods[index].name)
	end
end
check("every tier is dangerous bare and calmer kitted", curveOk)

-- Escape chance must stay inside its bounds at both extremes.
local worst = Operation.summarise(opState(#Operation.Methods, 1, "work_experience", 1, false))
local best = Operation.summarise(opState(1, 1, "work_experience", 1, true))
check("escape chance stays in bounds",
	worst.escapeChance >= Operation.Raid.MinEscapeChance and best.escapeChance <= Operation.Raid.MaxEscapeChance,
	string.format("%.0f%% to %.0f%%", worst.escapeChance * 100, best.escapeChance * 100))

-- Hiring costs must escalate, and severance must never exceed the hire price.
local employee = Operation.EmployeeById.caller
local first, tenth = Operation.hireCost(employee, 0), Operation.hireCost(employee, 10)
check("hiring gets more expensive", tenth > first,
	Util.formatNumber(first) .. " -> " .. Util.formatNumber(tenth))
check("severance never exceeds the hire cost", Operation.severance(employee, 1) < first)

print("")
print("Operation actions")

-- Work on a clean profile so the play simulation above cannot skew this.
local tycoon = { UserId = 8, Name = "Tycoon", DisplayName = "Tycoon" }
PlayerDataManager.load(tycoon)
local tycoonProfile = PlayerDataManager.get(tycoon)
tycoonProfile.credits = 50000
tycoonProfile.stats.lifetimeEarnings = 1000000
tycoonProfile.stats.successfulCalls = 400
PlayerDataManager.recalculateRank(tycoon)

local hired = OperationManager.hire(tycoon, "work_experience", 2)
check("hiring works", hired == true and (tycoonProfile.operation.staff.work_experience or 0) == 2)

-- Desks are a hard cap.
OperationManager.hire(tycoon, "work_experience", 50)
check("hiring stops at the desk cap",
	OperationManager.summary(tycoon).headcount <= OperationManager.summary(tycoon).deskCap,
	OperationManager.summary(tycoon).headcount .. " / " .. OperationManager.summary(tycoon).deskCap .. " desks")

local creditsBefore = tycoonProfile.credits
OperationManager.fire(tycoon, "work_experience", 1)
check("firing refunds severance", tycoonProfile.credits > creditsBefore)

-- Passive income is credited but must never count as lifetime earnings.
local lifetimeBefore = tycoonProfile.stats.lifetimeEarnings
local creditsBeforeTick = tycoonProfile.credits
OperationManager.step(tycoon, 10)
check("passive income pays out", tycoonProfile.credits > creditsBeforeTick,
	string.format("+%s", Util.formatNumber(tycoonProfile.credits - creditsBeforeTick)))
check("passive income is not lifetime earnings", tycoonProfile.stats.lifetimeEarnings == lifetimeBefore)
check("passive income is tracked separately", tycoonProfile.stats.passiveEarned > 0)

-- Method tiers are gated on rank and unlocked in order.
tycoonProfile.credits = 100000000
local skipped = OperationManager.setMethod(tycoon, "franchise")
check("method tiers cannot be skipped", skipped == false)
local stepped = OperationManager.setMethod(tycoon, "warm_lists")
check("the next method tier unlocks", stepped == true and tycoonProfile.operation.method == "warm_lists")
check("an unlocked method is remembered", tycoonProfile.operation.unlockedMethods.warm_lists == true)

-- Tradecraft that needs a higher method must refuse.
local tooEarly = OperationManager.buyTradecraft(tycoon, "compliance_theatre")
check("tradecraft respects its method requirement", tooEarly == false)

-- A more sophisticated operation must pay more per call.
local baseline = Operation.summarise(Operation.defaultState()).incomeMul
local upgraded = Operation.summarise(tycoonProfile.operation).incomeMul
check("a better operation multiplies call pay", upgraded > baseline,
	string.format("x%.2f -> x%.2f", baseline, upgraded))

print("")
print("Police and raids")

-- Laying low halts income and accelerates cooling.
tycoonProfile.operation.heat = 50
local laidLow = OperationManager.layLow(tycoon)
local heatBefore = tycoonProfile.operation.heat
local creditsAtLayLow = tycoonProfile.credits
OperationManager.step(tycoon, 10)
check("laying low cools you down fast", laidLow == true and tycoonProfile.operation.heat < heatBefore - 1,
	string.format("%.1f -> %.1f", heatBefore, tycoonProfile.operation.heat))
check("laying low stops the income", tycoonProfile.credits == creditsAtLayLow)
tycoonProfile.operation.layLowUntil = 0

-- A survived raid costs nothing.
tycoonProfile.operation.heat = 100
local survivedBeforeCredits = tycoonProfile.credits
local escapeOutcome = HeatManager.resolveRaid(tycoon, tycoonProfile.operation, { escapeChance = 1, headcount = 4 }, function()
	return 0
end)
check("a survived raid costs nothing", escapeOutcome.escaped == true and tycoonProfile.credits == survivedBeforeCredits)
check("a survived raid resets the heat", tycoonProfile.operation.heat == Operation.Raid.HeatAfterEscape)
check("survived raids are counted", tycoonProfile.operation.raidsSurvived == 1)

-- A failed raid takes the noisy staff first and shuts the floor.
tycoonProfile.operation.staff = { work_experience = 4, caller = 4 }
tycoonProfile.operation.heat = 100
local fined = 0
local raidOutcome = HeatManager.resolveRaid(tycoon, tycoonProfile.operation, { escapeChance = 0, headcount = 8 }, function(fraction)
	fined = math.floor(tycoonProfile.credits * fraction)
	tycoonProfile.credits -= fined
	return fined
end)
check("a failed raid fines you", raidOutcome.escaped == false and fined > 0, Util.formatNumber(fined) .. " Credits")
check("a failed raid takes the suspicious staff first",
	(tycoonProfile.operation.staff.work_experience or 0) < 4 and (tycoonProfile.operation.staff.caller or 0) == 4,
	string.format("%d interns left, %d callers left", tycoonProfile.operation.staff.work_experience or 0, tycoonProfile.operation.staff.caller or 0))
check("a failed raid shuts the floor", HeatManager.isShutDown(tycoonProfile.operation))
check("a shut floor earns nothing", (function()
	local before = tycoonProfile.credits
	OperationManager.step(tycoon, 5)
	return tycoonProfile.credits == before
end)())
tycoonProfile.operation.shutdownUntil = 0

-- Calling an actual police station is a very bad idea.
local heatBeforeCall = tycoonProfile.operation.heat
HeatManager.add(tycoonProfile.operation, Operation.Heat.PerPoliceCall)
check("ringing a police station spikes the heat", tycoonProfile.operation.heat > heatBeforeCall + 10)

-- Offline earnings are paid but capped.
tycoonProfile.operation.heat = 0
tycoonProfile.operation.shutdownUntil = 0
tycoonProfile.awaySeconds = 100 * 3600
local creditsBeforeOffline = tycoonProfile.credits
local earned, counted = OperationManager.applyOffline(tycoon)
check("offline earnings are capped", counted == Operation.Offline.CapSeconds,
	string.format("%d hours counted from %d away", counted / 3600, 100))
check("offline earnings are paid", earned > 0 and tycoonProfile.credits > creditsBeforeOffline,
	Util.formatNumber(earned) .. " Credits")

PlayerDataManager.setPassOwned(tycoon, "night_shift", true)
tycoonProfile.awaySeconds = 100 * 3600
local _, longerCount = OperationManager.applyOffline(tycoon)
check("the Night Shift pass raises the cap", longerCount == Operation.Offline.PassCapSeconds,
	string.format("%d hours", longerCount / 3600))

--------------------------------------------------------------------------------
-- Premium mechanics
--------------------------------------------------------------------------------

print("")
print("Premium mechanics")

-- Per-difficulty win counts must add up to the wins the simulation observed.
local recorded = 0
for _, count in pairs(profile.stats.successByDifficulty) do
	recorded += count
end
check("per-difficulty wins are recorded", recorded == (outcomes.success or 0),
	recorded .. " recorded vs " .. tostring(outcomes.success) .. " observed")

-- Game pass effects fold into the same bonus table the desk upgrades use.
local plainBonuses = Upgrades.aggregate({})
check("no pass means no multiplier", plainBonuses.rewardMul == 1, "x" .. tostring(plainBonuses.rewardMul))

local withPass = Products.applyBonuses(Upgrades.aggregate({}), { passes = { overtime_contract = true } })
check("Overtime Contract doubles pay", withPass.rewardMul == 2, "x" .. tostring(withPass.rewardMul))

local withBoost = Products.applyBonuses(Upgrades.aggregate({}), {
	passes = {},
	boostExpires = os.time() + 600,
	boostMultiplier = 1,
})
check("Double Shift doubles pay while it lasts", withBoost.rewardMul == 2, "x" .. tostring(withBoost.rewardMul))

local expiredBoost = Products.applyBonuses(Upgrades.aggregate({}), {
	passes = {},
	boostExpires = os.time() - 1,
	boostMultiplier = 1,
})
check("an expired boost does nothing", expiredBoost.rewardMul == 1, "x" .. tostring(expiredBoost.rewardMul))

-- Warm Lead must actually soften the roll.
local hardTiers, warmTiers = {}, {}
for _ = 1, 300 do
	local rolled = NPCGenerator.generate("Nightmare", {}, nil, nil)
	hardTiers[rolled.tier] = (hardTiers[rolled.tier] or 0) + 1
	local warm = NPCGenerator.generate("Nightmare", {}, nil, { warmLead = true })
	warmTiers[warm.tier] = (warmTiers[warm.tier] or 0) + 1
end
check("Warm Lead removes the worst tier", (warmTiers.Nightmare or 0) == 0 and (hardTiers.Nightmare or 0) > 0,
	string.format("nightmare callers: %d normally, %d with a warm lead", hardTiers.Nightmare or 0, warmTiers.Nightmare or 0))

-- Receipts must only ever be granted once.
check("a receipt cannot be claimed twice",
	PlayerDataManager.claimReceipt(player, "receipt-A") == true
		and PlayerDataManager.claimReceipt(player, "receipt-A") == false
		and PlayerDataManager.claimReceipt(player, "receipt-B") == true)

-- Consumables are spent, not duplicated.
PlayerDataManager.addItem(player, "coffee_refill", 1)
check("a consumable is spent exactly once",
	PlayerDataManager.consumeItem(player, "coffee_refill") == true
		and PlayerDataManager.consumeItem(player, "coffee_refill") == false)

-- Using an item outside a call must fail rather than vanish.
PlayerDataManager.addItem(player, "coffee_refill", 1)
local usedOutsideCall = CallManager.useItem(player, "coffee_refill")
check("consumables cannot be used outside a call", usedOutsideCall == false)
check("a failed use does not consume the item",
	(PlayerDataManager.get(player).premium.inventory.coffee_refill or 0) == 1)

-- Using a coffee mid-call restores patience and spends the item.
CallManager.start(player, "Normal")
local liveCall = CallManager.getState(player)
liveCall.npc.patience = 20
local usedInCall = CallManager.useItem(player, "coffee_refill")
check("coffee restores patience mid-call", usedInCall == true and liveCall.npc.patience > 20,
	"patience now " .. tostring(liveCall and math.floor(liveCall.npc.patience)))
check("the coffee was consumed", (PlayerDataManager.get(player).premium.inventory.coffee_refill or 0) == 0)
CallManager.hangUp(player)

-- Streaks: they build on wins, pay more, and reset the moment you lose one.
local streakPlayer = { UserId = 11, Name = "Streaky", DisplayName = "Streaky" }
PlayerDataManager.load(streakPlayer)
local streakProfile = PlayerDataManager.get(streakPlayer)
for _ = 1, 4 do
	PlayerDataManager.recordCall(streakPlayer, { outcome = "success", duration = 30, difficulty = "Normal", difficultyOrder = 2 })
end
check("a streak builds on wins", streakProfile.stats.successStreak == 4, tostring(streakProfile.stats.successStreak))

local streakResult = {
	outcome = "success",
	npc = { tier = "Normal", rewardMul = 1 },
	trust = 70,
	suspicion = 50,
	duration = 300,
	perfect = false,
	difficultyKey = "Normal",
	bonuses = {},
}
local _, streakBreakdown = RewardManager.calculate(streakPlayer, streakResult)
local sawStreakBonus = false
for _, line in ipairs(streakBreakdown) do
	if string.find(line.label, "Streak", 1, true) then
		sawStreakBonus = true
	end
end
check("a streak pays a bonus", sawStreakBonus)

PlayerDataManager.recordCall(streakPlayer, { outcome = "hangup", duration = 30, difficulty = "Normal", difficultyOrder = 2 })
check("one loss resets the streak", streakProfile.stats.successStreak == 0)
check("the best streak is remembered", streakProfile.stats.bestSuccessStreak == 4)

-- The Alias Licence must be gated on ownership, not just on having set a name.
PlayerDataManager.setAlias(player, "Barry")
check("an alias without the pass is ignored", PlayerDataManager.getAlias(player) == nil)
PlayerDataManager.setPassOwned(player, "alias_licence", true)
check("an alias with the pass applies", PlayerDataManager.getAlias(player) == "Barry")

local personalityCoverage = 0
for _ in pairs(seenPersonalities) do
	personalityCoverage += 1
end
check("most personalities appear", personalityCoverage >= Personalities.count() - 3, personalityCoverage .. "/" .. Personalities.count())

local situationCoverage = 0
for _ in pairs(seenSituations) do
	situationCoverage += 1
end
check("most situations appear", situationCoverage >= DialogueLibrary.count() - 6, situationCoverage .. "/" .. DialogueLibrary.count())

print("\nInvite-only office consent policy")
do
	local Sessions = require(serverFolder.OfficeSessions)
	local clock = 100
	local sessions = Sessions.new(function() return clock end)
	local host = { UserId = 8001, Name = "Host", DisplayName = "Host" }
	local guest = { UserId = 8002, Name = "Guest", DisplayName = "Guest" }
	local stranger = { UserId = 8003, Name = "Stranger", DisplayName = "Stranger" }
	for _, actor in ipairs({ host, guest, stranger }) do sessions:add(actor) end
	check("new sessions require an explicit Solo or Co-op choice", sessions:view(host.UserId).needsChoice
		and not sessions:canEnter(host.UserId, host.UserId))
	check("invalid mode cannot bypass the session choice", not sessions:choose(host.UserId, "public"))
	sessions:choose(host.UserId, "solo")
	sessions:choose(guest.UserId, "solo")
	sessions:choose(stranger.UserId, "coop")
	check("Solo grants only personal office access", sessions:canEnter(host.UserId, host.UserId)
		and not sessions:canEnter(guest.UserId, host.UserId))
	check("Co-op selection alone grants no shared access", not sessions:canEnter(stranger.UserId, host.UserId))
	check("unknown offices and players fail closed", not sessions:canEnter(host.UserId, 999999)
		and not sessions:canEnter(999999, host.UserId))
	check("self and offline invitations are denied", not sessions:invite(host.UserId, host.UserId)
		and not sessions:invite(host.UserId, 999999))
	local invited, _, invitation = sessions:invite(host.UserId, guest.UserId)
	check("Solo owner can invite a guest later", invited and invitation ~= nil)
	check("sending an invitation never grants entry", not sessions:canEnter(guest.UserId, host.UserId)
		and sessions:host(guest.UserId) == guest)
	check("only the named invitee sees the invitation", #sessions:view(guest.UserId).invitations == 1
		and #sessions:view(stranger.UserId).invitations == 0)
	check("another player cannot accept a stolen invitation", not sessions:respond(stranger.UserId, invitation.id, true))
	check("acceptance must be an explicit boolean", not sessions:respond(guest.UserId, invitation.id, "true"))
	check("declining keeps the target's own office", sessions:respond(guest.UserId, invitation.id, false)
		and sessions:host(guest.UserId) == guest and not sessions:canEnter(guest.UserId, host.UserId))
	check("declined invitations cannot be replayed", not sessions:respond(guest.UserId, invitation.id, true))
	local _, _, staleInvite = sessions:invite(host.UserId, guest.UserId)
	local _, _, replacement = sessions:invite(host.UserId, guest.UserId)
	check("reinviting invalidates the previous token", not sessions:respond(guest.UserId, staleInvite.id, true))
	check("explicit acceptance authorizes only the invited office", sessions:respond(guest.UserId, replacement.id, true)
		and sessions:canEnter(guest.UserId, host.UserId) and not sessions:canEnter(guest.UserId, stranger.UserId)
		and not sessions:canEnter(guest.UserId, guest.UserId))
	check("co-op host is the original player's identity", sessions:host(guest.UserId) == host
		and sessions:view(guest.UserId).hostUserId == host.UserId and sessions:view(host.UserId).mode == "coop")
	check("accepted invitation cannot be replayed", not sessions:respond(guest.UserId, replacement.id, true))
	check("guests cannot invite, revoke, or change the host's mode", not sessions:invite(guest.UserId, stranger.UserId)
		and not sessions:revoke(guest.UserId, host.UserId) and not sessions:choose(guest.UserId, "solo"))
	check("host cannot silently switch an occupied co-op to Solo", not sessions:choose(host.UserId, "solo"))
	check("host cannot revoke itself", not sessions:revoke(host.UserId, host.UserId))
	check("host revocation immediately denies office entry", sessions:revoke(host.UserId, guest.UserId)
		and not sessions:canEnter(guest.UserId, host.UserId) and sessions:canEnter(guest.UserId, guest.UserId))
	local _, _, cancelled = sessions:invite(host.UserId, guest.UserId)
	check("owner can revoke an unaccepted invitation", sessions:revoke(host.UserId, guest.UserId)
		and not sessions:respond(guest.UserId, cancelled.id, true))
	local _, _, expired = sessions:invite(host.UserId, guest.UserId)
	clock = expired.expires
	check("expired offers fail even before the expiry sweep", not sessions:respond(guest.UserId, expired.id, true)
		and #sessions:view(guest.UserId).invitations == 0)
	sessions:expire()
	check("expiry sweep removes stale offers", not sessions:respond(guest.UserId, expired.id, true))
	local _, _, leaving = sessions:invite(host.UserId, guest.UserId)
	sessions:respond(guest.UserId, leaving.id, true)
	check("a guest can leave without the host losing ownership", sessions:leave(guest.UserId)
		and sessions:host(host.UserId) == host and sessions:host(guest.UserId) == guest)
	local _, _, hostOffer = sessions:invite(stranger.UserId, host.UserId)
	local _, _, nested = sessions:invite(host.UserId, guest.UserId)
	sessions:respond(guest.UserId, nested.id, true)
	check("hosting guests prevents nesting one party inside another", not sessions:respond(host.UserId, hostOffer.id, true)
		and sessions:host(host.UserId) == host and sessions:host(guest.UserId) == host)
	local _, _, guestOffer = sessions:invite(stranger.UserId, guest.UserId)
	check("accepted transfer leaves the previous host's membership", sessions:respond(guest.UserId, guestOffer.id, true)
		and not sessions:canEnter(guest.UserId, host.UserId) and sessions:canEnter(guest.UserId, stranger.UserId))
	sessions:remove(stranger.UserId)
	check("host disconnect returns members to their private offices", sessions:host(guest.UserId) == guest
		and sessions:canEnter(guest.UserId, guest.UserId) and not sessions:canEnter(guest.UserId, stranger.UserId))
	local _, _, reconnectOffer = sessions:invite(host.UserId, guest.UserId)
	sessions:remove(host.UserId)
	local replacementHost = { UserId = host.UserId, Name = host.Name, DisplayName = host.DisplayName }
	sessions:add(replacementHost)
	sessions:choose(replacementHost.UserId, "solo")
	check("host rejoin cannot reactivate an old invitation", not sessions:respond(guest.UserId, reconnectOffer.id, true)
		and not sessions:canEnter(guest.UserId, replacementHost.UserId))
	local _, _, beforeDisconnect = sessions:invite(replacementHost.UserId, guest.UserId)
	sessions:respond(guest.UserId, beforeDisconnect.id, true)
	sessions:remove(guest.UserId)
	local replacementGuest = { UserId = guest.UserId, Name = guest.Name, DisplayName = guest.DisplayName }
	sessions:add(replacementGuest)
	check("guest rejoin resets consent and requires a fresh mode choice", sessions:view(guest.UserId).needsChoice
		and not sessions:canEnter(guest.UserId, replacementHost.UserId))
	sessions:choose(guest.UserId, "solo")
	local _, _, pendingDisconnect = sessions:invite(replacementHost.UserId, guest.UserId)
	sessions:remove(guest.UserId)
	sessions:add(guest)
	sessions:choose(guest.UserId, "solo")
	check("invite is bound to the original connection", not sessions:respond(guest.UserId, pendingDisconnect.id, true))

	local full = Sessions.new(function() return clock end)
	full:add(host)
	full:choose(host.UserId, "coop")
	local offers = {}
	for index = 1, 9 do
		local target = { UserId = 8100 + index, Name = "Party" .. index, DisplayName = "Party" .. index }
		full:add(target)
		full:choose(target.UserId, "solo")
		local _, _, offer = full:invite(host.UserId, target.UserId)
		offers[index] = offer
	end
	for index = 1, 7 do full:respond(offers[index].targetUserId, offers[index].id, true) end
	check("capacity includes the host and is rechecked on acceptance", #full:view(host.UserId).members == 8
		and not full:respond(offers[8].targetUserId, offers[8].id, true)
		and not full:canEnter(offers[8].targetUserId, host.UserId))
	check("full parties cannot issue further invitations", not full:invite(host.UserId, offers[9].targetUserId))
end

print("\nPhysical terminal security")
do
	local access = require(serverFolder.TerminalAccess)
	local actor = { UserId = 9001 }
	local character = Stub.newInstance("Model")
	local root = Stub.newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(0, 0, 0)
	root.Parent = character
	local humanoid = Stub.newInstance("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	actor.Character = character
	local anchor = Stub.newInstance("Part")
	anchor.Position = Vector3.new(0, 0, 5)
	anchor.Parent = workspace
	local terminal = { kind = "workstation", owner = 9001, anchor = anchor }
	check("remote call without a prompt session is denied", not access.authorize(actor, "StartCall"))
	check("nearby owner can open workstation", access.open(actor, terminal))
	check("workstation starts calls", access.authorize(actor, "StartCall"))
	check("rapid replay is denied", not access.authorize(actor, "StartCall"))
	check("workstation cannot hire or purchase", not access.authorize(actor, "hire") and not access.authorize(actor, "PromptPurchase"))
	root.Position = Vector3.new(50, 0, 0)
	check("moving away revokes session", not access.valid(actor))
	check("forged prompt from afar is denied", not access.open(actor, terminal))
	root.Position = Vector3.new(0, 0, 0)
	terminal.owner = 9002
	check("another player's desk is denied", not access.open(actor, terminal))
	terminal.owner = 9001
	workspace.Raycast = function() return {} end
	check("interaction through a wall is denied", not access.open(actor, terminal))
	workspace.Raycast = function() return nil end
	humanoid.Health = 0
	check("dead characters cannot interact", not access.open(actor, terminal))
	humanoid.Health = 100
	access.remove(actor)
	access.open(actor, terminal)
	actor.Character = Stub.newInstance("Model")
	check("respawning invalidates old sessions", not access.valid(actor))
	actor.Character = character
	access.remove(actor)
	terminal.canUse = function() return false end
	check("premium workstation entitlement is checked", not access.open(actor, terminal))
	terminal.canUse = nil
	for _, spec in ipairs({ { "hr", "hire", "StartCall" }, { "management", "PurchaseUpgrade", "buySecurity" },
		{ "security", "layLow", "buyFacility" }, { "premium", "PromptPurchase", "setMethod" } }) do
		access.remove(actor)
		terminal.kind = spec[1]
		access.open(actor, terminal)
		check(spec[1] .. " permits only its own actions", access.authorize(actor, spec[2]) and not access.authorize(actor, spec[3]))
	end
	check("NaN infinity fractions and oversized hires are denied", not access.finiteInteger(0 / 0, 1, 25)
		and not access.finiteInteger(math.huge, 1, 25) and not access.finiteInteger(1.5, 1, 25)
		and not access.finiteInteger(26, 1, 25) and access.finiteInteger(25, 1, 25))
	anchor:Destroy()
	check("destroyed terminals revoke access", not access.valid(actor))
	access.remove(actor)
end

print("\nGlobal personal rank")
do
	local ranker = require(serverFolder.LeaderboardRank)
	local values = {}
	for i = 1, 235 do table.insert(values, { key = tostring(i), value = 1000 - i }) end
	table.insert(values, { key = "tie", value = 765 })
	local store = { GetSortedAsync = function(_, ascending, size, minimum)
		assert(not ascending and size == 100)
		local entries = {}
		for _, entry in ipairs(values) do if entry.value >= minimum then table.insert(entries, entry) end end
		local cursor = 1
		local pages = { IsFinished = #entries <= size }
		function pages:GetCurrentPage()
			local page = {}
			for i = cursor, math.min(cursor + size - 1, #entries) do table.insert(page, entries[i]) end
			return page
		end
		function pages:AdvanceToNextPageAsync()
			cursor += size
			self.IsFinished = cursor + size - 1 >= #entries
		end
		return pages
	end }
	check("rank beyond Top 10 scans every page", ranker.calculate(store, 764) == 237)
	check("tied scores share competition rank", ranker.calculate(store, 765) == 235)
	check("highest score is rank one", ranker.calculate(store, 1001) == 1)
	check("zero score is unranked", ranker.calculate(store, 0) == nil)
	check("API failure never invents a rank", ranker.calculate({ GetSortedAsync = function() error("throttled") end }, 2) == nil)
	check("cancelled lookup never returns partial rank", ranker.calculate(store, 764, function() return false end) == nil)
end

print("\nOffice construction and saved roster")
local promptedTerminals = {}
do
	local environment = require(serverFolder.EnvironmentBuilder)
	local offices = require(serverFolder.OfficeManager)
	local root = environment.build()
	offices.start(function(actor, terminal)
		promptedTerminals[actor] = terminal
		require(serverFolder.TerminalAccess).open(actor, terminal)
	end)
	local owner = Stub.newPlayer(9101, "OfficeTest")
	services.Players:Add(owner)
	PlayerDataManager.load(owner)
	local profile = PlayerDataManager.get(owner)
	profile.credits = 1000000000
	offices.update(owner, OperationManager.view(owner))
	offices.chooseMode(owner, "solo")
	local office = root:FindFirstChild("Office_9101")
	check("starter office has no decorative hired workers", #office.HiredEmployees:GetChildren() == 0)
	local desk = office:FindFirstChild("CALLS + CAMPAIGNS")
	check("personal terminal has server owner identity", desk:GetAttribute("OwnerUserId") == 9101)
	OperationManager.hire(owner, Operation.Employees[1].id, 2)
	offices.update(owner, OperationManager.view(owner))
	check("every hired employee visibly occupies a desk", #office.HiredEmployees:GetChildren() == 2)
	local staff = office.HiredEmployees
	offices.update(owner, OperationManager.view(owner))
	check("income updates do not rebuild staff", office.HiredEmployees == staff)
	OperationManager.fire(owner, Operation.Employees[1].id, 1)
	offices.update(owner, OperationManager.view(owner))
	check("fired staff disappear", #office.HiredEmployees:GetChildren() == 1)
	local previousDepth = office.Premises.Floor.Size.Z
	for index = 2, #Operation.Facilities do
		local facility = Operation.Facilities[index]
		OperationManager.buyFacility(owner, facility.id)
		offices.update(owner, OperationManager.view(owner))
		local desks = 0
		for _, child in ipairs(office.Premises:GetChildren()) do if string.match(child.Name, "^StaffDesk_") then desks += 1 end end
		check("facility " .. index .. " presents its full desk capacity", desks == facility.desks)
	end
	check("headquarters is larger than the starter office", office.Premises.Floor.Size.Z > previousDepth)
	check("expanding keeps active terminal instances stable", office:FindFirstChild("CALLS + CAMPAIGNS") == desk)
	profile.operation.staff = { [Operation.Employees[7].id] = 90 }
	offices.update(owner, OperationManager.view(owner))
	check("full headquarters presents all 90 employees", #office.HiredEmployees:GetChildren() == 90)
	profile.operation.staff = {}
	profile.operation.shutdownUntil = os.time() + 60
	offices.update(owner, OperationManager.view(owner))
	check("raid losses and shutdown update the visible floor", #office.HiredEmployees:GetChildren() == 0 and office.HiredEmployees:GetAttribute("Paused"))
	local other = Stub.newPlayer(9102, "Other")
	services.Players:Add(other)
	PlayerDataManager.load(other)
	offices.update(other, OperationManager.view(other))
	offices.chooseMode(other, "solo")
	check("players have independent offices", root.Office_9102 ~= office and root.Office_9102.Premises.Floor.Size.Z < office.Premises.Floor.Size.Z)
end

print("\nPhysical private offices, co-op and independent saves")
do
	local offices = require(serverFolder.OfficeManager)
	local access = require(serverFolder.TerminalAccess)
	local environment = require(serverFolder.EnvironmentBuilder)
	local root = environment.getRoot()
	local travelConnection = offices.Travelling.Event:Connect(function(actor) CallManager.cancel(actor) end)
	-- Use the same world checks installed by the server bootstrap so accounting
	-- tests cannot accidentally bypass membership or the physical workstation.
	CallManager.setContextValidator(function(actor, owner)
		local current = access.current(actor)
		return offices.sessionHost(actor) == owner and offices.canEnter(actor, owner.UserId)
			and current ~= nil and current.terminal.kind == "workstation" and access.valid(actor)
			and (current.terminal.owner == owner.UserId or (current.terminal.owner == nil and actor == owner))
	end)
	local function addActor(uid, name, mode, savedPreference)
		local actor = Stub.newPlayer(uid, name)
		services.Players:Add(actor)
		PlayerDataManager.load(actor)
		if savedPreference then PlayerDataManager.get(actor).settings.officeMode = savedPreference end
		offices.update(actor, OperationManager.view(actor))
		Stub.spawnCharacter(actor)
		if mode then offices.chooseMode(actor, mode) end
		return actor
	end
	local function position(actor) return actor.Character.HumanoidRootPart.Position end
	local function at(actor, point) return (position(actor) - point).Magnitude < 0.01 end
	local function useComputer(actor, owner, title)
		local desk = root:FindFirstChild("Office_" .. owner.UserId):FindFirstChild(title)
		actor.Character:PivotTo(desk.Screen.CFrame * CFrame.new(0, 0, 3))
		access.remove(actor)
		promptedTerminals[actor] = nil
		desk.Screen:FindFirstChildWhichIsA("ProximityPrompt").Triggered:Fire(actor)
		return promptedTerminals[actor]
	end
	local function invite(owner, target)
		useComputer(owner, owner, "OFFICE MANAGEMENT")
		local ok = offices.invite(owner, target.UserId)
		local view = offices.sessionView(target)
		local offer = view.invitations[#view.invitations]
		assert(ok and offer, "test fixture could not invite target")
		return offer.id
	end
	local function sameValue(a, b)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		for key, value in pairs(a) do if not sameValue(value, b[key]) then return false end end
		for key in pairs(b) do if a[key] == nil then return false end end
		return true
	end

	local host = addActor(9201, "PhysicalHost")
	local guest = addActor(9202, "PhysicalGuest", nil, "solo")
	local stranger = addActor(9203, "PhysicalStranger", nil, "host_coop")
	local lobbyPoint = Vector3.new(0, 4, 44)
	check("new players stay in the public lobby until a mode is chosen", at(host, lobbyPoint)
		and not offices.teleport(host) and offices.sessionView(host).needsChoice
		and PlayerDataManager.getOfficeMode(host) == nil)
	check("Solo chooses an owned private office", offices.chooseMode(host, "solo")
		and offices.canEnter(host, host.UserId) and not at(host, lobbyPoint))
	check("first choice is stored in the existing profile", PlayerDataManager.getOfficeMode(host) == "solo")
	check("returning Solo skips onboarding and enters its private office", not offices.sessionView(guest).needsChoice
		and offices.sessionView(guest).mode == "solo" and offices.sessionView(guest).preference == "solo"
		and not at(guest, lobbyPoint))
	check("returning Host Co-op skips onboarding without restoring guests", not offices.sessionView(stranger).needsChoice
		and offices.sessionView(stranger).mode == "coop" and offices.sessionView(stranger).preference == "host_coop"
		and #offices.sessionView(stranger).members == 1 and not at(stranger, lobbyPoint))
	check("established preferences cannot be remotely changed away from Management",
		not offices.chooseMode(host, "coop") and PlayerDataManager.getOfficeMode(host) == "solo")
	local hostSpawn, guestSpawn, strangerSpawn = position(host), position(guest), position(stranger)
	local returnAnchor = root.OfficeLift.ReturnPromptAnchor
	local returnPrompt = returnAnchor:FindFirstChildWhichIsA("ProximityPrompt")
	check("return lift uses a visible non-colliding elevated prompt anchor", returnAnchor.Parent == root.OfficeLift
		and returnAnchor.Position.Y >= 4 and returnAnchor.CanCollide == false)
	check("return prompt is explicit, instant and not hidden by occlusion or competing prompts",
		returnPrompt.ActionText == "Return to My Office" and returnPrompt.RequiresLineOfSight == false
		and returnPrompt.Exclusivity == Enum.ProximityPromptExclusivity.AlwaysShow and returnPrompt.HoldDuration == 0)
	check("actual lobby arrival is comfortably inside return activation range",
		(returnAnchor.Position - lobbyPoint).Magnitude < returnPrompt.MaxActivationDistance - 4)
	check("lift signage sits above and behind the interaction anchor", root.OfficeLiftSign.Position.Y > returnAnchor.Position.Y + 2
		and root.OfficeLiftSign.Position.Z < returnAnchor.Position.Z)
	offices.visitLobby(host)
	access.remove(host)
	local previousRaycast = workspace.Raycast
	workspace.Raycast = function() return {} end -- another avatar/NPC blocks the ray
	returnPrompt.Triggered:Fire(host)
	workspace.Raycast = previousRaycast
	check("Solo returns from the exact lobby spawn even when another character blocks sight", at(host, hostSpawn))
	offices.visitLobby(host)
	returnPrompt.Triggered:Fire(host)
	check("return lift still throttles immediate replay", at(host, lobbyPoint))
	access.remove(host)
	host.Character:PivotTo(CFrame.new(0, 4, 80))
	returnPrompt.Triggered:Fire(host)
	check("forged return prompt from outside activation distance is denied", at(host, Vector3.new(0, 4, 80)))
	offices.visitLobby(host)
	host.Character:FindFirstChildWhichIsA("Humanoid").Health = 0
	returnPrompt.Triggered:Fire(host)
	check("dead players cannot activate the return lift", at(host, lobbyPoint))
	host.Character:FindFirstChildWhichIsA("Humanoid").Health = 100
	returnPrompt.Triggered:Fire(host)
	check("valid return after rejected requests still works", at(host, hostSpawn))
	check("default player spawns are in separate office slots", (hostSpawn - guestSpawn).Magnitude > 100
		and (guestSpawn - strangerSpawn).Magnitude > 100)
	check("office ownership attributes use account IDs", root.Office_9201:GetAttribute("OwnerUserId") == host.UserId
		and host:GetAttribute("OfficeHostUserId") == host.UserId and host:GetAttribute("OfficeMode") == "solo")
	check("an invite remote without physical management access is rejected", not offices.invite(host, guest.UserId))
	useComputer(host, host, "OFFICE MANAGEMENT")
	check("Management changes and saves the default office mode", offices.chooseMode(host, "coop")
		and PlayerDataManager.getOfficeMode(host) == "host_coop" and offices.sessionView(host).mode == "coop")
	access.remove(host)
	stranger.Character:PivotTo(host.Character.HumanoidRootPart.CFrame)
	services.RunService.Heartbeat:Fire(0.2)
	check("heartbeat ejects an uninvited player from an office", at(stranger, strangerSpawn)
		and not offices.canEnter(stranger, host.UserId))
	stranger.Character:PivotTo(CFrame.new(hostSpawn.X, 500, hostSpawn.Z))
	offices.enforce(stranger)
	check("flying above another plot cannot bypass authorization", at(stranger, strangerSpawn))
	stranger.Character:PivotTo(CFrame.new(math.huge, 4, 44))
	services.RunService.Heartbeat:Fire(0.2)
	check("heartbeat returns infinite character coordinates to the lobby", at(stranger, lobbyPoint))
	stranger.Character:PivotTo(CFrame.new(0 / 0, 4, 44))
	services.RunService.Heartbeat:Fire(0.2)
	check("heartbeat returns NaN character coordinates to the lobby", at(stranger, lobbyPoint))
	check("strangers cannot forge a physical workstation prompt", useComputer(stranger, host, "CALLS + CAMPAIGNS") == nil)
	offices.teleport(stranger)
	local pending = invite(host, guest)
	check("management invitation does not move or authorize the target", at(guest, guestSpawn)
		and not offices.canEnter(guest, host.UserId))
	check("manager invitation cannot be accepted by another player", not offices.respondInvite(stranger, pending, true))
	check("uninvited callers cannot select another account as their reward owner", not CallManager.start(stranger, "Easy", host))
	check("acceptance moves the guest into the host's physical office", offices.respondInvite(guest, pending, true)
		and at(guest, hostSpawn) and offices.sessionHost(guest) == host)
	check("accepted membership alone cannot remotely start a call", not CallManager.start(guest, "Easy", host))
	check("guest attributes identify the active host without changing model ownership", guest:GetAttribute("OfficeHostUserId") == host.UserId
		and guest:GetAttribute("OfficeMode") == "coop" and root.Office_9202:GetAttribute("OwnerUserId") == guest.UserId)
	local guestCallTerminal = useComputer(guest, host, "CALLS + CAMPAIGNS")
	check("invited helpers can physically start calls at the host's computer", guestCallTerminal ~= nil
		and access.authorize(guest, "StartCall"))
	access.remove(guest)
	access.open(guest, guestCallTerminal)
	check("helpers cannot change campaigns or consume premium items", not access.authorize(guest, "setMethod")
		and not access.authorize(guest, "UseItem"))
	for _, spec in ipairs({ { "HR / RECRUITMENT", "hire" }, { "OFFICE MANAGEMENT", "PurchaseUpgrade" },
		{ "SECURITY / POLICE", "buySecurity" }, { "PREMIUM KIOSK", "PromptPurchase" } }) do
		useComputer(guest, host, spec[1])
		check("guests cannot spend through " .. spec[1], not access.authorize(guest, spec[2]))
	end
	useComputer(guest, host, "OFFICE MANAGEMENT")
	check("guests cannot invite or revoke through the host's management computer", not offices.invite(guest, stranger.UserId)
		and not offices.revokeGuest(guest, host.UserId))
	local oldCharacter = guest.Character
	Stub.spawnCharacter(guest)
	check("respawn retains accepted membership and returns to the host", guest.Character ~= oldCharacter
		and at(guest, hostSpawn) and offices.canEnter(guest, host.UserId))
	check("respawning clears previously open terminal sessions", not access.valid(guest))
	guest.Character:PivotTo(root.Office_9201.LobbyLift.CFrame * CFrame.new(0, 4, 0))
	access.remove(guest)
	root.Office_9201.LobbyLift:FindFirstChildWhichIsA("ProximityPrompt").Triggered:Fire(guest)
	check("an accepted guest can use the physical lift to the shared lobby", at(guest, lobbyPoint))
	offices.visitLobby(stranger)
	offices.enforce(stranger)
	check("public leaderboard lobby remains accessible to everyone", at(stranger, lobbyPoint))
	access.remove(guest)
	root.OfficeLift:FindFirstChildWhichIsA("ProximityPrompt", true).Triggered:Fire(guest)
	check("the lobby return lift resolves a guest's current host", at(guest, hostSpawn))

	local hostProfile, guestProfile = PlayerDataManager.get(host), PlayerDataManager.get(guest)
	hostProfile.credits = 40000
	hostProfile.stats.lifetimeEarnings = 1000000
	hostProfile.stats.successfulCalls = 400
	PlayerDataManager.recalculateRank(host)
	guestProfile.credits = 1234
	guestProfile.operation.staff = { work_experience = 1 }
	PlayerDataManager.setPassOwned(guest, "overtime_contract", true)
	PlayerDataManager.addItem(host, "warm_lead", 1)
	PlayerDataManager.addItem(guest, "warm_lead", 1)
	PlayerDataManager.addItem(host, "coffee_refill", 1)
	PlayerDataManager.addItem(guest, "coffee_refill", 1)
	local guestSaveBefore = Util.deepCopy(guestProfile)
	local hostCreditsBefore = hostProfile.credits
	local hostWinsBefore, hostHeatBefore = hostProfile.stats.successfulCalls, hostProfile.operation.heat
	useComputer(guest, host, "CALLS + CAMPAIGNS")
	local sharedStarted = CallManager.start(guest, "Hard", offices.sessionHost(guest))
	local sharedCall = CallManager.getState(guest)
	check("guest call difficulty and bonuses come from the host's progression", sharedStarted and sharedCall ~= nil
		and sharedCall.bonuses.rewardMul == PlayerDataManager.getBonuses(host).rewardMul)
	check("shared calls never auto-consume either player's paid warm lead", hostProfile.premium.inventory.warm_lead == 1
		and guestProfile.premium.inventory.warm_lead == 1)
	check("guest cannot spend either account's consumables on a shared call", not CallManager.useItem(guest, "coffee_refill")
		and hostProfile.premium.inventory.coffee_refill == 1 and guestProfile.premium.inventory.coffee_refill == 1)
	CallManager.finish(sharedCall, "success")
	check("guest calls credit the host's money, progression and heat", hostProfile.credits > hostCreditsBefore
		and hostProfile.stats.successfulCalls == hostWinsBefore + 1 and hostProfile.operation.heat > hostHeatBefore)
	check("co-op help leaves the guest's entire permanent profile unchanged", sameValue(guestProfile, guestSaveBefore)
		and PlayerDataManager.get(host) ~= PlayerDataManager.get(guest))
	CallManager.start(guest, "Easy", host)
	local distantCall = CallManager.getState(guest)
	local beforeWalkingAway = hostProfile.credits
	guest.Character:PivotTo(CFrame.new(hostSpawn.X, hostSpawn.Y, hostSpawn.Z + 70))
	CallManager.finish(distantCall, "success")
	check("moving away invalidates the reward context before final settlement", hostProfile.credits == beforeWalkingAway
		and CallManager.getState(guest) == nil)
	useComputer(guest, host, "CALLS + CAMPAIGNS")
	CallManager.start(guest, "Easy", host)
	local revokedCall = CallManager.getState(guest)
	local beforeRevoke = hostProfile.credits
	useComputer(host, host, "OFFICE MANAGEMENT")
	check("revocation returns a guest to its own office immediately", offices.revokeGuest(host, guest.UserId)
		and at(guest, guestSpawn) and not offices.canEnter(guest, host.UserId))
	check("revocation cancels the live shared call and terminal session", CallManager.getState(guest) == nil
		and not access.valid(guest))
	CallManager.finish(revokedCall, "success")
	check("a cancelled call cannot pay a stale delayed result", hostProfile.credits == beforeRevoke
		and sameValue(guestProfile, guestSaveBefore))
	guest.Character:PivotTo(guestCallTerminal.anchor.CFrame * CFrame.new(0, 0, 3))
	check("old workstation specifications recheck revoked membership", not access.open(guest, guestCallTerminal))
	offices.enforce(guest)
	check("revoked players cannot walk or teleport back into the host plot", at(guest, guestSpawn))

	local disconnectInvite = invite(host, guest)
	offices.respondInvite(guest, disconnectInvite, true)
	useComputer(guest, host, "CALLS + CAMPAIGNS")
	CallManager.start(guest, "Easy", host)
	local removedOrigin = root.Office_9201.Premises.Floor.Position
	services.Players:Remove(host)
	check("host disconnect clears membership, calls and the physical office", root:FindFirstChild("Office_9201") == nil
		and offices.sessionHost(guest) == guest and at(guest, guestSpawn) and CallManager.getState(guest) == nil)
	local newOwner = addActor(9204, "ReplacementPlotOwner", "solo")
	check("freed slots can be reused without inheriting consent", (root.Office_9204.Premises.Floor.Position - removedOrigin).Magnitude < 0.01
		and not offices.canEnter(guest, newOwner.UserId))
	guest.Character:PivotTo(newOwner.Character.HumanoidRootPart.CFrame)
	offices.enforce(guest)
	check("a reused plot still ejects the previous host's guest", at(guest, guestSpawn))
	local newHost = addActor(host.UserId, "HostRejoined")
	check("host rejoin starts a fresh private session", offices.sessionView(newHost).needsChoice
		and not offices.canEnter(guest, newHost.UserId) and at(newHost, lobbyPoint))
	offices.chooseMode(newHost, "coop")
	local rejoinInvite = invite(newHost, guest)
	offices.respondInvite(guest, rejoinInvite, true)
	useComputer(newHost, newHost, "CALLS + CAMPAIGNS")
	assert(CallManager.start(newHost, "Easy", newHost), "test fixture could not start the host's call")
	local hostCallBeforeGuestDisconnect = CallManager.getState(newHost)
	local hostPointBeforeGuestDisconnect = position(newHost)
	services.Players:Remove(guest)
	check("guest disconnect removes it from the host's member list", #offices.sessionView(newHost).members == 1)
	check("guest disconnect preserves the host's position and live call", at(newHost, hostPointBeforeGuestDisconnect)
		and CallManager.getState(newHost) == hostCallBeforeGuestDisconnect and not hostCallBeforeGuestDisconnect.ended)
	local newGuest = addActor(guest.UserId, "GuestRejoined")
	check("guest rejoin neither restores consent nor skips session choice", offices.sessionView(newGuest).needsChoice
		and offices.sessionHost(newGuest) == newGuest and not offices.canEnter(newGuest, newHost.UserId)
		and at(newGuest, lobbyPoint) and not offices.respondInvite(newGuest, rejoinInvite, true))
	check("a disconnected player object cannot regain an office", not offices.canEnter(guest, newHost.UserId))
	offices.chooseMode(newGuest, "solo")
	local freshOffice = root:FindFirstChild("Office_" .. newGuest.UserId)
	offices.remove(guest)
	check("late cleanup of an old Player cannot remove a rejoined session", offices.canEnter(newGuest, newGuest.UserId)
		and root:FindFirstChild("Office_" .. newGuest.UserId) == freshOffice and offices.sessionHost(newGuest) == newGuest)
	CallManager.cancel(newHost)
	travelConnection:Disconnect()
	CallManager.setContextValidator(nil)
end

print("")
if failures == 0 then
	print("All checks passed.")
else
	print(failures .. " check(s) failed.")
	error("simulation failed", 0)
end
