# Schema — Ka0s Drop Watcher

The SavedVariables shape, every default, and the migration path. Defaults live in
`defaults/Profile.lua` (`NS.C`); `settings/Schema.lua`'s `Settings.BuildDefaults` merges them with
every stored schema row's own default and hands the tree to AceDB.

A default only a Retail-only feature reads (clients-§4) is added on Retail alone, from the feature's
declaration (`NS.Constants.FEATURE`, DW-FP21): `trade.warnAt`, `window.columns.tradeWindow`,
`messages.templates.transmog`, `messages.transmogAsk`, `messages.templates.askOffSpec` and the whole
`glow.offSpec` table. On WoW Forever the profile has none of them and their rows are not registered,
so `/dw list` and Defaults never reach them; a value a Retail profile stored stays in a shared
profile untouched and unread.

## The write seam

One write, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher and
the host verbs alike, and one read, `NS.Setting(path)` (the stored value, or the row's default
before the database exists). The rows are `settings/Schema.lua`'s `Settings.Schema` array: the
composed Master controls rows (`settings/Panel.lua`), then every hand-written row of design spec
§12.1 (`settings/SchemaRows.lua`), page by page as the tables below list them (regrouped by
feedback-24, then by item 020; no stored path moved): General's Simulator, Drops (page key `feed`:
Situations, with each situation's loot rule, then Quality, Items, and Retention with the account-wide Keep history for,
`global.history.retentionDays`, feedback-2 spec §5, DW-A5, which replaced the group cap),
Comparison, Messages, Window's Layout, Columns, Starting view and Icons' Zoom, then Alerts' Toast and
Upgrade glow; Icons' composed Border block (`settings/ComposedRows.lua`) is appended last.

- Each row's `group` is its tab on its page (design spec §12.2); a page draws the rows whose `page`
  is its key (`Settings.RowsForPage`). The tree is [`settings-panel.md`](settings-panel.md).
- A row with nothing to do carries a `disabledIf` predicate that dims it on the panel; its `default`
  references `defaults/Profile.lua`; its `validate` refuses a value outside its list or range
  before the seam stores it.
