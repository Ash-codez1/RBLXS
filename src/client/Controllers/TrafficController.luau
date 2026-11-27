--[[
	TrafficController  (StarterPlayerScripts.Client.Controllers.TrafficController)
	Cars driving round Lifeville's roads (World.TrafficLoops), on each client
	only: no network traffic and no collisions (walk-through), so they can
	never block or push a player. Fewer cars on Low graphics; hidden when
	you're not exploring.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Data.World)

local GraphicsController = require(script.Parent.GraphicsController)
local ExploreController = require(script.Parent.ExploreController)

local TrafficController = {}
TrafficController.Priority = 59
TrafficController.Speed = 26 -- studs per second
TrafficController.HighCount = 8
TrafficController.LowCount = 3

local COLOURS = { "#E63946", "#457B9D", "#F4A261", "#2A9D8F", "#E9C46A", "#6D597A", "#F8F9FA", "#1D3557" }

local folder: Folder? = nil
local cars: { { Model: Model, Loop: number, Distance: number } } = {}
local loops = {}

local function buildLoops()
	loops = {}
	for _, points in ipairs(World.TrafficLoops) do
		local list = {}
		for _, p in ipairs(points) do
			table.insert(list, Vector3.new(p[1], 0.22, p[2]))
		end
		local lengths, total = {}, 0
		for i = 1, #list do
			local a, b = list[i], list[i % #list + 1]
			lengths[i] = (b - a).Magnitude
			total += lengths[i]
		end
		table.insert(loops, { Points = list, Lengths = lengths, Total = total })
	end
end

-- Position and heading `distance` studs along loop `index`.
function TrafficController.At(index: number, distance: number): CFrame
	local loop = loops[index]
	local d = distance % loop.Total
	for i, length in ipairs(loop.Lengths) do
		if d <= length then
			local a, b = loop.Points[i], loop.Points[i % #loop.Points + 1]
			local position = a:Lerp(b, d / math.max(length, 0.001))
			return CFrame.lookAt(position, position + (b - a).Unit)
		end
		d -= length
	end
	return CFrame.new(loop.Points[1])
end

local function part(model: Model, name: string, size: Vector3, offset: CFrame, colour: Color3, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = offset
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

local function makeCar(i: number): Model
	local model = Instance.new("Model")
	model.Name = "Car" .. i
	local body = part(model, "Body", Vector3.new(4.6, 2, 9), CFrame.new(0, 1.9, 0), Color3.fromHex(COLOURS[(i - 1) % #COLOURS + 1]))
	part(model, "Cabin", Vector3.new(4, 1.8, 5), CFrame.new(0, 3.8, 0.5), Color3.fromHex("#BFE3F7"), Enum.Material.Glass)
	for _, w in ipairs({ { -2.3, 2.9 }, { 2.3, 2.9 }, { -2.3, -2.9 }, { 2.3, -2.9 } }) do
		local wheel = part(model, "Wheel", Vector3.new(0.8, 2, 2), CFrame.new(w[1], 1, w[2]), Color3.fromHex("#1E1E1E"))
		wheel.Shape = Enum.PartType.Cylinder
	end
	model.PrimaryPart = body
	model.Parent = folder
	return model
end

function TrafficController.Build()
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "CYL_Traffic"
	f.Parent = workspace
	folder = f
	cars = {}
	buildLoops()
	local count = if GraphicsController.IsLow() then TrafficController.LowCount else TrafficController.HighCount
	for i = 1, count do
		local loopIndex = (i - 1) % #loops + 1
		local car = { Model = makeCar(i), Loop = loopIndex, Distance = (i * 137) % loops[loopIndex].Total }
		car.Model:PivotTo(TrafficController.At(car.Loop, car.Distance))
		table.insert(cars, car)
	end
	TrafficController.SetVisible(ExploreController.IsExploring())
end

function TrafficController.Cars()
	return cars
end

function TrafficController.SetVisible(visible: boolean)
	if folder then
		folder.Parent = if visible then workspace else nil
	end
end

function TrafficController.Step(dt: number)
	for _, car in ipairs(cars) do
		car.Distance += TrafficController.Speed * dt
		car.Model:PivotTo(TrafficController.At(car.Loop, car.Distance))
	end
end

function TrafficController.Init() end

function TrafficController.Start()
	TrafficController.Build()
	GraphicsController.Changed:Connect(TrafficController.Build)
	ExploreController.Changed:Connect(TrafficController.SetVisible)
	RunService.Heartbeat:Connect(function(dt)
		if ExploreController.IsExploring() then
			TrafficController.Step(dt)
		end
	end)
end

return TrafficController
