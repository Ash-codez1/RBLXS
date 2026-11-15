--[[
	DecisionController  (StarterPlayerScripts.Client.Controllers.DecisionController)
	Draws scenarios inside the Game screen and drives the decision loop:

	  GetScenario → choice cards → select (highlight + confirm bar) → confirm
	  → MakeChoice → outcome card (story, stat changes, traits) → Continue
	  → age-up / stage-complete transition → next scenario

	Input: click/tap a card to select, tap again or press Confirm to lock it in.
	Keyboard 1–5 selects, Enter confirms / continues. Gamepad: D-pad + A, B to cancel.
	Locked choices show their unlock hint, so players know hidden paths exist.

	The client never decides outcomes; it only sends (scenarioId, choiceId).
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local LifeStages = require(Shared.Data.LifeStages)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local Traits = require(Shared.Data.Traits)
local Careers = require(Shared.Data.Careers)
local StatMath = require(Shared.Util.StatMath)
local People = require(Shared.Util.People)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local HUDController = require(script.Parent.HUDController)
local AudioController = require(script.Parent.AudioController)
local NotificationController = require(script.Parent.NotificationController)

local DecisionController = {}
DecisionController.Priority = 45

local content: Frame
local view: Frame? = nil
local mode = "Idle" -- Idle | Loading | Scenario | Outcome | Transition | Message
local scenario = nil
local selected = nil
local outcome = nil
local pendingEvent = nil -- event waiting to be shown after the outcome
local shownEvent = nil -- event card currently on screen
local busy = false
local cards: { [string]: TextButton } = {}
local confirmBar: Frame? = nil
local continueButton: GuiButton? = nil
local requestToken = 0

-- Invokes the server, waiting and retrying briefly if we were rate-limited
-- (e.g. very fast tapping), so the player never sees a spurious error.
local function invoke(name: string, ...)
	local ok, result
	for attempt = 1, 4 do
		ok, result = Net.Invoke(name, ...)
		if ok or result ~= "RateLimited" then
			break
		end
		task.wait(0.4 * attempt)
	end
	return ok, result
end

-- ===== View helpers =====
-- Views are plain Frames (not CanvasGroups): the Game screen is already a
-- CanvasGroup, and nesting them costs texture memory on mobile. Entry motion
-- comes from Anim.Pop on each view's main elements instead.
local function newView(): Frame
	if view then
		view:Destroy()
	end
	cards = {}
	confirmBar = nil
	continueButton = nil
	local v = Create("Frame", { Name = "View", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })
	view = v
	return v
end

local function previewText(choice): string
	if choice.Mystery then
		return "❓ <font color=\"" .. Theme.Hex.Dim .. "\">Unknown outcome</font>"
	end
	local parts = {}
	for _, p in ipairs(choice.Preview) do
		local info = StatDefinitions.Info[p.Stat]
		if info then
			local arrows = string.rep(if p.Dir > 0 then "▲" else "▼", p.Size)
			local color = if p.Dir > 0 then Theme.Hex.Positive else Theme.Hex.Negative
			table.insert(parts, ("%s<font color=\"%s\">%s</font>"):format(info.Icon, color, arrows))
		end
	end
	if choice.MoneyDir ~= 0 then
		table.insert(parts, ("💰<font color=\"%s\">%s</font>"):format(if choice.MoneyDir > 0 then Theme.Hex.Positive else Theme.Hex.Negative, if choice.MoneyDir > 0 then "▲" else "▼"))
	end
	if choice.Risky then
		table.insert(parts, "🎲<font color=\"" .. Theme.Hex.Gold .. "\">Risky</font>")
	end
	return table.concat(parts, "   ")
end

local function centeredPanel(parent: Instance, width: number)
	local panel = Components.Panel({
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Padding = 26,
		Parent = parent,
	})
	Create.List(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center).Parent = panel
	return panel
end

local function messageView(icon: string, title: string, body: string, buttons: { any })
	mode = "Message"
	local v = newView()
	local width = math.min(640, UIController.GetVirtualSize().X - 32)
	local panel = centeredPanel(v, width)
	Create.Label({ Text = icon, TextSize = 60, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 66), LayoutOrder = 1, Parent = panel })
	Create.Label({ Text = title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
	Create.Label({ Text = body, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = panel })
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 4, Parent = panel })
	Create.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = row
	local w = math.floor((width - 52 - 12 * (#buttons - 1)) / #buttons)
	local first
	for i, b in ipairs(buttons) do
		local button = Components.Button({ Text = b.Text, Icon = b.Icon, Style = b.Style or "Primary", Size = UDim2.fromOffset(math.min(w, 280), 56), LayoutOrder = i, Parent = row, OnClick = b.OnClick })
		first = first or button
	end
	Anim.Pop(panel, 0.92)
	UIController.Focus(first)
end

local function toMenu()
	UIController.Show("Menu")
end

local function showUnavailable()
	local life = DataController.GetActiveLife()
	local name = if life then life.Name else "Your"
	local stage = if life then LifeStages.Get(life.Stage).DisplayName else "next chapter"
	messageView(
		"📖",
		"To be continued…",
		("%s's %s haven't been written yet. Your life is saved at age %d, so you can pick up right here when new life stages arrive."):format(name, stage, if life then life.Age else 0),
		{
			{ Text = "Main Menu", Icon = "🏠", Style = "Secondary", OnClick = toMenu },
			{ Text = "Another Life", Icon = "✨", OnClick = function()
				UIController.Show("SlotSelect", "New")
			end },
		}
	)
end

local function showLifeComplete()
	local life = DataController.GetActiveLife()
	local body = "Every choice made this story yours."
	if life then
		local career = if life.Flags.Retired then "a well-earned retirement" elseif life.Career.Id ~= "None" then "life as " .. Careers.TitleAt(life.Career.Id, life.Career.Level) else "a life of their own design"
		body = ("%s lived to %d and ended with %s, %s in the bank, and overall life score %d/100. Every choice made this story yours."):format(
			life.Name,
			life.Age,
			career,
			Format.Money(life.Money),
			math.floor(StatMath.Overall(life.Stats) + 0.5)
		)
	end
	messageView("🌅", "A Life Complete", body, {
		{ Text = "Main Menu", Icon = "🏠", Style = "Secondary", OnClick = toMenu },
		{ Text = "Live Again", Icon = "✨", OnClick = function()
			UIController.Show("SlotSelect", "New")
		end },
	})
end

local function showError(reason: any)
	messageView("⚠️", "Hmm, that didn't work", "We couldn't load your next decision (" .. tostring(reason) .. "). Your progress is safe.", {
		{ Text = "Main Menu", Icon = "🏠", Style = "Secondary", OnClick = toMenu },
		{ Text = "Try Again", Icon = "🔄", OnClick = function()
			DecisionController.Next()
		end },
	})
end

local function showLoading()
	mode = "Loading"
	local v = newView()
	Create.Label({
		Text = "✨ Thinking about your life…",
		FontFace = Theme.Font.Bold,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -40, 0, 40),
		Parent = v,
	})
end

-- ===== Scenario =====
local renderScenario

local function setCardHighlight(card: TextButton, state: string)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local dim = card:FindFirstChild("Dim") :: Frame
	local scale = Anim.Scale(card)
	if state == "Selected" then
		if stroke then
			stroke.Color = Theme.Color.Primary
			stroke.Thickness = 3
			stroke.Transparency = 0
		end
		Anim.Tween(dim, { BackgroundTransparency = 1 }, 0.15)
		Anim.Tween(scale, { Scale = 1.03 }, 0.2, Enum.EasingStyle.Back)
	elseif state == "Dimmed" then
		if stroke then
			stroke.Color = Theme.Color.Stroke
			stroke.Thickness = 1.5
			stroke.Transparency = 0.35
		end
		Anim.Tween(dim, { BackgroundTransparency = 0.5 }, 0.15)
		Anim.Tween(scale, { Scale = 0.97 }, 0.2)
	else
		if stroke then
			stroke.Color = Theme.Color.Stroke
			stroke.Thickness = 1.5
			stroke.Transparency = 0.35
		end
		Anim.Tween(dim, { BackgroundTransparency = 1 }, 0.15)
		Anim.Tween(scale, { Scale = 1 }, 0.2)
	end
end

local confirmChoice

local function clearSelection()
	selected = nil
	for _, card in pairs(cards) do
		setCardHighlight(card, "Normal")
	end
	if confirmBar then
		confirmBar.Visible = false
	end
end

local function selectChoice(choice)
	if busy or mode ~= "Scenario" then
		return
	end
	local card = cards[choice.Id]
	if choice.Locked then
		AudioController.Play("Locked")
		if card then
			Anim.Shake(card)
		end
		NotificationController.Notify({ Title = "Locked choice", Text = "🔒 " .. (choice.LockHint or "Not available yet"), Kind = "Warning", Duration = 3 })
		return
	end
	if selected == choice then
		confirmChoice()
		return
	end
	selected = choice
	AudioController.Play("Select")
	for id, c in pairs(cards) do
		setCardHighlight(c, if id == choice.Id then "Selected" else "Dimmed")
	end
	if confirmBar then
		local label = confirmBar:FindFirstChild("Choice") :: TextLabel
		label.Text = "You chose: <b>" .. choice.Text .. "</b>"
		confirmBar.Visible = true
		Anim.Pop(confirmBar, 0.9, 0.25)
		UIController.Focus(confirmBar:FindFirstChild("Confirm", true) :: GuiObject)
	end
end

local function buildCard(parent: Instance, choice, wide: boolean)
	local card = Create("TextButton", {
		Name = choice.Id,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = if choice.Locked then 0.45 else 0.02,
		Size = if wide then UDim2.new() else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if wide then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		LayoutOrder = choice.Index,
		Parent = parent,
	}, { Create.Corner(Theme.Radius), Create.Stroke() })

	-- Body holds the laid-out content; Dim sits on top and isn't part of the layout.
	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = if wide then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if wide then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		Parent = card,
	}, { Create.Padding(16) })
	Create.List(Enum.FillDirection.Vertical, 8).Parent = body

	local top = Create("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, Parent = body })
	local badge = Create("Frame", { Name = "Badge", BackgroundColor3 = Theme.Color.SurfaceHigher, Size = UDim2.fromOffset(32, 32), Parent = top }, { Create.Corner(Theme.RadiusPill) })
	Create.Label({ Text = if choice.Locked then "🔒" else tostring(choice.Index), FontFace = Theme.Font.Heavy, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = badge })
	if choice.Risky and not choice.Locked then
		local chip = Components.Chip({ Text = "🎲 Risky", Height = 28, TextSize = 14, Color = Theme.Color.SurfaceHigher, Parent = top })
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.fromScale(1, 0)
	end

	local textTransparency = if choice.Locked then 0.45 else 0
	Create.Label({ Name = "Text", Text = choice.Text, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, TextTransparency = textTransparency, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = body })
	Create.Label({
		Name = "Description",
		Text = if choice.Locked then "🔒 " .. (choice.LockHint or "Locked") else (choice.Description or ""),
		TextSize = Theme.TextSize.Small,
		TextColor3 = if choice.Locked then Theme.Color.Warning else Theme.Color.TextDim,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = body,
	})
	if not choice.Locked then
		Create.Label({ Name = "Preview", Text = previewText(choice), RichText = true, FontFace = Theme.Font.Bold, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = body })
		if choice.Tags and #choice.Tags > 0 then
			Create.Label({ Name = "Tags", Text = table.concat(choice.Tags, "  ·  "), FontFace = Theme.Font.Bold, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = body })
		end
	end
	-- Dim overlay used when another card is selected.
	Create("Frame", { Name = "Dim", BackgroundColor3 = Theme.Color.Black, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card }, { Create.Corner(Theme.Radius) })

	local stroke = card:FindFirstChildOfClass("UIStroke")
	card.SelectionGained:Connect(function()
		if selected ~= choice and stroke then
			stroke.Color = Theme.Color.Gold
			stroke.Thickness = 2.5
		end
	end)
	card.SelectionLost:Connect(function()
		if selected ~= choice and stroke then
			stroke.Color = Theme.Color.Stroke
			stroke.Thickness = 1.5
		end
	end)
	card.Activated:Connect(function()
		selectChoice(choice)
	end)
	cards[choice.Id] = card
	return card
end

function renderScenario(animateIn: boolean?)
	mode = "Scenario"
	local v = newView()
	local vs = UIController.GetVirtualSize()
	local narrow = UIController.IsNarrow()
	local width = math.min(1180, vs.X - 32)

	local scroll = Create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Stroke,
		Selectable = false,
		Parent = v,
	})
	Create.List(Enum.FillDirection.Vertical, 18, Enum.HorizontalAlignment.Center).Parent = scroll
	Create.Padding(6, 16, if narrow then 150 else 110, 16).Parent = scroll

	-- Header: icon, title, age/stage line, description.
	local header = Create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	Create.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = header
	local stage = LifeStages.Get(scenario.Stage)
	Create.Label({
		Text = ("AGE %d  ·  %s  ·  DECISION %d OF %d"):format(scenario.Age, string.upper(scenario.StageName), scenario.ScenarioNumber, scenario.ScenariosInStage),
		FontFace = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Tiny,
		TextColor3 = stage.Color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = header,
	})
	Create.Label({
		Name = "Title",
		Text = scenario.Icon .. "  " .. scenario.Title,
		FontFace = Theme.Font.Heavy,
		TextSize = if narrow then 34 else Theme.TextSize.H1 + 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = header,
	})
	local description = Create.Label({
		Text = scenario.Description,
		TextColor3 = Theme.Color.TextDim,
		TextSize = if narrow then Theme.TextSize.Body else 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = header,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(820, math.huge) }).Parent = description

	-- Choice cards: a responsive grid on wide screens, a list on narrow ones.
	local choicesFrame = Create("Frame", { Name = "Choices", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	local count = #scenario.Choices
	if narrow then
		Create.List(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center).Parent = choicesFrame
	else
		local gap = 16
		local columns = math.clamp(math.floor((width + gap) / (210 + gap)), 1, count)
		if count == 4 and columns == 3 then
			columns = 2
		end
		local cellWidth = math.floor((width - gap * (columns - 1)) / columns)
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellWidth, if columns >= 4 then 250 else 210),
			CellPadding = UDim2.fromOffset(gap, gap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = choicesFrame,
		})
	end
	local firstOpen
	for i, choice in ipairs(scenario.Choices) do
		local card = buildCard(choicesFrame, choice, not narrow)
		if not choice.Locked and not firstOpen then
			firstOpen = card
		end
		if animateIn ~= false then
			Anim.Pop(card, 0.85, 0.3 + i * 0.06)
		end
	end

	-- Confirm bar pinned to the bottom of the content area.
	local barWidth = math.min(700, vs.X - 32)
	local bar = Components.Panel({
		Name = "ConfirmBar",
		Size = UDim2.fromOffset(barWidth, if narrow then 126 else 80),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Color = Theme.Color.SurfaceHigh,
		Padding = 12,
		Parent = v,
	})
	bar.ZIndex = 10
	bar.Visible = false
	Create.Label({
		Name = "Choice",
		RichText = true,
		Text = "",
		TextSize = Theme.TextSize.Body,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = narrow,
		Size = if narrow then UDim2.new(1, 0, 0, 44) else UDim2.new(1, -300, 1, 0),
		Parent = bar,
	})
	local buttons = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = if narrow then UDim2.new(1, 0, 0, 54) else UDim2.new(0, 290, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Parent = bar,
	})
	Create.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = buttons
	Components.Button({ Name = "Cancel", Text = "✕", Style = "Ghost", Size = UDim2.fromOffset(56, 54), LayoutOrder = 1, Parent = buttons, OnClick = function()
		clearSelection()
		UIController.Focus(firstOpen)
	end })
	Components.Button({ Name = "Confirm", Text = "Confirm", Icon = "✓", Style = "Primary", Size = if narrow then UDim2.new(1, -66, 0, 54) else UDim2.fromOffset(220, 54), LayoutOrder = 2, Parent = buttons, OnClick = function()
		confirmChoice()
	end })
	confirmBar = bar

	if selected then
		local keep = selected
		selected = nil
		selectChoice(keep)
	else
		UIController.Focus(firstOpen)
	end
