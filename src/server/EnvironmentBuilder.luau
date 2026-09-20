--!nonstrict
-- EnvironmentBuilder
-- Builds the whole call centre out of parts at runtime, so nothing has to be
-- placed by hand in Studio. Everything it creates lives under
-- workspace/CallCentre and is rebuilt cleanly on each server start.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local EnvironmentBuilder = {}

local ROOT_NAME = "CallCentre"
local employees = {}

EnvironmentBuilder._connection = nil

local THEME = {
	Floor = Color3.fromRGB(58, 62, 74),
	Carpet = Color3.fromRGB(42, 47, 64),
	-- Mid-tone walls. The old near-white ones plus 25 point lights washed the
	-- whole room out to a flat white.
	Wall = Color3.fromRGB(78, 84, 104),
	WallTrim = Color3.fromRGB(52, 57, 74),
	Desk = Color3.fromRGB(124, 96, 70),
	DeskLegs = Color3.fromRGB(70, 74, 86),
	Monitor = Color3.fromRGB(32, 34, 42),
	Screen = Config.Environment.ScreenColour,
	Chair = Color3.fromRGB(38, 42, 54),
	Glass = Color3.fromRGB(180, 220, 235),
	Accent = Color3.fromRGB(86, 140, 255),
}

local function part(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

local function label(parent: BasePart, text: string, face: Enum.NormalId, colour: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(400, 150)
	gui.LightInfluence = 0
	gui.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = colour or Color3.fromRGB(255, 255, 255)
	textLabel.Parent = gui
	return textLabel
end

--------------------------------------------------------------------------------
-- Props
--------------------------------------------------------------------------------

local function buildDesk(parent: Instance, cframe: CFrame, name: string)
	local model = Instance.new("Model")
	model.Name = name

	local top = part({
		Size = Vector3.new(7, 0.3, 3.5),
		CFrame = cframe * CFrame.new(0, 3, 0),
		Color = THEME.Desk,
		Material = Enum.Material.Wood,
		Parent = model,
	})

	for _, offset in ipairs({ Vector3.new(-3.2, 0, -1.4), Vector3.new(3.2, 0, -1.4), Vector3.new(-3.2, 0, 1.4), Vector3.new(3.2, 0, 1.4) }) do
		part({
			Size = Vector3.new(0.25, 3, 0.25),
			CFrame = cframe * CFrame.new(offset.X, 1.5, offset.Z),
			Color = THEME.DeskLegs,
			Parent = model,
		})
	end

	-- Monitor and a glowing screen.
	part({
		Size = Vector3.new(2.6, 1.7, 0.2),
		CFrame = cframe * CFrame.new(0, 4.1, -0.8),
		Color = THEME.Monitor,
		Parent = model,
	})
	local screen = part({
		Size = Vector3.new(2.3, 1.4, 0.1),
		CFrame = cframe * CFrame.new(0, 4.1, -0.68),
		Color = THEME.Screen,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	screen.Name = "Screen"
	part({
		Size = Vector3.new(0.6, 0.6, 0.4),
		CFrame = cframe * CFrame.new(0, 3.3, -0.8),
		Color = THEME.Monitor,
		Parent = model,
	})

	-- Keyboard, mug, headset hook.
	part({
		Size = Vector3.new(2.2, 0.12, 0.8),
		CFrame = cframe * CFrame.new(0, 3.2, 0.5),
		Color = Color3.fromRGB(40, 42, 50),
		Parent = model,
	})
	part({
		Size = Vector3.new(0.5, 0.6, 0.5),
		CFrame = cframe * CFrame.new(2.3, 3.45, 0.4),
		Color = Color3.fromRGB(230, 230, 230),
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})

	-- Chair.
	part({
		Size = Vector3.new(2, 0.3, 2),
		CFrame = cframe * CFrame.new(0, 2, 3),
		Color = THEME.Chair,
		Parent = model,
	})
	part({
		Size = Vector3.new(2, 2.2, 0.3),
		CFrame = cframe * CFrame.new(0, 3, 3.9),
		Color = THEME.Chair,
		Parent = model,
	})
	part({
		Size = Vector3.new(0.3, 2, 0.3),
		CFrame = cframe * CFrame.new(0, 1, 3),
		Color = Color3.fromRGB(60, 64, 76),
		Parent = model,
	})

	model.PrimaryPart = top
	model.Parent = parent
	return model
end

-- Very simple blocky employee. Animated by EnvironmentBuilder's heartbeat loop.
local function buildEmployee(parent: Instance, cframe: CFrame, name: string)
	local model = Instance.new("Model")
	model.Name = "Employee_" .. name

	local shirtColour = Color3.fromHSV(Util.newRandom():NextNumber(), 0.35, 0.8)

	local torso = part({
		Size = Vector3.new(2, 2, 1),
		CFrame = cframe * CFrame.new(0, 3, 0),
		Color = shirtColour,
		Parent = model,
	})
	torso.Name = "Torso"

	local head = part({
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = cframe * CFrame.new(0, 4.6, 0),
		Color = Color3.fromRGB(234, 200, 170),
		Parent = model,
	})
	head.Name = "Head"

	-- Headset.
	part({
		Size = Vector3.new(1.4, 0.2, 1.4),
		CFrame = cframe * CFrame.new(0, 5.2, 0),
		Color = Color3.fromRGB(28, 30, 38),
		Parent = model,
	})

	local leftArm = part({
		Size = Vector3.new(0.7, 1.8, 0.7),
		CFrame = cframe * CFrame.new(-1.35, 3, -0.3),
		Color = shirtColour,
		Parent = model,
	})
	leftArm.Name = "LeftArm"

	local rightArm = part({
		Size = Vector3.new(0.7, 1.8, 0.7),
		CFrame = cframe * CFrame.new(1.35, 3, -0.3),
		Color = shirtColour,
		Parent = model,
	})
	rightArm.Name = "RightArm"

	local legs = part({
		Size = Vector3.new(1.8, 2, 1),
		CFrame = cframe * CFrame.new(0, 1.5, 0.4),
		Color = Color3.fromRGB(52, 56, 68),
		Parent = model,
	})
	legs.Name = "Legs"

	-- Floating name / speech bubble.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 46)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = false
	billboard.Adornee = head
	billboard.Parent = head

	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	bubble.BackgroundTransparency = 0.25
	bubble.TextColor3 = Color3.fromRGB(240, 240, 245)
	bubble.Font = Enum.Font.Gotham
	bubble.TextSize = 14
	bubble.Text = ""
	bubble.Visible = false
	bubble.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bubble

	model.PrimaryPart = torso
	model.Parent = parent

	table.insert(employees, {
		model = model,
		torso = torso,
		head = head,
		leftArm = leftArm,
		rightArm = rightArm,
		baseCFrame = cframe,
		bubble = bubble,
		state = "typing",
		stateTimer = Util.newRandom():NextNumber(2, 8),
		phase = Util.newRandom():NextNumber(0, 10),
	})

	return model
end

local function buildRoomShell(parent: Instance)
	part({
		Size = Vector3.new(140, 1, 120),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = THEME.Carpet,
		Material = Enum.Material.Fabric,
		Parent = parent,
		Name = "Floor",
	})
	part({
		Size = Vector3.new(140, 1, 120),
		CFrame = CFrame.new(0, 24, 0),
		Color = Color3.fromRGB(236, 236, 240),
		Parent = parent,
		Name = "Ceiling",
	})

	local walls = {
		{ Vector3.new(140, 24, 2), CFrame.new(0, 12, -60) },
		{ Vector3.new(140, 24, 2), CFrame.new(0, 12, 60) },
		{ Vector3.new(2, 24, 120), CFrame.new(-70, 12, 0) },
		{ Vector3.new(2, 24, 120), CFrame.new(70, 12, 0) },
	}
	for index, wall in ipairs(walls) do
		part({
			Size = wall[1],
			CFrame = wall[2],
			Color = THEME.Wall,
			Parent = parent,
			Name = "Wall" .. index,
		})
	end

	-- Ceiling lights. Every fixture glows (Neon costs nothing), but only a
	-- sparse grid of them actually casts light -- 25 overlapping PointLights at
	-- brightness 1.2 is what blew the room out to white.
	for x = -50, 50, 25 do
		for z = -40, 40, 20 do
			local lightPart = part({
				Size = Vector3.new(8, 0.3, 4),
				CFrame = CFrame.new(x, 23.4, z),
				Color = Config.Environment.CeilingLightColour,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
			if (x + 50) % 50 == 0 and (z + 40) % 40 == 0 then
				local light = Instance.new("PointLight")
				light.Brightness = Config.Environment.CeilingLightBrightness
				light.Range = Config.Environment.CeilingLightRange
				light.Color = Config.Environment.CeilingLightColour
				light.Parent = lightPart
			end
		end
	end

	-- Accent strips down the long walls, purely decorative.
	for _, z in ipairs({ -59, 59 }) do
		part({
			Size = Vector3.new(120, 0.5, 0.3),
			CFrame = CFrame.new(0, 17, z),
			Color = Config.Environment.StripColourA,
			Material = Enum.Material.Neon,
			Parent = parent,
			Name = "AccentStrip",
		})
	end
	for _, x in ipairs({ -69, 69 }) do
		part({
			Size = Vector3.new(0.3, 0.5, 110),
			CFrame = CFrame.new(x, 17, 0),
			Color = Config.Environment.StripColourB,
			Material = Enum.Material.Neon,
			Parent = parent,
			Name = "AccentStrip",
		})
	end
end

local function buildSignage(parent: Instance)
	local sign = part({
		Size = Vector3.new(34, 6, 0.5),
		CFrame = CFrame.new(0, 16, -58.5),
		Color = Color3.fromRGB(24, 28, 40),
		Parent = parent,
		Name = "MainSign",
	})
	label(sign, "MACROSOFT SUPPORT\n(not a real company)", Enum.NormalId.Front, THEME.Accent)

	local disclaimer = part({
		Size = Vector3.new(26, 4, 0.4),
		CFrame = CFrame.new(0, 8.5, -58.5),
		Color = Color3.fromRGB(38, 42, 56),
		Parent = parent,
		Name = "Disclaimer",
	})
	label(disclaimer, "A SATIRE. Everything here is fictional.\nNever do any of this to a real person.", Enum.NormalId.Front, Color3.fromRGB(240, 210, 120))
end

local function buildBreakRoom(parent: Instance)
	local room = Instance.new("Model")
	room.Name = "BreakRoom"

	part({ Size = Vector3.new(30, 12, 1), CFrame = CFrame.new(-50, 6, 20), Color = THEME.Wall, Parent = room })
	part({ Size = Vector3.new(1, 12, 40), CFrame = CFrame.new(-35, 6, 40), Color = THEME.Wall, Parent = room })

	-- Coffee machine.
	local machine = part({
		Size = Vector3.new(3, 5, 2),
		CFrame = CFrame.new(-60, 2.5, 30),
		Color = Color3.fromRGB(64, 68, 82),
		Parent = room,
		Name = "CoffeeMachine",
	})
	label(machine, "COFFEE", Enum.NormalId.Front, Color3.fromRGB(230, 180, 120))

	-- Tables.
	for _, pos in ipairs({ Vector3.new(-52, 0, 34), Vector3.new(-44, 0, 44) }) do
		part({ Size = Vector3.new(5, 0.3, 5), CFrame = CFrame.new(pos.X, 3, pos.Z), Color = THEME.Desk, Parent = room })
		part({ Size = Vector3.new(0.5, 3, 0.5), CFrame = CFrame.new(pos.X, 1.5, pos.Z), Color = THEME.DeskLegs, Parent = room })
	end

	local sign = part({ Size = Vector3.new(8, 2, 0.4), CFrame = CFrame.new(-50, 10, 19.5), Color = Color3.fromRGB(30, 34, 46), Parent = room })
	label(sign, "BREAK ROOM", Enum.NormalId.Front, THEME.Accent)

	room.Parent = parent
	return room
end

local function buildBossOffice(parent: Instance)
	local office = Instance.new("Model")
	office.Name = "BossOffice"

	for _, spec in ipairs({
		{ Vector3.new(28, 12, 1), CFrame.new(50, 6, 20) },
		{ Vector3.new(1, 12, 40), CFrame.new(36, 6, 40) },
	}) do
		local glass = part({ Size = spec[1], CFrame = spec[2], Color = THEME.Glass, Parent = office })
		glass.Transparency = 0.55
		glass.Material = Enum.Material.Glass
	end

	part({ Size = Vector3.new(9, 0.4, 4), CFrame = CFrame.new(52, 3.2, 38), Color = Color3.fromRGB(88, 58, 40), Material = Enum.Material.Wood, Parent = office, Name = "BossDesk" })
	part({ Size = Vector3.new(3, 0.3, 3), CFrame = CFrame.new(52, 2.2, 43), Color = Color3.fromRGB(120, 30, 40), Parent = office })
	part({ Size = Vector3.new(3, 3, 0.4), CFrame = CFrame.new(52, 3.6, 44.4), Color = Color3.fromRGB(120, 30, 40), Parent = office })

	local sign = part({ Size = Vector3.new(10, 2, 0.4), CFrame = CFrame.new(50, 10, 19.5), Color = Color3.fromRGB(30, 34, 46), Parent = office })
	label(sign, "MANAGER'S OFFICE", Enum.NormalId.Front, Color3.fromRGB(244, 203, 96))

	-- The Corner Office game pass unlocks this desk. The prompt is always here;
	-- the server refuses it for players who do not own the pass.
	local executive = buildDesk(office, CFrame.new(50, 0, 32), "ExecutiveWorkstation")
	local plate = part({
		Size = Vector3.new(5, 1, 0.3),
		CFrame = CFrame.new(50, 3.8, 33.5),
		Color = Color3.fromRGB(244, 203, 96),
		Parent = executive,
		Name = "Nameplate",
	})
	label(plate, "CORNER OFFICE", Enum.NormalId.Front, Color3.fromRGB(40, 32, 10))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExecutivePrompt"
	prompt.ActionText = "Start Call"
	prompt.ObjectText = "Corner Office"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = executive.PrimaryPart

	office.Parent = parent
	return office
end

local function buildShopKiosk(parent: Instance)
	local kiosk = Instance.new("Model")
	kiosk.Name = "UpgradeShop"

	local counter = part({
		Size = Vector3.new(12, 4, 3),
		CFrame = CFrame.new(-25, 2, -45),
		Color = Color3.fromRGB(46, 52, 70),
		Parent = kiosk,
		Name = "Counter",
	})
	label(counter, "DESK UPGRADES", Enum.NormalId.Front, THEME.Accent)

	local board = part({
		Size = Vector3.new(14, 8, 0.4),
		CFrame = CFrame.new(-25, 9, -47),
		Color = Color3.fromRGB(28, 32, 44),
		Parent = kiosk,
	})
	label(board, "SPEND YOUR\nCALL CENTRE CREDITS", Enum.NormalId.Front, Color3.fromRGB(244, 203, 96))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Upgrade Shop"
	prompt.ObjectText = "Macrosoft Supplies"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Name = "ShopPrompt"
	prompt.Parent = counter

	kiosk.Parent = parent
	return kiosk, prompt
end

-- Board layout. The two career boards sit on the back wall either side of the
-- main sign; the five global difficulty boards run down the right-hand wall.
local LEADERBOARD_SPECS = {
	{ name = "LifetimeEarnings", title = "TOP LIFETIME EARNINGS", cframe = CFrame.new(25, 9, -58), size = Vector3.new(16, 12, 0.6), face = Enum.NormalId.Front },
	{ name = "SuccessfulCalls", title = "MOST SUCCESSFUL CALLS", cframe = CFrame.new(45, 9, -58), size = Vector3.new(16, 12, 0.6), face = Enum.NormalId.Front },
	{ name = "Board_Operation", title = "BIGGEST OPERATIONS", cframe = CFrame.new(-30, 9, -58), size = Vector3.new(16, 12, 0.6), face = Enum.NormalId.Front },
	{ name = "Board_Easy", title = "EASY - MOST WINS", cframe = CFrame.new(69, 9, -40), size = Vector3.new(0.6, 11, 15), face = Enum.NormalId.Left },
	{ name = "Board_Normal", title = "NORMAL - MOST WINS", cframe = CFrame.new(69, 9, -20), size = Vector3.new(0.6, 11, 15), face = Enum.NormalId.Left },
	{ name = "Board_Hard", title = "HARD - MOST WINS", cframe = CFrame.new(69, 9, 0), size = Vector3.new(0.6, 11, 15), face = Enum.NormalId.Left },
	{ name = "Board_Expert", title = "EXPERT - MOST WINS", cframe = CFrame.new(69, 9, 20), size = Vector3.new(0.6, 11, 15), face = Enum.NormalId.Left },
	{ name = "Board_Nightmare", title = "NIGHTMARE - MOST WINS", cframe = CFrame.new(69, 9, 40), size = Vector3.new(0.6, 11, 15), face = Enum.NormalId.Left },
}

local function buildLeaderboards(parent: Instance)
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"

	for _, spec in ipairs(LEADERBOARD_SPECS) do
		local board = part({
			Size = spec.size,
			CFrame = spec.cframe,
			Color = Color3.fromRGB(22, 26, 36),
			Parent = boards,
			Name = spec.name,
		})

		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = spec.face
		gui.CanvasSize = Vector2.new(400, 300)
		gui.LightInfluence = 0
		gui.Parent = board

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 40)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 24
		title.TextColor3 = THEME.Accent
		title.Text = spec.title
		title.Parent = gui

		local list = Instance.new("TextLabel")
		list.Name = "Entries"
		list.Position = UDim2.new(0, 10, 0, 45)
		list.Size = UDim2.new(1, -20, 1, -55)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextSize = 18
		list.TextColor3 = Color3.fromRGB(230, 234, 244)
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Text = "Loading..."
		list.Parent = gui
	end

	boards.Parent = parent
	return boards
end

--------------------------------------------------------------------------------
-- Raid visuals. A raid belongs to one player, but the whole server gets to
-- watch the car turn up outside, which is half the fun of it.
--------------------------------------------------------------------------------

local raidModel: Model? = nil
local raidLight: PointLight? = nil

function EnvironmentBuilder.showRaid(playerName: string, seconds: number)
	local root = Workspace:FindFirstChild(ROOT_NAME)
	if not root then
		return
	end
	if raidModel then
		raidModel:Destroy()
		raidModel = nil
	end

	local model = Instance.new("Model")
	model.Name = "PoliceRaid"

	part({
		Size = Vector3.new(6, 3, 12),
		CFrame = CFrame.new(-14, 1.6, -52),
		Color = Color3.fromRGB(235, 235, 240),
		Parent = model,
	})
	part({
		Size = Vector3.new(5.4, 2.2, 5),
		CFrame = CFrame.new(-14, 4.2, -51),
		Color = Color3.fromRGB(60, 64, 76),
		Transparency = 0.35,
		Parent = model,
	})
	part({
		Size = Vector3.new(6.2, 0.8, 3),
		CFrame = CFrame.new(-14, 1.6, -52),
		Color = Color3.fromRGB(40, 90, 200),
		Parent = model,
	})
	for _, offset in ipairs({ Vector3.new(-2.6, -1.2, -4), Vector3.new(2.6, -1.2, -4), Vector3.new(-2.6, -1.2, 4), Vector3.new(2.6, -1.2, 4) }) do
		part({
			Size = Vector3.new(1, 2, 2),
			CFrame = CFrame.new(-14 + offset.X, 1.6 + offset.Y, -52 + offset.Z),
			Color = Color3.fromRGB(24, 24, 28),
			Parent = model,
		})
	end

	local bar = part({
		Size = Vector3.new(4, 0.6, 1),
		CFrame = CFrame.new(-14, 5.6, -51),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.Neon,
		Parent = model,
		Name = "LightBar",
	})
	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 40
	light.Color = Color3.fromRGB(80, 120, 255)
	light.Parent = bar
	raidLight = light

	local sign = part({
		Size = Vector3.new(12, 3, 0.4),
		CFrame = CFrame.new(-14, 9, -52),
		Color = Color3.fromRGB(24, 26, 34),
		Parent = model,
	})
	label(sign, "RAID IN PROGRESS\n" .. playerName, Enum.NormalId.Front, Color3.fromRGB(240, 120, 120))

	model.Parent = root
	raidModel = model

	task.delay(seconds, function()
		if raidModel == model then
			model:Destroy()
			raidModel = nil
			raidLight = nil
		end
	end)
end

function EnvironmentBuilder.raidActive(): boolean
	return raidModel ~= nil
end

--------------------------------------------------------------------------------
-- Employee animation loop
--------------------------------------------------------------------------------

local EMPLOYEE_STATES = { "typing", "talking", "celebrating", "angry", "standing", "coffee" }

local CHATTER = {
	typing = { "...", "mm-hm", "one moment sir" },
	talking = { "Hello sir!", "Yes sir, the blue window.", "Sir, please listen.", "No sir, it is not a scam." },
	celebrating = { "YES!", "GOT ONE!", "SIR SAID YES!" },
	angry = { "DO NOT HANG UP", "SIR!", "HELLO? HELLO?" },
	standing = { "I need a minute.", "This job." },
	coffee = { "Coffee.", "Third one today." },
}

local function setEmployeeState(employee, state: string)
	employee.state = state
	employee.stateTimer = Util.newRandom():NextNumber(4, 12)
	local lines = CHATTER[state]
	if lines and Util.newRandom():NextNumber() < 0.7 then
		employee.bubble.Text = Util.pick(lines)
		employee.bubble.Visible = true
		task.delay(3, function()
			if employee.bubble and employee.bubble.Parent then
				employee.bubble.Visible = false
			end
		end)
	end
end

local function animateEmployees(dt: number)
	local now = os.clock()

	if raidLight and raidLight.Parent then
		raidLight.Color = (math.floor(now * 3) % 2 == 0)
			and Color3.fromRGB(80, 120, 255)
			or Color3.fromRGB(255, 80, 80)
	end

	for _, employee in ipairs(employees) do
		employee.stateTimer -= dt
		if employee.stateTimer <= 0 then
			setEmployeeState(employee, Util.pick(EMPLOYEE_STATES))
		end

		local t = now + employee.phase
		local base = employee.baseCFrame
		local state = employee.state

		if state == "typing" then
			local wobble = math.sin(t * 9) * 0.12
			employee.leftArm.CFrame = base * CFrame.new(-1.35, 3 + wobble, -0.9) * CFrame.Angles(math.rad(-70), 0, 0)
			employee.rightArm.CFrame = base * CFrame.new(1.35, 3 - wobble, -0.9) * CFrame.Angles(math.rad(-70), 0, 0)
			employee.head.CFrame = base * CFrame.new(0, 4.6, -0.1) * CFrame.Angles(math.rad(-12), 0, 0)
			employee.torso.CFrame = base * CFrame.new(0, 3, 0)
		elseif state == "talking" then
			local nod = math.sin(t * 3) * 0.1
			employee.head.CFrame = base * CFrame.new(0, 4.6, 0) * CFrame.Angles(nod, math.sin(t * 1.7) * 0.25, 0)
			employee.rightArm.CFrame = base * CFrame.new(1.35, 3.2 + math.sin(t * 4) * 0.25, -0.5) * CFrame.Angles(math.rad(-40), 0, 0)
			employee.leftArm.CFrame = base * CFrame.new(-1.35, 3, -0.3)
			employee.torso.CFrame = base * CFrame.new(0, 3, 0)
		elseif state == "celebrating" then
			local jump = math.abs(math.sin(t * 6)) * 0.6
			employee.torso.CFrame = base * CFrame.new(0, 3 + jump, 0)
			employee.head.CFrame = base * CFrame.new(0, 4.6 + jump, 0)
			employee.leftArm.CFrame = base * CFrame.new(-1.35, 4 + jump, 0) * CFrame.Angles(math.rad(160), 0, 0)
			employee.rightArm.CFrame = base * CFrame.new(1.35, 4 + jump, 0) * CFrame.Angles(math.rad(160), 0, 0)
		elseif state == "angry" then
			local shake = math.sin(t * 22) * 0.08
			employee.torso.CFrame = base * CFrame.new(shake, 3, 0)
			employee.head.CFrame = base * CFrame.new(shake, 4.6, 0) * CFrame.Angles(math.rad(10), 0, 0)
			employee.leftArm.CFrame = base * CFrame.new(-1.35 + shake, 3.4, -0.6) * CFrame.Angles(math.rad(-90), 0, 0)
			employee.rightArm.CFrame = base * CFrame.new(1.35 + shake, 3.4, -0.6) * CFrame.Angles(math.rad(-90), 0, 0)
		elseif state == "standing" then
			employee.torso.CFrame = base * CFrame.new(0, 4.2, 1.5)
			employee.head.CFrame = base * CFrame.new(0, 5.8, 1.5)
			employee.leftArm.CFrame = base * CFrame.new(-1.35, 4.2, 1.5)
			employee.rightArm.CFrame = base * CFrame.new(1.35, 4.2, 1.5)
		else -- coffee
			local sip = math.sin(t * 2) * 0.3
			employee.torso.CFrame = base * CFrame.new(0, 3, 0)
			employee.head.CFrame = base * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(8 + sip * 10), 0, 0)
			employee.rightArm.CFrame = base * CFrame.new(0.6, 4.2 + sip, -0.3) * CFrame.Angles(math.rad(-120), 0, 0)
			employee.leftArm.CFrame = base * CFrame.new(-1.35, 3, -0.3)
		end
	end
end

--------------------------------------------------------------------------------

function EnvironmentBuilder.build()
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end
	table.clear(employees)
	raidModel = nil
	raidLight = nil

	local root = Instance.new("Model")
	root.Name = ROOT_NAME

	buildRoomShell(root)
	buildSignage(root)

	local desks = Instance.new("Folder")
	desks.Name = "Desks"
	desks.Parent = root

	local staff = Instance.new("Folder")
	staff.Name = "Staff"
	staff.Parent = root

	-- Rows of desks. The front-left desk is the player's workstation.
	local deskIndex = 0
	for row = 0, 3 do
		for column = 0, 4 do
			deskIndex += 1
			local x = -40 + column * 18
			local z = -30 + row * 18
			local cframe = CFrame.new(x, 0, z)
			local desk = buildDesk(desks, cframe, "Desk_" .. deskIndex)

			if deskIndex == 1 then
				desk.Name = "PlayerWorkstation"
				local nameplate = part({
					Size = Vector3.new(4, 1, 0.3),
					CFrame = cframe * CFrame.new(0, 3.8, 1.5),
					Color = THEME.Accent,
					Parent = desk,
					Name = "Nameplate",
				})
				label(nameplate, "YOUR DESK", Enum.NormalId.Front)

				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "WorkstationPrompt"
				prompt.ActionText = "Start Call"
				prompt.ObjectText = "Your Workstation"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Parent = desk.PrimaryPart
			else
				-- Every other desk gets a colleague.
				buildEmployee(staff, cframe * CFrame.new(0, 0, 3), tostring(deskIndex))
			end
		end
	end

	-- A manager who patrols the floor.
	local managerCFrame = CFrame.new(0, 0, 45)
	local manager = buildEmployee(staff, managerCFrame, "Manager")
	manager.Name = "FloorManager"

	buildBreakRoom(root)
	local office = buildBossOffice(root)
	local _, shopPrompt = buildShopKiosk(root)
	buildLeaderboards(root)

	local executivePrompt = office:FindFirstChild("ExecutiveWorkstation")
	executivePrompt = executivePrompt and executivePrompt:FindFirstChildWhichIsA("ProximityPrompt", true) or nil

	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Size = Vector3.new(8, 1, 8)
	spawnPoint.CFrame = CFrame.new(-40, 0.5, -20)
	spawnPoint.Anchored = true
	spawnPoint.Neutral = true
	spawnPoint.Color = THEME.Accent
	spawnPoint.Material = Enum.Material.Neon
	spawnPoint.Name = "CallCentreSpawn"
	spawnPoint.Parent = root

	root.Parent = Workspace

	local env = Config.Environment
	Lighting.Ambient = env.Ambient
	Lighting.OutdoorAmbient = env.OutdoorAmbient
	Lighting.Brightness = env.Brightness
	Lighting.ClockTime = env.ClockTime
	Lighting.GlobalShadows = true
	Lighting.FogEnd = env.FogEnd

	local function ensureEffect(className: string, name: string, props)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local effect = Instance.new(className)
		effect.Name = name
		for key, value in pairs(props) do
			effect[key] = value
		end
		effect.Parent = Lighting
		return effect
	end

	-- Gentle. Bloom exists to make the neon read as lit, not to smear it.
	ensureEffect("BloomEffect", "MacrosoftBloom", {
		Intensity = env.Bloom.Intensity,
		Size = env.Bloom.Size,
		Threshold = env.Bloom.Threshold,
	})
	ensureEffect("ColorCorrectionEffect", "MacrosoftColour", {
		Saturation = env.Colour.Saturation,
		Contrast = env.Colour.Contrast,
		Brightness = env.Colour.Brightness,
		TintColor = Color3.fromRGB(255, 252, 250),
	})

	-- Any leftovers from an older install would stack on top of these.
	for _, name in ipairs({ "MacrosoftRays" }) do
		local stale = Lighting:FindFirstChild(name)
		if stale then
			stale:Destroy()
		end
	end

	-- Animate colleagues.
	if not EnvironmentBuilder._connection then
		EnvironmentBuilder._connection = RunService.Heartbeat:Connect(animateEmployees)
	end

	return root, shopPrompt, executivePrompt
end

function EnvironmentBuilder.getRoot(): Instance?
	return Workspace:FindFirstChild(ROOT_NAME)
end

-- Used by LeaderboardManager to push text onto the wall boards.
function EnvironmentBuilder.setLeaderboard(boardName: string, text: string)
	local root = EnvironmentBuilder.getRoot()
	if not root then
		return
	end
	local boards = root:FindFirstChild("Leaderboards")
	local board = boards and boards:FindFirstChild(boardName)
	local gui = board and board:FindFirstChild("Board")
	local entries = gui and gui:FindFirstChild("Entries")
	if entries then
		entries.Text = text
	end
end

return EnvironmentBuilder
