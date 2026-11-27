--[[
	GatesController  (StarterPlayerScripts.Client.Controllers.GatesController)
	Areas of Lifeville that open later in life (World.Districts UnlockStage,
	World.Locks) are surrounded by walls tagged CYL_Lock. They are invisible
	and walk-through on the server; on your client, the ones you haven't
	unlocked yet become shimmering walls with "🔒 Opens in …" signs.
	(The server still refuses actions there, whatever a client does.)
	If you're standing inside an area that's locked for your life (e.g. you
	started a new life while Downtown), you're taken back to the Plaza.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Data.World)

local UILib = script.Parent.Parent:WaitForChild("UILib")
local Theme = require(UILib.Theme)

local DataController = require(script.Parent.DataController)

local GatesController = {}
GatesController.Priority = 57
GatesController.PlazaSpawn = Vector3.new(0, 4, 32)

local lastStage: number? = nil

local function stage(): number
	local life = DataController.GetActiveLife()
	return World.StageOf(if life and not life.Completed then life else nil)
end

local function lockInfo(lockId: string)
	return World.Locks[lockId] or World.ById[lockId]
end

local function label(wall: BasePart, face)
	local name = "CYL_LockLabel" .. face.Name
	local gui = wall:FindFirstChild(name)
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 6
		gui.LightInfluence = 0
		gui.Parent = wall
		local text = Instance.new("TextLabel")
		text.Name = "Label"
		text.BackgroundTransparency = 1
		local height = wall.Size.Y
		local top = wall.Position.Y + height / 2
		text.Position = UDim2.fromScale(0.05, math.clamp((top - 9) / height, 0, 0.9))
		text.Size = UDim2.fromScale(0.9, math.clamp(5 / height, 0.05, 1))
		text.TextScaled = true
		text.FontFace = Theme.Font.Heavy
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextStrokeTransparency = 0.3
		text.Parent = gui
	end
	return gui
end

function GatesController.Apply(wall: BasePart, currentStage: number)
	local lockId = wall:GetAttribute("LockId")
	local info = lockInfo(lockId)
	if not info then
		return
	end
	local open = currentStage >= info.UnlockStage
	wall.CanCollide = not open
	wall.Transparency = if open then 1 else 0.55
	local text = ("🔒 %s · %s"):format(info.Name, World.UnlockText(info.UnlockStage))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local horizontalFace = face == Enum.NormalId.Front or face == Enum.NormalId.Back
		local wide = if horizontalFace then wall.Size.X >= wall.Size.Z else wall.Size.Z > wall.Size.X
		if wide then
			local gui = label(wall, face)
			gui.Enabled = not open
			gui.Label.Text = text
		end
	end
end

local function insideLocked(position: Vector3, currentStage: number): boolean
	local districtId = World.DistrictAt(position.X, position.Z)
	return districtId ~= nil and not World.IsUnlocked(districtId, currentStage)
end

function GatesController.Refresh()
	local current = stage()
	lastStage = current
	for _, wall in ipairs(CollectionService:GetTagged("CYL_Lock")) do
		GatesController.Apply(wall, current)
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and insideLocked(root.Position, current) then
		character:PivotTo(CFrame.new(GatesController.PlazaSpawn))
	end
end

function GatesController.Init() end

function GatesController.Start()
	GatesController.Refresh()
	DataController.Changed:Connect(function()
		if stage() ~= lastStage then
			GatesController.Refresh()
		end
	end)
	CollectionService:GetInstanceAddedSignal("CYL_Lock"):Connect(function(wall)
		GatesController.Apply(wall, stage())
	end)
end

return GatesController
