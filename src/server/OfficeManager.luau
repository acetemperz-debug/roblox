--!nonstrict
-- Physical presentation of the existing saved operation; never computes rewards.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Operation = require(Shared.Operation)
local Util = require(Shared.Util)
local Environment = require(script.Parent.EnvironmentBuilder)
local Data = require(script.Parent.PlayerDataManager)
local Access = require(script.Parent.TerminalAccess)
local OfficeManager = {}
local offices, slots = {}, {}
local onTerminal
local cyan = Color3.fromRGB(30, 225, 235)
local gold = Color3.fromRGB(255, 191, 60)
local pink = Color3.fromRGB(244, 75, 175)
local purple = Color3.fromRGB(133, 92, 235)

local function block(parent, name, size, cf, colour, material)
	return Environment.part({ Name = name, Size = size, CFrame = cf, Color = colour,
		Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end

local function sign(parent, name, cf, text, colour, width)
	local board = block(parent, name, Vector3.new(width or 10, 3, 0.3), cf, Color3.fromRGB(22, 28, 55))
	return Environment.label(board, text, Enum.NormalId.Back, colour)
end

local function terminal(office, kind, title, x, z, colour, canUse)
	local cf = office.origin * CFrame.new(x, 0, z)
	local desk = Environment.buildDesk(office.model, cf, title)
	desk:SetAttribute("OwnerUserId", office.player.UserId)
	desk:SetAttribute("TerminalKind", kind)
	desk.Screen.Color = colour
	sign(desk, "TerminalSign", cf * CFrame.new(0, 7, -1), title, colour, 8)
	local anchor = desk.Screen
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use Computer"
	prompt.ObjectText = title
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false -- server raycast is authoritative
	prompt.HoldDuration = 0.2
	prompt.Parent = anchor
	local spec = { kind = kind, anchor = anchor, model = desk, owner = office.player.UserId, canUse = canUse }
	prompt.Triggered:Connect(function(player)
		if Access.throttle(player, "prompt", 0.4) and Access.near(player, spec) then onTerminal(player, spec) end
	end)
	return desk
end

local function create(player)
	local slot = 1
	while slots[slot] do slot += 1 end
	slots[slot] = player
	local model = Instance.new("Model")
	model.Name = "Office_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = Environment.getRoot()
	local office = { player = player, model = model, slot = slot,
		origin = CFrame.new(240 + ((slot - 1) % 4) * 220, 0, math.floor((slot - 1) / 4) * 240) }
	offices[player] = office
	-- Terminals are stable while the floor expands, so an upgrade cannot strand a session.
	office.desk = terminal(office, "workstation", "CALLS + CAMPAIGNS", -12, 0, cyan)
	terminal(office, "hr", "HR / RECRUITMENT", 0, 0, pink)
	terminal(office, "management", "OFFICE MANAGEMENT", 12, 0, gold)
	terminal(office, "security", "SECURITY / POLICE", -12, 13, Color3.fromRGB(255, 95, 95))
	terminal(office, "premium", "PREMIUM KIOSK", 12, 13, purple)
	office.status = sign(model, "SuspicionBoard", office.origin * CFrame.new(0, 11, -3), "POLICE HEAT: 0", cyan, 23)
	office.upgrades = sign(model, "UpgradeBoard", office.origin * CFrame.new(0, 15, -3), "BACK ROOM", gold, 25)
	local exit = block(model, "LobbyLift", Vector3.new(6, 0.2, 5), office.origin * CFrame.new(0, 0.1, 20), purple, Enum.Material.Neon)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Visit Leaderboards"
	prompt.ObjectText = "Lobby Lift"
	prompt.MaxActivationDistance = 8
	prompt.Parent = exit
	prompt.Triggered:Connect(function(visitor)
		if Access.near(visitor, { anchor = exit, distance = 8 }) and Access.throttle(visitor, "travel", 2) then
			visitor.Character:PivotTo(CFrame.new(0, 4, 44))
		end
	end)
	return office
end

function OfficeManager.teleport(player)
	local office = offices[player]
	if office and player.Character then player.Character:PivotTo(office.origin * CFrame.new(0, 4, 9)) end
end

function OfficeManager.update(player, view)
	if not view then return end
	local firstVisit = offices[player] == nil
	local office = offices[player] or create(player)
	local profile = Data.get(player)
	if not profile then return end
	local facility = Operation.FacilityById[view.facility]
	local tier = facility.index
	local upgrades = 0
	for _, owned in pairs(profile.upgrades or {}) do if owned then upgrades += 1 end end
	office.upgrades.Text = string.format("%s | %s\n%d / %d DESKS  |  %d UPGRADES", player.DisplayName, facility.name, view.summary.headcount, facility.desks, upgrades)
	local paused = view.shutdownRemaining > 0 or view.layLowRemaining > 0
	office.status.Text = string.format("POLICE HEAT  %d / 100\n%s  |  SECURITY %d", math.floor(view.heat),
		paused and "FLOOR PAUSED" or ("+" .. Util.formatNumber(view.summary.netIncome) .. " / SEC"), view.summary.securityRating)
	office.status.TextColor3 = view.heat >= 70 and Color3.fromRGB(255, 85, 95) or cyan
	local signature = view.facility .. ":" .. upgrades .. ":" .. view.summary.securityRating
	if signature ~= office.signature then
		office.signature = signature
		if office.shell then office.shell:Destroy() end
		local shell = Instance.new("Model")
		shell.Name = "Premises"
		shell.Parent = office.model
		office.shell = shell
		local columns = math.min(9, math.max(3, math.ceil(math.sqrt(facility.desks))))
		local rows = math.ceil(facility.desks / columns)
		local width = math.max(44, columns * 11 + 8)
		local depth = 40 + rows * 10
		local centerZ = (depth - 12) / 2
		local floorColour = tier <= 2 and Color3.fromRGB(112, 74, 107) or Color3.fromRGB(30, 61, 85)
		block(shell, "Floor", Vector3.new(width, 1, depth), office.origin * CFrame.new(0, -0.5, centerZ), floorColour,
			tier <= 2 and Enum.Material.WoodPlanks or Enum.Material.Marble)
		block(shell, "Ceiling", Vector3.new(width, 0.6, depth), office.origin * CFrame.new(0, 19, centerZ), Color3.fromRGB(55, 46, 80))
		block(shell, "FrontWall", Vector3.new(width, 19, 1), office.origin * CFrame.new(0, 9.5, -6), Color3.fromRGB(77, 47, 105))
		block(shell, "BackWall", Vector3.new(width, 19, 1), office.origin * CFrame.new(0, 9.5, depth - 6), Color3.fromRGB(43, 88, 110))
		for _, side in ipairs({ -1, 1 }) do
			local glass = block(shell, "CityWindows", Vector3.new(0.5, 19, depth), office.origin * CFrame.new(side * width / 2, 9.5, centerZ), cyan, Enum.Material.Glass)
			glass.Transparency = tier >= 3 and 0.65 or 0.3
			block(shell, "NeonRail", Vector3.new(0.4, 0.4, depth), office.origin * CFrame.new(side * (width / 2 - 0.4), 1, centerZ), side == 1 and pink or cyan, Enum.Material.Neon)
			for z = 0, depth - 10, 16 do
				block(shell, "WindowFrame", Vector3.new(0.8, 19, 0.5), office.origin * CFrame.new(side * width / 2, 9.5, z), gold)
				local height = 22 + ((z * 7 + tier * 13) % 40)
				local tower = block(shell, "Skyline", Vector3.new(12, height, 12), office.origin * CFrame.new(side * (width / 2 + 25), height / 2 - 10, z), Color3.fromRGB(34, 44, 78))
				for y = 0, height - 5, 8 do
					block(shell, "CityLights", Vector3.new(12.2, 1.5, 12.2), tower.CFrame * CFrame.new(0, y - height / 2 + 3, 0), gold, Enum.Material.Neon)
				end
			end
		end
		for z = 10, depth - 10, 24 do
			local lamp = block(shell, "WarmLight", Vector3.new(width - 8, 0.2, 1), office.origin * CFrame.new(0, 18.5, z), gold, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 210, 155)
			light.Brightness = 0.7
			light.Range = 32
			light.Parent = lamp
		end
		for index = 1, facility.desks do
			local x = ((index - 1) % columns - (columns - 1) / 2) * 11
			local z = 32 + math.floor((index - 1) / columns) * 10
			local desk = Environment.buildDesk(shell, office.origin * CFrame.new(x, 0, z), "StaffDesk_" .. index)
			desk.Screen.Color = index % 2 == 0 and cyan or purple
		end
		if tier >= 4 then
			for _, x in ipairs({ -width / 2 + 4, width / 2 - 4 }) do
				block(shell, "Planter", Vector3.new(3, 2, 3), office.origin * CFrame.new(x, 1, 18), gold)
				block(shell, "Topiary", Vector3.new(3, 5, 3), office.origin * CFrame.new(x, 4, 18), Color3.fromRGB(57, 198, 124))
			end
		end
		for index = 1, math.min(8, view.summary.securityRating) do
			block(shell, "SecurityCamera", Vector3.new(0.8, 0.6, 1.5), office.origin * CFrame.new(-width / 2 + 2, 14, index * 8), cyan)
		end
		office.desk.PrimaryPart.Material = upgrades >= 4 and Enum.Material.Metal or Enum.Material.Wood
		office.desk.PrimaryPart.Color = upgrades >= 4 and Color3.fromRGB(35, 39, 70) or Color3.fromRGB(150, 98, 64)
		office.desk.Screen.Size = Vector3.new(2.3 + math.min(upgrades, 10) * 0.12, 1.4, 0.1)
		office.columns = columns
	end
	-- Rebuild workers only when the roster changes, not every income tick.
	local roster = { view.facility }
	for _, employee in ipairs(view.staff) do table.insert(roster, employee.id .. ":" .. employee.held) end
	local rosterKey = table.concat(roster, "|")
	if rosterKey ~= office.rosterKey then
		office.rosterKey = rosterKey
		if office.staff then Environment.removeEmployees(office.staff); office.staff:Destroy() end
		local staff = Instance.new("Model")
		staff.Name = "HiredEmployees"
		staff.Parent = office.model
		office.staff = staff
		local index = 0
		for _, employee in ipairs(view.staff) do
			for _ = 1, employee.held do
				index += 1
				local x = ((index - 1) % office.columns - (office.columns - 1) / 2) * 11
				local z = 35 + math.floor((index - 1) / office.columns) * 10
				local npc = Environment.buildEmployee(staff, office.origin * CFrame.new(x, 0, z), employee.name)
				npc:SetAttribute("EmployeeId", employee.id)
				npc:SetAttribute("OwnerUserId", player.UserId)
				npc.Torso.Color = Color3.fromHSV((employee.tier - 1) / 7, 0.7, 0.95)
				for _, p in ipairs(npc:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
			end
		end
	end
	office.staff:SetAttribute("Paused", paused)
	if firstVisit then OfficeManager.teleport(player) end
end

function OfficeManager.start(callback)
	onTerminal = callback
	local lobby = Environment.getRoot()
	local lift = block(lobby, "OfficeLift", Vector3.new(8, 1, 6), CFrame.new(0, 0.5, 44), purple, Enum.Material.Neon)
	sign(lobby, "OfficeLiftSign", CFrame.new(0, 6, 42), "YOUR OFFICE\nUSE THE LIFT", gold)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Return to My Office"
	prompt.MaxActivationDistance = 10
	prompt.Parent = lift
	prompt.Triggered:Connect(function(player)
		if Access.near(player, { anchor = lift }) and Access.throttle(player, "travel", 2) then OfficeManager.teleport(player) end
	end)
	local function joined(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(function()
				local root = character:WaitForChild("HumanoidRootPart", 15)
				local deadline = os.clock() + 30
				while player.Parent and not offices[player] and os.clock() < deadline do task.wait(0.2) end
				if root and player.Character == character then OfficeManager.teleport(player) end
			end)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in ipairs(Players:GetPlayers()) do joined(player) end
	Players.PlayerRemoving:Connect(function(player)
		local office = offices[player]
		if office then
			Environment.removeEmployees(office.model)
			office.model:Destroy()
			slots[office.slot] = nil
			offices[player] = nil
		end
	end)
end

return OfficeManager
