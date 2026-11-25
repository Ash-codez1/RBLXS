--[[
	StoreService  (ServerScriptService.Server.Services.StoreService)
	Legitimate Robux purchases via MarketplaceService (ids in Data/Monetisation).

	Developer products (coin packs): MarketplaceService.ProcessReceipt
	  • each PurchaseId is granted at most once (profile.ProcessedReceipts)
	  • Coins are granted, then the profile is SAVED, and only then do we
	    tell Roblox PurchaseGranted. If anything fails we answer
	    NotProcessedYet, and Roblox safely retries later.
	Game passes (VIP, 2× Coins):
	  • on every join, ownership comes from Roblox (UserOwnsGamePassAsync);
	  • when Roblox reports a purchase in this server (the server-side
	    PromptGamePassPurchaseFinished), the pass applies straight away, as
	    Roblox's own guide does. Roblox caches ownership, so a pass bought
	    in-game can still read as "not owned" for the rest of the session.
	    Until Roblox confirms ownership, the pass is marked unverified
	    (data.PassesUnverified) and is re-checked on the next join; it is
	    removed if Roblox says it isn't owned (or can't say).
	  • Remotes never grant passes: the client's word is never trusted.
	GetStoreInfo(): real names and Robux prices from Roblox (GetProductInfo).
	Unconfigured ids (0) are hidden: no placeholder buttons, nothing fake.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Config = require(Shared.Config)
local Monetisation = require(Shared.Data.Monetisation)
local TableUtil = require(Shared.Util.TableUtil)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local StoreService = {}
StoreService.Priority = 16
StoreService.PassChanged = Signal.new() -- (player, key, owned)
StoreService.CoinsPurchased = Signal.new() -- (player, coins)

-- Looked up on demand so ids pasted into Data/Monetisation are always current.
local function productFor(id: number)
	for _, product in ipairs(Monetisation.Products) do
		if product.Id ~= 0 and product.Id == id then
			return product
		end
	end
	return nil
end

local function passKeys(): { [number]: string }
	local map = {}
	for key, pass in pairs(Monetisation.Passes) do
		if pass.Id ~= 0 then
			map[pass.Id] = key
		end
	end
	return map
end

function StoreService.HasPass(player: Player, key: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Passes[key] == true
end

local function ownsPass(player: Player, passId: number): boolean?
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		return owned == true
	end
	return nil -- unknown (Roblox unreachable): keep the cached value
end

-- verified = Roblox confirmed ownership (UserOwnsGamePassAsync).
local function setPass(player: Player, key: string, owned: boolean, verified: boolean): boolean
	local changed = false
	DataService.Update(player, function(d)
		d.PassesUnverified = d.PassesUnverified or {}
		if (d.Passes[key] == true) ~= owned then
			changed = true
		end
		d.Passes[key] = owned or nil
		d.PassesUnverified[key] = if owned and not verified then true else nil
	end)
	if changed then
		StoreService.PassChanged:Fire(player, key, owned)
		if key == "VIP" then
			ShopService.Sanitize(player)
		end
	end
	return changed
end

function StoreService.IsVerified(player: Player, key: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Passes[key] == true and not (data.PassesUnverified and data.PassesUnverified[key])
end

-- On join: Roblox's answer is fresh when a player enters a server.
function StoreService.RefreshPasses(player: Player)
	for passId, key in pairs(passKeys()) do
		local owned = ownsPass(player, passId)
		if owned ~= nil then
			setPass(player, key, owned, true)
		elseif StoreService.HasPass(player, key) and not StoreService.IsVerified(player, key) then
			-- Roblox unreachable: keep confirmed passes, but an unconfirmed one
			-- waits until Roblox can confirm it.
			setPass(player, key, false, false)
		end
	end
end

-- ===== Developer products =====
function StoreService.ProcessReceipt(receipt)
	local player = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == receipt.PlayerId then
			player = p
		end
	end
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- they left; Roblox retries next time
	end
	local product = productFor(receipt.ProductId)
	if not product then
		warn("[StoreService] Receipt for an unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitForData(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.ProcessedReceipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted earlier
	end
	DataService.Update(player, function(d)
		d.Coins += product.Coins
		d.Lifetime.CoinsBought += product.Coins
		table.insert(d.ProcessedReceipts, receipt.PurchaseId)
		TableUtil.TrimArray(d.ProcessedReceipts, Config.MaxProcessedReceipts)
	end)
	if not DataService.SaveNow(player) then
		-- Keep the in-memory grant (the receipt id blocks a double grant if
		-- Roblox retries in this session), but don't confirm until it's saved.
		warn("[StoreService] Couldn't save after a purchase; Roblox will retry")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	StoreService.CoinsPurchased:Fire(player, product.Coins)
	Net.Fire("Notify", player, { Title = product.Icon .. " Thank you!", Text = ("+%d Coins added to your account."):format(product.Coins), Kind = "Important" })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== Store info for the client =====
local infoCache = {}
local function productInfo(id: number, infoType)
	local cached = infoCache[id]
	if cached and os.clock() - cached.Time < 300 then
		return cached.Info
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if ok and type(info) == "table" then
		infoCache[id] = { Info = info, Time = os.clock() }
		return info
	end
	return nil
end

function StoreService.Info(player: Player)
	local products, passes = {}, {}
	for _, product in ipairs(Monetisation.Products) do
		if product.Id ~= 0 then
			local info = productInfo(product.Id, Enum.InfoType.Product)
			if info and info.PriceInRobux then
				table.insert(products, { Key = product.Key, Id = product.Id, Coins = product.Coins, Name = product.Name, Icon = product.Icon, Price = info.PriceInRobux })
			end
		end
	end
	for _, key in ipairs(Monetisation.PassOrder) do
		local pass = Monetisation.Passes[key]
		if pass.Id ~= 0 then
			local info = productInfo(pass.Id, Enum.InfoType.GamePass)
			if info and info.PriceInRobux then
				table.insert(passes, { Key = key, Id = pass.Id, Name = pass.Name, Icon = pass.Icon, Description = pass.Description, Price = info.PriceInRobux, Owned = StoreService.HasPass(player, key) })
			end
		end
	end
	return { Products = products, Passes = passes }
end

function StoreService.Init()
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(StoreService.RefreshPasses, player)
	end)
end

function StoreService.Start()
	MarketplaceService.ProcessReceipt = StoreService.ProcessReceipt
	-- Fired on the server by Roblox's purchase prompt (not one of our remotes).
	local checking = {} -- [player] = { [passId] = true } while confirming
	Players.PlayerRemoving:Connect(function(player)
		checking[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeys()[passId]
		if not key or not purchased or not DataService.Get(player) then
			return
		end
		if StoreService.IsVerified(player, key) then
			return -- already confirmed (repeat events change nothing)
		end
		local pass = Monetisation.Passes[key]
		if setPass(player, key, true, false) then
			Net.Fire("Notify", player, { Title = pass.Icon .. " " .. pass.Name .. " unlocked!", Text = "Thank you for supporting the game.", Kind = "Important" })
		end
		checking[player] = checking[player] or {}
		if checking[player][passId] then
			return -- a confirmation is already running
		end
		checking[player][passId] = true
		-- Confirm with Roblox when its cache allows; otherwise on the next join.
		for attempt = 1, 3 do
			if player.Parent == nil then
				break
			end
			if ownsPass(player, passId) then
				setPass(player, key, true, true)
				break
			end
			task.wait(attempt * 2)
		end
		if checking[player] then
			checking[player][passId] = nil
		end
	end)
	Net.Handle("GetStoreInfo", function(player)
		return true, StoreService.Info(player)
	end)
end

return StoreService
