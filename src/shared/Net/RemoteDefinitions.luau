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

		-- ===== Life Circles (PartyService), all S->C =====
		PartyUpdate = {}, -- circle state, or false when not in a circle
		PartyInviteReceived = {}, -- { InviteId, FromUserId, FromName, Seconds }
		GroupEvent = {}, -- a group decision to vote on
		GroupVote = {}, -- live vote tally
		GroupEventResult = {}, -- what the group chose and what it meant for YOUR life
		GroupReveal = {}, -- a group Life Reveal session
		-- ===== City events (CityEventService), S->C =====
		CityEvent = {}, -- a server-wide invitation
		CityEventSummary = {}, -- how many people joined
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

		-- ===== People, lifestyle & money (LifeService → Lib/Actions) =====
		-- C->S: (personId, "Time"|"Gift"|"Talk")
		Interact = { RateLimit = { Rate = 3, Burst = 5 } },
		-- C->S: ("Friend"|"Love") try to meet someone new
		MeetPeople = { RateLimit = { Rate = 2, Burst = 4 } },
		-- C->S: (focusId) lifestyle focus
		SetFocus = { RateLimit = { Rate = 2, Burst = 4 } },
		-- C->S: (amount) move cash into / out of investments
		Invest = { RateLimit = { Rate = 3, Burst = 5 } },
		Withdraw = { RateLimit = { Rate = 3, Burst = 5 } },
		-- C->S: (loanIndex, amount) pay a loan down early
		RepayLoan = { RateLimit = { Rate = 3, Burst = 5 } },

		-- ===== Life Reveal (RevealService) =====
		-- C->S: () -> cards for every player in the server (privacy-filtered)
		GetLifeCards = { RateLimit = { Rate = 1, Burst = 3 } },

		-- ===== Life Circles (PartyService) =====
		PartyInvite = { RateLimit = { Rate = 1, Burst = 4 } }, -- (targetUserId)
		PartyRespond = { RateLimit = { Rate = 2, Burst = 4 } }, -- (inviteId, accept)
		PartyLeave = { RateLimit = { Rate = 1, Burst = 3 } },
		PartyKick = { RateLimit = { Rate = 1, Burst = 3 } }, -- (userId)
		PartyStartEvent = { RateLimit = { Rate = 0.5, Burst = 2 } },
		PartyVote = { RateLimit = { Rate = 3, Burst = 6 } }, -- (eventId, choiceId)
		PartyStartReveal = { RateLimit = { Rate = 0.5, Burst = 2 } },
		GetPartyState = { RateLimit = { Rate = 1, Burst = 3 } },
		JoinFriendServer = { RateLimit = { Rate = 0.2, Burst = 2 } }, -- (placeId, jobId)
		-- ===== City events (CityEventService) =====
		CityEventRespond = { RateLimit = { Rate = 1, Burst = 3 } }, -- (eventId, join)

		-- ===== Shop & store (ShopService, StoreService) =====
		ShopBuy = { RateLimit = { Rate = 2, Burst = 4 } }, -- (itemId)
		ShopEquip = { RateLimit = { Rate = 4, Burst = 8 } }, -- (itemId)
		ShopUnequip = { RateLimit = { Rate = 4, Burst = 8 } }, -- (slot)
		GetStoreInfo = { RateLimit = { Rate = 0.5, Burst = 2 } }, -- () -> Robux products & passes
		-- Phase 8 (Lifeville): use a world spot (or one offered by an NPC you're talking to)
		WorldAction = { RateLimit = { Rate = 2, Burst = 4 } }, -- (spotId, npcId?) -> outcome
	},
}
