--[[
	HelpController  (StarterPlayerScripts.Client.Controllers.HelpController)
	❓ Help & support (main menu → Help): short answers to the common
	questions (tap one to open it), how to report a problem or a player,
	the game version, and buttons to replay the tutorial or open Settings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local StatDefinitions = require(Shared.Data.StatDefinitions)
local World = require(Shared.Data.World)
local People = require(Shared.Util.People)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local UIController = require(script.Parent.UIController)

local HelpController = {}
HelpController.Priority = 67

local frame: CanvasGroup
local openTopic: string? = "HowToPlay"

local function statsText(): string
	local lines = {}
	for _, name in ipairs(StatDefinitions.Order) do
		local info = StatDefinitions.Info[name]
		table.insert(lines, ("%s %s: %s"):format(info.Icon, info.DisplayName, info.Description))
	end
	return table.concat(lines, "\n")
end

HelpController.Topics = {
	{ Id = "HowToPlay", Title = "How do I play?", Icon = "🎮", Text = function()
		return "You live a whole life, from age 5 to 85, through six life stages. Each decision card shows a situation: tap a choice, then confirm. The arrows hint at what it might change, and 🎲 means it's risky. Locked cards hint at hidden paths you could unlock with different choices."
	end },
	{ Id = "Stats", Title = "What do the stats mean?", Icon = "📊", Text = statsText },
	{ Id = "Actions", Title = "Actions and Lifeville", Icon = "🌆", Text = function()
		return ("Between decisions you get %d actions. Spend them on 👥 People (time, gifts, talks), or press 🌆 to explore Lifeville: study at school, run in the park, eat out, work an extra shift at your job and more. More of the town opens as you grow up: Downtown and the harbour at %d, the university and Career Row at %d, the Sunset Club at %d."):format(People.ActionsPerTurn, World.StageAges[2], World.StageAges[3], World.StageAges[6])
	end },
	{ Id = "Reveal", Title = "What is the Life Reveal?", Icon = "🔮", Text = function()
		return "At the end of every life stage, the Life Reveal predicts your possible futures from your real choices and stats. The odds change as you live, sometimes with a twist. At 85 you get your ending, and you can compare what was predicted with what really happened in 📜 Life History."
	end },
	{ Id = "Coins", Title = "Coins, the shop and passes", Icon = "🪙", Text = function()
		return "You earn Coins by playing: finishing stages and lives, joining group decisions and city events, achievements, challenges and daily rewards. Spend them in the 🛍️ Shop on cosmetics: outfits, homes, cars, pets, titles and effects. Nothing you can buy changes your life's choices or outcomes."
	end },
	{ Id = "Extras", Title = "Achievements, challenges and daily rewards", Icon = "🏆", Text = function()
		return "🏆 Achievements unlock as you play (some are secret!). 🎯 New daily and weekly challenges pay Coins automatically when you finish them. 🎁 Claim a daily reward every day to build a streak; day 7 is the big one. ⭐ Memory Stars are hidden all over Lifeville."
	end },
	{ Id = "Rebirth", Title = "Rebirth and Legacy perks", Icon = "🌟", Text = function()
		return "Every life you complete raises your Legacy level and unlocks perks. When you start a new life you can be reborn with one of them, like a head start in Intelligence or Health. Perks are earned by playing, never bought."
	end },
	{ Id = "Friends", Title = "Playing with friends", Icon = "🤝", Text = function()
		return "Invite players in your server to a Life Circle to vote on group decisions, watch Group Life Reveals and compare futures. Your life always stays your own. You can also trade cosmetic items: both players see the offers and must press Ready, and only items bought with Coins can be traded."
	end },
	{ Id = "Safety", Title = "Privacy and safety", Icon = "🛡️", Text = function()
		return "Settings → Privacy decides who can see your futures, life stats and past lives (Everyone, Friends or Nobody). Choosing Nobody also keeps you off the global leaderboards. Names are filtered by Roblox. To report a player, open the Roblox menu (☰ or Esc) and choose Report."
	end },
	{ Id = "Support", Title = "Something not working?", Icon = "🧰", Text = function()
		return Config.Support .. "\n\nVersion " .. Config.Version
	end },
}

local function render()
	Create.Clear(frame, true)
	Layout.Header(frame, "Help", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(frame)
	local width = math.min(760, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	for i, topic in ipairs(HelpController.Topics) do
		local open = openTopic == topic.Id
		Components.Button({ Name = "Topic_" .. topic.Id, Text = topic.Title, Icon = topic.Icon, Style = if open then "Primary" else "Secondary", Size = UDim2.fromOffset(width, 50), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i * 2, Parent = column, OnClick = function()
			openTopic = if open then nil else topic.Id
			render()
		end })
		if open then
			local panel = Components.Panel({ Name = "Answer_" .. topic.Id, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 16, LayoutOrder = i * 2 + 1, Parent = column, Color = Theme.Color.SurfaceHigh })
			Create.Label({ Name = "Text", Text = topic.Text(), AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), Parent = panel })
		end
	end
	local row = Create("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 54), LayoutOrder = 100, Parent = column })
	Create.List(Enum.FillDirection.Horizontal, 10).Parent = row
	Components.Button({ Name = "ReplayTutorial", Text = "Replay the tutorial", Icon = "▶", Style = "Accent", Size = UDim2.fromOffset(math.floor((width - 10) / 2), 52), TextSize = 17, LayoutOrder = 1, Parent = row, OnClick = function()
		require(script.Parent.TutorialController).Restart()
	end })
	Components.Button({ Name = "OpenSettings", Text = "Settings", Icon = "⚙️", Style = "Secondary", Size = UDim2.fromOffset(math.floor((width - 10) / 2), 52), TextSize = 17, LayoutOrder = 2, Parent = row, OnClick = function()
		UIController.Show("Settings")
	end })
end

function HelpController.Open(topicId: string?)
	openTopic = topicId or openTopic
	UIController.Show("Help")
end

function HelpController.Init()
	frame = UIController.NewScreen("Help", { Back = true, OnOpen = render })
end

function HelpController.Start()
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Help" then
			render()
		end
	end)
end

return HelpController
