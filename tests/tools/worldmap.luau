--[[
	Builds Lifeville in the test harness and writes every part's footprint to
	a JSON file, for a top-down map preview (tests/tools/render_map.py).
	  lune run tests/tools/worldmap.luau [out.json]
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local H = require("../harness")

local task = require("@lune/task")
-- Boot the real server (world, NPCs, plots) with two players so houses appear.
local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")
local store = MockDataStore.new()
local h = H.new({ Quiet = true, DataStoreService = {
	GetDataStore = function()
		return store
	end,
	GetRequestBudgetForRequestType = function()
		return 100
	end,
} })
local t0 = os.clock()
h.run("ServerScriptService.Server.Main")
task.wait(0.1)
local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
local DS = h.require("ServerScriptService.Server.Services.DataService")
local Plots = h.require("ServerScriptService.Server.Services.PlotService")
for i, name in ipairs({ "Ava", "Max" }) do
	local player = h.addPlayer(7000 + i, name)
	task.wait(0.1)
	DS.Update(player, function(d)
		d.Slots.Slot1 = DT.NewLife(name, i)
		d.ActiveSlot = "Slot1"
		d.Slots.Slot1.Age = 30 + i * 10
		d.Slots.Slot1.Assets = if i == 1 then { House = true, Car = true } else { Mansion = true, SportsCar = true }
	end)
	Plots.Refresh(player)
end
local world = h.workspace:FindFirstChild("World")
local elapsed = os.clock() - t0
local parts = H.partsOf(world)
local out = {}
for _, p in ipairs(parts) do
	local cf = p.CFrame
	local colour = p.Color or { R = 0.85, G = 0.7, B = 0.55 } -- harness rigs have no colour
	local look = cf.LookVector
	local right = cf.RightVector
	table.insert(out, {
		n = p.Name, c = p.ClassName, x = cf.X, y = cf.Y, z = cf.Z,
		sx = p.Size.X, sy = p.Size.Y, sz = p.Size.Z,
		rx = right.X, rz = right.Z, lx = look.X, lz = look.Z,
		col = { colour.R, colour.G, colour.B }, t = p.Transparency or 0,
		shape = p.Shape and p.Shape.Name or nil,
		tag = (function()
			local tags = p:GetTags()
			return tags[1]
		end)(),
	})
end
local path = process.args[1] or "worldmap.json"
fs.writeFile(path, serde.encode("json", out))
print(("Built %d parts in %.2fs -> %s"):format(#parts, elapsed, path))
local counts = {}
for _, d in ipairs(world.Districts:GetChildren()) do
	counts[d.Name] = #H.partsOf(d)
end
print(serde.encode("json", counts))
print("NPC anchors:", #world.NPCAnchors:GetChildren())
process.exit(0) -- NPC walkers and house timers keep running otherwise
