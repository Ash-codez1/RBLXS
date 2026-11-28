--[[
	Components  (StarterPlayerScripts.Client.UILib.Components)
	Reusable, themed widgets. Every interactive widget works with mouse,
	touch and gamepad (all are Selectable buttons; sliders also have −/+).

	Components.Button{ Text, Icon?, Style?, Size?, TextSize?, LayoutOrder?, Parent?, OnClick }
	Components.SetDisabled(button, disabled) / Components.SetText(button, text)
	Components.Panel{ Size?, Color?, Parent?, ... }
	Components.Slider{ Label, Min, Max, Step, Value, Format?, OnChanged, Parent?, LayoutOrder? } -> { Instance, Set }
	Components.Toggle{ Label, Value, OnChanged, Parent?, LayoutOrder? }                  -> { Instance, Set }
	Components.Selector{ Label, Options, Labels?, Value, OnChanged, Parent?, LayoutOrder? } -> { Instance, Set }
	Components.StatBar{ Name, Icon, Color, Value, Compact?, Parent?, LayoutOrder? }        -> { Instance, Set }
	Components.Chip{ Text, Color?, Parent?, LayoutOrder? }

	Components.OnClickSound: set by AudioController to play a click.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Create = require(script.Parent.Create)
local Anim = require(script.Parent.Anim)

local Components = {}
Components.OnClickSound = nil :: (() -> ())?

local STYLES = {
	Primary = { Color = Theme.Color.White, Gradient = Theme.Gradient.Primary, Text = Theme.Color.White },
	Accent = { Color = Theme.Color.White, Gradient = Theme.Gradient.Accent, Text = Theme.Color.White },
	Positive = { Color = Theme.Color.White, Gradient = Theme.Gradient.Positive, Text = Theme.Color.White },
	Danger = { Color = Theme.Color.White, Gradient = Theme.Gradient.Danger, Text = Theme.Color.White },
	Secondary = { Color = Theme.Color.SurfaceHigh, Text = Theme.Color.Text, Stroke = true },
	Ghost = { Color = Theme.Color.Surface, Text = Theme.Color.TextDim, Stroke = true, Transparency = 0.35 },
}

-- ===== Button =====
function Components.Button(p)
	local style = STYLES[p.Style or "Primary"] or STYLES.Primary
	local button = Create("TextButton", {
		Name = p.Name or "Button",
		AutoButtonColor = false,
		Text = "",
		Size = p.Size or UDim2.fromOffset(280, 56),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = style.Color,
		BackgroundTransparency = style.Transparency or 0,
		LayoutOrder = p.LayoutOrder or 0,
		Selectable = true,
		Parent = p.Parent,
	}, {
		Create.Corner(p.Radius or Theme.RadiusSmall),
	})
	if style.Gradient then
		Create.Gradient(style.Gradient, 15).Parent = button
	end
	local stroke = Create.Stroke(if style.Stroke then Theme.Color.Stroke else Theme.Color.White, 1.5, if style.Stroke then 0.4 else 1)
	stroke.Parent = button

	local text = p.Text or ""
	Create.Label({
		Name = "Label",
		Text = if p.Icon then p.Icon .. "  " .. text else text,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Font.Bold,
		TextSize = p.TextSize or 22,
		TextColor3 = style.Text,
		TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = button,
	})
	if p.TextXAlignment == Enum.TextXAlignment.Left then
		Create.Padding(0, 18).Parent = button
	end

	local scale = Anim.Scale(button)
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		if not button:GetAttribute("Disabled") then
			Anim.Tween(scale, { Scale = 1.03 }, 0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		Anim.Tween(scale, { Scale = 1 }, 0.15)
	end)
	button.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not button:GetAttribute("Disabled") then
			Anim.Tween(scale, { Scale = 0.96 }, 0.08)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Anim.Tween(scale, { Scale = if hovering then 1.03 else 1 }, 0.12)
		end
	end)
	-- Gamepad selection highlight.
	button.SelectionGained:Connect(function()
		stroke.Color = Theme.Color.Gold
		stroke.Thickness = 3
		stroke.Transparency = 0
	end)
	button.SelectionLost:Connect(function()
		stroke.Color = if style.Stroke then Theme.Color.Stroke else Theme.Color.White
		stroke.Thickness = 1.5
		stroke.Transparency = if style.Stroke then 0.4 else 1
	end)

	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		if Components.OnClickSound then
			Components.OnClickSound()
		end
		if p.OnClick then
			p.OnClick(button)
		end
	end)
	return button
end

function Components.SetDisabled(button: GuiButton, disabled: boolean)
	button:SetAttribute("Disabled", disabled)
	button.BackgroundTransparency = if disabled then 0.6 else 0
	local label = button:FindFirstChild("Label")
	if label then
		(label :: TextLabel).TextTransparency = if disabled then 0.5 else 0
	end
end

function Components.SetText(button: GuiButton, text: string)
	local label = button:FindFirstChild("Label")
	if label then
		(label :: TextLabel).Text = text
	end
end

