--[[
	TableUtil  (ReplicatedStorage.Shared.Util.TableUtil)
	Pure helpers for working with plain data tables.
]]

local TableUtil = {}

-- Deep-copies plain data. Metatables are not copied (data tables never use them).
function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value :: any) do
		copy[TableUtil.DeepCopy(k)] = TableUtil.DeepCopy(v)
	end
	return (copy :: any) :: T
end

--[[
	Fills keys that exist in `template` but are missing (nil) in `target`.
	Existing values are never overwritten. Recurses into nested dictionaries
	only when both sides are tables. Returns `target` for chaining.
	Array-like template entries are NOT merged element-by-element (an empty
	template array means "starts empty", not "must contain these").
]]
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any })
	for k, templateValue in pairs(template) do
		local current = target[k]
		if current == nil then
			target[k] = TableUtil.DeepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" and not TableUtil.IsArray(templateValue) then
			TableUtil.Reconcile(current, templateValue)
		end
	end
	return target
end

-- True for {} and for tables whose keys are exactly 1..n.
function TableUtil.IsArray(t: { [any]: any }): boolean
	local count = 0
	for _ in pairs(t) do
		count += 1
	end
	return count == #t
end

function TableUtil.Count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- Keeps only the last `max` entries of an array, in place.
function TableUtil.TrimArray(t: { any }, max: number)
	local excess = #t - max
	if excess > 0 then
		table.move(t, excess + 1, #t, 1)
		for i = #t, #t - excess + 1, -1 do
			t[i] = nil
		end
	end
	return t
end

--[[
	Checks that a value can be stored in a DataStore: only strings, numbers
	(finite), booleans and tables with either all-string keys or array keys.
	Returns ok, problemPath.
]]
function TableUtil.IsSerializable(value: any, path: string?): (boolean, string?)
	local here = path or "root"
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return false, here .. " (non-finite number)"
		end
		return true
	elseif kind == "string" or kind == "boolean" or kind == "nil" then
		return true
	elseif kind ~= "table" then
		return false, here .. " (" .. kind .. ")"
	end

	if getmetatable(value) ~= nil then
		return false, here .. " (has metatable)"
	end

	local isArray = TableUtil.IsArray(value)
	for k, v in pairs(value) do
		if not isArray and type(k) ~= "string" then
			return false, here .. " (mixed/non-string key " .. tostring(k) .. ")"
		end
		local ok, problem = TableUtil.IsSerializable(v, here .. "." .. tostring(k))
		if not ok then
			return false, problem
		end
	end
	return true
end

return TableUtil
