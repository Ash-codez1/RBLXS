--[[
	Prediction calibration report.   lune run tests/tools/calibrate.luau [lives]
	Plays random lives, records Futures.Predict at the end of each stage, then
	compares with Futures.Evaluate at the end of the life. Prints, per future
	and stage: base rate, mean prediction, Brier score vs. the "always guess
	the base rate" baseline (skill > 0 means genuinely predictive), and AUC
	(0.5 = coin flip, 1.0 = perfect ranking).
]]

local process = require("@lune/process")
local task = require("@lune/task")
local H = require("../harness")

local LIVES = tonumber(process.args[1]) or 600 -- usage: calibrate.luau [lives [seed]] | --fit [lives]

local function run(lives: number, seed: number?)
	local MockDataStore = H.new({ Quiet = true }).require("ServerScriptService.Server.Lib.MockDataStore")
	local store = MockDataStore.new()
	local h = H.new({ Quiet = true, JobId = "calib", DataStoreService = {
		GetDataStore = function()
			return store
		end,
		GetRequestBudgetForRequestType = function()
			return 100
		end,
	} })
	h.run("ServerScriptService.Server.Main")
	local player = h.addPlayer(1, "Calib")
	task.wait(0.05)
	local LS = h.require("ServerScriptService.Server.Services.LifeService")
	local DS = h.require("ServerScriptService.Server.Services.DataService")
	local DT = h.require("ReplicatedStorage.Shared.Data.DataTemplate")
	local Futures = h.require("ReplicatedStorage.Shared.Util.Futures")
	local rng = H.Random.new(seed or 2024)
	local records = {} -- records[stage] = { { preds, outcomes } }
	for i = 1, lives do
		DS.Update(player, function(d)
			d.Slots.Slot1 = DT.NewLife("C" .. i, rng:NextInteger(1, 2 ^ 30))
			d.ActiveSlot = "Slot1"
		end)
		local snapshots = {}
		for _ = 1, 60 do
			local life = DS.Get(player).Slots.Slot1
			if rng:NextNumber() < 0.5 and #life.People > 0 then
				local person = life.People[rng:NextInteger(1, #life.People)]
				LS.Interact(player, person.Id, ({ "Time", "Gift", "Talk" })[rng:NextInteger(1, 3)])
			end
			if rng:NextNumber() < 0.1 then
				LS.SetFocus(player, ({ "Balanced", "Career", "Family", "Health", "Social", "Money" })[rng:NextInteger(1, 6)])
			end
			if life.Age >= 18 and life.Money > 1000 and rng:NextNumber() < 0.2 then
				LS.Invest(player, math.floor(life.Money * rng:NextNumber()))
			end
			local okS, sc = LS.GetScenario(player)
			if not okS then
				break
			end
			local open = {}
			for _, c in ipairs(sc.Choices) do
				if not c.Locked then
					table.insert(open, c)
				end
			end
			local _, out = LS.MakeChoice(player, sc.Id, open[rng:NextInteger(1, #open)].Id)
			if out.StageCompleted and not out.LifeCompleted then
				local l = DS.Get(player).Slots.Slot1
				table.insert(snapshots, { Stage = out.PrevStage, Preds = Futures.Predict(l), Raw = Futures.Raw(l), Progress = Futures.Progress(l) })
			end
			if out.LifeCompleted then
				break
			end
		end
		local outcomes = Futures.Evaluate(DS.Get(player).Slots.Slot1)
		for _, snap in ipairs(snapshots) do
			records[snap.Stage] = records[snap.Stage] or {}
			table.insert(records[snap.Stage], { Preds = snap.Preds, Raw = snap.Raw, Progress = snap.Progress, Outcomes = outcomes })
		end
	end
	h.close()
	return records, Futures
end

local function auc(pairs_)
	local pos, neg = {}, {}
	for _, r in ipairs(pairs_) do
		table.insert(if r[2] then pos else neg, r[1])
	end
	if #pos == 0 or #neg == 0 then
		return nil
	end
	local wins = 0
	for _, a in ipairs(pos) do
		for _, b in ipairs(neg) do
			if a > b then
				wins += 1
			elseif a == b then
				wins += 0.5
			end
		end
	end
	return wins / (#pos * #neg)
end

local Calibrate = {}

-- Fits Platt scaling (A, B, C) per future by gradient descent on log loss.
function Calibrate.Fit(lives, seed)
	local records, Futures = run(lives, seed)
	local fitted = {}
	for _, id in ipairs(Futures.Order) do
		local data = {}
		for stage = 1, 5 do
			for _, r in ipairs(records[stage] or {}) do
				if r.Raw[id] < 0.97 then
					table.insert(data, { Futures.Logit(r.Raw[id]), r.Progress, if r.Outcomes[id] then 1 else 0 })
				end
			end
		end
		local a, b, c = 0, 1, 0
		local lr = 0.3
		for _ = 1, 3000 do
			local ga, gb, gc = 0, 0, 0
			for _, d in ipairs(data) do
				local pr = Futures.Logistic(a + b * d[1] + c * d[2])
				local e = pr - d[3]
				ga += e
				gb += e * d[1]
				gc += e * d[2]
			end
			local n = math.max(#data, 1)
			a -= lr * ga / n
			b -= lr * (gb / n + 0.001 * (b - 1))
			c -= lr * gc / n
		end
		fitted[id] = { a, b, c }
	end
	return fitted, Futures
end

function Calibrate.Report(lives, seed)
	local records, Futures = run(lives, seed)
	local summary = {}
	for _, id in ipairs(Futures.Order) do
		summary[id] = {}
		for stage = 1, 5 do
			local rs = records[stage] or {}
			local n, hits, sumP, brier, base = #rs, 0, 0, 0, 0
			local pairsList = {}
			for _, r in ipairs(rs) do
				local y = if r.Outcomes[id] then 1 else 0
				hits += y
				sumP += r.Preds[id] / 100
				table.insert(pairsList, { r.Preds[id], y == 1 })
			end
			local rate = if n > 0 then hits / n else 0
			for _, r in ipairs(rs) do
				local y = if r.Outcomes[id] then 1 else 0
				brier += (r.Preds[id] / 100 - y) ^ 2
				base += (rate - y) ^ 2
			end
			local skill = if base > 0 then 1 - brier / base else 0
			summary[id][stage] = { N = n, Rate = rate, Mean = if n > 0 then sumP / n else 0, Skill = skill, AUC = auc(pairsList) }
		end
	end
	return summary, Futures
end

if process.args[1] == "--fit" then
	local fitted, Futures = Calibrate.Fit(tonumber(process.args[2]) or 800, 1111)
	print("Futures.Calibration = {")
	for _, id in ipairs(Futures.Order) do
		local f = fitted[id]
		print(("\t%s = { %.3f, %.3f, %.3f },"):format(id, f[1], f[2], f[3]))
	end
	print("}")
elseif process.args[1] ~= "--quiet" then
	local summary, Futures = Calibrate.Report(LIVES, tonumber(process.args[2]))
	print(("%-12s %s"):format("future", "stage: base-rate / mean-pred / skill / AUC"))
	for _, id in ipairs(Futures.Order) do
		local parts = {}
		for stage = 1, 5 do
			local r = summary[id][stage]
			table.insert(parts, ("S%d %3d%%/%3d%% %+.2f %s"):format(stage, math.floor(r.Rate * 100), math.floor(r.Mean * 100), r.Skill, if r.AUC then ("%.2f"):format(r.AUC) else " -- "))
		end
		print(("%-12s %s"):format(id, table.concat(parts, " | ")))
	end
end

return Calibrate
