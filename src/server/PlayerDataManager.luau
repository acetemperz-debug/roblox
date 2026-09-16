--!nonstrict
-- PlayerDataManager
-- Owns every player's saved profile. Nothing else touches DataStoreService.
--
-- Safety rules used here:
--   * every DataStore call is wrapped in pcall with bounded retries
--   * a failed load never overwrites: the profile is flagged `loadFailed` and
--     saving is disabled for that session so we cannot wipe real progress
--   * autosave on a timer, save on leave, and a BindToClose flush

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Ranks = require(Shared.Ranks)
local Upgrades = require(Shared.Upgrades)

local PlayerDataManager = {}

local store: DataStore? = nil
local profiles: { [number]: any } = {}
local lastSave: { [number]: number } = {}

PlayerDataManager.DataChanged = Instance.new("BindableEvent")

local function defaultProfile()
	return {
		version = 1,
		credits = 0,
		rankIndex = 1,
		upgrades = {},
		achievements = {},
		stats = {
			successfulCalls = 0,
			failedCalls = 0,
			totalCalls = 0,
			lifetimeEarnings = 0,
			highestDifficulty = "",
			highestDifficultyOrder = 0,
			failStreak = 0,
			bestStreak = 0,
			timesOnHold = 0,
			totalCallSeconds = 0,
			bestSingleReward = 0,
		},
		settings = {
			difficulty = "Normal",
		},
		createdAt = os.time(),
		lastSeen = os.time(),
	}
end

-- Fill in anything missing after a schema change.
local function reconcile(profile)
	local base = defaultProfile()
	for key, value in pairs(base) do
		if profile[key] == nil then
			profile[key] = value
		elseif typeof(value) == "table" and typeof(profile[key]) == "table" then
			for subKey, subValue in pairs(value) do
				if profile[key][subKey] == nil then
					profile[key][subKey] = subValue
				end
			end
		end
	end
	return profile
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStore.Key)
	end)
	if ok then
		store = result
		return store
	end
	warn("[PlayerDataManager] DataStore unavailable: " .. tostring(result))
	return nil
end

-- Retry wrapper with exponential backoff.
local function retry(label: string, fn)
	local delayTime = Config.DataStore.RetryBaseDelay
	for attempt = 1, Config.DataStore.MaxRetries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[PlayerDataManager] %s attempt %d failed: %s", label, attempt, tostring(result)))
		if attempt < Config.DataStore.MaxRetries then
			task.wait(delayTime)
			delayTime *= 2
		end
	end
	return false, nil
end

local function keyFor(player: Player): string
	return "player_" .. tostring(player.UserId)
end

function PlayerDataManager.load(player: Player)
	local profile = defaultProfile()
	local ds = getStore()

	if ds then
		local ok, saved = retry("load", function()
			return ds:GetAsync(keyFor(player))
		end)
		if ok then
			if typeof(saved) == "table" then
				profile = reconcile(saved)
			end
		else
			-- Could not read. Run in memory only so we never clobber real data.
			profile.loadFailed = true
			warn("[PlayerDataManager] Load failed for " .. player.Name .. "; saving disabled this session.")
		end
	elseif not Config.DataStore.StudioFallbackToMemory then
		profile.loadFailed = true
	end

	profile.lastSeen = os.time()
	profiles[player.UserId] = profile
	lastSave[player.UserId] = os.clock()
	PlayerDataManager.recalculateRank(player)
	return profile
end

function PlayerDataManager.get(player: Player)
	return profiles[player.UserId]
end

function PlayerDataManager.save(player: Player, isFinal: boolean?): boolean
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	if profile.loadFailed then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end

	profile.lastSeen = os.time()
	local payload = profile

	local ok = retry(isFinal and "final save" or "save", function()
		ds:UpdateAsync(keyFor(player), function()
			return payload
		end)
		return true
	end)
	if ok then
		lastSave[player.UserId] = os.clock()
	end
	return ok
end

function PlayerDataManager.release(player: Player)
	PlayerDataManager.save(player, true)
	profiles[player.UserId] = nil
	lastSave[player.UserId] = nil
end

--------------------------------------------------------------------------------
-- Mutators. Everything that changes a profile goes through here so the client
-- update fires exactly once per change.
--------------------------------------------------------------------------------

