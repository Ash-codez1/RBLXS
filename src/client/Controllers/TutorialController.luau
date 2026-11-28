--[[
	TutorialController  (StarterPlayerScripts.Client.Controllers.TutorialController)
	A short tutorial for new players: friendly tips that appear at the right
	moment (not pop-ups that block the game). Each has "Got it" and "Skip
	tutorial". Progress is saved (Tutorial.Step / Completed) so tips show
	once; Help → "Replay the tutorial" starts again.
	  1 menu (no lives yet)   press Play
	  2 first decision        pick a card, confirm; arrows and locks
	  3 first outcome         stats change; Continue
	  4 later decision        your 2 actions: People, Lifestyle, Lifeville
	  5 first exploring       walk, E / tap prompts, Next decision
	  6 second life stage     Life Reveal, Achievements, Daily reward
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Anim = require(UILib.Anim)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)

local TutorialController = {}
TutorialController.Priority = 68
TutorialController.Shown = Signal.new() -- (step)

TutorialController.Steps = {
	{ Title = "👋 Welcome to CHOOSE YOUR LIFE!", Text = "Every choice shapes your future. Press ▶ Play to begin your first life." },
	{ Title = "Make your first choice", Text = "Tap a card, then tap it again (or Confirm). The ▲▼ arrows hint at what a choice might change, 🎲 means it's risky, and 🔒 cards hint at hidden paths." },
	{ Title = "Your stats changed!", Text = "Every choice nudges your 8 stats and can open or close future paths. Press Continue to move on through the years." },
	{ Title = "Between decisions", Text = "You get 2 actions before each decision: spend time with 👥 People, set your 🎯 Lifestyle, or press 🌆 to explore Lifeville." },
	{ Title = "Exploring Lifeville", Text = "Walk with WASD, the thumbstick or a gamepad. Press E (or tap) near glowing prompts to do things or talk to people. 📝 Next decision takes you back." },
	{ Title = "You saw your first Life Reveal", Text = "Your predicted futures change with every choice you make. Check 🏆 Achievements and 🎁 Daily Reward in the menu, too. Enjoy your life!" },
}

local bubble: CanvasGroup? = nil
local showing: number? = nil
local localStep = 0
local localDone = false

local function tutorial()
	local data = DataController.Get()
	return data and data.Tutorial or { Completed = true, Step = 0 }
end

function TutorialController.Active(): boolean
	local t = tutorial()
	return not (t.Completed or localDone)
end

function TutorialController.Showing(): number?
	return showing
end

local function hide()
	if bubble then
		local b = bubble
		bubble = nil
		Anim.Fade(b, false, 0.2)
		task.delay(0.25, function()
			b:Destroy()
		end)
	end
	showing = nil
end

local function done(step: number)
	localStep = math.max(localStep, step)
	task.spawn(Net.Invoke, "TutorialStep", step)
	if step >= #TutorialController.Steps then
		localDone = true
		task.spawn(Net.Invoke, "TutorialStep", "Done")
	end
end

function TutorialController.Skip()
	hide()
	localDone = true
	task.spawn(Net.Invoke, "TutorialStep", "Done")
end

-- Shows tip `step` if it's the next one and the tutorial is on.
function TutorialController.Show(step: number)
	if not TutorialController.Active() or showing == step then
		return false
	end
	local reached = math.max(tutorial().Step or 0, localStep)
	if step ~= reached + 1 then
		return false
	end
	hide()
	local def = TutorialController.Steps[step]
	local narrow = UIController.IsNarrow()
	local width = math.min(460, UIController.GetVirtualSize().X - 24)
	local card = Create("CanvasGroup", {
		Name = "TutorialTip",
		BackgroundColor3 = Theme.Color.SurfaceHigher,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = if narrow then UDim2.new(0.5, 0, 1, -150) else UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 35,
		Parent = UIController.GetOverlay(),
	}, { Create.Corner(Theme.Radius), Create.Stroke(Theme.Color.Gold, 2, 0), Create.Padding(14, 16) })
	Create.List(Enum.FillDirection.Vertical, 8).Parent = card
	Create.Label({ Name = "Title", Text = def.Title, FontFace = Theme.Font.Heavy, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 1, Parent = card })
	Create.Label({ Name = "Text", Text = def.Text, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = card })
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3, Parent = card })
	Create.List(Enum.FillDirection.Horizontal, 8).Parent = row
	Components.Button({ Name = "GotIt", Text = "Got it", Style = "Primary", Size = UDim2.fromOffset(140, 42), TextSize = 17, LayoutOrder = 1, Parent = row, OnClick = function()
		hide()
		done(step)
	end })
	Components.Button({ Name = "SkipTutorial", Text = "Skip tutorial", Style = "Ghost", Size = UDim2.fromOffset(160, 42), TextSize = 16, LayoutOrder = 2, Parent = row, OnClick = TutorialController.Skip })
	Create.Label({ Name = "Count", Text = ("Tip %d of %d"):format(step, #TutorialController.Steps), TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextFaint, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4, Parent = card })
	Anim.Fade(card, true, 0.25)
	bubble = card
	showing = step
	TutorialController.Shown:Fire(step)
	return true
end

function TutorialController.Restart()
	localStep = 0
	localDone = false
	task.spawn(Net.Invoke, "TutorialStep", "Reset")
	UIController.Show("Menu")
	task.delay(0.5, function()
		TutorialController.Show(1)
	end)
end

-- Offers tip `target`: earlier tips the player has moved past count as done.
function TutorialController.Offer(target: number)
	local reached = math.max(tutorial().Step or 0, localStep)
	if target <= reached or showing == target then
		return
	end
	if showing and showing < target then
		hide()
	end
	if target - 1 > reached then
		done(target - 1)
	end
	TutorialController.Show(target)
end

-- Works out which tip fits what's on screen right now.
function TutorialController.Check()
	if not TutorialController.Active() then
		hide()
		return
	end
	local data = DataController.Get()
	if not data then
		return
	end
	local screen = UIController.Current()
	local life = DataController.GetActiveLife()
	local mode = require(script.Parent.DecisionController).GetMode()
	if screen == "Menu" and (not life or life.Completed) and #data.LifeHistory == 0 then
		TutorialController.Offer(1)
	elseif screen == "Game" and life and not life.Completed then
		if life.Stage >= 2 then
			TutorialController.Offer(6)
		elseif mode == "Scenario" and #life.Decisions == 0 then
			TutorialController.Offer(2)
		elseif mode == "Outcome" then
			TutorialController.Offer(3)
		elseif mode == "Scenario" then
			TutorialController.Offer(4)
		end
	elseif screen == "Explore" then
		TutorialController.Offer(5)
	end
end

function TutorialController.Init() end

function TutorialController.Start()
	UIController.ScreenChanged:Connect(function()
		task.delay(0.6, TutorialController.Check)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(TutorialController.Check)
		end
	end)
end

return TutorialController
