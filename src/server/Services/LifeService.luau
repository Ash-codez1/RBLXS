--[[
	LifeService  (ServerScriptService.Server.Services.LifeService)
	The authoritative life loop: save slots, starting/continuing lives,
	serving scenarios and resolving choices.

	Flow (client asks, server decides):
	  StartNewLife(slot, name, overwrite) -> true, slotId
	  ContinueLife(slot)                  -> true, slotId
	  DeleteLife(slot)                    -> true
	  GetScenario()                       -> true, scenarioPayload | false, reason
	  MakeChoice(scenarioId, choiceId)    -> true, outcome | false, reason

	Anti-exploit:
	  • The scenario being answered is stored in the save (life.CurrentScenario),
	    so a client can only answer the scenario it was given, once.
	  • Rejoining returns the same scenario (no rerolling bad situations).
	  • Randomness comes from a per-life server seed + decision count, so
	    leaving and rejoining can't reroll a chance outcome either.
	  • Locked choices are re-checked on the server.
	  • Names are length-checked and passed through Roblox text filtering.

	Signals for other systems:
	  LifeService.ChoiceMade(player, scenarioId, choiceId, summary)
	  LifeService.StageCompleted(player, stageId, life)    -- Phase 5 Life Reveal hooks here
	  LifeService.LifeCompleted(player, life)              -- Phase 5 final reveal hooks here
	  LifeService.LifeStarted(player, slotId, life)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local LifeStages = require(Shared.Data.LifeStages)
local DataTemplate = require(Shared.Data.DataTemplate)
local TableUtil = require(Shared.Util.TableUtil)

local Server = script.Parent.Parent
local Validate = require(Server.Lib.Validate)
local Conditions = require(Server.Lib.Conditions)
local Consequences = require(Server.Lib.Consequences)
local ScenarioPicker = require(Server.Lib.ScenarioPicker)
local Scenarios = require(Server.Content.Scenarios)

local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)

local LifeService = {}
LifeService.Priority = 30

LifeService.ChoiceMade = Signal.new()
LifeService.StageCompleted = Signal.new()
LifeService.LifeCompleted = Signal.new()
LifeService.LifeStarted = Signal.new()

local NAME_MIN, NAME_MAX = 2, 20

-- ===== Helpers =====
local function rngFor(life, salt: number)
	-- Deterministic per life + progress: same state always gives the same roll.
	return Random.new((life.Seed + #life.Decisions * 7919 + salt * 104729) % 2147483647)
end

local function activeLife(data)
	local life = data.Slots[data.ActiveSlot]
	return if type(life) == "table" then life else nil
end

local function cleanName(raw: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	local name = raw:gsub("%c", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
	local length = utf8.len(name)
	if not length or length < NAME_MIN or length > NAME_MAX then
		return nil
	end
	return name
end

-- Roblox requires user-typed text shown to others to be filtered.
local function filterName(name: string, player: Player): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn("[LifeService] Text filter failed: " .. tostring(result))
		return nil
	end
	if result ~= name then
		return nil -- something was censored; ask for a different name
	end
	return result
end

-- What the client is allowed to know about a scenario.
function LifeService.ToClient(scenario, life)
	local choices = {}
	for index, choice in ipairs(scenario.Choices) do
		local unlocked = Conditions.Check(life, choice.Requires)
		local preview, moneyDir, risky = Consequences.Preview(choice.Effects)
		table.insert(choices, {
			Id = choice.Id,
			Index = index,
			Text = choice.Text,
			Description = choice.Description,
			Locked = not unlocked,
			LockHint = if unlocked then nil else (choice.LockHint or "Locked"),
			Mystery = choice.Mystery == true,
			Preview = if choice.Mystery then {} else preview,
			MoneyDir = if choice.Mystery then 0 else moneyDir,
			Risky = risky,
		})
	end
	local stage = LifeStages.Get(life.Stage)
	return {
		Id = scenario.Id,
		Icon = scenario.Icon or "✨",
		Title = scenario.Title,
		Description = (scenario.Description:gsub("{name}", life.Name)),
		Age = life.Age,
		Stage = life.Stage,
		StageName = stage.DisplayName,
		ScenarioNumber = life.ScenarioIndex + 1,
		ScenariosInStage = stage.ScenariosPerStage,
		Choices = choices,
	}
end

-- ===== Remote handlers =====
local function startNewLife(player: Player, slotArg: any, nameArg: any, overwriteArg: any)
	local slotId = Validate.OneOf(slotArg, DataTemplate.SlotIds)
	if not slotId then
		return false, "BadSlot"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	if type(data.Slots[slotId]) == "table" and overwriteArg ~= true then
		return false, "SlotInUse"
	end
	local name = cleanName(nameArg)
	if not name then
		return false, "BadName"
	end
	name = filterName(name, player) -- yields
	if not name then
		return false, "NameFiltered"
	end

	local seed = Random.new():NextInteger(1, 2147483646)
	local life = DataTemplate.NewLife(name, seed)
	local ok = DataService.Update(player, function(d)
		d.Slots[slotId] = life
		d.ActiveSlot = slotId
		d.Lifetime.LivesStarted += 1
	end)
	if not ok then
		return false, "NotLoaded"
	end
	LifeService.LifeStarted:Fire(player, slotId, life)
	return true, slotId
end

local function continueLife(player: Player, slotArg: any)
	local slotId = Validate.OneOf(slotArg, DataTemplate.SlotIds)
	if not slotId then
		return false, "BadSlot"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	if type(data.Slots[slotId]) ~= "table" then
		return false, "EmptySlot"
	end
	DataService.Update(player, function(d)
		d.ActiveSlot = slotId
	end)
	return true, slotId
end

local function deleteLife(player: Player, slotArg: any)
	local slotId = Validate.OneOf(slotArg, DataTemplate.SlotIds)
	if not slotId then
		return false, "BadSlot"
	end
	local ok = DataService.Update(player, function(d)
		d.Slots[slotId] = false
	end)
	return ok, if ok then slotId else "NotLoaded"
end

function LifeService.GetScenario(player: Player)
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	local life = activeLife(data)
	if not life then
		return false, "NoLife"
	end
	if life.Completed then
		return false, "LifeComplete"
	end

	local scenario = if life.CurrentScenario then Scenarios.ById[life.CurrentScenario] else nil
	if not scenario then
		scenario = ScenarioPicker.Pick(life, Scenarios.All, rngFor(life, 1))
		if not scenario then
			return false, "StageNotAvailable"
		end
		DataService.Update(player, function(d)
			local l = activeLife(d)
			if l then
				l.CurrentScenario = scenario.Id
			end
		end)
	end
	return true, LifeService.ToClient(scenario, life)
end

function LifeService.MakeChoice(player: Player, scenarioArg: any, choiceArg: any)
	local scenarioId = Validate.Id(scenarioArg)
	local choiceId = Validate.Id(choiceArg)
	if not scenarioId or not choiceId then
		return false, "BadArgs"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	local life = activeLife(data)
	if not life or life.Completed then
		return false, "NoLife"
	end
	if life.CurrentScenario ~= scenarioId then
		return false, "WrongScenario"
	end
	local scenario = Scenarios.ById[scenarioId]
	local choice = scenario and scenario.ChoiceById[choiceId]
	if not choice then
		return false, "BadChoice"
	end
	if not Conditions.Check(life, choice.Requires) then
		return false, "ChoiceLocked"
	end

	local outcome
	local stageCompleted, lifeCompleted = nil, false
	DataService.Update(player, function(d)
		local l = activeLife(d)
		local prevAge, prevStage = l.Age, l.Stage
		local summary = Consequences.Apply(l, choice.Effects, rngFor(l, 2))

		table.insert(l.Decisions, { S = scenarioId, C = choiceId, Age = prevAge, Stage = prevStage })
		l.Seen[scenarioId] = true
		l.CurrentScenario = false
		l.ScenarioIndex += 1
		d.Lifetime.DecisionsMade += 1

		local stage = LifeStages.Get(l.Stage)
		l.Age = LifeStages.AgeAfterScenario(l.Stage, l.ScenarioIndex)
		if l.ScenarioIndex >= stage.ScenariosPerStage then
			stageCompleted = l.Stage
			-- Snapshot for Life Reveal (Phase 5 adds predictions to this record).
			table.insert(l.Reveals, { Stage = l.Stage, Age = l.Age, Stats = table.clone(l.Stats), Money = l.Money, Time = os.time() })
			if l.Stage < LifeStages.Count then
				l.Stage += 1
				l.ScenarioIndex = 0
				l.Age = LifeStages.Get(l.Stage).MinAge
			else
				l.Completed = true
				lifeCompleted = true
				d.Lifetime.LivesCompleted += 1
			end
		end
		d.Lifetime.HighestNetWorth = math.max(d.Lifetime.HighestNetWorth, l.Money)

		outcome = {
			ScenarioId = scenarioId,
			ChoiceId = choiceId,
			Story = summary.Story,
			Applied = summary.Applied,
			MoneyDelta = summary.MoneyDelta,
			Money = l.Money,
			Lucky = summary.OutcomeTriggered,
			TraitsGained = summary.TraitsGained,
			PrevAge = prevAge,
			Age = l.Age,
			PrevStage = prevStage,
			Stage = l.Stage,
			StageName = LifeStages.Get(l.Stage).DisplayName,
			StageCompleted = stageCompleted ~= nil,
			CompletedStageName = if stageCompleted then LifeStages.Get(stageCompleted).DisplayName else nil,
			LifeCompleted = lifeCompleted,
			NextStageAvailable = lifeCompleted or Scenarios.CountForStage(l.Stage) > 0,
		}
	end)

	StatService.StatsChanged:Fire(player, outcome.Applied, "Choice:" .. scenarioId)
	LifeService.ChoiceMade:Fire(player, scenarioId, choiceId, outcome)
	if stageCompleted then
		LifeService.StageCompleted:Fire(player, stageCompleted, life)
	end
	if lifeCompleted then
		LifeService.LifeCompleted:Fire(player, life)
	end
	return true, TableUtil.DeepCopy(outcome)
end

function LifeService.Init()
	if #Scenarios.Issues > 0 then
		warn(("[LifeService] %d content issue(s) found; see warnings above"):format(#Scenarios.Issues))
	end
end

function LifeService.Start()
	Net.Handle("StartNewLife", startNewLife)
	Net.Handle("ContinueLife", continueLife)
	Net.Handle("DeleteLife", deleteLife)
	Net.Handle("GetScenario", LifeService.GetScenario)
	Net.Handle("MakeChoice", LifeService.MakeChoice)
end

return LifeService
