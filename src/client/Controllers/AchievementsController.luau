--[[
	AchievementsController  (StarterPlayerScripts.Client.Controllers.AchievementsController)
	🏆 The Achievements screen (main menu → Achievements), with three tabs:
	  • Achievements: every achievement with progress bars, rewards and
	    unlock dates; secret ones stay "???" with a hint until unlocked.
	  • Challenges: today's daily reward, the daily and weekly challenges
	    with progress and time left (the server pays rewards automatically).
	  • Memory Stars: how many you've found, with a hint for each one left.
	Progress is read from your own synced data, the same rules the server uses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Data.Achievements)
local Challenges = require(Shared.Data.Challenges)
local Collectibles = require(Shared.Data.Collectibles)
local World = require(Shared.Data.World)
local Format = require(Shared.Util.Format)
local DailyRules = require(Shared.Util.Daily)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)

local AchievementsController = {}
AchievementsController.Priority = 62

local frame: CanvasGroup
local tab = "Achievements"
local category: string? = nil

local MONEY = { NestEgg = true, Millionaire = true, S_Billionaire = true }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- "12 Mar 2027" (Roblox's os.date only returns tables).
local function dateText(unix: number): string
	local t = os.date("!*t", unix)
	return ("%d %s %d"):format(t.day, MONTHS[t.month], t.year)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function AchievementsController.Today(): number
	return Challenges.DayOf(serverNow())
end

local function timeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	end
	return ("%dh %dm"):format(hours, minutes)
end

local function card(parent, order: number, props)
	local panel = Components.Panel({ Name = props.Name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 14, LayoutOrder = order, Parent = parent, Color = if props.Done then Theme.Color.SurfaceHigh else Theme.Color.Surface })
	Create.List(Enum.FillDirection.Vertical, 6).Parent = panel
	local top = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = panel })
	Create.Label({ Name = "Title", Text = props.Icon .. "  " .. props.Title, FontFace = Theme.Font.Heavy, Size = UDim2.new(1, -120, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = top })
	Create.Label({ Name = "Reward", Text = props.Reward or "", TextColor3 = if props.Done then Theme.Color.Positive else Theme.Color.Gold, FontFace = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 120, 1, 0), Parent = top })
	Create.Label({ Name = "Description", Text = props.Text, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel })
	if props.Fraction then
		Components.ProgressBar({ Fraction = props.Fraction, Text = props.ProgressText, Color = if props.Done then Theme.Color.Positive else Theme.Color.Accent, LayoutOrder = 3, Parent = panel })
	end
	return panel
end

