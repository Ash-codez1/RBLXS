--[[
	Town  (ServerScriptService.Server.World.Town)
	Generates Lifeville into Workspace.World: the island, sea, roads, street
	lamps, trees, every district (World/Districts) and the walls of areas
	that unlock later in life.

	Town.Build(parent) -> worldFolder
	  World
	  ├─ Ground        land, roads, coast
	  ├─ Districts     one Folder per district (buildings, props, spots)
	  ├─ Locks         locked-area walls (CYL_Lock)
	  ├─ NPCAnchors    where NPCService places each character
	  └─ Plots         the 8 house plots on Oak Street (PlotService builds houses)

	Studio tip: you can bake the town into your place from the Command Bar:
	  require(game.ServerScriptService.Server.World.Town).Build(workspace)
	WorldService keeps an existing Workspace.World instead of generating one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Data.World)

local B = require(script.Parent.Builder)
local Districts = script.Parent:WaitForChild("Districts")

local Town = {}

Town.LandHalf = 320 -- island from -320 to 320 (minus the harbour bay)
Town.BayCorner = 150 -- the bay is x > 150 and z > 150
Town.WaterTop = -0.6
Town.SeaFloor = -14

local ROAD_TOP_H = 0.2 -- east-west roads
local ROAD_TOP_V = 0.22 -- north-south roads sit a hair higher (no z-fighting)

local function inBay(x: number, z: number): boolean
	return x > Town.BayCorner - 4 and z > Town.BayCorner - 4
end

local function buildGround(world: Folder)
	local ground = B.Folder(world, "Ground")
	local L, bay = Town.LandHalf, Town.BayCorner
	local depth = -Town.SeaFloor
	-- Two land blocks leave the bay open in the south-east corner.
	B.Part(ground, { Name = "LandNorth", Size = Vector3.new(2 * L, depth, L + bay), CFrame = CFrame.new(0, -depth / 2, (-L + bay) / 2), Color = B.Palette.Grass, Material = Enum.Material.Grass })
	B.Part(ground, { Name = "LandSouthWest", Size = Vector3.new(L + bay, depth, L - bay), CFrame = CFrame.new((-L + bay) / 2, -depth / 2, (L + bay) / 2), Color = B.Palette.Grass, Material = Enum.Material.Grass })
	-- Sand around the coast.
	local beach = 10
	B.Slab(ground, "CoastN", 0, -L + beach / 2, 2 * L, beach, 0.05, B.Palette.Sand, Enum.Material.Sand, 0.2)
	B.Slab(ground, "CoastW", -L + beach / 2, 0, beach, 2 * L, 0.05, B.Palette.Sand, Enum.Material.Sand, 0.2)
	B.Slab(ground, "CoastE", L - beach / 2, (-L + bay) / 2, beach, L + bay, 0.05, B.Palette.Sand, Enum.Material.Sand, 0.2)
	B.Slab(ground, "CoastS", (-L + bay) / 2, L - beach / 2, L + bay, beach, 0.05, B.Palette.Sand, Enum.Material.Sand, 0.2)

	-- Roads: two north-south, two east-west and a ring (cut by the bay).
	local roads = B.Folder(ground, "Roads")
	local w = World.RoadWidth
	local ring = World.RingRoad
	local outer = ring + w / 2
	for _, x in ipairs({ -80, 80 }) do
		B.Road(roads, x, -outer, x, outer, w, ROAD_TOP_V)
	end
	for _, z in ipairs({ -80, 80 }) do
		B.Road(roads, -outer, z, outer, z, w, ROAD_TOP_H)
	end
	local roadEnd = bay - 16 -- the ring road stops short of the bay
	B.Road(roads, -outer, -ring, outer, -ring, w, ROAD_TOP_H) -- north
	B.Road(roads, -ring, -outer, -ring, outer, w, ROAD_TOP_V) -- west
	B.Road(roads, ring, -outer, ring, roadEnd, w, ROAD_TOP_V) -- east
	B.Road(roads, -outer, ring, roadEnd, ring, w, ROAD_TOP_H) -- south
	-- Turning circles where the ring road meets the bay.
	B.Cylinder(roads, "TurnEast", CFrame.new(ring, ROAD_TOP_V - 0.4, roadEnd), 30, 0.4, B.Palette.Asphalt, Enum.Material.Asphalt)
	B.Cylinder(roads, "TurnSouth", CFrame.new(roadEnd, ROAD_TOP_H - 0.4, ring), 30, 0.4, B.Palette.Asphalt, Enum.Material.Asphalt)
	return ground
end

local function buildSea(world: Folder)
	local terrain = workspace.Terrain
	local half = 520
	local height = Town.WaterTop - Town.SeaFloor
	pcall(function()
		terrain:FillBlock(CFrame.new(0, Town.SeaFloor + height / 2, 0), Vector3.new(half * 2, height, half * 2), Enum.Material.Water)
	end)
	-- A sandy slope from the beach into the bay.
	local coast = world.Ground
	local run, drop = 18, 8
	B.Part(coast, { Name = "BeachSlope", Class = "WedgePart", Size = Vector3.new(Town.LandHalf - Town.BayCorner, drop, run), CFrame = CFrame.new(Town.BayCorner + run / 2, -drop / 2, (Town.BayCorner + Town.LandHalf) / 2) * CFrame.Angles(0, math.rad(-90), 0), Color = B.Palette.Sand, Material = Enum.Material.Sand })
end

-- Street lamps along the road edges and trees around the edge of town.
local function buildStreets(world: Folder)
	local streets = B.Folder(world, "Streets")
	local ring = World.RingRoad
	local edge = World.RoadWidth / 2 - 1
	local function nearCrossing(t: number): boolean
		for _, line in ipairs({ -80, 80, -ring, ring }) do
			if math.abs(t - line) < 16 then
				return true
			end
		end
		return false
	end
	for _, line in ipairs({ -80, 80 }) do
		for t = -208, 208, 64 do
			if not nearCrossing(t) then
				if not inBay(line - edge, t) then
					B.Lamp(streets, Vector3.new(line - edge, ROAD_TOP_V, t)) -- north-south roads, west edge
				end
				if not inBay(t, line + edge) then
					B.Lamp(streets, Vector3.new(t, ROAD_TOP_H, line + edge)) -- east-west roads, south edge
				end
			end
		end
	end
	-- Trees beyond the ring road (a green belt round the island).
	local belt = ring + 30
	for t = -300, 300, 36 do
		for _, p in ipairs({ { t, -belt }, { -belt, t }, { belt, t }, { t, belt } }) do
			local x, z = p[1], p[2]
			if not inBay(x, z) and math.abs(x) < Town.LandHalf - 14 and math.abs(z) < Town.LandHalf - 14 then
				B.Tree(streets, Vector3.new(x, 0, z), 1.1 + ((x * 7 + z * 3) % 5) / 10, if (x + z) % 72 == 0 then "Pine" else nil)
			end
		end
	end
	-- Direction signs at the Plaza's corners.
	B.PostSign(streets, "SignNorth", B.At(-60, 0.16, -64, 0), 15, "⬆ Downtown · University · Career Row", "#1D3557")
	B.PostSign(streets, "SignSouth", B.At(60, 0.16, 64, 180), 15, "⬇ Oak Street · Willow Park · Harbour", "#1D3557")
	return streets
end

-- Walls round each district that unlocks later (the client makes them solid).
local function buildLocks(world: Folder)
	local locks = B.Folder(world, "Locks")
	local half = World.CellSize / 2
	for _, d in ipairs(World.Districts) do
		if d.UnlockStage > 1 then
			-- From the sea floor up, so nobody can swim underneath.
			local c = Vector3.new(d.X, Town.SeaFloor, d.Z)
			local height, thickness = 16 - Town.SeaFloor, 1
			B.LockWall(locks, d.Id, d.UnlockStage, CFrame.new(c + Vector3.new(0, 0, -half)), World.CellSize, height, thickness)
			B.LockWall(locks, d.Id, d.UnlockStage, CFrame.new(c + Vector3.new(0, 0, half)), World.CellSize, height, thickness)
			B.LockWall(locks, d.Id, d.UnlockStage, CFrame.new(c + Vector3.new(-half, 0, 0)), thickness, height, World.CellSize)
			B.LockWall(locks, d.Id, d.UnlockStage, CFrame.new(c + Vector3.new(half, 0, 0)), thickness, height, World.CellSize)
		end
	end
	return locks
end

--[[
	ctx passed to each district builder:
	  ctx.Folder, ctx.District (World entry), ctx.NPCs (anchor folder),
	  ctx.Plots (Residential only), ctx.Locks,
	  ctx.At(x, z, yaw?, y?) -> CFrame in world space from district-local
	  coordinates (origin at the district centre on the ground).
]]
function Town.Context(world: Folder, district)
	local folder = B.Folder(world.Districts, district.Id)
	folder:SetAttribute("District", district.Id)
	local ctx = {
		Folder = folder,
		District = district,
		NPCs = world.NPCAnchors,
		Plots = world.Plots,
		Locks = world.Locks,
		Ground = 0.1,
	}
	function ctx.At(x: number, z: number, yaw: number?, y: number?): CFrame
		return B.At(district.X + x, y or ctx.Ground, district.Z + z, yaw)
	end
	function ctx.Pos(x: number, z: number, y: number?): Vector3
		return Vector3.new(district.X + x, y or ctx.Ground, district.Z + z)
	end
	return ctx
end

function Town.Build(parent: Instance?)
	local target = parent or workspace
	local existing = target:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local world = B.Folder(target, "World")
	world:SetAttribute("Town", World.TownName)
	buildGround(world)
	buildSea(world)
	B.Folder(world, "Districts")
	B.Folder(world, "NPCAnchors")
	B.Folder(world, "Plots")
	buildLocks(world)
	buildStreets(world)
	for _, district in ipairs(World.Districts) do
		local module = Districts:FindFirstChild(district.Id)
		if module then
			local ctx = Town.Context(world, district)
			if not district.Coastal then
				B.Slab(ctx.Folder, "Ground", district.X, district.Z, World.CellSize, World.CellSize, 0.1, "#7FBF6A", Enum.Material.Grass, 0.3)
			end
			require(module)(B, ctx)
		end
	end
	return world
end

return Town
