--[[
	Consequences  (ServerScriptService.Server.Lib.Consequences)
	Applies an Effects table (from a choice or a random event) to a life IN
	PLACE and returns a summary for the client. LifeService calls it inside
	DataService.Update so a whole decision is applied atomically.

	Effects = {
		-- immediate
		Stats        = { Intelligence = 6, Happiness = -2 },  -- Wealth is derived; don't set it
		Money        = 50,              -- flat change
		MoneyPercent = -0.3,            -- change by a share of current money (e.g. a crash)
		-- long-term
		Flags        = { "StudiedEarly" }, ClearFlags = { "Shy" },
		Traits       = { Studious = 1 },
		Career       = "Doctor" | "None", -- start a new career at level 1 (or lose your job)
		Promote      = 1,               -- move up career levels
		Retire       = true,            -- stop working; pension from PeakSalary
		Education    = "University",    -- raised only if higher than current
		Partner      = true | false,    Married = true | false,   -- creates/ends named people
		Children     = 1,               Friends = 2,
		Meet         = "BestFriend",    -- a new person in a role (BestFriend promotes your closest friend)
		Bond         = { Partner = 8, Child = 5, Friend = 3, Parent = 4, BestFriend = 6, Sibling = 3, All = 2 },
		Loan         = { Kind = "Mortgage", Amount = 208000, Years = 25, Rate = 0.04 },
		RepayLoan    = { Kind = "Student", Amount = 1500 },
		InvestPercent = 0.25,           -- grow/shrink invested money
		Farewell     = "Parent",        -- someone in that role passes away (gently, late in life)
		Reunite      = true,            -- get back together with an ex (if single)
		Assets       = { "House" },     RemoveAssets = { "Apartment" },
		Story        = "Text. {name} is replaced.",
		Outcomes     = { { Chance = 0.3, ...any of the above... }, ... },  -- at most one triggers
	}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatMath = require(Shared.Util.StatMath)
local TableUtil = require(Shared.Util.TableUtil)
local Traits = require(Shared.Data.Traits)
local Careers = require(Shared.Data.Careers)
local Assets = require(Shared.Data.Assets)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local People = require(Shared.Util.People)
local Budget = require(Shared.Util.Budget)

local Consequences = {}

local function personalise(text: string?, life): string?
	if not text then
		return nil
	end
	return (text:gsub("{name}", life.Name))
end

function Consequences.NetWorth(life): number
	return Budget.NetWorth(life)
end

function Consequences.SyncWealth(life)
	life.Stats.Wealth = StatMath.WealthFromNetWorth(math.max(0, Consequences.NetWorth(life)))
end

Consequences.LoanKinds = { Student = { Rate = 0.03, Years = 15, Title = "Student loan" }, Mortgage = { Rate = 0.04, Years = 25, Title = "Mortgage" } }

-- Records a bond change for the outcome card (merged per person).
local function noteBond(summary, person, delta: number)
	if math.abs(delta) < 0.05 then
		return
	end
	for _, entry in ipairs(summary.BondChanges) do
		if entry.Id == person.Id then
			entry.Delta += delta
			return
		end
	end
	table.insert(summary.BondChanges, { Id = person.Id, Name = person.Name, Role = person.Role, Delta = delta })
end
Consequences.NoteBond = noteBond

function Consequences.ChangeBond(person, delta: number, summary)
	noteBond(summary, person, People.ChangeBond(person, delta))
end

-- Ends the current relationship: partner becomes an Ex.
function Consequences.EndRelationship(life, summary, text: string?)
	local partner = People.Partner(life)
	if not partner then
		return
	end
	local wasMarried = partner.Married == true
	partner.Role = "Ex"
	partner.Married = nil
	partner.Bond = math.min(partner.Bond, 25)
	People.Sync(life)
	table.insert(summary.LifeChanges, text or ((if wasMarried then "📄 Divorced from " else "💔 Broke up with ") .. partner.Name))
end

local function addStats(life, deltas, summary, useTraits: boolean)
	local multipliers = if useTraits then Traits.GainMultipliers(life.Traits) else {}
	local scaled = {}
	for stat, delta in pairs(deltas) do
		if stat ~= "Wealth" then
			scaled[stat] = if delta > 0 then delta * (multipliers[stat] or 1) else delta
		end
	end
	local newStats, applied = StatMath.Apply(life.Stats, scaled)
	life.Stats = newStats
	for stat, change in pairs(applied) do
		summary.Applied[stat] = (summary.Applied[stat] or 0) + change
	end
end
Consequences.AddStats = addStats

local function changeMoney(life, amount: number, summary)
	local before = life.Money
	life.Money = math.max(0, math.floor(life.Money + amount))
	summary.MoneyDelta += life.Money - before
end

local function setCareer(life, careerId: string, summary)
	if careerId == "None" then
		if life.Career.Id ~= "None" then
			table.insert(summary.LifeChanges, "💼 Left job as " .. Careers.TitleAt(life.Career.Id, life.Career.Level))
		end
		life.Career = { Id = "None", Level = 0, YearsInRole = 0 }
		return
	end
	if not Careers.Info[careerId] or life.Career.Id == careerId then
		return
	end
	life.Career = { Id = careerId, Level = 1, YearsInRole = 0 }
	life.Flags["Was_" .. careerId] = true
	life.PeakCareerLevel = math.max(life.PeakCareerLevel or 0, 1)
	Consequences.TrackBestCareer(life)
	life.PeakSalary = math.max(life.PeakSalary or 0, Careers.SalaryAt(careerId, 1))
	table.insert(summary.LifeChanges, Careers.Info[careerId].Icon .. " New career: " .. Careers.TitleAt(careerId, 1))
end

-- Remembers the best career this life ever had (for endings and Life History).
function Consequences.TrackBestCareer(life)
	local current = life.Career
	if current.Id == "None" then
		return
	end
	local bestCareer = life.BestCareer
	if not bestCareer or current.Level > bestCareer.Level or (current.Level == bestCareer.Level and Careers.SalaryAt(current.Id, current.Level) > Careers.SalaryAt(bestCareer.Id, bestCareer.Level)) then
		life.BestCareer = { Id = current.Id, Level = current.Level }
	end
end

-- Career Success needed for the top levels: 62+ for level 4, 80+ for level 5.
function Consequences.MaxLevelForCareerStat(careerStat: number): number
	if careerStat >= 80 then
		return 5
	elseif careerStat >= 62 then
		return 4
	end
	return 3
end

function Consequences.Promote(life, levels: number, summary)
	local career = life.Career
	if career.Id == "None" or not Careers.Info[career.Id] then
		return false
	end
	local newLevel = math.clamp(career.Level + levels, 1, Careers.MaxLevel)
	if newLevel == career.Level then
		return false
	end
	local up = newLevel > career.Level
	-- The top roles need a strong track record (Career Success stat).
	if up then
		local cap = Consequences.MaxLevelForCareerStat(life.Stats.Career)
		if newLevel > cap then
			if cap <= career.Level then
				table.insert(summary.LifeChanges, ("📋 Not quite ready to be %s yet: build your Career Success"):format(Careers.TitleAt(career.Id, career.Level + 1)))
				addStats(life, { Career = 3 }, summary, false)
				return false
			end
			newLevel = cap
		end
	end
	career.Level = newLevel
	career.YearsInRole = 0
	life.PeakCareerLevel = math.max(life.PeakCareerLevel or 0, newLevel)
	Consequences.TrackBestCareer(life)
	life.PeakSalary = math.max(life.PeakSalary or 0, Careers.SalaryAt(career.Id, newLevel))
	table.insert(summary.LifeChanges, (if up then "📈 Promoted to " else "📉 Demoted to ") .. Careers.TitleAt(career.Id, newLevel))
	addStats(life, { Career = if up then 6 else -6 }, summary, false)
	return true
end

-- Applies one Effects-shaped table (base effects or a single outcome).
local function applyBlock(life, block, summary)
	if block.Stats then
		addStats(life, block.Stats, summary, true)
	end
	if type(block.Money) == "number" and block.Money ~= 0 then
		changeMoney(life, block.Money, summary)
	end
	if type(block.MoneyPercent) == "number" and block.MoneyPercent ~= 0 then
		changeMoney(life, life.Money * block.MoneyPercent, summary)
	end
	if block.Flags then
		for _, flag in ipairs(block.Flags) do
			if not life.Flags[flag] then
				life.Flags[flag] = true
				table.insert(summary.FlagsAdded, flag)
			end
		end
	end
	if block.ClearFlags then
		for _, flag in ipairs(block.ClearFlags) do
			life.Flags[flag] = nil
		end
	end
	if block.Traits then
		for trait, change in pairs(block.Traits) do
			if Traits.IsValid(trait) then
				local before = life.Traits[trait] or 0
				local after = math.clamp(before + change, 0, Traits.MaxStrength)
				life.Traits[trait] = if after > 0 then after else nil
				if before == 0 and after > 0 then
					table.insert(summary.TraitsGained, trait)
				end
			end
		end
	end
	if block.Retire then
		if not life.Flags.Retired then
			life.Flags.Retired = true
			if life.Career.Id ~= "None" then
				table.insert(summary.LifeChanges, "🏖️ Retired as " .. Careers.TitleAt(life.Career.Id, life.Career.Level))
			else
				table.insert(summary.LifeChanges, "🏖️ Retired")
			end
			life.Career = { Id = "None", Level = 0, YearsInRole = 0 }
		end
	end
	if type(block.Career) == "string" then
		setCareer(life, block.Career, summary)
	end
	if type(block.Promote) == "number" and block.Promote ~= 0 then
		Consequences.Promote(life, block.Promote, summary)
	end
	if type(block.Education) == "string" and Careers.EducationRank[block.Education] then
		if Careers.EducationRank[block.Education] > (Careers.EducationRank[life.Education] or 0) then
			life.Education = block.Education
			if Careers.EducationRank[block.Education] >= 2 then
				table.insert(summary.LifeChanges, "🎓 Earned a " .. Careers.EducationNames[block.Education])
			end
		end
	end
	local rng = summary._rng
	if block.Reunite and not People.Partner(life) then
		local ex = People.ByRole(life, "Ex")[1]
		if ex then
			ex.Role = "Partner"
			ex.Bond = math.max(ex.Bond, 60)
			People.Sync(life)
			table.insert(summary.LifeChanges, "❤️ Back together with " .. ex.Name)
		end
	end
	if block.Partner ~= nil then
		local partner = People.Partner(life)
		if block.Partner == true and not partner then
			partner = People.Add(life, "Partner", rng)
			table.insert(summary.LifeChanges, "❤️ In a relationship with " .. partner.Name)
		elseif block.Partner == false and partner then
			Consequences.EndRelationship(life, summary)
		end
	end
	if block.Married ~= nil then
		local partner = People.Partner(life)
		if block.Married == true then
			if not partner then
				partner = People.Add(life, "Partner", rng)
			end
			if not partner.Married then
				partner.Married = true
				People.ChangeBond(partner, 10)
				table.insert(summary.LifeChanges, "💍 Married " .. partner.Name)
			end
		elseif partner and partner.Married then
			Consequences.EndRelationship(life, summary)
		end
		People.Sync(life)
	end
	if type(block.Children) == "number" and block.Children > 0 then
		local names = {}
		for _ = 1, math.min(block.Children, 12 - life.Relationships.Children) do
			table.insert(names, People.Add(life, "Child", rng).Name)
		end
		if #names == 1 then
			table.insert(summary.LifeChanges, "👶 Welcome, " .. names[1] .. "!")
		elseif #names > 1 then
			table.insert(summary.LifeChanges, "👶 Welcome, " .. table.concat(names, " & ") .. "!")
		end
	end
	if type(block.Friends) == "number" and block.Friends ~= 0 then
		if block.Friends > 0 then
			for _ = 1, block.Friends do
				if life.Relationships.Friends >= People.MaxFriends then
					break
				end
				local friend = People.Add(life, "Friend", rng)
				table.insert(summary.LifeChanges, "🙂 New friend: " .. friend.Name)
			end
		else
			for _ = 1, -block.Friends do
				local friends = People.ByRole(life, "Friend")
				table.sort(friends, function(a, b)
					return a.Bond < b.Bond
				end)
				if friends[1] then
					table.insert(summary.LifeChanges, "👋 Lost touch with " .. friends[1].Name)
					People.Remove(life, friends[1])
				end
			end
		end
	end
	if block.Meet == "BestFriend" and #People.ByRole(life, "BestFriend") == 0 then
		local friends = People.ByRole(life, "Friend")
		table.sort(friends, function(a, b)
			return a.Bond > b.Bond
		end)
		local best = friends[1] or People.Add(life, "Friend", rng)
		best.Role = "BestFriend"
		People.ChangeBond(best, 15)
		People.Sync(life)
		table.insert(summary.LifeChanges, "🫶 " .. best.Name .. " is now your best friend")
	elseif block.Meet == "Sibling" then
		local sibling = People.Add(life, "Sibling", rng)
		sibling.BornAge = life.Age
		table.insert(summary.LifeChanges, "🧒 A new sibling: " .. sibling.Name)
	elseif block.Meet == "Friend" and life.Relationships.Friends < People.MaxFriends then
		local friend = People.Add(life, "Friend", rng)
		table.insert(summary.LifeChanges, "🙂 New friend: " .. friend.Name)
	end
	if type(block.InvestPercent) == "number" and (life.Investments or 0) > 0 then
		local before = life.Investments
		life.Investments = math.max(0, math.floor(before * (1 + block.InvestPercent)))
		local change = life.Investments - before
		table.insert(summary.LifeChanges, ("%s Investments %s%s"):format(if change >= 0 then "📈" else "📉", if change >= 0 then "+" else "", Format.Money(change)))
	end
	if type(block.Farewell) == "string" then
		local person = People.ByRole(life, block.Farewell)[1]
		if person then
			People.Remove(life, person)
			table.insert(summary.LifeChanges, "🕊️ Said goodbye to " .. person.Name)
		end
	end
	if type(block.Bond) == "table" then
		for _, person in ipairs(life.People) do
			local delta = (block.Bond[person.Role] or 0) + (if person.Role ~= "Ex" then (block.Bond.All or 0) else 0)
			if delta ~= 0 then
				Consequences.ChangeBond(person, delta, summary)
			end
		end
	end
	if type(block.Loan) == "table" and Consequences.LoanKinds[block.Loan.Kind] then
		local kind = Consequences.LoanKinds[block.Loan.Kind]
		local rate = block.Loan.Rate or kind.Rate
		local years = block.Loan.Years or kind.Years
		table.insert(life.Loans, { Kind = block.Loan.Kind, Balance = block.Loan.Amount, Rate = rate, Payment = Budget.LoanPayment(block.Loan.Amount, rate, years) })
		table.insert(summary.LifeChanges, "🏦 " .. kind.Title .. ": " .. Format.Money(block.Loan.Amount))
	end
	if type(block.RepayLoan) == "table" then
		for i, loan in ipairs(life.Loans) do
			if loan.Kind == block.RepayLoan.Kind then
				local paid = math.min(loan.Balance, block.RepayLoan.Amount, life.Money)
				loan.Balance -= paid
				changeMoney(life, -paid, summary)
				if loan.Balance <= 0 then
					table.remove(life.Loans, i)
					table.insert(summary.LifeChanges, "🎉 Paid off your " .. string.lower(Consequences.LoanKinds[loan.Kind].Title))
				end
				break
			end
		end
	end
	if block.Assets then
		for _, id in ipairs(block.Assets) do
			if Assets.Info[id] and not life.Assets[id] then
				life.Assets[id] = true
				table.insert(summary.LifeChanges, Assets.Info[id].Icon .. " Bought: " .. Assets.Info[id].Title)
			end
		end
	end
	if block.RemoveAssets then
		for _, id in ipairs(block.RemoveAssets) do
			if life.Assets[id] then
				life.Assets[id] = nil
				table.insert(summary.LifeChanges, Assets.Info[id].Icon .. " Sold: " .. Assets.Info[id].Title)
			end
		end
	end
	local story = personalise(block.Story, life)
	if story then
		table.insert(summary.StoryParts, story)
	end
end

function Consequences.NewSummary(rng)
	return {
		_rng = rng,
		BondChanges = {},
		Applied = {},
		MoneyDelta = 0,
		FlagsAdded = {},
		TraitsGained = {},
		LifeChanges = {},
		StoryParts = {},
		OutcomeTriggered = false,
	}
end

--[[
	Applies effects (and possibly one chance Outcome) to `life`.
	Returns summary = { Applied, MoneyDelta, FlagsAdded, TraitsGained, LifeChanges, Story, OutcomeTriggered }
]]
-- Rolls which chance Outcome (if any) happens: returns its index, or 0 for none.
function Consequences.RollOutcome(effects, rng): number
	if not effects.Outcomes then
		return 0
	end
	local roll = rng:NextNumber()
	local cumulative = 0
	for index, outcome in ipairs(effects.Outcomes) do
		cumulative += outcome.Chance
		if roll < cumulative then
			return index
		end
	end
	return 0
end

--[[
	`forcedOutcome` (optional) decides the chance Outcome instead of rolling:
	group decisions roll once and pass the same index to every member, so
	friends who start a business together share the same fate, while each
	life still applies the effects to its own stats and money.
]]
function Consequences.Apply(life, effects, rng, logStory: boolean?, forcedOutcome: number?)
	local summary = Consequences.NewSummary(rng)
	applyBlock(life, effects, summary)

	if effects.Outcomes then
		local index = if forcedOutcome ~= nil then forcedOutcome else Consequences.RollOutcome(effects, rng)
		local outcome = effects.Outcomes[index]
		if outcome then
			applyBlock(life, outcome, summary)
			summary.OutcomeTriggered = true
		end
	end

	Consequences.SyncWealth(life)
	summary.Story = table.concat(summary.StoryParts, " ")
	summary.StoryParts = nil
	summary._rng = nil
	if logStory ~= false and summary.Story ~= "" then
		table.insert(life.Story, { Age = life.Age, Text = summary.Story })
		TableUtil.TrimArray(life.Story, Config.MaxStoryEntries)
	end
	return summary
end

--[[
	Consequence preview for the decision cards: direction + size of each base
	stat effect, never exact numbers, and never what chance Outcomes do.
	Returns { { Stat, Dir = 1|-1, Size = 1..3 } ... }, moneyDir, risky, tags
	`tags` are short hints for big life changes ("💼 New career", "🏠 Home").
]]
function Consequences.Preview(effects)
	local preview = {}
	if effects.Stats then
		for stat, delta in pairs(effects.Stats) do
			if delta ~= 0 and stat ~= "Wealth" then
				local size = if math.abs(delta) <= 4 then 1 elseif math.abs(delta) <= 8 then 2 else 3
				table.insert(preview, { Stat = stat, Dir = if delta > 0 then 1 else -1, Size = size })
			end
		end
	end
	table.sort(preview, function(a, b)
		if a.Dir ~= b.Dir then
			return a.Dir > b.Dir
		end
		if a.Size ~= b.Size then
			return a.Size > b.Size
		end
		return a.Stat < b.Stat
	end)
	local money = (effects.Money or 0) + (if effects.MoneyPercent then effects.MoneyPercent * 1e6 else 0)
	local moneyDir = if money > 0 then 1 elseif money < 0 then -1 else 0

	local tags = {}
	if type(effects.Career) == "string" and effects.Career ~= "None" and Careers.Info[effects.Career] then
		table.insert(tags, Careers.Info[effects.Career].Icon .. " " .. Careers.TitleAt(effects.Career, 1))
	elseif effects.Career == "None" then
		table.insert(tags, "💼 Leave job")
	end
	if effects.Promote and effects.Promote > 0 then
		table.insert(tags, "📈 Promotion")
	end
	if effects.Education then
		table.insert(tags, "🎓 " .. (Careers.EducationNames[effects.Education] or effects.Education))
	end
	if effects.Married then
		table.insert(tags, "💍 Marriage")
	elseif effects.Partner == true then
		table.insert(tags, "❤️ Romance")
	end
	if effects.Children and effects.Children > 0 then
		table.insert(tags, "👶 Family")
	end
	if effects.Assets then
		for _, id in ipairs(effects.Assets) do
			if Assets.Info[id] then
				table.insert(tags, Assets.Info[id].Icon .. " " .. Assets.Info[id].Title)
			end
		end
	end
	if effects.Retire then
		table.insert(tags, "🏖️ Retire")
	end
	if type(effects.Loan) == "table" then
		table.insert(tags, "🏦 Loan " .. Format.Money(effects.Loan.Amount))
	end
	if type(effects.Bond) == "table" then
		local up, down = false, false
		for _, delta in pairs(effects.Bond) do
			if delta > 0 then
				up = true
			elseif delta < 0 then
				down = true
			end
		end
		if up then
			table.insert(tags, "💞 Closer bonds")
		end
		if down then
			table.insert(tags, "💔 Strained bonds")
		end
	end
	if type(effects.Money) == "number" and math.abs(effects.Money) >= 1000 then
		table.insert(tags, (if effects.Money > 0 then "+" else "") .. Format.Money(effects.Money))
	end
	return preview, moneyDir, effects.Outcomes ~= nil, tags
end

return Consequences
