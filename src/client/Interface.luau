--!nonstrict
-- Interface
-- Builds every screen in code and hands back references. No manual GUI work is
-- required in Studio -- the LocalScript just requires this and wires it up.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)

local UIKit = require(script.Parent.UIKit)

local Interface = {}

local T = UIKit.Theme

local function overlay(name: string, titleText: string)
	local frame = UIKit.new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	})

	local panel = UIKit.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 640, 0, 520),
		BackgroundColor3 = T.Panel,
		ZIndex = 21,
		Parent = frame,
	})
	UIKit.stroke(T.PanelLight, 2).Parent = panel

	local header = UIKit.label({
		Name = "Header",
		Text = titleText,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Position = UDim2.new(0, 20, 0, 16),
		Size = UDim2.new(1, -120, 0, 28),
		ZIndex = 22,
		Parent = panel,
	})

	local close = UIKit.button({
		Name = "Close",
		Text = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.new(0, 84, 0, 32),
		BackgroundColor3 = T.PanelLight,
		ZIndex = 22,
		Parent = panel,
	})

	local body = UIKit.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.new(0, 16, 0, 56),
		Size = UDim2.new(1, -32, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.PanelLight,
		ZIndex = 22,
		Parent = panel,
	})
	UIKit.listLayout({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }).Parent = body

	return { frame = frame, panel = panel, header = header, close = close, body = body }
end

