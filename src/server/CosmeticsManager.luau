--!nonstrict
-- CosmeticsManager
-- Applies the cosmetic Game Passes to a player's character: the overhead title
-- and the Platinum Headset. Nothing here touches gameplay values.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Products = require(Shared.Products)

local PlayerDataManager = require(script.Parent.PlayerDataManager)

local CosmeticsManager = {}

local TAG_NAME = "MacrosoftTitle"
local HEADSET_NAME = "MacrosoftPlatinumHeadset"

-- DataChanged fires on every credit tick, so cosmetics are only rebuilt when
-- what they depend on actually changed.
local lastSignature: { [number]: string } = {}

local function clearCosmetics(character: Model)
	local head = character:FindFirstChild("Head")
	if head then
		local existingTag = head:FindFirstChild(TAG_NAME)
		if existingTag then
			existingTag:Destroy()
		end
	end
	local existingHeadset = character:FindFirstChild(HEADSET_NAME)
	if existingHeadset then
		existingHeadset:Destroy()
	end
end

local function applyTitle(character: Model, text: string, colour: Color3)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Size = UDim2.fromOffset(240, 34)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Text = text
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
end

local function applyHeadset(character: Model)
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not head or not head:IsA("BasePart") or not humanoid then
		return
	end
	local headHatAttachment = head:FindFirstChild("HatAttachment")
	if not headHatAttachment or not headHatAttachment:IsA("Attachment") then
		return
	end

	local accessory = Instance.new("Accessory")
	accessory.Name = HEADSET_NAME
	accessory.AccessoryType = Enum.AccessoryType.Hat

	-- HatAttachment exists on standard R6 and R15 heads. Matching it from the
	-- Handle lets Humanoid:AddAccessory create the normal AccessoryWeld instead
	-- of pinning loose geometry directly to the character's head.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.CFrame = CFrame.new()
	handle.Parent = accessory

	local attachment = Instance.new("Attachment")
	attachment.Name = "HatAttachment"
	-- Copy the avatar's exact attachment transform. That puts the invisible
	-- Handle at the head centre without assuming one fixed hat offset.
	attachment.CFrame = headHatAttachment.CFrame
	attachment.Parent = handle

	local platinum = Color3.fromRGB(219, 225, 235)
	local platinumDark = Color3.fromRGB(142, 151, 166)
	local cushion = Color3.fromRGB(20, 23, 30)
	local cushionEdge = Color3.fromRGB(43, 48, 59)

	local function detail(className: string, name: string, size: Vector3, colour: Color3, material, offset: CFrame, shape)
		local part = Instance.new(className)
		part.Name = name
		part.Size = size
		part.Color = colour
		part.Material = material
		if shape then
			part.Shape = shape
		end
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.CFrame = handle.CFrame * offset
		part.Parent = accessory

		local weld = Instance.new("WeldConstraint")
		weld.Name = "HeadsetWeld"
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	-- A padded seven-piece arc follows the top of a standard avatar head.
	-- Overlapping cylinders read as one smooth band rather than a square halo.
	local bandSegments = {
		{ -1.02, 0.05, 72, 0.40 },
		{ -0.86, 0.34, 50, 0.44 },
		{ -0.52, 0.58, 24, 0.48 },
		{ 0, 0.67, 0, 0.60 },
		{ 0.52, 0.58, -24, 0.48 },
		{ 0.86, 0.34, -50, 0.44 },
		{ 1.02, 0.05, -72, 0.40 },
	}
	for index, segment in ipairs(bandSegments) do
		local offset = CFrame.new(segment[1], segment[2], 0.05) * CFrame.Angles(0, 0, math.rad(segment[3]))
		detail("Part", "PaddedBand" .. index, Vector3.new(segment[4], 0.24, 0.24), cushion, Enum.Material.SmoothPlastic, offset, Enum.PartType.Cylinder)
		local railOffset = CFrame.new(segment[1], segment[2] + 0.13, 0.05) * CFrame.Angles(0, 0, math.rad(segment[3]))
		detail("Part", "PlatinumRail" .. index, Vector3.new(segment[4], 0.065, 0.065), platinum, Enum.Material.Metal, railOffset, Enum.PartType.Cylinder)
	end

	-- Metal yokes bridge the band and the earcups without covering the padding.
	for _, side in ipairs({ -1, 1 }) do
		detail(
			"Part",
			side < 0 and "LeftYoke" or "RightYoke",
			Vector3.new(0.42, 0.09, 0.09),
			platinum,
			Enum.Material.Metal,
			CFrame.new(side * 1.08, 0.08, 0.05) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.PartType.Cylinder
		)
	end

	local function earcup(side: number, label: string)
		-- Circular outer shells, inset trim and thick inward-facing cushions make
		-- the silhouette unmistakably over-ear from the front and side.
		detail("Part", label .. "Earcup", Vector3.new(0.30, 0.82, 0.82), platinum, Enum.Material.Metal, CFrame.new(side * 1.12, -0.16, 0.05), Enum.PartType.Cylinder)
		detail("Part", label .. "Trim", Vector3.new(0.06, 0.68, 0.68), platinumDark, Enum.Material.Metal, CFrame.new(side * 1.29, -0.16, 0.05), Enum.PartType.Cylinder)
		detail("Part", label .. "Cushion", Vector3.new(0.20, 0.72, 0.72), cushion, Enum.Material.SmoothPlastic, CFrame.new(side * 0.94, -0.16, 0.05), Enum.PartType.Cylinder)
		detail("Part", label .. "CushionInset", Vector3.new(0.025, 0.48, 0.48), cushionEdge, Enum.Material.SmoothPlastic, CFrame.new(side * 0.825, -0.16, 0.05), Enum.PartType.Cylinder)
	end
	earcup(-1, "Left")
	earcup(1, "Right")

	-- A restrained diamond mark on the outside cup gives the pass a recognisable
	-- premium detail without turning the headset into a glowing costume prop.
	detail("Part", "PlatinumMark", Vector3.new(0.035, 0.18, 0.18), Color3.fromRGB(242, 246, 255), Enum.Material.Metal, CFrame.new(-1.335, -0.16, 0.05) * CFrame.Angles(math.rad(45), 0, 0), Enum.PartType.Block)

	-- The boom stays entirely on the left side, then turns inward near its tip;
	-- it finishes forward of the cheek rather than clipping through the face.
	detail("Part", "MicrophoneJoint", Vector3.new(0.18, 0.18, 0.18), platinumDark, Enum.Material.Metal, CFrame.new(-1.30, -0.28, -0.16), Enum.PartType.Ball)
	detail("Part", "MicrophoneBoom", Vector3.new(0.82, 0.07, 0.07), platinumDark, Enum.Material.Metal, CFrame.new(-1.25, -0.36, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(-8)), Enum.PartType.Cylinder)
	detail("Part", "MicrophoneStem", Vector3.new(0.34, 0.065, 0.065), platinumDark, Enum.Material.Metal, CFrame.new(-1.03, -0.45, -0.91), Enum.PartType.Cylinder)
	detail("Part", "MicrophoneCapsule", Vector3.new(0.20, 0.13, 0.13), cushion, Enum.Material.SmoothPlastic, CFrame.new(-0.79, -0.45, -0.91), Enum.PartType.Ball)

	humanoid:AddAccessory(accessory)
