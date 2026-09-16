--!nonstrict
-- AchievementManager
-- Runs every unearned achievement's predicate after calls and purchases.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MacrosoftShared")
local Achievements = require(Shared.Achievements)

local PlayerDataManager = require(script.Parent.PlayerDataManager)

local AchievementManager = {}

AchievementManager.Unlocked = Instance.new("BindableEvent")

-- context may be nil (used for "career total" style achievements).
function AchievementManager.evaluate(player: Player, context)
	local data = PlayerDataManager.get(player)
	if not data then
		return {}
	end

	local newlyUnlocked = {}
	for _, achievement in ipairs(Achievements.List) do
		if not data.achievements[achievement.id] then
			local ok, result = pcall(achievement.check, data, context)
			if ok and result == true then
				if PlayerDataManager.grantAchievement(player, achievement.id) then
					table.insert(newlyUnlocked, achievement)
					if achievement.reward and achievement.reward > 0 then
						PlayerDataManager.addCredits(player, achievement.reward, false)
					end
				end
			elseif not ok then
				warn("[AchievementManager] check failed for " .. achievement.id .. ": " .. tostring(result))
			end
		end
	end

	for _, achievement in ipairs(newlyUnlocked) do
		AchievementManager.Unlocked:Fire(player, {
			id = achievement.id,
			name = achievement.name,
			blurb = achievement.blurb,
			reward = achievement.reward,
		})
	end

	return newlyUnlocked
end

function AchievementManager.catalog(player: Player)
	local data = PlayerDataManager.get(player)
	local out = {}
	for _, achievement in ipairs(Achievements.List) do
		table.insert(out, {
			id = achievement.id,
			name = achievement.name,
			blurb = achievement.blurb,
			reward = achievement.reward,
			unlocked = data ~= nil and data.achievements[achievement.id] == true,
		})
	end
	return out
end

return AchievementManager
