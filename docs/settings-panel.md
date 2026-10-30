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
| General | `Master controls`, `Simulator`, `Skin`, `Keybindings` |
| Drops (key `feed`) | `Situations`, `Quality`, `Items`, `Retention` |
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

Item 020 (the 2026-10-24 settings-layout pass) folded the Situations page into Drops as its first
tab, moved and relabeled rows, and reworded tooltips. It too changed no stored path, default, range
or behavior (`tests/test_schema_rows.lua` pins every path and default). Two consequences of the
fold, both the owner's call: Drops' Defaults now also resets the situations table (Auto-open the
window, and every situation's tracking, auto-open, quality and loot rule), and `/dw list`'s
`situations` section is gone, its rows listed under `feed`.

`settings/Panel.lua` registers General, `settings/Pages.lua` the five after it,
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
`DropWatcherToggleWindow` button in `core/LauncherSetup.lua`). The header's Defaults is the global
reset, so its tooltip is the very text Reset all settings carries, read from the library
(`O.ResetAllTooltip`, options-ui-§12; item 020 retired the addon's own "Reset every … setting" lead),
then `Key bindings are not changed.` (`O.KEYBINDS_UNCHANGED`): no reset reaches a key.

## General → Simulator

One slider (the tab was `Simulation` until feedback-24), `Simulation step delay (seconds)` (`sim.stepDelay`, feedback-2 spec §8, DW-A7;
the unit joined the label, and the tooltip opens `Paces /dw sim:`, in item 020): the
seconds the simulator waits between steps as it plays, 0.5
to 10 in steps of 0.5, 1 by default (2 until the owner's 2026-10-23 simulator feedback). `/dw set sim.stepDelay <n>` reaches it too (the slash parser
clamps a number outside the range to it). A change takes effect from the next step of a running
timeline.

## General → Skin

The library's own tab (skinning-§3), drawn by `O.AppearanceTab({ owner, get = NS.SkinChoice, set =
NS.WriteSkinChoice })` (`settings/Panel.lua`) as a host tab after Simulator and before Keybindings.
Its key is `Appearance`, the group of the eight `skipRender` rows `skin.source`, `skin.skin`,
`skin.ignorePanel`, `skin.ignoreFonts`, `skin.font`, `skin.texture`, `skin.outline` and
`skin.pickerSeen` (the first-run picker's memory, which the tab does not draw); its label is
**Skin**. Its body is the library's (LibKa0s v1.82.0): **Skin source** (*Ka0s skins*, or
*EllesmereUI*, disabled with the failing conditions listed while EllesmereUI cannot skin this addon),
**Look** (the note first, then the nine skins three to a line with their swatches), **Font and
texture** (a **Font** and a **Texture** dropdown, each listing the skin's own first; under them
**Reset font** and **Reset texture**; under those the **Font outline**, *All text* by default,
*HUD text only* or *Off*, `skin.outline`, grayed while Ignore fonts is on), the Scope (**Ignore
settings panel**, on for a new profile, and **Ignore fonts**) and, under **Other Ka0s addons**,
**Copy to every Ka0s addon…**, which carries the outline too. Picking another skin gives the Font and
Texture overrides back to that skin's own. The window, the cards and the toast are window text, so
*HUD text only* takes their outline. A pick calls `Skin:SetChoice`
first (the live repaint, no reload), then writes through the seam, so `/dw get|set skin.*` reaches the
same values and every reset puts them back on Ka0s Default. Leaving EllesmereUI after it painted this
session asks for a reload (the library's popup). In combat the tab refuses every change. Without the
library there is no tab.

**The first-run skin picker** (LibKa0s OptionsSkinPicker, the rollout's O3): a small window titled **Choose a
skin**, with **Ka0s Drop Watcher** on its own line above a dropdown of the skins (the window widens
so the name is never cut off; LibKa0s v1.81.0, OptionsSkinPicker minor 2), an eye, a gear, and **Apply** (with **Apply
to all Ka0s addons** while another Ka0s addon that uses skins is loaded). `NS.MaybeShowSkinPicker`
(`core/SkinSetup.lua`) shows it while the profile's `skin.pickerSeen` is false: two seconds after
login, at a stand-up when the session started stood down, and after every profile switch, copy or
reset. Never while the addon stands down (disabled, or a perf capture), and a start in combat waits
for combat's end. A pick previews; **Apply** saves; the close control and Escape put the stored skin
back and save nothing. The eye opens the window in test mode, so the skin shows on this addon's own
frames; the gear saves the pending pick and opens this tab. Any close the player makes sets
`skin.pickerSeen`; a stand-down or a profile event takes it down without setting it. One picker is up
at a time across Ka0s addons; the others wait in the library's queue.

**The pages' own widgets wear the skin too** (DW-04): every AceGUI widget `settings/PageEditors.lua`
acquires goes through `acquire()`, which paints it for this owner (`NS.SkinPaintAce`, restored stock
on release); the Situations table's session-held check boxes and dropdowns repaint on a skin switch,
and the Profiles page paints the tree AceConfigDialog draws (`NS.SkinPaintAceTree`). Nothing in the
panel is painted while **Ignore settings panel** is on.

## General → Keybindings

The General page's last tab (options-ui-§20), drawn by LibKa0s's `O.KeybindingsTab` over
`NS.BINDINGS` (`core/LauncherSetup.lua`) as a host tab with no `before` (`settings/Panel.lua`). It
edits the same store as Options → Keybindings → Ka0s Drop Watcher, so a key set in either shows in
the other. The library's intro line, then one row, `Toggle drop feed` (tooltip `Shows or hides the
drop feed.`), with one key button and Clear (OptionsKeybinds minor 4). The button binds the first key
and shows it; when the game's page holds a second key for the action it reads `<key> +1`, and its
tooltip names every key and says where the others were set. Clear removes every key. Then which
binding set the key is saved to, and the outcome of the last change. Keys are saved by the game,
never in the profile: Defaults, Reset all settings and `/dw set` never touch them. In combat the tab refuses every change.

## Drops → Situations

Everything set per situation, on the Drops page's first tab (General › When to show and Trade ›
Rules until feedback-24; a page of its own from feedback-24 until item 020). The master `autoOpen` row (Auto-open the window), then the per-situation
settings as one table (feedback-8 spec §0, DW-H0), a line per situation in `K.SITUATIONS` order
(design spec §6.1):

| Situation | Track | Auto-open | Quality | Loot rule |
|---|---|---|---|---|
| the situation's name (`WindowFooter.SituationLabel`) | checkbox, `situations.<key>.track` | checkbox, `situations.<key>.autoOpen` | dropdown, `situations.<key>.quality` (`Use global` or a mode of its own) | dropdown, `trade.rules.<key>` (Personal, Group or Legacy loot, design spec §7.2) |

It takes the look of Ka0s Loot History's Price sources table, without its drag handle, reorder list
and status column: gold, left-aligned column headers (`GameFontNormalSmall`) in a band above
fixed-height lines, every second line faintly striped, the cells' text in `GameFontHighlightSmall`,
the panel's own CheckBox and Dropdown widgets. The columns sit at fixed offsets, 8, 128, 188, 262
and 424, with both dropdowns 150 wide, so the table ends at 574, clear of the panel's scroll gutter in
every skin (DW-02, owner ruling D-18; it ended at 610 before, cutting Loot rule off). An untracked situation's `Auto-open`, `Quality` and
`Loot rule` are dimmed and its name grays; every situation's `Auto-open` is dimmed while the master row is off.
Each cell dims exactly when its schema row's `disabledIf` says so (`Editors.SituationRows`), so the
rule has one home. Hovering a cell shows its row's label and tooltip; hovering a name shows the
situation.

The four per-situation rows stay schema rows (paths, defaults, checks, tooltips), marked
`skipRender` with no subsection, so `/dw get|set`, the Drops page's Defaults, profiles and their announce
reach them unchanged. The table is the Situations tab's `afterGroup` hook
(`Settings.PageEditors.SituationTable`), writes through `NS.SchemaRuntime.Set` and repaints every
value and state on each render and after every write (a toggle, the master row, Defaults, a profile
switch). Its host frame and slots are built once per session and re-hosted on a fresh placeholder
on each render. The placeholder's `OnRelease` parks it (`ParkSituationTable`), hidden on the panel,
whenever AceGUI takes the placeholder back (options-ui-§19); the Drops page's renderer
(`beforeClear` in `settings/Pages.lua`, and its `rerender`) also parks it before `ClearScroll` as
belt-and-braces. Until DW-H0 the tab drew one block per situation,
since LibKa0s has no grid composer for mixed controls;
[LibKa0s#50](https://github.com/tusharsaxena/LibKa0s/issues/50) was rejected at one consumer; the table stays the tab's own editor.

## Drops → Quality, Items and Retention

The page key stays `feed` (a page key is no stored path, but it names the page's section in
`/dw list`, which holds the situation rows too since item 020). What the addon lists at all, and how
long it keeps it. Its Defaults resets every tab, Situations included.

**Quality:** `Minimum quality` (`feed.quality.mode`) beside `Always show upgrades for me`, then the
mode's two values on one line, never live together: `Fixed minimum` (live in the fixed mode only) |
`Quality floor` (`Floor` until feedback-24; live in the two matching modes only). Then the closing
line `In force now: Quality: Rare+`: the filter bar's label for where you stand, naming the situation
when its own setting overrides the feed's mode. It repaints with every write. Under it, a line points
at the Situations tab's Quality column, where a situation sets its own.

**Items:** two subsections. **Item kinds:** Gear only | Include tier tokens (`Tier tokens` until item 020). **Item level:** Minimum item
level alone on its line, then its two values, each live in its mode only: Absolute minimum | Levels
under my average.

**Retention:** two subsections. **History:** Keep history for (7 to 180 days or Never delete,
default 30; account-wide, which its tooltip opens by saying, `Account-wide: shared by every profile.`,
since item 020; a shorter time that would delete groups asks first, and No puts the
previous time back), with **Clear history** beside it (feedback-15 spec §3, DW-Q3: an action, not a
setting, so no schema row; Keep history for's `pairWith` partner in `settings/PageEditors.lua`; it
asks first, `NS.History.AskClear`, and Yes empties the log on every character, or test mode's or a
simulation's session-only log while one is on). Window › Layout's until feedback-24. **Session:**
Clear this session's drops on boss kill (`Clear on boss kill` until item 020). (Show my own loot in Group drops is retired: Drops always lists your own drops,
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

**Sending:** the two per-send switches on one line, Ask once | Edit before sending, then Announce
channel | Offer transmog asks (`messages.transmogAsk`; the `Ask for transmog` checkbox until
feedback-24, the label its template's: on, also offer an ask, with the Ask for transmog template, on
a drop that is no gain for you but whose look you have not collected). Item 020 (DRO-L08) set this
order; until then it read Offer transmog asks | Ask once, then Edit before sending | Announce channel. **Auto-ask:** Ask automatically
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

**Layout:** two subsections since item 020 (DRO-L07; the row order unchanged). **Mode:** Window
layout (`window.mode`, `Layout` until feedback-24, the tab's own name; Full or Compact, compact
spec §1: the window's layout, also switched by the title-bar toggle, `/dw compact` and `/dw full`) |
Compact view when it auto-opens in a run (`Open in compact view during a run` until item 020; on by
default: an auto-open inside a dungeon, raid, key or delve opens compact until the run ends, and the
title-bar toggle's tooltip names it while it holds). **Tables:** Row height (18 by default, both tabs of
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
value; all unticked is View: All, the default, DW-A1, and since item 020 each tooltip ends `With none
ticked, a fresh tab lists every drop.`). **Content and sort:** Content (the Drops
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
swatch, its alpha kept; an item with no quality known keeps the swatch). The block's skin companion,
**Use the skin's border** (on; `icons.borderStyleFromSkin`, the composer's `fromSkin = "icon"`,
DW-03), draws the border in the skin's icon border style and thickness and dims Border style and
Border thickness while it is on; the color rows are always the player's. Style, thickness, Color by
item quality and Use the skin's border are dimmed while Show border is off; the color pair never is. Every change
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
Proc (flipbook) by default since DW-03, owner ruling D-18, Pixel border until then), then Main spec
color | Off-spec color (color swatches with alpha; `#19FF19` and `#3FC7EB`, opaque) and below them **Use class color (main spec)** | **Use
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
