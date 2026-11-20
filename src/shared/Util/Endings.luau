--[[
	Endings  (ReplicatedStorage.Shared.Util.Endings)
	Every finished life earns an ending title, decided from what actually
	happened (flags, career, money, family, stats, and how its predictions
	changed). The first matching ending in the list wins, so rarer endings
	come first. Shared so the client can show the list in Life History.
]]

local Budget = require(script.Parent.Budget)
local Futures = require(script.Parent.Futures)
local StatMath = require(script.Parent.StatMath)
local Careers = require(script.Parent.Parent.Data.Careers)

local Endings = {}

local function best(life)
	return life.BestCareer or { Id = "None", Level = 0 }
end

local function flag(life, ...)
	for _, f in ipairs({ ... }) do
		if life.Flags[f] then
			return true
		end
	end
	return false
end

local function everStruggled(life): boolean
	for _, reveal in ipairs(life.Reveals or {}) do
		if reveal.Predictions and (reveal.Predictions.Struggling or 0) >= 50 then
			return true
		end
	end
	return false
end

-- { Id, Title, Icon, Line, Coins, Check(life, ctx) }  ctx = { NetWorth, Outcomes, Overall }
Endings.List = {
	{ Id = "SpaceExplorer", Title = "The Space Explorer", Icon = "🚀", Coins = 60, Line = "{name} looked back at Earth from the stars.",
		Check = function(life)
			return flag(life, "Astronaut")
		end },
	{ Id = "NobelMind", Title = "The Nobel Mind", Icon = "🏆", Coins = 60, Line = "{name}'s discovery changed how the world understands itself.",
		Check = function(life)
			return flag(life, "NobelPrize")
		end },
	{ Id = "Billionaire", Title = "The Billionaire", Icon = "💎", Coins = 60, Line = "{name} built a fortune most people can't imagine.",
		Check = function(_, ctx)
			return ctx.NetWorth >= 1e9
		end },
	{ Id = "LuckyOne", Title = "The Lucky One", Icon = "🎰", Coins = 40, Line = "One ticket. Every number. {name}'s life was never the same.",
		Check = function(life)
			return flag(life, "LotteryWinner")
		end },
	{ Id = "Tycoon", Title = "The Tycoon", Icon = "🏙️", Coins = 50, Line = "{name} built an empire from a single idea.",
		Check = function(life)
			local b = best(life)
			return flag(life, "Tycoon") or ((b.Id == "Entrepreneur" or b.Id == "BusinessOwner" or b.Id == "RealEstate") and b.Level >= 5)
		end },
	{ Id = "SportingLegend", Title = "The Sporting Legend", Icon = "🏅", Coins = 50, Line = "Crowds still chant {name}'s name.",
		Check = function(life)
			local b = best(life)
			return flag(life, "Champion", "WorldChampion") or ((b.Id == "Athlete" or b.Id == "ProGamer") and b.Level >= 5)
		end },
	{ Id = "Celebrity", Title = "The Celebrity", Icon = "🌟", Coins = 45, Line = "Everyone knew {name}'s name, and many knew their songs, films or videos by heart.",
		Check = function(life)
			return flag(life, "Celebrity") and life.Stats.Popularity >= 75
		end },
	{ Id = "MultiMillionaire", Title = "The Multi-Millionaire", Icon = "💰", Coins = 45, Line = "{name} turned smart choices into serious wealth.",
		Check = function(_, ctx)
			return ctx.NetWorth >= 5e6
		end },
	{ Id = "FamilyLegend", Title = "The Family Legend", Icon = "👨‍👩‍👧‍👦", Coins = 45, Line = "{name}'s family will tell their stories for generations.",
		Check = function(life, ctx)
			return ctx.Outcomes.Family and life.Relationships.Children >= 2
		end },
	{ Id = "Philanthropist", Title = "The Philanthropist", Icon = "🎁", Coins = 45, Line = "{name} gave more than they ever took.",
		Check = function(life)
			return flag(life, "Foundation") or (flag(life, "Philanthropist") and life.Stats.Reputation >= 75)
		end },
	{ Id = "Genius", Title = "The Genius", Icon = "🧠", Coins = 40, Line = "{name}'s mind was a universe of its own.",
		Check = function(life)
			return life.Stats.Intelligence >= 82
		end },
	{ Id = "Healer", Title = "The Healer", Icon = "🩺", Coins = 40, Line = "Thousands of people are alive because of {name}.",
		Check = function(life)
			local b = best(life)
			return b.Id == "Doctor" and b.Level >= 4
		end },
	{ Id = "Adventurer", Title = "The Adventurer", Icon = "🧭", Coins = 35, Line = "{name} saw more of the world than most people dream of.",
		Check = function(life)
			return flag(life, "Sailor", "Nomad") or ((life.Traits.Adventurous or 0) >= 3 and flag(life, "LivedAbroad", "Traveller"))
		end },
	{ Id = "SelfMadeMillionaire", Title = "The Self-Made Millionaire", Icon = "💵", Coins = 40, Line = "No degree, no head start. Just {name}, and a lot of good decisions.",
		Check = function(life, ctx)
			return ctx.NetWorth >= 1e6 and (Careers.EducationRank[life.Education] or 0) < 2
		end },
	{ Id = "Millionaire", Title = "The Millionaire", Icon = "💰", Coins = 35, Line = "{name} built a seven-figure life.",
		Check = function(_, ctx)
			return ctx.NetWorth >= 1e6
		end },
	{ Id = "ComebackKid", Title = "The Comeback Kid", Icon = "🔥", Coins = 40, Line = "Everyone thought {name}'s story was heading for hard times. They wrote a different ending.",
		Check = function(life, ctx)
			return everStruggled(life) and not ctx.Outcomes.Struggling and ctx.Overall >= 58
		end },
	{ Id = "SelfMadeSuccess", Title = "The Self-Made Success", Icon = "💼", Coins = 40, Line = "No degree, no shortcuts. {name} climbed all the way to the top of their field.",
		Check = function(life, ctx)
			return ctx.Outcomes.Career and (Careers.EducationRank[life.Education] or 0) < 2
		end },
	{ Id = "HighFlyer", Title = "The High Flyer", Icon = "🛫", Coins = 35, Line = "{name} rose to the very top of their profession.",
		Check = function(_, ctx)
			return ctx.Outcomes.Career
		end },
	{ Id = "Beloved", Title = "The Beloved", Icon = "💞", Coins = 35, Line = "{name} was surrounded by love until the very end.",
		Check = function(life)
			return life.Stats.Relationships >= 70 and life.Stats.Happiness >= 70
		end },
	{ Id = "FreeSpirit", Title = "The Free Spirit", Icon = "🕊️", Coins = 30, Line = "{name} lived by their own rules, and loved every minute.",
		Check = function(life, ctx)
			return flag(life, "HappilySingle", "Nomad") and ctx.Outcomes.Content
		end },
	{ Id = "UnknownLegend", Title = "The Unknown Legend", Icon = "✨", Coins = 35, Line = "No headlines, no statues, just a truly great life, quietly lived.",
		Check = function(_, ctx)
			return ctx.Overall >= 66
		end },
	{ Id = "UnluckyOne", Title = "The Unlucky One", Icon = "🌧️", Coins = 25, Line = "Life threw everything at {name}. They kept getting back up.",
		Check = function(life, ctx)
			return ctx.Outcomes.Struggling and flag(life, "LostFortune", "LaidOff", "BurnedInvestor", "Divorced", "FailedStartup")
		end },
	{ Id = "Survivor", Title = "The Survivor", Icon = "🌱", Coins = 25, Line = "It wasn't easy. But {name} made it through, on their own terms.",
		Check = function(_, ctx)
			return ctx.Outcomes.Struggling
		end },
	{ Id = "QuietLife", Title = "The Quiet Life", Icon = "🏡", Coins = 30, Line = "{name} found happiness in the small, everyday things.",
		Check = function()
			return true
		end },
}

Endings.ById = {}
for _, ending in ipairs(Endings.List) do
	Endings.ById[ending.Id] = ending
end

function Endings.Context(life)
	return {
		NetWorth = Budget.NetWorth(life),
		Outcomes = Futures.Evaluate(life),
		Overall = StatMath.Overall(life.Stats),
	}
end

function Endings.Determine(life)
	local ctx = Endings.Context(life)
	for _, ending in ipairs(Endings.List) do
		if ending.Check(life, ctx) then
			return ending, ctx
		end
	end
	return Endings.List[#Endings.List], ctx
end

return Endings
