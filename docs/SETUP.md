# Setup guide

Install one system at a time. Each step lists the script name, its type, exactly
where it goes in Studio, anything you need to create, and how to prove it works
before moving on. Nothing in a step ever refers to something a later step
creates.

Two things are true of the whole project and save a lot of manual work:

* **No RemoteEvents are created by hand.** `Net.luau` creates them on the server
  and waits for them on the client.
* **No parts and no GUI objects are created by hand.** `EnvironmentBuilder`
  builds the call centre out of parts at runtime and `Interface.luau` builds the
  entire interface in code.

If you use [Rojo](https://rojo.space), skip to [Rojo](#rojo) at the bottom —
`default.project.json` already maps everything.

---

## Step 0 — Studio settings

1. Create a new Baseplate place.
2. **Home → Game Settings → Security → Enable Studio Access to API Services: on.**
   Without it, DataStores fail. The game still runs (progress just will not save,
   and it tells you so in the top bar).
3. Delete the default `Baseplate` part if you like — `EnvironmentBuilder` builds
   its own floor and a `SpawnLocation`.

---

## Step 1 — Shared modules

**Type:** ModuleScript (eleven of them)
**Location:** `ReplicatedStorage` → create a **Folder** named `MacrosoftShared`,
then put all eleven inside it.

| ModuleScript name | Source file |
| --- | --- |
| `Config` | `src/shared/Config.luau` |
| `Util` | `src/shared/Util.luau` |
| `Net` | `src/shared/Net.luau` |
| `NPCNames` | `src/shared/NPCNames.luau` |
| `Personalities` | `src/shared/Personalities.luau` |
| `DialogueLibrary` | `src/shared/DialogueLibrary.luau` |
| `RandomEvents` | `src/shared/RandomEvents.luau` |
| `Upgrades` | `src/shared/Upgrades.luau` |
| `Ranks` | `src/shared/Ranks.luau` |
| `Achievements` | `src/shared/Achievements.luau` |
| `Difficulty` | `src/shared/Difficulty.luau` |

The names must match exactly — every other script requires them by name.

**Test it.** Open the Studio Command Bar and run:

```lua
local S = game.ReplicatedStorage.MacrosoftShared
print(#require(S.Personalities).List, require(S.DialogueLibrary).count(), #require(S.Upgrades).List)
```

Expect `25 56 14`. Any error here is a missing or misnamed module.

---

## Step 2 — Server modules

**Type:** ModuleScript (ten of them)
**Location:** `ServerScriptService` → create a **Folder** named
`MacrosoftServer`, then put all ten inside it. They find each other through
`script.Parent`, so they must be siblings.

| ModuleScript name | Source file |
| --- | --- |
| `PlayerDataManager` | `src/server/PlayerDataManager.luau` |
| `NPCGenerator` | `src/server/NPCGenerator.luau` |
| `NPCPersonalitySystem` | `src/server/NPCPersonalitySystem.luau` |
| `DialogueManager` | `src/server/DialogueManager.luau` |
| `RandomEventManager` | `src/server/RandomEventManager.luau` |
| `RewardManager` | `src/server/RewardManager.luau` |
| `UpgradeManager` | `src/server/UpgradeManager.luau` |
| `AchievementManager` | `src/server/AchievementManager.luau` |
| `CallManager` | `src/server/CallManager.luau` |
| `LeaderboardManager` | `src/server/LeaderboardManager.luau` |

Do **not** add the entry-point Script yet — that is step 4.

**Test it.** Command bar:

```lua
local M = game.ServerScriptService.MacrosoftServer
local npc = require(M.NPCGenerator).generate("Normal", {})
print(npc.fullName, npc.age, npc.personalityName, npc.trust, npc.suspicion)
```

You should get a random caller. Run it a few times — name, age, personality and
starting meters should all change.

---

## Step 3 — Environment builder

**Type:** ModuleScript
**Name:** `EnvironmentBuilder`
**Location:** `ServerScriptService/MacrosoftServer`
**Source:** `src/server/EnvironmentBuilder.luau`

**Test it.** Command bar:

```lua
require(game.ServerScriptService.MacrosoftServer.EnvironmentBuilder).build()
```

`workspace.CallCentre` appears: floor, walls, ceiling lights, twenty desks with
monitors and chairs, blocky colleagues, a break room, a manager's office, an
upgrade kiosk, two leaderboard boards, signage and a `SpawnLocation`. The desk
at the front-left is named `PlayerWorkstation` and carries a `ProximityPrompt`
called `WorkstationPrompt`.

(The colleagues only animate once a `RunService.Heartbeat` connection is alive,
which happens automatically when the game runs.)

---

## Step 4 — Server entry point

**Type:** Script (a plain server Script, not a ModuleScript)
**Name:** `MacrosoftServer`
**Location:** `ServerScriptService/MacrosoftServer` — i.e. **inside** the folder,
as a sibling of the modules.
**Source:** `src/server/MacrosoftServer.server.luau`

This script calls `Net.init()`, which creates
`ReplicatedStorage/MacrosoftRemotes` and every RemoteEvent and RemoteFunction:

* RemoteEvents: `StartCall`, `ChooseOption`, `HangUp`, `PurchaseUpgrade`,
  `RequestData`, `SetDifficulty`, `CallStarted`, `CallUpdated`, `CallEnded`,
  `DataUpdated`, `Notify`, `AchievementUnlocked`, `RankChanged`
* RemoteFunctions: `GetData`, `GetCatalog`

**Test it.** Press Play. The Output window should show:

```
[Macrosoft] v1.0.0 online - 25 personalities, 56 dialogue situations, 17 random events, 14 upgrades.
```

Check that `ReplicatedStorage/MacrosoftRemotes` exists with 15 children, and
that your player has a `leaderstats` folder with `Credits` and `Rank`. Walk to
the front-left desk and the "Start Call" prompt should appear (pressing it does
nothing visible yet — the interface is step 5).

---

## Step 5 — Client

**Type:** two ModuleScripts and one LocalScript
**Location:** `StarterPlayer/StarterPlayerScripts` — all three directly inside
it, as siblings.

| Name | Type | Source file |
| --- | --- | --- |
| `UIKit` | ModuleScript | `src/client/UIKit.luau` |
| `Interface` | ModuleScript | `src/client/Interface.luau` |
| `MacrosoftClient` | **LocalScript** | `src/client/MacrosoftClient.client.luau` |

**Test it.** Press Play. You should see:

* a top bar with Credits, your rank, and Upgrades / Career / How To Play buttons
* a panel at the bottom with five difficulty buttons (Hard, Expert and Nightmare
  greyed out until you rank up) and a big **START CALL** button
* a welcome toast in the top right

Click **START CALL**. A caller card appears on the left with a portrait, name,
age, personality, mood and backstory, three meters, and on the right the stage
banner, a call timer, the caller's line typing itself out, and up to four
dialogue buttons plus **HANG UP**.

Play a call through and confirm each of these:

1. Picking a polite, patient line on a friendly caller raises Trust.
2. Picking an all-caps aggressive line spikes Suspicion (the `+Suspicion`
   readout appears top-right of the dialogue panel on Easy and Normal).
3. Driving Suspicion to 100 ends the call with "You Were Rumbled".
4. Getting through all seven stages with enough Trust ends it with "Call
   Complete" and a reward breakdown.
5. Credits in the top bar and on the Roblox player list both go up.

---

## Step 6 — Check the rest

* **Upgrade shop.** Click **Upgrades** (or use the kiosk prompt in the world).
  Buy the Cheap Headset once you have 250 Credits; it should say "installed at
  your desk", deduct the credits, and show as Owned. `Professional Headset`
  should refuse until you own the cheap one.
* **Career.** Click **Career** for statistics, all nine ranks and all twenty
  achievements. "Hello Sir" unlocks on your first finished call.
* **Saving.** Play, earn credits, stop the playtest, start it again. Credits
  persist. If you skipped the API services setting, the top bar says
  "saving disabled this session" instead of silently losing progress.
* **Leaderboards.** The two boards on the back wall populate about 90 seconds
  after a player with a non-zero total leaves the server.
* **Difficulty.** Rank up to Caller, then check Hard un-greys and that Trust is
  hidden on it.

---

## Rojo

```bash
rojo serve       # then connect from the Rojo Studio plugin
```

`default.project.json` maps:

* `src/shared` → `ReplicatedStorage/MacrosoftShared`
* `src/server` → `ServerScriptService/MacrosoftServer`
* `src/client` → `StarterPlayer/StarterPlayerScripts`

---

## Where the MVP stops and the full game starts

The brief asked for an MVP first. The MVP subset is:

`Config`, `Util`, `Net`, `NPCNames`, `Personalities` (the five Easy-tier
archetypes alone are enough), `DialogueLibrary`, `Upgrades`, `Ranks`,
`Difficulty`, `PlayerDataManager`, `NPCGenerator`, `NPCPersonalitySystem`,
`DialogueManager`, `RewardManager`, `UpgradeManager`, `CallManager`,
`MacrosoftServer`, `UIKit`, `Interface`, `MacrosoftClient`.

Everything else — `RandomEvents`/`RandomEventManager`, `Achievements`/
`AchievementManager`, `EnvironmentBuilder`, `LeaderboardManager`, the Hard,
Expert and Nightmare personality tiers — is the expansion, and each piece is
additive. Delete any of them and the rest still runs, except that
`MacrosoftServer` requires them all; comment out the matching `require` lines if
you want to strip it back.

---

## Extending it

* **New caller:** add one entry to `Personalities.List`. Give it a `tier`, base
  meters, `likes`/`dislikes` tag multipliers and the ten `voice` categories.
  Nothing else needs to change — it enters the rotation immediately.
* **New dialogue:** add an `add({...})` block in `DialogueLibrary.luau` with a
  `stage` and up to four choices. Optionally restrict it to specific callers with
  `personalities = { "tech_teen" }` or gate it behind rank with `minLevel`.
* **New interruption:** add an entry to `RandomEvents.List`.
* **New upgrade / rank / achievement:** add an entry to the matching list module.

Keep new dialogue fictional and absurd. The fake instructions in stage 5 (blue
wizard windows, moon keys, typing BANANA) are written that way deliberately.

## Balance knobs

All in `Config.Call`:

| Key | Effect |
| --- | --- |
| `TrustToSucceed` | Trust needed at stage 7 to win |
| `SuspicionScale` | Global multiplier on all suspicion gains |
| `SuspicionMultiplierSoftening` | Exponent applied to personality x difficulty suspicion, so the hardest callers stay hard without being arithmetically unwinnable |
| `ReassureTrust` / `ReassureAmount` | How much a well-judged line calms a caller |
| `ProgressPerStage` | How many situations a stage takes |
| `PatienceTickSeconds` | How fast patience drains with time |

After changing any of them, re-run `./tests/run.sh` — it asserts the difficulty
curve still descends and that every winnable caller is still winnable.
