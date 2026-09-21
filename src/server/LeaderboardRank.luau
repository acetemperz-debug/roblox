--!nonstrict
-- Competition rank: ties share a rank. No arbitrary Top-100/Top-1000 cutoff.
local LeaderboardRank = {}

function LeaderboardRank.calculate(store, score, keepGoing)
	if score <= 0 then return nil, "Unranked - earn your first score" end
	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, 100, score + 1)
		local ahead = 0
		while true do
			if keepGoing and not keepGoing() then error("Rank lookup cancelled") end
			ahead += #pages:GetCurrentPage()
			if pages.IsFinished then return ahead + 1 end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then return nil, "Rank unavailable - try again at this board" end
	return result, "YOUR GLOBAL RANK  #" .. tostring(result)
end

return LeaderboardRank
