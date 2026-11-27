--[[
	Park  (ServerScriptService.Server.World.Districts.Park)
	Willow Park: the running track round the edge, Willow Arena (stands and
	pitch), the duck pond, the playground with swings, the outdoor gym, the
	picnic area and the Sunset Club (opens in Retirement).
]]

return function(B, ctx)
	local f = ctx.Folder
	local d = ctx.District

	-- Running track and paths
	local track = "#C1666B"
	B.Slab(f, "TrackN", d.X, d.Z - 61, 128, 6, 0.16, track, Enum.Material.Fabric, 0.1)
	B.Slab(f, "TrackS", d.X, d.Z + 61, 128, 6, 0.16, track, Enum.Material.Fabric, 0.1)
	B.Slab(f, "TrackW", d.X - 61, d.Z, 6, 116, 0.165, track, Enum.Material.Fabric, 0.1)
	B.Slab(f, "TrackE", d.X + 61, d.Z, 6, 116, 0.165, track, Enum.Material.Fabric, 0.1)
	B.Spot(f, "Park_Run", ctx.At(61, 12))
	B.Slab(f, "PathEW", d.X + 2, d.Z, 116, 6, 0.15, "#D4C5A9", Enum.Material.Pebble, 0.08)
	B.Slab(f, "PathNS", d.X, d.Z + 2, 6, 116, 0.155, "#D4C5A9", Enum.Material.Pebble, 0.08)

	-- Willow Arena (north-west)
	B.Slab(f, "ArenaPitch", ctx.Pos(-32, -34).X, ctx.Pos(-32, -34).Z, 36, 24, 0.16, "#4C9A2A", Enum.Material.Grass, 0.08)
	for i = 1, 3 do
		B.Block(f, "StandNorth", ctx.At(-32, -46 - i * 2.2), 36, 1.2 * i, 2.2, "#ADB5BD", Enum.Material.Concrete)
		B.Block(f, "StandSouth", ctx.At(-32, -22 + i * 2.2), 36, 1.2 * i, 2.2, "#ADB5BD", Enum.Material.Concrete)
	end
	B.Sign(f, "ArenaSign", ctx.At(-32, -53.9, 180, 8), 20, 3, "🏟️ WILLOW ARENA", "#1D3557")
	B.Spot(f, "Arena_Watch", ctx.At(-32, -13))
	B.Spot(f, "Arena_Shift", ctx.At(-40, -34))
	B.Lamp(f, ctx.Pos(-52, -10, 0.1))
	B.Lamp(f, ctx.Pos(-12, -10, 0.1))

	-- Sunset Club (north-east, opens in Retirement)
	local club, cIn = B.Building(f, {
		Name = "Sunset Club", CFrame = ctx.At(34, -36, 180), Width = 30, Depth = 24, Height = 12,
		Wall = "#FFE8D6", WallMaterial = Enum.Material.WoodPlanks, Roof = "#CB997E", Floor = "#DDBEA9",
		DoorWidth = 8, Sign = "🌅 SUNSET CLUB · 61+", SignColor = "#B07D62",
	})
	B.Slab(club, "BowlsGreen", (cIn(-4, 0, 4)).Position.X, (cIn(-4, 0, 4)).Position.Z, 16, 10, 0.62, "#4C9A2A", Enum.Material.Fabric, 0.05)
	for i = 1, 3 do
		B.Ball(club, "Bowl", (cIn(-8 + i * 2.5, 1.1, 6)).Position, 1, "#212529", Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	B.Spot(club, "Club_Bowls", cIn(-4, 0, -3))
	B.Table(club, cIn(9, 0, 6), 4, 4, "#FFFFFF")
	B.Chair(club, cIn(9, 0, 3, 180), "#B07D62")
	B.Chair(club, cIn(9, 0, 9, 0), "#B07D62")
	B.Spot(club, "Club_Tea", cIn(9, 0, 0))
	B.LockWall(ctx.Locks, "SunsetClub", 6, ctx.At(34, -23.4), 9, 10, 1.2)
	B.NPC(ctx.NPCs, "Grandpa", ctx.At(42, -19, 180, 0.1))
	B.Bench(f, ctx.At(26, -18, 180, 0.1))

	-- Duck pond (south-west)
	local pond = ctx.Pos(-30, 28, 0.1)
	B.Cylinder(f, "PondBed", CFrame.new(pond), 28, 0.3, "#4E6E58", Enum.Material.Mud)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		B.Block(f, "PondRim", CFrame.new(pond + Vector3.new(math.cos(a) * 14.6, 0, math.sin(a) * 14.6)) * CFrame.Angles(0, -a, 0), 2, 1.6, 8, B.Palette.Stone, Enum.Material.Slate)
	end
	pcall(function()
		workspace.Terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, 0.9, 0)), 1.2, 13.5, Enum.Material.Water)
	end)
	for i = 1, 4 do
		B.Ball(f, "Duck", pond + Vector3.new(-6 + i * 3, 1.7, ((i * 5) % 7) - 3), 1.1, "#FFD60A", Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	B.Spot(f, "Park_Ducks", ctx.At(-30, 46))
	B.NPC(ctx.NPCs, "Ranger", ctx.At(-40, 47, 0, 0.1))
	B.Bench(f, ctx.At(-12, 40, B.YawFacing(-12, 40, -30, 28), 0.1)) -- the quiet bench by the pond

	-- Playground, outdoor gym and picnic area (south-east)
	B.Slab(f, "SoftGround", ctx.Pos(24, 26).X, ctx.Pos(24, 26).Z, 22, 16, 0.14, "#F4A261", Enum.Material.Fabric, 0.05)
	for _, x in ipairs({ 16, 32 }) do
		B.Block(f, "SwingPost", ctx.At(x, 26), 0.6, 8, 0.6, "#264653", Enum.Material.Metal)
	end
	B.Block(f, "SwingBar", ctx.At(24, 26, 0, 8), 17, 0.6, 0.6, "#264653", Enum.Material.Metal)
	for _, x in ipairs({ 20, 28 }) do
		B.Part(f, { Name = "Swing", Class = "Seat", Size = Vector3.new(2, 0.3, 1.4), CFrame = ctx.At(x, 26, 0, 2.2), Color = "#E76F51", Tag = "CYL_Seat" })
		for _, side in ipairs({ -0.9, 0.9 }) do
			B.Part(f, { Name = "Rope", Size = Vector3.new(0.1, 5.8, 0.1), CFrame = ctx.At(x + side, 26, 0, 5.2), Color = "#ADB5BD", CanCollide = false })
		end
	end
	B.Spot(f, "Park_Swings", ctx.At(24, 20))
	for _, x in ipairs({ 44, 52 }) do
		B.Block(f, "GymPost", ctx.At(x, 26), 0.5, 8, 0.5, "#6C757D", Enum.Material.Metal)
	end
	B.Block(f, "PullUpBar", ctx.At(48, 26, 0, 8), 8.5, 0.4, 0.4, "#6C757D", Enum.Material.Metal)
	B.Block(f, "GymBench", ctx.At(48, 32), 2, 1.6, 5, "#343A40", Enum.Material.SmoothPlastic)
	B.Spot(f, "Park_Gym", ctx.At(48, 20))
	for _, x in ipairs({ 22, 38 }) do
		B.Table(f, ctx.At(x, 50), 6, 3, B.Palette.Wood)
		B.Part(f, { Name = "PicnicSeat", Class = "Seat", Size = Vector3.new(6, 0.4, 1.2), CFrame = ctx.At(x, 47.6, 0, 1.6), Color = B.Palette.Wood, Material = Enum.Material.Wood, Tag = "CYL_Seat" })
		B.Part(f, { Name = "PicnicSeat", Class = "Seat", Size = Vector3.new(6, 0.4, 1.2), CFrame = ctx.At(x, 52.4, 180, 1.6), Color = B.Palette.Wood, Material = Enum.Material.Wood, Tag = "CYL_Seat" })
	end
	B.Spot(f, "Park_Picnic", ctx.At(30, 44))

	-- Trees, lamps, benches, flowers
	for _, p in ipairs({ { -54, 8 }, { -48, 56 }, { -8, 56 }, { -6, 18 }, { -52, 20 }, { 10, -20 }, { 54, -6 }, { 56, 50 }, { 8, 48 }, { -8, -50 }, { 12, -56 }, { 54, -54 } }) do
		B.Tree(f, ctx.Pos(p[1], p[2], 0.1), 1.2, if p[1] % 3 == 0 then "Pine" else nil)
	end
	for _, p in ipairs({ { 6, -30 }, { 6, 30 }, { -30, 6 }, { 30, 6 }, { 6, 52 } }) do
		B.Lamp(f, ctx.Pos(p[1], p[2], 0.1))
	end
	for _, p in ipairs({ { -20, -6, 180 }, { 20, -6, 180 }, { 20, 6, 0 } }) do
		B.Bench(f, ctx.At(p[1], p[2] + (if p[3] == 0 then 1 else -1), p[3], 0.1))
	end
	B.Flowerbed(f, ctx.At(-12, -12), 8, 8)
	B.Flowerbed(f, ctx.At(12, 12), 8, 8)
	B.PostSign(f, "ParkSign", ctx.At(66, 0, -90), 12, "🌳 Willow Park", "#386641")
end