end

-- ===== Outcome =====
local renderOutcome
local renderEvent
local advance

-- Adds change chips (stats, money, life changes, traits) to `parent`.
local function addChangeChips(parent: Instance, result, animateIn: boolean?, extra: { { Text: string, Color: Color3? } }?)
	local changeList = Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	changeList.Wraps = true
	changeList.Parent = parent
	local order = 0
	local function addChip(text: string, color: Color3?)
		order += 1
		local chip = Components.Chip({ Text = text, Height = 38, TextColor = color, LayoutOrder = order, Parent = parent })
		if animateIn ~= false then
			Anim.Pop(chip, 0.6, 0.35 + order * 0.05)
		end
	end
	for _, text in ipairs(result.LifeChanges or {}) do
		addChip(text, Theme.Color.Gold)
	end
	local list = {}
	for stat, delta in pairs(result.Applied or {}) do
		if math.abs(delta) >= 0.05 then
			table.insert(list, { Stat = stat, Delta = delta })
		end
	end
	table.sort(list, function(a, b)
		return math.abs(a.Delta) > math.abs(b.Delta)
	end)
	for _, change in ipairs(list) do
		local info = StatDefinitions.Info[change.Stat]
		if info then
			addChip(("%s %s %s"):format(info.Icon, info.DisplayName, Format.Signed(change.Delta)), if change.Delta > 0 then Theme.Color.Positive else Theme.Color.Negative)
		end
	end
	if result.MoneyDelta and result.MoneyDelta ~= 0 then
		addChip("💰 " .. (if result.MoneyDelta > 0 then "+" else "") .. Format.Money(result.MoneyDelta), if result.MoneyDelta > 0 then Theme.Color.Positive else Theme.Color.Negative)
	end
	for _, change in ipairs(result.BondChanges or {}) do
		if math.abs(change.Delta) >= 1 then
			local role = People.Roles[change.Role]
			addChip(("%s %s %s"):format(if role then role.Icon else "👤", change.Name, Format.Signed(change.Delta)), if change.Delta > 0 then Theme.Color.Positive else Theme.Color.Negative)
		end
	end
	for _, item in ipairs(extra or {}) do
		addChip(item.Text, item.Color)
	end
	for _, traitId in ipairs(result.TraitsGained or {}) do
		local info = Traits.Info[traitId]
		if info then
			addChip("New trait: " .. info.Icon .. " " .. info.DisplayName, Theme.Color.Gold)
		end
	end
	if order == 0 then
		addChip("No big changes… for now.", Theme.Color.TextDim)
	end
