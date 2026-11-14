--[[
	DataTemplate  (ReplicatedStorage.Shared.Data.DataTemplate)
	The saved-data schema, new-life factory and version migrations.

	Shape of a saved profile (all keys are strings so it is DataStore-safe):

	Profile
	├─ Version            schema version, see DataTemplate.CurrentVersion
	├─ Coins              meta currency spent in the shop (persists across lives)
	├─ ActiveSlot         "Slot1" | "Slot2" | "Slot3"
	├─ Slots              { Slot1 = Life | false, ... }  (false = empty slot)
	├─ LifeHistory        array of completed-life summaries (capped)
	├─ Inventory          { Owned = { [itemId] = true }, Equipped = { [category] = itemId } }
	├─ Achievements       { [achievementId] = unlockUnixTime }
	├─ Collectibles       { [collectibleId] = true }
	├─ Daily              login streak / daily reward state
	├─ Challenges         daily + weekly challenge progress
	├─ Lifetime           totals across every life (for profiles + leaderboards)
	├─ Settings           client preferences (validated on the server)
	├─ Privacy            what friends may see in comparisons
	├─ Tutorial           onboarding progress
	└─ ProcessedReceipts  recent developer-product receipt ids (duplicate guard)
]]

local Config = require(script.Parent.Parent.Config)
local StatDefinitions = require(script.Parent.StatDefinitions)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local StatMath = require(script.Parent.Parent.Util.StatMath)

local DataTemplate = {}

DataTemplate.CurrentVersion = 1

DataTemplate.SlotIds = {}
for i = 1, Config.SaveSlotCount do
	table.insert(DataTemplate.SlotIds, "Slot" .. i)
end

DataTemplate.DefaultSettings = {
	MusicVolume = 0.5, -- 0..1
	SfxVolume = 0.7, -- 0..1
	Graphics = "Auto", -- "Auto" | "Low" | "High"
	UIScale = 1, -- 0.75..1.25
	CameraSensitivity = 1, -- 0.2..2
	Notifications = true,
	ReduceAnimations = false,
}

DataTemplate.DefaultPrivacy = {
	ShareStats = "Friends", -- "Everyone" | "Friends" | "Nobody"
	ShareReveals = "Friends",
	ShareHistory = "Friends",
}

local profileTemplate = {
	Version = DataTemplate.CurrentVersion,
	Coins = Config.StartingCoins,
	ActiveSlot = "Slot1",
	Slots = {},
	LifeHistory = {},
	Inventory = { Owned = {}, Equipped = {} },
	Achievements = {},
	Collectibles = {},
	Daily = { LastClaimDay = 0, Streak = 0, BestStreak = 0 },
	Challenges = { DailyDay = 0, Daily = {}, WeeklyWeek = 0, Weekly = {} },
	Lifetime = {
		LivesStarted = 0,
		LivesCompleted = 0,
		DecisionsMade = 0,
		CoinsEarned = 0,
		HighestNetWorth = 0,
		RareEventsSeen = 0,
		FirstJoin = 0,
	},
	Settings = DataTemplate.DefaultSettings,
	Privacy = DataTemplate.DefaultPrivacy,
	Tutorial = { Completed = false, Step = 0 },
	ProcessedReceipts = {},
}
for _, slotId in ipairs(DataTemplate.SlotIds) do
	profileTemplate.Slots[slotId] = false
end

function DataTemplate.NewProfile()
	local profile = TableUtil.DeepCopy(profileTemplate)
	profile.Lifetime.FirstJoin = os.time()
	return profile
end

--[[
	A single life. Lives inside Profile.Slots[slotId].
	`Seed` drives this life's random events so results are reproducible for
	debugging; the server owns it and never trusts a client-supplied seed.
]]
function DataTemplate.NewLife(name: string, seed: number)
	local stats = {}
	for _, statName in ipairs(StatDefinitions.Order) do
		stats[statName] = Config.StatStart
	end
	-- Wealth is always derived from net worth (see StatMath.WealthFromNetWorth).
	stats.Wealth = StatMath.WealthFromNetWorth(Config.StartingMoney)

	return {
		Name = name,
		Seed = seed,
		StartedAt = os.time(),
		Age = 5,
		Stage = 1,
		ScenarioIndex = 0, -- scenarios completed in the current stage
		Stats = stats,
		Money = Config.StartingMoney,
		Assets = {}, -- { [assetId] = true } houses, cars bought in-life
		Career = { Id = "None", Level = 0, YearsInRole = 0 },
		PeakSalary = 0, -- highest yearly salary reached (sets the retirement pension)
		Education = "None",
		Relationships = { Partner = false, Married = false, Children = 0, Friends = 0 },
		Traits = {}, -- { [traitId] = strength } personality built from choices
		Flags = {}, -- { [flagId] = true } story branches unlocked by decisions
		Decisions = {}, -- array of { Scenario, Choice, Age, Stage }
		Story = {}, -- array of short story lines for Life History
		Events = {}, -- array of random-event ids that happened
		Seen = {}, -- { [scenarioId] = true } scenarios already played this life
		Reveals = {}, -- array of Life Reveal snapshots per stage
		CurrentScenario = false, -- the scenario the server is waiting on, or false
		Completed = false,
	}
end

--[[
	Migrations: Migrations[n] upgrades a profile from version n to n + 1.
	Add a new function whenever CurrentVersion is bumped; never edit old ones.
]]
DataTemplate.Migrations = {
	-- [1] = function(profile) ... profile.Version = 2 end,
}

--[[
	Brings any loaded profile up to date:
	  1. run migrations from its version to CurrentVersion
	  2. fill any keys added to the template since it was saved
	Returns the profile (mutated in place) or nil + reason if unusable.
]]
function DataTemplate.Upgrade(profile: any)
	if type(profile) ~= "table" then
		return nil, "profile is not a table"
	end
	local version = tonumber(profile.Version) or 1
	if version > DataTemplate.CurrentVersion then
		-- Saved by a newer server build. Refuse rather than corrupt it.
		return nil, ("profile version %d is newer than server version %d"):format(version, DataTemplate.CurrentVersion)
	end
	while version < DataTemplate.CurrentVersion do
		local migrate = DataTemplate.Migrations[version]
		if not migrate then
			return nil, "missing migration for version " .. version
		end
		migrate(profile)
		version += 1
		profile.Version = version
	end
	TableUtil.Reconcile(profile, profileTemplate)

	-- Reconcile active lives too, so lives saved before new fields existed keep working.
	local lifeTemplate = DataTemplate.NewLife("", 0)
	for _, slotId in ipairs(DataTemplate.SlotIds) do
		local life = profile.Slots[slotId]
		if type(life) == "table" then
			TableUtil.Reconcile(life, lifeTemplate)
		elseif life ~= false then
			profile.Slots[slotId] = false
		end
	end
	if profile.Slots[profile.ActiveSlot] == nil then
		profile.ActiveSlot = DataTemplate.SlotIds[1]
	end
	return profile
end

return DataTemplate
