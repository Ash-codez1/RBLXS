--[[
	FutureController  (StarterPlayerScripts.Client.Controllers.FutureController)
	The 🔮 Future panel:
	  • live odds for every possible future, recalculated from your current
	    life with the same model the server uses (Shared/Util/Futures)
	  • how your predicted future has changed at each Life Reveal so far
	  • compare predicted futures with other players in this server
	    (privacy-respecting; RevealService)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Futures = require(Shared.Util.Futures)
local Format = require(Shared.Util.Format)
local LifeStages = require(Shared.Data.LifeStages)
local StatDefinitions = require(Shared.Data.StatDefinitions)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)

local FutureController = {}
FutureController.Priority = 47

local handle = nil

local function bar(parent, order: number, icon: string, title: string, pct: number, positive: boolean, extra: string?)
	local row = Create("Frame", { Name = title, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = parent })
	Create.Label({ Text = icon .. "  " .. title .. (extra or ""), RichText = true, FontFace = Theme.Font.Bold, Size = UDim2.new(0.75, 0, 0, 22), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	Create.Label({ Name = "Pct", Text = pct .. "%", FontFace = Theme.Font.Heavy, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.25, 0, 0, 22), Position = UDim2.fromScale(0.75, 0), Parent = row })
	local track = Create("Frame", { BackgroundColor3 = Theme.Color.Background, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 26), Parent = row }, { Create.Corner(Theme.RadiusPill) })
	local color = if positive then (if pct >= 60 then Theme.Color.Positive elseif pct >= 35 then Theme.Color.Warning else Theme.Color.Accent) else Theme.Color.Negative
	Create("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(pct / 100, 1), Parent = track }, { Create.Corner(Theme.RadiusPill) })
end

local function heading(parent, text: string, order: number)
	Create.Label({ Text = text, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 24), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = parent })
end

local renderCompare

local function render()
	local life = DataController.GetActiveLife()
	if not handle or not life then
		return
	end
	handle.Clear()
	local scroll = handle.Scroll
	local predictions = Futures.Predict(life)
	local headline, warning = Futures.Headline(predictions)
	handle.Subtitle.Text = "Live odds · they change with every choice you make"
	Create.Label({ Text = headline, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	if warning then
		Create.Label({ Text = "⚠️ " .. warning, TextColor3 = Theme.Color.Warning, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	end
	local last = life.Reveals[#life.Reveals]
	local positives, risks = Futures.Sorted(predictions)
	heading(scroll, "POSSIBLE FUTURES", 3)
	for i, entry in ipairs(positives) do
		local extra = nil
		if last and last.Predictions and last.Predictions[entry.Id] then
			local diff = entry.Pct - last.Predictions[entry.Id]
			if math.abs(diff) >= 3 then
				extra = ("  <font color=\"%s\">%s%d</font>"):format(if diff > 0 then Theme.Hex.Positive else Theme.Hex.Negative, if diff > 0 then "▲" else "▼", math.abs(diff))
			end
		end
		bar(scroll, 3 + i, entry.Icon, entry.Title, entry.Pct, true, extra)
	end
	heading(scroll, "RISKS", 30)
	for i, entry in ipairs(risks) do
		bar(scroll, 30 + i, entry.Icon, entry.Title, entry.Pct, false)
	end

	local journey = {}
	for _, r in ipairs(life.Reveals) do
		if r.Predictions then
			table.insert(journey, r)
		end
	end
	if #journey > 0 then
		heading(scroll, "HOW YOUR FUTURE HAS CHANGED", 50)
		for i, r in ipairs(journey) do
			local top = Futures.Sorted(r.Predictions)
			local parts = {}
			for j = 1, math.min(3, #top) do
				table.insert(parts, ("%s %d%%"):format(top[j].Icon, top[j].Pct))
			end
			Create.Label({
				Text = ("<b>After %s (age %d):</b>  %s%s"):format(LifeStages.Get(r.Stage).DisplayName, r.Age, table.concat(parts, "   "), if r.Twist then "   ⚡ twist!" else ""),
				RichText = true,
				TextSize = Theme.TextSize.Small,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 50 + i,
				Parent = scroll,
			})
		end
	end
	Create.Label({ Text = "💡 These are estimates, not destiny. The future is never completely decided.", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 80, Parent = scroll })
	Components.Button({ Name = "Compare", Text = "Compare with players here", Icon = "⚖️", Style = "Accent", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 90, Parent = scroll, OnClick = function()
		renderCompare()
	end })
end

local function compareView(me, them)
	handle.Clear()
	local scroll = handle.Scroll
	handle.Subtitle.Text = "You vs " .. them.DisplayName
	local mine, theirs = me.Card, them.Card
	Create.Label({ Text = ("%s (%s, %d)   vs   %s (%s, %d)"):format(mine.LifeName, mine.StageName, mine.Age, theirs.LifeName, theirs.StageName, theirs.Age), FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	Create.Label({ Text = ("💼 %s   vs   💼 %s"):format(mine.Career, theirs.Career), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	heading(scroll, "PREDICTED FUTURES (YOU · THEM)", 3)
	for i, id in ipairs(Futures.Order) do
		local info = Futures.Info[id]
		local a, b = mine.Predictions[id] or 0, theirs.Predictions[id] or 0
		local winner = if math.abs(a - b) < 5 then "🤝" elseif (a > b) == info.Positive then "⬅️" else "➡️"
		Create.Label({ Text = ("%s %s   <b>%d%%</b>  %s  <b>%d%%</b>"):format(info.Icon, info.Title, a, winner, b), RichText = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 + i, Parent = scroll })
	end
	if mine.Stats and theirs.Stats then
		heading(scroll, "STATS", 40)
		for i, statName in ipairs(StatDefinitions.Order) do
			local info = StatDefinitions.Info[statName]
			Create.Label({ Text = ("%s %s   %d  vs  %d"):format(info.Icon, info.DisplayName, mine.Stats[statName], theirs.Stats[statName]), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 40 + i, Parent = scroll })
		end
		Create.Label({ Text = ("💰 Net worth   %s  vs  %s"):format(Format.Money(mine.NetWorth), Format.Money(theirs.NetWorth)), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 60, Parent = scroll })
		heading(scroll, "LIFESTYLE: HOMES & CARS", 61)
		local function owned(card)
			return if card.Assets and #card.Assets > 0 then table.concat(card.Assets, ", ") else "Nothing yet"
		end
		Create.Label({ Text = "You: " .. owned(mine), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 62, Parent = scroll })
		Create.Label({ Text = them.DisplayName .. ": " .. owned(theirs), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 63, Parent = scroll })
	elseif not theirs.Stats then
		Create.Label({ Text = "🔒 " .. them.DisplayName .. " keeps their exact stats private.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 40, Parent = scroll })
	end
	Components.Button({ Name = "BackToList", Text = "Back", Icon = "‹", Style = "Secondary", Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 99, Parent = scroll, OnClick = function()
		renderCompare()
	end })
end

function renderCompare()
	if not handle then
		return
	end
	handle.Clear()
	handle.Subtitle.Text = "Loading players…"
	local ok, cards = Net.Invoke("GetLifeCards")
	if not handle or not handle.IsOpen() then
		return
	end
	handle.Clear()
	local scroll = handle.Scroll
	if not ok then
		NotificationController.Notify({ Title = "Couldn't load players", Text = tostring(cards), Kind = "Warning" })
		render()
		return
	end
	handle.Subtitle.Text = "Players in this server · respects everyone's privacy settings"
	local me = nil
	for _, c in ipairs(cards) do
		if c.IsYou then
			me = c
		end
	end
	local others = 0
	for i, c in ipairs(cards) do
		if not c.IsYou then
			others += 1
			local panel = Components.Panel({ Name = "Player" .. c.UserId, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 14, LayoutOrder = i, Parent = scroll, Color = Theme.Color.SurfaceHigh })
			Create.List(Enum.FillDirection.Vertical, 4).Parent = panel
			Create.Label({ Text = c.DisplayName .. (if c.IsFriend then "  · 🤝 Friend" else ""), FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = panel })
			if c.Hidden then
				Create.Label({ Text = "🔒 Keeps their future private.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
			elseif c.NoLife then
				Create.Label({ Text = "Between lives right now.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
			else
				local card = c.Card
				local top = Futures.Sorted(card.Predictions)
				Create.Label({ Text = ("%s · age %d · %s · %s"):format(card.LifeName, card.Age, card.StageName, card.Career), TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
				Create.Label({ Text = ("%s %s %d%%   %s %s %d%%"):format(top[1].Icon, top[1].Title, top[1].Pct, top[2].Icon, top[2].Title, top[2].Pct), FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = panel })
				if me and me.Card then
					Components.Button({ Name = "CompareWith", Text = "Compare", Icon = "⚖️", Style = "Accent", Size = UDim2.fromOffset(180, 44), LayoutOrder = 5, Parent = panel, OnClick = function()
						compareView(me, c)
					end })
				end
			end
			if c.Endings and #c.Endings > 0 then
				local titles = {}
				for _, e in ipairs(c.Endings) do
					table.insert(titles, e.Icon .. " " .. e.Title)
				end
				Create.Label({ Text = "Past lives: " .. table.concat(titles, ", "), TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = panel })
			end
		end
	end
	if others == 0 then
		Create.Label({ Text = "Nobody else is here yet. Invite a friend to compare futures!", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	end
	Components.Button({ Name = "BackToFuture", Text = "Back to my future", Icon = "‹", Style = "Secondary", Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 999, Parent = scroll, OnClick = render })
end

function FutureController.Open()
	if not DataController.GetActiveLife() then
		return
	end
	handle = UIController.OpenPanel({ Name = "FutureModal", Title = "🔮  Your Future", Width = 760, OnClose = function()
		handle = nil
	end })
	render()
end

FutureController.OpenCompare = function()
	FutureController.Open()
	renderCompare()
end

-- Opens a side-by-side comparison with one player (from Play With Friends).
function FutureController.OpenCompareWith(userId: number)
	if not DataController.GetActiveLife() then
		NotificationController.Notify({ Title = "Start a life first", Text = "You need a life in progress to compare futures.", Kind = "Info" })
		return
	end
	handle = UIController.OpenPanel({ Name = "FutureModal", Title = "⚖️  Compare Futures", Width = 760, OnClose = function()
		handle = nil
	end })
	handle.Subtitle.Text = "Loading…"
	local ok, cards = Net.Invoke("GetLifeCards")
	if not handle or not handle.IsOpen() then
		return
	end
	local me, them = nil, nil
	if ok then
		for _, c in ipairs(cards) do
			if c.IsYou then
				me = c
			elseif c.UserId == userId then
				them = c
			end
		end
	end
	if me and me.Card and them and them.Card then
		compareView(me, them)
	else
		handle.Clear()
		handle.Subtitle.Text = ""
		local reason = if not ok then tostring(cards) elseif not them then "That player isn't here any more." elseif them.NoLife then them.DisplayName .. " is between lives right now." else "🔒 " .. them.DisplayName .. " keeps their future private."
		Create.Label({ Text = reason, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = handle.Scroll })
	end
end

function FutureController.Init()
	HUDController.AddAction({ Id = "Future", Icon = "🔮", Order = 5, OnClick = FutureController.Open })
end

function FutureController.Start() end

return FutureController
