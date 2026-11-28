--[[
	ExploreController  (StarterPlayerScripts.Client.Controllers.ExploreController)
	🌆 Explore mode: walk around Lifeville with your character.
	  • Enter from the HUD (🌆) or the main menu (Explore Lifeville).
	  • A slim top bar: your look and age, money, actions left, 🗺️ Map and
	    📝 Next decision (back to the decision cards).
	  • Character controls and ProximityPrompts are only on while exploring.
	  • Walk up to things (E / tap / gamepad X): study, work out, eat out, work
	    a shift... Each uses 1 of your 2 actions between decisions. The server
	    checks everything (WorldService); results show as a card.
	  • Talk to people (DialogueController), open the shop, the bank (Money),
	    the Hall of Lives (choose a life) and the town map.
	  • A banner names each district as you walk in (locked ones say when
	    they open).
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local People = require(Shared.Util.People)
local World = require(Shared.Data.World)
local WorldSpots = require(Shared.Data.WorldSpots)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local Careers = require(Shared.Data.Careers)
local LifeStages = require(Shared.Data.LifeStages)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)
local Avatar = require(UILib.Avatar)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local ControlsController = require(script.Parent.ControlsController)
local AudioController = require(script.Parent.AudioController)
local StyleController = require(script.Parent.StyleController)
local HUDController = require(script.Parent.HUDController)

local ExploreController = {}
ExploreController.Priority = 53
ExploreController.Changed = Signal.new() -- (exploring: boolean)
ExploreController.DistrictChanged = Signal.new() -- (districtId?)

local frame: CanvasGroup
local refs: { [string]: any } = {}
local exploring = false
local currentDistrict: string? = nil
local busy = false
local cardToken = 0

local REASONS = {
	NoActionsLeft = "No actions left. Make your next decision to get more time.",
	NotYourHome = "That's someone else's home. Yours has your name on the sign.",
	TooFar = "Walk a little closer first.",
	NoLife = "Start a life first: press 📝 or visit the Hall of Lives.",
	NoCharacter = "Your character is still arriving. Try again in a moment.",
	NotLoaded = "Still loading your life…",
	RateLimited = "Slow down a moment.",
	BadSpot = "Nothing to do here.",
}

-- Lazily required (they require controllers that load after this one).
local function controller(name: string)
	return require(script.Parent:FindFirstChild(name))
end

local function activeLife()
	local life = DataController.GetActiveLife()
	if life and not life.Completed then
		return life
	end
	return nil
end

function ExploreController.ActionsLeft(life): number
	if not life then
		return 0
	end
	if life.ActionTurn ~= #life.Decisions then
		return People.ActionsPerTurn
	end
	return math.max(0, People.ActionsPerTurn - life.ActionsUsed)
end

function ExploreController.IsExploring(): boolean
	return exploring
end

function ExploreController.CurrentDistrict(): string?
	return currentDistrict
end

local function careerNames(workplaceId: string): string
	local names = {}
	for _, id in ipairs(World.Workplaces[workplaceId].Careers) do
		local info = Careers.Info[id]
		if info then
			table.insert(names, info.Icon .. " " .. Careers.TitleAt(id, 1):gsub("^Junior ", ""):gsub("^Trainee ", ""))
		end
	end
	return table.concat(names, ", ")
end

function ExploreController.ReasonText(reason: string?, spotDef): string
	local life = activeLife()
	if spotDef then
		if reason == "NeedFlag" and spotDef.FlagText then
			return spotDef.FlagText
		elseif reason == "TooYoung" and spotDef.MinAge then
			return ("You need to be %d or older for this."):format(spotDef.MinAge)
		elseif reason == "TooOld" and spotDef.MaxAge then
			return ("This is for ages %d and under."):format(spotDef.MaxAge)
		elseif reason == "Locked" then
			local lock = spotDef.Lock and World.Locks[spotDef.Lock] or World.ById[spotDef.District]
			return ("🔒 %s. %s."):format(lock.Name, World.UnlockText(lock.UnlockStage))
		elseif (reason == "NoJob" or reason == "WrongJob") and spotDef.Workplace then
			return "Only for people who work here: " .. careerNames(spotDef.Workplace) .. "."
		elseif reason == "NotEnoughMoney" and life then
			return ("This costs %s. You have %s."):format(Format.Money(WorldSpots.CostFor(spotDef, life.Age)), Format.Money(life.Money))
		end
	end
	return REASONS[reason or ""] or tostring(reason)
end

-- ===== Result card =====
local function hideCard(token: number)
	task.delay(4.5, function()
		if cardToken == token and refs.Card then
			Anim.Tween(refs.Card, { GroupTransparency = 1 }, 0.3)
		end
	end)
end

local function showCard(title: string, body: string, chips: { { Text: string, Color: Color3 } }?, kind: string?)
	local card = refs.Card :: CanvasGroup?
	if not card then
		return
	end
	cardToken += 1
	Create.Clear(card) -- keeps the card's layout, padding, corner and stroke
	local accent = if kind == "Problem" then Theme.Color.Warning else Theme.Color.Positive
	card:FindFirstChildOfClass("UIStroke").Color = accent
	Create.Label({ Name = "Title", Text = title, FontFace = Theme.Font.Heavy, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 1, Parent = card })
	Create.Label({ Name = "Body", Text = body, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = card })
	if chips and #chips > 0 then
		local row = Create("Frame", { Name = "Chips", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 32), LayoutOrder = 3, Parent = card })
		local list = Create.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
		list.Wraps = true
		list.Parent = row
		for i, chip in ipairs(chips) do
			local c = Components.Chip({ Text = chip.Text, Height = 30, TextColor = chip.Color, LayoutOrder = i, Parent = row })
			c.Name = "Chip"
		end
	end
	card.Visible = true
	card.GroupTransparency = 0
	Anim.Pop(card, 0.85, 0.25)
	hideCard(cardToken)
