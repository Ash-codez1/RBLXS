# How to test-run CHOOSE YOUR LIFE

You need a **Windows or Mac computer** with **Roblox Studio** (free). Studio doesn't run on phones, iPads or Chromebooks, but you can test the phone and tablet layouts inside Studio (see below).

---

## Quickest way: open the ready-made place file (no extra tools)

1. **Install Roblox Studio** from <https://create.roblox.com> (Start Creating → download Studio) and sign in.
2. **Download the place file** `build/ChooseYourLife.rbxlx`:
   - Open <https://github.com/Ash-codez1/RBLXS/blob/main/build/ChooseYourLife.rbxlx>, then click **Download raw file** (the ⬇ button at the top right of the file view).
   - Or: on the repo's main page click **Code → Download ZIP**, unzip it, and find `build/ChooseYourLife.rbxlx`.
3. **Open it in Studio:** **File → Open from File…** and choose `ChooseYourLife.rbxlx`. Double-clicking the file also works.
4. **Press Play** (the ▶ button, or **F5**).

**What you should see:**
- **Output window** (View → Output):
  - `[Server] CHOOSE YOUR LIFE started with 13 services` and no red errors.
  - A yellow line saying DataStores are unavailable and the in-memory store is being used. That's expected: an unpublished place can't save, so progress resets each time you press Stop.
  - If filtering isn't available in Studio, a yellow line about text filtering. That's also expected and only happens in Studio.
- **On screen:** a loading screen, then the main menu. **Play** → choose a name → decision cards.
- **In the Explorer window:** `Workspace › World` appears once you press Play. The town is generated when the server starts, so in Edit mode Workspace only holds `SeaFloor` and `SpawnLocation` (README §1 shows how to bake the town in if you want to edit it).

**Things to try:**
- Play through Childhood to see your first **Life Reveal**.
- The HUD buttons: 🔮 Future, 🤝 Circle, 👥 People, 🎯 Lifestyle, 💰 Money, 📊 Stats.
- Settings, save slots, and Life History (after you finish a life).
- **🛍️ Shop** and **🎒 My Items** (main menu): you start with 100 Coins, enough for a baseball cap. Watch your look change on the menu card, in the HUD and on your character's name tag.
- **🌆 Explore Lifeville** (the first HUD button, or the main menu): see the next section.

> Tip: to rush through a life, tap each card twice (select + confirm) and press **Continue**. Settings → **Reduce animations** shortens the cinematics.

### Make progress save between tests

1. **File → Publish to Roblox** (create a new experience; it can stay private).
2. **Home → Game Settings → Security →** turn on **Enable Studio Access to API Services** → Save.
3. Press Play again. The "in-memory" warning disappears and your lives, coins and settings persist.

### Explore Lifeville (the 3D town)

1. Start a life, then press **🌆** in the HUD. The menus fade and you're standing in Lifeville Plaza.
2. Move with **WASD**, the touch thumbstick or a gamepad stick. Press **E** (tap, or **X** on a gamepad) when a prompt appears.
3. Things to try:
   - **Mayor Bloom** (just north of the spawn): talk to him, then try **Show me the town map** and tap a district to get a golden guide line.
   - **The wishing fountain:** you should hear a splash and see a result card (+Happiness). Note the **⚡ actions** counter in the top bar.
   - **Maple School** (west): study at a desk and read in the library. After 2 actions you're told to make your next decision. Press **📝 Next decision**, decide, then come back with 🌆 to get 2 more actions.
   - **Downtown** (north) is walled off for a child, with a sign saying when it opens. As a grown-up, try the bank, the café, The Golden Fork and the boutique (which opens the shop).
   - **Oak Street** (south): find the house with your name on the sign and go inside. Buy a house style or car in the shop and watch your house change within a few seconds.
   - **Day and night:** a full day lasts 12 minutes, so dusk is never more than 12 minutes away. At dusk the lamps and windows light up.
4. **Life Reveal flyover:** finish a life stage with Settings → **Reduce animations** off. After the cinematic preview, the camera flies over a real place in town.
5. **Two players** (Test → Clients and Servers): you should see each other walking around, and each of you gets your own house.

> If a townsperson can't be built in Studio, Output shows a yellow `[NPCService] Using a simple character for …` line and a block figure stands there instead. Please report it if you see it.

