--[[
	FriendsController  (StarterPlayerScripts.Client.Controllers.FriendsController)
	The "Play With Friends" screen (main menu, and 🤝 in the game HUD):
	  • YOUR LIFE CIRCLE: members, group decision, group reveal, leave/remove
	  • PLAYERS IN THIS SERVER: invite them to your circle, compare futures
	  • INVITE ROBLOX FRIENDS: the Roblox invite prompt
	  • FRIENDS PLAYING ELSEWHERE: join their server
	Every life stays independent; see PartyService for the rules.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local UIController = require(script.Parent.UIController)
local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)
local PartyController = require(script.Parent.PartyController)
local FutureController = require(script.Parent.FutureController)
local Avatar = require(UILib.Avatar)

local FriendsController = {}
FriendsController.Priority = 50

local frame: CanvasGroup
local elsewhere = nil -- cached list of friends in other servers
local busy = false

local function heading(parent, text: string, order: number)
	Create.Label({ Text = text, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 28), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = parent })
end

local function act(remote: string, ...)
	if busy then
		return false
	end
	busy = true
	local results = table.pack(Net.Invoke(remote, ...))
	busy = false
	if not results[1] then
		local extra = if results[3] then (" (%ss)"):format(tostring(results[3])) else ""
		NotificationController.Notify({ Title = "🤝 Life Circle", Text = PartyController.ErrorText(results[2]) .. extra, Kind = "Warning" })
	end
	return results[1], results[2]
end

local function row(parent, order: number, title: string, subtitle: string, buttons)
	local frameRow = Create("Frame", { Name = "Row" .. order, BackgroundColor3 = Theme.Color.SurfaceHigh, BackgroundTransparency = 0.15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent }, { Create.Corner(Theme.RadiusSmall), Create.Padding(10, 14) })
	Create.List(Enum.FillDirection.Vertical, 6).Parent = frameRow
	Create.Label({ Name = "Title", Text = title, RichText = true, FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = frameRow })
	if subtitle ~= "" then
		Create.Label({ Text = subtitle, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = frameRow })
	end
	if buttons and #buttons > 0 then
		local bar = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = frameRow })
		local list = Create.List(Enum.FillDirection.Horizontal, 8)
		list.Wraps = true
		list.Parent = bar
		for i, b in ipairs(buttons) do
			local button = Components.Button({ Name = b.Name, Text = b.Text, Icon = b.Icon, Style = b.Style or "Secondary", Size = UDim2.fromOffset(b.Width or 170, 44), TextSize = 17, LayoutOrder = i, Parent = bar, OnClick = b.OnClick })
			if b.Disabled then
				Components.SetDisabled(button, true)
			end
		end
	end
	return frameRow
end

local render

local function inCircle(userId: number): boolean
	local state = PartyController.Get()
	if not state then
		return false
	end
	for _, m in ipairs(state.Members) do
		if m.UserId == userId then
			return true
		end
	end
	return false
end

local function memberSummary(m): string
	if not m.LifeName then
		return "No life yet"
	end
	return ("%s · age %d · %s%s"):format(m.LifeName, m.Age, m.StageName, if m.Career then " · " .. m.Career else "") .. (if m.Completed then " · life complete" else "")
end

local function findFriendsElsewhere()
	elsewhere = "loading"
	task.spawn(function()
		local ok, friends = pcall(function()
			return Players.LocalPlayer:GetFriendsOnline(50)
		end)
		local list = {}
		if ok and type(friends) == "table" then
			for _, f in ipairs(friends) do
				-- LocationType 4 = playing an experience; GameId is that server's JobId.
				if f.LocationType == 4 and f.PlaceId == game.PlaceId and f.GameId and f.GameId ~= game.JobId then
					table.insert(list, f)
				end
			end
		end
		elsewhere = list
		if UIController.Current() == "Friends" then
			render()
		end
	end)
end

