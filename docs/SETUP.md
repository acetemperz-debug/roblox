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

**Type:** ModuleScript (twelve of them)
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
| `Products` | `src/shared/Products.luau` |

That is twelve modules. The names must match exactly — every other script
requires them by name.

**Test it.** Open the Studio Command Bar and run:

```lua
local S = game.ReplicatedStorage.MacrosoftShared
print(#require(S.Personalities).List, require(S.DialogueLibrary).count(), #require(S.Upgrades).List)
```

Expect `25 56 14`. Any error here is a missing or misnamed module.

---

## Step 2 — Server modules

**Type:** ModuleScript (twelve of them)
**Location:** `ServerScriptService` → create a **Folder** named
`MacrosoftServer`, then put all twelve inside it. They find each other through
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
| `MonetisationManager` | `src/server/MonetisationManager.luau` |
| `CosmeticsManager` | `src/server/CosmeticsManager.luau` |

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
upgrade kiosk, signage and a `SpawnLocation`. The desk at the front-left is
named `PlayerWorkstation` and carries a `ProximityPrompt` called
`WorkstationPrompt`.

Check `workspace.CallCentre.Leaderboards` has **seven** boards: `LifetimeEarnings`
and `SuccessfulCalls` on the back wall, and `Board_Easy` through
`Board_Nightmare` down the right-hand wall. Inside the manager's office there is
a second desk named `ExecutiveWorkstation` with an `ExecutivePrompt` — that one
is gated behind the Corner Office game pass in step 4.

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
  `RequestData`, `SetDifficulty`, `PromptPurchase`, `UseItem`, `SetAlias`,
  `CallStarted`, `CallUpdated`, `CallEnded`, `DataUpdated`, `Notify`,
  `AchievementUnlocked`, `RankChanged`
* RemoteFunctions: `GetData`, `GetCatalog`, `GetStore`

**Test it.** Press Play. The Output window should show:

```
[Macrosoft] v1.1.0 online - 25 personalities, 56 dialogue situations, 17 random events, 14 upgrades.
[Macrosoft] Robux store: 0 of 11 items have an asset id set. Items without one show as unavailable.
```

The second line is expected until you do step 7. Check that
`ReplicatedStorage/MacrosoftRemotes` exists with 19 children, and
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
* **Leaderboards.** All seven boards refresh on start and then every 90 seconds.
  A player's totals are published when they leave and after every finished call,
  so the boards fill in once somebody has a non-zero total. Without API services
  enabled they say so on the board rather than sitting on "Loading...".
* **Difficulty.** Rank up to Caller, then check Hard un-greys and that Trust is
  hidden on it.

---

## Step 7 — Robux items (optional, do it last)

The game runs fine without this. Every item in `src/shared/Products.luau` ships
with `assetId = 0`, which the store renders as **Unavailable** rather than
prompting a purchase that would fail.

To turn an item on:

1. **Creator Dashboard → your experience → Monetization.**
   * Game Passes for the five permanent items.
   * Developer Products for the six consumables.
2. Copy each item's ID.
3. Paste it into the matching `assetId` field in `Products.luau`.

| Item | Type | Suggested price |
| --- | --- | --- |
| Overtime Contract | Game Pass | 199 R$ |
| Employee Of The Month | Game Pass | 99 R$ |
| Corner Office | Game Pass | 149 R$ |
| Platinum Headset | Game Pass | 79 R$ |
| Alias Licence | Game Pass | 99 R$ |
| Coffee Refill | Developer Product | 25 R$ |
| Supervisor Takeover | Developer Product | 35 R$ |
| Warm Lead | Developer Product | 45 R$ |
| Petty Cash | Developer Product | 49 R$ |
| Bonus Payslip | Developer Product | 199 R$ |
| Double Shift | Developer Product | 99 R$ |

Prices are a starting point, not a rule — `suggestedRobux` is only what the
store UI prints under the button. The real price is whatever you set on the
Dashboard.

**Test it.** With at least one item configured:

1. Open **Store** in the top bar. Configured items show **Buy**; unconfigured
   ones show **Unavailable** and say so if you click them.
2. Buy a Coffee Refill (test purchases in Studio do not charge you). It should
   land in your inventory, and a **Coffee (1)** button appears at the bottom of
   the call screen during a call. Using it raises Patience and spends it.
3. Buy the Alias Licence, then set a name under **Career → Technician Name**.
   Your dialogue lines stop saying Kevin.
4. Buy Employee Of The Month and respawn — a gold title appears over your head.
   Without it you get your rank as a plain title instead.
5. Buy Corner Office, then use the desk inside the glass office. Without the
   pass that prompt refuses you.

**Things to know before you ship it:**

* `ProcessReceipt` saves the grant *before* returning `PurchaseGranted`, and
  dedupes on `PurchaseId`. If the save fails it returns `NotProcessedYet` so
  Roblox retries rather than charging for something that was not kept. Do not
  "simplify" that.
* Bought Credits are granted with `countAsEarnings = false`. They buy desk
  upgrades but never rank, the earnings board, or the wealth achievement.
* No paid item reveals anything about the caller. The headless tests assert
  this — see `no paid item sells information about the caller` in
  `tests/simulate.luau`.
* Keep item names corporate and mundane. Naming a paid item after the fictional
  store cards is the one thing that would make the storefront read as something
  other than parody.

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
`AchievementManager`, `EnvironmentBuilder`, `LeaderboardManager`, `Products`/
`MonetisationManager`/`CosmeticsManager`, the Hard, Expert and Nightmare
personality tiers — is the expansion, and each piece is additive. Delete any of them and the rest still runs, except that
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

* **New paid item:** add an entry to `Products.GamePasses` (permanent, folds its
  `effects` into the same bonus table the desk upgrades use) or
  `Products.DeveloperProducts` (consumable, with a `grant.kind` of `credits`,
  `boost` or `consumable`). Do not give a paid item an effect that reveals the
  caller — the tests fail the build if you do.

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
