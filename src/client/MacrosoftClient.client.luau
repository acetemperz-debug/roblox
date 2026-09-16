--!nonstrict
-- MacrosoftClient (LocalScript)
-- Wires the generated interface to the server. Lives in StarterPlayerScripts.


local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local UIKit = require(script.Parent.UIKit)
local Interface = require(script.Parent.Interface)

local T = UIKit.Theme

local ui = Interface.build()

local state = {
	data = nil,
	catalog = nil,
	difficulty = "Normal",
	inCall = false,
	elapsed = 0,
	typing = nil,
	lastView = nil,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function toast(title: string, body: string, kind: string?)
	local colour = T.Accent
	if kind == "success" then
		colour = T.Success
	elseif kind == "warn" then
		colour = T.Danger
	elseif kind == "gold" then
		colour = T.Gold
	end

	local card = UIKit.panel({
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = T.Panel,
		Parent = ui.toasts,
	})
	UIKit.stroke(colour, 2).Parent = card
	UIKit.padding(10).Parent = card

	UIKit.label({
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = colour,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = card,
	})
	UIKit.label({
		Text = body,
		TextSize = 13,
		TextColor3 = T.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 0, 0, 20),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = card,
	})

	card.BackgroundTransparency = 1
	UIKit.tween(card, { BackgroundTransparency = 0 }, 0.2)
	task.delay(4.5, function()
		if card.Parent then
			UIKit.tween(card, { BackgroundTransparency = 1 }, 0.3)
			task.wait(0.32)
			card:Destroy()
		end
	end)
end

-- Reveals text one character at a time; cancelled by the next call.
local function typewrite(label: TextLabel, text: string)
	state.typing = (state.typing or 0) + 1
	local token = state.typing
	label.Text = ""
	task.spawn(function()
		for index = 1, #text do
			if state.typing ~= token then
				return
			end
			label.Text = string.sub(text, 1, index)
			task.wait(Config.UI.TypewriterSpeed)
		end
	end)
end

local function skipTypewriter(label: TextLabel, text: string)
	state.typing = (state.typing or 0) + 1
	label.Text = text
end

--------------------------------------------------------------------------------
-- Home / difficulty
--------------------------------------------------------------------------------

local difficultyButtons = {}

local function refreshDifficultyButtons()
	for key, entry in pairs(difficultyButtons) do
		local unlocked = state.data ~= nil and state.data.rankIndex >= entry.info.minRankIndex
		local selected = state.difficulty == key
		entry.button.Active = unlocked
		entry.button.AutoButtonColor = false
		entry.button.BackgroundColor3 = selected and T.Accent or (unlocked and T.PanelLight or T.Background)
		entry.button.TextColor3 = unlocked and T.Text or T.SubText
		entry.sub.Text = unlocked and string.format("x%.2f pay", entry.info.rewardMul) or ("Locked - " .. entry.info.minRankName)
	end
	local info = difficultyButtons[state.difficulty]
	ui.home.blurb.Text = info and info.info.blurb or ""
end

local function buildDifficultyButtons()
	if not state.catalog then
		return
	end
	for _, child in ipairs(ui.home.difficultyRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(difficultyButtons)

	for _, info in ipairs(state.catalog.difficulties) do
		local button = UIKit.button({
			Text = "",
			Size = UDim2.new(0, 132, 1, 0),
			LayoutOrder = info.order,
			Parent = ui.home.difficultyRow,
		})
		UIKit.label({
			Text = info.label,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 0, 10),
			Size = UDim2.new(1, 0, 0, 20),
			Parent = button,
		})
		local sub = UIKit.label({
			Text = "",
			TextSize = 12,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 0, 18),
			Parent = button,
		})

		difficultyButtons[info.key] = { button = button, sub = sub, info = info }

		button.MouseButton1Click:Connect(function()
			if not button.Active then
				toast("Locked", info.label .. " unlocks at " .. info.minRankName .. ".", "warn")
				return
			end
			state.difficulty = info.key
			Net.event("SetDifficulty"):FireServer(info.key)
			refreshDifficultyButtons()
		end)
	end
	refreshDifficultyButtons()
end

--------------------------------------------------------------------------------
-- Call rendering
--------------------------------------------------------------------------------

