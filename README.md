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
| Operation | `src/shared/Operation.luau` | Tycoon data: 7 methods, 7 staff tiers, 7 premises, 7 security, 7 tradecraft |
| OperationManager | `src/server/OperationManager.luau` | Purchases, passive income, offline earnings, the tick |
| HeatManager | `src/server/HeatManager.luau` | Police pressure, warnings and raids |
| EnvironmentBuilder | `src/server/EnvironmentBuilder.luau` | Builds the whole call centre from parts |
| LeaderboardManager | `src/server/LeaderboardManager.luau` | OrderedDataStore wall boards |
| MacrosoftServer | `src/server/MacrosoftServer.server.luau` | Server entry point |
| OfficeManager / OfficeSessions | `src/server/OfficeManager.luau`, `src/server/OfficeSessions.luau` | Personal plots, authoritative entry and ephemeral invite-only parties |
| OfficeSessionUI | `src/client/OfficeSessionUI.luau` | Session choice, invitations and management access controls |
| UIKit / Interface | `src/client/UIKit.luau`, `src/client/Interface.luau` | Builds the whole GUI in code |
| MacrosoftClient | `src/client/MacrosoftClient.client.luau` | Client entry point |
| Juice | `src/client/Juice.luau` | Floating numbers, flashes, shakes, confetti, the live ticker |

No parts, GUIs or RemoteEvents have to be created by hand. The world and the
interface are both generated at runtime.

## Private offices and host co-op (1.5.0)

The first session starts with **Solo** or **Host Co-op** and saves that choice in
the existing player profile. Later joins restore it and enter the personal office
without blocking onboarding; the default can be changed at **Office Management**.
Choosing Co-op does not grant random players access. Use your
physical **Office Management** computer's **Invite / Access** button to invite
another player in the same server. The addressed player must accept the offer
within 90 seconds. Parties support eight players including the host.

Accepted guests teleport into the host's office and may make calls at its
workstation. Call income, heat, rank progress and achievements belong to the
host; guests never merge saves or consume either player's paid items. Spending,
campaign changes, recruitment, upgrades and premium purchases stay host-only.
Each player's existing personal passive-income simulation continues separately;
it is not copied into, multiplied by, or paid out of the shared office.

The host can remove guests at Management; guests can leave there too. Removal
returns the guest to their own office and cancels any unfinished shared call
without payout. Respawning and the public lobby's return lift use the accepted
host office. Host disconnection sends guests back to their own Solo offices;
guest disconnection leaves the host undisturbed. Rejoining requires fresh consent.

Membership and invitations live only in server memory. Existing user-ID save
keys, receipts, permanent ownership and leaderboards are unchanged; only the
owner's `solo` / `host_coop` default is persistent. Plot entry
is checked server-side independently of terminal permissions, including forced
movement across walls; replicated ownership attributes are display metadata,
not authorization. These are isolated plots in the same server, not reserved
servers or cross-server invitations.

## Physical office foundation (1.4.0)

Continues `claude/roblox-scam-call-centre-yx6beg` at `bbdb628`; the existing
managers, dialogue, economy, save keys and Rojo layout remain in place.

After choosing a mode, players enter their own saved office. Interact with **Calls + Campaigns**
to choose a difficulty, make calls or select a fictional operation method.
**HR** hires/fires staff; **Office Management** expands premises, buys desk
upgrades and trains tradecraft; **Security** installs protection, monitors heat,
uses the lawyer and activates Lay Low; the **Premium Kiosk** opens the Robux
catalogue. Career/help and read-only income/heat remain on the HUD. Walking
away or dying closes the computer and disconnects an active call.

The purple lift visits the original shared lobby and eight physical global
boards. Each board keeps its Top 10 and has a personalised row: interact with
the board to load your exact competition rank, including outside the Top 10.
Ties share a rank; zero scores are unranked. Results cache for 90 seconds.
Unavailable DataStores show an explicit unavailable state, never a made-up rank.

All seven premises grow the physical floor and its desk capacity, from three
desks to ninety. Hired employees occupy those desks with tier-coloured outfits;
firing and raids update the visible roster. Neon trim, warm lights, skyline
windows, upgrade/heat boards, plants and progressively improved surfaces make
the operation's growth visible. The original lobby is retained as a showroom.

`TerminalAccess` validates physical sessions on the server, including ownership,
distance, line of sight, a living character, terminal-specific permissions and
rate limits. `OfficeManager` presents saved operation state using the existing
`EnvironmentBuilder` primitives; it never pays income. `LeaderboardRank`
implements paginated global ranks without a Top-100 cutoff.

Windows validation: `./tests/run.ps1` (Luau, Python and Rojo on PATH, or pass
`-Luau`, `-Compiler`, `-Python`, `-Rojo`). See `docs/TESTING.md` for the physical
terminal and multiplayer Studio checklist and the limits of the headless tests.

## Testing it right now

