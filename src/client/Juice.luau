--!nonstrict
-- Juice
-- Feedback effects: floating numbers, screen flashes, shakes, confetti, a
-- count-up and the server-wide ticker. None of it changes what happens in the
-- game; all of it changes how it feels to play.
--
-- Sounds are wired but silent: drop asset ids into Juice.Sounds and they start
-- playing. Nothing here references an asset id it cannot verify.

local SoundService = game:GetService("SoundService")

local UIKit = require(script.Parent.UIKit)

local Juice = {}
local T = UIKit.Theme

-- Fill these in with your own asset ids ("rbxassetid://123") to add audio.
Juice.Sounds = {
	choice = "",
	good = "",
	bad = "",
	success = "",
	fail = "",
	cash = "",
	rankUp = "",
	alarm = "",
}

local layers = {
	popups = nil,
	flash = nil,
	confetti = nil,
	ticker = nil,
}

local soundCache = {}

function Juice.play(name: string, volume: number?)
	local id = Juice.Sounds[name]
	if not id or id == "" then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Juice_" .. name
		sound.SoundId = id
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	sound.Volume = volume or 0.5
	sound:Play()
end

function Juice.init(gui: ScreenGui)
	layers.popups = UIKit.new("Frame", {
		Name = "JuicePopups",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Active = false,
		Parent = gui,
	})

	layers.confetti = UIKit.new("Frame", {
		Name = "JuiceConfetti",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 49,
		Active = false,
		Parent = gui,
	})

	layers.flash = UIKit.new("Frame", {
		Name = "JuiceFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 48,
		Active = false,
		Parent = gui,
	})
	return layers
end

--------------------------------------------------------------------------------
-- Floating numbers
--------------------------------------------------------------------------------

