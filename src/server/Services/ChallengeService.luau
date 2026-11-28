--[[
	ChallengeService  (ServerScriptService.Server.Services.ChallengeService)
	Daily and weekly challenges (Shared/Data/Challenges).
	  • Everyone gets the same challenges each UTC day / week, except that a
	    challenge you can no longer do (say, visiting a new district when
	    you've been everywhere) is swapped for the next one.
	  • When a new day or week starts for a player, their challenges are
	    replaced and each remembers where its counters were (Base), so only
	    progress made from then on counts.
	  • After every data change the server checks progress; a finished
	    challenge pays its Coins once, automatically, and says so.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local Challenges = require(Shared.Data.Challenges)

local CoinRewards = require(script.Parent.Parent.Lib.CoinRewards)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)

local ChallengeService = {}
ChallengeService.Priority = 23

local queued: { [Player]: boolean } = {}

local function fresh(ids, lifetime)
	local set = {}
	for _, id in ipairs(ids) do
		set[id] = { Base = Challenges.CounterValue(Challenges.ById[id], lifetime), Done = false }
	end
	return set
end

-- Starts today's / this week's challenges if they changed. Call inside Update.
function ChallengeService.Roll(d, today: number)
	local week = Challenges.WeekOf(today)
	local c = d.Challenges
	local changed = false
	if c.DailyDay ~= today then
		c.DailyDay = today
		c.Daily = fresh(Challenges.ForDay(today, Config.DailyChallengeCount, d.Lifetime), d.Lifetime)
		changed = true
	end
	if c.WeeklyWeek ~= week then
		c.WeeklyWeek = week
		c.Weekly = fresh(Challenges.ForWeek(week, Config.WeeklyChallengeCount, d.Lifetime), d.Lifetime)
		changed = true
	end
	return changed
end

-- Rolls over if needed and pays for anything just finished.
function ChallengeService.Evaluate(player: Player)
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	local today = DailyService.Today()
	local c = data.Challenges
	local needsRoll = c.DailyDay ~= today or c.WeeklyWeek ~= Challenges.WeekOf(today)
	local finished = {}
	for _, group in ipairs({ c.Daily, c.Weekly }) do
		for id, entry in pairs(group or {}) do
			local def = Challenges.ById[id]
			if def and not entry.Done then
				local progress, target = Challenges.Progress(def, entry, data.Lifetime)
				if progress >= target then
					table.insert(finished, id)
				end
			end
		end
	end
	if not needsRoll and #finished == 0 then
		return {}
	end
	local paid = {}
	DataService.Update(player, function(d)
		for _, id in ipairs(finished) do
			local entry = d.Challenges.Daily[id] or d.Challenges.Weekly[id]
			if entry and not entry.Done then
				entry.Done = true
				d.Lifetime.ChallengesCompleted += 1
				CoinRewards.GrantBonus(d, Challenges.ById[id].Coins)
				table.insert(paid, id)
			end
		end
		ChallengeService.Roll(d, today)
	end)
	for _, id in ipairs(paid) do
		local def = Challenges.ById[id]
		Net.Fire("Notify", player, { Title = "🎯 Challenge complete!", Text = ("%s %s · +%d 🪙"):format(def.Icon, def.Text, def.Coins), Kind = "Important", Duration = 5 })
	end
	return paid
end

function ChallengeService.Init()
	DataService.Changed:Connect(function(player)
		if queued[player] then
			return
		end
		queued[player] = true
		task.defer(function()
			queued[player] = nil
			if player.Parent then
				ChallengeService.Evaluate(player)
			end
		end)
	end)
	DataService.ProfileLoaded:Connect(ChallengeService.Evaluate)
end

function ChallengeService.Start()
	-- New day while playing: roll the challenges over even if nothing changes.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(ChallengeService.Evaluate, player)
			end
		end
	end)
end

return ChallengeService
