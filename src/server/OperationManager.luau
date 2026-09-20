--!nonstrict
-- OperationManager
-- The tycoon layer's server side: purchases, headcount, passive income,
-- offline earnings, and the once-a-second tick that drives both income and
-- police heat.
--
-- Rank and the earnings leaderboard are deliberately NOT fed by passive income.
-- Ranks come from calls, and method tiers require ranks, so the active game is
-- what unlocks the idle game rather than being replaced by it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Operation = require(Shared.Operation)
local Products = require(Shared.Products)
local Ranks = require(Shared.Ranks)
local Util = require(Shared.Util)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local HeatManager = require(script.Parent.HeatManager)

local OperationManager = {}

OperationManager.Changed = Instance.new("BindableEvent") -- (player, view)
OperationManager.Raided = Instance.new("BindableEvent") -- (player, outcome)
OperationManager.OfflineEarnings = Instance.new("BindableEvent") -- (player, amount, seconds)

local TICK_SECONDS = 1

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function state(player: Player)
	local profile = PlayerDataManager.get(player)
	return profile and profile.operation or nil
end

local function offlineCap(player: Player): number
	if PlayerDataManager.ownsPass(player, "night_shift") then
		return Operation.Offline.PassCapSeconds
	end
	return Operation.Offline.CapSeconds
end

function OperationManager.summary(player: Player)
	local operation = state(player)
	if not operation then
		return nil
	end
	return Operation.summarise(operation, { offlineCapSeconds = offlineCap(player) })
end

-- The multiplier the rest of the game applies to call payouts. A more
-- sophisticated operation makes every call worth more, which is what keeps the
-- call game relevant at the top end.
function OperationManager.callMultiplier(player: Player): number
	local summary = OperationManager.summary(player)
	return summary and summary.incomeMul or 1
end

function OperationManager.notify(player: Player)
	OperationManager.Changed:Fire(player, OperationManager.view(player))
end

--------------------------------------------------------------------------------
-- Purchases
--------------------------------------------------------------------------------

local function charge(player: Player, cost: number): boolean
	return PlayerDataManager.spendCredits(player, cost)
end

function OperationManager.setMethod(player: Player, methodId: string): (boolean, string)
	local operation = state(player)
	local profile = PlayerDataManager.get(player)
	local method = Operation.MethodById[methodId]
	if not operation or not method then
		return false, "Unknown method."
	end
	if operation.method == methodId then
		return false, "Already running that."
	end

	local current = Operation.MethodById[operation.method]
	-- Stepping back down is always free; you are giving up income.
	if method.index < current.index then
		operation.method = methodId
		OperationManager.notify(player)
		return true, "Scaled back to " .. method.name .. "."
	end

	if method.index > current.index + 1 then
		return false, "Unlock the tiers in order."
	end
	if profile.rankIndex < method.requiresRank then
		return false, method.name .. " needs the rank of " .. Ranks.get(method.requiresRank).name .. "."
	end
	if not operation.unlockedMethods[methodId] then
		if not charge(player, method.cost) then
			return false, "Not enough Credits."
		end
		operation.unlockedMethods[methodId] = true
	end
	operation.method = methodId
	OperationManager.notify(player)
	return true, "Now running " .. method.name .. ". Expect attention."
end

function OperationManager.buyFacility(player: Player, facilityId: string): (boolean, string)
	local operation = state(player)
	local facility = Operation.FacilityById[facilityId]
	if not operation or not facility then
		return false, "Unknown facility."
	end
	local current = Operation.FacilityById[operation.facility]
	if facility.index <= current.index then
		return false, "You already have that."
	end
	if facility.index > current.index + 1 then
		return false, "One move at a time."
	end
	if not charge(player, facility.cost) then
		return false, "Not enough Credits."
	end
	operation.facility = facilityId
	OperationManager.notify(player)
	return true, "Moved into " .. facility.name .. "."
end

function OperationManager.buySecurity(player: Player, itemId: string): (boolean, string)
	local operation = state(player)
	local item = Operation.SecurityById[itemId]
	if not operation or not item then
		return false, "Unknown security upgrade."
	end
	if operation.security[itemId] then
		return false, "Already installed."
	end
	if not charge(player, item.cost) then
		return false, "Not enough Credits."
	end
	operation.security[itemId] = true
	OperationManager.notify(player)
	return true, item.name .. " installed."
end

function OperationManager.buyTradecraft(player: Player, itemId: string): (boolean, string)
	local operation = state(player)
	local item = Operation.TradecraftById[itemId]
	if not operation or not item then
		return false, "Unknown upgrade."
	end
	if operation.tradecraft[itemId] then
		return false, "Already trained."
	end
	local method = Operation.MethodById[operation.method]
	if method.index < item.requiresMethod then
		return false, "Needs " .. Operation.Methods[item.requiresMethod].name .. " or better."
	end
	if not charge(player, item.cost) then
		return false, "Not enough Credits."
	end
	operation.tradecraft[itemId] = true
	OperationManager.notify(player)
	return true, item.name .. " sorted."
end

