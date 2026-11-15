--[[
	PeopleController  (StarterPlayerScripts.Client.Controllers.PeopleController)
	The 👥 People panel: everyone in your life with their bond, plus actions.
	You get People.ActionsPerTurn actions between decisions:
	  Spend time · Give a gift · Talk   (per person)
	  Meet new friends · Look for love  (age 18+, when single)
	The server validates and applies every action (LifeService → Lib/Actions).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local People = require(Shared.Util.People)
local Format = require(Shared.Util.Format)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)
local DecisionController = require(script.Parent.DecisionController)

local PeopleController = {}
PeopleController.Priority = 42

local ROLE_ORDER = { "Partner", "Child", "Parent", "Sibling", "BestFriend", "Friend", "Ex" }
local ERRORS = {
	NoActionsLeft = "No actions left. Make your next decision to get more time.",
	NotEnoughMoney = "You can't afford a gift right now.",
	TooManyFriends = "You already have plenty of friends.",
	TooYoung = "You're too young for that.",
	AlreadyTaken = "You're already in a relationship.",
	RateLimited = "Slow down a moment.",
}

local handle = nil
local busy = false

function PeopleController.ActionsLeft(life): number
	if life.ActionTurn ~= #life.Decisions then
		return People.ActionsPerTurn
	end
	return math.max(0, People.ActionsPerTurn - life.ActionsUsed)
end

local function bondWord(bond: number): string
	if bond >= 85 then
		return "Inseparable"
	elseif bond >= 65 then
		return "Close"
	elseif bond >= 45 then
		return "Good"
	elseif bond >= 25 then
		return "Distant"
	end
	return "Strained"
end

local function bondColor(bond: number): Color3
	if bond >= 65 then
		return Theme.Color.Positive
	elseif bond >= 35 then
		return Theme.Color.Warning
	end
	return Theme.Color.Negative
end

local render

local function act(remote: string, ...)
	if busy then
		return
	end
	busy = true
	local ok, result = Net.Invoke(remote, ...)
	busy = false
	if ok then
		local lines = { result.Text }
		for _, change in ipairs(result.BondChanges or {}) do
			table.insert(lines, ("%s %s"):format(change.Name, Format.Signed(change.Delta)))
		end
		NotificationController.Notify({ Title = "👥 People", Text = table.concat(lines, "  ·  "), Kind = "Success", Duration = 3 })
		DecisionController.Refresh()
	else
		NotificationController.Notify({ Title = "Not now", Text = ERRORS[result] or tostring(result), Kind = "Warning", Duration = 3 })
	end
	task.wait(0.25) -- let the data snapshot arrive
	if handle and handle.IsOpen() then
		render()
	end
end

local function personRow(parent, life, person, order: number, narrow: boolean, canAct: boolean)
	local role = People.Roles[person.Role]
	local height = if narrow then 128 else 76
	local row = Create("Frame", { Name = person.Id, BackgroundColor3 = Theme.Color.SurfaceHigh, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = parent }, { Create.Corner(Theme.RadiusSmall), Create.Padding(10, 14) })
	local subtitle = role.Label
	local age = People.AgeOf(life, person)
	if age then
		subtitle ..= (" · age %d"):format(age)
	end
	if person.Married then
		subtitle = "Spouse"
	end
	subtitle ..= " · " .. bondWord(person.Bond)
	Create.Label({ Name = "Name", Text = role.Icon .. "  " .. person.Name, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Body, Size = UDim2.new(0, 260, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = row })
	Create.Label({ Name = "Sub", Text = subtitle, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Tiny, Size = UDim2.new(0, 260, 0, 18), Position = UDim2.fromOffset(0, 24), TextWrapped = false, Parent = row })
	local track = Create("Frame", { Name = "Bond", BackgroundColor3 = Theme.Color.Background, Size = UDim2.fromOffset(240, 8), Position = UDim2.fromOffset(0, 46), Parent = row }, { Create.Corner(Theme.RadiusPill) })
	Create("Frame", { Name = "Fill", BackgroundColor3 = bondColor(person.Bond), Size = UDim2.fromScale(person.Bond / 100, 1), Parent = track }, { Create.Corner(Theme.RadiusPill) })

	local buttons = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(if narrow then 0 else 330, 46),
		AutomaticSize = if narrow then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		AnchorPoint = if narrow then Vector2.new(0, 1) else Vector2.new(1, 0.5),
		Position = if narrow then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0.5),
		Parent = row,
	})
	Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = buttons
	local options = if person.Role == "Ex" then { { "Talk", "💬 Talk" } } else { { "Time", "⏰ Time" }, { "Gift", "🎁 " .. Format.Money(People.GiftCost(life)) }, { "Talk", "💬 Talk" } }
	for i, option in ipairs(options) do
		local button = Components.Button({ Name = option[1], Text = option[2], Style = "Secondary", Size = UDim2.fromOffset(104, 44), TextSize = 17, LayoutOrder = i, Parent = buttons, OnClick = function()
			act("Interact", person.Id, option[1])
		end })
		if not canAct then
			Components.SetDisabled(button, true)
		end
	end
