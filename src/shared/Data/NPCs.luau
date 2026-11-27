--[[
	NPCs  (ReplicatedStorage.Shared.Data.NPCs)
	The people of Lifeville: names, looks, what they say and what they can do
	for you. District builders place each one (NPC anchors); NPCService spawns
	them; DialogueController shows their lines.

	Lines: by life stage key (Childhood, Teen, YoungAdult, Adult, MiddleAge,
	Retirement) with Default as the fallback; Career lines win when the
	player's career matches. Options:
	  { Text, Reply }            just a reply
	  { Text, Spot = id }        do a world action (WorldSpots) right here
	  { Text, Open = screen }    Shop / Money / Map / SlotSelect / People / Future
	  { Text, Guide = district } point the way (map waypoint)
	  { Text, Tip = true }       a helpful tip about the game
	  MinAge / MaxAge on an option hide it for other ages (the server still checks).
]]

local NPCs = {}

-- Looks: Skin/Shirt/Pants hex colours, Hair colour + style, optional Hat.
local SKIN = { "#F1C27D", "#E0AC69", "#C68642", "#8D5524", "#FFDBAC", "#A0662F" }

NPCs.List = {
	-- ===== Plaza =====
	{ Id = "Mayor", Name = "Mayor Bloom", Role = "Mayor of Lifeville", Icon = "🎩", Anim = "Wave",
		Looks = { Skin = SKIN[1], Shirt = "#3D405B", Pants = "#22223B", Hair = "#B0B0B0", HairStyle = "Short", Hat = "Top" },
		Lines = {
			Default = "Welcome to Lifeville! Every choice you make shapes your future, and this town grows with you.",
			Childhood = "Hello there, young one! The school, the park, Oak Street and the hospital are all open to you. More of town opens as you grow up!",
			Teen = "Downtown and the harbour are open to you now. Grab a milkshake, but don't forget your studies!",
			Retirement = "Ah, a wise resident! The Sunset Club in Willow Park has opened its doors to you.",
		},
		Options = {
			{ Text = "What can I do around town?", Reply = "Walk up to things and people. You get 2 actions between decisions: study, exercise, eat out, work a shift... Then press 📝 Next decision." },
			{ Text = "Show me the town map", Open = "Map" },
			{ Text = "Any tips?", Tip = true },
		} },
	{ Id = "Keeper", Name = "Sage the Keeper", Role = "Keeper of the Hall of Lives", Icon = "🌟", Anim = "Idle",
		Looks = { Skin = SKIN[4], Shirt = "#6A4C93", Pants = "#3C2A4D", Hair = "#1B1B1B", HairStyle = "Long" },
		Lines = { Default = "Every life you live is kept here, in the Hall of Lives. Which life will you live today?" },
		Options = {
			{ Text = "Choose a life", Open = "SlotSelect" },
			{ Text = "What are the pedestals?", Reply = "One for each of your three save slots. Continue a life, or begin a brand new one." },
		} },
	{ Id = "Busker", Name = "Jay the Busker", Role = "Street musician", Icon = "🎸", Anim = "Dance",
		Looks = { Skin = SKIN[3], Shirt = "#F4A261", Pants = "#264653", Hair = "#3B2F2F", HairStyle = "Short", Hat = "Cap" },
		Lines = { Default = "Every street has a song! Mine's just a bit louder.", Career = { Musician = "A fellow musician! Fancy a jam later?", Singer = "That voice of yours could fill a stadium." } },
		Options = {
			{ Text = "How do I become a musician?", Reply = "Pick music when it comes up in your choices. Open-mic night at Starlight Studios helps too!" },
			{ Text = "Where's Starlight Studios?", Guide = "CareerRow" },
		} },

	-- ===== Maple School =====
	{ Id = "Teacher", Name = "Ms. Rivera", Role = "Teacher", Icon = "🍎", Anim = "Point",
		Looks = { Skin = SKIN[2], Shirt = "#E76F51", Pants = "#3D405B", Hair = "#5A3825", HairStyle = "Bun" },
		Lines = {
			Default = "Learning never stops. Not even when you're grown up!",
			Childhood = "Good morning! Studying at your desk raises your Intelligence, and the playground makes you happy.",
			Teen = "Exams are coming. A little studying now opens doors later, like university.",
			Career = { Teacher = "Morning, colleague! The staff room needs you for an extra class." },
		},
		Options = {
			{ Text = "Help me study", Spot = "School_Study", MaxAge = 18 },
			{ Text = "How do I get into university?", Reply = "Keep your Intelligence up and choose university in your teenage decisions." },
		} },
	{ Id = "Librarian", Name = "Mr. Chen", Role = "Librarian", Icon = "📖", Anim = "Idle",
		Looks = { Skin = SKIN[5], Shirt = "#2A9D8F", Pants = "#264653", Hair = "#2B2B2B", HairStyle = "Short" },
		Lines = { Default = "Shh... A good book is the best adventure there is." },
		Options = { { Text = "Recommend me a book", Spot = "School_Library" } } },
	{ Id = "Coach", Name = "Coach Okafor", Role = "Sports coach", Icon = "⚽", Anim = "Point",
		Looks = { Skin = SKIN[4], Shirt = "#E63946", Pants = "#1D3557", HairStyle = "Bald", Hat = "Cap" },
		Lines = { Default = "Sport keeps you healthy and makes you friends. Get out there!", Career = { Athlete = "There's my star! The arena team is lucky to have you." } },
		Options = { { Text = "Put me in the game", Spot = "School_Football" } } },

	-- ===== Lifeville University =====
	{ Id = "Professor", Name = "Professor Hale", Role = "Professor", Icon = "🎓", Anim = "Point",
		Looks = { Skin = SKIN[1], Shirt = "#5E548E", Pants = "#231942", Hair = "#E0E0E0", HairStyle = "Short", Hat = "Grad" },
		Lines = {
			Default = "Curiosity is the engine of every great life.",
			YoungAdult = "Enrolled students can attend my lectures. Everyone else is welcome at evening classes.",
			Career = { Scientist = "Your research is the talk of the faculty!" },
		},
		Options = {
			{ Text = "Attend a lecture", Spot = "Uni_Lecture" },
			{ Text = "Tell me about evening classes", Reply = "From 19, anyone can take an evening class here for $150. It builds Intelligence and Career Success." },
		} },
	{ Id = "Student", Name = "Sam", Role = "Student", Icon = "🎒", Anim = "Idle",
		Looks = { Skin = SKIN[2], Shirt = "#90BE6D", Pants = "#577590", Hair = "#E9C46A", HairStyle = "Long" },
		Lines = { Default = "Three essays due this week. Send coffee." },
		Options = { { Text = "Any good societies?", Reply = "The drama society is the best. Ask at the student union!" } } },

	-- ===== Downtown =====
	{ Id = "Receptionist", Name = "Priya", Role = "Lifeville Tower reception", Icon = "💼", Anim = "Idle",
		Looks = { Skin = SKIN[3], Shirt = "#F8F9FA", Pants = "#343A40", Hair = "#1B1B1B", HairStyle = "Long" },
		Lines = { Default = "Welcome to Lifeville Tower. Business, tech and media all happen upstairs.", Career = { Entrepreneur = "Your investors are waiting in meeting room three!" } },
		Options = {
			{ Text = "Visit the careers fair", Spot = "Office_Fair", MinAge = 15 },
			{ Text = "Who works here?", Reply = "Entrepreneurs, engineers, estate agents, influencers and YouTubers. They can work overtime upstairs." },
		} },
	{ Id = "Banker", Name = "Mr. Lewis", Role = "Bank manager", Icon = "🏦", Anim = "Idle",
		Looks = { Skin = SKIN[5], Shirt = "#14213D", Pants = "#14213D", Hair = "#7F5539", HairStyle = "Short" },
		Lines = { Default = "Saving a little each year adds up to a lot. Investing can add up to even more!", Childhood = "Too young for a bank account, but never too young to save your pocket money!" },
		Options = { { Text = "Manage my money", Open = "Money" } } },
	{ Id = "Barista", Name = "Mia", Role = "Barista", Icon = "☕", Anim = "Wave",
		Looks = { Skin = SKIN[1], Shirt = "#BC6C25", Pants = "#283618", Hair = "#9C6644", HairStyle = "Bun" },
		Lines = { Default = "What can I get you? The regulars here love a good chat." },
		Options = { { Text = "Chat with the regulars", Spot = "Cafe_Chat" } } },
	{ Id = "Waiter", Name = "Tom", Role = "Head waiter, The Golden Fork", Icon = "🍝", Anim = "Idle",
		Looks = { Skin = SKIN[6], Shirt = "#FFFFFF", Pants = "#111111", Hair = "#111111", HairStyle = "Short" },
		Lines = { Default = "Table for one? Our pasta is famous all over Lifeville.", Career = { Chef = "Chef! The kitchen's packed tonight." } },
		Options = {
			{ Text = "A table, please", Spot = "Restaurant_Eat" },
			{ Text = "Book the family table", Spot = "Restaurant_Treat", MinAge = 19 },
		} },
	{ Id = "Stylist", Name = "Zoe", Role = "Boutique stylist", Icon = "🛍️", Anim = "Wave",
		Looks = { Skin = SKIN[2], Shirt = "#FF006E", Pants = "#3A0CA3", Hair = "#FFBE0B", HairStyle = "Long" },
		Lines = { Default = "Darling, that look is SO you. But have you seen the new collection?" },
		Options = { { Text = "Show me the shop", Open = "Shop" } } },
	{ Id = "Usher", Name = "Ray", Role = "Starlight Cinema & Arcade", Icon = "🍿", Anim = "Idle",
		Looks = { Skin = SKIN[4], Shirt = "#7209B7", Pants = "#3F37C9", Hair = "#1B1B1B", HairStyle = "Short", Hat = "Cap" },
		Lines = { Default = "Film or games? Either way, popcorn's on the left.", Career = { ProGamer = "The esports stage is ready for your stream!" } },
		Options = {
			{ Text = "Watch a film", Spot = "Cinema_Watch" },
			{ Text = "Play some games", Spot = "Arcade_Play" },
		} },

	-- ===== Career Row =====
	{ Id = "Officer", Name = "Officer Grant", Role = "Police officer", Icon = "👮", Anim = "Idle",
		Looks = { Skin = SKIN[1], Shirt = "#1D3557", Pants = "#1D3557", Hair = "#5A3825", HairStyle = "Short", Hat = "Police" },
		Lines = { Default = "Lifeville is a safe town, and we'd like to keep it that way.", Career = { PoliceOfficer = "Ready for patrol, officer?" } },
		Options = { { Text = "Join the community watch", Spot = "Police_Watch", MinAge = 13 } } },
	{ Id = "Director", Name = "Luca", Role = "Director, Starlight Studios", Icon = "🎬", Anim = "Point",
		Looks = { Skin = SKIN[2], Shirt = "#000000", Pants = "#2B2D42", Hair = "#2B2B2B", HairStyle = "Short", Hat = "Beret" },
		Lines = { Default = "Lights, camera, action! Starlight Studios makes stars.", Career = { Actor = "Our leading star! Places, please.", Singer = "The booth's warmed up for you.", Musician = "Session's booked, the band's waiting.", Artist = "Your new mural for the lobby is stunning." } },
		Options = {
			{ Text = "Sign me up for open-mic night", Spot = "Studio_OpenMic", MinAge = 13 },
			{ Text = "Tickets for the show", Spot = "Theatre_Watch" },
		} },
	{ Id = "Scientist", Name = "Dr. Novak", Role = "Lab director", Icon = "🔬", Anim = "Idle",
		Looks = { Skin = SKIN[5], Shirt = "#FFFFFF", Pants = "#6C757D", Hair = "#C0C0C0", HairStyle = "Long" },
		Lines = { Default = "Science is just organised curiosity. The exhibit is open to everyone!", Career = { Scientist = "The results are in, and they're promising!", Astronaut = "Mission control has a new briefing for you." } },
		Options = { { Text = "See the exhibit", Spot = "Lab_Exhibit" } } },
	{ Id = "Judge", Name = "Judge Amara", Role = "Judge", Icon = "⚖️", Anim = "Idle",
		Looks = { Skin = SKIN[4], Shirt = "#111111", Pants = "#111111", Hair = "#E0E0E0", HairStyle = "Bun" },
		Lines = { Default = "Justice is patient. The public gallery is open if you'd like to watch.", Career = { Lawyer = "Counsel, your case is up next." } },
		Options = { { Text = "Watch a trial", Spot = "Court_Watch", MinAge = 13 } } },
	{ Id = "Builder", Name = "Bo", Role = "Master electrician", Icon = "🔧", Anim = "Idle",
		Looks = { Skin = SKIN[3], Shirt = "#F77F00", Pants = "#003049", HairStyle = "Bald", Hat = "Hard" },
		Lines = { Default = "If it's broken, I can fix it. Want to learn?", Career = { Tradesperson = "There's a rewiring job with your name on it." } },
		Options = { { Text = "Teach me something", Spot = "Workshop_Class", MinAge = 13 } } },
	{ Id = "Clerk", Name = "Ada", Role = "Town Hall clerk", Icon = "🏛️", Anim = "Wave",
		Looks = { Skin = SKIN[6], Shirt = "#457B9D", Pants = "#1D3557", Hair = "#111111", HairStyle = "Long" },
		Lines = { Default = "The town runs on volunteers. Fancy helping out?" },
		Options = { { Text = "I'd love to volunteer", Spot = "TownHall_Volunteer", MinAge = 13 } } },

	-- ===== St. Hope Hospital =====
	{ Id = "Doctor", Name = "Dr. Patel", Role = "Doctor", Icon = "🩺", Anim = "Idle",
		Looks = { Skin = SKIN[3], Shirt = "#FFFFFF", Pants = "#2A9D8F", Hair = "#111111", HairStyle = "Short" },
		Lines = { Default = "Exercise, rest and the occasional check-up. That's the secret to a long life.", Career = { Doctor = "Doctor! Ward three could use you." } },
		Options = {
			{ Text = "I'd like a check-up", Spot = "Hospital_Checkup" },
			{ Text = "How do I become a doctor?", Reply = "Study hard, go to university and choose medicine. It's a long road but worth it." },
		} },
	{ Id = "Nurse", Name = "Nurse Kim", Role = "Nurse", Icon = "💉", Anim = "Wave",
		Looks = { Skin = SKIN[5], Shirt = "#90E0EF", Pants = "#0077B6", Hair = "#2B2B2B", HairStyle = "Bun", Hat = "Nurse" },
		Lines = { Default = "Our patients love visitors. Volunteers make a real difference here." },
		Options = { { Text = "Volunteer on the wards", Spot = "Hospital_Volunteer", MinAge = 13 } } },

	-- ===== Willow Park =====
	{ Id = "Ranger", Name = "Ranger Rosa", Role = "Park ranger", Icon = "🌳", Anim = "Wave",
		Looks = { Skin = SKIN[2], Shirt = "#606C38", Pants = "#283618", Hair = "#6F4518", HairStyle = "Long", Hat = "Ranger" },
		Lines = { Default = "Fresh air, a run round the track, ducks to feed. Willow Park has it all." },
		Options = {
			{ Text = "Feed the ducks with me", Spot = "Park_Ducks" },
			{ Text = "Where's the arena?", Reply = "Just past the running track! The Lifeville team trains there." },
		} },
	{ Id = "Grandpa", Name = "Grandpa Joe", Role = "Sunset Club member", Icon = "🫖", Anim = "Idle",
		Looks = { Skin = SKIN[1], Shirt = "#A3B18A", Pants = "#588157", Hair = "#FFFFFF", HairStyle = "Bald", Hat = "Flat" },
		Lines = { Default = "In my day we walked to school uphill both ways! The Sunset Club opens for you at 61.", Retirement = "Welcome to the club! Bowls or tea? Why not both." },
		Options = { { Text = "Tell me a story", Reply = "I once met a fellow who chose every risky option. Millionaire by 30, broke by 31, happy at 80. Life's funny like that." } } },

	-- ===== Oak Street =====
	{ Id = "Neighbour", Name = "Nora", Role = "Your neighbour", Icon = "🏡", Anim = "Wave",
		Looks = { Skin = SKIN[6], Shirt = "#FFAFCC", Pants = "#A2D2FF", Hair = "#8D5524", HairStyle = "Bun" },
		Lines = { Default = "Your house is the one with your name on the sign. It changes as your life does!" },
		Options = {
			{ Text = "What's my house like?", Reply = "It grows with you: your family home, then your own flat, house or even a mansion. Your shop style and car show up too!" },
			{ Text = "Chat for a while", Spot = "Flats_Neighbours" },
		} },

	-- ===== Harbour & Hilltop =====
	{ Id = "Captain", Name = "Captain Finn", Role = "Harbour master", Icon = "⚓", Anim = "Point",
		Looks = { Skin = SKIN[1], Shirt = "#023E8A", Pants = "#03045E", Hair = "#E0E0E0", HairStyle = "Short", Hat = "Captain" },
		Lines = { Default = "The sea calls to adventurous souls. The travel agent can book you a trip abroad from 19." },
		Options = {
			{ Text = "Let's go fishing", Spot = "Pier_Fish" },
			{ Text = "Book a trip abroad", Spot = "Harbour_Trip", MinAge = 19 },
		} },
	{ Id = "IceCream", Name = "Lily", Role = "Ice-cream seller", Icon = "🍦", Anim = "Wave",
		Looks = { Skin = SKIN[2], Shirt = "#FFC8DD", Pants = "#CDB4DB", Hair = "#F4D35E", HairStyle = "Long" },
		Lines = { Default = "Strawberry, chocolate or mint? Sunshine's free!" },
		Options = { { Text = "One ice cream, please", Spot = "Beach_IceCream" } } },
	{ Id = "Butler", Name = "Mr. Graves", Role = "Butler of Hilltop Mansion", Icon = "🎩", Anim = "Idle",
		Looks = { Skin = SKIN[5], Shirt = "#111111", Pants = "#111111", Hair = "#7F7F7F", HairStyle = "Short" },
		Lines = { Default = "Hilltop Mansion belongs to whoever makes their fortune. Perhaps one day it shall be you." },
		Options = { { Text = "How do I get rich?", Reply = "Work hard, save and invest wisely, and maybe take one bold risk. The Future panel shows your odds." } } },
}

