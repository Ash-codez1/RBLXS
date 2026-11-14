--[[
	Format  (ReplicatedStorage.Shared.Util.Format)
	Display formatting for numbers and money. Pure functions.
]]

local Format = {}

-- 1234567 -> "1,234,567"
function Format.Commas(n: number): string
	local negative = n < 0
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if negative then "-" else "") .. out
end

-- Money: "$950", "$12,500", "$1.25M", "$3.4B"
function Format.Money(n: number): string
	local sign = if n < 0 then "-" else ""
	local a = math.abs(n)
	if a >= 1e9 then
		return ("%s$%.2fB"):format(sign, a / 1e9)
	elseif a >= 1e6 then
		return ("%s$%.2fM"):format(sign, a / 1e6)
	end
	return sign .. "$" .. Format.Commas(a)
end

-- Signed delta with one decimal place, dropping ".0": "+3", "-1.5"
function Format.Signed(n: number): string
	local rounded = math.floor(math.abs(n) * 10 + 0.5) / 10
	local text = if rounded % 1 == 0 then tostring(math.floor(rounded)) else ("%.1f"):format(rounded)
	return (if n < 0 then "-" else "+") .. text
end

return Format
