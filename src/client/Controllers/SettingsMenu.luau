--[[
	SettingsMenu  (StarterPlayerScripts.Client.Controllers.SettingsMenu)
	The Settings screen. Every control applies immediately and saves
	automatically (see SettingsController). Works with mouse, touch and gamepad.
]]

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local UIController = require(script.Parent.UIController)
local SettingsController = require(script.Parent.SettingsController)

local SettingsMenu = {}
SettingsMenu.Priority = 50

local frame: CanvasGroup
local saveLabel: TextLabel? = nil
local firstControl: GuiObject? = nil

local SHARE_OPTIONS = { "Everyone", "Friends", "Nobody" }
local SHARE_LABELS = { "Everyone", "Friends only", "Nobody" }

local function section(parent, title: string, order: number)
	Create.Label({
		Text = title,
		FontFace = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Primary,
		Size = UDim2.new(1, 0, 0, 30),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function render()
	Create.Clear(frame, true)
	Layout.Header(frame, "Settings", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(frame)
	local width = math.min(720, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	section(column, "🔊  AUDIO", nextOrder())
	local music = Components.Slider({ Label = "Music volume", Min = 0, Max = 1, Step = 0.05, Value = SettingsController.Get("MusicVolume"), LayoutOrder = nextOrder(), Parent = column, OnChanged = function(v)
		SettingsController.Set("MusicVolume", v)
	end })
	firstControl = music.Instance:FindFirstChild("Controls") and music.Instance.Controls:FindFirstChildWhichIsA("GuiButton")
	Components.Slider({ Label = "Sound effects volume", Min = 0, Max = 1, Step = 0.05, Value = SettingsController.Get("SfxVolume"), LayoutOrder = nextOrder(), Parent = column, OnChanged = function(v)
		SettingsController.Set("SfxVolume", v)
	end })

	section(column, "🖥️  DISPLAY", nextOrder())
	Components.Selector({ Label = "Graphics", Options = { "Auto", "Low", "High" }, Labels = { "Auto", "Low (faster)", "High" }, Value = SettingsController.Get("Graphics"), LayoutOrder = nextOrder(), Parent = column, OnChanged = function(v)
		SettingsController.Set("Graphics", v)
	end })
	Components.Slider({
		Label = "UI scale",
		Min = 0.75,
		Max = 1.25,
		Step = 0.05,
		Value = SettingsController.Get("UIScale"),
		LayoutOrder = nextOrder(),
		Parent = column,
		OnChanged = function(v)
			SettingsController.Set("UIScale", v)
		end,
	})
	Components.Toggle({ Label = "Reduce animations", Value = SettingsController.Get("ReduceAnimations"), LayoutOrder = nextOrder(), Parent = column, OnChanged = function(v)
		SettingsController.Set("ReduceAnimations", v)
	end })

	section(column, "🎮  CONTROLS", nextOrder())
	Components.Slider({
		Label = "Camera sensitivity",
		Min = 0.2,
		Max = 2,
		Step = 0.1,
		Value = SettingsController.Get("CameraSensitivity"),
		Format = function(v)
			return ("%.1fx"):format(v)
		end,
		LayoutOrder = nextOrder(),
		Parent = column,
		OnChanged = function(v)
			SettingsController.Set("CameraSensitivity", v)
		end,
	})

	section(column, "🔔  NOTIFICATIONS", nextOrder())
	Components.Toggle({ Label = "Show notifications", Value = SettingsController.Get("Notifications"), LayoutOrder = nextOrder(), Parent = column, OnChanged = function(v)
		SettingsController.Set("Notifications", v)
	end })

	section(column, "🔒  PRIVACY: WHAT OTHERS CAN SEE", nextOrder())
	for _, entry in ipairs({
		{ Key = "ShareStats", Label = "My life stats" },
		{ Key = "ShareReveals", Label = "My Life Reveals" },
		{ Key = "ShareHistory", Label = "My past lives" },
	}) do
		Components.Selector({ Label = entry.Label, Options = SHARE_OPTIONS, Labels = SHARE_LABELS, Value = SettingsController.GetPrivacy(entry.Key), LayoutOrder = nextOrder(), Parent = column, OnChanged = function(v)
			SettingsController.SetPrivacy(entry.Key, v)
		end })
	end

	saveLabel = Create.Label({
		Text = "✓ Changes save automatically",
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.TextFaint,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = nextOrder(),
		Parent = column,
	})
end

function SettingsMenu.Init()
	frame = UIController.NewScreen("Settings", {
		Back = true,
		OnOpen = render,
		DefaultFocus = function()
			return firstControl
		end,
	})
end

function SettingsMenu.Start()
	SettingsController.SaveStateChanged:Connect(function(state)
		if not saveLabel or not saveLabel.Parent then
			return
		end
		if state == "Saving" then
			saveLabel.Text = "Saving…"
		elseif state == "Saved" then
			saveLabel.Text = "✓ Saved"
		else
			saveLabel.Text = "⚠️ Couldn't save. It will retry with your next change."
		end
	end)
	UIController.LayoutChanged:Connect(function()
		-- UI scale changes re-layout the screen; rebuild so sizes fit.
		if UIController.Current() == "Settings" then
			render()
		end
	end)
end

return SettingsMenu
