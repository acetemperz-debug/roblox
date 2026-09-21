--!nonstrict
-- MacrosoftServer (Script)
-- The single server entry point. Requires every manager, wires the remotes and
-- builds the world. Everything else is a ModuleScript.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Ranks = require(Shared.Ranks)
local Difficulty = require(Shared.Difficulty)
local Upgrades = require(Shared.Upgrades)
local DialogueLibrary = require(Shared.DialogueLibrary)
local RandomEvents = require(Shared.RandomEvents)
local Personalities = require(Shared.Personalities)
local Products = require(Shared.Products)
local Operation = require(Shared.Operation)

-- Remotes must exist before any client script requires Net.
Net.init()

local Modules = script.Parent
local PlayerDataManager = require(Modules.PlayerDataManager)
local CallManager = require(Modules.CallManager)
local UpgradeManager = require(Modules.UpgradeManager)
local AchievementManager = require(Modules.AchievementManager)
local EnvironmentBuilder = require(Modules.EnvironmentBuilder)
local LeaderboardManager = require(Modules.LeaderboardManager)
local MonetisationManager = require(Modules.MonetisationManager)
local CosmeticsManager = require(Modules.CosmeticsManager)
local OperationManager = require(Modules.OperationManager)
local HeatManager = require(Modules.HeatManager)
local TerminalAccess = require(Modules.TerminalAccess)
local OfficeManager = require(Modules.OfficeManager)

--------------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------------

local _, shopPrompt, executivePrompt = EnvironmentBuilder.build()

local function openTerminal(player, terminal)
	if CallManager.getState(player) then return end
	if TerminalAccess.open(player, terminal) then
		Net.event("TerminalOpened"):FireClient(player, { kind = terminal.kind, anchor = terminal.anchor,
			isGuest = terminal.owner ~= nil and terminal.owner ~= player.UserId })
	end
end

OfficeManager.start(openTerminal)

-- Retain the showroom upgrade kiosk and the paid Corner Office workstation.
for _, entry in ipairs({
	{ prompt = shopPrompt, kind = "management" },
	{ prompt = executivePrompt, kind = "workstation", canUse = function(player)
		return MonetisationManager.owns(player, "corner_office")
	end },
}) do
	if entry.prompt then
		local terminal = { kind = entry.kind, anchor = entry.prompt.Parent, model = entry.prompt.Parent.Parent, canUse = entry.canUse }
		terminal.canAccess = function(player)
			return OfficeManager.sessionHost(player) == player and OfficeManager.canEnter(player, player.UserId)
		end
		entry.prompt.ActionText = "Use Computer"
		entry.prompt.Triggered:Connect(function(player)
			if TerminalAccess.throttle(player, "prompt", 0.4) then openTerminal(player, terminal) end
		end)
	end
end

local function closeTerminal(player)
	TerminalAccess.close(player)
	CallManager.cancel(player)
	Net.event("TerminalClosed"):FireClient(player)
end

OfficeManager.Travelling.Event:Connect(closeTerminal)
CallManager.setContextValidator(function(actor, owner)
	if OfficeManager.sessionHost(actor) ~= owner or not OfficeManager.canEnter(actor, owner.UserId) then return false end
	local current = TerminalAccess.current(actor)
	return current ~= nil and current.terminal.kind == "workstation" and TerminalAccess.valid(actor)
		and (current.terminal.owner == owner.UserId or (current.terminal.owner == nil and actor == owner))
end)

local function pushOfficeView(player)
	local host = OfficeManager.sessionHost(player)
	local view = host and PlayerDataManager.publicView(host)
	if not view then return end
	Net.event("OfficeDataUpdated"):FireClient(player, {
		hostUserId = host.UserId, hostName = host.DisplayName, credits = view.credits,
		rankIndex = view.rankIndex, rankName = view.rankName, saveDisabled = view.saveDisabled, saveNote = view.saveNote,
	})
	Net.event("OperationUpdated"):FireClient(player, OperationManager.view(host))
end

OfficeManager.SessionChanged.Event:Connect(function(player, view)
	Net.event("OfficeSessionUpdated"):FireClient(player, view)
	pushOfficeView(player)
end)

