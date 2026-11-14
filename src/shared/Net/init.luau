--[[
	Net  (ReplicatedStorage.Shared.Net)  — ModuleScript with children
	  RemoteDefinitions

	Server:  Net.Init()  creates ReplicatedStorage.Remotes from RemoteDefinitions.
	         Net.Handle(name, fn)       binds a RemoteFunction (rate-limited, pcall-wrapped)
	         Net.Listen(name, fn)       binds a client->server RemoteEvent (same protections)
	         Net.Fire(name, player, ...) / Net.FireAll(name, ...)
	Client:  Net.Invoke(name, ...)  -> ok, result
	         Net.OnEvent(name, fn)

	Handler convention: every RemoteFunction handler returns `true, payload` on
	success or `false, reasonString` on rejection, so the client always checks
	the first value. Net itself returns `false, "RateLimited" / "ServerError" /
	"NetworkError"` using the same convention.

	Security model: the client may *ask*; the server validates every argument,
	applies rate limits and decides. Handlers never receive a trusted value from
	the client except the Player object Roblox supplies.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Definitions = require(script.RemoteDefinitions)

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local Net = {}
Net.Definitions = Definitions

local folder: Folder? = nil
local remotes: { [string]: Instance } = {}

-- ===== Rate limiting (server only) =====
-- buckets[player][remoteName] = { tokens, last }
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local function allow(player: Player, name: string, limit): boolean
	limit = limit or Config.DefaultRateLimit
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { tokens = limit.Burst, last = now }
		perPlayer[name] = bucket
	end
	bucket.tokens = math.min(limit.Burst, bucket.tokens + (now - bucket.last) * limit.Rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function getRemote(name: string): Instance
	local remote = remotes[name]
	if remote then
		return remote
	end
	assert(not IS_SERVER, "Net: unknown remote '" .. name .. "' (add it to RemoteDefinitions)")
	folder = folder or ReplicatedStorage:WaitForChild(FOLDER_NAME)
	remote = (folder :: Folder):WaitForChild(name, 30)
	assert(remote, "Net: timed out waiting for remote '" .. name .. "'")
	remotes[name] = remote
	return remote
end

-- ===== Server API =====
function Net.Init()
	assert(IS_SERVER, "Net.Init is server-only")
	if folder then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	for name in pairs(Definitions.Events) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = newFolder
		remotes[name] = remote
	end
	for name in pairs(Definitions.Functions) do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = newFolder
		remotes[name] = remote
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

-- Binds a RemoteFunction. handler(player, ...) -> result. Errors become (false, "error").
function Net.Handle(name: string, handler: (Player, ...any) -> any)
	assert(IS_SERVER, "Net.Handle is server-only")
	local definition = Definitions.Functions[name]
	assert(definition, "Net.Handle: '" .. name .. "' is not a RemoteFunction")
	local remote = getRemote(name) :: RemoteFunction
	remote.OnServerInvoke = function(player, ...)
		if not allow(player, name, definition.RateLimit) then
			return false, "RateLimited"
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(("[Net] %s handler error for %s: %s"):format(name, player.Name, tostring(results[2])))
			return false, "ServerError"
		end
		return table.unpack(results, 2, results.n)
	end
end

-- Binds a client->server RemoteEvent with the same protections as Handle.
function Net.Listen(name: string, handler: (Player, ...any) -> ())
	assert(IS_SERVER, "Net.Listen is server-only")
	local definition = Definitions.Events[name]
	assert(definition, "Net.Listen: '" .. name .. "' is not a RemoteEvent")
	local remote = getRemote(name) :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, definition.RateLimit) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] %s listener error for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.Fire(name: string, player: Player, ...)
	assert(IS_SERVER, "Net.Fire is server-only");
	(getRemote(name) :: RemoteEvent):FireClient(player, ...)
end

function Net.FireAll(name: string, ...)
	assert(IS_SERVER, "Net.FireAll is server-only");
	(getRemote(name) :: RemoteEvent):FireAllClients(...)
end

-- ===== Client API =====
-- Returns ok, ...results. ok is false if the server rejected or errored.
function Net.Invoke(name: string, ...)
	assert(not IS_SERVER, "Net.Invoke is client-only")
	local remote = getRemote(name) :: RemoteFunction
	local results = table.pack(pcall(remote.InvokeServer, remote, ...))
	if not results[1] then
		return false, "NetworkError"
	end
	return table.unpack(results, 2, results.n)
end

function Net.OnEvent(name: string, handler: (...any) -> ())
	assert(not IS_SERVER, "Net.OnEvent is client-only")
	return (getRemote(name) :: RemoteEvent).OnClientEvent:Connect(handler)
end

-- Client->server fire (only for events declared with a RateLimit).
function Net.Send(name: string, ...)
	assert(not IS_SERVER, "Net.Send is client-only");
	(getRemote(name) :: RemoteEvent):FireServer(...)
end

-- Exposed for unit tests.
Net._allow = allow

return Net
