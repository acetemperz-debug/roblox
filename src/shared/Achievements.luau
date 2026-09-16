--!nonstrict
-- Achievements
-- Each achievement has a `check(data, context)` predicate. AchievementManager
-- runs every unearned achievement after each call and after each purchase.
--
-- context fields (may be nil outside of a call):
--   outcome        "success" | "hangup" | "exposed" | "bored" | "abandoned"
--   stage          stage index the call ended on
--   npc            the generated NPC table
--   trust, suspicion, patience, duration
--   perfect        boolean, no choice increased suspicion
--   reward         credits awarded

local Achievements = {}

Achievements.List = {
	{
		id = "hello_sir",
		name = "Hello Sir",
		blurb = "Complete your first call, either way.",
		reward = 100,
		check = function(data)
			return (data.stats.successfulCalls + data.stats.failedCalls) >= 1
		end,
	},
	{
		id = "do_not_redeem",
		name = "DO NOT REDEEM",
		blurb = "Lose a call during the final stage.",
		reward = 250,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome ~= "success" and ctx.stage ~= nil and ctx.stage >= 7
		end,
	},
	{
		id = "professional_time_waster",
		name = "Professional Time Waster",
		blurb = "Spend ten minutes on one call and walk away with nothing.",
		reward = 400,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome ~= "success" and (ctx.duration or 0) >= 600
		end,
	},
	{
		id = "wrong_number",
		name = "Wrong Number",
		blurb = "Accidentally call another fictional call centre.",
		reward = 300,
		check = function(_, ctx)
			return ctx ~= nil and ctx.npc ~= nil and ctx.npc.personalityId == "rival_centre"
		end,
	},
	{
		id = "cybersecurity_expert",
		name = "Cybersecurity Expert",
		blurb = "Get exposed within the first two stages by a tech-savvy caller.",
		reward = 250,
		check = function(_, ctx)
			return ctx ~= nil
				and ctx.outcome == "exposed"
				and (ctx.stage or 99) <= 2
				and ctx.npc ~= nil
				and ctx.npc.techKnowledge >= 7
		end,
	},
	{
		id = "first_blood",
		name = "Sir, You Have Won",
		blurb = "Complete your first successful call.",
		reward = 200,
		check = function(data)
			return data.stats.successfulCalls >= 1
		end,
	},
	{
		id = "flawless",
		name = "Laminated Perfection",
		blurb = "Finish a call without a single choice raising suspicion.",
		reward = 500,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome == "success" and ctx.perfect == true
		end,
	},
	{
		id = "speed_demon",
		name = "Two Minutes Flat",
		blurb = "Succeed on a call in under 120 seconds.",
		reward = 400,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome == "success" and (ctx.duration or 999) <= 120
		end,
	},
	{
		id = "nightmare_fuel",
		name = "Against All Odds",
		blurb = "Succeed on Nightmare difficulty.",
		reward = 2500,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome == "success" and ctx.difficulty == "Nightmare"
		end,
	},
	{
		id = "police_line",
		name = "You've Called A Police Station",
		blurb = "Discover the one number you should not have dialled.",
		reward = 500,
		check = function(_, ctx)
			return ctx ~= nil and ctx.npc ~= nil and ctx.npc.personalityId == "police_desk"
		end,
	},
	{
		id = "baited",
		name = "Content Creator",
		blurb = "Get strung along by a scambaiter for the entire call.",
		reward = 600,
		check = function(_, ctx)
			return ctx ~= nil and ctx.npc ~= nil and ctx.npc.personalityId == "scambaiter" and ctx.outcome ~= "success"
		end,
	},
	{
		id = "shouted_down",
		name = "JUST DO WHAT I SAY",
		blurb = "Lose a call by shouting at a caller.",
		reward = 150,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome ~= "success" and (ctx.aggressiveChoices or 0) >= 3
		end,
	},
	{
		id = "veteran",
		name = "Employee Of The Month",
		blurb = "Complete 50 successful calls.",
		reward = 3000,
		check = function(data)
			return data.stats.successfulCalls >= 50
		end,
	},
	{
		id = "millionaire",
		name = "Suspicious Wealth",
		blurb = "Earn 100,000 Credits in total.",
		reward = 5000,
		check = function(data)
			return data.stats.lifetimeEarnings >= 100000
		end,
	},
	{
		id = "fully_furnished",
		name = "Interior Designer",
		blurb = "Own eight desk upgrades.",
		reward = 2000,
		check = function(data)
			local n = 0
			for _, owned in pairs(data.upgrades) do
				if owned then
					n += 1
				end
			end
			return n >= 8
		end,
	},
	{
		id = "ceo",
		name = "Scam Empire CEO",
		blurb = "Reach the highest rank.",
		reward = 10000,
		check = function(data)
			return data.rankIndex >= 9
		end,
	},
	{
		id = "grandson",
		name = "The Grandson Problem",
		blurb = "Lose a call to a relative walking into the room.",
		reward = 200,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome ~= "success" and ctx.lastEventId == "grandson_arrives"
		end,
	},
	{
		id = "manager_please",
		name = "Let Me Speak To Your Manager",
		blurb = "Survive a caller demanding your supervisor.",
		reward = 350,
		check = function(_, ctx)
			return ctx ~= nil and ctx.outcome == "success" and ctx.survivedEvents ~= nil and ctx.survivedEvents["ask_for_manager"] == true
		end,
	},
	{
		id = "unlucky",
		name = "Statistically Improbable",
		blurb = "Fail ten calls in a row.",
		reward = 500,
		check = function(data)
			return (data.stats.failStreak or 0) >= 10
		end,
	},
	{
		id = "hold_music",
		name = "Hold Music Connoisseur",
		blurb = "Get put on hold five times across your career.",
		reward = 300,
		check = function(data)
			return (data.stats.timesOnHold or 0) >= 5
		end,
	},
}

Achievements.ById = {}
for _, a in ipairs(Achievements.List) do
	Achievements.ById[a.id] = a
end

return Achievements
