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
	}
	Every field is optional; nil or {} always passes.
]]

local Conditions = {}

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
	return true
end

return Conditions
