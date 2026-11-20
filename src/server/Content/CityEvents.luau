--[[
	City events  (ServerScriptService.Server.Content.CityEvents)
	Server-wide shared events (Services/CityEventService). Every few minutes
	the whole server gets the same invitation; each player chooses to join or
	skip, and effects apply to their own life only. Requires is per player.
	Outcomes (if any) are rolled once for the city, so everyone who joins
	shares the same result.
]]

return {
	{ Id = "CE_Festival", Icon = "🎪", Title = "City Festival", Description = "Music, food stalls and fireworks fill the city centre tonight!",
		JoinText = "Go to the festival", SkipText = "Stay in",
		Effects = { Stats = { Happiness = 5, Relationships = 3 }, Story = "{name} danced at the city festival under the fireworks." } },
	{ Id = "CE_Marathon", Icon = "🏃", Title = "The City Marathon", Description = "Thousands are lining up for the annual city marathon.",
		Requires = { MinAge = 12 }, JoinText = "Run it", SkipText = "Watch from the sidelines",
		Effects = { Stats = { Health = 6, Reputation = 2, Happiness = 2 }, Story = "{name} ran the city marathon and crossed the finish line." } },
	{ Id = "CE_Heatwave", Icon = "☀️", Title = "Heatwave!", Description = "It's the hottest day of the year. The whole city heads to the parks and pools.",
		JoinText = "Head to the lido", SkipText = "Stay cool indoors",
		Effects = { Stats = { Happiness = 4, Health = 2 }, Story = "{name} spent the heatwave splashing in the city lido." } },
	{ Id = "CE_Market", Icon = "📈", Title = "Market Frenzy", Description = "Everyone in the city is talking about a stock that's shooting up.",
		Requires = { MinAge = 18, MinMoney = 2000 }, JoinText = "Buy in ($1,000)", SkipText = "Ignore the hype",
		Effects = { Money = -1000, Story = "{name} joined the market frenzy.",
			Outcomes = { { Chance = 0.5, Money = 2600, Story = "The stock soared. Profit!" }, { Chance = 0.5, Story = "The bubble burst the next day." } } } },
	{ Id = "CE_Cleanup", Icon = "🧹", Title = "Great City Clean-Up", Description = "Volunteers are cleaning up parks and beaches across the city.",
		JoinText = "Volunteer", SkipText = "Not today",
		Effects = { Stats = { Reputation = 5, Health = 1 }, Traits = { Kind = 1 }, Story = "{name} helped clean up the city's parks." } },
	{ Id = "CE_Quiz", Icon = "❓", Title = "City Quiz Night", Description = "The biggest pub quiz in the city, live on local TV!",
		Requires = { MinAge = 10 }, JoinText = "Enter the quiz", SkipText = "Skip it",
		Effects = { Stats = { Intelligence = 2 }, Story = "{name} entered the city quiz night.",
			Outcomes = { { Chance = 0.3, Stats = { Popularity = 6, Intelligence = 3 }, Story = "And won it on live TV!" } } } },
	{ Id = "CE_Concert", Icon = "🎤", Title = "Free Concert in the Park", Description = "A superstar is playing a surprise free concert in the city park!",
		JoinText = "Go!", SkipText = "Crowds aren't my thing",
		Effects = { Stats = { Happiness = 7, Popularity = 2 }, Story = "{name} sang along at a surprise free concert in the park." } },
}