-- Walking townsfolk (follow World.WalkLoops; Talk gives a friendly line).
NPCs.Walkers = {
	{ Id = "Walker1", Name = "Ben", Role = "Jogger", Icon = "🏃", Looks = { Skin = SKIN[3], Shirt = "#06D6A0", Pants = "#073B4C", Hair = "#111111", HairStyle = "Short" }, Line = "Morning! Can't stop, personal best today!" },
	{ Id = "Walker2", Name = "Ella", Role = "Dog walker", Icon = "🐕", Looks = { Skin = SKIN[1], Shirt = "#FFD166", Pants = "#118AB2", Hair = "#D4A373", HairStyle = "Long" }, Line = "Lovely day for a walk, isn't it?" },
	{ Id = "Walker3", Name = "Omar", Role = "Postman", Icon = "📬", Looks = { Skin = SKIN[4], Shirt = "#E63946", Pants = "#1D3557", HairStyle = "Short", Hat = "Cap", Hair = "#111111" }, Line = "Letters for Oak Street! Nothing for you today, sorry." },
	{ Id = "Walker4", Name = "Grace", Role = "Shopper", Icon = "🛍️", Looks = { Skin = SKIN[5], Shirt = "#CDB4DB", Pants = "#6D597A", Hair = "#2B2B2B", HairStyle = "Bun" }, Line = "The boutique has a sale on! Don't tell anyone." },
	{ Id = "Walker5", Name = "Leo", Role = "Student", Icon = "📚", Looks = { Skin = SKIN[2], Shirt = "#3A86FF", Pants = "#8338EC", Hair = "#5A3825", HairStyle = "Short" }, Line = "Late for class again..." },
	{ Id = "Walker6", Name = "Ruth", Role = "Retired teacher", Icon = "🌸", Looks = { Skin = SKIN[6], Shirt = "#B5838D", Pants = "#6D6875", Hair = "#FFFFFF", HairStyle = "Bun" }, Line = "I taught half this town to read, you know." },
}

NPCs.ById = {}
for _, npc in ipairs(NPCs.List) do
	NPCs.ById[npc.Id] = npc
end
for _, npc in ipairs(NPCs.Walkers) do
	NPCs.ById[npc.Id] = npc
end

local STAGE_KEYS = { "Childhood", "Teen", "YoungAdult", "Adult", "MiddleAge", "Retirement" }

-- The line an NPC greets this life with.
function NPCs.LineFor(npc, life): string
	if npc.Line then
		return npc.Line
	end
	local lines = npc.Lines or {}
	if life and lines.Career and life.Career and lines.Career[life.Career.Id] then
		return lines.Career[life.Career.Id]
	end
	local stageKey = life and STAGE_KEYS[life.Stage or 1]
	return (stageKey and lines[stageKey]) or lines.Default or "Hello!"
end

function NPCs.OptionVisible(option, age: number): boolean
	if option.MinAge and age < option.MinAge then
		return false
	end
	if option.MaxAge and age > option.MaxAge then
		return false
	end
	return true
end

return NPCs
