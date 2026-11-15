--[[
	FinanceController  (StarterPlayerScripts.Client.Controllers.FinanceController)
	The 💰 Money panel: net worth, this year's budget (from Shared/Util/Budget,
	the exact maths the server uses), investments and loans.
	Invest / withdraw / repay are validated by the server (Lib/Actions).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Budget = require(Shared.Util.Budget)
local Format = require(Shared.Util.Format)
local Assets = require(Shared.Data.Assets)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)
local DecisionController = require(script.Parent.DecisionController)

local FinanceController = {}
FinanceController.Priority = 44
FinanceController.MinAge = 18

local LINE_LABELS = {
	Salary = "💼 Salary savings",
	Pension = "🏖️ Pension",
	PartTime = "☕ Part-time job",
	Rent = "🏠 Rent",
	Children = "👶 Raising children",
	Loans = "🏦 Loan repayments",
	Unemployed = "📭 Living costs (no job)",
}
local LINE_ORDER = { "Salary", "Pension", "PartTime", "Rent", "Children", "Loans", "Unemployed" }

local handle = nil
local busy = false
local render

local function act(remote: string, ...)
	if busy then
		return
	end
	busy = true
	local ok, result = Net.Invoke(remote, ...)
	busy = false
	if ok then
		NotificationController.Notify({ Title = "💰 Money", Text = if result.PaidOff then "Loan paid off! 🎉" else "Done.", Kind = "Success", Duration = 2 })
		DecisionController.Refresh()
	else
		NotificationController.Notify({ Title = "Not now", Text = tostring(result), Kind = "Warning", Duration = 3 })
	end
	task.wait(0.25)
	if handle and handle.IsOpen() then
		render()
	end
end

local function row(parent, order: number, left: string, right: string, color: Color3?, bold: boolean?)
	local frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = parent })
	Create.Label({ Text = left, Size = UDim2.new(0.65, 0, 1, 0), FontFace = if bold then Theme.Font.Heavy else Theme.Font.Medium, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	Create.Label({ Text = right, Size = UDim2.new(0.35, 0, 1, 0), Position = UDim2.fromScale(0.65, 0), TextXAlignment = Enum.TextXAlignment.Right, FontFace = Theme.Font.Heavy, TextColor3 = color or Theme.Color.Text, TextWrapped = false, Parent = frame })
	return frame
end

local function section(parent, order: number, title: string)
	Create.Label({ Text = title, TextSize = Theme.TextSize.Tiny, FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Primary, Size = UDim2.new(1, 0, 0, 24), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = parent })
end

local function buttonRow(parent, order: number, buttons)
	local frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent })
	local list = Create.List(Enum.FillDirection.Horizontal, 8)
	list.Wraps = true
	list.Parent = frame
	for i, b in ipairs(buttons) do
		local button = Components.Button({ Name = b.Name, Text = b.Text, Style = b.Style or "Secondary", Size = UDim2.fromOffset(b.Width or 150, 46), TextSize = 17, LayoutOrder = i, Parent = frame, OnClick = b.OnClick })
		if b.Disabled then
			Components.SetDisabled(button, true)
		end
	end
end

local function amountButtons(prefix: string, remote: string, pool: number, style: string)
	local list = {}
	for _, share in ipairs({ 0.1, 0.25, 0.5, 1 }) do
		local amount = math.floor(pool * share)
		table.insert(list, {
			Name = prefix .. tostring(math.floor(share * 100)),
			Text = (if share == 1 then "All " else ("%d%% "):format(share * 100)) .. Format.Money(amount),
			Style = style,
			Width = 170,
			Disabled = amount < 1,
			OnClick = function()
				act(remote, amount)
			end,
		})
	end
	return list
end

