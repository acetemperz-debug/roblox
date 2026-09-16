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

function methods:FindFirstChildWhichIsA(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "ClassName") == className then
			return child
		end
	end
	return nil
end

function methods:Destroy()
	rawset(self, "_children", {})
end

function methods:Connect(fn)
	table.insert(rawget(self, "_connections"), fn)
	return { Disconnect = function() end }
end

function methods:Fire(...)
	local event = rawget(self, "Event")
	if event then
		for _, fn in ipairs(rawget(event, "_connections")) do
			fn(...)
		end
	end
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

local instanceMeta = {
	__index = function(_, key)
		return methods[key]
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
	return self
end

Stub.newInstance = newInstance

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
	services.Players = {
		GetPlayers = function()
			return {}
		end,
		PlayerAdded = { Connect = function() end },
		PlayerRemoving = { Connect = function() end },
		GetPlayerByUserId = function()
			return nil
		end,
	}
	services.RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return true
		end,
		Heartbeat = { Connect = function() end },
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
	Vector3 = { new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end }
	Vector2 = { new = function(x, y)
		return { X = x, Y = y }
	end }
	CFrame = {
		new = function(x, y, z)
			return { X = x or 0, Y = y or 0, Z = z or 0 }
		end,
		Angles = function()
			return {}
		end,
	}
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
