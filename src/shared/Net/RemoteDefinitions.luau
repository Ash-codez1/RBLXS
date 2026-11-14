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

		-- ===== Life (LifeService) =====
		-- C->S: (slotId, name, overwrite) start a new life in a save slot.
		StartNewLife = { RateLimit = { Rate = 0.5, Burst = 2 } },
		-- C->S: (slotId) make an existing life the active one.
		ContinueLife = { RateLimit = { Rate = 1, Burst = 3 } },
		-- C->S: (slotId) permanently clear a save slot.
		DeleteLife = { RateLimit = { Rate = 0.5, Burst = 2 } },
		-- C->S: () -> scenario payload for the active life (same scenario until answered).
		GetScenario = { RateLimit = { Rate = 2, Burst = 4 } },
		-- C->S: (scenarioId, choiceId) -> outcome. The server computes every consequence.
		MakeChoice = { RateLimit = { Rate = 2, Burst = 3 } },
	},
}
