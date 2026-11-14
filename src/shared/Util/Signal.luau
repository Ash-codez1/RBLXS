--[[
	Signal  (ReplicatedStorage.Shared.Util.Signal)
	Minimal pure-Luau event: Connect / Once / Fire / Wait / DisconnectAll.
	Handlers run in their own thread so one erroring handler cannot break others.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	local connection = { Connected = true }
	local handlers = self._handlers
	function connection.Disconnect(c)
		if not c.Connected then
			return
		end
		c.Connected = false
		local index = table.find(handlers, c)
		if index then
			table.remove(handlers, index)
		end
	end
	connection._fn = handler
	table.insert(handlers, connection)
	return connection
end

function Signal:Once(handler: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Copy so handlers may disconnect while we iterate.
	local snapshot = table.clone(self._handlers)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in ipairs(table.clone(self._handlers)) do
		connection:Disconnect()
	end
end

return Signal
