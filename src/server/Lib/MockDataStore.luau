--[[
	MockDataStore  (ServerScriptService.Server.Lib.MockDataStore)
	In-memory stand-in with the same method signatures as a GlobalDataStore.
	DataService uses it automatically when DataStores are unavailable
	(Studio with "Enable Studio Access to API Services" off, or unit tests).
	Data is lost when the server stops.
]]

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in pairs(v) do
		c[k] = deepCopy(x)
	end
	return c
end

function MockDataStore.new()
	return setmetatable({ _data = {} }, MockDataStore)
end

function MockDataStore:GetAsync(key: string)
	return deepCopy(self._data[key])
end

function MockDataStore:SetAsync(key: string, value: any)
	self._data[key] = deepCopy(value)
end

function MockDataStore:UpdateAsync(key: string, transform: (any) -> any)
	local result = transform(deepCopy(self._data[key]))
	if result ~= nil then
		self._data[key] = deepCopy(result)
	end
	return deepCopy(result)
end

function MockDataStore:RemoveAsync(key: string)
	local old = self._data[key]
	self._data[key] = nil
	return old
end

return MockDataStore
