--[[
	Multiplayer tests: Life Circles, invites, group events and voting, shared
	fate with independent lives, group Life Reveals, privacy, city events.
	Called from tests/run.luau.
]]

local task = require("@lune/task")

return function(H)
	local test, eq, ok, section = H.test, H.eq, H.ok, H.section
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")

	local function boot()
		local store = MockDataStore.new()
		local server = H.new({
			Quiet = true,
			JobId = "mp",
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
		task.wait(0.02)
		return server
	end

	local server = boot()
	local Party = server.require("ServerScriptService.Server.Services.PartyService")
	local City = server.require("ServerScriptService.Server.Services.CityEventService")
	local DS = server.require("ServerScriptService.Server.Services.DataService")
	local RevealService = server.require("ServerScriptService.Server.Services.RevealService")
	local DT = server.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local People = server.require("ReplicatedStorage.Shared.Util.People")
	local Config = server.require("ReplicatedStorage.Shared.Config")
	local Conditions = server.require("ServerScriptService.Server.Lib.Conditions")
	local Scenarios = server.require("ServerScriptService.Server.Content.Scenarios")
	local Reveal = server.require("ServerScriptService.Server.Lib.Reveal")

	local function player(id, name, age, money)
		local p = server.addPlayer(id, name)
		task.wait(0.03)
		DS.Update(p, function(d)
			local life = DT.NewLife(name .. "Life", id * 7)
			life.Age = age
			life.Stage = if age >= 26 then 4 elseif age >= 19 then 3 elseif age >= 13 then 2 else 1
			life.Money = money or 0
			d.Slots.Slot1 = life
			d.ActiveSlot = "Slot1"
		end)
		return p
	end
	local function fired(remoteName, target)
		local list = {}
		for _, f in ipairs(server.remote(remoteName).Fired) do
			if f.Player == target then
				table.insert(list, f.Args[1])
			end
		end
		return list
	end
	local function last(remoteName, target)
		local list = fired(remoteName, target)
		return list[#list]
	end
	local function life(p)
		return DS.GetActiveLife(p)
	end

	local ana = player(1001, "Ana", 30, 50000)
	local ben = player(1002, "Ben", 27, 30000)
	local cara = player(1003, "Cara", 10, 0)
	local dev = player(1004, "Dev", 40, 20000)
	local eli = player(1005, "Eli", 35, 20000)

	section("Life Circles: invites and membership")
	test("Invites are validated", function()
		eq(select(2, Party.Invite(ana, ana.UserId)), "Self")
		eq(select(2, Party.Invite(ana, 999999)), "NotHere")
		eq(select(2, Party.Invite(ana, "1002")), "NotHere", "user ids must be numbers")
		local okI, res = Party.Invite(ana, ben.UserId)
		ok(okI and res.InviteId, "invite created")
		local got = last("PartyInviteReceived", ben)
		eq(got.FromName, "Ana")
		eq(got.InviteId, res.InviteId)
		eq(select(2, Party.Invite(ana, ben.UserId)), "AlreadyInvited")
		eq(select(2, Party.Respond(cara, res.InviteId, true)), "NoInvite", "only the invited player can answer")
		eq(select(2, Party.Respond(ben, 12345, true)), "BadArgs")
	end)

	test("Accepting creates a circle; both members get its state", function()
		local inviteId = last("PartyInviteReceived", ben).InviteId
		local okR, res = Party.Respond(ben, inviteId, true)
		ok(okR and res.Joined, "joined")
		ok(Party.SameParty(ana, ben), "same circle")
		local state = last("PartyUpdate", ana)
		eq(#state.Members, 2)
		eq(state.LeaderUserId, ana.UserId, "inviter leads")
		eq(last("PartyUpdate", ben).Id, state.Id)
		eq(select(2, Party.Respond(ben, inviteId, true)), "NoInvite", "invites can't be reused")
		eq(select(2, Party.Invite(ana, ben.UserId)), "AlreadyMember")
	end)

	test("Invites expire", function()
		Party.InviteSeconds = 0.05
		local _, res = Party.Invite(ana, dev.UserId)
		task.wait(0.1)
		eq(select(2, Party.Respond(dev, res.InviteId, true)), "Expired")
		Party.InviteSeconds = 45
	end)

	test("Circles hold at most 4 players", function()
		for _, p in ipairs({ cara, dev }) do
			local _, res = Party.Invite(ana, p.UserId)
			ok((Party.Respond(p, res.InviteId, true)), p.Name .. " joined")
		end
		eq(#Party.PartyOf(ana).Members, 4)
		eq(select(2, Party.Invite(ana, eli.UserId)), "PartyFull")
		-- and a stale invite from before the circle filled can't overflow it
		Party.Leave(dev)
		local _, res = Party.Invite(ana, eli.UserId)
		local _, res2 = Party.Invite(ana, dev.UserId)
		ok((Party.Respond(eli, res.InviteId, true)), "Eli joined")
		eq(select(2, Party.Respond(dev, res2.InviteId, true)), "PartyFull")
		Party.Leave(eli)
	end)

	test("Only the leader can remove members; leaving hands over leadership", function()
		eq(select(2, Party.Kick(ben, cara.UserId)), "NotLeader")
		ok((Party.Kick(ana, cara.UserId)), "leader removed Cara")
		eq(Party.PartyOf(cara), nil)
		eq(last("PartyUpdate", cara), false, "Cara told she's out")
		-- Ana leaves: Ben inherits leadership of a 2-person circle → it dissolves.
		local _, res = Party.Invite(ana, cara.UserId)
		Party.Respond(cara, res.InviteId, true)
		Party.Leave(ana)
		local circle = Party.PartyOf(ben)
		ok(circle and circle.Leader == ben, "leadership passed to Ben")
		Party.Leave(cara)
		eq(Party.PartyOf(ben), nil, "a circle of one dissolves")
		eq(last("PartyUpdate", ben), false)
	end)

	test("Remotes are wired and validate input", function()
		local okI, res = server.remote("PartyInvite").OnServerInvoke(ana, ben.UserId)
		eq(okI, true)
		local okR = server.remote("PartyRespond").OnServerInvoke(ben, res.InviteId, true)
		eq(okR, true)
		local okS, state = server.remote("GetPartyState").OnServerInvoke(ben)
		eq(okS, true)
		eq(#state.Members, 2)
		eq(select(2, server.remote("PartyVote").OnServerInvoke(ben, 1, "x")), "NoEvent")
		eq(select(2, server.remote("JoinFriendServer").OnServerInvoke(ben, 123, "abc")), "BadServer")
	end)

	section("Group events: voting, shared fate, independent lives")
	local function startForced(id)
		local circle = Party.PartyOf(ana)
		circle.LastEventAt = -math.huge
		return Party.StartEvent(ana, id)
	end

	test("Only scenarios every member qualifies for are offered", function()
		local _, res = Party.Invite(ana, cara.UserId) -- Cara is 10
		Party.Respond(cara, res.InviteId, true)
		local lives = { life(ana), life(ben), life(cara) }
		local eligible = Party.EligibleScenarios(lives)
		ok(#eligible >= 3, "several group scenarios for a mixed-age circle")
		for _, s in ipairs(eligible) do
			for _, l in ipairs(lives) do
				ok(Conditions.Check(l, s.Requires), s.Id .. " fits age " .. l.Age)
			end
		end
		eq(select(2, startForced("G_Business")), "NotEligible", "no business for a 10-year-old")
		Party.Kick(ana, cara.UserId)
	end)

	test("Everyone votes, majority wins, shared fate, each life changes independently", function()
		local before = {
			ana = { Money = life(ana).Money, Decisions = #life(ana).Decisions, Age = life(ana).Age },
			ben = { Money = life(ben).Money, Decisions = #life(ben).Decisions, Age = life(ben).Age },
			cara = { Money = life(cara).Money, Stats = table.clone(life(cara).Stats) },
		}
		local okE, res = startForced("G_Business")
		ok(okE, "event started")
		local payload = last("GroupEvent", ben)
		eq(payload.EventId, res.EventId)
		eq(payload.Title, "Start a Business Together")
		eq(#payload.Choices, 4)
		ok((Party.Vote(ana, res.EventId, "Startup")), "Ana voted")
		eq(Party.PartyOf(ana).Event ~= nil, true, "waits for everyone")
		ok(last("GroupVote", ben).Votes[tostring(ana.UserId)] == "Startup", "live tally shared")
		ok((Party.Vote(ben, res.EventId, "Startup")), "Ben voted")
		task.wait(0.05)
		eq(Party.PartyOf(ana).Event, nil, "resolved once everyone voted")
		local ra, rb = last("GroupEventResult", ana), last("GroupEventResult", ben)
		eq(ra.ChoiceId, "Startup")
		eq(rb.ChoiceId, "Startup")
		eq(ra.MoneyDelta, rb.MoneyDelta, "shared fate: the startup did the same for both")
		eq(life(ana).Money, before.ana.Money + ra.MoneyDelta)
		eq(life(ben).Money, before.ben.Money + rb.MoneyDelta)
		eq(#life(ana).Decisions, before.ana.Decisions, "group events don't use up a decision")
		eq(life(ana).Age, before.ana.Age, "or age anyone")
		-- Cara is not in the circle: untouched.
		eq(life(cara).Money, before.cara.Money)
		for stat, v in pairs(before.cara.Stats) do
			eq(life(cara).Stats[stat], v, "outsider's " .. stat .. " unchanged")
		end
		-- Real friends appear in each other's lives, once.
		local friendInAna = nil
		for _, p in ipairs(life(ana).People) do
			if p.PlayerUserId == ben.UserId then
				friendInAna = p
			end
		end
		ok(friendInAna and friendInAna.Name == "BenLife", "Ben's character is in Ana's People")
		eq(life(ana).Shared[#life(ana).Shared].Title, "Start a Business Together", "shared moment recorded")
		eq(life(ana).Shared[#life(ana).Shared].With[1], "BenLife")
	end)

	test("Locked choices can't be voted for; votes are validated", function()
		DS.Update(ben, function(d)
			d.Slots.Slot1.Money = 0
		end)
		local _, res = startForced("G_Holiday")
		local payload = last("GroupEvent", ana)
		local resort = nil
		for _, c in ipairs(payload.Choices) do
			if c.Id == "Resort" then
				resort = c
			end
		end
		ok(resort.Locked and resort.LockHint, "too expensive for Ben, so locked for the group")
		eq(select(2, Party.Vote(ana, res.EventId, "Resort")), "ChoiceLocked")
		eq(select(2, Party.Vote(ana, res.EventId + 1, "Trek")), "NoEvent")
		eq(select(2, Party.Vote(cara, res.EventId, "Trek")), "NoEvent", "outsiders can't vote")
		eq(select(2, Party.Vote(ana, res.EventId, "Nope")), "BadChoice")
		eq(select(2, Party.Vote(ana, res.EventId, "City")), "ChoiceLocked", "City break costs $1,200 each")
		ok((Party.Vote(ana, res.EventId, "Staycation")), "vote")
		ok((Party.Vote(ana, res.EventId, "Trek")), "votes can change")
		ok((Party.Vote(ben, res.EventId, "Staycation")), "Ben votes differently")
		task.wait(0.05)
		local result = last("GroupEventResult", ana)
		eq(result.Tie, true, "1–1 is a tie")
		ok(result.ChoiceId == "Trek" or result.ChoiceId == "Staycation", "tie settled between the tied choices")
		eq(last("GroupEventResult", ben).ChoiceId, result.ChoiceId, "everyone gets the same decision")
	end)

	test("Cooldown between group events", function()
		eq(select(2, Party.StartEvent(ana)), "Cooldown")
	end)

	test("Nobody voted: fate decides when time runs out", function()
		Party.VoteSeconds = 0.1
		local _, res = startForced("G_DayOut")
		task.wait(0.25)
		local result = last("GroupEventResult", ben)
		eq(result.EventId, res.EventId)
		eq(result.NoVotes, true)
		ok(result.ChoiceId ~= nil, "a choice was still made")
		Party.VoteSeconds = 40
	end)

	test("Someone leaving mid-vote doesn't block the others", function()
		local _, res = Party.Invite(ana, dev.UserId)
		Party.Respond(dev, res.InviteId, true)
		local _, ev = startForced("G_DayOut")
		Party.Vote(ana, ev.EventId, "Beach")
		Party.Vote(ben, ev.EventId, "Beach")
		eq(Party.PartyOf(ana).Event ~= nil, true, "still waiting for Dev")
		Party.Leave(dev)
		task.wait(0.05)
		eq(Party.PartyOf(ana).Event, nil, "resolved without Dev")
		eq(last("GroupEventResult", ana).ChoiceId, "Beach")
	end)

	test("Every member needs a life in progress", function()
		DS.Update(ben, function(d)
			d.Slots.Slot1.Completed = true
		end)
		Party.PartyOf(ana).LastEventAt = -math.huge
		local _, reason = Party.StartEvent(ana)
		DS.Update(ben, function(d)
			d.Slots.Slot1.Completed = false
		end)
		eq(reason, "NotEveryoneReady")
	end)

	test("Shared moments appear in the Final Reveal", function()
		local entry = Reveal.Final(life(ana), 1)
		local found = false
		for _, m in ipairs(entry.Moments) do
			if m:find("With BenLife") then
				found = true
			end
		end
		ok(found, "final reveal remembers moments with friends")
	end)

	section("Group Life Reveal & privacy")
	test("Circle members see each other's futures (they count as friends)", function()
		local cards = RevealService.CardsFor(ana)
		local benCard, caraCard = nil, nil
		for _, c in ipairs(cards) do
			if c.UserId == ben.UserId then
				benCard = c
			elseif c.UserId == cara.UserId then
				caraCard = c
			end
		end
		ok(benCard.Card, "circle member visible with default (Friends) privacy")
		eq(caraCard.Hidden, true, "a stranger outside the circle stays private")
	end)

	test("Group reveal: everyone gets the cards and a 'most likely to' board", function()
		ok((Party.StartReveal(ben)), "anyone in the circle can start one")
		local pa, pb = last("GroupReveal", ana), last("GroupReveal", ben)
		eq(#pa.Cards, 2)
		eq(pa.SessionId, pb.SessionId)
		ok(#pa.Superlatives > 0, "superlatives")
		eq(select(2, Party.StartReveal(ana)), "Cooldown")
	end)

	test("Privacy still wins inside a circle", function()
		DS.Update(ben, function(d)
			d.Privacy.ShareReveals = "Nobody"
		end)
		Party.PartyOf(ana).LastRevealAt = -math.huge
		Party.StartReveal(ana)
		local payload = last("GroupReveal", ana)
		for _, c in ipairs(payload.Cards) do
			if c.UserId == ben.UserId then
				eq(c.Hidden, true, "Ben chose Nobody")
			end
		end
		for _, s in ipairs(payload.Superlatives) do
			ok(s.UserId ~= ben.UserId, "hidden players aren't ranked")
		end
		local own = last("GroupReveal", ben)
		for _, c in ipairs(own.Cards) do
			if c.UserId == ben.UserId then
				ok(c.Card, "Ben still sees his own card")
			end
		end
		DS.Update(ben, function(d)
			d.Privacy.ShareReveals = "Friends"
		end)
	end)

	section("City events (whole server)")
	test("Everyone with a life is invited; joining changes only your own life", function()
		Config.CityEventJoinSeconds = 0.3
		local okT, res = City.Trigger("CE_Festival")
		ok(okT, "triggered")
		for _, p in ipairs({ ana, ben, cara, dev, eli }) do
			eq(last("CityEvent", p).EventId, res.EventId, p.Name .. " invited")
		end
		local caraHappy = life(cara).Stats.Happiness
		local okJ, result = City.Respond(ana, res.EventId, true)
		ok(okJ and result.Joined and result.Story:find("AnaLife"), "Ana joined")
		eq(select(2, City.Respond(ana, res.EventId, true)), "AlreadyResponded")
		ok((City.Respond(cara, res.EventId, false)), "Cara skipped")
		eq(life(cara).Stats.Happiness, caraHappy, "skipping changes nothing")
		eq(select(2, City.Respond(ana, res.EventId + 1, true)), "NoEvent")
		task.wait(0.4)
		local summary = server.remote("CityEventSummary").Fired
		local s = summary[#summary].Args[1]
		eq(s.EventId, res.EventId)
		eq(s.Joined, 1)
		eq(s.Invited, 5)
		eq(select(2, City.Respond(ben, res.EventId, true)), "NoEvent", "too late")
	end)

	test("City outcomes are shared; requirements are per player", function()
		DS.Update(ana, function(d)
			d.Slots.Slot1.Money = 50000
		end)
		DS.Update(ben, function(d)
			d.Slots.Slot1.Money = 50000
		end)
		local _, res = City.Trigger("CE_Market")
		eq(last("CityEvent", cara).Eligible, false, "a 10-year-old can't trade stocks")
		eq(select(2, City.Respond(cara, res.EventId, true)), "NotEligible")
		local _, ra = City.Respond(ana, res.EventId, true)
		local _, rb = City.Respond(ben, res.EventId, true)
		eq(ra.MoneyDelta, rb.MoneyDelta, "everyone who joined shared the same market result")
		task.wait(0.4)
		Config.CityEventJoinSeconds = 45
	end)

	test("Group and city content validates", function()
		eq(#Scenarios.Issues, 0, table.concat(Scenarios.Issues, "; "))
		ok(#Scenarios.Group >= 10, "plenty of group scenarios")
		ok(#Scenarios.City >= 5, "plenty of city events")
		local kid = DT.NewLife("Kid", 1)
		ok(#Party.EligibleScenarios({ kid, kid }) >= 2, "even two 5-year-olds have group events")
		local _ = People
	end)

	server.close()
end
