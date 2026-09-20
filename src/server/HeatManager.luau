--!nonstrict
-- HeatManager
-- The police pressure system. Heat rises with the size and sophistication of
-- the operation, falls with security and time, and at 100 the door goes in.
--
-- This module never reads global state: OperationManager hands it the player's
-- operation table and the summary it already computed, so the numbers on the
-- UI and the numbers in the simulation can never drift apart.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Operation = require(Shared.Operation)
local Util = require(Shared.Util)

local HeatManager = {}

HeatManager.Warned = Instance.new("BindableEvent") -- (player, warning)
HeatManager.Raided = Instance.new("BindableEvent") -- (player, outcome)

-- Which warning bands a player has already been shown this heat cycle.
local warnedAt: { [number]: { [number]: boolean } } = {}

function HeatManager.reset(player: Player)
	warnedAt[player.UserId] = nil
end

function HeatManager.isLayingLow(operation): boolean
	return (operation.layLowUntil or 0) > os.time()
end

function HeatManager.isShutDown(operation): boolean
	return (operation.shutdownUntil or 0) > os.time()
end

-- Adds heat from something that happened during a call.
function HeatManager.add(operation, amount: number)
	operation.heat = Util.clamp((operation.heat or 0) + amount, 0, Operation.Heat.Max)
end

function HeatManager.layLow(operation): (boolean, string)
	if HeatManager.isLayingLow(operation) then
		return false, "You are already lying low."
	end
	if HeatManager.isShutDown(operation) then
		return false, "The office is still shut."
	end
	operation.layLowUntil = os.time() + Operation.Heat.LayLowSeconds
	return true, string.format(
		"Everyone goes quiet for %d seconds. No income, but the heat drops fast.",
		Operation.Heat.LayLowSeconds
	)
end

-- Resolves a raid. Returns a table describing what happened, which the caller
-- forwards to the client and the achievement system.
function HeatManager.resolveRaid(player: Player, operation, summary, spendCredits)
	local random = Util.newRandom()
	local escaped = random:NextNumber() < summary.escapeChance

	if escaped then
		operation.heat = Operation.Raid.HeatAfterEscape
		operation.raidsSurvived += 1
		warnedAt[player.UserId] = nil
		local outcome = {
			escaped = true,
			title = "They Found Nothing",
			body = "Everyone stood very still next to a shredder for ten minutes. The coats left.",
			creditsLost = 0,
			staffLost = 0,
			escapeChance = summary.escapeChance,
		}
		HeatManager.Raided:Fire(player, outcome)
		return outcome
	end

	-- Failed raid: a fine, some staff scatter, and the floor shuts for a while.
	local fine = math.floor(spendCredits(Operation.Raid.CreditLossFraction))

	local staffLost = 0
	-- The noisy ones go first; they were always going to.
	local order = {}
	for _, employee in ipairs(Operation.Employees) do
		table.insert(order, employee)
	end
	table.sort(order, function(a, b)
		if a.suspicious ~= b.suspicious then
			return a.suspicious == true
		end
		return a.tier < b.tier
	end)

	local target = math.floor(summary.headcount * Operation.Raid.StaffLossFraction)
	for _, employee in ipairs(order) do
		if staffLost >= target then
			break
		end
		local held = operation.staff[employee.id] or 0
		if held > 0 then
			local take = math.min(held, target - staffLost)
			local left = held - take
			operation.staff[employee.id] = left > 0 and left or nil
			staffLost += take
		end
	end

	operation.heat = Operation.Raid.HeatAfterRaid
	operation.shutdownUntil = os.time() + Operation.Raid.ShutdownSeconds
	operation.raidsLost += 1
	warnedAt[player.UserId] = nil

	local outcome = {
		escaped = false,
		title = "Raided",
		body = string.format(
			"The door came off its hinges. %s Credits gone, %d staff out of a window, floor shut for %d seconds.",
			Util.formatNumber(fine),
			staffLost,
			Operation.Raid.ShutdownSeconds
		),
		creditsLost = fine,
		staffLost = staffLost,
		escapeChance = summary.escapeChance,
	}
	HeatManager.Raided:Fire(player, outcome)
	return outcome
end

-- One second of police pressure.
-- spendCredits(fraction) -> amount actually taken, supplied by OperationManager
-- so this module never touches the profile directly.
function HeatManager.tick(player: Player, operation, summary, dt: number, spendCredits)
	local layingLow = HeatManager.isLayingLow(operation)
	local shutDown = HeatManager.isShutDown(operation)

	local decay = summary.heatDecay
	local gain = summary.heatGain
	if layingLow then
		decay *= Operation.Heat.LayLowDecayMultiplier
		gain = 0
	end
	if shutDown then
		-- Nothing is running, so nothing is drawing attention.
		gain = 0
	end

	operation.heat = Util.clamp((operation.heat or 0) + (gain - decay) * dt, 0, Operation.Heat.Max)

	-- Warnings, once each per cycle.
	local seen = warnedAt[player.UserId]
	if not seen then
		seen = {}
		warnedAt[player.UserId] = seen
	end
	for index, warning in ipairs(Operation.Heat.Warnings) do
		if operation.heat >= warning.at and not seen[index] then
			seen[index] = true
			HeatManager.Warned:Fire(player, warning)
		elseif operation.heat < warning.at - 10 then
			-- Dropped well back below the band, so it can fire again later.
			seen[index] = nil
		end
	end

	if operation.heat >= Operation.Heat.Max then
		return HeatManager.resolveRaid(player, operation, summary, spendCredits)
	end
	return nil
end

return HeatManager