end
ExploreController.ShowCard = showCard

local function resultChips(result)
	local chips = {}
	local applied = result.Applied or {}
	for _, stat in ipairs(StatDefinitions.Order) do
		local delta = applied[stat]
		if delta and math.abs(delta) >= 0.5 then
			local info = StatDefinitions.Info[stat]
			table.insert(chips, { Text = ("%s %s%d"):format(info.Icon, if delta > 0 then "+" else "−", math.floor(math.abs(delta) + 0.5)), Color = if delta > 0 then Theme.Color.Positive else Theme.Color.Negative })
		end
	end
	if result.MoneyDelta and result.MoneyDelta ~= 0 then
		table.insert(chips, { Text = (if result.MoneyDelta > 0 then "💰 +" else "💰 −") .. Format.Money(math.abs(result.MoneyDelta)), Color = if result.MoneyDelta > 0 then Theme.Color.Positive else Theme.Color.Negative })
	end
	for _, bond in ipairs(result.BondChanges or {}) do
		if bond.Delta and bond.Delta > 0 then
			table.insert(chips, { Text = ("❤️ %s +%d"):format(bond.Name, math.floor(bond.Delta + 0.5)), Color = Theme.Color.Positive })
		end
	end
	return chips
end

-- Runs a world action through the server and shows what happened.
function ExploreController.UseSpot(spotId: string, npcId: string?): (boolean, any)
	local def = WorldSpots.Get(spotId)
	if not def or busy then
		return false, "Busy"
	end
	if not activeLife() then
		showCard(def.Label, ExploreController.ReasonText("NoLife"), nil, "Problem")
		return false, "NoLife"
	end
	busy = true
	local ok, result = Net.Invoke("WorldAction", spotId, npcId)
	busy = false
	if ok then
		local left = result.ActionsLeft or 0
		local body = result.Text or ""
		if result.Story then
			body = body .. "\n✨ " .. result.Story
		end
		body = body .. "\n" .. (if left > 0 then ("⚡ %d action%s left before your next decision."):format(left, if left == 1 then "" else "s") else "⚡ That was your last action. 📝 Make your next decision for more.")
		showCard(def.Label .. " ✓", body, resultChips(result), "Result")
		AudioController.Play(if spotId == "Plaza_Wish" then "Splash" else "Positive")
	else
		showCard(def.Label, ExploreController.ReasonText(result, def), nil, "Problem")
		AudioController.Play("Locked")
	end
	ExploreController.UpdateBar()
	return ok, result