end

function renderOutcome(animateIn: boolean?)
	mode = "Outcome"
	local v = newView()
	local vs = UIController.GetVirtualSize()
	local width = math.min(760, vs.X - 32)

	local scroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Selectable = false,
		Parent = v,
	})
	local list = Create.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	list.Parent = scroll
	Create.Padding(10, 16, 20, 16).Parent = scroll

	local panel = Components.Panel({ Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 26, Parent = scroll })
	Create.List(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center).Parent = panel

	Create.Label({ Text = "WHAT HAPPENED", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Primary, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = panel })
	if outcome.Lucky then
		Components.Chip({ Text = "🎲 Twist of fate!", Color = Theme.Color.SurfaceHigher, TextColor = Theme.Color.Gold, LayoutOrder = 2, Parent = panel })
	end
	local story = Create.Label({
		Name = "Story",
		Text = if outcome.Story ~= "" then outcome.Story else "Life goes on.",
		FontFace = Theme.Font.Medium,
		TextSize = Theme.TextSize.H3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = panel,
	})
	if animateIn ~= false and not Anim.Reduced then
		-- Typewriter reveal.
		story.MaxVisibleGraphemes = 0
		local total = utf8.len(story.Text) or #story.Text
		task.spawn(function()
			local shown = 0
			while shown < total and story.Parent do
				shown = math.min(total, shown + 3)
				story.MaxVisibleGraphemes = shown
				task.wait(1 / 60)
			end
			story.MaxVisibleGraphemes = -1
		end)
	end

	local changes = Create("Frame", { Name = "Changes", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = panel })
	local extra = {}
	if outcome.Years and outcome.Years > 0 and outcome.Income ~= 0 then
		if outcome.Income > 0 then
			table.insert(extra, { Text = ("💵 Earned %s over %d yr%s"):format(Format.Money(outcome.Income), outcome.Years, if outcome.Years == 1 then "" else "s"), Color = Theme.Color.Positive })
		else
			table.insert(extra, { Text = ("💸 Living costs %s over %d yr%s"):format(Format.Money(-outcome.Income), outcome.Years, if outcome.Years == 1 then "" else "s"), Color = Theme.Color.Negative })
		end
	end
	addChangeChips(changes, outcome, animateIn, extra)

	if outcome.StageCompleted then
		Create.Label({ Text = "🏁 " .. outcome.CompletedStageName .. " complete!", FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = panel })
	elseif outcome.Age ~= outcome.PrevAge then
		Create.Label({ Text = "🎂 Next: age " .. outcome.Age, FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = panel })
	end

	continueButton = Components.Button({
		Name = "Continue",
		Text = "Continue",
		Icon = "▶",
		Style = "Primary",
		Size = UDim2.fromOffset(math.min(320, width - 52), 60),
		LayoutOrder = 6,
		Parent = panel,
		OnClick = function()
			advance()
		end,
	})
	if animateIn ~= false then
		Anim.Pop(panel, 0.9)
	end
	UIController.Focus(continueButton)
