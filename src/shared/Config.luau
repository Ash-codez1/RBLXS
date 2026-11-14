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

-- ===== Networking =====
-- Default token-bucket limits for remotes (requests per second, burst size).
Config.DefaultRateLimit = { Rate = 4, Burst = 8 }

-- ===== Replication =====
Config.ReplicationThrottle = 0.15 -- min seconds between data pushes to a client

return Config
