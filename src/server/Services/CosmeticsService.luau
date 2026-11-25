--[[
	CosmeticsService  (ServerScriptService.Server.Services.CosmeticsService)
	Shows equipped cosmetics on the player's Roblox character for everyone in
	the server: a name tag (with title and name colour) above the head, and
	an aura (Sparkles / Fire / Smoke, built-in effects with no asset ids
	needed). Reapplied on spawn and whenever equipment changes. Visible once
	the 3D world is in play (Phase 8).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared.Util.Style)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local CosmeticsService = {}
CosmeticsService.Priority = 17

local TAG = "CYL_Cosmetic"

local function color(hex: string?, fallback: Color3): Color3
	if type(hex) == "string" then
		local ok, value = pcall(Color3.fromHex, hex)
		if ok then
			return value
		end
	end
	return fallback
end

function CosmeticsService.Apply(player: Player)
	local character = player.Character
	local data = DataService.Get(player)
	if not character or not data then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:GetAttribute(TAG) then
			d:Destroy()
		end
	end
	local style = Style.Of(data.Inventory.Equipped)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our name tag replaces it
	end
	if head then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "CYL_NameTag"
		billboard:SetAttribute(TAG, true)
		billboard.Size = UDim2.fromOffset(220, 56)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = 80
		billboard.Adornee = head
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0.6, 0)
		name.Text = player.DisplayName
		name.TextScaled = true
		name.TextColor3 = color(style.NameColor, Color3.fromRGB(255, 255, 255))
		name.TextStrokeTransparency = 0.4
		name.Font = Enum.Font.GothamBold
		name.Parent = billboard
		if style.Title then
			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.BackgroundTransparency = 1
			title.Position = UDim2.fromScale(0, 0.6)
			title.Size = UDim2.new(1, 0, 0.4, 0)
			title.Text = style.Title
			title.TextScaled = true
			title.TextColor3 = Color3.fromRGB(255, 212, 90)
			title.TextStrokeTransparency = 0.5
			title.Font = Enum.Font.Gotham
			title.Parent = billboard
		end
		billboard.Parent = head
	end
	if root and style.Aura then
		local aura = style.Aura
		local effect
		if aura.Kind == "Fire" then
			effect = Instance.new("Fire")
			effect.Color = color(aura.Color, Color3.fromRGB(255, 106, 0))
			effect.SecondaryColor = color(aura.Secondary, Color3.fromRGB(255, 208, 0))
			effect.Size = 4
			effect.Heat = 6
		elseif aura.Kind == "Smoke" then
			effect = Instance.new("Smoke")
			effect.Color = color(aura.Color, Color3.fromRGB(180, 140, 255))
			effect.Opacity = 0.15
			effect.RiseVelocity = 2
			effect.Size = 2
		else
			effect = Instance.new("Sparkles")
			effect.SparkleColor = color(aura.Color, Color3.fromRGB(255, 255, 255))
		end
		effect.Name = "CYL_Aura"
		effect:SetAttribute(TAG, true)
		effect.Parent = root
	end
end

function CosmeticsService.Init()
	ShopService.EquipmentChanged:Connect(function(player)
		CosmeticsService.Apply(player)
	end)
end

function CosmeticsService.Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait() -- let the character finish assembling
			CosmeticsService.Apply(player)
		end)
		if player.Character then
			CosmeticsService.Apply(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return CosmeticsService
