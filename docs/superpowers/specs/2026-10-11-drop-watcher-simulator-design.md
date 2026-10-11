# Ka0s Drop Watcher: the simulator (M7 addendum)

- **Extends:** `2026-10-10-drop-watcher-v1-design.md` (the v1 spec). Section numbers below that start with `v1 §` point there.
- **Owner request, 2026-10-11:** a test mode that simulates the game, not a UI preview, so the addon can be tested
  anywhere, solo and outside an instance, during ongoing development. Live dungeon and raid testing still happens;
  this is for everything in between.
- **Items:** DW-70..DW-74, milestone M7, on branch `feat/2026-10-10-drop-watcher-v1`.

## 1. Goal and the one principle

`/dw sim` runs a made-up group session through the **real engine**. The simulator invents the world's inputs (who is in
the group, what they wear, what dropped, which situation this is, when a boss is pulled and killed, when chat is locked
down, how long an item stays tradeable) and feeds them in at the **edges**. Every module between the edges runs exactly
as it does live: the loot parser, the feed and its de-duplication and grouping, the situation and quality gates, item
facts, the verdict kernel and scoring, the trade estimator, the inspect broker's cache and freshness rules, the
messaging queue and flush, auto-ask, the toast, trade timers, history and the whole window.

**The principle:** the simulator never calls a kernel directly to set a result, and never writes a verdict, trade state
or inspect state into a record. If a simulated drop shows a verdict, the verdict kernel computed it. A test-mode
placeholder (`v1 §11.6`) is the opposite and stays as it is: the two modes are separate and exclusive.

## 2. Where the simulator plugs in

The simulator is a provider of **client answers**, consulted by the seams that already exist:

| Edge | Live source | Simulated source |
|---|---|---|
| Group membership | `GetNumGroupMembers`, unit tokens, `UnitGUID`, `UnitClass` (Roster via Compat) | A sim roster of 4 (party) or 9–19 (raid) members with invented names, realms, GUIDs, classes and specs |
| Another player's gear | `NotifyInspect` → `INSPECT_READY` → inventory reads (Inspect broker via Compat) | The sim member's gear table, answered after a short, randomized inspect delay, so the broker's queue, throttle and freshness logic run; a member can be marked out of range or failing |
| Situation | `GetInstanceInfo`, difficulty, `C_ChallengeMode` (Situations) | The scenario's situation: `mythicPlus`, `dungeon`, `raid`, `raidLFR`, `delve`, `openWorldGroup` |
| Loot | `CHAT_MSG_LOOT` (+ `ENCOUNTER_LOOT_RECEIVED` / `C_LootHistory` dedupe sources) | Lines written from the client's own `LOOT_ITEM*` GlobalStrings, delivered to the feed's real loot handler with a sender and GUID |
| Encounters | `ENCOUNTER_START`, `ENCOUNTER_END`, `CHALLENGE_MODE_START/COMPLETED` | Sim pulls and kills with an invented encounter id and name |
| Restrictions and combat | `ADDON_RESTRICTION_STATE_CHANGED`, `InChatMessagingLockdown`, combat edges | A sim Encounter / ChallengeMode restriction while a sim boss is engaged, and sim combat edges |
| Own-item trade time | Tooltip trade-time line (`TradeTimeRemaining`) | A sim trade window per own sim drop (default 2h, configurable per scenario, one "ending soon" drop) |
| Chat sends | `ChatSender` | Printed locally, prefixed `[sim]`, with the channel and target; never sent |
| Trade with a player | `InitiateTrade`, trade window events | `/dw sim trade <id>` raises a simulated completed trade for a drop, so History outcomes `received` and `tradedAway` can be exercised; the Offer panel's Give prints what it would do |

The seam is one table, `NS.Sim`, that Compat (and only Compat, for client answers) consults first while a simulation
is running: `if NS.Sim.active then return NS.Sim.Answer(...) end`. Event-driven inputs (loot lines, encounters,
restriction changes, inspect-ready) are delivered by calling the same handlers the event registration calls, with the
same payload shapes. Compat stays the only file that calls the client (compat-§1); the simulator calls no client API of
its own except the item-pool reads in §3, which go through new Compat shims.

## 3. Items: real items from the Encounter Journal

Simulated drops and simulated gear use **real items**, so item facts, the tooltip readers and the comparisons work
for real, and the item pool never goes stale between seasons:

