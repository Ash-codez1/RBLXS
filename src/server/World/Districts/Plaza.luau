--[[
	Plaza  (ServerScriptService.Server.World.Districts.Plaza)
	Lifeville Plaza: the main spawn area. The wishing fountain, the Hall of
	Lives (the life selection area: one pedestal per save slot), the town map
	notice board, the welcome arch, the mayor and the busker.
	The SpawnLocation (from default.project.json) stands south of the fountain.
]]

return function(B, ctx)
	local f = ctx.Folder
	local d = ctx.District
	B.Slab(f, "Paving", d.X, d.Z, 132, 132, 0.16, "#D9CBB0", Enum.Material.Pavement, 0.1)

	-- Wishing fountain
	B.Fountain(f, ctx.Pos(0, 0, 0.16), 22)
	B.Spot(f, "Plaza_Wish", ctx.At(0, 13))

	-- Hall of Lives (north side, facing the fountain)
	local hall, inside = B.Building(f, {
		Name = "Hall of Lives", CFrame = ctx.At(0, -40, 180), Width = 46, Depth = 26, Height = 20,
		Wall = "#F3E9D2", WallMaterial = Enum.Material.Marble, Roof = "#6A4C93", Floor = "#EDE7F6", FloorMaterial = Enum.Material.Marble,
		DoorWidth = 10, DoorHeight = 11, Sign = "🌟 HALL OF LIVES", SignColor = "#6A4C93",
	})
	local orbColours = { "#FFD166", "#7BDFF2", "#F7AEF8" }
	for i, x in ipairs({ -13, 0, 13 }) do
		local base = inside(x, 0, 5)
		B.Cylinder(hall, "Pedestal", base, 4, 3, "#E0D7C6", Enum.Material.Marble)
		B.Ball(hall, "Orb", (base * CFrame.new(0, 4.4, 0)).Position, 2.6, orbColours[i], Enum.Material.Neon, { CanCollide = false })
		local sign = B.Sign(hall, "SlotSign", inside(x, 7.6, 5), 8, 2.6, "Life " .. i, "#3C2A4D", "#FFFFFF")
		sign.CanCollide = false
		sign:SetAttribute("Slot", "Slot" .. i)
		game:GetService("CollectionService"):AddTag(sign, "CYL_Pedestal")
		B.Spot(hall, "Plaza_Hall", inside(x, 0, 1), 0)
	end
	B.Slab(hall, "Carpet", (inside(0, 0, -6)).Position.X, (inside(0, 0, -6)).Position.Z, 6, 14, 0.62, "#9B2226", Enum.Material.Fabric, 0.05)
	B.Plant(hall, inside(-19, 0, -9))
	B.Plant(hall, inside(19, 0, -9))
	B.NPC(ctx.NPCs, "Keeper", inside(0, 0, -5))

	-- Welcome arch (south entrance)
	for _, x in ipairs({ -15, 15 }) do
		B.Block(f, "ArchPillar", ctx.At(x, 60), 3, 16, 3, "#F3E9D2", Enum.Material.Marble)
	end
	B.Block(f, "ArchBeam", ctx.At(0, 60, 0, 16), 34, 3, 3, "#6A4C93", Enum.Material.SmoothPlastic)
	B.Sign(f, "ArchSignSouth", ctx.At(0, 61.6, 180, 17.5), 30, 2.6, "WELCOME TO LIFEVILLE", "#6A4C93")
	B.Sign(f, "ArchSignNorth", ctx.At(0, 58.4, 0, 17.5), 30, 2.6, "EVERY CHOICE SHAPES YOUR FUTURE", "#6A4C93")

	-- Hall of Fame (LeaderboardService writes the top 5 here)
	for _, x in ipairs({ -36.6, -27.4 }) do
		B.Block(f, "FamePost", ctx.At(x, -24, 0, 0.16), 0.6, 4, 0.6, B.Palette.Black, Enum.Material.Metal)
	end
	local fame = B.Sign(f, "HallOfFame", ctx.At(-32, -24.3, 180, 8.6), 10, 9.4, "🏆 HALL OF FAME\nLoading…", "#3C2A4D", "#FFD60A")
	game:GetService("CollectionService"):AddTag(fame, "CYL_HallOfFame")

	-- Town map notice board
	B.PostSign(f, "NoticeBoard", ctx.At(28, 22, 180), 9, "🗺️ TOWN MAP", "#2A9D8F")
	B.Spot(f, "Plaza_Board", ctx.At(28, 25))

	-- Benches facing the fountain, flowers, trees and lamps
	for _, p in ipairs({ { 17, 17 }, { -17, 17 }, { 17, -17 }, { -17, -17 } }) do
		B.Bench(f, ctx.At(p[1], p[2], B.YawFacing(p[1], p[2], 0, 0), 0.16))
	end
	for _, x in ipairs({ -26, 26 }) do
		B.Flowerbed(f, ctx.At(x, 4, 0, 0.16), 6, 10)
	end
	for _, p in ipairs({ { -54, -54 }, { 54, -54 }, { -54, 54 }, { 54, 54 }, { -60, 8 }, { 60, 8 }, { -36, 46 }, { 36, 46 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.16), 1.1)
	end
	for _, p in ipairs({ { -30, 30 }, { 30, 30 }, { -32, -16 }, { 32, -16 }, { -10, 56 }, { 10, 56 } }) do
		B.Lamp(f, ctx.Pos(p[1], p[2], 0.16))
	end

	-- The busker's little stage and the mayor
	B.Cylinder(f, "BuskerStage", ctx.At(-26, 22, 0, 0.16), 7, 0.6, "#8D6E63", Enum.Material.WoodPlanks)
	B.NPC(ctx.NPCs, "Busker", ctx.At(-26, 22, B.YawFacing(-26, 22, 0, 0), 0.76))
	B.NPC(ctx.NPCs, "Mayor", ctx.At(10, 20, 180, 0.16))

	-- Memory Stars
	B.Star(f, "Star_HallOfLives", ctx.At(0, -57, 0, 0.16))
	B.Star(f, "Star_Arch", ctx.At(19, 60, 0, 0.16))
end
