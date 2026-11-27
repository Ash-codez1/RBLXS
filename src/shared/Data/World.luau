--[[
	World  (ReplicatedStorage.Shared.Data.World)
	The town of Lifeville: districts, what unlocks when, workplaces for every
	career, Life Reveal showcase shots and the day/night clock. Shared by the
	server (WorldService builds and validates) and the client (explore mode,
	map, gates, ambience).

	Layout: a 3×3 grid of districts (136×136 studs each, 160 studs apart)
	with roads in the gaps and a ring road around the edge. North is -Z.

	           x = -160          x = 0             x = 160
	 z = -160  University 🎓     Downtown 🏙️       Career Row 💼
	 z =    0  Maple School 🏫   Lifeville Plaza ⛲ St. Hope Hospital 🏥
	 z =  160  Willow Park 🌳    Oak Street 🏡     Harbour & Hilltop ⚓
]]

local LifeStages = require(script.Parent.LifeStages)

local World = {}

World.TownName = "Lifeville"
World.CellSize = 136
World.CellPitch = 160
World.RoadWidth = 24
World.RingRoad = 240 -- centre line of the ring road (|x| or |z|)
World.GroundSize = 720

-- UnlockStage: the life stage (1 Childhood … 6 Retirement) that opens a district.
World.Districts = {
	{ Id = "Plaza", Name = "Lifeville Plaza", Icon = "⛲", X = 0, Z = 0, UnlockStage = 1, Ambient = "AmbientPlaza", Map = "#E9C46A", Blurb = "The heart of town: the Hall of Lives, the wishing fountain and the mayor." },
	{ Id = "School", Name = "Maple School", Icon = "🏫", X = -160, Z = 0, UnlockStage = 1, Ambient = "AmbientSchool", Map = "#F4A261", Blurb = "Classrooms, the library, the playground and the sports field." },
	{ Id = "Park", Name = "Willow Park", Icon = "🌳", X = -160, Z = 160, UnlockStage = 1, Ambient = "AmbientPark", Map = "#7BC47F", Blurb = "Jogging track, duck pond, outdoor gym, the arena and the Sunset Club." },
	{ Id = "Residential", Name = "Oak Street", Icon = "🏡", X = 0, Z = 160, UnlockStage = 1, Ambient = "AmbientResidential", Map = "#B5E48C", Blurb = "Family homes, including yours, and the Oak Street apartments." },
	{ Id = "Hospital", Name = "St. Hope Hospital", Icon = "🏥", X = 160, Z = 0, UnlockStage = 1, Ambient = "AmbientHospital", Map = "#90E0EF", Blurb = "Check-ups, volunteering, and the workplace of doctors." },
	{ Id = "Downtown", Name = "Downtown", Icon = "🏙️", X = 0, Z = -160, UnlockStage = 2, Ambient = "AmbientCity", Map = "#ADB5BD", Blurb = "Offices, the bank, the café, the Golden Fork restaurant, the boutique and the arcade." },
	{ Id = "Harbour", Name = "Harbour & Hilltop", Icon = "⚓", X = 160, Z = 160, UnlockStage = 2, Ambient = "AmbientHarbour", Map = "#48CAE4", Coastal = true, Blurb = "The beach, the pier, the lighthouse, and the mansion on the hill." },
	{ Id = "University", Name = "Lifeville University", Icon = "🎓", X = -160, Z = -160, UnlockStage = 3, Ambient = "AmbientSchool", Map = "#CDB4DB", Blurb = "Lectures, the campus library and evening classes." },
	{ Id = "CareerRow", Name = "Career Row", Icon = "💼", X = 160, Z = -160, UnlockStage = 3, Ambient = "AmbientCity", Map = "#FFB4A2", Blurb = "The police station, Starlight Studios, the science lab, the courthouse, the workshop and the town hall." },
}

World.ById = {}
for _, district in ipairs(World.Districts) do
	World.ById[district.Id] = district
end

-- Building-level locks inside open districts (the builder places their doors).
World.Locks = {
	SunsetClub = { Name = "Sunset Club", District = "Park", UnlockStage = 6 },
}

