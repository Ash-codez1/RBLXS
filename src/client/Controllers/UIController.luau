--[[
	UIController  (StarterPlayerScripts.Client.Controllers.UIController)
	Owns the ScreenGuis, responsive scaling, the screen router and modals.

	Responsive scaling: all UI is designed in "virtual pixels". We pick a design
	resolution for the device shape (landscape / phone-landscape / portrait),
	compute scale = min(screen / design) × the player's UI Scale setting, and
	apply it with a UIScale. Root frames are sized in virtual pixels, so text
	and touch targets stay readable on phones and crisp on 4K monitors.

	Screens:
	  local frame = UIController.NewScreen("Menu", { Back = nil, OnOpen = fn, OnClose = fn, Backdrop = true })
	  UIController.Show("Menu", ...)      -- fades the old screen out, new one in
	  UIController.Back()                 -- previous screen (gamepad B does this)
	  UIController.Confirm({ Title, Text, ConfirmText, CancelText, Danger }) -> boolean (yields)
	Layout:
	  UIController.GetVirtualSize() -> Vector2,  UIController.IsNarrow() -> boolean
	  UIController.LayoutChanged:Connect(fn(virtualSize, isNarrow))
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)
local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local UIController = {}
UIController.Priority = 1

UIController.LayoutChanged = Signal.new()
UIController.ScreenChanged = Signal.new()

local mainGui: ScreenGui
local overlayGui: ScreenGui
local backdropGui: ScreenGui
local root: Frame
local overlay: Frame
local backdrop: Frame
local scales: { UIScale } = {}

local userScale = 1
local currentScale = 1
local virtualSize = Theme.DesignLandscape
local narrow = false

local screens: { [string]: any } = {}
local current: string? = nil
local history: { string } = {}
local modalOpen = false
local navigatingBack = false

-- ===== Scaling =====
local function computeLayout()
	local absolute = mainGui.AbsoluteSize
	if absolute.X < 2 or absolute.Y < 2 then
		return
	end
	local design
	if absolute.Y > absolute.X then
		design = Theme.DesignPortrait
	elseif absolute.Y < 500 then
		design = Theme.DesignCompact
	else
		design = Theme.DesignLandscape
	end
	local scale = math.min(absolute.X / design.X, absolute.Y / design.Y) * userScale
	scale = math.clamp(scale, 0.4, 3)
	currentScale = scale
	virtualSize = Vector2.new(math.floor(absolute.X / scale), math.floor(absolute.Y / scale))
	narrow = virtualSize.X < Theme.NarrowWidth

	for _, s in ipairs(scales) do
		s.Scale = scale
	end
	root.Size = UDim2.fromOffset(virtualSize.X, virtualSize.Y)
	overlay.Size = UDim2.fromOffset(virtualSize.X, virtualSize.Y)
	UIController.LayoutChanged:Fire(virtualSize, narrow)
end

function UIController.GetVirtualSize(): Vector2
	return virtualSize
end

-- The UIScale currently applied to virtual-pixel layouts.
function UIController.GetScale(): number
	return currentScale
end

function UIController.IsNarrow(): boolean
	return narrow
end

function UIController.SetUserScale(value: number)
	userScale = math.clamp(value, 0.75, 1.25)
	if mainGui then
		computeLayout()
	end
end

function UIController.GetRoot()
	return root
end

function UIController.GetOverlay()
	return overlay
end

function UIController.UsingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return UserInputService.GamepadEnabled and (last.Name:find("Gamepad") ~= nil)
end

-- Moves gamepad selection to `target` when a gamepad is in use.
function UIController.Focus(target: GuiObject?)
	if target and UIController.UsingGamepad() then
		GuiService.SelectedObject = target
	end
end

-- ===== Screens =====
function UIController.NewScreen(name: string, options: { [string]: any }?)
	options = options or {}
	local frame = Create("CanvasGroup", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		GroupTransparency = 1,
		Parent = root,
	})
	screens[name] = {
		Frame = frame,
		Back = options.Back,
		OnOpen = options.OnOpen,
		OnClose = options.OnClose,
		Backdrop = options.Backdrop ~= false,
		DefaultFocus = options.DefaultFocus,
	}
	return frame
end

function UIController.SetScreenOptions(name: string, options: { [string]: any })
	local screen = screens[name]
	for key, value in pairs(options) do
		screen[key] = value
	end
end

function UIController.HasScreen(name: string): boolean
	return screens[name] ~= nil
end

function UIController.Current(): string?
	return current
end

