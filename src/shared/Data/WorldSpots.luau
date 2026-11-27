--[[
	WorldSpots  (ReplicatedStorage.Shared.Data.WorldSpots)
	Every interactive spot in Lifeville. The world builder puts a
	ProximityPrompt (attribute CYL_Spot = id) on the matching object; the
	server (Actions.World) validates and applies it.

	Kinds:
	  Action — uses 1 of your 2 actions between decisions (same budget as the
	           People panel), applies Effects (Consequences format: Stats,
	           Bond, Flags, Traits, Outcomes...) and may cost money.
	  Shift  — an extra shift at your workplace (only for matching careers):
	           pay is ShiftPay × your salary, plus Career Success.
	  Open   — opens a screen (Shop, Money, SlotSelect, Map). Free.

	Optional fields: MinAge, MaxAge, Flag (required life flag), OwnHome (only in
	your own house), Lock (building lock id), Cost = { Child, Teen, Adult }.
]]

local WorldSpots = {}

WorldSpots.ShiftPay = 0.012 -- of yearly salary
WorldSpots.MinShiftPay = 60

local function spot(t)
	return t
end

WorldSpots.List = {
	-- ===== Lifeville Plaza =====
	spot({ Id = "Plaza_Wish", District = "Plaza", Kind = "Action", Label = "Make a wish", Object = "⛲ Wishing fountain",
		Effects = { Stats = { Happiness = 2 }, Outcomes = { { Chance = 0.15, Stats = { Happiness = 2 }, Money = 20, Story = "A wish at the fountain came true: {name} found $20 on the way home!" } } },
		Text = "You tossed a coin into the fountain and made a wish." }),
	spot({ Id = "Plaza_Hall", District = "Plaza", Kind = "Open", Open = "SlotSelect", Label = "Choose a life", Object = "🌟 Hall of Lives" }),
	spot({ Id = "Plaza_Board", District = "Plaza", Kind = "Open", Open = "Map", Label = "Read the town map", Object = "🗺️ Notice board" }),

	-- ===== Maple School =====
	spot({ Id = "School_Study", District = "School", Kind = "Action", Label = "Study hard", Object = "📚 Classroom desk", MaxAge = 18,
		Effects = { Stats = { Intelligence = 3, Happiness = -1 } }, Text = "You put your head down and studied. Your grades are climbing." }),
	spot({ Id = "School_Library", District = "School", Kind = "Action", Label = "Read in the library", Object = "📖 School library",
		Effects = { Stats = { Intelligence = 2, Happiness = 1 } }, Text = "You lost yourself in a good book." }),
	spot({ Id = "School_Football", District = "School", Kind = "Action", Label = "Play football", Object = "⚽ Sports field",
		Effects = { Stats = { Health = 2, Popularity = 1 } }, Text = "A great game! Everyone wants you on their team." }),
	spot({ Id = "School_Playground", District = "School", Kind = "Action", Label = "Play on the playground", Object = "🛝 Playground", MaxAge = 12,
		Effects = { Stats = { Happiness = 2, Relationships = 1 } }, Text = "You played tag until the bell rang." }),
	spot({ Id = "School_Shift", District = "School", Kind = "Shift", Workplace = "School", Label = "Teach an extra class", Object = "🍎 Staff room",
		Text = "You taught an extra class. The pupils were (mostly) listening." }),

	-- ===== Lifeville University =====
	spot({ Id = "Uni_Lecture", District = "University", Kind = "Action", Label = "Attend a lecture", Object = "🎓 Lecture hall", Flag = "AtUni",
		FlagText = "Only enrolled students can attend lectures. Choose university in your teenage decisions.",
		Effects = { Stats = { Intelligence = 3, Career = 1, Happiness = -1 } }, Text = "A fascinating lecture. You took pages of notes." }),
	spot({ Id = "Uni_Evening", District = "University", Kind = "Action", Label = "Take an evening class", Object = "🌙 Evening classes", MinAge = 19,
		Cost = { Adult = 150 }, Effects = { Stats = { Intelligence = 2, Career = 1 } }, Text = "It's never too late to learn something new." }),
	spot({ Id = "Uni_Library", District = "University", Kind = "Action", Label = "Study in the library", Object = "📚 Campus library",
		Effects = { Stats = { Intelligence = 2 } }, Text = "Hours in the quiet library paid off." }),
	spot({ Id = "Uni_Society", District = "University", Kind = "Action", Label = "Join a student society", Object = "🎭 Student union", Flag = "AtUni",
		FlagText = "Societies are for students. Choose university in your teenage decisions.",
		Effects = { Stats = { Popularity = 2, Relationships = 1 } }, Text = "You signed up for a society and met some brilliant people." }),

	-- ===== Downtown =====
	spot({ Id = "Office_Shift", District = "Downtown", Kind = "Shift", Workplace = "Office", Label = "Work overtime", Object = "💼 Lifeville Tower",
		Text = "You stayed late and smashed your targets." }),
	spot({ Id = "Office_Fair", District = "Downtown", Kind = "Action", Label = "Visit the careers fair", Object = "🧑‍💼 Careers fair", MinAge = 15,
		Effects = { Stats = { Career = 2, Intelligence = 1 } }, Text = "You picked up leaflets, tips and a couple of useful contacts." }),
	spot({ Id = "Bank_Open", District = "Downtown", Kind = "Open", Open = "Money", Label = "Manage your money", Object = "🏦 Lifeville Bank" }),
	spot({ Id = "Cafe_Chat", District = "Downtown", Kind = "Action", Label = "Chat with the locals", Object = "☕ Lifeville Café",
		Cost = { Child = 2, Teen = 4, Adult = 6 }, Effects = { Stats = { Relationships = 2, Popularity = 1 } }, Text = "A hot drink and a good natter. People really like you." }),
	spot({ Id = "Restaurant_Eat", District = "Downtown", Kind = "Action", Label = "Eat out", Object = "🍝 The Golden Fork",
		Cost = { Teen = 15, Adult = 40 }, Effects = { Stats = { Happiness = 3 } }, Text = "A delicious meal. You'll be dreaming about that pasta." }),
	spot({ Id = "Restaurant_Treat", District = "Downtown", Kind = "Action", Label = "Treat your family to dinner", Object = "🕯️ Family table", MinAge = 19,
		Cost = { Adult = 120 }, Effects = { Stats = { Happiness = 2, Relationships = 1 }, Bond = { Parent = 5, Partner = 6, Child = 5, Sibling = 3 } },
		Text = "Dinner was on you. Everyone left full and happy." }),
	spot({ Id = "Restaurant_Shift", District = "Downtown", Kind = "Shift", Workplace = "Restaurant", Label = "Cook an extra service", Object = "👨‍🍳 Kitchen",
		Text = "Orders flew out of your kitchen all night." }),
	spot({ Id = "Boutique_Shop", District = "Downtown", Kind = "Open", Open = "Shop", Label = "Browse the shop", Object = "🛍️ Boutique" }),
	spot({ Id = "Boutique_Shift", District = "Downtown", Kind = "Shift", Workplace = "Boutique", Label = "Work an extra shift", Object = "🛒 Shop floor",
		Text = "A busy day on the shop floor. Customers loved you." }),
	spot({ Id = "Arcade_Play", District = "Downtown", Kind = "Action", Label = "Play arcade games", Object = "🕹️ Starlight Arcade",
		Cost = { Child = 2, Teen = 5, Adult = 10 }, Effects = { Stats = { Happiness = 2, Popularity = 1 } }, Text = "New high score! Your name is on the leaderboard." }),
	spot({ Id = "Cinema_Watch", District = "Downtown", Kind = "Action", Label = "Watch a film", Object = "🎬 Starlight Cinema",
		Cost = { Child = 4, Teen = 8, Adult = 12 }, Effects = { Stats = { Happiness = 2 } }, Text = "Popcorn, a big screen and a great story." }),
	spot({ Id = "Arcade_Shift", District = "Downtown", Kind = "Shift", Workplace = "Arcade", Label = "Stream a tournament", Object = "🎮 Esports stage",
		Text = "You streamed a tournament to thousands of viewers." }),

	-- ===== Career Row =====
	spot({ Id = "Police_Shift", District = "CareerRow", Kind = "Shift", Workplace = "Police", Label = "Go on patrol", Object = "👮 Police Station",
		Text = "A long patrol. The streets felt safer with you around." }),
	spot({ Id = "Police_Watch", District = "CareerRow", Kind = "Action", Label = "Join the community watch", Object = "🚓 Community desk", MinAge = 13,
		Effects = { Stats = { Reputation = 2, Relationships = 1 } }, Text = "You helped keep the neighbourhood safe." }),
	spot({ Id = "Studio_Shift", District = "CareerRow", Kind = "Shift", Workplace = "Studio", Label = "Rehearse and record", Object = "🎙️ Recording booth",
		Text = "A long session in the studio. That take was the one." }),
	spot({ Id = "Studio_OpenMic", District = "CareerRow", Kind = "Action", Label = "Perform at open-mic night", Object = "🎤 Starlight stage", MinAge = 13,
		Effects = { Stats = { Popularity = 2, Happiness = 1 }, Outcomes = { { Chance = 0.2, Stats = { Happiness = -3, Popularity = -1 }, Story = "{name} got stage fright at open-mic night. Next time!" } } },
		Text = "You took the stage and the crowd cheered." }),
	spot({ Id = "Theatre_Watch", District = "CareerRow", Kind = "Action", Label = "Watch a show", Object = "🎭 Starlight Theatre",
		Cost = { Child = 5, Teen = 10, Adult = 25 }, Effects = { Stats = { Happiness = 3 } }, Text = "A standing ovation, and you were part of it." }),
	spot({ Id = "Lab_Shift", District = "CareerRow", Kind = "Shift", Workplace = "Lab", Label = "Run experiments", Object = "🔬 Research lab",
		Text = "Your experiment finally worked. Data like this gets published." }),
	spot({ Id = "Lab_Exhibit", District = "CareerRow", Kind = "Action", Label = "Explore the science exhibit", Object = "🚀 Science exhibit",
		Cost = { Teen = 3, Adult = 8 }, Effects = { Stats = { Intelligence = 2, Happiness = 1 } }, Text = "Rockets, robots and a real meteorite. Mind blown." }),
	spot({ Id = "Court_Shift", District = "CareerRow", Kind = "Shift", Workplace = "Court", Label = "Argue a case", Object = "⚖️ Courtroom",
		Text = "A brilliant closing argument. The jury was hanging on every word." }),
	spot({ Id = "Court_Watch", District = "CareerRow", Kind = "Action", Label = "Sit in on a trial", Object = "🏛️ Public gallery", MinAge = 13,
		Effects = { Stats = { Intelligence = 1, Reputation = 1 } }, Text = "You watched justice in action and learned a lot." }),
	spot({ Id = "Workshop_Shift", District = "CareerRow", Kind = "Shift", Workplace = "Workshop", Label = "Take on a job", Object = "🔧 Workshop",
		Text = "Wired, fixed and finished on time. Another happy customer." }),
	spot({ Id = "Workshop_Class", District = "CareerRow", Kind = "Action", Label = "Learn to fix things", Object = "🛠️ Workbench", MinAge = 13,
		Effects = { Stats = { Intelligence = 1, Career = 1 } }, Text = "You fixed your first radio. Handy!" }),
	spot({ Id = "TownHall_Volunteer", District = "CareerRow", Kind = "Action", Label = "Volunteer for the town", Object = "🏛️ Town Hall", MinAge = 13,
		Effects = { Stats = { Reputation = 3, Happiness = 1 } }, Text = "You gave your time to the community. People noticed." }),

	-- ===== St. Hope Hospital =====
	spot({ Id = "Hospital_Checkup", District = "Hospital", Kind = "Action", Label = "Get a check-up", Object = "🩺 Reception",
		Cost = { Adult = 60 }, Effects = { Stats = { Health = 3 } }, Text = "The doctor gave you a clean bill of health and some good advice." }),
	spot({ Id = "Hospital_Volunteer", District = "Hospital", Kind = "Action", Label = "Volunteer on the wards", Object = "💐 Wards", MinAge = 13,
		Effects = { Stats = { Reputation = 2, Happiness = 1, Relationships = 1 } }, Text = "You brightened a lot of patients' days." }),
	spot({ Id = "Hospital_Shift", District = "Hospital", Kind = "Shift", Workplace = "Hospital", Label = "Work a shift", Object = "🏥 Staff entrance",
		Text = "A long shift on the wards. You saved the day, more than once." }),

	-- ===== Willow Park =====
	spot({ Id = "Park_Run", District = "Park", Kind = "Action", Label = "Go for a run", Object = "🏃 Running track",
		Effects = { Stats = { Health = 3, Happiness = 1 } }, Text = "Three laps of the park. You feel amazing." }),
	spot({ Id = "Park_Ducks", District = "Park", Kind = "Action", Label = "Feed the ducks", Object = "🦆 Duck pond",
		Effects = { Stats = { Happiness = 2 } }, Text = "The ducks were very grateful. One followed you home." }),
	spot({ Id = "Park_Picnic", District = "Park", Kind = "Action", Label = "Have a family picnic", Object = "🧺 Picnic area",
		Cost = { Adult = 15 }, Effects = { Stats = { Happiness = 1 }, Bond = { Parent = 4, Sibling = 3, Partner = 4, Child = 4 } }, Text = "Sandwiches, sunshine and family. Perfect." }),
	spot({ Id = "Park_Gym", District = "Park", Kind = "Action", Label = "Work out", Object = "🏋️ Outdoor gym", MinAge = 13,
		Effects = { Stats = { Health = 2, Popularity = 1 } }, Text = "Pull-ups, push-ups, done. You're getting stronger." }),
	spot({ Id = "Park_Swings", District = "Park", Kind = "Action", Label = "Play on the swings", Object = "🛝 Playground", MaxAge = 12,
		Effects = { Stats = { Happiness = 2 } }, Text = "Higher! Higher! Best afternoon ever." }),
	spot({ Id = "Arena_Watch", District = "Park", Kind = "Action", Label = "Watch a match", Object = "🏟️ Willow Arena",
		Cost = { Child = 3, Teen = 6, Adult = 15 }, Effects = { Stats = { Happiness = 2, Relationships = 1 } }, Text = "What a match! The crowd went wild." }),
	spot({ Id = "Arena_Shift", District = "Park", Kind = "Shift", Workplace = "Arena", Label = "Train with the team", Object = "🏅 Training pitch",
		Text = "A gruelling training session. You're in the form of your life." }),
	spot({ Id = "Club_Bowls", District = "Park", Kind = "Action", Label = "Play bowls", Object = "🎳 Sunset Club green", Lock = "SunsetClub", MinAge = 61,
		Effects = { Stats = { Happiness = 2, Relationships = 2 } }, Text = "A gentle game of bowls with old friends." }),
	spot({ Id = "Club_Tea", District = "Park", Kind = "Action", Label = "Tea and stories", Object = "🫖 Sunset Club tea room", Lock = "SunsetClub", MinAge = 61,
		Effects = { Stats = { Relationships = 2, Health = 1 } }, Text = "Tea, biscuits and stories from the good old days." }),

	-- ===== Oak Street =====
	spot({ Id = "Home_Rest", District = "Residential", Kind = "Action", Label = "Rest at home", Object = "🛋️ Your home", OwnHome = true,
		Effects = { Stats = { Health = 2, Happiness = 1 } }, Text = "Feet up, a cup of tea and a nap. Bliss." }),
	spot({ Id = "Home_Dinner", District = "Residential", Kind = "Action", Label = "Have a family dinner", Object = "🍲 Your kitchen", OwnHome = true,
		Effects = { Stats = { Relationships = 1 }, Bond = { Parent = 4, Sibling = 3, Partner = 5, Child = 5 } }, Text = "Everyone round the table, talking about their day." }),
	spot({ Id = "Flats_Neighbours", District = "Residential", Kind = "Action", Label = "Chat with the neighbours", Object = "🏢 Oak Street Apartments",
		Effects = { Stats = { Relationships = 1, Popularity = 1 } }, Text = "You finally learned your neighbours' names. Lovely people." }),

	-- ===== Harbour & Hilltop =====
	spot({ Id = "Beach_Swim", District = "Harbour", Kind = "Action", Label = "Go for a swim", Object = "🏖️ Lifeville Beach",
		Effects = { Stats = { Health = 2, Happiness = 1 } }, Text = "The water was freezing. And brilliant." }),
	spot({ Id = "Beach_IceCream", District = "Harbour", Kind = "Action", Label = "Buy an ice cream", Object = "🍦 Ice-cream kiosk",
		Cost = { Child = 1, Teen = 2, Adult = 3 }, Effects = { Stats = { Happiness = 2 } }, Text = "Two scoops, extra sprinkles." }),
	spot({ Id = "Pier_Fish", District = "Harbour", Kind = "Action", Label = "Go fishing", Object = "🎣 The pier",
		Effects = { Stats = { Happiness = 2 }, Outcomes = { { Chance = 0.2, Stats = { Popularity = 1 }, Story = "{name} caught a fish so big it made the local paper!" } } },
		Text = "A peaceful afternoon on the pier." }),
	spot({ Id = "Harbour_Trip", District = "Harbour", Kind = "Action", Label = "Book a trip abroad", Object = "✈️ Harbour travel agent", MinAge = 19,
		Cost = { Adult = 2500 }, Effects = { Stats = { Happiness = 4, Intelligence = 1 }, Flags = { "Traveller" }, Traits = { Adventurous = 1 } },
		Text = "You saw the world: new cities, new food, new friends. Life feels bigger now." }),
}