function render()
	local life = DataController.GetActiveLife()
	if not handle or not life then
		return
	end
	handle.Clear()
	local scroll = handle.Scroll
	local netWorth = Budget.NetWorth(life)
	handle.Subtitle.Text = "Net worth " .. Format.Money(netWorth)

	section(scroll, 1, "WHAT YOU HAVE")
	row(scroll, 2, "💵 Cash", Format.Money(life.Money))
	row(scroll, 3, "📈 Investments", Format.Money(life.Investments or 0))
	local order = 4
	for id in pairs(life.Assets) do
		local info = Assets.Info[id]
		if info then
			row(scroll, order, info.Icon .. " " .. info.Title, Format.Money(info.Value))
			order += 1
		end
	end
	for _, loan in ipairs(life.Loans) do
		row(scroll, order, "🏦 " .. (if loan.Kind == "Mortgage" then "Mortgage" else "Student loan"), "-" .. Format.Money(loan.Balance), Theme.Color.Negative)
		order += 1
	end
	row(scroll, 19, "Net worth", Format.Money(netWorth), if netWorth >= 0 then Theme.Color.Positive else Theme.Color.Negative, true)

	section(scroll, 20, "EACH YEAR")
	local budget = Budget.Breakdown(life)
	local lineOrder = 21
	for _, key in ipairs(LINE_ORDER) do
		local amount = budget.Lines[key]
		if amount then
			row(scroll, lineOrder, LINE_LABELS[key], (if amount > 0 then "+" else "") .. Format.Money(amount), if amount >= 0 then Theme.Color.Positive else Theme.Color.Negative)
			lineOrder += 1
		end
	end
	if budget.GrossSalary > 0 then
		Create.Label({
			Text = ("You save %d%% of %s/yr. A 'Save Money' lifestyle or the Thrifty trait raises this."):format(math.floor(budget.SavingsRate * 100 + 0.5), Format.Money(budget.GrossSalary)),
			TextSize = Theme.TextSize.Tiny,
			TextColor3 = Theme.Color.TextFaint,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 38,
			Parent = scroll,
		})
	end
	row(scroll, 39, "Per year", (if budget.Net >= 0 then "+" else "") .. Format.Money(budget.Net), if budget.Net >= 0 then Theme.Color.Positive else Theme.Color.Negative, true)

	section(scroll, 40, "INVESTING")
	if life.Age < FinanceController.MinAge then
		Create.Label({ Text = ("Investing unlocks at age %d."):format(FinanceController.MinAge), TextColor3 = Theme.Color.TextDim, LayoutOrder = 41, Parent = scroll })
	else
		Create.Label({ Text = "Investments grow about 6% a year on average, but markets swing, and sometimes crash.", TextColor3 = Theme.Color.TextDim, TextSize = Theme.TextSize.Small, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 41, Parent = scroll })
		Create.Label({ Text = "Invest from cash:", FontFace = Theme.Font.Bold, LayoutOrder = 42, Parent = scroll })
		buttonRow(scroll, 43, amountButtons("Invest", "Invest", life.Money, "Positive"))
		Create.Label({ Text = "Withdraw to cash:", FontFace = Theme.Font.Bold, LayoutOrder = 44, Parent = scroll })
		buttonRow(scroll, 45, amountButtons("Withdraw", "Withdraw", life.Investments or 0, "Secondary"))
	end

	if #life.Loans > 0 then
		section(scroll, 50, "LOANS")
		for i, loan in ipairs(life.Loans) do
			local name = if loan.Kind == "Mortgage" then "Mortgage" else "Student loan"
			Create.Label({ Text = ("%s · %s left · %s/yr · %.1f%% interest"):format(name, Format.Money(loan.Balance), Format.Money(loan.Payment), loan.Rate * 100), LayoutOrder = 50 + i * 2, AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
			local payable = math.min(life.Money, loan.Balance)
			buttonRow(scroll, 51 + i * 2, {
				{ Name = "Repay" .. i .. "Quarter", Text = "Pay " .. Format.Money(math.floor(payable * 0.25)), Width = 180, Disabled = math.floor(payable * 0.25) < 1, OnClick = function()
					act("RepayLoan", i, math.floor(payable * 0.25))
				end },
				{ Name = "Repay" .. i .. "Max", Text = (if payable >= loan.Balance then "Pay it all off " else "Pay ") .. Format.Money(payable), Style = "Primary", Width = 220, Disabled = payable < 1, OnClick = function()
					act("RepayLoan", i, payable)
				end },
			})
		end
	end
end

function FinanceController.Open()
	if not DataController.GetActiveLife() then
		return
	end
	handle = UIController.OpenPanel({ Name = "MoneyModal", Title = "💰  Money", Width = 720, OnClose = function()
		handle = nil
	end })
	render()
end

function FinanceController.Init()
	HUDController.AddAction({ Id = "Money", Icon = "💰", Order = 30, OnClick = FinanceController.Open })
end

function FinanceController.Start()
	DataController.Changed:Connect(function()
		if handle and handle.IsOpen() and not busy then
			render()
		end
	end)
end

return FinanceController
