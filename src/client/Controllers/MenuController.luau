--[[
	MenuController  (StarterPlayerScripts.Client.Controllers.MenuController)
	Screens: Menu, SlotSelect, NameEntry, Credits.

	The main menu shows every feature whose screen exists. Later phases register
	their screens (Shop, Achievements, Leaderboards, LifeHistory, Friends) and
	their buttons appear automatically, so no button ever leads nowhere.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local LifeStages = require(Shared.Data.LifeStages)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local DataTemplate = require(Shared.Data.DataTemplate)
local NamePool = require(Shared.Data.NamePool)
local Format = require(Shared.Util.Format)
local Careers = require(Shared.Data.Careers)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local StyleController = require(script.Parent.StyleController)
local Avatar = require(UILib.Avatar)

local MenuController = {}
MenuController.Priority = 30

local menuFrame, slotFrame, nameFrame, creditsFrame
local slotMode = "Continue" -- "Continue" | "New"
local busy = false

local ERRORS = {
	BadName = "Names must be 2–20 characters.",
	NameFiltered = "That name isn't allowed. Please try another!",
	SlotInUse = "That slot already has a life in it.",
	RateLimited = "Slow down a moment, then try again.",
	NotLoaded = "Your data is still loading. Try again in a second.",
	EmptySlot = "That save slot is empty.",
}
local function errorText(reason: any): string
	return ERRORS[reason] or "Something went wrong. Please try again."
end

-- ===== Helpers =====
local function lifeSummary(life): string
	if life.Completed then
		return "✅ Life complete · Age " .. life.Age
	end
	local stage = LifeStages.Get(life.Stage)
	local text = ("Age %d · %s"):format(life.Age, stage.DisplayName)
	if life.Career and life.Career.Id ~= "None" and Careers.Info[life.Career.Id] then
		text ..= " · " .. Careers.TitleAt(life.Career.Id, life.Career.Level)
	end
	return text
end

local function statLine(life): string
	local s = life.Stats
	return ("😊 %d   ❤️ %d   🧠 %d   💰 %s"):format(math.floor(s.Happiness + 0.5), math.floor(s.Health + 0.5), math.floor(s.Intelligence + 0.5), Format.Money(life.Money))
end

local function firstEmptySlot(data): string?
	for _, slotId in ipairs(DataTemplate.SlotIds) do
		if data.Slots[slotId] == false then
			return slotId
		end
	end
	return nil
end

local function hasAnyLife(data): boolean
	for _, slotId in ipairs(DataTemplate.SlotIds) do
		if type(data.Slots[slotId]) == "table" then
			return true
		end
	end
	return false
end

function MenuController.ContinueSlot(slotId: string)
	if busy then
		return
	end
	busy = true
	local ok, reason = Net.Invoke("ContinueLife", slotId)
	busy = false
	if ok then
		UIController.Show("Game")
	else
		NotificationController.Notify({ Title = "Couldn't continue", Text = errorText(reason), Kind = "Error" })
	end
end

local function quickPlay()
	local data = DataController.Get()
	if not data then
		return
	end
	local life = DataController.GetActiveLife()
	if life and not life.Completed then
		MenuController.ContinueSlot(data.ActiveSlot)
		return
	end
	local empty = firstEmptySlot(data)
	if empty then
		UIController.Show("NameEntry", empty, false)
	else
		UIController.Show("SlotSelect", "New")
	end
end

MenuController.QuickPlay = quickPlay

-- ===== Main menu =====
local MENU_ITEMS = {
	{ Text = "Play With Friends", Icon = "👥", Screen = "Friends" },
	{ Text = "Continue Life", Icon = "⏯️", Action = function()
		UIController.Show("SlotSelect", "Continue")
	end, NeedsLife = true },
	{ Text = "New Life", Icon = "✨", Action = function()
		UIController.Show("SlotSelect", "New")
	end },
	{ Text = "Explore Lifeville", Icon = "🌆", Screen = "Explore" },
	{ Text = "Shop", Icon = "🛍️", Screen = "Shop" },
	{ Text = "My Items", Icon = "🎒", Screen = "Inventory" },
	{ Text = "Achievements", Icon = "🏆", Screen = "Achievements" },
	{ Text = "Leaderboards", Icon = "📈", Screen = "Leaderboards" },
	{ Text = "Life History", Icon = "📜", Screen = "LifeHistory" },
	{ Text = "Settings", Icon = "⚙️", Screen = "Settings" },
	{ Text = "Credits", Icon = "🎬", Screen = "Credits" },
}

local playButton
local function buildLifeCard(parent, width: number, life, layoutOrder: number)
	local card = Components.Panel({
		Name = "LifeCard",
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Padding = 20,
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
	Create.List(Enum.FillDirection.Vertical, 10).Parent = card
	Create.Label({
		Text = if life then "CURRENT LIFE" else "WELCOME",
		TextSize = Theme.TextSize.Tiny,
		FontFace = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Primary,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = card,
	})
	if not life then
		Create.Label({
			Text = "Your story hasn't started yet.",
			FontFace = Theme.Font.Heavy,
			TextSize = Theme.TextSize.H2,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = card,
		})
		Create.Label({
			Text = "Start as a five-year-old, make choices that shape who you become, and discover how your life turns out.",
			TextColor3 = Theme.Color.TextDim,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,
			Parent = card,
		})
		return card
	end
	local style = StyleController.Get()
	local nameRow = Create("Frame", { Name = "NameRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 2, Parent = card })
	Avatar.Badge({ Style = style, Size = 60, Parent = nameRow })
	Create.Label({
		Name = "LifeName",
		Text = Avatar.NameRich(life.Name, style),
		RichText = true,
		FontFace = Theme.Font.Heavy,
		TextSize = Theme.TextSize.H1,
		Position = UDim2.fromOffset(74, 0),
		Size = UDim2.new(1, -74, 0, 40),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = nameRow,
	})
	if style.Title then
		Create.Label({ Text = style.Title, TextColor3 = Theme.Color.Gold, TextSize = Theme.TextSize.Small, Position = UDim2.fromOffset(74, 40), Size = UDim2.new(1, -74, 0, 22), Parent = nameRow })
	end
	Create.Label({ Text = lifeSummary(life), TextColor3 = Theme.Color.TextDim, LayoutOrder = 3, Parent = card })
	local stage = LifeStages.Get(life.Stage)
	local progress = Components.StatBar({
		Name = "StageProgress",
		Icon = "🧭",
		DisplayName = stage.DisplayName .. " progress",
		Color = stage.Color,
		Value = if life.Completed then 100 else life.ScenarioIndex / stage.ScenariosPerStage * 100,
		LayoutOrder = 4,
		Parent = card,
	})
	progress.Instance:FindFirstChild("Value").Visible = false
	local grid = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = card })
	Create("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 40), CellPadding = UDim2.fromOffset(12, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, statName in ipairs({ "Happiness", "Health", "Intelligence", "Popularity" }) do
		local info = StatDefinitions.Info[statName]
		Components.StatBar({ Name = statName, Icon = info.Icon, DisplayName = info.DisplayName, Color = info.Color, Value = life.Stats[statName], Compact = true, LayoutOrder = i, Parent = grid })
	end
	Create.Label({ Text = "💰  " .. Format.Money(life.Money), FontFace = Theme.Font.Bold, LayoutOrder = 6, Parent = card })
	return card
end

local function renderMenu()
	Create.Clear(menuFrame, true)
	local data = DataController.Get()
	local life = DataController.GetActiveLife()
	local size = UIController.GetVirtualSize()
	local narrow = UIController.IsNarrow()

	local scroll = Layout.Scroll(menuFrame, { Size = UDim2.fromScale(1, 1), Position = UDim2.new() })
	local list = scroll:FindFirstChildOfClass("UIListLayout")
	local columnWidth = math.min(if narrow then 460 else 420, size.X - 40)

	local container
	if narrow then
		container = scroll
	else
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		container = Create("Frame", {
			Name = "Split",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = scroll,
		})
		Create.List(Enum.FillDirection.Horizontal, 60, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = container
	end

	local left = Layout.Column(container, columnWidth, { LayoutOrder = 1 })
	local title = Create.Label({
		Name = "Title",
		Text = Config.GameName,
		FontFace = Theme.Font.Heavy,
		TextSize = if narrow then 48 else Theme.TextSize.Hero,
		TextXAlignment = if narrow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = left,
	})
	Create.Gradient(Theme.Gradient.Title).Parent = title
	Create.Label({
		Text = "Every choice shapes your future.",
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = title.TextXAlignment,
		LayoutOrder = 2,
		Parent = left,
	})

	if narrow then
		buildLifeCard(left, columnWidth, life, 3)
	end

	local playText = if life and not life.Completed then "Play as " .. life.Name else "Play"
	playButton = Components.Button({
		Name = "Play",
		Text = playText,
		Icon = "▶",
		Style = "Primary",
		Size = UDim2.new(1, 0, 0, 66),
		TextSize = 26,
		LayoutOrder = 4,
		Parent = left,
		OnClick = quickPlay,
	})

	local grid = Create("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = left })
	Create("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 54), CellPadding = UDim2.fromOffset(12, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local order = 0
	for _, item in ipairs(MENU_ITEMS) do
		if item.Screen and not UIController.HasScreen(item.Screen) then
			continue
		end
		order += 1
		local button = Components.Button({
			Text = item.Text,
			Icon = item.Icon,
			Style = "Secondary",
			TextSize = 19,
			LayoutOrder = order,
			Parent = grid,
			OnClick = item.Action or function()
				UIController.Show(item.Screen)
			end,
		})
		if item.NeedsLife and not hasAnyLife(data) then
			Components.SetDisabled(button, true)
		end
	end

	if not narrow then
		buildLifeCard(container, math.min(440, size.X - columnWidth - 140), life, 2)
	end

	Create.Label({
		Name = "Coins",
		Text = ("🪙 %d coins · %d %s lived"):format(data.Coins, #data.LifeHistory, if #data.LifeHistory == 1 then "life" else "lives"),
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 98,
		Parent = scroll,
	})
	Create.Label({
		Name = "Version",
		Text = "v" .. Config.Version,
		TextSize = Theme.TextSize.Tiny,
		TextColor3 = Theme.Color.TextFaint,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 99,
		Parent = scroll,
	})
	Anim.Pop(left, 0.96)
end

-- ===== Save slots =====
local function slotCard(parent, slotId: string, index: number, life, width: number, height: number)
	local card = Components.Panel({
		Name = slotId,
		Size = UDim2.fromOffset(width, height),
		Padding = 18,
		LayoutOrder = index,
		Parent = parent,
	})
	local info = Create("Frame", { Name = "Info", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64), Parent = card })
	Create.List(Enum.FillDirection.Vertical, 8).Parent = info
	Create.Label({ Text = "SLOT " .. index, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = info })

	-- Action buttons pinned to the bottom of the card.
	local actions = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 54),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Parent = card,
	})
	Create.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left).Parent = actions
	local firstButton

	if life then
		Create.Label({ Text = life.Name, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, Size = UDim2.new(1, 0, 0, 36), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, LayoutOrder = 2, Parent = info })
		Create.Label({ Text = lifeSummary(life), TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 3, Parent = info })
		Create.Label({ Text = statLine(life), TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = info })

		if slotMode == "Continue" then
			firstButton = Components.Button({
				Name = if life.Completed then "ViewReveal" else "Continue",
				Text = if life.Completed then "View Final Reveal" else "Continue",
				Icon = if life.Completed then "🔮" else "▶",
				Style = if life.Completed then "Accent" else "Primary",
				Size = UDim2.new(1, -64, 1, 0),
				LayoutOrder = 1,
				Parent = actions,
				OnClick = function()
					if life.Completed then
						local LifeHistoryController = require(script.Parent.LifeHistoryController)
						local entry = life.HistoryId and LifeHistoryController.Find(life.HistoryId)
						if entry then
							LifeHistoryController.Replay(entry)
						else
							UIController.Show("LifeHistory")
						end
					else
						MenuController.ContinueSlot(slotId)
					end
				end,
			})
		else
			firstButton = Components.Button({
				Text = "Replace",
				Icon = "✨",
				Style = "Accent",
				Size = UDim2.new(1, -64, 1, 0),
				LayoutOrder = 1,
				Parent = actions,
				OnClick = function()
					local confirmed = UIController.Confirm({
						Title = "Replace " .. life.Name .. "?",
						Text = "Starting a new life here will permanently erase " .. life.Name .. "'s life (" .. lifeSummary(life) .. ").",
						ConfirmText = "Replace",
						Danger = true,
					})
					if confirmed then
						UIController.Show("NameEntry", slotId, true)
					end
				end,
			})
		end
		Components.Button({
			Name = "Delete",
			Text = "🗑",
			Style = "Ghost",
			Size = UDim2.fromOffset(54, 54),
			LayoutOrder = 2,
			Parent = actions,
			OnClick = function()
				local confirmed = UIController.Confirm({
					Title = "Delete " .. life.Name .. "?",
					Text = "This life will be gone forever. This can't be undone.",
					ConfirmText = "Delete",
					Danger = true,
				})
				if confirmed then
					local ok, reason = Net.Invoke("DeleteLife", slotId)
					if not ok then
						NotificationController.Notify({ Title = "Couldn't delete", Text = errorText(reason), Kind = "Error" })
					end
				end
			end,
		})
	else
		Create.Label({ Text = "Empty Slot", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2, Parent = info })
		Create.Label({ Text = "A blank page. Who will you be?", TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = info })
		firstButton = Components.Button({
			Text = "Start New Life",
			Icon = "✨",
			Style = "Primary",
			Size = UDim2.new(1, 0, 1, 0),
			LayoutOrder = 1,
			Parent = actions,
			OnClick = function()
				UIController.Show("NameEntry", slotId, false)
			end,
		})
	end
	return card, firstButton
end

local function renderSlots()
	Create.Clear(slotFrame, true)
	local data = DataController.Get()
	if not data then
		return
	end
	Layout.Header(slotFrame, if slotMode == "Continue" then "Continue a Life" else "Start a New Life", function()
		UIController.Back()
	end)
	local narrow = UIController.IsNarrow()
	local size = UIController.GetVirtualSize()
	local scroll = Layout.Scroll(slotFrame)
	local row = scroll
	local width, height
	if narrow then
		width, height = math.min(520, size.X - 32), 230
	else
		width, height = math.min(340, math.floor((size.X - 120) / 3)), 300
		row = Create("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), Parent = scroll })
		Create.List(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center).Parent = row
		scroll:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	end
	local focus
	for index, slotId in ipairs(DataTemplate.SlotIds) do
		local life = data.Slots[slotId]
		local card, button = slotCard(row, slotId, index, if type(life) == "table" then life else nil, width, height)
		focus = focus or button
		Anim.Pop(card, 0.92, 0.3 + index * 0.05)
	end
	UIController.Focus(focus)
end

-- ===== Name entry =====
local pendingSlot, pendingOverwrite = "Slot1", false

local function renderNameEntry()
	Create.Clear(nameFrame, true)
	Layout.Header(nameFrame, "", function()
		UIController.Back()
	end)
	local size = UIController.GetVirtualSize()
	local width = math.min(580, size.X - 32)
	local panel = Components.Panel({
		Name = "NamePanel",
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 20),
		Padding = 26,
		Parent = nameFrame,
	})
	Create.List(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center).Parent = panel
	Create.Label({ Text = "👶", TextSize = 54, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 1, Parent = panel })
	Create.Label({ Text = "Who will you become?", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
	Create.Label({ Text = "Choose a name for your new life. You'll start at age 5.", TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = panel })

	local box = Create("TextBox", {
		Name = "NameBox",
		Text = NamePool[math.random(1, #NamePool)],
		PlaceholderText = "Type a name…",
		PlaceholderColor3 = Theme.Color.TextFaint,
		ClearTextOnFocus = false,
		FontFace = Theme.Font.Bold,
		TextSize = 28,
		TextColor3 = Theme.Color.Text,
		BackgroundColor3 = Theme.Color.Background,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 4,
		Parent = panel,
	}, { Create.Corner(Theme.RadiusSmall), Create.Stroke(Theme.Color.Stroke, 2, 0.2) })
	local counter = Create.Label({ Text = "", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 5, Parent = panel })
	local errorLabel = Create.Label({ Text = "", TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Negative, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = panel })

	local function refreshCounter()
		-- Keep to 20 characters as the player types.
		local length = utf8.len(box.Text) or #box.Text
		if length > 20 then
			box.Text = box.Text:sub(1, utf8.offset(box.Text, 21) - 1)
			length = 20
		end
		counter.Text = length .. " / 20"
	end
	box:GetPropertyChangedSignal("Text"):Connect(refreshCounter)
	refreshCounter()

	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 7, Parent = panel })
	Create.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = row
	local half = math.floor((width - 52 - 12) / 2)
	Components.Button({
		Text = "Random",
		Icon = "🎲",
		Style = "Secondary",
		Size = UDim2.fromOffset(half, 58),
		LayoutOrder = 1,
		Parent = row,
		OnClick = function()
			box.Text = NamePool[math.random(1, #NamePool)]
			errorLabel.Text = ""
		end,
	})
	local startButton
	local function submit()
		if busy then
			return
		end
		busy = true
		Components.SetDisabled(startButton, true)
		errorLabel.Text = ""
		local ok, result = Net.Invoke("StartNewLife", pendingSlot, box.Text, pendingOverwrite)
		busy = false
		Components.SetDisabled(startButton, false)
		if ok then
			UIController.Show("Game")
		else
			errorLabel.Text = errorText(result)
			Anim.Shake(panel)
		end
	end
	startButton = Components.Button({
		Text = "Start Life",
		Icon = "▶",
		Style = "Primary",
		Size = UDim2.fromOffset(half, 58),
		LayoutOrder = 2,
		Parent = row,
		OnClick = submit,
	})
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	Anim.Pop(panel, 0.92)
	UIController.Focus(startButton)
end

-- ===== Credits =====
local function renderCredits()
	Create.Clear(creditsFrame, true)
	Layout.Header(creditsFrame, "Credits", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(creditsFrame)
	local width = math.min(640, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	Create.Label({ Text = Config.GameName, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0, Parent = column })
	for i, section in ipairs(Config.Credits) do
		local panel = Components.Panel({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 18, LayoutOrder = i, Parent = column })
		Create.List(Enum.FillDirection.Vertical, 6).Parent = panel
		Create.Label({ Text = section.Heading, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, TextSize = Theme.TextSize.Small, LayoutOrder = 0, Parent = panel })
		for j, line in ipairs(section.Lines) do
			Create.Label({ Text = line, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = j, Parent = panel })
		end
	end
	Create.Label({ Text = "Version " .. Config.Version, TextColor3 = Theme.Color.TextFaint, TextSize = Theme.TextSize.Small, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 100, Parent = column })
end

-- ===== Lifecycle =====
function MenuController.Init()
	menuFrame = UIController.NewScreen("Menu", {
		OnOpen = renderMenu,
		DefaultFocus = function()
			return playButton
		end,
	})
	slotFrame = UIController.NewScreen("SlotSelect", {
		Back = true, -- the menu, or Lifeville if you came from the Hall of Lives
		OnOpen = function(mode)
			slotMode = mode or slotMode
			renderSlots()
		end,
	})
	nameFrame = UIController.NewScreen("NameEntry", {
		Back = true,
		OnOpen = function(slotId, overwrite)
			pendingSlot = slotId or pendingSlot
			pendingOverwrite = overwrite == true
			renderNameEntry()
		end,
	})
	creditsFrame = UIController.NewScreen("Credits", { Back = true, OnOpen = renderCredits })
end

function MenuController.Start()
	UIController.LayoutChanged:Connect(function()
		local screen = UIController.Current()
		if screen == "Menu" then
			renderMenu()
		elseif screen == "SlotSelect" then
			renderSlots()
		elseif screen == "Credits" then
			renderCredits()
		end
		-- NameEntry is not re-rendered on resize so typed text isn't lost.
	end)
	DataController.Changed:Connect(function()
		local screen = UIController.Current()
		if screen == "SlotSelect" then
			renderSlots()
		end
	end)
	StyleController.Changed:Connect(function()
		if UIController.Current() == "Menu" then
			renderMenu()
		end
	end)
end

return MenuController
