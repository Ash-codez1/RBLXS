--[[
	StatService  (ServerScriptService.Server.Services.StatService)
	Authoritative stat changes for the active life. Decision, event, career and
	relationship systems (later phases) call StatService.Apply; nothing on the
	client can change stats directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatMath = require(Shared.Util.StatMath)
local Signal = require(Shared.Util.Signal)

local DataService = require(script.Parent.DataService)

local StatService = {}
StatService.Priority = 10

StatService.StatsChanged = Signal.new() -- (player, applied, reason)

--[[
	Applies deltas to the active life. `multipliers` lets traits amplify or dampen
	specific stats (e.g. a "Resilient" trait halves Health losses).
	Returns the actually-applied deltas, or nil if the player has no active life.
]]
function StatService.Apply(player: Player, deltas: { [string]: number }, reason: string, multipliers: { [string]: number }?)
	local applied
	local ok = DataService.Update(player, function(data)
		local life = data.Slots[data.ActiveSlot]
		if type(life) ~= "table" or life.Completed then
			return
		end
		local newStats
		newStats, applied = StatMath.Apply(life.Stats, deltas, multipliers)
		life.Stats = newStats
	end)
	if ok and applied then
		StatService.StatsChanged:Fire(player, applied, reason)
		return applied
	end
	return nil
end

function StatService.Get(player: Player): { [string]: number }?
	local life = DataService.GetActiveLife(player)
	return life and table.clone(life.Stats)
end

-- Recomputes the Wealth stat from money + asset value (called by economy systems).
function StatService.SyncWealth(player: Player, netWorth: number)
	DataService.Update(player, function(data)
		local life = data.Slots[data.ActiveSlot]
		if type(life) == "table" then
			life.Stats.Wealth = StatMath.WealthFromNetWorth(netWorth)
		end
	end)
end

function StatService.Init() end
function StatService.Start() end

return StatService
