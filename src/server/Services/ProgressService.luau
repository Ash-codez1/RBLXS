--[[
	ProgressService  (ServerScriptService.Server.Services.ProgressService)
	Achievements (Shared/Data/Achievements) and optional Roblox badges.

	Every system records progress in the profile as it happens (Lifetime
	counters such as DecisionsMade, WorldActions, EndingsSeen...). After any
	data change (DataService.Changed) this service checks each achievement's
	Progress(data) and unlocks the ones now complete: the unlock time is
	saved, the Coins reward is granted once, the player is told, and the
	matching Roblox badge (Data/Badges) is awarded if one is set up.
	Event achievements (e.g. a wish at night) are unlocked directly with
	ProgressService.Unlock by the system that sees them happen.
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Achievements = require(Shared.Data.Achievements)
local Badges = require(Shared.Data.Badges)

local CoinRewards = require(script.Parent.Parent.Lib.CoinRewards)
local Validate = require(script.Parent.Parent.Lib.Validate)
local DataService = require(script.Parent.DataService)

local ProgressService = {}
ProgressService.Priority = 21
ProgressService.AchievementUnlocked = Signal.new() -- (player, achievementId)

local queued: { [Player]: boolean } = {}

-- Adds to a Lifetime counter (Bump) or set (Mark).
function ProgressService.Bump(player: Player, key: string, amount: number?)
	DataService.Update(player, function(d)
		d.Lifetime[key] = (tonumber(d.Lifetime[key]) or 0) + (amount or 1)
	end)
end

function ProgressService.Mark(player: Player, setKey: string, id: string): boolean
	local added = false
	DataService.Update(player, function(d)
		local set = d.Lifetime[setKey]
		if type(set) ~= "table" then
			set = {}
			d.Lifetime[setKey] = set
		end
		if not set[id] then
			set[id] = true
			added = true
		end
	end)
	return added
end

local function awardBadge(player: Player, badgeId: number)
	if type(badgeId) ~= "number" or badgeId == 0 then
		return
	end
	local data = DataService.Get(player)
	if not data or data.BadgesAwarded[tostring(badgeId)] then
		return
	end
	task.spawn(function()
		local ok, awarded = pcall(function()
			return BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if ok and awarded then
			DataService.Update(player, function(d)
				d.BadgesAwarded[tostring(badgeId)] = true
			end)
		elseif not ok then
			warn("[ProgressService] Couldn't award badge " .. badgeId .. ": " .. tostring(awarded))
		end
	end)
end

local function announce(player: Player, ids: { string })
	local coins = 0
	for _, id in ipairs(ids) do
		coins += Achievements.ById[id].Coins or 0
	end
	if #ids <= 2 then
		for _, id in ipairs(ids) do
			local def = Achievements.ById[id]
			Net.Fire("Notify", player, { Title = "🏆 Achievement unlocked!", Text = ("%s %s · +%d 🪙"):format(def.Icon, def.Name, def.Coins or 0), Kind = "Important", Duration = 5 })
		end
	else
		Net.Fire("Notify", player, { Title = ("🏆 %d achievements unlocked!"):format(#ids), Text = ("+%d 🪙 · see 🏆 Achievements"):format(coins), Kind = "Important", Duration = 6 })
	end
	Net.Fire("AchievementsUnlocked", player, ids)
end

-- Unlocks achievements `ids` (skipping ones already unlocked). Returns the new ones.
local function unlockMany(player: Player, ids: { string }): { string }
	local fresh = {}
	DataService.Update(player, function(d)
		for _, id in ipairs(ids) do
			local def = Achievements.ById[id]
			if def and not d.Achievements[id] then
				d.Achievements[id] = os.time()
				CoinRewards.GrantBonus(d, def.Coins or 0)
				table.insert(fresh, id)
			end
		end
	end)
	if #fresh > 0 then
		announce(player, fresh)
		for _, id in ipairs(fresh) do
			awardBadge(player, Badges.ForAchievement[id] or 0)
			ProgressService.AchievementUnlocked:Fire(player, id)
		end
	end
	return fresh
end

-- For event achievements. Returns true if it was newly unlocked.
function ProgressService.Unlock(player: Player, achievementId: string): boolean
	return #unlockMany(player, { achievementId }) > 0
end

-- Checks every progress achievement against the player's data.
function ProgressService.Evaluate(player: Player): { string }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	local ready = {}
	for _, def in ipairs(Achievements.List) do
		if not def.Event and not data.Achievements[def.Id] then
			local current, target = Achievements.ProgressOf(def.Id, data)
			if current >= target then
				table.insert(ready, def.Id)
			end
		end
	end
	if #ready == 0 then
		return {}
	end
	return unlockMany(player, ready)
end

-- Badges for achievements unlocked before their badge id was configured.
local function catchUpBadges(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	awardBadge(player, Badges.Welcome)
	for id in pairs(data.Achievements) do
		awardBadge(player, Badges.ForAchievement[id] or 0)
	end
end

function ProgressService.Init()
	DataService.Changed:Connect(function(player)
		if queued[player] then
			return
		end
		queued[player] = true
		task.defer(function()
			queued[player] = nil
			if player.Parent then
				ProgressService.Evaluate(player)
			end
		end)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		ProgressService.Evaluate(player)
		catchUpBadges(player)
	end)
end

-- Tutorial progress: the furthest step reached, "Done" or "Reset" (Help → replay).
function ProgressService.SetTutorial(player: Player, step: any)
	if step == "Done" or step == "Reset" then
		DataService.Update(player, function(d)
			d.Tutorial.Completed = step == "Done"
			if step == "Reset" then
				d.Tutorial.Step = 0
			end
		end)
		return true
	end
	local n = Validate.Integer(step, 0, 20)
	if not n then
		return false, "BadArgs"
	end
	DataService.Update(player, function(d)
		d.Tutorial.Step = math.max(d.Tutorial.Step or 0, n)
	end)
	return true
end

function ProgressService.Start()
	Net.Handle("TutorialStep", ProgressService.SetTutorial)
end

return ProgressService
