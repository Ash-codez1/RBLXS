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
			task.spawn(fn, ...)
		end
	end
	return event
end
Harness.fakeEvent = fakeEvent

-- ===== Fake instances =====
local Instance = {}
local function newInstance(className: string, name: string?)
	local inst = { ClassName = className, Name = name or className, _children = {} }
	local parent = nil
	local mt = {}
	mt.__index = function(self, key)
		if key == "Parent" then
			return parent
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
			rawset(self, key, value)
		end
	end
	setmetatable(inst, mt)
	if className == "RemoteEvent" then
		inst.OnServerEvent = fakeEvent()
		inst.OnClientEvent = fakeEvent()
		inst.Fired = {}
		inst.FireClient = function(self, player, ...)
			table.insert(self.Fired, { Player = player, Args = table.pack(...) })
		end
		inst.FireAllClients = function(self, ...)
			table.insert(self.Fired, { Player = "ALL", Args = table.pack(...) })
		end
	end
	return inst
end

function Instance:FindFirstChild(name)
	for _, child in ipairs(rawget(self, "_children")) do
		if child.Name == name then
			return child
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
function Instance:IsA(className)
	return self.ClassName == className
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
		task = task,
		require = requireNode,
		warn = function(...)
			if not options.Quiet then
				print("[warn]", ...)
			end
		end,
		Instance = { new = function(className)
			return newInstance(className)
		end },
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
		},
		Enum = setmetatable({}, { __index = function(_, enumName)
			return setmetatable({}, { __index = function(_, item)
				return enumName .. "." .. item
			end })
		end }),
	}

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

	function self.addPlayer(userId: number, name: string)
		local player = newInstance("Player", name)
		rawset(player, "UserId", userId)
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
