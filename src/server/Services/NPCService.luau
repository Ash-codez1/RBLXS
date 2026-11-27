--[[
	NPCService  (ServerScriptService.Server.Services.NPCService)
	Spawns the people of Lifeville (Shared/Data/NPCs) at the anchors the
	district builders placed (World.NPCAnchors), into Workspace.World.NPCs:
	  • R15 characters built with Players:CreateHumanoidModelFromDescription
	    (skin, shirt and trouser colours), with simple hair and hats, a name tag
	    and a "Talk" ProximityPrompt (attribute CYL_NPC = id);
	  • idle animation plus a wave / point / dance now and then;
	  • six townsfolk walk loops round town (World.WalkLoops).
	Animations are Roblox's default R15 animations; if one can't load the
	character simply stands still.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCs = require(Shared.Data.NPCs)
local World = require(Shared.Data.World)

local WorldService = require(script.Parent.WorldService)

local NPCService = {}
NPCService.Priority = 18

NPCService.Animations = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
	Dance = "rbxassetid://507771019",
}

local rigs: { [string]: Model } = {}
local folder: Folder? = nil

local function colour(hex: string?, fallback: string): Color3
	return Color3.fromHex(hex or fallback)
end

function NPCService.Get(npcId: string): Model?
	return rigs[npcId]
end

function NPCService.PositionOf(npcId: string): Vector3?
	local rig = rigs[npcId]
	local root = rig and rig:FindFirstChild("HumanoidRootPart")
	return if root then root.Position else nil
end

-- A blocky stand-in if Roblox can't build a character (keeps the world usable).
local function blockyRig(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local function part(partName, size, y)
		local p = Instance.new("Part")
		p.Name = partName
		p.Size = size
		p.CFrame = CFrame.new(0, y, 0)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), 3)
	root.Transparency = 1
	local torso = part("UpperTorso", Vector3.new(2, 2, 1), 3)
	local head = part("Head", Vector3.new(1.2, 1.2, 1.2), 4.6)
	local legs = part("LowerTorso", Vector3.new(2, 2, 1), 1)
	for _, p in ipairs({ torso, head, legs }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 0
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	model.PrimaryPart = root
	return model
end

local function buildRig(npc): Model
	local looks = npc.Looks or {}
	local skin = colour(looks.Skin, "#F1C27D")
	local shirt = colour(looks.Shirt, "#457B9D")
	local pants = colour(looks.Pants, "#1D3557")
	local ok, rig = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = skin
		description.TorsoColor = shirt
		description.LeftArmColor = shirt
		description.RightArmColor = shirt
		description.LeftLegColor = pants
		description.RightLegColor = pants
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[NPCService] Using a simple character for " .. npc.Id .. ": " .. tostring(rig))
		rig = blockyRig(npc.Id)
		for _, p in ipairs(rig:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.Color = if p.Name == "Head" then skin elseif p.Name == "LowerTorso" then pants else shirt
			end
		end
	end
	rig.Name = "NPC_" .. npc.Id
	rig:SetAttribute("CYL_NPC", npc.Id)
	return rig
end

-- Hair and hats: plain parts welded to the head.
local function attach(head: BasePart, name: string, size: Vector3, offset: CFrame, col: Color3, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Color = col
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = p
	weld.Parent = p
	p.Parent = head.Parent
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders stand along Y

local function decorate(rig: Model, looks)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local top = head.Size.Y / 2
	local hair = if looks.Hair then Color3.fromHex(looks.Hair) else nil
	local style = looks.HairStyle or "Short"
	if hair and style ~= "Bald" then
		attach(head, "Hair", Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, top + 0.05, 0.02), hair)
		local backLength = if style == "Long" then 1.5 else 0.7
		attach(head, "HairBack", Vector3.new(1.3, backLength, 0.3), CFrame.new(0, top - backLength / 2 + 0.1, 0.55), hair)
		if style == "Bun" then
			attach(head, "Bun", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, top + 0.25, 0.5), hair, Enum.PartType.Ball)
		end
	end
	local hat = looks.Hat
	if hat == "Top" then
		attach(head, "Hat", Vector3.new(1.1, 1, 1), CFrame.new(0, top + 0.6, 0) * UPRIGHT, Color3.fromHex("#111111"), Enum.PartType.Cylinder)
		attach(head, "Brim", Vector3.new(0.1, 1.7, 1.7), CFrame.new(0, top + 0.1, 0) * UPRIGHT, Color3.fromHex("#111111"), Enum.PartType.Cylinder)
	elseif hat == "Cap" or hat == "Flat" then
		attach(head, "Hat", Vector3.new(1.35, 0.4, 1.35), CFrame.new(0, top + 0.15, 0), Color3.fromHex(looks.Shirt or "#E63946"))
		attach(head, "Brim", Vector3.new(1.1, 0.1, 0.6), CFrame.new(0, top, -0.85), Color3.fromHex(looks.Shirt or "#E63946"))
	elseif hat == "Grad" then
		attach(head, "Hat", Vector3.new(1.25, 0.35, 1.25), CFrame.new(0, top + 0.12, 0), Color3.fromHex("#111111"))
		attach(head, "Board", Vector3.new(1.8, 0.1, 1.8), CFrame.new(0, top + 0.35, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromHex("#111111"))
	elseif hat == "Police" or hat == "Captain" then
		local crown = if hat == "Police" then "#1D3557" else "#F8F9FA"
		attach(head, "Hat", Vector3.new(0.5, 1.35, 1.35), CFrame.new(0, top + 0.2, 0) * UPRIGHT, Color3.fromHex(crown), Enum.PartType.Cylinder)
		attach(head, "Brim", Vector3.new(1, 0.1, 0.5), CFrame.new(0, top, -0.8), Color3.fromHex("#111111"))
	elseif hat == "Chef" then
		attach(head, "Hat", Vector3.new(1.3, 1.1, 1.1), CFrame.new(0, top + 0.6, 0) * UPRIGHT, Color3.fromHex("#FFFFFF"), Enum.PartType.Cylinder)
	elseif hat == "Nurse" then
		attach(head, "Hat", Vector3.new(0.9, 0.35, 0.5), CFrame.new(0, top + 0.12, -0.2), Color3.fromHex("#FFFFFF"))
	elseif hat == "Hard" then
		attach(head, "Hat", Vector3.new(1.45, 0.55, 1.45), CFrame.new(0, top + 0.18, 0), Color3.fromHex("#FFD60A"))
	elseif hat == "Beret" then
		attach(head, "Hat", Vector3.new(0.25, 1.4, 1.4), CFrame.new(0.1, top + 0.08, 0) * UPRIGHT * CFrame.Angles(0, 0, math.rad(10)), Color3.fromHex("#9D0208"), Enum.PartType.Cylinder)
	elseif hat == "Ranger" then
		attach(head, "Hat", Vector3.new(0.6, 1.2, 1.2), CFrame.new(0, top + 0.3, 0) * UPRIGHT, Color3.fromHex("#BC8A5F"), Enum.PartType.Cylinder)
		attach(head, "Brim", Vector3.new(0.1, 2, 2), CFrame.new(0, top + 0.05, 0) * UPRIGHT, Color3.fromHex("#BC8A5F"), Enum.PartType.Cylinder)
	end
end

local function nameTag(rig: Model, npc)
	local head = rig:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CYL_NPCTag"
	gui.Size = UDim2.fromOffset(220, 52)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 55
	gui.LightInfluence = 0
	gui.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.58, 0)
	nameLabel.Text = (npc.Icon or "") .. " " .. npc.Name
	nameLabel.TextScaled = true
	nameLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = gui
	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "Role"
	roleLabel.BackgroundTransparency = 1
	roleLabel.Position = UDim2.fromScale(0, 0.6)
	roleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	roleLabel.Text = npc.Role or ""
	roleLabel.TextScaled = true
	roleLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	roleLabel.TextColor3 = Color3.fromRGB(255, 214, 90)
	roleLabel.TextStrokeTransparency = 0.5
	roleLabel.Parent = gui
end

local function talkPrompt(rig: Model, npc)
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = (npc.Icon or "") .. " " .. npc.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("CYL_NPC", npc.Id)
	prompt.Parent = root
end

local function load(rig: Model, key: string)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local ok, track = pcall(function()
		local animation = Instance.new("Animation")
		animation.Name = key
		animation.AnimationId = NPCService.Animations[key]
		return animator:LoadAnimation(animation)
	end)
	return if ok then track else nil
end

local function animate(rig: Model, npc)
	local idle = load(rig, "Idle")
	if idle then
		idle.Looped = true
		idle:Play()
	end
	local gestureKey = npc.Anim
	if gestureKey == "Dance" then
		local dance = load(rig, "Dance")
		if dance then
			dance.Looped = true
			dance:Play()
		end
	elseif gestureKey == "Wave" or gestureKey == "Point" then
		local gesture = load(rig, gestureKey)
		if gesture then
			task.spawn(function()
				local rng = Random.new(#npc.Id * 97)
				while rig.Parent do
					task.wait(rng:NextNumber(8, 16))
					if rig.Parent then
						gesture:Play()
					end
				end
			end)
		end
	end
end

local function standingCFrame(rig: Model, anchor: BasePart): CFrame
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local floorY = anchor.Position.Y - anchor.Size.Y / 2
	local height = (if humanoid then humanoid.HipHeight else 2) + (if root then root.Size.Y / 2 else 1)
	return anchor.CFrame.Rotation + Vector3.new(anchor.Position.X, floorY + height, anchor.Position.Z)
end

-- `place` is an anchor part (stand on it) or a CFrame for the root part.
local function spawnAt(npc, place, anchored: boolean): Model
	local rig = buildRig(npc)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	rig:PivotTo(if typeof(place) == "Instance" then standingCFrame(rig, place) else place)
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = anchored
	end
	decorate(rig, npc.Looks or {})
	nameTag(rig, npc)
	talkPrompt(rig, npc)
	rig.Parent = folder
	if root and not anchored then
		pcall(function()
			root:SetNetworkOwner(nil) -- the server moves walkers, not nearby players
		end)
	end
	rigs[npc.Id] = rig
	animate(rig, npc)
	return rig
end

local function waitForMove(humanoid: Humanoid, timeout: number): boolean
	local done, reached = false, false
	local connection = humanoid.MoveToFinished:Connect(function(ok)
		done = true
		reached = ok
	end)
	local waited = 0
	while not done and waited < timeout do
		waited += task.wait(0.25)
	end
	connection:Disconnect()
	return reached
end

local function walk(rig: Model, loop)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = loop.Speed or 7
	local walkTrack = load(rig, "Walk")
	if walkTrack then
		walkTrack.Looped = true
	end
	humanoid.Running:Connect(function(speed)
		if walkTrack then
			if speed > 0.5 and not walkTrack.IsPlaying then
				walkTrack:Play()
			elseif speed <= 0.5 and walkTrack.IsPlaying then
				walkTrack:Stop()
			end
		end
	end)
	local district = World.ById[loop.District]
	local points = {}
	for _, p in ipairs(loop.Points) do
		table.insert(points, Vector3.new(district.X + p[1], 0.2, district.Z + p[2]))
	end
	local index = 2
	while rig.Parent do
		local target = points[index]
		humanoid:MoveTo(target)
		if not waitForMove(humanoid, 30) then
			-- Stuck (or blocked by a player): hop to the corner and carry on.
			rig:PivotTo(CFrame.new(target + Vector3.new(0, 3, 0)))
		end
		index = index % #points + 1
		task.wait(0.4)
	end
end

function NPCService.Init()
	WorldService.NPCPosition = NPCService.PositionOf
end

function NPCService.Start()
	local world = WorldService.Folder()
	if not world then
		return
	end
	folder = world:FindFirstChild("NPCs") :: Folder?
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "NPCs"
		f.Parent = world
		folder = f
	end
	local anchors = world:FindFirstChild("NPCAnchors")
	for _, npc in ipairs(NPCs.List) do
		local anchor = anchors and anchors:FindFirstChild(npc.Id)
		if anchor then
			local ok, err = pcall(spawnAt, npc, anchor, true)
			if not ok then
				warn("[NPCService] Couldn't spawn " .. npc.Id .. ": " .. tostring(err))
			end
		end
	end
	for _, loop in ipairs(World.WalkLoops) do
		local npc = NPCs.ById[loop.Walker]
		local district = World.ById[loop.District]
		if npc and district then
			local first = loop.Points[1]
			local ok, rig = pcall(spawnAt, npc, CFrame.new(district.X + first[1], 3.2, district.Z + first[2]), false)
			if ok then
				task.spawn(walk, rig, loop)
			else
				warn("[NPCService] Couldn't spawn walker " .. npc.Id .. ": " .. tostring(rig))
			end
		end
	end
end

return NPCService
