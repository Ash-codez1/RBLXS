--[[
	RandomEvents  (ServerScriptService.Server.Lib.RandomEvents)
	Rolls for an unexpected life event after each decision.

	  1. A base chance (Config.EventChance) decides whether anything happens.
	  2. Eligible events = right stage, Requires pass, not already had (Once).
	     So events respect the player's circumstances (you can't lose a job you
	     don't have, inherit a fortune twice, etc.).
	  3. Weighted pick by rarity × Boost (e.g. inheritances favour people with
	     strong Relationships).
	Legendary events are extremely rare: roughly one life in a few hundred.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Conditions = require(script.Parent.Conditions)
local ScenarioPicker = require(script.Parent.ScenarioPicker)

local RandomEvents = {}

RandomEvents.RarityWeight = {
	Common = 10,
	Uncommon = 4,
	Rare = 1.2,
	Legendary = 0.12,
}

local function hadEvent(life, id: string): boolean
	return table.find(life.Events, id) ~= nil
end

function RandomEvents.Eligible(life, pool)
	local list = {}
	for _, event in ipairs(pool) do
		if table.find(event.Stages, life.Stage) and not (event.Once ~= false and hadEvent(life, event.Id)) and Conditions.Check(life, event.Requires) then
			table.insert(list, event)
		end
	end
	return list
end

function RandomEvents.Roll(life, pool, rng)
	if rng:NextNumber() >= Config.EventChance then
		return nil
	end
	local eligible = RandomEvents.Eligible(life, pool)
	if #eligible == 0 then
		return nil
	end
	local weights, total = {}, 0
	for i, event in ipairs(eligible) do
		weights[i] = ScenarioPicker.Weight(event, life, RandomEvents.RarityWeight[event.Rarity] or 1)
		total += weights[i]
	end
	local roll = rng:NextNumber() * total
	for i, event in ipairs(eligible) do
		roll -= weights[i]
		if roll <= 0 then
			return event
		end
	end
	return eligible[#eligible]
end

return RandomEvents