function OperationManager.hire(player: Player, employeeId: string, count: number): (boolean, string)
	local operation = state(player)
	local employee = Operation.EmployeeById[employeeId]
	if not operation or not employee then
		return false, "Nobody by that name."
	end
	count = math.clamp(math.floor(count or 1), 1, 25)

	local summary = OperationManager.summary(player)
	local room = summary.deskCap - summary.headcount
	if room <= 0 then
		return false, "No free desks. Upgrade the office."
	end
	count = math.min(count, room)

	local held = operation.staff[employeeId] or 0
	local total = 0
	for index = 0, count - 1 do
		total += Operation.hireCost(employee, held + index)
	end

	if not charge(player, total) then
		return false, "Not enough Credits."
	end
	operation.staff[employeeId] = held + count
	OperationManager.notify(player)
	return true, string.format("Hired %d x %s for %s Credits.", count, employee.name, Util.formatNumber(total))
end

function OperationManager.fire(player: Player, employeeId: string, count: number): (boolean, string)
	local operation = state(player)
	local employee = Operation.EmployeeById[employeeId]
	if not operation or not employee then
		return false, "Nobody by that name."
	end
	local held = operation.staff[employeeId] or 0
	if held <= 0 then
		return false, "You have none of those."
	end
	count = math.clamp(math.floor(count or 1), 1, held)

	local refund = 0
	for index = 0, count - 1 do
		refund += Operation.severance(employee, held - index)
	end
	local left = held - count
	operation.staff[employeeId] = left > 0 and left or nil
	PlayerDataManager.addCredits(player, refund, false)
	OperationManager.notify(player)
	return true, string.format("Let %d go. %s Credits back in severance.", count, Util.formatNumber(refund))
end

function OperationManager.layLow(player: Player): (boolean, string)
	local operation = state(player)
	if not operation then
		return false, "Still loading."
	end
	local ok, message = HeatManager.layLow(operation)
	if ok then
		OperationManager.notify(player)
	end
	return ok, message
end

-- Robux consumables that act on the operation rather than on a live call.
function OperationManager.useItem(player: Player, productId: string): (boolean, string)
	local product = Products.ProductById[productId]
	if not product or not product.usableInOperation then
		return false, "That cannot be used here."
	end
	local operation = state(player)
	if not operation then
		return false, "Still loading."
	end
	if product.use.clearHeat and (operation.heat or 0) <= 0 then
		return false, "Nobody is looking at you right now."
	end
	if not PlayerDataManager.consumeItem(player, productId) then
		return false, "You have none left."
	end

	local message = product.name .. " used."
	if product.use.clearHeat then
		operation.heat = 0
		operation.shutdownUntil = 0
		message = "The investigation has been dropped. Heat is at zero."
	end
	OperationManager.notify(player)
	return true, message
end

--------------------------------------------------------------------------------
-- Offline earnings
--------------------------------------------------------------------------------

function OperationManager.applyOffline(player: Player)
	local profile = PlayerDataManager.get(player)
	if not profile then
		return 0, 0
	end
	local operation = profile.operation
	local away = math.max(0, math.floor(profile.awaySeconds or 0))
	profile.awaySeconds = 0
	if away < 60 then
		return 0, 0
	end

	local summary = OperationManager.summary(player)
	local counted = math.min(away, summary.offlineCapSeconds)

	-- Heat bleeds off while nobody is there, but never builds.
	if Operation.Offline.DecayWhileAway then
		operation.heat = math.max(0, (operation.heat or 0) - summary.heatDecay * away)
	end
	operation.shutdownUntil = 0
	operation.layLowUntil = 0

	local earned = math.floor(summary.netIncome * counted * Operation.Offline.Efficiency)
	if earned > 0 then
		OperationManager.creditPassive(player, earned)
		OperationManager.OfflineEarnings:Fire(player, earned, counted)
	end
	return earned, counted
end

