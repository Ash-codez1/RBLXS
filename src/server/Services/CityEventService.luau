--[[
	CityEventService  (ServerScriptService.Server.Services.CityEventService)
	Shared, server-wide events (Content/CityEvents): every few minutes the
	whole server gets the same invitation, such as a festival, the marathon
	or a free concert. Each player chooses to join or skip within the time
	limit. Joining applies the effects to that player's own life; chance
	outcomes are rolled once for the whole city, so everyone who joins
	shares the same result. A summary ("12 people joined!") follows.

	CityEventRespond(eventId, join) -> true, result | false, reason
	CityEventService.Trigger(eventId?) starts one now (tests / admin tools).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config)

local Server = script.Parent.Parent
local Conditions = require(Server.Lib.Conditions)
local Consequences = require(Server.Lib.Consequences)
local Scenarios = require(Server.Content.Scenarios)

local DataService = require(script.Parent.DataService)

local CityEventService = {}
CityEventService.Priority = 37

local current = nil
local lastId = nil
local counter = 0
local rng = Random.new()

local function activeLife(player: Player)
	local life = DataService.GetActiveLife(player)
	if life and not life.Completed then
		return life
	end
	return nil
end

local function interval(): number
	return if RunService:IsStudio() then 90 else Config.CityEventInterval
end

local function minPlayers(): number
	return if RunService:IsStudio() then 1 else Config.CityEventMinPlayers
end

local function finish(event)
	if current ~= event then
		return
	end
	current = nil
	local joined, invited = 0, 0
	for _, response in pairs(event.Responses) do
		if response == "Join" then
			joined += 1
		end
	end
	for _ in pairs(event.Invited) do
		invited += 1
	end
	Net.FireAll("CityEventSummary", { EventId = event.Id, Icon = event.Def.Icon, Title = event.Def.Title, Joined = joined, Invited = invited })
end

function CityEventService.Current()
	return current
end

function CityEventService.Trigger(eventId: string?)
	if current then
		return false, "EventActive"
	end
	local pool = {}
	for _, def in ipairs(Scenarios.City) do
		if (not eventId or def.Id == eventId) and def.Id ~= lastId then
			table.insert(pool, def)
		end
	end
	if eventId and #pool == 0 then
		pool = { Scenarios.CityById[eventId] }
	end
	local def = pool[rng:NextInteger(1, #pool)]
	if not def then
		return false, "NoEvent"
	end
	counter += 1
	lastId = def.Id
	local event = {
		Id = counter,
		Def = def,
		OutcomeIndex = Consequences.RollOutcome(def.Effects, rng), -- the same for the whole city
		Responses = {},
		Invited = {},
		Deadline = os.clock() + Config.CityEventJoinSeconds,
	}
	current = event
	for _, player in ipairs(Players:GetPlayers()) do
		local life = activeLife(player)
		if life then
			local eligible = Conditions.Check(life, def.Requires)
			event.Invited[player] = eligible
			Net.Fire("CityEvent", player, {
				EventId = event.Id,
				Icon = def.Icon,
				Title = def.Title,
				Description = def.Description,
				JoinText = def.JoinText,
				SkipText = def.SkipText,
				Seconds = Config.CityEventJoinSeconds,
				Eligible = eligible,
			})
		end
	end
	task.delay(Config.CityEventJoinSeconds, function()
		finish(event)
	end)
	return true, { EventId = event.Id, Id = def.Id }
end

function CityEventService.Respond(player: Player, eventId: any, join: any)
	local event = current
	if not event or event.Id ~= eventId then
		return false, "NoEvent"
	end
	if event.Invited[player] == nil then
		return false, "NotInvited"
	end
	if event.Responses[player] then
		return false, "AlreadyResponded"
	end
	if join ~= true then
		event.Responses[player] = "Skip"
		return true, { Joined = false }
	end
	if not event.Invited[player] then
		return false, "NotEligible"
	end
	local result
	DataService.Update(player, function(d)
		local life = d.Slots[d.ActiveSlot]
		if type(life) ~= "table" or life.Completed then
			return
		end
		local lifeRng = Random.new((life.Seed + #life.Decisions * 17 + event.Id * 13) % 2147483646 + 1)
		local summary = Consequences.Apply(life, event.Def.Effects, lifeRng, true, event.OutcomeIndex)
		summary.Applied.Wealth = nil
		result = {
			Joined = true,
			Icon = event.Def.Icon,
			Title = event.Def.Title,
			Story = summary.Story,
			Applied = summary.Applied,
			MoneyDelta = summary.MoneyDelta,
			LifeChanges = summary.LifeChanges,
			TraitsGained = summary.TraitsGained,
			Lucky = event.OutcomeIndex > 0,
		}
	end)
	if not result then
		return false, "NoLife"
	end
	event.Responses[player] = "Join"
	return true, result
end

function CityEventService.Init() end

function CityEventService.Start()
	Net.Handle("CityEventRespond", CityEventService.Respond)
	task.spawn(function()
		while true do
			task.wait(interval())
			local active = 0
			for _, player in ipairs(Players:GetPlayers()) do
				if activeLife(player) then
					active += 1
				end
			end
			if active >= minPlayers() and not current then
				CityEventService.Trigger()
			end
		end
	end)
end

return CityEventService
