# Testing — Ka0s Drop Watcher

## The green commit gate

Both MUST pass before every commit (testing-§4):

```sh
lua tests/run.lua      # the headless suite, Lua 5.1
luacheck .             # 0 warnings / 0 errors
```

No authored `.lua` file may pass 1500 lines (layout-§1); the kit's `test_layout_cap` reads the
census in [`ARCHITECTURE.md`](ARCHITECTURE.md). Toolchain: [`DEPENDENCIES.md`](../DEPENDENCIES.md).
The suite needs a sibling `../LibKa0s` checkout for the vendor gate's two payload cases (they SKIP
without it).

## The harness

`tests/run.lua` on the vendored LibKa0s kit (`tests/_kit/`, revision 38, never edited).
`tests/loader.lua` builds a fresh, isolated addon per case from the TOC's own file list and the
library files `libs/LibKa0s/LibKa0s.xml` names; `tests/wow_mock.lua` extends the kit's base mock with
what this addon reads (combat state, the client's addon list, the chat sink, the launcher's two
libraries, the main window's whole frame tree (each region its own object, with its points, size,
text, text color, texture and check state recorded, and its backdrop, edit-box font and insets, checked texture and hit insets), and the client APIs `core/Compat.lua` wraps: the tooltip
data, the chat sender and lockdown, the restriction state, `C_Item`'s upgrade, bind and GUID
answers, the trade actions, the enums it resolves by name and the enUS GlobalStrings it parses),
and a mocked clock: `advance(seconds)` runs the kit's timer queue in due order, and
`C_Timer.NewTicker` is a repeating ticker on the same queue (its handle carries `ticker`).
Suites that need a secret value use `T.secret(v)` and install the kit's `issecretvalue` on the
mock (`m.issecretvalue = function(v) return T.isSecret(v) end`).

Suites reach the harness as `local T = _G.DW_TEST` and build instances with the three factories,
each taking an `opts` table (`skip`, `mock`, `inCombat`) and returning `(NS, env, mock)`:

- `T.newAddon(opts)` — every file loaded.
- `T.bootAddon(opts)` — plus `OnInitialize` (the database, the migrations, the chat commands).
- `T.enableAddon(opts)` — plus `OnEnable` (events, settings category, launcher, the latch).

`opts.skip = T.loadAddon.libFiles` loads the addon with the whole LibKa0s payload absent, which is how
every degradation stub is tested: by a real load, never by a hand-written stub (testing-§8).

