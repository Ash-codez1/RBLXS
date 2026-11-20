--[[
	Config  (ReplicatedStorage.Shared.Config)
	Game-wide constants shared by server and client.
	Nothing in here is secret: the client can read it, but only the server acts on it.
]]

local Config = {}

Config.GameName = "CHOOSE YOUR LIFE"
Config.Version = "0.1.0"

-- ===== Data =====
Config.DataStoreName = "ChooseYourLife_PlayerData_v1"
Config.DataKeyPrefix = "Player_"
Config.AutosaveInterval = 60 -- seconds between automatic saves
Config.SessionLockExpiry = 30 * 60 -- a lock older than this is treated as abandoned (server crash)
Config.LoadRetries = 5
Config.LoadRetryDelay = 6 -- seconds; multiplied by attempt number
Config.SaveRetries = 4
Config.MaxLifeHistory = 30 -- completed-life summaries kept per player
Config.MaxStoryEntries = 120 -- story log entries kept in the active life
Config.MaxProcessedReceipts = 50 -- dev-product receipts remembered to block duplicates
Config.SaveSlotCount = 3

-- ===== Stats =====
Config.StatMin = 0
Config.StatMax = 100
Config.StatStart = 50

-- ===== Economy =====
Config.StartingCoins = 100 -- meta currency (shop), persists across lives
Config.StartingMoney = 0 -- in-life money, resets every new life

-- ===== Life simulation =====
Config.EventChance = 0.28 -- chance of a random life event after each decision
Config.TwistChance = 0.22 -- chance of a twist at each stage's Life Reveal

-- ===== Multiplayer =====
Config.CityEventInterval = 480 -- seconds between server-wide city events (90 in Studio)
Config.CityEventJoinSeconds = 45
Config.CityEventMinPlayers = 2 -- with an active life (1 in Studio, so solo testing works)

-- ===== Networking =====
-- Default token-bucket limits for remotes (requests per second, burst size).
Config.DefaultRateLimit = { Rate = 4, Burst = 8 }

-- ===== Replication =====
Config.ReplicationThrottle = 0.15 -- min seconds between data pushes to a client

-- ===== Credits (shown on the Credits screen; edit freely) =====
Config.Credits = {
	{ Heading = "Created by", Lines = { "The CHOOSE YOUR LIFE team" } },
	{ Heading = "Game design & development", Lines = { "Built in Roblox Studio with Luau" } },
	{ Heading = "Special thanks", Lines = { "Everyone who played, tested and shared their lives with friends" } },
}

-- ===== Loading tips =====
Config.LoadingTips = {
	"Every choice shapes your future. There are no wrong answers, only different lives.",
	"Locked choices hint at hidden paths. Make different decisions to unlock them!",
	"Traits you build as a child make similar choices pay off more later in life.",
	"You have three save slots, so try living three completely different lives.",
	"Some outcomes are risky. Look for the 🎲 on a choice.",
}

return Config
