--[[
	LeaderboardService  (ServerScriptService.Server.Services.LeaderboardService)
	🏆 Global and friends leaderboards (Shared/Data/Leaderboards), the Hall of
	Fame board in Lifeville Plaza, and the player list (leaderstats).

	Global boards use one OrderedDataStore per board ("CYL_LB_<board>"):
	  • scores come from saved profiles on the server, never from clients;
	  • written when they change (every SubmitSeconds) and when you leave,
	    only while the DataStore request budget allows;
	  • players who set Privacy → My life stats to "Nobody" are removed
	    from global boards and the player list.
	Friends boards: your Roblox friends (Players:GetFriendsAsync), with live
	scores for friends in this server and cached lookups for the rest.
	In Studio without API access an in-memory store is used (nothing saved).
]]

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Leaderboards = require(Shared.Data.Leaderboards)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Validate = require(Server.Lib.Validate)
local MockOrderedDataStore = require(Server.Lib.MockOrderedDataStore)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}
LeaderboardService.Priority = 26
LeaderboardService.SubmitSeconds = 120
LeaderboardService.CacheSeconds = 120
LeaderboardService.FriendCacheSeconds = 300
LeaderboardService.FriendLookups = 25 -- most DataStore reads one friends board request may make
LeaderboardService.TopSize = 50

local stores = {}
local submitted: { [Player]: { [string]: any } } = {}
local topCache = {}
local nameCache: { [number]: string } = {}
local friendCache: { [Player]: { Time: number, Ids: { number } } } = {}
local valueCache = {}

local function usingMock(): boolean
	return DataService.UsingMockStore == true
end

local function store(boardId: string)
	if stores[boardId] then
		return stores[boardId]
	end
	local s = nil
	if not usingMock() then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore("CYL_LB_" .. boardId)
		end)
		if ok then
			s = result
		end
	end
	s = s or MockOrderedDataStore.new()
	stores[boardId] = s
	return s
end

local function budget(requestType): boolean
	local ok, value = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(requestType)
	end)
	return not ok or value > 0
end

local function playerById(userId: number): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function hidden(data): boolean
	return data.Privacy and data.Privacy.ShareStats == "Nobody"
end

-- Writes this player's scores to the global boards if they changed.
function LeaderboardService.Submit(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	submitted[player] = submitted[player] or {}
	local mine = submitted[player]
	local key = tostring(player.UserId)
	for _, board in ipairs(Leaderboards.List) do
		local s = store(board.Id)
		if hidden(data) then
			if mine[board.Id] ~= "removed" and budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
				if pcall(s.RemoveAsync, s, key) then
					mine[board.Id] = "removed"
				end
			end
		else
			local value = math.floor(board.Value(data))
			if value > 0 and mine[board.Id] ~= value and budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
				local ok, err = pcall(s.SetAsync, s, key, value)
				if ok then
					mine[board.Id] = value
				else
					warn("[LeaderboardService] Couldn't save " .. board.Id .. ": " .. tostring(err))
				end
			end
		end
	end
	topCache = {} -- fresh scores show on the next look
end

local function resolveNames(ids: { number })
	local missing = {}
	for _, id in ipairs(ids) do
		local player = playerById(id)
		if player then
			nameCache[id] = player.DisplayName or player.Name
		elseif not nameCache[id] then
			table.insert(missing, id)
		end
	end
	if #missing > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if ok and type(infos) == "table" then
			for _, info in ipairs(infos) do
				nameCache[info.Id] = info.DisplayName or info.Username
			end
		end
	end
end

-- Top scores worldwide: { { Rank, UserId, Name, Value } }.
function LeaderboardService.Top(boardId: string, force: boolean?)
	local cached = topCache[boardId]
	if cached and not force and os.clock() - cached.Time < LeaderboardService.CacheSeconds then
		return cached.Entries
	end
	if not budget(Enum.DataStoreRequestType.GetSortedAsync) then
		return if cached then cached.Entries else {}
	end
	local s = store(boardId)
	local ok, pages = pcall(s.GetSortedAsync, s, false, LeaderboardService.TopSize)
	if not ok then
		warn("[LeaderboardService] Couldn't read " .. boardId .. ": " .. tostring(pages))
		return if cached then cached.Entries else {}
	end
	local entries, ids = {}, {}
	for rank, item in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { Rank = rank, UserId = userId, Value = item.value })
			table.insert(ids, userId)
		end
	end
	resolveNames(ids)
	for _, entry in ipairs(entries) do
		entry.Name = nameCache[entry.UserId] or ("Player " .. entry.UserId)
	end
	topCache[boardId] = { Time = os.clock(), Entries = entries }
	return entries
end

