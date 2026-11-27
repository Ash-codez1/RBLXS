--[[
	MapController  (StarterPlayerScripts.Client.Controllers.MapController)
	🗺️ The town map (explore mode, the Plaza notice board, NPC directions):
	every district with its colour, icon and whether it's open for your life
	stage, the roads, the harbour bay, and you. Tap a district to set a
	waypoint: a glowing guide line from your character and a 📍 marker that
	clear when you arrive.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Data.World)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local ExploreController = require(script.Parent.ExploreController)

local MapController = {}
MapController.Priority = 55
MapController.Extent = 262 -- the map shows -262..262 studs

local waypoint: { Part: BasePart, District: string, Expires: number }? = nil

local function stage(): number
	local life = DataController.GetActiveLife()
	return World.StageOf(if life and not life.Completed then life else nil)
end

function MapController.ClearWaypoint()
	if waypoint then
		waypoint.Part:Destroy()
		waypoint = nil
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local attachment = root and root:FindFirstChild("CYL_WaypointFrom")
	if attachment then
		attachment:Destroy()
	end
end

function MapController.Waypoint(): string?
	return waypoint and waypoint.District or nil
end

function MapController.SetWaypoint(districtId: string)
	local d = World.ById[districtId]
	if not d then
		return
	end
	MapController.ClearWaypoint()
	local part = Instance.new("Part")
	part.Name = "CYL_Waypoint"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(d.X, 8, d.Z)
	local marker = Instance.new("BillboardGui")
	marker.Name = "Marker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(240, 60)
	marker.LightInfluence = 0
	marker.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "📍 " .. d.Name
	label.TextScaled = true
	label.FontFace = Theme.Font.Heavy
	label.TextColor3 = Theme.Color.Gold
	label.TextStrokeTransparency = 0.3
	label.Parent = marker
	local target = Instance.new("Attachment")
	target.Name = "To"
	target.Parent = part
	part.Parent = workspace
	waypoint = { Part = part, District = districtId, Expires = os.clock() + 180 }

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local from = Instance.new("Attachment")
		from.Name = "CYL_WaypointFrom"
		from.Parent = root
		local beam = Instance.new("Beam")
		beam.Name = "Guide"
		beam.Attachment0 = from
		beam.Attachment1 = target
		beam.Color = ColorSequence.new(Theme.Color.Gold)
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.35)
		beam.Parent = part
	end
	ExploreController.ShowCard("🧭 " .. d.Name, "Follow the golden line" .. (if World.IsUnlocked(districtId, stage()) then "." else ". It's still locked for you: " .. World.UnlockText(d.UnlockStage) .. "."), nil, "Result")
end

local function toMap(x: number, z: number, size: number): UDim2
	local e = MapController.Extent
	return UDim2.fromOffset((x + e) / (2 * e) * size, (z + e) / (2 * e) * size)
end

local function rect(parent: Instance, name: string, x1: number, z1: number, x2: number, z2: number, size: number, colour: Color3, zIndex: number?)
	local e = MapController.Extent
	x1, x2 = math.max(-e, x1), math.min(e, x2)
	z1, z2 = math.max(-e, z1), math.min(e, z2)
	local scale = size / (2 * e)
	return Create("Frame", { Name = name, BackgroundColor3 = colour, BorderSizePixel = 0, Position = toMap(x1, z1, size), Size = UDim2.fromOffset((x2 - x1) * scale, (z2 - z1) * scale), ZIndex = zIndex or 1, Parent = parent })
end

function MapController.Open()
	local handle = UIController.OpenPanel({ Name = "MapModal", Title = "🗺️  " .. World.TownName, Width = 640, Height = 720 })
	handle.Subtitle.Text = "Tap a place to get directions"
	local size = math.min(540, UIController.GetVirtualSize().X - 80, UIController.GetVirtualSize().Y - 200)
	local map = Create("Frame", { Name = "Map", BackgroundColor3 = Color3.fromHex("#3FA7D6"), Size = UDim2.fromOffset(size, size), LayoutOrder = 1, ClipsDescendants = true, Parent = handle.Scroll }, { Create.Corner(Theme.RadiusSmall) })
	local grass = Color3.fromHex("#5DA34B")
	rect(map, "LandNorth", -320, -320, 320, 150, size, grass)
	rect(map, "LandSouth", -320, 150, 150, 320, size, grass)
	local road = Color3.fromHex("#3A3D42")
	local w = World.RoadWidth / 2
	for _, line in ipairs({ -80, 80 }) do
		rect(map, "Road", line - w, -252, line + w, 252, size, road, 2)
		rect(map, "Road", -252, line - w, 252, line + w, size, road, 2)
	end
	rect(map, "Ring", -252, -252, 252, -228, size, road, 2)
	rect(map, "Ring", -252, -252, -228, 252, size, road, 2)
	rect(map, "Ring", 228, -252, 252, 134, size, road, 2)
	rect(map, "Ring", -252, 228, 134, 252, size, road, 2)

	local current = stage()
	local half = World.CellSize / 2
	for _, d in ipairs(World.Districts) do
		local open = World.IsUnlocked(d.Id, current)
		local cell = rect(map, "District_" .. d.Id, d.X - half, d.Z - half, d.X + half, d.Z + half, size, Color3.fromHex(d.Map), 3)
		cell.BackgroundTransparency = if open then 0 else 0.45
		if d.Coastal then
			cell.BackgroundTransparency = if open then 0.25 else 0.55
		end
		Create.Corner(UDim.new(0, 6)).Parent = cell
		local button = Create("TextButton", { Name = "Go", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = cell })
		button.Activated:Connect(function()
			UIController.ClosePanel()
			MapController.SetWaypoint(d.Id)
		end)
		Create.Label({ Name = "Icon", Text = (if open then d.Icon else "🔒"), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.25, 0.12), Size = UDim2.fromScale(0.5, 0.42), ZIndex = 4, Parent = cell })
		Create.Label({ Name = "Name", Text = d.Name, TextScaled = true, FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.05, 0.58), Size = UDim2.fromScale(0.9, 0.28), ZIndex = 4, Parent = cell })
	end

	local you = Create("Frame", { Name = "You", BackgroundColor3 = Theme.Color.Primary, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), ZIndex = 8, Parent = map }, { Create.Corner(UDim.new(1, 0)), Create.Stroke(Theme.Color.White, 2, 0) })
	local function place()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		you.Visible = root ~= nil
		if root then
			you.Position = toMap(root.Position.X, root.Position.Z, size)
		end
	end
	place()
	task.spawn(function()
		while handle.IsOpen() do
			place()
			task.wait(0.3)
		end
	end)

	Create.Label({ Name = "Legend", Text = ("🔴 You · 🔒 opens later in life (Downtown & Harbour at %d, University & Career Row at %d, Sunset Club at %d)"):format(World.StageAges[2], World.StageAges[3], World.StageAges[6]), TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = handle.Scroll })
	return handle
end

function MapController.Init() end

function MapController.Start()
	ExploreController.DistrictChanged:Connect(function(districtId)
		if waypoint and districtId == waypoint.District then
			MapController.ClearWaypoint()
		end
	end)
	ExploreController.Changed:Connect(function(on)
		if not on then
			MapController.ClearWaypoint()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			if waypoint and os.clock() > waypoint.Expires then
				MapController.ClearWaypoint()
			end
		end
	end)
end

return MapController