World.StageNames = {}
World.StageAges = {}
for _, stage in ipairs(LifeStages.List) do
	World.StageNames[stage.Id] = stage.DisplayName
	World.StageAges[stage.Id] = stage.MinAge
end

function World.UnlockText(stage: number): string
	return ("Opens in %s (age %d)"):format(World.StageNames[stage] or "a later stage", World.StageAges[stage] or 0)
end

-- Players without an active life explore as if in Childhood.
function World.StageOf(life): number
	if type(life) ~= "table" or life.Completed then
		return 1
	end
	return life.Stage or 1
end

function World.IsUnlocked(districtId: string, stage: number): boolean
	local district = World.ById[districtId]
	return district ~= nil and stage >= district.UnlockStage
end

function World.IsLockOpen(lockId: string, stage: number): boolean
	local lock = World.Locks[lockId] or World.ById[lockId]
	return lock ~= nil and stage >= lock.UnlockStage
end

-- District bounds (min/max X and Z) on the ground plane.
function World.Bounds(districtId: string)
	local d = World.ById[districtId]
	local half = World.CellSize / 2
	return d.X - half, d.Z - half, d.X + half, d.Z + half
end

-- Which district a world position is in (nil on roads and outside town).
function World.DistrictAt(x: number, z: number): string?
	local half = World.CellSize / 2
	for _, d in ipairs(World.Districts) do
		if math.abs(x - d.X) <= half and math.abs(z - d.Z) <= half then
			return d.Id
		end
	end
	return nil
end

--[[
	Workplaces: where each career works. "Work an extra shift" is offered at
	the workplace's spot only to lives in a matching career.
]]
World.Workplaces = {
	Office = { Name = "Lifeville Tower offices", District = "Downtown", Careers = { "Entrepreneur", "Engineer", "RealEstate", "Influencer", "YouTuber" } },
	Hospital = { Name = "St. Hope Hospital", District = "Hospital", Careers = { "Doctor" } },
	School = { Name = "Maple School", District = "School", Careers = { "Teacher" } },
	Restaurant = { Name = "The Golden Fork", District = "Downtown", Careers = { "Chef" } },
	Boutique = { Name = "the Boutique", District = "Downtown", Careers = { "ShopAssistant", "BusinessOwner" } },
	Arcade = { Name = "Starlight Arcade", District = "Downtown", Careers = { "ProGamer" } },
	Studio = { Name = "Starlight Studios", District = "CareerRow", Careers = { "Singer", "Actor", "Musician", "Artist" } },
	Lab = { Name = "the Science Lab", District = "CareerRow", Careers = { "Scientist", "Astronaut" } },
	Court = { Name = "the Courthouse", District = "CareerRow", Careers = { "Lawyer" } },
	Police = { Name = "the Police Station", District = "CareerRow", Careers = { "PoliceOfficer" } },
	Workshop = { Name = "the Workshop", District = "CareerRow", Careers = { "Tradesperson" } },
	Arena = { Name = "Willow Arena", District = "Park", Careers = { "Athlete" } },
}

World.WorkplaceOf = {}
for workplaceId, info in pairs(World.Workplaces) do
	for _, career in ipairs(info.Careers) do
		World.WorkplaceOf[career] = workplaceId
	end
end

