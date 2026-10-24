# Settings panel — Ka0s Drop Watcher

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

Every page after the landing page draws a tab strip, one tab per `group` of the rows whose `page` is
its key (`Settings.RowsForPage`, the descriptor's `rowsForPage`), in declaration order
(options-ui-§13). Each page's Defaults button resets that page's rows and no other page's; on
General it is the global reset instead. A row with nothing to do is drawn dimmed (its `disabledIf`
predicate, `settings/SchemaRows.lua`), never hidden, and keeps its value. A switch with dependent
knobs sits alone on its line (`solo`) and its knobs pair under it, and a mode's two exclusive values
share a line (feedback-24).

| Page | Covers |
|---|---|
| Ka0s Drop Watcher (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls`, `Simulator`, `Keybindings` |
| Situations | `Situations` (one tab: Auto-open the window and the per-situation table) |
| Drops (key `feed`) | `Quality`, `Items`, `Retention` |
| Comparison | `Scoring`, `Weights`, `Unwanted types` |
| Messages | `Sending`, `Auto-ask`, `Templates` |
| Window | `Layout`, `Columns`, `Starting view`, `Icons` |
| Alerts | `Toast`, `Upgrade glow` |
| Profiles | AceDBOptions: switch, copy, reset and delete profiles |

Until feedback-24 the pages were General (Master controls, When to show, Simulation), Feed (Quality,
Filters), Comparison, Trade (Rules, Timers), Messages (Templates first) and Window (Columns, Layout,
Toast, Upgrade glow, Icons). The regroup moved rows between pages and tabs and renamed some labels;
no stored path changed, so it needed no migration. It did move what each page's Defaults resets,
and `/dw list` groups rows by page, so its sections follow the new pages.

`settings/Panel.lua` registers General, `settings/Pages.lua` the six after it,
`settings/Profiles.lua` the last. Window › Icons' Border block is composed by the library
(`settings/ComposedRows.lua`, options-ui-§16), like General's Master controls. Three tabs, two
closing lines, one opening note and one table have no row the flow engine can draw; they are host
tabs, `afterGroup` hooks and a page `chrome` handed to the library's tabbed renderer
(`settings/PageEditors.lua`, over the pure `settings/Editors.lua`), and Drops › Retention's Clear
history button is Keep history for's `pairWith` partner, the right half of its line.

## General → Master controls

Composed by `Helpers.MasterControls` from one declaration (`settings/Panel.lua`), canonical rows in
canonical order (options-ui-§15):

| Left | Right |
|---|---|
| Enable Ka0s Drop Watcher (`enabled`) | General visibility (`visibility`) |
| Master scale (`scale`) | Master alpha (`alpha`) |
| Lock frame (`locked`) | Debug console (`state.debugConsole`, session) |
| Minimap button (`global.minimap.shown`) | Test mode (`state.testMode`, session) |
| Reset position (button) | Reset all settings (button, asks first) |

Every row writes through the one seam (`NS.SchemaRuntime.Set`), and its reaction is the same one
the CLI, the launcher and the host verbs trigger (`Settings.REACTIONS` in `settings/Schema.lua`).
The header's Defaults button and Reset all settings both open the confirmation popup; the global
reset is a profile reset and never touches the minimap button (options-ui-§12, launcher-§3).

The launcher's right-click menu mirrors four of these: Enabled, Locked, Test mode and Show window
(launcher-§2). Show window also has a key binding (launcher-§6): Options → Keybindings → Ka0s Drop
Watcher → Toggle drop feed, or General → Keybindings in this addon's settings, with no default key,
on the same handler as the menu entry and `/dw toggle` (`NS.ToggleWindow`, through the
`DropWatcherToggleWindow` button in `core/LauncherSetup.lua`). The header's Defaults tooltip ends
with `Key bindings are not changed.` (`O.KEYBINDS_UNCHANGED`): no reset reaches a key.

## General → Simulator

One slider (the tab was `Simulation` until feedback-24), `Simulation step delay` (`sim.stepDelay`, feedback-2 spec §8, DW-A7): the
seconds the simulator waits between steps as it plays, 0.5
to 10 in steps of 0.5, 1 by default (2 until the owner's 2026-10-23 simulator feedback). `/dw set sim.stepDelay <n>` reaches it too (the slash parser
clamps a number outside the range to it). A change takes effect from the next step of a running
timeline.

## General → Keybindings

The General page's last tab (options-ui-§20), drawn by LibKa0s's `O.KeybindingsTab` over
`NS.BINDINGS` (`core/LauncherSetup.lua`) as a host tab with no `before` (`settings/Panel.lua`). It
edits the same store as Options → Keybindings → Ka0s Drop Watcher, so a key set in either shows in
the other. The library's intro line, then one row, `Toggle drop feed` (tooltip `Shows or hides the
drop feed.`), with Key 1, Key 2 and Clear; then which binding set the key is saved to, and the
outcome of the last change. Keys are saved by the game, never in the profile: Defaults, Reset all
settings and `/dw set` never touch them. In combat the tab refuses every change.

## Situations

Everything set per situation, on one page with one tab (feedback-24: General › When to show and
Trade › Rules until then). The master `autoOpen` row (Auto-open the window), then the per-situation
settings as one table (feedback-8 spec §0, DW-H0), a line per situation in `K.SITUATIONS` order
(design spec §6.1):

| Situation | Track | Auto-open | Quality | Loot rule |
|---|---|---|---|---|
| the situation's name (`WindowFooter.SituationLabel`) | checkbox, `situations.<key>.track` | checkbox, `situations.<key>.autoOpen` | dropdown, `situations.<key>.quality` (`Use global` or a mode of its own) | dropdown, `trade.rules.<key>` (Personal, Group or Legacy loot, design spec §7.2) |

It takes the look of Ka0s Loot History's Price sources table, without its drag handle, reorder list
and status column: gold, left-aligned column headers (`GameFontNormalSmall`) in a band above
fixed-height lines, every second line faintly striped, the cells' text in `GameFontHighlightSmall`,
the panel's own CheckBox and Dropdown widgets. An untracked situation's `Auto-open`, `Quality` and
`Loot rule` are dimmed and its name grays; every situation's `Auto-open` is dimmed while the master row is off.
Each cell dims exactly when its schema row's `disabledIf` says so (`Editors.SituationRows`), so the
rule has one home. Hovering a cell shows its row's label and tooltip; hovering a name shows the
situation.

The four per-situation rows stay schema rows (paths, defaults, checks, tooltips), marked
`skipRender` with no subsection, so `/dw get|set`, the page's Defaults, profiles and their announce
reach them unchanged. The table is the Situations tab's `afterGroup` hook
(`Settings.PageEditors.SituationTable`), writes through `NS.SchemaRuntime.Set` and repaints every
value and state on each render and after every write (a toggle, the master row, Defaults, a profile
switch). Its host frame and slots are built once per session and re-hosted on a fresh placeholder
on each render. The placeholder's `OnRelease` parks it (`ParkSituationTable`), hidden on the panel,
whenever AceGUI takes the placeholder back (options-ui-§19); the Situations page's renderer
(`beforeClear` in `settings/Pages.lua`, and its `rerender`) also parks it before `ClearScroll` as
belt-and-braces. Until DW-H0 the tab drew one block per situation,
since LibKa0s has no grid composer for mixed controls;
[LibKa0s#50](https://github.com/tusharsaxena/LibKa0s/issues/50) was rejected at one consumer; the table stays the page's own editor.

## Drops

The page key stays `feed` (a page key is no stored path, but it names the page's section in
`/dw list`). What the addon lists at all, and how long it keeps it.

**Quality:** `Minimum quality` (`feed.quality.mode`) beside `Always show upgrades for me`, then the
mode's two values on one line, never live together: `Fixed minimum` (live in the fixed mode only) |
`Quality floor` (`Floor` until feedback-24; live in the two matching modes only). Then the closing
line `In force now: Quality: Rare+`: the filter bar's label for where you stand, naming the situation
when its own setting overrides the feed's mode. It repaints with every write. Under it, a line points
at the Situations page's Quality column, where a situation sets its own.

**Items:** two subsections. **Item kinds:** Gear only | Tier tokens. **Item level:** Minimum item
level alone on its line, then its two values, each live in its mode only: Absolute minimum | Levels
under my average.

**Retention:** two subsections. **History:** Keep history for (7 to 180 days or Never delete,
default 30; account-wide; a shorter time that would delete groups asks first, and No puts the
previous time back), with **Clear history** beside it (feedback-15 spec §3, DW-Q3: an action, not a
setting, so no schema row; Keep history for's `pairWith` partner in `settings/PageEditors.lua`; it
asks first, `NS.History.AskClear`, and Yes empties the log on every character, or test mode's or a
simulation's session-only log while one is on). Window › Layout's until feedback-24. **Session:**
Clear on boss kill. (Show my own loot in Group drops is retired: Drops always lists your own drops,
feedback-5 spec §2; schema step 6 removes the stored value.)

## Comparison

**Scoring:** Score with, Sidegrade band, Compare against items in my bags, Protect heirlooms.

**Weights** and **Unwanted types** edit the two per-spec maps (`comparison.weights`,
`comparison.undesired`). Each opens with a secondary strip of your class's specs (options-ui-§13:
session state in `ctx.activeSubTab`, keyed by the tab, never stored), on your own spec first.
Weights draws a slider (0 to 5) per stat: the spec's primary stat, Stamina and the four secondaries,
keyed by `GetItemStats`' own stat keys; 0 leaves a stat out. Under the sliders, **Import a Pawn
scale** takes a Pawn scale string (`( Pawn: v1: "name": Key=value, ... )`): Enter replaces the
weights of the spec on screen, the chat says how many came in and which Pawn keys are not scored,
and a string that is not Pawn's writes nothing and says why. Unwanted types (Preferences until feedback-24) draws a checkbox per weapon
type your class's loot comes in, then Shields where a spec carries one; a ticked type is never
called an upgrade for that spec. Every change writes the whole map through the seam, a fresh table
each time.

## Messages

Messages opens on its switches, the template editors last (feedback-24).

**Sending:** which asks you get, then how they go: Offer transmog asks (`messages.transmogAsk`; the
`Ask for transmog` checkbox until feedback-24, the label its template's: on, also offer an ask, with
the Ask for transmog template, on a drop that is no gain for you but whose look you have not
collected) | Ask once, then Edit before sending | Announce channel. **Auto-ask:** Ask automatically
alone on its line, then its Delay | Least gain, live only while it is on. Turning Ask automatically
on the first time prints auto-ask's one-time notice; turning it off cancels the asks waiting to go.

**Templates** (board 08): the token chips (`{player}` … `{mygain}`, each with what it fills in);
clicking one puts it at the cursor of the message you last edited and stores it. Then the five
editors, Ask, Ask for transmog, Ask for off-spec (feedback-19 spec §2), Offer and Announce: Enter (or the box's Okay) stores the text through the seam, which
refuses an empty one, and each label counts the template's bytes against 255 as you type. Then the
preview of the message being edited, written for a real drop when the feed has one that fits (an
upgrade for you for an ask, one whose look you have not collected for the transmog ask, an off-spec gain for the off-spec ask, your own
drop and its best candidate for an offer) and for a sample over your own
gear otherwise (since DW-84): who it goes to, the text as sent, its length, and a red note for a text past
the limit or an unknown token. Reset templates puts the five back.

## Window

**Layout:** Window layout (`window.mode`, `Layout` until feedback-24, the tab's own name; Full or
Compact, compact spec §1: the window's layout, also switched by the title-bar toggle, `/dw compact`
and `/dw full`) | Open in compact view during a run (on by default: an auto-open inside a dungeon,
raid, key or delve opens compact until the run ends), then Row height (18 by default, both tabs of
the full layout, a Drops row taller by its countdown bar's room while Trade window shows; the
compact layout's cards size from their text) | Font size (all the way left, 0, is Default: the
template's own size, like Ka0s Loot History's table; DW-A8; the compact cards follow it too, compact
spec §5).

**Columns:** the tab opens with a note, drawn by the page's `chrome` on this tab only
(`PageEditors.ColumnsNote`): the checkboxes change the full layout's Drops table; History shows
every column and the compact cards every fact. **Shown columns:** a checkbox per optional Drops
column, generated from its column list (Ilvl, Slot, Type since DW-D3, feedback-4 spec §3, Looter,
Me, Them, Trade, Trade window since DW-E1, feedback-5 spec §1, and Actions; My eq and Their eq,
there since DW-83, went with DW-F1, feedback-6 spec §1, when Me and Them took the worn gear).
**Trade window:** Mark a trade window ending within (seconds) (`trade.warnAt`; Trade › Timers'
`Warn before a trade window closes` until feedback-24): your own drop's Trade window countdown takes
its warning color this many seconds before it closes; 0 turns the mark off. It tints that column and
does nothing else.

**Starting view** (Feed › Filters until feedback-24): what a fresh Drops tab opens on. **View:**
Interesting, Likely tradeable, Usable by me and Upgrade for me (`feed.view.<key>`, one checkbox per
value; all unticked is View: All, the default, DW-A1). **Content and sort:** Content (the Drops
tab's, This instance or This session, This session by default; History always opens on All,
feedback-13 spec §0; All left the row in DW-Q1, feedback-15 spec §1, schema step 8) | Sort (what a
fresh tab starts with).

**Icons** (feedback-21 G11), Window's last tab: one look for every item icon the addon draws (the Drops rows and their
Me and Them gear icons, the compact cards, the detail card's header and Replaces rows, the toast,
History and the Offer panel). **Zoom:** Icon zoom (0 to 0.25, cropped off each side; 0.1 by default,
feedback-21 H6; 0 is the whole icon). **Border:** the canonical border block (options-ui-§16), composed by LibKa0s-Options'
`BorderGroup`: Show border (on), then Border style (a LibSharedMedia border; Solid, the flat edge
`modules/IconStyle.lua` registers) |
Border thickness (px) (1 to 16; 2), then Border color (black, opaque) | **Use class color** (off;
the player's class color, the swatch's alpha kept, options-ui-§17), then the block's one extra,
**Color by item quality** (off: on, each border takes its item's quality color in place of the
swatch, its alpha kept; an item with no quality known keeps the swatch). Style, thickness and
Color by item quality are dimmed while Show border is off; the color pair never is. Every change
restyles every icon at once (`NS.IconStyle.Refresh`); the upgrade glow draws over the border.
Ranges and defaults: [`schema.md`](schema.md#window--icons-feedback-21-g11).

## Alerts

Window › Toast and Window › Upgrade glow until feedback-24: both say an upgrade dropped, and neither
is part of the window.

**Toast:** Show a toast alone on its line, then Least gain | Duration, Show in combat | Play a sound,
and its Scale (feedback-21 G10: a 50-200 % slider by 5, `isPercent` on the stored 0.5-2, applied
live to a toast on screen about the place it was put), each live only while it is on.

**Upgrade glow** (feedback-21; on the Window page until feedback-24): the glow on a drop's icon in the Drops table, the compact card and
the detail card's header (never the toast, History, the Offer panel or the Replaces rows), two glows
side by side, the main spec's in the left column and the off-spec's in the right on every line,
each knob a main | off-spec pair. **Effect:** Main spec glow and Off-spec glow (both on), each
glow's Style (Button (rotating rays), Proc (flipbook), Pixel border or Auto cast sparkles; both
Pixel border by default, feedback-21 H6), then Main spec color | Off-spec color (color swatches
with alpha; `#FFF468` and `#3FC7EB`, opaque) and below them **Use class color (main spec)** | **Use
class color (off-spec)** (off; the player's class color in place of the swatch above, its alpha
kept). Each companion sits below its swatch, not immediately to its right: a documented
options-ui-§17 deviation, the owner's choice (main spec left, off-spec right on every row;
[`ARCHITECTURE.md`](ARCHITECTURE.md#documented-deviations)). Then **Offset** (X and Y, for Pixel, Proc and Auto cast: three of the four styles, so it comes
first), then one subsection per style, in the order and the words the Style dropdown lists them
(feedback-24): **Pixel border** (lines, frequency, line length with 0 Automatic, thickness, dark
border), **Auto cast sparkles** (particles, frequency, scale), **Button (rotating rays)**
(frequency), **Proc (flipbook)** (duration in seconds, start animation). A glow's Style is dimmed while it is off; a knob also while its glow is in a style the
knob does not apply to. A color and its Use class color are never dimmed (anti-pattern #74). Every change restarts the glowing icons at once
(`NS.Glow.Refresh`). Ranges and defaults: [`schema.md`](schema.md#alerts--upgrade-glow-feedback-21).
