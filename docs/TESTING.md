# How to test the game

Four ways in, fastest first.

---

## 0. Paste the installer into the Studio command bar (~20 seconds)

Open Studio on any place, open the **command bar** (View → Command Bar), paste
the contents of **`tools/StudioLoader.lua`**, press Enter.

It downloads every script from GitHub and puts it in the right service. Then
turn on **Game Settings → Security → Studio Access to API Services** and press
Play.

Re-run the same paste any time to pull the latest push — it replaces the old
copy rather than duplicating it.

Requirements and caveats:

* The repo has to stay **public**; the loader fetches over plain HTTPS with no
  credentials. Make it private again and the loader stops working (the place
  and model files below still work).
* It needs **Allow HTTP Requests**. The loader turns that on itself if it can,
  and tells you where the setting is if it cannot.
* It is pinned to the branch `claude/roblox-scam-call-centre-yx6beg`. Change
  `BASE` in the loader if you move the code.
* It installs into the place you currently have open, so it is also the answer
  for "add this to my existing place".

---

## 1. Open the prebuilt place (no tooling, ~1 minute)

1. Download **`build/MacrosoftSupport.rbxlx`** from the repo.
   On GitHub: open the file → the **Download raw file** button (top right).
2. Open Roblox Studio → **File → Open from File…** → pick that file.
   (Or just double-click the downloaded file.)
3. **Home → Game Settings → Security → Enable Studio Access to API Services: ON.**
   Without this, saving and leaderboards are disabled. The game still runs and
   the top bar tells you saving is off.
4. Press **Play** (F5).

That file already has everything in the right place: the thirteen shared
modules under `ReplicatedStorage/MacrosoftShared`, the sixteen server modules
under `ServerScriptService/MacrosoftServer`, and the three client files in
`StarterPlayer/StarterPlayerScripts`. The call centre itself and the entire
interface are generated at runtime, so there is nothing to build by hand.

It is generated from the source tree, so after changing any code run:

```bash
python3 tools/build_place.py
```

and reopen it.

---

## 1b. Adding it to a place you already have

Opening the place file above replaces whatever you had open. If you want the
game inside an existing place instead, use the model:

1. Download **`build/MacrosoftSupport.rbxmx`**.
2. In Studio, right-click anywhere in the Explorer → **Insert from File…** →
   pick it. A `MacrosoftSupport` folder appears with three folders inside.
3. Drag **`MacrosoftShared`** into `ReplicatedStorage`.
4. Drag **`MacrosoftServer`** into `ServerScriptService`.
5. Open **`DRAG_MY_CONTENTS_INTO_StarterPlayerScripts`** and drag its three
   children (`UIKit`, `Interface`, `MacrosoftClient`) into
   `StarterPlayer/StarterPlayerScripts`. They must be direct children there,
   not inside a folder — they find each other through `script.Parent`.
6. Delete the now-empty `MacrosoftSupport` folder and press Play.

## 2. Rojo (what to use if you are actually developing)

Editing code, rebuilding a place and reopening it gets old fast. Rojo syncs the
files into a running Studio session as you save.

1. Install the Rojo CLI: <https://rojo.space/docs/v7/getting-started/installation/>
2. Install the **Rojo** plugin from the Studio plugin marketplace.
3. In the repo: `rojo serve`
4. In Studio: open any place → Rojo plugin → **Connect**.
5. Press Play. Edits to files now appear in Studio immediately.

`default.project.json` already maps the three source folders to the right
services.

---

## 3. By hand

If you would rather place the files yourself, `docs/SETUP.md` walks through it
one system at a time with a test after each step. Thirty-two files, so budget
half an hour.

---

## What to check once it is running

### The call game (2 minutes)

1. A top bar appears with Credits, your rank and five buttons. Bottom right is
   the difficulty picker and **START CALL**. Bottom left is the operation HUD.
2. Click **START CALL**. You get a random caller with a name, age, personality,
   mood and backstory, three meters, and up to four dialogue choices.
3. Pick the polite, patient lines on a friendly caller — Trust climbs.
4. Pick the all-caps aggressive line — Suspicion spikes, and on Easy/Normal the
   `+Suspicion` readout shows in the top right of the dialogue panel.
5. Keep being aggressive until Suspicion hits 100 → **You Were Rumbled**.
6. Play one properly through all seven stages → **Call Complete** with a reward
   breakdown, and your Credits go up.

### The tycoon layer (3 minutes)

