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

local Scenarios = {}
Scenarios.All = {}
Scenarios.ById = {}
Scenarios.Issues = {}

local function issue(text)
	table.insert(Scenarios.Issues, text)
	warn("[Scenarios] " .. text)
end

local function validateEffects(where, effects)
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
		if type(scenario.Stage) ~= "number" or scenario.Stage < 1 or scenario.Stage > 6 then
			issue(id .. ": invalid Stage")
		end
		local choices = scenario.Choices or {}
		if #choices < 3 or #choices > 5 then
			issue(id .. ": should have 3–5 choices (has " .. #choices .. ")")
		end
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
			validateEffects(id .. "." .. tostring(choice.Id), choice.Effects)
		end
		if unlocked < 2 then
			issue(id .. ": needs at least 2 always-available choices")
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

function Scenarios.CountForStage(stage: number): number
	local n = 0
	for _, scenario in ipairs(Scenarios.All) do
		if scenario.Stage == stage then
			n += 1
		end
	end
	return n
end

return Scenarios
