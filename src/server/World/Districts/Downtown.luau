--[[
	Downtown  (ServerScriptService.Server.World.Districts.Downtown)
	Opens in the Teenage Years. A pedestrian high street with Lifeville Tower
	(offices, reception, careers fair) at the north end, the bank, the Golden
	Fork restaurant and the café on the west side, and Starlight Cinema &
	Arcade and the boutique on the east side.
]]

return function(B, ctx)
	local f = ctx.Folder

	-- High street paving
	B.Slab(f, "HighStreet", ctx.Pos(0, 4).X, ctx.Pos(0, 4).Z, 18, 128, 0.16, "#CFC6B8", Enum.Material.Pavement, 0.1)

	-- Lifeville Tower (north end, facing south)
	local tower, tIn = B.Building(f, {
		Name = "Lifeville Tower", CFrame = ctx.At(0, -46, 180), Width = 36, Depth = 30, Height = 64, Floors = 6,
		Wall = "#6C8EAD", WallMaterial = Enum.Material.Glass, Roof = "#2B2D42", Floor = "#E5E5E5", FloorMaterial = Enum.Material.Marble,
		DoorWidth = 10, DoorHeight = 10, Sign = "LIFEVILLE TOWER", SignColor = "#2B2D42",
	})
	B.Counter(tower, tIn(0, 0, 2), 10, "#2B2D42")
	B.NPC(ctx.NPCs, "Receptionist", tIn(0, 0, 4.5))
	for _, x in ipairs({ -12, -4, 4, 12 }) do
		B.Desk(tower, tIn(x, 0, 10), 5)
		B.Chair(tower, tIn(x, 0, 12.4, 0), "#2B2D42")
		B.Block(tower, "Monitor", tIn(x, 2.9, 9.8), 2.4, 1.6, 0.2, "#111111", Enum.Material.Neon, { CanCollide = false })
	end
	B.Spot(tower, "Office_Shift", tIn(-8, 0, 7))
	B.Table(tower, tIn(12, 0, -8), 6, 3, "#E63946")
	B.Board(tower, tIn(12, 3, -4.6), 8, 3, "🧑‍💼 CAREERS FAIR", "#E63946")
	B.Spot(tower, "Office_Fair", tIn(12, 0, -11.5))
	B.Plant(tower, tIn(-15, 0, -12))

	-- West side (facing east): bank, restaurant, café
	local bank, bIn = B.Building(f, {
		Name = "Lifeville Bank", CFrame = ctx.At(-30, -16, -90), Width = 24, Depth = 22, Height = 16,
		Wall = "#E9ECEF", WallMaterial = Enum.Material.Marble, Roof = "#14213D", Floor = "#F8F9FA", FloorMaterial = Enum.Material.Marble,
		Sign = "🏦 LIFEVILLE BANK", SignColor = "#14213D",
	})
	B.Counter(bank, bIn(0, 0, 3), 12, "#14213D")
	B.NPC(ctx.NPCs, "Banker", bIn(0, 0, 5.5))
	B.Spot(bank, "Bank_Open", bIn(0, 0, 0))
	B.Block(bank, "Vault", bIn(0, 0, 8.6), 6, 7, 1, "#ADB5BD", Enum.Material.DiamondPlate)

	local rest, rIn = B.Building(f, {
		Name = "The Golden Fork", CFrame = ctx.At(-30, 14, -90), Width = 28, Depth = 24, Height = 14,
		Wall = "#BC4749", WallMaterial = Enum.Material.Brick, Roof = "#386641", Floor = "#6F4E37", FloorMaterial = Enum.Material.WoodPlanks,
		Sign = "🍝 THE GOLDEN FORK", SignColor = "#386641",
	})
	for _, p in ipairs({ { -8, -3 }, { 0, -3 }, { 8, -3 } }) do
		B.Table(rest, rIn(p[1], 0, p[2]), 4, 4, "#FFFFFF")
		B.Chair(rest, rIn(p[1], 0, p[2] - 3, 180), "#BC4749")
		B.Chair(rest, rIn(p[1], 0, p[2] + 3, 0), "#BC4749")
	end
	B.Spot(rest, "Restaurant_Eat", rIn(-4, 0, -6))
	B.Table(rest, rIn(-7, 0, 6), 9, 4, "#FFF3B0")
	B.Spot(rest, "Restaurant_Treat", rIn(-7, 0, 3))
	B.Counter(rest, rIn(7, 0, 9), 10, "#ADB5BD")
	B.Spot(rest, "Restaurant_Shift", rIn(7, 0, 6))
	B.NPC(ctx.NPCs, "Waiter", rIn(1, 0, 3))

	local cafe, cIn = B.Building(f, {
		Name = "Lifeville Café", CFrame = ctx.At(-30, 44, -90), Width = 22, Depth = 22, Height = 12,
		Wall = "#DDA15E", WallMaterial = Enum.Material.WoodPlanks, Roof = "#606C38", Floor = "#BC6C25", FloorMaterial = Enum.Material.WoodPlanks,
		Sign = "☕ CAFÉ", SignColor = "#606C38",
	})
	B.Counter(cafe, cIn(0, 0, 6), 10, "#283618")
	B.NPC(ctx.NPCs, "Barista", cIn(0, 0, 8.5))
	for _, x in ipairs({ -6, 6 }) do
		B.Table(cafe, cIn(x, 0, -3), 3, 3)
		B.Chair(cafe, cIn(x - 2.4, 0, -3, -90), "#606C38")
		B.Chair(cafe, cIn(x + 2.4, 0, -3, 90), "#606C38")
	end
	B.Spot(cafe, "Cafe_Chat", cIn(0, 0, 1))

	-- East side (facing west): cinema & arcade, boutique
	local cinema, aIn = B.Building(f, {
		Name = "Starlight Cinema & Arcade", CFrame = ctx.At(32, -10, 90), Width = 34, Depth = 26, Height = 18,
		Wall = "#3A0CA3", Roof = "#240046", Floor = "#10002B", FloorMaterial = Enum.Material.Carpet,
		Sign = "🎬 STARLIGHT CINEMA & ARCADE", SignColor = "#7209B7",
	})
	B.Board(cinema, aIn(-6, 3, 11.8), 18, 8, "NOW SHOWING:\nThe Life You Chose", "#111111", "#FFD60A")
	for _, z in ipairs({ 2, 6 }) do
		for _, x in ipairs({ -12, -8, -4, 0 }) do
			B.Chair(cinema, aIn(x, 0, z, 180), "#9D0208")
		end
	end
	B.Spot(cinema, "Cinema_Watch", aIn(-6, 0, -2))
	for i, z in ipairs({ -8, -3, 2, 7 }) do
		local machine = B.Block(cinema, "ArcadeMachine", aIn(14, 0, z, 90), 3, 6, 2.4, "#111111", Enum.Material.SmoothPlastic)
		B.Part(cinema, { Name = "ArcadeScreen", Size = Vector3.new(2.4, 1.8, 0.2), CFrame = aIn(12.7, 4.4, z, 90), Color = ({ "#F72585", "#4CC9F0", "#FFD60A", "#80FFDB" })[i], Material = Enum.Material.Neon, CanCollide = false })
		machine:SetAttribute("Arcade", true)
	end
	B.Spot(cinema, "Arcade_Play", aIn(10, 0, -1))
	B.Block(cinema, "EsportsStage", aIn(8, 0, 9), 8, 1, 5, "#7209B7", Enum.Material.Neon)
	B.Spot(cinema, "Arcade_Shift", aIn(8, 1, 6))
	B.NPC(ctx.NPCs, "Usher", aIn(2, 0, -8))

	local boutique, sIn = B.Building(f, {
		Name = "The Boutique", CFrame = ctx.At(30, 28, 90), Width = 24, Depth = 22, Height = 14,
		Wall = "#FFAFCC", Roof = "#CDB4DB", Floor = "#FFF0F3", FloorMaterial = Enum.Material.Marble,
		Sign = "🛍️ THE BOUTIQUE", SignColor = "#B5179E",
	})
	for i, x in ipairs({ -7, 0, 7 }) do
		B.Block(boutique, "Rail", sIn(x, 0, 4), 5, 5, 0.4, "#ADB5BD", Enum.Material.Metal, { CanCollide = false })
		B.Block(boutique, "Clothes", sIn(x, 1.6, 4), 4.4, 2.6, 1.2, ({ "#F72585", "#4361EE", "#FFBE0B" })[i], Enum.Material.Fabric, { CanCollide = false })
	end
	B.Counter(boutique, sIn(-6, 0, -4), 6, "#B5179E")
	B.Spot(boutique, "Boutique_Shop", sIn(-6, 0, -7))
	B.Spot(boutique, "Boutique_Shift", sIn(6, 0, -3))
	B.NPC(ctx.NPCs, "Stylist", sIn(-6, 0, -1.6))

	-- Street furniture
	for _, z in ipairs({ -20, 0, 20, 40, 58 }) do
		B.Lamp(f, ctx.Pos(-10, z, 0.16))
		B.Lamp(f, ctx.Pos(10, z + 10, 0.16))
	end
	for _, z in ipairs({ -6, 30 }) do
		B.Bench(f, ctx.At(-6, z, -90, 0.16))
		B.Bench(f, ctx.At(6, z + 8, 90, 0.16))
	end
	for _, p in ipairs({ { -56, -56 }, { 56, -56 }, { -58, 62 }, { 58, 62 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 1)
	end
	B.Block(f, "ShelterBack", ctx.At(-12, 60.8), 8, 7, 0.4, "#BFE3F7", Enum.Material.Glass, { Transparency = 0.3 })
	B.Block(f, "ShelterRoof", ctx.At(-12, 62.2, 0, 7), 8.4, 0.4, 3.6, "#ADB5BD", Enum.Material.Metal)
	B.Bench(f, ctx.At(-12, 62.4, 180, 0.1))
	B.PostSign(f, "DowntownSign", ctx.At(0, 66, 180), 12, "🏙️ Downtown", "#2B2D42")
end
