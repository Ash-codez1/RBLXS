--[[
	StyleController  (StarterPlayerScripts.Client.Controllers.StyleController)
	Your equipped cosmetics as a Style (Shared/Util/Style), kept up to date
	from your data. Applies the menu theme (Backdrop) and lets other screens
	(HUD, menu, reveals, shop previews) show your look.
	StyleController.Get() -> style · StyleController.Changed(style)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Style = require(Shared.Util.Style)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)

local StyleController = {}
StyleController.Priority = 7
StyleController.Changed = Signal.new()

local current = Style.Of({})
local lastKey = ""

function StyleController.Get()
	return current
end

-- A preview of your look with one item swapped in (shop previews).
function StyleController.With(item)
	local data = DataController.Get()
	local equipped = table.clone(if data then data.Inventory.Equipped else {})
	if item then
		equipped[item.Slot] = item.Id
	end
	return Style.Of(equipped)
end

local function refresh(data)
	local equipped = data and data.Inventory and data.Inventory.Equipped or {}
	local parts = {}
	for slot, id in pairs(equipped) do
		table.insert(parts, slot .. "=" .. tostring(id))
	end
	table.sort(parts)
	local key = table.concat(parts, ",")
	if key == lastKey then
		return
	end
	lastKey = key
	current = Style.Of(equipped)
	if current.Backdrop then
		UIController.SetBackdropColors(Color3.fromHex(current.Backdrop[1]), Color3.fromHex(current.Backdrop[2]))
	else
		UIController.SetBackdropColors(nil)
	end
	StyleController.Changed:Fire(current)
end

function StyleController.Init() end

function StyleController.Start()
	DataController.Changed:Connect(refresh)
	if DataController.Get() then
		refresh(DataController.Get())
	end
end

return StyleController
