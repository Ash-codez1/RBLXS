--[[
	PlotService  (ServerScriptService.Server.Services.PlotService)
	Gives every player a house plot on Oak Street (8 plots per server) and
	keeps their house matching their life: family home → own place → house
	or mansion, with their equipped house style, car, pet and centrepiece
	(see World/Homes). Other players can visit; only the owner can use the
	"Rest at home" and "Family dinner" spots there (WorldService checks).

	Plot models carry attributes OwnerUserId and OwnerName for the client.
	PlotService.PlotOf(player) -> plot model?
]]

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local ShopService = require(script.Parent.ShopService)
local Homes = require(script.Parent.Parent.World.Homes)

local PlotService = {}
PlotService.Priority = 19
PlotService.RefreshSeconds = 3

local owners: { [Player]: Model } = {}
local keys: { [Model]: string } = {}

local function plots(): { Model }
	local world = WorldService.Folder()
	local folder = world and world:FindFirstChild("Plots")
	local list = {}
	if folder then
		for _, plot in ipairs(folder:GetChildren()) do
			if plot:IsA("Model") and plot:FindFirstChild("Base") then
				table.insert(list, plot)
			end
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	return list
end

function PlotService.PlotOf(player: Player): Model?
	return owners[player]
end

local function spotPartsIn(plot: Model): { BasePart }
	local list = {}
	for _, part in ipairs(plot:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("CYL_Spot") then
			table.insert(list, part)
		end
	end
	return list
end

local function unregisterSpots(plot: Model)
	for _, part in ipairs(spotPartsIn(plot)) do
		WorldService.UnregisterSpot(part)
	end
end

local function registerSpots(plot: Model)
	for _, part in ipairs(spotPartsIn(plot)) do
		WorldService.RegisterSpot(part)
	end
end

-- Rebuilds the player's house if anything it shows has changed.
function PlotService.Refresh(player: Player)
	local plot = owners[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	local spec = Homes.SpecFor(player, data)
	if keys[plot] == spec.Key then
		return
	end
	unregisterSpots(plot)
	Homes.Build(plot, spec)
	registerSpots(plot)
	keys[plot] = spec.Key
end

function PlotService.Assign(player: Player): Model?
	if owners[player] then
		return owners[player]
	end
	for _, plot in ipairs(plots()) do
		if not plot:GetAttribute("OwnerUserId") then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName or player.Name)
			owners[player] = plot
			PlotService.Refresh(player)
			return plot
		end
	end
	return nil -- the street is full; everything else still works
end

function PlotService.Release(player: Player)
	local plot = owners[player]
	if not plot then
		return
	end
	owners[player] = nil
	keys[plot] = nil
	unregisterSpots(plot)
	Homes.Clear(plot)
	Homes.ResetSign(plot)
	plot:SetAttribute("OwnerUserId", nil)
	plot:SetAttribute("OwnerName", nil)
end

-- The player's own home spot (WorldService.HomeSpot hook).
local function homeSpot(player: Player, spotId: string): BasePart?
	local plot = owners[player]
	if not plot then
		return nil
	end
	for _, part in ipairs(spotPartsIn(plot)) do
		if part:GetAttribute("CYL_Spot") == spotId then
			return part
		end
	end
	return nil
end

function PlotService.Init()
	WorldService.HomeSpot = homeSpot
end

function PlotService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		PlotService.Assign(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService.IsLoaded(player) then
			PlotService.Assign(player)
		end
	end
	Players.PlayerRemoving:Connect(PlotService.Release)
	ShopService.EquipmentChanged:Connect(function(player)
		PlotService.Refresh(player)
	end)
	-- Lives change through many systems (choices, events, group decisions),
	-- so houses are compared on a short timer; rebuilding only happens when
	-- something visible changed.
	task.spawn(function()
		while true do
			task.wait(PlotService.RefreshSeconds)
			for player in pairs(owners) do
				if player.Parent then
					local ok, err = pcall(PlotService.Refresh, player)
					if not ok then
						warn("[PlotService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return PlotService
