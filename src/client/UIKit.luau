--!nonstrict
-- UIKit
-- Tiny declarative helpers so Interface.luau can build the whole GUI in code.
-- Nothing in this game needs to be laid out by hand in Studio.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)

local UIKit = {}

UIKit.Theme = Config.UI.Theme

-- new("Frame", { Size = ... }, { childA, childB })
function UIKit.new(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UIKit.corner(radius: number)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UIKit.stroke(colour: Color3, thickness: number?, transparency: number?)
	return UIKit.new("UIStroke", {
		Color = colour,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(all: number, extra)
	extra = extra or {}
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, extra.top or all),
		PaddingBottom = UDim.new(0, extra.bottom or all),
		PaddingLeft = UDim.new(0, extra.left or all),
		PaddingRight = UDim.new(0, extra.right or all),
	})
end

function UIKit.listLayout(props)
	return UIKit.new("UIListLayout", props or {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
end

function UIKit.panel(props, children)
	local merged = {
		BackgroundColor3 = UIKit.Theme.Panel,
		BorderSizePixel = 0,
	}
	for key, value in pairs(props or {}) do
		merged[key] = value
	end
	local frame = UIKit.new("Frame", merged, children)
	UIKit.corner(10).Parent = frame
	return frame
end

function UIKit.label(props)
	local merged = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for key, value in pairs(props or {}) do
		merged[key] = value
	end
	return UIKit.new("TextLabel", merged)
end

function UIKit.button(props)
	local merged = {
		BackgroundColor3 = UIKit.Theme.PanelLight,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 16,
		AutoButtonColor = false,
	}
	for key, value in pairs(props or {}) do
		merged[key] = value
	end
	local button = UIKit.new("TextButton", merged)
	UIKit.corner(8).Parent = button

	-- Hover reads the colour at hover time rather than at creation time, so a
	-- button that is later restyled (a selected difficulty, an owned upgrade)
	-- does not snap back to its original colour when the mouse leaves.
	local restoreColour: Color3? = nil
	button.MouseEnter:Connect(function()
		if not button.Active or restoreColour then
			return
		end
		restoreColour = button.BackgroundColor3
		UIKit.tween(button, { BackgroundColor3 = button.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.12) }, 0.12)
	end)
	button.MouseLeave:Connect(function()
		if restoreColour then
			UIKit.tween(button, { BackgroundColor3 = restoreColour }, 0.12)
			restoreColour = nil
		end
	end)

	return button
end

function UIKit.tween(instance: Instance, goal, duration: number?, style: Enum.EasingStyle?)
	local info = TweenInfo.new(
		duration or Config.UI.TweenTime,
		style or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- A labelled meter with an animated fill.
function UIKit.meter(name: string, colour: Color3, layoutOrder: number)
	local holder = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
	})

	local title = UIKit.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 16),
		Text = name,
		TextSize = 13,
		TextColor3 = UIKit.Theme.SubText,
		Parent = holder,
	})

	local valueLabel = UIKit.label({
		Name = "Value",
		Size = UDim2.new(1, 0, 0, 16),
		Text = "0",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = colour,
		Parent = holder,
	})

	local track = UIKit.new("Frame", {
		Name = "Track",
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = UIKit.Theme.Background,
		BorderSizePixel = 0,
		Parent = holder,
	})
	UIKit.corner(6).Parent = track

	local fill = UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		Parent = track,
	})
	UIKit.corner(6).Parent = fill

	return {
		holder = holder,
		title = title,
		value = valueLabel,
		fill = fill,
		track = track,
	}
end

function UIKit.setMeter(meter, view)
	if not view then
		return
	end
	if view.mode == "hidden" then
		meter.value.Text = "???"
		UIKit.tween(meter.fill, { Size = UDim2.new(1, 0, 1, 0) }, 0.3)
		meter.fill.BackgroundTransparency = 0.75
	elseif view.mode == "vague" then
		meter.value.Text = view.label
		meter.fill.BackgroundTransparency = 0.5
		UIKit.tween(meter.fill, { Size = UDim2.new(0.5, 0, 1, 0) }, 0.3)
	else
		meter.value.Text = view.label
		meter.fill.BackgroundTransparency = 0
		UIKit.tween(meter.fill, { Size = UDim2.new(math.clamp(view.ratio, 0, 1), 0, 1, 0) }, 0.3)
	end
end

-- Fades a frame in or out and flips Visible at the right moment.
function UIKit.setVisible(frame: GuiObject, visible: boolean, slide: boolean?)
	if visible then
		frame.Visible = true
		frame.BackgroundTransparency = frame:GetAttribute("BaseTransparency") or frame.BackgroundTransparency
		if slide then
			frame.Position = frame:GetAttribute("BasePosition") or frame.Position
		end
	else
		frame.Visible = false
	end
end

return UIKit