local function renderChoices(view)
	for index, button in ipairs(ui.call.choiceButtons) do
		local choice = view.choices and view.choices[index]
		if choice then
			button.Visible = true
			button.Text = string.char(64 + index) .. ".  " .. choice.text
			button.Active = not choice.locked
			button.BackgroundColor3 = choice.locked and T.Background or T.PanelLight
			button.TextColor3 = choice.locked and T.SubText or T.Text
			button:SetAttribute("ChoiceIndex", choice.index)
			button:SetAttribute("Locked", choice.locked == true)
			button:SetAttribute("LockReason", choice.lockReason or "")
		else
			button.Visible = false
		end
	end
end

local function renderCall(view, animate: boolean)
	state.lastView = view

	ui.call.initials.Text = view.npc.initials
	ui.call.portrait.BackgroundColor3 = view.npc.portraitColour or T.Accent
	ui.call.name.Text = view.npc.fullName
	ui.call.sub.Text = string.format("%d - %s - %s", view.npc.age, view.npc.personalityName, view.npc.moodLabel)
	ui.call.backstory.Text = view.npc.backstory

	ui.call.stageLabel.Text = string.format("Stage %d of %d - %s", view.stage, view.stageCount, view.stageLabel)
	UIKit.tween(ui.call.stageFill, {
		Size = UDim2.new(math.clamp((view.stage - 1 + view.stageProgress) / view.stageCount, 0, 1), 0, 1, 0),
	}, 0.3)

	UIKit.setMeter(ui.call.meters.trust, view.meters.trust)
	UIKit.setMeter(ui.call.meters.suspicion, view.meters.suspicion)
	UIKit.setMeter(ui.call.meters.patience, view.meters.patience)

	if view.isEvent then
		ui.call.eventBanner.Visible = true
		ui.call.eventText.Text = "INTERRUPTION: " .. (view.eventTitle or "")
	else
		ui.call.eventBanner.Visible = false
	end

	local line = view.line or ""
	if animate then
		typewrite(ui.call.npcLine, line)
	else
		skipTypewriter(ui.call.npcLine, line)
	end

	ui.call.prompt.Text = view.prompt or ""

	if view.feedback then
		local parts = {}
		if view.feedback.trust then
			table.insert(parts, string.format("Trust %+.0f", view.feedback.trust))
		end
		if view.feedback.suspicion then
			table.insert(parts, string.format("Suspicion %+.0f", view.feedback.suspicion))
		end
		ui.call.feedback.Text = table.concat(parts, "   ")
		ui.call.feedback.TextColor3 = (view.feedback.suspicion or 0) > 0 and T.Suspicion or T.Trust
	else
		ui.call.feedback.Text = ""
	end

	renderChoices(view)
end

local function enterCall(view)
	state.inCall = true
	state.elapsed = 0
	ui.home.frame.Visible = false
	ui.call.frame.Visible = true
	ui.result.frame.Visible = false
	renderCall(view, true)
end

local function exitCall()
	state.inCall = false
	ui.call.frame.Visible = false
	ui.home.frame.Visible = true
end

--------------------------------------------------------------------------------
-- Result screen
--------------------------------------------------------------------------------

