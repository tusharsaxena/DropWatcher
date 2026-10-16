# Schema — Ka0s Drop Watcher

The SavedVariables shape, every default, and the migration path. Defaults live in
`defaults/Profile.lua` (`NS.C`); `settings/Schema.lua`'s `Settings.BuildDefaults` merges them with
every stored schema row's own default and hands the tree to AceDB.

## The write seam

One write, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher and
the host verbs alike, and one read, `NS.Setting(path)` (the stored value, or the row's default
before the database exists). The rows are `settings/Schema.lua`'s `Settings.Schema` array: the
composed Master controls rows (`settings/Panel.lua`), then every hand-written row of design spec
§12.1 (`settings/SchemaRows.lua`), page by page as the tables below list them: General's When to
show and Simulation, Feed, Comparison, Trade, Messages, Window, and the account-wide Keep history
for (`global.history.retentionDays`, feedback-2 spec §5, DW-A5; it replaced the group cap).

- Each row's `group` is its tab on its page (design spec §12.2); a page draws the rows whose `page`
  is its key (`Settings.RowsForPage`). The tree is [`settings-panel.md`](settings-panel.md).
- A row with nothing to do carries a `disabledIf` predicate that dims it on the panel; its `default`
  references `defaults/Profile.lua`; its `validate` refuses a value outside its list or range
  before the seam stores it.
- `comparison.weights` and `comparison.undesired` are whole-value `map` rows keyed by specID
  (architecture-§5's value route: a membership change is a whole write through the seam), drawn by
  their own editors (`skipRender`); the CLI shows them as their entry count. The
  `situations.<key>.*` rows are `skipRender` too (since DW-H0): When to show's table draws them, a
  line per situation, and writes through the seam.
- The reactions every surface shares are `Settings.REACTIONS` (Master controls) and the window
  repaint on the Columns, Layout and Quality rows. Paths `enabled` and `locked` are declared
  `writeThrough`, so the host verbs still land on a load where the composers are hollow
  (options-ui-§1 route (a)).
- The global closure rows are the Minimap button (`global.minimap.shown`, onto LibDBIcon's `hide`)
  and Keep history for (onto `global.history.retentionDays`, whose change to a shorter window asks
  before it deletes anything, `modules/HistoryRetention.lua`; until the player answers, its
  onChange writes the agreed window back, so an unanswered confirmation never leaves an
  unconfirmed window stored).
- Every other setting the window and the feed read is a row: the window's layout (`window.mode`,
  through `NS.SetWindowMode` and `NS.ToggleWindowMode`: the Window page's Layout row, the title-bar
  toggle, `/dw compact` and `/dw full`) and the filter bar's Quality control (`NS.SetQualityMode`,
  the Feed page's row) both write through the seam.

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
dungeons and raids, `track` alone for Raid Finder, and off elsewhere. The three
`situations.<key>.*` rows are `skipRender` with no subsection (since DW-H0, feedback-8 spec §0):
When to show's table draws them, one line per situation (`settings/PageEditors.lua`
`SituationTable`, docs/settings-panel.md), and writes through the seam, so the CLI, the Defaults
button and profiles reach them as any row.

### Feed

