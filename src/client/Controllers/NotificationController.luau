--[[
	NotificationController  (StarterPlayerScripts.Client.Controllers.NotificationController)
	Toast notifications (top-right, or top-centre on narrow screens).
	  NotificationController.Notify({ Title, Text, Kind = "Info"|"Success"|"Warning"|"Error"|"Important", Duration })
	Server pushes arrive on the "Notify" remote. When the player turns
	Notifications off, only "Important" and "Error" toasts are shown.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)

local UIController = require(script.Parent.UIController)
local SettingsController = require(script.Parent.SettingsController)
local AudioController = require(script.Parent.AudioController)

local NotificationController = {}
NotificationController.Priority = 20

local KINDS = {
	Info = { Icon = "ℹ️", Color = Theme.Color.Accent },
	Success = { Icon = "✅", Color = Theme.Color.Positive },
	Warning = { Icon = "⚠️", Color = Theme.Color.Warning },
	Error = { Icon = "⛔", Color = Theme.Color.Negative },
	Important = { Icon = "⭐", Color = Theme.Color.Gold },
}

local stack: Frame
local order = 0

local function layout()
	local narrow = UIController.IsNarrow()
	stack.AnchorPoint = if narrow then Vector2.new(0.5, 0) else Vector2.new(1, 0)
	stack.Position = if narrow then UDim2.new(0.5, 0, 0, 12) else UDim2.new(1, -16, 0, 84)
	stack.Size = UDim2.fromOffset(math.min(360, UIController.GetVirtualSize().X - 24), 0)
end

function NotificationController.Notify(options: { [string]: any })
	local kind = KINDS[options.Kind or "Info"] or KINDS.Info
	local critical = options.Kind == "Important" or options.Kind == "Error"
	if not critical and not SettingsController.Get("Notifications") then
		return
	end
	order += 1
	local toast = Create("CanvasGroup", {
		Name = "Toast",
		BackgroundColor3 = Theme.Color.Surface,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = stack,
	}, { Create.Corner(Theme.RadiusSmall), Create.Stroke(kind.Color, 2, 0.2), Create.Padding(12, 14) })
	Create.List(Enum.FillDirection.Vertical, 2).Parent = toast
	Create.Label({
		Text = kind.Icon .. "  " .. tostring(options.Title or ""),
		FontFace = Theme.Font.Bold,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = toast,
	})
	if options.Text and options.Text ~= "" then
		Create.Label({
			Text = tostring(options.Text),
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Color.TextDim,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = toast,
		})
	end
	AudioController.Play("Notify")
	Anim.Fade(toast, true, 0.2)
	task.delay(options.Duration or 4, function()
		Anim.Fade(toast, false, 0.3)
		task.wait(0.35)
		toast:Destroy()
	end)
	-- Keep at most 4 on screen.
	local toasts = {}
	for _, child in ipairs(stack:GetChildren()) do
		if child:IsA("CanvasGroup") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		toasts[1]:Destroy()
	end
end

function NotificationController.Init()
	stack = Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 40,
		Parent = UIController.GetOverlay(),
	})
	Create.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right).Parent = stack
	layout()
	UIController.LayoutChanged:Connect(layout)
end

function NotificationController.Start()
	Net.OnEvent("Notify", function(payload)
		if type(payload) == "table" then
			NotificationController.Notify(payload)
		end
	end)
end

return NotificationController
