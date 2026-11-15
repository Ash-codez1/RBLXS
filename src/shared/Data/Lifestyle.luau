--[[
	Lifestyle  (ReplicatedStorage.Shared.Data.Lifestyle)
	The player's lifestyle focus: what they prioritise as the years pass.
	Chosen any time from the HUD (🎯). Applied by the server every simulated
	year (Lib/Yearly); shared so the client can describe each option.

	PerYear: stat changes per year. BondDecay: change to yearly bond decay
	(negative = bonds grow). SavingsBonus adds to the savings rate.
	PromotionMultiplier scales the automatic promotion chance.
	Under 19, "Career" focus means schoolwork and boosts Intelligence instead.
]]

local Lifestyle = {}

Lifestyle.Order = { "Balanced", "Career", "Family", "Health", "Social", "Money" }

Lifestyle.Info = {
	Balanced = {
		Icon = "⚖️", Title = "Balanced", Description = "A bit of everything. Steady and content.",
		PerYear = { Happiness = 0.3, Health = 0.2 },
	},
	Career = {
		Icon = "💼", Title = "Career / School", Description = "Work hard and climb faster. Relationships and health suffer a little.",
		PerYear = { Career = 1.5, Health = -0.4 }, YouthPerYear = { Intelligence = 1.2, Happiness = -0.2 },
		BondDecay = { All = 1 }, PromotionMultiplier = 1.6,
	},
	Family = {
		Icon = "🏡", Title = "Family", Description = "Put loved ones first. Family bonds grow stronger; career slows.",
		PerYear = { Happiness = 0.4, Career = -0.5 },
		BondDecay = { Partner = -3, Child = -3, Parent = -3, Sibling = -3 }, PromotionMultiplier = 0.7,
	},
	Health = {
		Icon = "💪", Title = "Health", Description = "Exercise, sleep, eat well. Health improves every year.",
		PerYear = { Health = 1.5, Happiness = 0.2 },
	},
	Social = {
		Icon = "🎉", Title = "Social Life", Description = "Friends, parties, networking. Friendships and popularity grow.",
		PerYear = { Popularity = 1, Happiness = 0.3, Intelligence = -0.2 },
		BondDecay = { Friend = -4, BestFriend = -4 },
	},
	Money = {
		Icon = "💰", Title = "Save Money", Description = "Live frugally and save much more. Life is a bit less fun.",
		PerYear = { Happiness = -0.4 }, SavingsBonus = 0.08, MinAge = 16,
	},
}

function Lifestyle.IsValid(id: any): boolean
	return type(id) == "string" and Lifestyle.Info[id] ~= nil
end

function Lifestyle.Available(id: string, age: number): boolean
	local info = Lifestyle.Info[id]
	return info ~= nil and age >= (info.MinAge or 0)
end

return Lifestyle
