--[[
	SettingsController  (StarterPlayerScripts.Client.Controllers.SettingsController)
	Holds the player's settings + privacy choices on the client, applies them
	instantly (volume, UI scale, graphics, animations) and saves them to the
	server a moment after the last change (the server validates every value).

	SettingsController.Get(key)            SettingsController.Set(key, value)
	SettingsController.GetPrivacy(key)     SettingsController.SetPrivacy(key, value)
	SettingsController.Changed:Connect(fn(key, value))
	CameraSensitivity is read by the game's own camera systems (Life Reveal
	cinematics, house viewer). Roblox doesn't let games change the default
	camera's mouse sensitivity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local DataTemplate = require(Shared.Data.DataTemplate)
local Anim = require(script.Parent.Parent:WaitForChild("UILib").Anim)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local AudioController = require(script.Parent.AudioController)
local GraphicsController = require(script.Parent.GraphicsController)

local SettingsController = {}
SettingsController.Priority = 5
SettingsController.Changed = Signal.new()
SettingsController.SaveStateChanged = Signal.new() -- ("Saving" | "Saved" | "Failed")

local settings = table.clone(DataTemplate.DefaultSettings)
local privacy = table.clone(DataTemplate.DefaultPrivacy)
local pendingSettings, pendingPrivacy = {}, {}
local saveScheduled = false
local loadedFromServer = false
local scaleToken = 0

local function apply(key: string)
	if key == "MusicVolume" or key == "SfxVolume" then
		AudioController.SetVolumes(settings.MusicVolume, settings.SfxVolume)
	elseif key == "UIScale" then
		-- Applied after the slider pauses, so the screen doesn't re-layout mid-drag.
		scaleToken += 1
		local token = scaleToken
		task.delay(0.45, function()
			if token == scaleToken then
				UIController.SetUserScale(settings.UIScale)
			end
		end)
	elseif key == "Graphics" then
		GraphicsController.Apply(settings.Graphics)
	elseif key == "ReduceAnimations" then
		Anim.Reduced = settings.ReduceAnimations
	end
end

local function applyAll()
	for key in pairs(settings) do
		apply(key)
	end
end

local function scheduleSave()
	if saveScheduled then
		return
	end
	saveScheduled = true
	task.delay(0.8, function()
		saveScheduled = false
		local s, p = pendingSettings, pendingPrivacy
		pendingSettings, pendingPrivacy = {}, {}
		SettingsController.SaveStateChanged:Fire("Saving")
		local ok = true
		if next(s) then
			ok = (Net.Invoke("UpdateSettings", s)) == true and ok
		end
		if next(p) then
			ok = (Net.Invoke("UpdatePrivacy", p)) == true and ok
		end
		if not ok then
			-- Put the values back so the next change retries them.
			for key, value in pairs(s) do
				if pendingSettings[key] == nil then
					pendingSettings[key] = value
				end
			end
			for key, value in pairs(p) do
				if pendingPrivacy[key] == nil then
					pendingPrivacy[key] = value
				end
			end
		end
		SettingsController.SaveStateChanged:Fire(if ok then "Saved" else "Failed")
	end)
end

function SettingsController.Get(key: string)
	return settings[key]
end

function SettingsController.Set(key: string, value: any)
	if settings[key] == nil or settings[key] == value then
		return
	end
	settings[key] = value
	pendingSettings[key] = value
	apply(key)
	SettingsController.Changed:Fire(key, value)
	scheduleSave()
end

function SettingsController.GetPrivacy(key: string)
	return privacy[key]
end

function SettingsController.SetPrivacy(key: string, value: string)
	if privacy[key] == nil or privacy[key] == value then
		return
	end
	privacy[key] = value
	pendingPrivacy[key] = value
	SettingsController.Changed:Fire("Privacy." .. key, value)
	scheduleSave()
end

function SettingsController.Init() end

function SettingsController.Start()
	applyAll()
	DataController.Changed:Connect(function(data)
		-- Adopt saved values once; afterwards the client copy is the source of
		-- truth for display (the server already has whatever we sent).
		if loadedFromServer then
			return
		end
		loadedFromServer = true
		for key, value in pairs(data.Settings or {}) do
			if settings[key] ~= nil then
				settings[key] = value
			end
		end
		for key, value in pairs(data.Privacy or {}) do
			if privacy[key] ~= nil then
				privacy[key] = value
			end
		end
		applyAll()
		SettingsController.Changed:Fire("*", nil)
	end)
end

return SettingsController
