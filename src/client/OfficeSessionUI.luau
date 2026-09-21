--!nonstrict
-- Consent UI and a management-computer access panel. No permanent HUD entry.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Net = require(Shared.Net)
local Kit = require(script.Parent.UIKit)
local T = Kit.Theme
local OfficeSessionUI = {}

function OfficeSessionUI.init(ui)
	local state, terminalKind = nil, nil
	local render
	local function label(parent, text, y, height)
		return Kit.label({ Text = text, Position = UDim2.new(0, 18, 0, y), Size = UDim2.new(1, -36, 0, height),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 16, ZIndex = 82, Parent = parent })
	end
	local function button(parent, text, x, y, width, callback)
		local b = Kit.button({ Text = text, Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, width, 0, 42),
			TextSize = 16, BackgroundColor3 = T.AccentDark, ZIndex = 83, Parent = parent })
		b.Activated:Connect(callback)
		return b
	end
	local function panel(name, width, height)
		local backdrop = Kit.new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35, Visible = false, Active = true, ZIndex = 80, Parent = ui.gui })
		local body = Kit.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height), ZIndex = 81, Parent = backdrop })
		local scale = Kit.new("UIScale", { Parent = body })
		local function resize()
			local camera = workspace.CurrentCamera
			if camera then scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / width, (camera.ViewportSize.Y - 40) / height) end
		end
		resize()
		if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
		return backdrop, body
	end
	local function act(action, a, b) Net.event("OfficeAction"):FireServer(action, a, b) end
	local chooser, choice = panel("OfficeModeChoice", 600, 286)
	label(choice, "YOUR CALL CENTRE", 18, 28).Font = Enum.Font.GothamBold
	label(choice, "Choose how to start this session. Your office is private until someone explicitly accepts your invitation.", 58, 58)
	button(choice, "SOLO", 18, 126, 272, function() act("choose", "solo") end)
	button(choice, "HOST CO-OP", 310, 126, 272, function() act("choose", "coop") end)
	label(choice, "Solo can invite later. Co-op uses the host's progression and save. Guests help with calls; their own money and purchases stay separate. Use Office Management to invite or remove players.", 190, 80)

	local access, accessBody = panel("OfficeAccess", 620, 470)
	label(accessBody, "OFFICE ACCESS", 18, 28).Font = Enum.Font.GothamBold
	button(accessBody, "Close", 500, 12, 100, function() access.Visible = false end)
	local summary = label(accessBody, "", 60, 72)
	local feedback = label(accessBody, "", 132, 26)
	feedback.TextSize = 13
	feedback.TextColor3 = T.Accent
	local list = Kit.new("ScrollingFrame", { Position = UDim2.fromOffset(18, 164), Size = UDim2.new(1, -36, 1, -182),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6, ZIndex = 82, Parent = accessBody })
	Kit.listLayout({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = list
	local accessButton = button(ui.terminal.frame, "Invite / Access", 0, -50, 150, function()
		access.Visible = true
		task.spawn(function()
			local ok, view = pcall(function() return Net.func("GetOfficeSession"):InvokeServer() end)
			if ok and view then state = view; render() end
		end)
	end)
	accessButton.Visible = false

	local invitation, invitationBody = panel("OfficeInvitation", 560, 244)
	invitation.ZIndex = 90
	local invitationTitle = label(invitationBody, "", 18, 30)
	local invitationNote = label(invitationBody, "", 62, 104)
	local activeInvite
	button(invitationBody, "Accept invite", 18, 180, 250, function()
		if activeInvite then act("respond", activeInvite.id, true) end
	end)
	button(invitationBody, "Decline", 290, 180, 250, function()
		if activeInvite then act("respond", activeInvite.id, false) end
	end)

	render = function()
		if not state then return end
		chooser.Visible = state.needsChoice == true
		summary.Text = string.format("Host: %s | %s\nCalls benefit the host. Only the host spends office credits or uses paid items. Membership lasts for this server session.", state.hostName, state.mode == "coop" and "INVITE-ONLY CO-OP" or "PRIVATE SOLO")
		for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		local order = 0
		local function row(text, actionText, fn)
			order += 1
			local card = Kit.panel({ Size = UDim2.new(1, -8, 0, 52), LayoutOrder = order, ZIndex = 83, Parent = list })
			Kit.label({ Text = text, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -156, 1, -8),
				TextWrapped = true, TextSize = 15, ZIndex = 84, Parent = card })
			if fn then
				local b = button(card, actionText, 0, 5, 126, fn)
				b.AnchorPoint = Vector2.new(1, 0)
				b.Position = UDim2.new(1, -8, 0, 5)
				b.ZIndex = 85
			end
		end
		for _, member in ipairs(state.members or {}) do
			local canRemove = state.canManageAccess and member.userId ~= state.hostUserId
			row(member.name .. (member.userId == state.hostUserId and " (HOST)" or " (GUEST)"), "Remove", canRemove and function() act("revoke", member.userId) end or nil)
		end
		if not state.isHost then
			row("Return to your own private office. Your host's progress stays with them.", "Leave co-op", function() act("leave") end)
		elseif state.canManageAccess then
			for _, candidate in ipairs(state.candidates or {}) do
				row("Invite " .. candidate.name, "Invite", function() act("invite", candidate.userId) end)
			end
			if #(state.candidates or {}) == 0 then row("No other eligible players in this server.") end
		else
			row("Use your own physical Office Management computer to invite or revoke access.")
		end
		activeInvite = state.invitations and state.invitations[1]
		invitation.Visible = activeInvite ~= nil
		if activeInvite then
			invitationTitle.Text = activeInvite.hostName .. " invited you"
			invitationNote.Text = string.format("Join their office as a guest? Calls will earn progress for %s. Your own save and purchases will stay separate. You can leave at their management computer.\nInvitation expires in at most %d seconds.", activeInvite.hostName, activeInvite.expiresIn)
		end
	end
	Net.event("Notify").OnClientEvent:Connect(function(payload)
		if payload.title == "Office Access" then feedback.Text = payload.body end
	end)
	Net.event("OfficeSessionUpdated").OnClientEvent:Connect(function(view)
		if view then state = view; render() end
	end)
	Net.event("TerminalOpened").OnClientEvent:Connect(function(payload)
		terminalKind = payload.kind
		feedback.Text = ""
		accessButton.Visible = terminalKind == "management"
		access.Visible = payload.isGuest and terminalKind == "management"
		if accessButton.Visible then
			task.spawn(function()
				local ok, view = pcall(function() return Net.func("GetOfficeSession"):InvokeServer() end)
				if ok and view then state = view; render() end
			end)
		end
	end)
	Net.event("TerminalClosed").OnClientEvent:Connect(function()
		terminalKind = nil
		accessButton.Visible, access.Visible = false, false
	end)
	task.spawn(function()
		for _ = 1, 20 do
			local ok, view = pcall(function() return Net.func("GetOfficeSession"):InvokeServer() end)
			if ok and view then state = view; render(); return end
			task.wait(0.75)
		end
	end)
end

return OfficeSessionUI
