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
		ok(#life.Story >= 1, "story logged")
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

	section("LifeService: full-lifetime simulation")
	test("400 random lives all reach the end, stay valid and cover the content", function()
		local serde = require("@lune/serde")
		local h = bootServer({ JobId = "sim" })
		local LS = h.require("ServerScriptService.Server.Services.LifeService")
		local DS = h.require("ServerScriptService.Server.Services.DataService")
		local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
		local TU = h.require("ReplicatedStorage.Shared.Util.TableUtil")
		local SC = h.require("ServerScriptService.Server.Content.Scenarios")
		local CR = h.require("ReplicatedStorage.Shared.Data.Careers")
		local player = h.addPlayer(901, "Sim")
		task.wait(0.05)
		local rng = H.Random.new(99)
		local LIVES = 400
		local seen, events, careers, problems = {}, {}, {}, {}
		local totals = { Money = 0, Married = 0, Kids = 0, Uni = 0, Retired = 0, Home = 0, Millionaire = 0, Broke = 0 }
		local largest = 0
		for i = 1, LIVES do
			DS.Update(player, function(d)
				d.Slots.Slot1 = DT.NewLife("Sim" .. i, rng:NextInteger(1, 2 ^ 30))
				d.ActiveSlot = "Slot1"
			end)
			local steps, finished = 0, false
			while steps < 60 do
				-- Behave a bit like a player: sometimes use People/Money actions and change focus.
				local life = DS.Get(player).Slots.Slot1
				if rng:NextNumber() < 0.5 and #life.People > 0 then
					local person = life.People[rng:NextInteger(1, #life.People)]
					LS.Interact(player, person.Id, ({ "Time", "Gift", "Talk" })[rng:NextInteger(1, 3)])
				end
				if rng:NextNumber() < 0.15 then
					LS.MeetPeople(player, if rng:NextNumber() < 0.5 then "Friend" else "Love")
				end
				if rng:NextNumber() < 0.1 then
					LS.SetFocus(player, ({ "Balanced", "Career", "Family", "Health", "Social", "Money" })[rng:NextInteger(1, 6)])
				end
				if life.Age >= 18 and life.Money > 1000 and rng:NextNumber() < 0.2 then
					LS.Invest(player, math.floor(life.Money * rng:NextNumber()))
				end
				if (life.Investments or 0) > 1000 and rng:NextNumber() < 0.1 then
					LS.Withdraw(player, math.floor(life.Investments * rng:NextNumber()))
				end
				if #life.Loans > 0 and life.Money > 1000 and rng:NextNumber() < 0.1 then
					LS.RepayLoan(player, 1, math.floor(math.min(life.Money, life.Loans[1].Balance)))
				end
				local okS, sc = LS.GetScenario(player)
				if not okS then
					table.insert(problems, ("life %d: GetScenario failed (%s) at age %d stage %d"):format(i, tostring(sc), DS.Get(player).Slots.Slot1.Age, DS.Get(player).Slots.Slot1.Stage))
					break
				end
				seen[sc.Id] = true
				local open = {}
				for _, c in ipairs(sc.Choices) do
					if not c.Locked then
						table.insert(open, c)
					end
				end
				if #open < 2 then
					problems[#problems + 1] = ("%s offered only %d unlocked choice(s)"):format(sc.Id, #open)
				end
				local pick = open[rng:NextInteger(1, #open)]
				local okC, out = LS.MakeChoice(player, sc.Id, pick.Id)
				assert(okC, "MakeChoice failed: " .. tostring(out))
				steps += 1
				if out.Event then
					events[out.Event.Id] = (events[out.Event.Id] or 0) + 1
				end
				if out.LifeCompleted then
					finished = true
					break
				end
			end
			local data = DS.Get(player)
			local life = data.Slots.Slot1
			eq(finished, true, "life " .. i .. " finished")
			eq(steps, 38, "life " .. i .. " decisions")
			eq(life.Age, 85, "life " .. i .. " final age")
			eq(#life.Reveals, 6, "a reveal snapshot per stage")
			for stat, value in pairs(life.Stats) do
				ok(value >= 0 and value <= 100, stat .. " in range")
			end
			ok(life.Money >= 0 and life.Money % 1 == 0, "money is a non-negative integer")
			ok((life.Investments or 0) >= 0, "investments never negative")
			for _, person in ipairs(life.People) do
				ok(person.Bond >= 0 and person.Bond <= 100, "bond in range")
			end
			local partners = 0
			for _, person in ipairs(life.People) do
				if person.Role == "Partner" then
					partners += 1
				end
			end
			ok(partners <= 1, "at most one partner at a time")
			eq(life.Relationships.Partner, partners == 1, "Relationships counters in sync")
			ok(TU.IsSerializable(data), "serializable")
			local size = #serde.encode("json", data)
			largest = math.max(largest, size)
			for flag in pairs(life.Flags) do
				local career = flag:match("^Was_(.+)$")
				if career then
					careers[career] = true
				end
			end
			if life.Flags.Was_Doctor then
				ok(CR.EducationRank[life.Education] >= 2, "doctors have a degree")
			end
			totals.Money += life.Money
			totals.Married += if life.Relationships.Married then 1 else 0
			totals.Kids += if life.Relationships.Children > 0 then 1 else 0
			totals.Uni += if CR.EducationRank[life.Education] >= 2 then 1 else 0
			totals.Retired += if life.Flags.Retired then 1 else 0
			totals.Home += if life.Assets.House or life.Assets.Mansion or life.Assets.Apartment then 1 else 0
			totals.Millionaire += if life.Money >= 1e6 then 1 else 0
			totals.Broke += if life.Money < 1000 then 1 else 0
		end
		eq(#problems, 0, table.concat(problems, "; "))

		local unseen = {}
		for _, sc in ipairs(SC.All) do
			if not seen[sc.Id] then
				table.insert(unseen, sc.Id)
			end
		end
		local eventKinds = 0
		for _ in pairs(events) do
			eventKinds += 1
		end
		local careerKinds = 0
		for _ in pairs(careers) do
			careerKinds += 1
		end
		print(("      scenarios: %d/%d seen%s"):format(#SC.All - #unseen, #SC.All, if #unseen > 0 then " (unseen: " .. table.concat(unseen, ", ") .. ")" else ""))
		print(("      events: %d/%d kinds seen; careers reached: %d; largest save: %.1f KB"):format(eventKinds, #SC.Events, careerKinds, largest / 1024))
		print(("      endings: avg money %s · married %d%% · kids %d%% · degree %d%% · retired %d%% · homeowner %d%% · millionaire %d%% · broke %d%%"):format(
			tostring(math.floor(totals.Money / LIVES)), totals.Married * 100 // LIVES, totals.Kids * 100 // LIVES, totals.Uni * 100 // LIVES,
			totals.Retired * 100 // LIVES, totals.Home * 100 // LIVES, totals.Millionaire * 100 // LIVES, totals.Broke * 100 // LIVES))
		ok(#unseen <= math.floor(#SC.All * 0.1), "at least 90% of scenarios reachable by random play")
		ok(eventKinds >= 20, "a wide variety of random events")
		ok(careerKinds >= 14, "many different careers reached")
		ok(largest < 64 * 1024, "save stays small")
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

	section("Life engine: conditions, effects, income, events")
	local h = bootServer({ JobId = "engine" })
	local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local Conditions = h.require("ServerScriptService.Server.Lib.Conditions")
	local Consequences = h.require("ServerScriptService.Server.Lib.Consequences")
	local Yearly = h.require("ServerScriptService.Server.Lib.Yearly")
	local RandomEvents = h.require("ServerScriptService.Server.Lib.RandomEvents")
	local SC = h.require("ServerScriptService.Server.Content.Scenarios")
	local CR = h.require("ReplicatedStorage.Shared.Data.Careers")
	local rng = H.Random.new(5)

	test("Career, education, relationship and asset effects apply and report", function()
		local life = DT.NewLife("Eng", 1)
		life.Age = 25
		local s1 = Consequences.Apply(life, { Career = "Doctor", Education = "University", Partner = true }, rng)
		eq(life.Career.Id, "Doctor")
		eq(life.Career.Level, 1)
		eq(life.Education, "University")
		eq(life.Relationships.Partner, true)
		eq(life.Flags.Was_Doctor, true)
		ok(#s1.LifeChanges >= 3, "life changes listed")
		Consequences.Apply(life, { Education = "School" }, rng)
		eq(life.Education, "University", "education never goes down")
		Consequences.Apply(life, { Married = true, Children = 2, Promote = 1 }, rng)
		eq(life.Relationships.Married, true)
		eq(life.Relationships.Children, 2)
		eq(life.Career.Level, 2)
		life.Money = 300000
		Consequences.Apply(life, { Assets = { "House" }, Money = -260000 }, rng)
		eq(life.Money, 40000)
		eq(life.Assets.House, true)
		ok(life.Stats.Wealth > 60, "house counts toward wealth")
		Consequences.Apply(life, { MoneyPercent = -0.5 }, rng)
		eq(life.Money, 20000)
		Consequences.Apply(life, { Married = false, Partner = false }, rng)
		eq(life.Relationships.Married, false)
		Consequences.Apply(life, { Retire = true }, rng)
		eq(life.Flags.Retired, true)
		eq(life.Career.Id, "None")
		ok(life.PeakSalary >= CR.SalaryAt("Doctor", 2), "peak salary kept for pension")
	end)

	test("Conditions check careers, education, family and assets", function()
		local life = DT.NewLife("Eng", 1)
		life.Age = 30
		ok(Conditions.Check(life, { HasCareer = false }))
		ok(not Conditions.Check(life, { HasCareer = true }))
		life.Career = { Id = "Lawyer", Level = 3, YearsInRole = 0 }
		life.Education = "University"
		ok(Conditions.Check(life, { Careers = { "Doctor", "Lawyer" }, MinCareerLevel = 3, MinEducation = "School" }))
		ok(not Conditions.Check(life, { NotCareers = { "Lawyer" } }))
		ok(not Conditions.Check(life, { MaxEducation = "School" }))
		life.Relationships.Children = 1
		ok(Conditions.Check(life, { MinChildren = 1, Partner = false }))
		ok(not Conditions.Check(life, { MaxChildren = 0 }))
		life.Assets.Apartment = true
		ok(Conditions.Check(life, { AnyAssets = { "House", "Apartment" }, NotAssets = { "Mansion" } }))
		ok(not Conditions.Check(life, { Assets = { "House" } }))
	end)

	test("Yearly income: salary savings, unemployment costs, children, pension", function()
		local life = DT.NewLife("Eng", 1)
		life.Career = { Id = "Teacher", Level = 1, YearsInRole = 0 }
		local summary = Consequences.NewSummary()
		local rate = Yearly.BaseSavingsRate
		local r = Yearly.Advance(life, 26, 2, rng, summary)
		eq(r.Income, math.floor(CR.SalaryAt("Teacher", 1) * rate - Yearly.RentCost) * 2, "salary savings minus rent")
		eq(life.Career.YearsInRole, 2)
		life.Assets.Apartment = true -- homeowners pay no rent
		local People = h.require("ReplicatedStorage.Shared.Util.People")
		life.Age = 28
		People.Add(life, "Child", rng) -- born this year: costs money until 18
		local before = life.Money
		Yearly.Advance(life, 28, 1, rng, Consequences.NewSummary())
		eq(life.Money - before, math.floor(CR.SalaryAt("Teacher", 1) * rate - Yearly.ChildCost))
		-- Unemployed adults lose savings but never go below zero.
		life.Career = { Id = "None", Level = 0, YearsInRole = 0 }
		life.Money = 3000
		Yearly.Advance(life, 30, 2, rng, Consequences.NewSummary())
		eq(life.Money, 0)
		-- Retired: pension from peak salary (the child is grown up by 70).
		life.Flags.Retired = true
		life.PeakSalary = 100000
		Yearly.Advance(life, 70, 1, rng, Consequences.NewSummary())
		eq(life.Money, math.floor(100000 * Yearly.PensionShare * Yearly.BaseSavingsRate))
	end)

	test("Ageing lowers Health after 50", function()
		local life = DT.NewLife("Eng", 1)
		local s = Consequences.NewSummary()
		Yearly.Advance(life, 70, 4, rng, s)
		ok(life.Stats.Health < 50, "health declines")
		ok((s.Applied.Health or 0) < 0)
	end)

	test("Random events respect circumstances", function()
		local life = DT.NewLife("Eng", 1)
		life.Stage = 4
		life.Age = 30
		local function eligibleIds()
			local ids = {}
			for _, e in ipairs(RandomEvents.Eligible(life, SC.Events)) do
				ids[e.Id] = true
			end
			return ids
		end
		local ids = eligibleIds()
		eq(ids.E_LoseJob, nil, "can't lose a job you don't have")
		eq(ids.E_Twins, nil, "twins need a marriage")
		eq(ids.E_BadInvestment, nil, "can't lose savings you don't have")
		ok(ids.E_Lottery, "anyone can win the lottery")
		life.Career = { Id = "Engineer", Level = 1, YearsInRole = 0 }
		life.Money = 50000
		ids = eligibleIds()
		ok(ids.E_LoseJob and ids.E_BadInvestment, "now eligible")
		table.insert(life.Events, "E_Lottery")
		eq(eligibleIds().E_Lottery, nil, "once per life")
	end)

	test("Legendary events are extremely rare", function()
		local Config = h.require("ReplicatedStorage.Shared.Config")
		local life = DT.NewLife("Eng", 1)
		life.Stage = 4
		life.Age = 30
		local r = H.Random.new(1234)
		local legendary, any = 0, 0
		for _ = 1, 20000 do
			local e = RandomEvents.Roll(life, SC.Events, r)
			if e then
				any += 1
				if e.Rarity == "Legendary" then
					legendary += 1
				end
			end
		end
		local rate = any / 20000
		ok(math.abs(rate - Config.EventChance) < 0.02, "event rate ≈ EventChance (" .. rate .. ")")
		ok(legendary / 20000 < 0.005, "legendary < 0.5% of decisions (" .. legendary .. ")")
	end)
	h.close()

	section("People, bonds, loans, investments, lifestyle (Phase 4)")
	local h4 = bootServer({ JobId = "phase4" })
	local DT4 = h4.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local People = h4.require("ReplicatedStorage.Shared.Util.People")
	local Budget = h4.require("ReplicatedStorage.Shared.Util.Budget")
	local Cq = h4.require("ServerScriptService.Server.Lib.Consequences")
	local Yr = h4.require("ServerScriptService.Server.Lib.Yearly")
	local Act = h4.require("ServerScriptService.Server.Lib.Actions")
	local LS4 = h4.require("ServerScriptService.Server.Services.LifeService")
	local DS4 = h4.require("ServerScriptService.Server.Services.DataService")
	local r4 = H.Random.new(77)

	test("Every new life starts with two named parents", function()
		local life = DT4.NewLife("Robin", 42)
		local parents = People.ByRole(life, "Parent")
		eq(#parents, 2)
		ok(parents[1].Name ~= parents[2].Name and parents[1].Name ~= "Robin", "distinct names")
		eq(DT4.NewLife("Robin", 42).People[1].Name, parents[1].Name, "names are deterministic per seed")
	end)

	test("Partner, marriage, children, friends and exes are real people", function()
		local life = DT4.NewLife("Robin", 1)
		life.Age = 28
		local sum = Cq.Apply(life, { Partner = true }, r4)
		local partner = People.Partner(life)
		ok(partner and life.Relationships.Partner, "partner created")
		ok(sum.LifeChanges[1]:find(partner.Name), "named in life changes")
		Cq.Apply(life, { Married = true, Children = 2, Friends = 2 }, r4)
		eq(life.Relationships.Married, true)
		eq(#People.ByRole(life, "Child"), 2)
		eq(life.Relationships.Children, 2)
		eq(life.Relationships.Friends, 2)
		Cq.Apply(life, { Meet = "BestFriend" }, r4)
		eq(#People.ByRole(life, "BestFriend"), 1)
		eq(life.Relationships.Friends, 2, "best friend promoted from friends")
		Cq.Apply(life, { Friends = -1 }, r4)
		eq(life.Relationships.Friends, 1)
		Cq.Apply(life, { Partner = false }, r4)
		eq(People.Partner(life), nil)
		eq(#People.ByRole(life, "Ex"), 1)
		eq(life.Relationships.Married, false)
		Cq.Apply(life, { Reunite = true }, r4)
		eq(People.Partner(life).Name, partner.Name, "reunited with the ex")
		Cq.Apply(life, { Farewell = "Parent" }, r4)
		eq(#People.ByRole(life, "Parent"), 1)
	end)

	test("Bond effects report per-person changes and clamp to 0–100", function()
		local life = DT4.NewLife("Robin", 1)
		local sum = Cq.Apply(life, { Bond = { Parent = 50 } }, r4)
		eq(#sum.BondChanges, 2)
		for _, p in ipairs(People.ByRole(life, "Parent")) do
			eq(p.Bond, 100)
		end
		Cq.Apply(life, { Bond = { All = -500 } }, r4)
		eq(People.ByRole(life, "Parent")[1].Bond, 0)
	end)

	test("Bonds fade with time; a Family focus makes them grow", function()
		local life = DT4.NewLife("Robin", 1)
		life.Age = 30
		Cq.Apply(life, { Married = true }, r4)
		local partner = People.Partner(life)
		local start = partner.Bond
		Yr.Advance(life, 30, 5, r4, Cq.NewSummary())
		ok(partner.Bond < start, "partner bond fades when neglected")
		life.Focus = "Family"
		local mid = partner.Bond
		Yr.Advance(life, 35, 5, r4, Cq.NewSummary())
		ok(partner.Bond > mid, "family focus grows bonds")
	end)

	test("A badly neglected relationship can end on its own", function()
		local ended = 0
		for i = 1, 40 do
			local life = DT4.NewLife("Robin", i)
			life.Age = 30
			Cq.Apply(life, { Partner = true }, r4)
			People.Partner(life).Bond = 5
			local s4 = Cq.NewSummary()
			Yr.Advance(life, 30, 4, H.Random.new(i), s4)
			if not People.Partner(life) then
				ended += 1
			end
		end
		ok(ended > 10 and ended < 40, "some (not all) neglected couples split: " .. ended)
	end)

	test("Close bonds make you happier over the years", function()
		local function happinessAfter(bond)
			local life = DT4.NewLife("Robin", 3)
			life.Age = 30
			Cq.Apply(life, { Married = true, Children = 1 }, r4)
			for _, p in ipairs(life.People) do
				p.Bond = bond
			end
			life.Focus = "Family" -- keep bonds steady
			Yr.Advance(life, 30, 6, H.Random.new(1), Cq.NewSummary())
			return life.Stats.Happiness
		end
		ok(happinessAfter(95) > happinessAfter(10) + 3, "high bonds → happier")
	end)

	test("Loans: amortised payments, early repayment, debt counts against net worth", function()
		local life = DT4.NewLife("Robin", 1)
		life.Age = 30
		life.Money = 60000
		Cq.Apply(life, { Assets = { "House" }, Money = -52000, Loan = { Kind = "Mortgage", Amount = 208000 } }, r4)
		eq(#life.Loans, 1)
		local loan = life.Loans[1]
		eq(loan.Payment, Budget.LoanPayment(208000, 0.04, 25))
		eq(Budget.NetWorth(life), 8000 + 260000 - 208000)
		life.Career = { Id = "Doctor", Level = 3, YearsInRole = 0 }
		Yr.Advance(life, 30, 25, r4, Cq.NewSummary())
		eq(#life.Loans, 0, "a mortgage is paid off after its term")
		-- Repay effect & action
		Cq.Apply(life, { Loan = { Kind = "Student", Amount = 5000 } }, r4)
		life.Money = 10000
		local okR, res = Act.RepayLoan(life, 1, 5000)
		ok(okR and res.PaidOff, "repaid in full")
		eq(life.Money, 5000)
		eq(select(2, Act.RepayLoan(life, 1, 100)), "BadLoan")
	end)

	test("Investing is validated and the market moves over time", function()
		local life = DT4.NewLife("Robin", 1)
		life.Age = 16
		life.Money = 10000
		eq(select(2, Act.Invest(life, 100)), "TooYoung")
		life.Age = 30
		eq(select(2, Act.Invest(life, -5)), "BadAmount")
		eq(select(2, Act.Invest(life, 1.5)), "BadAmount")
		eq(select(2, Act.Invest(life, 20000)), "BadAmount")
		eq(select(2, Act.Invest(life, 0 / 0)), "BadAmount")
		ok((Act.Invest(life, 10000)))
		eq(life.Money, 0)
		eq(life.Investments, 10000)
		eq(select(2, Act.Withdraw(life, 10001)), "BadAmount")
		local total = 0
		for i = 1, 200 do
			local l = DT4.NewLife("I", i)
			l.Investments = 10000
			Yr.Advance(l, 30, 10, H.Random.new(i), Cq.NewSummary())
			total += l.Investments
		end
		ok(total / 200 > 13000, "average 10-year growth is positive: " .. math.floor(total / 200))
		Cq.Apply(life, { InvestPercent = -0.5 }, r4)
		eq(life.Investments, 5000)
	end)

	test("People actions: two per decision, validated, gifts cost money", function()
		local life = DT4.NewLife("Robin", 1)
		life.Age = 10
		life.Money = 15
		local parent = People.ByRole(life, "Parent")[1]
		local before = parent.Bond
		eq(Act.ActionsLeft(life), 2)
		ok((Act.Interact(life, parent.Id, "Time", r4)))
		ok(parent.Bond > before, "bond grows")
		ok((Act.Interact(life, parent.Id, "Gift", r4)))
		eq(life.Money, 5, "gift cost $10 at age 10")
		eq(select(2, Act.Interact(life, parent.Id, "Talk", r4)), "NoActionsLeft")
		table.insert(life.Decisions, { S = "x", C = "y" }) -- a decision refreshes actions
		eq(Act.ActionsLeft(life), 2)
		eq(select(2, Act.Interact(life, parent.Id, "Gift", r4)), "NotEnoughMoney")
		eq(select(2, Act.Interact(life, "p999", "Time", r4)), "NoSuchPerson")
		eq(select(2, Act.Interact(life, parent.Id, "Hug", r4)), "BadAction")
		eq(select(2, Act.Meet(life, "Love", r4)), "TooYoung")
		life.Age = 25
		Cq.Apply(life, { Partner = true }, r4)
		eq(select(2, Act.Meet(life, "Love", r4)), "AlreadyTaken")
	end)

	test("Lifestyle focus is validated and shapes the years", function()
		local life = DT4.NewLife("Robin", 1)
		life.Age = 12
		eq(select(2, Act.SetFocus(life, "Money")), "TooYoung")
		eq(select(2, Act.SetFocus(life, "Partying")), "BadFocus")
		local healthy = DT4.NewLife("A", 5)
		local balanced = DT4.NewLife("B", 5)
		healthy.Focus = "Health"
		Yr.Advance(healthy, 30, 8, H.Random.new(1), Cq.NewSummary())
		Yr.Advance(balanced, 30, 8, H.Random.new(1), Cq.NewSummary())
		ok(healthy.Stats.Health > balanced.Stats.Health + 5, "health focus pays off")
		local saver = DT4.NewLife("C", 5)
		saver.Career = { Id = "Teacher", Level = 2, YearsInRole = 0 }
		local spender = DT4.NewLife("D", 5)
		spender.Career = { Id = "Teacher", Level = 2, YearsInRole = 0 }
		saver.Focus = "Money"
		Yr.Advance(saver, 30, 5, H.Random.new(2), Cq.NewSummary())
		Yr.Advance(spender, 30, 5, H.Random.new(2), Cq.NewSummary())
		ok(saver.Money > spender.Money, "money focus saves more")
	end)

	test("Remotes validate People/Money arguments", function()
		local player = h4.addPlayer(990, "Remote")
		task.wait(0.05)
		DS4.Update(player, function(d)
			d.Slots.Slot1 = DT4.NewLife("Remote", 5)
			d.ActiveSlot = "Slot1"
		end)
		local invoke = function(name, ...)
			return h4.remote(name).OnServerInvoke(player, ...)
		end
		eq(select(2, invoke("Interact", { bad = true }, "Time")), "BadArgs")
		eq(select(2, invoke("Interact", "p1", "Kiss")), "BadArgs")
		eq(select(2, invoke("MeetPeople", "Enemy")), "BadArgs")
		eq(select(2, invoke("SetFocus", "../x")), "BadArgs")
		eq(select(2, invoke("Invest", "100")), "TooYoung")
		local okI, res = invoke("Interact", "p1", "Time")
		eq(okI, true)
		ok(res.Text and res.ActionsLeft == 1, "result returned")
		eq(DS4.Get(player).Slots.Slot1.ActionsUsed, 1)
		eq(LS4.Interact ~= nil, true)
	end)

	test("Old (v1) saves upgrade: partners and children become people", function()
		local old = {
			Version = 1,
			Coins = 5,
			Slots = { Slot1 = { Name = "Legacy", Age = 40, Seed = 9, Stage = 4, Relationships = { Partner = true, Married = true, Children = 2, Friends = 1 }, Stats = {} } },
		}
		local upgraded = DT4.Upgrade(old)
		ok(upgraded, "upgraded")
		eq(upgraded.Version, DT4.CurrentVersion)
		local life = upgraded.Slots.Slot1
		eq(#People.ByRole(life, "Parent"), 2)
		eq(#People.ByRole(life, "Child"), 2)
		eq(#People.ByRole(life, "Friend"), 1)
		local partner = People.Partner(life)
		ok(partner and partner.Married, "married partner kept")
		eq(life.Focus, "Balanced")
		eq(life.Investments, 0)
		ok(type(life.Loans) == "table")
	end)
	h4.close()

	server.close()
end
