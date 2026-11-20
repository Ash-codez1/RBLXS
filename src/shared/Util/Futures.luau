--[[
	Futures  (ReplicatedStorage.Shared.Util.Futures)
	The prediction engine behind LIFE REVEAL.

	Futures.Predict(life) -> { [futureId] = percent 1..99 }
	  Estimates how likely each possible future is BY THE END OF THIS LIFE,
	  from the life's actual state: stats and their recent trajectory, money,
	  investments, property and debt, career and level, education, partner,
	  children and bonds, traits, flags, lifestyle focus and age.
	  Predictions sharpen as life goes on (less time left to change things).
	  Shared and pure: the server stores reveal snapshots; the client shows
	  live odds in the 🔮 Future panel using the same maths.

	Futures.Evaluate(life) -> { [futureId] = true/false }
	  What actually came true. Used by the final reveal, and by the test
	  suite to check that predictions are genuinely predictive.

	Futures.Headline(predictions) -> headline, warning?
	Futures.Archetype(predictions) -> "Luxury" | "Family" | "Fame" | ...
]]

local Budget = require(script.Parent.Budget)
local Careers = require(script.Parent.Parent.Data.Careers)
local Lifestyle = require(script.Parent.Parent.Data.Lifestyle)

local Futures = {}

Futures.FinalAge = 85

Futures.Info = {
	Millionaire = { Icon = "💰", Title = "Millionaire", Archetype = "Luxury", Positive = true, Headline = "Your decisions suggest you could become a millionaire." },
	Career = { Icon = "💼", Title = "Top of your field", Archetype = "Career", Positive = true, Headline = "You're on track for a hugely successful career." },
	Family = { Icon = "👨‍👩‍👧", Title = "Happy family", Archetype = "Family", Positive = true, Headline = "Your future suggests a warm, happy family life." },
	Fame = { Icon = "🌟", Title = "Famous", Archetype = "Fame", Positive = true, Headline = "You're on the path to becoming a famous celebrity." },
	Genius = { Icon = "🧠", Title = "Brilliant mind", Archetype = "Genius", Positive = true, Headline = "Your mind could take you to extraordinary places." },
	Healthy = { Icon = "💪", Title = "Long, healthy life", Archetype = "Health", Positive = true, Headline = "You're on course for a long and healthy life." },
	Respected = { Icon = "🏅", Title = "Widely respected", Archetype = "Hero", Positive = true, Headline = "People are going to look up to you." },
	Content = { Icon = "😊", Title = "Truly happy", Archetype = "Content", Positive = true, Headline = "Your choices point towards a genuinely happy life." },
	Adventurer = { Icon = "🧭", Title = "Adventurer", Archetype = "Adventure", Positive = true, Headline = "A life of adventure is calling you." },
	Struggling = { Icon = "🌧️", Title = "Hard times", Archetype = "Difficult", Positive = false, Headline = "Your financial decisions could put your future at risk." },
	Lonely = { Icon = "🪑", Title = "Lonely later life", Archetype = "Lonely", Positive = false, Headline = "You could end up lonely if you're not careful." },
}

-- What each future means at age 85 (tuned so each is meaningful, not a given).
Futures.Thresholds = {
	Millionaire = 1e6, -- net worth
	CareerLevel = 5, -- peak career level
	FamilyBond = 50, -- average bond with partner + children
	Fame = 80,
	Genius = 75,
	Healthy = 50,
	Respected = 78,
	Content = 85,
	StrugglingWorth = 75000,
	StrugglingHappiness = 55,
	LonelyRelationships = 45,
}

Futures.Order = { "Millionaire", "Career", "Family", "Fame", "Genius", "Healthy", "Respected", "Content", "Adventurer", "Struggling", "Lonely" }

local ADVENTURE_FLAGS = { "Traveller", "LivedAbroad", "Sailor", "Nomad", "Astronaut" }
local WILDCARD_FLAGS = { "StartupFounder", "Tycoon", "Celebrity", "BigExit", "Inventor", "AppHit", "Bestseller", "WorldChampion" }
local STAR_CAREERS = { Singer = true, Actor = true, Musician = true, Influencer = true, YouTuber = true, Athlete = true, ProGamer = true, Astronaut = true }

-- ===== What actually happened =====
local function partnerAndChildrenBond(life): number?
	local total, count = 0, 0
	for _, person in ipairs(life.People or {}) do
		if person.Role == "Partner" or person.Role == "Child" then
			total += person.Bond
			count += 1
		end
	end
	return if count > 0 then total / count else nil
