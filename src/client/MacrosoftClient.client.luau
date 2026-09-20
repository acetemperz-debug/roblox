--!nonstrict
-- MacrosoftClient (LocalScript)
-- Wires the generated interface to the server. Lives in StarterPlayerScripts.


local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)

local UIKit = require(script.Parent.UIKit)
local Interface = require(script.Parent.Interface)
local Juice = require(script.Parent.Juice)

local T = UIKit.Theme

local ui = Interface.build()
Juice.init(ui.gui)
Juice.attachTicker(ui.ticker.frame, ui.ticker.label)

local state = {
	data = nil,
	catalog = nil,
	difficulty = "Normal",
	inCall = false,
	elapsed = 0,
	typing = nil,
	lastView = nil,
	store = nil,
	operation = nil,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Forward declarations. enterCall needs the mid-call consumable buttons, and
-- applyData needs to re-pull the store while its panel is open; both are
-- defined further down.
local renderItemRow
local refreshStore
local renderOperation

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

	ui.call.face.Text = Juice.face(view.reaction)

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

		-- Floating numbers next to the meter they belong to.
		if animate then
			local trust = view.feedback.trust or 0
			local suspicion = view.feedback.suspicion or 0
			if math.abs(trust) >= 1 then
				Juice.popup(
					string.format("%+.0f TRUST", trust),
					trust > 0 and T.Trust or T.Suspicion,
					ui.call.meters.trust.track,
					{ offsetX = 150, size = 24 }
				)
			end
			if math.abs(suspicion) >= 1 then
				Juice.popup(
					string.format("%+.0f SUS", suspicion),
					suspicion > 0 and T.Suspicion or T.Trust,
					ui.call.meters.suspicion.track,
					{ offsetX = 150, size = 24, offsetY = 10 }
				)
			end
			if suspicion >= 15 then
				Juice.shake(ui.call.frame, 10, 0.25)
				Juice.flash(T.Suspicion, 0.2, 0.35)
				Juice.play("bad")
			elseif trust >= 12 then
				Juice.play("good")
			end
		end
	else
		ui.call.feedback.Text = ""
	end

	-- Even with the meters hidden, the caller losing their temper should land.
	if animate and (view.reaction == "angry" or view.reaction == "accuse") then
		Juice.shake(ui.call.portrait, 6, 0.3)
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
	renderItemRow()
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
	Juice.countUp(ui.result.reward, 0, payload.reward, function(value)
		return string.format("+%s Credits", Util.formatNumber(value))
	end, 0.9)

	if success then
		Juice.confetti(55)
		Juice.flash(T.Success, 0.22, 0.5)
		Juice.play("success")
		Juice.play("cash")
	else
		Juice.flash(T.Danger, 0.25, 0.5)
		Juice.shake(ui.result.frame, 8, 0.3)
		Juice.play("fail")
	end

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

local function renderStore()
	for _, child in ipairs(ui.store.body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not state.store then
		return
	end

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function heading(text: string, subtitle: string)
		UIKit.label({
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = T.Gold,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = nextOrder(),
			Parent = ui.store.body,
		})
		UIKit.label({
			Text = subtitle,
			TextSize = 12,
			TextColor3 = T.SubText,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = nextOrder(),
			Parent = ui.store.body,
		})
	end

	local function card(item, kind: string)
		local frame = UIKit.panel({
			Size = UDim2.new(1, -8, 0, 86),
			BackgroundColor3 = T.PanelLight,
			LayoutOrder = nextOrder(),
			Parent = ui.store.body,
		})
		UIKit.padding(12).Parent = frame
		local owned = kind == "pass" and item.owned == true
		UIKit.stroke(owned and T.Success or T.Panel, 2).Parent = frame

		UIKit.label({
			Text = item.name,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Size = UDim2.new(1, -150, 0, 20),
			Parent = frame,
		})
		UIKit.label({
			Text = item.blurb,
			TextSize = 13,
			TextColor3 = T.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(1, -150, 0, 40),
			Parent = frame,
		})

		local label
		if not item.configured then
			label = "Unavailable"
		elseif owned then
			label = "Owned"
		elseif kind == "product" and item.owned > 0 then
			label = string.format("Buy (%d held)", item.owned)
		else
			label = "Buy"
		end

		local buy = UIKit.button({
			Text = label,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 130, 0, 40),
			BackgroundColor3 = owned and T.Success or (item.configured and T.Gold or T.Background),
			TextColor3 = item.configured and Color3.fromRGB(30, 26, 12) or T.SubText,
			Parent = frame,
		})
		buy.Active = item.configured and not owned

		if item.robux then
			UIKit.label({
				Text = "suggested " .. item.robux .. " R$",
				TextSize = 11,
				TextColor3 = T.SubText,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 1, 2),
				Size = UDim2.new(0, 140, 0, 14),
				Parent = frame,
			})
		end

		buy.MouseButton1Click:Connect(function()
			if not item.configured then
				toast("Not Set Up", item.name .. " has no asset id yet. See docs/SETUP.md.", "warn")
				return
			end
			if owned then
				return
			end
			Net.event("PromptPurchase"):FireServer(kind, item.id)
		end)
	end

	local configured = 0
	for _, pass in ipairs(state.store.passes) do
		configured += pass.configured and 1 or 0
	end
	for _, product in ipairs(state.store.products) do
		configured += product.configured and 1 or 0
	end
	if configured == 0 then
		local banner = UIKit.panel({
			Size = UDim2.new(1, -8, 0, 66),
			BackgroundColor3 = Color3.fromRGB(62, 48, 20),
			LayoutOrder = nextOrder(),
			Parent = ui.store.body,
		})
		UIKit.padding(10).Parent = banner
		UIKit.stroke(T.Gold, 2).Parent = banner
		UIKit.label({
			Text = "⚠ Nothing here is set up yet",
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = T.Gold,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = banner,
		})
		UIKit.label({
			Text = "Create each item on the Roblox Creator Dashboard, then paste its id into Products.luau (step 8 of docs/SETUP.md). Expected on a fresh install -- the rest of the game works without it.",
			TextSize = 12,
			TextColor3 = T.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(1, 0, 0, 34),
			Parent = banner,
		})
	end

	heading("Passes", "Bought once, kept forever.")
	for _, pass in ipairs(state.store.passes) do
		card(pass, "pass")
	end

	heading("Consumables", "Bought as often as you like. Used from the call screen.")
	for _, product in ipairs(state.store.products) do
		card(product, "product")
	end
