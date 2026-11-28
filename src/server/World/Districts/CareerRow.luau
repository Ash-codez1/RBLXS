--[[
	CareerRow  (ServerScriptService.Server.World.Districts.CareerRow)
	Opens at Young Adulthood. The workplaces along one street: the police
	station, Starlight Studios & Theatre and the science lab (north side),
	the courthouse, the workshop and the town hall (south side).
]]

return function(B, ctx)
	local f = ctx.Folder
	B.Slab(f, "Street", ctx.Pos(0, 0).X, ctx.Pos(0, 0).Z, 132, 28, 0.16, "#CFC6B8", Enum.Material.Pavement, 0.1)

	-- ===== North side (facing south) =====
	local police, pIn = B.Building(f, {
		Name = "Police Station", CFrame = ctx.At(-44, -36, 180), Width = 34, Depth = 28, Height = 16,
		Wall = "#1D3557", Roof = "#0B132B", Floor = "#ADB5BD", FloorMaterial = Enum.Material.Concrete,
		Sign = "👮 POLICE STATION", SignColor = "#457B9D",
	})
	B.Counter(police, pIn(0, 0, 2), 10, "#1D3557")
	B.NPC(ctx.NPCs, "Officer", pIn(0, 0, 4.5))
	B.Spot(police, "Police_Watch", pIn(0, 0, -1.5))
	for _, x in ipairs({ -14, -11.5, -9 }) do
		B.Block(police, "Locker", pIn(x, 0, 12.1), 2.2, 7, 1.6, "#6C757D", Enum.Material.Metal)
	end
	B.Spot(police, "Police_Shift", pIn(-11.5, 0, 8))
	B.Car(f, ctx.At(-44, -17, -90), "#F8F9FA", "Hatch")

	local studio, sIn = B.Building(f, {
		Name = "Starlight Studios", CFrame = ctx.At(0, -36, 180), Width = 36, Depth = 30, Height = 20,
		Wall = "#240046", Roof = "#10002B", Floor = "#3C096C", FloorMaterial = Enum.Material.Carpet,
		Sign = "⭐ STARLIGHT STUDIOS & THEATRE", SignColor = "#7209B7",
	})
	B.Block(studio, "Stage", sIn(2, 0, 10.5), 22, 2, 7, "#5A189A", Enum.Material.WoodPlanks)
	B.Board(studio, sIn(2, 2, 13.8), 20, 7, "✨ OPEN-MIC NIGHT ✨", "#10002B", "#FFD60A")
	for _, z in ipairs({ -2, 2 }) do
		for _, x in ipairs({ -6, -2, 2, 6, 10 }) do
			B.Chair(studio, sIn(x, 0, z, 180), "#9D0208")
		end
	end
	B.Spot(studio, "Theatre_Watch", sIn(2, 0, -7))
	B.Spot(studio, "Studio_OpenMic", sIn(8, 0, 6))
	B.Block(studio, "RecordingBooth", sIn(-13, 0, 9), 8, 9, 8, "#BFE3F7", Enum.Material.Glass, { Transparency = 0.5, CanCollide = false })
	B.Spot(studio, "Studio_Shift", sIn(-13, 0, 3))
	B.NPC(ctx.NPCs, "Director", sIn(-6, 0, 6))

	local lab, lIn = B.Building(f, {
		Name = "Science Lab", CFrame = ctx.At(44, -36, 180), Width = 34, Depth = 28, Height = 16,
		Wall = "#E0FBFC", Roof = "#3D5A80", Floor = "#F8F9FA", FloorMaterial = Enum.Material.Marble,
		Sign = "🔬 SCIENCE LAB", SignColor = "#3D5A80",
	})
	for _, z in ipairs({ 3, 9 }) do
		B.Counter(lab, lIn(7, 0, z), 12, "#ECEFF1")
		for i = 1, 3 do
			B.Ball(lab, "Flask", (lIn(2 + i * 3, 3.9, z)).Position, 0.9, ({ "#80FFDB", "#F72585", "#FFD60A" })[i], Enum.Material.Neon, { CanCollide = false })
		end
	end
	B.Spot(lab, "Lab_Shift", lIn(7, 0, 0))
	B.NPC(ctx.NPCs, "Scientist", lIn(3, 0, 6))
	B.Cylinder(lab, "RocketBody", lIn(-10, 0, 6), 3, 9, "#F8F9FA", Enum.Material.Metal)
	B.Ball(lab, "RocketTip", (lIn(-10, 9.6, 6)).Position, 3, "#E63946", Enum.Material.SmoothPlastic)
	B.Board(lab, lIn(-10, 1, -2, 0), 8, 3, "🚀 SPACE & SCIENCE EXHIBIT", "#3D5A80")
	B.Spot(lab, "Lab_Exhibit", lIn(-10, 0, -6))

	-- ===== South side (facing north) =====
	local court, cIn = B.Building(f, {
		Name = "Courthouse", CFrame = ctx.At(-44, 36, 0), Width = 34, Depth = 26, Height = 18,
		Wall = "#E9E4D8", WallMaterial = Enum.Material.Limestone, Roof = "#6C757D", Floor = "#6F4E37", FloorMaterial = Enum.Material.WoodPlanks,
		Sign = "⚖️ COURTHOUSE", SignColor = "#6C757D",
	})
	for _, x in ipairs({ -12, -4, 4, 12 }) do
		B.Cylinder(f, "Column", ctx.At(-44 + x, 21.5), 2, 15, "#F8F9FA", Enum.Material.Marble)
	end
	B.Block(court, "JudgesBench", cIn(0, 0, 8.5), 12, 4.5, 2.5, "#4E342E", Enum.Material.Wood)
	B.NPC(ctx.NPCs, "Judge", cIn(0, 0, 10.8))
	for _, z in ipairs({ -6, -2 }) do
		B.Bench(court, cIn(-6, 0, z, 180))
	end
	B.Spot(court, "Court_Watch", cIn(-6, 0, -9))
	B.Table(court, cIn(7, 0, 3), 6, 3, "#6D4C41")
	B.Spot(court, "Court_Shift", cIn(7, 0, -1))

	local shop, wIn = B.Building(f, {
		Name = "Workshop", CFrame = ctx.At(0, 36, 0), Width = 30, Depth = 24, Height = 14,
		Wall = "#6C757D", WallMaterial = Enum.Material.CorrodedMetal, Roof = "#343A40", Floor = "#495057", FloorMaterial = Enum.Material.Concrete,
		Sign = "🔧 WORKSHOP", SignColor = "#F77F00",
	})
	B.Counter(shop, wIn(-6, 0, 6), 10, "#8D6E63")
	B.Block(shop, "Toolboard", wIn(-6, 3, 10.6), 10, 4, 0.3, "#3E2723", Enum.Material.Wood, { CanCollide = false })
	B.Spot(shop, "Workshop_Class", wIn(-6, 0, 2.5))
	B.Block(shop, "Generator", wIn(8, 0, 6), 5, 4, 4, "#F77F00", Enum.Material.Metal)
	B.Spot(shop, "Workshop_Shift", wIn(8, 0, 1))
	B.NPC(ctx.NPCs, "Builder", wIn(0, 0, 4))

	local hall, hIn = B.Building(f, {
		Name = "Town Hall", CFrame = ctx.At(44, 36, 0), Width = 34, Depth = 28, Height = 20,
		Wall = "#F1FAEE", WallMaterial = Enum.Material.Marble, Roof = "#457B9D", Floor = "#E9ECEF", FloorMaterial = Enum.Material.Marble,
		Sign = "🏛️ TOWN HALL", SignColor = "#1D3557",
	})
	B.Block(f, "ClockTower", ctx.At(44, 40, 0, 20.5), 8, 14, 8, "#F1FAEE", Enum.Material.Marble)
	B.Sign(f, "Clock", ctx.At(44, 35.7, 0, 30), 5, 5, "🕰️", "#1D3557")
	B.Counter(hall, hIn(0, 0, 4), 12, "#1D3557")
	B.NPC(ctx.NPCs, "Clerk", hIn(0, 0, 6.5))
	B.Spot(hall, "TownHall_Volunteer", hIn(0, 0, 0))
	for _, x in ipairs({ -12, 12 }) do
		B.Cylinder(hall, "FlagPole", hIn(x, 0, 10), 0.4, 10, "#ADB5BD", Enum.Material.Metal)
		B.Part(hall, { Name = "Flag", Size = Vector3.new(3, 2, 0.1), CFrame = hIn(x + 1.6, 9, 10), Color = "#E63946", CanCollide = false })
	end

	-- Street furniture
	for _, x in ipairs({ -60, -22, 22, 60 }) do
		B.Lamp(f, ctx.Pos(x, -11, 0.16))
		B.Lamp(f, ctx.Pos(x, 11, 0.16))
	end
	for _, x in ipairs({ -22, 22 }) do
		B.Bench(f, ctx.At(x + 6, -10, 180, 0.16))
		B.Bench(f, ctx.At(x - 6, 10, 0, 0.16))
	end
	for _, p in ipairs({ { -64, -64 }, { 64, -64 }, { -64, 64 }, { 64, 64 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 0.9)
	end
	B.PostSign(f, "CareerRowSign", ctx.At(-66, 0, 90), 12, "💼 Career Row", "#F77F00")

	-- Memory Stars
	B.Star(f, "Star_ClockTower", ctx.At(44, 54))
	B.Star(studio, "Star_Booth", sIn(-13, 0, 10))
end
