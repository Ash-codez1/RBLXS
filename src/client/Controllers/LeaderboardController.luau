--[[
	LeaderboardController  (StarterPlayerScripts.Client.Controllers.LeaderboardController)
	🏆 The Leaderboards screen (main menu): pick a board (lives lived,
	richest life, achievements, login streak, Memory Stars) and Global or
	Friends. Your row is highlighted; tap a player in this server to see
	their profile. Results are cached for a minute to go easy on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Leaderboards = require(Shared.Data.Leaderboards)
local Format = require(Shared.Util.Format)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)
local Create = require(UILib.Create)
local Components = require(UILib.Components)
local Layout = require(UILib.Layout)

local UIController = require(script.Parent.UIController)

local LeaderboardController = {}
LeaderboardController.Priority = 64
LeaderboardController.CacheSeconds = 60

local frame: CanvasGroup
local boardId = Leaderboards.List[1].Id
local scope = "Global"
local cache = {}
local loading = false

local MEDALS = { "🥇", "🥈", "🥉" }

local function inServer(userId: number): boolean
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return true
		end
	end
	return false
end

function LeaderboardController.Fetch(id: string, which: string, force: boolean?)
	local key = id .. ":" .. which
	local cached = cache[key]
	if cached and not force and os.clock() - cached.Time < LeaderboardController.CacheSeconds then
		return true, cached.Result
	end
	local ok, result = Net.Invoke("GetLeaderboard", id, which)
	if ok then
		cache[key] = { Time = os.clock(), Result = result }
	end
	return ok, result
end

local function valueText(board, value: number): string
	return if board.Money then Format.Money(value) else Format.Commas(value)
end

local render

local function renderList(column, width: number)
	local board = Leaderboards.ById[boardId]
	local list = Create("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10, Parent = column })
	Create.List(Enum.FillDirection.Vertical, 6).Parent = list
	local status = Create.Label({ Name = "Status", Text = "Loading…", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0, Parent = list })
	loading = true
	local ok, result = LeaderboardController.Fetch(boardId, scope)
	loading = false
	if not list.Parent then
		return
	end
	if not ok then
		status.Text = if result == "RateLimited" then "Slow down a moment, then try again." else "Couldn't load this leaderboard right now."
		return
	end
	local me = Players.LocalPlayer.UserId
	if #result.Entries == 0 then
		status.Text = if scope == "Friends" then "None of your Roblox friends have a score here yet. Invite them!" else "No scores yet. Be the first!"
	else
		status.Text = if result.Offline then "Studio test mode: scores are kept only until you press Stop." else ""
	end
	for i, entry in ipairs(result.Entries) do
		local mine = entry.UserId == me
		local row = Create("TextButton", { Name = "Entry_" .. entry.UserId, Text = "", AutoButtonColor = false, BackgroundColor3 = if mine then Theme.Color.SurfaceHigher else Theme.Color.Surface, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, Parent = list }, { Create.Corner(Theme.RadiusSmall), Create.Stroke(if mine then Theme.Color.Primary else Theme.Color.Stroke, if mine then 2 else 1, if mine then 0 else 0.5), Create.Padding(0, 14) })
		Create.Label({ Name = "Rank", Text = MEDALS[entry.Rank] or ("#" .. entry.Rank), FontFace = Theme.Font.Heavy, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 56, 1, 0), Parent = row })
		Create.Label({ Name = "Name", Text = entry.Name .. (if mine then " (you)" else ""), FontFace = Theme.Font.Bold, Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -240, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = row })
		Create.Label({ Name = "Value", Text = board.Icon .. " " .. valueText(board, entry.Value), FontFace = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 170, 1, 0), Parent = row })
		if inServer(entry.UserId) then
			row.Activated:Connect(function()
				require(script.Parent.ProfileController).Open(entry.UserId)
			end)
		end
	end
	if result.You == nil and scope == "Global" and #result.Entries > 0 then
		Create.Label({ Text = "You're not in the top " .. #result.Entries .. " yet. Keep living!", TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 999, Parent = list })
	end
end

function render()
	Create.Clear(frame, true)
	Layout.Header(frame, "Leaderboards", function()
		UIController.Back()
	end)
	local scroll = Layout.Scroll(frame)
	local width = math.min(820, UIController.GetVirtualSize().X - 32)
	local column = Layout.Column(scroll, width)
	local boards = Create("Frame", { Name = "Boards", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = column })
	local list = Create.List(Enum.FillDirection.Horizontal, 8)
	list.Wraps = true
	list.Parent = boards
	for i, board in ipairs(Leaderboards.List) do
		Components.Button({ Name = "Board_" .. board.Id, Text = board.Name, Icon = board.Icon, Style = if board.Id == boardId then "Primary" else "Secondary", Size = UDim2.fromOffset(if UIController.IsNarrow() then 240 else 196, 44), TextSize = 16, LayoutOrder = i, Parent = boards, OnClick = function()
			if not loading then
				boardId = board.Id
				render()
			end
		end })
	end
	local scopes = Create("Frame", { Name = "Scopes", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 46), LayoutOrder = 2, Parent = column })
	Create.List(Enum.FillDirection.Horizontal, 8).Parent = scopes
	for i, s in ipairs({ { "Global", "🌍" }, { "Friends", "🤝" } }) do
		Components.Button({ Name = "Scope_" .. s[1], Text = s[1], Icon = s[2], Style = if scope == s[1] then "Accent" else "Secondary", Size = UDim2.fromOffset(160, 44), TextSize = 17, LayoutOrder = i, Parent = scopes, OnClick = function()
			if not loading then
				scope = s[1]
				render()
			end
		end })
	end
	Components.Button({ Name = "Refresh", Text = "Refresh", Icon = "🔄", Style = "Ghost", Size = UDim2.fromOffset(140, 44), TextSize = 16, LayoutOrder = 3, Parent = scopes, OnClick = function()
		cache[boardId .. ":" .. scope] = nil
		render()
	end })
	task.spawn(renderList, column, width)
end

function LeaderboardController.Open(id: string?, which: string?)
	boardId = id or boardId
	scope = which or scope
	UIController.Show("Leaderboards")
end

function LeaderboardController.Init()
	frame = UIController.NewScreen("Leaderboards", { Back = true, OnOpen = render })
end

function LeaderboardController.Start()
	UIController.LayoutChanged:Connect(function()
		if UIController.Current() == "Leaderboards" then
			render()
		end
	end)
end

return LeaderboardController
