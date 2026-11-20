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
  - `[Server] CHOOSE YOUR LIFE started with 7 services` and no red errors.
  - A yellow line saying DataStores are unavailable and the in-memory store is being used. That's expected: an unpublished place can't save, so progress resets each time you press Stop.
  - If filtering isn't available in Studio, a yellow line about text filtering. That's also expected and only happens in Studio.
- **On screen:** a loading screen, then the main menu. **Play** → choose a name → decision cards.

**Things to try:**
- Play through Childhood to see your first **Life Reveal**.
- The HUD buttons: 🔮 Future, 👥 People, 🎯 Lifestyle, 💰 Money, 📊 Stats.
- Settings, save slots, and Life History (after you finish a life).

> Tip: to rush through a life, tap each card twice (select + confirm) and press **Continue**. Settings → **Reduce animations** shortens the cinematics.

### Make progress save between tests

1. **File → Publish to Roblox** (create a new experience; it can stay private).
2. **Home → Game Settings → Security →** turn on **Enable Studio Access to API Services** → Save.
3. Press Play again. The "in-memory" warning disappears and your lives, coins and settings persist.

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
