--[[
	Daily  (ReplicatedStorage.Shared.Util.Daily)
	The daily-reward rules, shared by DailyService (which decides) and the
	client (which shows them). Days are UTC days from the server clock.
]]

local Config = require(script.Parent.Parent.Config)

local Daily = {}

-- What claiming on `today` gives for a profile's Daily table.
function Daily.Status(daily, today: number, now: number)
	local last = daily.LastClaimDay or 0
	local claimable = last < today
	local streak = if claimable then (if last == today - 1 then (daily.Streak or 0) + 1 else 1) else (daily.Streak or 0)
	local cycleDay = ((math.max(streak, 1) - 1) % #Config.DailyRewards) + 1
	return {
		Claimable = claimable,
		Streak = streak,
		Day = cycleDay,
		Reward = Config.DailyRewards[cycleDay],
		Today = today,
		SecondsLeft = math.max(0, (today + 1) * 86400 - now),
	}
end

return Daily
