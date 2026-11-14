# CHOOSE YOUR LIFE — Roblox life-simulation game

> Every choice you make shapes your future.

Built in Luau as a [Rojo](https://rojo.space) project, so every script is a plain file you can sync into Roblox Studio (or create by hand; see below).

## Build progress

| Phase | System | Status |
|---|---|---|
| 1 | Architecture: folders, bootstrap, networking, data, stats, settings | ✅ Done, 38 automated tests passing |
| 2 | Main menu, HUD, decision UI, settings UI, responsive layout | ⏳ Next |
| 3 | Six life stages, scenarios, branching, consequences | ⬜ |
| 4 | Careers, relationships, finances | ⬜ |
| 5 | Life Reveal: predictions, probabilities, cinematics, final reveal, history | ⬜ |
| 6 | Multiplayer: shared scenarios, group voting, comparisons, privacy | ⬜ |
| 7 | Shop, currency, inventory, monetisation | ⬜ |
| 8 | World and environment | ⬜ |
| 9 | Achievements, daily rewards, challenges, leaderboards, save slots | ⬜ |
| 10 | Saving and security hardening | ⬜ (core already done in Phase 1) |
| 11 | Testing and polish | ⬜ |

---

## 1. Where everything goes in Roblox Studio

```
ReplicatedStorage
└─ Shared                         (Folder)
   ├─ Config                      (ModuleScript)  src/shared/Config.luau
   ├─ Data                        (Folder)
   │  ├─ DataTemplate             (ModuleScript)  save schema, new life, migrations
   │  ├─ LifeStages               (ModuleScript)  the 6 stages + age progression
   │  └─ StatDefinitions          (ModuleScript)  the 8 stats
   ├─ Net                         (ModuleScript)  src/shared/Net/init.luau
   │  └─ RemoteDefinitions        (ModuleScript)  every remote, one list
   └─ Util                        (Folder)
      ├─ Signal                   (ModuleScript)
      ├─ StatMath                 (ModuleScript)  pure stat maths (server + previews)
      └─ TableUtil                (ModuleScript)

ServerScriptService
└─ Server                         (Folder)
   ├─ Main                        (Script)        src/server/Main.server.luau
   ├─ Lib                         (Folder)
   │  ├─ MockDataStore            (ModuleScript)
   │  ├─ SessionLock              (ModuleScript)
   │  └─ Validate                 (ModuleScript)
   └─ Services                    (Folder)
      ├─ DataService              (ModuleScript)
      ├─ SettingsService          (ModuleScript)
      └─ StatService              (ModuleScript)

StarterPlayer
└─ StarterPlayerScripts
   └─ Client                      (Folder)
      ├─ Main                     (LocalScript)   src/client/Main.client.luau
      └─ Controllers              (Folder)
         └─ DataController        (ModuleScript)

ReplicatedStorage.Remotes         (Folder, created at runtime by Net.Init. Do NOT create it yourself.)
```

File naming (Rojo convention): `X.server.luau` → **Script**, `X.client.luau` → **LocalScript**, `X.luau` → **ModuleScript**, and a folder containing `init.luau` → a **ModuleScript** with children.

### Option A: Rojo (recommended)
1. Install the Rojo Studio plugin and the Rojo CLI (7.x).
2. In this folder run `rojo serve`.
3. In Studio: Plugins → Rojo → **Connect**. Everything above appears automatically.

### Option B: manual
1. Create each Folder / ModuleScript / Script / LocalScript exactly as in the tree above, with exactly those names.
2. Paste each file's contents into the matching object.
3. Don't create `Remotes`; the server makes it.

### Studio settings
- **Game Settings → Security → Enable Studio Access to API Services**: turn it on to test real saving. If it's off, the game warns in Output and uses an in-memory store, so everything still runs but nothing persists.
- Publish the place first. DataStores need a published place.

---

## 2. How the systems connect

```
 CLIENT (LocalScript Main)                     SERVER (Script Main)
 ─────────────────────────                     ───────────────────
 Controllers (Init → Start)                    Net.Init() creates ReplicatedStorage.Remotes
   DataController ──Invoke "GetData"──────────► DataService  (Priority 0)
        ▲                                          │  owns all saved data, session lock,
        └──────── "DataSnapshot" event ◄───────────┤  autosave, replication
                  (own data only, throttled)       │
   (Phase 2 UI) ──Invoke "UpdateSettings"────────► SettingsService (validated by Lib/Validate)
                ──Invoke "UpdatePrivacy"─────────►
                                                 StatService ── DataService.Update(...)
                                                 (later: LifeService, RevealService, ShopService…
                                                  all change data only via DataService.Update)
```

**Lifecycle.** Both `Main` scripts require every ModuleScript in their folder, sort by `.Priority` (lower runs first), call every `Init()` and then every `Start()` in its own thread. To add a system you drop a new ModuleScript into `Services` (server) or `Controllers` (client). No other file needs editing.

**Networking rules (`Shared/Net`).**
- Every remote is declared once in `RemoteDefinitions` with its rate limit. The server builds them; the client waits for them.
- `Net.Handle` / `Net.Listen` wrap handlers in a per-player token-bucket rate limit and `pcall`, so spam returns `false, "RateLimited"` and a crashing handler returns `false, "ServerError"` without breaking the server.
- Convention: handlers return `true, payload` or `false, reason`.
- The client only **asks**. It never sends stat values, money, prices or outcomes. It sends ids (for example "I pick choice B"), and the server works out the result.

**Data rules (`DataService`).**
- One profile per player, stored as `{ Data, Lock }` under key `Player_<UserId>`.
- **Session lock:** loading claims the record for this server's `JobId` inside `UpdateAsync`. If a different live server holds it, the load retries with backoff. A lock older than 30 minutes is treated as a crashed server and taken over. Saves are cancelled if another server has taken the lock, so a stale server can never roll back newer data or duplicate items.
- Autosave every 60 s (this also refreshes the lock). The game saves and releases when a player leaves, and `BindToClose` flushes everyone on shutdown.
- Before every write the data is checked to be DataStore-safe (no NaN, functions or mixed keys).
- `DataTemplate.Upgrade` runs version migrations and back-fills any new fields, so old saves keep working as features are added. A save from a *newer* version is refused rather than corrupted.
- If loading fails after every retry, the player is kicked with a friendly message instead of playing on blank data that would overwrite their real save.
- The client gets a **sanitized** snapshot: no RNG seed and no receipt history.

**Stats (`StatMath` + `StatService`).** These are the 8 stats from the brief (0–100), with diminishing returns near the extremes so early choices keep mattering. Trait multipliers are supported. **Wealth** is computed from in-life net worth on a log scale ($10k → 50, $1M → 75, $100M → 100). There are two separate currencies: **Money** (in-life, resets every life) and **Coins** (shop currency that persists).

**Save data shape.** The full commented schema is in `src/shared/Data/DataTemplate.luau`. It covers 3 save slots, life history, inventory, achievements, collectibles, daily/streak state, challenges, lifetime totals, settings, privacy and tutorial state. Each life stores age, stage, stats, money, assets, career, education, relationships, traits, story flags, decision log, story log, random events and Life Reveal snapshots.

---

## 3. Testing

Tests run the **real** `src/` files outside Roblox using [Lune](https://lune-org.github.io), with a fake Roblox API in `tests/harness.luau`:

```bash
lune run tests/run.luau
```

They cover table utilities, signals, stat maths, stage ages, schema and migrations, session locking and validation, plus server integration: booting `Main`, loading and saving players, snapshot sanitising, throttled replication, settings validation, rate limiting, handler error isolation, lock handoff between two servers, `BindToClose`, player data separation and the Studio fallback.

Lint: `selene src` (uses `roblox_lite.yml`, a small Roblox global list for offline use).

**Not yet verified inside Roblox Studio itself.** The harness fakes Roblox, so run a Studio play-test too. You should see `[Server] CHOOSE YOUR LIFE started with 3 services` in Output and no errors.