end

local function anyFlag(life, flags): boolean
	for _, flag in ipairs(flags) do
		if life.Flags[flag] then
			return true
		end
	end
	return false
end

function Futures.Evaluate(life)
	local s = life.Stats
	local netWorth = Budget.NetWorth(life)
	local rel = life.Relationships
	local familyBond = partnerAndChildrenBond(life)
	local t = Futures.Thresholds
	return {
		Millionaire = netWorth >= t.Millionaire,
		Career = (life.PeakCareerLevel or 0) >= t.CareerLevel,
		Family = rel.Partner and rel.Children >= 1 and (familyBond or 0) >= t.FamilyBond,
		Fame = s.Popularity >= t.Fame or life.Flags.Celebrity == true,
		Genius = s.Intelligence >= t.Genius,
		Healthy = s.Health >= t.Healthy,
		Respected = s.Reputation >= t.Respected,
		Content = s.Happiness >= t.Content,
		Adventurer = (life.Traits.Adventurous or 0) >= 2 or anyFlag(life, ADVENTURE_FLAGS),
		Struggling = netWorth < t.StrugglingWorth or s.Happiness < t.StrugglingHappiness,
		Lonely = not rel.Partner and rel.Friends <= 1 and s.Relationships < t.LonelyRelationships,
	}
end

-- ===== Prediction helpers =====
local function logistic(x: number): number
	return 1 / (1 + math.exp(-x))
end

local function progressOf(life): number
	return math.clamp((life.Age - 5) / (Futures.FinalAge - 5), 0, 1)
end