function Interface.build(): any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UIKit.new("ScreenGui", {
		Name = "MacrosoftUI",
		ResetOnSpawn = false,
		-- false, so Roblox's own top bar does not sit on top of ours.
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = playerGui,
	})

	----------------------------------------------------------------------------
	-- Top bar
	----------------------------------------------------------------------------
	local topBar = UIKit.panel({
		Name = "TopBar",
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(1, -32, 0, 52),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UIKit.stroke(T.PanelLight, 1).Parent = topBar

	local brand = UIKit.label({
		Text = "MACROSOFT",
		Font = UIKit.HeadlineFont,
		TextSize = 20,
		TextColor3 = T.Accent,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0, 220, 1, 0),
		Parent = topBar,
	})

	local creditsLabel = UIKit.label({
		Name = "Credits",
		Text = "0 Credits",
		Font = UIKit.HeadlineFont,
		TextSize = 18,
		TextColor3 = T.Gold,
		Position = UDim2.new(0, 390, 0, 0),
		Size = UDim2.new(0, 200, 1, 0),
		Parent = topBar,
	})

	local rankLabel = UIKit.label({
		Name = "Rank",
		Text = "Intern",
		TextSize = 15,
		TextColor3 = T.SubText,
		Position = UDim2.new(0, 592, 0, 8),
		Size = UDim2.new(0, 230, 0, 20),
		Parent = topBar,
	})

	local boostLabel = UIKit.label({
		Name = "Boost",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = T.Gold,
		Position = UDim2.new(0, 592, 0, 26),
		Size = UDim2.new(0, 230, 0, 18),
		Visible = false,
		Parent = topBar,
	})

	local streakPill = UIKit.panel({
		Name = "Streak",
		Position = UDim2.new(0, 246, 0.5, -15),
		Size = UDim2.new(0, 132, 0, 30),
		BackgroundColor3 = Color3.fromRGB(255, 126, 64),
		Visible = false,
		Parent = topBar,
	})
	local streakLabel = UIKit.label({
		Name = "Text",
		Text = "",
		Font = UIKit.HeadlineFont,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(28, 18, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = streakPill,
	})

	local buttonRow = UIKit.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 560, 0, 34),
		BackgroundTransparency = 1,
		Parent = topBar,
	})
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = buttonRow

	local function topButton(text: string, order: number)
		return UIKit.button({
			Text = text,
			Size = UDim2.new(0, 106, 1, 0),
			LayoutOrder = order,
			BackgroundColor3 = T.PanelLight,
			Parent = buttonRow,
		})
	end

	local operationButton = topButton("Operation", 1)
	local shopButton = topButton("Upgrades", 2)
	local storeButton = topButton("Store", 3)
	local statsButton = topButton("Career", 4)
	local helpButton = topButton("How To Play", 5)
	operationButton.BackgroundColor3 = T.AccentDark
	storeButton.BackgroundColor3 = T.Gold
	storeButton.TextColor3 = Color3.fromRGB(32, 26, 10)

	----------------------------------------------------------------------------
	-- Home panel (difficulty + start call)
	----------------------------------------------------------------------------
	-- Bottom right, because the operation HUD owns the bottom left.
	local home = UIKit.panel({
		Name = "Home",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -24),
		Size = UDim2.new(0, 720, 0, 210),
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	UIKit.stroke(T.PanelLight, 1).Parent = home
	UIKit.padding(16).Parent = home

	UIKit.label({
		Text = "Pick a difficulty, then take a call.",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = home,
	})

	local difficultyRow = UIKit.new("Frame", {
		Name = "Difficulties",
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		Parent = home,
	})
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = difficultyRow

	local difficultyBlurb = UIKit.label({
		Name = "Blurb",
		Text = "",
		TextSize = 14,
		TextColor3 = T.SubText,
		TextWrapped = true,
		Position = UDim2.new(0, 0, 0, 100),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = home,
	})

	local startButton = UIKit.button({
		Name = "StartCall",
		Text = "📞  START CALL",
		Font = UIKit.HeadlineFont,
		TextSize = 24,
		BackgroundColor3 = T.Accent,
		Position = UDim2.new(0, 0, 1, -52),
		Size = UDim2.new(1, 0, 0, 50),
		Parent = home,
	})
	UIKit.gradient(Color3.fromRGB(122, 168, 255), Color3.fromRGB(58, 104, 226)).Parent = startButton
	UIKit.stroke(Color3.fromRGB(170, 205, 255), 2, 0.3).Parent = startButton

	----------------------------------------------------------------------------
	-- Live ticker: what everyone else in the server is doing.
	----------------------------------------------------------------------------
	local tickerFrame = UIKit.panel({
		Name = "Ticker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0, 560, 0, 34),
		BackgroundColor3 = Color3.fromRGB(16, 18, 26),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	UIKit.stroke(T.Accent, 2, 0.4).Parent = tickerFrame
	local tickerLabel = UIKit.label({
		Name = "Text",
		Text = "",
		Font = UIKit.HeadlineFont,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = tickerFrame,
	})

	----------------------------------------------------------------------------
	-- Operation HUD (bottom left, always visible -- heat matters during calls)
	----------------------------------------------------------------------------
	local ops = UIKit.panel({
		Name = "OpsHud",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -24),
		Size = UDim2.new(0, 300, 0, 206),
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	UIKit.stroke(T.PanelLight, 1).Parent = ops
	UIKit.padding(14).Parent = ops

	UIKit.label({
		Text = "THE OPERATION",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.SubText,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = ops,
	})

	local opsMethod = UIKit.label({
		Name = "Method",
		Text = "Cold Calling",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = ops,
	})

	local opsIncome = UIKit.label({
		Name = "Income",
		Text = "0 /sec",
		TextSize = 14,
		TextColor3 = T.Success,
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(0.55, 0, 0, 18),
		Parent = ops,
	})

	local opsStaff = UIKit.label({
		Name = "Staff",
		Text = "0 / 3 desks",
		TextSize = 14,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.55, 0, 0, 40),
		Size = UDim2.new(0.45, 0, 0, 18),
		Parent = ops,
	})

	local heatMeter = UIKit.meter("Police Heat", T.Suspicion, 1)
	heatMeter.holder.Position = UDim2.new(0, 0, 0, 62)
	heatMeter.holder.Size = UDim2.new(1, 0, 0, 40)
	heatMeter.holder.Parent = ops

	local opsHeatRate = UIKit.label({
		Name = "HeatRate",
		Text = "",
		TextSize = 12,
		TextColor3 = T.SubText,
		Position = UDim2.new(0, 0, 0, 102),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = ops,
	})

	local layLowButton = UIKit.button({
		Name = "LayLow",
		Text = "LAY LOW",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.new(0, 0, 0, 122),
		Size = UDim2.new(0.48, 0, 0, 30),
		BackgroundColor3 = T.PanelLight,
		Parent = ops,
	})

	local opsOpenButton = UIKit.button({
		Name = "Open",
		Text = "MANAGE",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.new(0.52, 0, 0, 122),
		Size = UDim2.new(0.48, 0, 0, 30),
		BackgroundColor3 = T.AccentDark,
		Parent = ops,
	})

	----------------------------------------------------------------------------
	-- Call screen
	----------------------------------------------------------------------------
	local call = UIKit.new("Frame", {
		Name = "Call",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	-- Left: caller card
	local callerCard = UIKit.panel({
		Name = "Caller",
		Position = UDim2.new(0, 16, 0, 80),
		Size = UDim2.new(0, 300, 0, 430),
		Parent = call,
	})
	UIKit.stroke(T.PanelLight, 1).Parent = callerCard
	UIKit.padding(16).Parent = callerCard

	local portrait = UIKit.new("Frame", {
		Name = "Portrait",
		Size = UDim2.new(0, 96, 0, 96),
		Position = UDim2.new(0.5, -48, 0, 4),
		BackgroundColor3 = T.Accent,
		BorderSizePixel = 0,
		Parent = callerCard,
	})
	UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0) }).Parent = portrait
	local initials = UIKit.label({
		Name = "Initials",
		Text = "??",
		Font = UIKit.HeadlineFont,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = portrait,
	})

	local face = UIKit.label({
		Name = "Face",
		Text = "🙂",
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(52, 44),
		ZIndex = 3,
		Parent = portrait,
	})

	local callerName = UIKit.label({
		Name = "Name",
		Text = "Connecting...",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 108),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = callerCard,
	})

	local callerSub = UIKit.label({
		Name = "Sub",
		Text = "",
		TextSize = 14,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 132),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = callerCard,
	})

	local callerBackstory = UIKit.label({
		Name = "Backstory",
		Text = "",
		TextSize = 13,
		TextColor3 = T.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 0, 0, 156),
		Size = UDim2.new(1, 0, 0, 72),
		Parent = callerCard,
	})

	local meterHolder = UIKit.new("Frame", {
		Name = "Meters",
		Position = UDim2.new(0, 0, 0, 234),
		Size = UDim2.new(1, 0, 0, 140),
		BackgroundTransparency = 1,
		Parent = callerCard,
	})
	UIKit.listLayout({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }).Parent = meterHolder

	local trustMeter = UIKit.meter("Trust", T.Trust, 1)
	trustMeter.holder.Parent = meterHolder
	local suspicionMeter = UIKit.meter("Suspicion", T.Suspicion, 2)
	suspicionMeter.holder.Parent = meterHolder
	local patienceMeter = UIKit.meter("Patience", T.Patience, 3)
	patienceMeter.holder.Parent = meterHolder

	-- Right: dialogue
	local dialogue = UIKit.panel({
		Name = "Dialogue",
		Position = UDim2.new(0, 332, 0, 80),
		Size = UDim2.new(1, -348, 0, 430),
		Parent = call,
	})
	UIKit.stroke(T.PanelLight, 1).Parent = dialogue
	UIKit.padding(16).Parent = dialogue

	local stageLabel = UIKit.label({
		Name = "Stage",
		Text = "Stage 1 of 7 - Introduction",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = T.Accent,
		Size = UDim2.new(1, -160, 0, 20),
		Parent = dialogue,
	})

	local timerLabel = UIKit.label({
		Name = "Timer",
		Text = "00:00",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 80, 0, 20),
		Parent = dialogue,
	})

	local stageTrack = UIKit.new("Frame", {
		Name = "StageTrack",
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
		Parent = dialogue,
	})
	UIKit.corner(3).Parent = stageTrack
	local stageFill = UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = T.Accent,
		BorderSizePixel = 0,
		Parent = stageTrack,
	})
	UIKit.corner(3).Parent = stageFill

	local eventBanner = UIKit.panel({
		Name = "EventBanner",
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = T.Gold,
		Visible = false,
		Parent = dialogue,
	})
	local eventText = UIKit.label({
		Name = "Text",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(30, 26, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = eventBanner,
	})

	local npcLine = UIKit.label({
		Name = "NPCLine",
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 19,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 0, 0, 76),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = dialogue,
	})

	local promptLine = UIKit.label({
		Name = "Prompt",
		Text = "",
		TextSize = 16,
		TextColor3 = T.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 0, 0, 140),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = dialogue,
	})

	local feedbackLabel = UIKit.label({
		Name = "Feedback",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 26),
		Size = UDim2.new(0, 220, 0, 20),
		Parent = dialogue,
	})

	local choiceHolder = UIKit.new("Frame", {
		Name = "Choices",
		Position = UDim2.new(0, 0, 0, 192),
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundTransparency = 1,
		Parent = dialogue,
	})
	UIKit.listLayout({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }).Parent = choiceHolder

	local choiceButtons = {}
	for index = 1, Config.Call.MaxChoices do
		local button = UIKit.button({
			Name = "Choice" .. index,
			Text = "",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = index,
			BackgroundColor3 = T.PanelLight,
			Visible = false,
			Parent = choiceHolder,
		})
		UIKit.padding(10).Parent = button
		choiceButtons[index] = button
	end

	-- Robux consumables usable mid-call. Populated by the client.
	local itemRow = UIKit.new("Frame", {
		Name = "Items",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -150, 0, 36),
		BackgroundTransparency = 1,
		Parent = dialogue,
	})
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = itemRow

	local hangUp = UIKit.button({
		Name = "HangUp",
		Text = "HANG UP",
		Font = Enum.Font.GothamBold,
		BackgroundColor3 = T.Danger,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0, 140, 0, 36),
		Parent = dialogue,
	})

	----------------------------------------------------------------------------
	-- Result screen
	----------------------------------------------------------------------------
	local result = overlay("Result", "Call Summary")
	result.frame.Parent = gui
	result.close.Text = "Back To Desk"
	result.close.Size = UDim2.new(0, 140, 0, 32)

	local resultOutcome = UIKit.label({
		Name = "Outcome",
		Text = "",
		Font = UIKit.HeadlineFont,
		TextSize = 32,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
		Parent = result.body,
	})
	local resultLine = UIKit.label({
		Name = "Line",
		Text = "",
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = T.SubText,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 2,
		Parent = result.body,
	})
	local resultDetail = UIKit.label({
		Name = "Detail",
		Text = "",
		TextSize = 15,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 70),
		LayoutOrder = 3,
		Parent = result.body,
	})
	local resultReward = UIKit.label({
		Name = "Reward",
		Text = "",
		Font = UIKit.HeadlineFont,
		TextSize = 34,
		TextColor3 = T.Gold,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 4,
		Parent = result.body,
	})
	local resultBreakdown = UIKit.new("Frame", {
		Name = "Breakdown",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = result.body,
	})
	UIKit.listLayout({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }).Parent = resultBreakdown

	local resultAchievements = UIKit.new("Frame", {
		Name = "Achievements",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		Parent = result.body,
	})
	UIKit.listLayout({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }).Parent = resultAchievements

	----------------------------------------------------------------------------
	-- Shop, career and help overlays
	----------------------------------------------------------------------------
	local shop = overlay("Shop", "Desk Upgrades")
	shop.frame.Parent = gui
	local shopCredits = UIKit.label({
		Name = "ShopCredits",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = T.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -112, 0, 20),
		Size = UDim2.new(0, 200, 0, 22),
		ZIndex = 22,
		Parent = shop.panel,
	})

	local career = overlay("Career", "Career")
	career.frame.Parent = gui

	local operation = overlay("Operation", "The Operation")
	operation.frame.Parent = gui
	operation.panel.Size = UDim2.new(0, 820, 0, 580)
	local operationSummary = UIKit.label({
		Name = "Summary",
		Text = "",
		TextSize = 13,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -112, 0, 18),
		Size = UDim2.new(0, 420, 0, 32),
		TextWrapped = true,
		ZIndex = 22,
		Parent = operation.panel,
	})

	local store = overlay("Store", "Robux Store")
	store.frame.Parent = gui
	local storeNote = UIKit.label({
		Name = "Note",
		Text = "Cosmetics and conveniences only. Nothing here reveals who is on the call.",
		TextSize = 13,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -112, 0, 20),
		Size = UDim2.new(0, 330, 0, 22),
		ZIndex = 22,
		Parent = store.panel,
	})

	local help = overlay("Help", "How To Play")
	help.frame.Parent = gui
	local helpText = UIKit.label({
		Name = "HelpText",
		Text = table.concat({
			"You work in a fictional call centre. Everything here is satire - the company, the",
			"products, the 'instructions' and the cards are all made up, and none of it works",
			"on real people. Do not try any of this outside the game.",
			"",
			"HOW A CALL WORKS",
			"- Each call runs through 7 stages. Clear a stage by picking good lines.",
			"- Trust goes up when your line suits that caller's personality.",
			"- Suspicion goes up when it does not. At 100 suspicion they hang up.",
			"- Patience drains over time and when you rush or shout. At 0 they get bored.",
			"- Reach the final stage with enough Trust and the fictional call succeeds.",
			"",
			"READING THE CALLER",
			"- A friendly pensioner rewards patience and small talk.",
			"- A tech-savvy teenager punishes jargon and authority.",
			"- Some callers - baiters, police desks, rival call centres - can never be won.",
			"- On Hard and above the meters are hidden, so judge them by what they say.",
			"",
			"PROGRESSION",
			"- Successful calls pay Call Centre Credits. Spend them on desk upgrades.",
			"- Lifetime earnings and successful calls raise your rank.",
			"- Higher ranks unlock harder difficulties and extra dialogue options.",
		}, "\n"),
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 520),
		LayoutOrder = 1,
		Parent = help.body,
	})

	----------------------------------------------------------------------------
	-- Toasts
	----------------------------------------------------------------------------
	local toasts = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 80),
		Size = UDim2.new(0, 320, 0, 400),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = gui,
	})
	UIKit.listLayout({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }).Parent = toasts

	return {
		gui = gui,
		topBar = {
			frame = topBar,
			credits = creditsLabel,
			rank = rankLabel,
			shopButton = shopButton,
			storeButton = storeButton,
			boost = boostLabel,
			statsButton = statsButton,
			helpButton = helpButton,
			brand = brand,
			streakPill = streakPill,
			streakLabel = streakLabel,
		},
		ticker = { frame = tickerFrame, label = tickerLabel },
		home = {
			frame = home,
			difficultyRow = difficultyRow,
			blurb = difficultyBlurb,
			startButton = startButton,
		},
		call = {
			frame = call,
			portrait = portrait,
			initials = initials,
			face = face,
			name = callerName,
			sub = callerSub,
			backstory = callerBackstory,
			meters = { trust = trustMeter, suspicion = suspicionMeter, patience = patienceMeter },
			stageLabel = stageLabel,
			stageFill = stageFill,
			timer = timerLabel,
			eventBanner = eventBanner,
			eventText = eventText,
			npcLine = npcLine,
			prompt = promptLine,
			feedback = feedbackLabel,
			choiceButtons = choiceButtons,
			itemRow = itemRow,
			hangUp = hangUp,
		},
		result = {
			frame = result.frame,
			close = result.close,
			outcome = resultOutcome,
			line = resultLine,
			detail = resultDetail,
			reward = resultReward,
			breakdown = resultBreakdown,
			achievements = resultAchievements,
			header = result.header,
		},
		shop = { frame = shop.frame, close = shop.close, body = shop.body, credits = shopCredits },
		store = { frame = store.frame, close = store.close, body = store.body, note = storeNote },
		operation = {
			frame = operation.frame,
			close = operation.close,
			body = operation.body,
			summary = operationSummary,
			button = operationButton,
			hud = {
				panel = ops,
				method = opsMethod,
				income = opsIncome,
				staff = opsStaff,
				heat = heatMeter,
				heatRate = opsHeatRate,
				layLow = layLowButton,
				open = opsOpenButton,
			},
		},
		career = { frame = career.frame, close = career.close, body = career.body },
		help = { frame = help.frame, close = help.close, body = help.body, text = helpText },
		toasts = toasts,
	}
end

return Interface
