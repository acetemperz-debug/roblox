# Macrosoft Support: Call Centre Simulator

A satirical, choice-based Roblox game (Luau) in which you work at a fictional
overseas call centre and try to convince AI-driven American NPCs that you are
calling from "Macrosoft Support".

**This is a comedy game about a scam, not a scam tool.** Everything in it is
invented: the company, the fault, the "instructions", the store cards. The
dialogue is deliberately absurd so the script cannot be lifted out of the game
and used on a real person. Do not do any of this to anybody.

## What is in here

| System | File | Role |
| --- | --- | --- |
| Config | `src/shared/Config.luau` | Every tunable number in one place |
| Util | `src/shared/Util.luau` | RNG, weighted picks, formatting |
| Net | `src/shared/Net.luau` | Creates/waits for every RemoteEvent and RemoteFunction |
| NPCNames | `src/shared/NPCNames.luau` | 306 first names, 168 surnames, moods, jobs, backstories |
| Personalities | `src/shared/Personalities.luau` | 25 caller archetypes with their own voice lines |
| DialogueLibrary | `src/shared/DialogueLibrary.luau` | 56 dialogue situations across 7 stages |
| RandomEvents | `src/shared/RandomEvents.luau` | 17 mid-call interruptions |
| Upgrades | `src/shared/Upgrades.luau` | 14 desk upgrades and their bonuses |
| Ranks | `src/shared/Ranks.luau` | 9 career ranks |
| Achievements | `src/shared/Achievements.luau` | 20 achievements |
| Difficulty | `src/shared/Difficulty.luau` | 5 difficulty presets and meter visibility |
| PlayerDataManager | `src/server/PlayerDataManager.luau` | DataStore load/save, autosave, stats |
| NPCGenerator | `src/server/NPCGenerator.luau` | Rolls a caller |
| NPCPersonalitySystem | `src/server/NPCPersonalitySystem.luau` | Turns a choice into a reaction |
| DialogueManager | `src/server/DialogueManager.luau` | Picks the next situation |
| RandomEventManager | `src/server/RandomEventManager.luau` | Fires interruptions |
| CallManager | `src/server/CallManager.luau` | The call state machine |
| RewardManager | `src/server/RewardManager.luau` | Payouts and bonuses |
| UpgradeManager | `src/server/UpgradeManager.luau` | Purchases |
| AchievementManager | `src/server/AchievementManager.luau` | Unlock checks |
| Products | `src/shared/Products.luau` | Robux catalogue: 5 passes, 6 developer products |
| MonetisationManager | `src/server/MonetisationManager.luau` | Ownership caching, ProcessReceipt, grants |
| CosmeticsManager | `src/server/CosmeticsManager.luau` | Overhead titles and the Platinum Headset |
| EnvironmentBuilder | `src/server/EnvironmentBuilder.luau` | Builds the whole call centre from parts |
| LeaderboardManager | `src/server/LeaderboardManager.luau` | OrderedDataStore wall boards |
| MacrosoftServer | `src/server/MacrosoftServer.server.luau` | Server entry point |
| UIKit / Interface | `src/client/UIKit.luau`, `src/client/Interface.luau` | Builds the whole GUI in code |
| MacrosoftClient | `src/client/MacrosoftClient.client.luau` | Client entry point |

No parts, GUIs or RemoteEvents have to be created by hand. The world and the
interface are both generated at runtime.

## Installing

Either sync with [Rojo](https://rojo.space) using `default.project.json`, or
copy the files in by hand. `docs/SETUP.md` walks through it one system at a
time, in an order where nothing ever references something that does not exist
yet, with a test for each step.

## Testing outside Studio

`tests/` contains a stubbed Roblox API and a headless simulator that plays whole
calls through the real server modules:

```bash
./tests/run.sh          # needs the standalone Luau CLI and python3
```

It checks content volume, compiles every file, then plays 1,200 calls across all
five difficulties with three different player skill levels and asserts the
difficulty curve behaves. Current balance, optimal play:

| Difficulty | Skilled player | Blind clicking |
| --- | --- | --- |
| Easy | 100% | 36% |
| Normal | 100% | 9% |
| Hard | 80% | 2% |
| Expert | 36% | 0% |
| Nightmare | 8% | 0% |

Nightmare is that low on purpose: most of its callers (a rival call centre, a
police front desk, a scambaiter) are written so they can never be fooled.

## Leaderboards

Seven global boards, all OrderedDataStore-backed and shared across servers:

* **Top Lifetime Earnings** and **Most Successful Calls** on the back wall
* **One board per difficulty** down the right-hand wall, counting wins on that
  difficulty

The difficulty boards count *wins*, never credits, so no paid multiplier can
move a player up them.

## Robux

The catalogue lives in `src/shared/Products.luau`. Every item ships with
`assetId = 0`, which means "not configured" — the store shows it as unavailable
rather than prompting a purchase that would fail. Create each item on the
Creator Dashboard and paste the IDs in.

| Game Pass | Effect |
| --- | --- |
| Overtime Contract | 2x Credits forever (does not touch leaderboards or rank) |
| Employee Of The Month | Gold overhead title visible to the whole server |
| Corner Office | A personal desk inside the glass manager's office |
| Platinum Headset | Cosmetic headset welded to your character |
| Alias Licence | Replace "Kevin" with your own technician name in dialogue |

| Developer Product | Effect |
| --- | --- |
| Coffee Refill | +40 Patience, used from the call screen |
| Supervisor Takeover | Skips the next random interruption |
| Warm Lead | Next caller rolls one tier friendlier |
| Petty Cash / Bonus Payslip | 2,500 / 15,000 Credits |
| Double Shift | 2x Credits for 30 minutes |

Three rules the code enforces, and the tests assert:

* **Nothing paid reveals the caller.** Reading the caller is the whole skill on
  Hard and above.
* **Bought Credits are not earnings.** They can buy desk upgrades but never
  rank, the earnings board, or the wealth achievement.
* **Grants are saved before `PurchaseGranted` is returned**, and deduped on
  `PurchaseId`, so a replayed receipt never double-grants and a failed save
  never silently eats a purchase.
