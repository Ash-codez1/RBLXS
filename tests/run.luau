--[[
	Run from the project root:   lune run tests/run.luau
	Executes the real src/ modules against the fake Roblox environment in harness.luau.
]]

local process = require("@lune/process")
local task = require("@lune/task")
local H = require("./harness")
local test, eq, ok, near, section = H.test, H.eq, H.ok, H.near, H.section

local unit = H.new({ Quiet = true })
local TableUtil = unit.require("ReplicatedStorage.Shared.Util.TableUtil")
local StatMath = unit.require("ReplicatedStorage.Shared.Util.StatMath")
local Signal = unit.require("ReplicatedStorage.Shared.Util.Signal")
local LifeStages = unit.require("ReplicatedStorage.Shared.Data.LifeStages")
local StatDefinitions = unit.require("ReplicatedStorage.Shared.Data.StatDefinitions")
local DataTemplate = unit.require("ReplicatedStorage.Shared.Data.DataTemplate")
local SessionLock = unit.require("ServerScriptService.Server.Lib.SessionLock")
local Validate = unit.require("ServerScriptService.Server.Lib.Validate")
local MockDataStore = unit.require("ServerScriptService.Server.Lib.MockDataStore")

-- ======================================================================
section("TableUtil")
test("DeepCopy produces independent nested tables", function()
	local a = { x = { y = { 1, 2 } } }
	local b = TableUtil.DeepCopy(a)
	b.x.y[1] = 99
	eq(a.x.y[1], 1)
end)
test("Reconcile fills missing keys without overwriting", function()
	local t = { a = 5, nested = { keep = true } }
	TableUtil.Reconcile(t, { a = 1, b = 2, nested = { keep = false, added = 3 }, list = {} })
	eq(t.a, 5)
	eq(t.b, 2)
	eq(t.nested.keep, true)
	eq(t.nested.added, 3)
	ok(type(t.list) == "table")
end)
test("Reconcile does not treat false as missing", function()
	local t = { slot = false }
	TableUtil.Reconcile(t, { slot = { Name = "x" } })
	eq(t.slot, false)
end)
test("TrimArray keeps the newest entries", function()
	local t = { 1, 2, 3, 4, 5 }
	TableUtil.TrimArray(t, 3)
	eq(#t, 3)
	eq(t[1], 3)
	eq(t[3], 5)
end)
test("IsSerializable rejects NaN, functions and mixed keys", function()
	ok(TableUtil.IsSerializable({ a = 1, b = { 1, 2 } }))
	ok(not TableUtil.IsSerializable({ a = 0 / 0 }))
	ok(not TableUtil.IsSerializable({ a = function() end }))
	ok(not TableUtil.IsSerializable({ [1] = "a", b = "c" }))
end)

-- ======================================================================
section("Signal")
test("Connect / Fire / Disconnect", function()
	local s = Signal.new()
	local total = 0
	local c = s:Connect(function(n)
		total += n
	end)
	s:Fire(2)
	c:Disconnect()
	s:Fire(5)
	eq(total, 2)
end)
test("Once fires only once", function()
	local s = Signal.new()
	local count = 0
	s:Once(function()
		count += 1
	end)
	s:Fire()
	s:Fire()
	eq(count, 1)
end)

-- ======================================================================
section("StatMath")
test("Apply clamps to [0, 100] and ignores unknown stats / NaN", function()
	local stats = { Happiness = 95, Health = 5 }
	local result, applied = StatMath.Apply(stats, { Happiness = 50, Health = -50, Hacked = 999, Wealth = 0 / 0 })
	eq(result.Happiness, 100)
	eq(result.Health, 0)
	eq(result.Hacked, nil)
	eq(result.Wealth, nil)
	eq(applied.Hacked, nil)
	eq(stats.Happiness, 95, "input not mutated")
end)
test("Diminishing returns near the top of the scale", function()
	local low = select(2, StatMath.Apply({ Intelligence = 20 }, { Intelligence = 10 }))
	local high = select(2, StatMath.Apply({ Intelligence = 85 }, { Intelligence = 10 }))
	ok(low.Intelligence > high.Intelligence, "gain at 20 should exceed gain at 85")
end)
test("Multipliers scale deltas", function()
	local _, base = StatMath.Apply({ Health = 50 }, { Health = -10 })
	local _, halved = StatMath.Apply({ Health = 50 }, { Health = -10 }, { Health = 0.5 })
	near(halved.Health, base.Health / 2, 0.11)
end)
test("WealthFromNetWorth log scale anchors", function()
	eq(StatMath.WealthFromNetWorth(0), 0)
	near(StatMath.WealthFromNetWorth(10000), 50, 0.1)
	near(StatMath.WealthFromNetWorth(1000000), 75, 0.1)
	eq(StatMath.WealthFromNetWorth(1e12), 100)
end)

section("Format / Traits")
local Format = unit.require("ReplicatedStorage.Shared.Util.Format")
local Traits = unit.require("ReplicatedStorage.Shared.Data.Traits")
test("Money and signed formatting", function()
	eq(Format.Money(0), "$0")
	eq(Format.Money(950), "$950")
	eq(Format.Money(12500), "$12,500")
	eq(Format.Money(1250000), "$1.25M")
	eq(Format.Money(-45), "-$45")
	eq(Format.Commas(1234567), "1,234,567")
	eq(Format.Signed(3), "+3")
	eq(Format.Signed(-1.25), "-1.3")
end)
test("Trait gain multipliers stack and clamp", function()
	local m = Traits.GainMultipliers({ Studious = 2, Shy = 1 })
	near(m.Intelligence, 1 + 0.06 * 2 + 0.03, 0.001)
	near(m.Popularity, 0.95, 0.001)
	local capped = Traits.GainMultipliers({ Studious = 99 })
	ok(capped.Intelligence <= 1.5)
end)

-- ======================================================================
section("LifeStages / StatDefinitions")
test("Six stages with contiguous ages", function()
	eq(LifeStages.Count, 6)
	for i = 2, LifeStages.Count do
		eq(LifeStages.List[i].MinAge, LifeStages.List[i - 1].MaxAge + 1, "stage " .. i)
	end
end)
test("Final scenario of each stage lands on MaxAge", function()
	for _, stage in ipairs(LifeStages.List) do
		eq(LifeStages.AgeAfterScenario(stage.Id, stage.ScenariosPerStage), stage.MaxAge, stage.Key)
	end
end)
test("ForAge maps ages to stages", function()
	eq(LifeStages.ForAge(5).Key, "Childhood")
	eq(LifeStages.ForAge(30).Key, "Adult")
	eq(LifeStages.ForAge(200).Key, "Retirement")
end)
test("Eight stats with info", function()
	eq(#StatDefinitions.Order, 8)
	for _, name in ipairs(StatDefinitions.Order) do
		ok(StatDefinitions.Info[name], name)
	end
	ok(not StatDefinitions.IsValid("Money"))
end)

-- ======================================================================
section("DataTemplate")
test("NewProfile and NewLife are DataStore-serializable", function()
	local profile = DataTemplate.NewProfile()
	profile.Slots.Slot1 = DataTemplate.NewLife("Alex", 12345)
	local good, problem = TableUtil.IsSerializable(profile)
	ok(good, tostring(problem))
	eq(profile.Version, DataTemplate.CurrentVersion)
end)
test("Upgrade fills fields missing from an old save", function()
	local old = { Version = 1, Coins = 777, Slots = { Slot1 = { Name = "Old", Age = 30, Stats = { Happiness = 80 } } } }
	local upgraded = DataTemplate.Upgrade(old)
	ok(upgraded)
	eq(upgraded.Coins, 777)
	eq(upgraded.Slots.Slot2, false)
	eq(upgraded.Slots.Slot1.Age, 30)
	eq(upgraded.Slots.Slot1.Stats.Happiness, 80)
	eq(upgraded.Slots.Slot1.Stats.Health, 50, "missing stat filled")
	ok(upgraded.Settings.MusicVolume ~= nil)
end)
test("Upgrade refuses data from a newer schema", function()
	local result, reason = DataTemplate.Upgrade({ Version = DataTemplate.CurrentVersion + 1 })
	eq(result, nil)
	ok(reason and reason:find("newer"))
end)
test("Migrations run in order", function()
	local saved = DataTemplate.CurrentVersion
	DataTemplate.CurrentVersion = saved + 1
	DataTemplate.Migrations[saved] = function(profile)
		profile.Coins = (profile.Coins or 0) * 2
	end
	local upgraded = DataTemplate.Upgrade({ Version = saved, Coins = 10 })
	DataTemplate.CurrentVersion = saved
	DataTemplate.Migrations[saved] = nil
	eq(upgraded.Coins, 20)
	eq(upgraded.Version, saved + 1)
end)

-- ======================================================================
section("SessionLock")
test("Acquire on empty record", function()
	local rec, result = SessionLock.Acquire(nil, "A", 1000, 1800)
	eq(result, "Acquired")
	eq(rec.Lock.JobId, "A")
end)
test("Acquire blocked by another live server", function()
	local rec, result = SessionLock.Acquire({ Data = {}, Lock = { JobId = "B", Time = 1000 } }, "A", 1100, 1800)
	eq(rec, nil)
	eq(result, "Locked")
end)
test("Acquire takes over an expired lock", function()
	local _, result = SessionLock.Acquire({ Data = {}, Lock = { JobId = "B", Time = 0 } }, "A", 5000, 1800)
	eq(result, "Acquired")
end)
test("Write is cancelled if another server stole the lock", function()
	local rec, result = SessionLock.Write({ Data = {}, Lock = { JobId = "B", Time = 1 } }, "A", { Coins = 1 }, 2, false)
	eq(rec, nil)
	eq(result, "LockStolen")
end)
test("Write with release clears the lock", function()
	local rec = SessionLock.Write({ Data = {}, Lock = { JobId = "A", Time = 1 } }, "A", { Coins = 1 }, 2, true)
	eq(rec.Lock, nil)
	eq(rec.Data.Coins, 1)
end)

-- ======================================================================
section("Validate")
test("Number/Integer/Id reject bad input", function()
	eq(Validate.Number(0 / 0, 0, 1), nil)
	eq(Validate.Number(2, 0, 1), nil)
	eq(Validate.Integer(1.5, 0, 5), nil)
	eq(Validate.Integer(3, 0, 5), 3)
	eq(Validate.Id("ok_id1"), "ok_id1")
	eq(Validate.Id("bad id!"), nil)
	eq(Validate.Id(string.rep("a", 100)), nil)
end)
test("Partial keeps only valid known keys", function()
	local schema = { Vol = { Kind = "Number", Min = 0, Max = 1 }, On = { Kind = "Boolean" }, Q = { Kind = "OneOf", Options = { "Low", "High" } } }
	local out = Validate.Partial({ Vol = 5, On = true, Q = "High", Evil = "x" }, schema)
	eq(out.Vol, nil)
	eq(out.On, true)
	eq(out.Q, "High")
	eq(out.Evil, nil)
	eq(next(Validate.Partial("not a table", schema)), nil)
end)

-- ======================================================================
-- Integration: boot the real server (Main.server.luau) with fake DataStores.
section("Server integration")

local sharedStore = MockDataStore.new()
local function makeDataStoreService()
	return {
		GetDataStore = function()
			return sharedStore
		end,
		GetRequestBudgetForRequestType = function()
			return 100
		end,
	}
end

local server = H.new({ JobId = "server-A", DataStoreService = makeDataStoreService(), Quiet = true })
server.run("ServerScriptService.Server.Main")
task.wait(0.05)
local DataService = server.require("ServerScriptService.Server.Services.DataService")
local StatService = server.require("ServerScriptService.Server.Services.StatService")
local NetS = server.require("ReplicatedStorage.Shared.Net")

test("Remotes folder created with every definition", function()
	for name in pairs(NetS.Definitions.Events) do
		ok(server.remote(name), name)
	end
	for name in pairs(NetS.Definitions.Functions) do
		ok(server.remote(name), name)
	end
	eq(DataService.UsingMockStore, false)
end)

local alice = server.addPlayer(101, "Alice")
task.wait(0.05)

test("New player gets a fresh profile", function()
	local data = DataService.Get(alice)
	ok(data, "loaded")
	eq(data.Coins, 100)
	eq(data.Slots.Slot1, false)
end)

test("GetData remote returns a sanitized snapshot", function()
	DataService.Update(alice, function(data)
		data.Slots.Slot1 = DataTemplate.NewLife("Alice", 4242)
		table.insert(data.ProcessedReceipts, "r1")
	end)
	local okResult, snapshot = server.remote("GetData").OnServerInvoke(alice)
	eq(okResult, true)
	eq(snapshot.Slots.Slot1.Seed, nil, "seed hidden")
	eq(snapshot.ProcessedReceipts, nil, "receipts hidden")
	eq(DataService.Get(alice).Slots.Slot1.Seed, 4242, "server keeps seed")
end)

test("Data changes replicate to the owning client only (throttled)", function()
	local remote = server.remote("DataSnapshot")
	table.clear(remote.Fired)
	for _ = 1, 5 do
		DataService.Update(alice, function(data)
			data.Coins += 1
		end)
	end
	task.wait(0.25)
	eq(#remote.Fired, 1, "5 updates coalesced into 1 push")
	eq(remote.Fired[1].Player, alice)
	eq(remote.Fired[1].Args[1].Coins, 105)
end)

test("StatService.Apply changes the active life and fires StatsChanged", function()
	local fired = nil
	StatService.StatsChanged:Once(function(_, applied, reason)
		fired = reason
	end)
	local applied = StatService.Apply(alice, { Intelligence = 10, Happiness = -5 }, "Studied")
	ok(applied and applied.Intelligence > 0)
	ok(StatService.Get(alice).Intelligence > 50)
	eq(fired, "Studied")
end)

test("UpdateSettings validates and drops bad values", function()
	local invoke = server.remote("UpdateSettings").OnServerInvoke
	local success, clean = invoke(alice, { MusicVolume = 0.2, UIScale = 99, Graphics = "Ultra", Hack = true })
	eq(success, true)
	eq(clean.MusicVolume, 0.2)
	eq(clean.UIScale, nil)
	local data = DataService.Get(alice)
	eq(data.Settings.MusicVolume, 0.2)
	eq(data.Settings.UIScale, 1)
	eq(data.Settings.Graphics, "Auto")
	eq(data.Hack, nil)
	local fail, reason = invoke(alice, "garbage")
	eq(fail, false)
	eq(reason, "NothingValid")
end)

test("Remote rate limiting rejects spam", function()
	local invoke = server.remote("UpdatePrivacy").OnServerInvoke
	local rejected = 0
	for _ = 1, 10 do
		local success, reason = invoke(alice, { ShareStats = "Nobody" })
		if not success and reason == "RateLimited" then
			rejected += 1
		end
	end
	ok(rejected >= 5, "expected >=5 rejections, got " .. rejected)
	eq(DataService.Get(alice).Privacy.ShareStats, "Nobody")
end)

test("Handler errors are caught and reported as ServerError", function()
	local h = H.new({ Quiet = true })
	local Net = h.require("ReplicatedStorage.Shared.Net")
	Net.Definitions.Functions.__TestBoom = {}
	Net.Init()
	Net.Handle("__TestBoom", function()
		error("kaboom")
	end)
	local fakePlayer = { Name = "Tester" }
	local success, reason = h.remote("__TestBoom").OnServerInvoke(fakePlayer)
	Net.Definitions.Functions.__TestBoom = nil
	eq(success, false)
	eq(reason, "ServerError")
end)

test("A second server cannot load a player whose data is locked", function()
	-- Flush Alice's data under server A's lock first.
	ok(DataService.SaveNow(alice), "save")
	local record = sharedStore:GetAsync("Player_101")
	eq(record.Lock.JobId, "server-A")
	local _, status = SessionLock.Acquire(record, "server-B", os.time(), 1800)
	eq(status, "Locked")
end)

test("Leaving saves and releases the lock; rejoining restores data", function()
	server.removePlayer(alice)
	task.wait(0.05)
	eq(DataService.IsLoaded(alice), false)
	local record = sharedStore:GetAsync("Player_101")
	eq(record.Lock, nil, "lock released")
	eq(record.Data.Coins, 105)
	ok(record.Data.Slots.Slot1.Stats.Intelligence > 50)

	-- Rejoin on a different server.
	local serverB = H.new({ JobId = "server-B", DataStoreService = makeDataStoreService(), Quiet = true })
	serverB.run("ServerScriptService.Server.Main")
	local aliceAgain = serverB.addPlayer(101, "Alice")
	task.wait(0.05)
	local DataServiceB = serverB.require("ServerScriptService.Server.Services.DataService")
	local data = DataServiceB.Get(aliceAgain)
	ok(data, "loaded on server B")
	eq(data.Coins, 105)
	eq(data.Slots.Slot1.Name, "Alice")
	eq(sharedStore:GetAsync("Player_101").Lock.JobId, "server-B")
	serverB.close()
	eq(sharedStore:GetAsync("Player_101").Lock, nil, "BindToClose released the lock")
end)

test("Two players' data stays separate", function()
	local p1 = server.addPlayer(201, "P1")
	local p2 = server.addPlayer(202, "P2")
	task.wait(0.05)
	DataService.Update(p1, function(d)
		d.Slots.Slot1 = DataTemplate.NewLife("P1", 1)
	end)
	DataService.Update(p2, function(d)
		d.Slots.Slot1 = DataTemplate.NewLife("P2", 2)
	end)
	StatService.Apply(p1, { Wealth = 40 }, "test")
	eq(StatService.Get(p2).Wealth, 0, "p2 unaffected")
	ok(StatService.Get(p1).Wealth > 0)
	server.close()
	ok(sharedStore:GetAsync("Player_201").Data.Slots.Slot1.Stats.Wealth > 0)
	eq(sharedStore:GetAsync("Player_202").Data.Slots.Slot1.Stats.Wealth, 0)
end)

test("Falls back to MockDataStore when DataStores are unavailable (Studio)", function()
	local studio = H.new({ IsStudio = true, Quiet = true })
	studio.run("ServerScriptService.Server.Main")
	local ds = studio.require("ServerScriptService.Server.Services.DataService")
	eq(ds.UsingMockStore, true)
	local p = studio.addPlayer(301, "StudioTester")
	task.wait(0.05)
	ok(ds.Get(p), "loaded from mock")
	studio.close()
end)

require("./life_spec")(H)
require("./client_spec")(H)

-- ======================================================================
print(("\n%d passed, %d failed"):format(H.results.passed, H.results.failed))
process.exit(if H.results.failed == 0 then 0 else 1)