-- ===== Panel =====
function Components.Panel(p)
	local props = {
		Name = p.Name or "Panel",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = p.Color or Theme.Color.Surface,
		BackgroundTransparency = p.Transparency or 0.05,
		LayoutOrder = p.LayoutOrder or 0,
		AutomaticSize = p.AutomaticSize or Enum.AutomaticSize.None,
		Parent = p.Parent,
	}
	local panel = Create("Frame", props, { Create.Corner(p.Radius), Create.Stroke() })
	if p.Padding then
		Create.Padding(p.Padding).Parent = panel
	end
	return panel
end

-- ===== Chip =====
function Components.Chip(p)
	local chip = Create("Frame", {
		Name = "Chip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, p.Height or 34),
		BackgroundColor3 = p.Color or Theme.Color.SurfaceHigh,
		BackgroundTransparency = p.Transparency or 0.1,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = p.Parent,
	}, { Create.Corner(Theme.RadiusPill), Create.Padding(0, 14) })
	Create.Label({
		Name = "Label",
		Text = p.Text,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextWrapped = false,
		FontFace = Theme.Font.Bold,
		TextSize = p.TextSize or Theme.TextSize.Small,
		TextColor3 = p.TextColor or Theme.Color.Text,
		Parent = chip,
	})
	return chip
end

-- ===== Row helper for settings widgets =====
local function settingRow(p, height)
	local row = Create("Frame", {
		Name = p.Label or "Row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Color.SurfaceHigh,
		BackgroundTransparency = 0.2,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = p.Parent,
	}, { Create.Corner(Theme.RadiusSmall), Create.Padding(10, 16) })
	Create.Label({
		Name = "Title",
		Text = p.Label,
		Size = UDim2.new(0.5, 0, 0, 28),
		FontFace = Theme.Font.Bold,
		TextSize = Theme.TextSize.Body,
		Parent = row,
	})
	return row
end

local function smallButton(text: string, onClick: () -> ())
	return Components.Button({ Text = text, Style = "Secondary", Size = UDim2.fromOffset(Theme.TouchTarget, Theme.TouchTarget - 8), TextSize = 22, OnClick = onClick })
end

-- ===== Slider =====
function Components.Slider(p)
	local min, max, step = p.Min, p.Max, p.Step or 0.05
	local value = p.Value
	local format = p.Format or function(v)
		return tostring(math.floor(v * 100 + 0.5)) .. "%"
	end
	local row = settingRow(p, 96)

	local valueLabel = Create.Label({
		Name = "Value",
		Size = UDim2.new(0.5, 0, 0, 28),
		Position = UDim2.fromScale(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.TextDim,
		FontFace = Theme.Font.Bold,
		Parent = row,
	})

	local controls = Create("Frame", {
		Name = "Controls",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget - 8),
		Position = UDim2.fromOffset(0, 34),
		Parent = row,
	})
	local minus = smallButton("−", function()
		Components._sliderNudge(p, -1)
	end)
	minus.Parent = controls
	local plus = smallButton("+", function()
		Components._sliderNudge(p, 1)
	end)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.fromScale(1, 0)
	plus.Parent = controls

	local track = Create("TextButton", {
		Name = "Track",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Theme.Color.Background,
		Size = UDim2.new(1, -(Theme.TouchTarget * 2 + 28), 0, 12),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = controls,
	}, { Create.Corner(Theme.RadiusPill) })
	local fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.White,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create.Corner(Theme.RadiusPill), Create.Gradient(Theme.Gradient.Primary) })
	local knob = Create("Frame", {
		Name = "Knob",
		BackgroundColor3 = Theme.Color.White,
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Parent = track,
	}, { Create.Corner(Theme.RadiusPill) })

	local function render()
		local alpha = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = format(value)
	end

	local function set(newValue: number, silent: boolean?)
		newValue = math.clamp(math.floor((newValue - min) / step + 0.5) * step + min, min, max)
		newValue = math.floor(newValue * 1000 + 0.5) / 1000
		if newValue == value then
			render()
			return
		end
		value = newValue
		render()
		if not silent and p.OnChanged then
			p.OnChanged(value)
		end
	end
	p._set = set
	p._get = function()
		return value
	end

	local dragging = false
	local function fromX(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + alpha * (max - min))
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	render()
	return { Instance = row, Set = set, Get = p._get }
end

function Components._sliderNudge(p, direction: number)
	p._set(p._get() + direction * (p.Step or 0.05))
end