end

function renderItemRow()
	for _, child in ipairs(ui.call.itemRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not state.store or not state.data then
		return
	end
	local inventory = state.data.premium and state.data.premium.inventory or {}

	for index, product in ipairs(state.store.products) do
		local held = inventory[product.id] or 0
		if product.usableInCall and held > 0 then
			local button = UIKit.button({
				Text = string.format("%s (%d)", product.useLabel or product.name, held),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(0, 132, 1, 0),
				LayoutOrder = index,
				BackgroundColor3 = T.Gold,
				TextColor3 = Color3.fromRGB(32, 26, 10),
				Parent = ui.call.itemRow,
			})
			button.MouseButton1Click:Connect(function()
				Net.event("UseItem"):FireServer(product.id)
			end)
		end
	end
end

-- Escalating labels, because a bare number is not a reason to keep going.
local STREAK_LABELS = {
	{ at = 12, text = "CERTIFIED MENACE" },
	{ at = 8, text = "UNHINGED" },
	{ at = 5, text = "ON FIRE" },
	{ at = 3, text = "COOKING" },
	{ at = 2, text = "WARM" },
}

local function streakLabel(streak: number): string
	for _, entry in ipairs(STREAK_LABELS) do
		if streak >= entry.at then
			return entry.text
		end
	end
	return "STREAK"
end

local function formatRate(value: number): string
	if value >= 100 then
		return Util.formatNumber(math.floor(value))
	end
	return string.format("%.1f", value)
end

local function renderOperationHud()
	local hud = ui.operation.hud
	local view = state.operation
	if not view then
		return
	end

	local method
	for _, entry in ipairs(view.methods) do
		if entry.active then
			method = entry
		end
	end
	hud.method.Text = method and method.name or "Cold Calling"

	local shutdown = view.shutdownRemaining or 0
	local layLow = view.layLowRemaining or 0
	if shutdown > 0 then
		hud.income.Text = "SHUT DOWN " .. Util.formatTime(shutdown)
		hud.income.TextColor3 = T.Danger
	elseif layLow > 0 then
		hud.income.Text = "LYING LOW " .. Util.formatTime(layLow)
		hud.income.TextColor3 = T.Patience
	else
		hud.income.Text = "+" .. formatRate(view.summary.netIncome) .. " /sec"
		hud.income.TextColor3 = T.Success
	end

	hud.staff.Text = string.format("%d / %d desks", view.summary.headcount, view.summary.deskCap)

	UIKit.setMeter(hud.heat, {
		mode = "full",
		label = string.format("%d / %d", math.floor(view.heat), view.heatMax),
		ratio = view.heat / view.heatMax,
	})

	local rate = view.summary.heatRate
	if layLow > 0 then
		rate = -(view.summary.heatDecay * 8)
	end
	if rate > 0 then
		local seconds = (view.heatMax - view.heat) / rate
		hud.heatRate.Text = string.format("+%.2f/s - raid in %s", rate, Util.formatTime(seconds))
		hud.heatRate.TextColor3 = T.Suspicion
	else
		hud.heatRate.Text = string.format("%.2f/s - cooling off", rate)
		hud.heatRate.TextColor3 = T.Success
	end

	hud.layLow.Active = layLow <= 0 and shutdown <= 0
	hud.layLow.BackgroundColor3 = hud.layLow.Active and T.PanelLight or T.Background
end

function renderOperation()
	renderOperationHud()

	for _, child in ipairs(ui.operation.body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local view = state.operation
	if not view then
		return
	end

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	ui.operation.summary.Text = string.format(
		"+%s/sec net  -  %d staff  -  security %d  -  escape chance %d%%  -  offline cap %dh",
		formatRate(view.summary.netIncome),
		view.summary.headcount,
		view.summary.securityRating,
		math.floor(view.summary.escapeChance * 100),
		math.floor(view.summary.offlineCapSeconds / 3600)
	)

	local function heading(text: string, subtitle: string?)
		UIKit.label({
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = T.Accent,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = nextOrder(),
			Parent = ui.operation.body,
		})
		if subtitle then
			UIKit.label({
				Text = subtitle,
				TextSize = 12,
				TextColor3 = T.SubText,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = nextOrder(),
				Parent = ui.operation.body,
			})
		end
	end

	-- One row shape reused by every section.
	local function row(opts)
		local card = UIKit.panel({
			Size = UDim2.new(1, -8, 0, opts.height or 74),
			BackgroundColor3 = T.PanelLight,
			LayoutOrder = nextOrder(),
			Parent = ui.operation.body,
		})
		UIKit.padding(12).Parent = card
		UIKit.stroke(opts.strokeColour or T.Panel, 2).Parent = card

		UIKit.label({
			Text = opts.title,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = opts.titleColour or T.Text,
			Size = UDim2.new(1, -230, 0, 20),
			Parent = card,
		})
		UIKit.label({
			Text = opts.blurb or "",
			TextSize = 12,
			TextColor3 = T.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, 0, 0, 21),
			Size = UDim2.new(1, -230, 0, 30),
			Parent = card,
		})
		if opts.stats then
			UIKit.label({
				Text = opts.stats,
				TextSize = 12,
				TextColor3 = T.Accent,
				TextWrapped = true,
				Position = UDim2.new(0, 0, 0, 52),
				Size = UDim2.new(1, -230, 0, 16),
				Parent = card,
			})
		end
		return card
	end

	local function actionButton(card, opts)
		local button = UIKit.button({
			Text = opts.text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, opts.offsetX or 0, 0.5, 0),
			Size = UDim2.new(0, opts.width or 150, 0, 38),
			BackgroundColor3 = opts.colour or T.Accent,
			TextColor3 = opts.textColour or T.Text,
			Parent = card,
		})
		button.Active = opts.enabled ~= false
		if not button.Active then
			button.BackgroundColor3 = T.Background
			button.TextColor3 = T.SubText
		end
		button.MouseButton1Click:Connect(function()
			if not button.Active then
				if opts.disabledReason then
					toast("Not Yet", opts.disabledReason, "warn")
				end
				return
			end
			opts.onClick()
		end)
		return button
	end

	local function act(action: string, a: string?, b: number?)
		Net.event("OperationAction"):FireServer(action, a, b)
	end

	----------------------------------------------------------------------------
	heading("Method", "How the operation makes its money. Every step up pays more and draws more attention.")
	for _, method in ipairs(view.methods) do
		local card = row({
			title = string.format("%d. %s", method.index, method.name),
			titleColour = method.active and T.Success or T.Text,
			strokeColour = method.active and T.Success or T.Panel,
			blurb = method.blurb,
			stats = string.format("income x%.1f  -  heat %.2f/s  -  needs %s", method.incomeMul, method.heatPerSecond, method.requiresRankName),
		})
		if method.active then
			actionButton(card, { text = "RUNNING", colour = T.Success, enabled = false })
		elseif method.unlocked then
			actionButton(card, { text = "SWITCH TO", onClick = function()
				act("setMethod", method.id)
			end })
		else
			actionButton(card, {
				text = Util.formatNumber(method.cost) .. " Cr",
				colour = T.Gold,
				textColour = Color3.fromRGB(30, 26, 12),
				enabled = method.available,
				disabledReason = "Unlock the tier below it first, and reach " .. method.requiresRankName .. ".",
				onClick = function()
					act("setMethod", method.id)
				end,
			})
		end
	end

	----------------------------------------------------------------------------
	heading("Staff", "Passive income, minus wages. The cheap ones draw more attention and are the first out of the window in a raid.")
	for _, employee in ipairs(view.staff) do
		local card = row({
			title = string.format("%s  x%d", employee.name, employee.held),
			blurb = employee.blurb,
			stats = string.format(
				"%s+%.0f/s each, wage %.0f/s, heat %.3f/s",
				employee.suspicious and "SUSPICIOUS - " or "",
				employee.incomePerSecond,
				employee.wagePerSecond,
				employee.heatPerSecond
			),
			height = 80,
		})
		actionButton(card, {
			text = "HIRE  " .. Util.formatNumber(employee.hireCost),
			width = 150,
			onClick = function()
				act("hire", employee.id, 1)
			end,
		})
		actionButton(card, {
			text = "FIRE",
			width = 64,
			offsetX = -156,
			colour = T.Danger,
			enabled = employee.held > 0,
			onClick = function()
				act("fire", employee.id, 1)
			end,
		})
	end

	----------------------------------------------------------------------------
	heading("Premises", "More desks, and a multiplier on everything the floor earns.")
	for _, facility in ipairs(view.facilities) do
		local card = row({
			title = string.format("%d. %s", facility.index, facility.name),
			titleColour = facility.id == view.facility and T.Success or T.Text,
			strokeColour = facility.id == view.facility and T.Success or T.Panel,
			blurb = facility.blurb,
			stats = string.format("%d desks  -  income x%.2f", facility.desks, facility.incomeMul),
		})
		if facility.id == view.facility then
			actionButton(card, { text = "CURRENT", colour = T.Success, enabled = false })
		elseif facility.owned then
			actionButton(card, { text = "OUTGROWN", enabled = false })
		else
			actionButton(card, {
				text = Util.formatNumber(facility.cost) .. " Cr",
				colour = T.Gold,
				textColour = Color3.fromRGB(30, 26, 12),
				enabled = facility.available,
				disabledReason = "Move in one step at a time.",
				onClick = function()
					act("buyFacility", facility.id)
				end,
			})
		end
	end

	----------------------------------------------------------------------------
	heading("Security", "Slows heat, speeds cooling, and decides how a raid goes.")
	for _, item in ipairs(view.security) do
		local card = row({
			title = item.name,
			blurb = item.blurb,
			stats = string.format("heat x%.2f  -  cooling +%.2f/s  -  escape +%d", item.heatMul, item.decayBonus, item.rating),
			strokeColour = item.owned and T.Success or T.Panel,
		})
		actionButton(card, {
			text = item.owned and "INSTALLED" or (Util.formatNumber(item.cost) .. " Cr"),
			colour = item.owned and T.Success or T.Gold,
			textColour = item.owned and T.Text or Color3.fromRGB(30, 26, 12),
			enabled = not item.owned,
			onClick = function()
				act("buySecurity", item.id)
			end,
		})
	end

	----------------------------------------------------------------------------
	heading("Tradecraft", "Makes whatever you are already doing look less obviously dodgy.")
	for _, item in ipairs(view.tradecraft) do
		local card = row({
			title = item.name,
			blurb = item.blurb,
			stats = string.format("heat x%.2f  -  income +%d%%  -  needs %s", item.heatMul, math.floor(item.incomeMul * 100), item.requiresMethodName),
			strokeColour = item.owned and T.Success or T.Panel,
		})
		actionButton(card, {
			text = item.owned and "TRAINED" or (Util.formatNumber(item.cost) .. " Cr"),
			colour = item.owned and T.Success or T.Gold,
			textColour = item.owned and T.Text or Color3.fromRGB(30, 26, 12),
			enabled = not item.owned,
			onClick = function()
				act("buyTradecraft", item.id)
			end,
		})
	end

	----------------------------------------------------------------------------
	local inventory = state.data and state.data.premium and state.data.premium.inventory or {}
	local hasOperationItems = false
	if state.store then
		for _, product in ipairs(state.store.products) do
			if product.usableInOperation and (inventory[product.id] or 0) > 0 then
				hasOperationItems = true
			end
		end
	end
	if hasOperationItems then
		heading("In Your Drawer", "Bought items you can use on the operation right now.")
		for _, product in ipairs(state.store.products) do
			local held = inventory[product.id] or 0
			if product.usableInOperation and held > 0 then
				local card = row({
					title = string.format("%s  x%d", product.name, held),
					blurb = product.blurb,
				})
				actionButton(card, {
					text = "USE",
					colour = T.Gold,
					textColour = Color3.fromRGB(30, 26, 12),
					onClick = function()
						act("useItem", product.id)
					end,
				})
			end
		end
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

	-- Alias Licence editor, shown to everyone so the pass is discoverable.
	local ownsAlias = state.data.premium and state.data.premium.passes and state.data.premium.passes.alias_licence == true
	UIKit.label({
		Text = "TECHNICIAN NAME",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = T.Accent,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = nextOrder(),
		Parent = ui.career.body,
	})

	local aliasRow = UIKit.new("Frame", {
		Size = UDim2.new(1, -8, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = ui.career.body,
	})

	local aliasBox = UIKit.new("TextBox", {
		Size = UDim2.new(1, -140, 1, 0),
		BackgroundColor3 = T.PanelLight,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = ownsAlias and T.Text or T.SubText,
		PlaceholderText = ownsAlias and "Two to sixteen letters" or "Requires the Alias Licence pass",
		Text = (state.data.premium and state.data.premium.alias) or "",
		ClearTextOnFocus = false,
		TextEditable = ownsAlias,
		Parent = aliasRow,
	})
	UIKit.corner(8).Parent = aliasBox
	UIKit.padding(8).Parent = aliasBox

	local aliasSave = UIKit.button({
		Text = ownsAlias and "Save" or "Locked",
		Font = Enum.Font.GothamBold,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 130, 1, 0),
		BackgroundColor3 = ownsAlias and T.Accent or T.Background,
		TextColor3 = ownsAlias and T.Text or T.SubText,
		Parent = aliasRow,
	})
	aliasSave.Active = ownsAlias
	aliasSave.MouseButton1Click:Connect(function()
		if not ownsAlias then
			toast("Locked", "The Alias Licence pass is in the Store.", "warn")
			return
		end
		Net.event("SetAlias"):FireServer(aliasBox.Text)
	end)

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

	local streak = data.stats and data.stats.successStreak or 0
	ui.topBar.streakPill.Visible = streak >= 2
	if streak >= 2 then
		ui.topBar.streakLabel.Text = string.format("🔥 %s x%d", streakLabel(streak), streak)
	end

	local boostRemaining = data.premium and data.premium.boostRemaining or 0
	ui.topBar.boost.Visible = boostRemaining > 0
	if boostRemaining > 0 then
		ui.topBar.boost.Text = "Double Shift active - " .. Util.formatTime(boostRemaining)
	end

	refreshDifficultyButtons()
	renderItemRow()
	if ui.store.frame.Visible then
		task.spawn(function()
			refreshStore()
			renderStore()
		end)
	end
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