### Test the shop and Robux purchases

**Coins and cosmetics** work straight away: finish stages (+15 Coins each) and lives, then buy, equip and remove items. Coins only save between tests if saving is on (see above).

**Robux purchases** need your own passes and products first (README §3 explains how):
1. Publish the place, then create the **VIP** and **2× Coins** passes and the three coin packs under Creator Dashboard → your experience → **Monetization**.
2. Paste each id into `ReplicatedStorage › Shared › Data › Monetisation`, then press Play.
3. Shop → **🪙 Get Coins**. Studio shows Roblox's purchase window as a **test purchase**, so no Robux are charged.
   - **Coin pack:** the Coins arrive once the purchase finishes, with a "Thank you!" notice.
   - **VIP:** the VIP items become free to claim (⭐ Claim free with VIP).
   - **2× Coins:** the next stage reveal shows "(2× Coins)".
4. Press Stop, then Play again. Roblox reports that you don't really own a pass you test-bought, so it's removed when you rejoin. That's the same check that stops anyone faking a pass.

### Test phones, tablets and consoles

**Test** tab → **Device** (the device emulator). Pick e.g. *iPhone 14* or *iPad*, and rotate it with the rotate button. The layout adapts to portrait, landscape and tablet. On PC you can also plug in a gamepad: D-pad/stick to move, **A** to press, **B** to go back or cancel.

### Test multiplayer (Life Circles, group decisions, city events)

1. **Test** tab → **Clients and Servers** → choose **2 Players** → **Start**. Studio opens a local server plus two player windows (Player1 and Player2).
2. In each window, press **Play** and start a life.
3. In Player1's window: **🤝** (in the HUD) or the menu's **Play With Friends** → **Invite** next to Player2.
4. In Player2's window an invite card appears at the top: press **Join**.
5. Now try:
   - **🎲 Group decision:** both windows get a vote. Vote in each window and watch the live tally. The majority decides, and each life gets its own result.
   - **🔮 Group reveal:** both windows play a Group Life Reveal with a "most likely to…" board.
   - **⚖️ Compare:** side-by-side futures, stats, homes and cars.
6. **City events** pop up for everyone in the server every 90 seconds in Studio (every 8 minutes in the live game). Press **Join** or **Skip**.

> Test players in Studio aren't Roblox friends. Players in the same Life Circle count as friends for privacy, so they can see each other's futures. Anyone outside your circle sees "keeps their future private" unless you set Settings → Privacy → *My Life Reveals* to **Everyone**.
> **Invite friends** (the Roblox invite prompt) and **Join their server** only work in the published game, not in Studio.

---

## For ongoing development: live sync with Rojo

Use this if you (or Claude on your computer) will keep editing the code. Studio updates instantly when files change.

1. Install **Rojo 7**, for example with the VS Code extension *"Rojo – Roblox Studio Sync"*, or download `rojo` from <https://github.com/rojo-rbx/rojo/releases>.
2. Install the Studio plugin:

```bash
rojo plugin install
```

3. Get the code:

```bash
git clone https://github.com/Ash-codez1/RBLXS.git
```

```bash
cd RBLXS
```

4. Start the sync server:

```bash
rojo serve
```

5. In Studio, open the place, then **Plugins → Rojo → Connect**.

To rebuild the place file yourself:

```bash
rojo build default.project.json -o build/ChooseYourLife.rbxlx
```

---

## Automated tests (no Studio needed)

The game's real scripts run against a simulated Roblox in [Lune](https://lune-org.github.io). This includes a full playthrough of the UI on desktop, phone and gamepad layouts, and 400 simulated lives.

Install Lune once:

```bash
cargo install lune --locked
```

Then run the tests:

```bash
lune run tests/run.luau
```

Prediction-accuracy report for the Life Reveal:

```bash
lune run tests/tools/calibrate.luau 600 555
```

---

## If something goes wrong

- **Red error in Output:** copy the whole red line (and the lines under it) and paste it to Claude. It will point straight at the problem.
- **The screen stays on "Loading your life…":** check Output for errors starting with `[DataService]`.
- **Text looks like a different font:** harmless. Studio is still downloading the font.
- **No sound:** expected for now. Add sound ids in `ReplicatedStorage › Shared › Data › SoundIds`.