end

-- ===== Random life event =====
local RARITY_STYLE = {
	Common = { Label = "LIFE EVENT", Color = Theme.Color.Accent },
	Uncommon = { Label = "UNCOMMON EVENT", Color = Theme.Color.Positive },
	Rare = { Label = "✨ RARE EVENT ✨", Color = Theme.Color.AccentAlt },
	Legendary = { Label = "🌟 LEGENDARY EVENT 🌟", Color = Theme.Color.Gold },
}

function renderEvent(event, animateIn: boolean?)
	mode = "Event"
	local v = newView()
	local style = RARITY_STYLE[event.Rarity] or RARITY_STYLE.Common
	local width = math.min(720, UIController.GetVirtualSize().X - 32)
	local scroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Selectable = false,
		Parent = v,
	})
	Create.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = scroll
	Create.Padding(10, 16, 20, 16).Parent = scroll
	local panel = Components.Panel({ Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 26, Parent = scroll })
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = style.Color
		stroke.Thickness = if event.Rarity == "Legendary" then 4 else 2.5
		stroke.Transparency = 0
	end
	Create.List(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center).Parent = panel
	Create.Label({ Text = style.Label, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Small, TextColor3 = style.Color, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = panel })
	local icon = Create.Label({ Text = event.Icon, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 2, Parent = panel })
	Create.Label({ Text = event.Title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = panel })
	Create.Label({ Text = event.Story, TextSize = Theme.TextSize.H3, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = panel })
	local changes = Create("Frame", { Name = "Changes", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = panel })
	addChangeChips(changes, event, animateIn)
	continueButton = Components.Button({
		Name = "Continue",
		Text = "Continue",
		Icon = "▶",
		Style = if event.Rarity == "Legendary" then "Primary" else "Accent",
		Size = UDim2.fromOffset(math.min(320, width - 52), 60),
		LayoutOrder = 6,
		Parent = panel,
		OnClick = function()
			advance()
		end,
	})
	if animateIn ~= false then
		Anim.Pop(panel, 0.8, 0.45)
		Anim.Pop(icon, 0.4, 0.6)
	end
	AudioController.Play(if event.Rarity == "Rare" or event.Rarity == "Legendary" then "StageComplete" else "Notify")
	UIController.Focus(continueButton)
