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
| `registration` | the declared feature events, whether they are registered, the events the client refused |
| `integrations` | the launcher's registration and button; whether Pawn and CanIMogIt are loaded |

The report reads state only: it calls no client API that changes anything, takes no hold, starts no
timer and registers no event. It reads no chat, no inventory and no other addon's data.

## Tags

`State` (test mode, combat edges), `Set` (one line per setting written at the seam, one per bulk
reset), `Profile`, `Init` (the session summary and the optional integrations, held until logging is
turned on), `Migrate`, `SIT` (one line per situation change, with the event that caused it). The
libraries add their own: `Cmd`, `Cfg`, `Launcher`, `Lifecycle`, `Perf`.
The design's other feature tags (spec §13) arrive with their modules.
