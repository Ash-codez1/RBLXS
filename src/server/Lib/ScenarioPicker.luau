--[[
	ScenarioPicker  (ServerScriptService.Server.Lib.ScenarioPicker)
	Chooses the next scenario for a life from a stage's pool.

	Rules, in order:
	  1. Only scenarios for the life's current stage whose Requires pass.
	  2. Scenarios marked Once are skipped if already seen this life.
	  3. If any eligible scenario has a Priority, the highest Priority wins
	     (used for "first day of school"-style openers).
	  4. Otherwise a weighted random pick. Weight = scenario.Weight (default 1)
	     × Boost multipliers for matching flags/traits, so earlier decisions make
	     related situations more likely. Recently seen repeatables are down-weighted.
]]

local Conditions = require(script.Parent.Conditions)

local ScenarioPicker = {}

local function weightFor(scenario, life): number
	local weight = scenario.Weight or 1
	local boost = scenario.Boost
	if boost then
		if boost.Flags then
			for flag, multiplier in pairs(boost.Flags) do
				if life.Flags[flag] then
					weight *= multiplier
				end
			end
		end
		if boost.Traits then
			for trait, multiplier in pairs(boost.Traits) do
				local strength = life.Traits[trait]
				if strength then
					weight *= 1 + (multiplier - 1) * math.min(strength, 3) / 3
				end
			end
		end
	end
	if life.Seen[scenario.Id] then
		weight *= 0.25 -- repeatable but already seen: less likely
	end
	return weight
end

function ScenarioPicker.Eligible(life, pool)
	local eligible = {}
	for _, scenario in ipairs(pool) do
		if scenario.Stage == life.Stage and not (scenario.Once and life.Seen[scenario.Id]) and Conditions.Check(life, scenario.Requires) then
			table.insert(eligible, scenario)
		end
	end
	return eligible
end

function ScenarioPicker.Pick(life, pool, rng)
	local eligible = ScenarioPicker.Eligible(life, pool)
	if #eligible == 0 then
		return nil
	end

	local best, bestPriority = nil, -math.huge
	for _, scenario in ipairs(eligible) do
		if scenario.Priority and scenario.Priority > bestPriority then
			best, bestPriority = scenario, scenario.Priority
		end
	end
	if best then
		return best
	end

	local total = 0
	local weights = {}
	for i, scenario in ipairs(eligible) do
		weights[i] = weightFor(scenario, life)
		total += weights[i]
	end
	local roll = rng:NextNumber() * total
	for i, scenario in ipairs(eligible) do
		roll -= weights[i]
		if roll <= 0 then
			return scenario
		end
	end
	return eligible[#eligible]
end

return ScenarioPicker
