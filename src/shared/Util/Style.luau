--[[
	Style  (ReplicatedStorage.Shared.Util.Style)
	Turns equipped cosmetics into a "look" used everywhere:
	avatar face + outfit + accessory + pet, title, name colour, home/car
	styles in Life Reveal scenes, menu theme, reveal effect, character aura.

	Style.Of(equipped) -> style table (defaults for empty slots)
	Style.Public(equipped) -> the parts other players see (safe to send)
	Cosmetics are public by design: they're for showing off.
]]

local Catalog = require(script.Parent.Parent.Data.Catalog)

local Style = {}

Style.DefaultFace = "🧑"

function Style.Of(equipped)
	equipped = equipped or {}
	local function get(slot)
		return Catalog.Get(equipped[slot])
	end
	local hair, title, nameColor, backdrop, effect, aura = get("Hair"), get("Title"), get("NameColor"), get("Backdrop"), get("RevealEffect"), get("Aura")
	local function icon(slot)
		local entry = get(slot)
		return entry and entry.Icon or nil
	end
	return {
		Face = if hair then hair.Face else Style.DefaultFace,
		Outfit = icon("Outfit"),
		Accessory = icon("Accessory"),
		Pet = icon("Pet"),
		House = icon("House"),
		Apartment = icon("Apartment"),
		Car = icon("Car"),
		Furniture = icon("Furniture"),
		Title = if title then title.Text else nil,
		NameColor = if nameColor then nameColor.Color else nil,
		Backdrop = if backdrop then backdrop.Colors else nil,
		RevealGlyphs = if effect then effect.Glyphs else nil,
		Aura = if aura then aura.Aura else nil,
	}
end

-- The subset shown to other players (avatar, title, name colour).
function Style.Public(equipped)
	local s = Style.Of(equipped)
	return { Face = s.Face, Outfit = s.Outfit, Accessory = s.Accessory, Pet = s.Pet, Title = s.Title, NameColor = s.NameColor }
end

-- One-line avatar, e.g. "🧑‍🦱👔🎩 🐶"
function Style.AvatarText(style): string
	local text = style.Face .. (style.Outfit or "") .. (style.Accessory or "")
	if style.Pet then
		text ..= " " .. style.Pet
	end
	return text
end

return Style
