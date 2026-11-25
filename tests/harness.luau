--[[
	Test harness for running the game's real ModuleScripts outside Roblox, using Lune
	(https://lune-org.github.io). It builds a fake instance tree that mirrors
	default.project.json and fakes just enough of the Roblox API
	(game:GetService, Instance.new, Players, DataStoreService, Color3, Enum...).

	Not shipped to Roblox: Rojo only syncs src/.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Harness = {}
Harness.eventErrors = {}

local ROOT = "src"

-- ===== Minimal signal for fake Roblox events =====
local function fakeEvent()
	local handlers = {}
	local event = {}
	function event:Connect(fn)
		table.insert(handlers, fn)
		return { Disconnect = function()
			local i = table.find(handlers, fn)
			if i then
				table.remove(handlers, i)
			end
		end }
	end
	function event:Fire(...)
		for _, fn in ipairs(table.clone(handlers)) do
			task.spawn(function(...)
				local ok, err = xpcall(fn, debug.traceback, ...)
				if not ok then
					table.insert(Harness.eventErrors, tostring(err))
					print("[event handler error] " .. tostring(err))
				end
			end, ...)
		end
	end
	return event
end
Harness.fakeEvent = fakeEvent

-- ===== Deterministic Random (same API shape as Roblox's Random) =====
local FakeRandom = {}
FakeRandom.__index = FakeRandom
function FakeRandom.new(seed: number?)
	-- Scramble the seed so small/consecutive seeds don't start with tiny values
	-- (a weakness of plain Park-Miller), then warm up a few steps.
	local raw = math.floor(seed or (os.clock() * 1e6))
	local state = (raw * 2654435761 + 12345) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local rng = setmetatable({ _s = state }, FakeRandom)
	for _ = 1, 4 do
		rng:_next()
	end
	return rng
end
function FakeRandom:_next()
	self._s = (self._s * 48271) % 2147483647 -- Park-Miller
	return self._s / 2147483647
end
function FakeRandom:NextNumber(min: number?, max: number?)
	local x = self:_next()
	if min then
		return min + (max - min) * x
	end
	return x
end
function FakeRandom:NextInteger(min: number, max: number)
	return min + math.floor(self:_next() * (max - min + 1))
end
Harness.Random = FakeRandom

-- ===== Fake Roblox datatypes (just enough for UI code) =====
local function vec2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0, _type = "Vector2" }, {
		__add = function(a, b)
			return vec2(a.X + b.X, a.Y + b.Y)
		end,
	})
end
local udim2mt
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 }, _type = "UDim2" }, udim2mt)
end
udim2mt = {
	__add = function(a, b)
		return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
	end,
}
local function vec3(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0, _type = "Vector3" }
end
local Datatypes = {
	Vector2 = { new = vec2, zero = vec2(0, 0), one = vec2(1, 1) },
	Vector3 = { new = vec3, zero = vec3(0, 0, 0), one = vec3(1, 1, 1) },
	UDim2 = {
		new = udim2,
		fromScale = function(x, y)
			return udim2(x, 0, y, 0)
		end,
		fromOffset = function(x, y)
			return udim2(0, x, 0, y)
		end,
	},
	UDim = { new = function(s, o)
		return { Scale = s, Offset = o }
	end },
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
		new = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
		fromHex = function(hex)
			local r, g, b = tostring(hex):match("^#?(%x%x)(%x%x)(%x%x)$")
			assert(r, "bad hex colour " .. tostring(hex))
			return { R = tonumber(r, 16) / 255, G = tonumber(g, 16) / 255, B = tonumber(b, 16) / 255 }
		end,
	},
	ColorSequence = { new = function(...)
		return { _type = "ColorSequence", ... }
	end },
	ColorSequenceKeypoint = { new = function(t, c)
		return { Time = t, Value = c }
	end },
	NumberSequence = { new = function(...)
		return { _type = "NumberSequence", ... }
	end },
	NumberSequenceKeypoint = { new = function(t, v)
		return { Time = t, Value = v }
	end },
	Font = { new = function(family, weight)
		return { Family = family, Weight = weight }
	end },
	TweenInfo = { new = function(...)
		return { ... }
	end },
}
Harness.Datatypes = Datatypes

-- Enum items are unique tables so equality works: Enum.KeyCode.One == Enum.KeyCode.One
local enumCache = {}
local FakeEnum = setmetatable({}, {
	__index = function(_, enumName)
		enumCache[enumName] = enumCache[enumName] or setmetatable({}, {
			__index = function(items, itemName)
				local item = { Name = itemName, EnumType = enumName, Value = 1000 }
				rawset(items, itemName, item)
				return item
			end,
		})
		return enumCache[enumName]
	end,
})
Harness.Enum = FakeEnum