- `comparison.weights` and `comparison.undesired` are whole-value `map` rows keyed by specID (on
  WoW Forever by `"<classFile>:<tree>"`, one per talent tree: `NS.ClassData.SpecKey`)
  (architecture-§5's value route: a membership change is a whole write through the seam), drawn by
  their own editors (`skipRender`); the CLI shows them as their entry count. So are the two item
  lists, `feed.whitelist` and `feed.blacklist` (issue #13), flat `{ [itemID] = true }` sets on the
  same value route, whose one writer is `NS.ItemLists` (`modules/ItemLists.lua`): the panel's Item
  lists tab and `/dw whitelist|blacklist` both call it, so the two surfaces share one refusal rule
  (an ID on the other list is refused, never moved). Their `validate` checks the shape alone; the
  overlap a copied profile may carry is resolved at read time, where Never watch wins. They are
  the seam's `resetExempt` beside the minimap row, so the Drops page's Defaults keeps them (plan
  #13, Q9); Reset all settings, a profile reset, empties them, and `/dw reset feed.whitelist` still
  resets one. The
  `situations.<key>.*` and `trade.rules.<key>` rows are `skipRender` too (since DW-H0; the loot
  rules since feedback-24): the Drops › Situations table draws them, a line per situation, and writes
  through the seam.
- The reactions every surface shares are `Settings.REACTIONS` (Master controls) and the window
  repaint on the Columns, Layout and Quality rows. Paths `enabled` and `locked` are declared
  `writeThrough`, so the host verbs still land on a load where the composers are hollow
  (options-ui-§1 route (a)).
- The per-character closure row is General › Role (`char.role`, WoW Forever alone, Forever port
  design §11.4): `auto`, `tank`, `healer` or `damage`, onto `db.char.role.override` through
  `Compat.SetRoleOverride` (`auto` clears it). No profile default and no profile reset reach it;
  `/dw reset char.role` is Automatic. Its tooltip names what Automatic answers now
  (`Compat.AutomaticRole`), rewritten each time the General page draws.
- The global closure rows are the Minimap button (`global.minimap.shown`, onto LibDBIcon's `hide`)
  and Keep history for (onto `global.history.retentionDays`, whose change to a shorter window asks
  before it deletes anything, `modules/HistoryRetention.lua`; until the player answers, its
  onChange writes the agreed window back, so an unanswered confirmation never leaves an
  unconfirmed window stored).
- Every other setting the window and the feed read is a row: the window's layout (`window.mode`,
  through `NS.SetWindowMode` and `NS.ToggleWindowMode`: the Window page's Window layout row, the title-bar
  toggle, `/dw compact` and `/dw full`) and the filter bar's Quality control (`NS.SetQualityMode`,
  the Drops page's row) both write through the seam.

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
| `char.role` | `"auto"` | Role (WoW Forever alone) | the role your gear is judged for: `auto`, `tank`, `healer` or `damage`; stored per character as `db.char.role.override` (no profile key; see the closure rows above), and on a Druid the Feral Pawn scale (2 for Damage, 3 for Tank, Forever port design §11.4) |
| `sim.stepDelay` | `1` | Simulator | the seconds the simulator waits between steps as it plays, 0.5 to 10 in steps of 0.5 (feedback-2 spec §8, DW-A7; the default was `2` until the owner's 2026-10-23 simulator feedback, and needs no migration because AceDB never stores a value equal to its default); read as each next step is set, so a change takes effect from the next step |
| `skin.source` | `"ka0s"` | Skin (skipRender; the library's tab draws it) | where the look comes from: `ka0s` (the Ka0s skins) or `eui` (EllesmereUI's); applied through core/SkinSetup.lua, its onChange moving this half alone |
| `skin.skin` | `NS.DEFAULT_SKIN` (`"ka0s"` on Retail, `"forever"` on Forever) | Skin (skipRender) | the Ka0s skin worn, one of LibKa0s-Skin-1.0's registered keys (`/dw set` refuses another); the default is `Skin:DefaultSkin()` (skinning-§2): `ka0s` is Ka0s Default, the look before skins, and `forever` is WoW Forever |
| `skin.ignorePanel`, `skin.ignoreFonts` | `true`, `false` | Skin › Scope (skipRender) | the two exceptions: the settings panel stays the client's; every font stays the game's (the skin still colors the text) |
| `skin.font`, `skin.texture` | `""`, `""` | Skin › Font and texture (skipRender) | the overrides, each a LibSharedMedia key, `""` for the skin's default |
| `skin.outline` | `"hud"` | Skin › Font and texture (skipRender) | the Font outline (LibKa0s v1.82.0, ruling D-06; the default moved to `hud` in v1.83.0, D-10, and a stored mode stays): `hud` text only, `all` text, or `off`; applied with `Skin:SetOutline` at load, on every profile event and on the row's write. The window, the cards and the toast are window text |
| `skin.pickerSeen` | `false` | none (skipRender) | the first-run skin picker was closed on this profile, so it shows once per profile (the rollout's O3) |

### Drops › Situations (page key `feed`)

General › When to show and Trade › Rules until feedback-24; a page of its own (key `situations`)
from feedback-24 until item 020, which made it the Drops page's first tab. The rows' page is now
`feed`, so Drops' Defaults resets them and `/dw list` lists them in its `feed` section.

| Key | Default | Column | What it is |
|---|---|---|---|
| `autoOpen` | `true` | (the row above the table) | master auto-open: `false` keeps every situation from opening the window |
| `situations.<key>.track` | per situation (below; the owner's defaults since DW-06) | Track | loot is watched in that situation |
| `situations.<key>.autoOpen` | per situation (below; the owner's defaults since DW-06) | Auto-open | every drop added to the feed there opens a hidden window, on the Drops tab (since DW-83; it was the first interesting drop, once per situation; the tab since feedback-20: an open window keeps its own) |
| `situations.<key>.quality` | `"global"` | Quality | `global` (the feed's mode), `fixed`, `dynamicSlot` or `dynamicCharacter` |
| `trade.rules.<key>` | `personal`; `legacy` for PvP (follower dungeons were `legacy` too, design spec §7.2, until DW-06) | Loot rule | Retail only (`clients = { "retail" }`, DW-FP11: WoW Forever has one rule, `soulbound`, and no Loot rule column). The rule (`personal`, `group` or `legacy`) that decides whether a drop there can be traded; dimmed while the situation is untracked |

`<key>` is each of `mythicPlus`, `dungeon`, `followerDungeon`, `raidLFR`, `raid`, `delve`,
`scenario`, `pvp`, `openWorldGroup` and `solo`; `track` and `autoOpen` default on for Mythic+,
dungeons, follower dungeons, raids, delves, scenarios and solo, `track` alone for Raid Finder, and off
for PvP and the open-world group (the owner's defaults since DW-06; design spec §6.1 had follower
dungeons, delves, scenarios and solo off). WoW Forever's five take the same values but for the
open-world group, whose `track` and `autoOpen` both default on there (RX-01, rolls UX ruling 7);
Retail's stays off. They are AceDB defaults, so a profile that never changed a
cell takes them and a stored choice stays, with no migration. The four per-situation rows
are `skipRender` with no subsection (since DW-H0, feedback-8 spec §0; the loot rule since
feedback-24): the Situations table draws them, one line per situation (`settings/PageEditors.lua`
`SituationTable`, docs/settings-panel.md), and writes through the seam, so the CLI, the Defaults
button and profiles reach them as any row.

### Drops (page key `feed`)

| Key | Default | Tab | What it is |
|---|---|---|---|
| `feed.quality.mode` | `"fixed"` | Quality; the filter bar's Quality control (`NS.SetQualityMode`) | the minimum-quality mode new drops are gated with |
| `feed.quality.fixed` | `3` (Rare) on Retail, `2` (Uncommon) on WoW Forever (RX-01, rolls UX ruling 7) | Quality | the fixed mode's threshold, Uncommon to Legendary |
| `feed.quality.floor` | `2` (Uncommon) | Quality | the dynamic modes' least threshold, Common to Epic |
| `feed.quality.upgradeOverride` | `true` | Quality | an upgrade for you, or a collectible new to your collection, shows below the threshold (issue #13); an Always watch item passes whatever its quality (`whitelisted`) |
| `feed.categories.equipment`, `.tierToken`, `.mount`, `.pet`, `.toy`, `.recipe`, `.cosmetic`, `.container`, `.other` | `true` each, `cosmetic` and `other` `false` | Items › Item kinds | the item kinds the feed watches (issue #13, categories design spec §1, §5.1), in `C.CATEGORIES`' order: a drop in no watched kind is hidden as `notWatched`, one in a kind turned off as `category` (`NS.FeedFilter`); they replaced `feed.gearOnly` and `feed.includeTokens` (step 13). `container` (RX-04) is a lockbox or a bag; `other` is the catch-all: an item of no kind is let in only when a group rolls on it (Pending's gate, or a drop with a roll table) and it is on. Both are additive stored paths, defaulted by AceDB: no schema step |
| `feed.whitelist` | `{}` | Item lists › Always watch (`map`) | `{ [itemID] = true }`: always watched, past the item kinds, the heirloom rule, the minimum item level and the quality gate, never past the situation gate; an item of no kind reads `unknown` and is feed-only (categories design spec §4.2) |
| `feed.blacklist` | `{}` | Item lists › Never watch (`map`) | `{ [itemID] = true }`: never watched, gear included, hidden as `blacklist` before every other filter; wins over `feed.whitelist` on an overlap |
| `feed.minIlvlMode` | `"off"` | Items | `off`, `absolute` (`feed.minIlvl`, 0 to 1000, default 0) or `relative` (`feed.relativeIlvl` under your average, 0 to 100, default 10) |
| `feed.clearOnBossKill` | `false` | Retention | empty the live feed at each boss kill (LootFeed, at the kill's `ENCOUNTER_END`) |
| `rolls.show` | `true` | Rolls | the Drops tab's Rolling now section and a rolled drop's Rolls box (Forever port design §5.3, DW-FP15; both clients); off hides them, the pending store still tracks every roll (design §11.1) |
| `rolls.keep` | `true` | Rolls | keep a rolled drop's roll table in History (the entry's `rolls`) |
| `rolls.popupMark` | `true` | Rolls | your verdict on the game's roll popup (`modules/RollPopup.lua`, since DW-FP20); a change repaints the marks on the shown popups |

### Comparison

| Key | Default | Tab | What it is |
|---|---|---|---|
| `comparison.scorer` | `"auto"` | Scoring | `auto`, `pawn`, `weights` or `none`; the adapter in use (`modules/Scoring.lua`) can differ, see the Known Limitations |
| `comparison.sidegradeBand` | `0` | Scoring | item levels either side of equal that read as a sidegrade, 0 to 20 |
| `comparison.compareOwned` | `false` | Scoring | judge against the best of worn and carried |
| `comparison.heirloomProtect` | `true` | Scoring | a slot holding an heirloom is not called an upgrade for you (LootFeed → Evaluate's `heirloomProtect`) |
| `comparison.weights` | `{}` | Weights (`map`) | `{ [specKey] = { STAT_KEY = weight } }` (the specID, or on WoW Forever `"<classFile>:<tree>"`), the Weights adapter's scores; the Pawn scale import writes one spec's |
| `comparison.undesired` | `{}` | Unwanted types (`map`) | `{ [specID] = { ["<classID>:<subClassID>"] = true } }`, the item types a spec never wants |

The two `map` rows are whole values: a write replaces the whole table through the seam, and the
row refuses a key that is not a specID, a weight that is not a number, or a type key not shaped
`<classID>:<subClassID>`. The CLI lists them as their entry count and does not set them.

### Messages

| Key | Default | Tab | What it is |
|---|---|---|---|
| `messages.templates.<kind>` | design spec §9.1's text | Templates | the `ask`, `transmog`, `askOffSpec`, `askML`, `offer` and `announce` templates; an empty one is refused. `askML` (DW-FP19, both clients) is the master-loot ask, whispered to the master looter for an item awaiting them, `{player}` the master looter; auto-ask never sends it. `transmog` and `askOffSpec` are Retail only (`clients = { "retail" }`, DW-FP10: WoW Forever has neither transmog nor off-spec, `C.MESSAGE_TEMPLATES` per client). `transmog` is the ask's wording for a drop that is no gain for you but whose look you have not collected (DW-53); `askOffSpec` is its wording for a drop your current spec can't use but another spec of your class gains from (feedback-19 spec §2; no migration, AceDB backfills the default) |
| `messages.transmogAsk` | `false` | Sending | Retail only (`clients = { "retail" }`, DW-FP10). Also offer an ask, with the `transmog` template, on a drop that is no gain for you but whose look you have not collected (DW-53) |
| `messages.editFirst` | `false` | Sending | open the Edit message box before an ask, offer or announce (the host handlers) |
| `messages.oneAsk` | `true` | Sending | each (drop, target, kind) is sent once |
| `messages.announceChannel` | `"auto"` | Sending | `auto`, `INSTANCE_CHAT`, `RAID` or `PARTY`; never say or yell |
| `messages.autoAsk.enabled` | `false` | Auto-ask | ask on your behalf (`modules/AutoAsk.lua`, read at each drop and when an ask is due); its reaction says the one-time notice when it turns on and cancels the waiting asks when it turns off |
| `messages.autoAsk.delay` | `10` | Auto-ask | seconds after the boss kill or the drop, 3 to 30 |
| `messages.autoAsk.minGain` | `5` | Auto-ask | the least item-level gain for you, 1 to 50 |

### Window, and Alerts › Toast

Window's Starting view was Feed › Filters, its Columns' Trade window mark Trade › Timers, and the
toast Window › Toast until feedback-24.

| Key | Default | Tab | What it is |
|---|---|---|---|
| `window.columns.<col>` | `true` | Columns | `false` hides that Drops column (`ilvl`, `slot`, `armorType` (the Type column, since DW-D3, feedback-4 spec §3; AceDB's default fills it in for a stored profile, no migration step), `looter`, `me` and `them` (since DW-F1, feedback-6 spec §1, the merged cells: the worn gear and the verdict; the `myEq` and `theirEq` toggles DW-83 added are retired by step 7), `trade`, `tradeWindow` (Trade window, since DW-E1, feedback-5 spec §1; AceDB's default fills it in for a stored profile, no migration step; Retail only, its row and default too, `clients = { "retail" }`, DW-FP21: WoW Forever has no countdown and no Trade window column), `actions`); Item never hides |
| `window.mode` | `"full"` | Layout; `NS.SetWindowMode`, the title-bar toggle, `/dw compact`, `/dw full` (DW-C0) | the window's layout, `full` or `compact` (compact spec §1, `modules/WindowCompact.lua`); its reaction lets a run override go and lays the window out. Replaced the compact preset `window.compact` (DW-42), which step 5 maps here |
| `window.compactInRuns` | `true` | Layout (DW-C0) | Compact view when it auto-opens in a run (Open in compact view during a run until item 020): an auto-open inside a dungeon, raid, key or delve opens the compact layout, whatever `window.mode`, until the situation leaves that run (the override itself is session-only, `NS.State.compactRun`) |
| `window.rowHeight`, `window.fontSize` | `18`, `0` | Layout | the drop tables' row height (18 to 40) and text size on both tabs (`modules/WindowRows.lua`, at each repaint; feedback-2 spec §8, FB2-9): `fontSize` 0 is Default, the template's own size like Ka0s Loot History's table (the CLI shows `0 (Default)`), else 8 to 20; a Drops row is taller by its countdown bar's room while the Trade window column shows (feedback-5 spec §1). Since DW-A8 (was `24`, `12`, Group drops only); a value the player stored stays as it is |
| `window.tableFont`, `window.tableFontFromSkin` | `"Ka0s Prototype"`, `true` | Layout › Tables (DW-01) | the tables' face, a LibSharedMedia name, read only while Use the skin's font is off; on, the skin's face is drawn (the look before DW-01). The composed font block (`H.FontGroup`, `fromSkin`; the lead's ruling on D-07) |
| `window.tableFontColor`, `window.tableFontClassColor` | `{ r = 0.92, g = 0.92, b = 0.92, a = 1 }`, `false` | Layout › Tables (DW-01) | the tables' plain text color and its class-color companion (the player's class); a verdict, a quality or a class keeps its own color. At the default swatch (Ka0s Default's `dw.plain`) the skin's plain color is drawn, so a new profile looks as before |
| `window.tableFontFlags`, `window.tableFontShadow` | `"@skin"`, `true` | Layout › Tables (DW-01) | the tables' font flags (From skin, `@skin`, resolved through the Skin tab's Font outline as window text; a picked flag as stored) and shadow (drawn through `S.HudFont`, `modules/WindowRows.lua`). Step 11 writes `@skin` to a stored flag once |
| `window.tableFontShadowFromSkin` | `true` | Layout › Tables (FS-DW-FLIP) | Use the skin's shadow: `dw.tableShadow` at `hud.shadowX`, `hud.shadowY`, which keeps black 1, -1 under Ka0s Default; `window.tableFontShadow` is not read while it is on, and stands under Ignore fonts. Step 11 turns it on once per stored profile |
| `feed.view.interesting`, `feed.view.likely`, `feed.view.usable`, `feed.view.upgrade`, `feed.view.newCollect` | `false` each | Starting view | the View a fresh filter bar tab opens on, a set (DW-A1, feedback-2 spec §1): each row on adds its value (Interesting; Likely tradeable, the trade estimate yes or likely; Usable by me, not can't use or doesn't want; Upgrade for me; New to my collection, issue #13, DW-CAT7: the verdict for you is new to your collection, a row added with no migration since a missing value reads its default), the values combine as AND; a Can't use whose off-spec is an upgrade counts for Interesting and Upgrade for me, and one whose off-spec is an upgrade or a sidegrade for Usable by me (feedback-19 spec §1), and all off is All, the default |
| `feed.content`, `feed.sort` | `"session"` (`"instance"` until feedback-13 spec §0), `"newest"` | Starting view | the Drops tab's Content when it opens (`instance` or `session`; `all` is History's alone since DW-Q1, feedback-15 spec §1, and step 8 turns a stored one into `session`), and a fresh tab's Sort (History always opens on Content: All) |
| `trade.warnAt` | `600` | Columns (Trade window) | Retail only (`clients = { "retail" }`, DW-FP11: WoW Forever has no countdown). Mark a trade window ending within: seconds left when your own drop's Trade window countdown takes its warning color (`modules/MineCells.lua`, `modules/TradeTimer.lua`), 0 to 1800; 0 is off |
| `toast.enabled` | `true` (`false` until 2026-10-25; no migration, so an existing profile keeps its value) | Alerts › Toast | Show a toast |
| `toast.inCombat`, `toast.sound` | `false` | Alerts › Toast | the upgrade toast (`modules/Toast.lua`, read at each drop and each toast); turning `toast.enabled` off takes the toast on screen down and empties its queue (the row's reaction); in combat, turning `toast.inCombat` on shows what waits and turning it off holds what follows the toast on screen, which stays up (its reaction, `NS.Toast.OnInCombatChanged`, AT-A3) |
| `toast.minGain`, `toast.duration` | `10`, `8` | Alerts › Toast | its least gain for you and its seconds on screen |
| `toast.stack` | `3` | Alerts › Toast (DW-T2, issue #14) | Toasts at once: how many upgrade toasts show on screen at once, a whole number 1 to 5 by 1 (`wholeIn(1, 5)`, so the CLI's `2.5` is refused), the LibKa0s-Toast-1.0 shell's `stack` getter; `1` is the one-at-a-time toast. Past it the drops wait in the queue. Dimmed while `toast.enabled` is off; its reaction `NS.Toast.ApplyStack()` is the shell's `SetStack`, live on the toasts on screen (a smaller stack sends its last ones back to the head of the queue, a larger one fills from it), and a profile reload's `Refresh` reads it again. A new stored path: AceDB's default fills it in for a stored profile, no migration step |
| `toast.stackGrow` | `"down"` | Alerts › Toast (DW-T2, issue #14) | Stack direction: `down` hangs each toast after the first below the one before, `up` above it (the shell's `stackGrow`, `DOWN` or `UP`, through `NS.Toast.Grow`); the first stays at `toast.point`. Dimmed while `toast.enabled` is off; the same reaction as `toast.stack`. A new stored path, no migration step |
| `toast.scale` | `1` | Alerts › Toast (feedback-21 G10) | the toast frame's scale, 0.5 to 2 by 0.05, drawn as a percentage (`isPercent`, 50 % to 200 %; the CLI shows the stored number), dimmed while `toast.enabled` is off; its reaction `NS.Toast.ApplyScale()` scales a built toast live, on screen or not, about its saved anchor (`toast.point` is unchanged), and a profile reload re-applies it; before the first toast the build applies it |

### Alerts › Upgrade glow (feedback-21)

Two glows on a drop's icon (`modules/Glow.lua`, LibCustomGlow-1.0): `glow.main` for an upgrade for
your current spec, `glow.offSpec` for a drop your spec can't use whose off-spec part is an upgrade;
either only on a drop whose trade estimate is Yes or Likely (feedback-22). Every `glow.offSpec` row
is Retail only (`clients = { "retail" }`, DW-FP10): WoW Forever has no off-spec, so its tab is the
main spec's column alone.
Each has the same keys, below as `glow.<g>.<key>`; the knob set, its ranges and defaults are shared
with KickCD's glow slots, but `pixelFrequency`'s default, 0.1, which is this addon's own
(feedback-21 H6; KickCD keeps the library's 0.25). On the tab every row is a main | off-spec pair,
main left and off-spec right, the colors too: the two swatches share a line and their *Use class
color (main spec)* | *Use class color (off-spec)* companions the next, so each companion sits below
its swatch rather than immediately to its right, a documented options-ui-§17 deviation
(`docs/ARCHITECTURE.md` -> Documented deviations, feedback-21 H6). A style's knobs are dimmed while the glow is in another style, and its style while it is off; the
color pair never is (anti-pattern #74: the swatch's alpha is read under either mode). Every row's
reaction is `NS.Glow.Refresh()` (the window repainted, each glowing icon restarted once; the toast
never glows). The class color is the **player's** (`classColorSource = "player"`): the glow says a drop is
an upgrade for you, whoever looted it. It resolves through `NS.ResolveColor` (LibKa0s-Core's
`ResolveColor`), keeps the swatch's alpha, and falls through to the swatch for a class with no color.

| Key | Default | Style | What it is |
|---|---|---|---|
| `glow.<g>.enabled` | `true`, `true` | all | the glow on or off |
| `glow.<g>.type` | `"proc"`, `"proc"` (DW-03, owner ruling D-18; `"pixel"` until then, and a profile that never chose follows the new default through AceDB, no migration) | all | the style: `button` (rotating rays), `proc` (flipbook), `pixel` (pixel border) or `autocast` (auto cast sparkles) |
| `glow.<g>.color` | `C.TONE.glowMain`, `#19FF19` (`{ r = 25/255, g = 1, b = 25/255, a = 1 }`; DW-03, D-18, `#FFF468` until then), and `C.TONE.glowOffSpec`, `#3FC7EB` (`{ r = 63/255, g = 199/255, b = 235/255, a = 1 }`), tokens of their own (feedback-21 H6) | all | the glow's color, typed `color` (`{ r, g, b, a }`, each 0 to 1; `/dw set` takes it in that shape); its alpha applies under Use class color too |
| `glow.<g>.useClassColor` | `false`, `false` | all | Use class color: the glow in the player's class color instead of the swatch, the swatch's alpha kept (player-scoped, options-ui-§17) |
| `glow.<g>.colorFromSkin` | `true`, `true` | all | Use the skin's color (FS-DW-FLIP, cause D5): `dw.glowMain` or `dw.glowOffSpec`, Ka0s Default's being the two swatch defaults, following `glow.color` and `sem.warband`, so the two stay apart; the swatch is not read while it is on. Use class color comes first. Step 11 turns it on once per stored profile |
| `glow.<g>.pixelLines` | `8` | pixel | how many lines, 1 to 20 |
| `glow.<g>.pixelFrequency` | `0.1` | pixel | how fast they run, 0.05 to 2 by 0.05 |
| `glow.<g>.pixelLength` | `0` | pixel | each line's length in pixels, 0 to 20; 0 is Automatic (the library sizes them from the icon; the CLI shows `0 (Automatic)`) |
| `glow.<g>.pixelThickness` | `1` | pixel | each line's thickness in pixels, 1 to 6 |
| `glow.<g>.pixelBorder` | `true` | pixel | a dark border inside the lines |
| `glow.<g>.autocastParticles` | `4` | autocast | sparkles in each ring, 1 to 12 |
| `glow.<g>.autocastFrequency` | `0.125` | autocast | how fast they circle, 0.05 to 2 by 0.05 |
| `glow.<g>.autocastScale` | `1` | autocast | their size, 0.5 to 3 by 0.1 |
| `glow.<g>.buttonFrequency` | `0.25` | button | how fast the rays turn, 0.05 to 2 by 0.05 |
| `glow.<g>.procDuration` | `1` | proc | seconds per loop of the flipbook, 0.25 to 3 by 0.25 |
| `glow.<g>.procStartAnim` | `true` | proc | the opening burst when it starts |
| `glow.<g>.xOffset`, `glow.<g>.yOffset` | `0`, `0` | pixel, autocast, proc | how far the glow reaches past the icon's sides and top and bottom, -10 to 10 |

### Window › Icons (feedback-21 G11)

One look for every item icon the addon draws (`modules/IconStyle.lua`, applied from
`NS.WindowGroup.ItemButton` and `SetItem`): the Drops rows and their Me and Them gear icons, the
compact cards, the detail card's header and Replaces rows, the toast, History and the Offer panel.
The defaults (feedback-21 H6, the owner's choice) trim the baked-in edge (zoom 0.1) and draw a
Solid black border 2 pixels thick (1 while Use the skin's border is on, the default), neither class nor quality colored; zoom 0 with Show border off
draws them as before G11. A profile that stored a value keeps it (AceDB fills only what is unset;
no migration). The Zoom row is
hand-written (`settings/SchemaRows.lua`); the Border block is LibKa0s-Options' composed
`BorderGroup` with its Show border toggle (options-ui-§16, `settings/ComposedRows.lua`, appended
after the hand-written rows because it needs the Options instance), its one extra after the
mandated four, and the skin companion Use the skin's border (DW-03), which dims style and thickness
while it is on. Style, thickness and Color by item quality are dimmed while Show border is off; the
color pair never is (anti-pattern #74). Every row's reaction is `NS.IconStyle.Refresh()`: the
settings generation moves on and every item button made so far, pooled or not, takes the new look
at once; a profile reload calls it too. Without LibKa0s the composer is hollow and the border rows
do not exist: `NS.IconStyle` reads these defaults, so the Solid black border is drawn and no row
can change it.

| Key | Default | What it is |
|---|---|---|
| `icons.zoom` | `0.1` | the crop off each side of the icon's texture, 0 to 0.25 by 0.01 (KickCD's shape); 0 is the whole icon |
| `icons.borderShow` | `true` | Show border: a BackdropTemplate child frame over the button, made the first time it is shown |
| `icons.borderStyle` | `"Solid"` | Border style: a LibSharedMedia border name (`Ka0sMedia_Border`); a name nothing registers draws the tooltip's edge. `Solid` is the flat edge `modules/IconStyle.lua` registers at load (`Interface\Buttons\WHITE8X8`, AuraMaster's name for it), drawn even where the media library does not know it |
| `icons.borderSize` | `2` | Border thickness (px): the backdrop's edge size, 1 to 16 (the composer's 0 floor raised to 1) |
| `icons.borderStyleFromSkin` | `true` | Use the skin's border: the composer's skin companion (`fromSkin = "icon"`, skinning-§6, DW-03). While on, the border's style and thickness are the skin's `icon.borderStyle` and `icon.borderSize` (every skin's is the flat edge at 1 pixel since LibKa0s v1.85.0's R3-FIX, so the default draws 1 pixel where the stored pick is 2), the two rows are not read and are dimmed, and the stored picks stay where they were; off, the player's own style and thickness. Dimmed while Show border is off. The color has its own companion, `icons.borderColorFromSkin`. Step 10 turned it on once per stored profile, and step 11 does again |
| `icons.borderColor` | `{ r = 0, g = 0, b = 0, a = 1 }` | Border color, typed `color`; its alpha applies under Use class color and Color by item quality |
| `icons.borderColorFromSkin` | `true` | Use the skin's color (FS-DW-FLIP, cause D4): the skin's `icon.outline` in a window (`icon.border` on the toast, a HUD icon; R5-ICON) in place of the swatch, behind Use class color and Color by item quality. Step 11 turns it on once per stored profile |
| `icons.useClassColorBorder` | `false` | Use class color: the border in the **player's** class color (`classColorSource = "player"`: the icons are the player's own view of the loot), through `NS.ResolveColor`, the swatch's alpha kept, the swatch for a class with no color |
| `icons.borderQuality` | `false` | Color by item quality: the border in the item's quality color in place of the swatch (and of the class color), the swatch's alpha kept; the quality is TipMarks.ItemName's source (`NS.ItemRead.QualityOf`, the client's answer else the link's color, in `ITEM_QUALITY_COLORS`, else the link's own `|cAARRGGBB` code); an item with no quality known keeps the swatch's mode |

### Named state (no row)

| Key | Default | Set by | What it is |
|---|---|---|---|
| `window.geometry.full`, `window.geometry.compact` | absent | a drag or a resize in that layout; Reset position clears both | `{ point, relativePoint, x, y }` as `point`, and `width`, `height`: one per layout (DW-C0; before step 5, `window.point`, `.width` and `.height`). Absent, full is 1080 x 600 and compact is 400 x 560 at the full window's top right. A stored width under the layout's least (its default: full 1080, compact 400; feedback-4 spec §4, DW-D4, recomputed by feedback-5 spec §4, DW-E4, feedback-6 spec §0-§1 and feedback-23) is raised to it on load |
| `window.minimized` | absent | the minimize button, a double-click on the title bar | the window collapsed to its title bar |
| `toast.point` | absent | a drag of the toast in test mode; Reset position clears it | `{ point, relativePoint, x, y }`, the offsets in UIParent's units (feedback-21 G10): a drag stores them times `toast.scale` and they are applied divided by it, so a scale change never moves the anchor; a point saved before G10 was saved at scale 1, so it reads the same |

Each one's owner and every writer are named under
[State written outside the seam](#state-written-outside-the-seam-architecture-5) below.

## `DropWatcherDB.global`

| Key | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | the migration stamp; the runner owns it |
| `minimap.hide` | `false` | LibDBIcon's own key; the Minimap button row inverts onto it, and no `shown` twin exists (launcher-§3) |
| `minimap.minimapPos` | absent | LibDBIcon's own write |
| `history.retentionDays` | `30` | Keep history for (feedback-2 spec §5): 7, 14, 30, 60, 90 or 180 days, or `0`, Never delete; the `global.history.retentionDays` row (Drops › Retention; Window › Layout until feedback-24) stores here through its own closures. A change to a window that would delete anything asks first (`NS.HistoryRetention.OnChanged`); the groups older than it go once per session, five seconds after the first `PLAYER_ENTERING_WORLD`. Account-wide: a profile switch, copy or reset never changes it. It replaced `history.maxGroups` (the 20-group cap), which step 4 removes |
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
          category?, tokenSlot?, tokenUsers?,
          me = { verdict, ilvlDelta, scoreDelta, offSpec?, collect?, category?, count?, limit?,
                 reasonKey? }, them = { ... } | nil,
          trade = { state, reasonKey, basis, args }, outcome, before, beforeExpired, at,
          askedAt?, offeredAt?, settledAt?, got?,
          rolls? = { at, allPassed, n, w, r = { { name, class, s, n? }, ... } } } } } } }
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
- `category` is the drop's item kind and `tokenSlot` a tier token's made slot (issue #13,
  categories design spec §3.3); `tokenUsers` (TT-1) is who may use a token naming no classes:
  `every` for an omni Curio, `yours` for a token whose Use text alone names your class, absent
  otherwise (its Type then reads a dash, an `any` slot never taken for a Curio); an Always watch item that fits no kind is kept as `watched`
  (`C.CATEGORY_WATCHED`, a History-only kind, never a `C.CATEGORIES` key). A collectible's `me`
  keeps its collection verdict: `collect` true, its `category`, a pet's `count` and `limit`, and
  `reasonKey` `notYourProfession` for a recipe of a profession you lack. The fields are additive:
  no migration, and `v` stays 1. An entry without `category` (one recorded before issue #13) reads
  as equipment in Insights (`InsightsFilters.CategoryOf`), or as a tier token when its `equipLoc` is
  `INVTYPE_NON_EQUIP_IGNORE`.
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
- `askedAt` and `offeredAt` are the `time()` your ask, or your offer or announce, was first sent
  (issue #12, Insights design spec §1.2): `AskStateChanged` `sent` stamps them once, whether or not
  the outcome moves, and nothing writes them again, so an ask is still known once the outcome moves
  on. An entry asked or offered before they existed and settled after has the stamp back-filled at
  settling (the drop's `at`), since settling overwrites the outcome that held the ask. `settledAt` is when a completed trade settled the entry (`received` or `tradedAway`). `got`,
  on a received entry only, is the `me` verdict frozen at that moment (`{ verdict, ilvlDelta,
  scoreDelta, offSpec?, at }`, or `{ at }` when there was none): equipping the item later re-judges
  `me` against itself, and `got` keeps the gain it was. An entry settled before these existed has
  no `settledAt`, and `NS.History.WasAsked` / `WasOffered` read it as asked (someone else's drop
  received) or offered (your drop traded away). No migration step: the fields are optional and
  additive, and `v` stays 1.
- `rolls` (Forever port design §5.4, DW-FP16) is a group-loot drop's final roll table, kept while
  `rolls.keep` is on: `r` one row per player in the roll cells' order (the winner first), at most
  40 (`NS.History.ROLL_ROWS`), each its name, classFile (`class`), state number (`s`, 0 Need to
  5 Pass) and roll number (`n`, none for a pass); `w` the winner's place in `r`; `n` every player
  who rolled, the rows cut or not; `at` the `time()` it was kept. No GUIDs. It lands with the drop
  or on the later merge that attaches it (that change sends `HistoryChanged`);
  `NS.History.RollTable` reads it back for the History card's Rolls box and the drop a reload
  restores. Additive, `v` stays 1.
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
| `session.cleared` | absent until the first clear | `time()` of the last live `LootFeed.Clear` (`/dw clear`, Clear this session's drops on boss kill): a reload restores no entry dated before it; an initial login drops it (`NS.Session.Cleared`) |

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
  button, which forgets both layouts' geometry, `WindowCompact.ResetGeometry`, and the toast's point
  too, and redocks the simulation panel through `NS.Sim:ResetPanelPosition`). The simulation panel's
  own position is not here: LibKa0s-Sim-1.0 holds a dragged point in memory for the session, it is
  never a schema row or a SavedVariables key, and nothing a simulation does is saved (H10, DW-04).
- `profile.window.minimized` is the minimize button's remembered view. Owner `modules/Window.lua`;
  writer `Window.SetMinimized` alone.
- `profile.toast.point` is the toast's position (design spec §11.5). Owner `modules/Toast.lua`;
  one writer, its `setPosition`, which LibKa0s-Toast-1.0's shell calls on a drag stop (a drag only
  test mode allows) and on `Toast.ResetPosition` (with nil). The shape is unchanged by the move to
  the shell (AT-A2), so no point was migrated.
- `global.notices.autoAsk` is auto-ask's one-time notice. Owner `modules/AutoAsk.lua`; written the
  first time the `messages.autoAsk.enabled` row turns on (its reaction), so the notice is said once
  per account.
- `global.history.v` and `global.history.groups` are the history's own record. Owner
  `modules/History.lua`, which writes them on a recorded drop, an outcome, a completed trade, the
  safety ceiling and Clear history (Settings › Drops › Retention); `modules/HistoryRetention.lua` deletes the groups older than
  Keep history for (once per session, five seconds after the first `PLAYER_ENTERING_WORLD`, or
  after the stand-up when the addon started disabled, and on a confirmed shorter window). Neither
  replaces `global.history` whole, since the retention row's value lives in it.
- `global.minimap.minimapPos` is LibDBIcon's own write into the table the launcher hands it.
- `char.session.start`, `char.session.instance` and `char.session.cleared` are the session
  (feedback-15 spec §0). Owner `modules/Session.lua`; writers `Session.Start` (now, when nothing
  valid is stored), `Session.OnEnteringWorld` (an initial login, which also drops `cleared`; the
  stand-up after a disabled start), `Session.MarkSituation` (each `SituationChanged` the window
  hears, but a reload's first one in the stored place) and `Session.MarkCleared` (`time()` at each
  live `LootFeed.Clear`, `/dw clear` or Clear this session's drops on boss kill: a reload restores no entry dated
  before it).
- `char.role.override` and `char.role.last` (`{ role, specID }`) are the player's role store
  (Forever port design §4.2, DW-FP02). Owner `core/CompatClient.lua` (`Compat.RoleStore`, made on
  first use); writers LibKa0s-Role-1.0's `Resolve` (`last`, on each answer from the group's
  assignment, the talent tree or the spec, read through `Compat.PlayerRole`) and `SetOverride`
  (`override`, through `Compat.SetRoleOverride`, the General › Role row's write on WoW Forever).

While a simulation runs, History writes a simulated drop (`sim = true`) and a simulated trade to
the simulation's session-only log instead (`NS.SimHost.HistoryLog`, `modules/Sim.lua`), never
`global.history`, and the stop lets that log go (simulator spec §5). A drop or trade is simulated
only when `NS.Sim:Fire` delivered the event that made it (`NS.Sim:IsDelivering()`): a real loot line or
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
`NS.State.insightsFilters` (the Insights tab's seven single-select picks, `{ char, instance,
difficulty, situation, date, quality, category }`, each `all` or one value, `InsightsFilters.DEFAULTS`
at first and after Reset filters; no schema row and no saved view; kept across test mode and a
simulation, and put back to All by Normalize wherever a pick matches nothing in the log in force;
issue #12),
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
`{ to, run, perProfile }`, and `NS.SCHEMA_VERSION` is the highest step's `to` (today 13). The runner
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
| 9 | 8 → 9, per profile: the simulation panel's position is session-only (DW-04, LibKa0s#54, OWNER_SCOPE C.11). The panel is LibKa0s-Sim-1.0's, which holds a dragged point for the session alone, so the retired `simPanel` key (the old panel's `point`, window state absent from defaults) is removed and a simulation writes nothing to SavedVariables; nothing else changes (`NS.RetireSimPanelPoint`) |
| 10 | 9 → 10, per profile: the item icon's border meets the skin once (DW-03; the skinning rollout's O2, skinning-§6). For a profile that stored an `icons` table, LibKa0s-Skin-1.0's `ResetToSkin` turns `icons.borderStyleFromSkin` on (called with `{ companions = true }`, LibKa0s v1.81.0's Skin minor 8, so a missing companion is set too and the reset never writes the library's sentinel into `icons.borderStyle`); the stored style, thickness and color stay, so turning the companion off later brings the player's own style back, and the stamp keeps that later choice from being reset again. A profile with no stored `icons` keeps the defaults, whose companion is already on. Without the library the companion is set directly (`NS.ResetIconBorderToSkin`) |
| 11 | 10 → 11, per profile: the full skinning step (FS-DW-FLIP; the owner's rulings of 2026-11-01, existing profiles follow the skin). `Skin.FollowOnce` puts `NS.FULL_SKIN_KEYS` on the skin: every companion is set true and `window.tableFontFlags` takes `@skin`, whatever the player picked. No stored color or pick moves, so a companion turned off brings the player's own back. The record is `skin.fullSkinReset`, per profile, in the AceDB defaults with no row, so no Defaults path walks it; a companion turned off afterwards stays off, and a profile reset runs the step again against defaults. `NS.ResetProfileToSkin` runs from the ladder and again after it on every load and profile event, for a profile that arrives with no record |
| 12 | 11 → 12, per profile: the deleted Friz becomes Ka0s Ubuntu (R3-FRIZ). LibKa0s v1.85.0 deleted `Ka0s Friz Quadrata TT` (R3-L7) and WoW Default draws `Ka0s Ubuntu` in its place (R3-L6). `NS.RetireFonts` moves every stored string naming the deleted face, at any depth (`window.tableFont`, the skin's Font override), to `Ka0s Ubuntu`. Blizzard's own `Friz Quadrata TT` stays. |
| 13 | 12 → 13, per profile: Gear only and Include tier tokens become the item kinds (DW-CAT2, issue #13, categories design spec §5.2). A stored `feed.gearOnly = false` (every item class let through) turns every `feed.categories.<key>` on, cosmetics included; a stored `feed.includeTokens` then carries into `feed.categories.tierToken`, so a stored `false` still turns tokens off; both keys go. The key list is a frozen literal, so a kind added later is not turned on by this step. A fresh profile stores neither and passes through (`NS.MigrateItemKinds`) |

A stored-value type change adds a step and raises `NS.SCHEMA_VERSION`.
