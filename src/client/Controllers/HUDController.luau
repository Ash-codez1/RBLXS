--[[
	HUDController  (StarterPlayerScripts.Client.Controllers.HUDController)
	The "Game" screen: a HUD bar (name, age, life stage, stage progress, money,
	happiness, health, occupation) above a content area where
	DecisionController draws scenarios. Also the full Stats panel.

	HUDController.Content         Frame for gameplay UI below the HUD
	HUDController.Opened / Closed Signals when the Game screen opens/closes
	HUDController.OpenStats()     shows the statistics panel
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local LifeStages = require(Shared.Data.LifeStages)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local Traits = require(Shared.Data.Traits)
local StatMath = require(Shared.Util.StatMath)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)

local HUDController = {}
HUDController.Priority = 40
HUDController.Opened = Signal.new()
HUDController.Closed = Signal.new()
HUDController.Content = nil :: Frame?

local gameFrame: CanvasGroup
local hud: Frame
local refs: { [string]: any } = {}
local statsModal: CanvasGroup? = nil

-- Occupation until the career system (Phase 4) assigns a real job.
function HUDController.Occupation(life): string
	if life.Career and life.Career.Id ~= "None" then
		return life.Career.Title or life.Career.Id
	end
	if life.Age <= 11 then
		return "Primary School Pupil"
	elseif life.Age <= 18 then
		return "Secondary School Student"
	end
	return "Unemployed"
end

local function hudHeight(): number
	return if UIController.GetVirtualSize().X < 1180 then 118 else 74
end

local function identityBlock(parent, width: number, order: number)
	local frame = Create("Frame", { Name = "Identity", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 50), LayoutOrder = order, Parent = parent })
	refs.Name = Create.Label({ Name = "Name", FontFace = Theme.Font.Heavy, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = frame })
	refs.Sub = Create.Label({ Name = "Sub", TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 26), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = frame })
	return frame
end

local function render()
	Create.Clear(hud, true)
	refs = {}
	local size = UIController.GetVirtualSize()
	local compact = size.X < 1180
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
	local function statsButton(parent, order, iconOnly)
		return Components.Button({ Name = "Stats", Text = if iconOnly then "📊" else "Stats", Icon = if iconOnly then nil else "📊", Style = "Accent", Size = UDim2.fromOffset(if iconOnly then 50 else 120, 50), TextSize = if iconOnly then 24 else 20, LayoutOrder = order, Parent = parent, OnClick = function()
			HUDController.OpenStats()
		end })
	end
	local function chip(parent, key, order)
		refs[key] = Components.Chip({ Text = "", Height = 40, LayoutOrder = order, Parent = parent })
	end
	local function bar(parent, statName, width, order)
		local info = StatDefinitions.Info[statName]
		refs[statName] = Components.StatBar({ Name = statName, Icon = info.Icon, DisplayName = info.DisplayName, Color = info.Color, Compact = true, Size = UDim2.fromOffset(width, 40), LayoutOrder = order, Parent = parent })
	end

	if not compact then
		local row = Create("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = hud })
		Create.List(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = row
		menuButton(row, 1)
		identityBlock(row, 250, 2)
		chip(row, "Money", 3)
		bar(row, "Happiness", 140, 4)
		bar(row, "Health", 140, 5)
		chip(row, "Occupation", 6)
		local right = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 120, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = hud })
		statsButton(right, 1, false)
	else
		local top = Create("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = hud })
		menuButton(top, 1).Position = UDim2.fromOffset(0, 0)
		local identity = identityBlock(top, size.X - 24 - 24 - 50 - 50 - 28, 2)
		identity.Position = UDim2.fromOffset(64, 0)
		local stats = statsButton(top, 3, true)
		stats.AnchorPoint = Vector2.new(1, 0)
		stats.Position = UDim2.fromScale(1, 0)

		local bottom = Create("Frame", { Name = "Bottom", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 56), Parent = hud })
		Create.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = bottom
		chip(bottom, "Money", 1)
		local barWidth = if size.X < 700 then 110 else 140
		bar(bottom, "Happiness", barWidth, 2)
		bar(bottom, "Health", barWidth, 3)
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
	refs.Name.Text = life.Name
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
	if statsModal then
		local modal = statsModal
		statsModal = nil
		ContextActionService:UnbindAction("CYL_CloseStats")
		Anim.Fade(modal, false, 0.15)
		task.delay(0.25, function()
			modal:Destroy()
		end)
	end
end

function HUDController.OpenStats()
	local life = DataController.GetActiveLife()
	if not life or statsModal then
		return
	end
	local size = UIController.GetVirtualSize()
	local narrow = UIController.IsNarrow()
	local modal = Create("CanvasGroup", { Name = "StatsModal", BackgroundColor3 = Theme.Color.Black, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = UIController.GetOverlay() })
	statsModal = modal
	-- Clicking the dimmed area closes it.
	local closer = Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Selectable = false, Parent = modal })
	closer.Activated:Connect(HUDController.CloseStats)

	local width = math.min(820, size.X - 24)
	local height = math.min(660, size.Y - 24)
	local panel = Components.Panel({ Size = UDim2.fromOffset(width, height), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Padding = 20, Parent = modal })

	Create.Label({ Text = "📊  " .. life.Name .. "'s Life", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, Size = UDim2.new(1, -60, 0, 36), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = panel })
	local stage = LifeStages.Get(life.Stage)
	Create.Label({
		Text = ("Age %d · %s · Overall %d / 100 · %s"):format(life.Age, stage.DisplayName, math.floor(StatMath.Overall(life.Stats) + 0.5), Format.Money(life.Money)),
		TextColor3 = Theme.Color.TextDim,
		TextSize = Theme.TextSize.Small,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, -60, 0, 22),
		Parent = panel,
	})
	local close = Components.Button({ Name = "Close", Text = "✕", Style = "Secondary", Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = panel, OnClick = HUDController.CloseStats })

	local scroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Selectable = false,
		Parent = panel,
	})
	Create.List(Enum.FillDirection.Vertical, 16).Parent = scroll
	Create.Padding(4, 10, 10, 4).Parent = scroll

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

	Create.Label({
		Text = ("📝 %d decisions made this life"):format(#life.Decisions),
		TextColor3 = Theme.Color.TextDim,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 4,
		Parent = scroll,
	})

	Anim.Fade(modal, true, 0.2)
	Anim.Pop(panel, 0.94)
	UIController.Focus(close)
	ContextActionService:BindActionAtPriority("CYL_CloseStats", function(_, state)
		if state == Enum.UserInputState.Begin then
			HUDController.CloseStats()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
end

-- ===== Lifecycle =====
function HUDController.Init()
	gameFrame = UIController.NewScreen("Game", {
		OnOpen = function()
			render()
			update(false)
			HUDController.Opened:Fire()
		end,
		OnClose = function()
			HUDController.CloseStats()
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
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Game" then
			render()
			update(false)
		end
	end)
end

return HUDController
