--!nonstrict
-- Ephemeral consent policy. No profile tables or DataStores belong here.
local OfficeSessions = {}
local LIMIT, INVITE_SECONDS = 8, 90

function OfficeSessions.new(now)
	now = now or os.clock
	local records, invitations = {}, {}
	local serial = 0
	local self = {}
	local function members(hostId)
		local ids = {}
		for id, record in pairs(records) do
			if record.hostUserId == hostId then table.insert(ids, id) end
		end
		table.sort(ids)
		return ids
	end
	local function clearInvites(id)
		for token, invite in pairs(invitations) do
			if invite.hostUserId == id or invite.targetUserId == id then invitations[token] = nil end
		end
	end
	function self:get(id) return records[id] end
	function self:host(id)
		local record = records[id]
		local host = record and records[record.hostUserId]
		return host and host.player or nil
	end
	function self:remove(id)
		local record = records[id]
		if not record then return {} end
		local affected = members(record.hostUserId)
		if record.hostUserId == id then
			for _, guestId in ipairs(affected) do
				if guestId ~= id then
					local guest = records[guestId]
					guest.hostUserId, guest.mode, guest.needsChoice = guestId, "solo", false
				end
			end
		end
		clearInvites(id)
		records[id] = nil
		local out = {}
		for _, uid in ipairs(affected) do if uid ~= id then table.insert(out, uid) end end
		return out
	end
	function self:add(player)
		if records[player.UserId] and records[player.UserId].player == player then return records[player.UserId] end
		self:remove(player.UserId)
		local record = { player = player, userId = player.UserId, hostUserId = player.UserId, mode = nil, needsChoice = true }
		records[player.UserId] = record
		return record
	end
	function self:choose(id, mode)
		local record = records[id]
		if not record or (mode ~= "solo" and mode ~= "coop") then return false, "Choose Solo or Co-op." end
		if record.hostUserId ~= id then return false, "Leave your host's session first." end
		if mode == "solo" and #members(id) > 1 then return false, "Remove guests before switching to Solo." end
		record.mode, record.needsChoice = mode, false
		return true, mode == "solo" and "Your office is private. You can invite friends later." or "Co-op is invite-only. Invite from Office Management."
	end
	function self:canEnter(id, ownerId)
		local record, owner = records[id], records[ownerId]
		return record ~= nil and owner ~= nil and not record.needsChoice and not owner.needsChoice
			and owner.hostUserId == ownerId and record.hostUserId == ownerId
	end
	function self:invite(hostId, targetId)
		local host, target = records[hostId], records[targetId]
		if not host or host.needsChoice or host.hostUserId ~= hostId then return false, "Only the office host can invite." end
		if not target or targetId == hostId then return false, "Choose another player in this server." end
		if target.hostUserId == hostId then return false, "That player is already a member." end
		if #members(hostId) >= LIMIT then return false, "The party is full (8 players)." end
		-- Reinviting replaces the prior offer, so old accept clicks cannot be replayed.
		for token, invite in pairs(invitations) do
			if invite.hostUserId == hostId and invite.targetUserId == targetId then invitations[token] = nil end
		end
		serial += 1
		local invite = { id = tostring(serial), hostUserId = hostId, targetUserId = targetId,
			hostPlayer = host.player, targetPlayer = target.player, expires = now() + INVITE_SECONDS }
		invitations[invite.id] = invite
		return true, "Invitation sent. Entry unlocks only after acceptance.", invite
	end
	function self:respond(id, token, accept)
		local invite = invitations[token]
		local target = records[id]
		local host = invite and records[invite.hostUserId]
		if type(accept) ~= "boolean" or not invite or invite.targetUserId ~= id or not target
			or target.player ~= invite.targetPlayer or not host or host.player ~= invite.hostPlayer
			or host.hostUserId ~= invite.hostUserId or invite.expires <= now() then
			return false, "This invitation is no longer valid.", {}
		end
		invitations[token] = nil
		if not accept then return true, "Invitation declined.", { id, invite.hostUserId } end
		if target.hostUserId == id and #members(id) > 1 then return false, "Remove your guests before joining another host.", { id } end
		if #members(invite.hostUserId) >= LIMIT then return false, "That party is now full.", { id } end
		local affected = members(target.hostUserId)
		clearInvites(id)
		target.hostUserId, target.mode, target.needsChoice = invite.hostUserId, "coop", false
		host.mode = "coop"
		for _, uid in ipairs(members(invite.hostUserId)) do if not table.find(affected, uid) then table.insert(affected, uid) end end
		return true, "Joined " .. host.player.DisplayName .. "'s office. Calls benefit the host; your save stays separate.", affected
	end
	function self:revoke(hostId, guestId)
		local host, guest = records[hostId], records[guestId]
		if not host or host.hostUserId ~= hostId or hostId == guestId then return false, "Only the host can remove guests.", {} end
		-- Also cancels a pending invitation for this player.
		local pending = false
		for token, invite in pairs(invitations) do
			if invite.hostUserId == hostId and invite.targetUserId == guestId then invitations[token] = nil; pending = true end
		end
		if not guest or guest.hostUserId ~= hostId then return pending, pending and "Invitation cancelled." or "That player is not a guest.", { hostId, guestId } end
		local affected = members(hostId)
		guest.hostUserId, guest.mode, guest.needsChoice = guestId, "solo", false
		return true, "Guest access revoked.", affected
	end
	function self:leave(id)
		local record = records[id]
		if not record or record.hostUserId == id then return false, "You are already in your own office.", {} end
		return self:revoke(record.hostUserId, id)
	end
	function self:expire()
		local affected = {}
		for token, invite in pairs(invitations) do
			if invite.expires <= now() then
				invitations[token] = nil
				table.insert(affected, invite.targetUserId)
			end
		end
		return affected
	end
	function self:view(id)
		local record = records[id]
		if not record then return nil end
		local host = records[record.hostUserId]
		local view = { needsChoice = record.needsChoice, mode = host.mode, hostUserId = record.hostUserId,
			hostName = host.player.DisplayName, isHost = id == record.hostUserId, members = {}, invitations = {},
			maxMembers = LIMIT }
		for _, uid in ipairs(members(record.hostUserId)) do
			table.insert(view.members, { userId = uid, name = records[uid].player.DisplayName })
		end
		for _, invite in pairs(invitations) do
			local inviter = records[invite.hostUserId]
			if invite.targetUserId == id and inviter and invite.expires > now() then
				table.insert(view.invitations, { id = invite.id, hostUserId = invite.hostUserId,
					hostName = inviter.player.DisplayName, expiresIn = math.ceil(invite.expires - now()) })
			end
		end
		table.sort(view.invitations, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
		return view
	end
	return self
end

return OfficeSessions