Named suites the standard requires: `test_surface_parity` (testing-§8), `test_vendor_sync`
(testing-§11, delegating to the kit), `test_disabled` (slash-commands-§7). The addon's own:
`test_harness` (the load and the repository's shape), `test_setup` (each adopted module's wiring),
`test_database` (the defaults tree and the migration runner: the stamp, a raising step, step 2
reaching a stored profile that is not the active one, step 3 folding the View and its checkboxes
into the View set), `test_schema`, `test_schema_rows` (every
spec §12.1 setting has a row whose default is `defaults/Profile.lua`'s and passes its own check,
the refused values, the per-spec maps, the readers that go through `NS.Setting`, the M3 handoffs
through the seam, the account-wide history cap, the CLI and the degraded load), `test_settings_pages` (the settings
pages built headless: the page list and each page's strip, a page's rows by its key, When to show's
blocks and dimmed rows, the Feed page's "in force now" readout, the Comparison page's per-spec
weights and unwanted types written whole through the seam, the Messages page's live counters,
preview, token chips and Reset templates, each page's Defaults, and the editors' pure halves),
`test_slash`, `test_window`, `test_window_shell` (the window's
chrome built headless: the title bar, the restriction badge, Scan group, the tabs and their lazy
panes, the filter bar's per-tab state and its Loot History flat skin, the multi-select View (its values, label, grayed values and bullet tooltip), the footer's composer, minimize, auto-open on every drop, a tooltip on
every control, the build without the Widgets library, and the pure row predicates),
`test_window_group` (the Group drops table: every cell's text, glyph, tone and reason tooltip for
each verdict, trade, inspect and ask state, My eq and Their eq's worn levels, the column sets and the entry order, then the table
built headless: pooled rows, collapsing headers, the item button's tooltip, link and dressing room,
the item tooltip beside the window (right, else left at the UI scale, top-aligned with the row, the
docked Offer panel's own edge, and the fallback on unknown geometry),
the Ask button and its repaint, the dismiss mark, the compact preset, the filters, the empty
state and its two buttons, and the filters' empty line), `test_detail_card` (the detail card: the header's chips, both comparisons, the trade box and
the actions with their reasons, state by state, then the card built headless: the row click that
expands it inline and moves the rows below, one row at a time, a reason on every line, each action
through its host handler, and the Edit message box), `test_window_mine` (the My drops tab and the
Offer panel: the countdown, exact and estimated, `ending soon`, For me's `keep?`, the candidates
ranked with their pills, Best candidates hidden for your upgrade, the buttons' lifecycles, the
summary, Post my tradeables' lines and the dock, then the tab and the panel built headless: pooled
rows, a reason on every cell, the countdown moved by `TradeTimerTick`, Hide, Announce, the row's
and the panel's Offer, Trade and Post my tradeables through their host handlers), `test_test_mode`
(test mode's samples: every Me and Them verdict, trade estimate, inspect state, ask state, countdown
and candidate pill covered by the data, over pool items that keep their slot and level, the worn
items the nearest of their slot, an empty pool giving none; the History sample with every outcome;
`AddTest` and the test feed filled from the mock journal's pool (`seedGearJournal`) and emptied
with test mode, while the pool loads, with no pool at all, by combat and by the stand-down; the
History tab's samples never written to `global.history`; the window built headless with every
sample drawn with a real icon, a reason on every cell, the TEST MODE text and banner, the My drops
count; no button label or My drops cell ending in an ellipsis; Ask and Post my tradeables printed,
never sent), `test_compat` (the compat seam: the
secret guards on both load paths, the localized duration decoder in three client languages, the
tooltip line reader, the trade window's items and partner, the row menu, and each shim's fallback
with its API absent), `test_text_parse` (the pure text parsers of `core/TextParse.lua`, the
localized strings passed in, and that the module reads no global), `test_constants` and
`test_class_data`
(the game-data tables and their lookups), `test_evaluate` (the verdict kernel, table-driven over
every slot plan and every equippability path, plus nil and garbage inputs), `test_scoring` (the
scorers: the Pawn scale import, the weights score and its unknown keys, the adapter in use for each
setting, the Pawn adapter's scales and `pending`, and the sidegrade item level and score reach
through the kernel and the feed), `test_quality_gate`
(the minimum-quality gate: each mode, the floor, empty slots, ties, both overrides),
`test_situations` (the situation classifier's truth table for every key, the per-situation settings
and their spec defaults, the six re-evaluation events and the stand-down), `test_trade_rules` (the
trade estimator: every row of the Estimate table in order, the trade window, the rule per situation
and the owner's override map), `test_messaging` (the messaging core: token expansion, the length
limit, the one-ask guard, queueing under restriction, the flush order, cancel and a failed send's
retry), `test_restrictions` (the restriction tracker: each restriction type's reason and what it
blocks, the priority order, the chat lockdown, the combat edges ahead of the client's flag, the
event's numeric, boolean and secret payloads, `RestrictionChanged` and the stand-down), `test_roster` (the roster: solo, party and raid
tokens, the realm normalization, resolving by GUID, Name-Realm and bare name, the same-name tie
settled by classFile and by the player's realm, the re-read on a miss, the shared
`GROUP_ROSTER_UPDATE`, secret unit answers and the stand-down), `test_item_facts` (the item facts: every field of a
cached item, the track tier by string id and by name, the tooltip track, uniqueness, tier tokens and
class gear, the link-color quality, the facts feeding the verdict kernel, the cache and its cap, the
appearance event, the load with its retries, the give-up, a client that cannot load, and the
stand-down), `test_item_read` (BUG-1 and BUG-2 of the M8 feedback, DW-80: the reproduction with
realistic 12.x links per loot source and each hypothesis proved or refuted, the merge keeping the most
complete link (loading and hidden drops included), `core/ItemRead.lua`'s link detail, better link,
identity, effective level, location reads and quality, the bag match by identity, an own drop read
from its bag item, the `drops` diagnostics line, and the real game tooltip: bag slot, worn slot,
link, and the addon's line after the game's), `test_gear` (the gear snapshot: each worn slot at its current level, empty and loading
slots, the candidate's class, spec and hand flags, the per-slot qualities, the owned best per slot
with pairs, dual wield, held off hands and Titan's Grip, tier tokens and secret links left out, the
candidate judged by the verdict kernel with and without the bags, the throttled rebuild and
`GearChanged`, a bag event in combat deferred to its end, a bag-only rebuild keeping the worn slots,
bag items with no slot plan never asked of the item facts, the spec event, the quiet first read, an item still loading, and the stand-down),
`test_loot_parser` (the loot parser: every `LOOT_ITEM*` variant, self and third person, single and
multiple, bonus roll and pushed; same-realm, cross-realm, hyperlinked, colored and unknown looters;
the upgrade and crafting echoes rejected; non-receipt lines and non-item links ignored; secret text,
a secret GUID and secret, empty or absent globals; globals rewritten at runtime and rebuilt; a deDE
client and positional arguments; the event's sinks, counters and twelfth argument; and the
stand-down), `test_inspect` (the inspect broker on the mock's clock, `advance(seconds)`: one inspect
in flight, the 2s spacing, the priority order and a raised job, the ready timeout and its one retry,
the range and identity waits, `CanInspect` false and an offline member, incomplete and nameless
links retried and kept, the tooltip level, the fast path and its hidden-slot guard, a read with no
data (cleared before the read, or a moved unit token) re-queued, failed or dropped and never stored
as `fresh`, a foreign inspect before and after the
data arrived, anyone's `INSPECT_READY` read, the combat park, the open inspect window, the TTL, the
invalidation and its echo guard, the roster prune, the warm-up and `Scan`, the candidate judged by
the verdict kernel, `InspectDone` after the items load, one debug line per job, secrets, and the
stand-down), `test_feed` (the feed: a member's drop judged for you, its looter's inspect asked for
and their verdict and trade arriving with `DropUpdated`; the trade re-made over time, a group drop
past its window turning `no expired` on the sweep, your own drop taking the timer's `yes` and then
`no expired`, a timer moving it off `no` asking for its candidates, a BoE drop keeping its bind; the dedupe across chat, the encounter loot
event and the loot history in either order, by GUID or by name, a GUID learned from a later source,
two copies and another looter's copy kept apart, the window's end; the loot history taken once with
a winner; the grouping by trash, a kill's loot window, a wipe, an earlier encounter's late loot, a
keystone run with its chest, the open world; the gate order, the situation hiding a drop before its
item loads and the quality gate before any inspect, the upgrade override, the stored quality
settings and a situation's mode; the pure filters row by row and the relative item level; an item
still loading and one that never loads; your own drop with its trade by your verdict and every
member a candidate, no inspects for an untradeable one, pushed items; `GearChanged`; the score
retry and its limit; `Add`, the test feed and `Clear`; the cap; secret payloads; and the
stand-down), `test_feed_counts` (feedback-2 spec §0: the owner's two-Yoke chat lines through the
real parser and feed, the accented cross-realm looter, both Yokes kept apart, the reagent and the
altar hidden by the gear-only rule and the reagent by the quality rule with it off, the currency
and money lines never read as loot; every hidden and refused receipt counted by reason, logged
under FEED and reported in the `drops` diagnostics section; the group headers' `2 drops · 1 shown`
and the tooltip naming each hidden drop and its filter, on Group drops and History),
`test_group_roster` (feedback-2 spec §3: the roster snapshot's pure core, `Entry`, `Merge` (it
only grows, you first, never the same character twice), `Copy`, `Names` (five names then `+n`,
class-colored) and `TipLines`; a feed group taking the party with its first drop and a mid-run
joiner on the roster event or with the next drop, its History group keeping it; the Group drops
and History headers, and an older History group naming nobody; test mode's sample rosters are
`test_test_mode`'s and a simulated run's `test_sim_e2e`'s),
`test_trade_timer` (your own drops' trade timer: the `TradeTimeRemaining` line read
by its type and keyed by item GUID, a line of another type ignored, the localized sentence decoded
from deDE-shaped globals without the line type, no line read as `no expired`; the match by exact
link then item id, one item per drop, a stranger's item, a member's drop and a test drop untimed,
a moved item kept and a removed one dropped; the three scan triggers sharing one throttled scan;
the ticker slow while the window is hidden, fast while it is shown and off with nothing live, one
ticker for every item; the warning once per item at the threshold with its message and chat line,
at once below it, off at 0; secret links, GUIDs and lines; and the stand-down keeping the warned
flags), `test_trade_helper` (the trade helper: your drop's bag item picked up by GUID and dropped on
the member named by GUID, name or Name-Realm; a moved item found by a walk of the bags, the hinted
slot first, a secret GUID refused; not in the bags, expired, a busy cursor left alone, no drop API
putting the pickup back; `CanGive` touching nothing; combat refused before the range is read; a
stranger, yourself, an offline member and one out of range; the stand-down; every reason's tooltip
line; `Open` and its missing API; the diagnostics line), `test_asks` (the messaging edge: a
whisper to the looter's Name-Realm with the template expanded from the drop's tokens and one
confirmation line; an empty slot's gain read as `an empty-slot upgrade`, never the item level, its `+` dropped; the one-ask guard and `messages.oneAsk`; an edited text over 255 bytes; a
stranger, yourself, an offline member and a missing or secret target refused; an offer to a
candidate; a raising sender failed with its message and retried, a secret error, no sender, the
deprecated global fallback; the announce channel; queueing under a restriction and the flush on
the lift, `ENCOUNTER_END` and `CHALLENGE_MODE_COMPLETED`, one send every 1.5 seconds first in first
out, stopped by a lockdown mid-flush; cancel by a second press and when the looter leaves, and a
queued announce once out of a group; test mode printing instead of sending; the stand-down),
`test_transmog` (the transmog-known flag: CanIMogIt answering first when loaded, its no-appearance
answer, a raise or a non-boolean falling back to `C_TransmogCollection`, and the source named; the
item facts reading through it; the ask template picked for a drop (the plain ask for a gain, the For
transmog ask only with `messages.transmogAsk` on and the look known missing); its default text and a
request that names it; the detail card's `New look` and `Look known` chips; the Ask button and the
card's actions offering it; the edge sending its text under the ask's key; its settings rows and
preview sample; the test mode placeholders; the diagnostics lines),
`test_history` (the history: the shape made in place with the cap kept, the snapshot kept small,
the group and drop caps, outcomes moving forward only, an expired trade, declined set and cleared
by hand, the trade match by partner then item id and your own drops traded away; then the edge on
the bus: a live drop recorded and a test drop never, `DropUpdated`, a sent ask, offer or announce;
a completed trade marking `received` and the Ask button `Traded`, one given away, and an
unfinished or changed trade marking nothing; the cap row trimming at once; Clear history behind its
confirmation; the diagnostics line; and the History tab built headless: kept groups newest first,
the outcome column, a reason on every cell, a header toggle, Content's This session, the row menu
with and without the client's menu, the empty line and `HistoryChanged`'s repaint),
`test_toast` (the toast: the pure qualifier, someone else's upgrade for you of `toast.minGain` or
more (or into an empty slot, whatever the least gain) with a `likely` or `yes` trade, and every
reason it refuses, and the board 06 C texts, `empty` for an empty slot; then
the edge: off by default, a qualifying drop shown and painted and gone after its duration, one at a
time with each drop once, the queue's cap, a drop that turns likely on its `DropUpdated`, the hover
pause and its resume, combat holding it and `toast.inCombat`, a drop asked for or gone skipped, the
Ask button through the host handler, the sound, the drag only in test mode with the point saved and
Reset position, test mode's placeholder toast, a drop leaving the feed (a clear, the cap's trim) or
dismissed taking its toast and its place in the queue, an Ask on a gone drop, turning the toast off
or switching to a profile with it off, the stand-down and the diagnostics line),
`test_auto_ask` (auto-ask: the pure `DueAt` and the delay's clamp; then the edge: off by default, a
qualifying drop whispered after the delay once with the ask template, the delay and least gain
read from the rows, an upgrade into an empty slot asked for whatever the least gain, a sidegrade,
your own drop or an unknown trade left alone and a later `likely`
scheduled, held through an encounter and due after its end, a loading screen or a new zone ending
a hold with no Encounter restriction left (and keeping it while one is, until its lifting after the
world event; a lifting with no world event keeping it), an encounter ending after
the drop pushing it back, each cancel rule (your own ask, the looter leaving, the row dismissed, the item
received, a drop gone or no longer qualifying when due, turning it off, the stand-down), only drops
from after it was turned on, the one-time notice, test mode printing instead of sending and the
diagnostics lines),
`test_sim_core` (the simulator's core: the seam wraps every Compat member that answers for the
client and no pure one, a provider answers only while a simulation runs and a live read skips it,
the guarded sender prints `[sim]` and never reaches the client (an ask through the real messaging
edge included), no real inspect or trade, each refusal and the line it prints, test mode refused
while one runs, an event delivered to the handlers its registration calls, the simulated Encounter
restriction and lockdown, its timers, the session-only history log with saved history untouched,
a real drop or trade arriving while one runs kept real and saved, a raising handler or stop step
isolated so the driver and the rest of the cleanup go on,
a stop that takes its drops, groups, inspect entries and restrictions and leaves a real drop, a
queued ask canceled before the lift so it never goes out, the situation re-read, the automatic stop
on joining a group or entering an instance, and the stand-down),
`test_sim_pool` (the simulator's item pool and group: the four journal shims and their absent
answers, each situation's side and difficulty, a read of every instance of the newest tier at every
difficulty with the player's selection restored, even when a read raises, no read while the
journal's frame is shown, the wait for `EJ_LOOT_DATA_RECIEVED` and its timeout keeping what loaded,
the class filter, the own-items fallback reported once, the stop ending a waiting build; the seeded
random source, a party of four and a raid of nine to nineteen with distinct names and GUIDs and
each spec its class's, the gear drawn inside the band from what the class can wear with the rest
left empty and the off hand empty behind a two-hander, and the group kept on the session and
forgotten by the stop),
`test_sim_events` (the simulator's event drivers and its world: every `LOOT_ITEM*` shape written
from its GlobalString and read back by the parser, a reordering locale written in its own order, a
burst's size, your own lines and its looter from another realm; the roster, the situation and the
announce channel reading the invented party or raid while a live read sees the real world, and the
stop putting it back; a member's line, bare or Name-Realm, reaching the feed under their GUID with
saved history untouched; an inspect read through the broker's queue after the reply, never the
fast path, giving the looter's verdict, a failing member timing out and one out of range giving up,
the reply delay replayed by its seed; a pull's combat edge and Encounter restriction with the ask
queued and flushed (printed) after the kill, loot after a kill grouped under the boss, a wipe not
counted, a keystone run's group and ChallengeMode restriction; your own drops in your bags with
their trade windows (the ending-soon one closing) and the scenario's window; a simulated trade
settling `tradedAway` and `received` in the session's log with no real trade, and its refusals; and
the stop ending the combat edge and the bag items),
`test_sim_scenario` (the simulator's scenarios, timeline and controls: the pure verb parser and
timeline; `/dw sim` through the real dispatcher with its status, usage and refusals, refused while
disabled, in combat and with test mode on; a scenario's pool, group, situation and window, a raid
sized by its argument; the timeline waiting for the pool, a step at a time, a run a few seconds per
step to its end, the stop and the stand-down ending a playing run; the SIMULATION text, the footer's
`Simulating` line, the `sim` diagnostics section and the `SIM` debug lines; and the end-to-end
scenarios (spec §7): a `key` and a `raid` run headless, asserting drops parsed from the written
lines, your verdict and the looter's after the simulated inspect, the ask held in the lockdown and
flushed, auto-ask firing after its delay, your own drop's countdown, a simulated trade in the
session's log, saved history untouched and the real chat sender, inspect and trade never called),
`test_sim_e2e` (the sim feedback regression, DW-90: a scan failing any module that names a world
global the simulator answers, the seam wrapping every world read, the combat flags and the
GlobalStrings; every scenario run in the real solo, out-of-instance world, at the content's level and
outgearing it, with drops in the feed, your verdict and the looter's, a chat line per step, the
footer's `Simulating` and `Inspect n/n`, and rows in Group drops and My drops under the default
filters; the combat flags during and after the simulated fight, the loot lines written from the
GlobalStrings Compat reads, `raid1` as you and online in a raid, and Raid Finder's instance chat),
`test_sim_panel` (the simulation step panel, DW-91: the rows, their PerfPanel states and commands
before and during a run, the controls following the timeline, `/dw sim`, `start` and `panel`
opening or toggling it beside the window, a click on the next step running it and one ahead running
every step in between, a completed step inert with its tooltip naming when it ran, a typed step,
stop or automatic stop repainting it, Run all, Pause and Resume, Restart and Stop, typed or clicked,
the picker starting the chosen scenario with a raid's count, and the dragged position remembered,
forgotten by Reset position and the panel hidden at stand-down),
`test_diagnostics`. Kit suites,
declared by directory: `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`,
`test_lizard_sighted`.

Write tests first for pure logic. Extend `tests/wow_mock.lua` for a new client API, never
`tests/_kit/`.

`lua tests/run.lua --list` prints the case inventory; it is committed as
[`test-cases.md`](test-cases.md), and its Total is the README's `[tests]` badge. Regenerate both in
the change that moves the count (testing-§5).

## The four suites, and which checkpoint each gates

| Suite | Command | Commit / run | Release (the tag) |
|---|---|---|---|
| `lint` | `luacheck .` | **gates** | gates |
| `tests` | `lua tests/run.lua` | **gates** | gates |
| `perf` | `lua tests/perf.lua` (offline scenarios; see [`performance.md`](performance.md)) | recorded, never fails a run or blocks a commit | gates |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (the sighted shadow) | recorded, never fails a run or blocks a commit | gates, with zero functions above CCN 15 and `blindFiles` 0 |

The release gate is evaluated by `/dev-copilot:bump-version` from the run's `manifest.json`
(automated-tests-§3). The record itself: [`automated-tests/README.md`](automated-tests/README.md).
For long batteries run through the bounded runner, `~/.claude/dev-copilot/bin/ka0s-bounded`.

## In game

[`smoke-tests.md`](smoke-tests.md) — the checks the headless suite cannot make. They are the owner's
to run; an agent never marks one passed.