Net.event("OfficeAction").OnServerEvent:Connect(function(player, action, a, b)
	if not TerminalAccess.throttle(player, "officeAction", 0.3) or typeof(action) ~= "string" then return end
	local ok, message
	if action == "choose" and (a == "solo" or a == "coop") then
		ok, message = OfficeManager.chooseMode(player, a)
	elseif action == "invite" and TerminalAccess.finiteInteger(a, 1, 9007199254740991) then
		ok, message = OfficeManager.invite(player, a)
	elseif action == "respond" and typeof(a) == "string" and #a <= 32 and typeof(b) == "boolean" then
		ok, message = OfficeManager.respondInvite(player, a, b)
	elseif action == "revoke" and TerminalAccess.finiteInteger(a, 1, 9007199254740991) then
		ok, message = OfficeManager.revokeGuest(player, a)
	elseif action == "leave" then
		ok, message = OfficeManager.leaveSession(player)
	else return end
	Net.event("OfficeSessionUpdated"):FireClient(player, OfficeManager.sessionView(player))
	if message then Net.event("Notify"):FireClient(player, { title = "Office Access", body = message, kind = ok and "info" or "warn" }) end
end)

Net.event("CloseTerminal").OnServerEvent:Connect(closeTerminal)
Players.PlayerRemoving:Connect(function(player) TerminalAccess.remove(player) end)

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			if TerminalAccess.current(player) and not TerminalAccess.valid(player) then closeTerminal(player) end
		end
	end
end)

-- The live ticker. Everyone sees everyone else's big moments, which is most of
-- what makes a server feel alive.
local function broadcast(text: string, kind: string?)
	Net.event("Broadcast"):FireAllClients({ text = text, kind = kind })
end

--------------------------------------------------------------------------------
-- Managers
--------------------------------------------------------------------------------

