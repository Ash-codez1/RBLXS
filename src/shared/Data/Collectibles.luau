--[[
	Collectibles  (ReplicatedStorage.Shared.Data.Collectibles)
	Memory Stars: 20 glowing stars hidden around Lifeville. The district
	builders place each one (Builder.Star); CollectibleService checks you're
	really next to one before it counts. Each star is found once per
	account and pays Coins; finding them all is an achievement, and one is
	a secret. Stars in districts that open later are behind their walls
	until then.
]]

local Collectibles = {}

Collectibles.Coins = 15

Collectibles.List = {
	{ Id = "Star_HallOfLives", District = "Plaza", Hint = "Behind the Hall of Lives." },
	{ Id = "Star_Arch", District = "Plaza", Hint = "At the foot of the welcome arch." },
	{ Id = "Star_Goal", District = "School", Hint = "Behind a goal on the sports field." },
	{ Id = "Star_Library", District = "School", Hint = "Among the school library's shelves." },
	{ Id = "Star_Statue", District = "University", Hint = "Behind the founder's statue." },
	{ Id = "Star_Union", District = "University", Hint = "In the student union." },
	{ Id = "Star_BusStop", District = "Downtown", Hint = "Waiting at the bus stop." },
	{ Id = "Star_Arcade", District = "Downtown", Hint = "Next to an arcade machine." },
	{ Id = "Star_ClockTower", District = "CareerRow", Hint = "Behind the town hall's clock tower." },
	{ Id = "Star_Booth", District = "CareerRow", Hint = "In the recording booth." },
	{ Id = "Star_Helipad", District = "Hospital", Hint = "On the helipad." },
	{ Id = "Star_Ward", District = "Hospital", Hint = "Beside a hospital bed." },
	{ Id = "Star_Pond", District = "Park", Hint = "On the far side of the duck pond." },
	{ Id = "Star_Stands", District = "Park", Hint = "At the top of the arena stands." },
	{ Id = "Star_Picnic", District = "Park", Hint = "Under a picnic table." },
	{ Id = "Star_Stairs", District = "Residential", Hint = "At the top of the apartment stairs." },
	{ Id = "Star_Hedge", District = "Residential", Hint = "Behind the hedges at the end of Oak Street." },
	{ Id = "Star_Lighthouse", District = "Harbour", Hint = "Swim out to the lighthouse.", Secret = "S_Lighthouse" },
	{ Id = "Star_Pier", District = "Harbour", Hint = "At the very end of the pier." },
	{ Id = "Star_Pool", District = "Harbour", Hint = "By the pool on Hilltop." },
}

Collectibles.ById = {}
for _, star in ipairs(Collectibles.List) do
	Collectibles.ById[star.Id] = star
end
Collectibles.Total = #Collectibles.List

return Collectibles