-- Passive income is credited, tracked, and kept out of lifetime earnings so it
-- cannot buy rank.
function OperationManager.creditPassive(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local profile = PlayerDataManager.get(player)
	if not profile then
		return
	end
	profile.stats.passiveEarned += amount
	profile.operation.passiveEarned += amount
	-- Silent: the per-second tick must not fire a remote per player per second.
	PlayerDataManager.addCredits(player, amount, false, true)
end

--------------------------------------------------------------------------------
-- Client view
--------------------------------------------------------------------------------

function OperationManager.view(player: Player)
	local profile = PlayerDataManager.get(player)
	local operation = profile and profile.operation
	if not operation then
		return nil
	end
	local summary = OperationManager.summary(player)

	local methods = {}
	for _, method in ipairs(Operation.Methods) do
		local current = Operation.MethodById[operation.method]
		table.insert(methods, {
			id = method.id,
			index = method.index,
			name = method.name,
			blurb = method.blurb,
			cost = method.cost,
			incomeMul = method.incomeMul,
			heatPerSecond = method.heatPerSecond,
			requiresRank = method.requiresRank,
			requiresRankName = Ranks.get(method.requiresRank).name,
			unlocked = operation.unlockedMethods[method.id] == true,
			active = operation.method == method.id,
			available = method.index <= current.index + 1 and profile.rankIndex >= method.requiresRank,
		})
	end

	local staff = {}
	for _, employee in ipairs(Operation.Employees) do
		local held = operation.staff[employee.id] or 0
		table.insert(staff, {
			id = employee.id,
			tier = employee.tier,
			name = employee.name,
			blurb = employee.blurb,
			held = held,
			hireCost = Operation.hireCost(employee, held),
			severance = Operation.severance(employee, held),
			incomePerSecond = employee.incomePerSecond,
			wagePerSecond = employee.wagePerSecond,
			heatPerSecond = employee.heatPerSecond,
			suspicious = employee.suspicious == true,
		})
	end

	local function listOf(source, owned, extra)
		local out = {}
		for _, item in ipairs(source) do
			local entry = {
				id = item.id,
				name = item.name,
				blurb = item.blurb,
				cost = item.cost,
				order = item.order,
				owned = owned[item.id] == true,
			}
			if extra then
				extra(entry, item)
			end
			table.insert(out, entry)
		end
		return out
	end

	local currentFacility = Operation.FacilityById[operation.facility]
	local facilities = {}
	for _, facility in ipairs(Operation.Facilities) do
		table.insert(facilities, {
			id = facility.id,
			index = facility.index,
			name = facility.name,
			blurb = facility.blurb,
			cost = facility.cost,
			desks = facility.desks,
			incomeMul = facility.incomeMul,
			owned = facility.index <= currentFacility.index,
			available = facility.index == currentFacility.index + 1,
		})
	end

	return {
		method = operation.method,
		facility = operation.facility,
		heat = operation.heat,
		heatMax = Operation.Heat.Max,
		layLowRemaining = math.max(0, (operation.layLowUntil or 0) - os.time()),
		shutdownRemaining = math.max(0, (operation.shutdownUntil or 0) - os.time()),
		raidsSurvived = operation.raidsSurvived,
		raidsLost = operation.raidsLost,
		passiveEarned = operation.passiveEarned,
		summary = {
			netIncome = summary.netIncome,
			income = summary.income,
			wages = summary.wages,
			incomeMul = summary.incomeMul,
			headcount = summary.headcount,
			deskCap = summary.deskCap,
			suspiciousCount = summary.suspiciousCount,
			heatGain = summary.heatGain,
			heatDecay = summary.heatDecay,
			heatRate = summary.heatRate,
			notoriety = summary.notoriety,
			securityRating = summary.securityRating,
			escapeChance = summary.escapeChance,
			offlineCapSeconds = summary.offlineCapSeconds,
		},
		methods = methods,
		staff = staff,
		facilities = facilities,
		security = listOf(Operation.Security, operation.security, function(entry, item)
			entry.rating = item.rating
			entry.heatMul = item.heatMul
			entry.decayBonus = item.decayBonus
		end),
		tradecraft = listOf(Operation.Tradecraft, operation.tradecraft, function(entry, item)
			entry.heatMul = item.heatMul
			entry.incomeMul = item.incomeMul
			entry.requiresMethod = item.requiresMethod
			entry.requiresMethodName = Operation.Methods[item.requiresMethod].name
		end),
	}
end

--------------------------------------------------------------------------------
-- Tick
--------------------------------------------------------------------------------

function OperationManager.step(player: Player, dt: number)
	local profile = PlayerDataManager.get(player)
	if not profile then
		return
	end
	local operation = profile.operation
	local summary = OperationManager.summary(player)

	local running = not HeatManager.isLayingLow(operation) and not HeatManager.isShutDown(operation)
	if running and summary.netIncome > 0 then
		OperationManager.creditPassive(player, summary.netIncome * dt)
	end

	local function spendFraction(fraction: number): number
		local amount = math.floor(profile.credits * fraction)
		if amount > 0 then
			PlayerDataManager.spendCredits(player, amount)
		end
		return amount
	end

	local outcome = HeatManager.tick(player, operation, summary, dt, spendFraction)
	if outcome then
		OperationManager.Raided:Fire(player, outcome)
	end
end

function OperationManager.start()
	local function onJoin(player: Player)
		task.spawn(function()
			local deadline = os.clock() + 25
			while not PlayerDataManager.get(player) and os.clock() < deadline do
				task.wait(0.25)
			end
			if PlayerDataManager.get(player) then
				OperationManager.applyOffline(player)
				OperationManager.notify(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		onJoin(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		HeatManager.reset(player)
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(TICK_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				if PlayerDataManager.get(player) then
					local ok, err = pcall(OperationManager.step, player, dt)
					if not ok then
						warn("[OperationManager] tick failed for " .. player.Name .. ": " .. tostring(err))
					end
				end
			end
		end
	end)

	-- Push a fresh view to clients a few times a minute so the meters move
	-- without spamming a remote every tick.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				if PlayerDataManager.get(player) then
					OperationManager.notify(player)
					-- Catches up the credit total and the player-list stats that
					-- the silent passive ticks deliberately skipped.
					PlayerDataManager.notify(player)
				end
			end
		end
	end)
end

return OperationManager
