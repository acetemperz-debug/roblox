--!nocheck
-- RobloxStub
-- Minimal fake Roblox API so the gameplay modules can be exercised from the
-- standalone `luau` CLI. Test-only; never shipped into the place file.

local Stub = {}

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

local methods = {}

function methods:GetChildren()
	return rawget(self, "_children")
end

function methods:GetDescendants()
	local out = {}
	for _, child in ipairs(self:GetChildren()) do
		table.insert(out, child)
		for _, descendant in ipairs(child:GetDescendants()) do table.insert(out, descendant) end
	end
	return out
end

function methods:IsA(className)
	return self.ClassName == className or (className == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"))
end

function methods:IsDescendantOf(parent)
	local cursor = self.Parent
	while cursor do
		if cursor == parent then return true end
		cursor = cursor.Parent
	end
	return false
end

function methods:FindFirstChild(name)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function methods:WaitForChild(name)
	return self:FindFirstChild(name)
end

function methods:FindFirstChildWhichIsA(className, recursive)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "ClassName") == className then
			return child
		end
		if recursive then
			local found = child:FindFirstChildWhichIsA(className, true)
			if found then return found end
		end
	end
	return nil
end

function methods:Destroy()
	for _, child in ipairs(table.clone(self:GetChildren())) do child:Destroy() end
	local parent = rawget(self, "Parent")
	if parent then
		local index = table.find(parent:GetChildren(), self)
		if index then table.remove(parent:GetChildren(), index) end
	end
	rawset(self, "Parent", nil)
	rawset(self, "_children", {})
end

function methods:Connect(fn)
	local connections = rawget(self, "_connections")
	table.insert(connections, fn)
	return { Disconnect = function()
		local index = table.find(connections, fn)
		if index then table.remove(connections, index) end
	end }
end

function methods:Fire(...)
	local event = rawget(self, "Event") or self
	for _, fn in ipairs(table.clone(rawget(event, "_connections"))) do
		fn(...)
	end
end

function methods:PivotTo(frame)
	local root = self:FindFirstChild("HumanoidRootPart") or self.PrimaryPart
	assert(root, "simulator: PivotTo requires a root part")
	root.CFrame = frame
	root.Position = frame.Position
	self._pivot = frame
end

function methods:FireClient(_player, ...)
	table.insert(rawget(self, "_log"), { ... })
end

function methods:FireAllClients() end

function methods:GetPropertyChangedSignal()
	return { Connect = function()
		return { Disconnect = function() end }
	end }
end

function methods:SetAttribute(key, value)
	rawget(self, "_attributes")[key] = value
end

function methods:GetAttribute(key)
	return rawget(self, "_attributes")[key]
end

function methods:AddAccessory(accessory)
	assert(self.ClassName == "Humanoid", "simulator: AddAccessory requires a Humanoid")
	local character = self.Parent
	local handle = accessory:FindFirstChild("Handle")
	assert(character and handle, "simulator: accessory requires a character and Handle")
	local handleAttachment = handle:FindFirstChildWhichIsA("Attachment")
	local head = character:FindFirstChild("Head")
	local headAttachment = head and handleAttachment and head:FindFirstChild(handleAttachment.Name)
	assert(headAttachment, "simulator: no matching character attachment")

	accessory.Parent = character
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = head
	weld.Part1 = handle
	weld.Parent = handle
end

local instanceMeta = {
	__index = function(self, key)
		if key == "Position" and rawget(self, "CFrame") then return rawget(self, "CFrame").Position end
		return methods[key] or methods.FindFirstChild(self, key)
	end,
	__newindex = function(self, key, value)
		if key == "Parent" and value ~= nil and type(value) == "table" and value.GetChildren then
			table.insert(value:GetChildren(), self)
		end
		rawset(self, key, value)
	end,
}

local function newInstance(className)
	local self = setmetatable({}, instanceMeta)
	rawset(self, "ClassName", className)
	rawset(self, "Name", className)
	rawset(self, "_children", {})
	rawset(self, "_connections", {})
	rawset(self, "_attributes", {})
	rawset(self, "_log", {})
	if className == "BindableEvent" then
		local signal = setmetatable({}, instanceMeta)
		rawset(signal, "ClassName", "_Signal")
		rawset(signal, "Name", "Signal")
		rawset(signal, "_children", {})
		rawset(signal, "_connections", {})
		rawset(signal, "_attributes", {})
		rawset(signal, "_log", {})
		rawset(self, "Event", signal)
	end
	if className == "RemoteEvent" then
		local signal = setmetatable({}, instanceMeta)
		rawset(signal, "ClassName", "_Signal")
		rawset(signal, "Name", "OnServerEvent")
		rawset(signal, "_children", {})
		rawset(signal, "_connections", {})
		rawset(signal, "_attributes", {})
		rawset(signal, "_log", {})
		rawset(self, "OnServerEvent", signal)
	end
	if className == "ProximityPrompt" then
		local signal = setmetatable({}, instanceMeta)
		rawset(signal, "_connections", {})
		rawset(signal, "_children", {})
		rawset(self, "Triggered", signal)
	end
	return self