end

-- ===== Transitions =====
local function transition(big: string, small: string, color: Color3, hold: number)
	mode = "Transition"
	local v = newView()
	v.BackgroundColor3 = Theme.Color.Background
	v.BackgroundTransparency = 0.2
	local skip = false
	local skipper = Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Selectable = false, Parent = v })
	skipper.Activated:Connect(function()
		skip = true
	end)
	local bigLabel = Create.Label({
		Text = big,
		FontFace = Theme.Font.Heavy,
		TextSize = if UIController.IsNarrow() then 52 else 76,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = v,
	})
	Create.Label({
		Text = small,
		FontFace = Theme.Font.Bold,
		TextSize = Theme.TextSize.H3,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = v,
	})
	Anim.Pop(bigLabel, 0.6, 0.5)
	local elapsed = 0
	local total = if Anim.Reduced then math.min(hold, 0.8) else hold
	while elapsed < total and not skip and view == v do
		elapsed += task.wait()
	end
end

function advance()
	if busy or not outcome then
		return
	end
	if pendingEvent then
		shownEvent = pendingEvent
		pendingEvent = nil
		renderEvent(shownEvent, true)
		return
	end
	busy = true
	shownEvent = nil
	local o = outcome
	if o.StageCompleted then
		AudioController.Play("StageComplete")
		local nextStage = LifeStages.Get(o.Stage)
		local subtitle = if o.LifeCompleted then "Your story is complete." else ("%s begin · Age %d"):format(o.StageName, o.Age)
		transition("🏁 " .. o.CompletedStageName .. " complete!", subtitle, nextStage.Color, 2.6)
	elseif o.Age ~= o.PrevAge then
		AudioController.Play("AgeUp")
		transition("🎂 Age " .. o.Age, "", Theme.Color.Gold, 1.3)
	end
	busy = false
	outcome = nil
	if UIController.Current() ~= "Game" then
		return
	end
	if o.LifeCompleted then
		showLifeComplete()
	elseif not o.NextStageAvailable then
		showUnavailable()
	else
		DecisionController.Next()
	end
