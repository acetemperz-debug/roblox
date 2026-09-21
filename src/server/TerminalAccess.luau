--!nonstrict
-- Server-owned interaction sessions. ProximityPrompt events are untrusted too.
local TerminalAccess = {}
local sessions = {}
local cooldowns = {}

local permissions = {
	workstation = { StartCall = true, ChooseOption = true, UseItem = true, SetDifficulty = true, setMethod = true },
	hr = { hire = true, fire = true },
	management = { PurchaseUpgrade = true, buyFacility = true, buyTradecraft = true },
	security = { buySecurity = true, layLow = true, useItem = true },
	premium = { PromptPurchase = true },
}

function TerminalAccess.near(player, terminal): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	local anchor = terminal and terminal.anchor
	if not root or not humanoid or humanoid.Health <= 0 or not anchor or not anchor:IsDescendantOf(workspace) then
		return false
	end
	local position = root.Position
	if not (math.abs(position.X) < math.huge and math.abs(position.Y) < math.huge and math.abs(position.Z) < math.huge) then return false end
	if terminal.canAccess then
		if not terminal.canAccess(player) then return false end
	elseif terminal.owner and terminal.owner ~= player.UserId then return false end
	if terminal.canUse and not terminal.canUse(player) then return false end
	if (root.Position - anchor.Position).Magnitude > (terminal.distance or 10) then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, terminal.model or anchor }
	return workspace:Raycast(root.Position, anchor.Position - root.Position, params) == nil
end

function TerminalAccess.throttle(player, key, seconds): boolean
	local bucket = cooldowns[player] or {}
	cooldowns[player] = bucket
	local now = os.clock()
	if now < (bucket[key] or 0) then return false end
	bucket[key] = now + seconds
	return true
end

function TerminalAccess.open(player, terminal): boolean
	if not permissions[terminal.kind] or not TerminalAccess.near(player, terminal) then return false end
	sessions[player] = { terminal = terminal, character = player.Character, expires = os.clock() + 1800 }
	return true
end

function TerminalAccess.valid(player): boolean
	local session = sessions[player]
	return session ~= nil and session.character == player.Character and session.expires > os.clock()
		and TerminalAccess.near(player, session.terminal)
end

function TerminalAccess.authorize(player, action): boolean
	if not TerminalAccess.valid(player) then return false end
	local session = sessions[player]
	if not permissions[session.terminal.kind][action] then return false end
	if session.terminal.canAct and not session.terminal.canAct(player, action) then return false end
	if not TerminalAccess.throttle(player, "action", 0.2) then return false end
	session.expires = os.clock() + 1800
	return true
end

function TerminalAccess.current(player)
	return sessions[player]
end

function TerminalAccess.close(player)
	sessions[player] = nil
end

function TerminalAccess.remove(player)
	sessions[player] = nil
	cooldowns[player] = nil
end

function TerminalAccess.finiteInteger(value, minimum, maximum): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
		and value % 1 == 0 and value >= minimum and value <= maximum
end

return TerminalAccess
