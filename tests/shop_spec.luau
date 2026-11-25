--[[
	Shop, inventory, coins and Robux purchase tests. Called from tests/run.luau.
]]

local task = require("@lune/task")

return function(H)
	local test, eq, ok, section = H.test, H.eq, H.ok, H.section
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")

	local store = MockDataStore.new()
	local saveFails = false
	local failingStore = setmetatable({}, { __index = function(_, key)
		local fn = store[key]
		if key == "UpdateAsync" then
			return function(self, k, transform)
				if saveFails then
					error("DataStore is down")
				end
				return fn(store, k, transform)
			end
		end
		return function(_, ...)
			return fn(store, ...)
		end
	end })
	local server = H.new({
		Quiet = true,
		JobId = "shop",
		DataStoreService = {
			GetDataStore = function()
				return failingStore
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		},
	})
	server.run("ServerScriptService.Server.Main")
	task.wait(0.02)
	local Shop = server.require("ServerScriptService.Server.Services.ShopService")
	local StoreService = server.require("ServerScriptService.Server.Services.StoreService")
	local Cosmetics = server.require("ServerScriptService.Server.Services.CosmeticsService")
	local DS = server.require("ServerScriptService.Server.Services.DataService")
	local LS = server.require("ServerScriptService.Server.Services.LifeService")
	local Catalog = server.require("ReplicatedStorage.Shared.Data.Catalog")
	local Monetisation = server.require("ReplicatedStorage.Shared.Data.Monetisation")
	local Style = server.require("ReplicatedStorage.Shared.Util.Style")
	local DT = server.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local Config = server.require("ReplicatedStorage.Shared.Config")
	local Market = server.game:GetService("MarketplaceService")

	local player = server.addPlayer(4001, "Shopper")
	task.wait(0.05)
	local function data()
		return DS.Get(player)
	end
	local function setCoins(n)
		DS.Update(player, function(d)
			d.Coins = n
		end)
	end

	section("Catalog")
	test("Catalog is valid, cosmetic-only, and covers every category", function()
		eq(#Catalog.Validate(), 0, table.concat(Catalog.Validate(), "; "))
		eq(#Catalog.Categories, 10)
		for _, c in ipairs(Catalog.Categories) do
			ok(#Catalog.InCategory(c.Id) >= 4, c.Id .. " has at least 4 items")
		end
		ok(#Catalog.Items >= 70, "a big catalog")
		-- Cosmetic only: items have no gameplay fields (stats, money, effects on a life).
		for _, item in ipairs(Catalog.Items) do
			for _, field in ipairs({ "Stats", "Effects", "Money", "Bonus", "Multiplier" }) do
				eq(item[field], nil, item.Id .. " has no gameplay field " .. field)
			end
		end
	end)

	test("Search finds items by name, description, category and rarity", function()
		local function ids(list)
			local set = {}
			for _, i in ipairs(list) do
				set[i.Id] = true
			end
			return set
		end
		ok(ids(Catalog.Search("dragon")).Pet_Dragon, "by name")
		ok(ids(Catalog.Search("LEGENDARY")).Car_Super, "case-insensitive rarity")
		ok(ids(Catalog.Search("castle", "Houses")).House_Castle, "within a category")
		eq(next(Catalog.Search("castle", "Pets")), nil, "category filter applies")
		eq(#Catalog.Search(""), #Catalog.Items, "empty search shows everything")
	end)

	section("Buying and equipping (Coins)")
	test("Buying is validated: unknown, too expensive, VIP-only", function()
		setCoins(100)
		eq(select(2, Shop.Buy(player, "Nope")), "NoSuchItem")
		eq(select(2, Shop.Buy(player, { "Pet_Dog" })), "NoSuchItem")
		eq(select(2, Shop.Buy(player, "Pet_Dog")), "NotEnoughCoins")
		eq(select(2, Shop.Buy(player, "Acc_Crown")), "NeedVIP", "VIP items can't be bought with Coins")
		eq(data().Coins, 100, "nothing charged")
	end)

	test("A purchase charges once, owns and equips the item", function()
		setCoins(1000)
		local okB, res = Shop.Buy(player, "Pet_Dog")
		ok(okB, "bought")
		eq(res.Coins, 800)
		eq(data().Inventory.Owned.Pet_Dog, true)
		eq(data().Inventory.Equipped.Pet, "Pet_Dog", "auto-equipped")
		eq(select(2, Shop.Buy(player, "Pet_Dog")), "AlreadyOwned")
		eq(data().Coins, 800, "no double charge")
		eq(data().Lifetime.CoinsSpent, 200)
	end)

	test("Equip needs ownership; unequip restores the default look", function()
		eq(select(2, Shop.Equip(player, "Pet_Cat")), "NotOwned")
		Shop.Buy(player, "Pet_Cat")
		eq(data().Inventory.Equipped.Pet, "Pet_Cat")
		ok((Shop.Equip(player, "Pet_Dog")), "re-equip the dog")
		eq(data().Inventory.Equipped.Pet, "Pet_Dog")
		eq(select(2, Shop.Unequip(player, "Wings")), "BadSlot")
		ok((Shop.Unequip(player, "Pet")))
		eq(data().Inventory.Equipped.Pet, nil)
		Shop.Buy(player, "Hair_Curly")
		eq(Style.Of(data().Inventory.Equipped).Face, "🧑‍🦱", "look changes the avatar")
	end)

	test("Remotes are wired", function()
		setCoins(500)
		eq((server.remote("ShopBuy").OnServerInvoke(player, "Acc_Cap")), true)
		eq((server.remote("ShopEquip").OnServerInvoke(player, "Acc_Cap")), true)
		eq((server.remote("ShopUnequip").OnServerInvoke(player, "Accessory")), true)
		eq(select(2, server.remote("ShopBuy").OnServerInvoke(player, 42)), "NoSuchItem")
	end)

	section("Robux: developer products (coin packs)")
	Monetisation.Products[1].Id = 111
	Monetisation.Products[2].Id = 222
	local function receipt(id, productId)
		return Market.ProcessReceipt({ PurchaseId = id, PlayerId = 4001, ProductId = productId, CurrencySpent = 99 })
	end
	test("ProcessReceipt is installed and grants coins exactly once per receipt", function()
		eq(Market.ProcessReceipt, StoreService.ProcessReceipt, "handler installed")
		setCoins(0)
		eq(receipt("r-1", 111), H.Enum.ProductPurchaseDecision.PurchaseGranted)
		eq(data().Coins, 500)
		eq(receipt("r-1", 111), H.Enum.ProductPurchaseDecision.PurchaseGranted, "retry of the same receipt")
		eq(data().Coins, 500, "not granted twice")
		eq(receipt("r-2", 222), H.Enum.ProductPurchaseDecision.PurchaseGranted)
		eq(data().Coins, 2000)
		eq(data().Lifetime.CoinsBought, 2000)
		local saved = store:GetAsync("Player_4001")
		eq(saved.Data.Coins, 2000, "saved before confirming")
	end)

	test("Unknown products, absent players and failed saves are NOT confirmed", function()
		eq(receipt("r-3", 999), H.Enum.ProductPurchaseDecision.NotProcessedYet, "unknown product")
		eq(Market.ProcessReceipt({ PurchaseId = "r-4", PlayerId = 123456, ProductId = 111 }), H.Enum.ProductPurchaseDecision.NotProcessedYet, "player not here")
		saveFails = true
		local coins = data().Coins
		eq(receipt("r-5", 111), H.Enum.ProductPurchaseDecision.NotProcessedYet, "save failed: Roblox will retry")
		saveFails = false
		eq(receipt("r-5", 111), H.Enum.ProductPurchaseDecision.PurchaseGranted, "the retry is confirmed")
		eq(data().Coins, coins + 500, "granted once across the retry")
	end)

	section("Robux: game passes")
	Monetisation.Passes.VIP.Id = 7001
	Monetisation.Passes.CoinBooster.Id = 7002
	test("No remote can grant a pass; only Roblox's purchase signal or ownership check", function()
		for _, name in ipairs({ "ShopBuy", "ShopEquip", "ShopUnequip" }) do
			server.remote(name).OnServerInvoke(player, "VIP")
		end
		eq(data().Passes.VIP, nil, "no pass from remotes")
		Market.PromptGamePassPurchaseFinished:Fire(player, 7001, false)
		Market.PromptGamePassPurchaseFinished:Fire(player, 9999, true)
		task.wait(0.1)
		eq(data().Passes.VIP, nil, "cancelled or unknown passes ignored")
	end)

	test("A pass bought in this server applies at once; Roblox confirms it", function()
		Market.OwnedPasses["4001:7001"] = true
		Market.PromptGamePassPurchaseFinished:Fire(player, 7001, true)
		task.wait(0.1)
		eq(data().Passes.VIP, true, "VIP granted")
		eq(StoreService.IsVerified(player, "VIP"), true, "confirmed by Roblox")
		ok((Shop.Buy(player, "Acc_Crown")), "VIP items are free with VIP")
		eq(data().Inventory.Equipped.Accessory, "Acc_Crown")
	end)

	test("If Roblox's cache still says 'not owned', the pass works this session and is re-checked on join", function()
		-- Roblox documents that ownership can read false right after an in-game purchase.
		Market.PromptGamePassPurchaseFinished:Fire(player, 7002, true)
		task.wait(0.1)
		eq(data().Passes.CoinBooster, true, "applies straight away")
		eq(StoreService.IsVerified(player, "CoinBooster"), false, "awaiting confirmation")
		eq(data().PassesUnverified.CoinBooster, true)
		Market.PromptGamePassPurchaseFinished:Fire(player, 7002, true)
		task.wait(0.1)
		eq(data().Passes.CoinBooster, true, "repeat events are harmless")
		-- Next join: Roblox says they don't own it → removed.
		StoreService.RefreshPasses(player)
		eq(data().Passes.CoinBooster, nil, "unconfirmed pass removed when Roblox says not owned")
		eq(data().PassesUnverified.CoinBooster, nil)
		-- An unconfirmed pass also waits if Roblox can't answer; confirmed ones are kept.
		Market.PromptGamePassPurchaseFinished:Fire(player, 7002, true)
		task.wait(0.1)
		Market.Unavailable = true
		StoreService.RefreshPasses(player)
		Market.Unavailable = false
		eq(data().Passes.CoinBooster, nil, "unconfirmed + Roblox down → removed for now")
		eq(data().Passes.VIP, true, "confirmed VIP kept while Roblox is down")
		-- Real owner on the next join → confirmed.
		Market.OwnedPasses["4001:7002"] = true
		StoreService.RefreshPasses(player)
		eq(data().Passes.CoinBooster, true)
		eq(StoreService.IsVerified(player, "CoinBooster"), true)
		Market.OwnedPasses["4001:7002"] = nil
		StoreService.RefreshPasses(player)
		eq(data().Passes.CoinBooster, nil, "clean state for the coin tests")
	end)

	test("Losing VIP unequips VIP items; Roblox being down keeps the cached pass", function()
		Market.Unavailable = true
		StoreService.RefreshPasses(player)
		eq(data().Passes.VIP, true, "unknown → keep cached")
		Market.Unavailable = false
		Market.OwnedPasses["4001:7001"] = nil
		StoreService.RefreshPasses(player)
		eq(data().Passes.VIP, nil, "pass gone")
		eq(data().Inventory.Equipped.Accessory, nil, "VIP item unequipped")
		eq(data().Inventory.Owned.Acc_Crown, true, "but kept, ready if VIP returns")
		eq(select(2, Shop.Equip(player, "Acc_Crown")), "NeedVIP")
	end)

	test("Store info shows real prices only for configured ids", function()
		local okI, info = server.remote("GetStoreInfo").OnServerInvoke(player)
		eq(okI, true)
		eq(#info.Products, 2, "only products with ids")
		ok(info.Products[1].Price > 0, "price from Roblox")
		eq(#info.Passes, 2)
		Monetisation.Products[2].Id = 0
		local _, info2 = server.remote("GetStoreInfo").OnServerInvoke(player)
		eq(#info2.Products, 1, "unconfigured products are hidden")
	end)

	section("Coins earned by playing")
	local function playStage()
		local out
		for _ = 1, 10 do
			local okS, sc = LS.GetScenario(player)
			if not okS then
				break
			end
			local choice
			for _, c in ipairs(sc.Choices) do
				if not c.Locked then
					choice = c
					break
				end
			end
			local _, o = LS.MakeChoice(player, sc.Id, choice.Id)
			out = o
			if o.StageCompleted then
				break
			end
		end
		return out
	end
	test("Completing a stage pays Coins; 2× Coins doubles play rewards only", function()
		DS.Update(player, function(d)
			d.Slots.Slot1 = DT.NewLife("Earner", 5)
			d.ActiveSlot = "Slot1"
		end)
		local before = data().Coins
		local out = playStage()
		eq(out.Reveal.Coins, Config.StageCoins)
		eq(data().Coins, before + Config.StageCoins)
		Market.OwnedPasses["4001:7002"] = true
		StoreService.RefreshPasses(player)
		eq(data().Passes.CoinBooster, true)
		out = playStage()
		eq(out.Reveal.Coins, Config.StageCoins * 2, "doubled with 2× Coins")
		local coins = data().Coins
		receipt("r-6", 111)
		eq(data().Coins, coins + 500, "bought coins are never doubled")
	end)

	section("Cosmetics on the character, and for other players")
	test("Name tag (title, name colour) and aura are built on the character", function()
		local character = H.newInstance("Model", "Shopper")
		for _, name in ipairs({ "Head", "HumanoidRootPart" }) do
			H.newInstance("Part", name).Parent = character
		end
		H.newInstance("Humanoid", "Humanoid").Parent = character
		player.Character = character
		setCoins(5000)
		Shop.Buy(player, "Title_Boss")
		Shop.Buy(player, "Name_Gold")
		Shop.Buy(player, "Aura_Fire")
		Cosmetics.Apply(player)
		local tag = character.Head:FindFirstChild("CYL_NameTag")
		ok(tag, "name tag")
		eq(tag:FindFirstChild("Title").Text, "The Boss")
		eq(character.HumanoidRootPart:FindFirstChild("CYL_Aura").ClassName, "Fire")
		Shop.Unequip(player, "Aura")
		Cosmetics.Apply(player)
		eq(character.HumanoidRootPart:FindFirstChild("CYL_Aura"), nil, "removed when unequipped")
		local count = 0
		for _, child in ipairs(character.Head:GetChildren()) do
			if child.Name == "CYL_NameTag" then
				count += 1
			end
		end
		eq(count, 1, "reapplying never duplicates")
	end)

	test("Other players see your look (avatar, title, name colour)", function()
		local RevealService = server.require("ServerScriptService.Server.Services.RevealService")
		local card = RevealService.CardFor(player, player)
		eq(card.Style.Title, "The Boss")
		eq(card.Style.NameColor, "#FFD45A")
		eq(card.Style.Face, "🧑‍🦱")
	end)

	server.close()
end