Fastest: paste **`tools/StudioLoader.lua`** into the Roblox Studio command bar.
It downloads every script from this repo into the right service, in about
twenty seconds, and re-running it updates an existing install. Needs the repo
to stay public and HTTP requests allowed.

Otherwise: download **`build/MacrosoftSupport.rbxlx`**, open it in Roblox Studio, turn on
**Game Settings → Security → Studio Access to API Services**, and press Play.
Everything is already in the right service and the world and UI build
themselves at runtime.

To add it to a place you already have, use `build/MacrosoftSupport.rbxmx`
instead: right-click in Explorer → Insert from File, then drag the three
folders where their names say.

`docs/TESTING.md` has the full walkthrough, command-bar shortcuts for forcing a
raid or a specific caller, and what to check.

## Installing

Either sync with [Rojo](https://rojo.space) using `default.project.json`, or
copy the files in by hand. `docs/SETUP.md` walks through it one system at a
time, in an order where nothing ever references something that does not exist
yet, with a test for each step. `tools/build_place.py` regenerates the place
file after any code change.

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

## The operation (tycoon layer)

Calls are the skill game. The operation is what you build with the proceeds, and
it runs whether you are on a call or not.

**Methods** are the ladder of how the fictional operation makes money. Each step
multiplies income and multiplies the attention you draw:

| # | Method | Income | Heat | Unlocks at |
| --- | --- | --- | --- | --- |
| 1 | Cold Calling | x1.0 | 0.06/s | Intern |
| 2 | Warm Lead Sheets | x1.7 | 0.14/s | Caller |
| 3 | Dodgy Links | x2.8 | 0.26/s | Senior Caller |
| 4 | Popup Farm | x4.5 | 0.42/s | Team Leader |
| 5 | Fake Refund Portal | x7.0 | 0.62/s | Floor Manager |
| 6 | Corporate Impersonation Desk | x11.0 | 0.90/s | Operations Manager |
| 7 | The Franchise | x18.0 | 1.30/s | Call Centre Boss |

Method tiers are gated on **rank**, and rank comes only from calls — so the
active game is what unlocks the idle game rather than being replaced by it. The
method multiplier also applies to call payouts, so a bigger operation makes
every call worth more.

**Staff** earn passively, minus wages. The cheap tiers are marked *suspicious*:
they generate more heat each, and they are the first ones a raid takes.

**Premises** set the desk cap (3 → 90) and multiply income. **Security** slows
heat, speeds cooling and improves your odds in a raid. **Tradecraft** (voice
modulator, charisma training, compliance theatre…) makes whatever you are
already doing look less obviously dodgy.

### Police heat

Heat rises with the size and sophistication of the operation and falls with
security and time. Crucially it scales with *notoriety* — a player with three
interns and a phone generates almost none, so nobody gets raided in their first
twenty minutes for doing nothing much.

Three warnings fire on the way up (an unmarked car, someone photographing the
door, two people in matching coats). At 100 the door goes in:

* **Escaped** — heat drops to 25, you lose nothing.
* **Raided** — 20% of your credits, a quarter of your staff (noisy ones first),
  and the floor shuts for 60 seconds.

`Lay Low` halts income for three minutes and cools you eight times faster. The
whole server sees a police car pull up outside with your name on it.

Offline, the floor keeps working at 50% for up to 4 hours (24 with the Night
Shift pass) and heat only ever bleeds off.

The test suite asserts the shape of this: every tier above the first must be
*unsustainable bare and survivable kitted*, every ladder must climb, and no
employee may cost more in wages than they bring in.

## Leaderboards

Eight global boards, all OrderedDataStore-backed and shared across servers:

* **Top Lifetime Earnings**, **Most Successful Calls** and **Biggest
  Operations** on the back wall
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
| Night Shift Licence | Offline earnings cap goes from 4 hours to 24 |

| Developer Product | Effect |
| --- | --- |
| Coffee Refill | +40 Patience, used from the call screen |
| Supervisor Takeover | Skips the next random interruption |
| Warm Lead | Next caller rolls one tier friendlier |
| Petty Cash / Bonus Payslip | 2,500 / 15,000 Credits |
| Double Shift | 2x Credits for 30 minutes |
| Instant Payslip | Collect 2 hours of passive income now |
| Suspiciously Expensive Lawyer | Drops police heat to zero, once |

Three rules the code enforces, and the tests assert:

* **Nothing paid reveals the caller.** Reading the caller is the whole skill on
  Hard and above.
* **Bought Credits are not earnings.** They can buy desk upgrades but never
  rank, the earnings board, or the wealth achievement. Passive income from the
  tycoon layer is treated the same way, so neither Robux nor idling buys rank —
  only calls do.
* **Grants are saved before `PurchaseGranted` is returned**, and deduped on
  `PurchaseId`, so a replayed receipt never double-grants and a failed save
  never silently eats a purchase.