local function friendIds(player: Player): { number }
	local cached = friendCache[player]
	if cached and os.clock() - cached.Time < LeaderboardService.FriendCacheSeconds then
		return cached.Ids
	end
	local ids = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if ok and pages then
		local okPage, page = pcall(function()
			return pages:GetCurrentPage()
		end)
		if okPage and type(page) == "table" then
			for _, friend in ipairs(page) do
				table.insert(ids, friend.Id)
				nameCache[friend.Id] = friend.DisplayName or friend.Username
			end
		end
	end
	friendCache[player] = { Time = os.clock(), Ids = ids }
	return ids
end

-- You and your Roblox friends, best first.
function LeaderboardService.Friends(player: Player, boardId: string)
	local board = Leaderboards.ById[boardId]
	local data = DataService.Get(player)
	local entries = {}
	if data then
		table.insert(entries, { UserId = player.UserId, Name = player.DisplayName or player.Name, Value = math.floor(board.Value(data)) })
	end
	local s = store(boardId)
	local lookups = 0
	for _, id in ipairs(friendIds(player)) do
		local friend = playerById(id)
		local friendData = friend and DataService.Get(friend)
		if friendData then
			if not hidden(friendData) then
				table.insert(entries, { UserId = id, Name = friend.DisplayName or friend.Name, Value = math.floor(board.Value(friendData)), InServer = true })
			end
		else
			local key = boardId .. ":" .. id
			local cached = valueCache[key]
			if not (cached and os.clock() - cached.Time < LeaderboardService.FriendCacheSeconds) and lookups < LeaderboardService.FriendLookups and budget(Enum.DataStoreRequestType.GetAsync) then
				lookups += 1
				local ok, value = pcall(s.GetAsync, s, tostring(id))
				cached = { Time = os.clock(), Value = if ok then value else nil }
				valueCache[key] = cached
			end
			if cached and type(cached.Value) == "number" then
				table.insert(entries, { UserId = id, Name = nameCache[id] or ("Player " .. id), Value = cached.Value })
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.Value == b.Value then
			return a.UserId < b.UserId
		end
		return a.Value > b.Value
	end)
	for rank, entry in ipairs(entries) do
		entry.Rank = rank
	end
	return entries
end

-- ===== Hall of Fame (Plaza) and the player list =====
function LeaderboardService.UpdateHallOfFame()
	local board = Leaderboards.ById[Leaderboards.HallOfFame]
	local entries = LeaderboardService.Top(board.Id, true)
	local lines = { "🏆 HALL OF FAME", board.Icon .. " " .. board.Name }
	for i = 1, 5 do
		local e = entries[i]
		table.insert(lines, if e then ("%d. %s · %s"):format(i, e.Name, if board.Money then Format.Money(e.Value) else tostring(e.Value)) else ("%d. —"):format(i))
	end
	local text = table.concat(lines, "\n")
	for _, part in ipairs(CollectionService:GetTagged("CYL_HallOfFame")) do
		local gui = part:FindFirstChild("Text")
		local label = gui and gui:FindFirstChild("Label")
		if label then
			label.Text = text
		end
	end
	return text
end

local function updateLeaderstats(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local folder = player:FindFirstChild("leaderstats")
	if hidden(data) then
		if folder then
			folder:Destroy()
		end
		return
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		for _, name in ipairs({ "Lives", "Trophies" }) do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = folder
		end
		folder.Parent = player
	end
	folder.Lives.Value = data.Lifetime.LivesCompleted or 0
	folder.Trophies.Value = Leaderboards.ById.Achievements.Value(data)
end
LeaderboardService.UpdateLeaderstats = updateLeaderstats

function LeaderboardService.Init()
	DataService.ProfileLoaded:Connect(updateLeaderstats)
	DataService.Changed:Connect(updateLeaderstats)
	DataService.ProfileReleasing:Connect(function(player)
		LeaderboardService.Submit(player)
		submitted[player] = nil
		friendCache[player] = nil
	end)
end

function LeaderboardService.Start()
	local ids = {}
	for _, board in ipairs(Leaderboards.List) do
		table.insert(ids, board.Id)
	end
	Net.Handle("GetLeaderboard", function(player, boardId, scope)
		local id = Validate.OneOf(boardId, ids)
		local which = Validate.OneOf(scope, { "Global", "Friends" })
		if not id or not which then
			return false, "BadArgs"
		end
		LeaderboardService.Submit(player)
		local entries = if which == "Global" then LeaderboardService.Top(id) else LeaderboardService.Friends(player, id)
		local you = nil
		for _, entry in ipairs(entries) do
			if entry.UserId == player.UserId then
				you = entry
			end
		end
		return true, { Board = id, Scope = which, Entries = entries, You = you, Offline = usingMock() }
	end)
	task.spawn(function()
		while true do
			pcall(LeaderboardService.UpdateHallOfFame)
			task.wait(LeaderboardService.SubmitSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(LeaderboardService.Submit, player)
			end
		end
	end)
end

return LeaderboardService
