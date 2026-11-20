# CHOOSE YOUR LIFE — Roblox life-simulation game

> Every choice you make shapes your future.

**▶ Try it:** download [`build/ChooseYourLife.rbxlx`](build/ChooseYourLife.rbxlx), open it in Roblox Studio and press Play. Full instructions (saving, phone/tablet emulation, multiplayer testing, live sync) are in **[TESTING.md](TESTING.md)**.

Built in Luau as a [Rojo](https://rojo.space) project, so every script is a plain file you can sync into Roblox Studio (or create by hand; see §1).

## Build progress

| Phase | System | Status |
|---|---|---|
| 1 | Architecture: bootstrap, networking, saving, stats, settings | ✅ Done |
| 2 | Main menu, HUD, decision UI, settings, responsive layout (PC / mobile / tablet / console) | ✅ Done |
| 3 | All six life stages (85 scenarios), 34 random events, branching, consequences, yearly income & ageing | ✅ Done |
| 4 | People & bonds, People/Lifestyle/Money panels, investments, loans & mortgages, a scenario for every career | ✅ Done |
| 5 | **Life Reveal**: calibrated predictions, twists, stage & final cinematics, ending titles, Life History, comparisons | ✅ Done |
| 6 | **Multiplayer**: Life Circles, invites, group decisions with voting, group Life Reveals, city events, joining friends | ✅ Done |
| 7 | Shop, currency, inventory, monetisation | ⏳ Next |
| 8 | World and environment, music and sound | ⬜ |
| 9 | Achievements, daily rewards, challenges, leaderboards | ⬜ |
| 10–11 | Security hardening, testing, polish | ⬜ (core saving/security done in Phase 1) |

**123 automated tests pass** (`lune run tests/run.luau`). They include:
- a simulation of 400 random lives from age 5 to 85;
- a full life played through the real UI;
- UI click-throughs on desktop, phone portrait, phone landscape and gamepad.

Nothing has been play-tested inside Roblox Studio yet; see §4.

### Playing with friends (Phase 6)

Every player always has their **own independent life**. Multiplayer adds things to do *together* without ever letting someone else write to your life.

- **🤝 Life Circles** (Play With Friends, or 🤝 in the HUD): invite players in your server (invites expire after 45 s), up to 4 per circle.
  - The leader can remove members, and leadership passes on if the leader leaves; a circle of one dissolves.
  - You can **invite Roblox friends** with the Roblox invite prompt, and **join friends playing in other servers** (teleport).
- **🎲 Group decisions:** the server picks a scenario everyone qualifies for, from 15 group scenarios (start a business together, holiday, band, sleepover, escape room…).
  - Choices someone can't afford are locked for the group.
  - Everyone votes, with a live tally and a 40 s timer. The majority decides; ties and no-shows are settled fairly at random.
  - Chance outcomes are rolled **once for the group** (shared fate). The effects are applied to **each member's own life**, with their own stats, traits and money.
  - Group decisions don't use up a turn or age anyone.
  - Your friends' characters join your People list, and the shared moment shows up in your Final Reveal.
- **🔮 Group Life Reveal:** everyone watches each member's predicted futures, then a **"most likely to…"** board. Privacy settings still apply, and circle members count as friends.
- **⚖️ Compare:** side-by-side futures, stats, net worth and **homes & cars** with anyone whose privacy allows it.
- **🎪 City events:** every 8 minutes the whole server is invited to something (festival, marathon, free concert, market frenzy…). Join or skip; joiners share one city-wide outcome, applied to their own lives.

### LIFE REVEAL (Phase 5): the signature feature

**Predictions you can trust.** `Shared/Util/Futures` estimates 11 possible futures: Millionaire, Top of your field, Happy family, Famous, Brilliant mind, Long healthy life, Widely respected, Truly happy, Adventurer, plus two risks (Hard times, Lonely).
- The estimates come from the life's actual state: stats and their trend, money, investments, property, debt, career, level, education, partner, children, bonds, traits, flags, lifestyle focus and age.
- Raw model scores are calibrated (Platt scaling) on simulated lives, then checked on a separate set of lives the fit never saw.
- The test suite proves that from Young Adulthood onward, every common future's predictions beat "just guess the average" and are within 10 points of reality. Odds sharpen as life goes on and change with every decision.
- Re-fit after big balance changes:

```bash
lune run tests/tools/calibrate.luau --fit 800
```

- Report on held-out lives:

```bash
lune run tests/tools/calibrate.luau 600 555
```

**Stage reveals.** At the end of each of the first five stages a cinematic plays:
1. Title with light rays.
2. Who you became.
3. Your possible futures, as counting bars with ▲▼ trend arrows versus the last reveal.
4. A typewriter prediction, such as *"Your decisions suggest you could become a millionaire."*, *"Your financial decisions could put your future at risk."* or *"Your future is uncertain. One major decision could change everything."*
5. An animated preview of the most likely future (11 scenes, e.g. a mansion and sports car for Luxury, a stage with camera flashes for Fame, rain for Hard times… "but it's not too late"), with a slow camera push-in.
6. *"The future is never decided."*

Tap to speed up, Skip to jump ahead, and Reduce animations is respected.

**Twists.** At 22% of reveals something unexpected really happens (`Content/Twists`, 16 twists):
- If one future looks very likely, a **setback** works against it: a crash, a scandal, an illness, a heartbreak.
- If a risk looks likely, a **rescue** helps: a secret inheritance, a new circle of friends.
- Otherwise, a **surprise**: a child prodigy, the big idea, a long-lost sibling.

The reveal shows the odds before and after; on average, setbacks cut the top future's odds by about 28 points.

**Final reveal & ending titles.** At 85, the final reveal covers:
- the choices that shaped you (the most consequential decisions, measured when you made them);
- the people in your life, a net worth count-up, and your career and education;
- achievements, greatest moments and biggest regrets;
- what was predicted vs. what came true;
- your **ending title**, chosen from 23 by what actually happened (The Space Explorer, The Billionaire, The Family Legend, The Celebrity, The Comeback Kid, The Unknown Legend, The Unlucky One, The Quiet Life…), plus coins.

It ends by asking *"What if you had chosen differently?"*, with **Live Again**, **Life History** and **Main Menu** buttons.

**Life History** (menu → 📜). Your last 30 lives, each with a full detail view: replay its final reveal, or **compare two lives side by side**. Completed save slots offer "View Final Reveal".

**🔮 Future panel.** Live odds for every future, how your predictions changed at each reveal, and **compare with players in this server**. Comparisons respect privacy settings: *Everyone / Friends / Nobody* for reveals, exact stats and past lives, using Roblox friendships. Group reveal sessions come with multiplayer in Phase 6.

### People, lifestyle and money (Phase 4)

- **Named people with bonds (0–100):** every life starts with two parents. Siblings, partners, children and friends join through choices, events and actions; an ex can come back.
  - Bonds fade each year unless you make time for people.
  - Close bonds raise Happiness and pull the Relationships stat up; being alone after 25 hurts.
  - A partner bond below 15 can end the relationship, and ending a marriage costs money too.
- **👥 People panel:** you get **2 actions between decisions**: *Spend time*, *Give a gift* (the cost scales with age) or *Talk* (sometimes a heart-to-heart). There are also *Meet new friends* and, from 18, *Look for love*. Chance-based actions use the life's seeded RNG, so retrying can't reroll them.
- **🎯 Lifestyle focus:** Balanced, Career/School, Family, Health, Social or Save Money. It applies every simulated year; for example, Career focus means faster promotions and fading bonds, and Family focus means growing bonds and a slower career.
- **💰 Money panel:**
  - Net worth (cash + investments + property − debt) and this year's budget line by line. It uses `Shared/Util/Budget`, the same maths the server runs.
  - Invest or withdraw from age 18. Markets average about 6% a year with swings, and crash 5% of the time.
  - Repay loans early.
- **Loans:** university adds a $27,000 student loan, and homes can be bought with a mortgage (deposit plus 25 years). Repayments come out every year.
- **Save upgrade:** save format v2 adds people, focus, investments and loans. The v1→v2 migration turns old saves' partner, children and friend counts into named people.

### What a life looks like now

| Stage | Ages | Decisions | Scenarios | Highlights |
|---|---|---|---|---|
| Childhood | 5–12 | 6 | 11 | first friends, clubs, hidden talents, pocket money |
| Teenage Years | 13–18 | 7 | 14 | friend groups, exams, first job, crushes, going viral, subjects, university plans |
| Young Adulthood | 19–25 | 7 | 17 | university or work or travel, graduation, **career choice** (professional, creative, business or service), moving out, love |
| Adulthood | 26–40 | 7 | 18 (+ multi-stage) | promotions, marriage, children, buying homes, investing, career crossroads, job-specific dramas, **astronaut** |
| Middle Age | 41–60 | 6 | 15 | running a business, raising teens, old regrets, dreams, health, wealth, divorce or late love |
| Retirement | 61–85 | 5 | 10 | retiring (or not), grandchildren, giving back, legacy, looking back |

Between decisions, years pass:
- Salaries are paid, with a savings rate that the Thrifty trait raises.
- Rent is due until you own a home.
- Children cost money while they're young.
- Pensions are based on your career peak.
- Strong performers can be promoted automatically.
- Health declines after 50.

**Multi-stage "Life & Work" scenarios (28):** there is a dilemma for every career, such as a police stakeout, a teacher's struggling student, a chef facing a food critic, a startup pitch, an emergency in orbit and an esports world final. There are also relationship moments (a best friend's wedding, growing apart, work vs. family, lonely evenings, saying goodbye to a parent) and a mortgage-debt dilemma.

