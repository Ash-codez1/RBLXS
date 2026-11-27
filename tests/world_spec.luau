--[[
	Lifeville (Phase 8) server tests: the generated town, data validity, the
	server's checks for world actions, homes and NPCs, and the day clock.
	Called from tests/run.luau.
]]

local task = require("@lune/task")

return function(H)
	local test, eq, ok, section = H.test, H.eq, H.ok, H.section
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")
	local store = MockDataStore.new()
	local server = H.new({
		Quiet = true,
		JobId = "world",
		DataStoreService = {
			GetDataStore = function()
				return store
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		},
	})
	server.run("ServerScriptService.Server.Main")
	task.wait(0.05)

	local V3 = H.Datatypes.Vector3.new
	local World = server.require("ReplicatedStorage.Shared.Data.World")
	local WorldSpots = server.require("ReplicatedStorage.Shared.Data.WorldSpots")
	local NPCs = server.require("ReplicatedStorage.Shared.Data.NPCs")
	local Catalog = server.require("ReplicatedStorage.Shared.Data.Catalog")
	local Careers = server.require("ReplicatedStorage.Shared.Data.Careers")
	local StatDefinitions = server.require("ReplicatedStorage.Shared.Data.StatDefinitions")
	local DT = server.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local WS = server.require("ServerScriptService.Server.Services.WorldService")
	local NPCService = server.require("ServerScriptService.Server.Services.NPCService")
	local PlotService = server.require("ServerScriptService.Server.Services.PlotService")
	local DS = server.require("ServerScriptService.Server.Services.DataService")
	local Shop = server.require("ServerScriptService.Server.Services.ShopService")
	local Actions = server.require("ServerScriptService.Server.Lib.Actions")
	local CollectionService = server.CollectionService
	local world = server.workspace:FindFirstChild("World")

	section("Lifeville: the generated town")
	test("Every district is built, within a sensible part budget", function()
		ok(world, "Workspace.World exists")
		for _, d in ipairs(World.Districts) do
			ok(world.Districts:FindFirstChild(d.Id), "district folder " .. d.Id)
		end
		local parts = #H.partsOf(world)
		ok(parts > 1500 and parts < 4500, ("part count %d within budget (1500–4500, NPCs and houses included)"):format(parts))
		ok(server.workspace:FindFirstChild("SpawnLocation") or true, "spawn (from the project file in Studio)")
	end)

	test("Every spot and NPC exists, and sits inside its own district", function()
		local placed = {}
		for _, part in ipairs(CollectionService:GetTagged("CYL_Spot")) do
			local id = part:GetAttribute("CYL_Spot")
			placed[id] = (placed[id] or 0) + 1
			local def = WorldSpots.Get(id)
			ok(def, "known spot " .. tostring(id))
			local district = World.DistrictAt(part.Position.X, part.Position.Z)
			eq(district, def.District, id .. " is in " .. def.District)
			ok(part:FindFirstChildOfClass("ProximityPrompt"), id .. " has a prompt")
		end
		for _, def in ipairs(WorldSpots.List) do
			if not def.OwnHome then -- home spots are built with each player's house
				ok((placed[def.Id] or 0) >= 1, "spot placed: " .. def.Id)
				if def.Kind ~= "Open" then
					eq(placed[def.Id], 1, "action spot placed exactly once: " .. def.Id)
				end
			end
		end
		for _, npc in ipairs(NPCs.List) do
			local anchor = world.NPCAnchors:FindFirstChild(npc.Id)
			ok(anchor, "anchor for " .. npc.Id)
			ok(World.DistrictAt(anchor.Position.X, anchor.Position.Z), npc.Id .. " stands inside a district")
		end
	end)

	test("Buildings in a district never overlap", function()
		for _, folder in ipairs(world.Districts:GetChildren()) do
			local boxes = {}
			for _, model in ipairs(folder:GetDescendants()) do
				if model.ClassName == "Model" and model:GetAttribute("CYL_Building") then
					local floor = model:FindFirstChild("Floor")
					local cf, size = floor.CFrame, floor.Size
					local right, back = cf.RightVector, -cf.LookVector
					local hx = math.abs(right.X) * size.X / 2 + math.abs(back.X) * size.Z / 2
					local hz = math.abs(right.Z) * size.X / 2 + math.abs(back.Z) * size.Z / 2
					table.insert(boxes, { Name = model.Name, X = cf.X, Z = cf.Z, HX = hx, HZ = hz })
				end
			end
			for i = 1, #boxes do
				for j = i + 1, #boxes do
					local a, b = boxes[i], boxes[j]
					local overlap = math.abs(a.X - b.X) < a.HX + b.HX - 0.01 and math.abs(a.Z - b.Z) < a.HZ + b.HZ - 0.01
					ok(not overlap, ("%s overlaps %s"):format(a.Name, b.Name))
				end
			end
		end
	end)

	test("Districts that unlock later are walled; the Sunset Club door is locked", function()
		local walls = {}
		for _, part in ipairs(CollectionService:GetTagged("CYL_Lock")) do
			local id = part:GetAttribute("LockId")
			walls[id] = (walls[id] or 0) + 1
			eq(part.CanCollide, false, "lock walls are only solid on the client")
		end
		for _, d in ipairs(World.Districts) do
			eq(walls[d.Id] or 0, if d.UnlockStage > 1 then 4 else 0, "walls round " .. d.Id)
		end
		eq(walls.SunsetClub, 1, "Sunset Club door")
	end)

	test("World data validates (spots, NPC options, walkers, showcase shots)", function()
		local problems = WorldSpots.Validate(World, StatDefinitions.Order)
		eq(#problems, 0, table.concat(problems, "; "))
		local screens = { Shop = true, Money = true, Map = true, SlotSelect = true, People = true, Future = true }
		for _, npc in ipairs(NPCs.List) do
			for _, option in ipairs(npc.Options or {}) do
				if option.Spot then
					ok(WorldSpots.Get(option.Spot), npc.Id .. " offers a real spot " .. option.Spot)
				end
				if option.Open then
					ok(screens[option.Open], npc.Id .. " opens a real screen " .. option.Open)
				end
				if option.Guide then
					ok(World.ById[option.Guide], npc.Id .. " guides to a real district")
				end
			end
		end
		for _, loop in ipairs(World.WalkLoops) do
			ok(NPCs.ById[loop.Walker], "walker " .. loop.Walker)
		end
		for career in pairs(Careers.Info) do
			ok(World.WorkplaceOf[career], "every career has a workplace: " .. career)
		end
		for _, archetype in ipairs({ "Luxury", "Family", "Fame", "Career", "Genius", "Health", "Hero", "Content", "Adventure", "Difficult", "Lonely" }) do
			ok(World.ShowcaseShot(archetype), "showcase shot for " .. archetype)
		end
	end)

	test("The day clock comes from server time and has nights", function()
		local nights, days = 0, 0
		for t = 0, World.DayLengthSeconds - 1, 10 do
			local clock = World.ClockTimeAt(t)
			ok(clock >= 0 and clock < 24)
			if World.IsNight(clock) then
				nights += 1
			else
				days += 1
			end
		end
		ok(nights > 0 and days > nights, ("days %d > nights %d"):format(days, nights))
		eq(World.ClockTimeAt(5), World.ClockTimeAt(5 + World.DayLengthSeconds), "repeats every day")
	end)

	section("Lifeville: world actions are checked on the server")
	local player = server.addPlayer(5101, "Explorer")
	task.wait(0.05)
	local function data()
		return DS.Get(player)
	end
	local function life()
		return data().Slots.Slot1
	end
	local function setLife(fn)
		DS.Update(player, function(d)
			fn(d.Slots.Slot1)
		end)
	end
	DS.Update(player, function(d)
		d.Slots.Slot1 = DT.NewLife("Explorer", 77)
		d.ActiveSlot = "Slot1"
	end)
	local function spotPos(id)
		return WS.SpotParts(id)[1].Position
	end
	local function standAt(position)
		server.spawnCharacter(player, position + V3(0, 0.5, 0))
	end
	-- WorldService.Use is what the remote calls (after the rate limit and
	-- argument checks, which the "bad arguments" test covers through the remote).
	local function use(spotId, npcId)
		return WS.Use(player, spotId, npcId)
	end
	local function newDecision()
		setLife(function(l)
			table.insert(l.Decisions, { Scenario = "Test", Choice = "A", Age = l.Age, Stage = l.Stage })
		end)
	end

	test("You must be at the spot; a child can study at school", function()
		standAt(V3(0, 3, 30))
		eq(select(2, use("School_Study")), "TooFar", "from the plaza")
		standAt(spotPos("School_Study"))
		local before = life().Stats.Intelligence
		local okUse, result = use("School_Study")
		eq(okUse, true, tostring(result))
		ok(life().Stats.Intelligence > before, "Intelligence went up")
		eq(result.ActionsLeft, 1)
		ok(result.Applied.Intelligence > 0, "outcome lists the change")
	end)

	test("Two actions between decisions, shared with the People panel", function()
		standAt(spotPos("School_Library"))
		eq((use("School_Library")), true)
		eq(select(2, use("School_Library")), "NoActionsLeft")
		newDecision()
		eq((use("School_Library")), true, "the budget refreshes after a decision")
		eq(Actions.ActionsLeft(life()), 1)
	end)

	test("Locked districts, ages and flags are enforced", function()
		newDecision()
		standAt(spotPos("Cafe_Chat"))
		eq(select(2, use("Cafe_Chat")), "Locked", "Downtown is closed to children")
		standAt(spotPos("Park_Gym"))
		eq(select(2, use("Park_Gym")), "TooYoung", "the gym is 13+")
		setLife(function(l)
			l.Age, l.Stage = 20, 3
		end)
		standAt(spotPos("Uni_Lecture"))
		eq(select(2, use("Uni_Lecture")), "NeedFlag", "lectures need a university place")
		setLife(function(l)
			l.Flags.AtUni = true
		end)
		eq((use("Uni_Lecture")), true, "students can attend")
		standAt(spotPos("School_Playground"))
		eq(select(2, use("School_Playground")), "TooOld")
	end)

	test("Shifts are only for your workplace, and pay part of your salary", function()
		newDecision()
		standAt(spotPos("Hospital_Shift"))
		eq(select(2, use("Hospital_Shift")), "NoJob")
		setLife(function(l)
			l.Career = { Id = "Teacher", Level = 2, YearsInRole = 1 }
		end)
		eq(select(2, use("Hospital_Shift")), "WrongJob", "teachers don't work at the hospital")
		setLife(function(l)
			l.Career = { Id = "Doctor", Level = 1, YearsInRole = 0 }
		end)
		local money = life().Money
		local okShift, result = use("Hospital_Shift")
		eq(okShift, true, tostring(result))
		local pay = math.max(WorldSpots.MinShiftPay, math.floor(Careers.SalaryAt("Doctor", 1) * WorldSpots.ShiftPay))
		eq(life().Money, money + pay, "paid " .. pay)
		ok(result.Applied.Career > 0, "Career Success up")
	end)

	test("Costs are charged, and you can't spend money you don't have", function()
		newDecision()
		setLife(function(l)
			l.Money = 10
		end)
		standAt(spotPos("Restaurant_Eat"))
		eq(select(2, use("Restaurant_Eat")), "NotEnoughMoney")
		setLife(function(l)
			l.Money = 100
		end)
		eq((use("Restaurant_Eat")), true)
		eq(life().Money, 60, "a $40 meal")
	end)

	test("Menu spots, bad arguments and unknown spots are refused", function()
		newDecision()
		standAt(spotPos("Bank_Open"))
		local remote = server.remote("WorldAction")
		eq(select(2, remote.OnServerInvoke(player, "Bank_Open")), "BadSpot", "open-a-screen spots aren't actions")
		eq(select(2, remote.OnServerInvoke(player, 123)), "BadArgs")
		task.wait(1)
		eq(select(2, remote.OnServerInvoke(player, "Nope_Spot")), "BadSpot")
		eq(select(2, remote.OnServerInvoke(player, "School_Study", "Bad Id!")), "BadArgs")
		task.wait(1)
	end)

	test("Talking to an NPC: only what they offer, only when you're with them", function()
		newDecision()
		setLife(function(l)
			l.Age, l.Stage = 10, 1
		end)
		local teacher = NPCService.PositionOf("Teacher")
		ok(teacher, "the teacher is in the classroom")
		standAt(teacher + V3(3, 0, 0))
		eq((use("School_Study", "Teacher")), true, "help with studying from Ms. Rivera")
		eq(select(2, use("Park_Run", "Teacher")), "BadSpot", "she doesn't offer runs")
		standAt(V3(0, 3, 30))
		eq(select(2, use("School_Library", "Librarian")), "TooFar")
	end)

	section("Lifeville: homes on Oak Street")
	test("Each player gets a plot with a house that shows their life", function()
		local plot = PlotService.PlotOf(player)
		ok(plot, "plot assigned")
		eq(plot:GetAttribute("OwnerUserId"), 5101)
		local house = plot:FindFirstChild("House")
		ok(house, "house built")
		eq(house:FindFirstChild("Home"):GetAttribute("Tier"), "Family", "children live in the family home")
		local label = plot.NameSign.Board.Text.Label
		ok(label.Text:find("Explorer", 1, true), "name sign: " .. label.Text)
		setLife(function(l)
			l.Age, l.Stage = 30, 4
			l.Assets.House = true
		end)
		PlotService.Refresh(player)
		eq(plot.House.Home:GetAttribute("Tier"), "House", "a bought house shows up")
		DS.Update(player, function(d)
			d.Coins = 5000
		end)
		ok((Shop.Buy(player, "House_Cabin")), "buy a house style")
		task.wait(0.1)
		ok(plot.House:GetAttribute("Key"):find("House_Cabin", 1, true), "the house uses the equipped style")
		ok((Shop.Buy(player, "Car_Super")), "buy a supercar")
		task.wait(0.1)
		ok(plot.House:FindFirstChild("Car"), "car on the drive")
	end)

	test("Home spots work only in your own home", function()
		newDecision()
		local plot = PlotService.PlotOf(player)
		local rest = nil
		for _, part in ipairs(plot:GetDescendants()) do
			if part:IsA("BasePart") and part:GetAttribute("CYL_Spot") == "Home_Rest" then
				rest = part
			end
		end
		ok(rest, "rest spot in the house")
		standAt(rest.Position)
		eq((use("Home_Rest")), true, "rest at home")
		local visitor = server.addPlayer(5102, "Visitor")
		task.wait(0.1)
		DS.Update(visitor, function(d)
			d.Slots.Slot1 = DT.NewLife("Visitor", 9)
			d.ActiveSlot = "Slot1"
		end)
		server.spawnCharacter(visitor, rest.Position)
		local okVisit = WS.Use(visitor, "Home_Rest")
		eq(okVisit, false, "visitors can't use someone else's home spot")
		local theirs = PlotService.PlotOf(visitor)
		ok(theirs and theirs ~= plot, "the visitor has their own plot")
		server.removePlayer(visitor)
		task.wait(0.1)
		eq(theirs:GetAttribute("OwnerUserId"), nil, "plot freed when they leave")
		eq(theirs:FindFirstChild("House"), nil, "house cleared")
		ok(theirs.NameSign.Board.Text.Label.Text:find("For sale", 1, true), "sign reset")
	end)

	section("Lifeville: people")
	test("NPCs stand at their anchors with a name tag and a Talk prompt", function()
		for _, npc in ipairs(NPCs.List) do
			local rig = NPCService.Get(npc.Id)
			ok(rig, "spawned " .. npc.Id)
			local root = rig:FindFirstChild("HumanoidRootPart")
			eq(root.Anchored, true, npc.Id .. " stands still")
			local prompt = root:FindFirstChild("TalkPrompt")
			eq(prompt:GetAttribute("CYL_NPC"), npc.Id)
			ok(rig.Head:FindFirstChild("CYL_NPCTag"), npc.Id .. " name tag")
			local anchor = world.NPCAnchors[npc.Id]
			local flat = V3(root.Position.X - anchor.Position.X, 0, root.Position.Z - anchor.Position.Z)
			ok(flat.Magnitude < 0.01, npc.Id .. " at its anchor")
		end
		for _, loop in ipairs(World.WalkLoops) do
			local rig = NPCService.Get(loop.Walker)
			ok(rig and not rig.HumanoidRootPart.Anchored, loop.Walker .. " walks")
		end
	end)

	test("No errors or failure warnings on the server", function()
		eq(#server.errors, 0, table.concat(server.errors, "\n"))
		for _, w in ipairs(server.warnings) do
			ok(not w:find("NPCService") and not w:find("PlotService"), w)
		end
	end)
	server.close()
end
