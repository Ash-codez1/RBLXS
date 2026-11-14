--[[
	SettingsService  (ServerScriptService.Server.Services.SettingsService)
	Saves client preferences and privacy choices. Every field is validated
	against a schema; unknown keys and out-of-range values are dropped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Validate = require(script.Parent.Parent.Lib.Validate)

local SettingsService = {}
SettingsService.Priority = 20

local SHARE_OPTIONS = { "Everyone", "Friends", "Nobody" }

SettingsService.SettingsSchema = {
	MusicVolume = { Kind = "Number", Min = 0, Max = 1 },
	SfxVolume = { Kind = "Number", Min = 0, Max = 1 },
	Graphics = { Kind = "OneOf", Options = { "Auto", "Low", "High" } },
	UIScale = { Kind = "Number", Min = 0.75, Max = 1.25 },
	CameraSensitivity = { Kind = "Number", Min = 0.2, Max = 2 },
	Notifications = { Kind = "Boolean" },
	ReduceAnimations = { Kind = "Boolean" },
}

SettingsService.PrivacySchema = {
	ShareStats = { Kind = "OneOf", Options = SHARE_OPTIONS },
	ShareReveals = { Kind = "OneOf", Options = SHARE_OPTIONS },
	ShareHistory = { Kind = "OneOf", Options = SHARE_OPTIONS },
}

local function applyPartial(player: Player, field: string, input: any, schema)
	local clean = Validate.Partial(input, schema)
	if next(clean) == nil then
		return false, "NothingValid"
	end
	local ok = DataService.Update(player, function(data)
		for key, value in pairs(clean) do
			data[field][key] = value
		end
	end)
	if not ok then
		return false, "NotLoaded"
	end
	return true, clean
end

-- Used by multiplayer systems (Phase 6) before revealing someone's stats.
-- relation: "Self" | "Friend" | "Stranger"
function SettingsService.CanView(owner: Player, field: string, relation: string): boolean
	if relation == "Self" then
		return true
	end
	local data = DataService.Get(owner)
	if not data then
		return false
	end
	local level = data.Privacy[field]
	if level == "Everyone" then
		return true
	elseif level == "Friends" then
		return relation == "Friend"
	end
	return false
end

function SettingsService.Init() end

function SettingsService.Start()
	Net.Handle("UpdateSettings", function(player, input)
		return applyPartial(player, "Settings", input, SettingsService.SettingsSchema)
	end)
	Net.Handle("UpdatePrivacy", function(player, input)
		return applyPartial(player, "Privacy", input, SettingsService.PrivacySchema)
	end)
end

return SettingsService