local function renderResult(payload)
	for _, child in ipairs(ui.result.breakdown:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in ipairs(ui.result.achievements:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local success = payload.outcome == "success"
	ui.result.outcome.Text = payload.title
	ui.result.outcome.TextColor3 = success and T.Success or T.Danger
	ui.result.line.Text = "\"" .. (payload.closingLine or "") .. "\""
	ui.result.detail.Text = string.format(
		"%s was a %s.\nReached stage %d (%s) in %s.  Trust %d  Suspicion %d.%s",
		payload.npc.fullName,
		payload.revealedPersonality or "caller",
		payload.stage,
		payload.stageLabel,
		Util.formatTime(payload.duration),
		payload.trust,
		payload.suspicion,
		payload.perfect and "\nNo choice raised suspicion - perfect run." or ""
	)
	ui.result.reward.Text = string.format("+%s Credits", Util.formatNumber(payload.reward))

	for index, entry in ipairs(payload.breakdown or {}) do
		UIKit.label({
			Text = string.format("%s: +%s", entry.label, Util.formatNumber(entry.amount)),
			TextSize = 14,
			TextColor3 = T.SubText,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = index,
			Parent = ui.result.breakdown,
		})
	end

	for index, achievement in ipairs(payload.achievements or {}) do
		local card = UIKit.panel({
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = T.PanelLight,
			LayoutOrder = index,
			Parent = ui.result.achievements,
		})
		UIKit.stroke(T.Gold, 2).Parent = card
		UIKit.padding(8).Parent = card
		UIKit.label({
			Text = "ACHIEVEMENT: " .. achievement.name,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = T.Gold,
			Size = UDim2.new(1, 0, 0, 16),
			Parent = card,
		})
		UIKit.label({
			Text = achievement.blurb .. "  (+" .. Util.formatNumber(achievement.reward) .. ")",
			TextSize = 12,
			TextColor3 = T.SubText,
			TextWrapped = true,
			Position = UDim2.new(0, 0, 0, 18),
			Size = UDim2.new(1, 0, 0, 20),
			Parent = card,
		})
	end

	ui.result.frame.Visible = true
end

--------------------------------------------------------------------------------
-- Shop and career panels
--------------------------------------------------------------------------------

local EFFECT_LABELS = {
	startTrust = "Starting Trust",
	startSuspicion = "Starting Suspicion",
	suspicionResist = "Suspicion Gain",
	rewardMul = "Call Rewards",
	patienceBonus = "NPC Patience",
	easyChance = "Easier Caller Chance",
	timeBonus = "Fast-Call Window",
	eventResist = "Interruption Chance",
}

local function describeEffect(effect): string
	local name = EFFECT_LABELS[effect.key] or effect.key
	if effect.key == "suspicionResist" or effect.key == "eventResist" then
		return string.format("%s -%d%%", name, math.floor((1 - effect.value) * 100 + 0.5))
	elseif effect.key == "rewardMul" or effect.key == "easyChance" then
		return string.format("%s +%d%%", name, math.floor(effect.value * 100 + 0.5))
	end
	return string.format("%s +%d", name, effect.value)
end

local function renderShop()
	for _, child in ipairs(ui.shop.body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not state.catalog then
		return
	end
	ui.shop.credits.Text = Util.formatNumber(state.data and state.data.credits or 0) .. " Credits"

	for index, upgrade in ipairs(state.catalog.upgrades) do
		local card = UIKit.panel({
			Size = UDim2.new(1, -8, 0, 92),
			BackgroundColor3 = T.PanelLight,
			LayoutOrder = index,
			Parent = ui.shop.body,
		})
		UIKit.padding(12).Parent = card
		UIKit.stroke(upgrade.owned and T.Success or T.Panel, 2).Parent = card

		UIKit.label({
			Text = upgrade.name,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Size = UDim2.new(1, -140, 0, 20),
			Parent = card,
		})
		UIKit.label({
			Text = upgrade.blurb,
			TextSize = 13,
			TextColor3 = T.SubText,
			TextWrapped = true,
			Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(1, -140, 0, 30),
			Parent = card,
		})

		local effects = {}
		for _, effect in ipairs(upgrade.effects) do
			table.insert(effects, describeEffect(effect))
		end
		UIKit.label({
			Text = table.concat(effects, "   |   "),
			TextSize = 12,
			TextColor3 = T.Accent,
			TextWrapped = true,
			Position = UDim2.new(0, 0, 0, 54),
			Size = UDim2.new(1, -140, 0, 18),
			Parent = card,
		})

		local buy = UIKit.button({
			Text = upgrade.owned and "Owned" or (Util.formatNumber(upgrade.cost) .. " Cr"),
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 120, 0, 40),
			BackgroundColor3 = upgrade.owned and T.Success or (upgrade.canBuy and T.Accent or T.Background),
			TextColor3 = (upgrade.owned or upgrade.canBuy) and T.Text or T.SubText,
			Parent = card,
		})
		buy.Active = upgrade.canBuy

		if not upgrade.owned then
			UIKit.label({
				Text = upgrade.canBuy and "" or upgrade.reason,
				TextSize = 11,
				TextColor3 = T.Danger,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 1, 4),
				Size = UDim2.new(0, 180, 0, 14),
				Parent = card,
			})
		end

		buy.MouseButton1Click:Connect(function()
			if upgrade.owned then
				return
			end
			if not upgrade.canBuy then
				toast("Cannot Buy", upgrade.reason, "warn")
				return
			end
			Net.event("PurchaseUpgrade"):FireServer(upgrade.id)
		end)
	end
end

local function renderCareer()
	for _, child in ipairs(ui.career.body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not state.data or not state.catalog then
		return
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local stats = state.data.stats
	local statLines = {
		{ "Rank", state.data.rankName },
		{ "Credits", Util.formatNumber(state.data.credits) },
		{ "Lifetime earnings", Util.formatNumber(stats.lifetimeEarnings) },
		{ "Successful calls", tostring(stats.successfulCalls) },
		{ "Failed calls", tostring(stats.failedCalls) },
		{ "Best single payout", Util.formatNumber(stats.bestSingleReward) },
		{ "Highest difficulty cleared", stats.highestDifficulty ~= "" and stats.highestDifficulty or "None yet" },
		{ "Time on calls", Util.formatTime(stats.totalCallSeconds) },
		{ "Times put on hold", tostring(stats.timesOnHold) },
	}

	UIKit.label({
		Text = "STATISTICS",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = T.Accent,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = nextOrder(),
		Parent = ui.career.body,
	})
	for _, entry in ipairs(statLines) do
		local row = UIKit.new("Frame", {
			Size = UDim2.new(1, -8, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = ui.career.body,
		})
		UIKit.label({ Text = entry[1], TextSize = 14, TextColor3 = T.SubText, Size = UDim2.new(0.6, 0, 1, 0), Parent = row })
		UIKit.label({
			Text = entry[2],
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.6, 0, 0, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
			Parent = row,
		})
	end

	if state.data.nextRank then
		UIKit.label({
			Text = string.format(
				"Next rank: %s (needs %s lifetime earnings and %d successful calls)",
				state.data.nextRank.name,
				Util.formatNumber(state.data.nextRank.lifetime),
				state.data.nextRank.calls
			),
			TextSize = 13,
			TextColor3 = T.Gold,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 34),
			LayoutOrder = nextOrder(),
			Parent = ui.career.body,
		})
	end

	UIKit.label({
		Text = "RANKS",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = T.Accent,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = nextOrder(),
		Parent = ui.career.body,
	})
	for _, rank in ipairs(state.catalog.ranks) do
		local reached = state.data.rankIndex >= rank.index
		UIKit.label({
			Text = string.format("%s%s  -  %s Cr / %d calls  -  %s",
				reached and "[x] " or "[ ] ",
				rank.name,
				Util.formatNumber(rank.lifetime),
				rank.calls,
				table.concat(rank.perks, ", ")
			),
			TextSize = 13,
			TextColor3 = reached and T.Text or T.SubText,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 32),
			LayoutOrder = nextOrder(),
			Parent = ui.career.body,
		})
	end

	UIKit.label({
		Text = "ACHIEVEMENTS",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = T.Accent,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = nextOrder(),
		Parent = ui.career.body,
	})
	for _, achievement in ipairs(state.catalog.achievements) do
		local unlocked = state.data.achievements[achievement.id] == true
		UIKit.label({
			Text = string.format("%s%s  -  %s  (+%s)",
				unlocked and "[x] " or "[ ] ",
				achievement.name,
				achievement.blurb,
				Util.formatNumber(achievement.reward)
			),
			TextSize = 13,
			TextColor3 = unlocked and T.Gold or T.SubText,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 32),
			LayoutOrder = nextOrder(),
			Parent = ui.career.body,
		})
	end

	local content = state.catalog.content
	UIKit.label({
		Text = string.format(
			"Content loaded: %d personalities, %d dialogue situations, %d random events, %d upgrades. Version %s.",
			content.personalities, content.situations, content.events, content.upgrades, state.catalog.version
		),
		TextSize = 12,
		TextColor3 = T.SubText,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = nextOrder(),
		Parent = ui.career.body,
	})
