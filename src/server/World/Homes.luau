--[[
	Homes  (ServerScriptService.Server.World.Homes)
	Builds a player's house on an Oak Street plot. The house reflects their
	life and their shop cosmetics:
	  • size: family home (under 19, living with parents), rented house,
	    starter home (Apartment asset), family house (House) or mansion;
	  • look: the equipped House style (or Apartment style for flats);
	  • drive: the equipped car, or the life's own car;
	  • garden: the equipped pet; inside: the equipped centrepiece;
	  • inside: "Rest at home" (sofa) and "Have a family dinner" (table) spots.

	Homes.SpecFor(player, data) -> spec (with spec.Key to detect changes)
	Homes.Build(plotModel, spec) -> house model
	Homes.Clear(plotModel)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Data.Catalog)

local B = require(script.Parent.Builder)

local Homes = {}

Homes.Tiers = {
	Family = { Title = "family home", Width = 16, Depth = 14, Height = 12, RoofStyle = "Pitched" },
	Rented = { Title = "rented house", Width = 13, Depth = 12, Height = 11, RoofStyle = "Pitched" },
	Apartment = { Title = "starter home", Width = 14, Depth = 12, Height = 12, RoofStyle = "Flat" },
	House = { Title = "family house", Width = 18, Depth = 15, Height = 15, RoofStyle = "Pitched", Floors = 2 },
	Mansion = { Title = "mansion", Width = 21, Depth = 18, Height = 18, RoofStyle = "Flat", Floors = 2 },
}

Homes.Styles = {
	Default = { Wall = "#E9E4D8", Roof = "#7A3E2E" },
	House_Cottage = { Wall = "#FFF3D6", Roof = "#A0522D", RoofStyle = "Pitched" },
	House_Cabin = { Wall = "#8B5A2B", Roof = "#2F5233", Material = Enum.Material.WoodPlanks, RoofStyle = "Pitched" },
	House_Beach = { Wall = "#FFFFFF", Roof = "#48CAE4", RoofStyle = "Flat" },
	House_Japanese = { Wall = "#4E342E", Roof = "#263238", Material = Enum.Material.Wood, RoofStyle = "Pitched" },
	House_Castle = { Wall = "#9E9E9E", Roof = "#616161", Material = Enum.Material.Cobblestone, RoofStyle = "Flat" },
	House_Manor = { Wall = "#F5F0E1", Roof = "#1D3557", Material = Enum.Material.Marble, RoofStyle = "Pitched" },
	Apt_Loft = { Wall = "#B5651D", Roof = "#3E2723", Material = Enum.Material.Brick, RoofStyle = "Flat" },
	Apt_Studio = { Wall = "#ADB5BD", Roof = "#495057", Material = Enum.Material.Concrete, RoofStyle = "Flat" },
	Apt_Penthouse = { Wall = "#90E0EF", Roof = "#023E8A", Material = Enum.Material.Glass, RoofStyle = "Flat" },
	Apt_Tower = { Wall = "#2B2D42", Roof = "#8D99AE", Material = Enum.Material.Glass, RoofStyle = "Flat" },
}

Homes.Cars = {
	Car_Hatch = { Shape = "Hatch", Color = "#E63946" },
	Car_SUV = { Shape = "SUV", Color = "#2A9D8F" },
	Car_Pickup = { Shape = "Pickup", Color = "#F4A261" },
	Car_Camper = { Shape = "Van", Color = "#E9C46A" },
	Car_Moto = { Shape = "Moto", Color = "#111111" },
	Car_Vintage = { Shape = "Vintage", Color = "#9B2226" },
	Car_Super = { Shape = "Super", Color = "#FFBE0B" },
}

local function activeLife(data)
	local life = data.Slots[data.ActiveSlot]
	if type(life) == "table" and not life.Completed then
		return life
	end
	return nil
end

function Homes.SpecFor(player: Player, data)
	local life = activeLife(data)
	local equipped = data.Inventory and data.Inventory.Equipped or {}
	local tier
	if not life or life.Age < 19 then
		tier = "Family"
	elseif life.Assets.Mansion then
		tier = "Mansion"
	elseif life.Assets.House then
		tier = "House"
	elseif life.Assets.Apartment then
		tier = "Apartment"
	else
		tier = "Rented"
	end
	local styleId = if tier == "Apartment" or tier == "Rented" then equipped.Apartment else equipped.House
	local car = Homes.Cars[equipped.Car or ""]
	if not car and life then
		if life.Assets.SportsCar then
			car = { Shape = "Super", Color = "#D00000" }
		elseif life.Assets.Car then
			car = { Shape = "Hatch", Color = "#8D99AE" }
		elseif tier == "Family" then
			car = { Shape = "SUV", Color = "#6C757D" } -- your parents' car
		end
	end
	local pet = Catalog.Get(equipped.Pet)
	local furniture = Catalog.Get(equipped.Furniture)
	local spec = {
		Tier = tier,
		Style = if styleId and Homes.Styles[styleId] then styleId else "Default",
		Car = car,
		Pet = pet and pet.Icon or nil,
		Furniture = furniture and furniture.Icon or nil,
		Owner = player.DisplayName or player.Name,
		LifeName = life and life.Name or nil,
	}
	spec.Key = table.concat({ spec.Tier, spec.Style, car and (car.Shape .. car.Color) or "-", spec.Pet or "-", spec.Furniture or "-", spec.Owner, spec.LifeName or "-" }, "|")
	return spec
end

function Homes.Clear(plot: Model)
	local house = plot:FindFirstChild("House")
	if house then
		house:Destroy()
	end
end

local function floatingIcon(parent: Instance, position: Vector3, icon: string, size: number)
	local holder = B.Part(parent, { Name = "Icon", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position), Transparency = 1, CanCollide = false })
	holder.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "Icon"
	gui.Size = UDim2.fromOffset(size, size)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = icon
	label.TextScaled = true
	label.Parent = gui
	return holder
