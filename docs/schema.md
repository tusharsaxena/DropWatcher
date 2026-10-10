# Schema — Ka0s Drop Watcher

The SavedVariables shape, every default, and the migration path. Defaults live in
`defaults/Profile.lua` (`NS.C`); `settings/Schema.lua`'s `Settings.BuildDefaults` merges them with
every stored schema row's own default and hands the tree to AceDB.

## SavedVariables

Exactly two (savedvariables-§4):

- `DropWatcherDB` — AceDB, with profiles.
- `DropWatcherPerfDB` — LibKa0s-Perf's capture ring, outside the profile tree (performance-§5).

## `DropWatcherDB.profile`

| Key | Default | Set by | What it is |
|---|---|---|---|
| `enabled` | `true` | the Enable row, `/dw enable|disable`, the launcher | the master switch; `false` takes the latch's `disabled` hold |
| `visibility` | `"always"` | General visibility | `always`, `inCombat`, `outOfCombat` or `never` |
| `scale` | `1.0` | Master scale | the window's scale |
| `alpha` | `1.0` | Master alpha | the window's alpha |
| `locked` | `false` | Lock frame, `/dw lock|unlock`, the launcher | the window cannot be dragged or resized |
| `window.point` | absent | a drag; Reset position clears it | `{ point, relativePoint, x, y }` |
| `window.width`, `window.height` | absent | a resize; Reset position clears them | the window's size |

`situations.<key>.track`, `.autoOpen` and `.quality` are read by `modules/Situations.lua` but have
no row yet (DW-40 adds them): until one is stored, each situation takes its design spec §6.1 default
from `C.SITUATIONS`, and `quality` means the global mode.

`trade.rules.<situation>` is the owner's override of a situation's trade rule (`personal`, `group`
or `legacy`), read by `modules/TradeRules.lua` as its `ctx.rules` map; it has no row yet (DW-40 adds
Settings › Trade). An absent, unknown or default-equal value means the design spec §7.2 default
from `C.CONTENT_RULE`, and the reset empties the map.

`window.*` is geometry only a drag or a resize sets: no row addresses it, and its one owner is
`modules/Window.lua` (`savePoint`, `saveSize`, `Window.ResetPosition`), as `docs/ARCHITECTURE.md` →
Settings Schema names (architecture-§5).

## `DropWatcherDB.global`

| Key | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | the migration stamp; the runner owns it |
| `minimap.hide` | `false` | LibDBIcon's own key; the Minimap button row inverts onto it, and no `shown` twin exists (launcher-§3) |
| `minimap.minimapPos` | absent | LibDBIcon's own write |

## Session-only (never saved)

`NS.State.debug` (the logging flag), `NS.State.testMode`, `NS.State.windowOpen`,
`NS.State.situation` and `NS.State.situationInputs` (the last classified situation and the inputs it
came from; nil while stood down). The Debug console
and Test mode rows are `sessionOnly` and store through their own closures.

## Migrations

`core/Database.lua`: `NS.SCHEMA_VERSION = 1`; step 1 is the stamp itself (0 → 1, nothing to reshape).
The runner runs in `OnInitialize` before anything reads the profile, and again on every profile
event. A stored-value type change adds a step and raises `NS.SCHEMA_VERSION`; the default stays `0`.

The design's full settings (spec §12.1) are added by the settings item, each with its row, its
default here and, where a shape changes, its step.
