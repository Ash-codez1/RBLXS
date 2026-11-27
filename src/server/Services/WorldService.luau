--[[
	WorldService  (ServerScriptService.Server.Services.WorldService)
	Lifeville on the server:
	  • builds the town into Workspace.World when the server starts (or keeps
	    a World you baked into the place, see World/Town);
	  • sets up lighting effects (the day/night cycle runs on each client from
	    the shared server clock, see Shared/Data/World.ClockTimeAt);
	  • handles WorldAction(spotId, npcId?) — the server decides:
	      - the spot exists and isn't just a menu shortcut,
	      - your character is actually there (near the spot, or near the NPC
	        offering it), or in your own home for home spots,
	      - then Actions.World checks age, career, unlocks, money and the
	        2-actions-per-decision budget (shared with the People panel).

	Hooks set by other services (avoids circular requires):
	  WorldService.NPCPosition(npcId) -> Vector3?      (NPCService)
	  WorldService.HomeSpot(player, spotId) -> BasePart? (PlotService)
	Signals: WorldService.ActionDone(player, spotId, result)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local WorldSpots = require(Shared.Data.WorldSpots)
local NPCs = require(Shared.Data.NPCs)

local Server = script.Parent.Parent
local Validate = require(Server.Lib.Validate)
local Town = require(Server.World.Town)

local LifeService = require(script.Parent.LifeService)

local WorldService = {}
WorldService.Priority = 12
WorldService.ActionDone = Signal.new()
WorldService.MaxSpotDistance = 16
WorldService.MaxNPCDistance = 18

WorldService.NPCPosition = function(_npcId: string): Vector3?
	return nil
end
WorldService.HomeSpot = function(_player: Player, _spotId: string): BasePart?
	return nil
end

local world: Folder? = nil
local spotParts: { [string]: { BasePart } } = {}

function WorldService.Folder(): Folder?
	return world
end

function WorldService.SpotParts(spotId: string): { BasePart }
	return spotParts[spotId] or {}
end

function WorldService.RegisterSpot(part: BasePart)
	local id = part:GetAttribute("CYL_Spot")
	if type(id) == "string" then
		spotParts[id] = spotParts[id] or {}
		if not table.find(spotParts[id], part) then
			table.insert(spotParts[id], part)
		end
	end
end

function WorldService.UnregisterSpot(part: BasePart)
	local id = part:GetAttribute("CYL_Spot")
	local list = type(id) == "string" and spotParts[id]
	if list then
		local i = table.find(list, part)
		if i then
			table.remove(list, i)
		end
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root then root.Position else nil
end

local function npcOffers(npcId: string, spotId: string): boolean
	local npc = NPCs.ById[npcId]
	if not npc or not npc.Options then
		return false
	end
	for _, option in ipairs(npc.Options) do
		if option.Spot == spotId then
			return true
		end
	end
	return false
end

-- Validates where the player is, then runs the action on their life.
function WorldService.Use(player: Player, spotId: string, npcId: string?)
	local def = WorldSpots.Get(spotId)
	if not def or def.Kind == "Open" then
		return false, "BadSpot"
	end
	local position = rootPosition(player)
	if not position then
		return false, "NoCharacter"
	end
	local extra = {}
	if npcId then
		if not npcOffers(npcId, spotId) then
			return false, "BadSpot"
		end
		local npcPosition = WorldService.NPCPosition(npcId)
		if not npcPosition or (npcPosition - position).Magnitude > WorldService.MaxNPCDistance then
			return false, "TooFar"
		end
	elseif def.OwnHome then
		local part = WorldService.HomeSpot(player, spotId)
		if not part then
			return false, "NotYourHome"
		end
		if (part.Position - position).Magnitude > WorldService.MaxSpotDistance then
			return false, "TooFar"
		end
		extra.OwnHome = true
	else
		local nearest = math.huge
		for _, part in ipairs(WorldService.SpotParts(spotId)) do
			nearest = math.min(nearest, (part.Position - position).Magnitude)
		end
		if nearest > WorldService.MaxSpotDistance then
			return false, "TooFar"
		end
	end
	local ok, result = LifeService.WorldAction(player, spotId, extra)
	if ok then
		WorldService.ActionDone:Fire(player, spotId, result)
	end
	return ok, result
end

local function ensureEffect(className: string, name: string, props)
	local effect = Lighting:FindFirstChild(name)
	if not effect then
		effect = Instance.new(className)
		effect.Name = name
		for key, value in pairs(props) do
			effect[key] = value
		end
		effect.Parent = Lighting
	end
	return effect
end

local function setupLighting()
	ensureEffect("Atmosphere", "Atmosphere", { Density = 0.28, Offset = 0.2, Color = Color3.fromRGB(199, 214, 230), Decay = Color3.fromRGB(106, 112, 125), Glare = 0.15, Haze = 1.1 })
	ensureEffect("BloomEffect", "Bloom", { Intensity = 0.4, Size = 24, Threshold = 1.7 })
	ensureEffect("SunRaysEffect", "SunRays", { Intensity = 0.05, Spread = 0.6 })
	ensureEffect("ColorCorrectionEffect", "WorldColour", { Saturation = 0.08, Contrast = 0.04, Brightness = 0 })
end

local function ensureSpawn()
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			return
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.66, 32)
	spawn.Duration = 0
	spawn.Parent = workspace
end

function WorldService.Init()
	world = workspace:FindFirstChild("World") :: Folder?
	if not world then
		world = Town.Build(workspace)
	end
	for _, part in ipairs(CollectionService:GetTagged("CYL_Spot")) do
		if part:IsDescendantOf(world) then
			WorldService.RegisterSpot(part)
		end
	end
	ensureSpawn()
	setupLighting()
end

function WorldService.Start()
	Net.Handle("WorldAction", function(player, spotId, npcId)
		local id = Validate.Id(spotId, 32)
		if not id then
			return false, "BadArgs"
		end
		local npc = nil
		if npcId ~= nil then
			npc = Validate.Id(npcId, 24)
			if not npc then
				return false, "BadArgs"
			end
		end
		return WorldService.Use(player, id, npc)
	end)
end

return WorldService
