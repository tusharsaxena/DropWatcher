# Review findings: Ka0s Drop Watcher v1 (2026-10-11)

**Verdict: minor issues.** Nothing crashes, taints, leaks a secret value or loses saved data. Five
real behavior bugs sit in the two opt-in v1 features (the toast and auto-ask) and in how the
scorer picks Pawn. Two low items are cosmetic or precautionary.

**Resolved scope:** the whole addon at `87d8694` (branch `feat/2026-10-10-drop-watcher-v1`, M6 item
DW-62), with the five low findings the M5 review recorded but did not fix carried in as review
input. Reviewed against the v1 design spec (`docs/superpowers/specs/2026-10-10-drop-watcher-v1-design.md`).

## Measurement run

Every suite was run fresh on 2026-10-11 from the repo root, through
`~/.claude/dev-copilot/bin/ka0s-bounded`, at `87d8694` with a clean tree. Output went to the session
scratchpad, never into the repo.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 109 files | `ka0s-bounded luacheck .` |
| Headless test suite | **pass**: 886 passed, 0 failed, 1 skipped, 887 total | `ka0s-bounded lua tests/run.lua` (`lua` is Lua 5.1 here; `luajit` is not installed) |
| Test-case inventory | **pass**: the fresh `--list` output is byte-identical to the committed `docs/test-cases.md` once CRs are stripped | `ka0s-bounded lua tests/run.lua --list > <scratch>/list.md`, then `diff <(tr -d '\r' < docs/test-cases.md) <(tr -d '\r' < <scratch>/list.md)` |
| Offline perf runner | **ran** (not a gate): `refreshCaptureOff` 13456.1 bytes/iter, `refreshCaptureOn` 13456.1 bytes/iter and 1.00 notes/iter, `showDecisionStoodDown` 0.0 bytes/iter, `parseCaptureOff` 664.2 bytes/iter, `parseCaptureOn` 664.2 bytes/iter and 1.00 notes/iter. The zero-overhead pairs match: a dormant bracket allocates nothing extra | `ka0s-bounded lua tests/perf.lua` |
| Complexity (sighted) | **pass**: 0 warnings, max CCN 13, 3369 functions, 25529 NLOC, avg CCN 2.4. Kit revision 38 (sighted), 0 blind files in the newest bundle's manifest | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| `make test` | not applicable: there is no root `Makefile` | none |
| Vendor sync | **clean**: both diffs are empty against LibKa0s `v1.71.0`, the tag the root `CLAUDE.md` provenance line names | `git -C ../LibKa0s archive v1.71.0 LibKa0s testkit` into scratch, then `diff -r <scratch>/LibKa0s libs/LibKa0s` and `diff -r <scratch>/testkit tests/_kit` |
| Cross-addon pass | **clean** on all four classes, measured at LibKa0s `v1.71.0` (all 13 roster addons name that tag) | the four loops of the review playbook, run from `GIT/`, with `$@` derived from `WowAddonStandards/standards/ADDONS.md` (13 addons, `echo $#` = 13) |

Cross-addon detail:

- **Class 1, slash tokens.** 24 roots across 12 addons, no duplicates, and no raw `SLASH_*` line in any
  TOC-loaded file. The census regex `RegisterChatCommand\("[a-z]+"` does **not** see Drop Watcher's two
  roots, because `core/DropWatcher.lua:532-533` registers them from constants
  (`self:RegisterChatCommand(NS.SLASH:sub(2), "OnSlashCommand")`, with `NS.SLASH = "/dw"` at
  `core/Namespace.lua:19`). Checked by hand: `dw` and `dropwatcher` collide with none of the 24.
  The blind spot is in the census command, not in the addon.
- **Class 2, vendored minors.** One line for all 13 addons:
  `Bus:2 Compat:1 Core:10 DebugLog:19 Env:2 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:20 Widgets:12`.
- **Class 3, payload bytes.** Reference addon AbsorbTracker, 159 files, no `diff -rq` output for any of
  the 13.
- **Class 4, `## Interface:`.** One value: `120100`.

Committed artifacts against the fresh run:

