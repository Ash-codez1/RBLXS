--[[
	Budget  (ReplicatedStorage.Shared.Util.Budget)
	One year of a life's money, broken down line by line. Pure and shared:
	the server uses it to advance years (Lib/Yearly); the client shows the
	same numbers in the Money panel, so what you see is what happens.
]]

local Careers = require(script.Parent.Parent.Data.Careers)
local Assets = require(script.Parent.Parent.Data.Assets)
local Lifestyle = require(script.Parent.Parent.Data.Lifestyle)

local Budget = {}

Budget.BaseSavingsRate = 0.22
Budget.ThriftyBonus = 0.03 -- per Thrifty trait strength
Budget.PartTimeIncome = 2500
Budget.UnemployedCost = 5000
Budget.ChildCost = 3500 -- per child under 18
Budget.RentCost = 3000 -- adults without a home of their own
Budget.PensionShare = 0.4 -- of peak salary

function Budget.OwnsHome(life): boolean
	return life.Assets.Apartment or life.Assets.House or life.Assets.Mansion or false
end

function Budget.ChildrenUnder18(life): number
	local count = 0
	for _, person in ipairs(life.People or {}) do
		if person.Role == "Child" and life.Age - person.BornAge < 18 then
			count += 1
		end
	end
	return count
end

function Budget.SavingsRate(life): number
	local focus = Lifestyle.Info[life.Focus or "Balanced"]
	return Budget.BaseSavingsRate + Budget.ThriftyBonus * math.min(life.Traits.Thrifty or 0, 5) + ((focus and focus.SavingsBonus) or 0)
end

function Budget.TotalDebt(life): number
	local total = 0
	for _, loan in ipairs(life.Loans or {}) do
		total += loan.Balance
	end
	return total
end

function Budget.NetWorth(life): number
	return life.Money + (life.Investments or 0) + Assets.TotalValue(life.Assets) - Budget.TotalDebt(life)
end

--[[
	Returns the year's lines (positive = money in, negative = out) and Net.
	Loan payments are listed separately because Yearly pays them from cash.
]]
function Budget.Breakdown(life, age: number?)
	age = age or life.Age
	local lines = {}
	local rate = Budget.SavingsRate(life)
	local salary = 0
	if life.Flags.Retired then
		salary = (life.PeakSalary or 0) * Budget.PensionShare
		lines.Pension = math.floor(salary * rate)
	elseif life.Career.Id ~= "None" then
		salary = Careers.SalaryAt(life.Career.Id, life.Career.Level)
		lines.Salary = math.floor(salary * rate)
	elseif (age :: number) >= 19 then
		lines.Unemployed = -Budget.UnemployedCost
	end
	if (age :: number) < 19 and life.Flags.PartTimeJob then
		lines.PartTime = Budget.PartTimeIncome
	end
	if (age :: number) >= 19 and not Budget.OwnsHome(life) then
		lines.Rent = -Budget.RentCost
	end
	local kids = Budget.ChildrenUnder18(life)
	if kids > 0 then
		lines.Children = -Budget.ChildCost * kids
	end
	local loanPayments = 0
	for _, loan in ipairs(life.Loans or {}) do
		loanPayments += math.min(loan.Payment, math.ceil(loan.Balance * (1 + loan.Rate)))
	end
	if loanPayments > 0 then
		lines.Loans = -loanPayments
	end
	local net = 0
	for _, amount in pairs(lines) do
		net += amount
	end
	return { Lines = lines, Net = net, GrossSalary = salary, SavingsRate = rate }
end

-- Fixed yearly repayment for a loan (standard amortisation).
function Budget.LoanPayment(amount: number, rate: number, years: number): number
	if rate <= 0 then
		return math.ceil(amount / years)
	end
	return math.ceil(amount * rate / (1 - (1 + rate) ^ -years))
end

return Budget