After each decision there is a 28% chance of a **random life event**. There are 43 of them, rated Common, Uncommon, Rare or Legendary, and each is gated by your real situation: you can only be laid off if you have a job, and twins need a marriage. Legendary events, like a lottery win or a call from the space agency, happen in only a small fraction of lives.

Results from the 400-life simulation with random choices:
- 84 of 85 scenarios and 33 of 34 events appeared. The exception is the astronaut path, which needs a legendary event.
- 19 different careers were reached.
- Saves stay under 10 KB.
- About 48% of lives ended owning a home and 12% as millionaires.

---

## 1. Where everything goes in Roblox Studio

```
ReplicatedStorage
└─ Shared                              Folder
   ├─ Config                           ModuleScript   constants, credits, loading tips
   ├─ Data                             Folder
   │  ├─ Assets                        ModuleScript   homes/cars you can buy in a life
   │  ├─ Lifestyle                     ModuleScript   lifestyle focus options
   │  ├─ Careers                       ModuleScript   21 careers, salaries, level titles, education
   │  ├─ DataTemplate                  ModuleScript   save schema, new life, migrations
   │  ├─ LifeStages                    ModuleScript   6 stages, ages, decisions per stage
   │  ├─ NamePool                      ModuleScript   names for the "Random" button
   │  ├─ SoundIds                      ModuleScript   audio asset ids (fill in, see §3)
   │  ├─ StatDefinitions               ModuleScript   the 8 stats
   │  └─ Traits                        ModuleScript   13 personality traits
   ├─ Net                              ModuleScript   (src/shared/Net/init.luau)
   │  └─ RemoteDefinitions             ModuleScript   every remote + rate limits
   └─ Util                             Folder
      ├─ Budget, Endings, Format, Futures, People,
      │  Signal, StatMath, TableUtil                          ModuleScripts

ServerScriptService
└─ Server                              Folder
   ├─ Main                             Script         (Main.server.luau)
   ├─ Content                          Folder
   │  ├─ CityEvents                    ModuleScript   7 server-wide shared events
   │  ├─ Events                        ModuleScript   43 random life events
   │  ├─ GroupScenarios                ModuleScript   15 group decisions for Life Circles
   │  ├─ Twists                        ModuleScript   16 Life Reveal twists
   │  └─ Scenarios                     ModuleScript   (Scenarios/init.luau) loads + validates everything
   │     ├─ Childhood, Teen, YoungAdult,
   │     │  Adult, MiddleAge, Retirement  ModuleScripts  one per life stage
   │     └─ LifeAndWork                ModuleScript   multi-stage career & relationship scenarios
   ├─ Lib                              Folder
   │  ├─ Actions, Conditions, Consequences, MockDataStore, RandomEvents,
   │  │  Reveal, ScenarioPicker, SessionLock, Validate, Yearly   ModuleScripts
   └─ Services                         Folder
      ├─ CityEventService, DataService, LifeService, PartyService,
      │  RevealService, SettingsService, StatService                          ModuleScripts

StarterPlayer
└─ StarterPlayerScripts
   └─ Client                           Folder
      ├─ Main                          LocalScript    (Main.client.luau)
      ├─ Controllers                   Folder
      │  ├─ AudioController, ControlsController, DataController, DecisionController,
      │  │  FinanceController, FriendsController, FutureController, GraphicsController,
      │  │  HUDController, LifeHistoryController, LifestyleController, LoadingController,
      │  │  MenuController, NotificationController, PartyController, PeopleController,
      │  │  RevealController, SettingsController, SettingsMenu, UIController   ModuleScripts
      └─ UILib                         Folder
         ├─ Anim, Components, Create, Layout, Theme                    ModuleScripts
```

