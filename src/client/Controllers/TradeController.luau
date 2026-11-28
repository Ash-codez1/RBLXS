--[[
	TradeController  (StarterPlayerScripts.Client.Controllers.TradeController)
	🔄 Trading cosmetics with another player in this server.
	  • Offer a trade from the Friends screen or someone's profile; they get
	    a request card (Accept / No thanks).
	  • The trade window shows both offers, your tradable items (tap to add
	    or remove, up to 6), each side's Ready state and the countdown.
	  • Ready locks in exactly what you can see. If anyone changes their
	    offer, both of you have to press Ready again.
	  • Only items bought with Coins can be traded. The server checks
	    everything and swaps both inventories at once (TradeService).
	Closing the window cancels the trade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Catalog = require(Shared.Data.Catalog)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local PartyController = require(script.Parent.PartyController)

local TradeController = {}
TradeController.Priority = 66

local ERRORS = {
	NotHere = "That player isn't in this server.",
	NotLoaded = "Still loading. Try again in a moment.",
	AlreadyTrading = "You're already in a trade.",
	TheyAreTrading = "They're already trading with someone.",
	Cooldown = "Wait a few seconds before sending another request.",
	NoRequest = "That trade request has expired.",
	Expired = "That trade request has expired.",
	NotOwned = "You don't own that item any more.",
	NotTradable = "That item can't be traded.",
	TheyOwnIt = "They already own that item.",
	TooMany = "You can offer up to 6 items.",
	Changed = "The offer changed. Check it again, then press Ready.",
	RateLimited = "Slow down a moment.",
}

local state = nil -- the latest TradeUpdate for an open trade
local handle = nil
local closingFromServer = false

function TradeController.State()
	return state
end

local function errorText(reason): string
	return ERRORS[reason] or tostring(reason)
end

function TradeController.Request(userId: number)
	local ok, result = Net.Invoke("TradeRequestSend", userId)
	if ok then
		NotificationController.Notify({ Title = "🔄 Trade request sent", Text = "They have 30 seconds to accept.", Kind = "Success", Duration = 3 })
	else
		NotificationController.Notify({ Title = "🔄 Couldn't send", Text = errorText(result), Kind = "Warning" })
	end
	return ok, result
end

local function myOffer(): { string }
	local ids = {}
	for _, item in ipairs(state and state.Mine or {}) do
		table.insert(ids, item.Id)
	end
	return ids
end

local function toggle(itemId: string)
	if not state then
		return
	end
	local ids = myOffer()
	local index = table.find(ids, itemId)
	if index then
		table.remove(ids, index)
	else
		table.insert(ids, itemId)
	end
	local ok, result = Net.Invoke("TradeSetOffer", state.SessionId, ids)
	if not ok then
		NotificationController.Notify({ Title = "🔄 Trade", Text = errorText(result), Kind = "Warning" })
	end
end

local function itemChips(parent, items, order: number, empty: string)
	local holder = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent })
	local list = Create.List(Enum.FillDirection.Horizontal, 6)
	list.Wraps = true
	list.Parent = holder
	if #items == 0 then
		Create.Label({ Text = empty, TextColor3 = Theme.Color.TextFaint, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.XY, Parent = holder })
	end
	for i, item in ipairs(items) do
		local chip = Components.Chip({ Text = item.Icon .. " " .. item.Name, Height = 32, LayoutOrder = i, Parent = holder })
		chip.Name = "Offer_" .. item.Id
	end
	return holder
end

