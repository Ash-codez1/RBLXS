--[[
	Yearly  (ServerScriptService.Server.Lib.Yearly)
	What happens to a life as years pass between decisions:
	  • income: salary × savings rate (Thrifty raises it); part-time jobs for teens;
	    pension in retirement; living costs when unemployed; costs of raising children
	  • career: years in role, with an automatic promotion chance for strong performers
	  • ageing: Health slowly declines after 50, faster after 70
	Called by LifeService inside the decision update, using the life's seeded RNG.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Careers = require(ReplicatedStorage:WaitForChild("Shared").Data.Careers)
local Consequences = require(script.Parent.Consequences)

local Yearly = {}

Yearly.BaseSavingsRate = 0.22
Yearly.ThriftyBonus = 0.03 -- per trait strength
Yearly.PartTimeIncome = 2500
Yearly.UnemployedCost = 5000
Yearly.ChildCost = 3500
Yearly.RentCost = 3000 -- adults without a home of their own
Yearly.PensionShare = 0.4 -- of peak salary
Yearly.AutoPromoteYears = 5
Yearly.AutoPromoteMinCareer = 55
Yearly.AutoPromoteChance = 0.5

function Yearly.SavingsRate(life): number
	return Yearly.BaseSavingsRate + Yearly.ThriftyBonus * math.min(life.Traits.Thrifty or 0, 5)
end

-- Net money for one year at `age`.
function Yearly.NetForYear(life, age: number): number
	local rate = Yearly.SavingsRate(life)
	local net = 0
	if life.Flags.Retired then
		net += (life.PeakSalary or 0) * Yearly.PensionShare * rate
	elseif life.Career.Id ~= "None" then
		net += Careers.SalaryAt(life.Career.Id, life.Career.Level) * rate
	elseif age >= 19 then
		net -= Yearly.UnemployedCost
	end
	if age < 19 and life.Flags.PartTimeJob then
		net += Yearly.PartTimeIncome
	end
	if age >= 19 and not (life.Assets.Apartment or life.Assets.House or life.Assets.Mansion) then
		net -= Yearly.RentCost
	end
	if age < 55 then
		net -= Yearly.ChildCost * life.Relationships.Children
	end
	return net
end

--[[
	Advances `years` years starting at `startAge`. Mutates life and adds to
	`summary` (a Consequences summary). Returns { Years, Income }.
]]
function Yearly.Advance(life, startAge: number, years: number, rng, summary)
	local income = 0
	local healthLoss = 0
	for i = 0, years - 1 do
		local age = startAge + i
		local before = life.Money
		life.Money = math.max(0, math.floor(life.Money + Yearly.NetForYear(life, age)))
		income += life.Money - before

		local career = life.Career
		if career.Id ~= "None" then
			career.YearsInRole += 1
			if career.YearsInRole >= Yearly.AutoPromoteYears and career.Level < Careers.MaxLevel and life.Stats.Career >= Yearly.AutoPromoteMinCareer then
				if rng:NextNumber() < Yearly.AutoPromoteChance then
					Consequences.Promote(life, 1, summary)
				end
			end
		end
		if age >= 70 then
			healthLoss += 1
		elseif age >= 50 then
			healthLoss += 0.5
		end
	end
	if healthLoss > 0 then
		Consequences.AddStats(life, { Health = -healthLoss }, summary, false)
	end
	summary.MoneyDelta += income
	Consequences.SyncWealth(life)
	return { Years = years, Income = income }
end

return Yearly
