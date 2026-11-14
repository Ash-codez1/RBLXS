--[[
	DataService  (ServerScriptService.Server.Services.DataService)
	Owns every player's saved profile on this server.

	• Loads with a session lock (Lib/SessionLock) inside UpdateAsync so two
	  servers can never both write the same player's data (anti-duplication).
	• Retries loads/saves with backoff; kicks with a friendly message rather
	  than letting a player play on unsaved/blank data.
	• Autosaves every Config.AutosaveInterval (this also refreshes the lock),
	  saves + releases on leave, and flushes everything in BindToClose.
	• Validates that data is DataStore-serializable before writing.
	• Replicates a sanitized snapshot to the owning client only (throttled).
	• Falls back to an in-memory MockDataStore in Studio when API access is off.

	Other services must change data ONLY through DataService.Update(player, fn).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DataTemplate = require(Shared.Data.DataTemplate)
local TableUtil = require(Shared.Util.TableUtil)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)

local Lib = script.Parent.Parent.Lib
local SessionLock = require(Lib.SessionLock)
local MockDataStore = require(Lib.MockDataStore)

local DataService = {}
DataService.Priority = 0 -- initialised first; everything else depends on it

DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.ProfileReleasing = Signal.new() -- (player, data) fired before the final save
DataService.UsingMockStore = false

local JOB_ID = if game.JobId ~= "" then game.JobId else "Studio_" .. HttpService:GenerateGUID(false)

type Entry = {
	Data: any,
	Saving: boolean,
	Releasing: boolean,
	LockLost: boolean,
	ReplicationQueued: boolean,
}

local store: any = nil
local entries: { [Player]: Entry } = {}
local loading: { [Player]: boolean } = {}
local activeSaves = 0
local shuttingDown = false

local function keyFor(player: Player): string
	return Config.DataKeyPrefix .. player.UserId
end

local function chooseStore()
	local realStore
	local ok, err = pcall(function()
		realStore = DataStoreService:GetDataStore(Config.DataStoreName)
		if RunService:IsStudio() then
			realStore:GetAsync("__studio_probe")
		end
	end)
	if ok then
		return realStore, false
	end
	warn("[DataService] DataStores unavailable (" .. tostring(err) .. "). Using in-memory MockDataStore: progress will NOT persist.")
	return MockDataStore.new(), true
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	if DataService.UsingMockStore then
		return
	end
	local deadline = os.clock() + 10
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() < deadline do
		task.wait(0.5)
	end
end

-- ===== Load =====
local function loadData(player: Player): (any, string?)
	local key = keyFor(player)
	for attempt = 1, Config.LoadRetries do
		local status, loadedRecord
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(record)
				local newRecord, result = SessionLock.Acquire(record, JOB_ID, os.time(), Config.SessionLockExpiry)
				status = result
				loadedRecord = newRecord
				return newRecord
			end)
		end)

		if ok and status == SessionLock.Result.Acquired then
			local data = loadedRecord.Data
			if data == nil then
				data = DataTemplate.NewProfile()
			end
			local upgraded, reason = DataTemplate.Upgrade(data)
			if not upgraded then
				return nil, reason
			end
			return upgraded
		end

		if not ok then
			warn(("[DataService] Load attempt %d for %s failed: %s"):format(attempt, player.Name, tostring(err)))
		else
			warn(("[DataService] %s's data is locked by another server (attempt %d)"):format(player.Name, attempt))
		end
		if player.Parent == nil then
			return nil, "PlayerLeft"
		end
		task.wait(Config.LoadRetryDelay * attempt)
	end
	return nil, "Could not load data after " .. Config.LoadRetries .. " attempts"
end

-- ===== Save =====
-- Returns true when the write is confirmed.
local function writeData(player: Player, data: any, release: boolean): (boolean, string?)
	local serializable, problem = TableUtil.IsSerializable(data)
	if not serializable then
		warn("[DataService] Refusing to save unserializable data for " .. player.Name .. ": " .. tostring(problem))
		return false, "Unserializable"
	end
	local payload = TableUtil.DeepCopy(data)
	local key = keyFor(player)

	for attempt = 1, Config.SaveRetries do
		local status
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(record)
				local newRecord, result = SessionLock.Write(record, JOB_ID, payload, os.time(), release)
				status = result
				return newRecord
			end)
		end)
		if ok and status == "Written" then
			return true
		elseif ok and status == "LockStolen" then
			return false, "LockStolen"
		end
		warn(("[DataService] Save attempt %d for %s failed: %s"):format(attempt, player.Name, tostring(err)))
		if attempt < Config.SaveRetries then
			task.wait(2 ^ attempt)
		end
	end
	return false, "SaveFailed"
end

