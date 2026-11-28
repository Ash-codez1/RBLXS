--[[
	Leaderboards  (ReplicatedStorage.Shared.Data.Leaderboards)
	The boards shown in 🏆 Leaderboards (global and friends) and on the Hall
	of Fame in Lifeville Plaza. Value(data) is what a player scores, read
	from their saved profile by the server (never sent by a client).
]]

local Leaderboards = {}

local function count(set): number
	local n = 0
	for _ in pairs(set or {}) do
		n += 1
	end
	return n
end

Leaderboards.List = {
	{ Id = "LivesCompleted", Name = "Lives lived", Icon = "🏁", Value = function(data)
		return data.Lifetime.LivesCompleted or 0
	end },
	{ Id = "HighestNetWorth", Name = "Richest life", Icon = "💰", Money = true, Value = function(data)
		return math.floor(data.Lifetime.HighestNetWorth or 0)
	end },
	{ Id = "Achievements", Name = "Achievements", Icon = "🏆", Value = function(data)
		return count(data.Achievements)
	end },
	{ Id = "BestStreak", Name = "Best login streak", Icon = "🔥", Value = function(data)
		return data.Daily.BestStreak or 0
	end },
	{ Id = "Stars", Name = "Memory Stars", Icon = "⭐", Value = function(data)
		return count(data.Collectibles)
	end },
}

Leaderboards.ById = {}
for _, board in ipairs(Leaderboards.List) do
	Leaderboards.ById[board.Id] = board
end

Leaderboards.HallOfFame = "LivesCompleted" -- the board shown in the Plaza

return Leaderboards
