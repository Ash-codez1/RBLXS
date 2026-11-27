--[[
	RevealController  (StarterPlayerScripts.Client.Controllers.RevealController)
	The cinematic LIFE REVEAL sequences (data comes from the server: Lib/Reveal).

	RevealController.PlayStage(reveal)          -- yields until the player continues
	RevealController.PlayFinal(entry, options)  -- yields; returns "Again" | "History" | "Menu"

	Built entirely from UI (the 3D world arrives in Phase 8): title cards with
	light rays, counting probability bars with trend arrows, typewriter
	predictions, a TWIST sequence, and an animated preview scene for the
	predicted future (Luxury, Family, Fame, Career, Genius, Health, Hero,
	Content, Adventure, Difficult, Lonely) with a slow "camera" push-in.
	Tap to speed up a step; Skip jumps to the end card. Respects Reduce animations.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Futures = require(Shared.Util.Futures)
local Format = require(Shared.Util.Format)
local LifeStages = require(Shared.Data.LifeStages)
local World = require(Shared.Data.World)
local StatDefinitions = require(Shared.Data.StatDefinitions)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local UIController = require(script.Parent.UIController)
local AudioController = require(script.Parent.AudioController)
local StyleController = require(script.Parent.StyleController)
local Avatar = require(UILib.Avatar)

local RevealController = {}
RevealController.Priority = 46

local gui: ScreenGui
local root: Frame
local uiScale: UIScale
local playing = false
local session = { Fast = false, Skip = false }

-- ===== Layout =====
-- Full-screen size in pixels. A disabled ScreenGui may not report its size
-- yet, so fall back to the camera's viewport.
local function screenSize(): Vector2
	local absolute = gui.AbsoluteSize
	if (not absolute or absolute.X < 2) and workspace and workspace.CurrentCamera then
		absolute = workspace.CurrentCamera.ViewportSize
	end
	return absolute
end

local function layout()
	local scale = UIController.GetScale()
	uiScale.Scale = scale
	local absolute = screenSize()
	root.Size = UDim2.fromOffset(math.floor(absolute.X / scale), math.floor(absolute.Y / scale))
end

local function size(): Vector2
	local absolute = screenSize()
	local scale = UIController.GetScale()
	return Vector2.new(absolute.X / scale, absolute.Y / scale)
end

-- ===== Sequencing =====
local function pause(seconds: number)
	if Anim.Reduced then
		seconds *= 0.5
	end
	local elapsed = 0
	while elapsed < seconds and not session.Fast and not session.Skip do
		elapsed += task.wait()
	end
end

local function newStep(): Frame
	session.Fast = false
	Create.Clear(root:FindFirstChild("Stage") :: Frame)
	return root:FindFirstChild("Stage") :: Frame
end

local function label(parent, props)
	local defaults = { TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = parent }
	for k, v in pairs(props) do
		defaults[k] = v
	end
	return Create.Label(defaults)
end

local function column(parent, width: number)
	local frame = Create("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = parent,
	})
	Create.List(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center).Parent = frame
	return frame
end

local function typewrite(textLabel: TextLabel, cps: number?)
	if Anim.Reduced then
		return
	end
	local total = utf8.len(textLabel.Text) or #textLabel.Text
	textLabel.MaxVisibleGraphemes = 0
	local shown = 0
	while shown < total and not session.Fast and not session.Skip do
		shown += math.max(1, math.floor((cps or 45) / 30))
		textLabel.MaxVisibleGraphemes = shown
		task.wait(1 / 30)
	end
	textLabel.MaxVisibleGraphemes = -1
end

-- Rotating light rays behind a title.
local function lightRays(parent, color: Color3)
	local s = size()
	local d = math.max(s.X, s.Y) * 1.6
	local rays = Create("Frame", {
		Name = "Rays",
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(d, d),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 0,
		Parent = parent,
	}, { Create.Corner(Theme.RadiusPill) })
	local keypoints = {}
	for i = 0, 12 do
		table.insert(keypoints, NumberSequenceKeypoint.new(i / 12, if i % 2 == 0 then 0.82 else 1))
	end
	local gradient = Create("UIGradient", { Transparency = NumberSequence.new(keypoints), Parent = rays })
	Anim.Loop(gradient, { Rotation = 90 }, 10)
	return rays
end

local function flash(color: Color3?)
	if Anim.Reduced then
		return
	end
	local f = Create("Frame", { Name = "Flash", BackgroundColor3 = color or Theme.Color.White, BackgroundTransparency = 0.1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	Anim.Tween(f, { BackgroundTransparency = 1 }, 0.6)
	task.delay(0.7, function()
		f:Destroy()
	end)
end

local function skipButton()
	local button = Components.Button({
		Name = "RevealSkip",
		Text = "Skip ▶▶",
		Style = "Ghost",
		Size = UDim2.fromOffset(130, 46),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		TextSize = 18,
		Parent = root,
		OnClick = function()
			session.Skip = true
		end,
	})
	button.ZIndex = 30
	return button
end

-- ===== Probability bars =====
local function futureBar(parent, entry, previous: number?, order: number, width: number)
	local info = Futures.Info[entry.Id]
	local row = Create("Frame", { Name = entry.Id, BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 46), LayoutOrder = order, Parent = parent })
	Create.Label({ Text = info.Icon .. "  " .. info.Title, FontFace = Theme.Font.Bold, TextSize = Theme.TextSize.Body, Size = UDim2.new(0.6, 0, 0, 24), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local pctLabel = Create.Label({ Name = "Pct", Text = "0%", FontFace = Theme.Font.Heavy, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, 0, 0, 24), Position = UDim2.fromScale(0.6, 0), TextWrapped = false, Parent = row })
	local track = Create("Frame", { BackgroundColor3 = Theme.Color.Background, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 30), Parent = row }, { Create.Corner(Theme.RadiusPill) })
	local color = if info.Positive then (if entry.Pct >= 60 then Theme.Color.Positive elseif entry.Pct >= 35 then Theme.Color.Warning else Theme.Color.Accent) else Theme.Color.Negative
	local fill = Create("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale((previous or 0) / 100, 1), Parent = track }, { Create.Corner(Theme.RadiusPill) })
	local trend = ""
	if previous then
		local diff = entry.Pct - previous
		if math.abs(diff) >= 3 then
			trend = ("  <font color=\"%s\">%s%d</font>"):format(if (diff > 0) == info.Positive then Theme.Hex.Positive else Theme.Hex.Negative, if diff > 0 then "▲" else "▼", math.abs(diff))
		end
	end
	pctLabel.RichText = true
	return function(duration: number)
		Anim.Tween(fill, { Size = UDim2.fromScale(entry.Pct / 100, 1) }, duration)
		task.spawn(function()
			local start = previous or 0
			local steps = math.max(1, math.floor(duration * 30))
			for i = 1, steps do
				if session.Fast or session.Skip then
					break
				end
				pctLabel.Text = tostring(math.floor(start + (entry.Pct - start) * i / steps + 0.5)) .. "%"
				task.wait(duration / steps)
			end
			pctLabel.Text = entry.Pct .. "%" .. trend
		end)
	end
end

local function chosenFutures(predictions)
	local positives, risks = Futures.Sorted(predictions)
	local list = {}
	for i = 1, math.min(4, #positives) do
		table.insert(list, positives[i])
	end
	if risks[1] and risks[1].Pct >= 25 then
		table.insert(list, risks[1])
	end
	return list
end

local function barsStep(title: string, predictions, previous, subtitle: string?)
	local step = newStep()
	local width = math.min(640, size().X - 40)
	local col = column(step, width)
	label(col, { Text = title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
	if subtitle then
		label(col, { Text = subtitle, TextColor3 = Theme.Color.TextDim, LayoutOrder = 2 })
	end
	local starters = {}
	for i, entry in ipairs(chosenFutures(predictions)) do
		table.insert(starters, futureBar(col, entry, previous and previous[entry.Id], 10 + i, width))
	end
	for _, start in ipairs(starters) do
		start(0.7)
		AudioController.Play("Select")
		pause(0.35)
	end
	pause(1.4)
end

-- ===== Cinematic preview scenes =====
local SCENES = {
	Luxury = { Sky = { Color3.fromRGB(60, 30, 90), Color3.fromRGB(255, 190, 90) }, Hero = "🏰", Props = { "🏎️", "💎", "🛥️" }, Sparkle = "✨", Caption = "A mansion on the hill. Cars in the drive. A life of luxury." },
	Family = { Sky = { Color3.fromRGB(255, 160, 120), Color3.fromRGB(255, 220, 160) }, Hero = "🏡", Props = { "👨‍👩‍👧‍👦", "🐶", "🌳" }, Sparkle = "💛", Caption = "A house full of laughter, and the people you love most." },
	Fame = { Sky = { Color3.fromRGB(20, 10, 40), Color3.fromRGB(120, 40, 160) }, Hero = "🎤", Props = { "📸", "👏", "🌟" }, Sparkle = "🌟", Caption = "Bright lights. Screaming fans. Your name in lights." },
	Career = { Sky = { Color3.fromRGB(20, 40, 90), Color3.fromRGB(100, 160, 255) }, Hero = "🏙️", Props = { "💼", "📈", "🏆" }, Sparkle = "⭐", Caption = "The corner office. The top of your field." },
	Genius = { Sky = { Color3.fromRGB(10, 20, 60), Color3.fromRGB(60, 90, 200) }, Hero = "🔬", Props = { "💡", "📚", "🧠" }, Sparkle = "✦", Caption = "Discoveries, inventions, ideas that change the world." },
	Health = { Sky = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 230, 160) }, Hero = "🏃", Props = { "🌅", "🥗", "🚴" }, Sparkle = "☀️", Caption = "Strong, energetic and still running marathons at 80." },
	Hero = { Sky = { Color3.fromRGB(40, 30, 80), Color3.fromRGB(255, 200, 120) }, Hero = "🏅", Props = { "🤝", "🏛️", "🕊️" }, Sparkle = "✨", Caption = "Respected. Trusted. The person everyone turns to." },
	Content = { Sky = { Color3.fromRGB(255, 190, 220), Color3.fromRGB(190, 220, 255) }, Hero = "😊", Props = { "🌈", "🌻", "☕" }, Sparkle = "💫", Caption = "Not perfect, but genuinely, deeply happy." },
	Adventure = { Sky = { Color3.fromRGB(40, 120, 200), Color3.fromRGB(120, 220, 200) }, Hero = "🌍", Props = { "✈️", "⛰️", "🧭" }, Sparkle = "✦", Caption = "Mountains, oceans, a passport full of stamps." },
	Difficult = { Sky = { Color3.fromRGB(40, 45, 60), Color3.fromRGB(90, 95, 110) }, Hero = "🏚️", Props = { "🌧️", "🧾", "☂️" }, Sparkle = "💧", Caption = "Hard times could be ahead… but it's not too late to change course." },
	Lonely = { Sky = { Color3.fromRGB(20, 25, 50), Color3.fromRGB(60, 70, 110) }, Hero = "🪑", Props = { "🌙", "🕯️", "📞" }, Sparkle = "✦", Caption = "A quiet house… but people are waiting to know you." },
}

-- Your shop cosmetics star in your own future: equipped home, car and pet
-- replace the defaults in the scenes where they belong.
local function personalise(archetype: string, scene)
	local style = StyleController.Get()
	local result = table.clone(scene)
	result.Props = table.clone(scene.Props)
	if archetype == "Luxury" then
		result.Hero = style.House or scene.Hero
		result.Props[1] = style.Car or scene.Props[1]
		result.Props[3] = style.Pet or scene.Props[3]
	elseif archetype == "Family" then
		result.Hero = style.House or scene.Hero
		result.Props[2] = style.Pet or scene.Props[2]
	elseif archetype == "Career" then
		result.Props[1] = style.Car or scene.Props[1]
	elseif archetype == "Content" or archetype == "Health" then
		result.Props[2] = style.Pet or scene.Props[2]
	end
	return result
end

-- Falling glyphs from an equipped Reveal effect (shop cosmetic). They live in
-- their own layer above the steps, so they keep falling into the next step
-- (e.g. when the player skips straight to the end card).
local function effectRain(count: number)
	local glyphs = StyleController.Get().RevealGlyphs
	if not glyphs or Anim.Reduced then
		return
	end
	local layer = root:FindFirstChild("Fx") or Create("Frame", { Name = "Fx", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = root })
	local rng = Random.new()
	for i = 1, count do
		local g = Create.Label({ Name = "RevealFx" .. i, Text = glyphs[(i - 1) % #glyphs + 1], TextSize = rng:NextInteger(24, 40), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(rng:NextNumber(0, 0.97), 0, -0.1 - rng:NextNumber(0, 0.4), 0), Parent = layer })
		local duration = rng:NextNumber(2, 3.5)
		Anim.Tween(g, { Position = UDim2.new(g.Position.X.Scale, 0, 1.1, 0), Rotation = rng:NextInteger(-90, 90) }, duration, Enum.EasingStyle.Linear)
		task.delay(duration + 0.1, function()
			g:Destroy()
		end)
	end
end

local function sceneStep(archetype: string)
	local scene = personalise(archetype, SCENES[archetype] or SCENES.Content)
	local step = newStep()
	local s = size()
	local frame = Create("CanvasGroup", { Name = "Scene", BackgroundColor3 = Theme.Color.White, Size = UDim2.fromScale(1, 1), Parent = step }, {
		Create.Gradient(ColorSequence.new(scene.Sky[1], scene.Sky[2]), 90),
	})
	local camera = Anim.Scale(frame)
	camera.Scale = 1
	Anim.Tween(camera, { Scale = 1.12 }, 6, Enum.EasingStyle.Sine)
	local heroSize = math.min(s.X, s.Y) * 0.36
	local hero = Create.Label({ Text = scene.Hero, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(heroSize, heroSize), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Parent = frame })
	Anim.Pop(hero, 0.5, 0.8)
	for i, prop in ipairs(scene.Props) do
		local x = ({ 0.2, 0.8, 0.35 })[i]
		local y = ({ 0.68, 0.66, 0.78 })[i]
		local p = Create.Label({ Text = prop, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(heroSize * 0.38, heroSize * 0.38), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x - (if i == 1 then 0.25 else 0), y), Parent = frame })
		Anim.Tween(p, { Position = UDim2.fromScale(x, y) }, 1.6 + i * 0.4, Enum.EasingStyle.Quad)
		Anim.Loop(p, { Rotation = 4 }, 1.2 + i * 0.3)
	end
	local rng = Random.new(#archetype)
	for i = 1, 10 do
		local sparkle = Create.Label({ Name = "Sparkle" .. i, Text = scene.Sparkle, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.2, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.05, 0.55)), Parent = frame })
		Anim.Loop(sparkle, { TextTransparency = 0.9 }, rng:NextNumber(0.6, 1.4))
	end
	if archetype == "Fame" then
		task.spawn(function()
			for _ = 1, 3 do
				pause(0.6)
				flash()
			end
		end)
	end
	local caption = Create.Label({
		Text = scene.Caption,
		FontFace = Theme.Font.Bold,
		TextSize = Theme.TextSize.H3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 0.45,
		Parent = frame,
	})
	Create.Corner(Theme.RadiusSmall).Parent = caption
	Create.Padding(10, 16).Parent = caption
	label(step, { Text = "A GLIMPSE OF ONE POSSIBLE FUTURE…", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.White, Position = UDim2.fromOffset(0, 24), ZIndex = 5 })
	typewrite(caption, 40)
	pause(2.6)
end

-- ===== The real place in Lifeville (camera flyover) =====
local function worldStep(archetype: string)
	local Showcase = require(script.Parent.ShowcaseController)
	if Anim.Reduced or not Showcase.Available(archetype) then
		return
	end
	local step = newStep()
	local backdrop = root:FindFirstChild("Backdrop")
	if backdrop then
		backdrop.Visible = false
	end
	local shot = Showcase.Begin(archetype)
	local strip = Create("Frame", { Name = "WorldShowcase", BackgroundColor3 = Theme.Color.Black, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 130), Parent = step })
	label(strip, { Name = "Place", Text = "📍 " .. shot.Place .. ", " .. World.TownName, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, Position = UDim2.fromOffset(0, 20) })
	label(strip, { Name = "Line", Text = "One day, this could be where your story leads.", TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.H3, Position = UDim2.fromOffset(0, 70) })
	Showcase.Glide(3.8)
	pause(3.8)
	Showcase.End()
	if backdrop then
		backdrop.Visible = true
	end
end
RevealController.WorldStep = worldStep

-- ===== End card =====
local function endCard(title: string, body: string, buttons)
	session.Skip = false
	local step = newStep()
	lightRays(step, Theme.Color.AccentAlt)
	local width = math.min(620, size().X - 40)
	local col = column(step, width)
	label(col, { Text = title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
	label(col, { Text = body, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.H3, LayoutOrder = 2 })
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = col })
	local list = Create.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	list.Wraps = true
	list.Parent = row
	local result = nil
	local first
	for i, b in ipairs(buttons) do
		local button = Components.Button({ Name = b.Name, Text = b.Text, Icon = b.Icon, Style = b.Style or "Primary", Size = UDim2.fromOffset(b.Width or 260, 58), LayoutOrder = i, Parent = row, OnClick = function()
			result = b.Result
		end })
		first = first or button
	end
	Anim.Pop(col, 0.9)
	UIController.Focus(first)
	while result == nil do
		task.wait()
	end
	return result
end

-- ===== Session control =====
local function begin()
	playing = true
	session.Fast = false
	session.Skip = false
	gui.Enabled = true
	Create.Clear(root) -- keeps the UIScale
	Create("Frame", { Name = "Backdrop", BackgroundColor3 = Theme.Color.White, Size = UDim2.fromScale(1, 1), Parent = root }, {
		Create.Gradient(ColorSequence.new(Color3.fromRGB(8, 6, 20), Color3.fromRGB(40, 16, 70)), 120),
	})
	local stage = Create("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	-- Tap anywhere to speed up the current step.
	local tap = Create("TextButton", { Name = "Tap", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Selectable = false, ZIndex = 1, Parent = root })
	tap.Activated:Connect(function()
		session.Fast = true
	end)
	stage.ZIndex = 2
	skipButton()
	layout()
end

local function finish()
	playing = false
	gui.Enabled = false
	Create.Clear(root)
	require(script.Parent.ShowcaseController).End() -- never leave the camera flying
end

function RevealController.IsPlaying(): boolean
	return playing
end

function RevealController.Skip()
	session.Skip = true
end

-- ===== Stage reveal =====
function RevealController.PlayStage(reveal)
	if playing then
		return
	end
	begin()
	AudioController.Play("StageComplete")

	-- 1. Title
	local step = newStep()
	lightRays(step, Theme.Color.Accent)
	local col = column(step, math.min(700, size().X - 40))
	local title = label(col, { Text = "🔮  LIFE REVEAL", FontFace = Theme.Font.Heavy, TextSize = 64, LayoutOrder = 1 })
	Create.Gradient(Theme.Gradient.Title).Parent = title
	label(col, { Text = ("%s is over. You are %d."):format(reveal.StageName, reveal.Age), TextSize = Theme.TextSize.H3, TextColor3 = Theme.Color.TextDim, LayoutOrder = 2 })
	Anim.Pop(title, 0.6, 0.9)
	effectRain(18)
	if reveal.Coins and reveal.Coins > 0 then
		label(col, { Name = "RevealCoins", Text = ("🪙 +%d coins%s"):format(reveal.Coins, if reveal.Boosted then "  (2× Coins)" else ""), FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold, LayoutOrder = 3 })
	end
	pause(1.8)

	-- 2. Who you became
	if not session.Skip and reveal.Became and #reveal.Became > 0 then
		local s2 = newStep()
		local c2 = column(s2, math.min(640, size().X - 40))
		label(c2, { Text = "Who you became", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		for i, line in ipairs(reveal.Became) do
			local chip = Components.Chip({ Text = line, Height = 44, TextSize = Theme.TextSize.Body, LayoutOrder = 1 + i, Parent = c2 })
			Anim.Pop(chip, 0.6, 0.35 + i * 0.08)
		end
		pause(1.8)
	end

	-- 3. Futures
	if not session.Skip then
		barsStep("Your possible futures", if reveal.Twist then reveal.Twist.Before else reveal.Predictions, reveal.Previous, "Based on everything you've done so far")
	end

	-- 4. Headline
	if not session.Skip then
		local s4 = newStep()
		lightRays(s4, Theme.Color.Primary)
		local c4 = column(s4, math.min(720, size().X - 40))
		local h = label(c4, { Text = if reveal.Twist then Futures.Headline(reveal.Twist.Before) else reveal.Headline, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		typewrite(h, 50)
		local warning = if reveal.Twist then select(2, Futures.Headline(reveal.Twist.Before)) else reveal.Warning
		if warning then
			label(c4, { Text = "⚠️ " .. warning, TextColor3 = Theme.Color.Warning, TextSize = Theme.TextSize.H3, LayoutOrder = 2 })
		end
		pause(2)
	end

	-- 5. Twist
	if not session.Skip and reveal.Twist then
		local twist = reveal.Twist
		flash()
		AudioController.Play("Negative")
		local s5 = newStep()
		local c5 = column(s5, math.min(680, size().X - 40))
		local but = label(c5, { Text = "⚡ BUT THEN…", FontFace = Theme.Font.Heavy, TextSize = 56, TextColor3 = Theme.Color.Gold, LayoutOrder = 1 })
		Anim.Shake(but)
		label(c5, { Text = twist.Icon, TextSize = 72, LayoutOrder = 2 })
		label(c5, { Text = twist.Title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 3 })
		local story = label(c5, { Text = twist.Story, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.H3, LayoutOrder = 4 })
		typewrite(story, 45)
		local changes = {}
		for _, text in ipairs(twist.LifeChanges or {}) do
			table.insert(changes, text)
		end
		for stat, delta in pairs(twist.Applied or {}) do
			local info = StatDefinitions.Info[stat]
			if info and math.abs(delta) >= 0.5 then
				table.insert(changes, info.Icon .. " " .. Format.Signed(delta))
			end
		end
		if twist.MoneyDelta and twist.MoneyDelta ~= 0 then
			table.insert(changes, "💰 " .. (if twist.MoneyDelta > 0 then "+" else "") .. Format.Money(twist.MoneyDelta))
		end
		if #changes > 0 then
			label(c5, { Text = table.concat(changes, "   "), FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Gold, LayoutOrder = 5 })
		end
		pause(2.6)
		if not session.Skip then
			barsStep("The odds have changed", reveal.Predictions, twist.Before, "One moment can change everything")
		end
	end

	-- 6. Cinematic preview, then the real place in Lifeville
	if not session.Skip then
		sceneStep(reveal.Archetype)
	end
	if not session.Skip then
		worldStep(reveal.Archetype)
	end

	-- 7. End card
	endCard(
		if reveal.Twist then reveal.Headline else "The future is never decided.",
		"Every choice can still change it." .. (if reveal.NextStageName then ("\n%s begins now."):format(reveal.NextStageName) else ""),
		{ { Name = "RevealContinue", Text = if reveal.NextStageName then "Continue to " .. reveal.NextStageName else "Continue", Icon = "▶", Result = "Continue", Width = 340 } }
	)
	finish()
end

-- ===== Final reveal =====
local function section(parent, title: string, lines, order: number)
	if not lines or #lines == 0 then
		return
	end
	label(parent, { Text = title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Primary, LayoutOrder = order })
	for i, line in ipairs(lines) do
		local l = label(parent, { Text = line, TextSize = Theme.TextSize.Body, LayoutOrder = order + i })
		Anim.Pop(l, 0.8, 0.25 + i * 0.05)
	end
end

function RevealController.PlayFinal(entry, options)
	options = options or {}
	if playing then
		return "Menu"
	end
	begin()
	local width = math.min(720, size().X - 40)

	-- 1. Title
	local step = newStep()
	lightRays(step, Theme.Color.Gold)
	local col = column(step, width)
	label(col, { Text = "THE LIFE OF", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, TextColor3 = Theme.Color.TextDim, LayoutOrder = 1 })
	local name = label(col, { Text = string.upper(entry.Name), FontFace = Theme.Font.Heavy, TextSize = 72, LayoutOrder = 2 })
	Create.Gradient(Theme.Gradient.Title).Parent = name
	label(col, { Text = ("Age 5 → %d · %d decisions"):format(entry.Age, entry.DecisionCount or 0), TextColor3 = Theme.Color.TextDim, LayoutOrder = 3 })
	Anim.Pop(name, 0.6, 0.9)
	pause(2)

	-- 2. Key decisions montage
	if not session.Skip and #entry.KeyDecisions > 0 then
		local s2 = newStep()
		local c2 = column(s2, width)
		label(c2, { Text = "The choices that shaped you", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		for i, d in ipairs(entry.KeyDecisions) do
			if session.Skip then
				break
			end
			local stage = LifeStages.ForAge(d.Age)
			local card = Components.Panel({ Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 12, LayoutOrder = 1 + i, Parent = c2, Color = Theme.Color.SurfaceHigh })
			Create.Label({ Text = ("<font color=\"%s\">AGE %d · %s</font>   %s"):format(Theme.Hex.Gold, d.Age, string.upper(stage.DisplayName), d.Title), RichText = true, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
			Create.Label({ Text = "“" .. d.Choice .. "”", FontFace = Theme.Font.Bold, Position = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
			Anim.Pop(card, 0.7, 0.35)
			pause(0.8)
		end
		pause(1.2)
	end

	-- 3. Family & relationships
	if not session.Skip then
		local s3 = newStep()
		local c3 = column(s3, width)
		label(c3, { Text = "The people in your life", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		local lines = {}
		if entry.Partner then
			table.insert(lines, (if entry.Partner.Married then "💍 Married to " else "❤️ Together with ") .. entry.Partner.Name)
		else
			table.insert(lines, "🕊️ Single at the end")
		end
		if #entry.Children > 0 then
			table.insert(lines, "👶 Children: " .. table.concat(entry.Children, ", "))
		end
		if entry.BestFriend then
			table.insert(lines, "🫶 Best friend: " .. entry.BestFriend)
		end
		for i, line in ipairs(lines) do
			local l = label(c3, { Text = line, TextSize = Theme.TextSize.H3, LayoutOrder = 1 + i })
			Anim.Pop(l, 0.7, 0.3 + i * 0.1)
		end
		pause(2)
	end

	-- 4. Wealth & career
	if not session.Skip then
		local s4 = newStep()
		local c4 = column(s4, width)
		label(c4, { Text = "What you built", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		local worth = label(c4, { Text = "$0", FontFace = Theme.Font.Heavy, TextSize = 64, TextColor3 = Theme.Color.Gold, LayoutOrder = 2 })
		label(c4, { Text = "net worth", TextColor3 = Theme.Color.TextDim, LayoutOrder = 3 })
		label(c4, { Text = "💼 " .. entry.Career .. "   ·   🎓 " .. entry.Education, TextSize = Theme.TextSize.H3, LayoutOrder = 4 })
		local steps = 40
		for i = 1, steps do
			if session.Fast or session.Skip then
				break
			end
			worth.Text = Format.Money(entry.NetWorth * (i / steps) ^ 2)
			task.wait(1 / 30)
		end
		worth.Text = Format.Money(entry.NetWorth)
		pause(1.6)
	end

	-- 5. Achievements, moments, mistakes
	if not session.Skip then
		local s5 = newStep()
		local scroll = Create("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Selectable = false, Parent = s5 })
		Create.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = scroll
		Create.Padding(80, 20, 40, 20).Parent = scroll
		local c5 = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
		Create.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = c5
		section(c5, "🏆 ACHIEVEMENTS", entry.Achievements, 10)
		section(c5, "✨ GREATEST MOMENTS", entry.Moments, 40)
		section(c5, "💭 BIGGEST REGRETS", entry.Mistakes, 70)
		if #entry.Achievements + #entry.Moments + #entry.Mistakes == 0 then
			label(c5, { Text = "A simple life, lived your way.", TextSize = Theme.TextSize.H3, LayoutOrder = 1 })
		end
		pause(3.2)
	end

	-- 6. Predictions vs reality
	if not session.Skip and #entry.Journey > 0 then
		local s6 = newStep()
		local c6 = column(s6, width)
		label(c6, { Text = "What we predicted… and what came true", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, LayoutOrder = 1 })
		local came = {}
		for _, id in ipairs(entry.CameTrue) do
			came[id] = true
		end
		local first = entry.Journey[math.min(2, #entry.Journey)]
		for i, top in ipairs(first.Top) do
			local info = Futures.Info[top.Id]
			label(c6, {
				Text = ("At %d: %s %s %d%% → %s"):format(first.Age, info.Icon, info.Title, top.Pct, if came[top.Id] then "✅ it came true" else "❌ it didn't"),
				RichText = false,
				TextSize = Theme.TextSize.Body,
				LayoutOrder = 1 + i,
			})
		end
		local trueList = {}
		for _, id in ipairs(entry.CameTrue) do
			if Futures.Info[id].Positive then
				table.insert(trueList, Futures.Info[id].Icon .. " " .. Futures.Info[id].Title)
			end
		end
		label(c6, { Text = if #trueList > 0 then "Your life became: " .. table.concat(trueList, " · ") else "Your life took its own unpredictable path.", FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Gold, LayoutOrder = 10 })
		pause(3)
	end

	-- 7. Ending title
	if not session.Skip then
		local s7 = newStep()
		local c7 = column(s7, width)
		label(c7, { Text = "Your life will be remembered as…", TextSize = Theme.TextSize.H3, TextColor3 = Theme.Color.TextDim, LayoutOrder = 1 })
		pause(1.4)
	end
	local s8 = newStep()
	lightRays(s8, Theme.Color.Gold)
	flash(Theme.Color.Gold)
	AudioController.Play("StageComplete")
	local c8 = column(s8, width)
	local icon = label(c8, { Text = entry.Ending.Icon, TextSize = 96, LayoutOrder = 1 })
	local endingTitle = label(c8, { Text = string.upper(entry.Ending.Title), FontFace = Theme.Font.Heavy, TextSize = 60, LayoutOrder = 2 })
	Create.Gradient(Theme.Gradient.Title).Parent = endingTitle
	label(c8, { Text = entry.Ending.Line, TextSize = Theme.TextSize.H3, TextColor3 = Theme.Color.TextDim, LayoutOrder = 3 })
	if not options.Replay then
		label(c8, { Name = "RevealCoins", Text = ("🪙 +%d coins%s"):format(entry.Coins or 0, if entry.Boosted then "  (2× Coins)" else ""), FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold, LayoutOrder = 4 })
	end
	Anim.Pop(icon, 0.3, 1)
	Anim.Pop(endingTitle, 0.6, 0.9)
	effectRain(26)
	pause(2.5)

	local result = endCard("What if you had chosen differently?", "Every life is a different story. Would yours have turned out better?", {
		{ Name = "RevealAgain", Text = "Live Again", Icon = "✨", Result = "Again", Width = 230 },
		{ Name = "RevealHistory", Text = "Life History", Icon = "📜", Style = "Accent", Result = "History", Width = 230 },
		{ Name = "RevealMenu", Text = if options.Replay then "Close" else "Main Menu", Style = "Secondary", Result = "Menu", Width = 200 },
	})
	finish()
	return result
end

-- ===== Group Life Reveal (a Life Circle watches together) =====
function RevealController.PlayGroup(payload)
	-- If another reveal is showing (e.g. your own stage reveal), wait for it.
	local waited = 0
	while playing and waited < 90 do
		waited += task.wait(0.25)
	end
	if playing then
		return
	end
	begin()
	local width = math.min(700, size().X - 40)

	local step = newStep()
	lightRays(step, Theme.Color.AccentAlt)
	local col = column(step, width)
	local title = label(col, { Text = "👥  GROUP LIFE REVEAL", FontFace = Theme.Font.Heavy, TextSize = 56, LayoutOrder = 1 })
	Create.Gradient(Theme.Gradient.Title).Parent = title
	label(col, { Text = ("Started by %s · %d lives, %d possible futures"):format(payload.StartedBy, #payload.Cards, #payload.Cards), TextColor3 = Theme.Color.TextDim, LayoutOrder = 2 })
	Anim.Pop(title, 0.6, 0.9)
	pause(1.8)

	for _, entry in ipairs(payload.Cards) do
		if session.Skip then
			break
		end
		local s2 = newStep()
		local c2 = column(s2, width)
		label(c2, { Text = Avatar.Line(entry.DisplayName, entry.Style) .. (if entry.IsYou then " (you)" else ""), RichText = true, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		if entry.Hidden or not entry.Card then
			label(c2, { Text = if entry.NoLife then "Between lives right now." else "🔒 Keeps their future private.", TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.H3, LayoutOrder = 2 })
			pause(1.2)
		else
			local card = entry.Card
			label(c2, { Text = ("%s · age %d · %s · %s"):format(card.LifeName, card.Age, card.StageName, card.Career), TextColor3 = Theme.Color.TextDim, LayoutOrder = 2 })
			local starters = {}
			local positives = Futures.Sorted(card.Predictions)
			for i = 1, math.min(3, #positives) do
				table.insert(starters, futureBar(c2, positives[i], nil, 10 + i, width))
			end
			for _, start in ipairs(starters) do
				start(0.6)
				pause(0.25)
			end
			local headline = label(c2, { Text = card.Headline, FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Gold, LayoutOrder = 20 })
			typewrite(headline, 60)
			pause(1.6)
		end
	end

	if not session.Skip and #payload.Superlatives > 0 then
		local s3 = newStep()
		lightRays(s3, Theme.Color.Gold)
		local c3 = column(s3, width)
		label(c3, { Text = "MOST LIKELY TO…", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H1, LayoutOrder = 1 })
		for i = 1, math.min(6, #payload.Superlatives) do
			local s = payload.Superlatives[i]
			local info = Futures.Info[s.Id]
			local line = label(c3, { Text = ("%s %s: <b>%s</b> (%d%%)"):format(info.Icon, info.Title, s.DisplayName, s.Pct), RichText = true, TextSize = Theme.TextSize.H3, LayoutOrder = 1 + i })
			Anim.Pop(line, 0.7, 0.3)
			pause(0.5)
		end
		pause(2)
	end

	endCard("Same start. Different futures.", "Keep choosing. Every one of these futures can still change.", {
		{ Name = "RevealGroupClose", Text = "Close", Icon = "👍", Result = "Close", Width = 240 },
	})
	finish()
end

function RevealController.Init()
	gui = Create("ScreenGui", {
		Name = "CYL_Reveal",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 60,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	root = Create("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
	uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	UIController.LayoutChanged:Connect(layout)
end

function RevealController.Start() end

return RevealController