7. **Operation → Staff → Hire** a Work Experience Kid (750 Credits). The HUD
   income line goes to `+1.5 /sec` and Credits start climbing on their own.
8. Hire until it refuses — the Back Room has 3 desks. Buy **Premises → Small
   Office** for more.
9. The heat line should read *cooling off*. That is correct: a tiny operation
   draws no police attention. Nobody gets raided in their first session.
10. Switch to a higher **Method** once you have the rank and the Credits. Heat
    starts climbing and the HUD estimates a time to raid.
11. Buy a **Security** upgrade or two and watch the heat rate fall and the
    escape chance in the Operation header rise.

### Seeing a raid without waiting

Paste into the Studio **command bar** while playing (swap in your username):

```lua
local PDM = require(game.ServerScriptService.MacrosoftServer.PlayerDataManager)
PDM.get(game.Players.YourName).operation.heat = 96
```

Within seconds you get the final warning, then either *They Found Nothing* or
*Raided* — and a police car with your name on it pulls up outside for the whole
server to see.

### Other useful command-bar pokes

Give yourself money:

```lua
local PDM = require(game.ServerScriptService.MacrosoftServer.PlayerDataManager)
PDM.addCredits(game.Players.YourName, 5000000, true)
```

Jump to the top rank so every difficulty and method tier is unlocked:

```lua
local PDM = require(game.ServerScriptService.MacrosoftServer.PlayerDataManager)
local data = PDM.get(game.Players.YourName)
data.stats.lifetimeEarnings = 1000000
data.stats.successfulCalls = 400
PDM.recalculateRank(game.Players.YourName)
PDM.notify(game.Players.YourName)
```

Force a specific caller so you can test one personality:

```lua
-- Run this, then press START CALL.
local NPCGen = require(game.ServerScriptService.MacrosoftServer.NPCGenerator)
local real = NPCGen.generate
NPCGen.generate = function(difficulty, bonuses, seed, options)
	local npc = real(difficulty, bonuses, seed, options)
	while npc.personalityId ~= "tech_teen" do -- swap in any id
		npc = real(difficulty, bonuses, seed, options)
	end
	return npc
end
```

Personality ids live in `src/shared/Personalities.luau`: `friendly_elder`,
`gullible_max`, `tech_teen`, `cyber_pro`, `scambaiter`, `police_desk`,
`rival_centre`, `the_auditor`, `drama_student` and the rest.

---

## Why the installer downloads instead of carrying the code

The Studio command bar is a single-line input, and the game is about 370,000
characters of Luau across 32 files. Pasting all of it would be truncated, so
`StudioLoader.lua` is a 2 KB script that fetches the rest at runtime from
`build/manifest.json` plus one request per file.

The loader has no `--` line comments on purpose: if the command bar collapses
the paste onto one line, a line comment would swallow everything after it. The
build checks that the loader still compiles when flattened.

## Testing without Studio at all

The logic runs headless. From the repo, with the
[Luau CLI](https://github.com/luau-lang/luau/releases) and python3 on PATH:

```bash
./tests/run.sh
```

That compiles every file, lints, rebuilds the place, then plays 1,200 calls
through the real server modules at three skill levels and asserts the whole
economy: the difficulty curve descends, every winnable caller is winnable, every
tycoon ladder climbs, a starter operation never overheats, and no paid item
sells information about the caller.

It is the fastest way to know you have not broken anything, and it takes a few
seconds.

---

## If something goes wrong

**Nothing appears / no UI.** Check Output. The server prints two lines on a
healthy start:

```
[Macrosoft] v1.3.0 online - 25 personalities, 56 dialogue situations, 17 random events, 14 upgrades.
[Macrosoft] Robux store: 0 of 14 items have an asset id set. Items without one show as unavailable.
```

No first line means the server script did not run — check it is a **Script**
(not a ModuleScript) named `MacrosoftServer` inside
`ServerScriptService/MacrosoftServer`.

**"Infinite yield possible on ReplicatedStorage:WaitForChild("MacrosoftShared")".**
The shared folder is missing or misnamed. It must be exactly
`MacrosoftShared` inside `ReplicatedStorage`.

**Top bar says "saving disabled this session".** API services are off (step 3
above), or the DataStore read failed. This is deliberate: the game refuses to
save over a profile it could not read, rather than wiping your progress.

**Store items all say "Unavailable".** Expected until you create them on the
Creator Dashboard and paste the IDs into `src/shared/Products.luau`. See step 8
of `docs/SETUP.md`.

**Leaderboards say they need API access.** Same as above — turn on Studio
Access to API Services.
