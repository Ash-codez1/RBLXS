--[[
	CoinRewards  (ServerScriptService.Server.Lib.CoinRewards)
	The one place Coins are earned by PLAYING (not bought). Call inside a
	DataService.Update mutator. The 2× Coins game pass doubles these.

	Sources & amounts (see Config): completing a stage, completing a life
	(score-based, from the Final Reveal), joining group decisions and
	city events.
]]

local CoinRewards = {}

function CoinRewards.Multiplier(data): number
	return if data.Passes and data.Passes.CoinBooster then 2 else 1
end

-- Adds `amount` (× multiplier) and returns what was actually granted.
function CoinRewards.Grant(data, amount: number): number
	if type(amount) ~= "number" or amount <= 0 then
		return 0
	end
	local granted = math.floor(amount * CoinRewards.Multiplier(data))
	data.Coins += granted
	data.Lifetime.CoinsEarned += granted
	data.Lifetime.PlayCoins = (data.Lifetime.PlayCoins or 0) + granted -- for "earn coins by playing" challenges
	return granted
end

-- Rewards that aren't from playing (achievements, challenges, daily rewards):
-- counted as earned, never doubled, and not towards "earn coins" challenges.
function CoinRewards.GrantBonus(data, amount: number): number
	if type(amount) ~= "number" or amount <= 0 then
		return 0
	end
	local granted = math.floor(amount)
	data.Coins += granted
	data.Lifetime.CoinsEarned += granted
	return granted
end

return CoinRewards
