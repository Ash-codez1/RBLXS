--[[
	Create  (StarterPlayerScripts.Client.UILib.Create)
	Small helpers for building UI from code.

	Create("Frame", { Size = ..., Parent = ... }, { childA, childB })
	Create.Corner(radius)   Create.Stroke(color, thickness, transparency)
	Create.Padding(all) / Create.Padding(top, right, bottom, left)
	Create.List(direction, padding, hAlign, vAlign)
	Create.Gradient(colorSequence, rotation)
	Create.Label(props)     TextLabel with the theme defaults applied
	Create.Clear(instance)  destroys all GuiObject children (keeps layouts if asked)
]]

local Theme = require(script.Parent.Theme)

local function new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local Create = setmetatable({}, {
	__call = function(_, className, props, children)
		return new(className, props, children)
	end,
})

function Create.Corner(radius: UDim?)
	return new("UICorner", { CornerRadius = radius or Theme.Radius })
end

function Create.Stroke(color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color or Theme.Color.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.Padding(top: number, right: number?, bottom: number?, left: number?)
	right = right or top
	bottom = bottom or top
	left = left or right
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right :: number),
		PaddingBottom = UDim.new(0, bottom :: number),
		PaddingLeft = UDim.new(0, left :: number),
	})
end

function Create.List(direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 10),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Create.Gradient(sequence: ColorSequence, rotation: number?)
	return new("UIGradient", { Color = sequence, Rotation = rotation or 0 })
end

function Create.Label(props: { [string]: any })
	local defaults = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Medium,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return new("TextLabel", defaults)
end

-- Removes GuiObject children (layouts/corners/padding are kept unless `all`).
function Create.Clear(inst: Instance, all: boolean?)
	for _, child in ipairs(inst:GetChildren()) do
		if all or child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Create
