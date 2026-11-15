--[[
	Actions  (ServerScriptService.Server.Lib.Actions)
	Things a player can do between decisions, from the People, Lifestyle and
	Money panels. Every function validates its input, mutates `life` in place
	and returns ok, result | reason. LifeService wraps them in remotes and
	DataService.Update.

	People actions (limited to People.ActionsPerTurn per decision):
	  Interact(personId, "Time" | "Gift" | "Talk")
	  Meet("Friend" | "Love")
	Free actions:
	  SetFocus(focusId)
	  Invest(amount), Withdraw(amount), RepayLoan(index, amount)   (age 18+)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local People = require(Shared.Util.People)
local Lifestyle = require(Shared.Data.Lifestyle)
local Format = require(Shared.Util.Format)
local Consequences = require(script.Parent.Consequences)

local Actions = {}

Actions.MinFinanceAge = 18
Actions.MinLoveAge = 18

function Actions.ActionsLeft(life): number
	if life.ActionTurn ~= #life.Decisions then
		return People.ActionsPerTurn
	end
	return math.max(0, People.ActionsPerTurn - life.ActionsUsed)
end

local function useAction(life)
	if life.ActionTurn ~= #life.Decisions then
		life.ActionTurn = #life.Decisions
		life.ActionsUsed = 0
	end
	life.ActionsUsed += 1
end

local function finish(life, summary, text: string)
	Consequences.SyncWealth(life)
	return true, {
		Text = text,
		Applied = summary.Applied,
		BondChanges = summary.BondChanges,
		LifeChanges = summary.LifeChanges,
		ActionsLeft = Actions.ActionsLeft(life),
	}
end

function Actions.Interact(life, personId: string, action: string, rng)
	if life.Completed then
		return false, "NoLife"
	end
	local person = People.Find(life, personId)
	if not person then
		return false, "NoSuchPerson"
	end
	if action ~= "Time" and action ~= "Gift" and action ~= "Talk" then
		return false, "BadAction"
	end
	if person.Role == "Ex" and action ~= "Talk" then
		return false, "BadAction"
	end
	if Actions.ActionsLeft(life) <= 0 then
		return false, "NoActionsLeft"
	end
	local summary = Consequences.NewSummary(rng)
	local text
	if action == "Time" then
		Consequences.ChangeBond(person, 7, summary)
		Consequences.AddStats(life, { Happiness = 1 }, summary, false)
		text = "You spent quality time with " .. person.Name .. "."
	elseif action == "Gift" then
		local cost = People.GiftCost(life)
		if life.Money < cost then
			return false, "NotEnoughMoney"
		end
		life.Money -= cost
		summary.MoneyDelta -= cost
		Consequences.ChangeBond(person, 10, summary)
		text = ("You gave %s a gift (%s). They loved it!"):format(person.Name, Format.Money(cost))
	else
		local deep = rng:NextNumber() < 0.25
		Consequences.ChangeBond(person, if deep then 9 else 4, summary)
		Consequences.AddStats(life, { Relationships = 1 }, summary, false)
		text = if deep then ("You and %s had a heart-to-heart that brought you much closer."):format(person.Name) else ("You had a good talk with %s."):format(person.Name)
	end
	useAction(life)
	return finish(life, summary, text)
end

function Actions.Meet(life, kind: string, rng)
	if life.Completed then
		return false, "NoLife"
	end
	if kind ~= "Friend" and kind ~= "Love" then
		return false, "BadAction"
	end
	if Actions.ActionsLeft(life) <= 0 then
		return false, "NoActionsLeft"
	end
	local summary = Consequences.NewSummary(rng)
	local text
	if kind == "Friend" then
		if life.Relationships.Friends >= People.MaxFriends then
			return false, "TooManyFriends"
		end
		local chance = 0.35 + life.Stats.Popularity / 200
		if rng:NextNumber() < chance then
			local friend = People.Add(life, "Friend", rng)
			table.insert(summary.LifeChanges, "🙂 New friend: " .. friend.Name)
			text = "You hit it off with " .. friend.Name .. "!"
		else
			text = "You put yourself out there, but nobody clicked this time."
		end
	else
		if life.Age < Actions.MinLoveAge then
			return false, "TooYoung"
		end
		if People.Partner(life) then
			return false, "AlreadyTaken"
		end
		local chance = 0.25 + (life.Stats.Popularity + life.Stats.Happiness) / 400
		if rng:NextNumber() < chance then
			local partner = People.Add(life, "Partner", rng)
			table.insert(summary.LifeChanges, "❤️ In a relationship with " .. partner.Name)
			Consequences.AddStats(life, { Happiness = 5 }, summary, false)
			text = ("You met %s. Sparks flew!"):format(partner.Name)
		else
			Consequences.AddStats(life, { Happiness = -1 }, summary, false)
			text = "A few dates, but no spark. Maybe next time."
		end
	end
	useAction(life)
	return finish(life, summary, text)
end

function Actions.SetFocus(life, focusId: string)
	if not Lifestyle.IsValid(focusId) then
		return false, "BadFocus"
	end
	if not Lifestyle.Available(focusId, life.Age) then
		return false, "TooYoung"
	end
	life.Focus = focusId
	return true, { Focus = focusId }
end

local function checkAmount(amount: any, max: number): number?
	if type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > max then
		return nil
	end
	return amount
end

function Actions.Invest(life, amount: any)
	if life.Age < Actions.MinFinanceAge then
		return false, "TooYoung"
	end
	local value = checkAmount(amount, life.Money)
	if not value then
		return false, "BadAmount"
	end
	life.Money -= value
	life.Investments = (life.Investments or 0) + value
	Consequences.SyncWealth(life)
	return true, { Money = life.Money, Investments = life.Investments }
end

function Actions.Withdraw(life, amount: any)
	if life.Age < Actions.MinFinanceAge then
		return false, "TooYoung"
	end
	local value = checkAmount(amount, life.Investments or 0)
	if not value then
		return false, "BadAmount"
	end
	life.Investments -= value
	life.Money += value
	Consequences.SyncWealth(life)
	return true, { Money = life.Money, Investments = life.Investments }
end

function Actions.RepayLoan(life, index: any, amount: any)
	if type(index) ~= "number" or index % 1 ~= 0 then
		return false, "BadLoan"
	end
	local loan = life.Loans[index]
	if not loan then
		return false, "BadLoan"
	end
	local value = checkAmount(amount, math.min(life.Money, loan.Balance))
	if not value then
		return false, "BadAmount"
	end
	life.Money -= value
	loan.Balance -= value
	local paidOff = loan.Balance <= 0
	if paidOff then
		table.remove(life.Loans, index)
	end
	Consequences.SyncWealth(life)
	return true, { Money = life.Money, PaidOff = paidOff }
end

return Actions
