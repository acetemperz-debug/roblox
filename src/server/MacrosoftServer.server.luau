--!nonstrict
-- MacrosoftServer (Script)
-- The single server entry point. Requires every manager, wires the remotes and
-- builds the world. Everything else is a ModuleScript.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Ranks = require(Shared.Ranks)
local Difficulty = require(Shared.Difficulty)
local Upgrades = require(Shared.Upgrades)
local DialogueLibrary = require(Shared.DialogueLibrary)
local RandomEvents = require(Shared.RandomEvents)
local Personalities = require(Shared.Personalities)

-- Remotes must exist before any client script requires Net.
Net.init()

local Modules = script.Parent
local PlayerDataManager = require(Modules.PlayerDataManager)
local CallManager = require(Modules.CallManager)
local UpgradeManager = require(Modules.UpgradeManager)
local AchievementManager = require(Modules.AchievementManager)
local EnvironmentBuilder = require(Modules.EnvironmentBuilder)
local LeaderboardManager = require(Modules.LeaderboardManager)

--------------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------------

local _, shopPrompt = EnvironmentBuilder.build()

if shopPrompt then
	shopPrompt.Triggered:Connect(function(player)
		Net.event("Notify"):FireClient(player, {
			title = "Upgrade Shop",
			body = "Shop opened.",
			kind = "info",
			openShop = true,
		})
	end)
end

local callCentre = workspace:WaitForChild("CallCentre")
local workstation = callCentre:WaitForChild("Desks"):WaitForChild("PlayerWorkstation")
local workstationPrompt = workstation:FindFirstChildWhichIsA("ProximityPrompt", true)
if workstationPrompt then
	workstationPrompt.Triggered:Connect(function(player)
		local data = PlayerDataManager.get(player)
		local difficulty = data and data.settings.difficulty or "Normal"
		local ok, reason = CallManager.start(player, difficulty)
		if not ok then
			Net.event("Notify"):FireClient(player, { title = "Cannot Start Call", body = reason, kind = "warn" })
		end
	end)
end

--------------------------------------------------------------------------------
-- Managers
--------------------------------------------------------------------------------

PlayerDataManager.start()
CallManager.beginRuntime()
LeaderboardManager.start()

-- leaderstats so Credits and Rank appear on the Roblox player list.
local function setupLeaderstats(player: Player, view)
	local existing = player:FindFirstChild("leaderstats")
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = "leaderstats"
		existing.Parent = player

		local credits = Instance.new("IntValue")
		credits.Name = "Credits"
		credits.Parent = existing

		local rank = Instance.new("StringValue")
		rank.Name = "Rank"
		rank.Parent = existing
	end
	if view then
		existing.Credits.Value = math.floor(view.credits)
		existing.Rank.Value = view.rankName
	end
end

PlayerDataManager.DataChanged.Event:Connect(function(player, view)
	setupLeaderstats(player, view)
	Net.event("DataUpdated"):FireClient(player, view)
end)

Players.PlayerAdded:Connect(function(player)
	setupLeaderstats(player, nil)
end)

--------------------------------------------------------------------------------
-- Rank-up and achievement notifications
--------------------------------------------------------------------------------

local lastRank = {}

PlayerDataManager.DataChanged.Event:Connect(function(player, view)
	local previous = lastRank[player.UserId]
	if previous and view.rankIndex > previous then
		Net.event("RankChanged"):FireClient(player, {
			from = Ranks.get(previous).name,
			to = view.rankName,
			perks = view.rankPerks,
		})
	end
	lastRank[player.UserId] = view.rankIndex
end)

Players.PlayerRemoving:Connect(function(player)
	lastRank[player.UserId] = nil
end)

AchievementManager.Unlocked.Event:Connect(function(player, achievement)
	Net.event("AchievementUnlocked"):FireClient(player, achievement)
end)

UpgradeManager.Purchased.Event:Connect(function(player, def)
	Net.event("Notify"):FireClient(player, {
		title = "Upgrade Installed",
		body = def.name .. " - " .. def.blurb,
		kind = "success",
	})
end)

CallManager.CallFinished.Event:Connect(function(player)
	LeaderboardManager.publish(player)
	-- Career-total achievements that do not depend on the call itself.
	AchievementManager.evaluate(player, nil)
end)

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------

Net.event("StartCall").OnServerEvent:Connect(function(player, difficultyKey)
	if typeof(difficultyKey) ~= "string" then
		return
	end
	local level = Difficulty.Levels[difficultyKey]
	if not level then
		return
	end
	local ok, reason = CallManager.start(player, difficultyKey)
	if not ok then
		Net.event("Notify"):FireClient(player, { title = "Cannot Start Call", body = reason, kind = "warn" })
	end
end)

Net.event("ChooseOption").OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" then
		return
	end
	CallManager.choose(player, math.floor(index))
end)

Net.event("HangUp").OnServerEvent:Connect(function(player)
	CallManager.hangUp(player)
end)

Net.event("PurchaseUpgrade").OnServerEvent:Connect(function(player, upgradeId)
	if typeof(upgradeId) ~= "string" then
		return
	end
	local ok, message = UpgradeManager.purchase(player, upgradeId)
	Net.event("Notify"):FireClient(player, {
		title = ok and "Purchased" or "Purchase Failed",
		body = message,
		kind = ok and "success" or "warn",
	})
	if ok then
		AchievementManager.evaluate(player, nil)
	end
end)

Net.event("SetDifficulty").OnServerEvent:Connect(function(player, key)
	if typeof(key) ~= "string" or not Difficulty.Levels[key] then
		return
	end
	local data = PlayerDataManager.get(player)
	local level = Difficulty.Levels[key]
	if data and data.rankIndex < level.minRankIndex then
		Net.event("Notify"):FireClient(player, {
			title = "Locked",
			body = level.label .. " unlocks at " .. Ranks.get(level.minRankIndex).name .. ".",
			kind = "warn",
		})
		return
	end
	PlayerDataManager.setDifficulty(player, key)
end)

Net.event("RequestData").OnServerEvent:Connect(function(player)
	PlayerDataManager.notify(player)
end)

Net.func("GetData").OnServerInvoke = function(player)
	return PlayerDataManager.publicView(player)
end

Net.func("GetCatalog").OnServerInvoke = function(player)
	local difficulties = {}
	for _, key in ipairs(Difficulty.Order) do
		local level = Difficulty.Levels[key]
		table.insert(difficulties, {
			key = level.key,
			label = level.label,
			blurb = level.blurb,
			minRankIndex = level.minRankIndex,
			minRankName = Ranks.get(level.minRankIndex).name,
			rewardMul = level.rewardMul,
			order = level.order,
		})
	end

	local ranks = {}
	for _, rank in ipairs(Ranks.List) do
		table.insert(ranks, {
			index = rank.index,
			name = rank.name,
			lifetime = rank.lifetime,
			calls = rank.calls,
			perks = rank.perks,
		})
	end

	return {
		upgrades = UpgradeManager.catalog(player),
		achievements = AchievementManager.catalog(player),
		difficulties = difficulties,
		ranks = ranks,
		version = Config.Version,
		content = {
			personalities = Personalities.count(),
			situations = DialogueLibrary.count(),
			events = RandomEvents.count(),
			upgrades = #Upgrades.List,
		},
	}
end

print(string.format(
	"[Macrosoft] v%s online - %d personalities, %d dialogue situations, %d random events, %d upgrades.",
	Config.Version,
	Personalities.count(),
	DialogueLibrary.count(),
	RandomEvents.count(),
	#Upgrades.List
))