At runtime the game also creates `ReplicatedStorage.Remotes` (server), the `CYL_*` ScreenGuis in PlayerGui and the `CYL_Music` / `CYL_SFX` SoundGroups (client). **Don't create those yourself.** All UI is generated by code; there are no hand-made GUIs.

File naming (Rojo): `X.server.luau` → **Script**, `X.client.luau` → **LocalScript**, `X.luau` → **ModuleScript**, and a folder containing `init.luau` → a **ModuleScript** with children.

**Option 0, just play it:** open `build/ChooseYourLife.rbxlx` in Studio (see [TESTING.md](TESTING.md)). It's rebuilt from `src/` with:

```bash
rojo build default.project.json -o build/ChooseYourLife.rbxlx
```

**Option A, Rojo (recommended for development):** install the Rojo plugin + CLI 7.x, run `rojo serve` in this folder, then in Studio go to Plugins → Rojo → Connect.
**Option B, manual:** create every object above with exactly those names and classes, and paste in each file's contents.

**Studio settings:** publish the place, then turn on Game Settings → Security → **Enable Studio Access to API Services** to test real saving. With it off, the game warns once and uses memory-only saving.

---

## 2. How the systems connect

```
 CLIENT                                             SERVER
 Main.client → Controllers (Init → Start)           Main.server → Net.Init() → Services (Init → Start)

 LoadingController ─ waits for DataController ──┐
 DataController ── Invoke GetData ─────────────►│ DataService   save/load, session lock, autosave,
        ▲ ◄────── DataSnapshot (own data only) ─┤               sanitized replication
 MenuController ── StartNewLife / ContinueLife ─►│ LifeService   slots, scenarios, choices
                   DeleteLife                    │   ├ Content/Scenarios  (server-only text + effects)
 DecisionController ─ GetScenario / MakeChoice ─►│   ├ Lib/ScenarioPicker (eligibility + weights)
                                                 │   ├ Lib/Conditions     (flags/stats/traits gates)
                                                 │   └ Lib/Consequences   (stats, money, flags, traits, chance)
 SettingsController ─ UpdateSettings/Privacy ───►│ SettingsService (validated against a schema)
 UIController   screens, scaling, modals          │ StatService   authoritative stat changes
 HUDController  HUD + stats panel
```