local function render()
	if not handle or not state then
		return
	end
	handle.Clear()
	handle.Subtitle.Text = if state.Countdown then ("Trading in %d…"):format(state.Countdown) else "Both players must press Ready"
	local scroll = handle.Scroll
	local sides = Create("Frame", { Name = "Sides", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	local narrow = UIController.IsNarrow()
	local list = Create.List(if narrow then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal, 12)
	list.Parent = sides
	local width = if narrow then UDim2.new(1, 0, 0, 0) else UDim2.new(0.5, -6, 0, 0)
	for i, side in ipairs({ { "YOU GIVE", state.Mine, state.MyReady, "Mine" }, { state.With.Name:upper() .. " GIVES", state.Theirs, state.TheirReady, "Theirs" } }) do
		local panel = Components.Panel({ Name = side[4], Size = width, AutomaticSize = Enum.AutomaticSize.Y, Padding = 12, LayoutOrder = i, Parent = sides, Color = Theme.Color.SurfaceHigh })
		Create.List(Enum.FillDirection.Vertical, 8).Parent = panel
		Create.Label({ Text = side[1], TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = panel })
		itemChips(panel, side[2], 2, "Nothing yet")
		Create.Label({ Name = "ReadyState", Text = if side[3] then "✅ Ready" else "⏳ Not ready", TextColor3 = if side[3] then Theme.Color.Positive else Theme.Color.TextDim, FontFace = Theme.Font.Bold, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, Parent = panel })
	end

	-- Your tradable items
	Create.Label({ Text = "YOUR TRADABLE ITEMS · tap to add or remove", TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 26), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = 2, Parent = scroll })
	local data = DataController.Get()
	local grid = Create("Frame", { Name = "Inventory", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = scroll })
	local gridList = Create.List(Enum.FillDirection.Horizontal, 8)
	gridList.Wraps = true
	gridList.Parent = grid
	local offered = {}
	for _, id in ipairs(myOffer()) do
		offered[id] = true
	end
	local count = 0
	for _, item in ipairs(Catalog.Items) do
		if data and data.Inventory.Owned[item.Id] and Catalog.IsTradable(item) then
			count += 1
			Components.Button({ Name = "Item_" .. item.Id, Text = item.Name, Icon = item.Icon, Style = if offered[item.Id] then "Primary" else "Secondary", Size = UDim2.fromOffset(200, 44), TextSize = 15, LayoutOrder = count, Parent = grid, OnClick = function()
				toggle(item.Id)
			end })
		end
	end
	if count == 0 then
		Create.Label({ Text = "You don't have any tradable items yet. Items bought with Coins in the shop can be traded; VIP items can't.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = grid })
	end

	local row = Create("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 4, Parent = scroll })
	Create.List(Enum.FillDirection.Horizontal, 10).Parent = row
	Components.Button({ Name = "ReadyButton", Text = if state.MyReady then "Not ready" else "Ready", Icon = if state.MyReady then "↩️" else "✅", Style = if state.MyReady then "Secondary" else "Primary", Size = UDim2.fromOffset(220, 52), Parent = row, LayoutOrder = 1, OnClick = function()
		local ok, result = Net.Invoke("TradeReady", state.SessionId, state.Version, not state.MyReady)
		if not ok then
			NotificationController.Notify({ Title = "🔄 Trade", Text = errorText(result), Kind = "Warning" })
		end
	end })
	Components.Button({ Name = "CancelTrade", Text = "Cancel", Icon = "✕", Style = "Ghost", Size = UDim2.fromOffset(160, 52), Parent = row, LayoutOrder = 2, OnClick = function()
		UIController.ClosePanel()
	end })
	Create.Label({ Text = "Check both offers carefully. Ready locks in what you see; any change means both of you press Ready again. Coins, VIP and Robux items can't be traded.", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = scroll })
end

local function openWindow()
	if handle and handle.IsOpen() then
		render()
		return
	end
	handle = UIController.OpenPanel({ Name = "TradeModal", Title = "🔄  Trade with " .. state.With.Name, Width = 800, Height = 660, OnClose = function()
		if not closingFromServer and state then
			Net.Invoke("TradeCancel", state.SessionId)
		end
		handle = nil
	end })
	render()
end

local function onUpdate(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Closed then
		state = nil
		if handle and handle.IsOpen() then
			closingFromServer = true
			UIController.ClosePanel()
			closingFromServer = false
		end
		handle = nil
		if payload.Completed then
			local got = {}
			for _, item in ipairs(payload.Got or {}) do
				table.insert(got, item.Icon .. " " .. item.Name)
			end
			NotificationController.Notify({ Title = "✅ Trade complete!", Text = if #got > 0 then "You got: " .. table.concat(got, ", ") else "Your items were sent.", Kind = "Important", Duration = 5 })
		else
			NotificationController.Notify({ Title = "🔄 Trade ended", Text = payload.Reason or "The trade was cancelled.", Kind = "Info" })
		end
		return
	end
	state = payload
	openWindow()
end

local function onRequest(request)
	PartyController.PromptCard("Trade" .. request.RequestId, "🔄 " .. request.FromName .. " wants to trade", "Swap cosmetic items with them. You'll both see the offers and must press Ready before anything changes hands.", request.Seconds or 30, {
		{ Name = "AcceptTrade", Text = "Trade", OnClick = function()
			local ok, result = Net.Invoke("TradeRespond", request.RequestId, true)
			if not ok then
				NotificationController.Notify({ Title = "🔄 Couldn't start the trade", Text = errorText(result), Kind = "Warning" })
			end
		end },
		{ Name = "DeclineTrade", Text = "No thanks", OnClick = function()
			Net.Invoke("TradeRespond", request.RequestId, false)
		end },
	})
end

function TradeController.Init() end

function TradeController.Start()
	Net.OnEvent("TradeRequest", onRequest)
	Net.OnEvent("TradeUpdate", onUpdate)
	DataController.Changed:Connect(function()
		if handle and handle.IsOpen() then
			render()
		end
	end)
end

return TradeController
