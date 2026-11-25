--[[
	Catalog  (ReplicatedStorage.Shared.Data.Catalog)
	Every cosmetic item in the shop. Bought with Coins (earned by playing, or
	coin packs bought with Robux). ALL ITEMS ARE COSMETIC: they change how
	your life looks (avatar, home, car, pet, name, title, themes, effects)
	and never its choices, stats or money. No pay-to-win.

	Item = { Id, Name, Category, Slot, Icon, Rarity, Price, Description, VipOnly?, ...style }
	One item can be equipped per Slot. VipOnly items are free with the VIP
	game pass (Data/Monetisation) and can't be bought with Coins.

	Style fields by slot:
	  Hair: Face (emoji used as your avatar's face) · NameColor: Color (hex)
	  Title: Text · Backdrop: Colors { hex, hex } · RevealEffect: Glyphs { emoji... }
	  Aura: Aura { Kind = "Sparkles"|"Fire"|"Smoke", Color, Secondary? }
	  Other slots use Icon.
]]

local Catalog = {}

Catalog.Categories = {
	{ Id = "Clothing", Name = "Clothing", Icon = "👕" },
	{ Id = "Hairstyles", Name = "Hairstyles", Icon = "💇" },
	{ Id = "Accessories", Name = "Accessories", Icon = "🎩" },
	{ Id = "Houses", Name = "Houses", Icon = "🏡" },
	{ Id = "Apartments", Name = "Apartments", Icon = "🏢" },
	{ Id = "Cars", Name = "Cars", Icon = "🚗" },
	{ Id = "Pets", Name = "Pets", Icon = "🐶" },
	{ Id = "Furniture", Name = "Furniture", Icon = "🛋️" },
	{ Id = "Lifestyle", Name = "Lifestyle", Icon = "✨" },
	{ Id = "Effects", Name = "Effects", Icon = "🎆" },
}

Catalog.Slots = {
	Outfit = { Name = "Outfit", Category = "Clothing" },
	Hair = { Name = "Look", Category = "Hairstyles" },
	Accessory = { Name = "Accessory", Category = "Accessories" },
	House = { Name = "House style", Category = "Houses" },
	Apartment = { Name = "Apartment style", Category = "Apartments" },
	Car = { Name = "Car", Category = "Cars" },
	Pet = { Name = "Pet", Category = "Pets" },
	Furniture = { Name = "Centrepiece", Category = "Furniture" },
	Title = { Name = "Title", Category = "Lifestyle" },
	NameColor = { Name = "Name colour", Category = "Lifestyle" },
	Backdrop = { Name = "Theme", Category = "Lifestyle" },
	RevealEffect = { Name = "Reveal effect", Category = "Effects" },
	Aura = { Name = "Aura", Category = "Effects" },
}
Catalog.SlotOrder = { "Hair", "Outfit", "Accessory", "Pet", "House", "Apartment", "Car", "Furniture", "Title", "NameColor", "Backdrop", "RevealEffect", "Aura" }

Catalog.Rarities = {
	Common = { Color = "#ACB1D6", Order = 1 },
	Rare = { Color = "#6C8CFF", Order = 2 },
	Epic = { Color = "#B48CFF", Order = 3 },
	Legendary = { Color = "#FFD45A", Order = 4 },
	VIP = { Color = "#FF5A8C", Order = 5 },
}

local function item(t)
	return t
end

Catalog.Items = {
	-- ===== Clothing =====
	item({ Id = "Outfit_Tee", Name = "Casual Tee", Category = "Clothing", Slot = "Outfit", Icon = "👕", Rarity = "Common", Price = 120, Description = "Simple, comfy, timeless." }),
	item({ Id = "Outfit_Denim", Name = "Denim Jacket", Category = "Clothing", Slot = "Outfit", Icon = "🧥", Rarity = "Common", Price = 150, Description = "Effortlessly cool." }),
	item({ Id = "Outfit_Sports", Name = "Sports Kit", Category = "Clothing", Slot = "Outfit", Icon = "🎽", Rarity = "Common", Price = 180, Description = "Always ready for kick-off." }),
	item({ Id = "Outfit_Suit", Name = "Sharp Suit", Category = "Clothing", Slot = "Outfit", Icon = "👔", Rarity = "Rare", Price = 400, Description = "Dress for the job you want." }),
	item({ Id = "Outfit_Dress", Name = "Party Dress", Category = "Clothing", Slot = "Outfit", Icon = "👗", Rarity = "Rare", Price = 400, Description = "Made for dancing." }),
	item({ Id = "Outfit_LabCoat", Name = "Lab Coat", Category = "Clothing", Slot = "Outfit", Icon = "🥼", Rarity = "Rare", Price = 450, Description = "For brilliant minds." }),
	item({ Id = "Outfit_Kimono", Name = "Silk Kimono", Category = "Clothing", Slot = "Outfit", Icon = "👘", Rarity = "Epic", Price = 900, Description = "Elegant and graceful." }),
	item({ Id = "Outfit_Golden", Name = "Golden Robes", Category = "Clothing", Slot = "Outfit", Icon = "🌟", Rarity = "VIP", Price = 0, VipOnly = true, Description = "VIP exclusive. Shine everywhere you go." }),

	-- ===== Hairstyles & looks =====
	item({ Id = "Hair_Bald", Name = "Shaved Head", Category = "Hairstyles", Slot = "Hair", Icon = "🧑‍🦲", Face = "🧑‍🦲", Rarity = "Common", Price = 100, Description = "Low maintenance, high confidence." }),
	item({ Id = "Hair_Curly", Name = "Curly Hair", Category = "Hairstyles", Slot = "Hair", Icon = "🧑‍🦱", Face = "🧑‍🦱", Rarity = "Common", Price = 120, Description = "Bouncy curls." }),
	item({ Id = "Hair_Red", Name = "Red Hair", Category = "Hairstyles", Slot = "Hair", Icon = "🧑‍🦰", Face = "🧑‍🦰", Rarity = "Common", Price = 150, Description = "Fiery and bold." }),
	item({ Id = "Hair_Blond", Name = "Blond Hair", Category = "Hairstyles", Slot = "Hair", Icon = "👱", Face = "👱", Rarity = "Common", Price = 150, Description = "Sunny and bright." }),
	item({ Id = "Hair_Silver", Name = "Silver Fox", Category = "Hairstyles", Slot = "Hair", Icon = "🧑‍🦳", Face = "🧑‍🦳", Rarity = "Rare", Price = 350, Description = "Distinguished at any age." }),
	item({ Id = "Hair_Prince", Name = "Prince Look", Category = "Hairstyles", Slot = "Hair", Icon = "🤴", Face = "🤴", Rarity = "Epic", Price = 1000, Description = "Royalty, obviously." }),
	item({ Id = "Hair_Princess", Name = "Princess Look", Category = "Hairstyles", Slot = "Hair", Icon = "👸", Face = "👸", Rarity = "Epic", Price = 1000, Description = "Royalty, obviously." }),
	item({ Id = "Hair_Wizard", Name = "Wizard Look", Category = "Hairstyles", Slot = "Hair", Icon = "🧙", Face = "🧙", Rarity = "Epic", Price = 1200, Description = "A little bit magical." }),
	item({ Id = "Hair_Fairy", Name = "Fairy Look", Category = "Hairstyles", Slot = "Hair", Icon = "🧚", Face = "🧚", Rarity = "Epic", Price = 1200, Description = "Sprinkled with stardust." }),
	item({ Id = "Hair_Hero", Name = "Superhero Look", Category = "Hairstyles", Slot = "Hair", Icon = "🦸", Face = "🦸", Rarity = "Legendary", Price = 2000, Description = "Saving the day, every day." }),

	-- ===== Accessories =====
	item({ Id = "Acc_Cap", Name = "Baseball Cap", Category = "Accessories", Slot = "Accessory", Icon = "🧢", Rarity = "Common", Price = 100, Description = "Backwards, of course." }),
	item({ Id = "Acc_Shades", Name = "Cool Shades", Category = "Accessories", Slot = "Accessory", Icon = "🕶️", Rarity = "Common", Price = 150, Description = "The future's so bright." }),
	item({ Id = "Acc_Bow", Name = "Big Bow", Category = "Accessories", Slot = "Accessory", Icon = "🎀", Rarity = "Common", Price = 150, Description = "Adorable." }),
	item({ Id = "Acc_Headphones", Name = "Headphones", Category = "Accessories", Slot = "Accessory", Icon = "🎧", Rarity = "Rare", Price = 350, Description = "Your life has a soundtrack." }),
	item({ Id = "Acc_TopHat", Name = "Top Hat", Category = "Accessories", Slot = "Accessory", Icon = "🎩", Rarity = "Rare", Price = 400, Description = "Fancy." }),
	item({ Id = "Acc_Grad", Name = "Graduation Cap", Category = "Accessories", Slot = "Accessory", Icon = "🎓", Rarity = "Rare", Price = 450, Description = "Top of the class (in spirit)." }),
	item({ Id = "Acc_Clover", Name = "Lucky Clover", Category = "Accessories", Slot = "Accessory", Icon = "🍀", Rarity = "Epic", Price = 800, Description = "Feels lucky. (It's just for show!)" }),
	item({ Id = "Acc_Crown", Name = "Crown", Category = "Accessories", Slot = "Accessory", Icon = "👑", Rarity = "VIP", Price = 0, VipOnly = true, Description = "VIP exclusive." }),

	-- ===== Houses (style of your House / Mansion and in reveal scenes) =====
	item({ Id = "House_Cottage", Name = "Country Cottage", Category = "Houses", Slot = "House", Icon = "🏡", Rarity = "Common", Price = 200, Description = "Roses round the door." }),
	item({ Id = "House_Cabin", Name = "Log Cabin", Category = "Houses", Slot = "House", Icon = "🛖", Rarity = "Rare", Price = 500, Description = "Cosy, by the lake." }),
	item({ Id = "House_Beach", Name = "Beach Villa", Category = "Houses", Slot = "House", Icon = "🏖️", Rarity = "Epic", Price = 1200, Description = "Waves outside the window." }),
	item({ Id = "House_Japanese", Name = "Japanese Villa", Category = "Houses", Slot = "House", Icon = "🏯", Rarity = "Epic", Price = 1500, Description = "Gardens and calm." }),
	item({ Id = "House_Castle", Name = "Castle", Category = "Houses", Slot = "House", Icon = "🏰", Rarity = "Legendary", Price = 2500, Description = "Every life deserves a turret." }),
	item({ Id = "House_Manor", Name = "Grand Manor", Category = "Houses", Slot = "House", Icon = "🏛️", Rarity = "VIP", Price = 0, VipOnly = true, Description = "VIP exclusive." }),

	-- ===== Apartments (style of your Apartment) =====
	item({ Id = "Apt_Loft", Name = "City Loft", Category = "Apartments", Slot = "Apartment", Icon = "🏢", Rarity = "Common", Price = 200, Description = "Exposed brick, big windows." }),
	item({ Id = "Apt_Studio", Name = "Downtown Studio", Category = "Apartments", Slot = "Apartment", Icon = "🏙️", Rarity = "Rare", Price = 450, Description = "Right in the middle of everything." }),
	item({ Id = "Apt_Penthouse", Name = "Sky Penthouse", Category = "Apartments", Slot = "Apartment", Icon = "🌆", Rarity = "Epic", Price = 1300, Description = "The whole city at your feet." }),
	item({ Id = "Apt_Tower", Name = "Tower Suite", Category = "Apartments", Slot = "Apartment", Icon = "🗼", Rarity = "Legendary", Price = 2200, Description = "The highest address in town." }),

	-- ===== Cars =====
	item({ Id = "Car_Hatch", Name = "Hatchback", Category = "Cars", Slot = "Car", Icon = "🚗", Rarity = "Common", Price = 150, Description = "Reliable and red." }),
	item({ Id = "Car_SUV", Name = "SUV", Category = "Cars", Slot = "Car", Icon = "🚙", Rarity = "Common", Price = 200, Description = "Room for everyone." }),
	item({ Id = "Car_Pickup", Name = "Pickup Truck", Category = "Cars", Slot = "Car", Icon = "🛻", Rarity = "Rare", Price = 400, Description = "Built tough." }),
	item({ Id = "Car_Camper", Name = "Camper Van", Category = "Cars", Slot = "Car", Icon = "🚐", Rarity = "Rare", Price = 450, Description = "Home is wherever you park it." }),
	item({ Id = "Car_Moto", Name = "Motorbike", Category = "Cars", Slot = "Car", Icon = "🏍️", Rarity = "Rare", Price = 500, Description = "Wind in your hair." }),
	item({ Id = "Car_Vintage", Name = "Vintage Ride", Category = "Cars", Slot = "Car", Icon = "🚘", Rarity = "Epic", Price = 900, Description = "They don't make them like this any more." }),
	item({ Id = "Car_Super", Name = "Supercar", Category = "Cars", Slot = "Car", Icon = "🏎️", Rarity = "Legendary", Price = 2500, Description = "Zero to sixty in a blink." }),

	-- ===== Pets (a companion shown with your avatar) =====
	item({ Id = "Pet_Bunny", Name = "Bunny", Category = "Pets", Slot = "Pet", Icon = "🐰", Rarity = "Common", Price = 180, Description = "Hop hop." }),
	item({ Id = "Pet_Dog", Name = "Puppy", Category = "Pets", Slot = "Pet", Icon = "🐶", Rarity = "Common", Price = 200, Description = "Your biggest fan." }),
	item({ Id = "Pet_Cat", Name = "Kitten", Category = "Pets", Slot = "Pet", Icon = "🐱", Rarity = "Common", Price = 200, Description = "Judges you lovingly." }),
	item({ Id = "Pet_Parrot", Name = "Parrot", Category = "Pets", Slot = "Pet", Icon = "🦜", Rarity = "Rare", Price = 450, Description = "Repeats everything. Everything." }),
	item({ Id = "Pet_Fox", Name = "Fox", Category = "Pets", Slot = "Pet", Icon = "🦊", Rarity = "Rare", Price = 500, Description = "Clever and curious." }),
	item({ Id = "Pet_Panda", Name = "Panda", Category = "Pets", Slot = "Pet", Icon = "🐼", Rarity = "Epic", Price = 1100, Description = "Mostly eats and naps." }),
	item({ Id = "Pet_Dragon", Name = "Baby Dragon", Category = "Pets", Slot = "Pet", Icon = "🐉", Rarity = "Legendary", Price = 3000, Description = "Warm cuddles. Very warm." }),
	item({ Id = "Pet_Unicorn", Name = "Unicorn", Category = "Pets", Slot = "Pet", Icon = "🦄", Rarity = "VIP", Price = 0, VipOnly = true, Description = "VIP exclusive." }),

	-- ===== Furniture (the centrepiece of your home showcase) =====
	item({ Id = "Furn_Plant", Name = "Big Plant", Category = "Furniture", Slot = "Furniture", Icon = "🪴", Rarity = "Common", Price = 100, Description = "Brings life to any room." }),
	item({ Id = "Furn_Sofa", Name = "Comfy Sofa", Category = "Furniture", Slot = "Furniture", Icon = "🛋️", Rarity = "Common", Price = 120, Description = "You'll never want to get up." }),
	item({ Id = "Furn_Art", Name = "Masterpiece Painting", Category = "Furniture", Slot = "Furniture", Icon = "🖼️", Rarity = "Rare", Price = 400, Description = "Very cultured." }),
	item({ Id = "Furn_Telescope", Name = "Telescope", Category = "Furniture", Slot = "Furniture", Icon = "🔭", Rarity = "Rare", Price = 450, Description = "For stargazing nights." }),
	item({ Id = "Furn_Arcade", Name = "Arcade Machine", Category = "Furniture", Slot = "Furniture", Icon = "🕹️", Rarity = "Rare", Price = 500, Description = "High score: you." }),
	item({ Id = "Furn_Piano", Name = "Grand Piano", Category = "Furniture", Slot = "Furniture", Icon = "🎹", Rarity = "Epic", Price = 900, Description = "Fills the house with music." }),
	item({ Id = "Furn_Fountain", Name = "Fountain", Category = "Furniture", Slot = "Furniture", Icon = "⛲", Rarity = "Legendary", Price = 1800, Description = "For the garden. Obviously." }),

	-- ===== Lifestyle upgrades: titles, name colours, themes =====
	item({ Id = "Title_Dreamer", Name = "Title: The Dreamer", Category = "Lifestyle", Slot = "Title", Icon = "💭", Text = "The Dreamer", Rarity = "Common", Price = 150, Description = "Shown under your name to other players." }),
	item({ Id = "Title_Kind", Name = "Title: Kind Soul", Category = "Lifestyle", Slot = "Title", Icon = "💛", Text = "Kind Soul", Rarity = "Common", Price = 150, Description = "Shown under your name to other players." }),
	item({ Id = "Title_Boss", Name = "Title: The Boss", Category = "Lifestyle", Slot = "Title", Icon = "💼", Text = "The Boss", Rarity = "Rare", Price = 400, Description = "Shown under your name to other players." }),
	item({ Id = "Title_Explorer", Name = "Title: World Explorer", Category = "Lifestyle", Slot = "Title", Icon = "🧭", Text = "World Explorer", Rarity = "Rare", Price = 400, Description = "Shown under your name to other players." }),
	item({ Id = "Title_Legend", Name = "Title: Living Legend", Category = "Lifestyle", Slot = "Title", Icon = "🌟", Text = "Living Legend", Rarity = "Epic", Price = 1000, Description = "Shown under your name to other players." }),
	item({ Id = "Title_VIP", Name = "Title: VIP", Category = "Lifestyle", Slot = "Title", Icon = "⭐", Text = "VIP", Rarity = "VIP", Price = 0, VipOnly = true, Description = "VIP exclusive title." }),
	item({ Id = "Name_Sky", Name = "Sky Blue Name", Category = "Lifestyle", Slot = "NameColor", Icon = "🔵", Color = "#6CA0FF", Rarity = "Common", Price = 200, Description = "Your name in sky blue." }),
	item({ Id = "Name_Mint", Name = "Mint Name", Category = "Lifestyle", Slot = "NameColor", Icon = "🟢", Color = "#58DC91", Rarity = "Rare", Price = 350, Description = "Your name in fresh mint." }),
	item({ Id = "Name_Purple", Name = "Purple Name", Category = "Lifestyle", Slot = "NameColor", Icon = "🟣", Color = "#B48CFF", Rarity = "Rare", Price = 350, Description = "Your name in royal purple." }),
	item({ Id = "Name_Gold", Name = "Golden Name", Category = "Lifestyle", Slot = "NameColor", Icon = "🟡", Color = "#FFD45A", Rarity = "Epic", Price = 900, Description = "Your name in gold." }),
	item({ Id = "Backdrop_Forest", Name = "Forest Theme", Category = "Lifestyle", Slot = "Backdrop", Icon = "🌲", Colors = { "#0B2E1E", "#2E6B4A" }, Rarity = "Common", Price = 250, Description = "A calm green menu background." }),
	item({ Id = "Backdrop_Sunset", Name = "Sunset Theme", Category = "Lifestyle", Slot = "Backdrop", Icon = "🌅", Colors = { "#2B1055", "#FF7E5F" }, Rarity = "Rare", Price = 400, Description = "A warm sunset menu background." }),
	item({ Id = "Backdrop_Ocean", Name = "Ocean Theme", Category = "Lifestyle", Slot = "Backdrop", Icon = "🌊", Colors = { "#0F2027", "#2C5364" }, Rarity = "Rare", Price = 400, Description = "A deep blue menu background." }),
	item({ Id = "Backdrop_Galaxy", Name = "Galaxy Theme", Category = "Lifestyle", Slot = "Backdrop", Icon = "🌌", Colors = { "#0B0B2B", "#5B2A86" }, Rarity = "Epic", Price = 900, Description = "A starry purple menu background." }),

	-- ===== Cosmetic effects =====
	item({ Id = "Fx_Confetti", Name = "Confetti Reveal", Category = "Effects", Slot = "RevealEffect", Icon = "🎉", Glyphs = { "🎉", "🎊" }, Rarity = "Common", Price = 200, Description = "Confetti rains down during your Life Reveals." }),
	item({ Id = "Fx_Hearts", Name = "Hearts Reveal", Category = "Effects", Slot = "RevealEffect", Icon = "💖", Glyphs = { "💖", "💕", "💗" }, Rarity = "Rare", Price = 450, Description = "Hearts float up during your Life Reveals." }),
	item({ Id = "Fx_Fireworks", Name = "Fireworks Reveal", Category = "Effects", Slot = "RevealEffect", Icon = "🎆", Glyphs = { "🎆", "🎇", "✨" }, Rarity = "Rare", Price = 500, Description = "Fireworks light up your Life Reveals." }),
	item({ Id = "Fx_Stars", Name = "Shooting Stars", Category = "Effects", Slot = "RevealEffect", Icon = "🌠", Glyphs = { "🌠", "⭐", "✨" }, Rarity = "Epic", Price = 900, Description = "Stars streak across your Life Reveals." }),
	item({ Id = "Fx_Money", Name = "Money Rain", Category = "Effects", Slot = "RevealEffect", Icon = "💸", Glyphs = { "💸", "💵", "🪙" }, Rarity = "Legendary", Price = 1800, Description = "It's raining money (just for show)." }),
	item({ Id = "Aura_Mist", Name = "Mystic Mist", Category = "Effects", Slot = "Aura", Icon = "🌫️", Aura = { Kind = "Smoke", Color = "#B48CFF" }, Rarity = "Rare", Price = 450, Description = "A swirl of purple mist around your character." }),
	item({ Id = "Aura_Sparkle", Name = "Sparkle Aura", Category = "Effects", Slot = "Aura", Icon = "✨", Aura = { Kind = "Sparkles", Color = "#FFFFFF" }, Rarity = "Rare", Price = 500, Description = "Sparkles follow your character around." }),
	item({ Id = "Aura_Fire", Name = "Fire Aura", Category = "Effects", Slot = "Aura", Icon = "🔥", Aura = { Kind = "Fire", Color = "#FF6A00", Secondary = "#FFD000" }, Rarity = "Epic", Price = 1200, Description = "Harmless flames for a fiery entrance." }),
	item({ Id = "Aura_Gold", Name = "Golden Aura", Category = "Effects", Slot = "Aura", Icon = "🌟", Aura = { Kind = "Sparkles", Color = "#FFD45A" }, Rarity = "VIP", Price = 0, VipOnly = true, Description = "VIP exclusive." }),
}

Catalog.ById = {}
for _, entry in ipairs(Catalog.Items) do
	Catalog.ById[entry.Id] = entry
end

function Catalog.Get(id: any)
	return if type(id) == "string" then Catalog.ById[id] else nil
end

function Catalog.InCategory(categoryId: string)
	local list = {}
	for _, entry in ipairs(Catalog.Items) do
		if entry.Category == categoryId then
			table.insert(list, entry)
		end
	end
	return list
end

-- Case-insensitive search over name, description and category.
function Catalog.Search(query: string, categoryId: string?)
	local q = string.lower(query or "")
	local list = {}
	for _, entry in ipairs(Catalog.Items) do
		if not categoryId or entry.Category == categoryId then
			local haystack = string.lower(entry.Name .. " " .. entry.Description .. " " .. entry.Category .. " " .. entry.Rarity)
			if q == "" or haystack:find(q, 1, true) then
				table.insert(list, entry)
			end
		end
	end
	return list
end

-- Checks the catalog itself; returns a list of problems (used by tests and at startup).
function Catalog.Validate()
	local problems, seen, categories = {}, {}, {}
	for _, c in ipairs(Catalog.Categories) do
		categories[c.Id] = true
	end
	for _, entry in ipairs(Catalog.Items) do
		if seen[entry.Id] then
			table.insert(problems, "duplicate item " .. entry.Id)
		end
		seen[entry.Id] = true
		if not categories[entry.Category] then
			table.insert(problems, entry.Id .. ": unknown category")
		end
		local slot = Catalog.Slots[entry.Slot]
		if not slot then
			table.insert(problems, entry.Id .. ": unknown slot")
		elseif slot.Category ~= entry.Category then
			table.insert(problems, entry.Id .. ": slot belongs to another category")
		end
		if not Catalog.Rarities[entry.Rarity] then
			table.insert(problems, entry.Id .. ": unknown rarity")
		end
		if entry.VipOnly then
			if entry.Price ~= 0 or entry.Rarity ~= "VIP" then
				table.insert(problems, entry.Id .. ": VIP items are free with VIP and marked VIP")
			end
		elseif type(entry.Price) ~= "number" or entry.Price <= 0 or entry.Price % 1 ~= 0 then
			table.insert(problems, entry.Id .. ": needs a positive whole price")
		end
		if entry.Slot == "Hair" and not entry.Face then
			table.insert(problems, entry.Id .. ": looks need a Face")
		elseif entry.Slot == "NameColor" and not (type(entry.Color) == "string" and entry.Color:match("^#%x%x%x%x%x%x$")) then
			table.insert(problems, entry.Id .. ": name colours need a #RRGGBB Color")
		elseif entry.Slot == "Title" and type(entry.Text) ~= "string" then
			table.insert(problems, entry.Id .. ": titles need Text")
		elseif entry.Slot == "Backdrop" and not (entry.Colors and #entry.Colors == 2) then
			table.insert(problems, entry.Id .. ": themes need two Colors")
		elseif entry.Slot == "RevealEffect" and not (entry.Glyphs and #entry.Glyphs >= 1) then
			table.insert(problems, entry.Id .. ": reveal effects need Glyphs")
		elseif entry.Slot == "Aura" and not (entry.Aura and entry.Aura.Kind) then
			table.insert(problems, entry.Id .. ": auras need Aura settings")
		end
	end
	return problems
end

return Catalog