end

-- Builds the house for `spec` on `plot` (replacing any previous house).
function Homes.Build(plot: Model, spec)
	Homes.Clear(plot)
	local base = plot:FindFirstChild("Base") :: BasePart
	local house = B.Model(plot, "House")
	house:SetAttribute("Key", spec.Key)
	local tier = Homes.Tiers[spec.Tier] or Homes.Tiers.Family
	local style = Homes.Styles[spec.Style] or Homes.Styles.Default
	-- The plot's Base faces the street (-Z). The house sits at the back left,
	-- the drive and car on the right, the garden in front.
	local ground = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	local halfW, halfD = tier.Width / 2, tier.Depth / 2
	local houseCf = ground * CFrame.new(-12 + halfW + 0.6, 0, 15 - halfD - 0.6)
	local building, inside = B.Building(house, {
		Name = "Home", CFrame = houseCf, Width = tier.Width, Depth = tier.Depth, Height = tier.Height, Floors = tier.Floors,
		Wall = style.Wall, WallMaterial = style.Material, Roof = style.Roof, RoofStyle = style.RoofStyle or tier.RoofStyle,
		DoorWidth = 5, DoorHeight = 8, DoorOffset = -halfW + 3.5, Floor = "#D7CCC8", Light = true,
	})
	building:SetAttribute("Tier", spec.Tier)
	-- Inside: sofa (rest) at the back left, table (dinner) on the right, centrepiece
	B.Sofa(building, inside(-halfW + 4.5, 0, halfD - 3, 0), "#577590")
	local rest = B.Spot(building, "Home_Rest", inside(-halfW + 4.5, 0, halfD - 6))
	B.Table(building, inside(halfW - 3.5, 0, -1), 4, 4, "#FFFFFF")
	B.Chair(building, inside(halfW - 3.5, 0, -3.6, 180), "#E9C46A")
	B.Chair(building, inside(halfW - 3.5, 0, 1.6, 0), "#E9C46A")
	local dinner = B.Spot(building, "Home_Dinner", inside(halfW - 6.5, 0, -1))
	for _, part in ipairs({ rest, dinner }) do
		part:SetAttribute("Plot", plot:GetAttribute("Index"))
	end
	if spec.Furniture then
		floatingIcon(building, (inside(0, 3, halfD - 3)).Position, spec.Furniture, 90)
	end
	-- Drive and garden
	local drive = ground * CFrame.new(9.5, 0, -10.5)
	B.Slab(house, "Drive", drive.Position.X, drive.Position.Z, 5, 9, ground.Position.Y + 0.06, B.Palette.Pavement, Enum.Material.Pavement, 0.1)
	if spec.Car then
		B.Car(house, drive * CFrame.new(0, 0.06, 0), spec.Car.Color, spec.Car.Shape)
	end
	if spec.Pet then
		B.Block(house, "Kennel", ground * CFrame.new(-8, 0, -10), 2.4, 2.2, 2.4, B.Palette.Wood, Enum.Material.WoodPlanks)
		floatingIcon(house, (ground * CFrame.new(-5.5, 2, -10)).Position, spec.Pet, 60)
	end
	B.Flowerbed(house, ground * CFrame.new(-6, 0, -13.5), 8, 2)
	B.Tree(house, (ground * CFrame.new(3, 0, -11)).Position, 0.8)
	-- Name sign
	local sign = plot:FindFirstChild("NameSign")
	local board = sign and sign:FindFirstChild("Board")
	local label = board and board:FindFirstChild("Text") and board.Text:FindFirstChild("Label")
	if label then
		label.Text = ("🏡 %s's %s"):format(spec.Owner, tier.Title)
	end
	return house
end

function Homes.ResetSign(plot: Model)
	local sign = plot:FindFirstChild("NameSign")
	local board = sign and sign:FindFirstChild("Board")
	local label = board and board:FindFirstChild("Text") and board.Text:FindFirstChild("Label")
	if label then
		label.Text = "🏡 For sale"
	end
end

return Homes
