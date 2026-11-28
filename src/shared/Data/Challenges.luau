--[[
	Challenges  (ReplicatedStorage.Shared.Data.Challenges)
	Daily and weekly challenge pools. Each day (UTC) everyone gets the same
	Config.DailyChallengeCount challenges from the Daily pool, and each week
	(Monday to Sunday, UTC) Config.WeeklyChallengeCount from the Weekly pool.
	A challenge with Possible(lifetime) is skipped for anyone who can no
	longer do it (for example, they've already been to every district); they
	get the next one in that day's order instead.

	A challenge watches one or more Lifetime counters (or sets, which count
	new entries). Progress = how much they grew since the challenge began,
	so only things you do after it starts count. Rewards are Coins, granted
	automatically by ChallengeService when the target is reached.
]]

local NPCs = require(script.Parent.NPCs)
local World = require(script.Parent.World)

local Challenges = {}

local function size(set): number
	local n = 0
	for _ in pairs(type(set) == "table" and set or {}) do
		n += 1
	end
	return n
end

local TOWNSPEOPLE = #NPCs.List + #NPCs.Walkers

Challenges.Daily = {
	{ Id = "D_Decisions", Icon = "🧭", Text = "Make 5 decisions", Counter = { "DecisionsMade" }, Target = 5, Coins = 40 },
	{ Id = "D_World", Icon = "🌆", Text = "Do 3 things around Lifeville", Counter = { "WorldActions" }, Target = 3, Coins = 40 },
	{ Id = "D_Talk", Icon = "💬", Text = "Talk to 2 townspeople you haven't met", Counter = { "NPCsTalked" }, Target = 2, Coins = 30, Possible = function(lifetime)
		return size(lifetime.NPCsTalked) + 2 <= TOWNSPEOPLE
	end },
	{ Id = "D_Stage", Icon = "🎒", Text = "Finish a life stage", Counter = { "StagesCompleted" }, Target = 1, Coins = 50 },
	{ Id = "D_Coins", Icon = "🪙", Text = "Earn 60 Coins by playing", Counter = { "PlayCoins" }, Target = 60, Coins = 30 },
	{ Id = "D_Wish", Icon = "⛲", Text = "Make a wish at the Plaza fountain", Counter = { "Wishes" }, Target = 1, Coins = 25 },
	{ Id = "D_Shift", Icon = "💼", Text = "Work an extra shift at your workplace", Counter = { "ShiftsWorked" }, Target = 1, Coins = 40 },
	{ Id = "D_Social", Icon = "🤝", Text = "Join a group decision or a city event", Counter = { "GroupDecisions", "CityEvents" }, Target = 1, Coins = 40 },
	{ Id = "D_Explore", Icon = "🗺️", Text = "Visit a district you've never been to", Counter = { "DistrictsVisited" }, Target = 1, Coins = 30, Possible = function(lifetime)
		return size(lifetime.DistrictsVisited) < #World.Districts
	end },
}

Challenges.Weekly = {
	{ Id = "W_Decisions", Icon = "🧭", Text = "Make 40 decisions", Counter = { "DecisionsMade" }, Target = 40, Coins = 200 },
	{ Id = "W_Life", Icon = "🏁", Text = "Complete a life", Counter = { "LivesCompleted" }, Target = 1, Coins = 250 },
	{ Id = "W_World", Icon = "🌆", Text = "Do 20 things around Lifeville", Counter = { "WorldActions" }, Target = 20, Coins = 180 },
	{ Id = "W_Stages", Icon = "🎒", Text = "Finish 4 life stages", Counter = { "StagesCompleted" }, Target = 4, Coins = 200 },
	{ Id = "W_Shifts", Icon = "💼", Text = "Work 6 extra shifts", Counter = { "ShiftsWorked" }, Target = 6, Coins = 160 },
	{ Id = "W_Social", Icon = "🤝", Text = "Join 3 group decisions or city events", Counter = { "GroupDecisions", "CityEvents" }, Target = 3, Coins = 160 },
	{ Id = "W_Coins", Icon = "🪙", Text = "Earn 400 Coins by playing", Counter = { "PlayCoins" }, Target = 400, Coins = 150 },
	{ Id = "W_Twist", Icon = "🌀", Text = "Live through a Life Reveal twist", Counter = { "TwistsSeen" }, Target = 1, Coins = 150 },
}

Challenges.ById = {}
for _, list in ipairs({ Challenges.Daily, Challenges.Weekly }) do
	for _, c in ipairs(list) do
		Challenges.ById[c.Id] = c
	end
end

-- UTC day number and Monday-starting week number for a Unix time.
function Challenges.DayOf(unixTime: number): number
	return math.floor(unixTime / 86400)
end

function Challenges.WeekOf(day: number): number
	return math.floor((day + 3) / 7) -- 1 Jan 1970 was a Thursday
end

-- The challenge ids for a given day / week: the same order for every player.
-- With `lifetime`, challenges that player can no longer do are skipped.
local function pick(pool, count: number, seed: number, lifetime)
	local ids = {}
	for _, c in ipairs(pool) do
		table.insert(ids, c.Id)
	end
	local rng = Random.new(seed)
	for i = #ids, 2, -1 do
		local j = rng:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	local out = {}
	for _, id in ipairs(ids) do
		if #out >= count then
			break
		end
		local def = Challenges.ById[id]
		if not (lifetime and def.Possible and not def.Possible(lifetime)) then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

function Challenges.ForDay(day: number, count: number, lifetime: any?)
	return pick(Challenges.Daily, count, day * 7919 + 13, lifetime)
end

function Challenges.ForWeek(week: number, count: number, lifetime: any?)
	return pick(Challenges.Weekly, count, week * 104729 + 7, lifetime)
end

-- Current value of a challenge's counters (sets count their entries).
function Challenges.CounterValue(def, lifetime): number
	local total = 0
	for _, key in ipairs(def.Counter) do
		local value = lifetime and lifetime[key]
		if type(value) == "table" then
			for _ in pairs(value) do
				total += 1
			end
		else
			total += tonumber(value) or 0
		end
	end
	return total
end

-- progress, target for an active challenge entry { Base, Done }.
function Challenges.Progress(def, entry, lifetime): (number, number)
	if entry and entry.Done then
		return def.Target, def.Target
	end
	local base = entry and entry.Base or 0
	return math.clamp(Challenges.CounterValue(def, lifetime) - base, 0, def.Target), def.Target
end

return Challenges
