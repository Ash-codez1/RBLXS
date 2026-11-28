--[[
	Harbour  (ServerScriptService.Server.World.Districts.Harbour)
	Harbour & Hilltop (opens in the Teenage Years), on the bay in the
	south-east of the island:
	  north-west  the harbour square: travel agent and ice-cream kiosk
	  north-east  Hilltop: a raised plateau with Hilltop Mansion and its pool
	  south-west  Lifeville Beach: umbrellas, towels, lifeguard tower
	  south-east  the bay (sea): the pier, moored boats and the lighthouse
	This district builds its own ground (part of it is water).
]]

return function(B, ctx)
	local f = ctx.Folder
	local d = ctx.District
	local function slab(name, x, z, sx, sz, top, colour, material)
		B.Slab(f, name, d.X + x, d.Z + z, sx, sz, top, colour, material, 0.3)
	end
	slab("HarbourSquare", -39, -39, 58, 58, 0.16, "#D9CBB0", Enum.Material.Pavement)
	slab("HilltopGrounds", 29, -39, 78, 58, 0.1, "#7FBF6A", Enum.Material.Grass)
	slab("Beach", -39, 29, 58, 78, 0.12, B.Palette.Sand, Enum.Material.Sand)

	-- ===== Hilltop =====
	local hilltop = 10.1
	B.Block(f, "Plateau", ctx.At(37, -38, 0, 0.1), 62, hilltop - 0.4, 48, "#8D7B68", Enum.Material.Slate)
	B.Block(f, "PlateauGrass", ctx.At(37, -38, 0, hilltop - 0.3), 62, 0.3, 48, "#6FBF5A", Enum.Material.Grass)
	B.Part(f, { Name = "Ramp", Class = "WedgePart", Size = Vector3.new(12, hilltop - 0.1, 30), CFrame = ctx.At(-9, -38, 90, (hilltop + 0.1) / 2), Color = "#8D7B68", Material = Enum.Material.Slate })
	for _, z in ipairs({ -45, -31 }) do
		B.Block(f, "GatePost", ctx.At(7, z, 0, hilltop), 1.4, 6, 1.4, "#F8F9FA", Enum.Material.Marble)
	end
	local mansion, mIn = B.Building(f, {
		Name = "Hilltop Mansion", CFrame = ctx.At(40, -38, 90, hilltop), Width = 34, Depth = 24, Height = 20, Floors = 2,
		Wall = "#FFF8E7", WallMaterial = Enum.Material.Marble, Roof = "#2B2D42", Floor = "#F3E9D2", FloorMaterial = Enum.Material.Marble,
		DoorWidth = 8, DoorHeight = 11, Sign = "HILLTOP MANSION", SignColor = "#2B2D42", SignText = "#FFD60A",
	})
	B.Sofa(mansion, mIn(-8, 0, 7, 0), "#9D0208")
	B.Block(mansion, "Piano", mIn(9, 0, 7), 5, 3.4, 4, "#111111", Enum.Material.SmoothPlastic)
	B.Table(mansion, mIn(0, 0, -3), 10, 4, "#6D4C41")
	B.Ball(mansion, "Chandelier", (mIn(0, 15, 0)).Position, 3, "#FFF3B0", Enum.Material.Neon, { CanCollide = false })
	B.NPC(ctx.NPCs, "Butler", ctx.At(24, -38, 90, hilltop))
	B.Block(f, "PoolRim", ctx.At(60, -38, 0, hilltop), 12, 0.5, 22, "#F8F9FA", Enum.Material.Marble)
	B.Block(f, "PoolWater", ctx.At(60, -38, 0, hilltop + 0.05), 10, 0.5, 20, "#4CC9F0", Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	for _, p in ipairs({ { 14, -58 }, { 64, -58 }, { 14, -18 }, { 64, -17 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], hilltop), 1, "Palm")
	end

	-- ===== Harbour square =====
	local agent, tIn = B.Building(f, {
		Name = "Travel Agent", CFrame = ctx.At(-50, -50, 180), Width = 16, Depth = 12, Height = 10,
		Wall = "#90E0EF", Roof = "#023E8A", Floor = "#CAF0F8", DoorWidth = 6, Sign = "✈️ TRAVEL", SignColor = "#023E8A",
	})
	B.Counter(agent, tIn(0, 0, 2), 8, "#023E8A")
	B.Board(agent, tIn(0, 2, 4.8), 10, 3, "🌍 See the world!", "#0077B6")
	B.Spot(agent, "Harbour_Trip", tIn(0, 0, -1.5))
	B.Block(f, "IceCreamHut", ctx.At(-26, -32), 8, 7, 6, "#FFC8DD", Enum.Material.WoodPlanks)
	B.Part(f, { Name = "Awning", Class = "WedgePart", Size = Vector3.new(9, 1.6, 3), CFrame = ctx.At(-26, -27.6, 180, 7.4), Color = "#FF006E" })
	B.Sign(f, "IceCreamSign", ctx.At(-26, -28.9, 180, 5), 6, 1.6, "🍦 ICE CREAM", "#FF006E")
	B.Spot(f, "Beach_IceCream", ctx.At(-26, -25))
	B.NPC(ctx.NPCs, "IceCream", ctx.At(-20, -26, 180, 0.16))
	for _, p in ipairs({ { -62, -20 }, { -14, -62 }, { -36, -62 }, { -62, -36 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.16), 1, "Palm")
	end
	for _, x in ipairs({ -50, -38 }) do
		B.Bench(f, ctx.At(x, -16, 180, 0.16))
	end
	B.Lamp(f, ctx.Pos(-44, -22, 0.16))
	B.Lamp(f, ctx.Pos(-16, -52, 0.16))

	-- ===== Beach =====
	local umbrellaColours = { "#F72585", "#4CC9F0", "#FFD60A" }
	for i, p in ipairs({ { -50, 10 }, { -42, 40 }, { -56, 58 } }) do
		B.Cylinder(f, "UmbrellaPole", ctx.At(p[1], p[2], 0, 0.12), 0.4, 7, "#F8F9FA", Enum.Material.SmoothPlastic)
		B.Cylinder(f, "Umbrella", ctx.At(p[1], p[2], 0, 6.6), 8, 0.4, umbrellaColours[i], Enum.Material.Fabric, { CanCollide = false })
		B.Block(f, "Towel", ctx.At(p[1] + 4, p[2] + 1, 15, 0.12), 3, 0.05, 6, umbrellaColours[(i % 3) + 1], Enum.Material.Fabric, { CanCollide = false })
	end
	for _, p in ipairs({ { -33, 49 }, { -27, 49 }, { -33, 55 }, { -27, 55 } }) do
		B.Block(f, "TowerLeg", ctx.At(p[1], p[2], 0, 0.12), 0.6, 6, 0.6, "#F8F9FA", Enum.Material.Wood)
	end
	B.Block(f, "TowerDeck", ctx.At(-30, 52, 0, 6.1), 7, 0.5, 7, "#E63946", Enum.Material.Wood)
	B.Block(f, "TowerRoof", ctx.At(-30, 52, 0, 9.5), 7.6, 0.4, 7.6, "#E63946", Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -33, -27 }) do
		B.Block(f, "RoofPost", ctx.At(x, 55, 0, 6.6), 0.4, 2.9, 0.4, "#F8F9FA", Enum.Material.Wood)
	end
	B.Spot(f, "Beach_Swim", ctx.At(-13, 20, 0, 0.12))

	-- ===== Pier, boats and lighthouse =====
	B.Block(f, "PierDeck", ctx.At(19, 40, 0, 1.0), 66, 0.6, 6, B.Palette.Wood, Enum.Material.WoodPlanks)
	B.Part(f, { Name = "PierRamp", Class = "WedgePart", Size = Vector3.new(6, 1.48, 4), CFrame = ctx.At(-16, 40, 90, 0.86), Color = B.Palette.Wood, Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -4, 8, 20, 32, 44 }) do
		for _, z in ipairs({ 37.5, 42.5 }) do
			B.Cylinder(f, "PierPost", ctx.At(x, z, 0, -14), 1, 15, B.Palette.DarkWood, Enum.Material.Wood)
		end
	end
	B.Spot(f, "Pier_Fish", ctx.At(48, 40, 0, 1.6))
	B.Boat(f, ctx.At(12, 49, 90, -1.8), 16, "#E63946")
	B.Boat(f, ctx.At(36, 51, 90, -1.8), 24, "#F8F9FA", true)
	B.NPC(ctx.NPCs, "Captain", ctx.At(-16, 34, -90, 0.12))
	B.Block(f, "LighthouseRock", ctx.At(56, 58, 0, -14), 14, 17, 14, "#6C757D", Enum.Material.Rock)
	for i, colour in ipairs({ "#E63946", "#F8F9FA", "#E63946" }) do
		B.Cylinder(f, "LighthouseBand", ctx.At(56, 58, 0, 3 + (i - 1) * 7), 6 - i * 0.4, 7, colour, Enum.Material.SmoothPlastic)
	end
	local lantern = B.Ball(f, "Lantern", ctx.Pos(56, 58, 25.5), 4, "#FFF3B0", Enum.Material.Neon, { CanCollide = false, Tag = "CYL_Lamp" })
	local beam = Instance.new("PointLight")
	beam.Name = "Light"
	beam.Range = 40
	beam.Brightness = 2
	beam.Enabled = false
	beam.Parent = lantern
	B.Cylinder(f, "LighthouseCap", ctx.At(56, 58, 0, 27.4), 5, 1.2, "#1D3557", Enum.Material.Metal)
	B.PostSign(f, "HarbourSign", ctx.At(-66, -20, 90, 0.16), 12, "⚓ Harbour & Hilltop", "#023E8A")

	-- Memory Stars
	B.Star(f, "Star_Lighthouse", ctx.At(46, 58, 0, -0.4))
	B.Star(f, "Star_Pier", ctx.At(51, 41.5, 0, 1.6))
	B.Star(f, "Star_Pool", ctx.At(60, -51, 0, hilltop))
end
