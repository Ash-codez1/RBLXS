--[[
	ShowcaseController  (StarterPlayerScripts.Client.Controllers.ShowcaseController)
	The Life Reveal's flyover: "show actual environments the player might
	eventually unlock". For a future archetype (Luxury, Career, Family…) the
	camera glides over the matching real place in Lifeville
	(World.Showcase: Hilltop Mansion, Lifeville Tower, Oak Street…), with the
	menus hidden and the sky set to a fitting time of day. Everything is
	restored afterwards (camera, menus, sky, traffic).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Data.World)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Anim = require(UILib.Anim)

local UIController = require(script.Parent.UIController)
local DayNightController = require(script.Parent.DayNightController)
local ExploreController = require(script.Parent.ExploreController)
local TrafficController = require(script.Parent.TrafficController)

local ShowcaseController = {}
ShowcaseController.Priority = 61
ShowcaseController.Hours = { Lonely = 19.2, Difficult = 17.4, Fame = 20.5, Content = 16.5, Adventure = 15 }
ShowcaseController.DefaultHour = 13.5

local saved = nil
local shot = nil

local function vector(t): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function ShowcaseController.Available(archetype: string): boolean
	return workspace:FindFirstChild("World") ~= nil and World.ShowcaseShot(archetype) ~= nil and workspace.CurrentCamera ~= nil
end

function ShowcaseController.IsActive(): boolean
	return saved ~= nil
end

-- Starts the shot: menus hidden, camera at the first position. Returns the shot.
function ShowcaseController.Begin(archetype: string)
	local camera = workspace.CurrentCamera
	shot = World.ShowcaseShot(archetype)
	if not shot or not camera then
		return nil
	end
	if not saved then
		saved = { Type = camera.CameraType, CFrame = camera.CFrame, Subject = camera.CameraSubject, FieldOfView = camera.FieldOfView }
	end
	UIController.SetWorldView(true)
	TrafficController.SetVisible(true)
	DayNightController.Override(ShowcaseController.Hours[archetype] or ShowcaseController.DefaultHour)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	camera.CFrame = CFrame.lookAt(vector(shot.From), vector(shot.Focus))
	return shot
end

-- Glides the camera to the shot's end position over `duration` seconds.
function ShowcaseController.Glide(duration: number)
	local camera = workspace.CurrentCamera
	if not shot or not camera then
		return
	end
	Anim.Tween(camera, { CFrame = CFrame.lookAt(vector(shot.To), vector(shot.Focus)) }, duration, Enum.EasingStyle.Sine)
end

function ShowcaseController.End()
	if not saved then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = saved.Type
		camera.CFrame = saved.CFrame
		camera.CameraSubject = saved.Subject
		camera.FieldOfView = saved.FieldOfView
	end
	saved = nil
	shot = nil
	UIController.SetWorldView(false)
	DayNightController.Override(nil)
	TrafficController.SetVisible(ExploreController.IsExploring())
end

function ShowcaseController.Init() end
function ShowcaseController.Start() end

return ShowcaseController
