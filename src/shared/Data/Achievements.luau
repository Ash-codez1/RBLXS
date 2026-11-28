--[[
	Achievements  (ReplicatedStorage.Shared.Data.Achievements)
	Every achievement: name, description, icon, category, Coins reward and a
	Progress(data) function returning current, target. The server
	(ProgressService) unlocks one when current >= target; the client uses the
	same function for progress bars. Event achievements (Event = true) are
	unlocked directly by the system they belong to.
	Secret achievements show "???" and a hint until unlocked.
	Optional Roblox badges: Shared/Data/Badges.
]]

local Achievements = {}

Achievements.Categories = {
	{ Id = "Life", Name = "Life", Icon = "🌱" },
	{ Id = "Career", Name = "Career", Icon = "💼" },
	{ Id = "Family", Name = "Family", Icon = "❤️" },
	{ Id = "Wealth", Name = "Wealth", Icon = "💰" },
	{ Id = "Reveal", Name = "Life Reveal", Icon = "🔮" },
	{ Id = "World", Name = "Lifeville", Icon = "🌆" },
	{ Id = "Social", Name = "Friends", Icon = "🤝" },
	{ Id = "Collector", Name = "Collector", Icon = "✨" },
	{ Id = "Secret", Name = "Secret", Icon = "🕵️" },
}

Achievements.TotalStars = 20 -- Memory Stars hidden in Lifeville (Data/Collectibles)

local function count(set): number
	local n = 0
	for _ in pairs(set or {}) do
		n += 1
	end
	return n
end
Achievements.Count = count

local function lifetime(data, key: string): number
	local value = data.Lifetime and data.Lifetime[key]
	if type(value) == "table" then
		return count(value)
	end
	return tonumber(value) or 0
end

local function flag(data, setKey: string, id: string): number
	local set = data.Lifetime and data.Lifetime[setKey]
	return if type(set) == "table" and set[id] then 1 else 0
end

-- Highest value of fn(life or history entry) across saved lives and history.
local function best(data, fromLife, fromHistory): number
	local top = 0
	for _, life in pairs(data.Slots or {}) do
		if type(life) == "table" then
			top = math.max(top, fromLife(life) or 0)
		end
	end
	for _, entry in ipairs(data.LifeHistory or {}) do
		top = math.max(top, fromHistory(entry) or 0)
	end
	return top
end

local function counter(key: string, target: number)
	return function(data)
		return lifetime(data, key), target
	end
end

local function hasFlag(setKey: string, id: string)
	return function(data)
		return flag(data, setKey, id), 1
	end
end

local function event()
	return function(data, id)
		return if data.Achievements and data.Achievements[id] then 1 else 0, 1
	end
end

local function a(t)
	return t
end

