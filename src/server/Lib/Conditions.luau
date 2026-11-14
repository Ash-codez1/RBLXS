--[[
	Conditions  (ServerScriptService.Server.Lib.Conditions)
	Evaluates a `Requires` table against a life. Used by scenarios and by
	individual choices, which is how earlier decisions unlock (or close off)
	later branches.

	Requires = {
		Flags      = { "A", "B" },    -- all must be set
		AnyFlags   = { "A", "B" },    -- at least one must be set
		NotFlags   = { "C" },         -- none may be set
		MinStats   = { Intelligence = 60 },
		MaxStats   = { Health = 30 },
		MinTraits  = { Studious = 2 },
		MinMoney   = 1000,
		MinAge     = 7,  MaxAge = 10,
		-- life situation
		HasCareer  = true | false,
		Careers    = { "Doctor", "Lawyer" },  -- current career is one of these
		NotCareers = { "ShopAssistant" },
		MinCareerLevel = 3,
		MinEducation = "University",          -- None < School < University < Masters
		MaxEducation = "School",
		Partner    = true | false,
		Married    = true | false,
		MinChildren = 1, MaxChildren = 0,
		Assets     = { "House" },             -- owns all of these
		AnyAssets  = { "House", "Mansion" },
		NotAssets  = { "Mansion" },
	}
	Every field is optional; nil or {} always passes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Careers = require(ReplicatedStorage:WaitForChild("Shared").Data.Careers)

local Conditions = {}

local function hasCareer(life): boolean
	return life.Career.Id ~= "None" and Careers.Info[life.Career.Id] ~= nil
end
Conditions.HasCareer = hasCareer

function Conditions.Check(life, requires): boolean
	if not requires then
		return true
	end
	local flags = life.Flags
	if requires.Flags then
		for _, flag in ipairs(requires.Flags) do
			if not flags[flag] then
				return false
			end
		end
	end
	if requires.AnyFlags then
		local any = false
		for _, flag in ipairs(requires.AnyFlags) do
			if flags[flag] then
				any = true
				break
			end
		end
		if not any then
			return false
		end
	end
	if requires.NotFlags then
		for _, flag in ipairs(requires.NotFlags) do
			if flags[flag] then
				return false
			end
		end
	end
	if requires.MinStats then
		for stat, min in pairs(requires.MinStats) do
			if (life.Stats[stat] or 0) < min then
				return false
			end
		end
	end
	if requires.MaxStats then
		for stat, max in pairs(requires.MaxStats) do
			if (life.Stats[stat] or 0) > max then
				return false
			end
		end
	end
	if requires.MinTraits then
		for trait, min in pairs(requires.MinTraits) do
			if (life.Traits[trait] or 0) < min then
				return false
			end
		end
	end
	if requires.MinMoney and life.Money < requires.MinMoney then
		return false
	end
	if requires.MinAge and life.Age < requires.MinAge then
		return false
	end
	if requires.MaxAge and life.Age > requires.MaxAge then
		return false
	end
	if requires.HasCareer ~= nil and hasCareer(life) ~= requires.HasCareer then
		return false
	end
	if requires.Careers and not table.find(requires.Careers, life.Career.Id) then
		return false
	end
	if requires.NotCareers and table.find(requires.NotCareers, life.Career.Id) then
		return false
	end
	if requires.MinCareerLevel and (not hasCareer(life) or life.Career.Level < requires.MinCareerLevel) then
		return false
	end
	local educationRank = Careers.EducationRank[life.Education] or 0
	if requires.MinEducation and educationRank < Careers.EducationRank[requires.MinEducation] then
		return false
	end
	if requires.MaxEducation and educationRank > Careers.EducationRank[requires.MaxEducation] then
		return false
	end
	local rel = life.Relationships
	if requires.Partner ~= nil and (rel.Partner == true) ~= requires.Partner then
		return false
	end
	if requires.Married ~= nil and (rel.Married == true) ~= requires.Married then
		return false
	end
	if requires.MinChildren and rel.Children < requires.MinChildren then
		return false
	end
	if requires.MaxChildren and rel.Children > requires.MaxChildren then
		return false
	end
	if requires.Assets then
		for _, asset in ipairs(requires.Assets) do
			if not life.Assets[asset] then
				return false
			end
		end
	end
	if requires.AnyAssets then
		local any = false
		for _, asset in ipairs(requires.AnyAssets) do
			if life.Assets[asset] then
				any = true
				break
			end
		end
		if not any then
			return false
		end
	end
	if requires.NotAssets then
		for _, asset in ipairs(requires.NotAssets) do
			if life.Assets[asset] then
				return false
			end
		end
	end
	return true
end

return Conditions
