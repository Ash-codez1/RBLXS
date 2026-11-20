--[[
	LifeHistoryController  (StarterPlayerScripts.Client.Controllers.LifeHistoryController)
	The 📜 Life History screen (appears on the main menu automatically).
	  • every completed life (newest first) with its ending title
	  • a detail view: career, wealth, family, achievements, moments,
	    regrets, key decisions and how the predictions played out
	  • replay any life's Final Reveal
	  • compare two lives side by side: "What if I had chosen differently?"
	Data: profile.LifeHistory (written by the server at the end of each life).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Futures = require(Shared.Util.Futures)
local Format = require(Shared.Util.Format)
local StatDefinitions = require(Shared.Data.StatDefinitions)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local RevealController = require(script.Parent.RevealController)

local LifeHistoryController = {}
LifeHistoryController.Priority = 48

local frame: CanvasGroup

local function history()
	local data = DataController.Get()
	local list = {}
	if data then
		for i = #data.LifeHistory, 1, -1 do
			table.insert(list, data.LifeHistory[i])
		end
	end
	return list
end

function LifeHistoryController.Find(id: number)
	for _, entry in ipairs(history()) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

local function summaryLine(entry): string
	return ("Lived to %d · %s · %s"):format(entry.Age, entry.Career, Format.Money(entry.NetWorth))
end

local function familyLine(entry): string
	local parts = {}
	if entry.Partner then
		table.insert(parts, (if entry.Partner.Married then "💍 " else "❤️ ") .. entry.Partner.Name)
	end
	if #entry.Children > 0 then
		table.insert(parts, ("👶 %d %s"):format(#entry.Children, if #entry.Children == 1 then "child" else "children"))
	end
	return if #parts > 0 then table.concat(parts, "  ·  ") else "🕊️ Single"
end

local function heading(parent, text: string, order: number)
	Create.Label({ Text = text, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 24), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = parent })
end

local function lines(parent, list, order: number)
	for i, text in ipairs(list) do
		Create.Label({ Text = text, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + i, Parent = parent })
	end
end

local openDetail

local function openCompare(a, b)
	local handle = UIController.OpenPanel({ Name = "CompareLivesModal", Title = "⚖️  " .. a.Name .. " vs " .. b.Name, Width = 860 })
	handle.Subtitle.Text = "Different choices. Different lives."
	local scroll = handle.Scroll
	local function row(order, label, left, right)
		local r = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll })
		Create.Label({ Text = label, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, Size = UDim2.new(0.24, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r })
		Create.Label({ Text = left, FontFace = Theme.Font.Bold, Size = UDim2.new(0.38, -8, 0, 0), Position = UDim2.fromScale(0.24, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r })
		Create.Label({ Text = right, FontFace = Theme.Font.Bold, Size = UDim2.new(0.38, -8, 0, 0), Position = UDim2.fromScale(0.62, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r })
	end
	row(1, "", a.Name, b.Name)
	row(2, "Ending", a.Ending.Icon .. " " .. a.Ending.Title, b.Ending.Icon .. " " .. b.Ending.Title)
	row(3, "Career", a.Career, b.Career)
	row(4, "Education", a.Education, b.Education)
	row(5, "Net worth", Format.Money(a.NetWorth), Format.Money(b.NetWorth))
	row(6, "Family", familyLine(a), familyLine(b))
	row(7, "Life score", a.Overall .. " / 100", b.Overall .. " / 100")
	for i, statName in ipairs(StatDefinitions.Order) do
		local info = StatDefinitions.Info[statName]
		local x, y = a.Stats[statName], b.Stats[statName]
		row(10 + i, info.Icon .. " " .. info.DisplayName, tostring(x) .. (if x > y + 4 then " ⭐" else ""), tostring(y) .. (if y > x + 4 then " ⭐" else ""))
	end
	local function came(entry)
		local names = {}
		for _, id in ipairs(entry.CameTrue) do
			if Futures.Info[id] and Futures.Info[id].Positive then
				table.insert(names, Futures.Info[id].Icon)
			end
		end
		return if #names > 0 then table.concat(names, " ") else "—"
	end
	row(30, "Futures that came true", came(a), came(b))
	local function firstChoice(entry)
		local d = entry.KeyDecisions[1]
		return if d then ("Age %d: %s"):format(d.Age, d.Choice) else "—"
	end
	row(31, "A defining choice", firstChoice(a), firstChoice(b))
	Components.Button({ Name = "BackToLife", Text = "Back to " .. a.Name, Icon = "‹", Style = "Secondary", Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 99, Parent = scroll, OnClick = function()
		openDetail(a)
	end })
end

local function pickCompare(entry)
	local handle = UIController.OpenPanel({ Name = "PickLifeModal", Title = "⚖️  Compare " .. entry.Name .. " with…", Width = 640 })
	local scroll = handle.Scroll
	local count = 0
	for i, other in ipairs(history()) do
		if other.Id ~= entry.Id then
			count += 1
			Components.Button({ Name = "Pick" .. other.Id, Text = ("%s %s: %s"):format(other.Ending.Icon, other.Name, other.Ending.Title), Style = "Secondary", Size = UDim2.new(1, 0, 0, 52), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = scroll, OnClick = function()
				openCompare(entry, other)
			end })
		end
	end
	if count == 0 then
		Create.Label({ Text = "Complete another life to compare them!", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
	end
end

function openDetail(entry)
	local handle = UIController.OpenPanel({ Name = "LifeDetailModal", Title = entry.Ending.Icon .. "  " .. entry.Name .. ": " .. entry.Ending.Title, Width = 820 })
	handle.Subtitle.Text = summaryLine(entry)
	local scroll = handle.Scroll
	local buttons = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 0, Parent = scroll })
	Create.List(Enum.FillDirection.Horizontal, 10).Parent = buttons
	Components.Button({ Name = "Replay", Text = "Replay reveal", Icon = "▶", Style = "Primary", Size = UDim2.fromOffset(220, 50), TextSize = 18, LayoutOrder = 1, Parent = buttons, OnClick = function()
		UIController.ClosePanel()
		LifeHistoryController.Replay(entry)
	end })
	Components.Button({ Name = "CompareLives", Text = "Compare", Icon = "⚖️", Style = "Accent", Size = UDim2.fromOffset(180, 50), TextSize = 18, LayoutOrder = 2, Parent = buttons, OnClick = function()
		pickCompare(entry)
	end })
	Create.Label({ Text = "“" .. entry.Ending.Line .. "”", FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	heading(scroll, "LIFE", 2)
	lines(scroll, {
		"💼 " .. entry.Career .. "   ·   🎓 " .. entry.Education,
		"💰 Net worth " .. Format.Money(entry.NetWorth) .. "   ·   Life score " .. entry.Overall .. "/100",
		familyLine(entry) .. (if entry.BestFriend then "   ·   🫶 " .. entry.BestFriend else ""),
	}, 2)
	heading(scroll, "ACHIEVEMENTS", 10)
	lines(scroll, if #entry.Achievements > 0 then entry.Achievements else { "—" }, 10)
	heading(scroll, "GREATEST MOMENTS", 30)
	lines(scroll, if #entry.Moments > 0 then entry.Moments else { "—" }, 30)
	heading(scroll, "BIGGEST REGRETS", 40)
	lines(scroll, if #entry.Mistakes > 0 then entry.Mistakes else { "None worth mentioning." }, 40)
	heading(scroll, "KEY DECISIONS", 50)
	local decisionLines = {}
	for _, d in ipairs(entry.KeyDecisions) do
		table.insert(decisionLines, ("Age %d: %s (%s)"):format(d.Age, d.Choice, d.Title))
	end
	lines(scroll, decisionLines, 50)
	heading(scroll, "PREDICTIONS VS REALITY", 60)
	local came = {}
	for _, id in ipairs(entry.CameTrue) do
		came[id] = true
	end
	local journeyLines = {}
	for _, j in ipairs(entry.Journey) do
		local parts = {}
		for _, top in ipairs(j.Top) do
			table.insert(parts, ("%s %d%%%s"):format(Futures.Info[top.Id].Icon, top.Pct, if came[top.Id] then "✅" else ""))
		end
		table.insert(journeyLines, ("At %d: %s%s"):format(j.Age, table.concat(parts, "  "), if j.Twist then "  ⚡" else ""))
	end
	lines(scroll, journeyLines, 60)
end

function LifeHistoryController.Replay(entry)
	task.spawn(function()
		local action = RevealController.PlayFinal(entry, { Replay = true })
		if action == "Again" then
			UIController.Show("SlotSelect", "New")
		end
	end)
end

local function render()
	Create.Clear(frame, true)
	Layout.Header(frame, "Life History", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(frame)
	local width = math.min(760, UIController.GetVirtualSize().X - 32)
	local list = history()
	local data = DataController.Get()
	Create.Label({
		Text = ("%d %s lived · 🪙 %d coins"):format(#list, if #list == 1 then "life" else "lives", data and data.Coins or 0),
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(width, 24),
		LayoutOrder = 0,
		Parent = scroll,
	})
	if #list == 0 then
		local empty = Components.Panel({ Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 24, LayoutOrder = 1, Parent = scroll })
		Create.Label({ Text = "📜 No completed lives yet.\nLive a whole life to age 85 to see its story, ending and Final Reveal here.", TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Parent = empty })
		return
	end
	for i, entry in ipairs(list) do
		local card = Create("TextButton", {
			Name = "Life" .. entry.Id,
			Text = "",
			AutoButtonColor = false,
			Selectable = true,
			BackgroundColor3 = Theme.Color.Surface,
			Size = UDim2.fromOffset(width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = scroll,
		}, { Create.Corner(Theme.Radius), Create.Stroke(), Create.Padding(14, 18) })
		Create.List(Enum.FillDirection.Vertical, 4).Parent = card
		Create.Label({ Text = entry.Ending.Icon .. "  " .. entry.Ending.Title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
		Create.Label({ Text = entry.Name .. " · " .. summaryLine(entry), TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
		Create.Label({ Text = familyLine(entry), TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = card })
		card.Activated:Connect(function()
			if Components.OnClickSound then
				Components.OnClickSound()
			end
			openDetail(entry)
		end)
	end
end

function LifeHistoryController.Init()
	frame = UIController.NewScreen("LifeHistory", { Back = true, OnOpen = render })
end

function LifeHistoryController.Start()
	DataController.Changed:Connect(function()
		if UIController.Current() == "LifeHistory" then
			render()
		end
	end)
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "LifeHistory" then
			render()
		end
	end)
end

return LifeHistoryController
