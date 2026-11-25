--[[
	InventoryController  (StarterPlayerScripts.Client.Controllers.InventoryController)
	The 🎒 My Items screen (main menu): your look, what's equipped in every
	slot (change or remove), and everything you own, ready to equip.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Catalog = require(Shared.Data.Catalog)
local Format = require(Shared.Util.Format)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)
local Avatar = require(UILib.Avatar)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local StyleController = require(script.Parent.StyleController)
local ShopController = require(script.Parent.ShopController)

local InventoryController = {}
InventoryController.Priority = 52

local frame: CanvasGroup
local busy = false

local ERRORS = {
	NotOwned = "You don't own that item.",
	NeedVIP = "VIP items need the VIP pass to wear.",
	NoSuchItem = "That item isn't available any more.",
	BadSlot = "That slot doesn't exist.",
	RateLimited = "Slow down a moment.",
}

local function act(remote: string, arg)
	if busy then
		return
	end
	busy = true
	local ok, result = Net.Invoke(remote, arg)
	busy = false
	if not ok then
		NotificationController.Notify({ Title = "🎒 My Items", Text = ERRORS[result] or tostring(result), Kind = "Warning" })
	end
end

local function heading(parent, text: string, order: number)
	Create.Label({ Text = text, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 28), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = parent })
end

local function render()
	Create.Clear(frame, true)
	Layout.Header(frame, "My Items", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(frame)
	local width = math.min(820, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	local data = DataController.Get()
	if not data then
		return
	end
	local style = StyleController.Get()
	local life = DataController.GetActiveLife()
	local name = if life then life.Name else (Players.LocalPlayer.DisplayName or "You")

	-- Your look
	local look = Components.Panel({ Name = "Look", Size = UDim2.fromOffset(width, 120), Padding = 14, LayoutOrder = 1, Parent = column })
	Avatar.Badge({ Style = style, Size = 90, Parent = look })
	Create.Label({ Name = "LookName", Text = Avatar.Line(name, style), RichText = true, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, Position = UDim2.fromOffset(106, 8), Size = UDim2.new(1, -110, 0, 30), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = look })
	local owned = 0
	for _ in pairs(data.Inventory.Owned) do
		owned += 1
	end
	Create.Label({ Text = ("🪙 %s Coins · %d of %d items owned"):format(Format.Commas(data.Coins), owned, #Catalog.Items), TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(106, 44), Size = UDim2.new(1, -110, 0, 24), Parent = look })
	Components.Button({ Name = "OpenShop", Text = "Shop", Icon = "🛍️", Style = "Accent", Size = UDim2.fromOffset(140, 40), Position = UDim2.fromOffset(106, 72), TextSize = 17, Parent = look, OnClick = function()
		ShopController.Open()
	end })

	-- Loadout
	heading(column, "EQUIPPED", 2)
	for i, slotId in ipairs(Catalog.SlotOrder) do
		local slot = Catalog.Slots[slotId]
		local item = Catalog.Get(data.Inventory.Equipped[slotId])
		local row = Create("Frame", { Name = "Slot_" .. slotId, BackgroundColor3 = Theme.Color.SurfaceHigh, BackgroundTransparency = 0.2, Size = UDim2.fromOffset(width, 52), LayoutOrder = 2 + i, Parent = column }, { Create.Corner(Theme.RadiusSmall), Create.Padding(4, 12) })
		Create.Label({ Text = slot.Name, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, Size = UDim2.new(0.28, 0, 1, 0), TextWrapped = false, Parent = row })
		Create.Label({ Name = "Equipped", Text = if item then item.Icon .. " " .. item.Name else "Default", FontFace = Theme.Font.Bold, Position = UDim2.fromScale(0.28, 0), Size = UDim2.new(0.4, 0, 1, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		local buttons = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(230, 40), Parent = row })
		Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = buttons
		Components.Button({ Name = "Change", Text = "Change", Style = "Secondary", Size = UDim2.fromOffset(110, 38), TextSize = 16, LayoutOrder = 1, Parent = buttons, OnClick = function()
			ShopController.Open(slot.Category)
		end })
		if item then
			Components.Button({ Name = "Remove", Text = "Remove", Style = "Ghost", Size = UDim2.fromOffset(110, 38), TextSize = 16, LayoutOrder = 2, Parent = buttons, OnClick = function()
				act("ShopUnequip", slotId)
			end })
		end
	end

	-- Owned items
	heading(column, "YOUR ITEMS", 30)
	local grid = Create("Frame", { Name = "Owned", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 31, Parent = column })
	local columns = if UIController.IsNarrow() then 2 else 4
	Create("UIGridLayout", { CellSize = UDim2.fromOffset(math.floor((width - 10 * (columns - 1)) / columns), 130), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local list = {}
	for _, item in ipairs(Catalog.Items) do
		if data.Inventory.Owned[item.Id] then
			table.insert(list, item)
		end
	end
	for i, item in ipairs(list) do
		local isOn = data.Inventory.Equipped[item.Slot] == item.Id
		local card = Create("Frame", { Name = "Own_" .. item.Id, BackgroundColor3 = Theme.Color.Surface, LayoutOrder = i, Parent = grid }, { Create.Corner(Theme.RadiusSmall), Create.Stroke(if isOn then Theme.Color.Positive else Theme.Color.Stroke, if isOn then 2.5 else 1.5, if isOn then 0 else 0.4), Create.Padding(8) })
		Create.Label({ Text = item.Icon, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 44), Parent = card })
		Create.Label({ Text = item.Name, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Bold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 30), Parent = card })
		if isOn then
			Create.Label({ Name = "On", Text = "✅", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(24, 20), Parent = card })
		end
		Components.Button({ Name = "Toggle", Text = if isOn then "Unequip" else "Equip", Style = if isOn then "Secondary" else "Primary", Size = UDim2.new(1, 0, 0, 34), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), TextSize = 15, Parent = card, OnClick = function()
			if isOn then
				act("ShopUnequip", item.Slot)
			else
				act("ShopEquip", item.Id)
			end
		end })
	end
	if #list == 0 then
		Create.Label({ Text = "You don't own any items yet. Visit the Shop to get your first one!", TextColor3 = Theme.Color.TextDim, Size = UDim2.fromOffset(width, 40), LayoutOrder = 1, Parent = grid })
	end
end

function InventoryController.Init()
	frame = UIController.NewScreen("Inventory", { Back = true, OnOpen = render })
end

function InventoryController.Start()
	DataController.Changed:Connect(function()
		if UIController.Current() == "Inventory" then
			render()
		end
	end)
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Inventory" then
			render()
		end
	end)
end

return InventoryController