-- Per-year stat drift since the previous reveal (dampened), or 0.
local function drift(life, stat: string): number
	local last = life.Reveals and life.Reveals[#life.Reveals]
	if not last or not last.Stats or not last.Age or last.Age >= life.Age then
		return 0
	end
	return (life.Stats[stat] - (last.Stats[stat] or life.Stats[stat])) / (life.Age - last.Age)
end

-- Health lost to ageing between now and 85 (mirrors Lib/Yearly).
local function ageingLoss(age: number): number
	local loss = 0
	for y = age, Futures.FinalAge - 1 do
		if y >= 70 then
			loss += 0.8
		elseif y >= 55 then
			loss += 0.4
		end
	end
	return loss
end

-- Projected final value of a stat: current + dampened trajectory + focus.
local function project(life, stat: string, extra: number?): number
	local yearsLeft = math.max(0, Futures.FinalAge - life.Age)
	local focus = Lifestyle.Info[life.Focus or "Balanced"]
	local perYear = (focus and focus.PerYear and focus.PerYear[stat]) or 0
	local value = life.Stats[stat] + drift(life, stat) * math.min(yearsLeft, 20) * 0.35 + perYear * math.min(yearsLeft, 30) * 0.4 + (extra or 0)
	return math.clamp(value, 0, 100)
end

-- P(final stat ≥ threshold): uncertainty shrinks as life progresses.
local function chanceAbove(life, projected: number, threshold: number): number
	local spread = 4 + 14 * (1 - progressOf(life))
	return logistic((projected - threshold) / spread)
end

-- Rough estimate of final net worth.
function Futures.ProjectNetWorth(life): number
	local age = life.Age
	local netWorth = Budget.NetWorth(life)
	local yearsLeft = math.max(0, Futures.FinalAge - age)
	local rate = Budget.SavingsRate(life)
	local workYears = math.max(0, 65 - math.max(age, 22))
	local annual
	if life.Flags.Retired then
		annual = Budget.Breakdown(life).Net
		workYears = yearsLeft
	elseif life.Career.Id ~= "None" and Careers.Info[life.Career.Id] then
		local level = life.Career.Level
		local expectedLevel = math.min(Careers.MaxLevel, level + workYears / 12)
		local salary = Careers.SalaryAt(life.Career.Id, (level + expectedLevel) / 2)
		annual = salary * rate - Budget.RentCost * 0.5
	else
		local potential = 18000 + 500 * life.Stats.Intelligence + 250 * life.Stats.Career + (if (Careers.EducationRank[life.Education] or 0) >= 2 then 20000 else 0)
		annual = potential * rate * (if age < 22 then 1 else 0.6) - Budget.RentCost * 0.6
	end
	local pensionYears = math.max(0, Futures.FinalAge - math.max(age, 65))
	local pension = (life.PeakSalary or 0) * Budget.PensionShare * rate
	local projected = netWorth + annual * workYears + (if life.Flags.Retired then 0 else pension * pensionYears)
	projected += (life.Investments or 0) * ((1.05 ^ math.min(yearsLeft, 40)) - 1)
	if anyFlag(life, WILDCARD_FLAGS) then
		projected *= 1.6
	end
	return projected
end

local function moneyChance(life, projected: number, target: number): number
	local sharpness = 1.2 + 3.5 * progressOf(life)
	return logistic((math.log10(math.max(projected, 1)) - math.log10(target)) * sharpness * 2.3)
end

-- ===== Predict =====
--[[
	Raw model probabilities (0..1) before calibration. Exposed so the
	calibration tool can fit Futures.Calibration from simulated lives.
]]
function Futures.Raw(life)
	local s = life.Stats
	local age = life.Age
	local progress = progressOf(life)
	local rel = life.Relationships
	local p = {}

	-- Money
	local projectedWorth = Futures.ProjectNetWorth(life)
	p.Millionaire = moneyChance(life, projectedWorth, Futures.Thresholds.Millionaire)
	local brokeChance = 1 - moneyChance(life, projectedWorth, Futures.Thresholds.StrugglingWorth)

	-- Career
	local peak = life.PeakCareerLevel or 0
	local t = Futures.Thresholds
	if peak >= t.CareerLevel then
		p.Career = 0.98
	elseif age < 22 and life.Career.Id == "None" then
		local edge = (s.Intelligence - 55) / 15 + (s.Career - 50) / 20 + 0.3 * (life.Traits.Ambitious or 0)
		if anyFlag(life, { "GoodGrades", "Honours", "FirstClass", "Scholarship" }) then
			edge += 0.5
		end
		p.Career = logistic(edge - 0.6)
	else
		local workYears = math.max(0, 65 - age)
		local focus = Lifestyle.Info[life.Focus or "Balanced"]
		local pace = (0.07 + math.max(0, s.Career - 45) / 500) * ((focus and focus.PromotionMultiplier) or 1)
		local level = if life.Career.Id ~= "None" then life.Career.Level else 0
		local projectedLevel = level + workYears * pace + (if level == 0 and workYears > 0 then -0.5 else 0)
		p.Career = logistic((projectedLevel - (t.CareerLevel - 0.5)) * (1.4 + 2 * progress))
	end

	-- Family
	local familyBond = partnerAndChildrenBond(life)
	local fam
	if age < 22 and not rel.Partner then
		fam = (s.Relationships - 50) / 18 + 0.15 * ((life.Traits.Kind or 0) + (life.Traits.Social or 0)) - 0.9
	else
		fam = -1.4
		if rel.Partner then
			fam += 1.3
		else
			fam -= math.max(0, age - 30) / 10
		end
		if rel.Married then
			fam += 0.5
		end
		if rel.Children >= 1 then
			fam += 1.3
		elseif age >= 45 then
			fam -= 2.5
		end
		if familyBond then
			-- Bonds fade over the decades unless maintained: project them forward.
			local yearsLeft = math.max(0, Futures.FinalAge - age)
			local projectedBond = familyBond - yearsLeft * 0.45
			fam += (projectedBond - t.FamilyBond) / 15
		end
		fam *= 1 + progress
	end
	p.Family = logistic(fam)

	-- Fame
	if life.Flags.Celebrity then
		p.Fame = 0.97
	else
		local boost = 0
		if STAR_CAREERS[life.Career.Id] then
			boost += 6 + 3 * life.Career.Level
		end
		if anyFlag(life, { "TeenFamous", "ChannelStarted", "StageStar", "StreamerSeed" }) then
			boost += 4
		end
		p.Fame = chanceAbove(life, project(life, "Popularity", boost), t.Fame)
	end

	p.Genius = chanceAbove(life, project(life, "Intelligence"), t.Genius)
	p.Healthy = chanceAbove(life, project(life, "Health", -ageingLoss(age) * 0.85), t.Healthy)
	p.Respected = chanceAbove(life, project(life, "Reputation", 4 * (1 - progress)), t.Respected)
	local projectedHappiness = project(life, "Happiness", 4)
	p.Content = chanceAbove(life, projectedHappiness, t.Content)

	-- Adventure: can only be gained, never lost.
	if (life.Traits.Adventurous or 0) >= 2 or anyFlag(life, ADVENTURE_FLAGS) then
		p.Adventurer = 0.97
	else
		p.Adventurer = logistic(1.1 * (life.Traits.Adventurous or 0) - 1.6 + 1.2 * (1 - progress) - 1.5 * progress)
	end

	-- Risks
	local unhappyChance = 1 - chanceAbove(life, projectedHappiness, t.StrugglingHappiness)
	p.Struggling = 1 - (1 - brokeChance) * (1 - unhappyChance)
	local lonely = -1.2
	if not rel.Partner then
		lonely += 0.6 + math.max(0, age - 30) / 25
	else
		lonely -= 1.2
	end
	lonely += (1 - math.min(rel.Friends, 4) / 2) * 0.8 + (t.LonelyRelationships - s.Relationships) / 15
	p.Lonely = logistic(lonely * (0.8 + progress))

	return p
end

--[[
	Calibration (Platt scaling with an age term), fitted by
	tests/tools/calibrate.luau --fit on simulated lives and checked on a
	separate, unseen set of lives by the test suite:
	    P = logistic(A + B × logit(raw) + C × progress)
	Re-run the fitter after big balance or content changes.
]]
Futures.Calibration = {
	Millionaire = { 0.282, 0.802, -2.901 },
	Career = { 0.343, 0.303, -3.433 },
	Family = { -2.505, 0.712, 0.299 },
	Fame = { 1.289, 1.647, -3.191 },
	Genius = { 0.729, 3.992, -2.043 },
	Healthy = { -0.204, 0.973, -0.941 },
	Respected = { 2.522, 2.555, -3.029 },
	Content = { -0.013, 0.940, -0.852 },
	Adventurer = { 0.572, 1.507, -2.094 },
	Struggling = { -1.345, 0.761, 1.918 },
	Lonely = { -2.767, 0.447, -0.779 },
}

local function logit(prob: number): number
	prob = math.clamp(prob, 0.001, 0.999)
	return math.log(prob / (1 - prob))
end
Futures.Logit = logit
Futures.Logistic = logistic

function Futures.Predict(life)
	local raw = Futures.Raw(life)
	local progress = progressOf(life)
	local result = {}
	for id, prob in pairs(raw) do
		local cal = Futures.Calibration[id]
		local value = prob
		if cal and prob < 0.97 then -- certainties (e.g. already famous) stay certain
			value = logistic(cal[1] + cal[2] * logit(prob) + cal[3] * progress)
		end
		result[id] = math.clamp(math.floor(value * 100 + 0.5), 1, 99)
	end
	return result
end

function Futures.Progress(life): number
	return progressOf(life)
end

-- Sorted list: { { Id, Pct, Icon, Title, Positive } } best first (positives), then risks.
function Futures.Sorted(predictions)
	local positives, risks = {}, {}
	for _, id in ipairs(Futures.Order) do
		local info = Futures.Info[id]
		local entry = { Id = id, Pct = predictions[id] or 0, Icon = info.Icon, Title = info.Title, Positive = info.Positive }
		table.insert(if info.Positive then positives else risks, entry)
	end
	table.sort(positives, function(a, b)
		return a.Pct > b.Pct
	end)
	table.sort(risks, function(a, b)
		return a.Pct > b.Pct
	end)
	return positives, risks
end

function Futures.Headline(predictions): (string, string?)
	local positives, risks = Futures.Sorted(predictions)
	local best, risk = positives[1], risks[1]
	local headline
	if best.Pct >= 55 then
		headline = Futures.Info[best.Id].Headline
	else
		headline = "Your future is uncertain. One major decision could change everything."
	end
	local warning = nil
	if risk.Pct >= 45 then
		warning = Futures.Info[risk.Id].Headline
		if risk.Id == "Struggling" and (predictions.Millionaire or 0) >= 40 then
			warning = "Money could be fine, but your happiness needs looking after."
		end
	end
	return headline, warning
end

function Futures.Archetype(predictions): string
	local positives, risks = Futures.Sorted(predictions)
	if risks[1].Pct >= 55 and risks[1].Pct >= positives[1].Pct then
		return Futures.Info[risks[1].Id].Archetype
	end
	return Futures.Info[positives[1].Id].Archetype
end

return Futures
