--[[
	ProfileController  (StarterPlayerScripts.Client.Controllers.ProfileController)
	👤 Player profiles: your own (main menu → Profile) or anyone in this
	server (Friends screen, leaderboards). Shows their look and title,
	Legacy level, achievements and Memory Stars, and — if their privacy
	settings allow you — lifetime statistics, endings collected, their
	current life and recent lives. From someone else's profile you can
	offer a trade.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Avatar = require(UILib.Avatar)

local UIController = require(script.Parent.UIController)

local ProfileController = {}
ProfileController.Priority = 65

local STATS = {
	{ "LivesCompleted", "🏁", "Lives lived" },
	{ "DecisionsMade", "🧭", "Decisions made" },
	{ "HighestNetWorth", "💰", "Richest life", true },
	{ "CoinsEarned", "🪙", "Coins earned" },
	{ "BestStreak", "🔥", "Best login streak" },
	{ "CareersHeld", "💼", "Careers tried" },
	{ "WorldActions", "🌆", "Things done in town" },
	{ "ShiftsWorked", "⏰", "Extra shifts" },
	{ "DistrictsVisited", "🗺️", "Districts visited" },
	{ "ChallengesCompleted", "🎯", "Challenges done" },
	{ "TradesCompleted", "🔄", "Trades" },
}

local function tile(parent, order: number, icon: string, label: string, value: string, width: number)
	local t = Create("Frame", { Name = "Stat_" .. order, BackgroundColor3 = Theme.Color.SurfaceHigh, Size = UDim2.fromOffset(width, 64), LayoutOrder = order, Parent = parent }, { Create.Corner(Theme.RadiusSmall), Create.Padding(6, 10) })
	Create.Label({ Name = "Value", Text = icon .. " " .. value, FontFace = Theme.Font.Heavy, Size = UDim2.new(1, 0, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = t })
	Create.Label({ Name = "Label", Text = label, TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Tiny, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = t })
	return t
end

function ProfileController.Render(handle, profile)
	handle.Clear()
	handle.Subtitle.Text = if profile.IsYou then "Your profile" else "In this server"
	local scroll = handle.Scroll
	local head = Create("Frame", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), LayoutOrder = 1, Parent = scroll })
	Avatar.Badge({ Style = profile.Style, Size = 88, Parent = head })
	Create.Label({ Name = "NameLine", Text = Avatar.Line(profile.DisplayName, profile.Style), RichText = true, FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, Position = UDim2.fromOffset(102, 4), Size = UDim2.new(1, -104, 0, 32), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = head })
	Create.Label({ Name = "Legacy", Text = ("⭐ Legacy level %d · 🌟 %d rebirth%s"):format(profile.LegacyLevel, profile.Rebirths or 0, if profile.Rebirths == 1 then "" else "s"), TextColor3 = Theme.Color.Gold, Position = UDim2.fromOffset(102, 38), Size = UDim2.new(1, -104, 0, 24), Parent = head })
	Create.Label({ Name = "Counts", Text = ("🏆 %d / %d achievements · ✨ %d / %d Memory Stars"):format(profile.Achievements, profile.AchievementsTotal, profile.Stars, profile.StarsTotal), TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, Position = UDim2.fromOffset(102, 64), Size = UDim2.new(1, -104, 0, 24), Parent = head })

	if profile.CurrentLife then
		Create.Label({ Name = "CurrentLife", Text = ("Living as %s · age %d · %s%s"):format(profile.CurrentLife.Name, profile.CurrentLife.Age, profile.CurrentLife.Stage, if profile.CurrentLife.Legacy then " · 🌟 reborn" else ""), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	end
	if profile.Stats then
		local grid = Create("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = scroll })
		local list = Create.List(Enum.FillDirection.Horizontal, 8)
		list.Wraps = true
		list.Parent = grid
		local columns = if UIController.IsNarrow() then 2 else 3
		local width = math.floor((math.min(720, UIController.GetVirtualSize().X - 24) - 60 - 8 * (columns - 1)) / columns)
		for i, s in ipairs(STATS) do
			local value = profile.Stats[s[1]] or 0
			tile(grid, i, s[2], s[3], if s[4] then Format.Money(value) else Format.Commas(value), width)
		end
		tile(grid, #STATS + 1, "📚", "Endings collected", ("%d / %d"):format(profile.Stats.EndingsSeen, profile.Stats.EndingsTotal), width)
		if profile.EndingIcons and #profile.EndingIcons > 0 then
			Create.Label({ Name = "Endings", Text = "Endings: " .. table.concat(profile.EndingIcons, " "), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = scroll })
		end
	elseif profile.Private then
		Create.Label({ Name = "Private", Text = ("🔒 %s keeps their life stats private."):format(profile.DisplayName), TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = scroll })
	end
	if profile.RecentLives and #profile.RecentLives > 0 then
		Create.Label({ Text = "RECENT LIVES", TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 5, Parent = scroll })
		for i, life in ipairs(profile.RecentLives) do
			Create.Label({ Name = "Life" .. i, Text = ("%s %s · %s, lived to %d · %s · %s"):format(life.EndingIcon, life.EndingTitle, life.Name, life.Age, life.Career, Format.Money(life.NetWorth or 0)), TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5 + i, Parent = scroll })
		end
	end
	if not profile.IsYou then
		Components.Button({ Name = "OfferTrade", Text = "Offer a trade", Icon = "🔄", Style = "Accent", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 20, Parent = scroll, OnClick = function()
			UIController.ClosePanel()
			require(script.Parent.TradeController).Request(profile.UserId)
		end })
	end
end

function ProfileController.Open(userId: number?)
	local id = userId or Players.LocalPlayer.UserId
	local handle = UIController.OpenPanel({ Name = "ProfileModal", Title = "👤  Profile", Width = 760, Height = 660 })
	Create.Label({ Name = "Loading", Text = "Loading…", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = handle.Scroll })
	task.spawn(function()
		local ok, profile = Net.Invoke("GetProfile", id)
		if not handle.IsOpen() then
			return
		end
		if ok then
			ProfileController.Render(handle, profile)
		else
			handle.Clear()
			Create.Label({ Text = if profile == "NotHere" then "That player has left the server." else "Couldn't load this profile right now.", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = handle.Scroll })
		end
	end)
	return handle
end

function ProfileController.Init() end
function ProfileController.Start() end

return ProfileController
