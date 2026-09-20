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
	"HeatManager",
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

print("")
if failures == 0 then
	print("All checks passed.")
else
	print(failures .. " check(s) failed.")
	error("simulation failed", 0)
end