-- ===== Toggle =====
function Components.Toggle(p)
	local value = p.Value == true
	local row = settingRow(p, 60)
	local pill = Create("TextButton", {
		Name = "Switch",
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		Size = UDim2.fromOffset(72, 38),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Theme.Color.Background,
		Parent = row,
	}, { Create.Corner(Theme.RadiusPill), Create.Stroke() })
	local knob = Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(30, 30),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Color.TextDim,
		Parent = pill,
	}, { Create.Corner(Theme.RadiusPill) })
	local stroke = pill:FindFirstChildOfClass("UIStroke")

	local function render(animate: boolean?)
		local props = { Position = if value then UDim2.new(1, -34, 0.5, 0) else UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = if value then Theme.Color.White else Theme.Color.TextDim }
		if animate then
			Anim.Tween(knob, props, 0.18)
		else
			knob.Position = props.Position
			knob.BackgroundColor3 = props.BackgroundColor3
		end
		pill.BackgroundColor3 = if value then Theme.Color.Positive else Theme.Color.Background
	end
	local function set(newValue: boolean, silent: boolean?)
		value = newValue == true
		render(true)
		if not silent and p.OnChanged then
			p.OnChanged(value)
		end
	end
	pill.Activated:Connect(function()
		if Components.OnClickSound then
			Components.OnClickSound()
		end
		set(not value)
	end)
	pill.SelectionGained:Connect(function()
		if stroke then
			stroke.Color = Theme.Color.Gold
			stroke.Thickness = 3
		end
	end)
	pill.SelectionLost:Connect(function()
		if stroke then
			stroke.Color = Theme.Color.Stroke
			stroke.Thickness = 1.5
		end
	end)
	render(false)
	return { Instance = row, Set = set, Get = function()
		return value
	end }
end

-- ===== Selector (cycle through options) =====
function Components.Selector(p)
	local options = p.Options
	local labels = p.Labels or options
	local index = table.find(options, p.Value) or 1
	local row = settingRow(p, 60)
	local box = Create("Frame", {
		Name = "Box",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(250, Theme.TouchTarget - 8),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Parent = row,
	})
	local valueLabel = Create.Label({
		Name = "Value",
		Size = UDim2.new(1, -(Theme.TouchTarget * 2), 1, 0),
		Position = UDim2.fromOffset(Theme.TouchTarget, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Font.Bold,
		Parent = box,
	})
	local function render()
		valueLabel.Text = labels[index]
	end
	local function step(direction: number)
		index = (index - 1 + direction) % #options + 1
		render()
		if p.OnChanged then
			p.OnChanged(options[index])
		end
	end
	local left = smallButton("‹", function()
		step(-1)
	end)
	left.Parent = box
	local right = smallButton("›", function()
		step(1)
	end)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Parent = box
	render()
	return {
		Instance = row,
		Set = function(v)
			index = table.find(options, v) or index
			render()
		end,
		Get = function()
			return options[index]
		end,
	}
end

-- ===== StatBar =====
function Components.StatBar(p)
	local compact = p.Compact == true
	local height = if compact then 34 else 58
	local frame = Create("Frame", {
		Name = p.Name,
		BackgroundTransparency = 1,
		Size = p.Size or UDim2.new(1, 0, 0, height),
		LayoutOrder = p.LayoutOrder or 0,
		Parent = p.Parent,
	})
	local title = Create.Label({
		Name = "Title",
		Text = p.Icon .. "  " .. p.DisplayName,
		Size = UDim2.new(1, -60, 0, if compact then 16 else 26),
		TextSize = if compact then Theme.TextSize.Tiny else Theme.TextSize.Body,
		FontFace = Theme.Font.Bold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = frame,
	})
	local valueLabel = Create.Label({
		Name = "Value",
		Size = UDim2.new(0, 60, 0, if compact then 16 else 26),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = if compact then Theme.TextSize.Tiny else Theme.TextSize.Body,
		FontFace = Theme.Font.Heavy,
		TextColor3 = p.Color,
		Parent = frame,
	})
	if compact then
		title.Visible = p.ShowTitle ~= false
	end
	local track = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Color.Background,
		Size = UDim2.new(1, 0, 0, if compact then 8 else 14),
		Position = UDim2.new(0, 0, 1, if compact then -10 else -18),
		Parent = frame,
	}, { Create.Corner(Theme.RadiusPill) })
	local fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = p.Color,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create.Corner(Theme.RadiusPill) })

	local current = nil
	local function set(value: number, animate: boolean?)
		value = math.clamp(value, 0, 100)
		valueLabel.Text = tostring(math.floor(value + 0.5))
		local size = UDim2.fromScale(value / 100, 1)
		if animate and current ~= nil then
			Anim.Tween(fill, { Size = size }, 0.6)
		else
			fill.Size = size
		end
		current = value
	end
	set(p.Value or 0, false)
	return { Instance = frame, Set = set }
end

-- ===== Progress bar =====
-- Components.ProgressBar({ Fraction 0..1, Color?, Text?, Size?, LayoutOrder?, Parent?, Name? })
function Components.ProgressBar(p)
	local track = Create("Frame", {
		Name = p.Name or "Progress",
		BackgroundColor3 = Theme.Color.Background,
		Size = p.Size or UDim2.new(1, 0, 0, 22),
		LayoutOrder = p.LayoutOrder or 0,
		Parent = p.Parent,
	}, { Create.Corner(Theme.RadiusPill) })
	Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = p.Color or Theme.Color.Positive,
		Size = UDim2.fromScale(math.clamp(p.Fraction or 0, 0, 1), 1),
		Parent = track,
	}, { Create.Corner(Theme.RadiusPill) })
	if p.Text then
		Create.Label({
			Name = "Label",
			Text = p.Text,
			TextSize = Theme.TextSize.Tiny,
			FontFace = Theme.Font.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = track,
		})
	end
	return track
end

return Components