| Key | Default | Tab | What it is |
|---|---|---|---|
| `feed.quality.mode` | `"fixed"` | Quality; the filter bar's Quality control (`NS.SetQualityMode`) | the minimum-quality mode new drops are gated with |
| `feed.quality.fixed` | `3` (Rare) | Quality | the fixed mode's threshold, Uncommon to Legendary |
| `feed.quality.floor` | `2` (Uncommon) | Quality | the dynamic modes' least threshold, Common to Epic |
| `feed.quality.upgradeOverride` | `true` | Quality | an upgrade for you shows below the threshold |
| `feed.view.interesting`, `feed.view.likely`, `feed.view.usable`, `feed.view.upgrade` | `false` each | Filters | the View a fresh filter bar tab opens on, a set (DW-A1, feedback-2 spec §1): each row on adds its value (Interesting; Likely tradeable, the trade estimate yes or likely; Usable by me, not can't use or doesn't want; Upgrade for me), the values combine as AND, and all off is All, the default |
| `feed.content`, `feed.sort` | `"session"` (`"instance"` until feedback-13 spec §0), `"newest"` | Filters | the Drops tab's Content when it opens (`instance` or `session`; `all` is History's alone since DW-Q1, feedback-15 spec §1, and step 8 turns a stored one into `session`), and a fresh tab's Sort (History always opens on Content: All) |
| `feed.gearOnly`, `feed.includeTokens` | `true`, `true` | Filters | armor, weapons, jewelry and trinkets only; tier tokens too |
| `feed.minIlvlMode` | `"off"` | Filters | `off`, `absolute` (`feed.minIlvl`, 0 to 1000, default 0) or `relative` (`feed.relativeIlvl` under your average, 0 to 100, default 10) |
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
| `window.columns.<col>` | `true` | Columns | `false` hides that Drops column (`ilvl`, `slot`, `armorType` (the Type column, since DW-D3, feedback-4 spec §3; AceDB's default fills it in for a stored profile, no migration step), `looter`, `me` and `them` (since DW-F1, feedback-6 spec §1, the merged cells: the worn gear and the verdict; the `myEq` and `theirEq` toggles DW-83 added are retired by step 7), `trade`, `tradeWindow` (Trade window, since DW-E1, feedback-5 spec §1; AceDB's default fills it in for a stored profile, no migration step), `actions`); Item never hides |
| `window.mode` | `"full"` | Layout; `NS.SetWindowMode`, the title-bar toggle, `/dw compact`, `/dw full` (DW-C0) | the window's layout, `full` or `compact` (compact spec §1, `modules/WindowCompact.lua`); its reaction lets a run override go and lays the window out. Replaced the compact preset `window.compact` (DW-42), which step 5 maps here |
| `window.compactInRuns` | `true` | Layout (DW-C0) | Open in compact view during a run: an auto-open inside a dungeon, raid, key or delve opens the compact layout, whatever `window.mode`, until the situation leaves that run (the override itself is session-only, `NS.State.compactRun`) |
| `window.rowHeight`, `window.fontSize` | `18`, `0` | Layout | the drop tables' row height (18 to 40) and text size on both tabs (`modules/WindowRows.lua`, at each repaint; feedback-2 spec §8, FB2-9): `fontSize` 0 is Default, the template's own size like Ka0s Loot History's table (the CLI shows `0 (Default)`), else 8 to 20; a Drops row is taller by its countdown bar's room while the Trade window column shows (feedback-5 spec §1). Since DW-A8 (was `24`, `12`, Group drops only); a value the player stored stays as it is |
| `toast.enabled`, `toast.inCombat`, `toast.sound` | `false` | Toast | the upgrade toast (`modules/Toast.lua`, read at each drop and each toast); turning `toast.enabled` off takes the toast on screen down and empties its queue (the row's reaction) |
| `toast.minGain`, `toast.duration` | `10`, `8` | Toast | its least gain for you and its seconds on screen |

### Named state (no row)

| Key | Default | Set by | What it is |
|---|---|---|---|
| `window.geometry.full`, `window.geometry.compact` | absent | a drag or a resize in that layout; Reset position clears both | `{ point, relativePoint, x, y }` as `point`, and `width`, `height`: one per layout (DW-C0; before step 5, `window.point`, `.width` and `.height`). Absent, full is 1038 x 600 and compact is 440 x 460 at the full window's top right. A stored width under the layout's least (its default: full 1038, compact 440; feedback-4 spec §4, DW-D4, recomputed by feedback-5 spec §4, DW-E4, and feedback-6 spec §0-§1) is raised to it on load |
| `window.minimized` | absent | the minimize button, a double-click on the title bar | the window collapsed to its title bar |
| `toast.point` | absent | a drag of the toast in test mode; Reset position clears it | `{ point, relativePoint, x, y }` |
| `simPanel.point` | absent | a drag of the simulation panel; Reset position clears it | `{ point, relativePoint, x, y }`; until set, the panel opens beside the window |

Each one's owner and every writer are named under
[State written outside the seam](#state-written-outside-the-seam-architecture-5) below.

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
          me = { verdict, ilvlDelta, scoreDelta, offSpec? }, them = { ... } | nil,
          trade = { state, reasonKey, basis, args }, outcome, before, beforeExpired, at } } } } }
