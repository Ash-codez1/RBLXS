--[[
	LifeStages  (ReplicatedStorage.Shared.Data.LifeStages)
	The six major life stages. A stage ends with a Life Reveal (Phase 5).
	ScenariosPerStage is how many decisions a player makes before the stage's reveal.
]]

local LifeStages = {}

LifeStages.List = {
	{ Id = 1, Key = "Childhood", DisplayName = "Childhood", MinAge = 5, MaxAge = 12, ScenariosPerStage = 6, Color = Color3.fromRGB(255, 196, 87) },
	{ Id = 2, Key = "Teen", DisplayName = "Teenage Years", MinAge = 13, MaxAge = 18, ScenariosPerStage = 7, Color = Color3.fromRGB(255, 120, 170) },
	{ Id = 3, Key = "YoungAdult", DisplayName = "Young Adulthood", MinAge = 19, MaxAge = 25, ScenariosPerStage = 7, Color = Color3.fromRGB(110, 170, 255) },
	{ Id = 4, Key = "Adult", DisplayName = "Adulthood", MinAge = 26, MaxAge = 40, ScenariosPerStage = 7, Color = Color3.fromRGB(90, 210, 150) },
	{ Id = 5, Key = "MiddleAge", DisplayName = "Middle Age", MinAge = 41, MaxAge = 60, ScenariosPerStage = 6, Color = Color3.fromRGB(190, 130, 255) },
	{ Id = 6, Key = "Retirement", DisplayName = "Retirement", MinAge = 61, MaxAge = 85, ScenariosPerStage = 5, Color = Color3.fromRGB(240, 170, 110) },
}

LifeStages.Count = #LifeStages.List

function LifeStages.Get(id: number)
	return LifeStages.List[id]
end

-- Returns the stage containing `age`, clamped to the first/last stage.
function LifeStages.ForAge(age: number)
	for _, stage in ipairs(LifeStages.List) do
		if age <= stage.MaxAge then
			return stage
		end
	end
	return LifeStages.List[#LifeStages.List]
end

--[[
	Age the player should be after completing `scenarioIndex` (1-based) of `stageId`.
	Ages advance evenly across the stage so the final scenario lands on MaxAge.
]]
function LifeStages.AgeAfterScenario(stageId: number, scenarioIndex: number): number
	local stage = LifeStages.List[stageId]
	local span = stage.MaxAge - stage.MinAge
	local fraction = math.clamp(scenarioIndex / stage.ScenariosPerStage, 0, 1)
	return stage.MinAge + math.floor(span * fraction + 0.5)
end

return LifeStages
