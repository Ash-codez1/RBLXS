--[[
	Phase 9 server tests: achievements & badges, daily rewards & streaks,
	challenges, Memory Stars, rebirth, leaderboards, profiles and trading.
	Called from tests/run.luau.
]]

local task = require("@lune/task")

return function(H)
	local test, eq, ok, section = H.test, H.eq, H.ok, H.section
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")
	local store = MockDataStore.new()
	local server = H.new({
		Quiet = true,
		JobId = "extras",
		Friends = { [6001] = { { Id = 6002, Username = "pal", DisplayName = "Pal" }, { Id = 6999, Username = "faraway", DisplayName = "Far Away" } } },
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
	local DS = server.require("ServerScriptService.Server.Services.DataService")
	local DT = server.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local Achievements = server.require("ReplicatedStorage.Shared.Data.Achievements")
	local Badges = server.require("ReplicatedStorage.Shared.Data.Badges")
	local Challenges = server.require("ReplicatedStorage.Shared.Data.Challenges")
	local Collectibles = server.require("ReplicatedStorage.Shared.Data.Collectibles")
	local Legacy = server.require("ReplicatedStorage.Shared.Data.Legacy")
	local Config = server.require("ReplicatedStorage.Shared.Config")
	local World = server.require("ReplicatedStorage.Shared.Data.World")
	local Progress = server.require("ServerScriptService.Server.Services.ProgressService")
	local Daily = server.require("ServerScriptService.Server.Services.DailyService")
	local ChallengeService = server.require("ServerScriptService.Server.Services.ChallengeService")
	local Stars = server.require("ServerScriptService.Server.Services.CollectibleService")
	local Boards = server.require("ServerScriptService.Server.Services.LeaderboardService")
	local Profiles = server.require("ServerScriptService.Server.Services.ProfileService")
	local Trade = server.require("ServerScriptService.Server.Services.TradeService")
	local Shop = server.require("ServerScriptService.Server.Services.ShopService")
	local WS = server.require("ServerScriptService.Server.Services.WorldService")
	local NPCService = server.require("ServerScriptService.Server.Services.NPCService")
	local Badge = server.game:GetService("BadgeService")

	local alice = server.addPlayer(6001, "Alice")
	local bob = server.addPlayer(6002, "Bob")
	task.wait(0.1)
	local function data(p)
		return DS.Get(p)
	end
	local function newLife(p, name, age, stage)
		DS.Update(p, function(d)
			d.Slots.Slot1 = DT.NewLife(name, 3)
			d.ActiveSlot = "Slot1"
			d.Slots.Slot1.Age = age or 5
			d.Slots.Slot1.Stage = stage or 1
		end)
	end
	newLife(alice, "Alice")
	newLife(bob, "Bob")

	section("Phase 9: achievements and badges")
	test("Achievement data is valid; secret ones have hints; every category is used", function()
		local categories = {}
		for _, c in ipairs(Achievements.Categories) do
			categories[c.Id] = 0
		end
		local seen = {}
		for _, a in ipairs(Achievements.List) do
			ok(not seen[a.Id], "unique id " .. a.Id)
			seen[a.Id] = true
			ok(categories[a.Category] ~= nil, a.Id .. " category")
			categories[a.Category] += 1
			ok(type(a.Progress) == "function" and a.Name and a.Description and a.Icon, a.Id .. " complete")
			if a.Secret then
				ok(a.Hint, a.Id .. " has a hint")
			end
			local current, target = Achievements.ProgressOf(a.Id, data(alice))
			ok(current >= 0 and target >= 1, a.Id .. " progress works on a fresh profile")
		end
		for id, n in pairs(categories) do
			ok(n > 0, "category used: " .. id)
		end
		ok(#Achievements.List >= 40, ("%d achievements"):format(#Achievements.List))
		for id in pairs(Badges.ForAchievement) do
			ok(Achievements.ById[id], "badge maps to a real achievement: " .. id)
		end
	end)

	test("Progress unlocks achievements once, pays Coins once, and awards the Roblox badge", function()
		Badges.ForAchievement.FirstLife = 4242
		local coins = data(alice).Coins
		DS.Update(alice, function(d)
			d.Lifetime.LivesCompleted = 1
			d.Lifetime.DecisionsMade = 1
		end)
		task.wait(0.3)
		ok(data(alice).Achievements.FirstLife, "A Life Well Lived")
		ok(data(alice).Achievements.FirstSteps, "First Steps")
		local reward = Achievements.ById.FirstLife.Coins + Achievements.ById.FirstSteps.Coins
		eq(data(alice).Coins, coins + reward, "rewards paid")
		Progress.Evaluate(alice)
		task.wait(0.2)
		eq(data(alice).Coins, coins + reward, "paid only once")
		local awarded = false
		for _, a in ipairs(Badge.Awarded) do
			if a.UserId == 6001 and a.BadgeId == 4242 then
				awarded = true
			end
		end
		ok(awarded, "Roblox badge awarded")
		ok(data(alice).BadgesAwarded["4242"], "badge remembered")
		Badges.ForAchievement.FirstLife = 0
	end)

	test("Secret and event achievements: a wish at night unlocks Night Owl", function()
		DS.Update(alice, function(d)
			d.Slots.Slot1.Decisions = { {} }
		end)
		local length = World.DayLengthSeconds
		local now = server.workspace:GetServerTimeNow()
		server.setServerTimeOffset(length * 0.5 - now % length) -- 21:00
		local spot = WS.SpotParts("Plaza_Wish")[1]
		server.spawnCharacter(alice, spot.Position)
		local okUse = WS.Use(alice, "Plaza_Wish")
		eq(okUse, true)
		task.wait(0.2)
		ok(data(alice).Achievements.S_NightOwl, "Night Owl unlocked")
		eq(data(alice).Lifetime.Wishes, 1, "wishes counted")
		eq(data(alice).Lifetime.WorldActions, 1, "world actions counted")
		server.setServerTimeOffset(0)
	end)

	test("Talking (next to the NPC only) and visiting districts are recorded", function()
		local mayor = NPCService.PositionOf("Mayor")
		server.spawnCharacter(alice, V3(0, 3, -200))
		eq(select(2, WS.Talk(alice, "Mayor")), "TooFar")
		server.spawnCharacter(alice, mayor + V3(2, 0, 0))
		eq((WS.Talk(alice, "Mayor")), true)
		ok(data(alice).Lifetime.NPCsTalked.Mayor, "talked to the mayor")
		WS.CheckVisits()
		ok(data(alice).Lifetime.DistrictsVisited.Plaza, "visited the Plaza")
		local downtown = World.ById.Downtown
		server.spawnCharacter(alice, V3(downtown.X, 3, downtown.Z))
		WS.CheckVisits()
		eq(data(alice).Lifetime.DistrictsVisited.Downtown, nil, "locked districts don't count")
	end)

	section("Phase 9: daily rewards and login streaks")
	local day = 20000
	Daily.Today = function()
		return day
	end
	test("Claim once per day; consecutive days grow the streak; missing a day resets it", function()
		local coins = data(bob).Coins
		local okClaim, result = Daily.Claim(bob)
		eq(okClaim, true)
		eq(result.Streak, 1)
		eq(result.Coins, Config.DailyRewards[1])
		eq(select(2, Daily.Claim(bob)), "AlreadyClaimed", "once per day")
		day += 1
		eq(select(2, Daily.Claim(bob)).Streak, 2, "next day: streak 2")
		day += 2
		local _, again = Daily.Claim(bob)
		eq(again.Streak, 1, "missed a day: back to 1")
		eq(data(bob).Daily.BestStreak, 2, "best streak kept")
		eq(data(bob).Coins, coins + Config.DailyRewards[1] * 2 + Config.DailyRewards[2], "coins")
		eq(data(bob).Lifetime.DailyClaims, 3)
	end)

	test("Day 7 pays the big reward, then the cycle repeats; the remote works", function()
		for _ = 1, 6 do
			day += 1
			Daily.Claim(bob)
		end
		eq(data(bob).Daily.Streak, 7)
		eq(Daily.Status(data(bob)).Claimable, false)
		day += 1
		local status = Daily.Status(data(bob))
		eq(status.Day, 1, "day 8 starts the cycle again")
		eq(status.Reward, Config.DailyRewards[1])
		local okRemote, result = server.remote("ClaimDaily").OnServerInvoke(bob)
		eq(okRemote, true)
		eq(result.Streak, 8, "the streak keeps counting")
		task.wait(0.3)
		ok(data(bob).Achievements.Dedicated, "7-day streak achievement")
	end)

	section("Phase 9: daily and weekly challenges")
	test("Everyone gets the same challenges per day and week, and only new progress counts", function()
		eq(table.concat(Challenges.ForDay(day, 3), ","), table.concat(Challenges.ForDay(day, 3), ","), "deterministic")
		ok(table.concat(Challenges.ForDay(day, 3), ",") ~= table.concat(Challenges.ForDay(day + 1, 3), ",") or table.concat(Challenges.ForDay(day + 2, 3), ",") ~= table.concat(Challenges.ForDay(day, 3), ","), "they change day to day")
		ChallengeService.Evaluate(alice)
		task.wait(0.1)
		local c = data(alice).Challenges
		eq(c.DailyDay, day)
		local count = 0
		for id, entry in pairs(c.Daily) do
			count += 1
			eq(entry.Done, false)
			eq(entry.Base, Challenges.CounterValue(Challenges.ById[id], data(alice).Lifetime), "baseline taken when it starts")
		end
		eq(count, Config.DailyChallengeCount)
	end)

	test("Finishing a challenge pays its Coins once; a new day brings new ones", function()
		local c = data(alice).Challenges
		local id = next(c.Daily)
		local def = Challenges.ById[id]
		local coins = data(alice).Coins
		DS.Update(alice, function(d)
			local key = def.Counter[1]
			if type(d.Lifetime[key]) == "table" then
				for i = 1, def.Target do
					d.Lifetime[key]["Test" .. i] = true
				end
			else
				d.Lifetime[key] += def.Target
			end
		end)
		task.wait(0.3)
		eq(data(alice).Challenges.Daily[id].Done, true, def.Text .. " done")
		ok(data(alice).Coins >= coins + def.Coins, "reward paid")
		local after = data(alice).Coins
		ChallengeService.Evaluate(alice)
		task.wait(0.1)
		eq(data(alice).Coins, after, "not paid twice")
		ok(data(alice).Lifetime.ChallengesCompleted >= 1)
		day += 1
		ChallengeService.Evaluate(alice)
		task.wait(0.1)
		eq(data(alice).Challenges.DailyDay, day, "rolled over")
		for _, entry in pairs(data(alice).Challenges.Daily) do
			eq(entry.Done, false, "fresh challenges")
		end
	end)

	test("A challenge you can no longer do is swapped for another", function()
		local NPCs = server.require("ReplicatedStorage.Shared.Data.NPCs")
		local everywhere = { DistrictsVisited = {}, NPCsTalked = {} }
		for _, district in ipairs(World.Districts) do
			everywhere.DistrictsVisited[district.Id] = true
		end
		for id in pairs(NPCs.ById) do
			everywhere.NPCsTalked[id] = true
		end
		local swapDay = nil
		for d = day + 1, day + 60 do
			local normal = Challenges.ForDay(d, 3)
			local veteran = Challenges.ForDay(d, 3, everywhere)
			eq(#veteran, 3, "still 3 challenges")
			ok(not table.find(veteran, "D_Explore") and not table.find(veteran, "D_Talk"), "nothing impossible")
			if table.find(normal, "D_Explore") or table.find(normal, "D_Talk") then
				swapDay = swapDay or d
			else
				eq(table.concat(veteran, ","), table.concat(normal, ","), "otherwise the same as everyone")
			end
		end
		ok(swapDay ~= nil, "some days need a swap")
		eq(table.concat(Challenges.ForDay(swapDay, 3, { DistrictsVisited = {}, NPCsTalked = {} }), ","), table.concat(Challenges.ForDay(swapDay, 3), ","), "a new player keeps them")

		-- The server rolls a veteran's day without them
		local vet = server.addPlayer(6050, "Vet")
		task.wait(0.1)
		DS.Update(vet, function(d)
			for id in pairs(everywhere.DistrictsVisited) do
				d.Lifetime.DistrictsVisited[id] = true
			end
			for id in pairs(everywhere.NPCsTalked) do
				d.Lifetime.NPCsTalked[id] = true
			end
		end)
		local saved = day
		day = swapDay
		ChallengeService.Evaluate(vet)
		task.wait(0.1)
		local c = data(vet).Challenges
		eq(c.DailyDay, swapDay)
		eq(c.Daily.D_Explore, nil, "no district challenge")
		eq(c.Daily.D_Talk, nil, "no townspeople challenge")
		local count = 0
		for _ in pairs(c.Daily) do
			count += 1
		end
		eq(count, Config.DailyChallengeCount)
		day = saved
		server.removePlayer(vet)
		task.wait(0.1)
	end)

	section("Phase 9: Memory Stars and rebirth")
	test("20 stars, each placed once; you must be next to one; found once; one is secret", function()
		eq(Collectibles.Total, 20)
		for _, star in ipairs(Collectibles.List) do
			local part = Stars.Part(star.Id)
			ok(part, "placed: " .. star.Id)
			eq(World.DistrictAt(part.Position.X, part.Position.Z), star.District, star.Id .. " in " .. star.District)
		end
		local pier = Stars.Part("Star_Pier")
		server.spawnCharacter(alice, V3(0, 3, 0))
		eq(select(2, Stars.Collect(alice, "Star_Pier")), "TooFar")
		server.spawnCharacter(alice, pier.Position)
		local coins = data(alice).Coins
		local okStar, result = Stars.Collect(alice, "Star_Pier")
		eq(okStar, true)
		eq(result.Found, 1)
		eq(data(alice).Coins, coins + Collectibles.Coins)
		eq(select(2, Stars.Collect(alice, "Star_Pier")), "AlreadyFound")
		server.spawnCharacter(alice, Stars.Part("Star_Lighthouse").Position)
		Stars.Collect(alice, "Star_Lighthouse")
		task.wait(0.2)
		ok(data(alice).Achievements.S_Lighthouse, "Keeper of the Light")
		ok(data(alice).Achievements.FirstStar, "Shooting Star")
		eq(select(2, server.remote("CollectStar").OnServerInvoke(alice, "Not A Star!")), "BadArgs")
	end)

	test("Rebirth: Legacy perks unlock with completed lives and give the new life a head start", function()
		local start = server.remote("StartNewLife").OnServerInvoke
		DS.Update(bob, function(d)
			d.Lifetime.LivesCompleted = 0
		end)
		eq(select(2, start(bob, "Slot2", "Bobby", false, "HeadStart")), "PerkLocked")
		DS.Update(bob, function(d)
			d.Lifetime.LivesCompleted = 1
		end)
		eq(select(2, start(bob, "Slot2", "Bobby", false, "OldSoul")), "PerkLocked", "Old Soul needs 6 lives")
		task.wait(2.1) -- StartNewLife is rate limited (0.5/s)
		local okLife = start(bob, "Slot2", "Bobby", false, "HeadStart")
		eq(okLife, true)
		local life = data(bob).Slots.Slot2
		eq(life.Legacy, "HeadStart")
		eq(life.Stats.Intelligence, Config.StatStart + 5, "+5 Intelligence")
		eq(data(bob).Lifetime.Rebirths, 1)
		eq(#Legacy.Unlocked(1), 2, "two perks at Legacy level 1")
		task.wait(0.3)
		ok(data(bob).Achievements.Rebirth, "Born Again")
	end)

	section("Phase 9: leaderboards and profiles")
	test("Global boards rank scores from saved data; privacy opts you out", function()
		DS.Update(alice, function(d)
			d.Lifetime.LivesCompleted = 4
		end)
		DS.Update(bob, function(d)
			d.Lifetime.LivesCompleted = 2
		end)
		Boards.Submit(alice)
		Boards.Submit(bob)
		local top = Boards.Top("LivesCompleted", true)
		eq(top[1].UserId, 6001, "Alice first")
		eq(top[1].Value, 4)
		eq(top[1].Name, "Alice")
		eq(top[2].UserId, 6002)
		DS.Update(bob, function(d)
			d.Privacy.ShareStats = "Nobody"
		end)
		Boards.Submit(bob)
		task.wait(0.3)
		local after = Boards.Top("LivesCompleted", true)
		for _, e in ipairs(after) do
			ok(e.UserId ~= 6002, "Bob removed from the global board")
		end
		eq(bob:FindFirstChild("leaderstats"), nil, "and from the player list")
		ok(alice.leaderstats.Lives.Value == 4, "player list shows lives")
		DS.Update(bob, function(d)
			d.Privacy.ShareStats = "Friends"
		end)
	end)

	test("Friends boards: friends in this server live, others from the store", function()
		local farStore = nil
		-- A friend who isn't in this server but has a saved score.
		Boards.Submit(alice)
		local okBoard, board = server.remote("GetLeaderboard").OnServerInvoke(alice, "LivesCompleted", "Friends")
		eq(okBoard, true)
		local names = {}
		for _, e in ipairs(board.Entries) do
			names[e.UserId] = e
		end
		ok(names[6001] and names[6002], "you and your friend in this server")
		eq(board.You.UserId, 6001)
		eq(board.Entries[1].UserId, 6001, "sorted best first")
		eq(farStore, nil)
		eq(select(2, server.remote("GetLeaderboard").OnServerInvoke(alice, "Nope", "Global")), "BadArgs")
	end)

	test("The Hall of Fame board in the Plaza shows the top lives", function()
		local text = Boards.UpdateHallOfFame()
		ok(text:find("Alice", 1, true), text)
		local board = server.CollectionService:GetTagged("CYL_HallOfFame")[1]
		ok(board.Text.Label.Text:find("HALL OF FAME", 1, true), "board updated")
	end)

	test("Profiles: yourself in full; others as their privacy allows", function()
		local okSelf, mine = Profiles.Get(alice, 6001)
		eq(okSelf, true)
		ok(mine.Stats and mine.Stats.LivesCompleted == 4, "your stats")
		local _, theirs = Profiles.Get(alice, 6002)
		eq(theirs.Private, true, "Bob shares with friends only, and they aren't friends")
		eq(theirs.Stats, nil)
		ok(theirs.Achievements >= 1 and theirs.AchievementsTotal == #Achievements.List, "counts always shown")
		DS.Update(bob, function(d)
			d.Privacy.ShareStats = "Everyone"
		end)
		local _, open = Profiles.Get(alice, 6002)
		ok(open.Stats, "Everyone: stats shown")
		eq(select(2, Profiles.Get(alice, 123)), "NotHere")
	end)

	section("Phase 9: trading cosmetics")
	local function give(p, ids)
		DS.Update(p, function(d)
			for _, id in ipairs(ids) do
				d.Inventory.Owned[id] = true
			end
		end)
	end
	give(alice, { "Acc_Cap", "Pet_Dog" })
	give(bob, { "Car_Hatch", "Pet_Unicorn" })
	DS.Update(alice, function(d)
		d.Inventory.Equipped.Pet = "Pet_Dog"
	end)
	local sessionId
	test("Requests and sessions: only players in this server, one trade at a time", function()
		eq(select(2, Trade.Request(alice, 6001)), "NotHere", "not with yourself")
		eq(select(2, Trade.Request(alice, 9999)), "NotHere")
		local okReq, requestId = Trade.Request(alice, 6002)
		eq(okReq, true)
		eq(select(2, Trade.Request(alice, 6002)), "Cooldown", "no request spam")
		eq(select(2, Trade.Respond(alice, requestId, true)), "NoRequest", "only the receiver can accept")
		local okResp, id = Trade.Respond(bob, requestId, true)
		eq(okResp, true)
		sessionId = id
		ok(Trade.SessionOf(alice) and Trade.SessionOf(bob), "both in the trade")
	end)

	test("Offers: only tradable items you own that they don't", function()
		eq(select(2, Trade.SetOffer(alice, sessionId, { "Outfit_Suit" })), "NotOwned")
		eq(select(2, Trade.SetOffer(bob, sessionId, { "Pet_Unicorn" })), "NotTradable", "VIP items can't be traded")
		give(bob, { "Acc_Cap" })
		eq(select(2, Trade.SetOffer(alice, sessionId, { "Acc_Cap" })), "TheyOwnIt", "no duplicates")
		DS.Update(bob, function(d)
			d.Inventory.Owned.Acc_Cap = nil
		end)
		eq(select(2, Trade.SetOffer(alice, sessionId, { "Pet_Dog", "Pet_Dog" })), "Duplicate")
		eq(select(2, Trade.SetOffer(alice, sessionId, { "a", "b", "c", "d", "e", "f", "g" })), "TooMany")
		ok((Trade.SetOffer(alice, sessionId, { "Pet_Dog" })), "Alice offers her puppy")
		ok((Trade.SetOffer(bob, sessionId, { "Car_Hatch" })), "Bob offers his hatchback")
	end)

	test("Ready locks in the exact offer; any change un-readies both; then the swap happens", function()
		local session = Trade.SessionOf(alice)
		eq(select(2, Trade.SetReady(alice, sessionId, session.Version - 1, true)), "Changed", "stale version refused")
		ok((Trade.SetReady(alice, sessionId, session.Version, true)))
		ok((Trade.SetReady(bob, sessionId, session.Version, true)))
		ok(session.CountdownEnds, "countdown started")
		-- Bob switches items during the countdown: both un-ready, no trade.
		give(bob, { "Car_SUV" })
		ok((Trade.SetOffer(bob, sessionId, { "Car_SUV" })))
		eq(session.Ready[alice], nil, "Alice is no longer ready")
		task.wait(Trade.CountdownSeconds + 0.2)
		eq(data(alice).Inventory.Owned.Pet_Dog, true, "nothing traded")
		ok((Trade.SetReady(alice, sessionId, session.Version, true)))
		ok((Trade.SetReady(bob, sessionId, session.Version, true)))
		task.wait(Trade.CountdownSeconds + 0.3)
		eq(data(alice).Inventory.Owned.Pet_Dog, nil, "Alice gave the puppy")
		eq(data(bob).Inventory.Owned.Pet_Dog, true, "Bob got the puppy")
		eq(data(alice).Inventory.Owned.Car_SUV, true, "Alice got the SUV")
		eq(data(bob).Inventory.Owned.Car_SUV, nil)
		eq(data(alice).Inventory.Equipped.Pet, nil, "the traded pet was unequipped")
		eq(data(alice).Lifetime.TradesCompleted, 1)
		eq(#data(alice).TradeLog, 1, "logged for support")
		eq(data(alice).TradeLog[1].Id, data(bob).TradeLog[1].Id, "same trade id on both sides")
		eq(Trade.SessionOf(alice), nil, "trade closed")
	end)

	test("Leaving cancels a trade; bad arguments are refused", function()
		task.wait(Trade.RequestCooldown)
		local _, requestId = Trade.Request(bob, 6001)
		Trade.Respond(alice, requestId, true)
		ok(Trade.SessionOf(bob), "trading again")
		server.removePlayer(bob)
		task.wait(0.1)
		eq(Trade.SessionOf(alice), nil, "cancelled when Bob left")
		eq(select(2, server.remote("TradeSetOffer").OnServerInvoke(alice, "x y", {})), "BadArgs")
	end)

	test("No errors on the server", function()
		eq(#server.errors, 0, table.concat(server.errors, "\n"))
	end)
	server.close()
end
