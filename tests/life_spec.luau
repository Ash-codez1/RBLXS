--[[
	LifeService / content tests. Called from tests/run.luau.
]]

local task = require("@lune/task")

return function(H)
	local test, eq, ok, section = H.test, H.eq, H.ok, H.section
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")

	local function bootServer(options)
		local store = MockDataStore.new()
		options = options or {}
		options.Quiet = true
		options.JobId = options.JobId or "life-server"
		options.DataStoreService = {
			GetDataStore = function()
				return store
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		}
		local server = H.new(options)
		server.run("ServerScriptService.Server.Main")
		task.wait(0.02)
		server.store = store
		return server
	end

	local function invoke(server, name, player, ...)
		return server.remote(name).OnServerInvoke(player, ...)
	end

	-- Bypass rate limits for scripted play-throughs by calling the service directly.
	local function playStage(server, player, LifeService, rng)
		local steps = 0
		while steps < 20 do
			local okS, scenario = LifeService.GetScenario(player)
			if not okS then
				return steps, scenario
			end
			local open = {}
			for _, c in ipairs(scenario.Choices) do
				if not c.Locked then
					table.insert(open, c)
				end
			end
			local pick = open[rng:NextInteger(1, #open)]
			local okC, outcome = LifeService.MakeChoice(player, scenario.Id, pick.Id)
			assert(okC, "MakeChoice failed: " .. tostring(outcome))
			steps += 1
			if outcome.StageCompleted then
				return steps, "StageCompleted", outcome
			end
		end
		return steps, "TooMany"
	end

	section("Scenario content")
	local server = bootServer()
	local Scenarios = server.require("ServerScriptService.Server.Content.Scenarios")
	local LifeService = server.require("ServerScriptService.Server.Services.LifeService")
	local DataService = server.require("ServerScriptService.Server.Services.DataService")
	local LifeStages = server.require("ReplicatedStorage.Shared.Data.LifeStages")
	local TableUtil = server.require("ReplicatedStorage.Shared.Util.TableUtil")

	test("All scenario content validates with zero issues", function()
		eq(#Scenarios.Issues, 0, "issues: " .. table.concat(Scenarios.Issues, "; "))
		ok(Scenarios.CountForStage(1) >= LifeStages.Get(1).ScenariosPerStage, "enough childhood scenarios")
	end)

	test("Every choice has 3–5 options and text", function()
		for _, s in ipairs(Scenarios.All) do
			ok(#s.Choices >= 3 and #s.Choices <= 5, s.Id)
			for _, c in ipairs(s.Choices) do
				ok(type(c.Text) == "string" and #c.Text > 0, s.Id .. "." .. c.Id .. " text")
			end
		end
	end)

	section("LifeService: starting lives")
	local p = server.addPlayer(500, "Tester")
	task.wait(0.05)

	test("Rejects bad slot / bad name / filtered name", function()
		local a, ra = invoke(server, "StartNewLife", p, "Slot9", "Alex")
		eq(a, false)
		eq(ra, "BadSlot")
		local b, rb = invoke(server, "StartNewLife", p, "Slot1", "A")
		eq(b, false)
		eq(rb, "BadName")
		task.wait(2.1) -- StartNewLife allows a burst of 2, then 1 per 2 s
		local c, rc = invoke(server, "StartNewLife", p, "Slot1", string.rep("x", 40))
		eq(c, false)
		eq(rc, "BadName")
		task.wait(2.1) -- refill the StartNewLife rate-limit bucket
		local d, rd = invoke(server, "StartNewLife", p, "Slot1", "Badword Jones")
		eq(d, false)
		eq(rd, "NameFiltered")
	end)

	test("Starts a life, trims whitespace, sets active slot", function()
		task.wait(2.1)
		local success, slot = invoke(server, "StartNewLife", p, "Slot2", "   Riley   Q  ")
		eq(success, true)
		eq(slot, "Slot2")
		local data = DataService.Get(p)
		eq(data.ActiveSlot, "Slot2")
		eq(data.Slots.Slot2.Name, "Riley Q")
		eq(data.Slots.Slot2.Age, 5)
		eq(data.Lifetime.LivesStarted, 1)
	end)

	test("Won't overwrite a used slot unless confirmed", function()
		task.wait(2.1)
		local a, ra = invoke(server, "StartNewLife", p, "Slot2", "Someone")
		eq(a, false)
		eq(ra, "SlotInUse")
		task.wait(2.1)
		local b = invoke(server, "StartNewLife", p, "Slot2", "Someone", true)
		eq(b, true)
		eq(DataService.Get(p).Slots.Slot2.Name, "Someone")
	end)

	section("LifeService: decisions")
	test("First scenario is the Priority opener and is stable across requests", function()
		local _, s1 = LifeService.GetScenario(p)
		local _, s2 = LifeService.GetScenario(p)
		eq(s1.Id, "C_FirstDay")
		eq(s2.Id, s1.Id)
		eq(DataService.Get(p).Slots.Slot2.CurrentScenario, "C_FirstDay")
		ok(#s1.Choices >= 3)
		ok(s1.Choices[1].Preview, "preview present")
	end)

	test("Client payload never contains effects, chances or seeds", function()
		local _, s = LifeService.GetScenario(p)
		for _, c in ipairs(s.Choices) do
			eq(c.Effects, nil)
			eq(c.Outcomes, nil)
		end
		eq(s.Seed, nil)
	end)

	test("Wrong scenario / bad choice / injection attempts are rejected", function()
		eq(select(2, LifeService.MakeChoice(p, "C_PocketMoney", "Save")), "WrongScenario")
		eq(select(2, LifeService.MakeChoice(p, "C_FirstDay", "Nope")), "BadChoice")
		eq(select(2, LifeService.MakeChoice(p, { evil = true }, "Wave")), "BadArgs")
		eq(select(2, LifeService.MakeChoice(p, "C_FirstDay", "../../x")), "BadArgs")
	end)

	test("A choice applies consequences, advances age, and can't be submitted twice", function()
		local before = TableUtil.DeepCopy(DataService.Get(p).Slots.Slot2)
		local success, outcome = LifeService.MakeChoice(p, "C_FirstDay", "Listen")
		eq(success, true)
		ok(outcome.Applied.Intelligence > 0, "intelligence up")
		ok(outcome.Story:find("Someone"), "story personalised")
		local life = DataService.Get(p).Slots.Slot2
		ok(life.Stats.Intelligence > before.Stats.Intelligence)
		eq(life.Traits.Studious, 1)
		eq(life.Flags.Attentive, true)
		eq(life.Age, 6)
		eq(life.ScenarioIndex, 1)
		eq(#life.Decisions, 1)
		eq(#life.Story, 1)
		eq(life.CurrentScenario, false)
		local again, reason = LifeService.MakeChoice(p, "C_FirstDay", "Listen")
		eq(again, false)
		eq(reason, "WrongScenario")
	end)

	test("Locked choices are rejected server-side", function()
		-- Force the playground scenario, where 'Race' needs the Athlete flag.
		DataService.Update(p, function(d)
			d.Slots.Slot2.CurrentScenario = "C_Playground"
		end)
		local _, s = LifeService.GetScenario(p)
		local race
		for _, c in ipairs(s.Choices) do
			if c.Id == "Race" then
				race = c
			end
		end
		ok(race and race.Locked, "Race shown locked")
		ok(race.LockHint and #race.LockHint > 0, "lock hint")
		eq(select(2, LifeService.MakeChoice(p, "C_Playground", "Race")), "ChoiceLocked")
		DataService.Update(p, function(d)
			d.Slots.Slot2.Flags.Athlete = true
		end)
		local _, s2 = LifeService.GetScenario(p)
		for _, c in ipairs(s2.Choices) do
			if c.Id == "Race" then
				eq(c.Locked, false, "unlocked after flag")
			end
		end
		eq((LifeService.MakeChoice(p, "C_Playground", "Race")), true)
	end)

	test("Outcomes are deterministic for the same life state (no reroll by rejoining)", function()
		local function run(seed)
			local h = bootServer({ JobId = "det-" .. seed })
			local LS = h.require("ServerScriptService.Server.Services.LifeService")
			local DS = h.require("ServerScriptService.Server.Services.DataService")
			local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
			local player = h.addPlayer(900, "Det")
			task.wait(0.05)
			DS.Update(player, function(d)
				d.Slots.Slot1 = DT.NewLife("Det", seed)
				d.ActiveSlot = "Slot1"
			end)
			local trail = {}
			local rng = H.Random.new(7)
			for _ = 1, 6 do
				local _, sc = LS.GetScenario(player)
				local open = {}
				for _, c in ipairs(sc.Choices) do
					if not c.Locked then
						table.insert(open, c)
					end
				end
				local pick = open[rng:NextInteger(1, #open)]
				local _, o = LS.MakeChoice(player, sc.Id, pick.Id)
				table.insert(trail, sc.Id .. ":" .. pick.Id .. ":" .. tostring(o.Lucky))
			end
			h.close()
			return table.concat(trail, ",")
		end
		eq(run(12345), run(12345))
	end)

	section("LifeService: full childhood simulation")
	test("300 random lives all complete Childhood and stay valid", function()
		local h = bootServer({ JobId = "sim" })
		local LS = h.require("ServerScriptService.Server.Services.LifeService")
		local DS = h.require("ServerScriptService.Server.Services.DataService")
		local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
		local TU = h.require("ReplicatedStorage.Shared.Util.TableUtil")
		local player = h.addPlayer(901, "Sim")
		task.wait(0.05)
		local rng = H.Random.new(99)
		local seenScenarios = {}
		local lucky = 0
		for i = 1, 300 do
			DS.Update(player, function(d)
				d.Slots.Slot1 = DT.NewLife("Sim" .. i, rng:NextInteger(1, 2 ^ 30))
				d.ActiveSlot = "Slot1"
			end)
			local steps, status, outcome = playStage(h, player, LS, rng)
			eq(status, "StageCompleted", "life " .. i)
			eq(steps, 6, "life " .. i .. " steps")
			eq(outcome.CompletedStageName, "Childhood")
			eq(outcome.Age, 13)
			eq(outcome.Stage, 2)
			local life = DS.Get(player).Slots.Slot1
			for stat, value in pairs(life.Stats) do
				ok(value >= 0 and value <= 100, stat .. " in range")
			end
			ok(TU.IsSerializable(DS.Get(player)), "serializable")
			eq(#life.Reveals, 1, "stage snapshot recorded")
			for _, dec in ipairs(life.Decisions) do
				seenScenarios[dec.S] = true
			end
			for _, ev in ipairs(life.Story) do
				ok(not ev.Text:find("{name}"), "name substituted")
			end
			if outcome.Lucky then
				lucky += 1
			end
		end
		local count = 0
		for _ in pairs(seenScenarios) do
			count += 1
		end
		ok(count >= 10, "variety: saw " .. count .. " different scenarios")
		-- Next stage has no content yet in this build.
		local okS, reason = LS.GetScenario(player)
		eq(okS, false)
		eq(reason, "StageNotAvailable")
		h.close()
	end)

	test("Life persists across leave/rejoin with the same pending scenario", function()
		local h = bootServer({ JobId = "persist-1" })
		local LS = h.require("ServerScriptService.Server.Services.LifeService")
		local DS = h.require("ServerScriptService.Server.Services.DataService")
		local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
		local player = h.addPlayer(902, "Persist")
		task.wait(0.05)
		DS.Update(player, function(d)
			d.Slots.Slot3 = DT.NewLife("Persist", 4444)
			d.ActiveSlot = "Slot3"
		end)
		local _, first = LS.GetScenario(player)
		LS.MakeChoice(player, first.Id, first.Choices[1].Id)
		local _, pending = LS.GetScenario(player)
		h.removePlayer(player)
		task.wait(0.05)

		local h2 = H.new({ Quiet = true, JobId = "persist-2", DataStoreService = {
			GetDataStore = function()
				return h.store
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		} })
		h2.run("ServerScriptService.Server.Main")
		local again = h2.addPlayer(902, "Persist")
		task.wait(0.05)
		local LS2 = h2.require("ServerScriptService.Server.Services.LifeService")
		local _, resumed = LS2.GetScenario(again)
		eq(resumed.Id, pending.Id, "same pending scenario after rejoin")
		eq(resumed.ScenarioNumber, 2)
		h2.close()
		h.close()
	end)

	test("DeleteLife and ContinueLife validate slots", function()
		eq(select(2, invoke(server, "ContinueLife", p, "Slot1")), "EmptySlot")
		eq((invoke(server, "ContinueLife", p, "Slot2")), true)
		eq((invoke(server, "DeleteLife", p, "Slot2")), true)
		eq(DataService.Get(p).Slots.Slot2, false)
		eq(select(2, LifeService.GetScenario(p)), "NoLife")
	end)

	server.close()
end
