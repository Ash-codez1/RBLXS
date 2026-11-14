--[[
	RemoteDefinitions  (ReplicatedStorage.Shared.Net.RemoteDefinitions)
	Single source of truth for every remote in the game. The server creates
	them at startup inside ReplicatedStorage.Remotes; the client only waits for them.

	Direction legend:
	  C->S  client requests something from the server (always validated server-side)
	  S->C  server pushes state to the client
	RateLimit is { Rate = requests/second, Burst = max stored tokens } for C->S remotes.
]]

return {
	Events = {
		-- Data replication (S->C): full sanitized snapshot of the player's own profile.
		DataSnapshot = {},
		-- Notifications / toasts (S->C): { Title, Text, Kind }
		Notify = {},
		-- Generic gameplay signals (S->C) other systems push, e.g. "LifeReveal", "StageChanged".
		GameEvent = {},
	},

	Functions = {
		-- C->S: returns the caller's snapshot once their data has loaded.
		GetData = { RateLimit = { Rate = 1, Burst = 3 } },
		-- C->S: save client preferences. Args: settingsTable
		UpdateSettings = { RateLimit = { Rate = 2, Burst = 4 } },
		-- C->S: change who may see your stats/reveals/history. Args: privacyTable
		UpdatePrivacy = { RateLimit = { Rate = 2, Burst = 4 } },
	},
}
