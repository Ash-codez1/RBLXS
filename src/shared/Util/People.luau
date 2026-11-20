--[[
	People  (ReplicatedStorage.Shared.Util.People)
	The named people in a life: parents, siblings, partner, children, friends.
	Each person has a Bond (0–100) that fades if neglected and grows through
	time together. Bonds feed Happiness and the Relationships stat every year,
	and very weak bonds cause relationship problems (see Lib/Yearly).

	Person = { Id, Name, Role, Bond, BornAge (the life's age when they were born/met), Married? }
	Roles: Parent, Sibling, Partner, Ex, Child, Friend, BestFriend

	Pure functions shared by server (authoritative) and client (display).
	`life.Relationships` (Partner/Married/Children/Friends) is kept in sync for
	Requires checks via People.Sync.
]]

local NamePool = require(script.Parent.Parent.Data.NamePool)

local People = {}

People.MaxFriends = 6
People.ActionsPerTurn = 2

People.Roles = {
	Parent = { Label = "Parent", Icon = "🧑‍🍼", Decay = 1, Weight = 1, StartBond = 70 },
	Sibling = { Label = "Sibling", Icon = "🧒", Decay = 1.2, Weight = 0.7, StartBond = 60 },
	Partner = { Label = "Partner", Icon = "❤️", Decay = 1, MarriedDecay = 0.6, Weight = 2.5, StartBond = 65 },
	Ex = { Label = "Ex", Icon = "💔", Decay = 0, Weight = 0, StartBond = 20 },
	Child = { Label = "Child", Icon = "👶", Decay = 0.8, Weight = 1.2, StartBond = 75 },
	BestFriend = { Label = "Best Friend", Icon = "🫶", Decay = 1.2, Weight = 1.2, StartBond = 75 },
	Friend = { Label = "Friend", Icon = "🙂", Decay = 2, Weight = 0.5, StartBond = 55 },
}

function People.IsRole(role: any): boolean
	return type(role) == "string" and People.Roles[role] ~= nil
end

function People.ByRole(life, role: string)
	local list = {}
	for _, person in ipairs(life.People) do
		if person.Role == role then
			table.insert(list, person)
		end
	end
	return list
end

function People.Find(life, id: any)
	for _, person in ipairs(life.People) do
		if person.Id == id then
			return person
		end
	end
	return nil
end

function People.Partner(life)
	return People.ByRole(life, "Partner")[1]
end

function People.AgeOf(life, person): number?
	if person.Role == "Child" then
		return life.Age - person.BornAge
	end
	return nil
end

-- Picks a name not already used in this life.
local function pickName(life, rng): string
	local used = { [life.Name] = true }
	for _, person in ipairs(life.People) do
		used[person.Name] = true
	end
	for _ = 1, 20 do
		local name = NamePool[rng:NextInteger(1, #NamePool)]
		if not used[name] then
			return name
		end
	end
	return NamePool[rng:NextInteger(1, #NamePool)]
end

function People.Add(life, role: string, rng, bond: number?)
	life.NextPersonId = (life.NextPersonId or 1)
	local person = {
		Id = "p" .. life.NextPersonId,
		Name = pickName(life, rng),
		Role = role,
		Bond = bond or People.Roles[role].StartBond,
		BornAge = life.Age,
	}
	life.NextPersonId += 1
	table.insert(life.People, person)
	People.Sync(life)
	return person
end

function People.Remove(life, person)
	local index = table.find(life.People, person)
	if index then
		table.remove(life.People, index)
	end
	People.Sync(life)
end

function People.ChangeBond(person, delta: number): number
	local before = person.Bond
	person.Bond = math.clamp(math.floor((person.Bond + delta) * 10 + 0.5) / 10, 0, 100)
	return person.Bond - before
end

-- Keeps the summary counters in life.Relationships in step with People.
function People.Sync(life)
	local rel = life.Relationships
	local partner = People.Partner(life)
	rel.Partner = partner ~= nil
	rel.Married = partner ~= nil and partner.Married == true
	rel.Children = #People.ByRole(life, "Child")
	rel.Friends = #People.ByRole(life, "Friend") + #People.ByRole(life, "BestFriend")
end

--[[
	Weighted average bond of the people who matter most (partner, children,
	best friend, parents, siblings, friends). nil when the life has nobody.
]]
function People.CloseBond(life): number?
	local total, weight = 0, 0
	for _, person in ipairs(life.People) do
		local info = People.Roles[person.Role]
		if info and info.Weight > 0 then
			total += person.Bond * info.Weight
			weight += info.Weight
		end
	end
	if weight == 0 then
		return nil
	end
	return total / weight
end

-- Gift cost grows with age (a toy at 8, a nice dinner at 40).
function People.GiftCost(life): number
	if life.Age < 13 then
		return 10
	elseif life.Age < 19 then
		return 40
	end
	return 300
end

return People
