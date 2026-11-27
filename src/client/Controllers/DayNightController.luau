--[[
	DayNightController  (StarterPlayerScripts.Client.Controllers.DayNightController)
	Lifeville's day and night: the sky (Lighting.ClockTime) follows the shared
	server clock (World.ClockTimeAt), so every player sees the same time with
	no network traffic. A full day lasts World.DayLengthSeconds (12 min).
	At dusk street lamps glow and windows light up; at dawn they switch off.
	On Low graphics lamps glow without casting light (cheaper on phones).
	DayNightController.Override(hour?) pins the time (Life Reveal showcase).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Data.World)

local GraphicsController = require(script.Parent.GraphicsController)

local DayNightController = {}
DayNightController.Priority = 56

local WINDOW_NIGHT = Color3.fromRGB(255, 226, 150)

local override: number? = nil
local night: boolean? = nil
local windowDay: { [BasePart]: { Color: Color3, Material: Enum.Material, Transparency: number } } = {}

function DayNightController.ClockTime(): number
	if override then
		return override
	end
	return World.ClockTimeAt(workspace:GetServerTimeNow())
end

function DayNightController.IsNight(): boolean
	return World.IsNight(DayNightController.ClockTime())
end

local function applyLamp(part: BasePart, on: boolean)
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = on and not GraphicsController.IsLow()
	end
end

local function applyWindow(part: BasePart, on: boolean)
	if not windowDay[part] then
		windowDay[part] = { Color = part.Color, Material = part.Material, Transparency = part.Transparency }
		part.Destroying:Connect(function()
			windowDay[part] = nil
		end)
	end
	local day = windowDay[part]
	if on then
		part.Color = WINDOW_NIGHT
		part.Material = Enum.Material.Neon
		part.Transparency = 0.05
	else
		part.Color = day.Color
		part.Material = day.Material
		part.Transparency = day.Transparency
	end
end

function DayNightController.ApplyAll()
	local on = night == true
	for _, part in ipairs(CollectionService:GetTagged("CYL_Lamp")) do
		applyLamp(part, on)
	end
	for _, part in ipairs(CollectionService:GetTagged("CYL_Window")) do
		applyWindow(part, on)
	end
end

function DayNightController.Step()
	local clock = DayNightController.ClockTime()
	Lighting.ClockTime = clock
	local isNight = World.IsNight(clock)
	if isNight ~= night then
		night = isNight
		DayNightController.ApplyAll()
	end
end

-- Pins the sky to `hour` (nil returns to the shared clock).
function DayNightController.Override(hour: number?)
	override = hour
	DayNightController.Step()
end

function DayNightController.Init() end

function DayNightController.Start()
	CollectionService:GetInstanceAddedSignal("CYL_Lamp"):Connect(function(part)
		applyLamp(part, night == true)
	end)
	CollectionService:GetInstanceAddedSignal("CYL_Window"):Connect(function(part)
		if night then
			applyWindow(part, true)
		end
	end)
	GraphicsController.Changed:Connect(DayNightController.ApplyAll)
	DayNightController.Step()
	while true do
		task.wait(1)
		DayNightController.Step()
	end
end

return DayNightController