-- anchor: a GuiObject to appear next to, or nil for the centre of the screen.
function Juice.popup(text: string, colour: Color3, anchor: GuiObject?, options)
	if not layers.popups then
		return
	end
	options = options or {}

	local x, y
	if anchor and anchor.AbsoluteSize.X > 0 then
		x = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X / 2
		y = anchor.AbsolutePosition.Y
	else
		x = layers.popups.AbsoluteSize.X / 2
		y = layers.popups.AbsoluteSize.Y * 0.4
	end
	x += (options.offsetX or 0)
	y += (options.offsetY or 0)

	local label = UIKit.label({
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = options.size or 28,
		TextColor3 = colour,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(12, 12, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(260, 40),
		ZIndex = 51,
		Parent = layers.popups,
	})

	-- Small random drift so a burst of popups does not stack into one blob.
	local drift = math.random(-26, 26)
	local rise = options.rise or 70
	UIKit.tween(label, {
		Position = UDim2.fromOffset(x + drift, y - rise),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}, options.duration or 0.9, Enum.EasingStyle.Quad)

	-- A quick punch on the way in.
	label.TextSize = (options.size or 28) * 1.6
	UIKit.tween(label, { TextSize = options.size or 28 }, 0.18, Enum.EasingStyle.Back)

	task.delay((options.duration or 0.9) + 0.1, function()
		label:Destroy()
	end)
	return label
end

--------------------------------------------------------------------------------
-- Screen effects
--------------------------------------------------------------------------------

function Juice.flash(colour: Color3, strength: number?, duration: number?)
	if not layers.flash then
		return
	end
	layers.flash.BackgroundColor3 = colour
	layers.flash.BackgroundTransparency = 1 - (strength or 0.35)
	UIKit.tween(layers.flash, { BackgroundTransparency = 1 }, duration or 0.45)
end

-- Shakes a GuiObject around wherever it currently sits.
function Juice.shake(object: GuiObject, intensity: number?, duration: number?)
	if not object then
		return
	end
	local home = object:GetAttribute("JuiceHome")
	if not home then
		object:SetAttribute("JuiceHome", true)
	end
	local base = object.Position
	local power = intensity or 8
	local finish = os.clock() + (duration or 0.3)

	task.spawn(function()
		while os.clock() < finish do
			object.Position = base + UDim2.fromOffset(math.random(-power, power), math.random(-power, power))
			task.wait(0.03)
		end
		object.Position = base
	end)
end

function Juice.pulse(object: GuiObject, amount: number?)
	if not object then
		return
	end
	local base = object.Size
	local grow = amount or 0.06
	local target = UDim2.new(
		base.X.Scale * (1 + grow),
		base.X.Offset * (1 + grow),
		base.Y.Scale * (1 + grow),
		base.Y.Offset * (1 + grow)
	)
	UIKit.tween(object, { Size = target }, 0.09, Enum.EasingStyle.Quad)
	task.delay(0.1, function()
		UIKit.tween(object, { Size = base }, 0.14, Enum.EasingStyle.Back)
	end)
end

function Juice.confetti(count: number?)
	if not layers.confetti then
		return
	end
	local colours = {
		Color3.fromRGB(255, 92, 132),
		Color3.fromRGB(96, 220, 255),
		Color3.fromRGB(255, 214, 92),
		Color3.fromRGB(140, 255, 160),
		Color3.fromRGB(196, 140, 255),
	}
	local width = math.max(1, layers.confetti.AbsoluteSize.X)

	for _ = 1, (count or 40) do
		local piece = UIKit.new("Frame", {
			Size = UDim2.fromOffset(math.random(6, 14), math.random(8, 18)),
			Position = UDim2.fromOffset(math.random(0, width), math.random(-120, -20)),
			BackgroundColor3 = colours[math.random(1, #colours)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 49,
			Parent = layers.confetti,
		})
		UIKit.corner(3).Parent = piece

		local fall = math.random(12, 22) / 10
		UIKit.tween(piece, {
			Position = piece.Position + UDim2.fromOffset(math.random(-160, 160), layers.confetti.AbsoluteSize.Y + 200),
			Rotation = piece.Rotation + math.random(-540, 540),
			BackgroundTransparency = 1,
		}, fall, Enum.EasingStyle.Linear)

		task.delay(fall + 0.1, function()
			piece:Destroy()
		end)
	end
end

--------------------------------------------------------------------------------
-- Count-up, for reward numbers
--------------------------------------------------------------------------------

local countTokens = {}

function Juice.countUp(label: TextLabel, from: number, to: number, format, duration: number?)
	countTokens[label] = (countTokens[label] or 0) + 1
	local token = countTokens[label]
	local time = duration or 0.8

	task.spawn(function()
		local start = os.clock()
		while true do
			if countTokens[label] ~= token or not label.Parent then
				return
			end
			local alpha = math.min(1, (os.clock() - start) / time)
			-- Ease out, so it races up then settles.
			local eased = 1 - (1 - alpha) ^ 3
			label.Text = format(math.floor(from + (to - from) * eased))
			if alpha >= 1 then
				return
			end
			task.wait(0.03)
		end
	end)
end

--------------------------------------------------------------------------------
-- Ticker: one line at a time, showing what everyone else is up to.
--------------------------------------------------------------------------------

local tickerQueue = {}
local tickerBusy = false

function Juice.attachTicker(frame: Frame, label: TextLabel)
	layers.ticker = { frame = frame, label = label }
end

local function runTicker()
	if tickerBusy or not layers.ticker then
		return
	end
	local entry = table.remove(tickerQueue, 1)
	if not entry then
		return
	end
	tickerBusy = true

	local frame = layers.ticker.frame
	local label = layers.ticker.label
	label.Text = entry.text
	label.TextColor3 = entry.colour or T.Text

	frame.Visible = true
	frame.BackgroundTransparency = 1
	label.TextTransparency = 1
	UIKit.tween(frame, { BackgroundTransparency = 0.15 }, 0.2)
	UIKit.tween(label, { TextTransparency = 0 }, 0.2)

	task.delay(entry.hold or 3.4, function()
		UIKit.tween(frame, { BackgroundTransparency = 1 }, 0.3)
		UIKit.tween(label, { TextTransparency = 1 }, 0.3)
		task.delay(0.35, function()
			frame.Visible = #tickerQueue > 0
			tickerBusy = false
			runTicker()
		end)
	end)
end

function Juice.ticker(text: string, colour: Color3?, hold: number?)
	table.insert(tickerQueue, { text = text, colour = colour, hold = hold })
	-- Never let a burst of events build an unbounded backlog.
	while #tickerQueue > 6 do
		table.remove(tickerQueue, 1)
	end
	runTicker()
end

--------------------------------------------------------------------------------

-- Mood faces for the caller portrait. Reaction category -> face.
Juice.Faces = {
	greet = "🙂",
	believe = "😊",
	question = "🤨",
	nervous = "😰",
	angry = "😡",
	laugh = "😂",
	accuse = "🤬",
	pretend = "😏",
	waste = "🥱",
	hangup = "📵",
}

function Juice.face(reaction: string?): string
	return Juice.Faces[reaction or "greet"] or "🙂"
end

return Juice
