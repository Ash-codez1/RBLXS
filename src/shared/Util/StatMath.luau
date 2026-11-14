--[[
	StatMath  (ReplicatedStorage.Shared.Util.StatMath)
	Pure stat arithmetic shared by the server (authoritative) and the client
	(consequence previews). Contains no game state.
]]

local Config = require(script.Parent.Parent.Config)
local StatDefinitions = require(script.Parent.Parent.Data.StatDefinitions)

local StatMath = {}

function StatMath.Clamp(value: number): number
	return math.clamp(value, Config.StatMin, Config.StatMax)
end

--[[
	Diminishing returns: gains are smaller near the top of the scale and losses
	are smaller near the bottom, so stats rarely sit pinned at 0 or 100 and
	earlier choices keep mattering.
	  effective = delta * (room / 50) clamped to [0.35, 1.25]
]]
function StatMath.Scale(current: number, delta: number): number
	if delta == 0 then
		return 0
	end
	local room = if delta > 0 then Config.StatMax - current else current - Config.StatMin
	local factor = math.clamp(room / 50, 0.35, 1.25)
	return delta * factor
end

--[[
	Applies `deltas` ({ StatName = number }) to a copy of `stats`.
	Unknown stat names and non-finite numbers are ignored.
	Returns newStats, applied (the real change per stat after scaling + clamping).
]]
function StatMath.Apply(stats: { [string]: number }, deltas: { [string]: number }, multipliers: { [string]: number }?)
	local result = table.clone(stats)
	local applied = {}
	for name, delta in pairs(deltas) do
		if StatDefinitions.IsValid(name) and type(delta) == "number" and delta == delta and math.abs(delta) ~= math.huge then
			local m = multipliers and multipliers[name] or 1
			local current = result[name] or Config.StatStart
			local nextValue = StatMath.Clamp(current + StatMath.Scale(current, delta * m))
			nextValue = math.floor(nextValue * 10 + 0.5) / 10 -- one decimal place
			applied[name] = nextValue - current
			result[name] = nextValue
		end
	end
	return result, applied
end

-- Average of all eight stats; used by Life Reveal and endings.
function StatMath.Overall(stats: { [string]: number }): number
	local total = 0
	for _, name in ipairs(StatDefinitions.Order) do
		total += stats[name] or Config.StatStart
	end
	return total / #StatDefinitions.Order
end

--[[
	Maps net worth (in-life money + assets) to the 0-100 Wealth stat on a log
	scale: $0 -> 0, $10k -> 50, $1M -> 75, $100M+ -> 100.
]]
function StatMath.WealthFromNetWorth(netWorth: number): number
	if netWorth <= 0 then
		return 0
	end
	return StatMath.Clamp(math.log10(netWorth + 1) * 12.5)
end

return StatMath