end

function confirmChoice()
	if busy or mode ~= "Scenario" or not selected or not scenario then
		return
	end
	busy = true
	local choice = selected
	AudioController.Play("Confirm")
	for id, card in pairs(cards) do
		card.Active = false
		if id ~= choice.Id then
			Anim.Tween(card:FindFirstChild("Dim"), { BackgroundTransparency = 0.25 }, 0.2)
		end
	end
	if confirmBar then
		confirmBar.Visible = false
	end
	local selectedCard = cards[choice.Id]
	if selectedCard then
		Anim.Tween(Anim.Scale(selectedCard), { Scale = 1.08 }, 0.25, Enum.EasingStyle.Back)
	end

	local ok, result = invoke("MakeChoice", scenario.Id, choice.Id)
	busy = false
	if not ok then
		if result == "WrongScenario" or result == "NoLife" or result == "ChoiceLocked" then
			-- Our view was out of date (e.g. money was spent in the Money panel).
			DecisionController.Next()
		else
			NotificationController.Notify({ Title = "Couldn't make that choice", Text = tostring(result), Kind = "Error" })
			selected = nil
			renderScenario(false)
		end
		return
	end
	AudioController.Play(if (result.Applied.Happiness or 0) >= 0 then "Positive" else "Negative")
	task.wait(if Anim.Reduced then 0 else 0.3)
	outcome = result
	pendingEvent = result.Event
	scenario = nil
	selected = nil
	if UIController.Current() == "Game" then
		renderOutcome(true)
	end
