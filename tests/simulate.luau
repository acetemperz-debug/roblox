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
	"RandomEvents", "Upgrades", "Ranks", "Achievements", "Difficulty",
}
local SERVER = {
	"PlayerDataManager", "NPCGenerator", "NPCPersonalitySystem", "DialogueManager",
	"RandomEventManager", "RewardManager", "UpgradeManager", "AchievementManager",
	"CallManager",
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
local Upgrades = require(sharedFolder.Upgrades)
local Ranks = require(sharedFolder.Ranks)
local Achievements = require(sharedFolder.Achievements)
local Difficulty = require(sharedFolder.Difficulty)
local NPCNames = require(sharedFolder.NPCNames)

local PlayerDataManager = require(serverFolder.PlayerDataManager)
local CallManager = require(serverFolder.CallManager)

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
require(sharedFolder.Util).setSeed(20260916)

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