end

local Ranks = require(Shared.Ranks)

function CosmeticsManager.apply(player: Player, force: boolean?)
	local character = player.Character
	if not character then
		return
	end

	local rank = ""
	local data = PlayerDataManager.get(player)
	if data then
		rank = Ranks.get(data.rankIndex).name
	end

	local signature = string.format(
		"%s|%s|%s",
		rank,
		tostring(PlayerDataManager.ownsPass(player, "employee_of_month")),
		tostring(PlayerDataManager.ownsPass(player, "platinum_headset"))
	)
	if not force and lastSignature[player.UserId] == signature then
		return
	end
	lastSignature[player.UserId] = signature

	clearCosmetics(character)

	if PlayerDataManager.ownsPass(player, "employee_of_month") then
		local pass = Products.PassById.employee_of_month
		applyTitle(character, pass.title.text, pass.title.colour)
	elseif rank ~= "" then
		applyTitle(character, rank, Color3.fromRGB(190, 198, 214))
	end

	if PlayerDataManager.ownsPass(player, "platinum_headset") then
		applyHeadset(character)
	end
end

function CosmeticsManager.start()
	local function hook(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			task.wait(0.2)
			-- A fresh character has no cosmetics, so force a rebuild.
			CosmeticsManager.apply(player, true)
		end)
		if player.Character then
			CosmeticsManager.apply(player, true)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSignature[player.UserId] = nil
	end)

	-- Re-apply when ownership or rank changes.
	PlayerDataManager.DataChanged.Event:Connect(function(player)
		if player.Character then
			CosmeticsManager.apply(player)
		end
	end)
end

return CosmeticsManager