local function grid(parent, order: number, columns: number, width: number)
	local holder = Create("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent })
	if columns > 1 then
		local list = Create.List(Enum.FillDirection.Horizontal, 12)
		list.Wraps = true
		list.Parent = holder
	else
		Create.List(Enum.FillDirection.Vertical, 10).Parent = holder
	end
	return holder, math.floor((width - 12 * (columns - 1)) / columns)
end

-- ===== Tabs =====
local function renderAchievements(column, data, width: number)
	local unlocked = Achievements.Unlocked(data)
	Create.Label({ Name = "Summary", Text = ("🏆 %d of %d unlocked"):format(unlocked, #Achievements.List), FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = column })
	local filters = Create("Frame", { Name = "Filters", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = column })
	local list = Create.List(Enum.FillDirection.Horizontal, 8)
	list.Wraps = true
	list.Parent = filters
	local entries = { { Id = nil, Name = "All", Icon = "🌟" } }
	for _, c in ipairs(Achievements.Categories) do
		table.insert(entries, c)
	end
	for i, c in ipairs(entries) do
		Components.Button({ Name = "Filter_" .. (c.Id or "All"), Text = c.Name, Icon = c.Icon, Style = if category == c.Id then "Primary" else "Secondary", Size = UDim2.fromOffset(if UIController.IsNarrow() then 150 else 140, 40), TextSize = 15, LayoutOrder = i, Parent = filters, OnClick = function()
			category = c.Id
			AchievementsController.Render()
		end })
	end
	local columns = if UIController.IsNarrow() then 1 else 2
	local holder, cellWidth = grid(column, 5, columns, width)
	local order = 0
	for _, def in ipairs(Achievements.List) do
		if category == nil or def.Category == category then
			order += 1
			local done = data.Achievements[def.Id] ~= nil
			local hidden = def.Secret and not done
			local current, target = Achievements.ProgressOf(def.Id, data)
			local progressText = if MONEY[def.Id] then ("%s / %s"):format(Format.Money(current), Format.Money(target)) else ("%s / %s"):format(Format.Commas(current), Format.Commas(target))
			local c = card(holder, order, {
				Name = "Ach_" .. def.Id,
				Icon = if hidden then "🔒" else def.Icon,
				Title = if hidden then "???" else def.Name,
				Text = if hidden then "Secret: " .. (def.Hint or "keep playing to find it.") else def.Description,
				Reward = if done then "✅ Unlocked" else ("🪙 %d"):format(def.Coins or 0),
				Done = done,
				Fraction = if hidden then nil else current / target,
				ProgressText = if done then "Unlocked " .. dateText(data.Achievements[def.Id]) else progressText,
			})
			c.Size = UDim2.fromOffset(cellWidth, 0)
		end
	end
end

local function challengeCards(column, order: number, title: string, group, defsById, lifetime, secondsLeft: number, prefix: string)
	Create.Label({ Name = prefix .. "Heading", Text = ("%s · resets in %s"):format(title, timeLeft(secondsLeft)), TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 28), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = column })
	local ids = {}
	for id in pairs(group or {}) do
		table.insert(ids, id)
	end
	table.sort(ids)
	if #ids == 0 then
		Create.Label({ Text = "New challenges are on their way…", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + 1, Parent = column })
	end
	for i, id in ipairs(ids) do
		local def = defsById[id]
		if def then
			local entry = group[id]
			local progress, target = Challenges.Progress(def, entry, lifetime)
			card(column, order + i, {
				Name = "Challenge_" .. id,
				Icon = def.Icon,
				Title = def.Text,
				Text = if entry.Done then "Complete! The Coins are yours." else "Progress made since this challenge started counts.",
				Reward = if entry.Done then "✅ Done" else ("🪙 %d"):format(def.Coins),
				Done = entry.Done,
				Fraction = progress / target,
				ProgressText = ("%d / %d"):format(progress, target),
			})
		end
	end
end

local function renderChallenges(column, data)
	local today = AchievementsController.Today()
	local status = DailyRules.Status(data.Daily, today, serverNow())
	local daily = Components.Panel({ Name = "DailyCard", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 14, LayoutOrder = 3, Parent = column, Color = Theme.Color.SurfaceHigh })
	Create.List(Enum.FillDirection.Vertical, 8).Parent = daily
	Create.Label({ Text = ("🎁 Daily reward · 🔥 %d-day streak"):format(data.Daily.Streak or 0), FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = daily })
	Create.Label({ Text = if status.Claimable then ("Day %d reward ready: 🪙 %d"):format(status.Day, status.Reward) else ("Claimed today. Next reward in %s."):format(timeLeft(status.SecondsLeft)), TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = daily })
	Components.Button({ Name = "OpenDaily", Text = if status.Claimable then "Claim" else "View", Icon = "🎁", Style = if status.Claimable then "Primary" else "Secondary", Size = UDim2.fromOffset(180, 46), TextSize = 18, LayoutOrder = 3, Parent = daily, OnClick = function()
		require(script.Parent.DailyController).Open()
	end })
	local c = data.Challenges
	local dailyGroup = if c.DailyDay == today then c.Daily else {}
	local week = Challenges.WeekOf(today)
	local weeklyGroup = if c.WeeklyWeek == week then c.Weekly else {}
	local weekEnds = (week * 7 + 4) * 86400 -- Monday 00:00 UTC
	challengeCards(column, 10, "🎯 DAILY CHALLENGES", dailyGroup, Challenges.ById, data.Lifetime, (today + 1) * 86400 - serverNow(), "Daily")
	challengeCards(column, 30, "🗓️ WEEKLY CHALLENGES", weeklyGroup, Challenges.ById, data.Lifetime, weekEnds - serverNow(), "Weekly")
end

local function renderStars(column, data)
	local found = Achievements.Count(data.Collectibles)
	Create.Label({ Name = "StarSummary", Text = ("⭐ %d of %d Memory Stars found · 🪙 %d each"):format(found, Collectibles.Total, Collectibles.Coins), FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = column })
	Components.ProgressBar({ Name = "StarBar", Fraction = found / Collectibles.Total, Text = ("%d / %d"):format(found, Collectibles.Total), Color = Theme.Color.Gold, LayoutOrder = 4, Parent = column })
	local order = 10
	for _, district in ipairs(World.Districts) do
		local stars = {}
		for _, star in ipairs(Collectibles.List) do
			if star.District == district.Id then
				table.insert(stars, star)
			end
		end
		if #stars > 0 then
			order += 1
			Create.Label({ Text = district.Icon .. "  " .. district.Name, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = column })
			for _, star in ipairs(stars) do
				order += 1
				local got = data.Collectibles[star.Id] == true
				Create.Label({ Name = star.Id, Text = (if got then "✅ Found · " else "❔ ") .. star.Hint, TextColor3 = if got then Theme.Color.Positive else Theme.Color.TextDim, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = column })
			end
		end
	end
end

function AchievementsController.Render()
	Create.Clear(frame, true)
	Layout.Header(frame, "Achievements", function()
		UIController.Back()
	end)
	local data = DataController.Get()
	if not data then
		return
	end
	local scroll = Layout.Scroll(frame)
	local width = math.min(900, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	local tabs = Create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 48), LayoutOrder = 1, Parent = column })
	Create.List(Enum.FillDirection.Horizontal, 8).Parent = tabs
	local tabWidth = math.floor((width - 16) / 3)
	for i, t in ipairs({ { "Achievements", "🏆" }, { "Challenges", "🎯" }, { "Stars", "⭐" } }) do
		Components.Button({ Name = "Tab_" .. t[1], Text = if t[1] == "Stars" then "Memory Stars" else t[1], Icon = t[2], Style = if tab == t[1] then "Primary" else "Secondary", Size = UDim2.fromOffset(tabWidth, 48), TextSize = 17, LayoutOrder = i, Parent = tabs, OnClick = function()
			tab = t[1]
			AchievementsController.Render()
		end })
	end
	if tab == "Achievements" then
		renderAchievements(column, data, width)
	elseif tab == "Challenges" then
		renderChallenges(column, data)
	else
		renderStars(column, data)
	end
end

function AchievementsController.Open(tabName: string?)
	tab = tabName or tab
	UIController.Show("Achievements")
end

function AchievementsController.Init()
	frame = UIController.NewScreen("Achievements", { Back = true, OnOpen = function(tabName)
		if tabName then
			tab = tabName
		end
		AchievementsController.Render()
	end })
end

function AchievementsController.Start()
	DataController.Changed:Connect(function()
		if UIController.Current() == "Achievements" then
			AchievementsController.Render()
		end
	end)
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Achievements" then
			AchievementsController.Render()
		end
	end)
end

return AchievementsController
