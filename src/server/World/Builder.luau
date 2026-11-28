--[[
	Builder  (ServerScriptService.Server.World.Builder)
	Building blocks for generating Lifeville from code: parts, buildings you
	can walk into (walls with a real doorway, windows, roof, lights, sign),
	furniture, trees, lamps, benches (sittable Seats), cars, boats, signs,
	interaction spots (ProximityPrompts) and NPC anchors.

	Conventions:
	  • Everything is Anchored; small props don't cast shadows (performance).
	  • A CFrame "cf" for a building is its ground centre; the front (door)
	    faces cf.LookVector (-Z in its local space).
	  • Tags (CollectionService) the client and services look for:
	      CYL_Lamp (street lamp heads), CYL_Window (glow at night),
	      CYL_Door (sliding door panels), CYL_Spot (interaction parts),
	      CYL_Lock (locked-area walls), CYL_Seat.
	  • Spot parts carry attribute CYL_Spot = WorldSpots id.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldSpots = require(Shared.Data.WorldSpots)

local B = {}

B.Palette = {
	Asphalt = "#3A3D42", Line = "#F1F1F1", Pavement = "#B9B4AA", Kerb = "#8F8A80",
	Grass = "#5DA34B", DarkGrass = "#3F7F36", Sand = "#E8D3A2", Wood = "#8B5A2B", DarkWood = "#5C3B1E",
	Leaves = "#3E9B46", LeavesLight = "#6BBF59", Trunk = "#6B4423", Stone = "#A8A29A", Glass = "#9FD3F2",
	White = "#F5F5F5", Black = "#1E1E1E", Metal = "#9AA0A6", Roof = "#7A3E2E", Water = "#3FA7D6",
}

local function color(value)
	if type(value) == "string" then
		return Color3.fromHex(value)
	end
	return value
end
B.Color = color

-- CFrame helper: position + yaw (degrees).
function B.At(x: number, y: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

-- Yaw (degrees) that makes something at (x, z) face (tx, tz).
function B.YawFacing(x: number, z: number, tx: number, tz: number): number
	return math.deg(math.atan2(x - tx, z - tz))
end

function B.Folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function B.Model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

--[[
	B.Part(parent, {
		Name, Size = Vector3, CFrame, Color = hex|Color3, Material = Enum.Material,
		Class = "Part" | "WedgePart" | "Seat" | "SpawnLocation", Shape = Enum.PartType,
		Transparency, CanCollide, CastShadow, Reflectance, Tag
	})
]]
function B.Part(parent: Instance, p)
	local part = Instance.new(p.Class or "Part")
	part.Name = p.Name or "Part"
	part.Anchored = true
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = color(p.Color or B.Palette.Stone)
	part.Material = p.Material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if p.Shape then
		part.Shape = p.Shape
	end
	if p.Transparency then
		part.Transparency = p.Transparency
	end
	if p.Reflectance then
		part.Reflectance = p.Reflectance
	end
	if p.CanCollide ~= nil then
		part.CanCollide = p.CanCollide
	end
	part.CastShadow = p.CastShadow == true
	if p.CanCollide == false then
		part.CanTouch = false
	end
	if p.Tag then
		CollectionService:AddTag(part, p.Tag)
	end
	part.Parent = parent
	return part
end

-- Box with size (x, y, z) whose BOTTOM sits on cf (handy for things on the ground).
function B.Block(parent: Instance, name: string, cf: CFrame, sx: number, sy: number, sz: number, col, material, extra)
	local props = extra or {}
	props.Name = name
	props.Size = Vector3.new(sx, sy, sz)
	props.CFrame = cf * CFrame.new(0, sy / 2, 0)
	props.Color = col
	props.Material = material
	return B.Part(parent, props)
end

function B.Cylinder(parent: Instance, name: string, cf: CFrame, diameter: number, height: number, col, material, extra)
	-- Roblox cylinders run along X; rotate so they stand up.
	local props = extra or {}
	props.Name = name
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	props.Color = col
	props.Material = material
	return B.Part(parent, props)
end

function B.Ball(parent: Instance, name: string, position: Vector3, diameter: number, col, material, extra)
	local props = extra or {}
	props.Name = name
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = CFrame.new(position)
	props.Color = col
	props.Material = material
	return B.Part(parent, props)
end

-- ===== Text =====
function B.Text(part: BasePart, face, text: string, options)
	options = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = options.PixelsPerStud or 30
	gui.LightInfluence = options.LightInfluence or 0.2
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.RichText = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextColor3 = color(options.TextColor or B.Palette.White)
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return label
end

-- A sign board (front faces cf.LookVector) with text.
function B.Sign(parent: Instance, name: string, cf: CFrame, width: number, height: number, text: string, bg, fg)
	local board = B.Part(parent, { Name = name, Size = Vector3.new(width, height, 0.4), CFrame = cf, Color = bg or "#264653", Material = Enum.Material.SmoothPlastic })
	B.Text(board, Enum.NormalId.Front, text, { TextColor = fg })
	return board
end

-- A sign on two posts, standing on the ground at cf.
function B.PostSign(parent: Instance, name: string, cf: CFrame, width: number, text: string, bg, fg)
	local model = B.Model(parent, name)
	for _, side in ipairs({ -1, 1 }) do
		B.Block(model, "Post", cf * CFrame.new(side * (width / 2 - 0.3), 0, 0), 0.4, 6, 0.4, B.Palette.DarkWood, Enum.Material.Wood)
	end
	B.Sign(model, "Board", cf * CFrame.new(0, 5, -0.25), width, 2.4, text, bg, fg)
	return model
end

-- ===== Ground and roads =====
function B.Slab(parent: Instance, name: string, x: number, z: number, sx: number, sz: number, top: number, col, material, thickness: number?)
	local t = thickness or 1
	return B.Part(parent, { Name = name, Size = Vector3.new(sx, t, sz), CFrame = CFrame.new(x, top - t / 2, z), Color = col, Material = material or Enum.Material.SmoothPlastic })
end

-- Straight road from (x1, z1) to (x2, z2) along one axis, with a centre line.
function B.Road(parent: Instance, x1: number, z1: number, x2: number, z2: number, width: number, top: number)
	local model = B.Model(parent, "Road")
	local horizontal = z1 == z2
	local length = if horizontal then math.abs(x2 - x1) else math.abs(z2 - z1)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local sx, sz = if horizontal then length else width, if horizontal then width else length
	B.Slab(model, "Asphalt", cx, cz, sx, sz, top, B.Palette.Asphalt, Enum.Material.Asphalt, 0.4)
	local lx, lz = if horizontal then length - 8 else 0.6, if horizontal then 0.6 else length - 8
	B.Slab(model, "CentreLine", cx, cz, lx, lz, top + 0.02, B.Palette.Line, Enum.Material.SmoothPlastic, 0.05)
	return model
end

-- ===== Nature and street furniture =====
function B.Tree(parent: Instance, position: Vector3, scale: number?, style: string?)
	local s = scale or 1
	local model = B.Model(parent, "Tree")
	local base = CFrame.new(position)
	if style == "Palm" then
		B.Cylinder(model, "Trunk", base, 1.2 * s, 14 * s, "#8D6E63", Enum.Material.Wood)
		B.Ball(model, "Leaves", position + Vector3.new(0, 14.5 * s, 0), 7 * s, "#4CAF50", Enum.Material.Grass, { CanCollide = false })
	elseif style == "Pine" then
		B.Cylinder(model, "Trunk", base, 1.4 * s, 6 * s, B.Palette.Trunk, Enum.Material.Wood)
		B.Ball(model, "Leaves", position + Vector3.new(0, 7 * s, 0), 8 * s, "#2E7D32", Enum.Material.Grass, { CanCollide = false })
		B.Ball(model, "Top", position + Vector3.new(0, 11 * s, 0), 5 * s, "#388E3C", Enum.Material.Grass, { CanCollide = false })
	else
		B.Cylinder(model, "Trunk", base, 1.6 * s, 7 * s, B.Palette.Trunk, Enum.Material.Wood)
		B.Ball(model, "Leaves", position + Vector3.new(0, 9 * s, 0), 9 * s, if (position.X + position.Z) % 2 < 1 then B.Palette.Leaves else B.Palette.LeavesLight, Enum.Material.Grass, { CanCollide = false })
	end
	return model
end

function B.Lamp(parent: Instance, position: Vector3)
	local model = B.Model(parent, "Lamp")
	B.Cylinder(model, "Pole", CFrame.new(position), 0.6, 12, B.Palette.Black, Enum.Material.Metal)
	local head = B.Part(model, { Name = "Head", Size = Vector3.new(1.6, 1, 1.6), CFrame = CFrame.new(position + Vector3.new(0, 12.5, 0)), Color = "#FFF3C4", Material = Enum.Material.SmoothPlastic, CanCollide = false, Tag = "CYL_Lamp" })
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Range = 18
	light.Brightness = 1.6
	light.Color = color("#FFD99A")
	light.Shadows = false
	light.Enabled = false
	light.Parent = head
	return model
end

-- A bench you can sit on (Seat). Faces cf.LookVector.
function B.Bench(parent: Instance, cf: CFrame)
	local model = B.Model(parent, "Bench")
	B.Part(model, { Name = "Seat", Class = "Seat", Size = Vector3.new(5, 0.6, 1.8), CFrame = cf * CFrame.new(0, 1.6, 0), Color = B.Palette.Wood, Material = Enum.Material.Wood, Tag = "CYL_Seat" })
	B.Part(model, { Name = "Back", Size = Vector3.new(5, 2, 0.4), CFrame = cf * CFrame.new(0, 2.9, 0.8), Color = B.Palette.Wood, Material = Enum.Material.Wood })
	B.Block(model, "Legs", cf * CFrame.new(0, 0, 0), 4.4, 1.3, 1.2, B.Palette.Black, Enum.Material.Metal)
	return model
end

function B.Hedge(parent: Instance, cf: CFrame, sx: number, sz: number, height: number?)
	return B.Block(parent, "Hedge", cf, sx, height or 3, sz, B.Palette.DarkGrass, Enum.Material.Grass)
end

function B.Flowerbed(parent: Instance, cf: CFrame, sx: number, sz: number)
	local model = B.Model(parent, "Flowerbed")
	B.Block(model, "Soil", cf, sx, 0.8, sz, "#5D4037", Enum.Material.Ground)
	local colours = { "#FF6B6B", "#FFD93D", "#C77DFF", "#FF9F1C" }
	local n = math.max(2, math.floor(sx * sz / 18))
	for i = 1, math.min(n, 6) do
		local fx = ((i * 37) % 10) / 10 - 0.5
		local fz = ((i * 53) % 10) / 10 - 0.5
		B.Ball(model, "Flower", (cf * CFrame.new(fx * (sx - 1), 1.2, fz * (sz - 1))).Position, 1.2, colours[(i - 1) % #colours + 1], Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	return model
end

function B.Fountain(parent: Instance, position: Vector3, diameter: number?)
	local d = diameter or 18
	local model = B.Model(parent, "Fountain")
	local base = CFrame.new(position)
	B.Cylinder(model, "Basin", base, d, 2.4, B.Palette.Stone, Enum.Material.Marble)
	B.Cylinder(model, "Water", base * CFrame.new(0, 0.6, 0), d - 2, 2, B.Palette.Water, Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	B.Cylinder(model, "Pillar", base, 2.4, 7, B.Palette.Stone, Enum.Material.Marble)
	local bowl = B.Cylinder(model, "Bowl", base * CFrame.new(0, 7, 0), 7, 1, B.Palette.Stone, Enum.Material.Marble)
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(color("#E0F7FF"))
	spray.Size = NumberSequence.new(0.6)
	spray.Lifetime = NumberRange.new(0.8, 1.4)
	spray.Rate = 40
	spray.Speed = NumberRange.new(8, 12)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Parent = bowl
	return model
end

-- ===== Vehicles =====
local CAR_SHAPES = {
	Hatch = { Length = 9, Width = 4.6, Body = 2.2, Cabin = 2, CabinLength = 5, CabinOffset = 0.6 },
	SUV = { Length = 10, Width = 5, Body = 2.8, Cabin = 2.4, CabinLength = 6.5, CabinOffset = 0.8 },
	Pickup = { Length = 11, Width = 5, Body = 2.6, Cabin = 2.4, CabinLength = 4, CabinOffset = -2 },
	Van = { Length = 11, Width = 5, Body = 3.2, Cabin = 3, CabinLength = 9, CabinOffset = 0.5 },
	Vintage = { Length = 10, Width = 4.6, Body = 2.2, Cabin = 1.8, CabinLength = 4.5, CabinOffset = 1 },
	Super = { Length = 10, Width = 5, Body = 1.6, Cabin = 1.4, CabinLength = 4, CabinOffset = 0.8 },
	Moto = { Length = 5, Width = 1.4, Body = 1.8, Cabin = 0, CabinLength = 0, CabinOffset = 0 },
}
B.CarShapes = CAR_SHAPES

-- A simple car (body, cabin, wheels, lights). Faces cf.LookVector.
function B.Car(parent: Instance, cf: CFrame, bodyColour, shape: string?)
	local s = CAR_SHAPES[shape or "Hatch"] or CAR_SHAPES.Hatch
	local model = B.Model(parent, "Car")
	local wheelSize = if shape == "Moto" then 2.2 else 2
	B.Block(model, "Body", cf * CFrame.new(0, wheelSize * 0.45, 0), s.Width, s.Body, s.Length, bodyColour or "#E63946", Enum.Material.SmoothPlastic, { CastShadow = true })
	if s.Cabin > 0 then
		B.Block(model, "Cabin", cf * CFrame.new(0, wheelSize * 0.45 + s.Body, s.CabinOffset), s.Width - 0.6, s.Cabin, s.CabinLength, "#BFE3F7", Enum.Material.Glass, { Transparency = 0.15 })
	end
	local wx = s.Width / 2 - 0.2
	local wz = s.Length / 2 - 1.6
	local wheels = if shape == "Moto" then { { 0, wz }, { 0, -wz } } else { { -wx, wz }, { wx, wz }, { -wx, -wz }, { wx, -wz } }
	for _, w in ipairs(wheels) do
		B.Part(model, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, wheelSize, wheelSize), CFrame = cf * CFrame.new(w[1], wheelSize / 2, w[2]), Color = B.Palette.Black, Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	if shape ~= "Moto" then
		for _, side in ipairs({ -1, 1 }) do
			B.Part(model, { Name = "Headlight", Size = Vector3.new(0.8, 0.5, 0.2), CFrame = cf * CFrame.new(side * (s.Width / 2 - 0.7), wheelSize * 0.45 + s.Body * 0.6, -s.Length / 2 - 0.05), Color = "#FFF8D6", Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	model.PrimaryPart = model:FindFirstChild("Body")
	return model
end

function B.Boat(parent: Instance, cf: CFrame, length: number, hullColour, big: boolean?)
	local model = B.Model(parent, "Boat")
	local width = length * 0.36
	B.Block(model, "Hull", cf, width, 2.4, length * 0.75, hullColour or B.Palette.White, Enum.Material.SmoothPlastic)
	B.Part(model, { Name = "Bow", Class = "WedgePart", Size = Vector3.new(width, 2.4, length * 0.25), CFrame = cf * CFrame.new(0, 1.2, -length * 0.5), Color = hullColour or B.Palette.White })
	B.Block(model, "Cabin", cf * CFrame.new(0, 2.4, length * 0.1), width * 0.7, if big then 4 else 2.4, length * 0.3, "#ECEFF1", Enum.Material.SmoothPlastic)
	if not big then
		B.Cylinder(model, "Mast", cf * CFrame.new(0, 2.4, -length * 0.15), 0.4, length * 0.7, B.Palette.White, Enum.Material.Metal)
	end
	return model
end

-- ===== Furniture (positions are on the floor at cf; front faces cf.LookVector) =====
function B.Desk(parent: Instance, cf: CFrame, width: number?)
	local model = B.Model(parent, "Desk")
	local w = width or 4
	B.Block(model, "Top", cf * CFrame.new(0, 2.6, 0), w, 0.3, 2.4, B.Palette.Wood, Enum.Material.Wood)
	B.Block(model, "Legs", cf, w - 0.6, 2.6, 0.4, B.Palette.Metal, Enum.Material.Metal)
	return model
end

function B.Chair(parent: Instance, cf: CFrame, col)
	local model = B.Model(parent, "Chair")
	B.Part(model, { Name = "Seat", Class = "Seat", Size = Vector3.new(2, 0.4, 2), CFrame = cf * CFrame.new(0, 1.7, 0), Color = col or "#2A9D8F", Tag = "CYL_Seat" })
	B.Part(model, { Name = "Back", Size = Vector3.new(2, 2, 0.3), CFrame = cf * CFrame.new(0, 2.9, 0.85), Color = col or "#2A9D8F" })
	B.Block(model, "Leg", cf, 0.4, 1.5, 0.4, B.Palette.Metal, Enum.Material.Metal)
	return model
end

function B.Table(parent: Instance, cf: CFrame, sx: number?, sz: number?, col)
	local model = B.Model(parent, "Table")
	B.Block(model, "Top", cf * CFrame.new(0, 2.8, 0), sx or 4, 0.3, sz or 4, col or B.Palette.Wood, Enum.Material.Wood)
	B.Block(model, "Leg", cf, 0.6, 2.8, 0.6, B.Palette.DarkWood, Enum.Material.Wood)
	return model
end

function B.Counter(parent: Instance, cf: CFrame, length: number, col)
	local model = B.Model(parent, "Counter")
	B.Block(model, "Body", cf, length, 3.2, 2, col or "#6D4C41", Enum.Material.Wood)
	B.Block(model, "Top", cf * CFrame.new(0, 3.2, 0), length + 0.4, 0.3, 2.4, "#ECEFF1", Enum.Material.Marble)
	return model
end

function B.Shelf(parent: Instance, cf: CFrame, width: number?)
	local model = B.Model(parent, "Shelf")
	local w = width or 6
	B.Block(model, "Frame", cf, w, 8, 1.4, B.Palette.DarkWood, Enum.Material.Wood)
	local colours = { "#E63946", "#457B9D", "#F4A261", "#2A9D8F" }
	for row = 1, 3 do
		B.Block(model, "Books", cf * CFrame.new(0, row * 2.3 - 1, -0.6), w - 0.8, 1.4, 0.3, colours[row], Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	return model
end

function B.Bed(parent: Instance, cf: CFrame, col)
	local model = B.Model(parent, "Bed")
	B.Block(model, "Frame", cf, 4.4, 1.6, 8, B.Palette.DarkWood, Enum.Material.Wood)
	B.Block(model, "Mattress", cf * CFrame.new(0, 1.6, 0), 4, 0.8, 7.6, col or "#E0E7FF", Enum.Material.Fabric)
	B.Block(model, "Pillow", cf * CFrame.new(0, 2.4, 3), 3, 0.6, 1.4, B.Palette.White, Enum.Material.Fabric, { CanCollide = false })
	return model
end

function B.Sofa(parent: Instance, cf: CFrame, col)
	local model = B.Model(parent, "Sofa")
	local c = col or "#577590"
	B.Part(model, { Name = "Seat", Class = "Seat", Size = Vector3.new(6, 1.2, 2.6), CFrame = cf * CFrame.new(0, 1.2, 0), Color = c, Material = Enum.Material.Fabric, Tag = "CYL_Seat" })
	B.Block(model, "Base", cf, 6, 0.6, 2.6, c, Enum.Material.Fabric)
	B.Block(model, "Back", cf * CFrame.new(0, 0.6, 1.1), 6, 3, 0.6, c, Enum.Material.Fabric)
	return model
end

function B.Plant(parent: Instance, cf: CFrame)
	local model = B.Model(parent, "Plant")
	B.Cylinder(model, "Pot", cf, 1.6, 1.4, "#A1887F", Enum.Material.SmoothPlastic)
	B.Ball(model, "Leaves", (cf * CFrame.new(0, 2.6, 0)).Position, 2.6, B.Palette.Leaves, Enum.Material.Grass, { CanCollide = false })
	return model
end

-- A wall board/screen with text facing cf.LookVector (bottom at cf).
function B.Board(parent: Instance, cf: CFrame, width: number, height: number, text: string, bg, fg)
	local board = B.Part(parent, { Name = "Board", Size = Vector3.new(width, height, 0.3), CFrame = cf * CFrame.new(0, height / 2, 0), Color = bg or "#2D4739", Material = Enum.Material.SmoothPlastic, CanCollide = false })
	B.Text(board, Enum.NormalId.Front, text, { TextColor = fg or "#F1FAEE", PixelsPerStud = 24 })
	return board
end

-- ===== Buildings =====
--[[
	B.Building(parent, {
		Name, CFrame (ground centre, front = LookVector), Width, Depth, Height,
		Wall, Trim, Roof = hex, RoofStyle = "Flat" | "Pitched",
		DoorWidth (8), DoorHeight (9), DoorOffset (0), AutoDoor (true),
		Sign = "text", SignColor, Floors (visual window rows, 1),
		Floor = hex, FloorMaterial, Light = true,
	})
	Returns model, plus `inside(x, y, z, yaw)` -> CFrame helper in the building's
	local space (origin on the floor at the centre, -Z towards the door).
]]
function B.Building(parent: Instance, spec)
	local model = B.Model(parent, spec.Name)
	model:SetAttribute("CYL_Building", spec.Name)
	local cf: CFrame = spec.CFrame
	local w, d, h = spec.Width, spec.Depth, spec.Height
	local t = 1
	local wall = spec.Wall or "#E9E4D8"
	local material = spec.WallMaterial or Enum.Material.SmoothPlastic
	local doorW, doorH = spec.DoorWidth or 8, spec.DoorHeight or 9
	local doorX = spec.DoorOffset or 0

	local floor = B.Block(model, "Floor", cf, w, 0.4, d, spec.Floor or "#D7CCC8", spec.FloorMaterial or Enum.Material.WoodPlanks)
	model.PrimaryPart = floor
	local base = cf * CFrame.new(0, 0.4, 0)
	local wallH = h - 0.4

	local function wallPart(name, sx, sy, sz, x, y, z)
		return B.Part(model, { Name = name, Size = Vector3.new(sx, sy, sz), CFrame = base * CFrame.new(x, y, z), Color = wall, Material = material, CastShadow = true })
	end
	-- Back and sides
	wallPart("BackWall", w, wallH, t, 0, wallH / 2, d / 2 - t / 2)
	wallPart("LeftWall", t, wallH, d - 2 * t, -w / 2 + t / 2, wallH / 2, 0)
	wallPart("RightWall", t, wallH, d - 2 * t, w / 2 - t / 2, wallH / 2, 0)
	-- Front wall with a doorway
	local leftEdge, rightEdge = -w / 2, w / 2
	local doorL, doorR = doorX - doorW / 2, doorX + doorW / 2
	local frontZ = -d / 2 + t / 2
	if doorL - leftEdge > 0.05 then
		wallPart("FrontWallL", doorL - leftEdge, wallH, t, (leftEdge + doorL) / 2, wallH / 2, frontZ)
	end
	if rightEdge - doorR > 0.05 then
		wallPart("FrontWallR", rightEdge - doorR, wallH, t, (doorR + rightEdge) / 2, wallH / 2, frontZ)
	end
	if wallH - doorH > 0.05 then
		wallPart("FrontWallTop", doorW, wallH - doorH, t, doorX, doorH + (wallH - doorH) / 2, frontZ)
	end

	-- Sliding door panels (animated by the client; never collide).
	if spec.AutoDoor ~= false then
		for _, side in ipairs({ -1, 1 }) do
			local panel = B.Part(model, { Name = "DoorPanel", Size = Vector3.new(doorW / 2, doorH, 0.3), CFrame = base * CFrame.new(doorX + side * doorW / 4, doorH / 2, frontZ - 0.2), Color = "#BFE3F7", Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false, Tag = "CYL_Door" })
			panel:SetAttribute("SlideX", side * (doorW / 2 - 0.2))
		end
	end

	-- Windows (glow at night): rows on the sides and back.
	local floors = spec.Floors or 1
	local rowH = wallH / floors
	local function windowsAlong(face: string, length: number)
		local count = math.max(1, math.floor(length / 10))
		for f = 1, floors do
			local y = (f - 1) * rowH + rowH * 0.58
			for i = 1, count do
				local along = -length / 2 + (i - 0.5) * (length / count)
				local cfw
				if face == "Back" then
					cfw = base * CFrame.new(along, y, d / 2 + 0.05)
				elseif face == "Left" then
					cfw = base * CFrame.new(-w / 2 - 0.05, y, along) * CFrame.Angles(0, math.rad(90), 0)
				elseif face == "Right" then
					cfw = base * CFrame.new(w / 2 + 0.05, y, along) * CFrame.Angles(0, math.rad(90), 0)
				else
					if math.abs(along - doorX) < doorW / 2 + 3 and f == 1 then
						continue
					end
					cfw = base * CFrame.new(along, y, -d / 2 - 0.05)
				end
				B.Part(model, { Name = "Window", Size = Vector3.new(math.min(5, length / count - 2), math.min(4, rowH * 0.5), 0.2), CFrame = cfw, Color = B.Palette.Glass, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, Tag = "CYL_Window" })
			end
		end
	end
	if spec.Windows ~= false then
		windowsAlong("Front", w)
		windowsAlong("Back", w)
		windowsAlong("Left", d)
		windowsAlong("Right", d)
	end

	-- Roof
	local roofColour = spec.Roof or "#5C5C5C"
	if spec.RoofStyle == "Pitched" then
		local rise = math.min(w, d) * 0.35
		for _, side in ipairs({ -1, 1 }) do
			B.Part(model, { Name = "Roof", Class = "WedgePart", Size = Vector3.new(d + 2, rise, w / 2 + 1), CFrame = base * CFrame.new(side * (w / 4 + 0.5), wallH + rise / 2, 0) * CFrame.Angles(0, math.rad(-side * 90), 0), Color = roofColour, Material = Enum.Material.Slate, CastShadow = true })
		end
	else
		B.Part(model, { Name = "Roof", Size = Vector3.new(w + 1.4, 1, d + 1.4), CFrame = base * CFrame.new(0, wallH + 0.5, 0), Color = roofColour, Material = Enum.Material.Concrete, CastShadow = true })
	end

	-- Sign above the door
	if spec.Sign then
		B.Sign(model, "Sign", base * CFrame.new(doorX, math.min(wallH - 1.2, doorH + 2.2), -d / 2 - 0.35), math.min(w - 2, math.max(16, #spec.Sign * 1.1)), 3, spec.Sign, spec.SignColor or "#264653", spec.SignText)
	end

	-- Ceiling light
	if spec.Light ~= false then
		local lamp = B.Part(model, { Name = "CeilingLight", Size = Vector3.new(3, 0.3, 3), CFrame = base * CFrame.new(0, wallH - 0.3, 0), Color = "#FFF8E1", Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Range = math.min(40, math.max(w, d) * 0.7)
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lamp
	end

	local function inside(x: number, y: number, z: number, yaw: number?): CFrame
		return base * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	return model, inside
end

-- ===== Gameplay markers =====
-- An interaction spot: invisible part + ProximityPrompt for WorldSpots[id].
function B.Spot(parent: Instance, spotId: string, cf: CFrame, holdDuration: number?)
	local def = WorldSpots.Get(spotId)
	assert(def, "Builder.Spot: unknown spot " .. tostring(spotId))
	local part = B.Part(parent, { Name = "Spot_" .. spotId, Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 2.5, 0), Transparency = 1, CanCollide = false, Tag = "CYL_Spot" })
	part.CanQuery = false
	part:SetAttribute("CYL_Spot", spotId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = def.Label
	prompt.ObjectText = def.Object
	prompt.HoldDuration = holdDuration or (if def.Kind == "Open" then 0 else 0.4)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("CYL_Spot", spotId)
	prompt.Parent = part
	return part
end

-- A Memory Star collectible (Data/Collectibles), floating above cf.
function B.Star(parent: Instance, starId: string, cf: CFrame)
	local star = B.Part(parent, { Name = starId, Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(0, 1.4, 0), Color = "#FFD60A", Material = Enum.Material.Neon, CanCollide = false, Tag = "CYL_Star" })
	star.CanQuery = false
	star:SetAttribute("CYL_Star", starId)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color("#FFF3B0"))
	sparkle.Size = NumberSequence.new(0.35)
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = star
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Collect"
	prompt.ObjectText = "✨ Memory Star"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("CYL_Star", starId)
	prompt.Parent = star
	return star
end

-- Where an NPC stands (NPCService spawns the character here, facing cf.LookVector).
function B.NPC(anchors: Instance, npcId: string, cf: CFrame)
	local part = B.Part(anchors, { Name = npcId, Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 0.5, 0), Transparency = 1, CanCollide = false })
	part.CanQuery = false
	return part
end

-- Walls of a locked area (the client turns them solid while it's locked for you).
function B.LockWall(parent: Instance, lockId: string, unlockStage: number, cf: CFrame, sx: number, sy: number, sz: number)
	local part = B.Part(parent, { Name = "Lock_" .. lockId, Size = Vector3.new(sx, sy, sz), CFrame = cf * CFrame.new(0, sy / 2, 0), Color = "#7B61FF", Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Tag = "CYL_Lock" })
	part.CanQuery = false
	part:SetAttribute("LockId", lockId)
	part:SetAttribute("UnlockStage", unlockStage)
	return part
end

return B