- `docs/test-cases.md`: agrees with the fresh inventory (887 cases).
- `docs/automated-tests/RESULTS.md`: the newest row (`20261011-091808`, commit `eb7aafb`) matches the
  fresh complexity figures exactly. It is one commit behind `HEAD`, and that commit (`87d8694`) only
  added the bundle itself.
- `docs/performance.md`: no contradiction with today's scenario figures.

**Standards cross-check:** done against the local `WowAddonStandards` checkout at `c1f1cdc`, standard
**v2.78.3** (2026-10-10). Its `master` matches `origin`.

## Findings

### Medium

**F-001 [ux] The toast outlives its drop.** `modules/Toast.lua:11-12` says a toast goes "when its drop
leaves the feed", but no code does this outside test mode. A drop leaves the live feed through
`LF.Clear` (`modules/LootFeed.lua:793-797`, reached from `/dw clear` at `settings/SlashVerbs.lua:40-44`
and from `feed.clearOnBossKill` at `modules/LootFeed.lua:882-886`) or through the cap's trim
(`modules/LootFeed.lua:579`, `while #feed.drops > LF.MAX_DROPS do removeOldest(feed) end`). None of
these tells the toast. Dismissing a row (`core/DropWatcher.lua:316-319`) cancels the drop's auto-ask
but not its toast. The toast stays on screen until its countdown ends, or for good while the pointer
rests on it. Its Ask (`modules/Toast.lua:319-324`) then calls `NS.PressAsk` for a drop that is gone
or that the player has just dismissed: the first prints "Not asked: That drop is gone.", the second
whispers for a drop the player explicitly hid.
*Impact:* a stale toast whose button refuses, or asks for something the player dismissed.
*Reachability:* any player who has turned the toast on (it is off by default) and then types
`/dw clear`, has `feed.clearOnBossKill` on during a pull, dismisses the toasted row, or passes 200
drops in a session while a toast is up.

**F-002 [logic] An empty-slot upgrade never toasts or auto-asks.** The kernel reports an empty
baseline as `upgrade` with the `emptySlot` reason and **no** `ilvlDelta`
(`modules/Evaluate.lua:401-404`, and `tests/test_evaluate.lua` asserts `assertNil(res.ilvlDelta)`).
`Toast.Qualifies` treats a missing gain as failing the threshold
(`modules/Toast.lua:61`: `if not gain or gain < (num(minGain) or 0) then return false, "gain" end`),
and auto-ask reuses that test (`modules/AutoAsk.lua`, `blocker`). So the clearest upgrade there is, an
item for a slot you have nothing in, is the one case both features skip. This contradicts spec §11.5
and §9.4, which fire on "an upgrade for me", and §5.2, under which an empty slot is an upgrade. The
case was pinned as intended behavior: `tests/test_toast.lua`'s qualifier table expects
`{ drop({ me = { verdict = "upgrade" } }), "gain" }`.
*Impact:* no toast and no auto-ask for the drops that matter most.
*Reachability:* a player with the toast or auto-ask on and an empty equippable slot (a leveling or
fresh character, an empty off hand, or an unfilled ring or trinket slot), when a drop for that slot
falls to someone else.

**F-003 [logic] `Scoring.InUse` picks the Pawn adapter when Pawn is merely loaded.** Spec §5.4 says
the Pawn adapter is "present only when `PawnIsInitialized` is true". `modules/Scoring.lua:217` reads
`local loaded = NS.Compat.PawnIsReady() or NS.Compat.PawnIsLoaded()`, so a loaded but uninitialized
Pawn wins `auto` over the player's own weights. Every score then answers `pending`, the feed spends
its five retries (`LF.SCORE_TRIES`), and the verdict falls back to item level alone. If Pawn never
finishes initializing (an error in Pawn, an out-of-date Pawn), the weights the player entered are
ignored for the whole session, while the diagnostics report (`modules/Diagnostics.lua:283-293`) and
the detail card's score line (`modules/DetailCard.lua:326`) name Pawn as the scorer in use.
*Impact:* the player's weights are silently unused, and the reported scorer is wrong.
*Reachability:* any player with Pawn installed and `comparison.scorer = auto` (the default), for
every drop judged before Pawn initializes; for the whole session when Pawn fails to initialize.

