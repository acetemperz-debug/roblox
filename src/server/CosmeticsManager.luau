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
	if not head or not head:IsA("BasePart") then
		return
	end

	local band = Instance.new("Part")
	band.Name = HEADSET_NAME
	band.Size = Vector3.new(1.5, 0.22, 1.5)
	band.Color = Color3.fromRGB(226, 229, 238)
	band.Material = Enum.Material.Metal
	band.CanCollide = false
	band.Massless = true
	band.Anchored = false
	band.CFrame = head.CFrame * CFrame.new(0, 0.62, 0)
	band.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = band
	weld.Part1 = head
	weld.Parent = band

	local cup = Instance.new("Part")
	cup.Name = HEADSET_NAME .. "Cup"
	cup.Size = Vector3.new(0.25, 0.5, 0.5)
	cup.Color = Color3.fromRGB(200, 204, 214)
	cup.Material = Enum.Material.Metal
	cup.CanCollide = false
	cup.Massless = true
	cup.CFrame = head.CFrame * CFrame.new(-0.72, 0.1, 0)
	cup.Parent = band

	local cupWeld = Instance.new("WeldConstraint")
	cupWeld.Part0 = cup
	cupWeld.Part1 = head
	cupWeld.Parent = cup
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
