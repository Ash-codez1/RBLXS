--[[
	Reveal  (ServerScriptService.Server.Lib.Reveal)
	Builds LIFE REVEAL moments from a life's real state.

	Reveal.Stage(life, completedStage, rng) -> payload
	  End-of-stage reveal: predictions (Shared/Util/Futures), headline and
	  warning, cinematic archetype, who-you-became highlights, how the odds
	  moved since the last reveal, and maybe a TWIST that really changes the
	  life (Content/Twists) with odds before → after. Also writes the
	  predictions into the stage's life.Reveals snapshot.

	Reveal.Final(life, nextId) -> historyEntry
	  The final reveal / Life History entry: ending title, achievements,
	  greatest moments, biggest mistakes, key decisions, family, wealth,
	  career, stats, which futures came true, and the prediction journey.

	Reveal.Card(life) -> shareable summary for comparing with other players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Futures = require(Shared.Util.Futures)
local Endings = require(Shared.Util.Endings)
local Budget = require(Shared.Util.Budget)
local People = require(Shared.Util.People)
local StatMath = require(Shared.Util.StatMath)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local LifeStages = require(Shared.Data.LifeStages)
local Careers = require(Shared.Data.Careers)
local Traits = require(Shared.Data.Traits)
local Assets = require(Shared.Data.Assets)
local Config = require(Shared.Config)

local Conditions = require(script.Parent.Conditions)
local Consequences = require(script.Parent.Consequences)
local Content = script.Parent.Parent.Content
local Scenarios = require(Content.Scenarios)
local Twists = require(Content.Twists)

local Reveal = {}

Reveal.Twists = Twists
Reveal.TwistById = {}
for _, twist in ipairs(Twists) do
	Reveal.TwistById[twist.Id] = twist
end

Reveal.AchievementFlags = {
	Astronaut = "🚀 Went to space",
	SpaceHero = "🛰️ Saved a space mission",
	NobelPrize = "🏆 Won the world's top science prize",
	LotteryWinner = "🎰 Won the lottery",
	Celebrity = "🌟 Became a celebrity",
	Tycoon = "🏙️ Built a business empire",
	Champion = "🏅 Won a championship",
	WorldChampion = "🎮 Became world champion",
	Bestseller = "📚 Wrote a bestseller",
	Published = "✍️ Got published",
	Album = "💿 Recorded an album",
	AwardWinner = "🏆 Won a major award",
	LifetimeAward = "🎖️ Received a lifetime achievement award",
	Foundation = "🎁 Set up a charitable foundation",
	Philanthropist = "💝 Gave generously to charity",
	MiracleDoctor = "🩺 Performed a 'miracle' operation",
	PeoplesLawyer = "⚖️ Won a landmark case for a family in need",
	StarChef = "⭐ Earned a five-star review",
	Inventor = "💡 Patented an invention",
	Councillor = "🗳️ Was elected to the council",
	SavedPark = "🌳 Saved the local park",
	ChessChampion = "♟️ Became senior chess champion",
	Marathoner = "🏃 Ran a marathon",
	Sailor = "⛵ Sailed around the world",
	Honours = "🎓 Graduated with top honours",
	AppHit = "📱 Made a chart-topping app",
	Detective = "🕵️ Became a detective",
	LifeChangingTeacher = "🍎 Changed a student's life",
	Grandparent = "👶 Became a grandparent",
	ViralSenior = "📱 Became the internet's favourite grandparent",
	Prodigy = "🎹 Was a child prodigy",
}

local function round(n: number): number
	return math.floor(n + 0.5)
end

local function topPredictions(predictions, count: number)
	local positives = Futures.Sorted(predictions)
	local top = {}
	for i = 1, math.min(count, #positives) do
		table.insert(top, { Id = positives[i].Id, Pct = positives[i].Pct })
	end
	return top
end

-- Decides which kind of twist fits the current predictions.
local function pickTwist(life, predictions, rng, completedStage: number)
	local positives, risks = Futures.Sorted(predictions)
	local kind, counter
	if risks[1].Pct >= 45 then
		kind, counter = "Rescue", risks[1].Id
	elseif positives[1].Pct >= 60 then
		kind, counter = "Setback", positives[1].Id
	else
		kind = "Surprise"
	end
	local function candidates(wantKind, wantCounter)
		local list = {}
		for _, twist in ipairs(Twists) do
			if twist.Kind == wantKind and table.find(twist.Stages, completedStage) and not table.find(life.Events, twist.Id) and Conditions.Check(life, twist.Requires) then
				if not wantCounter or table.find(twist.Counters, wantCounter) then
					table.insert(list, twist)
				end
			end
		end
		return list
	end
	local list = candidates(kind, counter)
	if #list == 0 then
		list = candidates("Surprise", nil)
	end
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

-- Short "who you became" lines for the reveal.
local function becameHighlights(life)
	local lines = {}
	local traitList = {}
	for id, strength in pairs(life.Traits) do
		table.insert(traitList, { Id = id, Strength = strength })
	end
	table.sort(traitList, function(a, b)
		return a.Strength > b.Strength
	end)
	for i = 1, math.min(3, #traitList) do
		local info = Traits.Info[traitList[i].Id]
		if info then
			table.insert(lines, info.Icon .. " " .. info.DisplayName)
		end
	end
	-- Strongest and weakest stats.
	local order = table.clone(StatDefinitions.Order)
	table.sort(order, function(a, b)
		return life.Stats[a] > life.Stats[b]
	end)
	local strongest = StatDefinitions.Info[order[1]]
	table.insert(lines, ("%s Strongest: %s (%d)"):format(strongest.Icon, strongest.DisplayName, round(life.Stats[order[1]])))
	return lines
end

function Reveal.Stage(life, completedStage: number, rng)
	local record = life.Reveals[#life.Reveals]
	local previous = life.Reveals[#life.Reveals - 1]
	local before = Futures.Predict(life)
	local payload = {
		Stage = completedStage,
		StageName = LifeStages.Get(completedStage).DisplayName,
		NextStageName = if completedStage < LifeStages.Count then LifeStages.Get(completedStage + 1).DisplayName else nil,
		Age = life.Age,
		Became = becameHighlights(life),
		Previous = previous and previous.Predictions or nil,
	}

	local predictions = before
	if completedStage < LifeStages.Count and rng:NextNumber() < Config.TwistChance then
		local twist = pickTwist(life, before, rng, completedStage)
		if twist then
			local summary = Consequences.Apply(life, twist.Effects, rng)
			table.insert(life.Events, twist.Id)
			summary.Applied.Wealth = nil
			predictions = Futures.Predict(life)
			payload.Twist = {
				Id = twist.Id,
				Kind = twist.Kind,
				Icon = twist.Icon,
				Title = twist.Title,
				Story = summary.Story,
				Applied = summary.Applied,
				MoneyDelta = summary.MoneyDelta,
				LifeChanges = summary.LifeChanges,
				BondChanges = summary.BondChanges,
				Before = before,
			}
			if record then
				record.Stats = table.clone(life.Stats) -- a twist isn't a "trend"
				record.Money = life.Money
				record.Twist = twist.Id
			end
		end
	end

	local headline, warning = Futures.Headline(predictions)
	payload.Predictions = predictions
	payload.Headline = headline
	payload.Warning = warning
	payload.Archetype = Futures.Archetype(predictions)
	if record then
		record.Predictions = predictions
		record.Headline = headline
		record.Archetype = payload.Archetype
	end
	return payload
end

-- ===== Final reveal =====
local function decisionText(d): string
	if d.X and d.T then
		return ("Age %d: %s (%s)"):format(d.Age, d.X, d.T)
	end
	return ("Age %d: a choice that mattered"):format(d.Age)
end

function Reveal.Final(life, nextId: number)
	local ending, ctx = Endings.Determine(life)
	local outcomes = ctx.Outcomes
	local decisions = {}
	for _, d in ipairs(life.Decisions) do
		table.insert(decisions, d)
	end

	-- Key decisions: the most consequential choices, in life order.
	table.sort(decisions, function(a, b)
		return (a.I or 0) > (b.I or 0)
	end)
	local key = {}
	for i = 1, math.min(5, #decisions) do
		local d = decisions[i]
		table.insert(key, { Age = d.Age, Title = d.T or "", Choice = d.X or "" })
	end
	table.sort(key, function(a, b)
		return a.Age < b.Age
	end)

	-- Greatest moments and biggest mistakes by how good/bad they were.
	table.sort(decisions, function(a, b)
		return (a.G or 0) > (b.G or 0)
	end)
	local moments, mistakes = {}, {}
	for i = 1, math.min(3, #decisions) do
		if (decisions[i].G or 0) >= 6 then
			table.insert(moments, decisionText(decisions[i]))
		end
	end
	for i = #decisions, math.max(1, #decisions - 2), -1 do
		if (decisions[i].G or 0) <= -4 then
			table.insert(mistakes, decisionText(decisions[i]))
		end
	end
	for _, eventId in ipairs(life.Events) do
		local event = Scenarios.EventById[eventId]
		local twist = Reveal.TwistById[eventId]
		if event and (event.Rarity == "Rare" or event.Rarity == "Legendary") and #moments < 6 then
			table.insert(moments, event.Icon .. " " .. event.Title)
		elseif twist and twist.Kind ~= "Setback" and #moments < 6 then
			table.insert(moments, twist.Icon .. " " .. twist.Title)
		end
	end

	-- Moments shared with friends (group events in a Life Circle).
	for i = #(life.Shared or {}), 1, -1 do
		local shared = life.Shared[i]
		if #moments >= 7 then
			break
		end
		table.insert(moments, ("%s With %s: %s"):format(shared.Icon or "🤝", table.concat(shared.With or {}, " & "), shared.Title))
	end

	-- Achievements.
	local achievements = {}
	if outcomes.Millionaire then
		table.insert(achievements, "💰 Became a millionaire")
	end
	if outcomes.Career then
		table.insert(achievements, "💼 Reached the top of their field")
	end
	if (Careers.EducationRank[life.Education] or 0) >= 2 then
		table.insert(achievements, "🎓 Earned a " .. Careers.EducationNames[life.Education])
	end
	if life.Assets.House or life.Assets.Mansion or life.Assets.Apartment then
		table.insert(achievements, "🏠 Owned their own home")
	end
	for flagId, text in pairs(Reveal.AchievementFlags) do
		if life.Flags[flagId] then
			table.insert(achievements, text)
		end
	end
	table.sort(achievements)

	-- Family.
	local partner = People.Partner(life)
	local children = {}
	for _, child in ipairs(People.ByRole(life, "Child")) do
		table.insert(children, child.Name)
	end
	local bestFriend = People.ByRole(life, "BestFriend")[1]

	-- Prediction journey across the stages.
	local journey = {}
	for _, r in ipairs(life.Reveals) do
		if r.Predictions then
			table.insert(journey, { Stage = r.Stage, Age = r.Age, Top = topPredictions(r.Predictions, 3), Headline = r.Headline, Twist = r.Twist })
		end
	end

	local came = {}
	for _, id in ipairs(Futures.Order) do
		if outcomes[id] then
			table.insert(came, id)
		end
	end

	local stats = {}
	for _, statName in ipairs(StatDefinitions.Order) do
		stats[statName] = round(life.Stats[statName])
	end
	local bestCareer = life.BestCareer
	local overall = ctx.Overall
	local coins = math.floor(40 + overall + 5 * #came + (ending.Coins or 30))

	return {
		Id = nextId,
		Name = life.Name,
		Ending = { Id = ending.Id, Title = ending.Title, Icon = ending.Icon, Line = (ending.Line:gsub("{name}", life.Name)) },
		Age = life.Age,
		CompletedAt = os.time(),
		NetWorth = math.floor(ctx.NetWorth),
		Money = life.Money,
		Overall = round(overall),
		Stats = stats,
		Career = if bestCareer then Careers.TitleAt(bestCareer.Id, bestCareer.Level) else "No career",
		CareerId = if bestCareer then bestCareer.Id else "None",
		Education = Careers.EducationNames[life.Education] or "None",
		Partner = if partner then { Name = partner.Name, Married = partner.Married == true, Bond = round(partner.Bond) } else false,
		Children = children,
		BestFriend = if bestFriend then bestFriend.Name else false,
		Achievements = achievements,
		Moments = moments,
		Mistakes = mistakes,
		KeyDecisions = key,
		Journey = journey,
		CameTrue = came,
		DecisionCount = #life.Decisions,
		Coins = coins,
	}
end

-- ===== Shareable card for comparisons =====
function Reveal.Card(life, includeStats: boolean)
	local predictions = Futures.Predict(life)
	local headline = Futures.Headline(predictions)
	local card = {
		LifeName = life.Name,
		Age = life.Age,
		StageName = LifeStages.Get(life.Stage).DisplayName,
		Completed = life.Completed,
		Career = if life.Career.Id ~= "None" and Careers.Info[life.Career.Id] then Careers.TitleAt(life.Career.Id, life.Career.Level) elseif life.Flags.Retired then "Retired" else "—",
		Predictions = predictions,
		Headline = headline,
		Archetype = Futures.Archetype(predictions),
		Married = life.Relationships.Married,
		Children = life.Relationships.Children,
	}
	if includeStats then
		card.Stats = {}
		for _, statName in ipairs(StatDefinitions.Order) do
			card.Stats[statName] = round(life.Stats[statName])
		end
		card.NetWorth = math.floor(Budget.NetWorth(life))
		card.Overall = round(StatMath.Overall(life.Stats))
		-- Show off your lifestyle: homes, cars and more.
		local owned = {}
		for id in pairs(life.Assets) do
			local asset = Assets.Info[id]
			if asset then
				table.insert(owned, asset.Icon .. " " .. asset.Title)
			end
		end
		table.sort(owned)
		card.Assets = owned
	end
	return card
end

return Reveal
