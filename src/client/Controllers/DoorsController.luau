--[[
	DoorsController  (StarterPlayerScripts.Client.Controllers.DoorsController)
	Automatic sliding glass doors (parts tagged CYL_Door by the world
	builder): each panel slides open when any character comes within
	OpenDistance studs and closes again after they leave. Panels never
	collide, so nobody can get stuck; the animation runs on each client.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Anim = require(UILib.Anim)

local ExploreController = require(script.Parent.ExploreController)

local DoorsController = {}
DoorsController.Priority = 58
DoorsController.OpenDistance = 11

local doors: { [BasePart]: { Closed: CFrame, Open: CFrame, IsOpen: boolean } } = {}

local function track(panel: BasePart)
	if doors[panel] then
		return
	end
	local slide = panel:GetAttribute("SlideX") or 2
	doors[panel] = { Closed = panel.CFrame, Open = panel.CFrame * CFrame.new(slide, 0, 0), IsOpen = false }
	panel.Destroying:Connect(function()
		doors[panel] = nil
	end)
end

function DoorsController.Doors()
	return doors
end

function DoorsController.Step()
	local positions = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(positions, root.Position)
		end
	end
	for panel, door in pairs(doors) do
		local near = false
		local centre = door.Closed.Position
		for _, p in ipairs(positions) do
			if (p - centre).Magnitude < DoorsController.OpenDistance then
				near = true
				break
			end
		end
		if near ~= door.IsOpen then
			door.IsOpen = near
			Anim.Tween(panel, { CFrame = if near then door.Open else door.Closed }, 0.35)
		end
	end
end

function DoorsController.Init() end

function DoorsController.Start()
	for _, panel in ipairs(CollectionService:GetTagged("CYL_Door")) do
		track(panel)
	end
	CollectionService:GetInstanceAddedSignal("CYL_Door"):Connect(track)
	while true do
		task.wait(0.2)
		if ExploreController.IsExploring() then
			DoorsController.Step()
		end
	end
end

return DoorsController