function UIController.Show(name: string, ...)
	local screen = screens[name]
	assert(screen, "UIController.Show: unknown screen " .. name)
	if current == name then
		if screen.OnOpen then
			task.spawn(screen.OnOpen, ...)
		end
		return
	end
	local previous = current and screens[current]
	if previous then
		Anim.Fade(previous.Frame, false, 0.18)
		if previous.OnClose then
			task.spawn(previous.OnClose)
		end
		if not navigatingBack then
			table.insert(history, current :: string)
			if #history > 20 then
				table.remove(history, 1)
			end
		end
	end
	current = name
	backdrop.Visible = screen.Backdrop
	Anim.Fade(screen.Frame, true, 0.28)
	if screen.OnOpen then
		task.spawn(screen.OnOpen, ...)
	end
	task.defer(function()
		if current == name and screen.DefaultFocus then
			UIController.Focus(screen.DefaultFocus())
		end
	end)
	UIController.ScreenChanged:Fire(name)
end

-- Goes to the screen's declared Back target: a screen name, or `true` for
-- "wherever I came from". History is trimmed so it always reflects the path.
function UIController.Back()
	if modalOpen or not current then
		return
	end
	local screen = screens[current]
	local target = if screen.Back == true then history[#history] else screen.Back
	if not target or not screens[target] then
		return
	end
	for i = #history, 1, -1 do
		if history[i] == target then
			for j = #history, i, -1 do
				history[j] = nil
			end
			break
		end
	end
	navigatingBack = true
	UIController.Show(target)
	navigatingBack = false
end

-- ===== Modals =====
function UIController.Confirm(options: { [string]: any }): boolean
	if modalOpen then
		return false
	end
	modalOpen = true
	local result = nil
	local previousSelection = GuiService.SelectedObject

	local dim = Create("CanvasGroup", {
		Name = "ConfirmModal",
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = overlay,
	})
	local width = math.min(520, virtualSize.X - 40)
	local panel = Components.Panel({
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Color = Theme.Color.Surface,
		Padding = 24,
		Parent = dim,
	})
	Create.List(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center).Parent = panel
	Create.Label({
		Text = options.Title or "Are you sure?",
		FontFace = Theme.Font.Heavy,
		TextSize = Theme.TextSize.H2,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = panel,
	})
	Create.Label({
		Text = options.Text or "",
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = panel,
	})
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 3, Parent = panel })
	Create.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = row
	local buttonWidth = math.floor((width - 48 - 12) / 2)
	local cancel = Components.Button({
		Text = options.CancelText or "Cancel",
		Style = "Secondary",
		Size = UDim2.fromOffset(buttonWidth, 54),
		LayoutOrder = 1,
		Parent = row,
		OnClick = function()
			result = false
		end,
	})
	Components.Button({
		Text = options.ConfirmText or "Confirm",
		Style = if options.Danger then "Danger" else "Primary",
		Size = UDim2.fromOffset(buttonWidth, 54),
		LayoutOrder = 2,
		Parent = row,
		OnClick = function()
			result = true
		end,
	})
	Anim.Fade(dim, true, 0.2)
	Anim.Pop(panel, 0.9)
	UIController.Focus(cancel)
	UIController._modalCancel = function()
		result = false
	end

	while result == nil do
		task.wait()
	end
	UIController._modalCancel = nil
	modalOpen = false
	Anim.Fade(dim, false, 0.15)
	task.delay(0.3, function()
		dim:Destroy()
	end)
	if previousSelection and previousSelection.Parent then
		UIController.Focus(previousSelection)
	end
	return result
end

function UIController.IsModalOpen(): boolean
	return modalOpen
end

--[[
	Panel modal used by the HUD panels (People, Lifestyle, Money, Stats).
	Only one is open at a time. Returns a handle:
	  { Root, Panel, Scroll, Close(), IsOpen() }
	Closes on ✕, on tapping outside, and on gamepad B.
]]
local currentPanel = nil
function UIController.ClosePanel()
	if currentPanel then
		local handle = currentPanel
		currentPanel = nil
		ContextActionService:UnbindAction("CYL_ClosePanel")
		Anim.Fade(handle.Root, false, 0.15)
		task.delay(0.25, function()
			handle.Root:Destroy()
		end)
		if handle.OnClose then
			task.spawn(handle.OnClose)
		end
	end
end

