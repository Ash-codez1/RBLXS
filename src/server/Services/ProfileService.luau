--[[
	ProfileService  (ServerScriptService.Server.Services.ProfileService)
	👤 Player profiles and statistics: GetProfile(userId) for yourself or
	anyone in this server. What others see follows their privacy settings:
	  • the name, look, title, Legacy level and achievement / star counts
	    are always shown;
	  • lifetime statistics and the current life need "My life stats" to be
	    Everyone, or Friends (Roblox friends and Life Circle members);
	  • recent lives need "Past lives" to allow you.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Style = require(Shared.Util.Style)
local Achievements = require(Shared.Data.Achievements)
local Collectibles = require(Shared.Data.Collectibles)
local LifeStages = require(Shared.Data.LifeStages)
local Endings = require(Shared.Util.Endings)
local Legacy = require(Shared.Data.Legacy)

local Server = script.Parent.Parent
local Validate = require(Server.Lib.Validate)
local DataService = require(script.Parent.DataService)
local RevealService = require(script.Parent.RevealService)
local SettingsService = require(script.Parent.SettingsService)

local ProfileService = {}
ProfileService.Priority = 27

local count = Achievements.Count

-- Same relationship rules as Life Reveal comparisons (circle members count as friends).
local function relation(viewer: Player, target: Player): string
	if viewer == target then
		return "Self"
	end
	local circle = RevealService.ExtraFriendCheck ~= nil and RevealService.ExtraFriendCheck(viewer, target)
	return if circle or RevealService.AreFriends(viewer, target) then "Friend" else "Stranger"
end

function ProfileService.Build(viewer: Player, target: Player)
	local data = DataService.Get(target)
	if not data then
		return nil
	end
	local rel = relation(viewer, target)
	local lifetime = data.Lifetime
	local endingIcons = {}
	for _, ending in ipairs(Endings.List) do
		if lifetime.EndingsSeen[ending.Id] then
			table.insert(endingIcons, ending.Icon)
		end
	end
	local profile = {
		UserId = target.UserId,
		DisplayName = target.DisplayName or target.Name,
		IsYou = viewer == target,
		Style = Style.Public(data.Inventory.Equipped),
		LegacyLevel = Legacy.Level(lifetime.LivesCompleted),
		Rebirths = lifetime.Rebirths,
		Achievements = count(data.Achievements),
		AchievementsTotal = #Achievements.List,
		Stars = count(data.Collectibles),
		StarsTotal = Collectibles.Total,
		Private = false,
	}
	if SettingsService.CanView(target, "ShareStats", rel) then
		profile.Stats = {
			LivesCompleted = lifetime.LivesCompleted,
			DecisionsMade = lifetime.DecisionsMade,
			HighestNetWorth = math.floor(lifetime.HighestNetWorth),
			CoinsEarned = lifetime.CoinsEarned,
			BestStreak = data.Daily.BestStreak,
			EndingsSeen = count(lifetime.EndingsSeen),
			EndingsTotal = #Endings.List,
			CareersHeld = count(lifetime.CareersHeld),
			WorldActions = lifetime.WorldActions,
			ShiftsWorked = lifetime.ShiftsWorked,
			DistrictsVisited = count(lifetime.DistrictsVisited),
			ChallengesCompleted = lifetime.ChallengesCompleted,
			TradesCompleted = lifetime.TradesCompleted,
		}
		profile.EndingIcons = endingIcons
		local life = data.Slots[data.ActiveSlot]
		if type(life) == "table" and not life.Completed then
			profile.CurrentLife = { Name = life.Name, Age = life.Age, Stage = LifeStages.Get(life.Stage).DisplayName, Legacy = life.Legacy }
		end
	else
		profile.Private = true
	end
	if SettingsService.CanView(target, "ShareHistory", rel) then
		profile.RecentLives = {}
		for i = #data.LifeHistory, math.max(1, #data.LifeHistory - 2), -1 do
			local entry = data.LifeHistory[i]
			table.insert(profile.RecentLives, { Name = entry.Name, Age = entry.Age, EndingIcon = entry.Ending.Icon, EndingTitle = entry.Ending.Title, Career = entry.Career, NetWorth = entry.NetWorth })
		end
	end
	return profile
end

function ProfileService.Get(viewer: Player, userId: number)
	local target = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			target = player
		end
	end
	if not target then
		return false, "NotHere"
	end
	local profile = ProfileService.Build(viewer, target)
	if not profile then
		return false, "NotLoaded"
	end
	return true, profile
end

function ProfileService.Init() end

function ProfileService.Start()
	Net.Handle("GetProfile", function(player, userId)
		local id = Validate.Integer(userId, -1e12, 1e12)
		if not id then
			return false, "BadArgs"
		end
		return ProfileService.Get(player, id)
	end)
end

return ProfileService