**The decision loop.**
1. `GetScenario` picks the next scenario: highest `Priority` first, otherwise a weighted pick. Weights are boosted by flags and traits from earlier choices, and scenarios you can't qualify for are skipped. The pick is saved as `life.CurrentScenario`, so reconnecting shows the same one.
2. The client gets titles, choices and **arrow-only previews** (▲▲ Intelligence, ▼ Happiness, 🎲 Risky). It never sees exact numbers or chances.
3. Locked choices are shown with their unlock hint (🔒 "Requires an athletic background"), so players know hidden paths exist.
4. `MakeChoice(scenarioId, choiceId)` is checked against the saved pending scenario and re-checks locks. It then applies all effects in one atomic update:
   - **Short term:** stat changes, with diminishing returns near 0 and 100 and trait multipliers on gains.
   - **Long term:** flags (which unlock or close off later scenarios and choices) and traits (which make related gains worth more later).
   - It also updates money, the story log and the decision log.
5. **Years pass** (`Lib/Yearly`): income, rent, children's costs, pension, career years, automatic promotions and ageing.
6. **Random events** (`Lib/RandomEvents`) may then fire. The outcome card shows what changed, and an event card follows if one happened.
7. Chance rolls use a per-life server seed plus the decision count, so leaving and rejoining can't reroll a bad outcome.
8. After the last decision of a stage, the stats are snapshotted into `life.Reveals` and `StageCompleted` fires. This is where Life Reveal plugs in during Phase 5.