WorldSpots.ById = {}
for _, s in ipairs(WorldSpots.List) do
	WorldSpots.ById[s.Id] = s
end

function WorldSpots.Get(id: any)
	return if type(id) == "string" then WorldSpots.ById[id] else nil
end

function WorldSpots.AgeGroup(age: number): string
	if age < 13 then
		return "Child"
	elseif age < 19 then
		return "Teen"
	end
	return "Adult"
end

function WorldSpots.CostFor(spotDef, age: number): number
	local cost = spotDef.Cost
	if not cost then
		return 0
	end
	return cost[WorldSpots.AgeGroup(age)] or 0
end

-- Problems with the data (tested): bad districts, workplaces, kinds, duplicates.
function WorldSpots.Validate(World, StatNames)
	local problems = {}
	local seen = {}
	for _, s in ipairs(WorldSpots.List) do
		if seen[s.Id] then
			table.insert(problems, "duplicate spot " .. s.Id)
		end
		seen[s.Id] = true
		if not World.ById[s.District] then
			table.insert(problems, s.Id .. ": unknown district " .. tostring(s.District))
		end
		if s.Kind ~= "Action" and s.Kind ~= "Shift" and s.Kind ~= "Open" then
			table.insert(problems, s.Id .. ": bad kind")
		end
		if s.Kind == "Shift" and not World.Workplaces[s.Workplace] then
			table.insert(problems, s.Id .. ": unknown workplace " .. tostring(s.Workplace))
		end
		if s.Kind == "Action" and not s.Effects then
			table.insert(problems, s.Id .. ": action without effects")
		end
		if s.Effects and s.Effects.Stats then
			for stat in pairs(s.Effects.Stats) do
				if not table.find(StatNames, stat) or stat == "Wealth" then
					table.insert(problems, s.Id .. ": bad stat " .. stat)
				end
			end
		end
		if s.Lock and not World.Locks[s.Lock] then
			table.insert(problems, s.Id .. ": unknown lock " .. s.Lock)
		end
		if not s.Label or not s.Object then
			table.insert(problems, s.Id .. ": needs Label and Object")
		end
	end
	return problems
end

return WorldSpots
