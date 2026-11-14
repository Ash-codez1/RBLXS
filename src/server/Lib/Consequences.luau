--[[
	Consequences  (ServerScriptService.Server.Lib.Consequences)
	Applies a choice's Effects to a life table IN PLACE and returns a summary
	for the client. Called by LifeService inside DataService.Update so the
	whole decision is applied atomically.

	Effects = {
		Stats      = { Intelligence = 6, Happiness = -2 },  -- base deltas (Wealth is derived; don't set it)
		Money      = 50,                                   -- in-life money change
		Flags      = { "StudiedEarly" },                   -- story flags to set
		ClearFlags = { "Shy" },                            -- story flags to remove
		Traits     = { Studious = 1 },                     -- trait strength changes
		Story      = "Text for the life story. {name} is replaced.",
		Outcomes   = {                                     -- optional chance-based extras;
			{ Chance = 0.3, Stats = {...}, Money = 0, Flags = {...}, Traits = {...}, Story = "..." },
		},                                                 -- at most ONE outcome triggers (rolled in order)
	}

	Short-term vs long-term: Stats are the immediate effect; Flags and Traits
	are the long-term effect (they gate future scenarios/choices and change
	how much future gains are worth via Traits.GainMultipliers).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatMath = require(Shared.Util.StatMath)
local TableUtil = require(Shared.Util.TableUtil)
local Traits = require(Shared.Data.Traits)
local Config = require(Shared.Config)

local Consequences = {}

local function personalise(text: string?, life): string?
	if not text then
		return nil
	end
	return (text:gsub("{name}", life.Name))
end

-- Applies one Effects-shaped table (base effects or a single outcome).
local function applyBlock(life, block, summary)
	if block.Stats then
		-- Traits amplify gains only; losses are applied as-is.
		local multipliers = Traits.GainMultipliers(life.Traits)
		local deltas = {}
		for stat, delta in pairs(block.Stats) do
			if stat ~= "Wealth" then
				deltas[stat] = if delta > 0 then delta * (multipliers[stat] or 1) else delta
			end
		end
		local newStats, applied = StatMath.Apply(life.Stats, deltas)
		life.Stats = newStats
		for stat, change in pairs(applied) do
			summary.Applied[stat] = (summary.Applied[stat] or 0) + change
		end
	end
	if type(block.Money) == "number" and block.Money ~= 0 then
		local before = life.Money
		life.Money = math.max(0, math.floor(life.Money + block.Money))
		summary.MoneyDelta += life.Money - before
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
	local story = personalise(block.Story, life)
	if story then
		table.insert(summary.StoryParts, story)
	end
end

--[[
	rng: a Random object (server-seeded). netWorthExtra: asset value to include
	when recomputing Wealth (0 until houses/cars exist).
	Returns summary = { Applied, MoneyDelta, FlagsAdded, TraitsGained, Story, OutcomeTriggered }
]]
function Consequences.Apply(life, effects, rng, netWorthExtra: number?)
	local summary = {
		Applied = {},
		MoneyDelta = 0,
		FlagsAdded = {},
		TraitsGained = {},
		StoryParts = {},
		OutcomeTriggered = false,
	}
	local wealthBefore = life.Stats.Wealth

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

	-- Wealth always follows net worth.
	life.Stats.Wealth = StatMath.WealthFromNetWorth(life.Money + (netWorthExtra or 0))
	local wealthChange = life.Stats.Wealth - wealthBefore
	if math.abs(wealthChange) >= 0.05 then
		summary.Applied.Wealth = wealthChange
	end

	summary.Story = table.concat(summary.StoryParts, " ")
	summary.StoryParts = nil

	if summary.Story ~= "" then
		table.insert(life.Story, { Age = life.Age, Text = summary.Story })
		TableUtil.TrimArray(life.Story, Config.MaxStoryEntries)
	end
	return summary
end

--[[
	Consequence preview for the decision cards: direction + size of each base
	stat effect, never exact numbers, and never what chance Outcomes do.
	Returns { { Stat, Dir = 1|-1, Size = 1..3 } ... }, moneyDir, risky
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
		return a.Size > b.Size
	end)
	local moneyDir = if type(effects.Money) == "number" and effects.Money ~= 0 then (if effects.Money > 0 then 1 else -1) else 0
	return preview, moneyDir, effects.Outcomes ~= nil
end

return Consequences