PlayerDataManager.start()
CallManager.beginRuntime()
LeaderboardManager.start()
MonetisationManager.start()
CosmeticsManager.start()
OperationManager.start()

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
	for _, viewer in ipairs(Players:GetPlayers()) do
		if OfficeManager.sessionHost(viewer) == player then pushOfficeView(viewer) end
	end
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
		Net.event("Broadcast"):FireAllClients({
			text = player.DisplayName .. " got promoted to " .. view.rankName,
			kind = "gold",
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

OperationManager.Changed.Event:Connect(function(player, view)
	OfficeManager.update(player, view)
	for _, viewer in ipairs(Players:GetPlayers()) do
		if OfficeManager.sessionHost(viewer) == player then Net.event("OperationUpdated"):FireClient(viewer, view) end
	end
end)

OperationManager.OfflineEarnings.Event:Connect(function(player, amount, seconds)
	Net.event("OfflineEarnings"):FireClient(player, {
		amount = amount,
		seconds = seconds,
		capped = seconds >= (OperationManager.summary(player) or {}).offlineCapSeconds,
	})
end)

HeatManager.Warned.Event:Connect(function(player, warning)
	for _, viewer in ipairs(Players:GetPlayers()) do
		if OfficeManager.sessionHost(viewer) == player then Net.event("HeatWarning"):FireClient(viewer, warning) end
	end
end)

OperationManager.Raided.Event:Connect(function(player, outcome)
	for _, viewer in ipairs(Players:GetPlayers()) do
		if OfficeManager.sessionHost(viewer) == player then
			Net.event("RaidAlert"):FireClient(viewer, outcome)
			Net.event("OperationUpdated"):FireClient(viewer, OperationManager.view(player))
		end
	end
	OfficeManager.update(player, OperationManager.view(player))
	-- Everyone gets to watch the car turn up.
	EnvironmentBuilder.showRaid(player.DisplayName, outcome.escaped and 12 or Operation.Raid.ShutdownSeconds)
	broadcast(
		outcome.escaped and (player.DisplayName .. " just talked their way out of a raid")
			or (player.DisplayName .. "'s floor just got raided"),
		outcome.escaped and "success" or "warn"
	)
	AchievementManager.evaluate(player, nil)
end)

MonetisationManager.Granted.Event:Connect(function(player, product, message)
	Net.event("Notify"):FireClient(player, {
		title = product.name,
		body = message,
		kind = "gold",
	})
end)

MonetisationManager.PassChanged.Event:Connect(function(player, pass)
	Net.event("Notify"):FireClient(player, {
		title = pass.name .. " unlocked",
		body = pass.blurb,
		kind = "gold",
	})
end)

UpgradeManager.Purchased.Event:Connect(function(player, def)
	Net.event("Notify"):FireClient(player, {
		title = "Upgrade Installed",
		body = def.name .. " - " .. def.blurb,
		kind = "success",
	})
end)

CallManager.CallFinished.Event:Connect(function(player, result, reward)
	LeaderboardManager.publish(player)
	-- Career-total achievements that do not depend on the call itself.
	AchievementManager.evaluate(player, nil)

	local data = PlayerDataManager.get(player)
	local streak = data and data.stats.successStreak or 0
	if result.outcome == "success" then
		broadcast(string.format(
			"%s talked %s (%d) into %s Credits",
			player.DisplayName,
			result.npc.firstName,
			result.npc.age,
			tostring(reward)
		), "success")
		if streak >= 3 then
			broadcast(string.format("%s is on a %d call streak", player.DisplayName, streak), "gold")
		end
	elseif result.npc.personalityId == "police_desk" then
		broadcast(player.DisplayName .. " just cold-called a police station", "warn")
	elseif result.outcome == "exposed" and result.stage and result.stage >= 6 then
		broadcast(string.format(
			"%s got rumbled by %s at the last hurdle",
			player.DisplayName,
			result.npc.firstName
		), "warn")
	end
end)

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------

Net.event("StartCall").OnServerEvent:Connect(function(player, difficultyKey)
	if not TerminalAccess.authorize(player, "StartCall") then return end
	if typeof(difficultyKey) ~= "string" then
		return
	end
	local level = Difficulty.Levels[difficultyKey]
	if not level then
		return
	end
	local owner = OfficeManager.sessionHost(player)
	if not owner then return end
	local ok, reason = CallManager.start(player, difficultyKey, owner)
	if not ok then
		Net.event("Notify"):FireClient(player, { title = "Cannot Start Call", body = reason, kind = "warn" })
	end
end)

Net.event("ChooseOption").OnServerEvent:Connect(function(player, index)
	if not TerminalAccess.authorize(player, "ChooseOption") or not TerminalAccess.finiteInteger(index, 1, 4) then
		return
	end
	CallManager.choose(player, math.floor(index))
end)

Net.event("HangUp").OnServerEvent:Connect(function(player)
	CallManager.hangUp(player)
end)

Net.event("PurchaseUpgrade").OnServerEvent:Connect(function(player, upgradeId)
	if not TerminalAccess.authorize(player, "PurchaseUpgrade") then return end
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
	if not TerminalAccess.authorize(player, "SetDifficulty") then return end
	if typeof(key) ~= "string" or not Difficulty.Levels[key] then
		return
	end
	local owner = OfficeManager.sessionHost(player)
	local data = owner and PlayerDataManager.get(owner)
	local level = Difficulty.Levels[key]
	if data and data.rankIndex < level.minRankIndex then
		Net.event("Notify"):FireClient(player, {
			title = "Locked",
			body = level.label .. " unlocks at " .. Ranks.get(level.minRankIndex).name .. ".",
			kind = "warn",
		})
		return
	end
	if owner == player then PlayerDataManager.setDifficulty(player, key) end
end)

Net.event("PromptPurchase").OnServerEvent:Connect(function(player, kind, itemId)
	if not TerminalAccess.authorize(player, "PromptPurchase") then return end
	if typeof(kind) ~= "string" or typeof(itemId) ~= "string" then
		return
	end
	local ok, reason
	if kind == "pass" then
		ok, reason = MonetisationManager.promptPass(player, itemId)
	elseif kind == "product" then
		ok, reason = MonetisationManager.promptProduct(player, itemId)
	else
		return
	end
	if not ok then
		Net.event("Notify"):FireClient(player, { title = "Store", body = reason, kind = "warn" })
	end
end)

Net.event("UseItem").OnServerEvent:Connect(function(player, productId)
	if not TerminalAccess.authorize(player, "UseItem") then return end
	if typeof(productId) ~= "string" then
		return
	end
	local ok, message = CallManager.useItem(player, productId)
	Net.event("Notify"):FireClient(player, {
		title = ok and "Item Used" or "Cannot Use That",
		body = message,
		kind = ok and "success" or "warn",
	})
end)

Net.event("SetAlias").OnServerEvent:Connect(function(player, alias)
	if not TerminalAccess.throttle(player, "alias", 2) then return end
	if typeof(alias) ~= "string" then
		return
	end
	if not MonetisationManager.owns(player, "alias_licence") then
		Net.event("Notify"):FireClient(player, {
			title = "Alias Licence",
			body = "You need the Alias Licence to change your technician name.",
			kind = "warn",
		})
		return
	end

	alias = string.gsub(alias, "^%s+", "")
	alias = string.gsub(alias, "%s+$", "")
	if #alias < 2 or #alias > 16 or string.match(alias, "[^%a%s'%-]") then
		Net.event("Notify"):FireClient(player, {
			title = "Alias Rejected",
			body = "Two to sixteen letters, please.",
			kind = "warn",
		})
		return
	end

	-- Filter it even though only the buyer ever sees it -- it is user text.
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(alias, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		Net.event("Notify"):FireClient(player, {
			title = "Alias Rejected",
			body = "Could not check that name. Try again.",
			kind = "warn",
		})
		return
	end

	PlayerDataManager.setAlias(player, filtered)
	Net.event("Notify"):FireClient(player, {
		title = "Alias Set",
		body = "You are now " .. filtered .. " from Macrosoft Technical.",
		kind = "success",
	})
end)

local OPERATION_ACTIONS = {
	setMethod = function(player, a)
		return OperationManager.setMethod(player, a)
	end,
	buyFacility = function(player, a)
		return OperationManager.buyFacility(player, a)
	end,
	buySecurity = function(player, a)
		return OperationManager.buySecurity(player, a)
	end,
	buyTradecraft = function(player, a)
		return OperationManager.buyTradecraft(player, a)
	end,
	hire = function(player, a, b)
		return OperationManager.hire(player, a, b)
	end,
	fire = function(player, a, b)
		return OperationManager.fire(player, a, b)
	end,
	layLow = function(player)
		return OperationManager.layLow(player)
	end,
	useItem = function(player, a)
		return OperationManager.useItem(player, a)
	end,
}

Net.event("OperationAction").OnServerEvent:Connect(function(player, action, a, b)
	if typeof(action) ~= "string" then
		return
	end
	local handler = OPERATION_ACTIONS[action]
	if not handler then
		return
	end
	if not TerminalAccess.authorize(player, action) then return end
	if a ~= nil and typeof(a) ~= "string" then
		return
	end
	if b ~= nil and not TerminalAccess.finiteInteger(b, 1, 25) then
		return
	end

	local ok, message = handler(player, a, b)
	if message and message ~= "" then
		Net.event("Notify"):FireClient(player, {
			title = ok and "Operation" or "Cannot Do That",
			body = message,
			kind = ok and "success" or "warn",
		})
	end
	if ok then
		AchievementManager.evaluate(player, nil)
	end
end)

Net.event("RequestData").OnServerEvent:Connect(function(player)
	if not TerminalAccess.throttle(player, "data", 1) then return end
	PlayerDataManager.notify(player)
end)

Net.func("GetData").OnServerInvoke = function(player)
	return PlayerDataManager.publicView(player)
end

Net.func("GetOperation").OnServerInvoke = function(player)
	return OperationManager.view(OfficeManager.sessionHost(player) or player)
end

Net.func("GetOfficeSession").OnServerInvoke = function(player)
	if not TerminalAccess.throttle(player, "officeRead", 0.5) then return nil end
	pushOfficeView(player)
	return OfficeManager.sessionView(player)
end

Net.func("GetStore").OnServerInvoke = function(player)
	return MonetisationManager.catalog(player)
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

local configuredProducts = 0
for _, def in ipairs(Products.GamePasses) do
	configuredProducts += Products.isConfigured(def) and 1 or 0
end
for _, def in ipairs(Products.DeveloperProducts) do
	configuredProducts += Products.isConfigured(def) and 1 or 0
end

print(string.format(
	"[Macrosoft] v%s online - %d personalities, %d dialogue situations, %d random events, %d upgrades.",
	Config.Version,
	Personalities.count(),
	DialogueLibrary.count(),
	RandomEvents.count(),
	#Upgrades.List
))
print(string.format(
	"[Macrosoft] Robux store: %d of %d items have an asset id set. Items without one show as unavailable.",
	configuredProducts,
	#Products.GamePasses + #Products.DeveloperProducts
))
