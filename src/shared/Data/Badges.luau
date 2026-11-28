--[[
	Badges  (ReplicatedStorage.Shared.Data.Badges)
	Optional Roblox badges. The game works without them: an id of 0 is skipped.

	To add one: Creator Dashboard → your experience → Associated Items →
	Badges → Create a Badge. Copy its id and paste it here. Roblox limits
	how many free badges you can create per day, so start with a few.
	ProgressService awards a badge when the matching achievement unlocks,
	and also gives it to players who unlocked the achievement before you
	added the badge.
]]

return {
	Welcome = 0, -- the first time someone plays

	-- Achievement id -> badge id
	ForAchievement = {
		FirstLife = 0,
		ThreeLives = 0,
		TenLives = 0,
		Millionaire = 0,
		CareerTop = 0,
		FiveEndings = 0,
		Legendary = 0,
		Local = 0,
		AllStars = 0,
		Dedicated = 0,
		S_Jackpot = 0,
		S_Astronaut = 0,
	},
}