local function refreshOperation()
	local ok, view = pcall(function()
		return Net.func("GetOperation"):InvokeServer()
	end)
	if ok and view then
		state.operation = view
		renderOperation()
	end
	return ok
end

function refreshStore()
	local ok, store = pcall(function()
		return Net.func("GetStore"):InvokeServer()
	end)
	if ok and store then
		state.store = store
		renderItemRow()
	end
	return ok
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

Net.event("DataUpdated").OnClientEvent:Connect(applyData)

Net.event("OperationUpdated").OnClientEvent:Connect(function(view)
	-- Show what the floor earned since the last push, so idle income is visible
	-- rather than a number quietly ticking up.
	local previous = state.operation
	if previous and view.summary.netIncome > 0 and (view.shutdownRemaining or 0) <= 0 and (view.layLowRemaining or 0) <= 0 then
		local earned = math.floor(view.summary.netIncome * 5)
		if earned > 0 then
			Juice.popup("+" .. Util.formatNumber(earned), T.Gold, ui.operation.hud.panel, {
				offsetX = 40,
				offsetY = -10,
				size = 20,
				rise = 40,
				duration = 0.8,
			})
		end
	end

	state.operation = view
	if ui.operation.frame.Visible then
		renderOperation()
	else
		renderOperationHud()
	end
end)