function PlayerDataManager.addCredits(player: Player, amount: number, countAsEarnings: boolean?)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.credits = math.max(0, profile.credits + amount)
	if countAsEarnings and amount > 0 then
		profile.stats.lifetimeEarnings += amount
		if amount > profile.stats.bestSingleReward then
			profile.stats.bestSingleReward = amount
		end
	end
	PlayerDataManager.recalculateRank(player)
	PlayerDataManager.notify(player)
end

function PlayerDataManager.spendCredits(player: Player, amount: number): boolean
	local profile = profiles[player.UserId]
	if not profile or profile.credits < amount then
		return false
	end
	profile.credits -= amount
	PlayerDataManager.notify(player)
	return true
end

function PlayerDataManager.grantUpgrade(player: Player, upgradeId: string)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.upgrades[upgradeId] = true
	PlayerDataManager.notify(player)
end

function PlayerDataManager.grantAchievement(player: Player, achievementId: string): boolean
	local profile = profiles[player.UserId]
	if not profile or profile.achievements[achievementId] then
		return false
	end
	profile.achievements[achievementId] = true
	PlayerDataManager.notify(player)
	return true
end

function PlayerDataManager.recordCall(player: Player, result)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	local stats = profile.stats
	stats.totalCalls += 1
	stats.totalCallSeconds += math.floor(result.duration or 0)

	if result.outcome == "success" then
		stats.successfulCalls += 1
		stats.failStreak = 0
		if (result.difficultyOrder or 0) > stats.highestDifficultyOrder then
			stats.highestDifficultyOrder = result.difficultyOrder
			stats.highestDifficulty = result.difficulty
		end
	else
		stats.failedCalls += 1
		stats.failStreak += 1
		if stats.failStreak > stats.bestStreak then
			stats.bestStreak = stats.failStreak
		end
	end

	if result.timesOnHold then
		stats.timesOnHold += result.timesOnHold
	end

	PlayerDataManager.recalculateRank(player)
	PlayerDataManager.notify(player)
end

-- Returns the new rank index, and the old one if it changed.
function PlayerDataManager.recalculateRank(player: Player): (number, number?)
	local profile = profiles[player.UserId]
	if not profile then
		return 1, nil
	end
	local newIndex = Ranks.evaluate(profile.stats.lifetimeEarnings, profile.stats.successfulCalls)
	local old = profile.rankIndex
	if newIndex ~= old then
		profile.rankIndex = newIndex
		return newIndex, old
	end
	return newIndex, nil
end

function PlayerDataManager.getBonuses(player: Player)
	local profile = profiles[player.UserId]
	if not profile then
		return Upgrades.aggregate({})
	end
	return Upgrades.aggregate(profile.upgrades)
end

-- The trimmed profile the client is allowed to see.
function PlayerDataManager.publicView(player: Player)
	local profile = profiles[player.UserId]
	if not profile then
		return nil
	end
	local rank = Ranks.get(profile.rankIndex)
	local nextRank = Ranks.next(profile.rankIndex)
	return {
		credits = profile.credits,
		rankIndex = profile.rankIndex,
		rankName = rank.name,
		rankPerks = rank.perks,
		dialogueLevel = rank.dialogueLevel,
		nextRank = nextRank and {
			name = nextRank.name,
			lifetime = nextRank.lifetime,
			calls = nextRank.calls,
		} or nil,
		upgrades = profile.upgrades,
		achievements = profile.achievements,
		stats = profile.stats,
		settings = profile.settings,
		bonuses = PlayerDataManager.getBonuses(player),
		saveDisabled = profile.loadFailed == true,
	}
end

function PlayerDataManager.notify(player: Player)
	PlayerDataManager.DataChanged:Fire(player, PlayerDataManager.publicView(player))
end

function PlayerDataManager.setDifficulty(player: Player, key: string)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.settings.difficulty = key
	PlayerDataManager.notify(player)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function PlayerDataManager.start()
	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		PlayerDataManager.notify(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if not profiles[player.UserId] then
			task.spawn(function()
				PlayerDataManager.load(player)
				PlayerDataManager.notify(player)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.release(player)
	end)

	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(Config.DataStore.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				if profiles[player.UserId] then
					task.spawn(PlayerDataManager.save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				PlayerDataManager.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return PlayerDataManager
