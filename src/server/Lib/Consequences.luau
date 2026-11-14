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
		Partner      = true | false,    Married = true | false,
		Children     = 1,               Friends = 2,
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

local Consequences = {}

local function personalise(text: string?, life): string?
	if not text then
		return nil
	end
	return (text:gsub("{name}", life.Name))
end

function Consequences.NetWorth(life): number
	return life.Money + Assets.TotalValue(life.Assets)
end

function Consequences.SyncWealth(life)
	life.Stats.Wealth = StatMath.WealthFromNetWorth(Consequences.NetWorth(life))
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
	life.PeakSalary = math.max(life.PeakSalary or 0, Careers.SalaryAt(careerId, 1))
	table.insert(summary.LifeChanges, Careers.Info[careerId].Icon .. " New career: " .. Careers.TitleAt(careerId, 1))
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
	career.Level = newLevel
	career.YearsInRole = 0
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
	local rel = life.Relationships
	if block.Partner ~= nil then
		local had = rel.Partner == true
		rel.Partner = block.Partner == true
		if rel.Partner and not had then
			table.insert(summary.LifeChanges, "❤️ In a relationship")
		elseif had and not rel.Partner then
			rel.Married = false
			table.insert(summary.LifeChanges, "💔 Relationship ended")
		end
	end
	if block.Married ~= nil then
		local was = rel.Married == true
		rel.Married = block.Married == true
		if rel.Married then
			rel.Partner = true
			if not was then
				table.insert(summary.LifeChanges, "💍 Married")
			end
		elseif was then
			table.insert(summary.LifeChanges, "📄 Divorced")
		end
	end
	if type(block.Children) == "number" and block.Children ~= 0 then
		local before = rel.Children
		rel.Children = math.clamp(rel.Children + block.Children, 0, 12)
		local added = rel.Children - before
		if added == 1 then
			table.insert(summary.LifeChanges, "👶 A new child")
		elseif added > 1 then
			table.insert(summary.LifeChanges, ("👶 %d new children"):format(added))
		end
	end
	if type(block.Friends) == "number" then
		rel.Friends = math.clamp(rel.Friends + block.Friends, 0, 99)
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

function Consequences.NewSummary()
	return {
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
function Consequences.Apply(life, effects, rng, logStory: boolean?)
	local summary = Consequences.NewSummary()
	applyBlock(life, effects, summary)

	if effects.Outcomes then
		local roll = rng:NextNumber()
		local cumulative = 0
		for _, outcome in ipairs(effects.Outcomes) do
			cumulative += outcome.Chance
			if roll < cumulative then
				applyBlock(life, outcome, summary)
				summary.OutcomeTriggered = true
				break
			end
		end
	end

	Consequences.SyncWealth(life)
	summary.Story = table.concat(summary.StoryParts, " ")
	summary.StoryParts = nil
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
	if type(effects.Money) == "number" and math.abs(effects.Money) >= 1000 then
		table.insert(tags, (if effects.Money > 0 then "+" else "") .. Format.Money(effects.Money))
	end
	return preview, moneyDir, effects.Outcomes ~= nil, tags
end

return Consequences
