--[[
	StatDefinitions  (ReplicatedStorage.Shared.Data.StatDefinitions)
	The eight life statistics. Order here is the display order in the UI.
	Every stat is a number clamped to [Config.StatMin, Config.StatMax].
]]

local StatDefinitions = {}

StatDefinitions.Order = {
	"Happiness",
	"Wealth",
	"Intelligence",
	"Health",
	"Popularity",
	"Relationships",
	"Reputation",
	"Career",
}

StatDefinitions.Info = {
	Happiness = { DisplayName = "Happiness", Icon = "😊", Color = Color3.fromRGB(255, 200, 60), Description = "How content you feel with your life." },
	Wealth = { DisplayName = "Wealth", Icon = "💰", Color = Color3.fromRGB(80, 200, 120), Description = "Your financial security and assets." },
	Intelligence = { DisplayName = "Intelligence", Icon = "🧠", Color = Color3.fromRGB(90, 150, 255), Description = "Knowledge, skills and education." },
	Health = { DisplayName = "Health", Icon = "❤️", Color = Color3.fromRGB(240, 80, 90), Description = "Physical and mental wellbeing." },
	Popularity = { DisplayName = "Popularity", Icon = "⭐", Color = Color3.fromRGB(255, 120, 200), Description = "How well-known and liked you are." },
	Relationships = { DisplayName = "Relationships", Icon = "🤝", Color = Color3.fromRGB(255, 150, 90), Description = "The strength of your bonds with others." },
	Reputation = { DisplayName = "Reputation", Icon = "🏅", Color = Color3.fromRGB(170, 120, 255), Description = "How trustworthy and respected you are." },
	Career = { DisplayName = "Career Success", Icon = "💼", Color = Color3.fromRGB(70, 200, 220), Description = "How far you've progressed professionally." },
}

local valid = {}
for _, name in ipairs(StatDefinitions.Order) do
	valid[name] = true
end

function StatDefinitions.IsValid(name: any): boolean
	return type(name) == "string" and valid[name] == true
end

return StatDefinitions