end

--------------------------------------------------------------------------------
-- Data plumbing
--------------------------------------------------------------------------------

local function applyData(data)
	if not data then
		return
	end
	state.data = data
	state.difficulty = data.settings.difficulty or state.difficulty
	ui.topBar.credits.Text = Util.formatNumber(data.credits) .. " Credits"
	ui.topBar.rank.Text = data.rankName .. (data.saveDisabled and "   (saving disabled this session)" or "")
	refreshDifficultyButtons()
	if ui.shop.frame.Visible then
		task.spawn(function()
			state.catalog = Net.func("GetCatalog"):InvokeServer()
			renderShop()
		end)
	end
	if ui.career.frame.Visible then
		renderCareer()
	end
end

local function refreshCatalog()
	local ok, catalog = pcall(function()
		return Net.func("GetCatalog"):InvokeServer()
	end)
	if ok and catalog then
		state.catalog = catalog
		buildDifficultyButtons()
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

Net.event("DataUpdated").OnClientEvent:Connect(applyData)

Net.event("CallStarted").OnClientEvent:Connect(function(view)
	enterCall(view)
end)

Net.event("CallUpdated").OnClientEvent:Connect(function(view)
	if not state.inCall then
		enterCall(view)
		return
	end
	renderCall(view, true)
end)

