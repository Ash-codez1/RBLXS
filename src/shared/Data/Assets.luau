--[[
	Assets  (ReplicatedStorage.Shared.Data.Assets)
	Big purchases a life can make through choices (homes, cars...). They count
	toward net worth, so they raise the Wealth stat. In-life only: these are
	separate from the cosmetic shop items bought with Coins (Phase 7).
]]

local Assets = {}

Assets.Info = {
	Apartment = { Title = "Apartment", Icon = "🏢", Value = 60000, Kind = "Home" },
	House = { Title = "Family House", Icon = "🏡", Value = 260000, Kind = "Home" },
	Mansion = { Title = "Mansion", Icon = "🏰", Value = 2500000, Kind = "Home" },
	HolidayHome = { Title = "Holiday Home", Icon = "🏝️", Value = 400000, Kind = "Home" },
	Car = { Title = "Car", Icon = "🚗", Value = 18000, Kind = "Vehicle" },
	SportsCar = { Title = "Sports Car", Icon = "🏎️", Value = 180000, Kind = "Vehicle" },
	Yacht = { Title = "Yacht", Icon = "🛥️", Value = 1500000, Kind = "Vehicle" },
}

function Assets.IsValid(id: any): boolean
	return type(id) == "string" and Assets.Info[id] ~= nil
end

function Assets.TotalValue(owned: { [string]: any }): number
	local total = 0
	for id in pairs(owned) do
		local info = Assets.Info[id]
		if info then
			total += info.Value
		end
	end
	return total
end

return Assets