end

-- Screens a spot (or an NPC) can open.
function ExploreController.OpenScreen(name: string)
	local needsLife = { Money = true, People = true, Future = true }
	if needsLife[name] and not activeLife() then
		showCard("Not yet", ExploreController.ReasonText("NoLife"), nil, "Problem")
		return
	end
	if name == "Shop" then
		controller("ShopController").Open()
	elseif name == "Money" then
		controller("FinanceController").Open()
	elseif name == "People" then
		controller("PeopleController").Open()
	elseif name == "Future" then
		controller("FutureController").Open()
	elseif name == "Map" then
		controller("MapController").Open()
	elseif name == "SlotSelect" then
		local data = DataController.Get()
		local any = false
		for _, slot in pairs(data and data.Slots or {}) do
			if type(slot) == "table" then
				any = true
			end
		end
		if any then
			UIController.Show("SlotSelect", "Continue")
		else
			controller("MenuController").QuickPlay()
		end
	end
end

local function onPrompt(prompt: ProximityPrompt)
	if not exploring then
		return
	end
	local spotId = prompt:GetAttribute("CYL_Spot")
	local npcId = prompt:GetAttribute("CYL_NPC")
	local starId = prompt:GetAttribute("CYL_Star")
	if type(starId) == "string" then
		controller("CollectiblesController").Collect(starId)
	elseif type(spotId) == "string" then
		local def = WorldSpots.Get(spotId)
		if def and def.Kind == "Open" then
			ExploreController.OpenScreen(def.Open)
		elseif def then
			ExploreController.UseSpot(spotId)
		end
	elseif type(npcId) == "string" then
		controller("DialogueController").Open(npcId)
	end
end
ExploreController.HandlePrompt = onPrompt

-- ===== Prompts and pedestals, personalised for this life =====
local function myPlotIndex(): number?
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot:GetAttribute("Index")
		end
	end
	return nil
end
ExploreController.MyPlotIndex = myPlotIndex

function ExploreController.RefreshPrompts()
	local life = activeLife()
	local mine = myPlotIndex()
	for _, part in ipairs(CollectionService:GetTagged("CYL_Spot")) do
		local def = WorldSpots.Get(part:GetAttribute("CYL_Spot"))
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if def and prompt then
			local enabled = true
			if def.Kind == "Shift" then
				enabled = life ~= nil and not life.Flags.Retired and World.WorkplaceOf[life.Career.Id] == def.Workplace
			elseif def.OwnHome then
				enabled = mine ~= nil and part:GetAttribute("Plot") == mine
			end
			prompt.Enabled = enabled
			local text = def.Label
			if life then
				local cost = WorldSpots.CostFor(def, life.Age)
				if (def.MinAge and life.Age < def.MinAge) or (def.MaxAge and life.Age > def.MaxAge) or (def.Flag and not life.Flags[def.Flag]) then
					text = "🔒 " .. text
				elseif cost > 0 then
					text = text .. " · " .. Format.Money(cost)
				end
			end
			prompt.ActionText = text
		end
	end
end

local function refreshPedestals()
	local data = DataController.Get()
	for _, sign in ipairs(CollectionService:GetTagged("CYL_Pedestal")) do
		local slotId = sign:GetAttribute("Slot")
		local life = data and data.Slots[slotId]
		local gui = sign:FindFirstChild("Text")
		local label = gui and gui:FindFirstChild("Label")
		if label then
			if type(life) == "table" then
				label.Text = if life.Completed then ("✔ %s · lived to %d"):format(life.Name, life.Age) else ("%s · age %d"):format(life.Name, life.Age)
			else
				label.Text = "Empty · begin a new life"
			end
		end
	end
end

-- ===== Top bar =====
local function barHeight(): number
	return if UIController.IsNarrow() then 112 else 66
end

