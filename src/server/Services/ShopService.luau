--[[
	ShopService  (ServerScriptService.Server.Services.ShopService)
	The Coin shop and inventory. Everything is validated on the server:
	the client only sends an item id.

	ShopBuy(itemId)      buy with Coins (auto-equips); VIP items are free with VIP
	ShopEquip(itemId)    equip something you own
	ShopUnequip(slot)    back to the default look for that slot
	ShopService.EquipmentChanged(player) fires after any change (Cosmetics).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Catalog = require(Shared.Data.Catalog)

local DataService = require(script.Parent.DataService)

local ShopService = {}
ShopService.Priority = 15
ShopService.EquipmentChanged = Signal.new() -- (player)

local function hasVip(data): boolean
	return data.Passes ~= nil and data.Passes.VIP == true
end

function ShopService.Buy(player: Player, itemId: any)
	local item = Catalog.Get(itemId)
	if not item then
		return false, "NoSuchItem"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	if data.Inventory.Owned[item.Id] then
		return false, "AlreadyOwned"
	end
	if item.VipOnly then
		if not hasVip(data) then
			return false, "NeedVIP"
		end
	elseif data.Coins < item.Price then
		return false, "NotEnoughCoins"
	end
	DataService.Update(player, function(d)
		if not item.VipOnly then
			d.Coins -= item.Price
			d.Lifetime.CoinsSpent += item.Price
		end
		d.Inventory.Owned[item.Id] = true
		d.Inventory.Equipped[item.Slot] = item.Id
	end)
	ShopService.EquipmentChanged:Fire(player)
	return true, { Coins = DataService.Get(player).Coins, Equipped = item.Slot }
end

function ShopService.Equip(player: Player, itemId: any)
	local item = Catalog.Get(itemId)
	if not item then
		return false, "NoSuchItem"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	if not data.Inventory.Owned[item.Id] then
		return false, "NotOwned"
	end
	if item.VipOnly and not hasVip(data) then
		return false, "NeedVIP"
	end
	DataService.Update(player, function(d)
		d.Inventory.Equipped[item.Slot] = item.Id
	end)
	ShopService.EquipmentChanged:Fire(player)
	return true, { Slot = item.Slot }
end

function ShopService.Unequip(player: Player, slot: any)
	if type(slot) ~= "string" or not Catalog.Slots[slot] then
		return false, "BadSlot"
	end
	if not DataService.Update(player, function(d)
		d.Inventory.Equipped[slot] = nil
	end) then
		return false, "NotLoaded"
	end
	ShopService.EquipmentChanged:Fire(player)
	return true
end

--[[
	Removes anything that's no longer valid: unknown items (removed from the
	catalog), items not owned, and VIP items without VIP. Called on join and
	whenever VIP ownership changes.
]]
function ShopService.Sanitize(player: Player)
	DataService.Update(player, function(d)
		for slot, itemId in pairs(d.Inventory.Equipped) do
			local item = Catalog.Get(itemId)
			if not item or item.Slot ~= slot or not d.Inventory.Owned[itemId] or (item.VipOnly and not hasVip(d)) then
				d.Inventory.Equipped[slot] = nil
			end
		end
	end)
	ShopService.EquipmentChanged:Fire(player)
end

function ShopService.Init()
	local problems = Catalog.Validate()
	for _, problem in ipairs(problems) do
		warn("[ShopService] Catalog problem: " .. problem)
	end
	DataService.ProfileLoaded:Connect(function(player)
		ShopService.Sanitize(player)
	end)
end

function ShopService.Start()
	Net.Handle("ShopBuy", ShopService.Buy)
	Net.Handle("ShopEquip", ShopService.Equip)
	Net.Handle("ShopUnequip", ShopService.Unequip)
end

return ShopService
