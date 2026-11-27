--[[
	University  (ServerScriptService.Server.World.Districts.University)
	Lifeville University (opens at Young Adulthood): the lecture hall, the
	campus library, evening classes, the student union and the campus green.
	The main entrance faces south, towards the road into Downtown.
]]

return function(B, ctx)
	local f = ctx.Folder

	-- Main building: lecture hall (left) and library (right)
	local uni, inside = B.Building(f, {
		Name = "Lifeville University", CFrame = ctx.At(0, -20, 180), Width = 60, Depth = 34, Height = 22, Floors = 2,
		Wall = "#E9E4D8", WallMaterial = Enum.Material.Limestone, Roof = "#5E548E", Floor = "#D6CCC2",
		DoorWidth = 12, DoorHeight = 12, Sign = "🎓 LIFEVILLE UNIVERSITY", SignColor = "#5E548E",
	})
	B.Board(uni, inside(-15, 3, 15.8), 18, 7, "Lecture 7: The Meaning of Life 🤔", "#22223B")
	B.Block(uni, "Podium", inside(-15, 0, 11.5), 3, 3.6, 2, "#6D4C41", Enum.Material.Wood)
	for _, z in ipairs({ 5, 1, -3 }) do
		for _, x in ipairs({ -25, -20, -15, -10, -5 }) do
			B.Chair(uni, inside(x, 0, z, 180), "#5E548E")
		end
	end
	B.Spot(uni, "Uni_Lecture", inside(-15, 0, -7))
	B.NPC(ctx.NPCs, "Professor", inside(-11, 0, 12))

	for _, z in ipairs({ -10, -3, 4, 11 }) do
		B.Shelf(uni, inside(28, 0, z, 90), 6)
	end
	for _, z in ipairs({ -4, 6 }) do
		B.Table(uni, inside(14, 0, z), 8, 4)
		B.Chair(uni, inside(11, 0, z - 3, 180), "#2A9D8F")
		B.Chair(uni, inside(17, 0, z + 3, 0), "#2A9D8F")
	end
	B.Spot(uni, "Uni_Library", inside(14, 0, 1))
	B.Board(uni, inside(20, 0, -13.5, 180), 7, 4, "🌙 Evening Classes\nFrom age 19", "#3C2A4D")
	B.Spot(uni, "Uni_Evening", inside(20, 0, -11))

	-- Student union (east side, facing east)
	local union, uInside = B.Building(f, {
		Name = "Student Union", CFrame = ctx.At(44, 34, -90), Width = 26, Depth = 20, Height = 12,
		Wall = "#FFB4A2", Roof = "#6D597A", Floor = "#E5989B", DoorWidth = 8, Sign = "🎭 STUDENT UNION", SignColor = "#6D597A",
	})
	B.Sofa(union, uInside(-6, 0, 6, 0), "#6D597A")
	B.Table(union, uInside(-6, 0, 1), 5, 3)
	B.Board(union, uInside(6, 2, 8.8), 8, 5, "SOCIETIES:\nDrama · Chess · Coding · Football", "#6D597A")
	B.Spot(union, "Uni_Society", uInside(6, 0, 3))
	B.NPC(ctx.NPCs, "Student", uInside(2, 0, 5))

	-- Campus green: path, statue, trees, benches, lamps
	B.Slab(f, "CampusPath", ctx.Pos(0, 32).X, ctx.Pos(0, 32).Z, 10, 70, 0.16, "#C9C3B6", Enum.Material.Pavement, 0.1)
	B.Block(f, "StatuePlinth", ctx.At(-24, 30), 4, 3, 4, "#ADB5BD", Enum.Material.Marble)
	B.Block(f, "Statue", ctx.At(-24, 30, 0, 3), 1.6, 6, 1.6, "#B08D57", Enum.Material.Metal)
	B.Ball(f, "StatueHead", ctx.Pos(-24, 30, 10), 2, "#B08D57", Enum.Material.Metal)
	for _, p in ipairs({ { -50, 10 }, { -50, 40 }, { -40, 60 }, { -20, 58 }, { 20, 58 }, { 60, -50 }, { -60, -56 }, { 60, 8 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 1.1)
	end
	for _, p in ipairs({ { -12, 20 }, { -12, 44 }, { 12, 20 }, { 12, 44 } }) do
		B.Bench(f, ctx.At(p[1], p[2], if p[1] < 0 then -90 else 90, 0.1))
	end
	for _, p in ipairs({ { -7, 10 }, { 7, 10 }, { -7, 52 }, { 7, 52 } }) do
		B.Lamp(f, ctx.Pos(p[1], p[2], 0.16))
	end
	B.PostSign(f, "UniSign", ctx.At(0, 64, 180), 14, "🎓 Lifeville University", "#5E548E")
end