end

function render()
	local life = DataController.GetActiveLife()
	if not handle or not life then
		return
	end
	handle.Clear()
	local narrow = UIController.IsNarrow()
	local left = PeopleController.ActionsLeft(life)
	handle.Subtitle.Text = ("%d action%s left before your next decision"):format(left, if left == 1 then "" else "s")
	local scroll = handle.Scroll

	local top = Create("Frame", { Name = "Meet", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 0, Parent = scroll })
	Create.List(Enum.FillDirection.Horizontal, 10).Parent = top
	local meet = Components.Button({ Name = "MeetFriends", Text = "Meet new friends", Icon = "🙂", Style = "Accent", Size = UDim2.fromOffset(if narrow then 200 else 240, 48), TextSize = 18, LayoutOrder = 1, Parent = top, OnClick = function()
		act("MeetPeople", "Friend")
	end })
	if left <= 0 then
		Components.SetDisabled(meet, true)
	end
	if life.Age >= 18 and not life.Relationships.Partner then
		local love = Components.Button({ Name = "LookForLove", Text = "Look for love", Icon = "💘", Style = "Primary", Size = UDim2.fromOffset(if narrow then 180 else 220, 48), TextSize = 18, LayoutOrder = 2, Parent = top, OnClick = function()
			act("MeetPeople", "Love")
		end })
		if left <= 0 then
			Components.SetDisabled(love, true)
		end
	end

	local order = 1
	for _, role in ipairs(ROLE_ORDER) do
		for _, person in ipairs(People.ByRole(life, role)) do
			order += 1
			personRow(scroll, life, person, order, narrow, left > 0)
		end
	end
	if #life.People == 0 then
		Create.Label({ Text = "Nobody yet. Go out and meet people!", TextColor3 = Theme.Color.TextDim, LayoutOrder = 2, Parent = scroll })
	end
	Create.Label({
		Text = "💡 Bonds fade over time unless you make time for people. Strong bonds make you happier; very weak ones can end relationships.",
		TextSize = Theme.TextSize.Tiny,
		TextColor3 = Theme.Color.TextFaint,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 999,
		Parent = scroll,
	})
end

function PeopleController.Open()
	local life = DataController.GetActiveLife()
	if not life then
		return
	end
	handle = UIController.OpenPanel({ Name = "PeopleModal", Title = "👥  People in " .. life.Name .. "'s Life", Width = 860, OnClose = function()
		handle = nil
	end })
	render()
end

function PeopleController.Init()
	HUDController.AddAction({ Id = "People", Icon = "👥", Order = 10, OnClick = PeopleController.Open })
end

function PeopleController.Start()
	DataController.Changed:Connect(function()
		if handle and handle.IsOpen() and not busy then
			render()
		end
	end)
end

return PeopleController
