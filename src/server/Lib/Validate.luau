--[[
	Validate  (ServerScriptService.Server.Lib.Validate)
	Argument checks for anything arriving from a client. Each function returns
	the sanitized value or nil if invalid. Never trust client types or ranges.
]]

local Validate = {}

function Validate.Number(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

function Validate.Integer(value: any, min: number, max: number): number?
	local n = Validate.Number(value, min, max)
	if n and n % 1 == 0 then
		return n
	end
	return nil
end

function Validate.String(value: any, maxLength: number): string?
	if type(value) ~= "string" or #value == 0 or #value > maxLength or not utf8.len(value) then
		return nil
	end
	return value
end

function Validate.Boolean(value: any): boolean?
	if type(value) == "boolean" then
		return value
	end
	return nil
end

function Validate.OneOf(value: any, options: { any }): any
	if table.find(options, value) then
		return value
	end
	return nil
end

-- Identifiers used for scenario/choice/item ids: letters, digits, underscore.
function Validate.Id(value: any, maxLength: number?): string?
	local s = Validate.String(value, maxLength or 64)
	if s and s:match("^[%w_]+$") then
		return s
	end
	return nil
end

--[[
	Validates a partial settings table against a schema:
	schema[key] = { Kind = "Number"|"Boolean"|"OneOf", Min, Max, Options }
	Unknown keys are dropped. Returns a new table with only valid entries.
]]
function Validate.Partial(input: any, schema: { [string]: any }): { [string]: any }
	local out = {}
	if type(input) ~= "table" then
		return out
	end
	for key, rule in pairs(schema) do
		local raw = input[key]
		if raw ~= nil then
			local value
			if rule.Kind == "Number" then
				value = Validate.Number(raw, rule.Min, rule.Max)
			elseif rule.Kind == "Boolean" then
				value = Validate.Boolean(raw)
			elseif rule.Kind == "OneOf" then
				value = Validate.OneOf(raw, rule.Options)
			end
			if value ~= nil then
				out[key] = value
			end
		end
	end
	return out
end

return Validate
