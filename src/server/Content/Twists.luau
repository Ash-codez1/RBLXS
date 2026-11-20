--[[
	Life Reveal twists  (ServerScriptService.Server.Content.Twists)
	"Even if a future looks predictable, anything can happen."
	At the end of a stage, Lib/Reveal may roll a twist (Config.TwistChance):
	  • Setback: if one future looks very likely (60%+), a twist that works
	    against it (Counters lists which futures it can upset)
	  • Rescue: if a risk (Hard times / Lonely) looks likely, a twist that helps
	  • Surprise: otherwise, an unexpected turn
	Twists apply real effects (Consequences format) and the reveal shows the
	odds before and after. Each twist happens at most once per life.
]]

local KID, TEEN, YOUNG, ADULT, MID = 1, 2, 3, 4, 5

return {
	-- ===== Setbacks =====
	{ Id = "TW_Crash", Kind = "Setback", Icon = "📉", Title = "The Crash", Stages = { YOUNG, ADULT, MID }, Counters = { "Millionaire" }, Requires = { MinMoney = 20000 },
		Effects = { MoneyPercent = -0.5, InvestPercent = -0.5, Stats = { Happiness = -8 }, Story = "Out of nowhere, a global financial crash wiped out half of everything {name} had saved." } },
	{ Id = "TW_Scandal", Kind = "Setback", Icon = "📰", Title = "Scandal at Work", Stages = { YOUNG, ADULT, MID }, Counters = { "Career", "Respected" }, Requires = { HasCareer = true },
		Effects = { Promote = -1, Stats = { Career = -12, Reputation = -10 }, Story = "A colleague's lie dragged {name} into a workplace scandal. It took years to clear their name." } },
	{ Id = "TW_Illness", Kind = "Setback", Icon = "🏥", Title = "A Serious Illness", Stages = { TEEN, YOUNG, ADULT, MID }, Counters = { "Healthy", "Content", "Genius" },
		Effects = { Stats = { Health = -18, Happiness = -6 }, Story = "{name} fell seriously ill. Recovery was long and slow." } },
	{ Id = "TW_Heartbreak", Kind = "Setback", Icon = "💔", Title = "Heartbreak", Stages = { YOUNG, ADULT, MID }, Counters = { "Family", "Content" }, Requires = { Partner = true },
		Effects = { Partner = false, Stats = { Happiness = -10 }, Story = "Without warning, {name}'s partner left. Everything they'd planned together was gone." } },
	{ Id = "TW_FameFades", Kind = "Setback", Icon = "🕯️", Title = "Yesterday's News", Stages = { TEEN, YOUNG, ADULT, MID }, Counters = { "Fame" }, Requires = { MinStats = { Popularity = 55 } },
		Effects = { Stats = { Popularity = -18, Happiness = -5 }, Story = "The spotlight moved on. Almost overnight, nobody was talking about {name} any more." } },
	{ Id = "TW_FallOut", Kind = "Setback", Icon = "🌪️", Title = "A Bitter Falling-Out", Stages = { TEEN, YOUNG, ADULT, MID }, Counters = { "Respected", "Family", "Adventurer" },
		Effects = { Bond = { All = -15 }, Stats = { Reputation = -6, Relationships = -8 }, Story = "A misunderstanding spiralled into a falling-out that split {name}'s circle in two." } },

	-- ===== Rescues =====
	{ Id = "TW_Inheritance", Kind = "Rescue", Icon = "📜", Title = "A Secret Inheritance", Stages = { YOUNG, ADULT, MID }, Counters = { "Struggling" },
		Effects = { Money = 150000, Stats = { Happiness = 8 }, Story = "A letter from a lawyer: a relative {name} had never met had left them $150,000." } },
	{ Id = "TW_Partnership", Kind = "Rescue", Icon = "🤝", Title = "The Offer of a Lifetime", Stages = { YOUNG, ADULT, MID }, Counters = { "Struggling" }, Requires = { HasCareer = false },
		Effects = { Career = "BusinessOwner", Promote = 1, Money = 20000, Stats = { Happiness = 8, Career = 8 }, Story = "An old friend offered {name} a partnership in their thriving business. Life turned around overnight." } },
	{ Id = "TW_NewCircle", Kind = "Rescue", Icon = "🎊", Title = "A New Circle", Stages = { TEEN, YOUNG, ADULT, MID }, Counters = { "Lonely", "Struggling" },
		Effects = { Friends = 3, Meet = "BestFriend", Stats = { Happiness = 10, Relationships = 10 }, Story = "A chance invitation led {name} into a warm, welcoming group of new friends." } },
	{ Id = "TW_SecondChance", Kind = "Rescue", Icon = "💌", Title = "A Second Chance at Love", Stages = { YOUNG, ADULT, MID }, Counters = { "Lonely" }, Requires = { Partner = false },
		Effects = { Partner = true, Stats = { Happiness = 10, Relationships = 8 }, Story = "Just when {name} had stopped looking, love found them." } },

	-- ===== Surprises =====
	{ Id = "TW_Prodigy", Kind = "Surprise", Icon = "🎹", Title = "An Extraordinary Talent", Stages = { KID, TEEN }, Counters = {},
		Effects = { Flags = { "MusicTalent", "Prodigy" }, Stats = { Intelligence = 6, Popularity = 6, Happiness = 6 }, Story = "An ordinary afternoon, a borrowed piano, and {name} played like they'd practised for years. A prodigy." } },
	{ Id = "TW_BigIdea", Kind = "Surprise", Icon = "💡", Title = "The Big Idea", Stages = { TEEN, YOUNG, ADULT, MID }, Counters = {},
		Effects = { Flags = { "BigIdea" }, Stats = { Intelligence = 6, Career = 8 }, Traits = { Ambitious = 1 }, Story = "At 3am, {name} sat up in bed with an idea that would change the direction of their life." } },
	{ Id = "TW_HiddenTalent", Kind = "Surprise", Icon = "💎", Title = "A Hidden Gift", Stages = { YOUNG, ADULT, MID }, Counters = {},
		Effects = { Flags = { "LateBloomer" }, Stats = { Popularity = 10, Happiness = 8 }, Story = "{name} discovered a gift they never knew they had, and people couldn't stop talking about it." } },
	{ Id = "TW_Windfall", Kind = "Surprise", Icon = "🍀", Title = "A Lucky Break", Stages = { TEEN, YOUNG, ADULT, MID }, Counters = {},
		Effects = { Money = 40000, Stats = { Happiness = 6 }, Story = "A forgotten investment of {name}'s grandparent's turned out to be worth $40,000." } },
	{ Id = "TW_Sibling", Kind = "Surprise", Icon = "🧬", Title = "A Long-Lost Sibling", Stages = { YOUNG, ADULT, MID }, Counters = {},
		Effects = { Meet = "Sibling", Stats = { Relationships = 6, Happiness = 6 }, Story = "A DNA test revealed {name} had a sibling they'd never known. They met, and it felt like they always had." } },
	{ Id = "TW_Mentor", Kind = "Surprise", Icon = "🦉", Title = "An Unexpected Mentor", Stages = { KID, TEEN, YOUNG }, Counters = {},
		Effects = { Stats = { Intelligence = 6, Reputation = 4, Career = 4 }, Traits = { Studious = 1 }, Story = "A brilliant retired professor took an interest in {name} and changed how they saw the world." } },
}
