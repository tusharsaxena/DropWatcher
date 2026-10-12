# Schema — Ka0s Drop Watcher

The SavedVariables shape, every default, and the migration path. Defaults live in
`defaults/Profile.lua` (`NS.C`); `settings/Schema.lua`'s `Settings.BuildDefaults` merges them with
every stored schema row's own default and hands the tree to AceDB.

## SavedVariables

Exactly two (savedvariables-§4):

- `DropWatcherDB` — AceDB, with profiles.
- `DropWatcherPerfDB` — LibKa0s-Perf's capture ring, outside the profile tree (performance-§5).

## `DropWatcherDB.profile`

Every setting has a row in `settings/SchemaRows.lua` (or, for the Master controls, the composed
rows of `settings/Panel.lua`) and its default in `defaults/Profile.lua`. A row's `validate` refuses
a value outside its list or range, so `/dw set` and the panel store only what the readers expect.
Every module reads a setting through `NS.Setting(path)`.

### General

| Key | Default | Tab | What it is |
|---|---|---|---|
| `enabled` | `true` | Master controls; `/dw enable|disable`, the launcher | the master switch; `false` takes the latch's `disabled` hold |
| `visibility` | `"always"` | Master controls | `always`, `inCombat`, `outOfCombat` or `never` |
| `scale`, `alpha` | `1.0`, `1.0` | Master controls | the window's scale and alpha |
| `locked` | `false` | Master controls; `/dw lock|unlock`, the launcher | the window cannot be dragged or resized |
| `autoOpen` | `true` | When to show | master auto-open: `false` keeps every situation from opening the window |
| `situations.<key>.track` | per design spec §6.1 | When to show | loot is watched in that situation |
| `situations.<key>.autoOpen` | per design spec §6.1 | When to show | every drop added to the feed there opens a hidden window (since DW-83; it was the first interesting drop, once per situation) |
| `situations.<key>.quality` | `"global"` | When to show | `global` (the feed's mode), `fixed`, `dynamicSlot` or `dynamicCharacter` |
| `sim.stepDelay` | `2` | Simulation | the seconds the simulator's automatic run (`/dw sim run`, the panel's Run all) waits between steps, 0.5 to 10 in steps of 0.5 (feedback-2 spec §8, DW-A7); read as each next step is set, so a change takes effect from the next step |

`<key>` is each of `mythicPlus`, `dungeon`, `followerDungeon`, `raidLFR`, `raid`, `delve`,
`scenario`, `pvp`, `openWorldGroup` and `solo`; `track` and `autoOpen` default on for Mythic+,
dungeons and raids, `track` alone for Raid Finder, and off elsewhere.

### Feed

