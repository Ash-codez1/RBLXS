--[[
	Yearly  (ServerScriptService.Server.Lib.Yearly)
	What happens to a life as years pass between decisions. For each year:
	  • money: the budget from Shared/Util/Budget (salary savings, pension, rent,
	    unemployment, children under 18, loan repayments)
	  • investments: a market return (usually +, sometimes a crash)
	  • career: years in role; strong performers may be promoted automatically
	    (more likely with a Career focus)
	  • lifestyle focus: small stat changes each year (Shared/Data/Lifestyle)
	  • people: bonds fade unless maintained; close bonds lift Happiness and
	    pull the Relationships stat toward them; loneliness hurts; a very weak
	    partner bond can end the relationship
	  • ageing: Health slowly declines after 50, faster after 70
	Called by LifeService inside the decision update, with the life's seeded RNG.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Careers = require(Shared.Data.Careers)
local Lifestyle = require(Shared.Data.Lifestyle)
local Budget = require(Shared.Util.Budget)
local People = require(Shared.Util.People)
local Format = require(Shared.Util.Format)
local Consequences = require(script.Parent.Consequences)

local Yearly = {}

-- Re-exported for tests and tuning.
Yearly.BaseSavingsRate = Budget.BaseSavingsRate
Yearly.RentCost = Budget.RentCost
Yearly.ChildCost = Budget.ChildCost
Yearly.PensionShare = Budget.PensionShare
Yearly.AutoPromoteYears = 5
Yearly.AutoPromoteMinCareer = 55
Yearly.AutoPromoteChance = 0.5
Yearly.MarketReturn = 0.06
Yearly.MarketSwing = 0.24
Yearly.CrashChance = 0.05
Yearly.NeglectBond = 15 -- partner bond below this risks a break-up
Yearly.NeglectChance = 0.25

local function payLoans(life, summary)
	local paidTotal = 0
	for i = #life.Loans, 1, -1 do
		local loan = life.Loans[i]
		local owed = math.ceil(loan.Balance * (1 + loan.Rate))
		local due = math.min(loan.Payment, owed)
		local paid = math.min(due, life.Money)
		life.Money -= paid
		paidTotal += paid
		loan.Balance = owed - paid
		if loan.Balance <= 0 then
			table.remove(life.Loans, i)
			table.insert(summary.LifeChanges, "🎉 Paid off your " .. string.lower(Consequences.LoanKinds[loan.Kind].Title))
		end
	end
	return paidTotal
end

local function growInvestments(life, rng, summary): number
	if (life.Investments or 0) <= 0 then
		return 0
	end
	local r
	if rng:NextNumber() < Yearly.CrashChance then
		r = -0.3
	else
		r = Yearly.MarketReturn + (rng:NextNumber() - 0.5) * Yearly.MarketSwing
	end
	local before = life.Investments
	life.Investments = math.max(0, math.floor(before * (1 + r)))
	if r == -0.3 then
		table.insert(summary.LifeChanges, "📉 Market crash! Investments fell 30%")
	end
	return life.Investments - before
end

local function tendPeople(life, focus, summary, rng)
	for _, person in ipairs(life.People) do
		local info = People.Roles[person.Role]
		if info and info.Decay > 0 then
			local decay = if person.Married and info.MarriedDecay then info.MarriedDecay else info.Decay
			if focus.BondDecay then
				decay += (focus.BondDecay[person.Role] or 0) + (focus.BondDecay.All or 0)
			end
			People.ChangeBond(person, -decay) -- gradual drift: visible in the People panel, not as chips
		end
	end
	local partner = People.Partner(life)
	if partner and partner.Bond < Yearly.NeglectBond and rng:NextNumber() < Yearly.NeglectChance then
		local married = partner.Married
		Consequences.EndRelationship(life, summary, ("💔 You and %s drifted apart%s"):format(partner.Name, if married then " and divorced" else ""))
		Consequences.AddStats(life, { Happiness = -8 }, summary, false)
		if married then
			local before = life.Money
			life.Money = math.floor(life.Money * 0.75)
			summary.MoneyDelta += life.Money - before
		end
	end
end

local function relationshipMood(life, summary)
	local close = People.CloseBond(life)
	local deltas = {}
	if close then
		deltas.Happiness = (close - 50) / 50 * 0.8
		deltas.Relationships = (close - life.Stats.Relationships) * 0.12
	end
	local hasSomeone = People.Partner(life) ~= nil or life.Relationships.Friends > 0
	if life.Age >= 25 and not hasSomeone then
		deltas.Happiness = (deltas.Happiness or 0) - 0.5
	end
	if next(deltas) then
		Consequences.AddStats(life, deltas, summary, false)
	end
end

--[[
	Advances `years` years starting at `startAge`. Mutates life and adds to
	`summary` (a Consequences summary). Returns { Years, Income, Investment }.
]]
function Yearly.Advance(life, startAge: number, years: number, rng, summary)
	local income, investment = 0, 0
	local healthLoss = 0
	local focusTotals = {}
	local focus = Lifestyle.Info[life.Focus] or Lifestyle.Info.Balanced
	local savedAge = life.Age
	for i = 0, years - 1 do
		local age = startAge + i
		life.Age = age -- budget and people depend on the age during that year
		local before = life.Money
		local budget = Budget.Breakdown(life, age)
		local net = budget.Net - (budget.Lines.Loans or 0) -- loans paid separately below
		life.Money = math.max(0, math.floor(life.Money + net))
		payLoans(life, summary)
		income += life.Money - before
		investment += growInvestments(life, rng, summary)

		local career = life.Career
		if career.Id ~= "None" then
			career.YearsInRole += 1
			if career.YearsInRole >= Yearly.AutoPromoteYears and career.Level < Careers.MaxLevel and life.Stats.Career >= Yearly.AutoPromoteMinCareer then
				if rng:NextNumber() < Yearly.AutoPromoteChance * (focus.PromotionMultiplier or 1) then
					Consequences.Promote(life, 1, summary)
				end
			end
		end

		local perYear = if age < 19 and focus.YouthPerYear then focus.YouthPerYear else focus.PerYear
		for stat, delta in pairs(perYear or {}) do
			if not (stat == "Career" and age < 19) then
				focusTotals[stat] = (focusTotals[stat] or 0) + delta
			end
		end
		tendPeople(life, focus, summary, rng)
		relationshipMood(life, summary)

		if age >= 70 then
			healthLoss += 1
		elseif age >= 50 then
			healthLoss += 0.5
		end
	end
	life.Age = savedAge
	if healthLoss > 0 then
		focusTotals.Health = (focusTotals.Health or 0) - healthLoss
	end
	if next(focusTotals) then
		Consequences.AddStats(life, focusTotals, summary, false)
	end
	summary.MoneyDelta += income
	if investment ~= 0 then
		table.insert(summary.LifeChanges, ("%s Investments %s%s"):format(if investment > 0 then "📈" else "📉", if investment > 0 then "+" else "", Format.Money(investment)))
	end
	Consequences.SyncWealth(life)
	return { Years = years, Income = income, Investment = investment }
end

return Yearly