function UIController.OpenPanel(options: { [string]: any })
	UIController.ClosePanel()
	local modalRoot = Create("CanvasGroup", { Name = options.Name or "PanelModal", BackgroundColor3 = Theme.Color.Black, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = overlay })
	local closer = Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Selectable = false, Parent = modalRoot })
	closer.Activated:Connect(UIController.ClosePanel)
	local width = math.min(options.Width or 820, virtualSize.X - 24)
	local height = math.min(options.Height or 660, virtualSize.Y - 24)
	local panel = Components.Panel({ Name = "Panel", Size = UDim2.fromOffset(width, height), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Padding = 20, Parent = modalRoot })
	Create.Label({ Name = "Title", Text = options.Title or "", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, Size = UDim2.new(1, -60, 0, 36), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = panel })
	local subtitle = Create.Label({ Name = "Subtitle", Text = options.Subtitle or "", TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, -60, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = panel })
	local close = Components.Button({ Name = "Close", Text = "✕", Style = "Secondary", Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = panel, OnClick = UIController.ClosePanel })
	local scroll = Create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Stroke,
		Selectable = false,
		Parent = panel,
	})
	Create.List(Enum.FillDirection.Vertical, 12).Parent = scroll
	Create.Padding(4, 10, 14, 4).Parent = scroll

	local handle = { Root = modalRoot, Panel = panel, Scroll = scroll, Subtitle = subtitle, Close = UIController.ClosePanel, OnClose = options.OnClose }
	function handle.IsOpen()
		return currentPanel == handle
	end
	-- Rebuilds the scrolling contents (keeps scroll position).
	function handle.Clear()
		Create.Clear(scroll)
	end
	currentPanel = handle
	Anim.Fade(modalRoot, true, 0.2)
	Anim.Pop(panel, 0.94)
	UIController.Focus(close)
	ContextActionService:BindActionAtPriority("CYL_ClosePanel", function(_, state)
		if state == Enum.UserInputState.Begin then
			UIController.ClosePanel()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	return handle
end

function UIController.CurrentPanel()
	return currentPanel
end

-- ===== Backdrop: gradient + slowly drifting soft circles =====
local function buildBackdrop()
	backdrop = Create("Frame", {
		Name = "Backdrop",
		BackgroundColor3 = Theme.Color.White,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = backdropGui,
	}, { Create.Gradient(Theme.Gradient.Backdrop, 120) })
	local gradient = backdrop:FindFirstChildOfClass("UIGradient")
	if gradient then
		Anim.Loop(gradient, { Rotation = 160 }, 12)
	end
	local orbColors = { Theme.Color.Primary, Theme.Color.Accent, Theme.Color.AccentAlt, Theme.Color.PrimaryAlt }
	local rng = Random.new(7)
	for i = 1, 6 do
		local size = rng:NextInteger(180, 420)
		local orb = Create("Frame", {
			Name = "Orb" .. i,
			BackgroundColor3 = orbColors[(i - 1) % #orbColors + 1],
			BackgroundTransparency = 0.86,
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.05, 0.95)),
			Parent = backdrop,
		}, { Create.Corner(Theme.RadiusPill) })
		orb:SetAttribute("Decor", true)
		local target = orb.Position + UDim2.fromScale(rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.08, 0.08))
		Anim.Loop(orb, { Position = target }, rng:NextNumber(9, 16))
	end
end

function UIController.SetDecorations(enabled: boolean)
	if not backdrop then
		return
	end
	for _, child in ipairs(backdrop:GetChildren()) do
		if child:GetAttribute("Decor") then
			(child :: GuiObject).Visible = enabled
		end
	end
end

-- ===== Lifecycle =====
function UIController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	backdropGui = Create("ScreenGui", {
		Name = "CYL_Backdrop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1,
		Parent = playerGui,
	})
	mainGui = Create("ScreenGui", {
		Name = "CYL_Main",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	overlayGui = Create("ScreenGui", {
		Name = "CYL_Overlay",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Parent = playerGui,
	})

	root = Create("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = mainGui })
	overlay = Create("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = overlayGui })
	for _, container in ipairs({ root, overlay }) do
		local s = Instance.new("UIScale")
		s.Parent = container
		table.insert(scales, s)
	end
	buildBackdrop()

	mainGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(computeLayout)
	computeLayout()

	-- Gamepad B goes back; modals treat it as Cancel.
	ContextActionService:BindAction("CYL_Back", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if modalOpen and UIController._modalCancel then
			UIController._modalCancel()
			return Enum.ContextActionResult.Sink
		end
		if current and screens[current].Back then
			UIController.Back()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)
end

function UIController.Start() end

return UIController