function ExploreController.UpdateBar()
	if not refs.Name then
		return
	end
	local life = activeLife()
	local style = StyleController.Get()
	local name = if life then life.Name else (Players.LocalPlayer.DisplayName or "You")
	refs.Name.Text = style.Face .. " " .. Avatar.NameRich(name, style)
	local district = currentDistrict and World.ById[currentDistrict]
	local place = if district then district.Icon .. " " .. district.Name else "🛣️ " .. World.TownName
	if life then
		local stage = LifeStages.Get(life.Stage)
		refs.Sub.Text = ("Age %d · %s · %s"):format(life.Age, stage.DisplayName, place)
		refs.Money:FindFirstChild("Label").Text = "💰 " .. Format.Money(life.Money)
		local left = ExploreController.ActionsLeft(life)
		refs.Actions:FindFirstChild("Label").Text = ("⚡ %d/%d actions"):format(left, People.ActionsPerTurn)
		refs.Actions:FindFirstChild("Label").TextColor3 = if left > 0 then Theme.Color.Text else Theme.Color.Warning
	else
		refs.Sub.Text = "No life yet · " .. place
		refs.Money:FindFirstChild("Label").Text = "💰 —"
		refs.Actions:FindFirstChild("Label").Text = "⚡ —"
	end
	Components.SetText(refs.Next, if life then (if UIController.IsNarrow() then "📝" else "📝  Next decision") else (if UIController.IsNarrow() then "✨" else "✨  Start a life"))
end

local function render()
	Create.Clear(frame, true)
	refs = {}
	local narrow = UIController.IsNarrow()
	local height = barHeight()
	local bar = Create("Frame", { Name = "TopBar", BackgroundColor3 = Theme.Color.Surface, BackgroundTransparency = 0.12, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, height), Parent = frame }, { Create.Corner(Theme.Radius), Create.Stroke(), Create.Padding(8, 12) })
	local top = Create("Frame", { Name = "Row1", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Parent = bar })
	Components.Button({ Name = "Menu", Text = "≡", Style = "Secondary", Size = UDim2.fromOffset(50, 50), TextSize = 28, Parent = top, OnClick = function()
		UIController.Show("Menu")
	end })
	local rightWidth = if narrow then 50 else 236 + 8 + 130
	local identity = Create("Frame", { Name = "Identity", BackgroundTransparency = 1, Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -(62 + rightWidth + (if narrow then 8 else 300)), 0, 50), Parent = top })
	if narrow then
		identity.Size = UDim2.new(1, -(62 + rightWidth + 8), 0, 50)
	end
	refs.Name = Create.Label({ Name = "Name", RichText = true, FontFace = Theme.Font.Heavy, TextSize = 20, Size = UDim2.new(1, 0, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = identity })
	refs.Sub = Create.Label({ Name = "Sub", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = identity })
	local right = Create("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(rightWidth, 50), Parent = top })
	Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right).Parent = right
	local chips = right
	if narrow then
		local row2 = Create("Frame", { Name = "Row2", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 40), Parent = bar })
		Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = row2
		chips = row2
	else
		local middle = Create("Frame", { Name = "Chips", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(rightWidth + 8), 0, 5), Size = UDim2.fromOffset(292, 40), Parent = top })
		Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = middle
		chips = middle
	end
	refs.Money = Components.Chip({ Text = "", Height = 40, LayoutOrder = 1, Parent = chips })
	refs.Money.Name = "Money"
	refs.Actions = Components.Chip({ Text = "", Height = 40, LayoutOrder = 2, Parent = chips })
	refs.Actions.Name = "ActionsLeft"
	Components.Button({ Name = "Map", Text = if narrow then "🗺️ Map" else "Map", Icon = if narrow then nil else "🗺️", Style = "Secondary", Size = UDim2.fromOffset(if narrow then 110 else 130, if narrow then 40 else 50), TextSize = 18, LayoutOrder = 3, Parent = if narrow then chips else right, OnClick = function()
		controller("MapController").Open()
	end })
	refs.Next = Components.Button({ Name = "NextDecision", Text = "", Style = "Primary", Size = UDim2.fromOffset(if narrow then 50 else 236, 50), TextSize = if narrow then 24 else 19, LayoutOrder = 4, Parent = right, OnClick = function()
		if activeLife() then
			UIController.Show("Game")
		else
			controller("MenuController").QuickPlay()
		end
	end })

	-- District banner and result card (under the bar, clear of touch controls)
	refs.Banner = Create("CanvasGroup", { Name = "Banner", BackgroundColor3 = Theme.Color.Surface, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, height + 22), Size = UDim2.fromOffset(math.min(520, UIController.GetVirtualSize().X - 40), 64), GroupTransparency = 1, Visible = false, Parent = frame }, { Create.Corner(Theme.Radius), Create.Stroke(Theme.Color.Gold, 2, 0.2) })
	Create.Label({ Name = "Title", FontFace = Theme.Font.Heavy, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), Parent = refs.Banner })
	Create.Label({ Name = "Blurb", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 36), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = refs.Banner })
	refs.Card = Create("CanvasGroup", { Name = "ResultCard", BackgroundColor3 = Theme.Color.Surface, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, height + 96), Size = UDim2.fromOffset(math.min(560, UIController.GetVirtualSize().X - 40), 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, Visible = false, Parent = frame }, { Create.Corner(Theme.Radius), Create.Stroke(Theme.Color.Positive, 2, 0.1), Create.Padding(12, 16) })
	Create.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = refs.Card
	ExploreController.UpdateBar()