| Key | Default | Tab | What it is |
|---|---|---|---|
| `feed.quality.mode` | `"fixed"` | Quality; the filter bar's Quality control (`NS.SetQualityMode`) | the minimum-quality mode new drops are gated with |
| `feed.quality.fixed` | `3` (Rare) | Quality | the fixed mode's threshold, Uncommon to Legendary |
| `feed.quality.floor` | `2` (Uncommon) | Quality | the dynamic modes' least threshold, Common to Epic |
| `feed.quality.upgradeOverride` | `true` | Quality | an upgrade for you shows below the threshold |
| `feed.view.interesting`, `feed.view.likely`, `feed.view.usable`, `feed.view.upgrade` | `false` each | Filters | the View a fresh filter bar tab opens on, a set (DW-A1, feedback-2 spec §1): each row on adds its value (Interesting; Likely tradeable, the trade estimate yes or likely; Usable by me, not can't use or doesn't want; Upgrade for me), the values combine as AND, and all off is All, the default |
| `feed.content`, `feed.sort` | `"instance"`, `"newest"` | Filters | a fresh filter bar tab's Content and Sort |
| `feed.gearOnly`, `feed.includeTokens` | `true`, `true` | Filters | armor, weapons, jewelry and trinkets only; tier tokens too |
| `feed.minIlvlMode` | `"off"` | Filters | `off`, `absolute` (`feed.minIlvl`, 0 to 1000, default 0) or `relative` (`feed.relativeIlvl` under your average, 0 to 100, default 10) |
| `feed.showOwn` | `false` | Filters | your own loot in Group drops too (your own drops auto-open the window and count toward `n new` either way since DW-83) |
| `feed.clearOnBossKill` | `false` | Filters | empty the live feed at each boss kill (LootFeed, at the kill's `ENCOUNTER_END`) |

### Comparison

| Key | Default | Tab | What it is |
|---|---|---|---|
| `comparison.scorer` | `"auto"` | Scoring | `auto`, `pawn`, `weights` or `none`; the adapter in use (`modules/Scoring.lua`) can differ, see the Known Limitations |
| `comparison.sidegradeBand` | `0` | Scoring | item levels either side of equal that read as a sidegrade, 0 to 20 |
| `comparison.compareOwned` | `false` | Scoring | judge against the best of worn and carried |
| `comparison.heirloomProtect` | `true` | Scoring | a slot holding an heirloom is not called an upgrade for you (LootFeed → Evaluate's `heirloomProtect`) |
| `comparison.weights` | `{}` | Weights (`map`) | `{ [specID] = { STAT_KEY = weight } }`, the Weights adapter's scores; the Pawn scale import writes one spec's |
| `comparison.undesired` | `{}` | Preferences (`map`) | `{ [specID] = { ["<classID>:<subClassID>"] = true } }`, the item types a spec never wants |

The two `map` rows are whole values: a write replaces the whole table through the seam, and the
row refuses a key that is not a specID, a weight that is not a number, or a type key not shaped
`<classID>:<subClassID>`. The CLI lists them as their entry count and does not set them.

### Trade

| Key | Default | Tab | What it is |
|---|---|---|---|
| `trade.rules.<situation>` | per design spec §7.2 (`personal`; `legacy` for follower dungeons and PvP) | Rules | the rule (`personal`, `group` or `legacy`) that decides whether a drop there can be traded |
| `trade.warnAt` | `600` | Timers | seconds left when your own item's trade timer warns, 0 to 1800; 0 is off |

### Messages

| Key | Default | Tab | What it is |
|---|---|---|---|
| `messages.templates.<kind>` | design spec §9.1's text | Templates | the `ask`, `transmog`, `offer` and `announce` templates; an empty one is refused. `transmog` is the ask's wording for a drop that is no gain for you but whose look you have not collected (DW-53) |
| `messages.transmogAsk` | `false` | Sending | also offer an ask, with the `transmog` template, on a drop that is no gain for you but whose look you have not collected (DW-53) |
| `messages.editFirst` | `false` | Sending | open the Edit message box before an ask, offer or announce (the host handlers) |
| `messages.oneAsk` | `true` | Sending | each (drop, target, kind) is sent once |
| `messages.announceChannel` | `"auto"` | Sending | `auto`, `INSTANCE_CHAT`, `RAID` or `PARTY`; never say or yell |
| `messages.autoAsk.enabled` | `false` | Auto-ask | ask on your behalf (`modules/AutoAsk.lua`, read at each drop and when an ask is due); its reaction says the one-time notice when it turns on and cancels the waiting asks when it turns off |
| `messages.autoAsk.delay` | `10` | Auto-ask | seconds after the boss kill or the drop, 3 to 30 |
| `messages.autoAsk.minGain` | `5` | Auto-ask | the least item-level gain for you, 1 to 50 |

### Window and toast

| Key | Default | Tab | What it is |
|---|---|---|---|
| `window.columns.<col>` | `true` | Columns | `false` hides that Group drops column (`ilvl`, `slot`, `looter`, `myEq` (since DW-83), `theirEq`, `me`, `them`, `trade`, `actions`); Item never hides |
| `window.compact` | `false` | Layout; `NS.SetCompact`, `/dw compact` (DW-42) | the compact preset: Item and looter, Ilvl, Their eq, Me, Ask |
| `window.rowHeight`, `window.fontSize` | `18`, `0` | Layout | the drop tables' row height (18 to 40) and text size on all three tabs (`modules/WindowRows.lua`, at each repaint; feedback-2 spec §8, FB2-9): `fontSize` 0 is Default, the template's own size like Ka0s Loot History's table (the CLI shows `0 (Default)`), else 8 to 20; a My drops row is the row height plus 10 for its countdown bar. Since DW-A8 (was `24`, `12`, Group drops only); a value the player stored stays as it is |
| `toast.enabled`, `toast.inCombat`, `toast.sound` | `false` | Toast | the upgrade toast (`modules/Toast.lua`, read at each drop and each toast); turning `toast.enabled` off takes the toast on screen down and empties its queue (the row's reaction) |
| `toast.minGain`, `toast.duration` | `10`, `8` | Toast | its least gain for you and its seconds on screen |

### Named state (no row)

| Key | Default | Set by | What it is |
|---|---|---|---|
| `window.point` | absent | a drag; Reset position clears it | `{ point, relativePoint, x, y }` |
| `window.width`, `window.height` | absent | a resize; Reset position clears them | the window's size |
| `window.minimized` | absent | the minimize button, a double-click on the title bar | the window collapsed to its title bar |
| `toast.point` | absent | a drag of the toast in test mode; Reset position clears it | `{ point, relativePoint, x, y }` |
| `simPanel.point` | absent | a drag of the simulation panel; Reset position clears it | `{ point, relativePoint, x, y }`; until set, the panel opens beside the window |

Their one owner is `modules/Window.lua` (`savePoint`, `saveSize`, `Window.SetMinimized`,
`Window.ResetPosition`), as `docs/ARCHITECTURE.md` → Settings Schema names (architecture-§5).
The toast's position (design spec §11.5) is named state too: `toast.point` (`{ point, relativePoint, x, y }`, absent until a drag), written by `modules/Toast.lua` alone, from a drag that only test mode allows; the Window's Reset position forgets it with the window's.
The simulation panel's position (sim feedback spec §1, DW-91) is named state as well: `simPanel.point`, written by `modules/SimPanel.lua` alone (its drag stop and `SimPanel.ResetPosition`), absent until a drag; the Window's Reset position forgets it with the window's.

## `DropWatcherDB.global`

| Key | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | the migration stamp; the runner owns it |
| `minimap.hide` | `false` | LibDBIcon's own key; the Minimap button row inverts onto it, and no `shown` twin exists (launcher-§3) |
| `minimap.minimapPos` | absent | LibDBIcon's own write |
| `history.retentionDays` | `30` | Keep history for (feedback-2 spec §5): 7, 14, 30, 60, 90 or 180 days, or `0`, Never delete; the `global.history.retentionDays` row (Window › Layout) stores here through its own closures. A change to a window that would delete anything asks first (`NS.HistoryRetention.OnChanged`); the groups older than it go once per session, five seconds after the first `PLAYER_ENTERING_WORLD`. Account-wide: a profile switch, copy or reset never changes it. It replaced `history.maxGroups` (the 20-group cap), which step 4 removes |
| `history.v` | absent until the first drop is recorded | the history's own shape stamp, `1` (`NS.History.VERSION`); `NS.History.Normalize` sets it and makes `groups` a list, in place |
| `history.groups` | absent until the first drop is recorded | the kept drops, below; written by `modules/History.lua` alone, never through the seam |
| `notices.autoAsk` | absent until auto-ask is first turned on | `true` once auto-ask's one-time chat notice was said (design spec §9.4); written by `modules/AutoAsk.lua` alone, never through the seam |

### The history (design spec §10)

`modules/History.lua` owns `history.v` and `history.groups` and never replaces `global.history`
whole, because the retention row lives in the same table; `modules/HistoryRetention.lua` deletes the
groups older than it. It is account-wide: every character adds to one
log and sees it.

```lua
history = { retentionDays = 30, v = 1, groups = {
    { key, label, kind, situation, at, instance, difficulty, seenBy, seenByClass,
      roster = { { name, realm, class, me }, ... }, drops = {
        { itemLink, itemID, looter, class, isMine, ilvl, equipLoc, quality, seenBy, seenByClass,
          me = { verdict, ilvlDelta, scoreDelta }, them = { ... } | nil,
          trade = { state, reasonKey, basis, args }, outcome, before, at } } } } }
```

- A group is one feed group of one session: its `key` is the feed group's key and the session's
  start (`enc:<id>:<t>@<time()>`), its `label` the encounter, run or area name, `kind` `encounter`,
  `run` or `area`, `situation` the situation key and `at` its first drop's time.
- `at` is `time()` (seconds since the epoch), so it reads the same after a reload; `looter` is the
  Name-Realm and `class` its classFile; `me`, `them` and `trade` are the verdicts and the trade
  estimate as last judged while the drop was in the feed, plain fields only.
- `roster` is who was in the group (feedback-2 spec §3, `modules/GroupRoster.lua`): each a short
  `name`, the normalized `realm` only when it is not the recorder's, the `class` (classFile) and
  `me` on the recorder's own entry, the recorder first. Every recorded drop merges the feed group's
  snapshot in, and a mid-run joiner is added; it only grows. A group kept before DW-A3 has none and
  its tooltip has no `Group:` line; since DW-B4 the header itself never names the party. No migration
  step: the field is optional.
- `instance` and `difficulty` say where the group dropped (feedback-3 spec §4, `modules/GroupPlace.lua`):
  the instance's name and the client's difficulty name (`Timewalking`, `Heroic`, `Mythic+ 12` for a
  key), captured when the feed group opened, nil outside an instance. `seenBy` and `seenByClass` on
  the group are the character that saw its first drop, the one name its header shows. A group kept
  before DW-B4 has none of the four: its header reads `Label · Situation`, and its recorder is its
  first entry's. No migration step: the fields are optional.
- `seenBy` is the character that saw the drop, its Name-Realm, and `seenByClass` that character's
  classFile (feedback-2 spec §4, `modules/CharFilter.lua`): the feed stamps every drop record with
  them and the entry copies them. The History tab's Character dropdown (Current by default) filters
  by `seenBy`. An entry kept before DW-A4 has neither: it is "unknown", which only `Character: All`
  shows. No migration step: the fields are optional.
- `outcome` is `seen`, `asked`, `offered`, `received`, `tradedAway`, `expired` or `declined`;
  `before` is the outcome a hand-set `declined` replaced.
- How long it is kept: a group goes whole once its newest entry's `at` is older than
  `history.retentionDays` days (never under `0`), at the session's prune or a confirmed shorter
  window. Beside that, 50 drops per group and a safety ceiling of 5,000 drops in all
  (`NS.History.CEILING`, a constant the diagnostics report), the oldest going first, keep
  SavedVariables bounded even under Never delete. The history's shape has its own stamp, `v`.

## Session-only (never saved)

`NS.State.debug` (the logging flag), `NS.State.testMode`, `NS.State.windowOpen`,
`NS.State.windowFilters` (the filter bar's state per tab, `{ view = { [value] = true },
char = { [Name-Realm] = true }, content, search, sort }`, seeded from the `feed.view.<value>`,
`feed.content` and `feed.sort` rows when they hold a valid value; `char` starts on Current, your
key, or the `current` sentinel until your key is known),
`NS.State.windowGroup` (the Group drops table's collapsed groups, dismissed rows and the row whose detail card is open),
`NS.State.windowMine` (the My drops tab's hidden rows and the upgrades whose candidates you chose to see),
`NS.State.offerPanel` (the drop the Offer panel shows),
`NS.State.windowHistory` (the History tab's collapsed groups, and whether this session already put
View: All and Content: All on it),
`NS.State.situation` and `NS.State.situationInputs` (the last classified situation and the inputs it
came from; nil while stood down). The Debug console
and Test mode rows are `sessionOnly` and store through their own closures.

## Migrations

`core/Database.lua`: `NS.MIGRATIONS` is a list of steps `{ to, run, perProfile }`, and
`NS.SCHEMA_VERSION` is the highest step's `to` (today 4). The runner runs in `OnInitialize` straight
after `AceDB:New`, before anything reads the profile, and again on every profile event. It owns the
stamp: a step's `to` is stored only after the step returned, so a step that raises is retried on the
next load. A `perProfile` step runs for every stored profile in the raw SavedVariables, not only the
active one. The default stays `0`.

| Step | What it does |
|---|---|
| 1 | 0 → 1: the stamp itself; nothing to reshape |
| 2 | 1 → 2, per profile: every setting has a row (DW-40). A stored value its row now refuses (the wrong type, or outside its list or range) is dropped, so the default shows: before the rows, `feed.quality.mode` and `window.compact` were written straight onto the profile, and `trade.rules.*`, `messages.*` and `situations.*` were read with forgiving fallbacks. A valid value and every default pass through unchanged (`NS.RepairStoredSettings`) |
| 3 | 2 → 3, per profile: the View becomes a set (DW-A1, feedback-2 spec §1). A stored `feed.view` string becomes `feed.view = { [value] = true }` (`interesting` keeps Interesting, `all` is the empty set), and the retired `trade.likelyOnly`, `feed.usableOnly` and `feed.upgradeOnly` fold into it as `likely`, `usable` and `upgrade` when they were on, their leaves removed, so each player keeps the choices they had. A profile that only inherited the old default (`interesting`) stored nothing, since AceDB strips a value equal to its default at logout, and opens on the new default, All. A profile already in the new shape passes through (`NS.MigrateViewSet`) |
| 4 | 3 → 4, global: the History is kept by days (DW-A5, feedback-2 spec §5). The retired group cap, `global.history.maxGroups`, is removed; nothing is pruned by the step, and Keep history for starts on its default, 30 days, which the session's prune applies (`NS.RetireHistoryCap`) |

A stored-value type change adds a step and raises `NS.SCHEMA_VERSION`.
