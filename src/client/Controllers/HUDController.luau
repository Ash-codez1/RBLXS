--[[
	HUDController  (StarterPlayerScripts.Client.Controllers.HUDController)
	The "Game" screen: a HUD bar (name, age, life stage, stage progress, money,
	happiness, health, occupation) above a content area where
	DecisionController draws scenarios. Also the full Stats panel.

	HUDController.Content         Frame for gameplay UI below the HUD
	HUDController.Opened / Closed Signals when the Game screen opens/closes
	HUDController.OpenStats()     shows the statistics panel
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local LifeStages = require(Shared.Data.LifeStages)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local Traits = require(Shared.Data.Traits)
local StatMath = require(Shared.Util.StatMath)
local Careers = require(Shared.Data.Careers)
local Assets = require(Shared.Data.Assets)
local Budget = require(Shared.Util.Budget)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local StyleController = require(script.Parent.StyleController)
local Avatar = require(UILib.Avatar)

local HUDController = {}
HUDController.Priority = 40
HUDController.Opened = Signal.new()
HUDController.Closed = Signal.new()
HUDController.Content = nil :: Frame?

local gameFrame: CanvasGroup
local hud: Frame
local refs: { [string]: any } = {}
local actions: { { Id: string, Icon: string, Order: number, OnClick: () -> () } } = {}

--[[
	Adds an icon button to the HUD (People, Lifestyle, Money, Stats...).
	Call from a controller's Init. Buttons are named by Id.
]]
function HUDController.AddAction(action)
	table.insert(actions, action)
	table.sort(actions, function(a, b)
		return a.Order < b.Order
	end)
end

function HUDController.Occupation(life): string
	if life.Career and life.Career.Id ~= "None" and Careers.Info[life.Career.Id] then
		return Careers.TitleAt(life.Career.Id, life.Career.Level)
	end
	if life.Flags.Retired then
		return "Retired"
	elseif life.Flags.AtUni then
		return "University Student"
	elseif life.Age <= 11 then
		return "Primary School Pupil"
	elseif life.Age <= 18 then
		return "Secondary School Student"
	end
	return "Unemployed"
end

-- One row needs room for: menu, identity, money, two bars, occupation and
-- every action button; otherwise the HUD switches to two rows.
local function actionBarWidth(): number
	return #actions * 50 + math.max(0, #actions - 1) * 8
end
local function isCompact(): boolean
	local needed = 50 + 220 + 140 + 120 + 120 + 250 + 14 * 6 + actionBarWidth() + 48
	return UIController.GetVirtualSize().X < needed
end
local function hudHeight(): number
	return if isCompact() then 118 else 74
end

local function actionBar(parent)
	local width = actionBarWidth()
	local bar = Create("Frame", { Name = "Actions", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 50), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = parent })
	Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right).Parent = bar
	for i, action in ipairs(actions) do
		Components.Button({ Name = action.Id, Text = action.Icon, Style = if i == #actions then "Accent" else "Secondary", Size = UDim2.fromOffset(50, 50), TextSize = 24, LayoutOrder = i, Parent = bar, OnClick = action.OnClick })
	end
	return width
end

local function identityBlock(parent, width: number, order: number)
	local frame = Create("Frame", { Name = "Identity", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 50), LayoutOrder = order, Parent = parent })
	refs.Name = Create.Label({ Name = "Name", RichText = true, FontFace = Theme.Font.Heavy, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = frame })
	refs.Sub = Create.Label({ Name = "Sub", TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 26), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = frame })
	return frame
end

