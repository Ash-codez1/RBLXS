--[[
	RevealService  (ServerScriptService.Server.Services.RevealService)
	Friends' Life Reveals: lets players compare predicted futures with
	others in the same server, respecting each player's privacy settings
	(Settings → Privacy):
	  ShareReveals  who may see your predicted futures at all
	  ShareStats    who may also see your exact stats and net worth
	  ShareHistory  who may see the endings of your past lives
	Each is Everyone / Friends / Nobody. "Friends" uses Roblox friendships.

	Remote: GetLifeCards() -> true, { card per player in the server }
	(Group reveal sessions arrive with multiplayer in Phase 6.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local Style = require(ReplicatedStorage:WaitForChild("Shared").Util.Style)

local DataService = require(script.Parent.DataService)
local SettingsService = require(script.Parent.SettingsService)
local Reveal = require(script.Parent.Parent.Lib.Reveal)

local RevealService = {}
RevealService.Priority = 35
RevealService.FriendCacheSeconds = 300

local friendCache: { [string]: { Value: boolean, Time: number } } = {}

-- Set by PartyService: members of the same Life Circle count as friends.
RevealService.ExtraFriendCheck = nil :: ((Player, Player) -> boolean)?

function RevealService.AreFriends(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = low .. ":" .. high
	local cached = friendCache[key]
	if cached and os.clock() - cached.Time < RevealService.FriendCacheSeconds then
		return cached.Value
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value = ok and result == true
	friendCache[key] = { Value = value, Time = os.clock() }
	return value
end

function RevealService.CardFor(viewer: Player, target: Player)
	local data = DataService.Get(target)
	if not data then
		return nil
	end
	local partyFriend = RevealService.ExtraFriendCheck ~= nil and RevealService.ExtraFriendCheck(viewer, target)
	local relation = if viewer == target then "Self" elseif partyFriend or RevealService.AreFriends(viewer, target) then "Friend" else "Stranger"
	local entry = {
		UserId = target.UserId,
		DisplayName = target.DisplayName or target.Name,
		IsYou = relation == "Self",
		IsFriend = relation == "Friend",
		Style = Style.Public(data.Inventory.Equipped), -- cosmetics are for showing off
	}
	if SettingsService.CanView(target, "ShareHistory", relation) then
		local endings = {}
		for i = #data.LifeHistory, math.max(1, #data.LifeHistory - 2), -1 do
			local h = data.LifeHistory[i]
			table.insert(endings, { Icon = h.Ending.Icon, Title = h.Ending.Title, Name = h.Name })
		end
		entry.Endings = endings
	end
	if not SettingsService.CanView(target, "ShareReveals", relation) then
		entry.Hidden = true
		return entry
	end
	local life = data.Slots[data.ActiveSlot]
	if type(life) ~= "table" then
		entry.NoLife = true
		return entry
	end
	entry.Card = Reveal.Card(life, SettingsService.CanView(target, "ShareStats", relation))
	return entry
end

function RevealService.CardsFor(viewer: Player)
	local cards = {}
	for _, target in ipairs(Players:GetPlayers()) do
		local card = RevealService.CardFor(viewer, target)
		if card then
			table.insert(cards, card)
		end
	end
	table.sort(cards, function(a, b)
		if a.IsYou ~= b.IsYou then
			return a.IsYou
		end
		if a.IsFriend ~= b.IsFriend then
			return a.IsFriend
		end
		return a.DisplayName < b.DisplayName
	end)
	return cards
end

function RevealService.Init() end

function RevealService.Start()
	Net.Handle("GetLifeCards", function(player)
		if not DataService.IsLoaded(player) then
			return false, "NotLoaded"
		end
		return true, RevealService.CardsFor(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for key in pairs(friendCache) do
			if key:find(tostring(player.UserId), 1, true) then
				friendCache[key] = nil
			end
		end
	end)
end

return RevealService
