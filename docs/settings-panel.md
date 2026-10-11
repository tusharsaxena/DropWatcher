# Settings panel — Ka0s Drop Watcher

Built on LibKa0s-Options from the descriptor in `settings/OptionsSetup.lua`. The category registers
eagerly at `OnEnable`; each page's body builds on its first show (options-ui-§1/§5).

Every page after the landing page draws a tab strip, one tab per `group` of the rows whose `page` is
its key (`Settings.RowsForPage`, the descriptor's `rowsForPage`), in declaration order
(options-ui-§13). Each page's Defaults button resets that page's rows and no other page's; on
General it is the global reset instead. A row with nothing to do is drawn dimmed (its `disabledIf`
predicate, `settings/SchemaRows.lua`), never hidden, and keeps its value.

| Page | Covers |
|---|---|
| Ka0s Drop Watcher (landing) | The logo, the TOC notes line and the slash command list, drawn by the library's `BuildLandingPage` |
| General | `Master controls`, `When to show`, `Simulation` |
| Feed | `Quality`, `Filters` |
| Comparison | `Scoring`, `Weights`, `Preferences` |
| Trade | `Rules`, `Timers` |
| Messages | `Templates`, `Sending`, `Auto-ask` |
| Window | `Columns`, `Layout`, `Toast` |
| Profiles | AceDBOptions: switch, copy, reset and delete profiles |

`settings/Panel.lua` registers General, `settings/Pages.lua` the five after it,
`settings/Profiles.lua` the last. Three tabs and one closing line have no row the flow engine can
draw; they are host tabs and an `afterGroup` hook handed to the library's tabbed renderer
(`settings/PageEditors.lua`, over the pure `settings/Editors.lua`).

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

## General → When to show

The master `autoOpen` row (Auto-open the window), then one block per situation under the
situation's name: `Track` and `Auto-open`, then `Quality` (`Use global` or a mode of its own)
(design spec §6.1). An untracked situation's `Auto-open` and `Quality` are dimmed, and every
situation's `Auto-open` is dimmed while the master row is off. The design's grid (situations by
setting) has no LibKa0s composer: `ChoiceGrid` draws one choice per row over one value list, and a
situation's line holds two checkboxes and a dropdown. So the tab draws one block per situation, as
the plan's fallback says, and a LibKa0s issue asking for a grid composer is filed as [LibKa0s#50](https://github.com/tusharsaxena/LibKa0s/issues/50).

## General → Simulation

One slider, `Simulation step delay` (`sim.stepDelay`, feedback-2 spec §8, DW-A7): the seconds the
simulator's automatic run (`/dw sim run`, the simulation panel's Run all) waits between steps, 0.5
to 10 in steps of 0.5, 2 by default. `/dw set sim.stepDelay <n>` reaches it too (the slash parser
clamps a number outside the range to it). A change takes effect from the next step of a running
timeline, and the panel's Run all tooltip names the current delay.

## Feed

**Quality:** `Minimum quality` (`feed.quality.mode`), `Fixed minimum` (live in the fixed mode only),
`Floor` (live in the two matching modes only), `Always show upgrades for me`, then the closing line
`In force now: Quality: Rare+`: the filter bar's label for where you stand, naming the situation
when its own setting overrides the feed's mode. It repaints with every write.

**Filters:** View: Interesting, View: Likely tradeable, View: Usable by me and View: Upgrade for me
(the View a fresh tab opens on, one checkbox per value; all unticked is View: All, the default,
DW-A1), Content and Sort (what a fresh tab starts with), Gear only, Tier tokens, Minimum item level
with its absolute and relative values (each live in its mode only), Show my own loot in Group drops,
Clear on boss kill.

## Comparison

**Scoring:** Score with, Sidegrade band, Compare against items in my bags, Protect heirlooms.

**Weights** and **Preferences** edit the two per-spec maps (`comparison.weights`,
`comparison.undesired`). Each opens with a secondary strip of your class's specs (options-ui-§13:
session state in `ctx.activeSubTab`, keyed by the tab, never stored), on your own spec first.
Weights draws a slider (0 to 5) per stat: the spec's primary stat, Stamina and the four secondaries,
keyed by `GetItemStats`' own stat keys; 0 leaves a stat out. Under the sliders, **Import a Pawn
scale** takes a Pawn scale string (`( Pawn: v1: "name": Key=value, ... )`): Enter replaces the
weights of the spec on screen, the chat says how many came in and which Pawn keys are not scored,
and a string that is not Pawn's writes nothing and says why. Preferences draws a checkbox per weapon
type your class's loot comes in, then Shields where a spec carries one; a ticked type is never
called an upgrade for that spec. Every change writes the whole map through the seam, a fresh table
each time.

## Trade

**Rules:** the loot rule per situation (`trade.rules.<situation>`). **Timers:** Warn before a trade
window closes. (Likely tradeable only moved to Feed › Filters as View: Likely tradeable, DW-A1.)

## Messages

**Templates** (board 08): the token chips (`{player}` … `{mygain}`, each with what it fills in);
clicking one puts it at the cursor of the message you last edited and stores it. Then the four
editors, Ask, Ask for transmog, Offer and Announce: Enter (or the box's Okay) stores the text through the seam, which
refuses an empty one, and each label counts the template's bytes against 255 as you type. Then the
preview of the message being edited, written for a real drop when the feed has one that fits (an
upgrade for you for an ask, one whose look you have not collected for the transmog ask, your own
drop and its best candidate for an offer) and for a sample over your own
gear otherwise (since DW-84): who it goes to, the text as sent, its length, and a red note for a text past
the limit or an unknown token. Reset templates puts the four back.

**Sending:** Ask for transmog (off: also offer an ask, with the For transmog template, on a drop
that is no gain for you but whose look you have not collected), Edit before sending, Ask once,
Announce channel. **Auto-ask:** Ask automatically, then
its delay and least gain, live only while it is on. Turning Ask automatically on the first time
prints auto-ask's one-time notice; turning it off cancels the asks waiting to go.

## Window

**Columns:** a checkbox per optional column (My eq among them since DW-83). **Layout:** Layout (Full or Compact, compact spec §1: the window's layout, also switched by the title-bar toggle, `/dw compact` and `/dw full`), Open in compact view during a run (on by default: an auto-open inside a dungeon, raid, key or delve opens compact until the run ends), Row height (18 by default, all three
tabs), Font size (all the way left, 0, is Default: the template's own size, like Ka0s Loot History's table; DW-A8), Keep history
for (7 to 180 days or Never delete, default 30; account-wide; a shorter time that would delete groups
asks first, and No puts the previous time back). **Toast:** Show a toast, then its least gain, duration, combat and sound
rows, live only while it is on.