Achievements.List = {
	-- ===== Life =====
	a({ Id = "FirstSteps", Name = "First Steps", Icon = "👣", Category = "Life", Coins = 15, Description = "Make your first decision.", Progress = counter("DecisionsMade", 1) }),
	a({ Id = "Decisions100", Name = "Choices, Choices", Icon = "🧭", Category = "Life", Coins = 60, Description = "Make 100 decisions.", Progress = counter("DecisionsMade", 100) }),
	a({ Id = "Decisions500", Name = "Decision Maker", Icon = "⚖️", Category = "Life", Coins = 200, Description = "Make 500 decisions.", Progress = counter("DecisionsMade", 500) }),
	a({ Id = "FirstStage", Name = "Growing Up", Icon = "🎒", Category = "Life", Coins = 20, Description = "Finish a life stage.", Progress = counter("StagesCompleted", 1) }),
	a({ Id = "FirstLife", Name = "A Life Well Lived", Icon = "🏁", Category = "Life", Coins = 80, Description = "Complete a whole life.", Progress = counter("LivesCompleted", 1) }),
	a({ Id = "ThreeLives", Name = "Third Time's the Charm", Icon = "🎲", Category = "Life", Coins = 150, Description = "Complete 3 lives.", Progress = counter("LivesCompleted", 3) }),
	a({ Id = "TenLives", Name = "Many Lifetimes", Icon = "♾️", Category = "Life", Coins = 400, Description = "Complete 10 lives.", Progress = counter("LivesCompleted", 10) }),
	a({ Id = "Rebirth", Name = "Born Again", Icon = "🌟", Category = "Life", Coins = 50, Description = "Start a new life with a Legacy perk.", Progress = counter("Rebirths", 1) }),

	-- ===== Career =====
	a({ Id = "FirstJob", Name = "Employed!", Icon = "💼", Category = "Career", Coins = 25, Description = "Get your first job.", Progress = counter("CareersHeld", 1) }),
	a({ Id = "CareerTop", Name = "Top of Your Field", Icon = "🏆", Category = "Career", Coins = 120, Description = "Reach the top level of a career.", Progress = counter("TopCareerLevel", 5) }),
	a({ Id = "FiveCareers", Name = "Jack of All Trades", Icon = "🧰", Category = "Career", Coins = 120, Description = "Have 5 different careers across your lives.", Progress = counter("CareersHeld", 5) }),
	a({ Id = "Overtime", Name = "Overtime Hero", Icon = "⏰", Category = "Career", Coins = 80, Description = "Work 10 extra shifts in Lifeville.", Progress = counter("ShiftsWorked", 10) }),

	-- ===== Family =====
	a({ Id = "LoveStory", Name = "Love Story", Icon = "💕", Category = "Family", Coins = 30, Description = "Fall in love.", Progress = function(data)
		return best(data, function(life)
			return if life.Relationships and life.Relationships.Partner then 1 else 0
		end, function(entry)
			return if entry.Partner then 1 else 0
		end), 1
	end }),
	a({ Id = "Married", Name = "Happily Ever After", Icon = "💍", Category = "Family", Coins = 50, Description = "Get married.", Progress = function(data)
		return best(data, function(life)
			return if life.Relationships and life.Relationships.Married then 1 else 0
		end, function(entry)
			return if entry.Partner and entry.Partner.Married then 1 else 0
		end), 1
	end }),
	a({ Id = "Parent", Name = "Bundle of Joy", Icon = "👶", Category = "Family", Coins = 50, Description = "Have a child.", Progress = function(data)
		return math.min(1, best(data, function(life)
			return life.Relationships and life.Relationships.Children or 0
		end, function(entry)
			return if type(entry.Children) == "table" then #entry.Children else 0
		end)), 1
	end }),
	a({ Id = "FullHouse", Name = "Full House", Icon = "🏡", Category = "Family", Coins = 120, Description = "Have 3 children in one life.", Progress = function(data)
		return math.min(3, best(data, function(life)
			return life.Relationships and life.Relationships.Children or 0
		end, function(entry)
			return if type(entry.Children) == "table" then #entry.Children else 0
		end)), 3
	end }),

	-- ===== Wealth =====
	a({ Id = "NestEgg", Name = "Nest Egg", Icon = "🥚", Category = "Wealth", Coins = 30, Description = "Reach a net worth of $10,000.", Progress = function(data)
		return math.min(lifetime(data, "HighestNetWorth"), 10000), 10000
	end }),
	a({ Id = "Millionaire", Name = "Millionaire", Icon = "💰", Category = "Wealth", Coins = 150, Description = "Reach a net worth of $1,000,000.", Progress = function(data)
		return math.min(lifetime(data, "HighestNetWorth"), 1000000), 1000000
	end }),
	a({ Id = "HomeOwner", Name = "Home Sweet Home", Icon = "🔑", Category = "Wealth", Coins = 60, Description = "Buy a home in one of your lives.", Progress = function(data)
		local owned = data.Lifetime and data.Lifetime.AssetsOwned or {}
		return if owned.Apartment or owned.House or owned.Mansion or owned.HolidayHome then 1 else 0, 1
	end }),
	a({ Id = "Mansion", Name = "Living Large", Icon = "🏰", Category = "Wealth", Coins = 150, Description = "Own a mansion.", Progress = hasFlag("AssetsOwned", "Mansion") }),
	a({ Id = "Investor", Name = "Investor", Icon = "📈", Category = "Wealth", Coins = 30, Description = "Invest some of your money.", Progress = counter("InvestActions", 1) }),
	a({ Id = "DebtFree", Name = "Debt Free", Icon = "🧾", Category = "Wealth", Coins = 60, Description = "Pay off a loan completely.", Progress = counter("LoansRepaid", 1) }),

	-- ===== Life Reveal =====
	a({ Id = "PlotTwist", Name = "Plot Twist", Icon = "🌀", Category = "Reveal", Coins = 40, Description = "Live through a Life Reveal twist.", Progress = counter("TwistsSeen", 1) }),
	a({ Id = "Prophecy", Name = "Prophecy Fulfilled", Icon = "🔮", Category = "Reveal", Coins = 100, Description = "Finish a life where 3 or more predicted futures came true.", Progress = function(data)
		return math.min(3, best(data, function()
			return 0
		end, function(entry)
			return if type(entry.CameTrue) == "table" then #entry.CameTrue else 0
		end)), 3
	end }),
	a({ Id = "FiveEndings", Name = "Many Endings", Icon = "📚", Category = "Reveal", Coins = 120, Description = "See 5 different life endings.", Progress = counter("EndingsSeen", 5) }),
	a({ Id = "TenEndings", Name = "Ending Collector", Icon = "🗂️", Category = "Reveal", Coins = 300, Description = "See 10 different life endings.", Progress = counter("EndingsSeen", 10) }),
	a({ Id = "Legendary", Name = "Legendary Life", Icon = "🌠", Category = "Reveal", Coins = 200, Description = "Get a legendary ending: Space Explorer, Nobel Mind, Billionaire or Lucky One.", Progress = function(data)
		local seen = data.Lifetime and data.Lifetime.EndingsSeen or {}
		return if seen.SpaceExplorer or seen.NobelMind or seen.Billionaire or seen.LuckyOne then 1 else 0, 1
	end }),

	-- ===== Lifeville =====
	a({ Id = "Tourist", Name = "Tourist", Icon = "📸", Category = "World", Coins = 30, Description = "Visit 5 districts of Lifeville.", Progress = counter("DistrictsVisited", 5) }),
	a({ Id = "Local", Name = "Lifeville Local", Icon = "🗺️", Category = "World", Coins = 100, Description = "Visit all 9 districts of Lifeville.", Progress = counter("DistrictsVisited", 9) }),
	a({ Id = "BusyBee", Name = "Busy Bee", Icon = "🐝", Category = "World", Coins = 80, Description = "Do 25 things around town.", Progress = counter("WorldActions", 25) }),
	a({ Id = "Chatterbox", Name = "Chatterbox", Icon = "💬", Category = "World", Coins = 60, Description = "Talk to 10 different townspeople.", Progress = counter("NPCsTalked", 10) }),
	a({ Id = "Wish", Name = "Make a Wish", Icon = "⛲", Category = "World", Coins = 15, Description = "Make a wish at the Plaza fountain.", Progress = counter("Wishes", 1) }),
	a({ Id = "Passport", Name = "Passport Stamped", Icon = "✈️", Category = "World", Coins = 60, Description = "Book a trip abroad at the harbour.", Progress = counter("Trips", 1) }),

	-- ===== Friends =====
	a({ Id = "Together", Name = "Better Together", Icon = "🤝", Category = "Social", Coins = 40, Description = "Join a Life Circle.", Progress = counter("CirclesJoined", 1) }),
	a({ Id = "Democracy", Name = "Democracy", Icon = "🗳️", Category = "Social", Coins = 40, Description = "Take part in a group decision.", Progress = counter("GroupDecisions", 1) }),
	a({ Id = "CivicSpirit", Name = "Civic Spirit", Icon = "🎪", Category = "Social", Coins = 30, Description = "Join a city event.", Progress = counter("CityEvents", 1) }),
	a({ Id = "FairTrade", Name = "Fair Trade", Icon = "🔄", Category = "Social", Coins = 40, Description = "Complete a trade with another player.", Progress = counter("TradesCompleted", 1) }),

	-- ===== Collector =====
	a({ Id = "FirstStar", Name = "Shooting Star", Icon = "⭐", Category = "Collector", Coins = 20, Description = "Find a Memory Star hidden in Lifeville.", Progress = function(data)
		return math.min(1, count(data.Collectibles)), 1
	end }),
	a({ Id = "AllStars", Name = "Star Collector", Icon = "🌟", Category = "Collector", Coins = 300, Description = ("Find all %d Memory Stars."):format(Achievements.TotalStars), Progress = function(data)
		return count(data.Collectibles), Achievements.TotalStars
	end }),
	a({ Id = "StyleIcon", Name = "Style Icon", Icon = "👗", Category = "Collector", Coins = 80, Description = "Own 10 shop items.", Progress = function(data)
		return math.min(10, count(data.Inventory and data.Inventory.Owned)), 10
	end }),
	a({ Id = "Dedicated", Name = "Dedicated", Icon = "🔥", Category = "Collector", Coins = 100, Description = "Reach a 7-day login streak.", Progress = function(data)
		return math.min(7, data.Daily and data.Daily.BestStreak or 0), 7
	end }),
	a({ Id = "Loyal", Name = "Loyal Resident", Icon = "🏅", Category = "Collector", Coins = 400, Description = "Reach a 30-day login streak.", Progress = function(data)
		return math.min(30, data.Daily and data.Daily.BestStreak or 0), 30
	end }),
	a({ Id = "Challenger", Name = "Challenge Accepted", Icon = "🎯", Category = "Collector", Coins = 100, Description = "Complete 10 daily or weekly challenges.", Progress = counter("ChallengesCompleted", 10) }),

	-- ===== Secret =====
	a({ Id = "S_Jackpot", Name = "Jackpot!", Icon = "🎰", Category = "Secret", Secret = true, Coins = 100, Hint = "Fortune favours the bold… and the lucky.", Description = "Get the Lucky One ending.", Progress = hasFlag("EndingsSeen", "LuckyOne") }),
	a({ Id = "S_Comeback", Name = "Rise from the Ashes", Icon = "🔥", Category = "Secret", Secret = true, Coins = 100, Hint = "Hit rock bottom, then climb.", Description = "Get the Comeback Kid ending.", Progress = hasFlag("EndingsSeen", "ComebackKid") }),
	a({ Id = "S_Unlucky", Name = "Murphy's Law", Icon = "🌧️", Category = "Secret", Secret = true, Coins = 100, Hint = "Some lives just go wrong.", Description = "Get the Unlucky One ending.", Progress = hasFlag("EndingsSeen", "UnluckyOne") }),
	a({ Id = "S_Astronaut", Name = "To the Stars", Icon = "🚀", Category = "Secret", Secret = true, Coins = 150, Hint = "Reach for the stars.", Description = "Become an astronaut.", Progress = hasFlag("CareersHeld", "Astronaut") }),
	a({ Id = "S_Billionaire", Name = "Billionaire", Icon = "💎", Category = "Secret", Secret = true, Coins = 200, Hint = "More money than you could ever spend.", Description = "Reach a net worth of $1,000,000,000.", Progress = function(data)
		return if lifetime(data, "HighestNetWorth") >= 1e9 then 1 else 0, 1
	end }),
	a({ Id = "S_NightOwl", Name = "Night Owl", Icon = "🦉", Category = "Secret", Secret = true, Event = true, Coins = 60, Hint = "Some wishes are best made under the stars.", Description = "Make a wish at the fountain at night.", Progress = event() }),
	a({ Id = "S_Lighthouse", Name = "Keeper of the Light", Icon = "🗼", Category = "Secret", Secret = true, Event = true, Coins = 60, Hint = "Look for the brightest light in Lifeville.", Description = "Find the Memory Star by the lighthouse.", Progress = event() }),
}

Achievements.ById = {}
for _, achievement in ipairs(Achievements.List) do
	Achievements.ById[achievement.Id] = achievement
end

-- current, target for achievement `id` (clamped).
function Achievements.ProgressOf(id: string, data): (number, number)
	local def = Achievements.ById[id]
	if not def then
		return 0, 1
	end
	local ok, current, target = pcall(def.Progress, data, id)
	if not ok then
		return 0, 1
	end
	current = tonumber(current) or 0
	target = tonumber(target) or 1
	return math.min(current, target), target
end

function Achievements.Unlocked(data): number
	return count(data.Achievements)
end

return Achievements