```

- A group is one feed group of one session: its `key` is the feed group's key and the session's
  start (`enc:<id>:<t>@<time()>`, an area's `area:<name>:<drop id>:<t>@<time()>`, its `<t>` the
  GetTime() a reload does not reset, so no key made after a reload meets one from before it; the
  session is the login, kept by a reload: `char.session.start` below, feedback-15 spec §0), its `label` the encounter, run or area name, `kind` `encounter`,
  `run` or `area`, `situation` the situation key and `at` its first drop's time.
- `at` is `time()` (seconds since the epoch), so it reads the same after a reload; `looter` is the
  Name-Realm and `class` its classFile; `me`, `them` and `trade` are the verdicts and the trade
  estimate as last judged while the drop was in the feed, plain fields only. A `cantUse` that another
  spec of the class can use keeps `offSpec = { specID, mainSpecID, verdict, ilvlDelta }` (feedback-19
  spec §1): no baseline and no reasons. No migration step: the field is optional.
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
  them and the entry copies them. The History tab's Character dropdown (All by default since feedback-13 spec §0) filters
  by `seenBy`. An entry kept before DW-A4 has neither: it is "unknown", which only `Character: All`
  shows. No migration step: the fields are optional.
- `outcome` is `seen`, `asked`, `offered`, `received`, `tradedAway`, `expired` or `declined`;
  `before` is the outcome a hand-set `declined` replaced, and `beforeExpired` the one an automatic
  `expired` replaced (feedback-15 spec §0): the trade timer's live `yes` puts it back, so a false
  Expired is undone (an entry expired before the field existed returns to `seen`). No migration
  step: the field is optional.
- How long it is kept: a group goes whole once its newest entry's `at` is older than
  `history.retentionDays` days (never under `0`), at the session's prune or a confirmed shorter
  window. Beside that, 50 drops per group and a safety ceiling of 5,000 drops in all
  (`NS.History.CEILING`, a constant the diagnostics report), the oldest going first, keep
  SavedVariables bounded even under Never delete. The history's shape has its own stamp, `v`.

## `DropWatcherDB.char`

Per character (AceDB's `char` section, keyed by character; savedvariables-§1), no defaults declared
and no setting row: the session (feedback-15 spec §0, DW-Q0, `modules/Session.lua`).

| Key | Default | What it is |
|---|---|---|
| `session.start` | absent until the first read or login | the session start, `time()`: an initial login's `PLAYER_ENTERING_WORLD` sets it to now, a reload keeps it, a zone change moves nothing; absent or not a number, it is now (stored). History's group keys (`@<start>`) and every tab's This session read it (`NS.History.SessionStart`) |
| `session.instance` | absent until the first `SituationChanged` | `{ at, situation, instance }`: where This instance started, `at` the epoch, `situation` the situation key, `instance` the instance map id (nil outside one); a reload's first situation announcement that names the same situation and instance restores the window's This instance from it |

The kit's AceDB fake has no `char` section, so headless the record is session-only unless a suite
seeds `db.char` (`test_feed_restore` does).

## State written outside the seam (architecture-§5)

The one home of these names: `docs/ARCHITECTURE.md` → Settings Schema summarizes them and links
here (documentation-§3's spill rule). Each key has one owner module, and every function that writes
it is named.

- `profile.window.geometry.full` and `.geometry.compact` (`{ point, width, height }`, one per
  layout; compact spec §1, DW-C0) are geometry only a drag or a resize sets, read and created
  through `NS.WindowCompact.Geometry` for the layout in force. Owner `modules/Window.lua`; writers
  `savePoint` (the title-bar drag stop and the resize grip's release), `saveSize` (the resize
  grip's release, saved together with the point) and `Window.ResetPosition` (the Reset position
  button, which forgets both layouts' geometry, `WindowCompact.ResetGeometry`, and the toast's and
  the simulation panel's points too).
- `profile.window.minimized` is the minimize button's remembered view. Owner `modules/Window.lua`;
  writer `Window.SetMinimized` alone.
- `profile.toast.point` is the toast's position (design spec §11.5). Owner `modules/Toast.lua`;
  writers its drag stop (a drag only test mode allows) and `Toast.ResetPosition`.
- `profile.simPanel.point` is the simulation panel's position (sim feedback spec §1, DW-91), absent
  until the player drags it, so the panel opens beside the window. Owner `modules/SimPanel.lua`;
  writers its drag stop and `SimPanel.ResetPosition`.
- `global.notices.autoAsk` is auto-ask's one-time notice. Owner `modules/AutoAsk.lua`; written the
  first time the `messages.autoAsk.enabled` row turns on (its reaction), so the notice is said once
  per account.
- `global.history.v` and `global.history.groups` are the history's own record. Owner
  `modules/History.lua`, which writes them on a recorded drop, an outcome, a completed trade, the
  safety ceiling and Clear history (Settings › Window › Layout); `modules/HistoryRetention.lua` deletes the groups older than
  Keep history for (once per session, five seconds after the first `PLAYER_ENTERING_WORLD`, or
  after the stand-up when the addon started disabled, and on a confirmed shorter window). Neither
  replaces `global.history` whole, since the retention row's value lives in it.
- `global.minimap.minimapPos` is LibDBIcon's own write into the table the launcher hands it.
- `char.session.start`, `char.session.instance` and `char.session.cleared` are the session
  (feedback-15 spec §0). Owner `modules/Session.lua`; writers `Session.Start` (now, when nothing
  valid is stored), `Session.OnEnteringWorld` (an initial login, which also drops `cleared`; the
  stand-up after a disabled start), `Session.MarkSituation` (each `SituationChanged` the window
  hears, but a reload's first one in the stored place) and `Session.MarkCleared` (`time()` at each
  live `LootFeed.Clear`, `/dw clear` or Clear on boss kill: a reload restores no entry dated
  before it).

While a simulation runs, History writes a simulated drop (`sim = true`) and a simulated trade to
the simulation's session-only log instead (`NS.Sim.HistoryLog`, `modules/Sim.lua`), never
`global.history`, and the stop lets that log go (simulator spec §5). A drop or trade is simulated
only when `Sim.Fire` delivered the event that made it (`NS.Sim.IsDelivering`): a real loot line or
trade that arrives while a simulation runs is real, keeps the real situation and is saved
(`History.LogFor`).

No structural registry exists yet. The load pass is `NS:RunMigrations` (`core/Database.lua`),
below.

## Session-only (never saved)

`NS.State.debug` (the logging flag), `NS.State.testMode`, `NS.State.windowOpen`,
`NS.State.windowFilters` (the filter bar's state per tab, `{ view = { [value] = true },
char = { [Name-Realm] = true }, content, search, sort }`, seeded from the `feed.view.<value>`,
`feed.content` and `feed.sort` rows when they hold a value the tab offers (Content: Drops This instance and This
session, History All too, `WindowFilterBar.CONTENTS`, DW-Q1); `char` starts on Current, your
key, or the `current` sentinel until your key is known; History then takes
`WindowFilterBar.TAB_FIXED`'s View: All, Content: All and Character: All, feedback-13 spec §0),
`NS.State.windowGroup` (the Drops table's collapsed groups and the row whose detail card is open; no
drop is dismissed since DW-D2, feedback-4 spec §2),
`NS.State.windowOwn` (your own drops that are upgrades for you whose Offer panel you opened, so Drops
draws who they would help; feedback-5 spec §2, DW-E2, where `NS.State.windowMine` was My drops'),
`NS.State.offerPanel` (the drop the Offer panel shows),
`NS.State.windowHistory` (the History tab's collapsed groups; its View: All, Content: All and
Character: All come from WindowFilterBar.TAB_FIXED since feedback-13 spec §0),
`NS.State.situation` and `NS.State.situationInputs` (the last classified situation and the inputs it
came from; nil while stood down), and compact mode's run override (`NS.State.compactRun`,
`{ key, ended }` while an auto-open inside a run holds the window compact, and
`NS.State.compactRunSpent`, the situation a completed key's grace ran out in, where no auto-open
re-arms it until the situation moves or a key starts; `modules/WindowCompact.lua`). The Debug console
and Test mode rows are `sessionOnly` and store through their own closures.

The filter bar's View is a set (DW-A1): the multi-select View dropdown's values combine as AND, All
is the empty set and the default, and each tab grays the values it does not use
(`FB.HONORS[tab].views`). Test mode sets the Drops tab's View to All while it is on and puts the
player's value back when it ends (`modules/TestMode.lua`). Compact mode keeps no state of its own
beyond the run override: the cards read the same session tables as the rows, so a switch keeps the
tab, the filters, the collapsed groups and the expanded detail card. No drop is dismissed or hidden
on any tab (feedback-4 spec §2, DW-D2).

## Migrations

`core/Database.lua`: the load pass is `NS:RunMigrations`, `NS.MIGRATIONS` is a list of steps
`{ to, run, perProfile }`, and `NS.SCHEMA_VERSION` is the highest step's `to` (today 8). The runner
runs in `OnInitialize` straight after `AceDB:New`, before anything reads the profile, and again on
every profile event. It owns the stamp: a step's `to` is stored only after the step returned, so a
step that raises is retried on the next load. A `perProfile` step runs for every stored profile in
the raw SavedVariables, not only the active one. The default stays `0`.

| Step | What it does |
|---|---|
| 1 | 0 → 1: the stamp itself; nothing to reshape |
| 2 | 1 → 2, per profile: every setting has a row (DW-40). A stored value its row now refuses (the wrong type, or outside its list or range) is dropped, so the default shows: before the rows, `feed.quality.mode` and `window.compact` were written straight onto the profile, and `trade.rules.*`, `messages.*` and `situations.*` were read with forgiving fallbacks. A valid value and every default pass through unchanged (`NS.RepairStoredSettings`) |
| 3 | 2 → 3, per profile: the View becomes a set (DW-A1, feedback-2 spec §1). A stored `feed.view` string becomes `feed.view = { [value] = true }` (`interesting` keeps Interesting, `all` is the empty set), and the retired `trade.likelyOnly`, `feed.usableOnly` and `feed.upgradeOnly` fold into it as `likely`, `usable` and `upgrade` when they were on, their leaves removed, so each player keeps the choices they had. A profile that only inherited the old default (`interesting`) stored nothing, since AceDB strips a value equal to its default at logout, and opens on the new default, All. A profile already in the new shape passes through (`NS.MigrateViewSet`) |
| 4 | 3 → 4, global: the History is kept by days (DW-A5, feedback-2 spec §5). The retired group cap, `global.history.maxGroups`, is removed; nothing is pruned by the step, and Keep history for starts on its default, 30 days, which the session's prune applies (`NS.RetireHistoryCap`) |
| 5 | 4 → 5, per profile: compact mode (DW-C0, compact spec §1). The retired compact preset, `window.compact = true`, becomes `window.mode = "compact"` (the preset wins over a `mode` the defaults answer), and the key goes; the single-layout geometry `window.point`, `.width` and `.height` moves into `window.geometry.full`, keeping any value already there. A profile already in the new shape passes through (`NS.MigrateWindowMode`) |
| 6 | 5 → 6, per profile: own drops are always listed on Drops (DW-E2, feedback-5 spec §2). The retired switch `feed.showOwn` (Show my own loot in Group drops) is removed; nothing else changes (`NS.RetireShowOwn`) |
| 7 | 6 → 7, per profile: My eq merged into Me and Their eq into Them (DW-F1, feedback-6 spec §1). The retired `window.columns.myEq` and `window.columns.theirEq` toggles are removed, since `me` and `them` now toggle the cells that show the worn gear; only the two keys go (`NS.RetireEqColumns`) |
| 8 | 7 → 8, per profile: Content: All is History's alone (DW-Q1, feedback-15 spec §1). The Drops tab offers This instance and This session (its feed holds this session's drops alone), so a stored `feed.content = "all"` becomes `"session"`, the row's default; anything else passes through (`NS.MigrateContentAll`) |

A stored-value type change adds a step and raises `NS.SCHEMA_VERSION`.
