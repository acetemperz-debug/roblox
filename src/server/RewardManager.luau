--!nonstrict
-- RewardManager
-- Works out what a finished call is worth and writes it to the profile.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Ranks = require(Shared.Ranks)
local Difficulty = require(Shared.Difficulty)
local Operation = require(Shared.Operation)

local PlayerDataManager = require(script.Parent.PlayerDataManager)

local RewardManager = {}

-- result: { outcome, npc, trust, suspicion, duration, perfect, difficultyKey, bonuses }
function RewardManager.calculate(player: Player, result)
	local random = Util.newRandom()
	local data = PlayerDataManager.get(player)
	local level = Difficulty.get(result.difficultyKey)
	local rank = Ranks.get(data and data.rankIndex or 1)
	local bonuses = result.bonuses or {}
	local breakdown = {}

	if result.outcome ~= "success" then
		local band = Config.Rewards.FailureConsolation
		local amount = random:NextInteger(band.min, band.max)
		table.insert(breakdown, { label = "Attendance (failed call)", amount = amount })
		return amount, breakdown
	end

	local band = Config.Rewards.TierBase[result.npc.tier] or Config.Rewards.TierBase.Normal
	local base = random:NextInteger(band.min, band.max)
	base = math.floor(base * (result.npc.rewardMul or 1))
	table.insert(breakdown, { label = result.npc.tier .. " caller", amount = base })

	local total = base
	local bonusMult = 0

	local b = Config.Rewards.Bonuses
	if result.suspicion <= b.LowSuspicion.threshold then
		bonusMult += b.LowSuspicion.mult
		table.insert(breakdown, { label = b.LowSuspicion.label, amount = math.floor(base * b.LowSuspicion.mult) })
	end
	if result.trust >= b.HighTrust.threshold then
		bonusMult += b.HighTrust.mult
		table.insert(breakdown, { label = b.HighTrust.label, amount = math.floor(base * b.HighTrust.mult) })
	end
	local fastWindow = Config.Call.FastCallSeconds + (bonuses.timeBonus or 0)
	if result.duration <= fastWindow then
		bonusMult += b.FastCall.mult
		table.insert(breakdown, { label = b.FastCall.label, amount = math.floor(base * b.FastCall.mult) })
	end
	if result.perfect then
		bonusMult += b.PerfectRun.mult
		table.insert(breakdown, { label = b.PerfectRun.label, amount = math.floor(base * b.PerfectRun.mult) })
	end
	if result.npc.tier == "Hard" or result.npc.tier == "Expert" or result.npc.tier == "Nightmare" then
		bonusMult += b.HardNPC.mult
		table.insert(breakdown, { label = b.HardNPC.label, amount = math.floor(base * b.HardNPC.mult) })
	end

	total = base * (1 + bonusMult)

	-- A more sophisticated operation makes every call worth more. This is what
	-- keeps the call game relevant once the tycoon layer is running.
	local operationMul = 1
	if data and data.operation then
		operationMul = Operation.summarise(data.operation).incomeMul
	end

	-- Multipliers from difficulty, rank, upgrades and the operation.
	local multipliers = level.rewardMul * rank.rewardMul * (bonuses.rewardMul or 1) * operationMul
	local beforeMultipliers = total
	total = math.floor(total * multipliers)
	if total ~= math.floor(beforeMultipliers) then
		table.insert(breakdown, {
			label = string.format(
				"Difficulty x%.2f / Rank x%.2f / Desk x%.2f / Operation x%.2f",
				level.rewardMul,
				rank.rewardMul,
				bonuses.rewardMul or 1,
				operationMul
			),
			amount = total - math.floor(beforeMultipliers),
		})
	end

	return total, breakdown
end

-- Applies the payout and the call statistics, returning the amount awarded.
function RewardManager.award(player: Player, result): (number, any)
	local amount, breakdown = RewardManager.calculate(player, result)
	local level = Difficulty.get(result.difficultyKey)

	PlayerDataManager.recordCall(player, {
		outcome = result.outcome,
		duration = result.duration,
		difficulty = result.difficultyKey,
		difficultyOrder = level.order,
		timesOnHold = result.timesOnHold,
	})
	PlayerDataManager.addCredits(player, amount, true)

	return amount, breakdown
end

return RewardManager