end

local function showBanner(districtId: string?)
	local banner = refs.Banner
	if not banner or not districtId then
		return
	end
	local d = World.ById[districtId]
	local life = activeLife()
	local stage = World.StageOf(life)
	local open = World.IsUnlocked(districtId, stage)
	banner.Title.Text = (if open then d.Icon .. "  " else "🔒  ") .. d.Name
	banner.Blurb.Text = if open then d.Blurb else World.UnlockText(d.UnlockStage)
	banner.Visible = true
	banner.GroupTransparency = 0
	Anim.Pop(banner, 0.9, 0.25)
	local token = d.Id .. os.clock()
	banner:SetAttribute("Token", token)
	task.delay(3.5, function()
		if banner:GetAttribute("Token") == token then
			Anim.Tween(banner, { GroupTransparency = 1 }, 0.4)
		end
	end)
end

local function districtLoop()
	while exploring do
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local id = World.DistrictAt(root.Position.X, root.Position.Z)
			if id ~= currentDistrict then
				currentDistrict = id
				showBanner(id)
				ExploreController.UpdateBar()
				ExploreController.DistrictChanged:Fire(id)
			end
		end
		task.wait(0.5)
	end
end

function ExploreController.Enter()
	UIController.Show("Explore")
end

local function onOpen()
	exploring = true
	render()
	ControlsController.SetEnabled(true)
	ProximityPromptService.Enabled = true
	GuiService.SelectedObject = nil
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	ExploreController.RefreshPrompts()
	refreshPedestals()
	ExploreController.Changed:Fire(true)
	task.spawn(districtLoop)
end

local function onClose()
	exploring = false
	currentDistrict = nil
	ControlsController.SetEnabled(false)
	ProximityPromptService.Enabled = false
	UIController.ClosePanel()
	ExploreController.Changed:Fire(false)
end

function ExploreController.Init()
	frame = UIController.NewScreen("Explore", { Backdrop = false, OnOpen = onOpen, OnClose = onClose })
	HUDController.AddAction({ Id = "Explore", Icon = "🌆", Order = 1, Style = "Primary", OnClick = ExploreController.Enter })
	ProximityPromptService.Enabled = false
end

function ExploreController.Start()
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	DataController.Changed:Connect(function()
		if exploring then
			ExploreController.UpdateBar()
			ExploreController.RefreshPrompts()
			refreshPedestals()
		end
	end)
	StyleController.Changed:Connect(function()
		if exploring then
			ExploreController.UpdateBar()
		end
	end)
	UIController.LayoutChanged:Connect(function()
		if exploring then
			render()
		end
	end)
	CollectionService:GetInstanceAddedSignal("CYL_Spot"):Connect(function()
		if exploring then
			task.defer(ExploreController.RefreshPrompts)
		end
	end)
end

return ExploreController
