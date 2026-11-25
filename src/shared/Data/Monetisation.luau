--[[
	Monetisation  (ReplicatedStorage.Shared.Data.Monetisation)
	Real Robux purchases through Roblox's MarketplaceService. Nothing is
	faked: prices shown in the game come from Roblox itself, purchases use
	Roblox's own purchase prompt, and everything is granted by the server
	only after Roblox confirms it (Services/StoreService).

	HOW TO SET UP (once, after publishing the game):
	  1. Creator Dashboard (create.roblox.com) → your experience →
	     Monetization → Passes → create "VIP" and "2× Coins" passes, set a price.
	  2. Monetization → Developer Products → create the coin packs below.
	  3. Paste each Id here. Anything left at 0 is simply hidden in the game.

	Fair play: everything you can buy is cosmetic or speeds up earning
	cosmetic Coins. Nothing affects a life's choices, stats or outcomes.
]]

return {
	Passes = {
		VIP = {
			Id = 0, -- paste your VIP game pass id
			Name = "VIP",
			Icon = "⭐",
			Description = "6 exclusive VIP cosmetics (Crown, Golden Robes, Grand Manor, Unicorn, Golden Aura, VIP title).",
		},
		CoinBooster = {
			Id = 0, -- paste your 2× Coins game pass id
			Name = "2× Coins",
			Icon = "🪙",
			Description = "Earn double Coins from playing (completing stages and lives, group and city events).",
		},
	},
	PassOrder = { "VIP", "CoinBooster" },

	Products = {
		{ Key = "CoinsSmall", Id = 0, Coins = 500, Name = "Pocket of Coins", Icon = "🪙" },
		{ Key = "CoinsMedium", Id = 0, Coins = 1500, Name = "Bag of Coins", Icon = "💰" },
		{ Key = "CoinsLarge", Id = 0, Coins = 4000, Name = "Chest of Coins", Icon = "🧰" },
	},
}