local function render()
	Create.Clear(hud, true)
	refs = {}
	local size = UIController.GetVirtualSize()
	local compact = isCompact()
	local height = hudHeight()

	hud.Size = UDim2.new(1, -24, 0, height)
	local content = HUDController.Content :: Frame
	content.Position = UDim2.fromOffset(0, height + 18)
	content.Size = UDim2.new(1, 0, 1, -(height + 18))

	Create.Corner(Theme.Radius).Parent = hud
	Create.Stroke().Parent = hud
	Create.Padding(10, 12, 14, 12).Parent = hud

	-- Thin stage-progress bar along the bottom edge.
	local track = Create("Frame", { Name = "Progress", BackgroundColor3 = Theme.Color.Background, Size = UDim2.new(1, 0, 0, 5), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 8), Parent = hud }, { Create.Corner(Theme.RadiusPill) })
	refs.ProgressFill = Create("Frame", { Name = "Fill", BackgroundColor3 = Theme.Color.Primary, Size = UDim2.fromScale(0, 1), Parent = track }, { Create.Corner(Theme.RadiusPill) })

	local function menuButton(parent, order)
		return Components.Button({ Name = "Menu", Text = "≡", Style = "Secondary", Size = UDim2.fromOffset(50, 50), TextSize = 28, LayoutOrder = order, Parent = parent, OnClick = function()
			UIController.Show("Menu")
		end })
	end
	local function chip(parent, key, order)
		refs[key] = Components.Chip({ Text = "", Height = 40, LayoutOrder = order, Parent = parent })
		refs[key].Name = key
	end
	local function bar(parent, statName, width, order)
		local info = StatDefinitions.Info[statName]
		refs[statName] = Components.StatBar({ Name = statName, Icon = info.Icon, DisplayName = info.DisplayName, Color = info.Color, Compact = true, Size = UDim2.fromOffset(width, 40), LayoutOrder = order, Parent = parent })
	end

	if not compact then
		local row = Create("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = hud })
		Create.List(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = row
		-- Widths budgeted in isCompact(): below that width the HUD uses two rows.
		menuButton(row, 1)
		identityBlock(row, 220, 2)
		chip(row, "Money", 3)
		bar(row, "Happiness", 120, 4)
		bar(row, "Health", 120, 5)
		chip(row, "Occupation", 6)
		actionBar(hud)
	else
		local top = Create("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = hud })
		menuButton(top, 1).Position = UDim2.fromOffset(0, 0)
		local barWidth = actionBar(top)
		local identity = identityBlock(top, size.X - 24 - 24 - 50 - barWidth - 28, 2)
		identity.Position = UDim2.fromOffset(64, 0)

		local bottom = Create("Frame", { Name = "Bottom", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 56), Parent = hud })
		Create.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = bottom
		chip(bottom, "Money", 1)
		local statWidth = if size.X < 700 then 110 else 140
		bar(bottom, "Happiness", statWidth, 2)
		bar(bottom, "Health", statWidth, 3)
		if size.X >= 760 then
			chip(bottom, "Occupation", 4)
		end
	end
end

local lastLife = nil
local function update(animate: boolean?)
	local life = DataController.GetActiveLife()
	if not life or not refs.Name then
		return
	end
	local stage = LifeStages.Get(life.Stage)
	local style = StyleController.Get()
	refs.Name.Text = style.Face .. " " .. Avatar.NameRich(life.Name, style)
	refs.Name:SetAttribute("LifeName", life.Name)
	refs.Sub.Text = ("Age %d · %s · %d/%d"):format(life.Age, stage.DisplayName, math.min(life.ScenarioIndex + 1, stage.ScenariosPerStage), stage.ScenariosPerStage)
	refs.ProgressFill.BackgroundColor3 = stage.Color
	local progress = UDim2.fromScale(life.ScenarioIndex / stage.ScenariosPerStage, 1)
	if animate then
		Anim.Tween(refs.ProgressFill, { Size = progress }, 0.6)
	else
		refs.ProgressFill.Size = progress
	end
	refs.Money:FindFirstChild("Label").Text = "💰 " .. Format.Money(life.Money)
	if refs.Occupation then
		refs.Occupation:FindFirstChild("Label").Text = "💼 " .. HUDController.Occupation(life)
	end
	refs.Happiness.Set(life.Stats.Happiness, animate)
	refs.Health.Set(life.Stats.Health, animate)
	if animate and lastLife and lastLife.Money ~= life.Money then
		Anim.Pop(refs.Money, 1.2, 0.4)
	end
	lastLife = { Money = life.Money }
end

-- ===== Stats panel =====
function HUDController.CloseStats()
	local panel = UIController.CurrentPanel()
	if panel and panel.Root.Name == "StatsModal" then
		panel.Close()
	end
end

function HUDController.OpenStats()
	local life = DataController.GetActiveLife()
	if not life then
		return
	end
	local narrow = UIController.IsNarrow()
	local stage = LifeStages.Get(life.Stage)
	local handle = UIController.OpenPanel({
		Name = "StatsModal",
		Title = "📊  " .. life.Name .. "'s Life",
		Subtitle = ("Age %d · %s · Overall %d / 100 · %s"):format(life.Age, stage.DisplayName, math.floor(StatMath.Overall(life.Stats) + 0.5), Format.Money(life.Money)),
	})
	local scroll = handle.Scroll

	local grid = Create("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	Create("UIGridLayout", { CellSize = if narrow then UDim2.new(1, 0, 0, 84) else UDim2.new(0.5, -10, 0, 84), CellPadding = UDim2.fromOffset(20, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, statName in ipairs(StatDefinitions.Order) do
		local info = StatDefinitions.Info[statName]
		local cell = Create("Frame", { Name = statName, BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
		local bar = Components.StatBar({ Name = "Bar", Icon = info.Icon, DisplayName = info.DisplayName, Color = info.Color, Value = 0, Parent = cell })
		bar.Set(life.Stats[statName], true)
		Create.Label({ Text = info.Description, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 20), Parent = cell })
	end

	Create.Label({ Text = "PERSONALITY", TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, LayoutOrder = 2, Parent = scroll })
	local traitRow = Create("Frame", { Name = "Traits", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = scroll })
	Create("UIGridLayout", { CellSize = if narrow then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -10, 0, 40), CellPadding = UDim2.fromOffset(20, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = traitRow })
	local traitList = {}
	for id, strength in pairs(life.Traits) do
		table.insert(traitList, { Id = id, Strength = strength })
	end
	table.sort(traitList, function(a, b)
		return a.Strength > b.Strength
	end)
	if #traitList == 0 then
		Create.Label({ Text = "Your choices will shape your personality.", TextColor3 = Theme.Color.TextDim, LayoutOrder = 1, Parent = traitRow })
	end
	for i, trait in ipairs(traitList) do
		local info = Traits.Info[trait.Id]
		if info then
			local dots = string.rep("●", trait.Strength) .. string.rep("○", Traits.MaxStrength - trait.Strength)
			local chipFrame = Components.Chip({ Text = ("%s %s  <font color=\"%s\">%s</font>"):format(info.Icon, info.DisplayName, Theme.Hex.Gold, dots), Height = 40, LayoutOrder = i, Parent = traitRow })
			chipFrame.AutomaticSize = Enum.AutomaticSize.None
		end
	end

	Create.Label({ Text = "LIFE", TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, LayoutOrder = 10, Parent = scroll })
	local rel = life.Relationships
	local relationship = if rel.Married then "Married" elseif rel.Partner then "In a relationship" else "Single"
	local owned = {}
	for id in pairs(life.Assets) do
		local info = Assets.Info[id]
		if info then
			table.insert(owned, info.Icon .. " " .. info.Title)
		end
	end
	table.sort(owned)
	local career = HUDController.Occupation(life)
	if life.Career.Id ~= "None" then
		career ..= (" · %s/yr"):format(Format.Money(Careers.SalaryAt(life.Career.Id, life.Career.Level)))
	end
	local facts = {
		"💼  " .. career,
		"🎓  " .. (Careers.EducationNames[life.Education] or "None"),
		"❤️  " .. relationship .. (if rel.Children > 0 then ("  ·  👶 %d %s"):format(rel.Children, if rel.Children == 1 then "child" else "children") else ""),
		"🏠  " .. (if #owned > 0 then table.concat(owned, ", ") else "No property yet"),
		"💰  Net worth " .. Format.Money(Budget.NetWorth(life)),
	}
	for i, fact in ipairs(facts) do
		Create.Label({ Text = fact, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10 + i, Parent = scroll })
	end

	Create.Label({
		Text = ("📝 %d decisions made this life"):format(#life.Decisions),
		TextColor3 = Theme.Color.TextDim,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 20,
		Parent = scroll,
	})
	return handle
end

-- ===== Lifecycle =====
function HUDController.Init()
	HUDController.AddAction({ Id = "Stats", Icon = "📊", Order = 100, OnClick = HUDController.OpenStats })
	gameFrame = UIController.NewScreen("Game", {
		OnOpen = function()
			render()
			update(false)
			HUDController.Opened:Fire()
		end,
		OnClose = function()
			UIController.ClosePanel()
			HUDController.Closed:Fire()
		end,
	})
	HUDController.Content = Create("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gameFrame })
	hud = Create("Frame", {
		Name = "HUD",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 74),
		Parent = gameFrame,
	})
end

function HUDController.Start()
	DataController.Changed:Connect(function()
		if UIController.Current() == "Game" then
			update(true)
		end
	end)
	StyleController.Changed:Connect(function()
		if UIController.Current() == "Game" then
			update(false)
		end
	end)
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Game" then
			render()
			update(false)
		end
	end)
end

return HUDController
