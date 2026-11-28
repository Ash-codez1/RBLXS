--[[
	DailyService  (ServerScriptService.Server.Services.DailyService)
	Daily rewards and login streaks.
	  • One reward per UTC day: ClaimDaily() → Coins from Config.DailyRewards,
	    by your streak day (1–7, then the cycle repeats; day 7 is the big one).
	  • Claim on consecutive days to grow the streak; miss a day and it
	    starts again at 1. Your best streak is kept (achievements, profile).
	  • The server's clock decides the day; clients can't claim twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Challenges = require(Shared.Data.Challenges)
local Daily = require(Shared.Util.Daily)

local CoinRewards = require(script.Parent.Parent.Lib.CoinRewards)
local DataService = require(script.Parent.DataService)

local DailyService = {}
DailyService.Priority = 22

-- Today's UTC day number (tests replace this).
function DailyService.Today(): number
	return Challenges.DayOf(os.time())
end

-- What claiming today would give (for a profile).
function DailyService.Status(data)
	return Daily.Status(data.Daily, DailyService.Today(), os.time())
end

function DailyService.Claim(player: Player)
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	local result = nil
	DataService.Update(player, function(d)
		local status = DailyService.Status(d)
		if not status.Claimable then
			return
		end
		d.Daily.Streak = status.Streak
		d.Daily.LastClaimDay = status.Today
		d.Daily.BestStreak = math.max(d.Daily.BestStreak or 0, status.Streak)
		d.Lifetime.DailyClaims += 1
		result = { Coins = CoinRewards.GrantBonus(d, status.Reward), Streak = status.Streak, Day = status.Day }
	end)
	if not result then
		return false, "AlreadyClaimed"
	end
	return true, result
end

function DailyService.Init() end

function DailyService.Start()
	Net.Handle("ClaimDaily", function(player)
		return DailyService.Claim(player)
	end)
end

return DailyService
