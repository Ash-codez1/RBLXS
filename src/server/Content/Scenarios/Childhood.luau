--[[
	Childhood scenarios (Stage 1, ages 5–12)
	ServerScriptService.Server.Content.Scenarios.Childhood

	Kept on the server so players can't read hidden outcomes or chances.
	Format is documented in Scenarios/init.luau and Lib/Consequences.luau.
	Flags set here are read by later stages (Phase 3), e.g. Athlete, Bookworm,
	MusicTalent, YoungEntrepreneur, Rebellious.
]]

return {
	{
		Id = "C_FirstDay",
		Stage = 1,
		Icon = "🏫",
		Title = "First Day of School",
		Description = "The classroom is loud, bright and full of strangers. Your parent squeezes your hand one last time. What do you do?",
		Priority = 10,
		Once = true,
		Choices = {
			{
				Id = "Wave",
				Text = "Say hi to everyone",
				Description = "March in and introduce yourself.",
				Effects = {
					Stats = { Popularity = 6, Relationships = 6, Happiness = 3 },
					Traits = { Social = 1 },
					Flags = { "Outgoing" },
					Friends = 2,
					Story = "{name} walked into class and introduced themselves to everyone. By lunchtime they had three new friends.",
				},
			},
			{
				Id = "Listen",
				Text = "Sit at the front and listen",
				Description = "The teacher seems interesting.",
				Effects = {
					Stats = { Intelligence = 6, Reputation = 3, Popularity = -2 },
					Traits = { Studious = 1 },
					Flags = { "Attentive" },
					Story = "{name} sat right at the front and soaked up every word. The teacher noticed.",
				},
			},
			{
				Id = "Hide",
				Text = "Hide behind your parent",
				Description = "Maybe if you stay very still, nobody will notice.",
				Effects = {
					Stats = { Happiness = -3, Relationships = 3, Popularity = -3 },
					Bond = { Parent = 4 },
					Traits = { Shy = 1 },
					Flags = { "Shy" },
					Story = "{name} clung on and had to be gently coaxed inside. It took a while to feel brave.",
				},
			},
			{
				Id = "Toy",
				Text = "Show off your favourite toy",
				Description = "Everyone will love it. Probably.",
				Effects = {
					Stats = { Popularity = 5, Happiness = 4, Reputation = -1 },
					Story = "{name} showed off their favourite toy and drew a crowd.",
					Outcomes = {
						{ Chance = 0.3, Stats = { Happiness = -6 }, Story = "Then someone dropped it and it snapped in half." },
					},
				},
			},
		},
	},

	{
		Id = "C_AfterSchool",
		Stage = 1,
		Icon = "🎒",
		Title = "After School",
		Description = "You're home, your bag is on the floor and the whole afternoon stretches ahead.",
		Weight = 1.2,
		Choices = {
			{
				Id = "Homework",
				Text = "Do your homework first",
				Description = "Get it out of the way.",
				Effects = {
					Stats = { Intelligence = 5, Reputation = 2, Happiness = -2 },
					Traits = { Studious = 1 },
					Story = "{name} finished every bit of homework before doing anything fun.",
				},
			},
			{
				Id = "Games",
				Text = "Play video games",
				Description = "Just one more level...",
				Effects = {
					Stats = { Happiness = 6, Intelligence = -2, Health = -1 },
					Traits = { Playful = 1 },
					Flags = { "Gamer" },
					Story = "{name} spent the afternoon glued to a screen, beating level after level.",
				},
			},
			{
				Id = "Outside",
				Text = "Play outside with friends",
				Description = "Football, tag, climbing trees.",
				Effects = {
					Stats = { Health = 5, Relationships = 4, Popularity = 2 },
					Traits = { Athletic = 1 },
					Friends = 1,
					Story = "{name} played outside until the streetlights came on.",
				},
			},
			{
				Id = "Create",
				Text = "Draw, build or make something",
				Description = "Your imagination has ideas.",
				Effects = {
					Stats = { Happiness = 3, Intelligence = 3 },
					Traits = { Creative = 1 },
					Flags = { "Creative" },
					Story = "{name} built a cardboard castle with working drawbridge. Mostly working.",
				},
			},
		},
	},

	{
		Id = "C_Tryouts",
		Stage = 1,
		Icon = "⚽",
		Title = "Club Sign-Ups",
		Description = "The school noticeboard is covered in sign-up sheets. You can pick one.",
		Once = true,
		Boost = { Traits = { Athletic = 2 } },
		Choices = {
			{
				Id = "Football",
				Text = "Try out for football",
				Description = "Only the best make the team.",
				Effects = {
					Stats = { Health = 6, Popularity = 3 },
					Traits = { Athletic = 1 },
					Story = "{name} gave the football trials everything.",
					Outcomes = {
						{ Chance = 0.6, Stats = { Popularity = 4, Happiness = 4 }, Flags = { "Athlete", "TeamPlayer" }, Story = "They made the team!" },
						{ Chance = 0.4, Stats = { Happiness = -5 }, Flags = { "Determined" }, Story = "They didn't make the cut this year, and vowed to train harder." },
					},
				},
			},
			{
				Id = "Swim",
				Text = "Join the swimming club",
				Description = "Early mornings, chlorine, medals.",
				Effects = {
					Stats = { Health = 7, Happiness = 2 },
					Traits = { Athletic = 1 },
					Flags = { "Athlete", "Swimmer" },
					Story = "{name} joined the swimming club and was soon racing lengths every morning.",
				},
			},
			{
				Id = "Chess",
				Text = "Join the chess club",
				Description = "Think three moves ahead.",
				Effects = {
					Stats = { Intelligence = 7, Popularity = -1 },
					Traits = { Studious = 1 },
					Flags = { "ChessClub" },
					Story = "{name} joined chess club and won their first tournament game.",
				},
			},
			{
				Id = "Drama",
				Text = "Sign up for drama",
				Description = "The stage is calling.",
				Effects = {
					Stats = { Popularity = 5, Happiness = 3 },
					Traits = { Charismatic = 1 },
					Flags = { "Performer" },
					Story = "{name} joined drama club and discovered they loved an audience.",
				},
			},
			{
				Id = "None",
				Text = "No clubs, thanks",
				Description = "More free time for you.",
				Effects = {
					Stats = { Happiness = 2, Health = -2 },
					Story = "{name} skipped clubs and kept their afternoons free.",
				},
			},
		},
	},

	{
		Id = "C_Bedtime",
		Stage = 1,
		Icon = "🌙",
		Title = "Bedtime Rules",
		Description = "Your parents say lights out at eight. Your friends say they stay up until ten.",
		Once = true,
		Choices = {
			{
				Id = "Obey",
				Text = "Go to bed on time",
				Description = "Rules are rules.",
				Effects = {
					Stats = { Health = 5, Reputation = 3, Relationships = 3 },
					Bond = { Parent = 5 },
					Flags = { "GoodKid" },
					Story = "{name} went to bed on time and woke up full of energy.",
				},
			},
			{
				Id = "Torch",
				Text = "Read under the covers with a torch",
				Description = "Just one more chapter.",
				Effects = {
					Stats = { Intelligence = 5, Health = -3 },
					Traits = { Studious = 1 },
					Flags = { "Bookworm" },
					Story = "{name} read under the covers by torchlight, night after night.",
				},
			},
			{
				Id = "Argue",
				Text = "Argue until they give in",
				Description = "You can be very persuasive.",
				Effects = {
					Stats = { Happiness = 2, Relationships = -5, Reputation = -2 },
					Bond = { Parent = -8 },
					Traits = { Rebellious = 1 },
					Flags = { "Rebellious" },
					Story = "{name} argued every single night. Dinners got a bit tense.",
				},
			},
			{
				Id = "Tablet",
				Text = "Pretend to sleep, then play on a tablet",
				Description = "What they don't know can't hurt them.",
				Effects = {
					Stats = { Happiness = 4, Health = -4 },
					Traits = { Playful = 1 },
					Story = "{name} played games under the duvet long after lights out.",
					Outcomes = {
						{ Chance = 0.5, Stats = { Relationships = -4, Reputation = -3 }, Bond = { Parent = -5 }, Story = "Until the night their parents walked in. Tablet confiscated for a month." },
					},
				},
			},
		},
	},

	{
		Id = "C_Playground",
		Stage = 1,
		Icon = "🛝",
		Title = "Trouble in the Playground",
		Description = "An older kid is picking on someone from your class. They look close to tears.",
		Once = true,
		Choices = {
			{
				Id = "StandUp",
				Text = "Stand up for them",
				Description = "Someone has to.",
				Effects = {
					Stats = { Reputation = 7, Relationships = 5 },
					Traits = { Kind = 1, Brave = 1 },
					Flags = { "Protector" },
					Story = "{name} stepped in between them and told the older kid to back off.",
					Outcomes = {
						{ Chance = 0.3, Stats = { Health = -4 }, Story = "It earned them a shove and a scraped knee, but a friend for life." },
					},
				},
			},
			{
				Id = "Race",
				Text = "Challenge the bully to a race",
				Description = "Beat them at their own game.",
				Requires = { AnyFlags = { "Athlete" } },
				LockHint = "Requires an athletic background",
				Effects = {
					Stats = { Popularity = 8, Reputation = 5, Health = 2 },
					Traits = { Brave = 1 },
					Flags = { "Protector" },
					Story = "{name} challenged the bully to a race across the field and won by a mile. The whole playground cheered.",
				},
			},
			{
				Id = "Teacher",
				Text = "Tell a teacher",
				Description = "Let the grown-ups handle it.",
				Effects = {
					Stats = { Reputation = 5, Relationships = 2, Popularity = -2 },
					Traits = { Kind = 1 },
					Story = "{name} fetched a teacher, who put a stop to it.",
				},
			},
			{
				Id = "Walk",
				Text = "Walk away",
				Description = "Not your problem.",
				Effects = {
					Stats = { Happiness = -2, Reputation = -2 },
					Story = "{name} walked away, but couldn't stop thinking about it that night.",
				},
			},
			{
				Id = "Join",
				Text = "Join in",
				Description = "Better them than you.",
				Effects = {
					Stats = { Popularity = 3, Reputation = -8, Relationships = -4 },
					Traits = { Rebellious = 1 },
					Flags = { "WasBully" },
					Story = "{name} joined in with the teasing. Some people never forgot it.",
				},
			},
		},
	},

	{
		Id = "C_Spark",
		Stage = 1,
		Icon = "💡",
		Title = "A Hidden Spark",
		Description = "Lately you can't stop thinking about something. A feeling that you might be really, really good at it.",
		Once = true,
		Weight = 2,
		Requires = { AnyFlags = { "Creative", "Bookworm", "Performer", "ChessClub", "Attentive" } },
		Choices = {
			{
				Id = "Music",
				Text = "Practise music every day",
				Description = "Melodies keep popping into your head.",
				Effects = {
					Stats = { Happiness = 4, Intelligence = 3, Popularity = 2 },
					Traits = { Creative = 1 },
					Flags = { "MusicTalent" },
					Story = "{name} discovered a real gift for music and practised every single day.",
				},
			},
			{
				Id = "Writing",
				Text = "Fill notebooks with stories",
				Description = "Whole worlds live in your head.",
				Effects = {
					Stats = { Intelligence = 5, Happiness = 3 },
					Traits = { Creative = 1 },
					Flags = { "WritingTalent" },
					Story = "{name} filled notebook after notebook with stories, each better than the last.",
				},
			},
			{
				Id = "Tech",
				Text = "Take apart old gadgets",
				Description = "How does it all work?",
				Effects = {
					Stats = { Intelligence = 7 },
					Traits = { Studious = 1 },
					Flags = { "TechTalent" },
					Story = "{name} took apart every old gadget in the house and, impressively, put most of them back together.",
				},
			},
			{
				Id = "Ignore",
				Text = "Ignore it",
				Description = "It's probably just a phase.",
				Effects = {
					Stats = { Happiness = -1 },
					Flags = { "IgnoredTalent" },
					Story = "{name} let the spark fade. Years later, they'd sometimes wonder what might have been.",
				},
			},
		},
	},

	{
		Id = "C_PocketMoney",
		Stage = 1,
		Icon = "🪙",
		Title = "Pocket Money",
		Description = "A relative slips you $10 for your birthday. It's the most money you've ever had.",
		Once = true,
		Choices = {
			{
				Id = "Save",
				Text = "Save it in a piggy bank",
				Description = "Future you will thank you.",
				Effects = {
					Money = 10,
					Stats = { Reputation = 1 },
					Traits = { Thrifty = 1 },
					Flags = { "Saver" },
					Story = "{name} put every cent into a piggy bank and checked on it daily.",
				},
			},
			{
				Id = "Spend",
				Text = "Buy sweets and toys",
				Description = "Treat yourself!",
				Effects = {
					Stats = { Happiness = 5, Health = -1 },
					Traits = { Playful = 1 },
					Story = "{name} spent it all at the corner shop in under ten minutes.",
				},
			},
			{
				Id = "Lemonade",
				Text = "Start a lemonade stand",
				Description = "Turn $10 into more.",
				Effects = {
					Stats = { Intelligence = 2 },
					Traits = { Ambitious = 1 },
					Story = "{name} spent the money on lemons and sugar and set up a stand at the end of the road.",
					Outcomes = {
						{ Chance = 0.55, Money = 35, Stats = { Happiness = 4, Reputation = 3 }, Flags = { "YoungEntrepreneur" }, Story = "It sold out by noon. $35 profit!" },
						{ Chance = 0.45, Stats = { Happiness = -3 }, Flags = { "Determined" }, Story = "It rained all day. Nobody came." },
					},
				},
			},
			{
				Id = "Charity",
				Text = "Put it in a charity box",
				Description = "Someone needs it more.",
				Effects = {
					Stats = { Reputation = 6, Happiness = 3 },
					Traits = { Kind = 1 },
					Flags = { "Generous" },
					Story = "{name} dropped the whole $10 into a charity box without a second thought.",
				},
			},
		},
	},

	{
		Id = "C_Moving",
		Stage = 1,
		Icon = "📦",
		Title = "Moving Day?",
		Description = "Your parents sit you down: there's a job offer in another city. They want to know how you feel.",
		Once = true,
		Weight = 0.7,
		Choices = {
			{
				Id = "Stay",
				Text = "Beg to stay",
				Description = "Your whole life is here.",
				Effects = {
					Stats = { Relationships = 3, Happiness = -2 },
					Flags = { "Hometown" },
					Story = "{name} begged to stay, and the family decided to remain in their hometown.",
				},
			},
			{
				Id = "Excited",
				Text = "Get excited for a fresh start",
				Description = "New city, new adventures.",
				Effects = {
					Stats = { Happiness = 3, Popularity = -3, Relationships = -3 },
					Traits = { Adventurous = 1 },
					Flags = { "Moved", "Adventurous" },
					Story = "{name} packed their own boxes and couldn't wait to explore the new city.",
				},
			},
			{
				Id = "Promise",
				Text = "Move, but promise to keep in touch",
				Description = "Distance doesn't end friendship.",
				Effects = {
					Stats = { Relationships = 5, Happiness = -1 },
					Traits = { Kind = 1 },
					Flags = { "Moved", "Loyal" },
					Story = "{name} moved away but wrote to their old friends every week.",
				},
			},
		},
	},

	{
		Id = "C_OnlineGame",
		Stage = 1,
		Icon = "🕹️",
		Title = "The Online Game",
		Description = "Everyone at school is obsessed with a new online game, and you're already pretty good.",
		Once = true,
		Weight = 2,
		Requires = { Flags = { "Gamer" } },
		Choices = {
			{
				Id = "Grind",
				Text = "Grind to the top of the leaderboard",
				Description = "Glory awaits.",
				Effects = {
					Stats = { Popularity = 5, Intelligence = 1, Health = -3 },
					Flags = { "CompetitiveGamer" },
					Story = "{name} climbed the leaderboard week after week.",
					Outcomes = {
						{ Chance = 0.15, Stats = { Popularity = 6, Happiness = 4 }, Flags = { "StreamerSeed" }, Story = "A clip of them went viral and hundreds of people started watching their games." },
					},
				},
			},
			{
				Id = "Friends",
				Text = "Play with classmates",
				Description = "It's better together.",
				Effects = {
					Stats = { Relationships = 5, Happiness = 3 },
					Traits = { Social = 1 },
					Friends = 1,
					Story = "{name} played with their classmates every evening, laughing over voice chat.",
				},
			},
			{
				Id = "Break",
				Text = "Take a break from screens",
				Description = "Touch some grass.",
				Effects = {
					Stats = { Health = 4, Happiness = -1 },
					Story = "{name} decided to take a break and rediscovered their bike.",
				},
			},
		},
	},

	{
		Id = "C_SchoolPlay",
		Stage = 1,
		Icon = "🎭",
		Title = "The School Play",
		Description = "Auditions for the end-of-year play are tomorrow. The whole school will be watching.",
		Once = true,
		Boost = { Flags = { Performer = 3, MusicTalent = 2 } },
		Choices = {
			{
				Id = "Lead",
				Text = "Audition for the lead",
				Description = "Go big or go home.",
				Effects = {
					Stats = { Popularity = 2 },
					Traits = { Charismatic = 1 },
					Story = "{name} auditioned for the lead role.",
					Outcomes = {
						{ Chance = 0.5, Stats = { Popularity = 8, Happiness = 5 }, Flags = { "StageStar" }, Story = "They got it, and brought the house down on opening night." },
						{ Chance = 0.5, Stats = { Happiness = -3 }, Story = "They were cast as Tree Number Three. A very convincing tree." },
					},
				},
			},
			{
				Id = "Song",
				Text = "Perform a song you wrote",
				Description = "Show them what you can really do.",
				Requires = { Flags = { "MusicTalent" } },
				LockHint = "Requires a musical talent",
				Effects = {
					Stats = { Popularity = 10, Happiness = 6, Reputation = 3 },
					Flags = { "StageStar", "Songwriter" },
					Story = "{name} performed a song they'd written themselves. People were still humming it weeks later.",
				},
			},
			{
				Id = "Scenery",
				Text = "Paint the scenery",
				Description = "Behind the scenes, but essential.",
				Effects = {
					Stats = { Happiness = 3, Intelligence = 2 },
					Traits = { Creative = 1 },
					Story = "{name} painted a stunning backdrop for the play.",
				},
			},
			{
				Id = "Tech",
				Text = "Run the lights and sound",
				Description = "Press the right buttons at the right time.",
				Effects = {
					Stats = { Intelligence = 3, Relationships = 2 },
					Story = "{name} ran the lights and sound desk without a single mistake.",
				},
			},
			{
				Id = "Skip",
				Text = "Skip it",
				Description = "Theatre isn't your thing.",
				Effects = {
					Stats = { Happiness = 1 },
					Story = "{name} skipped the play.",
				},
			},
		},
	},

	{
		Id = "C_SickDay",
		Stage = 1,
		Icon = "🤒",
		Title = "Feeling Unwell",
		Description = "You wake up with a sore throat and a runny nose. There's a test at school today.",
		Once = true,
		Requires = { MinAge = 7 },
		Choices = {
			{
				Id = "Rest",
				Text = "Rest and drink plenty of water",
				Description = "Health comes first.",
				Effects = {
					Stats = { Health = 6, Intelligence = -1 },
					Story = "{name} stayed home, rested, and was back on their feet in two days.",
				},
			},
			{
				Id = "Push",
				Text = "Go to school anyway",
				Description = "You can't miss that test.",
				Effects = {
					Stats = { Reputation = 3, Intelligence = 2, Health = -5 },
					Traits = { Ambitious = 1 },
					Story = "{name} dragged themselves to school, sat the test and passed, then slept for fourteen hours.",
				},
			},
			{
				Id = "Fake",
				Text = "Pretend to be even sicker",
				Description = "Maybe stretch this to a whole week.",
				Effects = {
					Stats = { Happiness = 3, Reputation = -3, Intelligence = -2 },
					Story = "{name} put on an award-winning performance of being very, very ill.",
					Outcomes = {
						{ Chance = 0.4, Stats = { Relationships = -3 }, Story = "Their parents saw them dancing in their room. Busted." },
					},
				},
			},
		},
	},
}