-- ===== Fake instances =====
local CLASS_PARENTS = {
	Frame = "GuiObject", TextLabel = "GuiObject", ImageLabel = "GuiObject", ScrollingFrame = "GuiObject",
	CanvasGroup = "GuiObject", TextBox = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton",
	GuiButton = "GuiObject", GuiObject = "GuiBase2d", ScreenGui = "LayerCollector", LayerCollector = "GuiBase2d",
	BloomEffect = "PostEffect", SunRaysEffect = "PostEffect", BlurEffect = "PostEffect",
	DepthOfFieldEffect = "PostEffect", ColorCorrectionEffect = "PostEffect",
}
local function isA(className, target)
	local c = className
	while c do
		if c == target or target == "Instance" then
			return true
		end
		c = CLASS_PARENTS[c]
	end
	return false
end

local EVENT_NAMES = {
	Activated = true, MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true,
	InputChanged = true, SelectionGained = true, SelectionLost = true, FocusLost = true, Focused = true,
	Changed = true, MouseButton1Click = true, AncestryChanged = true, ChildAdded = true, Destroying = true,
	CharacterAdded = true, CharacterRemoving = true,
}

local Instance = {}
local function newInstance(className: string, name: string?)
	-- Common Roblox property defaults so reads of untouched properties behave.
	local props = {
		ClassName = className,
		Name = name or className,
		Rotation = 0,
		Visible = true,
		Active = true,
		Enabled = true,
		BackgroundTransparency = 0,
		GroupTransparency = 0,
		TextTransparency = 0,
		Text = if className == "TextLabel" or className == "TextButton" or className == "TextBox" then "Label" else nil,
	}
	local inst = { _children = {}, _props = props, _events = {}, _signals = {}, _attrs = {} }
	local parent = nil
	local mt = {}
	mt.__index = function(self, key)
		if key == "Parent" then
			return parent
		end
		local props = rawget(self, "_props")
		local value = props[key]
		if value ~= nil then
			return value
		end
		local method = Instance[key]
		if method then
			return method
		end
		for _, child in ipairs(rawget(self, "_children")) do
			if child.Name == key then
				return child
			end
		end
		if EVENT_NAMES[key] then
			local events = rawget(self, "_events")
			events[key] = events[key] or fakeEvent()
			return events[key]
		end
		return nil
	end
	mt.__newindex = function(self, key, value)
		if key == "Parent" then
			if parent then
				local siblings = rawget(parent, "_children")
				local i = table.find(siblings, self)
				if i then
					table.remove(siblings, i)
				end
			end
			parent = value
			if value then
				table.insert(rawget(value, "_children"), self)
			end
		else
			rawget(self, "_props")[key] = value
			local signal = rawget(self, "_signals")[key]
			if signal then
				signal:Fire()
			end
		end
	end
	setmetatable(inst, mt)
	if className == "RemoteEvent" then
		inst.OnServerEvent = fakeEvent()
		inst.OnClientEvent = fakeEvent()
		inst.Fired = {}
		inst.FireClient = function(self, player, ...)
			table.insert(self.Fired, { Player = player, Args = table.pack(...) })
			if self.Bridge then
				self.Bridge(player, ...)
			end
		end
		inst.FireAllClients = function(self, ...)
			table.insert(self.Fired, { Player = "ALL", Args = table.pack(...) })
			if self.Bridges then
				for target in pairs(self.Bridges) do
					self.Bridge(target, ...)
				end
			end
		end
	end
	return inst
end
Harness.newInstance = newInstance

