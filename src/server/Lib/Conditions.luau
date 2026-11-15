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
		-- people & finances
		HasRole    = { "BestFriend" },        -- has someone in each of these roles
		NotRole    = { "Partner" },
		MinBond    = { Partner = 40 },         -- best bond among people in that role
		MaxBond    = { Partner = 30 },         -- (role must exist for MaxBond to pass)
		MinFriends = 2, MaxFriends = 0,
		HasLoan    = "Mortgage", NoLoans = true,
		MinInvestments = 10000,
		Focus      = { "Career", "Money" },
	}
	Every field is optional; nil or {} always passes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Careers = require(ReplicatedStorage:WaitForChild("Shared").Data.Careers)
local People = require(ReplicatedStorage:WaitForChild("Shared").Util.People)

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
	if requires.HasRole then
		for _, role in ipairs(requires.HasRole) do
			if #People.ByRole(life, role) == 0 then
				return false
			end
		end
	end
	if requires.NotRole then
		for _, role in ipairs(requires.NotRole) do
			if #People.ByRole(life, role) > 0 then
				return false
			end
		end
	end
	local function bestBond(role)
		local best = nil
		for _, person in ipairs(People.ByRole(life, role)) do
			best = math.max(best or 0, person.Bond)
		end
		return best
	end
	if requires.MinBond then
		for role, min in pairs(requires.MinBond) do
			local bond = bestBond(role)
			if not bond or bond < min then
				return false
			end
		end
	end
	if requires.MaxBond then
		for role, max in pairs(requires.MaxBond) do
			local bond = bestBond(role)
			if not bond or bond > max then
				return false
			end
		end
	end
	if requires.MinFriends and rel.Friends < requires.MinFriends then
		return false
	end
	if requires.MaxFriends and rel.Friends > requires.MaxFriends then
		return false
	end
	if requires.HasLoan then
		local found = false
		for _, loan in ipairs(life.Loans) do
			if loan.Kind == requires.HasLoan then
				found = true
			end
		end
		if not found then
			return false
		end
	end
	if requires.NoLoans and #life.Loans > 0 then
		return false
	end
	if requires.MinInvestments and (life.Investments or 0) < requires.MinInvestments then
		return false
	end
	if requires.Focus and not table.find(requires.Focus, life.Focus) then
		return false
	end
	return true
end

return Conditions
