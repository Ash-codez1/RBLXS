--[[
	Traits  (ReplicatedStorage.Shared.Data.Traits)
	Personality traits are built up by choices (life.Traits[id] = strength 1..MaxStrength).
	Each point of strength boosts (or reduces) future GAINS in the listed stats,
	so who you became early in life shapes how later choices pay off.
	Shared so the client can display them; the server alone applies them.
]]

local Traits = {}

Traits.MaxStrength = 5

Traits.Info = {
	Social = { DisplayName = "Social", Icon = "🗣️", Description = "Makes friends easily.", Bonus = { Popularity = 0.05, Relationships = 0.05 } },
	Studious = { DisplayName = "Studious", Icon = "📚", Description = "Loves to learn.", Bonus = { Intelligence = 0.06 } },
	Shy = { DisplayName = "Shy", Icon = "🙈", Description = "Thoughtful, but quiet in crowds.", Bonus = { Popularity = -0.05, Intelligence = 0.03 } },
	Playful = { DisplayName = "Playful", Icon = "🎮", Description = "Finds fun in everything.", Bonus = { Happiness = 0.05 } },
	Creative = { DisplayName = "Creative", Icon = "🎨", Description = "Full of ideas.", Bonus = { Happiness = 0.03, Intelligence = 0.03 } },
	Athletic = { DisplayName = "Athletic", Icon = "🏃", Description = "Strong and energetic.", Bonus = { Health = 0.06 } },
	Kind = { DisplayName = "Kind", Icon = "💛", Description = "Looks out for others.", Bonus = { Reputation = 0.05, Relationships = 0.04 } },
	Rebellious = { DisplayName = "Rebellious", Icon = "😈", Description = "Rules are made to be broken.", Bonus = { Popularity = 0.04, Reputation = -0.05 } },
	Thrifty = { DisplayName = "Thrifty", Icon = "🐷", Description = "Careful with money.", Bonus = { Wealth = 0.06 } },
	Ambitious = { DisplayName = "Ambitious", Icon = "🚀", Description = "Always aiming higher.", Bonus = { Career = 0.06, Wealth = 0.03 } },
	Adventurous = { DisplayName = "Adventurous", Icon = "🧭", Description = "Seeks new experiences.", Bonus = { Happiness = 0.04 } },
	Charismatic = { DisplayName = "Charismatic", Icon = "✨", Description = "Lights up a room.", Bonus = { Popularity = 0.06 } },
	Brave = { DisplayName = "Brave", Icon = "🦁", Description = "Faces fears head-on.", Bonus = { Reputation = 0.04, Health = 0.02 } },
}

function Traits.IsValid(id: any): boolean
	return type(id) == "string" and Traits.Info[id] ~= nil
end

--[[
	Gain multipliers for a life's traits: { Stat = multiplier }.
	multiplier = 1 + Σ(bonus × strength), clamped to [0.6, 1.5].
]]
function Traits.GainMultipliers(lifeTraits: { [string]: number }): { [string]: number }
	local totals = {}
	for id, strength in pairs(lifeTraits) do
		local info = Traits.Info[id]
		if info then
			for stat, bonus in pairs(info.Bonus) do
				totals[stat] = (totals[stat] or 0) + bonus * math.min(strength, Traits.MaxStrength)
			end
		end
	end
	local result = {}
	for stat, total in pairs(totals) do
		result[stat] = math.clamp(1 + total, 0.6, 1.5)
	end
	return result
end

return Traits
