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
local Products = require(Shared.Products)
local Operation = require(Shared.Operation)

local PlayerDataManager = {}

local store: DataStore? = nil
local profiles: { [number]: any } = {}
local lastSave: { [number]: number } = {}

PlayerDataManager.DataChanged = Instance.new("BindableEvent")

local function defaultProfile()
	return {
		version = 2,
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
			successStreak = 0,
			bestSuccessStreak = 0,
			timesOnHold = 0,
			totalCallSeconds = 0,
			bestSingleReward = 0,
			-- Successful calls per difficulty. These drive the global boards and
			-- are deliberately immune to any paid reward multiplier.
			successByDifficulty = {},
			-- Passive income is tracked separately and never counted as
			-- lifetime earnings, so the tycoon layer cannot buy rank.
			passiveEarned = 0,
		},
		operation = Operation.defaultState(),
		settings = {
			difficulty = "Normal",
			-- Intentionally absent for a first-time player. Once chosen, this is
			-- "solo" or "host_coop"; invitations and guests are never persisted.
		},
		premium = {
			passes = {}, -- [passId] = true
			inventory = {}, -- [productId] = count
			boostExpires = 0,
			boostMultiplier = 0,
			alias = "",
			-- Developer Product receipt ids already granted, newest last. Bounded
			-- so a long-lived profile cannot grow without limit.
			receipts = {},
		},
		createdAt = os.time(),
		lastSeen = os.time(),
	}
end

-- Fill in anything missing after a schema change.
local function reconcile(profile)
	-- Nested-but-dynamic tables reconcile explicitly; the generic pass below
	-- only walks one level deep.
	if typeof(profile.stats) == "table" and typeof(profile.stats.successByDifficulty) ~= "table" then
		profile.stats.successByDifficulty = {}
	end
	if typeof(profile.premium) == "table" then
		profile.premium.passes = profile.premium.passes or {}
		profile.premium.inventory = profile.premium.inventory or {}
		profile.premium.receipts = profile.premium.receipts or {}
	end
	if typeof(profile.settings) ~= "table" then profile.settings = {} end
	if profile.settings.officeMode ~= "solo" and profile.settings.officeMode ~= "host_coop" then
		profile.settings.officeMode = nil
	end
	if typeof(profile.operation) ~= "table" then
		profile.operation = Operation.defaultState()
	else
		local defaults = Operation.defaultState()
		for key, value in pairs(defaults) do
			if profile.operation[key] == nil then
				profile.operation[key] = value
			end
		end
		-- A saved method or facility that no longer exists falls back safely.
		if not Operation.MethodById[profile.operation.method] then
			profile.operation.method = Operation.StartingMethod
		end
		if not Operation.FacilityById[profile.operation.facility] then
			profile.operation.facility = Operation.StartingFacility
		end
		profile.operation.unlockedMethods[Operation.StartingMethod] = true
	end
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
	profile.version = 2
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
				local previousSeen = saved.lastSeen
				profile = reconcile(saved)
				-- Captured before lastSeen is refreshed below, so the tycoon
				-- layer can pay out offline earnings.
				profile.awaySeconds = previousSeen and math.max(0, os.time() - previousSeen) or 0
			end
		else
			-- Could not read. Run in memory only so we never clobber real data.
			profile.loadFailed = true
			warn("[PlayerDataManager] Load failed for " .. player.Name .. "; saving disabled this session.")
		end
	else
		-- No DataStore at all: either API services are off, or the place has
		-- never been published (DataStores need a published place). Running in
		-- memory is fine, but it used to do so silently, which reads exactly
		-- like the game losing your progress.
		profile.saveUnavailable = true
		if not Config.DataStore.StudioFallbackToMemory then
			profile.loadFailed = true
		end
		warn("[PlayerDataManager] No DataStore access -- progress will not save. "
			.. "Publish the place, then turn on Game Settings > Security > "
			.. "Studio Access to API Services.")
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

