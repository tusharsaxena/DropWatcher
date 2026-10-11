# Debug — Ka0s Drop Watcher

The console is LibKa0s-DebugLog's, built from the descriptor in `core/DebugLogSetup.lua`. The
logging flag is `NS.State.debug`: session-only, default off, never saved, independent of the window.

## Commands

| Command | What it does |
|---|---|
| `/dw debug` | open or close the console window; logging is untouched |
| `/dw debug on` / `off` | turn logging on or off for this session |
| `/dw diagnostics` | write the diagnostics report to the console |
| `/dw debug diagnostics` | the same report; `diagnostics` is tested first |

No other name runs the report: there is no `diag`, `dump` or other alias.

## The diagnostics report (debug-logging-§14)

Both forms run the same report, also reachable from the console's orange **Diagnostics** link. It
runs while the addon is disabled, **turns debug logging on for the session** before it writes when
it is off, **appends** after whatever the console already holds and never clears it, and stays under
the library's cap (a `truncated` line says when it was reached). The library writes the markers, the
identity header (client build, locale, the debug flag, both combat reads, the running LibKa0s minors,
the `[Init]` line) and wraps each section in its own `pcall`.

The addon's sections (`modules/Diagnostics.lua`), in order:

| Section | What it reports |
|---|---|
| `identity` | schema stored and in code, the profile, `enabled`, whether stood down, the latch's holds |
| `state` | design spec §13's State line: `enabled`, the situation classified now, test mode, the restriction in force and the asks queued (`state: enabled=… situation=… testMode=… restriction=… queuedSends=…`) |
| `settings` | every setting that differs from its default, and `enabled` always |
| `window` | built, shown and the show decision; the player's choice, test mode, visibility, lock; the stored point and size; the active tab, whether it is minimized and its `n new` count |
| `situation` | the situation classified now and the last one announced, its track, auto-open and quality settings, and the classifier inputs read live |
| `restrictions` | the four answers now (reason, can send chat, can inspect, can trade), every reason in effect (the Map type included) and the answers last announced |
| `roster` | the group as last read (stored state, so the report never triggers a read): the member count, then per member the Name-Realm, unit token, classFile, online state, specID and whether it is the player |
| `inspect` | the inspect broker (stored state): the queue's length, the GUID in flight, whether it is parked and the spacing left, then per member asked about the status, reason, spec, slots read, age and whether it is stale |
| `gear` | your gear snapshot as last read (stored state, so the report never triggers a read): your class, spec, hand flags and the items still loading, then per slot the worn item level and quality (or `empty`, `loading`) and the best owned level when it is not the worn item |
| `feed` | what the loot parser has read since login (stored state): the lines turned into loot (`hits`), ignored, rejected (upgrade and crafting echoes) and secret, and the last loot seen with its age, kind and looter; then the feed's drops (Group drops and My drops, the test feed, the groups, the reports merged, the drops still loading), the drops hidden by reason, the encounter and keystone run in progress, and the quality mode in force here with its threshold (one per slot, compact, for the per-slot mode) |
| `trade` | the trade helper's counts once it has been used (`trade helper: gives=… opens=… refused=… last=<reason>`), then the trade timer (stored state): the live and expired entries, the scans so far and the ticker's period (`off` with nothing live), then per entry the drop id, the item, the seconds left, whether it has expired or warned, and the item GUID |
| `scoring` | the scorer chosen (`comparison.scorer`) and the adapter actually in use (`inUse=pawn`, `weights` or `none`: `pawn` without Pawn loaded is none, `auto` falls back to your weights, then none), whether Pawn is ready and your Pawn scale (from the stored gear snapshot's class and spec), then the score retries: drops still retrying a pending score, drops that used up their tries, and whether the shared retry timer is armed |
| `messaging` | the one-ask registry by state (asks, queued, sent, failed, ready), the sends, failures, refusals and flushes and whether a flush is running, each template's length, `oneAsk` and the announce channel, then one line per queued ask |
| `registration` | the declared feature events (each once), whether they are registered, the events the client refused |
| `integrations` | the launcher's registration and button; whether Pawn and CanIMogIt are loaded |

The report reads state only: it calls no client API that changes anything, takes no hold, starts no
timer and registers no event. It reads no chat, no inventory and no other addon's data.

## Tags

`State` (test mode, combat edges), `Set` (one line per setting written at the seam, one per bulk
reset), `Profile`, `Init` (the session summary and the optional integrations, held until logging is
turned on), `Migrate`, `SIT` (one line per situation change, with the event that caused it), `RES` (one line per change
of what the restrictions allow, with the event that caused it), `ROSTER` (one line per change of the
group's members, tokens, names or online states, with the member count and the cause), `ITEM` (an
item given up after its loads, and the least recently used quarter of the item facts cache dropped at its cap), `GEAR` (one line per
change of your gear snapshot, with your spec, the items still loading and the cause), `PARSE` (the
loot patterns built, with how many globals were usable; one line per loot line read, with the kind,
the link, the quantity, the looter and its GUID; one per line skipped as rejected, secret or not an
item; and a sink that raised), `INSPECT` (one line per inspect job when it ends, with the member, the
status and its reason, the spec and the slots read, and one per scan with how many were queued),
`FEED` (one line per drop added, with its looter, source, group, both verdicts and the trade
state; one per report merged into a drop; one per drop hidden by the situation or a filter, with
the reason; one when a feed is cleared), `SCORE` (one line per drop whose scorer answered "not ready", with the tries it gets, and one per
score retry pass, with the drops re-scored and whether any is still pending; once per key, a Pawn
import key or a stored weight's stat key the scorer does not score, which counts 0), `QUAL` (one line per drop the quality gate hides, with
its quality, the threshold, the mode and the reason), `EVAL` (one line per re-judging pass after an
inspect or a gear change, with the number of drops), `TRADE` (one line per trade-timer scan while
you have own drops, with the cause, the own drops and the live timers; one per warning, with the
drop, the item and the seconds left; one per trade-helper give or open, with the bag slot and the
unit, and one per refusal, with its reason), `MSG` (one line per ask, offer or announce sent, queued
with the restriction that held it, failed with its reason, refused with its reason, or canceled by a
click or because its looter left; one per flush started, with its trigger and the queue length; one
when the stand-down drops queued asks), `UI` (one line per tab selected, per filter changed on a
tab, per minimize and expand, per auto-open with its situation, and per Group drops header
collapsed or expanded, per row dismissed, and per detail card expanded or collapsed and per Retry
inspect with the broker's answer; per My drops row hidden, per Offer panel opened with its drop,
and per Post my tradeables with the lines posted); `Set` also logs `window.compact` when the compact
preset is stored outside the seam. The
libraries add their own: `Cmd`, `Cfg`, `Launcher`, `Lifecycle`, `Perf`.
Every feature tag of design spec §13 is in use (`PARSE`, `FEED`, `EVAL`, `INSPECT`, `TRADE`, `MSG`,
`SIT`, `QUAL`, `UI`, `SCORE`); `RES`, `ROSTER`, `ITEM` and `GEAR` are this build's additions for the
edges the spec's module map added.
