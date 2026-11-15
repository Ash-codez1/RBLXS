--[[
	Scenarios  (ServerScriptService.Server.Content.Scenarios)  — ModuleScript with children
	Collects every stage module in this folder into one pool, builds an Id
	index and validates all content at startup.

	Scenario fields:
	  Id (unique), Stage (1–6), Title, Description, Icon (emoji)
	  Choices    3–5 choices: { Id, Text, Description, Effects, Requires?, LockHint?, Mystery? }
	  Requires?  scenario only appears if this passes (see Lib/Conditions)
	  Once?      at most once per life
	  Priority?  highest-priority eligible scenario is always picked first
	  Weight?    base random weight (default 1)
	  Boost?     { Flags = { Flag = multiplier }, Traits = { Trait = multiplier } }

	Choice fields:
	  Requires + LockHint   choice is shown LOCKED with the hint unless Requires
	                        passes, which hints at hidden branches and encourages replays
	  Mystery = true        consequence preview hidden ("???")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatDefinitions = require(Shared.Data.StatDefinitions)
local Traits = require(Shared.Data.Traits)
local Careers = require(Shared.Data.Careers)
local Assets = require(Shared.Data.Assets)
local People = require(Shared.Util.People)

local Scenarios = {}
Scenarios.All = {}
Scenarios.ById = {}
Scenarios.Issues = {}

local function issue(text)
	table.insert(Scenarios.Issues, text)
	warn("[Scenarios] " .. text)
end

local function validateEffects(where, effects, requires)
	if type(effects) ~= "table" then
		issue(where .. ": missing Effects")
		return
	end
	local function checkBlock(label, block)
		for stat, delta in pairs(block.Stats or {}) do
			if not StatDefinitions.IsValid(stat) then
				issue(label .. ": unknown stat " .. tostring(stat))
			elseif stat == "Wealth" then
				issue(label .. ": Wealth is derived from money; use Money instead")
			elseif type(delta) ~= "number" then
				issue(label .. ": non-number delta for " .. stat)
			end
		end
		for trait in pairs(block.Traits or {}) do
			if not Traits.IsValid(trait) then
				issue(label .. ": unknown trait " .. tostring(trait))
			end
		end
		if block.Career ~= nil and not Careers.IsValid(block.Career) then
			issue(label .. ": unknown career " .. tostring(block.Career))
		end
		if block.Education ~= nil and not Careers.EducationRank[block.Education] then
			issue(label .. ": unknown education " .. tostring(block.Education))
		end
		for _, list in ipairs({ block.Assets or {}, block.RemoveAssets or {} }) do
			for _, id in ipairs(list) do
				if not Assets.IsValid(id) then
					issue(label .. ": unknown asset " .. tostring(id))
				end
			end
		end
		if block.Bond then
			for role in pairs(block.Bond) do
				if role ~= "All" and not People.IsRole(role) then
					issue(label .. ": unknown Bond role " .. tostring(role))
				end
			end
		end
		if block.Meet and not ({ BestFriend = true, Friend = true, Sibling = true })[block.Meet] then
			issue(label .. ": Meet must be BestFriend, Friend or Sibling")
		end
		if block.Loan and not ({ Student = true, Mortgage = true })[block.Loan.Kind] then
			issue(label .. ": unknown Loan kind")
		end
		-- Big purchases ($10k+) must be gated by MinMoney so nothing is ever "free".
		-- Smaller costs may floor at $0 (you can always scrape together a wedding).
		if type(block.Money) == "number" and block.Money <= -10000 then
			local min = requires and requires.MinMoney or 0
			if min < -block.Money then
				issue(label .. (": spends %d but Requires.MinMoney is %d"):format(-block.Money, min))
			end
		end
	end
	checkBlock(where, effects)
	local total = 0
	for i, outcome in ipairs(effects.Outcomes or {}) do
		if type(outcome.Chance) ~= "number" or outcome.Chance <= 0 then
			issue(where .. ": outcome " .. i .. " needs a positive Chance")
		else
			total += outcome.Chance
		end
		checkBlock(where .. " outcome " .. i, outcome)
	end
	if total > 1.0001 then
		issue(where .. ": outcome chances add up to more than 1")
	end
end
Scenarios.ValidateEffects = validateEffects

local function validateRequires(where, requires)
	if not requires then
		return
	end
	for _, key in ipairs({ "Careers", "NotCareers" }) do
		for _, id in ipairs(requires[key] or {}) do
			if not Careers.IsValid(id) then
				issue(where .. ": unknown career in Requires." .. key .. ": " .. tostring(id))
			end
		end
	end
	for _, key in ipairs({ "MinEducation", "MaxEducation" }) do
		if requires[key] and not Careers.EducationRank[requires[key]] then
			issue(where .. ": unknown education in Requires." .. key)
		end
	end
	for _, key in ipairs({ "HasRole", "NotRole" }) do
		for _, role in ipairs(requires[key] or {}) do
			if not People.IsRole(role) then
				issue(where .. ": unknown role in Requires." .. key .. ": " .. tostring(role))
			end
		end
	end
	for _, key in ipairs({ "MinBond", "MaxBond" }) do
		for role in pairs(requires[key] or {}) do
			if not People.IsRole(role) then
				issue(where .. ": unknown role in Requires." .. key .. ": " .. tostring(role))
			end
		end
	end
	for _, key in ipairs({ "MinStats", "MaxStats" }) do
		for stat in pairs(requires[key] or {}) do
			if not StatDefinitions.IsValid(stat) then
				issue(where .. ": unknown stat in Requires." .. key .. ": " .. tostring(stat))
			end
		end
	end
end

function Scenarios.Register(list)
	for _, scenario in ipairs(list) do
		local id = scenario.Id
		if type(id) ~= "string" or not id:match("^[%w_]+$") then
			issue("scenario with invalid Id: " .. tostring(id))
			continue
		end
		if Scenarios.ById[id] then
			issue("duplicate scenario Id " .. id)
			continue
		end
		if scenario.Stages then
			for _, stage in ipairs(scenario.Stages) do
				if type(stage) ~= "number" or stage < 1 or stage > 6 then
					issue(id .. ": invalid entry in Stages")
				end
			end
		elseif type(scenario.Stage) ~= "number" or scenario.Stage < 1 or scenario.Stage > 6 then
			issue(id .. ": invalid Stage")
		end
		local choices = scenario.Choices or {}
		if #choices < 3 or #choices > 5 then
			issue(id .. ": should have 3–5 choices (has " .. #choices .. ")")
		end
		validateRequires(id, scenario.Requires)
		local unlocked = 0
		local seen = {}
		scenario.ChoiceById = {}
		for _, choice in ipairs(choices) do
			if type(choice.Id) ~= "string" or not choice.Id:match("^[%w_]+$") then
				issue(id .. ": choice with invalid Id")
			elseif seen[choice.Id] then
				issue(id .. ": duplicate choice " .. choice.Id)
			else
				seen[choice.Id] = true
				scenario.ChoiceById[choice.Id] = choice
			end
			if not choice.Requires then
				unlocked += 1
			end
			validateRequires(id .. "." .. tostring(choice.Id), choice.Requires)
			local scenarioMin = scenario.Requires and scenario.Requires.MinMoney or 0
			local choiceMin = choice.Requires and choice.Requires.MinMoney or 0
			validateEffects(id .. "." .. tostring(choice.Id), choice.Effects, { MinMoney = math.max(scenarioMin, choiceMin) })
		end
		if unlocked < 1 then
			issue(id .. ": needs at least 1 always-available choice")
		end
		Scenarios.ById[id] = scenario
		table.insert(Scenarios.All, scenario)
	end
end

-- Load every stage module in this folder.
local children = script:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)
for _, module in ipairs(children) do
	if module:IsA("ModuleScript") then
		Scenarios.Register(require(module))
	end
end

-- ===== Random events =====
Scenarios.Events = {}
Scenarios.EventById = {}
local RARITIES = { Common = true, Uncommon = true, Rare = true, Legendary = true }
function Scenarios.RegisterEvents(list)
	for _, event in ipairs(list) do
		local id = event.Id
		if type(id) ~= "string" or Scenarios.EventById[id] or Scenarios.ById[id] then
			issue("invalid or duplicate event Id " .. tostring(id))
			continue
		end
		if not RARITIES[event.Rarity] then
			issue(id .. ": unknown rarity " .. tostring(event.Rarity))
		end
		if type(event.Stages) ~= "table" or #event.Stages == 0 then
			issue(id .. ": needs Stages")
		end
		validateRequires(id, event.Requires)
		validateEffects(id, event.Effects, { MinMoney = math.huge }) -- events may cost money
		Scenarios.EventById[id] = event
		table.insert(Scenarios.Events, event)
	end
end
Scenarios.RegisterEvents(require(script.Parent:WaitForChild("Events")))

function Scenarios.CountForStage(stage: number): number
	local n = 0
	for _, scenario in ipairs(Scenarios.All) do
		if scenario.Stage == stage or (scenario.Stages and table.find(scenario.Stages, stage)) then
			n += 1
		end
	end
	return n
end

return Scenarios
