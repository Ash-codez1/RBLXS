--[[
	MockOrderedDataStore  (ServerScriptService.Server.Lib.MockOrderedDataStore)
	In-memory stand-in for an OrderedDataStore, used when Studio can't reach
	DataStores (and in tests). Same calls as the real thing:
	SetAsync, GetAsync, RemoveAsync, GetSortedAsync(ascending, pageSize).
	Nothing persists between Play sessions.
]]

local MockOrderedDataStore = {}
MockOrderedDataStore.__index = MockOrderedDataStore

function MockOrderedDataStore.new()
	return setmetatable({ _data = {} }, MockOrderedDataStore)
end

function MockOrderedDataStore:SetAsync(key, value)
	assert(type(value) == "number" and value % 1 == 0, "OrderedDataStore values must be integers")
	self._data[tostring(key)] = value
end

function MockOrderedDataStore:GetAsync(key)
	return self._data[tostring(key)]
end

function MockOrderedDataStore:RemoveAsync(key)
	local old = self._data[tostring(key)]
	self._data[tostring(key)] = nil
	return old
end

function MockOrderedDataStore:GetSortedAsync(ascending: boolean, pageSize: number)
	local entries = {}
	for key, value in pairs(self._data) do
		table.insert(entries, { key = key, value = value })
	end
	table.sort(entries, function(a, b)
		if a.value == b.value then
			return a.key < b.key
		end
		return if ascending then a.value < b.value else a.value > b.value
	end)
	local page = {}
	for i = 1, math.min(pageSize, #entries) do
		page[i] = entries[i]
	end
	return {
		IsFinished = true,
		GetCurrentPage = function()
			return page
		end,
		AdvanceToNextPageAsync = function() end,
	}
end

return MockOrderedDataStore
