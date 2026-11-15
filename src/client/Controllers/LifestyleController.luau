--[[
	LifestyleController  (StarterPlayerScripts.Client.Controllers.LifestyleController)
	The 🎯 Lifestyle panel: choose what this life prioritises as the years
	pass (Shared/Data/Lifestyle). Free to change at any time; the server
	applies the focus every simulated year.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Lifestyle = require(Shared.Data.Lifestyle)
local StatDefinitions = require(Shared.Data.StatDefinitions)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)

local LifestyleController = {}
LifestyleController.Priority = 43

local handle = nil
local busy = false

local function effectText(info, age: number): string
	local parts = {}
	local perYear = if age < 19 and info.YouthPerYear then info.YouthPerYear else info.PerYear
	for stat, delta in pairs(perYear or {}) do
		local stat_info = StatDefinitions.Info[stat]
		if stat_info and not (stat == "Career" and age < 19) then
			table.insert(parts, ("%s%s"):format(stat_info.Icon, if delta > 0 then "▲" else "▼"))
		end
	end
	if info.SavingsBonus then
		table.insert(parts, "💰 saves more")
	end
	if info.BondDecay then
		local grows = false
		for _, v in pairs(info.BondDecay) do
			grows = grows or v < 0
		end
		table.insert(parts, if grows then "💞 bonds grow" else "💔 bonds fade faster")
	end
	if info.PromotionMultiplier then
		table.insert(parts, if info.PromotionMultiplier > 1 then "📈 faster promotions" else "📉 slower promotions")
	end
	table.sort(parts)
	return table.concat(parts, "   ")
end

local function render()
	local life = DataController.GetActiveLife()
	if not handle or not life then
		return
	end
	handle.Clear()
	local current = Lifestyle.Info[life.Focus] or Lifestyle.Info.Balanced
	handle.Subtitle.Text = "Current focus: " .. current.Icon .. " " .. current.Title .. " · applies every year that passes"
	for i, id in ipairs(Lifestyle.Order) do
		local info = Lifestyle.Info[id]
		local available = Lifestyle.Available(id, life.Age)
		local selected = life.Focus == id
		local card = Create("TextButton", {
			Name = id,
			Text = "",
			AutoButtonColor = false,
			Selectable = true,
			BackgroundColor3 = if selected then Theme.Color.SurfaceHigher else Theme.Color.SurfaceHigh,
			BackgroundTransparency = if available then 0.05 else 0.5,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = handle.Scroll,
		}, { Create.Corner(Theme.RadiusSmall), Create.Stroke(if selected then Theme.Color.Primary else Theme.Color.Stroke, if selected then 3 else 1.5, if selected then 0 else 0.4), Create.Padding(12, 16) })
		Create.List(Enum.FillDirection.Vertical, 4).Parent = card
		Create.Label({ Text = info.Icon .. "  " .. info.Title .. (if selected then "   ✓ CURRENT" else ""), FontFace = Theme.Font.Heavy, TextSize = Theme.TextSize.H3, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
		Create.Label({ Text = if available then info.Description else ("Available from age %d."):format(info.MinAge or 0), TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
		Create.Label({ Text = effectText(info, life.Age), FontFace = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Gold, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = card })
		card.Activated:Connect(function()
			if busy or selected or not available then
				return
			end
			if Components.OnClickSound then
				Components.OnClickSound()
			end
			busy = true
			local ok, result = Net.Invoke("SetFocus", id)
			busy = false
			if ok then
				NotificationController.Notify({ Title = "🎯 Lifestyle", Text = "Focus set to " .. info.Title .. ".", Kind = "Success", Duration = 2.5 })
			else
				NotificationController.Notify({ Title = "Not now", Text = tostring(result), Kind = "Warning", Duration = 3 })
			end
			task.wait(0.25)
			if handle and handle.IsOpen() then
				render()
			end
		end)
	end
end

function LifestyleController.Open()
	if not DataController.GetActiveLife() then
		return
	end
	handle = UIController.OpenPanel({ Name = "LifestyleModal", Title = "🎯  Lifestyle Focus", Width = 700, OnClose = function()
		handle = nil
	end })
	render()
end

function LifestyleController.Init()
	HUDController.AddAction({ Id = "Lifestyle", Icon = "🎯", Order = 20, OnClick = LifestyleController.Open })
end

function LifestyleController.Start()
	DataController.Changed:Connect(function()
		if handle and handle.IsOpen() and not busy then
			render()
		end
	end)
end

return LifestyleController