**Branching between stages.** Choices set *flags* (Athlete, MusicTalent, PlanUni, Cheater…) and *traits* (Studious, Kind…). Later scenarios and choices use `Requires` to test flags, traits, stats, money, career, education, relationship status, children and assets. Examples:
- A childhood swimmer can beat the bully in a race.
- A teen who started a channel gets the brand deal at 22.
- A childhood chess player can win the senior championship at 75.
- A science grad can be invited to train as an astronaut.

**Content validation.** At startup, `Content/Scenarios` checks every scenario and event: unique ids, 3–5 choices, valid stats, traits, careers, education and assets, and outcome chances that add up to 1 or less. It also checks that every purchase of $10,000 or more is guarded by a `MinMoney` requirement. Any problem prints a warning in Output, and the test suite fails on it.

**Responsive UI.** Every screen is laid out in virtual pixels on a 1280×720, 960×540 (phone landscape) or 540×960 (portrait) canvas, then scaled with `UIScale` to fill the safe area. Below 900 virtual pixels wide, layouts stack: the decision cards become a list, the HUD uses two rows and the menu becomes one column. Screens rebuild live when the device rotates or the UI-scale setting changes. All controls are buttons, so touch, mouse and gamepad all work. Sliders also have −/+ buttons.

**Input.**
- **Mouse/touch:** tap a card to select it, then tap again or press Confirm.
- **Keyboard:** `1`–`5` selects a choice, `Enter` confirms or continues.
- **Gamepad:** D-pad to move, A to press, and B to cancel a selection or go back.

**Settings** apply instantly and save about 0.8 s after the last change (failed saves retry with the next change).
- **Graphics:** Auto / Low / High controls shadows, post-effects and decorative motion. Auto picks Low on touch-only devices.
- **Camera sensitivity:** saved and exposed for the game's own camera systems. Roblox doesn't let games change the default camera's mouse sensitivity.

---

## 3. Things you need to add in Studio

- **Sounds and music:** paste asset ids you have rights to (Toolbox → Audio) into `Shared/Data/SoundIds`. Empty ids are skipped, so the game is silent until then. The volume settings already control them.
- **Credits:** edit `Config.Credits`.

---

## 4. Testing

```bash
lune run tests/run.luau
```

```bash
selene src
```

Tests run the **real** `src/` files outside Roblox using [Lune](https://lune-org.github.io) and a fake Roblox API (`tests/harness.luau`). The client tests boot the real client against a real server harness, with remotes bridged and data deep-copied. They then click through the loading screen, menu, name entry, the full childhood, the stats panel, settings, credits, save slots and delete confirmation. This runs at desktop, phone-portrait, phone-landscape (including rotating mid-decision) and gamepad layouts, and the tests fail on any script error.

**What the harness can't check:** how things actually look, fonts, real tween timing, and real DataStore and text-filter behaviour. Please play-test in Studio. You should see:
- Output shows `[Server] CHOOSE YOUR LIFE started with 4 services` and no red errors.
- The loading screen leads to the main menu. **Play** leads to name entry, then to decision cards.
- Use Studio's **device emulator** (Test → Device) to check a phone and a tablet.
