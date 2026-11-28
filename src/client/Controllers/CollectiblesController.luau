--[[
	CollectiblesController  (StarterPlayerScripts.Client.Controllers.CollectiblesController)
	✨ Memory Stars in Lifeville: stars you've already found are hidden on
	your screen (their prompt and sparkle switch off), and collecting one
	asks the server (CollectibleService), which checks you're next to it.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Collectibles = require(Shared.Data.Collectibles)

local DataController = require(script.Parent.DataController)
local AudioController = require(script.Parent.AudioController)

local CollectiblesController = {}
CollectiblesController.Priority = 69

local busy = false

local function apply(star: BasePart)
	local data = DataController.Get()
	local found = data ~= nil and data.Collectibles[star:GetAttribute("CYL_Star")] == true
	star.Transparency = if found then 1 else 0
	local prompt = star:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not found
	end
	local sparkle = star:FindFirstChildOfClass("ParticleEmitter")
	if sparkle then
		sparkle.Enabled = not found
	end
end

function CollectiblesController.Refresh()
	for _, star in ipairs(CollectionService:GetTagged("CYL_Star")) do
		apply(star)
	end
end

function CollectiblesController.Collect(starId: string)
	if busy then
		return false
	end
	busy = true
	local ok, result = Net.Invoke("CollectStar", starId)
	busy = false
	local Explore = require(script.Parent.ExploreController)
	if ok then
		AudioController.Play("Positive")
		Explore.ShowCard("✨ Memory Star found!", ("%d of %d found · +%d 🪙"):format(result.Found, result.Total, result.Coins) .. (if result.Found == result.Total then "\n🌟 You found them all!" else ""), nil, "Result")
	elseif result ~= "AlreadyFound" then
		Explore.ShowCard("✨ Memory Star", if result == "TooFar" then "Get a little closer." else "Couldn't collect it right now.", nil, "Problem")
	end
	CollectiblesController.Refresh()
	return ok, result
end

function CollectiblesController.Found(): number
	local data = DataController.Get()
	local n = 0
	for id in pairs(data and data.Collectibles or {}) do
		if Collectibles.ById[id] then
			n += 1
		end
	end
	return n
end

function CollectiblesController.Init() end

function CollectiblesController.Start()
	CollectionService:GetInstanceAddedSignal("CYL_Star"):Connect(apply)
	DataController.Changed:Connect(CollectiblesController.Refresh)
	CollectiblesController.Refresh()
end

return CollectiblesController