end

-- ===== Loop =====
function DecisionController.Next()
	requestToken += 1
	local token = requestToken
	showLoading()
	local ok, payload = invoke("GetScenario")
	if token ~= requestToken or UIController.Current() ~= "Game" then
		return
	end
	if ok then
		scenario = payload
		selected = nil
		renderScenario(true)
	elseif payload == "NoLife" then
		UIController.Show("Menu")
	elseif payload == "StageNotAvailable" then
		showUnavailable()
	elseif payload == "LifeComplete" then
		showLifeComplete()
	else
		showError(payload)
	end
end

-- Re-fetches the current scenario so locked/unlocked choices reflect the
-- latest money, people and stats (called after People/Money panel actions).
function DecisionController.Refresh()
	if mode ~= "Scenario" or busy or not scenario then
		return
	end
	local keep = selected and selected.Id
	local ok, payload = invoke("GetScenario")
	if ok and mode == "Scenario" and UIController.Current() == "Game" then
		scenario = payload
		selected = nil
		renderScenario(false)
		if keep then
			for _, choice in ipairs(payload.Choices) do
				if choice.Id == keep and not choice.Locked then
					selectChoice(choice)
				end
			end
		end
	end
end

function DecisionController.GetMode(): string
	return mode
end

local KEY_INDEX = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

function DecisionController.Init()
	content = HUDController.Content :: Frame
end

function DecisionController.Start()
	HUDController.Opened:Connect(function()
		-- Returning mid-way restores exactly where the player was.
		if outcome and shownEvent then
			renderEvent(shownEvent, false)
		elseif outcome then
			renderOutcome(false)
		else
			DecisionController.Next()
		end
	end)
	HUDController.Closed:Connect(function()
		requestToken += 1
		mode = "Idle"
		ContextActionService:UnbindAction("CYL_CancelChoice")
	end)
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() ~= "Game" then
			return
		end
		if mode == "Scenario" and scenario then
			renderScenario(false)
		elseif mode == "Outcome" and outcome then
			renderOutcome(false)
		elseif mode == "Event" and shownEvent then
			renderEvent(shownEvent, false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UIController.Current() ~= "Game" or UIController.IsModalOpen() then
			return
		end
		local index = KEY_INDEX[input.KeyCode]
		if index and mode == "Scenario" and scenario and scenario.Choices[index] then
			selectChoice(scenario.Choices[index])
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			if mode == "Scenario" and selected then
				confirmChoice()
			elseif mode == "Outcome" or mode == "Event" then
				advance()
			end
		end
	end)

	-- Gamepad B clears a selection instead of leaving the game screen.
	HUDController.Opened:Connect(function()
		ContextActionService:BindAction("CYL_CancelChoice", function(_, state)
			if state == Enum.UserInputState.Begin and mode == "Scenario" and selected then
				clearSelection()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.ButtonB)
	end)
end

return DecisionController
