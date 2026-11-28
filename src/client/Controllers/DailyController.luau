--[[
	DailyController  (StarterPlayerScripts.Client.Controllers.DailyController)
	🎁 Daily reward panel: the 7-day reward track, your streak, and Claim.
	Opens from the main menu (🎁 Daily Reward) or Achievements → Challenges;
	once per visit a reminder appears when a reward is waiting.
	The server decides the day and pays the reward (DailyService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local Challenges = require(Shared.Data.Challenges)
local DailyRules = require(Shared.Util.Daily)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local AudioController = require(script.Parent.AudioController)

local DailyController = {}
DailyController.Priority = 63

local shownThisVisit = false
local busy = false

function DailyController.Status()
	local data = DataController.Get()
	if not data then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	return DailyRules.Status(data.Daily, Challenges.DayOf(now), now)
end

function DailyController.IsClaimable(): boolean
	local status = DailyController.Status()
	return status ~= nil and status.Claimable
end

local function hours(seconds: number): string
	return ("%dh %dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

function DailyController.Open()
	local status = DailyController.Status()
	if not status then
		return
	end
	local handle = UIController.OpenPanel({ Name = "DailyModal", Title = "🎁  Daily Reward", Width = 680, Height = 520 })
	handle.Subtitle.Text = ("🔥 %d-day streak · come back every day for bigger rewards"):format(DataController.Get().Daily.Streak or 0)
	local scroll = handle.Scroll
	local track = Create("Frame", { Name = "Track", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	local list = Create.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	list.Wraps = true
	list.Parent = track
	local currentDay = status.Day
	local doneUpTo = if status.Claimable then currentDay - 1 else currentDay
	local tileWidth = math.min(80, math.floor((UIController.GetVirtualSize().X - 120) / 7))
	for day, coins in ipairs(Config.DailyRewards) do
		local today = status.Claimable and day == currentDay
		local tile = Create("Frame", { Name = "Day" .. day, BackgroundColor3 = if today then Theme.Color.Primary elseif day <= doneUpTo then Theme.Color.SurfaceHigher else Theme.Color.Surface, Size = UDim2.fromOffset(tileWidth, 104), LayoutOrder = day, Parent = track }, { Create.Corner(Theme.RadiusSmall), Create.Stroke(if day == #Config.DailyRewards then Theme.Color.Gold else Theme.Color.Stroke, if day == #Config.DailyRewards then 2 else 1, 0.2) })
		Create.Label({ Text = "Day " .. day, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Bold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), Parent = tile })
		Create.Label({ Text = if day <= doneUpTo then "✅" elseif day == #Config.DailyRewards then "💰" else "🪙", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 36), Parent = tile })
		Create.Label({ Name = "Coins", Text = tostring(coins), FontFace = Theme.Font.Heavy, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 24), Parent = tile })
		if today then
			Anim.Pop(tile, 0.9, 0.4)
		end
	end
	local message = Create.Label({ Name = "Message", Text = if status.Claimable then ("Day %d of your streak: 🪙 %d Coins are waiting!"):format(currentDay, status.Reward) else ("You've claimed today's reward. Come back in %s."):format(hours(status.SecondsLeft)), TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	local claim = Components.Button({ Name = "Claim", Text = if status.Claimable then ("Claim 🪙 %d"):format(status.Reward) else "Claimed ✓", Icon = "🎁", Style = "Primary", Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 3, Parent = scroll, OnClick = function(button)
		if busy or not DailyController.IsClaimable() then
			return
		end
		busy = true
		local ok, result = Net.Invoke("ClaimDaily")
		busy = false
		if ok then
			AudioController.Play("Positive")
			NotificationController.Notify({ Title = "🎁 Daily reward", Text = ("+%d 🪙 · %d-day streak!"):format(result.Coins, result.Streak), Kind = "Success", Duration = 4 })
			message.Text = ("+%d Coins! See you tomorrow for day %d."):format(result.Coins, (result.Day % #Config.DailyRewards) + 1)
			Components.SetText(button, "🎁  Claimed ✓")
			Components.SetDisabled(button, true)
		else
			message.Text = if result == "AlreadyClaimed" then "Already claimed today." else "Couldn't claim right now. Try again in a moment."
		end
	end })
	if not status.Claimable then
		Components.SetDisabled(claim, true)
	end
	Create.Label({ Text = "Miss a day and your streak starts again at day 1. Day 7 is the big one!", TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = scroll })
	return handle
end

function DailyController.Init() end

function DailyController.Start()
	-- A gentle reminder (not a pop-up that blocks the menu) once per visit.
	UIController.ScreenChanged:Connect(function(screen)
		if screen == "Menu" and not shownThisVisit then
			shownThisVisit = true
			task.delay(1.5, function()
				local status = DailyController.Status()
				if status and status.Claimable then
					NotificationController.Notify({ Title = "🎁 Daily reward ready", Text = ("Day %d of your streak: 🪙 %d. Open 🎁 Daily Reward in the menu."):format(status.Day, status.Reward), Kind = "Info", Duration = 6 })
				end
			end)
		end
	end)
end

return DailyController