function render()
	Create.Clear(frame, true)
	Layout.Header(frame, "Play With Friends", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(frame)
	local width = math.min(760, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	local state = PartyController.Get()
	local me = Players.LocalPlayer

	-- Circle
	heading(column, "🤝 YOUR LIFE CIRCLE" .. (if state then ("  (%d/%d)"):format(#state.Members, state.MaxMembers) else ""), 1)
	if not state then
		Create.Label({ Text = "You're not in a circle yet. Invite someone below. In a circle you make group decisions together, compare futures and watch Group Life Reveals. Every life stays your own.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = column })
	else
		local leader = PartyController.IsLeader()
		for i, m in ipairs(state.Members) do
			local buttons = {}
			if m.UserId ~= me.UserId then
				table.insert(buttons, { Name = "Compare" .. m.UserId, Text = "Compare", Icon = "⚖️", Width = 150, OnClick = function()
					FutureController.OpenCompareWith(m.UserId)
				end })
				if leader then
					table.insert(buttons, { Name = "Remove" .. m.UserId, Text = "Remove", Width = 130, OnClick = function()
						local confirmed = UIController.Confirm({ Title = "Remove " .. m.DisplayName .. "?", Text = "They'll leave your Life Circle.", ConfirmText = "Remove", Danger = true })
						if confirmed then
							act("PartyKick", m.UserId)
						end
					end })
				end
			end
			row(column, 2 + i, (if m.IsLeader then "👑 " else "") .. Avatar.Line(m.DisplayName, m.Style) .. (if m.UserId == me.UserId then " (you)" else ""), memberSummary(m), buttons)
		end
		local eventText = if state.EventActive then "Deciding…" elseif state.EventCooldown > 0 then ("Group decision (%ds)"):format(state.EventCooldown) else "Group decision"
		row(column, 10, "Do something together", "Start a group decision for everyone to vote on, or watch everyone's futures in a Group Life Reveal.", {
			{ Name = "StartGroupEvent", Text = eventText, Icon = "🎲", Style = "Primary", Width = 250, Disabled = state.EventActive, OnClick = function()
				act("PartyStartEvent")
			end },
			{ Name = "StartGroupReveal", Text = if state.RevealCooldown > 0 then ("Group reveal (%ds)"):format(state.RevealCooldown) else "Group reveal", Icon = "🔮", Style = "Accent", Width = 230, OnClick = function()
				act("PartyStartReveal")
			end },
			{ Name = "LeaveCircle", Text = "Leave", Icon = "🚪", Width = 130, OnClick = function()
				act("PartyLeave")
			end },
		})
	end

	-- Players here
	heading(column, "👥 PLAYERS IN THIS SERVER", 20)
	local others = 0
	for i, p in ipairs(Players:GetPlayers()) do
		if p ~= me then
			others += 1
			local already = inCircle(p.UserId)
			local full = state and #state.Members >= state.MaxMembers
			row(column, 20 + i, Avatar.NameRich(p.DisplayName or p.Name, nil), if already then "In your circle" else "", {
				{ Name = "Invite" .. p.UserId, Text = if already then "In circle" else "Invite", Icon = "🤝", Style = "Primary", Width = 160, Disabled = already or full, OnClick = function()
					local ok = act("PartyInvite", p.UserId)
					if ok then
						NotificationController.Notify({ Title = "🤝 Invite sent", Text = (p.DisplayName or p.Name) .. " has 45 seconds to accept.", Kind = "Success", Duration = 3 })
					end
				end },
				{ Name = "CompareP" .. p.UserId, Text = "Compare", Icon = "⚖️", Width = 150, OnClick = function()
					FutureController.OpenCompareWith(p.UserId)
				end },
			})
		end
	end
	if others == 0 then
		Create.Label({ Text = "Nobody else is in this server yet.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 21, Parent = column })
	end

	-- Invite Roblox friends
	heading(column, "📨 INVITE YOUR ROBLOX FRIENDS", 60)
	row(column, 61, "Bring your friends into this server", "They'll get a Roblox invite to join you here.", {
		{ Name = "InviteFriends", Text = "Invite friends", Icon = "📨", Style = "Accent", Width = 220, OnClick = function()
			local ok = pcall(function()
				local SocialService = game:GetService("SocialService")
				if SocialService:CanSendGameInviteAsync(Players.LocalPlayer) then
					SocialService:PromptGameInvite(Players.LocalPlayer)
				else
					error("cannot invite")
				end
			end)
			if not ok then
				NotificationController.Notify({ Title = "Invites unavailable", Text = "Roblox invites only work in a published game, not in Studio.", Kind = "Warning" })
			end
		end },
	})

	-- Friends elsewhere
	heading(column, "🌍 FRIENDS PLAYING IN OTHER SERVERS", 70)
	if elsewhere == nil then
		findFriendsElsewhere()
	end
	if elsewhere == "loading" then
		Create.Label({ Text = "Looking for friends…", TextColor3 = Theme.Color.TextDim, LayoutOrder = 71, Parent = column })
	elseif type(elsewhere) == "table" and #elsewhere == 0 then
		Create.Label({ Text = "No friends are playing CHOOSE YOUR LIFE in other servers right now.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 71, Parent = column })
	elseif type(elsewhere) == "table" then
		for i, f in ipairs(elsewhere) do
			row(column, 71 + i, f.DisplayName or f.UserName or "Friend", "Playing in another server", {
				{ Name = "Join" .. tostring(f.VisitorId), Text = "Join their server", Icon = "🚀", Style = "Primary", Width = 240, OnClick = function()
					local ok = act("JoinFriendServer", f.PlaceId, f.GameId)
					if ok then
						NotificationController.Notify({ Title = "🚀 Joining…", Text = "Teleporting you to " .. (f.DisplayName or "your friend") .. "'s server.", Kind = "Info" })
					end
				end },
			})
		end
	end
	Components.Button({ Name = "RefreshFriends", Text = "Refresh", Icon = "🔄", Style = "Ghost", Size = UDim2.fromOffset(160, 44), LayoutOrder = 99, Parent = column, OnClick = function()
		elsewhere = nil
		render()
	end })
end

function FriendsController.Init()
	frame = UIController.NewScreen("Friends", { Back = true, OnOpen = function()
		elsewhere = nil
		render()
	end })
	HUDController.AddAction({ Id = "Circle", Icon = "🤝", Order = 8, OnClick = function()
		UIController.Show("Friends")
	end })
end

function FriendsController.Start()
	PartyController.Changed:Connect(function()
		if UIController.Current() == "Friends" then
			render()
		end
	end)
	for _, signal in ipairs({ Players.PlayerAdded, Players.PlayerRemoving }) do
		signal:Connect(function()
			task.defer(function()
				if UIController.Current() == "Friends" then
					render()
				end
			end)
		end)
	end
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Friends" then
			render()
		end
	end)
end

return FriendsController