**F-004 [ux] Turning the toast off leaves the toast up.** The `toast.enabled` row has no reaction
(`settings/SchemaRows.lua:317-318`). Unticking it stops new toasts (`Toast.Consider` and `Toast.Pump`
read the setting), but the toast on screen stays and the queue keeps its drops. A test-mode toast
never times out (`modules/Toast.lua:261`, `if not rec.test then startTimer(...)`), so it stays until
its close mark is clicked or test mode ends. A profile switch to a profile with the toast off does
the same, because no row reaction runs on a switch.
*Impact:* a toast on screen after the player has turned toasts off.
*Reachability:* a player with the toast on who unticks **Show a toast** or switches to a profile with
it off while a toast is showing. That is most likely in test mode, where the toast is being placed.

**F-005 [logic] Auto-ask can be held for the rest of the session.** `inEncounter` is set by
`ENCOUNTER_START` and cleared only by `ENCOUNTER_END` or the stand-down
(`modules/AutoAsk.lua:262-271`, `:331-335`). If the client never sends the matching
`ENCOUNTER_END` to this player (a hearth, a teleport or a release out of the instance mid-fight),
every waiting auto-ask stays held, and every later one is scheduled but never armed, until the next
`ENCOUNTER_END` or a `/reload`. It is **unverified** whether the client sends `ENCOUNTER_END` to a
player who leaves mid-encounter. The fix is cheap and harmless either way.
*Impact:* auto-ask silently stops working until a later boss or a reload.
*Reachability:* a player with auto-ask on (off by default) who leaves an instance during a boss
encounter.

### Low

**F-006 [taint] The two confirmations take the first free StaticPopup slot.** Neither the Clear
history popup (`modules/WindowHistory.lua:361-366`) nor the Reset all settings popup
(`settings/Schema.lua:313-320`) sets `preferredIndex = 3`. This is the collection's usual guard against
sharing a dialog slot with Blizzard's secure popups (LootHistory sets it on all three of its popups,
`../LootHistory/settings/Slash.lua:17`). It is not a standard rule.
*Reachability:* a player confirming either action while another addon or a Blizzard dialog holds
StaticPopup1. This is a precaution with no observed failure.

**F-007 [design] The toast's degraded close is a typed glyph.** When LibKa0s is missing,
`NS.MakeCloseButton` returns nil and the toast draws its own text button with the glyph `×`
(`modules/Toast.lua:164-166`). `core/CoreSetup.lua` says the chrome should degrade to nothing. This
fallback is deliberate: without it a test-mode toast, which never times out, could not be closed.
*Reachability:* only an install missing LibKa0s (DEGRADED-1). This is cosmetic.

## Upstream findings

None. Nothing under `libs/` or `tests/_kit/` was found defective, and the vendor diffs are empty. The
cross-addon census blind spot noted under Class 1 belongs to the review playbook's command, not to
any library, and it hides no collision today.

## Looked at, not findings

- `core/Compat.lua` is 1107 lines, in layout-§1's 1000–1500 band, while spec §4 asks for a split past
  about 1000. The watch list already carries a ruling for it: `docs/automated-tests/RESULTS.md:96`
  says "accepted (DW-61) — compat-§1 makes this the only file allowed to call version-variant client
  APIs", and gives a re-check trigger. It is not re-filed here.
- The send paths (`modules/Asks.lua`), the trade helper's guards (`modules/TradeHelper.lua`), the
  `NotifyInspect` hook's self-guard (`modules/Inspect.lua:564-565`), the window's show ladder
  (`modules/Window.lua:620-656`) and the stand-down of every module touched above were read. They
  match the spec, and nothing in them is reachable while disabled.

## Coverage notes

- F-001, F-004 and F-005 sit on paths with no case in the inventory: there is no clear, trim or
  dismiss case in `tests/test_toast.lua`, no case that turns `toast.enabled` off, and no
  zone-change case in `tests/test_auto_ask.lua`. This is a gap, not a sleeping case.
- F-002 is the "test pins the bug" form: a case asserted the wrong behavior.
- F-003 is pinned the same way: `tests/test_scoring.lua` asserts `"auto prefers a loaded Pawn"`.
