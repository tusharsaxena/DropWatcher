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
| `settings` | every setting that differs from its default, and `enabled` always |
| `window` | built, shown and the show decision; the player's choice, test mode, visibility, lock; the stored point and size |
| `situation` | the situation classified now and the last one announced, its track, auto-open and quality settings, and the classifier inputs read live |
| `restrictions` | the four answers now (reason, can send chat, can inspect, can trade), every reason in effect (the Map type included) and the answers last announced |
| `roster` | the group as last read (stored state, so the report never triggers a read): the member count, then per member the Name-Realm, unit token, classFile, online state, specID and whether it is the player |
| `gear` | your gear snapshot as last read (stored state, so the report never triggers a read): your class, spec, hand flags and the items still loading, then per slot the worn item level and quality (or `empty`, `loading`) and the best owned level when it is not the worn item |
| `feed` | what the loot parser has read since login (stored state): the lines turned into loot (`hits`), ignored, rejected (upgrade and crafting echoes) and secret, and the last loot seen with its age, kind and looter. The feed (DW-27) adds its drop counts here |
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
item given up after its loads, and the item facts cache emptied at its cap), `GEAR` (one line per
change of your gear snapshot, with your spec, the items still loading and the cause), `PARSE` (the
loot patterns built, with how many globals were usable; one line per loot line read, with the kind,
the link, the quantity, the looter and its GUID; one per line skipped as rejected, secret or not an
item; and a sink that raised). The
libraries add their own: `Cmd`, `Cfg`, `Launcher`, `Lifecycle`, `Perf`.
The design's other feature tags (spec §13) arrive with their modules.
