--[[
	Theme  (StarterPlayerScripts.Client.UILib.Theme)
	One place for colours, fonts, sizes and the virtual design resolution, so
	every screen looks consistent.
]]

local Theme = {}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
Theme.Font = {
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
}

Theme.Color = {
	Background = Color3.fromRGB(13, 14, 30),
	BackgroundAlt = Color3.fromRGB(34, 20, 58),
	Surface = Color3.fromRGB(27, 30, 56),
	SurfaceHigh = Color3.fromRGB(39, 43, 78),
	SurfaceHigher = Color3.fromRGB(52, 57, 100),
	Stroke = Color3.fromRGB(78, 84, 140),
	Text = Color3.fromRGB(246, 247, 255),
	TextDim = Color3.fromRGB(172, 177, 214),
	TextFaint = Color3.fromRGB(120, 126, 170),
	Primary = Color3.fromRGB(255, 90, 140),
	PrimaryAlt = Color3.fromRGB(255, 150, 90),
	Accent = Color3.fromRGB(108, 140, 255),
	AccentAlt = Color3.fromRGB(150, 100, 255),
	Positive = Color3.fromRGB(88, 220, 145),
	Negative = Color3.fromRGB(245, 90, 100),
	Warning = Color3.fromRGB(255, 196, 72),
	Gold = Color3.fromRGB(255, 212, 90),
	Black = Color3.fromRGB(0, 0, 0),
	White = Color3.fromRGB(255, 255, 255),
}

-- Hex strings for RichText <font color="">.
Theme.Hex = {
	Positive = "#58DC91",
	Negative = "#F55A64",
	Dim = "#ACB1D6",
	Gold = "#FFD45A",
}

Theme.TextSize = {
	Hero = 64,
	H1 = 40,
	H2 = 28,
	H3 = 23,
	Body = 20,
	Small = 17,
	Tiny = 14,
}

Theme.Radius = UDim.new(0, 16)
Theme.RadiusSmall = UDim.new(0, 10)
Theme.RadiusPill = UDim.new(1, 0)

Theme.Gradient = {
	Primary = ColorSequence.new(Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 150, 90)),
	Accent = ColorSequence.new(Color3.fromRGB(108, 140, 255), Color3.fromRGB(150, 100, 255)),
	Positive = ColorSequence.new(Color3.fromRGB(60, 200, 130), Color3.fromRGB(110, 230, 170)),
	Danger = ColorSequence.new(Color3.fromRGB(230, 70, 90), Color3.fromRGB(255, 120, 90)),
	Backdrop = ColorSequence.new(Color3.fromRGB(13, 14, 30), Color3.fromRGB(40, 20, 66)),
	Title = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 170)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 170, 255)),
	}),
}

-- Virtual design resolutions. UIController picks one and scales the UI so
-- it fills the screen on every device.
Theme.DesignLandscape = Vector2.new(1280, 720)
Theme.DesignCompact = Vector2.new(960, 540) -- phones held sideways
Theme.DesignPortrait = Vector2.new(540, 960) -- phones held upright
Theme.NarrowWidth = 900 -- below this virtual width, layouts stack vertically

-- Minimum touch target in virtual pixels.
Theme.TouchTarget = 48

return Theme
