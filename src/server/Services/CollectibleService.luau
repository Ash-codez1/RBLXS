--[[
	CollectibleService  (ServerScriptService.Server.Services.CollectibleService)
	Memory Stars (Shared/Data/Collectibles) hidden around Lifeville.
	CollectStar(starId): the server checks the star exists, you haven't found
	it already, and your character is right next to it; then it's saved,
	pays Collectibles.Coins, and may unlock a secret achievement.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Collectibles = require(Shared.Data.Collectibles)

local Server = script.Parent.Parent
local Validate = require(Server.Lib.Validate)
local CoinRewards = require(Server.Lib.CoinRewards)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local WorldService = require(script.Parent.WorldService)

local CollectibleService = {}
CollectibleService.Priority = 24
CollectibleService.MaxDistance = 12

local stars: { [string]: BasePart } = {}

function CollectibleService.Part(starId: string): BasePart?
	return stars[starId]
end

function CollectibleService.Collect(player: Player, starId: string)
	local def = Collectibles.ById[starId]
	local part = stars[starId]
	if not def or not part then
		return false, "NoSuchStar"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	if data.Collectibles[starId] then
		return false, "AlreadyFound"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - part.Position).Magnitude > CollectibleService.MaxDistance then
		return false, "TooFar"
	end
	local found = 0
	DataService.Update(player, function(d)
		d.Collectibles[starId] = true
		CoinRewards.GrantBonus(d, Collectibles.Coins)
		for _ in pairs(d.Collectibles) do
			found += 1
		end
	end)
	if def.Secret then
		ProgressService.Unlock(player, def.Secret)
	end
	return true, { Found = found, Total = Collectibles.Total, Coins = Collectibles.Coins }
end

function CollectibleService.Init()
	local world = WorldService.Folder()
	for _, part in ipairs(CollectionService:GetTagged("CYL_Star")) do
		if not world or part:IsDescendantOf(world) then
			stars[part:GetAttribute("CYL_Star")] = part
		end
	end
end

function CollectibleService.Start()
	Net.Handle("CollectStar", function(player, starId)
		local id = Validate.Id(starId, 32)
		if not id then
			return false, "BadArgs"
		end
		return CollectibleService.Collect(player, id)
	end)
end

return CollectibleService