function Instance:FindFirstChild(name, recursive)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(rawget(self, "_children")) do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Instance:WaitForChild(name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild: " .. tostring(name) .. " not found under " .. self.Name)
	return child
end
function Instance:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Instance:GetDescendants()
	local out = {}
	for _, child in ipairs(rawget(self, "_children")) do
		table.insert(out, child)
		for _, d in ipairs(child:GetDescendants()) do
			table.insert(out, d)
		end
	end
	return out
end
function Instance:IsA(className)
	return isA(self.ClassName, className)
end
function Instance:FindFirstChildOfClass(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end
function Instance:FindFirstChildWhichIsA(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end
function Instance:GetPropertyChangedSignal(prop)
	local signals = rawget(self, "_signals")
	signals[prop] = signals[prop] or fakeEvent()
	return signals[prop]
end
function Instance:SetAttribute(key, value)
	rawget(self, "_attrs")[key] = value
end
function Instance:GetAttribute(key)
	return rawget(self, "_attrs")[key]
end
function Instance:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Instance:Kick(message)
	rawset(self, "KickedWith", message)
	self.Parent = nil
end

-- Builds instances from a directory using Rojo's file conventions.
local function buildTree(path: string, name: string, parent)
	local isDir = fs.isDir(path)
	local node
	if isDir and fs.isFile(path .. "/init.luau") then
		node = newInstance("ModuleScript", name)
		rawset(node, "_source", path .. "/init.luau")
	elseif isDir then
		node = newInstance("Folder", name)
	else
		local base, kind = name:match("^(.-)%.(%a+)$")
		if kind == "server" then
			node = newInstance("Script", base)
		elseif kind == "client" then
			node = newInstance("LocalScript", base)
		else
			node = newInstance("ModuleScript", name)
		end
		rawset(node, "_source", path)
	end
	if isDir then
		for _, entry in ipairs(fs.readDir(path)) do
			if entry ~= "init.luau" then
				local childName = entry:gsub("%.luau$", "")
				buildTree(path .. "/" .. entry, childName, node)
			end
		end
	end
	node.Parent = parent
	return node
end

-- ===== Environment =====
function Harness.new(options)
	options = options or {}
	local self = {}
	local moduleCache = {}

	local DataModel = newInstance("DataModel", "Game")
	local ReplicatedStorage = newInstance("ReplicatedStorage", "ReplicatedStorage")
	ReplicatedStorage.Parent = DataModel
	local ServerScriptService = newInstance("ServerScriptService", "ServerScriptService")
	ServerScriptService.Parent = DataModel
	local PlayersService = newInstance("Players", "Players")
	PlayersService.Parent = DataModel

	buildTree(ROOT .. "/shared", "Shared", ReplicatedStorage)
	buildTree(ROOT .. "/server", "Server", ServerScriptService)
	local StarterPlayerScripts = newInstance("StarterPlayerScripts", "StarterPlayerScripts")
	StarterPlayerScripts.Parent = DataModel
	buildTree(ROOT .. "/client", "Client", StarterPlayerScripts)
	local Lighting = newInstance("Lighting", "Lighting")
	Lighting.GlobalShadows = true
	Lighting.Parent = DataModel
	newInstance("BloomEffect").Parent = Lighting
	local SoundService = newInstance("SoundService", "SoundService")
	SoundService.Parent = DataModel

	-- Errors thrown inside spawned threads are recorded so tests can fail on them.
	self.errors = {}
	self.warnings = {}
	local function guard(fn)
		if type(fn) ~= "function" then
			return fn
		end
		return function(...)
			local ok, err = xpcall(fn, debug.traceback, ...)
			if not ok then
				table.insert(self.errors, tostring(err))
				if not options.QuietErrors then
					print("[thread error] " .. tostring(err))
				end
			end
		end
	end
	local guardedTask = {
		wait = task.wait,
		cancel = task.cancel,
		spawn = function(fn, ...)
			return task.spawn(guard(fn), ...)
		end,
		defer = function(fn, ...)
			return task.defer(guard(fn), ...)
		end,
		delay = function(t, fn, ...)
			return task.delay(t, guard(fn), ...)
		end,
	}
	self.guard = guard

	PlayersService.PlayerAdded = fakeEvent()
	PlayersService.PlayerRemoving = fakeEvent()
	PlayersService.GetPlayers = function()
		local list = {}
		for _, child in ipairs(PlayersService:GetChildren()) do
			if child.ClassName == "Player" then
				table.insert(list, child)
			end
		end
		return list
	end

	local closeHandlers = {}
	local services = {
		ReplicatedStorage = ReplicatedStorage,
		ServerScriptService = ServerScriptService,
		Players = PlayersService,
		RunService = {
			IsServer = function()
				return options.IsServer ~= false
			end,
			IsClient = function()
				return options.IsServer == false
			end,
			IsStudio = function()
				return options.IsStudio == true
			end,
		},
		TextService = {
			FilterStringAsync = function(_, text)
				if options.FilterFails then
					error("filter offline")
				end
				return {
					GetNonChatStringForBroadcastAsync = function()
						return (text:gsub("[Bb]adword", "#######"))
					end,
				}
			end,
		},
		Lighting = Lighting,
		SoundService = SoundService,
		TweenService = {
			Create = function(_, inst, _info, props)
				local tween = { PlaybackState = FakeEnum.PlaybackState.Begin, Completed = fakeEvent() }
				function tween:Play()
					for key, value in pairs(props) do
						inst[key] = value
					end
					self.PlaybackState = FakeEnum.PlaybackState.Completed
					local completed = self.Completed
					task.defer(function()
						completed:Fire(FakeEnum.PlaybackState.Completed)
					end)
				end
				function tween:Cancel() end
				return tween
			end,
		},
		ContextActionService = {
			Bound = {},
			BindAction = function(cas, name, fn)
				cas.Bound[name] = fn
			end,
			BindActionAtPriority = function(cas, name, fn)
				cas.Bound[name] = fn
			end,
			UnbindAction = function(cas, name)
				cas.Bound[name] = nil
			end,
		},
		GuiService = { SelectedObject = nil },
		UserInputService = {
			GamepadEnabled = options.Gamepad == true,
			TouchEnabled = options.Touch == true,
			KeyboardEnabled = options.Touch ~= true,
			GetLastInputType = function()
				return if options.Gamepad then FakeEnum.UserInputType.Gamepad1 else FakeEnum.UserInputType.Keyboard
			end,
			InputBegan = fakeEvent(),
			InputChanged = fakeEvent(),
			InputEnded = fakeEvent(),
		},
		MarketplaceService = {
			ProcessReceipt = nil,
			Prompts = {},
			OwnedPasses = options.OwnedPasses or {}, -- [userId .. ":" .. passId] = true
			PromptGamePassPurchaseFinished = fakeEvent(),
			UserOwnsGamePassAsync = function(service, userId, passId)
				if service.Unavailable then
					error("Marketplace unavailable")
				end
				return service.OwnedPasses[userId .. ":" .. passId] == true
			end,
			GetProductInfo = function(_, id)
				return { Name = "Item " .. tostring(id), PriceInRobux = 49 + id % 50 }
			end,
			PromptProductPurchase = function(service, player, id)
				table.insert(service.Prompts, { Kind = "Product", Player = player, Id = id })
			end,
			PromptGamePassPurchase = function(service, player, id)
				table.insert(service.Prompts, { Kind = "Pass", Player = player, Id = id })
			end,
		},
		SocialService = {
			Prompts = 0,
			CanSendGameInviteAsync = function()
				return true
			end,
			PromptGameInvite = function(service)
				service.Prompts += 1
			end,
		},
		TeleportService = {
			Teleports = {},
			TeleportToPlaceInstance = function(service, placeId, jobId, player)
				if options.TeleportFails ~= false then
					error("Teleport isn't available in tests")
				end
				table.insert(service.Teleports, { PlaceId = placeId, JobId = jobId, Player = player })
			end,
		},
		HttpService = {
			GenerateGUID = function()
				return tostring(math.random(1, 1e9))
			end,
		},
		DataStoreService = options.DataStoreService or {
			GetDataStore = function()
				error("StudioAccessToApisNotAllowed")
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		},
	}

	local game = DataModel
	rawset(game, "JobId", options.JobId or "")
	rawset(game, "GetService", function(_, name)
		local service = services[name]
		assert(service, "Harness: service not faked: " .. name)
		return service
	end)
	rawset(game, "BindToClose", function(_, fn)
		table.insert(closeHandlers, fn)
	end)

	local env
	local function requireNode(node)
		assert(type(node) == "table" and rawget(node, "_source"), "require: not a ModuleScript")
		local cached = moduleCache[node]
		if cached ~= nil then
			return cached.value
		end
		local source = fs.readFile(rawget(node, "_source"))
		local chunk = luau.load(source, { debugName = rawget(node, "_source"), environment = setmetatable({ script = node }, { __index = env }), injectGlobals = false })
		local value = chunk()
		moduleCache[node] = { value = value }
		return value
	end

	env = {
		print = print, pairs = pairs, ipairs = ipairs, next = next, type = type, typeof = typeof,
		tostring = tostring, tonumber = tonumber, select = select, error = error, assert = assert,
		pcall = pcall, xpcall = xpcall, setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal, unpack = unpack,
		table = table, math = math, string = string, os = os, utf8 = utf8, coroutine = coroutine,
		bit32 = bit32, buffer = buffer,
		game = game,
		debug = debug,
		task = guardedTask,
		require = requireNode,
		warn = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(self.warnings, table.concat(parts, " "))
			if not options.Quiet then
				print("[warn]", ...)
			end
		end,
		Instance = { new = function(className)
			local inst = newInstance(className)
			if className == "ScreenGui" then
				inst.AbsoluteSize = options.Viewport or Datatypes.Vector2.new(1280, 720)
			end
			return inst
		end },
		Random = FakeRandom,
		Enum = FakeEnum,
	}
	for name, lib in pairs(Datatypes) do
		env[name] = lib
	end

	function self.require(path: string)
		local node = game
		for part in path:gmatch("[^%.]+") do
			node = node:WaitForChild(part)
		end
		return requireNode(node)
	end

	-- Runs a Script/LocalScript node (e.g. "ServerScriptService.Server.Main").
	function self.run(path: string)
		local node = game
		for part in path:gmatch("[^%.]+") do
			node = node:WaitForChild(part)
		end
		local source = fs.readFile(rawget(node, "_source"))
		local chunk = luau.load(source, { debugName = rawget(node, "_source"), environment = setmetatable({ script = node }, { __index = env }), injectGlobals = false })
		chunk()
	end

	-- Makes this harness a client for `player`: creates LocalPlayer + PlayerGui.
	function self.makeLocalPlayer(userId: number, name: string)
		local player = newInstance("Player", name)
		rawset(player, "UserId", userId)
		player.DisplayName = name
		player.Parent = PlayersService
		newInstance("PlayerGui", "PlayerGui").Parent = player
		PlayersService.LocalPlayer = player
		return player
	end

	-- Another player as seen from this client (for multiplayer UI tests).
	function self.addOtherPlayer(userId: number, name: string)
		local player = newInstance("Player", name)
		rawset(player, "UserId", userId)
		player.DisplayName = name
		player.Parent = PlayersService
		PlayersService.PlayerAdded:Fire(player)
		return player
	end

	function self.addPlayer(userId: number, name: string)
		local player = newInstance("Player", name)
		rawset(player, "UserId", userId)
		player.DisplayName = name
		player.Parent = PlayersService
		PlayersService.PlayerAdded:Fire(player)
		return player
	end

	function self.removePlayer(player)
		PlayersService.PlayerRemoving:Fire(player)
		player.Parent = nil
	end

	function self.close()
		for _, fn in ipairs(closeHandlers) do
			fn()
		end
	end

	function self.remote(name: string)
		return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
	end

	self.game = game
	self.env = env
	return self
end

-- Wires a client harness's remotes to a server harness as `serverPlayer`.
-- Arguments and results are deep-copied, like real remotes serialise them.
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in pairs(v) do
		c[k] = copy(x)
	end
	return c
end
function Harness.bridge(server, client, serverPlayer)
	local serverFolder = server.game.ReplicatedStorage:WaitForChild("Remotes")
	local folder = newInstance("Folder", "Remotes")
	for _, remote in ipairs(serverFolder:GetChildren()) do
		local proxy = newInstance(remote.ClassName, remote.Name)
		if remote.ClassName == "RemoteFunction" then
			proxy.InvokeServer = function(_, ...)
				local args = copy(table.pack(...))
				local results = table.pack(remote.OnServerInvoke(serverPlayer, table.unpack(args, 1, args.n)))
				return table.unpack(copy(results), 1, results.n)
			end
		else
			-- Several clients can be bridged to one server (multiplayer tests).
			remote.Bridges = remote.Bridges or {}
			remote.Bridges[serverPlayer] = proxy
			remote.Bridge = function(target, ...)
				local clientProxy = remote.Bridges[target]
				if clientProxy then
					clientProxy.OnClientEvent:Fire(table.unpack(copy(table.pack(...))))
				end
			end
		end
		proxy.Parent = folder
	end
	folder.Parent = client.game.ReplicatedStorage
end

-- Finds the first descendant matching a predicate.
function Harness.find(root, predicate)
	for _, d in ipairs(root:GetDescendants()) do
		if predicate(d) then
			return d
		end
	end
	return nil
end

-- ===== Tiny test runner =====
local results = { passed = 0, failed = 0, failures = {} }

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
		print("  ✓ " .. name)
	else
		results.failed += 1
		table.insert(results.failures, name .. ": " .. tostring(err))
		print("  ✗ " .. name .. "\n      " .. tostring(err))
	end
end

function Harness.section(name: string)
	print("\n" .. name)
end

function Harness.eq(actual, expected, label: string?)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(label and (label .. ": ") or "", tostring(expected), tostring(actual)), 2)
	end
end

function Harness.ok(value, label: string?)
	if not value then
		error((label or "assertion") .. " failed", 2)
	end
end

function Harness.near(actual, expected, tolerance, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(("%sexpected ~%s, got %s"):format(label and (label .. ": ") or "", tostring(expected), tostring(actual)), 2)
	end
end

Harness.results = results
return Harness
