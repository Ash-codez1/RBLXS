--[[
	DataController  (StarterPlayerScripts.Client.Controllers.DataController)
	Holds the local player's latest data snapshot sent by the server.
	The client copy is DISPLAY-ONLY: changing it changes nothing on the server.

	DataController.Changed:Connect(function(data) ... end)
	DataController.Get()            -> data or nil
	DataController.WaitForData()    -> data (yields until first snapshot)
	DataController.GetActiveLife()  -> life table or nil
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local DataController = {}
DataController.Priority = 0

DataController.Changed = Signal.new() -- (data)
DataController.Loaded = Signal.new() -- () fired once

local current = nil

local function set(data)
	if type(data) ~= "table" then
		return
	end
	-- The server leaves Life History out of updates when it hasn't changed.
	if data.HistoryUnchanged then
		data.HistoryUnchanged = nil
		data.LifeHistory = if current then current.LifeHistory else {}
	end
	local first = current == nil
	current = data
	DataController.Changed:Fire(data)
	if first then
		DataController.Loaded:Fire()
	end
end

function DataController.Get()
	return current
end

function DataController.WaitForData()
	if current then
		return current
	end
	DataController.Loaded:Wait()
	return current
end

function DataController.GetActiveLife()
	if not current then
		return nil
	end
	local life = current.Slots[current.ActiveSlot]
	return if type(life) == "table" then life else nil
end

function DataController.Init() end

function DataController.Start()
	Net.OnEvent("DataSnapshot", set)
	-- Also ask directly, in case the first push arrived before we connected.
	for attempt = 1, 5 do
		if current then
			return
		end
		local ok, data = Net.Invoke("GetData")
		if ok then
			set(data)
			return
		end
		task.wait(attempt)
	end
	if not current then
		warn("[DataController] Could not fetch data from server")
	end
end

return DataController
