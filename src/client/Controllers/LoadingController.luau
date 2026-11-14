--[[
	LoadingController  (StarterPlayerScripts.Client.Controllers.LoadingController)
	Full-screen loading screen shown from the moment the client starts until
	the player's data has arrived, then hands over to the main menu.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)

local LoadingController = {}
LoadingController.Priority = 4
LoadingController.Done = false

local gui: ScreenGui
local group: CanvasGroup
local status: TextLabel

function LoadingController.Init()
	gui = Create("ScreenGui", {
		Name = "CYL_Loading",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 100,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	group = Create("CanvasGroup", {
		Name = "Loading",
		BackgroundColor3 = Theme.Color.White,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { Create.Gradient(Theme.Gradient.Backdrop, 120) })

	local center = Create("Frame", {
		Name = "Center",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = group,
	}, { Create.List(Enum.FillDirection.Vertical, 16, Enum.HorizontalAlignment.Center) })
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, math.huge) }).Parent = center

	local title = Create.Label({
		Name = "Title",
		Text = Config.GameName,
		FontFace = Theme.Font.Heavy,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 80),
		LayoutOrder = 1,
		Parent = center,
	})
	Create("UITextSizeConstraint", { MaxTextSize = 72 }).Parent = title
	Create.Gradient(Theme.Gradient.Title).Parent = title

	-- Spinner: a ring (UIStroke) with a gradient that rotates.
	local ring = Create("Frame", {
		Name = "Spinner",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(54, 54),
		LayoutOrder = 2,
		Parent = center,
	}, { Create.Corner(Theme.RadiusPill) })
	local stroke = Create.Stroke(Theme.Color.White, 5, 0)
	stroke.Parent = ring
	local spinGradient = Create("UIGradient", {
		Color = Theme.Gradient.Primary,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Parent = stroke,
	})
	task.spawn(function()
		while gui.Parent and not LoadingController.Done do
			spinGradient.Rotation = (spinGradient.Rotation + 6) % 360
			task.wait(1 / 30)
		end
	end)

	status = Create.Label({
		Name = "Status",
		Text = "Loading your life…",
		FontFace = Theme.Font.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		Parent = center,
	})
	local tip = Create.Label({
		Name = "Tip",
		Text = "💡 " .. Config.LoadingTips[math.random(1, #Config.LoadingTips)],
		TextColor3 = Theme.Color.TextDim,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = center,
	})
	task.spawn(function()
		local i = 1
		while gui.Parent and not LoadingController.Done do
			task.wait(4)
			i = i % #Config.LoadingTips + 1
			tip.Text = "💡 " .. Config.LoadingTips[i]
		end
	end)
end

function LoadingController.Start()
	task.delay(20, function()
		if not LoadingController.Done then
			status.Text = "Still loading… if this takes much longer, try rejoining."
		end
	end)
	DataController.WaitForData()
	LoadingController.Done = true
	status.Text = "Ready!"
	UIController.Show("Menu")
	task.wait(0.3)
	Anim.Fade(group, false, 0.5)
	task.wait(0.6)
	gui:Destroy()
end

return LoadingController
