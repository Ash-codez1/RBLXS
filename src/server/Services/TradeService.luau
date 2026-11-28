--[[
	TradeService  (ServerScriptService.Server.Services.TradeService)
	🔄 Trading cosmetic items between two players in the same server.
	Only items bought with Coins can be traded (Catalog.IsTradable); VIP
	items, Coins and anything bought with Robux never change hands.

	Flow (every step checked on the server):
	  1. TradeRequestSend(userId) → the other player gets a request (30 s).
	  2. TradeRespond(requestId, true) opens a trade window for both.
	  3. TradeSetOffer(sessionId, { itemIds }) — up to MaxItems you own that
	     the other player doesn't. Any change un-readies BOTH players and
	     bumps the offer Version.
	  4. TradeReady(sessionId, version, true) — you lock in the exact version
	     you saw, so nobody can switch items after you agree. When both are
	     ready a short countdown runs; either player can still cancel.
	  5. The server re-checks everything (both still here, own the items,
	     can receive them), swaps both inventories in one step with no
	     yielding in between, records the trade id in both profiles (a trade
	     is applied at most once) and saves both players immediately.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Catalog = require(Shared.Data.Catalog)
local TableUtil = require(Shared.Util.TableUtil)

local Server = script.Parent.Parent
local Validate = require(Server.Lib.Validate)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local TradeService = {}
TradeService.Priority = 28
TradeService.MaxItems = 6
TradeService.RequestSeconds = 30
TradeService.RequestCooldown = 8
TradeService.CountdownSeconds = 3
TradeService.MaxLog = 20
TradeService.Completed = Signal.new() -- (playerA, playerB, tradeId)

local requests = {}
local sessions = {}
local sessionOf: { [Player]: any } = {}
local lastRequest: { [Player]: number } = {}
local counter = 0

local function nextId(prefix: string): string
	counter += 1
	return prefix .. counter
end

local function name(player: Player): string
	return player.DisplayName or player.Name
end

local function playerById(userId: number): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function other(session, player: Player): Player
	return if session.A == player then session.B else session.A
end

local function itemInfo(ids: { string })
	local out = {}
	for _, id in ipairs(ids) do
		local item = Catalog.Get(id)
		if item then
			table.insert(out, { Id = id, Name = item.Name, Icon = item.Icon, Rarity = item.Rarity })
		end
	end
	return out
end

local function stateFor(session, player: Player)
	local them = other(session, player)
	return {
		SessionId = session.Id,
		Version = session.Version,
		With = { UserId = them.UserId, Name = name(them) },
		Mine = itemInfo(session.Offers[player]),
		Theirs = itemInfo(session.Offers[them]),
		MyReady = session.Ready[player] == true,
		TheirReady = session.Ready[them] == true,
		Countdown = session.CountdownEnds and math.max(0, math.ceil(session.CountdownEnds - os.clock())) or nil,
	}
end

local function broadcast(session)
	for _, player in ipairs({ session.A, session.B }) do
		Net.Fire("TradeUpdate", player, stateFor(session, player))
	end
end

local function close(session, reason: string, extra)
	if session.Done then
		return
	end
	session.Done = true
	sessions[session.Id] = nil
	for _, player in ipairs({ session.A, session.B }) do
		if sessionOf[player] == session then
			sessionOf[player] = nil
		end
		local payload = { Closed = true, Reason = reason, SessionId = session.Id }
		if extra then
			payload.Completed = true
			payload.Gave = itemInfo(session.Offers[player])
			payload.Got = itemInfo(session.Offers[other(session, player)])
		end
		Net.Fire("TradeUpdate", player, payload)
	end
end

function TradeService.SessionOf(player: Player)
	return sessionOf[player]
end

-- ===== Requests =====
function TradeService.Request(player: Player, targetUserId: number)
	local target = playerById(targetUserId)
	if not target or target == player then
		return false, "NotHere"
	end
	if not DataService.Get(player) or not DataService.Get(target) then
		return false, "NotLoaded"
	end
	if sessionOf[player] then
		return false, "AlreadyTrading"
	end
	if sessionOf[target] then
		return false, "TheyAreTrading"
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < TradeService.RequestCooldown then
		return false, "Cooldown"
	end
	lastRequest[player] = now
	local id = nextId("tr")
	requests[id] = { Id = id, From = player, To = target, Expires = now + TradeService.RequestSeconds }
	Net.Fire("TradeRequest", target, { RequestId = id, FromUserId = player.UserId, FromName = name(player), Seconds = TradeService.RequestSeconds })
	return true, id
end

function TradeService.Respond(player: Player, requestId: string, accept: boolean)
	local request = requests[requestId]
	if not request or request.To ~= player then
		return false, "NoRequest"
	end
	requests[requestId] = nil
	local from = request.From
	if os.clock() > request.Expires then
		return false, "Expired"
	end
	if not accept then
		Net.Fire("Notify", from, { Title = "🔄 Trade", Text = name(player) .. " declined your trade request.", Kind = "Info" })
		return true, "Declined"
	end
	if not from.Parent then
		return false, "NotHere"
	end
	if sessionOf[player] or sessionOf[from] then
		return false, "AlreadyTrading"
	end
	local session = { Id = nextId("ts"), A = from, B = player, Offers = { [from] = {}, [player] = {} }, Ready = {}, Version = 1 }
	sessions[session.Id] = session
	sessionOf[from] = session
	sessionOf[player] = session
	broadcast(session)
	return true, session.Id
end

-- ===== Offers =====
-- Checks `ids` can go from `giver` to `receiver`: ok, reason.
function TradeService.CheckOffer(giver: Player, receiver: Player, ids: { string }): (boolean, string?)
	local giverData, receiverData = DataService.Get(giver), DataService.Get(receiver)
	if not giverData or not receiverData then
		return false, "NotLoaded"
	end
	local seen = {}
	for _, id in ipairs(ids) do
		local item = Catalog.Get(id)
		if seen[id] then
			return false, "Duplicate"
		end
		seen[id] = true
		if not Catalog.IsTradable(item) then
			return false, "NotTradable"
		end
		if not giverData.Inventory.Owned[id] then
			return false, "NotOwned"
		end
		if receiverData.Inventory.Owned[id] then
			return false, "TheyOwnIt"
		end
	end
	return true, nil
end

local function cancelCountdown(session)
	session.CountdownEnds = nil
	session.CountdownToken = nil
end

function TradeService.SetOffer(player: Player, sessionId: string, itemIds: any)
	local session = sessions[sessionId]
	if not session or sessionOf[player] ~= session or session.Done then
		return false, "NoTrade"
	end
	if type(itemIds) ~= "table" or #itemIds > TradeService.MaxItems then
		return false, "TooMany"
	end
	local ids = {}
	for i = 1, #itemIds do
		local id = Validate.Id(itemIds[i], 40)
		if not id then
			return false, "BadArgs"
		end
		table.insert(ids, id)
	end
	local ok, reason = TradeService.CheckOffer(player, other(session, player), ids)
	if not ok then
		return false, reason
	end
	session.Offers[player] = ids
	session.Ready = {}
	session.Version += 1
	cancelCountdown(session)
	broadcast(session)
	return true, session.Version
end

-- ===== Completing a trade =====
local function applySide(d, gives: { string }, gets: { string }, tradeId: string, withName: string)
	for _, id in ipairs(gives) do
		d.Inventory.Owned[id] = nil
		for slot, equipped in pairs(d.Inventory.Equipped) do
			if equipped == id then
				d.Inventory.Equipped[slot] = nil
			end
		end
	end
	for _, id in ipairs(gets) do
		d.Inventory.Owned[id] = true
	end
	d.Lifetime.TradesCompleted += 1
	table.insert(d.ProcessedTrades, tradeId)
	TableUtil.TrimArray(d.ProcessedTrades, 50)
	table.insert(d.TradeLog, { Id = tradeId, With = withName, Gave = table.clone(gives), Got = table.clone(gets), Time = os.time() })
	TableUtil.TrimArray(d.TradeLog, TradeService.MaxLog)
end

function TradeService.Execute(session)
	local a, b = session.A, session.B
	if session.Done or not a.Parent or not b.Parent then
		close(session, "A player left.")
		return false, "Gone"
	end
	local giveA, giveB = session.Offers[a], session.Offers[b]
	if #giveA + #giveB == 0 then
		return false, "Empty"
	end
	local okA, reasonA = TradeService.CheckOffer(a, b, giveA)
	local okB, reasonB = TradeService.CheckOffer(b, a, giveB)
	if not okA or not okB then
		session.Ready = {}
		cancelCountdown(session)
		broadcast(session)
		return false, reasonA or reasonB
	end
	local tradeId = HttpService:GenerateGUID(false)
	local dataA, dataB = DataService.Get(a), DataService.Get(b)
	if table.find(dataA.ProcessedTrades, tradeId) or table.find(dataB.ProcessedTrades, tradeId) then
		return false, "Duplicate"
	end
	-- Both inventories change together: no yields between these two updates.
	DataService.Update(a, function(d)
		applySide(d, giveA, giveB, tradeId, name(b))
	end)
	DataService.Update(b, function(d)
		applySide(d, giveB, giveA, tradeId, name(a))
	end)
	close(session, "Trade complete!", true)
	for _, player in ipairs({ a, b }) do
		ShopService.EquipmentChanged:Fire(player)
		task.spawn(function()
			if not DataService.SaveNow(player) then
				warn("[TradeService] Save after trade " .. tradeId .. " failed for " .. player.Name .. "; it will be saved with the next autosave")
			end
		end)
	end
	TradeService.Completed:Fire(a, b, tradeId)
	return true, tradeId
end

function TradeService.SetReady(player: Player, sessionId: string, version: any, ready: any)
	local session = sessions[sessionId]
	if not session or sessionOf[player] ~= session or session.Done then
		return false, "NoTrade"
	end
	if version ~= session.Version then
		return false, "Changed" -- the offer changed since you looked
	end
	session.Ready[player] = ready == true
	if not session.Ready[player] then
		cancelCountdown(session)
		broadcast(session)
		return true
	end
	local them = other(session, player)
	if session.Ready[them] and #session.Offers[player] + #session.Offers[them] > 0 then
		local token = {}
		session.CountdownToken = token
		session.CountdownEnds = os.clock() + TradeService.CountdownSeconds
		local lockedVersion = session.Version
		task.delay(TradeService.CountdownSeconds, function()
			if session.CountdownToken == token and session.Version == lockedVersion and session.Ready[session.A] and session.Ready[session.B] then
				TradeService.Execute(session)
			end
		end)
	end
	broadcast(session)
	return true
end

function TradeService.Cancel(player: Player, sessionId: any)
	local session = sessionOf[player]
	if not session or (sessionId ~= nil and session.Id ~= sessionId) then
		return false, "NoTrade"
	end
	close(session, name(player) .. " cancelled the trade.")
	return true
end

function TradeService.Init()
	Players.PlayerRemoving:Connect(function(player)
		local session = sessionOf[player]
		if session then
			close(session, name(player) .. " left the server.")
		end
		for id, request in pairs(requests) do
			if request.From == player or request.To == player then
				requests[id] = nil
			end
		end
		lastRequest[player] = nil
	end)
end

function TradeService.Start()
	Net.Handle("TradeRequestSend", function(player, userId)
		local id = Validate.Integer(userId, -1e12, 1e12)
		if not id then
			return false, "BadArgs"
		end
		return TradeService.Request(player, id)
	end)
	Net.Handle("TradeRespond", function(player, requestId, accept)
		local id = Validate.Id(requestId, 16)
		if not id or type(accept) ~= "boolean" then
			return false, "BadArgs"
		end
		return TradeService.Respond(player, id, accept)
	end)
	Net.Handle("TradeSetOffer", function(player, sessionId, itemIds)
		local id = Validate.Id(sessionId, 16)
		if not id then
			return false, "BadArgs"
		end
		return TradeService.SetOffer(player, id, itemIds)
	end)
	Net.Handle("TradeReady", function(player, sessionId, version, ready)
		local id = Validate.Id(sessionId, 16)
		if not id or type(version) ~= "number" then
			return false, "BadArgs"
		end
		return TradeService.SetReady(player, id, version, ready)
	end)
	Net.Handle("TradeCancel", function(player, sessionId)
		return TradeService.Cancel(player, Validate.Id(sessionId, 16))
	end)
end

return TradeService