--[[
	Life Reveal showcase shots: for each future archetype, the camera glides
	from From to To while looking at Focus (offsets from the district centre).
]]
World.Showcase = {
	Luxury = { District = "Harbour", From = { -30, 40, 10 }, To = { 0, 32, -6 }, Focus = { 40, 18, -38 }, Place = "Hilltop Mansion" },
	Family = { District = "Residential", From = { -60, 26, 10 }, To = { 20, 22, 8 }, Focus = { -10, 6, -30 }, Place = "Oak Street" },
	Fame = { District = "CareerRow", From = { -34, 18, 6 }, To = { 0, 14, 4 }, Focus = { 0, 12, -36 }, Place = "Starlight Studios" },
	Career = { District = "Downtown", From = { 20, 12, 30 }, To = { 14, 30, 10 }, Focus = { 0, 40, -46 }, Place = "Lifeville Tower" },
	Genius = { District = "CareerRow", From = { 64, 18, 10 }, To = { 30, 14, 6 }, Focus = { 44, 10, -36 }, Place = "The Science Lab" },
	Health = { District = "Park", From = { 40, 16, -40 }, To = { 44, 12, 30 }, Focus = { 61, 2, 0 }, Place = "The Willow Park track" },
	Hero = { District = "CareerRow", From = { 20, 14, -4 }, To = { 60, 16, -4 }, Focus = { 44, 16, 30 }, Place = "The Town Hall" },
	Content = { District = "Park", From = { -60, 16, 60 }, To = { -6, 12, 56 }, Focus = { -30, 2, 28 }, Place = "The duck pond" },
	Adventure = { District = "Harbour", From = { -30, 16, 60 }, To = { -6, 12, 60 }, Focus = { 50, 10, 50 }, Place = "The harbour and the lighthouse" },
	Difficult = { District = "Residential", From = { 64, 10, 4 }, To = { 44, 8, 6 }, Focus = { 54, 4, 21 }, Place = "A rainy bus stop" },
	Lonely = { District = "Park", From = { 4, 8, 54 }, To = { -2, 6, 50 }, Focus = { -12, 2, 40 }, Place = "A bench by the pond" },
}

function World.ShowcaseShot(archetype: string)
	local shot = World.Showcase[archetype]
	if not shot then
		return nil
	end
	local d = World.ById[shot.District]
	local function abs(offset)
		return { d.X + offset[1], offset[2], d.Z + offset[3] }
	end
	return { From = abs(shot.From), To = abs(shot.To), Focus = abs(shot.Focus), Place = shot.Place, District = shot.District }
end

-- ===== Day and night =====
World.DayLengthSeconds = 720 -- one full day every 12 minutes
World.DawnHour = 6.25
World.DuskHour = 18.5

-- The clock is derived from server time, so every player sees the same sky.
function World.ClockTimeAt(serverTime: number): number
	local fraction = (serverTime % World.DayLengthSeconds) / World.DayLengthSeconds
	return (fraction * 24 + 9) % 24 -- one global cycle; +9 is just where it begins
end

function World.IsNight(clockTime: number): boolean
	return clockTime >= World.DuskHour or clockTime < World.DawnHour
end

-- Paths the walking townsfolk follow: district-local (x, z) corners of clear
-- loops (checked against the layout), and walking speed.
World.WalkLoops = {
	{ Walker = "Walker1", District = "Park", Speed = 11, Points = { { 61, -61 }, { 61, 61 }, { -61, 61 }, { -61, -61 } } },
	{ Walker = "Walker2", District = "Plaza", Speed = 6, Points = { { -44, -24 }, { 44, -24 }, { 44, 40 }, { -44, 40 } } },
	{ Walker = "Walker3", District = "Residential", Speed = 7, Points = { { -60, -4 }, { 60, -4 }, { 60, 4 }, { -60, 4 } } },
	{ Walker = "Walker4", District = "Downtown", Speed = 6, Points = { { -4, -24 }, { -4, 60 }, { 4, 60 }, { 4, -24 } } },
	{ Walker = "Walker5", District = "Plaza", Speed = 7, Points = { { 44, 40 }, { -44, 40 }, { -44, -24 }, { 44, -24 } } },
	{ Walker = "Walker6", District = "Hospital", Speed = 5, Points = { { -30, -56 }, { -30, 30 }, { -20, 30 }, { -20, -56 } } },
}

-- Car loops for client-side traffic: lane centres (absolute X, Z), driving on
-- the right, clockwise round blocks of the road grid.
World.TrafficLoops = {
	{ { -234, -234 }, { -86, -234 }, { -86, 234 }, { -234, 234 } },
	{ { -74, -234 }, { 74, -234 }, { 74, 74 }, { -74, 74 } },
	{ { 86, -234 }, { 234, -234 }, { 234, 74 }, { 86, 74 } },
	{ { -74, 86 }, { 74, 86 }, { 74, 234 }, { -74, 234 } },
}

return World
