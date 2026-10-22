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
| `clear` | feature | no | `SlashVerbs.Clear`: empties the live feed (`NS.LootFeed.Clear("live")`, which stores the clear with `Session.MarkCleared` so a `/reload` does not bring the cleared drops back) and repaints; the test feed and the history stay |
| `history` / `mine` | feature | no | `SlashVerbs.OpenTab`: opens the window, expands it when minimized and selects the tab; `mine` selects Drops, where your own drops are listed since the My drops tab was retired (feedback-5 spec §3) |
| `compact` | feature | no | `SlashVerbs.Compact`: `NS.ToggleWindowMode` (the `window.mode` row through the seam, the title-bar toggle's handler), then prints the layout, `Compact view.` or `Full view.` (compact spec §1) |
| `full` | feature | no | `SlashVerbs.Full`: `NS.SetWindowMode("full")`, then prints `Full view.` |
| `situation` | feature | no | `SlashVerbs.Situation`: three lines, the situation with its Track, Auto-open and Quality, then the classifier's inputs, read live |
| `offer <link>` | feature | no | `SlashVerbs.Offer`: your newest live drop of that item, or the bag item added as your drop (`NS.LootFeed.Add`); then the Drops tab and `NS.OfferPanel.Open` |
| `add <link> [player]` | feature | no | `SlashVerbs.Add`: `NS.LootFeed.Add(link, player)`, you when no player is named; prints the drop's id, that it is loading, or why the feed refused it |
| `sim [verb]` | feature | no | `NS.Sim:RunVerb` (simulator spec §4; DW-03): LibKa0s-Sim-1.0's grammar, `sim` alone (the status, the usage and the library's step panel), `status` (the library's status line, then `SimVerbs.StatusLine`), `start <key\|dungeon\|raid\|lfr\|delve\|world> [size]` (`NS.Sim:Start`, refused per the simulator's safety rules), `run` / `step` / `pause` / `resume` / `restart` / `stop`, `panel` (the library's panel); plus DropWatcher's five verbs from `NS.SimVerbs.VERBS`: `pull` / `kill` (`NS.SimEvents.Pull` / `Kill`), `loot [n] [player\|me]` (`NS.SimReport.Loot`), `lockdown on\|off` (`NS.SimHost.SetLockdown`), `trade <dropID>` (`NS.SimEvents.Trade`); anything else prints the usage (no `help` verb) |

While disabled, a verb that is not live prints the one refusal line, `Ka0s Drop Watcher is disabled —
enable it with /dw enable`, and does nothing else. The gate reads the stored `enabled`, not the
latch, so a perf capture never refuses a verb.

A verb or a button that gets past the gate and then finds the latch down refuses through
`NS.StoodDownRefusal()` (`core/LifecycleSetup.lua`), the one line for every stood-down refusal: `scan`
and Scan group, `test`, `sim start`, Post my tradeables, Retry inspect, Ask, Offer, Announce to group
and Trade. With the `disabled` hold taken it is the refusal line above; with the `perf` hold alone it
is `Not available during a performance capture.`, since `/dw enable` would change nothing. The line is
printed alone, never inside `Not asked: …`; `NS.PressAsk`, `PressOffer` and `PressAnnounce` return
the reason `disabled` or `perf` (`NS.StoodDownReason()`).

The Show window key binding (launcher-§6, `Bindings.xml`) refuses as `/dw toggle` does. A key press
never passes through the dispatcher, so its button (`DropWatcherToggleWindow`,
`core/LauncherSetup.lua`) asks `NS.StoodDownRefusal()` itself and prints that one line, chosen by
hold, before it would call `NS.ToggleWindow`; standing up, it calls the toggle verb's handler.

The feature verbs are spec §12.3's (and compact spec §1's `full`). `scan`, `compact` and `full` call the host handlers their window
controls call; the slash-only ones live in `settings/SlashVerbs.lua` (`NS.SlashVerbs`), loaded just before
`settings/Slash.lua`. A verb that takes an item link reads it with the pure `SlashVerbs.SplitLink`:
the link runs to its closing `|h` (and `|r` when colored), so an item name's spaces stay in it and
what follows is the player. A verb with no link prints its usage line. `offer` refuses an item that
is in neither the feed nor your bags, and an item still loading asks to run it again in a moment.

`sim` is the simulator's (simulator spec §4). Its row hands the argument to `NS.Sim:RunVerb`, so
LibKa0s-Sim-1.0 reads it: the generic grammar first, then the host verbs `settings/SimVerbs.lua`
fills into the descriptor (`NS.SimVerbs.VERBS`, `WHY`, `USAGE`, `StatusLine`; DW-03), else the usage.
Every verb but the bare form, `status`, `start` and `panel` says `No simulation is running: start one
with /dw sim start <scenario>.` when none runs (DropWatcher's words for the library's line, through
the descriptor's `L`), each refusal the simulator answers (a boss already engaged, no such drop, the
timeline finished, the pool still loading) prints its own line, and a refused start prints only its
refusal. The launcher menu has no simulator entry and there is no simulator key binding (OWNER_SCOPE C.11):
the slash verbs and the step panel are its interface, and every click on the panel runs one of these
verbs through `NS.Sim:RunVerb`, so a click prints what the typed verb prints.

With the library absent, the stub in `settings/Slash.lua` dispatches the same table, keeps the
same live list, and the schema CLI verbs say the library is missing.
