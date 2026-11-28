--[[
	Residential  (ServerScriptService.Server.World.Districts.Residential)
	Oak Street: eight house plots (PlotService builds a home on each plot for
	a player in this server), the Oak Street Apartments, a bus stop, street
	lamps and back-garden hedges.

	Plot models live in World.Plots: Plot1..Plot8, each with a Base part
	(the lawn) whose CFrame faces the street, and a NameSign board.
]]

return function(B, ctx)
	local f = ctx.Folder
	local d = ctx.District

	-- Oak Street and pavements
	B.Slab(f, "OakStreet", d.X - 2, d.Z, 132, 16, 0.2, B.Palette.Asphalt, Enum.Material.Asphalt, 0.3)
	B.Slab(f, "PavementN", d.X - 2, d.Z - 10, 132, 4, 0.24, B.Palette.Pavement, Enum.Material.Pavement, 0.3)
	B.Slab(f, "PavementS", d.X - 2, d.Z + 10, 132, 4, 0.24, B.Palette.Pavement, Enum.Material.Pavement, 0.3)
	B.PostSign(f, "StreetSign", ctx.At(-64, -14, 90), 9, "🏡 Oak Street", "#386641")

	-- Eight plots: four on each side, facing the street
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, x in ipairs({ -50, -24, 2, 28 }) do
			index += 1
			local yaw = if side < 0 then 180 else 0
			local plot = B.Model(ctx.Plots, "Plot" .. index)
			plot:SetAttribute("Index", index)
			local base = B.Block(plot, "Base", ctx.At(x, side * 30, yaw, 0.12), 24, 0.1, 30, "#6FBF5A", Enum.Material.Grass)
			base.CFrame = ctx.At(x, side * 30, yaw, 0.17)
			plot.PrimaryPart = base
			local sign = B.PostSign(plot, "NameSign", ctx.At(x + 9, side * 13.5, yaw, 0.24), 6, "🏡 For sale", "#386641")
			sign:SetAttribute("PlotSign", true)
			B.Hedge(f, ctx.At(x, side * 46, 0, 0.1), 24, 1.6, 3)
		end
	end

	-- Oak Street Apartments (north-east, facing the street)
	local flats, aIn = B.Building(f, {
		Name = "Oak Street Apartments", CFrame = ctx.At(55, -32, 180), Width = 24, Depth = 28, Height = 30, Floors = 4,
		Wall = "#B5838D", WallMaterial = Enum.Material.Brick, Roof = "#6D6875", Floor = "#E5E5E5",
		DoorWidth = 7, Sign = "🏢 APARTMENTS", SignColor = "#6D6875",
	})
	B.Block(flats, "Mailboxes", aIn(-9, 0, 4, 90), 6, 5, 1.2, "#ADB5BD", Enum.Material.Metal)
	B.Sofa(flats, aIn(5, 0, 6, 0), "#6D6875")
	B.Plant(flats, aIn(9, 0, -10))
	B.Part(flats, { Name = "Stairs", Class = "WedgePart", Size = Vector3.new(6, 9, 10), CFrame = aIn(-3, 4.5, 8), Color = "#ADB5BD" })
	B.Spot(flats, "Flats_Neighbours", aIn(0, 0, 0))

	-- Bus stop (south-east corner)
	B.Block(f, "ShelterBack", ctx.At(54, 22.2), 8, 7, 0.4, "#BFE3F7", Enum.Material.Glass, { Transparency = 0.3 })
	B.Block(f, "ShelterRoof", ctx.At(54, 20.8, 0, 7), 8.4, 0.4, 3.6, "#ADB5BD", Enum.Material.Metal)
	B.Bench(f, ctx.At(54, 20.4, 0, 0.1))
	B.PostSign(f, "BusSign", ctx.At(60, 16, 0, 0.1), 4, "🚌 Bus", "#1D3557")

	-- Street lamps, trees and the neighbour
	for _, x in ipairs({ -56, -30, -4, 22, 48 }) do
		B.Lamp(f, ctx.Pos(x, -13, 0.24))
	end
	for _, x in ipairs({ -62, -36, -10, 16, 44 }) do
		B.Lamp(f, ctx.Pos(x, 13, 0.24))
	end
	for _, p in ipairs({ { -64, 56 }, { -36, 58 }, { -10, 58 }, { 16, 58 }, { 48, 58 }, { -64, -56 }, { -36, -58 }, { -10, -58 }, { 16, -58 }, { 64, 58 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 1)
	end
	B.NPC(ctx.NPCs, "Neighbour", ctx.At(-6, 10, 0, 0.24))

	-- Memory Stars
	B.Star(flats, "Star_Stairs", aIn(-3, 9, 12.5))
	B.Star(f, "Star_Hedge", ctx.At(-60, -50))
end
