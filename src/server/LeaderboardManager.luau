--!nonstrict
-- LeaderboardManager
-- Pushes career totals into OrderedDataStores and renders them onto the two
-- wall boards built by EnvironmentBuilder. Entirely optional: if DataStores are
-- unavailable the boards simply show a friendly message.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local EnvironmentBuilder = require(script.Parent.EnvironmentBuilder)

local LeaderboardManager = {}

local BOARDS = {
	{ name = "LifetimeEarnings", key = Config.DataStore.LeaderboardKey .. "_earnings", stat = "lifetimeEarnings", suffix = " Credits" },
	{ name = "SuccessfulCalls", key = Config.DataStore.LeaderboardKey .. "_calls", stat = "successfulCalls", suffix = " calls" },
}

local stores = {}

local function getStore(key: string)
	if stores[key] ~= nil then
		return stores[key]
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(key)
	end)
	stores[key] = ok and store or false
	if not ok then
		warn("[LeaderboardManager] OrderedDataStore unavailable: " .. tostring(store))
	end
	return stores[key]
end

function LeaderboardManager.publish(player: Player)
	local data = PlayerDataManager.get(player)
	if not data or data.loadFailed then
		return
	end
	for _, board in ipairs(BOARDS) do
		local store = getStore(board.key)
		if store then
			local value = math.floor(data.stats[board.stat] or 0)
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
end

local function nameFor(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return ok and name or ("User " .. tostring(userId))
end

function LeaderboardManager.refresh()
	for _, board in ipairs(BOARDS) do
		local store = getStore(board.key)
		if not store then
			EnvironmentBuilder.setLeaderboard(board.name, "Leaderboards need API access enabled\nin Game Settings > Security.")
		else
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, 10)
			end)
			if ok then
				local lines = {}
				local rank = 0
				local okPage, entries = pcall(function()
					return pages:GetCurrentPage()
				end)
				if okPage then
					for _, entry in ipairs(entries) do
						rank += 1
						table.insert(lines, string.format("%d. %s - %s%s", rank, nameFor(tonumber(entry.key) or 0), Util.formatNumber(entry.value), board.suffix))
					end
				end
				if #lines == 0 then
					table.insert(lines, "Nobody on the board yet.")
				end
				EnvironmentBuilder.setLeaderboard(board.name, table.concat(lines, "\n"))
			end
		end
	end
end

function LeaderboardManager.start()
	task.spawn(function()
		while true do
			LeaderboardManager.refresh()
			task.wait(90)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		LeaderboardManager.publish(player)
	end)
end

return LeaderboardManager
