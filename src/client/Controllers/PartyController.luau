--[[
	PartyController  (StarterPlayerScripts.Client.Controllers.PartyController)
	Client side of Life Circles and city events (server: PartyService,
	CityEventService).
	  • keeps the current circle state (PartyController.Get / .Changed)
	  • shows circle invites with Join / No thanks
	  • opens the group-decision vote panel, live tally and countdown, then
	    what the group chose and what it meant for YOUR life
	  • plays Group Life Reveals (RevealController.PlayGroup)
	  • shows city-event invitations with Join / Skip, and a summary
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local StatDefinitions = require(Shared.Data.StatDefinitions)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local AudioController = require(script.Parent.AudioController)
local RevealController = require(script.Parent.RevealController)

local PartyController = {}
PartyController.Priority = 49
PartyController.Changed = Signal.new() -- (state or false)

local state = false
local promptStack: Frame
local vote = nil -- { Payload, Handle, Votes, MyVote, Deadline }

local ERRORS = {
	NotHere = "That player isn't in this server any more.",
	PartyFull = "That circle is full (4 players max).",
	AlreadyInvited = "You've already invited them.",
	AlreadyMember = "They're already in your circle.",
	Expired = "That invite has expired.",
	NoInvite = "That invite is no longer valid.",
	Cooldown = "Give it a moment before the next one.",
	EventActive = "Your circle is already deciding something.",
	NotEveryoneReady = "Everyone in the circle needs a life in progress.",
	NoParty = "You're not in a circle.",
	NotLeader = "Only the circle leader can do that.",
	ChoiceLocked = "Not everyone in the circle can do that one.",
	NotEligible = "You can't join this one.",
	RateLimited = "Slow down a moment.",
}
function PartyController.ErrorText(reason: any): string
	return ERRORS[reason] or tostring(reason)
end

function PartyController.Get()
	return state
end

function PartyController.MyUserId(): number
	return Players.LocalPlayer.UserId
end

function PartyController.IsLeader(): boolean
	return state ~= false and state.LeaderUserId == PartyController.MyUserId()
end

local function setState(newState)
	state = newState or false
	PartyController.Changed:Fire(state)
end

-- ===== Small prompt cards (invites, city events) =====
local function promptCard(name: string, title: string, body: string, seconds: number, buttons)
	local card = Create("CanvasGroup", {
		Name = name,
		BackgroundColor3 = Theme.Color.Surface,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = promptStack,
	}, { Create.Corner(Theme.Radius), Create.Stroke(Theme.Color.Gold, 2, 0.1), Create.Padding(14, 16) })
	Create.List(Enum.FillDirection.Vertical, 8).Parent = card
	Create.Label({ Text = title, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
	Create.Label({ Text = body, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
	local timer = Create.Label({ Name = "Timer", Text = "", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, LayoutOrder = 3, Parent = card })
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 4, Parent = card })
	Create.List(Enum.FillDirection.Horizontal, 10).Parent = row
	local done = false
	local function close()
		if done then
			return
		end
		done = true
		Anim.Fade(card, false, 0.2)
		task.delay(0.3, function()
			card:Destroy()
		end)
	end
	for i, b in ipairs(buttons) do
		Components.Button({ Name = b.Name, Text = b.Text, Style = b.Style or (if i == 1 then "Primary" else "Secondary"), Size = UDim2.fromOffset(b.Width or 170, 46), TextSize = 18, LayoutOrder = i, Parent = row, OnClick = function()
			if done then
				return
			end
			close()
			if b.OnClick then
				task.spawn(b.OnClick)
			end
		end })
	end
	Anim.Fade(card, true, 0.2)
	AudioController.Play("Notify")
	task.spawn(function()
		local deadline = os.clock() + seconds
		while not done and os.clock() < deadline do
			timer.Text = ("%ds left"):format(math.ceil(deadline - os.clock()))
			task.wait(0.5)
		end
		close()
	end)
	return card
end

PartyController.PromptCard = promptCard -- also used for trade requests

local function onInvite(invite)
	promptCard("Invite" .. invite.InviteId, "🤝 " .. invite.FromName .. " invited you", "Join their Life Circle to make group decisions, compare futures and watch Group Life Reveals together. Your own life stays yours.", invite.Seconds or 45, {
		{ Name = "AcceptInvite", Text = "Join", OnClick = function()
			local ok, result = Net.Invoke("PartyRespond", invite.InviteId, true)
			if ok then
				NotificationController.Notify({ Title = "🤝 Life Circle", Text = "You joined " .. invite.FromName .. "'s circle!", Kind = "Success" })
			else
				NotificationController.Notify({ Title = "Couldn't join", Text = PartyController.ErrorText(result), Kind = "Warning" })
			end
		end },
		{ Name = "DeclineInvite", Text = "No thanks", OnClick = function()
			Net.Invoke("PartyRespond", invite.InviteId, false)
		end },
	})
end

-- ===== Group decisions =====
local function previewText(choice): string
	local parts = {}
	for _, p in ipairs(choice.Preview or {}) do
		local info = StatDefinitions.Info[p.Stat]
		if info then
			table.insert(parts, ("%s<font color=\"%s\">%s</font>"):format(info.Icon, if p.Dir > 0 then Theme.Hex.Positive else Theme.Hex.Negative, string.rep(if p.Dir > 0 then "▲" else "▼", p.Size)))
		end
	end
	if choice.Risky then
		table.insert(parts, "🎲<font color=\"" .. Theme.Hex.Gold .. "\">Risky</font>")
	end
	for _, tag in ipairs(choice.Tags or {}) do
		table.insert(parts, "<font color=\"" .. Theme.Hex.Gold .. "\">" .. tag .. "</font>")
	end
	return table.concat(parts, "   ")
end

local function nameFor(userId: string): string
	if state then
		for _, m in ipairs(state.Members) do
			if tostring(m.UserId) == userId then
				return m.DisplayName
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if tostring(p.UserId) == userId then
			return p.DisplayName or p.Name
		end
	end
	return "Someone"
end

local renderVote
function renderVote()
	if not vote or not vote.Handle or not vote.Handle.IsOpen() then
		return
	end
	local payload = vote.Payload
	local handle = vote.Handle
	handle.Clear()
	local scroll = handle.Scroll
	Create.Label({ Text = payload.Description, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	Create.Label({ Text = "Everyone votes. The majority decides, and each of you lives with the result in your own life.", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	local votersByChoice = {}
	for userId, choiceId in pairs(vote.Votes) do
		votersByChoice[choiceId] = votersByChoice[choiceId] or {}
		table.insert(votersByChoice[choiceId], nameFor(userId))
	end
	for i, choice in ipairs(payload.Choices) do
		local mine = vote.MyVote == choice.Id
		local card = Create("TextButton", {
			Name = "Vote" .. choice.Id,
			Text = "",
			AutoButtonColor = false,
			Selectable = not choice.Locked,
			BackgroundColor3 = if mine then Theme.Color.SurfaceHigher else Theme.Color.SurfaceHigh,
			BackgroundTransparency = if choice.Locked then 0.5 else 0.05,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 10 + i,
			Parent = scroll,
		}, { Create.Corner(Theme.RadiusSmall), Create.Stroke(if mine then Theme.Color.Primary else Theme.Color.Stroke, if mine then 3 else 1.5, if mine then 0 else 0.4), Create.Padding(12, 14) })
		Create.List(Enum.FillDirection.Vertical, 4).Parent = card
		Create.Label({ Text = (if choice.Locked then "🔒 " elseif mine then "✅ " else "") .. choice.Text, FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
		Create.Label({ Text = if choice.Locked then (choice.LockHint or "Locked") else choice.Description, TextSize = Theme.TextSize.Small, TextColor3 = if choice.Locked then Theme.Color.Warning else Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
		if not choice.Locked then
			Create.Label({ Text = previewText(choice), RichText = true, TextSize = Theme.TextSize.Small, FontFace = Theme.Font.Bold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = card })
		end
		local voters = votersByChoice[choice.Id]
		if voters then
			Create.Label({ Name = "Voters", Text = ("🗳️ %d: %s"):format(#voters, table.concat(voters, ", ")), TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = card })
		end
		card.Activated:Connect(function()
			if choice.Locked then
				NotificationController.Notify({ Title = "Locked", Text = choice.LockHint or "Not everyone can do this.", Kind = "Warning", Duration = 2.5 })
				return
			end
			if Components.OnClickSound then
				Components.OnClickSound()
			end
			vote.MyVote = choice.Id
			renderVote()
			local ok, result = Net.Invoke("PartyVote", payload.EventId, choice.Id)
			if not ok then
				NotificationController.Notify({ Title = "Vote not counted", Text = PartyController.ErrorText(result), Kind = "Warning" })
			end
		end)
	end
end

local function onGroupEvent(payload)
	vote = { Payload = payload, Votes = {}, MyVote = nil, Deadline = os.clock() + (payload.Seconds or 40) }
	local handle = UIController.OpenPanel({ Name = "GroupEventModal", Title = payload.Icon .. "  Group Decision: " .. payload.Title, Width = 760 })
	vote.Handle = handle
	AudioController.Play("Notify")
	renderVote()
	local current = vote
	task.spawn(function()
		while vote == current and handle.IsOpen() and not current.Result do
			local left = math.max(0, math.ceil(current.Deadline - os.clock()))
			handle.Subtitle.Text = ("Vote now · %ds left · started by %s"):format(left, payload.StartedBy)
			task.wait(0.5)
		end
	end)
end

local function onGroupVote(update)
	if vote and vote.Payload.EventId == update.EventId then
		vote.Votes = update.Votes
		renderVote()
	end
end

local function changeLines(result)
	local parts = {}
	for _, text in ipairs(result.LifeChanges or {}) do
		table.insert(parts, text)
	end
	for stat, delta in pairs(result.Applied or {}) do
		local info = StatDefinitions.Info[stat]
		if info and math.abs(delta) >= 0.5 then
			table.insert(parts, info.Icon .. " " .. Format.Signed(delta))
		end
	end
	if result.MoneyDelta and result.MoneyDelta ~= 0 then
		table.insert(parts, "💰 " .. (if result.MoneyDelta > 0 then "+" else "") .. Format.Money(result.MoneyDelta))
	end
	return parts
end

local function onGroupResult(result)
	local handle = if vote and vote.Payload.EventId == result.EventId and vote.Handle.IsOpen() then vote.Handle else nil
	if vote and vote.Payload.EventId == result.EventId then
		vote.Result = result
	end
	if not handle then
		handle = UIController.OpenPanel({ Name = "GroupEventModal", Title = result.Icon .. "  Group Decision: " .. result.Title, Width = 760 })
	end
	handle.Clear()
	local scroll = handle.Scroll
	local chosenText = result.ChoiceText
	local count = result.Tally and result.Tally[result.ChoiceId] or 0
	handle.Subtitle.Text = if result.NoVotes then "Nobody voted, so fate decided" elseif result.Tie then "It was a tie, settled by chance" else ("Decided by %d vote%s"):format(count, if count == 1 then "" else "s")
	Create.Label({ Name = "Chosen", Text = "The group chose: " .. chosenText, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H2, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	if result.Lucky then
		Components.Chip({ Text = "🎲 Fate stepped in!", TextColor = Theme.Color.Gold, LayoutOrder = 2, Parent = scroll })
	end
	Create.Label({ Name = "Story", Text = result.Story, TextSize = Theme.TextSize.H3, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = scroll })
	local lines = changeLines(result)
	if #lines > 0 then
		Create.Label({ Text = "For your life:  " .. table.concat(lines, "   "), FontFace = Theme.Font.Bold, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = scroll })
	end
	Components.Button({ Name = "CloseGroupResult", Text = "Nice!", Icon = "👍", Style = "Primary", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 10, Parent = scroll, OnClick = function()
		UIController.ClosePanel()
	end })
	AudioController.Play("Positive")
end

-- ===== City events =====
local function onCityEvent(event)
	if not event.Eligible then
		promptCard("City" .. event.EventId, event.Icon .. " " .. event.Title, event.Description .. "\n(You can't join this one right now.)", event.Seconds or 45, {
			{ Name = "CityOk", Text = "OK", Style = "Secondary" },
		})
		return
	end
	promptCard("City" .. event.EventId, event.Icon .. " " .. event.Title, event.Description, event.Seconds or 45, {
		{ Name = "CityJoin", Text = event.JoinText, Width = 220, OnClick = function()
			local ok, result = Net.Invoke("CityEventRespond", event.EventId, true)
			if ok and result.Joined then
				local lines = changeLines(result)
				NotificationController.Notify({ Title = event.Icon .. " " .. event.Title, Text = result.Story .. (if #lines > 0 then "  " .. table.concat(lines, "  ") else ""), Kind = "Success", Duration = 6 })
			elseif not ok then
				NotificationController.Notify({ Title = "Couldn't join", Text = PartyController.ErrorText(result), Kind = "Warning" })
			end
		end },
		{ Name = "CitySkip", Text = event.SkipText, Width = 220, OnClick = function()
			Net.Invoke("CityEventRespond", event.EventId, false)
		end },
	})
end

local function onCitySummary(summary)
	if summary.Invited and summary.Invited > 1 then
		NotificationController.Notify({ Title = summary.Icon .. " " .. summary.Title, Text = ("%d of %d people in this server joined in."):format(summary.Joined, summary.Invited), Kind = "Info", Duration = 4 })
	end
end

-- ===== Lifecycle =====
function PartyController.Init()
	promptStack = Create("Frame", {
		Name = "Prompts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(math.min(460, UIController.GetVirtualSize().X - 24), 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 45,
		Parent = UIController.GetOverlay(),
	})
	Create.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = promptStack
	UIController.LayoutChanged:Connect(function()
		promptStack.Size = UDim2.fromOffset(math.min(460, UIController.GetVirtualSize().X - 24), 0)
	end)
end

function PartyController.Start()
	Net.OnEvent("PartyUpdate", setState)
	Net.OnEvent("PartyInviteReceived", onInvite)
	Net.OnEvent("GroupEvent", onGroupEvent)
	Net.OnEvent("GroupVote", onGroupVote)
	Net.OnEvent("GroupEventResult", onGroupResult)
	Net.OnEvent("GroupReveal", function(payload)
		task.spawn(RevealController.PlayGroup, payload)
	end)
	Net.OnEvent("CityEvent", onCityEvent)
	Net.OnEvent("CityEventSummary", onCitySummary)
	local ok, current = Net.Invoke("GetPartyState")
	if ok then
		setState(current)
	end
end

return PartyController
