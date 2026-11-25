--[[
	ShopController  (StarterPlayerScripts.Client.Controllers.ShopController)
	The 🛍️ Shop screen (main menu → Shop):
	  • search box and category tabs (All + 10 categories)
	  • item cards with icon, rarity, price / Owned / Equipped / VIP
	  • a preview of each item ON YOUR LOOK before you buy (avatar, home &
	    car scene, name tag, theme swatch, falling reveal effect...)
	  • purchase confirmation, then buy, equip or unequip
	  • 🪙 Get Coins: real Robux coin packs and passes (only shown when the
	    game has them set up; prices come from Roblox)
	Everything is cosmetic. The server validates every purchase (ShopService).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Catalog = require(Shared.Data.Catalog)
local Format = require(Shared.Util.Format)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)
local Avatar = require(UILib.Avatar)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local StyleController = require(script.Parent.StyleController)

local ShopController = {}
ShopController.Priority = 51

local frame: CanvasGroup
local category: string? = nil -- nil = All
local query = ""
local storeInfo = nil
local busy = false
local grid: Frame? = nil

local ERRORS = {
	NotEnoughCoins = "You don't have enough Coins yet. Play to earn more!",
	AlreadyOwned = "You already own this.",
	NeedVIP = "This is a VIP exclusive.",
	NotOwned = "You don't own this yet.",
	RateLimited = "Slow down a moment.",
}

local function data()
	return DataController.Get()
end

local function owns(item): boolean
	local d = data()
	return d ~= nil and d.Inventory.Owned[item.Id] == true
end

local function equipped(item): boolean
	local d = data()
	return d ~= nil and d.Inventory.Equipped[item.Slot] == item.Id
end

local function hasVip(): boolean
	local d = data()
	return d ~= nil and d.Passes ~= nil and d.Passes.VIP == true
end

local function priceText(item): string
	if equipped(item) then
		return "✅ Equipped"
	elseif owns(item) then
		return "Owned"
	elseif item.VipOnly then
		return "⭐ VIP"
	end
	return "🪙 " .. Format.Commas(item.Price)
end

local renderGrid
local openItem

local function act(remote: string, arg, successText: string?)
	if busy then
		return false
	end
	busy = true
	local ok, result = Net.Invoke(remote, arg)
	busy = false
	if ok then
		if successText then
			NotificationController.Notify({ Title = "🛍️ Shop", Text = successText, Kind = "Success", Duration = 2.5 })
		end
	else
		NotificationController.Notify({ Title = "🛍️ Shop", Text = ERRORS[result] or tostring(result), Kind = "Warning" })
	end
	return ok
end

-- ===== Item preview =====
local function previewBox(parent, item)
	local box = Create("Frame", { Name = "Preview", BackgroundColor3 = Theme.Color.Background, Size = UDim2.new(1, 0, 0, 190), LayoutOrder = 1, ClipsDescendants = true, Parent = parent }, { Create.Corner(Theme.RadiusSmall) })
	local style = StyleController.With(item)
	local d = data()
	local name = (d and DataController.GetActiveLife() and DataController.GetActiveLife().Name) or Players.LocalPlayer.DisplayName or "You"
	local slot = item.Slot
	if slot == "Backdrop" then
		Create.Gradient(ColorSequence.new(Color3.fromHex(item.Colors[1]), Color3.fromHex(item.Colors[2])), 120).Parent = box
		box.BackgroundColor3 = Theme.Color.White
		Create.Label({ Text = "Your menus will look like this", FontFace = Theme.Font.Bold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = box })
	elseif slot == "House" or slot == "Apartment" or slot == "Car" or slot == "Furniture" then
		local scene = (style.House or style.Apartment or "🏠") .. "  " .. (style.Car or "") .. "  " .. (style.Furniture or "")
		Create.Label({ Text = item.Icon, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0.62, 0), Parent = box })
		Create.Label({ Text = "Your life: " .. scene, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.66), Size = UDim2.new(1, 0, 0.3, 0), Parent = box })
	elseif slot == "RevealEffect" then
		Create.Label({ Text = "LIFE REVEAL", FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = box })
		local rng = Random.new()
		for i = 1, 14 do
			local g = Create.Label({ Name = "Fx" .. i, Text = item.Glyphs[(i - 1) % #item.Glyphs + 1], TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(rng:NextNumber(0, 0.95), 0, -0.2, 0), Parent = box })
			Anim.Tween(g, { Position = UDim2.new(g.Position.X.Scale, 0, 1.1, 0) }, rng:NextNumber(1.2, 2.4), Enum.EasingStyle.Linear)
		end
	elseif slot == "Aura" then
		Create.Label({ Text = style.Face .. item.Icon, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0.6, 0), Parent = box })
		Create.Label({ Text = "Surrounds your character in the world", TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.65), Size = UDim2.new(1, 0, 0.3, 0), Parent = box })
	else
		local badge = Avatar.Badge({ Style = style, Size = 120, Parent = box })
		badge.AnchorPoint = Vector2.new(0.5, 0)
		badge.Position = UDim2.new(0.5, 0, 0, 14)
		Create.Label({ Name = "PreviewName", Text = Avatar.Line(name, style), RichText = true, FontFace = Theme.Font.Bold, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 28), Parent = box })
	end
	return box
