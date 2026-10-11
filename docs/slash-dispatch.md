# Slash dispatch — Ka0s Drop Watcher

`/dw` (alias `/dropwatcher`), registered through AceConsole in `OnInitialize`. The dispatcher is
LibKa0s-Slash's; `NS.COMMANDS` in `settings/Slash.lua` is passed in as ordered positional triples.
The bare command opens the settings panel.

| Verb | Kind | Live while disabled | Handler |
|---|---|---|---|
| `help` | reserved | yes | the library's index |
| `config` | reserved | yes | `DW:OpenSettings` |
| `enable` / `disable` | reserved | yes | `runEnabled`, writing `enabled` through the seam |
| `version` | reserved | yes | the library |
| `list` / `get` / `set` / `reset` / `resetall` | reserved | yes | the library over the schema seam; `reset` takes a path, `resetall` asks first |
| `profile` | reserved | yes (added to the live list) | the library's profile verb |
| `debug` | reserved | yes | `DebugVerb` (diagnostics first, then on/off), else the console toggle |
| `diagnostics` | reserved | yes | `NS.DebugLog:RunDiagnostics` |
| `perf` | reserved | yes | `NS.Perf.OnCommand`, lines printed by the addon |
| `lock` / `unlock` | window | no | `NS.SetLocked` |
| `show` / `hide` / `toggle` | window | no | `NS.ShowWindow` / `NS.HideWindow` / `NS.ToggleWindow` |
| `test` | window | no | `NS.ToggleTestMode` |
| `scan` | feature | no | `NS.ScanGroup`, the window's Scan group button |
| `clear` | feature | no | `SlashVerbs.Clear`: empties the live feed (`NS.LootFeed.Clear("live")`) and repaints; the test feed and the history stay |
| `history` / `mine` | feature | no | `SlashVerbs.OpenTab`: opens the window, expands it when minimized and selects the tab |
| `compact` | feature | no | `SlashVerbs.Compact`: `NS.ToggleCompact` (the `window.compact` row through the seam), then prints the new state |
| `situation` | feature | no | `SlashVerbs.Situation`: three lines, the situation with its Track, Auto-open and Quality, then the classifier's inputs, read live |
| `offer <link>` | feature | no | `SlashVerbs.Offer`: your newest live drop of that item, or the bag item added as your drop (`NS.LootFeed.Add`); then the My drops tab and `NS.OfferPanel.Open` |
| `add <link> [player]` | feature | no | `SlashVerbs.Add`: `NS.LootFeed.Add(link, player)`, you when no player is named; prints the drop's id, that it is loading, or why the feed refused it |

While disabled, a verb that is not live prints the one refusal line, `Ka0s Drop Watcher is disabled —
enable it with /dw enable`, and does nothing else. The gate reads the stored `enabled`, not the
latch, so a perf capture never refuses a verb.

The feature verbs are spec §12.3's. `scan` and `compact` call the host handlers their window controls
call; the slash-only ones live in `settings/SlashVerbs.lua` (`NS.SlashVerbs`), loaded just before
`settings/Slash.lua`. A verb that takes an item link reads it with the pure `SlashVerbs.SplitLink`:
the link runs to its closing `|h` (and `|r` when colored), so an item name's spaces stay in it and
what follows is the player. A verb with no link prints its usage line. `offer` refuses an item that
is in neither the feed nor your bags, and an item still loading asks to run it again in a moment.

With the library absent, the stub in `settings/Slash.lua` dispatches the same table, keeps the
same live list, and the schema CLI verbs say the library is missing.
