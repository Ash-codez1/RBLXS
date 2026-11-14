--[[
	AudioController  (StarterPlayerScripts.Client.Controllers.AudioController)
	Creates Music and SFX SoundGroups (driven by the volume settings), plays UI
	sound effects and switches background music per screen.
	Asset ids live in Shared.Data.SoundIds; empty ids are skipped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundIds = require(ReplicatedStorage:WaitForChild("Shared").Data.SoundIds)
local Components = require(script.Parent.Parent:WaitForChild("UILib").Components)

local AudioController = {}
AudioController.Priority = 2

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local sfxCache: { [string]: Sound } = {}
local currentMusic: Sound? = nil
local currentMusicName: string? = nil

local MUSIC_FOR_SCREEN = {
	Menu = "MenuMusic",
	SlotSelect = "MenuMusic",
	NameEntry = "MenuMusic",
	Settings = nil, -- keep whatever is playing
	Credits = "MenuMusic",
	Game = "GameMusic",
}

local function makeSound(name: string, group: SoundGroup, looped: boolean): Sound?
	local id = SoundIds[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = looped
	sound.SoundGroup = group
	sound.Parent = group
	return sound
end

function AudioController.Play(name: string)
	local sound = sfxCache[name]
	if sound == nil then
		sound = makeSound(name, sfxGroup, false)
		sfxCache[name] = sound or (false :: any)
	end
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

function AudioController.PlayMusic(name: string?)
	if name == currentMusicName then
		return
	end
	currentMusicName = name
	if currentMusic then
		currentMusic:Stop()
		currentMusic:Destroy()
		currentMusic = nil
	end
	if name then
		currentMusic = makeSound(name, musicGroup, true)
		if currentMusic then
			currentMusic:Play()
		end
	end
end

function AudioController.SetVolumes(music: number, sfx: number)
	musicGroup.Volume = math.clamp(music, 0, 1)
	sfxGroup.Volume = math.clamp(sfx, 0, 1)
end

function AudioController.Init()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "CYL_Music"
	musicGroup.Parent = SoundService
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "CYL_SFX"
	sfxGroup.Parent = SoundService
	Components.OnClickSound = function()
		AudioController.Play("Click")
	end
end

function AudioController.Start()
	local UIController = require(script.Parent.UIController)
	UIController.ScreenChanged:Connect(function(screen)
		local track = MUSIC_FOR_SCREEN[screen]
		if track then
			AudioController.PlayMusic(track)
		end
	end)
end

return AudioController