- The pool is read from the **Encounter Journal**: the current season's dungeons (for `dungeon` and `mythicPlus`) or
  the current raid tier (for `raid` / `raidLFR`), at the scenario's difficulty, so links carry the right item level.
  Shims: the `EJ_*` / `C_EncounterJournal` loot readers, through Compat. The journal's selection is saved and restored,
  and the pool is not read while the Encounter Journal frame is shown. Loot that arrives asynchronously
  (`EJ_LOOT_DATA_RECIEVED`, sic) is awaited with a timeout.
- Optional class filter: `loot for me` (the journal's class/spec filter set to yours) or `any`.
- **Fallback** when the journal yields nothing (an API change, a flavor without the data): your own equipped and bag
  items, so a sim always has something to drop. The fallback is reported once.
- **Sim members' gear** is drawn from the same pool, slot by slot, at an item level band the scenario sets around yours
  (default: your average −10 to +5). A slot the pool cannot fill stays empty, which also exercises empty-slot upgrades.

## 4. Scenarios and control

| Command | What it does |
|---|---|
| `/dw sim` | Prints status and usage |
| `/dw sim start <key\|dungeon\|raid\|lfr\|delve\|world> [size]` | Builds the pool and roster, sets the situation, opens the window; refuses per §5 |
| `/dw sim run` | Plays the scenario's timeline automatically (pull → combat and lockdown → kill → loot burst → lockdown lifts), a few seconds per step; a key plays several bosses and then the completion |
| `/dw sim step` | Advances the timeline one event |
| `/dw sim pull`, `/dw sim kill` | One encounter start or end |
| `/dw sim loot [n] [player\|me]` | n loot lines now (default 1–3, random looters, with occasional multiples, bonus rolls and a cross-realm looter) |
| `/dw sim lockdown on\|off` | The chat restriction, independent of a pull |
| `/dw sim trade <dropID>` | A simulated completed trade for that drop |
| `/dw sim stop` | Ends the simulation (§5) |

The launcher menu gains no entry; the slash verbs are the interface. `sim` is a feature verb: it is refused while the
addon is disabled. `docs/slash-dispatch.md` gets the rows.

## 5. Safety

- **Refuses to start** while in a real group, in an instance, in combat, or while test mode is on (it says which).
- **Stops by itself** when the player joins a real group, enters an instance, the addon stands down, or on `/reload`
  and logout (it is session-only; nothing about it is saved).
- **Never sends anything.** Every whisper, party, raid and instance message is printed with `[sim]`. This is enforced
  inside the send seam, not by the callers.
- **Never touches saved history.** Simulated drops are history entries in a session-only sim log shown in the History
  tab while the sim runs, and dropped on stop. `DB.global.history` is not written.
- **Never inspects a real player** and never initiates a real trade.
- **Stop cleans up everything:** sim roster, inspect cache entries for sim GUIDs, sim drops and groups in the feed,
  sim trade timers, queued sim asks, the sim restriction, the sim situation (the classifier re-reads the real one).
- Everything the simulator invented carries `sim = true`, so a stray one is identifiable in diagnostics.

## 6. UI, diagnostics, debug

- The title bar shows a `SIM` chip (like the test chip, its own color) with the scenario as its tooltip; the footer's
  situation reads `Simulating: <situation> · n members`.
- A `sim` diagnostics section: active, scenario, member count, pool size and source (journal or fallback), timeline
  position, sends printed.
- A `SIM` debug tag logs every injected event.

## 7. Tests

- The simulator's pure parts (roster and gear generation, loot-line writing, the timeline) get their own suites.
- **Scenarios as fixtures:** a headless end-to-end suite runs a `key` and a `raid` scenario through the mock and asserts
  outcomes the real engine produced: drops parsed from the written lines, verdicts present for you and the looter after
  the simulated inspect, the ask queued during the lockdown and flushed after the kill, auto-ask firing after its
  delay when enabled, own-drop countdowns, a simulated trade landing in the sim history log, nothing written to
  `DB.global.history`, and no call to the real chat sender.
- `test_disabled` stays green: the simulator's events and timers tear down on stand-down.

## 8. Smoke checks (owed, never marked passed by an agent)

A new `SIM` theme in `docs/smoke-tests.md`: start/stop and the refusals; a full `key` run; a `raid` run with a large
roster; the lockdown queue and flush; a simulated trade into History; the journal fallback; the auto-stop on joining a
real group.

## 9. Out of scope

Simulating a real trade window, a real inspect of a real player, or an actual message being sent. Those stay in the
owner's live test.