end

local function promptPass(key: string)
	if not storeInfo then
		return false
	end
	for _, pass in ipairs(storeInfo.Passes) do
		if pass.Key == key and not pass.Owned then
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
			end)
			return true
		end
	end
	return false
end

function openItem(item)
	local handle = UIController.OpenPanel({ Name = "ItemModal", Title = item.Icon .. "  " .. item.Name, Width = 620 })
	handle.Subtitle.Text = ("%s · %s · %s"):format(item.Rarity, Catalog.Slots[item.Slot].Name, priceText(item))
	local scroll = handle.Scroll
	previewBox(scroll, item)
	Create.Label({ Text = item.Description, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	Create.Label({ Text = "✨ Cosmetic only: it never changes your life's choices, stats or money.", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = scroll })
	local d = data()
	local function refresh()
		task.wait(0.25)
		if handle.IsOpen() then
			openItem(item)
		end
		if UIController.Current() == "Shop" then
			renderGrid()
		end
	end
	local buttonProps = { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 10, Parent = scroll }
	local function button(props)
		for k, v in pairs(buttonProps) do
			props[k] = props[k] or v
		end
		return Components.Button(props)
	end
	if owns(item) then
		if equipped(item) then
			button({ Name = "Unequip", Text = "Unequip", Icon = "↩️", Style = "Secondary", OnClick = function()
				if act("ShopUnequip", item.Slot) then
					refresh()
				end
			end })
		elseif item.VipOnly and not hasVip() then
			button({ Name = "NeedVip", Text = "Needs VIP to wear", Icon = "⭐", Style = "Secondary" })
		else
			button({ Name = "Equip", Text = "Equip", Icon = "✅", Style = "Primary", OnClick = function()
				if act("ShopEquip", item.Id, item.Name .. " equipped!") then
					refresh()
				end
			end })
		end
	elseif item.VipOnly then
		if hasVip() then
			button({ Name = "ClaimVip", Text = "Claim free with VIP", Icon = "⭐", Style = "Primary", OnClick = function()
				if act("ShopBuy", item.Id, item.Name .. " is yours!") then
					refresh()
				end
			end })
		else
			local available = storeInfo ~= nil and #storeInfo.Passes > 0
			local vip = button({ Name = "GetVip", Text = if available then "Get VIP" else "VIP isn't available yet", Icon = "⭐", Style = if available then "Accent" else "Secondary", OnClick = function()
				promptPass("VIP")
			end })
			if not available then
				Components.SetDisabled(vip, true)
			end
		end
	else
		local coins = d and d.Coins or 0
		local buy = button({ Name = "Buy", Text = ("Buy for %s Coins"):format(Format.Commas(item.Price)), Icon = "🪙", Style = "Primary", OnClick = function()
			local confirmed = UIController.Confirm({
				Title = "Buy " .. item.Name .. "?",
				Text = ("It costs %s Coins. You have %s."):format(Format.Commas(item.Price), Format.Commas(coins)),
				ConfirmText = "Buy",
			})
			if confirmed and act("ShopBuy", item.Id, item.Name .. " bought and equipped!") then
				refresh()
			end
		end })
		if coins < item.Price then
			Components.SetDisabled(buy, true)
			Create.Label({ Text = ("You need %s more Coins. Finish stages and lives to earn them."):format(Format.Commas(item.Price - coins)), TextColor3 = Theme.Color.Warning, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 11, Parent = scroll })
		end
	end
end

-- ===== Get Coins (Robux) =====
local function openCoins()
	local handle = UIController.OpenPanel({ Name = "CoinsModal", Title = "🪙  Get Coins", Width = 640 })
	handle.Subtitle.Text = "Purchases are handled securely by Roblox"
	local scroll = handle.Scroll
	local info = storeInfo or { Products = {}, Passes = {} }
	local order = 0
	for _, product in ipairs(info.Products) do
		order += 1
		Components.Button({ Name = "Product_" .. product.Key, Text = ("%s %s Coins · %s  (R$ %d)"):format(product.Icon, Format.Commas(product.Coins), product.Name, product.Price), Style = "Primary", Size = UDim2.new(1, 0, 0, 56), TextSize = 18, LayoutOrder = order, Parent = scroll, OnClick = function()
			pcall(function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
			end)
		end })
	end
	for _, pass in ipairs(info.Passes) do
		order += 1
		local panel = Components.Panel({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 14, LayoutOrder = 100 + order, Parent = scroll, Color = Theme.Color.SurfaceHigh })
		Create.List(Enum.FillDirection.Vertical, 6).Parent = panel
		Create.Label({ Text = pass.Icon .. "  " .. pass.Name, FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = panel })
		Create.Label({ Text = pass.Description, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
		local passButton = Components.Button({ Name = "Pass_" .. pass.Key, Text = if pass.Owned then "Owned ✓" else ("Get it  (R$ %d)"):format(pass.Price), Style = if pass.Owned then "Secondary" else "Accent", Size = UDim2.fromOffset(220, 48), LayoutOrder = 3, Parent = panel, OnClick = function()
			if not pass.Owned then
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
				end)
			end
		end })
		if pass.Owned then
			Components.SetDisabled(passButton, true)
		end
	end
	if order == 0 then
		Create.Label({ Text = "Coin packs and passes aren't set up for this game yet. You can earn Coins by playing: completing stages and lives, and joining group and city events.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	end
	Create.Label({ Text = "Fair play: everything you can buy is cosmetic. Nothing affects your life's choices or outcomes.", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 999, Parent = scroll })
end

-- ===== Grid =====
function renderGrid()
	if not grid then
		return
	end
	Create.Clear(grid)
	local narrow = UIController.IsNarrow()
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	local columns = if narrow then 2 else 5
	local available = math.min(1100, UIController.GetVirtualSize().X - 40)
	local cellWidth = math.floor((available - 12 * (columns - 1)) / columns)
	if layout then
		layout.CellSize = UDim2.fromOffset(cellWidth, 176)
	end
	local items = Catalog.Search(query, category)
	table.sort(items, function(a, b)
		local ra, rb = Catalog.Rarities[a.Rarity].Order, Catalog.Rarities[b.Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return a.Price < b.Price
	end)
	for i, item in ipairs(items) do
		local rarity = Catalog.Rarities[item.Rarity]
		local card = Create("TextButton", {
			Name = "Item_" .. item.Id,
			Text = "",
			AutoButtonColor = false,
			Selectable = true,
			BackgroundColor3 = Theme.Color.Surface,
			LayoutOrder = i,
			Parent = grid,
		}, { Create.Corner(Theme.RadiusSmall), Create.Stroke(Color3.fromHex(rarity.Color), if equipped(item) then 3 else 1.5, if equipped(item) then 0 else 0.3), Create.Padding(10) })
		Create.Label({ Text = item.Icon, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 72), Parent = card })
		Create.Label({ Text = item.Name, FontFace = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 40), Parent = card })
		Create.Label({ Name = "Price", Text = priceText(item), FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Small, TextColor3 = if owns(item) then Theme.Color.Positive else Color3.fromHex(rarity.Color), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 24), Parent = card })
		card.Activated:Connect(function()
			if Components.OnClickSound then
				Components.OnClickSound()
			end
			openItem(item)
		end)
	end
	if #items == 0 then
		Create.Label({ Text = "Nothing matches that search.", TextColor3 = Theme.Color.TextDim, Size = UDim2.fromOffset(300, 40), LayoutOrder = 1, Parent = grid })
	end
end

local function render()
	Create.Clear(frame, true)
	local header = Layout.Header(frame, "Shop", function()
		UIController.Back()
	end)
	local d = data()
	local coinsChip = Components.Chip({ Text = "🪙 " .. Format.Commas(d and d.Coins or 0), Height = 44, TextSize = Theme.TextSize.Body, Parent = header })
	coinsChip.Name = "Coins"
	coinsChip.AnchorPoint = Vector2.new(1, 0.5)
	coinsChip.Position = UDim2.fromScale(1, 0.5)

	local scroll = Layout.Scroll(frame)
	local width = math.min(1100, UIController.GetVirtualSize().X - 40)
	local column = Layout.Column(scroll, width)

	-- Search + get coins
	local top = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 50), LayoutOrder = 1, Parent = column })
	local hasStore = storeInfo ~= nil and (#storeInfo.Products > 0 or #storeInfo.Passes > 0)
	local search = Create("TextBox", {
		Name = "ShopSearch",
		Text = query,
		PlaceholderText = "🔎 Search items…",
		PlaceholderColor3 = Theme.Color.TextFaint,
		ClearTextOnFocus = false,
		FontFace = Theme.Font.Medium,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Theme.Color.Background,
		Size = UDim2.new(1, if hasStore then -200 else 0, 1, 0),
		Parent = top,
	}, { Create.Corner(Theme.RadiusSmall), Create.Stroke(), Create.Padding(0, 14) })
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if search.Text ~= query then
			query = search.Text
			renderGrid()
		end
	end)
	if hasStore then
		Components.Button({ Name = "GetCoins", Text = "Get Coins", Icon = "🪙", Style = "Accent", Size = UDim2.fromOffset(188, 50), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), TextSize = 18, Parent = top, OnClick = openCoins })
	end

	-- Category tabs
	local tabs = Create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = column })
	local tabList = Create.List(Enum.FillDirection.Horizontal, 8)
	tabList.Wraps = true
	tabList.Parent = tabs
	local entries = { { Id = nil, Name = "All", Icon = "🛍️" } }
	for _, c in ipairs(Catalog.Categories) do
		table.insert(entries, c)
	end
	for i, c in ipairs(entries) do
		local selected = category == c.Id
		Components.Button({
			Name = "Tab_" .. (c.Id or "All"),
			Text = c.Name,
			Icon = c.Icon,
			Style = if selected then "Primary" else "Secondary",
			Size = UDim2.fromOffset(if UIController.IsNarrow() then 150 else 160, 44),
			TextSize = 16,
			LayoutOrder = i,
			Parent = tabs,
			OnClick = function()
				category = c.Id
				render()
			end,
		})
	end

	grid = Create("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = column })
	Create("UIGridLayout", { CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	renderGrid()
	Create.Label({ Text = "Every item is cosmetic. Earn Coins by completing stages (+15) and lives, and by joining group and city events.", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 9, Parent = column })
end

function ShopController.Open(categoryId: string?)
	category = categoryId
	query = ""
	UIController.Show("Shop")
end

function ShopController.Init()
	frame = UIController.NewScreen("Shop", { Back = true, OnOpen = function()
		render()
		task.spawn(function()
			local ok, info = Net.Invoke("GetStoreInfo")
			if ok then
				storeInfo = info
				if UIController.Current() == "Shop" then
					render()
				end
			end
		end)
	end })
end

function ShopController.Start()
	DataController.Changed:Connect(function()
		if UIController.Current() == "Shop" and grid then
			-- Update prices/owned state and the coin balance without losing the search box.
			renderGrid()
			local header = frame:FindFirstChild("Header")
			local chip = header and header:FindFirstChild("Coins")
			local d = data()
			if chip and d then
				chip:FindFirstChild("Label").Text = "🪙 " .. Format.Commas(d.Coins)
			end
		end
	end)
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Shop" then
			render()
		end
	end)
end

return ShopController
