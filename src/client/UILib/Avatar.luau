--[[
	Avatar  (StarterPlayerScripts.Client.UILib.Avatar)
	Draws a player's look from a Style (Shared/Util/Style): a big face with
	accessory, outfit and pet badges, and a name with name colour + title.

	Avatar.Badge({ Style, Size?, Parent?, LayoutOrder?, Name? }) -> Frame
	Avatar.NameRich(name, style) -> RichText string (coloured name)
	Avatar.Line(name, style) -> "🧑‍🦱 Name" with name colour, for one-line labels
]]

local Theme = require(script.Parent.Theme)
local Create = require(script.Parent.Create)

local Avatar = {}

function Avatar.Badge(p)
	local style = p.Style or {}
	local size = p.Size or 72
	local frame = Create("Frame", {
		Name = p.Name or "Avatar",
		BackgroundColor3 = Theme.Color.SurfaceHigher,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = p.LayoutOrder or 0,
		Parent = p.Parent,
	}, { Create.Corner(Theme.RadiusPill), Create.Stroke(if style.NameColor then Color3.fromHex(style.NameColor) else Theme.Color.Stroke, 2, 0.1) })
	local function glyph(name, text, scale, anchor, position)
		if not text then
			return
		end
		Create.Label({
			Name = name,
			Text = text,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(size * scale, size * scale),
			AnchorPoint = anchor,
			Position = position,
			Parent = frame,
		})
	end
	glyph("Face", style.Face or "🧑", 0.66, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	glyph("Accessory", style.Accessory, 0.36, Vector2.new(1, 0), UDim2.fromScale(1.05, -0.05))
	glyph("Outfit", style.Outfit, 0.32, Vector2.new(1, 1), UDim2.fromScale(1.05, 1.05))
	glyph("Pet", style.Pet, 0.34, Vector2.new(0, 1), UDim2.fromScale(-0.08, 1.05))
	return frame
end

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Avatar.NameRich(name: string, style): string
	local safe = escape(name)
	if style and style.NameColor then
		return ("<font color=\"%s\">%s</font>"):format(style.NameColor, safe)
	end
	return safe
end

function Avatar.Line(name: string, style): string
	return ((style and style.Face) or "🧑") .. " " .. Avatar.NameRich(name, style) .. (if style and style.Title then (" <font color=\"%s\">· %s</font>"):format(Theme.Hex.Gold, escape(style.Title)) else "")
end

return Avatar
