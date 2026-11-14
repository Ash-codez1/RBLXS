--[[
	SessionLock  (ServerScriptService.Server.Lib.SessionLock)
	Pure transform functions used inside DataStore:UpdateAsync so only one
	server can own a player's data at a time (prevents item/coin duplication
	when a player hops servers quickly).

	Stored record shape:  { Data = profile, Lock = { JobId = string, Time = unix } | nil }
]]

local SessionLock = {}

SessionLock.Result = {
	Acquired = "Acquired",
	Locked = "Locked", -- another live server owns it; caller should retry
}

--[[
	Attempt to claim `record` for `jobId`.
	Returns newRecord (to write, or nil to cancel the write), result.
	A lock older than `expiry` seconds is considered abandoned and is taken over.
]]
function SessionLock.Acquire(record: any, jobId: string, now: number, expiry: number)
	if type(record) ~= "table" then
		record = { Data = nil, Lock = nil }
	end
	local lock = record.Lock
	if type(lock) == "table" and lock.JobId ~= jobId and type(lock.Time) == "number" and now - lock.Time < expiry then
		return nil, SessionLock.Result.Locked
	end
	record.Lock = { JobId = jobId, Time = now }
	return record, SessionLock.Result.Acquired
end

--[[
	Write `data` back. If `release` the lock is cleared, otherwise refreshed.
	Returns nil (cancel write) if a different server has taken the lock, so a
	stale server can never overwrite newer data.
]]
function SessionLock.Write(record: any, jobId: string, data: any, now: number, release: boolean)
	if type(record) == "table" and type(record.Lock) == "table" and record.Lock.JobId ~= jobId then
		return nil, "LockStolen"
	end
	local newRecord = { Data = data, Lock = nil }
	if not release then
		newRecord.Lock = { JobId = jobId, Time = now }
	end
	return newRecord, "Written"
end

return SessionLock