Net.event("CallEnded").OnClientEvent:Connect(function(payload)
	exitCall()
	renderResult(payload)
	task.spawn(refreshCatalog)
end)

Net.event("Notify").OnClientEvent:Connect(function(payload)
	toast(payload.title, payload.body, payload.kind)
	if payload.openShop then
		task.spawn(function()
			refreshCatalog()
			renderShop()
			ui.shop.frame.Visible = true
		end)
	end
end)

Net.event("AchievementUnlocked").OnClientEvent:Connect(function(achievement)
	toast("Achievement: " .. achievement.name, achievement.blurb, "gold")
end)

Net.event("RankChanged").OnClientEvent:Connect(function(payload)
	toast("Promoted to " .. payload.to, "Unlocked: " .. table.concat(payload.perks or {}, ", "), "gold")
end)

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------

ui.home.startButton.MouseButton1Click:Connect(function()
	Net.event("StartCall"):FireServer(state.difficulty)
end)

ui.call.hangUp.MouseButton1Click:Connect(function()
	Net.event("HangUp"):FireServer()
end)

for _, button in ipairs(ui.call.choiceButtons) do
	button.MouseButton1Click:Connect(function()
		if button:GetAttribute("Locked") then
			toast("Locked", button:GetAttribute("LockReason"), "warn")
			return
		end
		local index = button:GetAttribute("ChoiceIndex")
		if not index then
			return
		end
		for _, other in ipairs(ui.call.choiceButtons) do
			other.Visible = false
		end
		Net.event("ChooseOption"):FireServer(index)
	end)
end

ui.topBar.shopButton.MouseButton1Click:Connect(function()
	task.spawn(function()
		refreshCatalog()
		renderShop()
		ui.shop.frame.Visible = true
	end)
end)

ui.topBar.statsButton.MouseButton1Click:Connect(function()
	task.spawn(function()
		refreshCatalog()
		renderCareer()
		ui.career.frame.Visible = true
	end)
end)

ui.topBar.helpButton.MouseButton1Click:Connect(function()
	ui.help.frame.Visible = true
end)

ui.shop.close.MouseButton1Click:Connect(function()
	ui.shop.frame.Visible = false
end)
ui.career.close.MouseButton1Click:Connect(function()
	ui.career.frame.Visible = false
end)
ui.help.close.MouseButton1Click:Connect(function()
	ui.help.frame.Visible = false
end)
ui.result.close.MouseButton1Click:Connect(function()
	ui.result.frame.Visible = false
end)

--------------------------------------------------------------------------------
-- Timer
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(0.25)
		if state.inCall then
			state.elapsed += 0.25
			ui.call.timer.Text = Util.formatTime(state.elapsed)
			if state.elapsed > Config.Call.FastCallSeconds then
				ui.call.timer.TextColor3 = T.Suspicion
			else
				ui.call.timer.TextColor3 = T.Trust
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

task.spawn(function()
	local ok, data = pcall(function()
		return Net.func("GetData"):InvokeServer()
	end)
	if ok and data then
		applyData(data)
	end
	refreshCatalog()
	Net.event("RequestData"):FireServer()
	toast("Welcome to Macrosoft", "Everything here is fictional satire. Press How To Play for the rules.", "info")
end)
