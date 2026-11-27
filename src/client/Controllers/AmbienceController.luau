--[[
	AmbienceController  (StarterPlayerScripts.Client.Controllers.AmbienceController)
	Background sound while exploring: each district has an ambient loop
	(World.Districts[].Ambient: birdsong in the park, chatter downtown, waves
	at the harbour...), switching to AmbientNight after dark, crossfading as
	you walk between districts. The busker in the Plaza plays music you hear
	when you're near him.
	All sounds come from Shared/Data/SoundIds and follow the Sound effects
	volume. Empty ids are silent, so the game works before audio is added.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Data.World)
local SoundIds = require(Shared.Data.SoundIds)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Anim = require(UILib.Anim)

local ExploreController = require(script.Parent.ExploreController)
local DayNightController = require(script.Parent.DayNightController)

local AmbienceController = {}
AmbienceController.Priority = 60
AmbienceController.Volume = 0.45

local currentKey: string? = nil
local currentSound: Sound? = nil

local function sfxGroup(): SoundGroup?
	return SoundService:FindFirstChild("CYL_SFX") :: SoundGroup?
end

function AmbienceController.Current(): string?
	return currentKey
end

-- Which ambient loop fits where you are and the time of day.
function AmbienceController.KeyFor(districtId: string?, night: boolean): string
	if night then
		return "AmbientNight"
	end
	local district = districtId and World.ById[districtId]
	return if district then district.Ambient else "AmbientCity"
end

function AmbienceController.Set(key: string?)
	if key == currentKey then
		return
	end
	currentKey = key
	local old = currentSound
	currentSound = nil
	if old then
		Anim.Tween(old, { Volume = 0 }, 1.2)
		task.delay(1.3, function()
			old:Destroy()
		end)
	end
	local id = key and SoundIds[key]
	if type(id) == "string" and id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = sfxGroup()
		sound.Parent = SoundService
		sound:Play()
		Anim.Tween(sound, { Volume = AmbienceController.Volume }, 1.5)
		currentSound = sound
	end
end

local function busker(on: boolean)
	local world = workspace:FindFirstChild("World")
	local npcs = world and world:FindFirstChild("NPCs")
	local rig = npcs and npcs:FindFirstChild("NPC_Busker")
	local head = rig and rig:FindFirstChild("Head")
	if not head then
		return
	end
	local music = head:FindFirstChild("CYL_BuskerMusic") :: Sound?
	if not music and on and SoundIds.BuskerMusic ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "CYL_BuskerMusic"
		sound.SoundId = SoundIds.BuskerMusic
		sound.Looped = true
		sound.Volume = 0.8
		sound.RollOffMaxDistance = 70
		sound.SoundGroup = sfxGroup()
		sound.Parent = head
		music = sound
	end
	if music then
		if on then
			music:Play()
		else
			music:Stop()
		end
	end
end

function AmbienceController.Step()
	if ExploreController.IsExploring() then
		AmbienceController.Set(AmbienceController.KeyFor(ExploreController.CurrentDistrict(), DayNightController.IsNight()))
	else
		AmbienceController.Set(nil)
	end
end

function AmbienceController.Init() end

function AmbienceController.Start()
	ExploreController.Changed:Connect(function(on)
		busker(on)
		AmbienceController.Step()
	end)
	ExploreController.DistrictChanged:Connect(AmbienceController.Step)
	while true do
		task.wait(2)
		AmbienceController.Step()
	end
end

return AmbienceController