local function saveEntry(player: Player, release: boolean): boolean
	local entry = entries[player]
	if not entry or entry.LockLost then
		return false
	end
	while entry.Saving do
		task.wait()
	end
	entry.Saving = true
	activeSaves += 1
	local ok, reason = writeData(player, entry.Data, release)
	activeSaves -= 1
	entry.Saving = false

	if reason == "LockStolen" then
		entry.LockLost = true
		warn("[DataService] Another server took " .. player.Name .. "'s data; this server will stop saving it.")
		if player.Parent then
			player:Kick("Your game was opened on another server. Please rejoin.")
		end
	end
	return ok
end

-- ===== Replication =====
-- What the owning client is allowed to see. Server-only fields are stripped.
function DataService.Snapshot(player: Player)
	local entry = entries[player]
	if not entry then
		return nil
	end
	local snapshot = TableUtil.DeepCopy(entry.Data)
	snapshot.ProcessedReceipts = nil
	for _, slotId in ipairs(DataTemplate.SlotIds) do
		local life = snapshot.Slots[slotId]
		if type(life) == "table" then
			life.Seed = nil -- never reveal the RNG seed
		end
	end
	return snapshot
end

local function replicate(player: Player)
	local entry = entries[player]
	if not entry or entry.ReplicationQueued then
		return
	end
	entry.ReplicationQueued = true
	task.delay(Config.ReplicationThrottle, function()
		entry.ReplicationQueued = false
		if entries[player] == entry and player.Parent then
			Net.Fire("DataSnapshot", player, DataService.Snapshot(player))
		end
	end)
end

-- ===== Public API =====
function DataService.IsLoaded(player: Player): boolean
	return entries[player] ~= nil
end

-- Read-only access. Do NOT mutate the returned table; use Update.
function DataService.Get(player: Player)
	local entry = entries[player]
	return entry and entry.Data
end

function DataService.WaitForData(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while not entries[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

--[[
	The only way to change saved data. `mutator(data)` edits in place.
	Returns true + mutator's return value, or false if data isn't loaded.
	The mutator must not yield.
]]
function DataService.Update(player: Player, mutator: (any) -> any)
	local entry = entries[player]
	if not entry or entry.Releasing then
		return false
	end
	local result = mutator(entry.Data)
	replicate(player)
	return true, result
end

-- The life in the player's active save slot, or nil if that slot is empty.
function DataService.GetActiveLife(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local life = data.Slots[data.ActiveSlot]
	return if type(life) == "table" then life else nil
end

function DataService.SaveNow(player: Player): boolean
	return saveEntry(player, false)
end

-- ===== Lifecycle =====
local function onPlayerAdded(player: Player)
	if loading[player] or entries[player] then
		return
	end
	loading[player] = true
	local data, reason = loadData(player)
	loading[player] = nil

	if not data then
		if reason ~= "PlayerLeft" and player.Parent then
			warn("[DataService] Failed to load " .. player.Name .. ": " .. tostring(reason))
			player:Kick("We couldn't load your life safely (" .. tostring(reason) .. "). Please rejoin in a moment.")
		end
		return
	end

	local entry: Entry = { Data = data, Saving = false, Releasing = false, LockLost = false, ReplicationQueued = false }
	entries[player] = entry

	if player.Parent == nil then
		-- Left while loading: release the lock we just took.
		entry.Releasing = true
		saveEntry(player, true)
		entries[player] = nil
		return
	end

	DataService.ProfileLoaded:Fire(player, data)
	replicate(player)
end

local function onPlayerRemoving(player: Player)
	local entry = entries[player]
	if not entry or entry.Releasing then
		return
	end
	DataService.ProfileReleasing:Fire(player, entry.Data)
	task.wait() -- let ProfileReleasing handlers (deferred) run their final edits
	entry.Releasing = true
	saveEntry(player, true)
	entries[player] = nil
end

local function onClose()
	shuttingDown = true
	local pending = 0
	for player in pairs(entries) do
		pending += 1
		task.spawn(function()
			onPlayerRemoving(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while (pending > 0 or activeSaves > 0) and os.clock() < deadline do
		task.wait(0.1)
	end
end

function DataService.Init()
	local chosen, isMock = chooseStore()
	store = chosen
	DataService.UsingMockStore = isMock
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(onClose)

	Net.Handle("GetData", function(player)
		local data = DataService.WaitForData(player, 30)
		if not data then
			return false, "NotLoaded"
		end
		return true, DataService.Snapshot(player)
	end)

	task.spawn(function()
		while not shuttingDown do
			task.wait(Config.AutosaveInterval)
			for player, entry in pairs(entries) do
				if not entry.Releasing then
					task.spawn(saveEntry, player, false)
				end
			end
		end
	end)
end

-- Exposed for tests only.
DataService._setStore = function(s, isMock)
	store = s
	DataService.UsingMockStore = isMock
end

return DataService
