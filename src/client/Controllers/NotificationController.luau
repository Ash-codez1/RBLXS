--[[
	NotificationController  (StarterPlayerScripts.Client.Controllers.NotificationController)
	Toast notifications (top-right, or top-centre on narrow screens).
	  NotificationController.Notify({ Title, Text, Kind = "Info"|"Success"|"Warning"|"Error"|"Important", Duration })
	Server pushes arrive on the "Notify" remote. When the player turns
	Notifications off, only "Important" and "Error" toasts are shown.
	🔔 Inbox: every notification this visit is kept (latest 40, even ones
	not shown as toasts) and can be read again from the main menu;
	NotificationController.Unread() counts the new ones.
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

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local NotificationController = {}
NotificationController.Priority = 20
NotificationController.Changed = Signal.new() -- inbox changed
NotificationController.MaxHistory = 40

local history: { { Title: string, Text: string, Kind: string, Time: number } } = {}
local unread = 0

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

function NotificationController.History()
	return history
end

function NotificationController.Unread(): number
	return unread
end

function NotificationController.MarkRead()
	unread = 0
	NotificationController.Changed:Fire()
end

function NotificationController.Notify(options: { [string]: any })
	local kind = KINDS[options.Kind or "Info"] or KINDS.Info
	table.insert(history, 1, { Title = tostring(options.Title or ""), Text = tostring(options.Text or ""), Kind = options.Kind or "Info", Time = os.time() })
	if #history > NotificationController.MaxHistory then
		table.remove(history)
	end
	unread += 1
	NotificationController.Changed:Fire()
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

local function ago(t: number): string
	local seconds = math.max(0, os.time() - t)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return ("%d min ago"):format(math.floor(seconds / 60))
	end
	return ("%d h ago"):format(math.floor(seconds / 3600))
end

-- 🔔 The inbox panel (main menu → Notifications).
function NotificationController.OpenInbox()
	local handle = UIController.OpenPanel({ Name = "InboxModal", Title = "🔔  Notifications", Width = 640, Height = 620 })
	handle.Subtitle.Text = if #history == 0 then "Nothing yet" else ("%d this visit"):format(#history)
	for i, item in ipairs(history) do
		local kind = KINDS[item.Kind] or KINDS.Info
		local row = Create("Frame", { Name = "Item" .. i, BackgroundColor3 = Theme.Color.SurfaceHigh, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = handle.Scroll }, { Create.Corner(Theme.RadiusSmall), Create.Stroke(kind.Color, 1.5, if i <= unread then 0 else 0.6), Create.Padding(10, 14) })
		Create.List(Enum.FillDirection.Vertical, 2).Parent = row
		Create.Label({ Text = kind.Icon .. "  " .. item.Title, FontFace = Theme.Font.Bold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = row })
		if item.Text ~= "" then
			Create.Label({ Text = item.Text, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = row })
		end
		Create.Label({ Text = ago(item.Time), TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = row })
	end
	if #history == 0 then
		Create.Label({ Text = "Achievements, challenges, daily rewards, invites and trades will show up here.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = handle.Scroll })
	end
	NotificationController.MarkRead()
	return handle
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
