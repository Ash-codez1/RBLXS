--[[
	PartyService  (ServerScriptService.Server.Services.PartyService)
	"Life Circles": play with friends while every life stays independent.

	Circles (parties) of up to 4 players in the same server:
	  PartyInvite(targetUserId) · PartyRespond(inviteId, accept) · PartyLeave() · PartyKick(userId)
	  Invites expire; the leader role passes on if the leader leaves; a circle
	  of one dissolves.

	Group events (PartyStartEvent → PartyVote):
	  The server picks a group scenario every member qualifies for
	  (Content/GroupScenarios), everyone votes, and the majority wins (ties and
	  no-shows are settled fairly at random). Chance outcomes are rolled ONCE
	  for the group (shared fate), but the effects are applied to each
	  member's OWN life with their own stats, traits and money. Nothing a
	  friend does ever writes to your life except through a vote you were
	  part of. Group events don't use a decision or change anyone's age.
	  Each member's life also gains the others as named friends and records
	  the shared moment (it appears in the Final Reveal).

	Group Life Reveal (PartyStartReveal): everyone watches each member's
	predicted futures, then a "most likely to…" board. Privacy settings
	still apply; circle members count as friends.

	JoinFriendServer(placeId, jobId): teleport to a friend's server of this
	experience (the client finds friends with Player:GetFriendsOnline).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local People = require(Shared.Util.People)
local Futures = require(Shared.Util.Futures)
local TableUtil = require(Shared.Util.TableUtil)
local LifeStages = require(Shared.Data.LifeStages)
local Careers = require(Shared.Data.Careers)
local Style = require(Shared.Util.Style)

local Server = script.Parent.Parent
local Conditions = require(Server.Lib.Conditions)
local Consequences = require(Server.Lib.Consequences)
local Scenarios = require(Server.Content.Scenarios)
local CoinRewards = require(Server.Lib.CoinRewards)
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)
local RevealService = require(script.Parent.RevealService)

local PartyService = {}
PartyService.Priority = 36

PartyService.MaxMembers = 4
PartyService.InviteSeconds = 45
PartyService.VoteSeconds = 40
PartyService.EventCooldown = 90
PartyService.RevealCooldown = 45
PartyService.MaxSharedMoments = 10

PartyService.EventResolved = Signal.new() -- (party, scenario, choiceId, outcomeIndex)

local parties = {}
local partyOf: { [Player]: any } = {}
local invites = {}
local counters = { Party = 0, Invite = 0, Event = 0, Reveal = 0 }
local rng = Random.new()

-- ===== Helpers =====
local function now(): number
	return os.clock()
end

local function findPlayer(userId: any): Player?
	if type(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 then
		return nil
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function displayName(player: Player): string
	return player.DisplayName or player.Name
end

local function activeLife(player: Player)
	local life = DataService.GetActiveLife(player)
	if life and not life.Completed then
		return life
	end
	return nil
end

function PartyService.PartyOf(player: Player)
	return partyOf[player]
end

function PartyService.SameParty(a: Player, b: Player): boolean
	return partyOf[a] ~= nil and partyOf[a] == partyOf[b]
end

local function memberInfo(party, player: Player)
	local info = { UserId = player.UserId, DisplayName = displayName(player), IsLeader = party.Leader == player }
	local data = DataService.Get(player)
	if data then
		info.Style = Style.Public(data.Inventory.Equipped)
	end
	local life = DataService.GetActiveLife(player)
	if life then
		info.LifeName = life.Name
		info.Age = life.Age
		info.StageName = LifeStages.Get(life.Stage).DisplayName
		info.Completed = life.Completed
		info.Career = if life.Career.Id ~= "None" and Careers.Info[life.Career.Id] then Careers.TitleAt(life.Career.Id, life.Career.Level) elseif life.Flags.Retired then "Retired" else nil
	end
	return info
end

function PartyService.State(party)
	local members = {}
	for _, member in ipairs(party.Members) do
		table.insert(members, memberInfo(party, member))
	end
	return {
		Id = party.Id,
		LeaderUserId = party.Leader.UserId,
		Members = members,
		MaxMembers = PartyService.MaxMembers,
		EventActive = party.Event ~= nil,
		EventCooldown = math.max(0, math.ceil(PartyService.EventCooldown - (now() - party.LastEventAt))),
		RevealCooldown = math.max(0, math.ceil(PartyService.RevealCooldown - (now() - party.LastRevealAt))),
	}
end

local function broadcast(party)
	local state = PartyService.State(party)
	for _, member in ipairs(party.Members) do
		Net.Fire("PartyUpdate", member, state)
	end
end

local function notify(player: Player, text: string, kind: string?)
	Net.Fire("Notify", player, { Title = "🤝 Life Circle", Text = text, Kind = kind or "Info" })
end

-- ===== Circle membership =====
local resolveEvent

local function removeFromParty(player: Player, reason: string?)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	if player.Parent then
		Net.Fire("PartyUpdate", player, false)
	end
	if #party.Members <= 1 then
		-- A circle of one dissolves.
		for _, last in ipairs(party.Members) do
			partyOf[last] = nil
			Net.Fire("PartyUpdate", last, false)
			notify(last, "Your Life Circle has ended.")
		end
		party.Members = {}
		party.Event = nil
		parties[party.Id] = nil
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	for _, member in ipairs(party.Members) do
		notify(member, displayName(player) .. (if reason == "Kicked" then " was removed from the circle." else " left the circle."))
	end
	-- A leaving voter no longer counts; finish the vote if everyone left has voted.
	local event = party.Event
	if event then
		event.Votes[player] = nil
		local stillVoting = false
		for _, voter in ipairs(event.Voters) do
			if partyOf[voter] == party and event.Votes[voter] == nil then
				stillVoting = true
			end
		end
		if not stillVoting then
			resolveEvent(party)
		end
	end
	broadcast(party)
end

function PartyService.Invite(player: Player, targetUserId: any)
	local target = findPlayer(targetUserId)
	if not target then
		return false, "NotHere"
	end
	if target == player then
		return false, "Self"
	end
	if not DataService.IsLoaded(player) or not DataService.IsLoaded(target) then
		return false, "NotLoaded"
	end
	local party = partyOf[player]
	if party and table.find(party.Members, target) then
		return false, "AlreadyMember"
	end
	if party and #party.Members >= PartyService.MaxMembers then
		return false, "PartyFull"
	end
	for _, invite in pairs(invites) do
		if invite.From == player and invite.To == target and invite.Expires > now() then
			return false, "AlreadyInvited"
		end
	end
	counters.Invite += 1
	local id = "inv" .. counters.Invite
	invites[id] = { Id = id, From = player, To = target, Expires = now() + PartyService.InviteSeconds }
	Net.Fire("PartyInviteReceived", target, { InviteId = id, FromUserId = player.UserId, FromName = displayName(player), Seconds = PartyService.InviteSeconds })
	return true, { InviteId = id }
end

function PartyService.Respond(player: Player, inviteId: any, accept: any)
	if type(inviteId) ~= "string" then
		return false, "BadArgs"
	end
	local invite = invites[inviteId]
	if not invite or invite.To ~= player then
		return false, "NoInvite"
	end
	invites[inviteId] = nil
	if invite.Expires < now() then
		return false, "Expired"
	end
	local from = invite.From
	if not from.Parent then
		return false, "NotHere"
	end
	if accept ~= true then
		notify(from, displayName(player) .. " declined your invite.")
		return true, { Joined = false }
	end
	local party = partyOf[from]
	if party and #party.Members >= PartyService.MaxMembers then
		return false, "PartyFull"
	end
	if partyOf[player] and partyOf[player] ~= party then
		removeFromParty(player)
	end
	if not party then
		counters.Party += 1
		party = { Id = "circle" .. counters.Party, Leader = from, Members = { from }, LastEventAt = -math.huge, LastRevealAt = -math.huge, Recent = {} }
		parties[party.Id] = party
		partyOf[from] = party
	end
	if not table.find(party.Members, player) then
		table.insert(party.Members, player)
	end
	partyOf[player] = party
	for _, member in ipairs(party.Members) do
		if member ~= player then
			notify(member, displayName(player) .. " joined your Life Circle!", "Success")
		end
	end
	broadcast(party)
	return true, { Joined = true, PartyId = party.Id }
end

function PartyService.Leave(player: Player)
	if not partyOf[player] then
		return false, "NoParty"
	end
	removeFromParty(player)
	return true
end

function PartyService.Kick(player: Player, userId: any)
	local party = partyOf[player]
	if not party then
		return false, "NoParty"
	end
	if party.Leader ~= player then
		return false, "NotLeader"
	end
	local target = findPlayer(userId)
	if not target or target == player or partyOf[target] ~= party then
		return false, "NotMember"
	end
	removeFromParty(target, "Kicked")
	if target.Parent then
		notify(target, "You were removed from the Life Circle.", "Warning")
	end
	return true
end

-- ===== Group events =====
local function lockedFor(lives, requires): boolean
	for _, life in ipairs(lives) do
		if not Conditions.Check(life, requires) then
			return true
		end
	end
	return false
end

function PartyService.EligibleScenarios(lives)
	local list = {}
	for _, scenario in ipairs(Scenarios.Group) do
		if not lockedFor(lives, scenario.Requires) then
			local open = 0
			for _, choice in ipairs(scenario.Choices) do
				if not lockedFor(lives, choice.Requires) then
					open += 1
				end
			end
			if open >= 2 then
				table.insert(list, scenario)
			end
		end
	end
	return list
end

function PartyService.StartEvent(player: Player, forcedScenarioId: string?)
	local party = partyOf[player]
	if not party then
		return false, "NoParty"
	end
	if party.Event then
		return false, "EventActive"
	end
	local wait = PartyService.EventCooldown - (now() - party.LastEventAt)
	if wait > 0 then
		return false, "Cooldown", math.ceil(wait)
	end
	local lives = {}
	for _, member in ipairs(party.Members) do
		local life = activeLife(member)
		if not life then
			return false, "NotEveryoneReady", displayName(member)
		end
		table.insert(lives, life)
	end
	local eligible = PartyService.EligibleScenarios(lives)
	local scenario
	if forcedScenarioId then
		scenario = Scenarios.GroupById[forcedScenarioId]
		if not scenario or not table.find(eligible, scenario) then
			return false, "NotEligible"
		end
	else
		local total, weights = 0, {}
		for i, s in ipairs(eligible) do
			weights[i] = (s.Weight or 1) * (if table.find(party.Recent, s.Id) then 0.15 else 1)
			total += weights[i]
		end
		local roll = rng:NextNumber() * total
		for i, s in ipairs(eligible) do
			roll -= weights[i]
			if roll <= 0 then
				scenario = s
				break
			end
		end
		scenario = scenario or eligible[#eligible]
	end
	if not scenario then
		return false, "NoEvent"
	end
	counters.Event += 1
	local event = {
		Id = counters.Event,
		Scenario = scenario,
		Voters = table.clone(party.Members),
		Votes = {},
		Locked = {},
		StartedBy = player,
	}
	local choices = {}
	for index, choice in ipairs(scenario.Choices) do
		local locked = lockedFor(lives, choice.Requires)
		event.Locked[choice.Id] = locked
		local preview, moneyDir, risky, tags = Consequences.Preview(choice.Effects)
		table.insert(choices, {
			Id = choice.Id,
			Index = index,
			Text = choice.Text,
			Description = choice.Description,
			Locked = locked,
			LockHint = if locked then (choice.LockHint or "Not everyone can do this") else nil,
			Preview = preview,
			MoneyDir = moneyDir,
			Risky = risky,
			Tags = tags,
		})
	end
	local names = {}
	for _, member in ipairs(party.Members) do
		table.insert(names, displayName(member))
	end
	party.Event = event
	local payload = {
		EventId = event.Id,
		Icon = scenario.Icon,
		Title = scenario.Title,
		Description = scenario.Description,
		Choices = choices,
		Seconds = PartyService.VoteSeconds,
		Members = names,
		StartedBy = displayName(player),
	}
	for _, member in ipairs(party.Members) do
		Net.Fire("GroupEvent", member, payload)
	end
	broadcast(party)
	task.delay(PartyService.VoteSeconds, function()
		if party.Event == event then
			resolveEvent(party)
		end
	end)
	return true, { EventId = event.Id, ScenarioId = scenario.Id }
end

function PartyService.Vote(player: Player, eventId: any, choiceId: any)
	local party = partyOf[player]
	local event = party and party.Event
	if not event or event.Id ~= eventId then
		return false, "NoEvent"
	end
	if not table.find(event.Voters, player) then
		return false, "NotInEvent"
	end
	if type(choiceId) ~= "string" or not event.Scenario.ChoiceById[choiceId] then
		return false, "BadChoice"
	end
	if event.Locked[choiceId] then
		return false, "ChoiceLocked"
	end
	event.Votes[player] = choiceId
	local votes = {}
	for voter, choice in pairs(event.Votes) do
		votes[tostring(voter.UserId)] = choice
	end
	for _, member in ipairs(party.Members) do
		Net.Fire("GroupVote", member, { EventId = event.Id, Votes = votes })
	end
	local everyone = true
	for _, voter in ipairs(event.Voters) do
		if partyOf[voter] == party and event.Votes[voter] == nil then
			everyone = false
		end
	end
	if everyone then
		task.defer(function()
			if party.Event == event then
				resolveEvent(party)
			end
		end)
	end
	return true
end

function resolveEvent(party)
	local event = party.Event
	if not event then
		return
	end
	party.Event = nil
	party.LastEventAt = now()
	table.insert(party.Recent, event.Scenario.Id)
	if #party.Recent > 4 then
		table.remove(party.Recent, 1)
	end
	local scenario = event.Scenario

	-- Count votes from voters still in the circle.
	local tally, best, top = {}, 0, {}
	local voteMap = {}
	for voter, choiceId in pairs(event.Votes) do
		if partyOf[voter] == party then
			tally[choiceId] = (tally[choiceId] or 0) + 1
			voteMap[tostring(voter.UserId)] = choiceId
		end
	end
	for choiceId, count in pairs(tally) do
		if count > best then
			best, top = count, { choiceId }
		elseif count == best then
			table.insert(top, choiceId)
		end
	end
	local noVotes = #top == 0
	if noVotes then
		for _, choice in ipairs(scenario.Choices) do
			if not event.Locked[choice.Id] then
				table.insert(top, choice.Id)
			end
		end
	end
	table.sort(top)
	local choiceId = top[rng:NextInteger(1, #top)]
	local choice = scenario.ChoiceById[choiceId]
	local outcomeIndex = Consequences.RollOutcome(choice.Effects, rng) -- shared fate

	local members = table.clone(party.Members)
	local lifeNames = {}
	for _, member in ipairs(members) do
		local life = DataService.GetActiveLife(member)
		lifeNames[member] = if life then life.Name else displayName(member)
	end
	for _, member in ipairs(members) do
		local result
		DataService.Update(member, function(d)
			local life = d.Slots[d.ActiveSlot]
			if type(life) ~= "table" or life.Completed then
				return
			end
			local memberRng = Random.new((life.Seed + #life.Decisions * 31 + event.Id * 7) % 2147483646 + 1)
			local summary = Consequences.Apply(life, choice.Effects, memberRng, true, outcomeIndex)
			-- Friends in real life become friends in each other's lives.
			local others = {}
			for _, other in ipairs(members) do
				if other ~= member then
					table.insert(others, lifeNames[other])
					local existing = nil
					for _, person in ipairs(life.People) do
						if person.PlayerUserId == other.UserId then
							existing = person
						end
					end
					if existing then
						Consequences.ChangeBond(existing, 5, summary)
					else
						local added = People.AddNamed(life, "Friend", lifeNames[other], other.UserId, 70)
						if added then
							table.insert(summary.LifeChanges, ("🤝 %s (%s) is now in your People"):format(added.Name, displayName(other)))
						end
					end
				end
			end
			life.Shared = life.Shared or {}
			table.insert(life.Shared, { Title = scenario.Title, Icon = scenario.Icon, With = others, Age = life.Age })
			TableUtil.TrimArray(life.Shared, PartyService.MaxSharedMoments)
			Consequences.SyncWealth(life)
			summary.Applied.Wealth = nil
			local coins = CoinRewards.Grant(d, Config.GroupEventCoins)
			result = {
				Coins = coins,
				EventId = event.Id,
				Icon = scenario.Icon,
				Title = scenario.Title,
				ChoiceId = choiceId,
				ChoiceText = choice.Text,
				Tally = tally,
				Votes = voteMap,
				NoVotes = noVotes,
				Tie = not noVotes and #top > 1,
				Lucky = outcomeIndex > 0,
				Story = summary.Story,
				Applied = summary.Applied,
				MoneyDelta = summary.MoneyDelta,
				LifeChanges = summary.LifeChanges,
				TraitsGained = summary.TraitsGained,
				BondChanges = summary.BondChanges,
			}
		end)
		if result and member.Parent then
			Net.Fire("GroupEventResult", member, result)
		end
	end
	PartyService.EventResolved:Fire(party, scenario, choiceId, outcomeIndex)
	if parties[party.Id] then
		broadcast(party)
	end
end

-- ===== Group Life Reveal =====
local function superlatives(cards)
	local list = {}
	for _, id in ipairs(Futures.Order) do
		local info = Futures.Info[id]
		if info.Positive then
			local best = nil
			for _, c in ipairs(cards) do
				if c.Card and (not best or c.Card.Predictions[id] > best.Card.Predictions[id]) then
					best = c
				end
			end
			if best and best.Card.Predictions[id] >= 15 then
				table.insert(list, { Id = id, UserId = best.UserId, DisplayName = best.DisplayName, LifeName = best.Card.LifeName, Pct = best.Card.Predictions[id] })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Pct > b.Pct
	end)
	return list
end

function PartyService.StartReveal(player: Player)
	local party = partyOf[player]
	if not party then
		return false, "NoParty"
	end
	local wait = PartyService.RevealCooldown - (now() - party.LastRevealAt)
	if wait > 0 then
		return false, "Cooldown", math.ceil(wait)
	end
	party.LastRevealAt = now()
	counters.Reveal += 1
	for _, viewer in ipairs(party.Members) do
		local cards = {}
		for _, target in ipairs(party.Members) do
			local card = RevealService.CardFor(viewer, target)
			if card then
				table.insert(cards, card)
			end
		end
		Net.Fire("GroupReveal", viewer, {
			SessionId = counters.Reveal,
			StartedBy = displayName(player),
			Cards = cards,
			Superlatives = superlatives(cards),
		})
	end
	broadcast(party)
	return true
end

-- ===== Joining friends in other servers =====
local function looksLikeJobId(value: any): boolean
	return type(value) == "string" and #value <= 64 and value:match("^[%w%-]+$") ~= nil
end

function PartyService.JoinFriendServer(player: Player, placeId: any, jobId: any)
	if placeId ~= game.PlaceId or not looksLikeJobId(jobId) then
		return false, "BadServer"
	end
	if jobId == game.JobId then
		return false, "SameServer"
	end
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
	end)
	if not ok then
		return false, "TeleportFailed: " .. tostring(err)
	end
	return true
end

-- ===== Lifecycle =====
function PartyService.Init()
	RevealService.ExtraFriendCheck = PartyService.SameParty
end

function PartyService.Start()
	Net.Handle("PartyInvite", PartyService.Invite)
	Net.Handle("PartyRespond", PartyService.Respond)
	Net.Handle("PartyLeave", PartyService.Leave)
	Net.Handle("PartyKick", PartyService.Kick)
	Net.Handle("PartyStartEvent", function(player)
		return PartyService.StartEvent(player)
	end)
	Net.Handle("PartyVote", PartyService.Vote)
	Net.Handle("PartyStartReveal", PartyService.StartReveal)
	Net.Handle("JoinFriendServer", PartyService.JoinFriendServer)
	Net.Handle("GetPartyState", function(player)
		local party = partyOf[player]
		return true, if party then PartyService.State(party) else false
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeFromParty(player)
		for id, invite in pairs(invites) do
			if invite.From == player or invite.To == player then
				invites[id] = nil
			end
		end
	end)
	-- Tidy expired invites.
	task.spawn(function()
		while true do
			task.wait(30)
			for id, invite in pairs(invites) do
				if invite.Expires < now() then
					invites[id] = nil
				end
			end
		end
	end)
end

return PartyService