end

Stub.newInstance = newInstance

function Stub.newPlayer(userId, name)
	local player = newInstance("Player")
	player.UserId = userId
	player.Name = name or ("Player" .. userId)
	player.DisplayName = player.Name
	player.CharacterAdded = newInstance("BindableEvent").Event
	return player
end

function Stub.spawnCharacter(player, frame)
	local character = newInstance("Model")
	character.Name = player.Name
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = frame or CFrame.new(0, 4, 44)
	root.Position = root.CFrame.Position
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Parent = character
	character.PrimaryPart = root
	local humanoid = newInstance("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	character.Parent = workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

-- Everything a RemoteEvent sent to a client during the test run.
function Stub.drain(remote)
	local log = rawget(remote, "_log")
	rawset(remote, "_log", {})
	return log
end

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

function Stub.install()
	local services = {}

	local function folder(name)
		local f = newInstance("Folder")
		f.Name = name
		return f
	end

	services.ReplicatedStorage = folder("ReplicatedStorage")
	services.Workspace = folder("Workspace")
	services.Lighting = folder("Lighting")
	local connectedPlayers = {}
	services.Players = {
		GetPlayers = function() return table.clone(connectedPlayers) end,
		PlayerAdded = newInstance("BindableEvent").Event,
		PlayerRemoving = newInstance("BindableEvent").Event,
		GetPlayerByUserId = function(_, userId)
			for _, player in ipairs(connectedPlayers) do
				if player.UserId == userId then return player end
			end
			return nil
		end,
	}
	function services.Players:Add(player)
		table.insert(connectedPlayers, player)
		player.Parent = self
		self.PlayerAdded:Fire(player)
	end
	function services.Players:Remove(player)
		self.PlayerRemoving:Fire(player)
		local index = table.find(connectedPlayers, player)
		if index then table.remove(connectedPlayers, index) end
		player.Parent = nil
	end
	services.RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return true
		end,
		Heartbeat = newInstance("BindableEvent").Event,
	}
	services.DataStoreService = {
		GetDataStore = function()
			error("DataStores disabled in simulator")
		end,
		GetOrderedDataStore = function()
			error("DataStores disabled in simulator")
		end,
	}

	game = {
		GetService = function(_, name)
			if not services[name] then
				services[name] = folder(name)
			end
			return services[name]
		end,
		BindToClose = function() end,
	}
	workspace = services.Workspace
	Instance = { new = newInstance }

	Random = {
		new = function(seed)
			local state = { value = (seed or os.time()) % 2147483647 }
			if state.value <= 0 then
				state.value = 12345
			end
			local self = {}
			local function nextNumber()
				state.value = (state.value * 1103515245 + 12345) % 2147483648
				return state.value / 2147483648
			end
			function self:NextNumber(min, max)
				local v = nextNumber()
				if min and max then
					return min + v * (max - min)
				end
				return v
			end
			function self:NextInteger(min, max)
				return math.floor(min + nextNumber() * (max - min + 1) - 1e-9)
			end
			return self
		end,
	}

	local function colour(r, g, b)
		local c
		c = {
			R = r,
			G = g,
			B = b,
			Lerp = function()
				return c
			end,
		}
		return c
	end
	Color3 = {
		fromRGB = colour,
		fromHSV = colour,
		new = colour,
	}
	local vectorMeta = {}
	vectorMeta.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
	vectorMeta.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
	vectorMeta.__index = function(a, key)
		if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
	end
	Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vectorMeta) end }
	Vector3.zero = Vector3.new(0, 0, 0)
	Vector2 = { new = function(x, y)
		return { X = x, Y = y }
	end }
	local frameMeta = {
		__mul = function(a, b) return CFrame.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
		__index = {
			PointToObjectSpace = function(self, point) return point - self.Position end,
		},
	}
	CFrame = {
		new = function(x, y, z)
			return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, Position = Vector3.new(x or 0, y or 0, z or 0) }, frameMeta)
		end,
		Angles = function()
			return CFrame.new()
		end,
	}
	RaycastParams = { new = function() return {} end }
	services.Workspace.Raycast = function() return nil end
	UDim = { new = function(a, b)
		return { Scale = a, Offset = b }
	end }
	UDim2 = {
		new = function()
			return {}
		end,
		fromScale = function()
			return {}
		end,
		fromOffset = function()
			return {}
		end,
	}
	Enum = setmetatable({}, {
		__index = function()
			return setmetatable({}, {
				__index = function()
					return 0
				end,
			})
		end,
	})

	task = {
		wait = function()
			return 0
		end,
		spawn = function(fn, ...)
			fn(...)
		end,
		delay = function() end,
		defer = function(fn, ...)
			fn(...)
		end,
	}
	warn = function(...)
		print("[warn]", ...)
	end
	if rawget(_G, "typeof") == nil then
		typeof = function(value)
			return type(value)
		end
	end

	return services
end

return Stub
