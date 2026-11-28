--[[
	DialogueController  (StarterPlayerScripts.Client.Controllers.DialogueController)
	Talking to the people of Lifeville (Shared/Data/NPCs). Their greeting
	depends on your life stage and career. Options can reply, do a world
	action right there (the server checks you're next to them), open a
	screen (shop, bank, map, Hall of Lives), point the way on the map, or
	give a tip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NPCs = require(Shared.Data.NPCs)
local WorldSpots = require(Shared.Data.WorldSpots)
local World = require(Shared.Data.World)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local ExploreController = require(script.Parent.ExploreController)

local DialogueController = {}
DialogueController.Priority = 54

local tipIndex = 0

local function activeLife()
	local life = DataController.GetActiveLife()
	return if life and not life.Completed then life else nil
end

function DialogueController.Tip(): string
	local life = activeLife()
	if life then
		if ExploreController.ActionsLeft(life) == 0 then
			return "You've used your actions for now. Press 📝 Next decision to move your life on, then come back!"
		end
		if life.Career.Id == "None" and life.Age >= 19 then
			return "No job yet? The careers fair in Lifeville Tower (Downtown) builds Career Success."
		end
	end
	tipIndex = tipIndex % #Config.LoadingTips + 1
	return Config.LoadingTips[tipIndex]
end

function DialogueController.Open(npcId: string)
	local npc = NPCs.ById[npcId]
	if not npc then
		return
	end
	task.spawn(Net.Invoke, "Talk", npcId) -- counts for achievements and challenges
	local handle = UIController.OpenPanel({ Name = "DialogueModal", Title = (npc.Icon or "💬") .. "  " .. npc.Name, Width = 600, Height = 560 })
	handle.Subtitle.Text = npc.Role or ""
	local life = activeLife()
	local age = if life then life.Age else 5

	local function render(line: string, note: string?)
		handle.Clear()
		local bubble = Components.Panel({ Name = "Speech", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Padding = 16, Color = Theme.Color.SurfaceHigh, LayoutOrder = 1, Parent = handle.Scroll })
		Create.Label({ Name = "Line", Text = "“" .. line .. "”", AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), Parent = bubble })
		if note then
			Create.Label({ Name = "Note", Text = note, TextColor3 = Theme.Color.Warning, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = handle.Scroll })
		end
		local order = 10
		for i, option in ipairs(npc.Options or {}) do
			if NPCs.OptionVisible(option, age) then
				order += 1
				local label = option.Text
				local icon = "💬"
				if option.Spot then
					local def = WorldSpots.Get(option.Spot)
					local cost = if def and life then WorldSpots.CostFor(def, life.Age) else 0
					icon = "⚡"
					if cost > 0 then
						label ..= " (" .. Format.Money(cost) .. ")"
					end
				elseif option.Open then
					icon = "➡️"
				elseif option.Guide then
					icon = "🧭"
				elseif option.Tip then
					icon = "💡"
				end
				Components.Button({ Name = "Option" .. i, Text = label, Icon = icon, Style = if option.Spot then "Primary" else "Secondary", Size = UDim2.new(1, 0, 0, 50), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = handle.Scroll, OnClick = function()
					if option.Reply then
						render(option.Reply)
					elseif option.Tip then
						render(DialogueController.Tip())
					elseif option.Open then
						UIController.ClosePanel()
						ExploreController.OpenScreen(option.Open)
					elseif option.Guide then
						UIController.ClosePanel()
						require(script.Parent.MapController).SetWaypoint(option.Guide)
					elseif option.Spot then
						local ok, result = ExploreController.UseSpot(option.Spot, npc.Id)
						if handle.IsOpen() then
							if ok then
								render(result.Text or "Done!", ("⚡ %d action%s left before your next decision."):format(result.ActionsLeft or 0, if result.ActionsLeft == 1 then "" else "s"))
							else
								render(NPCs.LineFor(npc, life), ExploreController.ReasonText(result, WorldSpots.Get(option.Spot)))
							end
						end
					end
				end })
			end
		end
		if npc.Options and life and ExploreController.ActionsLeft(life) == 0 then
			Create.Label({ Name = "NoActions", Text = "⚡ No actions left until your next decision.", TextColor3 = Theme.Color.TextFaint, TextSize = Theme.TextSize.Tiny, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 90, Parent = handle.Scroll })
		end
		Components.Button({ Name = "Goodbye", Text = "Goodbye", Icon = "👋", Style = "Ghost", Size = UDim2.new(1, 0, 0, 46), TextSize = 17, LayoutOrder = 99, Parent = handle.Scroll, OnClick = UIController.ClosePanel })
	end

	render(NPCs.LineFor(npc, life))
	return handle
end

-- Which district an NPC lives in (from their anchor), for the map and tips.
function DialogueController.DistrictOf(npcId: string): string?
	local world = workspace:FindFirstChild("World")
	local anchor = world and world:FindFirstChild("NPCAnchors") and world.NPCAnchors:FindFirstChild(npcId)
	return if anchor then World.DistrictAt(anchor.Position.X, anchor.Position.Z) else nil
end

function DialogueController.Init() end
function DialogueController.Start() end

return DialogueController