Net.event("HeatWarning").OnClientEvent:Connect(function(warning)
	toast(warning.title, warning.body, "warn")
	Juice.flash(T.Suspicion, 0.18, 0.6)
	Juice.play("alarm")
end)

Net.event("RaidAlert").OnClientEvent:Connect(function(outcome)
	toast(outcome.title, outcome.body, outcome.escaped and "success" or "warn")
	if outcome.escaped then
		Juice.confetti(30)
		Juice.flash(T.Success, 0.25, 0.6)
	else
		Juice.flash(T.Danger, 0.45, 0.9)
		Juice.shake(ui.operation.hud.panel, 12, 0.8)
		Juice.popup("RAIDED", T.Danger, nil, { size = 54, rise = 40, duration = 1.4 })
	end
end)

Net.event("Broadcast").OnClientEvent:Connect(function(payload)
	local colour = T.Text
	if payload.kind == "success" then
		colour = T.Success
	elseif payload.kind == "warn" then
		colour = T.Danger
	elseif payload.kind == "gold" then
		colour = T.Gold
	end
	Juice.ticker(payload.text, colour)
end)

Net.event("OfflineEarnings").OnClientEvent:Connect(function(payload)
	toast(
		"While You Were Out",
		string.format(
			"The floor kept working for %s and made %s Credits.%s",
			Util.formatTime(payload.seconds),
			Util.formatNumber(payload.amount),
			payload.capped and " (offline cap reached)" or ""
		),
		"gold"
	)
end)

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
	task.spawn(function()
		refreshCatalog()
		refreshStore()
	end)
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
	Juice.confetti(70)
	Juice.flash(T.Gold, 0.3, 0.8)
	Juice.popup("PROMOTED", T.Gold, nil, { size = 52, rise = 50, duration = 1.5 })
	Juice.play("rankUp")
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
		Juice.pulse(button, 0.05)
		Juice.play("choice")
		for _, other in ipairs(ui.call.choiceButtons) do
			other.Visible = false
		end
		Net.event("ChooseOption"):FireServer(index)
	end)
