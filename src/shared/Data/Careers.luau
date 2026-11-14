--[[
	Careers  (ReplicatedStorage.Shared.Data.Careers)
	Every career a life can have. Shared so the client can show titles; only the
	server assigns careers (through choice/event Effects) and pays salaries.

	Each career has 5 levels. Salary at level L = Salary × (1 + 0.3 × (L − 1)).
	Special careers (Astronaut, ProGamer) are only reachable through rare
	branches.
]]

local Careers = {}

Careers.MaxLevel = 5

Careers.Info = {
	Doctor = { Icon = "🩺", Salary = 90000, Category = "Medical", Levels = { "Junior Doctor", "Doctor", "Senior Doctor", "Consultant", "Chief of Medicine" } },
	Lawyer = { Icon = "⚖️", Salary = 80000, Category = "Law", Levels = { "Junior Lawyer", "Associate", "Senior Associate", "Partner", "Senior Partner" } },
	PoliceOfficer = { Icon = "👮", Salary = 38000, Category = "Public Service", Levels = { "Constable", "Sergeant", "Inspector", "Chief Inspector", "Commissioner" } },
	Teacher = { Icon = "🍎", Salary = 36000, Category = "Education", Levels = { "Trainee Teacher", "Teacher", "Head of Department", "Deputy Head", "Headteacher" } },
	Athlete = { Icon = "🏅", Salary = 70000, Category = "Sport", Levels = { "Rookie", "Professional Athlete", "Star Player", "Team Captain", "Sporting Legend" } },
	Singer = { Icon = "🎤", Salary = 45000, Category = "Entertainment", Levels = { "Open-Mic Singer", "Signed Artist", "Chart Star", "Headliner", "Pop Icon" } },
	Actor = { Icon = "🎬", Salary = 40000, Category = "Entertainment", Levels = { "Extra", "Supporting Actor", "Lead Actor", "Film Star", "Screen Legend" } },
	Influencer = { Icon = "📸", Salary = 30000, Category = "Media", Levels = { "Micro-Influencer", "Influencer", "Brand Partner", "Mega-Influencer", "Internet Icon" } },
	YouTuber = { Icon = "▶️", Salary = 28000, Category = "Media", Levels = { "Small Creator", "Rising Creator", "Partnered Creator", "Top Creator", "Platform Legend" } },
	Entrepreneur = { Icon = "🚀", Salary = 45000, Category = "Business", Levels = { "Founder", "Startup CEO", "Scale-up CEO", "Tycoon", "Mogul" } },
	BusinessOwner = { Icon = "🏪", Salary = 42000, Category = "Business", Levels = { "Shop Owner", "Business Owner", "Chain Owner", "Regional Boss", "Business Magnate" } },
	Chef = { Icon = "👨‍🍳", Salary = 32000, Category = "Food", Levels = { "Line Cook", "Chef", "Sous Chef", "Head Chef", "Celebrity Chef" } },
	Engineer = { Icon = "⚙️", Salary = 55000, Category = "Technology", Levels = { "Graduate Engineer", "Engineer", "Senior Engineer", "Lead Engineer", "Chief Engineer" } },
	Scientist = { Icon = "🔬", Salary = 52000, Category = "Science", Levels = { "Research Assistant", "Scientist", "Senior Scientist", "Lab Director", "Renowned Professor" } },
	Musician = { Icon = "🎸", Salary = 30000, Category = "Entertainment", Levels = { "Busker", "Session Musician", "Band Member", "Touring Musician", "Rock Legend" } },
	Artist = { Icon = "🎨", Salary = 26000, Category = "Arts", Levels = { "Struggling Artist", "Exhibiting Artist", "Gallery Artist", "Renowned Artist", "Master Artist" } },
	RealEstate = { Icon = "🏘️", Salary = 50000, Category = "Business", Levels = { "Estate Agent", "Property Investor", "Property Developer", "Property Mogul", "Real Estate Tycoon" } },
	Tradesperson = { Icon = "🔧", Salary = 32000, Category = "Trades", Levels = { "Apprentice", "Electrician", "Senior Electrician", "Contractor", "Firm Owner" } },
	ShopAssistant = { Icon = "🛒", Salary = 22000, Category = "Retail", Levels = { "Shop Assistant", "Supervisor", "Assistant Manager", "Store Manager", "Area Manager" } },
	-- Special careers
	Astronaut = { Icon = "🚀", Salary = 120000, Category = "Special", Special = true, Levels = { "Astronaut Candidate", "Astronaut", "Mission Specialist", "Mission Commander", "Space Legend" } },
	ProGamer = { Icon = "🎮", Salary = 40000, Category = "Special", Special = true, Levels = { "Amateur Pro", "Pro Gamer", "Team Captain", "World Champion", "Esports Legend" } },
}

-- Education levels, lowest to highest.
Careers.Education = { "None", "School", "University", "Masters" }
Careers.EducationRank = { None = 0, School = 1, University = 2, Masters = 3 }
Careers.EducationNames = { None = "None", School = "School Graduate", University = "University Degree", Masters = "Master's Degree" }

function Careers.IsValid(id: any): boolean
	return type(id) == "string" and (id == "None" or Careers.Info[id] ~= nil)
end

function Careers.SalaryAt(id: string, level: number): number
	local info = Careers.Info[id]
	if not info then
		return 0
	end
	return math.floor(info.Salary * (1 + 0.3 * (math.clamp(level, 1, Careers.MaxLevel) - 1)))
end

function Careers.TitleAt(id: string, level: number): string
	local info = Careers.Info[id]
	if not info then
		return "Unemployed"
	end
	return info.Levels[math.clamp(level, 1, Careers.MaxLevel)]
end

return Careers