-- `silent` skips the client update. Passive income uses it: it ticks every
-- second, and firing a remote per player per second to move a number the client
-- is already interpolating is pure waste. OperationManager pushes a real
-- update every few seconds instead.
function PlayerDataManager.addCredits(player: Player, amount: number, countAsEarnings: boolean?, silent: boolean?)
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
	if not silent then
		PlayerDataManager.notify(player)
	end
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
		stats.successStreak += 1
		if stats.successStreak > stats.bestSuccessStreak then
			stats.bestSuccessStreak = stats.successStreak
		end
		if result.difficulty then
			stats.successByDifficulty[result.difficulty] = (stats.successByDifficulty[result.difficulty] or 0) + 1
		end
		if (result.difficultyOrder or 0) > stats.highestDifficultyOrder then
			stats.highestDifficultyOrder = result.difficultyOrder
			stats.highestDifficulty = result.difficulty
		end
	else
		stats.failedCalls += 1
		stats.successStreak = 0
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
	return Products.applyBonuses(Upgrades.aggregate(profile.upgrades), profile.premium)
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
		saveDisabled = profile.loadFailed == true or profile.saveUnavailable == true,
		saveNote = profile.saveUnavailable and "not saving - no API access"
			or (profile.loadFailed and "not saving - load failed" or nil),
		operation = {
			method = profile.operation.method,
			facility = profile.operation.facility,
			heat = profile.operation.heat,
		},
		premium = {
			passes = profile.premium.passes,
			inventory = profile.premium.inventory,
			alias = profile.premium.alias,
			boostRemaining = math.max(0, (profile.premium.boostExpires or 0) - os.time()),
		},
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

function PlayerDataManager.getOfficeMode(player: Player): string?
	local profile = profiles[player.UserId]
	local mode = profile and profile.settings and profile.settings.officeMode
	return (mode == "solo" or mode == "host_coop") and mode or nil
end

function PlayerDataManager.setOfficeMode(player: Player, mode: string): boolean
	if mode ~= "solo" and mode ~= "host_coop" then return false end
	local profile = profiles[player.UserId]
	if not profile then return false end
	profile.settings.officeMode = mode
	PlayerDataManager.notify(player)
	-- Mode changes are rare and affect the next join, so persist promptly in
	-- addition to the normal autosave/final-save lifecycle.
	if not profile.loadFailed and not profile.saveUnavailable then
		task.spawn(PlayerDataManager.save, player, false)
	end
	return true
end

--------------------------------------------------------------------------------
-- Premium state (Robux purchases). MonetisationManager owns the policy; this
-- module only owns the storage.
--------------------------------------------------------------------------------

local MAX_RECEIPTS = 60

function PlayerDataManager.setPassOwned(player: Player, passId: string, owned: boolean)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	if profile.premium.passes[passId] == owned or (not owned and profile.premium.passes[passId] == nil) then
		return
	end
	profile.premium.passes[passId] = owned or nil
	PlayerDataManager.notify(player)
end

function PlayerDataManager.ownsPass(player: Player, passId: string): boolean
	local profile = profiles[player.UserId]
	return profile ~= nil and profile.premium.passes[passId] == true
end

-- Returns false if this receipt was already granted, so ProcessReceipt can be
-- replayed by Roblox without double-granting.
function PlayerDataManager.claimReceipt(player: Player, receiptId: string): boolean
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	for _, seen in ipairs(profile.premium.receipts) do
		if seen == receiptId then
			return false
		end
	end
	table.insert(profile.premium.receipts, receiptId)
	while #profile.premium.receipts > MAX_RECEIPTS do
		table.remove(profile.premium.receipts, 1)
	end
	return true
end

function PlayerDataManager.addItem(player: Player, productId: string, amount: number)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.premium.inventory[productId] = (profile.premium.inventory[productId] or 0) + amount
	PlayerDataManager.notify(player)
end

-- Spends one of an item. Returns false when the player has none.
function PlayerDataManager.consumeItem(player: Player, productId: string): boolean
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	local count = profile.premium.inventory[productId] or 0
	if count <= 0 then
		return false
	end
	count -= 1
	profile.premium.inventory[productId] = count > 0 and count or nil
	PlayerDataManager.notify(player)
	return true
end

function PlayerDataManager.addBoost(player: Player, seconds: number, multiplier: number)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	local now = os.time()
	local base = math.max(profile.premium.boostExpires or 0, now)
	profile.premium.boostExpires = base + seconds
	profile.premium.boostMultiplier = multiplier
	PlayerDataManager.notify(player)
end

function PlayerDataManager.setAlias(player: Player, alias: string)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.premium.alias = alias
	PlayerDataManager.notify(player)
end

function PlayerDataManager.getAlias(player: Player): string?
	local profile = profiles[player.UserId]
	if not profile or profile.premium.alias == "" then
		return nil
	end
	if not profile.premium.passes.alias_licence then
		return nil
	end
	return profile.premium.alias
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
