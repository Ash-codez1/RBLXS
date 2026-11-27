--[[
	School  (ServerScriptService.Server.World.Districts.School)
	Maple School: a classroom (desks you can sit at, the board), the school
	library, the staff room, the playground and the sports field with goals.
	The entrance faces east, towards the Plaza.
]]

return function(B, ctx)
	local f = ctx.Folder

	-- Forecourt and main building
	B.Slab(f, "Forecourt", ctx.Pos(56, -18).X, ctx.Pos(56, -18).Z, 22, 40, 0.16, "#C9C3B6", Enum.Material.Concrete, 0.1)
	local school, inside = B.Building(f, {
		Name = "Maple School", CFrame = ctx.At(30, -18, -90), Width = 50, Depth = 30, Height = 16,
		Wall = "#C8553D", WallMaterial = Enum.Material.Brick, Roof = "#3D405B", Floor = "#E9D8A6",
		DoorWidth = 10, Sign = "🏫 MAPLE SCHOOL", SignColor = "#3D405B",
	})

	-- Classroom (left half): the board, two rows of desks and chairs
	B.Board(school, inside(-13, 2.5, 13.8), 14, 6, "Today: Fractions! ➗", "#2D4739")
	for _, z in ipairs({ 2, -5 }) do
		for _, x in ipairs({ -20, -13, -6 }) do
			B.Desk(school, inside(x, 0, z), 4)
			B.Chair(school, inside(x, 0, z - 2.4, 180), "#E9C46A")
		end
	end
	B.Spot(school, "School_Study", inside(-13, 0, -1))
	B.NPC(ctx.NPCs, "Teacher", inside(-13, 0, 9))

	-- Library (right half)
	for _, z in ipairs({ -8, 0, 8 }) do
		B.Shelf(school, inside(23, 0, z, 90), 6)
	end
	B.Table(school, inside(11, 0, 1), 6, 4)
	B.Chair(school, inside(11, 0, -2, 180), "#2A9D8F")
	B.Chair(school, inside(11, 0, 4, 0), "#2A9D8F")
	B.Counter(school, inside(13, 0, 9), 6)
	B.Spot(school, "School_Library", inside(14, 0, -4))
	B.NPC(ctx.NPCs, "Librarian", inside(13, 0, 11.5))

	-- Staff room corner
	B.Table(school, inside(-20, 0, -10), 4, 4, "#ADB5BD")
	B.Board(school, inside(-20, 3, -13.8, 180), 6, 2, "STAFF ROOM", "#3D405B")
	B.Spot(school, "School_Shift", inside(-17, 0, -10))

	-- Playground (south)
	B.Slab(f, "SoftGround", ctx.Pos(18, 42).X, ctx.Pos(18, 42).Z, 34, 24, 0.14, "#E76F51", Enum.Material.Fabric, 0.06)
	B.Block(f, "SlideTower", ctx.At(8, 42), 4, 6, 4, "#2A9D8F", Enum.Material.SmoothPlastic)
	B.Part(f, { Name = "Slide", Class = "WedgePart", Size = Vector3.new(3, 6, 10), CFrame = ctx.At(8, 49, 180, 3.1), Color = "#E9C46A", Material = Enum.Material.SmoothPlastic })
	for _, x in ipairs({ 22, 30 }) do
		for _, z in ipairs({ 36, 46 }) do
			B.Block(f, "FramePost", ctx.At(x, z), 0.6, 7, 0.6, "#264653", Enum.Material.Metal)
		end
	end
	B.Block(f, "FrameTop", ctx.At(26, 41, 0, 7), 9, 0.6, 11, "#264653", Enum.Material.Metal)
	B.Spot(f, "School_Playground", ctx.At(18, 36))
	B.Bench(f, ctx.At(42, 46, 90))

	-- Sports field (north-west) with goals
	local fieldCentre = ctx.Pos(-30, -30, 0.14)
	B.Slab(f, "Pitch", fieldCentre.X, fieldCentre.Z, 56, 36, 0.14, "#4C9A2A", Enum.Material.Grass, 0.04)
	B.Slab(f, "HalfwayLine", fieldCentre.X, fieldCentre.Z, 0.6, 36, 0.15, "#FFFFFF", Enum.Material.SmoothPlastic, 0.01)
	for _, x in ipairs({ -57, -3 }) do
		local inward = if x < -30 then 1 else -1
		for _, z in ipairs({ -34, -26 }) do
			B.Block(f, "GoalPost", ctx.At(x, z), 0.5, 5, 0.5, "#FFFFFF", Enum.Material.SmoothPlastic)
		end
		B.Block(f, "Crossbar", ctx.At(x, -30, 0, 5), 0.5, 0.5, 8.5, "#FFFFFF", Enum.Material.SmoothPlastic)
		B.Block(f, "Net", ctx.At(x - inward * 1.2, -30), 2, 5, 8, "#FFFFFF", Enum.Material.Fabric, { Transparency = 0.6, CanCollide = false })
	end
	B.Ball(f, "Football", ctx.Pos(-24, -28, 1.2), 1.6, "#FFFFFF", Enum.Material.SmoothPlastic)
	B.Spot(f, "School_Football", ctx.At(-30, -9))
	B.NPC(ctx.NPCs, "Coach", ctx.At(-36, -9, 0))

	-- Trees, benches and lamps
	for _, p in ipairs({ { -60, 10 }, { -60, 30 }, { -60, 52 }, { -40, 60 }, { -20, 60 }, { 60, 30 }, { 60, 60 }, { -62, -62 }, { 0, -62 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 1)
	end
	for _, p in ipairs({ { -20, 10 }, { 0, 10 } }) do
		B.Bench(f, ctx.At(p[1], p[2], 180))
	end
	for _, p in ipairs({ { 62, -40 }, { 62, 4 }, { -10, -52 } }) do
		B.Lamp(f, ctx.Pos(p[1], p[2], 0.1))
	end
	B.PostSign(f, "SchoolSign", ctx.At(64, 20, -90), 12, "🏫 Maple School", "#C8553D")
end
