--[[
	Legacy  (ReplicatedStorage.Shared.Data.Legacy)
	Rebirth: every life you complete raises your Legacy level and unlocks
	perks. When you start a new life you can be "reborn" with one unlocked
	perk, a small head start inherited from your past lives. Perks are
	earned by playing only (never sold) and stay modest so every life is
	still decided by its choices.
]]

local Legacy = {}

Legacy.Perks = {
	{ Id = "HeadStart", Name = "Head Start", Icon = "📚", Lives = 1, Description = "Start with +5 Intelligence.", Stats = { Intelligence = 5 } },
	{ Id = "StrongGenes", Name = "Strong Genes", Icon = "💪", Lives = 1, Description = "Start with +5 Health.", Stats = { Health = 5 } },
	{ Id = "SunnyStart", Name = "Sunny Disposition", Icon = "😊", Lives = 2, Description = "Start with +5 Happiness.", Stats = { Happiness = 5 } },
	{ Id = "PopularKid", Name = "Popular Kid", Icon = "⭐", Lives = 2, Description = "Start with +5 Popularity.", Stats = { Popularity = 5 } },
	{ Id = "FamilyFortune", Name = "Family Fortune", Icon = "💰", Lives = 3, Description = "Start with $500 in savings.", Money = 500 },
	{ Id = "GoodName", Name = "A Good Name", Icon = "🏅", Lives = 4, Description = "Start with +5 Reputation.", Stats = { Reputation = 5 } },
	{ Id = "OldSoul", Name = "Old Soul", Icon = "🦉", Lives = 6, Description = "Start with +3 to every stat.", Stats = { Happiness = 3, Intelligence = 3, Health = 3, Popularity = 3, Relationships = 3, Reputation = 3, Career = 3 } },
}

Legacy.ById = {}
for _, perk in ipairs(Legacy.Perks) do
	Legacy.ById[perk.Id] = perk
end

function Legacy.Level(livesCompleted: number): number
	return math.max(0, math.floor(livesCompleted or 0))
end

function Legacy.IsUnlocked(perkId: any, livesCompleted: number): boolean
	local perk = type(perkId) == "string" and Legacy.ById[perkId]
	return perk ~= nil and perk ~= false and (livesCompleted or 0) >= perk.Lives
end

function Legacy.Unlocked(livesCompleted: number)
	local list = {}
	for _, perk in ipairs(Legacy.Perks) do
		if (livesCompleted or 0) >= perk.Lives then
			table.insert(list, perk)
		end
	end
	return list
end

return Legacy