end

local function openOperation()
	task.spawn(function()
		refreshStore()
		refreshOperation()
		ui.operation.frame.Visible = true
	end)
end

ui.operation.button.MouseButton1Click:Connect(openOperation)
ui.operation.hud.open.MouseButton1Click:Connect(openOperation)
ui.operation.close.MouseButton1Click:Connect(function()
	ui.operation.frame.Visible = false
end)
ui.operation.hud.layLow.MouseButton1Click:Connect(function()
	if not ui.operation.hud.layLow.Active then
		return
	end
	Net.event("OperationAction"):FireServer("layLow")
end)

ui.topBar.storeButton.MouseButton1Click:Connect(function()
	task.spawn(function()
		refreshStore()
		renderStore()
		ui.store.frame.Visible = true
	end)
end)

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
ui.store.close.MouseButton1Click:Connect(function()
	ui.store.frame.Visible = false
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
		if ui.topBar.boost.Visible and state.data and state.data.premium then
			state.data.premium.boostRemaining = math.max(0, (state.data.premium.boostRemaining or 0) - 0.25)
			if state.data.premium.boostRemaining <= 0 then
				ui.topBar.boost.Visible = false
			else
				ui.topBar.boost.Text = "Double Shift active - " .. Util.formatTime(state.data.premium.boostRemaining)
			end
		end

		-- The server pushes the operation view every few seconds; between pushes
		-- the client advances heat and credits itself so the meters move
		-- smoothly instead of stepping.
		local view = state.operation
		if view then
			local running = (view.shutdownRemaining or 0) <= 0
			local rate = view.summary.heatRate
			if (view.layLowRemaining or 0) > 0 then
				rate = -(view.summary.heatDecay * 8)
				view.layLowRemaining = math.max(0, view.layLowRemaining - 0.25)
			end
			if (view.shutdownRemaining or 0) > 0 then
				view.shutdownRemaining = math.max(0, view.shutdownRemaining - 0.25)
				rate = -view.summary.heatDecay
			end
			view.heat = math.clamp(view.heat + rate * 0.25, 0, view.heatMax)
			if running and state.data and (view.layLowRemaining or 0) <= 0 then
				state.data.credits += view.summary.netIncome * 0.25
				ui.topBar.credits.Text = Util.formatNumber(state.data.credits) .. " Credits"
			end
			renderOperationHud()
		end

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
	refreshStore()
	refreshOperation()
	Net.event("RequestData"):FireServer()
	toast("Welcome to Macrosoft", "Everything here is fictional satire. Press How To Play for the rules.", "info")
end)
