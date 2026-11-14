--[[
	Layout  (StarterPlayerScripts.Client.UILib.Layout)
	Screen-level layout helpers shared by every menu.

	Layout.Header(parent, title, onBack?)     -> header frame (back button + title)
	Layout.Scroll(parent, props?)             -> ScrollingFrame with vertical list + auto canvas
	Layout.Column(parent, width, props?)      -> centred vertical column frame
]]

local Theme = require(script.Parent.Theme)
local Create = require(script.Parent.Create)
local Components = require(script.Parent.Components)

local Layout = {}

Layout.HeaderHeight = 72

function Layout.Header(parent: Instance, title: string, onBack: (() -> ())?)
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Layout.HeaderHeight),
		Parent = parent,
	}, { Create.Padding(12, 20) })
	local backButton
	if onBack then
		backButton = Components.Button({
			Name = "Back",
			Text = "‹  Back",
			Style = "Ghost",
			Size = UDim2.fromOffset(120, Theme.TouchTarget),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			TextSize = 20,
			Parent = header,
			OnClick = onBack,
		})
	end
	Create.Label({
		Name = "Title",
		Text = title,
		FontFace = Theme.Font.Heavy,
		TextSize = Theme.TextSize.H1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -280, 1, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		TextScaled = true,
		Parent = header,
	})
	local titleLabel = header:FindFirstChild("Title") :: TextLabel
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = Theme.TextSize.H1
	constraint.MinTextSize = 18
	constraint.Parent = titleLabel
	return header, backButton
end

function Layout.Scroll(parent: Instance, props: { [string]: any }?)
	local defaults = {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -Layout.HeaderHeight),
		Position = UDim2.fromOffset(0, Layout.HeaderHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Stroke,
		Selectable = false,
		Parent = parent,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	local scroll = Create("ScrollingFrame", defaults)
	Create.List(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center).Parent = scroll
	Create.Padding(8, 16, 24, 16).Parent = scroll
	return scroll
end

function Layout.Column(parent: Instance, width: number, props: { [string]: any }?)
	local defaults = {
		Name = "Column",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	local column = Create("Frame", defaults)
	Create.List(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center).Parent = column
	return column
end

return Layout
