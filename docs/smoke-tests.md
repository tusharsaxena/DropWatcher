# Smoke tests — Ka0s Drop Watcher

The in-client checks the headless suite cannot make: what the real client draws, what its events
really carry, and what Blizzard's restrictions really allow. Run them on a clean `/reload`, with
debug logging off unless a check says to turn it on (`/dw debug on`). Record each result on its
`Result:` line with the date, the client build and pass or fail (and what was seen when it failed).
IDs are `<THEME>-<n>`: a new check takes the next free number in its theme, and a retired number is
never reused. A number marked *reserved* is promised to the plan item named beside it, which writes
the check when its feature lands. These checks are the owner's to run; an agent never marks one
passed.

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1..4 | Install | Load, reload, first run, the logo; the re-vendored LibKa0s (INSTALL-4, DW-P22) |
| SLASH-1..7 | Slash | `/dw` and `/dropwatcher`, help, the window verbs (SLASH-1..3); the feature verbs of design spec §12.3 (SLASH-4..6, DW-42); each root reaching its own addon with the collection loaded (SLASH-7, review 2026-10-14) |
| PANEL-1..8 | Settings panel | Landing page, General → Master controls, the Defaults button (PANEL-1..3); the pages of design spec §12.2: General → When to show and Feed (PANEL-4), Comparison (PANEL-5), Messages (PANEL-6), DW-41; the rows that act on the feed, the verdict, the sends and the table (PANEL-7); When to show's table never riding a released frame (PANEL-8, DW-P21) |
| PROFILE-1..3 | Profiles | The Profiles page, the `profile` verb, and the settings rows kept per profile (PROFILE-3, DW-40) |
| STATE-1..5 | State | Enable/disable, lock, test mode (STATE-3); test mode with real items, History test data and no trailing ellipses (STATE-4, DW-84); one refusal line while disabled, inert across combat and zones (STATE-5, DW-P16) |
| COMPAT-1..4 | Compat | The client facts `core/Compat.lua` relies on (DW-20); the optional-addon probe (COMPAT-4, DW-P20) |
| COMBAT-1..3 | Combat | Loot reads mid-encounter, restrictions, test mode ended by combat |
| DIAG-1..4 | Diagnostics | The debug console, the report, perf and the perf-hold refusal (DIAG-1..2); the State and Scoring sections of design spec §13 (DIAG-3, DW-43); the perf nesting confirmed by a capture (DIAG-4, DW-P24) |
| DEGRADED-1..2 | Degraded | The install with LibKa0s missing; the toast's close degrading to nothing (DEGRADED-2, DW-P21) |
| FEED-1..78 | Feed | The loot parser (FEED-1, DW-25), the feed (FEED-2..6, DW-27), a Devourer looter (FEED-7, DW-10/DW-11), the window's shell (FEED-8..9, DW-30), the Drops table (the Group drops table until DW-E3; FEED-10..12, DW-31), the detail card (FEED-13..15, DW-32), the header beside Loot History (FEED-16, DW-81), the filter bar beside it (FEED-17, DW-82) and the equipment columns, the two new filters and auto-open on every drop (FEED-18, DW-83); the two-Yoke regression, nothing hidden or refused silently and `n drops · m shown` (FEED-19, DW-A0); View: All by default, the checkboxes as multi-select View values, the bullet tooltip and the settings migration (FEED-20, DW-A1); item tooltips beside the window (FEED-21, DW-A2); group headers naming the party, class-colored, on Drops and History (FEED-22, DW-A3); the Character dropdown, Current by default, filtering History by who saw each drop (FEED-23, DW-A4); the tables' font and row height beside Loot History's, on both tabs (FEED-24, DW-A8); your own drops under the same group headers, and a tooltip that never covers the docked Offer panel (FEED-25, DW-A9) every row tooltip at the row's top right (FEED-26, DW-B2) and the filter bar's tooltips above their controls (FEED-27, DW-B1); group headers naming the instance, the boss, the difficulty and only your character (FEED-28, DW-B4); the filter bar's tooltips below their controls near the top of the screen (FEED-29, DW-B5; its tab counts retired by DW-E3); what a delve's header names, and whether the client gives its tier (FEED-30, DW-B4); one tone per verdict in Me and Them, the arrow before the number (FEED-31, DW-D0); the action buttons colored by whose move it is, full and compact, your own drops' Offer and the Offer panel (FEED-32, DW-D1); nothing dismisses or hides a drop (FEED-33, DW-D2); the Type column's values (FEED-34, DW-D3); gold column labels, the search box spanning to the window's edge and the least width equal to the default in both layouts (FEED-35..37, DW-D4); the gold header chevron (FEED-38, DW-E0), the row chevron and indent (FEED-39, DW-E0), the Actions width (FEED-40, DW-E0), the Trade window column on every drop, ticking each second (FEED-41, DW-E1), your own drop's Trade count (FEED-42, DW-E2), `(Details)` (`(Multiple)` until DW-F3) and the keep? rule (FEED-43, DW-E2), Offer and its tones (FEED-44, DW-E2), the strip and Post (FEED-45, DW-E3), the tabs Drops and History (FEED-46, DW-E3), the least width and the compact card's line 2 (FEED-47, DW-E4); the Trade window column fitted to its widest answer (FEED-48, DW-F0), My eq merged into Me and Their eq into Them, on Drops, History and compact line 3 (FEED-49, DW-F1), the retired My eq and Their eq toggles (FEED-50, DW-F1), Offer in cyan everywhere (FEED-51, DW-F2), the (Details) tooltip's lines and fit (FEED-52, DW-F3), no glyph boxes in any tooltip (FEED-53, DW-F3), the least width 1038 (FEED-54, DW-F1), no glyph boxes outside tooltips: the toast, the detail card and the Offer panel (FEED-55, DW-F5); the Offer panel's Their eq column and no Trade button (FEED-56, DW-G0), its rows without the class bar and striped (FEED-57, DW-G0), an icon on every action button (FEED-58, DW-G1), Trade `No` in red (FEED-59, DW-G2), `Name [YOU]` (FEED-60, DW-G2), `Upgrade for N` and Trade without its count (FEED-61, DW-G2), columnar gear tooltips with the table's arrows (FEED-62, DW-G3), Post above Sort and Scan group beside it (FEED-63, DW-G4), the empty state's buttons centered (FEED-64, DW-G4); General › When to show as one table, a line per situation (FEED-65, DW-H0); the toast as four rows beside a four-row icon, its colors, verdicts, trade reason and right-click close (FEED-66, DW-I0); the filled downgrade glyph `▼` (FEED-67, DW-J0), Offer's `external-link` icon (FEED-68, DW-J1), the compact cards' new lines with no countdown (FEED-69, DW-J2), Sort on the tab's strip beside Scan group, Post and Clear history (FEED-70, DW-J3); no `(…)` after a compact card's name while Them reads `…`, Them cut at the card's right inset (FEED-71, DW-K0), the gray `No action` button wherever a drop has no action (FEED-72, DW-K1); History's outcomes in the action buttons' colors (FEED-73, DW-L0); no `0 shown` header where Character or Content left a group empty (FEED-74, DW-L1); each tab's default filters (FEED-75, DW-M0); no Lua error from a gear tooltip in combat (FEED-76, DW-N0); Content per tab (FEED-77, DW-Q1); one footer button kind and Expand all / Collapse all on both tabs and layouts (FEED-78, DW-Q2) |
| ROSTER-1..3 | Roster | The group's members and the name resolver (DW-22); the roster kept current when another handler on its shared event raises (ROSTER-3, DW-P18) |
| ITEM-1..5 | Item facts | The item readers' shapes and the track ids (ITEM-1..2, DW-23); a real drop read at its real level and quality, and the `drops` diagnostics line (ITEM-3, DW-80, BUG-1); the real game tooltip on every item (ITEM-4, DW-80, BUG-2); a multi-stat item judged for every primary stat (ITEM-5, the Fireproof Drape fix) |
| GEAR-1..2 | Gear | Your gear snapshot, the owned best and the rebuild events (DW-24) |
| INSPECT-1..4 | Inspect | The inspect broker: warm-up and spacing, the waits and the cache, courtesy and combat, the item level (DW-26) |
| TRADE-1..6 | Trade | Trade estimates and the raid rule (TRADE-1..4, DW-14), timers (TRADE-5, DW-28), the trade helper (TRADE-6, DW-29) |
| ASK-1..10 | Ask | Sending and its confirmation, the queue and its flush, cancel, a whisper during an encounter (ASK-1..4, DW-2A); your own drops, the Offer panel and Post my tradeables (ASK-5..7, DW-33; on Drops since DW-E2/DW-E3); auto-ask (ASK-8, DW-54); auto-ask after leaving an encounter (ASK-9, DW-62); a stored announce channel refused without its group (ASK-10, DW-P17) |
| SIT-1..5 | Situations | Where the addon is active (DW-13) |
| QUAL-1..4 | Quality | The minimum-quality gate (DW-12) |
| SCORE-1..3 | Scoring | The Pawn adapter (SCORE-1), your weights and the Pawn scale import (SCORE-2), DW-50; Pawn counts only once initialized (SCORE-3), DW-62 |
| HIST-1..6 | [History](#history) | A completed trade recorded (HIST-1), the History tab across a reload, its row menu and Clear history (HIST-2), DW-51, and the Drops tab across a reload (HIST-2, DW-Q0); Keep history for, its confirmation, the login prune and step 4 (HIST-3), DW-A5; the prune after a disabled start and a stale confirmation (HIST-4), DW-A9; the undone Expired and This instance across a reload (HIST-5), DW-Q0; Clear history in Settings, off the footers (HIST-6), DW-Q3 |
| TOAST-1..4 | [Toast](#toast) | The opt-in upgrade toast: shown, paused, held in combat, placed in test mode and its sound (TOAST-1), DW-52; it leaves with its drop and with its switch (TOAST-2) and fires for an empty slot (TOAST-3), DW-62; its close mark with the library present (TOAST-4, DW-P21) |
| TMOG-1 | [Transmog](#transmog) | The look chip and the opt-in For transmog ask, with and without CanIMogIt (TMOG-1), DW-53 |
| SIM-1..13 | [Simulator](#simulator) | Start and stop, the refusals, the automatic stop, nothing sent and saved history untouched (SIM-1, DW-70); a full `key` run and a `raid` run with a large roster, with the `SIMULATION` title text, the footer and the `sim` diagnostics section (SIM-2..3, DW-73), the inspect replies, the lockdown queue and its flush (SIM-4, DW-72), your own drops' trade windows and a simulated trade into History (SIM-5, DW-72), the item pool from the Encounter Journal and its own-gear fallback (SIM-6, DW-71), the verbs' refusals and the automatic stop end to end (SIM-7, DW-73), real loot during a simulation kept and saved (SIM-8), a sim run that fills the window under the default filters, every step in chat, Raid Finder's instance chat and you online in a raid (SIM-9, DW-90), the step panel: its highlight following the run, a click ahead running the steps in between, Pause and Resume, Restart and Stop, the picker (SIM-10, DW-91), the step delay (SIM-11, DW-A7), the loot step saying where its drops went and the window reconciling with it (SIM-12, DW-B0), the loot step honoring test mode's feed (SIM-13, DW-B5; `feed.showOwn` retired by DW-E2) |
| COMPACT-1..7 | [Compact](#compact) | Compact mode (compact spec, M12): the title-bar toggle, `/dw compact` and `/dw full` swap the layouts, each remembering its own size and position, and the old preset migrates (COMPACT-1, DW-C0); the Drops cards in every state from test mode and `/dw sim`, the stacked detail card and the same drops in both layouts (COMPACT-2, DW-C2, DW-C5); your own cards, the countdown, Offer and the strip, the Offer panel docked beside (COMPACT-3, DW-C3, on Drops since DW-E3); History cards and their outcomes (COMPACT-4, DW-C3); the compact chrome and the Filters ▾ menu matching the full bar's choices (COMPACT-5, DW-C4); Open in compact view during a run opens an auto-open inside a key compact and the stored layout after it ends (COMPACT-6, DW-C0); the card tooltips at the card's top right, outside the window (COMPACT-7, DW-C2) |
| LOC-1..2 | [Non-English client](#non-english-client) | What a deDE or frFR client changes: the loot lines, the trade-time decode, the track names (spec §15); the completed enUS catalog reading the same (LOC-2, DW-P19) |

## Before you start

- Install the addon folder as `Interface\AddOns\DropWatcher` and `/reload`.
- Have a second character or a friend available for the trade, ask and offer checks.
- Keep the debug console closed unless a check opens it; `/dw debug` opens it.

## Install

**INSTALL-1. Loads clean.** `/reload` with only Drop Watcher enabled → no Lua error, no chat line at
login, the addon listed in the AddOns list with the gem logo. Result:

**INSTALL-2. Minimap button and broker.** Look at the minimap → the gem button is there; hover it →
the tooltip reads `Ka0s Drop Watcher  v0.1.0`, `Enabled: Yes`, `Locked`, `Test mode`, then the two
click hints. A missing icon (a blank or green square) is the failure. Result:

**INSTALL-3. Reload keeps settings.** Set Master scale to 1.25 and lock the window, `/reload` →
both are kept; the debug flag and test mode are not (session-only). Result:

**INSTALL-4. The re-vendored LibKa0s (DW-P22).** The DW-P22 re-vendor has landed (`ff567d3`). `/reload`
→ no Lua error and no new chat line; `/dump LibStub.minors["LibKa0s-Perf-1.0"]` → `15`. `/dw diagnostics`
and `/dw perf` open as DIAG-1 and DIAG-2 describe. A lower minor means an older copy of the library
loaded first from another addon; record which addons were enabled. Result:

## Slash

**SLASH-1. Help.** `/dw help` and `/dropwatcher help` → the same index, gold commands, white
descriptions, every row present; `/dw` alone opens the settings panel. Result:

**SLASH-2. Window verbs.** `/dw show`, `/dw hide`, `/dw toggle` → the window opens, closes and
toggles; Escape closes it too. Result:

**SLASH-3. Lock verbs.** `/dw lock` → the window cannot be dragged by its title bar or resized from
its corner; `/dw unlock` → both work again; the Lock frame box follows. Result:

**SLASH-4. Feed verbs.** In a group, `/dw scan` → `Inspecting n group members, one at a time.` and
the footer's inspect freshness moves as they are read. `/dw add <shift-click an item>` → `Added
[item] for you (drop n).` and the drop is on Drops with Offer in its Actions; `/dw add <item> <a
member's name>` → the drop is on Drops under that member; `/dw add <item> Nobody` → it shows, with no inspect asked.
`/dw clear` → `Cleared this session's drops.`, both tabs empty; with test mode on, its sample drops
stay. Result:

**SLASH-5. View verbs.** `/dw history` → the window opens on History, expanded even when it was
minimized; `/dw mine` → it opens on Drops (where your own drops are, since DW-E3 retired My drops),
the same way. `/dw compact` → `Compact view.` and the window narrows to its compact layout
(COMPACT-1); again → `Full view.`; `/dw full` → `Full view.` and stays full; the Window page's
Layout choice follows. `/dw situation` in a Heroic dungeon →
three lines: `Situation: Dungeon (dungeon) · Track yes · …`, then the inputs (in instance yes, type
party, difficulty 2); outdoors alone → `Solo (solo)`. Result:

**SLASH-6. Offer verb.** `/dw offer <one of your drops>` → the window opens on Drops with the
Offer panel docked for that drop. `/dw offer <a tradeable bag item the feed never saw>` → it is added
as your drop and the panel opens for it. `/dw offer <an item not in your bags>` → `[item] is not in
your bags.`; `/dw offer` alone → the usage line. While disabled, every one of these verbs answers
the one disabled line. Result:

**SLASH-7. Each root reaches its own addon (cross-addon census, review 2026-10-14).** Enable Drop
Watcher with as many other Ka0s addons as you have (QuickComms, and any others), `/reload`. Type each
root with `help`: `/dw`, `/dropwatcher`, then each other addon's own roots (`/qc`, `/quickcomms`, …)
→ each prints its own addon's help, under its own brand, and none is answered by another addon or by
the client's `Type /help for a listing`. Then Settings → AddOns → each addon is listed once, and each
multi-page addon's pages appear once each under it. Result:

## Settings panel

**PANEL-1. Landing page.** Settings → AddOns → Ka0s Drop Watcher → the logo once (not twice after
switching pages back and forth), the notes line, and the slash command list. Result:

**PANEL-2. Master controls.** General → the `Master controls` tab: Enable, General visibility,
Master scale, Master alpha, Lock frame, Debug console, Minimap button, Test mode, then Reset position
and Reset all settings. Each control changes the window at once. Result:

**PANEL-3. Defaults and Reset all.** Hide the minimap button, change the scale, press the header's
Defaults button and accept → the scale is back to 1.0 and the minimap button stays hidden. Result:

**PANEL-4. When to show and Feed.** The settings list shows General, Feed, Comparison, Trade,
Messages, Window and Profiles, in that order, and every page has a tab strip with the tabs of design
spec §12.2. General › When to show: Auto-open the window, then one block per situation under its
name (superseded by feedback-8, 2026-10-13: one table, a line per situation, FEED-65); untick Delve's Track → its Auto-open and Quality dim, tick it → they light; untick the master
row → every Auto-open dims. Feed › Quality: with Minimum quality `Fixed minimum` the Floor is dimmed;
switch to `Match each slot` → Fixed minimum dims, Floor lights, and the closing line reads
`In force now: Quality: Match slot`, as the window's filter bar does. In a dungeon whose Quality is
set on When to show, the line names it (`(Dungeon's own setting)`). Feed › Filters: the absolute and
relative item levels light only in their mode. Press Feed's Defaults → only Feed's rows go back
(a Trade value you changed stays). Result:

**PANEL-5. Comparison.** Comparison › Weights opens on your current spec in a strip of your class's
specs (no other class's), with a slider for your primary stat (no other primary), Stamina and the
four secondaries; set Haste to 1.5, switch spec in the strip, set it to 0.75, switch back → 1.5 is
kept, and `/dw get comparison.weights` reads `{2}`. Preferences: one checkbox per weapon type your
class uses (Shields only for a class with a shield spec); tick Daggers → `/dw get comparison.undesired`
reads `{1}`, and a dagger that drops afterwards reads `Doesn't want` for you, with the reason "You marked this item
type as not wanted for your spec." Comparison's Defaults clears both. The tabs, the strip and the
sliders cannot be used in combat (the page is covered). Result:

**PANEL-6. Messages.** Messages › Templates (board 08): the seven token chips, each with its tooltip;
the three editors with `n / 255` in their labels, counting as you type; the preview below names who
it goes to (a real drop's looter when the feed has one, else a placeholder) and follows the editor
you type in. Type `{bogus}` into Ask → the preview's status line shows it in red; press Enter → it is
stored and shown again on `/reload`. Clear a box and press Enter → refused, and the stored text comes
back. Click into Offer, then click `{item}` → it lands at the cursor and is stored. Reset templates →
all three back to the shipped wording. With test mode on, Ask in the window sends the text you
stored (printed). Sending and Auto-ask: Auto-ask's delay and least gain are dimmed until Ask
automatically is ticked. Window › Toast: its rows dim until Show a toast is ticked. Result:

**PANEL-7. Rows that act.** Feed › Filters: tick Clear on boss kill, loot some trash in a dungeon,
then kill a boss → the trash drops leave the table at the kill and the boss's loot fills its own
group; a wipe clears nothing. Comparison › Scoring: wearing an heirloom in a slot, a higher drop for
that slot reads `≈` for you, its reason "The slot holds an heirloom you protect, so it is a
sidegrade."; untick Protect heirlooms → it reads `▲`. Messages › Sending: tick Edit before sending,
press a row's Ask → the Edit message box opens with the ask filled in and nothing is sent until you
press Send; an Offer panel's Offer and Announce to group open the box with the offer's and the
announcement's text; Post my tradeables still posts at once. Window › Layout: drag Row height to 32
and Font size to 15 → the rows grow and their text with them, at once, on Drops and History.
Result:

**PANEL-8. When to show's table never rides a released frame (DW-P21).** Open General › When to show
→ the table, a line per situation. Without changing anything: close the Settings window, reopen it on
Feed → no situation table anywhere on Feed. Back to General › When to show → the table is there once.
Switch to Master controls and back three times, then open Comparison, Trade and Messages in turn →
the table shows only on When to show, never on another tab or page, never twice, never empty; toggle
one cell → it writes, and Defaults repaints it. No Lua error throughout. Result:

## Profiles

**PROFILE-1. The Profiles page.** Settings → Ka0s Drop Watcher → Profiles → AceDB's page draws;
create a profile, change the scale, switch back → each profile keeps its own scale. Result:

**PROFILE-2. The profile verb.** `/dw profile` lists the profiles; `/dw profile <name>` switches,
and works while the addon is disabled. Result:

**PROFILE-3. The settings rows.** `/dw list` → every setting of design spec §12.1 listed under its
page (general, feed, comparison, trade, messages, window), the two Comparison maps as `{0}`.
`/dw set feed.quality.fixed 4` → the filter bar reads `Quality: Epic+`; `/dw set feed.quality.mode
bogus` and `/dw set messages.announceChannel SAY` are refused and change nothing. `/reload` →
`/dw get feed.quality.fixed` still reads 4. Switch to a new profile → it reads 3; switch back → 4.
`/dw set global.history.retentionDays 60`, switch profile → still 60 (it is account-wide). On the
first login on this build, `/dw debug on` → one held `[Migrate] v1 -> v2` line. Result:

## State

**STATE-1. Disable stands everything down.** Open the window and turn test mode on, then
`/dw disable` → the window closes, test mode ends, `/dw show` and `/dw test` answer `Ka0s Drop Watcher
is disabled — enable it with /dw enable`; the minimap menu grays every entry but Enabled;
`/dw enable` → the window comes back. Result:

**STATE-2. Launcher menu.** Right-click the minimap button → Enabled, Locked, Test mode, Show window,
each ticking the state it shows and toggling it. Result:

**STATE-3. Test mode populates every drop state.** Solo, outside an instance and out of combat, open the
window with no drop yet → the Drops tab shows `No drops yet`,
`Loot your group receives appears here, grouped by boss.` and two buttons, each with a tooltip; Scan group
answers in chat. Click Preview with test data → test mode turns on, bright-red `TEST MODE` text sits beside
the title and an amber banner (`Nothing is whispered. Combat ends it.`) above the table, both with the same
tooltip; View reads All. Two groups show, `Placeholder boss` open and `Placeholder key run` collapsed;
expand it (since DW-84 the items are real: see STATE-4). Across the rows: Me shows ▲ ≈ ▼, Can't use, Not
wanted and `?`; Them shows ▲ ≈ ▼, Can't use and `?`; Trade shows Yes, Likely, Unknown and No; Them's gear part (Their eq until DW-F1)
shows worn item levels, `empty`, `…`, `range`, `combat`, `!` and `–`, the read's age on hover; Actions shows Ask, Queued,
Asked, Retry and a dash (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72). Hover a dozen cells → each has a reason, none is blank, and the text fits its
column at the default size, which is also the least (DW-D4). Expand the head-slot row Seta looted → the
detail card names the looter's spec and `inspected 40s ago`. Click Ask on a ready row → chat prints
`Test mode, not sent: …` and the button reads Asked; nothing is whispered. Your own four samples are
Drops rows too (since DW-E2; My drops is retired): their Trade window countdowns move each second (one in
bold amber, ending soon, one estimated with `~`, one `No limit (BoE)`, one not tradeable), and Offer on the
trinket opens the panel with `+14 UPGRADE`, `+6 UPGRADE`, `EQUAL`, `NO UPGRADE`, `CAN'T USE`, `CHECKING` and
`UNAVAILABLE`; Offer and the strip's Post my tradeables print and send nothing. Drag the window and minimize it: the `TEST MODE` text stays on the title bar.
`/dw test` → the text, the banner and the rows go, View is back to Interesting and the empty state returns.
Result:

**STATE-4. Test mode shows real items, History test data and no trailing ellipsis (DW-84).** Solo, outside
an instance and out of combat, `/dw test` → for a moment the Drops tab may read
`Gathering real items for test mode.`, then the rows fill. Every row's icon is a real item's (no red
question mark anywhere: Item, the Me and Them icons (My eq and Their eq until DW-F1), the detail card, the Offer panel), the names are
real items of the current season's dungeons (or your own gear, with the chat line
`The Encounter Journal gave no items, so test mode shows your own gear instead.`), each in its slot (the
head row a helm, the ring rows rings), and the Ilvl column shows each item's real level: hover an item → the
game's own tooltip agrees with it. Them shows a real worn item and its level for the inspected looters.
The looter names stay invented (Seta, Butterz, …). Every state of STATE-3 is still there. Open History → two
groups, `Placeholder key run` (a day ago) and `Placeholder boss` (two hours ago), whose rows read Seen,
Asked, Offered, Received, Traded away, Expired and Declined, over real items. `/dw test` off → the History
tab shows your own kept groups again, untouched (none of the samples among them, after a `/reload` too). On
Drops your own sample's button reads `Offer`, with no ellipsis; an expired row's Trade window reads `Window
passed` in full (its tooltip still says `Not tradeable` and why); a `(Details)` tooltip still being read
says `1 checking`, the Offer panel's pill `CHECKING`. Look over every button and cell at the default width (also the least,
since DW-D4) → none ends in an ellipsis or is cut short. Then in a Heroic dungeon (an auto-open situation),
out of combat, with the window closed: `/dw test` → the window opens with the test rows; `/dw test` again →
the window closes (test mode opened it, even though its drops arrived first). Result:

**STATE-5. One refusal line while disabled (DW-P16).** `/dw disable` (the refusal comes before any
other check, so no drop is needed). Run
`/run LibStub("AceAddon-3.0"):GetAddon("DropWatcher").PressAsk(1)` and then `/dw scan` → each prints
exactly `Ka0s Drop Watcher is disabled — enable it with /dw enable`, byte for byte the same, never
inside `Not asked: …` and never `The addon is disabled.`. Then enter and leave combat with a training
dummy and travel to another zone without reloading → no `[DW]` chat line and no window, and nothing
in the feed changes (review C-01's in-client half). `/dw enable` after. Result:

## Compat

The seam's decisions are headless-tested (`test_compat`), on the mock's idea of the client. These
checks confirm the client facts behind them, with `/dump` in the chat box; nothing in them needs the
addon's window. Record what the client printed on each `Result:` line.

**COMPAT-1. Enum names.** `/dump Enum.TooltipDataLineType.TradeTimeRemaining,
Enum.TooltipDataLineType.ItemLevel, Enum.TooltipDataLineType.ItemUpgradeLevel` → three numbers;
`/dump Enum.AddOnRestrictionState` → a table with `Inactive`, `Activating` and `Active`;
`/dump C_RestrictedActions.IsAddOnRestrictionActive ~= nil` → `true`. A nil anywhere is the
failure: name the member that is missing. Result:

**COMPAT-2. The tooltip lines.** Loot a tradeable BoP item in a dungeon and note its bag and slot,
then `/dump C_TooltipInfo.GetBagItem(<bag>, <slot>)` → one line whose `type` is the
`TradeTimeRemaining` number from COMPAT-1 and whose `leftText` is the trade sentence ending in a
duration such as `1 hour 59 min`. Then `/dump C_TooltipInfo.GetInventoryItem("player", 1)` → an
`ItemLevel` line; record whether it carries a numeric `itemLevel` field. And
`/dump C_Item.GetItemUpgradeInfo(GetInventoryItemLink("player", 1))` → a table with
`trackString`, `currentLevel` and `maxLevel` for a tracked helm. Result:

**COMPAT-3. Pawn.** With Pawn installed and loaded, `/dump type(PawnIsInitialized), PawnIsInitialized`
→ `boolean`, `true`. Without Pawn → `nil`. Result:

**COMPAT-4. The optional-addon probe (DW-P20).** Pawn installed and enabled, CanIMogIt not (or the
other way round). `/reload`, then `/dw debug on` (the line is said once, as logging turns on) → the
console's `[Init]` line reads `optional: Pawn loaded, CanIMogIt absent`; `/dw diagnostics` → its
`integrations` section reads `optional: Pawn=true CanIMogIt=false`. Both agree with the AddOns list; swap which addon is enabled and they follow. A
line that names neither, or one reading `unavailable` or `unreadable`, is the failure. Result:

## Combat

**COMBAT-1. Loot lines mid-encounter.** The question the design leaves open (spec §15): is
`CHAT_MSG_LOOT` readable during an encounter, or does it arrive secret? `/dw debug on`, then kill a
boss in a dungeon or raid with personal loot, and have a trash mob drop something mid-pull if one
will. → each loot line someone receives shows a `[PARSE]` line naming the kind (`loot`, `bonus`
or `pushed`), the link, the quantity and the looter, the boss's loot included. Then
`/dw diagnostics` → the `feed: parser hits=… ignored=… rejected=… secret=…` line. Record whether
`secret` is above 0, and if so whether the secret lines came during the pull (between the pull and
the kill) or after it: a `[PARSE] loot line skipped: secret` line marks each. A Mythic+ key run
(trash loot mid-key, the chest at the end) is the second place to record it. Result:

**COMBAT-2. What the restrictions stop.** `/dw debug on`, then pull a boss in a normal dungeon →
the console shows a `RES` line naming `encounter` and `canSendChat` false at the pull, and one back
to `none` when the boss dies; `/dw diagnostics` mid-fight → `restrictions: reason=encounter
canSendChat=false canInspect=false canTrade=false`. Outside any encounter but in combat →
`reason=combat canSendChat=true`. Record which `active` reasons the report lists in a dungeon out of
combat (the design expects `map` alone), and in a Mythic+ key between pulls (is `challengeMode`
there, and does `/dump C_ChatInfo.InChatMessagingLockdown()` say true?). With the window open
(`/dw show`) through the same pull → the title bar shows the orange lock badge reading `Encounter`
from the pull until the boss dies, `Combat` while fighting trash, and no badge out of combat; hovering it says which restriction is
active, and once an ask is queued (ASK-2) it reads `Encounter · 1 queued` and its tooltip lists the
ask. Result:

**COMBAT-3. Combat ends test mode.** Turn test mode on, pull a training dummy → test mode ends with
the chat line `Test mode ended: you entered combat.`; `/dw test` in combat is refused. With General
visibility `Only in combat`, the open window shows on the pull and hides when combat ends. Result:

## Diagnostics

**DIAG-1. The report.** `/dw diagnostics` → the console opens with both markers naming Ka0s Drop
Watcher and the `identity`, `settings`, `window`, `registration` and `integrations` sections; logging
is on afterwards. `/dw debug diagnostics` writes the same report again below the first. Result:

**DIAG-2. Perf.** `/dw perf` → the step panel opens with its own close mark; run A, B and finish →
the report lists `window.refresh`, and `parse` when a loot line arrived during the run. During a
suspended run (the addon stood down by the `perf` hold, `enabled` still on), `/dw scan`, `/dw test` and
`/dw sim start dungeon` each answer `Not available during a performance capture.` and never `is
disabled — enable it with /dw enable`. Result:

**DIAG-3. State and Scoring.** In a dungeon, `/dw diagnostics` → `state: enabled=true
situation=dungeon testMode=false restriction=none queuedSends=0`; pull a boss and run it again →
`restriction=encounter`. The `scoring:` lines name the scorer setting, `pawn ready=true scale=<your
spec's Pawn scale>` with Pawn installed (`ready=false scale=none` without it), and `retries pending=0
spent=0 timer=off` out of loot. Result:

**DIAG-4. Perf nesting confirmed by a capture (DW-P24, review C-04).** DW-P22 (LibKa0s Perf 15,
`ff567d3`) and DW-P24 (`evaluate` and `quality.gate` declared within `feed.add`, `917449f`) have landed. In a
dungeon, in a group: the standard two-arm `/dw perf` protocol, the clean arm first and the suspended
arm second, no `/reload` between the arms, with at least one boss kill and its loot in the clean arm.
→ the report's nesting lines read `evaluate observed inside feed.add and at top level` and
`quality.gate observed inside feed.add and at top level` (top level is an item judged later, once it
loads). The failure is any `declares itself within feed.add — not observed` or `… but was observed
at top level` line. Read the bucket figures, not the frame-time delta. Hand the report and the JSON
dump to `/dev-copilot:wow-perf-analysis`, which records the capture as
`docs/perf-analysis/<YYYYMMDD-HHMMSS>/`; record that folder here. Result:

## Degraded

**DEGRADED-1. LibKa0s missing.** Rename `libs\LibKa0s` and `/reload` → no Lua error; one chat line
says the library is missing; `/dw show` opens the window without the skin; `/dw disable` and
`/dw enable` still work; `/dw list` says the settings CLI is unavailable. Restore the folder after.
Result:

**DEGRADED-2. The toast's close degrades to nothing (DW-P21).** With the library present, turn
Settings › Window › Toast › Show a toast on (it is saved). Rename `libs\LibKa0s` as in DEGRADED-1,
`/reload`, then `/dw test` → the test toast shows with Ask in its top-right corner and no close control at all:
no `×` text button. Right-click the toast → it closes. With the library restored and `/reload` → the
skinned close mark is back at the corner and Ask sits to its left. Restore the folder after. Result:

## Feed

The parser's patterns, the rebuild and the secret guards are headless-tested (`test_loot_parser`),
and the feed's dedupe, grouping and gate order are too (`test_feed`); FEED-1 confirms the client's
real lines and FEED-2..6 what the feed makes of the client's real events, read through `/dw debug on`
and the `feed:` lines of `/dw diagnostics`, FEED-10..12 how the Drops table draws them
(DW-31), FEED-13..15 the detail card a row expands into (DW-32), FEED-16 the title bar side by side with Ka0s Loot History's (DW-81), FEED-17 the filter bar beside Loot History's (DW-82), FEED-18 My eq, Their eq, Usable by me, Upgrade for me and auto-open on every drop (DW-83), FEED-19 the two-Yoke regression (DW-A0), FEED-20 the multi-select View (DW-A1), FEED-21 item tooltips beside the window (DW-A2), FEED-22 the party named in every group header (DW-A3), FEED-23 the Character dropdown (DW-A4), FEED-24 the tables' font and row height beside Loot History's (DW-A8), and FEED-25 your own drops' group headers and the tooltip beside the docked Offer panel (DW-A9), FEED-26 every row tooltip at the row's top right (DW-B2), FEED-27 the filter bar's tooltips above their controls (DW-B1), FEED-28 the group headers' instance, boss, difficulty and recorder (DW-B4), FEED-29 the filter bar's tooltips near the top of the screen (DW-B5), FEED-30 a delve's header and its tier (DW-B4), FEED-31..37 feedback-4's tones, colors, Type column, labels, search box and least width (DW-D0..DW-D4), and FEED-38..47 feedback-5's chevrons and indent, Actions width, Trade window column, your own drops on Drops, the strip, the two tabs and the least width (DW-E0..DW-E4), and FEED-48..54 feedback-6's narrower Trade window, the merged Me and Them cells, the retired toggles, Offer in cyan, the (Details) tooltip, tooltips without glyph boxes and the least width 1038 (DW-F0..DW-F3). FEED-7 checks the class data (DW-10, judged by DW-11) for the one spec the client data could not
settle.

**FEED-1. The parser on real loot.** `/dw debug on`, in a party with at least one player from
another realm, and run a dungeon. → For every loot line chat shows, the console shows one `[PARSE]`
line: your own loot as `loot <link> x1 by <You>-<YourRealm> (Player-…)`, a stack you loot as `x<n>`
with the link stopping before the count, a member's loot as `by <Name>-<Realm> (Player-…)` with the
realm spelled as the `roster:` lines spell it, a bonus roll as `bonus`, an item handed to you by a
quest or a container as `pushed`. Upgrading an item at the upgrade vendor shows `loot line skipped:
rejected` and no loot line; so does crafting an item. Roll lines (`… has selected Need for …`, `…
won …`) show nothing. `/dw diagnostics` → `feed: parser hits=<n>` matches the receipts seen and
`feed: last loot <s>s ago (chat, <kind>) by <looter>` names the last one. Then `/etrace`, filter on
`CHAT_MSG_LOOT`, and let a member loot something → the event's twelfth argument equals
`/dump UnitGUID("party1")` for that member: the parser takes it as the GUID of a looter the roster
cannot place. Record any line chat showed with no `[PARSE]` line, any
looter shown without a realm, and any quantity wrong. Result:

**FEED-2. One drop per item, whatever reports it.** `/dw debug on`, in a Normal or Heroic dungeon
with four others, and kill a boss. → Each item chat shows as looted produces one `[FEED] drop <n>:
<link> by <Name-Realm> (chat) in <boss name>` line (or `(encounter)` when the encounter's report
came first), and, when the other report arrives, one `[FEED] drop <n>: <link> also reported by
encounter` line with the same `<n>`: no item gets two `drop` numbers. `/dw diagnostics` →
`feed: drops group=<members' drops> mine=<yours>` match what chat showed, and `merged=` counts the
second reports. In a group-loot (Need/Greed) run, each won item also shows `also reported by
history` once the roll ends, never before. Record any item with two numbers, or a `merged=` of 0
after a boss whose loot chat showed. Result:

**FEED-3. Groups by encounter and area.** Same dungeon, `/dw debug on`. → Trash loot before the
first boss reads `in <dungeon name>`; the boss's loot reads `in <boss name>`, including loot that
arrives up to two minutes after the kill; trash after that reads `in <dungeon name>` again. Wipe on
a boss once → loot that follows is not filed under the boss. While a boss is up (or within two
minutes of its kill), `/dw diagnostics` shows `feed: encounter=<boss name>`; afterwards
`encounter=none`. Record any drop filed under the wrong name. Result:

**FEED-4. The gates, in order, and your own drops.** Same dungeon, Feed quality at its default
(Rare+). → An Uncommon or lower item a member loots that is not an upgrade for you shows a
`[QUAL] hidden <link>: quality <q> below 3 (fixed, belowThreshold)` line and **no** `[INSPECT]`
line for that member right after it; an Epic shows `[FEED] drop`, then an `[INSPECT] inspect
<Name-Realm>: cached` or `fresh` line within a few seconds (out of combat), then `[EVAL] re-judged
1 drops after an inspect`. A potion or a reagent shows `[FEED] hidden <link> by <name>: notGear`.
An item you loot yourself shows `them=-` and a trade state judged by your own verdict (`no` when it
is an upgrade for you). Then leave the instance and, alone in the open world, loot a few items:
no `[FEED] drop` line appears outside a tracked situation (`/dw diagnostics` →
`feed: hidden ... notTracking=<n>` counts any loot seen there). Result:

**FEED-5. The upgrade track on someone else's link.** After FEED-2, shift-click a member's drop
(a piece with an upgrade track, from the loot window or chat) into `/dump
C_Item.GetItemUpgradeInfo(<link>)`. → A table with `trackString`, `currentLevel`, `maxLevel` and a
`trackStringID` answers for a link that is not yours; record the `trackStringID` per track name, so
`C.TRACK_TIER_BY_STRING_ID` can be filled (ITEM-2). If it answers nil, record that: the feed then
reads the track from the hyperlink tooltip's `ItemUpgradeLevel` line. Result:

**FEED-6. The Mythic+ chest.** `/dw debug on` and `/etrace` filtered on `ENCOUNTER_LOOT_RECEIVED`,
then time a keystone. → `/dw diagnostics` during the run shows `feed: run=<keystone dungeon
name>`. At the chest, each item shows `[FEED] drop <n>: ... in <keystone dungeon name>` (the run's
group, bosses included), and `/etrace` shows one `ENCOUNTER_LOOT_RECEIVED` per chest item: record
the first argument (the encounter id) it carries, and whether the chat line and the event both
arrive (`also reported by encounter`). Loot two minutes after completion falls back to the
dungeon's name. Result:

**FEED-7. A Devourer looter.** In a group with a Devourer Demon Hunter, once they are inspected
(`/dw diagnostics`'s `inspect` lines show them with `spec=1480`), `/dw add` a warglaive or a
one-handed Intellect weapon with their name, then an Intellect held-in-off-hand item. → The Them
column reads the weapon as usable (an upgrade, sidegrade or downgrade, never `Can't use`) and the
off-hand item as `Can't use`. Before the inspect, the same Intellect weapon reads `?` (the spec is
not known and Intellect suits only one Demon Hunter spec). If the item's own spec list disagrees,
the item wins: record the item and both verdicts. Result:

**FEED-8. The window's shell.** `/dw show` on a clean `/reload` → a window about 1038 × 600 (since DW-F1; 1132 from DW-E4)
with the Ka0s edge (a hard black line with a gray line inside it), the gold `Ka0s Drop Watcher` title
centered on the title bar (no logo), a `Scan group` button with a people mark (since DW-G4 on the Drops
strip in the full layout, the title bar's icon in compact: FEED-63), a minimize mark and the close
mark; the `Drops` tab gold with a gold underline, `History` gray (two tabs since DW-E3); the filter bar reads
`View: All`, `Quality: Rare+`, `Content: This session` (`This instance` until feedback-13, FEED-75) and the `Filter looter or item…` box (no checkbox:
DW-A1 made them View values, FEED-20); the footer reads `Inspect: no group`, `No loot seen yet` (or
`Last loot …`), `Not tracking in Solo · change in settings`, `Pawn: on` or `off`, and `Sort: Newest` beside
the corner grip (superseded by feedback-10, 2026-10-14: Sort sits at the right edge of the tab's strip, the footer
keeps only its health segments; FEED-70). Hover each control → every one shows a tooltip with a reason. Click `History` → Quality
grays out (its tooltip says the tab does not use it); set Sort to Oldest there, go back to Drops → Sort
reads Newest again. Open each dropdown and press Escape → the window and the open menu both
close. Drag by the title bar and resize from the corner, `/reload` → the same place and size (the corner
will not take it narrower than 1038: FEED-37, FEED-54). In a party, `Scan group` → the chat line
`Inspecting <n> group members, one at a time.`, and within a minute the footer reads
`Inspect <n>/<n> fresh`. Result:

**FEED-9. Minimize and auto-open.** With the window open, the minimize mark → the window shrinks
to its title bar where it stood, the mark becomes a plus; `/reload` → it comes back minimized. In a
Drag the window to the middle of the screen and minimize it again → the title bar stays exactly
where it was, and the expand grows the window downward from it. Press Alt-Z twice → the window
comes back with the UI; enter and leave combat → it stays open. On Drops open your own drop's `Offer`,
expand another row and click `Edit message`; then minimize → both close with the body. In a
Heroic dungeon with the window minimized, let a member loot an item → a `1 new` chip
appears beside the title and the window stays minimized; a double-click on the title bar expands it
and the chip goes. Superseded in part by FEED-18 (DW-83): every drop now opens it, not only the
first upgrade. In the open world solo nothing opens it. Result:

**FEED-10. The Drops table.** In a Heroic dungeon with the window open, let the group loot a boss →
under the filter bar a row of gold column labels (`Item`, `Ilvl`, `Slot`, `Type`, `Looter`, `Me`,
`Them`, `Trade`, `Trade window`, `Actions`; gold and Type since DW-D4 and DW-D3, Trade window since DW-E1;
`My eq` and `Their eq` merged into Me and Them since DW-F1: FEED-49), then a gold header `<boss> · Dungeon · <age> ago · <n> drops` with a gold down chevron
(DW-E0), then one row per drop, indented under the header with a muted-white chevron at its left (DW-E0:
FEED-39): the item's own icon
and its name in its quality color, its item level, its slot, its type (FEED-34), the looter's short name in
their class color, then Me and Them, each the worn item (yours, the looter's; two for a ring, trinket or
weapon) as icons with item levels, or `empty`, `…`, `range`, `combat`, `!`, then `▲`, `≈` or `▼` before
the unsigned difference (`321/308 ▼8`; the glyphs drawn, not boxes; FEED-49), Trade as `Yes`, `Likely`, `Unknown` or `No`, Trade window as a countdown over a
thin bar (FEED-41), and an `Ask` button or a dash (no `×` since DW-D2; superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72). An upgrade is green, a sidegrade yellow and a downgrade red, in Me and Them alike (since
DW-D0: FEED-31). With View: Interesting the rows are your upgrades plus the drops their looter has no use
for that read Yes or Likely; View: All (the default since DW-A1) lists every drop. Your own loot is
listed here too, with Offer in its Actions (since DW-E2; `feed.showOwn` is retired: FEED-42..44). Resize the
window to its narrowest (1038 since DW-F1) → no column goes, and the Ask and Offer buttons stay inside the
window. (Before DW-D4
the narrowest width shed Slot, Looter, My eq, Their eq and Ilvl in turn; the headless `test_side_cells`
pins today's order, Type, Slot, Looter, Trade window, Ilvl, Them, Trade, Me, for a row narrower than the
least.) Hover every cell, every column label
and the header → each one shows a tooltip with a reason (Trade's reads like
`Personal loot: 311 is not an upgrade over the 324 <name> wears, so they may trade it.`); no cell is blank.
Result:

**FEED-11. Headers, item buttons, compact.** After FEED-10, kill a second boss → its group is on top and
open, the first one collapsed with a right chevron and `(collapsed)`; click each header → it opens or
collapses. Hover an item icon → the game's item tooltip with a
`Shift-click to link it in chat; ctrl-click to try it on.` line; shift-click it with the chat box open → the
link is inserted; ctrl-click it → the dressing room shows it. No row has an `×` (DW-D2 removed the dismiss:
FEED-33). Switch to the compact layout (`/dw compact`) → the table gives way to cards (COMPACT-2); set it
back. Resize the window → the Item column takes the width. Scroll with the mouse wheel when the rows pass
the bottom. Result:

**FEED-12. The table's Ask button.** In a party, on a drop that is an upgrade for you and Likely tradeable,
click `Ask` (red: your move, DW-D1) → the looter is whispered your ask template and the chat line
`Whispered <name>: [item]` appears; the button reads `Asked` with a check mark, yellow and grayed; its
tooltip says it cannot be sent twice. In a boss fight, click `Ask` on another such drop → it reads `Queued`
with a clock mark and the title bar's badge counts it; click it again → it is canceled and reads `Ask`;
click once more and let the fight end → it is sent and reads `Asked`. A drop with Trade `No`, or one
that is not an upgrade for you, shows a dash whose tooltip says why (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72); a drop of your own shows `Offer`
instead (since DW-E2: FEED-44). Result:

**FEED-13. The detail card opens inline.** After FEED-10, click a drop's row (anywhere but a button) → a
card opens right under it, indented with its row, and the rows below move down; the row gets a faint gold
tint and its left chevron turns up (since DW-E0 there is no chevron at the right edge: FEED-39). The card shows the item's icon and name in its quality color, then chips: the slot, the type
(Cloth, Leather, Mail, Plate, Jewelry, Trinkets, Cloak or Weapons; the `Armor type` chip until DW-D3), the
bind (BoP, BoE), the track with rank and item level (`Hero 2/6 · 311`), the primary stat, and Socket or a
tertiary stat when the item has them. Click the row again → the card closes and the rows move back. Click
another row → the card moves to it: one card at a time. Fold the row's header, or type a search that hides
the row → the card goes with it; clear the search → it comes back still open. Result:

**FEED-14. Both comparisons and the trade box.** On a drop the looter's inspect has read, the card's left
box `FOR YOU` and right box `FOR <NAME> (LOOTER)` each show a verdict chip (`▲ UPGRADE`, `▼ DOWNGRADE`, …,
the arrow first and the chip green, yellow or red since DW-D0), the item it replaces with its icon and item
level, `292 → 311 · +19`, the track change (`Champion 6/6 → Hero 2/6 ▲`), the secondary stats gained and
lost (`+130 Haste -119 Mastery`), and for you Pawn's score (or `–`, whose tooltip says whether Pawn is
loaded), for the looter their spec and `inspected 40s ago`. The values match the item tooltips the game
shows (compare each by hovering the icons). Below, the trade box shows a chip (`LIKELY TRADEABLE`), the
reason in a sentence, and `Rule: personal loot, Mythic+ · Basis: inspect 40s ago`. Hover every line and chip
→ each tooltip names it and says why; nothing is blank. Result:

**FEED-15. The card's actions.** On another player's drop that is an upgrade for you: `Ask <name>` whispers
them as the row's Ask does; `Edit message` opens a small box over the window with the ask filled in and
`n / 255 bytes`; change the text and click `Send` → the edited text is whispered and the box closes; type
past 255 bytes → Send grays out; `Cancel` or Escape closes it unsent. `Link in chat` puts the item's link in
the chat box. `Retry inspect` is grayed while the looter's read is fresh (its tooltip gives the age); on a
looter whose inspect failed or ran out of range it queues them (`/dw debug on` shows the inspect). Standing
far from the looter, `Trade` reads `Trade · out of range` grayed, with the reason on hover; walk up to them
→ it lights up, and a click opens a trade window with them; in combat it reads `Trade · in combat`. There is
no `Hide this item` (DW-D2: FEED-33). On your own drop the first button is `Offer` (since DW-E2), which
opens the Offer panel, and the For the looter box's Them row reads `(Details)` (`(Multiple)` until DW-F3) with the row's tooltip;
Edit message, Retry inspect and Trade are grayed and each says why. Result:

**FEED-16. The header beside Loot History (DW-81).** Open Ka0s Loot History (`/lh`) and put the two windows
side by side. → Drop Watcher's title bar has no logo (the minimap button and the AddOns list keep it), and
its gold `Ka0s Drop Watcher` title sits centered on the bar in the same font as Loot History's. `/dw test`
and Loot History's test mode → each shows `TEST MODE` in bright red, the same size and color, 10px right of
its title, with no box behind it; Drop Watcher's hover still shows the test-mode tooltip. The yellow strip
under the filter bar (`TEST MODE: sample drops of real items in every state. …`) is unchanged. On the right,
the restriction badge, `Scan group`, minimize and the close mark keep their places. `/dw test` off, then
`/dw sim start key` → `SIMULATION` in cyan, the same style and place. Minimize with a new drop pending → the
`n new` counter sits after the mode's words. Resize to the least width (1038 since DW-F1; 1132 from DW-E4, 972 from DW-D4, 520 before) with
test mode on → the title stays centered; record whether `TEST MODE` reaches `Scan group` or the restriction
badge (at that width the centered title leaves them little room). Result:

**FEED-17. The filter bar beside Loot History (DW-82).** With the two windows side by side as in
FEED-16 → Drop Watcher's search box is a flat, square-cornered box, the same dark fill, thin gray
line and height as Loot History's `Search items…` box, with its gray hint 6px in; click into it →
its line turns gold, and click away → gray again. (The `Likely tradeable only` checkbox this check
covered is a View value since DW-A1: FEED-20.) The View, Quality and Content dropdowns match Loot
History's (same flat box, chevron, font and height), 8px apart. Switch to History → the control it
does not use (Quality) grays out the same way. Result:

**FEED-18. My eq, Their eq, the two new filters and auto-open on every drop (DW-83).** (Since DW-F1 My eq
is the gear part of Me and Their eq of Them, and the My eq and Their eq toggles are gone: read the column
checks below against Me and Them, FEED-49 and FEED-50.) In a Heroic dungeon
with the window open, let the group loot a boss → the `My eq` column sits before `Their eq`; each row shows
the icon of what you wear in the drop's slot (two icons for a ring, trinket or one-hand weapon) with its
item level (`300/296` for two), and `empty slot` where you wear nothing. Hover a My eq icon → the game's own
tooltip for your equipped item (its enchant and gems). Swap a piece of gear → My eq follows within a second.
Their eq shows the looter's worn icon(s) and item level(s); hover the cell → its tooltip names each item and
says `Inspected 2m ago.` (or `From the inspect cache, read …`); an uninspected looter still shows `…`,
`range` or `–`. Settings › Window › Columns → untick My eq → the column goes. (Since DW-D4 the window cannot
be narrowed past the width where every column fits, so no column goes; the headless `test_window_group` pins
My eq shedding before Their eq.) Tick `Usable by me` → the rows reading Can't use or Not wanted in Me go;
tick `Upgrade for me` → only your ▲ rows stay; untick both. (Since DW-A1 these two are View values, not
checkboxes: pick them in the View dropdown, and FEED-20 covers the grayed tabs and the settings.) Close the
window, then let any member loot an item the feed shows → the window opens by itself; close it again and the
next drop opens it again; loot an item yourself → it opens too. Minimize it, let another drop come → it
stays minimized and its `n new` count rises. Untick General › When to show › Dungeon › Auto-open → drops no
longer open it; tick it back. Enter combat with the window closed and let an item drop → it opens with no
Lua error and no "Interface action blocked" message. `/dw sim start key` with the window closed → the
simulator's first drop opens it. Result:

**FEED-19. Every drop counted: the two-Yoke regression (DW-A0, feedback-2 spec §0).** In a Mythic+
dungeon with a cross-realm group, `/dw debug on`, View: Interesting. Let two members loot the same
item, one for whom it is an equal (sidegrade) and one for whom it is a downgrade, while it is a
downgrade for you (the owner's run: two Yokes of the Charging Bear, `Bùnian-Azralon` and
`Keghunt-Thrall`) → the debug console has an `[FEED] drop n: ... by Bùnian-Azralon` line for
each, both looters spelled as in chat; the group header reads `<run> · Mythic+ · <age> · 2 drops ·
1 shown`; hover it → the tooltip lists `Yoke of the Charging Bear (Bùnian): View: Interesting`.
Switch View to All → both rows show and the header reads `2 drops`. A boss whose every drop View:
Interesting hides → its header still shows, `n drops · 0 shown`, with no row under it; Search for
an item it does not hold → that group leaves the table. A reagent and a non-gear item
(a decor piece) in the same run → one `[FEED] hidden <link> by <looter>: notGear` line each, no
row. Loot an item yourself through a quest reward → one `[FEED] refused <link>: pushed` line.
`/dw diagnostics` → its `drops` section reads `drops: hidden notGear=2` (plus any others) and
`drops: refused pushed=1`. Result:

**FEED-20. View: All by default, the checkboxes as View values (DW-A1, feedback-2 spec §1).** On a
character whose profile never changed the View, `/dw show` → the bar reads `View: All` and no
checkbox is left on it. Open View → its rows are `View: All`, `Interesting`, `Likely tradeable`,
`Usable by me` and `Upgrade for me`, and the menu stays open as you click. Click `Likely tradeable`
→ the button reads `Likely tradeable` and only Yes or Likely rows stay; click `Usable by me` too →
`View: 2 selected`, and a row must pass both; click `Likely tradeable` again → `Usable by me`;
click `View: All` → every row comes back. Hover View → a bullet line per value (`• All: …`,
`• Interesting: …`, `• Likely tradeable: …`, `• Usable by me: …`, `• Upgrade for me: …`). Switch to
History → View stays live, `Likely tradeable` is gray in the menu and does not tick, and its
tooltip line is gray with `(not on this tab)`. Settings › Feed
› Filters → four rows, `View: Interesting`, `View: Likely tradeable`, `View: Usable by me`, `View:
Upgrade for me`, all unticked; Trade › Timers no longer has Likely tradeable only. `/dw get
feed.view.likely` → `false`; `/dw set feed.view.usable true`, `/reload`, `/dw show` → a fresh
Drops tab reads `Usable by me`; `/dw set feed.view.usable false`. On a character that had
ticked Usable by me or Likely tradeable only in the old settings (or `View: All` saved), the first
load of this version → the same choices show as View values. Result:

**FEED-21. Item tooltips beside the window (DW-A2, feedback-2 spec §2).** `/dw test`, window in the
middle of the screen. Hover an item in each place: a Drops row (icon and name), the Me and Them icons (My eq and Their eq until DW-F1), the detail card's icon, name and Replaces rows, a row of your own, the Offer panel's icon and name,
and a History row → each tooltip opens to the RIGHT of the window, its top level with the hovered
row, and covers none of the table (the Offer panel's opens to the right of the panel). Drag the
window to the screen's right edge and hover again → each opens on the LEFT of the window instead.
Set the UI scale low (or the window's Scale to 0.7) and repeat near the right edge → still beside
the window, never over it, never off screen. Hover the toast's icon → beside the toast. (Where
each tooltip sits against the row is FEED-26's since DW-B2: it rises from the row's top.) Result:

**FEED-22. Group headers keep the party (DW-A3, feedback-2 spec §3; the header since DW-B4).** In a
five-player party, run a dungeon or a key until something drops. Since DW-B4 the header itself names
only you (FEED-28). Hover the header → the tooltip's one line reads `Group: You, A, B, C, D`: your
name first, every name in its class color, a cross-realm member as Name-Realm. Have someone leave
and another join mid-run, then let a drop fall (or just wait for the roster change) → the newcomer
is added to that line, the leaver stays named. Open History → the same group's tooltip names the
same party; `/reload` → it still does. A History group kept before DW-A3 has no `Group:` line and
still reads correctly. In a raid (or `/dw test`, whose Placeholder boss is a raid of eight) → the
line names all eight (ten at most, then `+n`). `/dw sim start key` then `/dw sim run` → the run's
tooltip names you and the simulated group, and the simulation's History does too. Result:

**FEED-23. The Character dropdown (DW-A4, feedback-2 spec §4).** Open the window: after Content the
bar holds `Character: Current`. Open it on Drops → `Character: All`,
`Character: Current` and your own character alone, its class icon beside the name, in class color.
Loot something on this character, log on to an alt and loot something there, then open History on
the alt → `Character: Current` shows the alt's drops only; the menu lists both characters, each with
its class icon and color. Tick the main as well → the label reads `Character: 2 selected` and both
characters' groups show. Untick the alt → the label is the main's row and only its drops show. Pick
Current → exactly the alt again, and the Current row lights gold. Pick All → every group, and a group
kept before this version (no recorder) shows its rows only now (under Current or a character it
is left out, no `0 shown` header, since feedback-12 spec §1). Hover a group header while the dropdown hides
some of its drops → the tooltip names them with `Character: Current`. Turn on `/dw test` → History
lists you and `Emberwick`, and Current hides the alt's `Placeholder boss (alt)` until All. `/dw sim
start key` then `/dw sim run` → the simulated run shows under Current on every tab. Result:

**FEED-24. The tables' font and row height beside Loot History's (DW-A8, feedback-2 spec §8, FB2-9).**
The headless `test_window_group` (`rows:`, `table: the Window page's row height`, and the Trade window
row's height) and `test_history` (`rows take the Window page's row height`) cover the same ground. On a
profile that never moved Row height or Font size, `/dw test`, then open Ka0s Loot History beside the window
→ the Drops text is the same small table font at the same size as Loot History's (compare research
`11-font-vs-loothistory.png`, where Drop Watcher's was larger), the item icon fits inside the row, and each
row is taller than Loot History's 18 pixels by the room the Trade window's countdown bar needs (since
DW-E1), the countdown and its bar never overlapping; untick Settings › Window › Columns › Trade window → the
rows are 18 pixels again; tick it back. History → 18-pixel rows. Settings › Window › Layout → Row height
reads 18 and Font size reads 0, all the way left (Default). Drag Font size to 15 → the text grows on both
tabs, the countdown included (also while it is bold amber, ending soon), and the Drops rows grow with it so
the countdown never runs into its bar (also at Font size 20 with Row height 18); drag it back
to 0 → the original size returns. `/dw get window.fontSize` → `0 (Default)`. On a profile where you had
stored another row height or font size before this version, it is unchanged. Result:

**FEED-25. Your own drops' headers and the tooltip beside the Offer panel (DW-A9, feedback-2 spec §8,
FB2-10; on Drops since DW-E3).** The headless `test_own_drops`, `test_drops_strip` and `test_window_group`
(`beside the docked Offer panel`, `a docked panel's row never opens over the window`) cover the same
ground. `/dw sim start key` then `/dw sim run` until your own drops fall, or `/dw test` → your own drops
are Drops rows under the same headers as everyone's: `Den of Nalorakk · Mythic+ · 6m ago · 2 drops`, the
party in class color in the tooltip. Click a header → its rows fold away and it reads `(collapsed)`,
while the strip still counts their tradeables (FEED-45); click again → they return. Search for one
item → the header reads `n drops · 1 shown`. Open your own row's Offer panel, docked on the window's right,
then hover a row's item → the tooltip opens to the RIGHT of the panel, never over it; drag
the window toward the screen's right edge until the panel has no room beside it (or the tooltip
does not fit) → the tooltip opens on the window's LEFT. Hover an item in the panel → the tooltip
never covers the window (right of the panel, else left of the window). Close the panel and hover a
row → the tooltip is beside the window again. Result:

**FEED-26. Every row tooltip at the row's top right, like Loot History (DW-B2, feedback-3 spec §2).** The
headless `test_row_tooltip` covers the same ground. `/dw test`, window in the middle of the screen, Ka0s
Loot History open for comparison (research `06-loothistory-tooltip-top-right.png`). On Drops hover a
row's item, then its Looter, Me, Them and Trade cells (Me and Them holding the worn gear since DW-F1), the Ask button, then a group header
→ every tooltip's bottom-left corner sits at the hovered row's top-right corner, just outside the window's
right edge, rising above the row, never over the table (compare `04-cell-tooltip-in-row.png`, where a reason
opened over other columns). Hover your own row's Trade and Them cells and its Offer button (or the
dash; `No action` since feedback-11, 2026-10-14: FEED-72), and the strip → the same corner. On History hover each cell of a row and a header → the same. Open a
row's Offer panel (docked right) and hover a window row → the tooltip rises outside the panel's right edge;
hover a candidate's cells, pill, Offer and Trade → the same corner, never over the window. Drag the window
to the screen's right edge and repeat a few → each rises from the row's top-LEFT corner instead, just
outside the window's left edge. The column labels, the tabs, the title bar, the footer and the filter bar
keep their own anchors. Result:

**FEED-27. The filter bar's tooltips open above their controls (DW-B1, feedback-3 spec §1).**
The headless `test_window_shell` (its three `filter bar tooltip` cases) covers the placement math. `/dw test`, window in
the middle of the screen (research `03-view-tooltip-over-dropdown.png` shows the old overlap). Hover View,
Quality, Content, Character, the search box and the footer's Sort (the strip's since feedback-10, 2026-10-14;
FEED-70) in turn → each tooltip's bottom-left
corner sits on the control's top-right corner, the tooltip rising above the control and never covering
it; click a dropdown open while its tooltip shows → the menu is never under the tooltip. Drag the
window to the screen's right edge and hover the right-most controls → the tooltip's bottom-right
corner sits on the control's top-left corner instead, still above it. Result:

**FEED-28. Group headers name where it dropped and only your character (DW-B4, feedback-3 spec §4).**
The headless `test_group_place` covers the names and the capture. Research `07-my-drops-real-timewalking-drop.png`
shows the old header (`Commander Ri'mok · Dungeon · ... · Euthanàsia, Deathllanira, ...`) and
`08-header-roster-too-long.png` the roster crowding it. Run a Timewalking dungeon and kill a boss that
drops something → the Drops header reads `Gate of the Setting Sun · Commander
Ri'mok · Timewalking · 3m ago · 1 drop · <you>`: the instance, the boss, the client's difficulty name
(never the generic `Dungeon`), the time, the count, then only your character, in class color. Do the
same on Normal, Heroic, Mythic, in Raid Finder and in a delve → each header names that difficulty as
the client does. Finish a key and loot the chest → `<Dungeon> · Mythic+ <key level> · ... · <you>`.
Open History → the same groups read the same; `/reload` → they still do; log in on an alt and open
History with `Character: All` → a group the first character saw ends with that character's name, not
the alt's. A History group kept before this version still reads `Label · Situation · ...`. In the open
world → `Open world · Open world group` (or `Solo`). `/dw test` → the key run is a real dungeon at
`Mythic+ 10` and the boss sits in a real instance at Heroic, on Drops and History.
`/dw sim start dungeon` then `/dw sim run` → the boss headers name the pool's dungeon and `Mythic`;
`/dw sim start key` → the run's header names the dungeon and `Mythic+ 12`. Result:

**FEED-29. A tooltip near the top of the screen opens below (DW-B5, feedback-3 spec §5).** The headless
`test_window_shell` (its `near the top` cases) covers the placement. (The tab counts this check also
covered, `My drops · 1` and the Group drops header's `· 1 yours on My drops`, are gone since DW-E3: your own
drop is a Drops row and its header counts it with the others, FEED-46.) Solo, `/dw sim start key`, play it
to its loot step → the Drops header counts both drops, yours among them. Drag the window to the top edge of
the screen and hover
View, the search box and the footer's Sort (the strip's since feedback-10, 2026-10-14; FEED-70) → each
tooltip opens below the control, its top-left corner on
the control's bottom-right corner (its top-right on the bottom-left at the screen's right edge), never over
the control or its menu; drag the window back down → above again. Result:

**FEED-30. A delve's header, and whether the client names its tier (DW-B4, feedback-3 spec §4).**
The spec names `a delve tier` among the header's difficulties; offline, neither GetInstanceInfo's
difficultyName nor GetDifficultyInfo is known to give it (both are read as `Delves` for difficulty
208), so the header names `Delves` and the tier is a known limitation (ARCHITECTURE.md). The headless
`test_group_place` covers the order the two names are read in. Enter a delve at a known tier (say
Tier 8) → `/dump GetInstanceInfo()` and record its fourth return (difficultyName) and its third
(the difficulty id), then `/dump GetDifficultyInfo(<id>)`'s first. Loot something from its chest →
the Drops header reads `<Delve> · <label> · <the difficultyName recorded> · ... ·
<you>`. If either dump names the tier, the header shows it; if neither does, record that here so
the tier can be read from another source or the gap ratified. Result:

**FEED-31. One tone per verdict, the arrow first (DW-D0, feedback-4 spec §0).** The headless
`test_window_group` (its `cells: Me` and `Them column` cases), `test_compact_cards` and `test_detail_card`
cover the tones and the order. Research `05-delta-arrows-after-text.png` shows the old cells. `/dw test`,
full layout, Drops → in Me and in Them alike an upgrade reads `▲6` in green, a sidegrade `≈0` in
yellow (a yellow lighter than the gold of the headers), a downgrade `▼13` in red (unsigned, after the worn
item level, since DW-F1: FEED-49; `▲ +6` before), `Can't use` and
`Not wanted` gray, `?` muted; the arrow sits before the number, the two in the same
color (since DW-F1 after the worn icons and item level, which stay plain). Them is not inverted: the looter's upgrade is green, not amber. Hover Me and Them → neither tooltip
describes an inversion. History's Me and Them read the same way. Expand a row → the
detail card's verdict chips read `▲ UPGRADE`, `▼ DOWNGRADE`, … in the same tones. `/dw compact` → each
card's You and Them halves keep the arrow first and take the same tones. Result:

**FEED-32. Action buttons colored by whose move it is (DW-D1, feedback-4 spec §1).** The headless
`test_window_group` (`ActionTone`, `the Ask button wears its state's tone`), `test_mine_cells`
(`ToneState`), `test_own_drops`, `test_offer_panel` and `test_compact_group` cover each state. Research
`04-actions-column-uncolored.png` shows the old white column. `/dw test`, full layout, Drops → `Ask` and
`Retry` are red, `Asked` and `Queued` yellow, `Traded` green, a dash stays gray (the gray `No action` button since feedback-11, 2026-10-14; FEED-72). Expand a ready row → the
detail card's `Ask <name>` is red; its other buttons stay white. Your own tradeable drop's `Offer` is cyan (red until DW-F2: FEED-51);
open it and offer one member → that member's `Offer` reads `Offered` in yellow, and the row's `Offer` turns
yellow too (an offer for the drop is out, whoever it went to); the panel's `Announce to group` is red, then
`Announced` (or `Queued` in a boss fight) in yellow. (Since DW-E2 the table has no Announce button: FEED-44.)
Once a drop of yours is traded away (HIST-1, or test mode's History sample) its Offer and the panel's
Announce to group are green. No button is gold. `/dw compact` → each card's Ask, and Offer on your own
card, show the same colors in each state (Offer cyan while it is your move). Result:

**FEED-33. Nothing dismisses or hides a drop (DW-D2, feedback-4 spec §2).** The headless `test_window_group`
(`no row can be dismissed`), `test_detail_card` (`no Hide this item`), `test_own_drops` and
`test_compact_group` cover it. Research `03-dismiss-column.png` shows the old × column. `/dw test`, full
layout → Drops' Actions column holds only the Ask button, Offer on your own drop (or its dash; `No action` since feedback-11, 2026-10-14: FEED-72), no `×`; the
detail card's actions are `Ask` (or `Offer`), `Edit message`, `Link in chat`, `Retry inspect` and `Trade`,
no `Hide this item`. A drop of yours that cannot be traded shows a dash whose tooltip says why (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72), and no
`Hide`; it stays listed. `/dw compact` → no card has an `×` or a `Hide`. (The My drops tab's tooltip this
check also read is gone since DW-E3.)
Turn on auto-ask (ASK-8) → its one-time notice reads
`It holds off when you ask yourself, they leave or you get the item.`, with no word of dismissing. Result:

**FEED-34. The Type column (DW-D3, feedback-4 spec §3).** The headless `test_window_group`
(`Type names the armor type`, `the Type column sits after Slot`) and `test_compact_cards` cover the values.
`/dw test`, full layout, Drops → a `Type` column sits right after `Slot`, its label gold. A head,
shoulder, chest, waist, legs, feet, wrist or hands drop reads `Cloth`, `Leather`, `Mail` or `Plate` as the
game's tooltip names its armor; a neck or ring reads `Jewelry`; a trinket `Trinkets`; a cloak `Cloak` (never
`Cloth`); a one-hand, two-hand, main-hand, off-hand weapon, a shield, a held off hand or a ranged weapon
`Weapons`; anything else (a tier token) a dash whose tooltip says why. Hover a cell → `Type: <word>` and a
reason line. History shows the same column after Slot. Settings › Window ›
Columns has a `Type` box; untick it → the column goes from Drops; tick it back. Expand a row → the
detail card's chips include the same word (no `Armor type` chip). `/dw compact` → each Drops and
History card's second line reads looter · slot · type · trade. Result:

**FEED-35. Gold column labels (DW-D4, feedback-4 spec §4).** The headless `test_drops_layout`
(`the column labels are gold`) covers it. Research `01-full-header-white.png` and
`02-loothistory-header-gold.png` show the old labels and Loot History's. `/dw test`, full layout, Ka0s Loot
History (`/lh`) open beside it → Drops' and History's column labels are the same gold as
Loot History's headers; the group headers stay gold, and the tabs keep their own colors. Result:

**FEED-36. The search box spans to the window's edge (DW-D4, feedback-4 spec §4).** The headless
`test_drops_layout` (`the search box spans from the bar's gap after Character`) covers the width. Research
`06-filter-textbox-gap.png` shows the old gap. Full layout → the `Filter looter or item…` box starts 8px
after the Character dropdown (the same gap as between the dropdowns) and ends at the filter bar's right
edge, with no empty space after it. Drag the corner wider and back → the box widens and narrows with the
window while you drag, not only on release. Switch tabs → the same on each. Result:

**FEED-37. The window never goes narrower than its default (DW-D4, feedback-4 spec §4; the widths since
DW-E4).** The headless `test_window_shell` (`the default size is 1038 x 600`) and `test_drops_layout`
(`at the least width no tab sheds a column`) cover the bounds. On a new profile (Settings › Profiles › New),
`/dw show` → the full window is about 1038 wide (1132 from DW-E4 to DW-F1, 972 before); drag its corner left → it stops at that
width; at it, every column of Drops and History shows, nothing is cut, and Ask stays inside the row. Widen
it and bring it back → it stops at the same width. `/dw compact` → 440 wide (380 before DW-E4); drag the
corner left → it stops at 440 (and at 520 on the right). With a profile whose stored full width is under
1038 (an older build's 972, say), `/reload` → the full window opens at 1038. Result:

**FEED-38. The group header's chevron is gold (DW-E0, feedback-5 spec §0).** The headless
`test_drops_layout` (`a group header's chevron is gold`) covers the color. Research `04-header-chevron.png` shows
the chevron the rows now reuse. `/dw test`, full layout → every Drops header's chevron (down while open,
right while collapsed) is the same gold as its text; History's headers too; `/dw compact` → the compact
headers' chevrons are gold as well. Result:

**FEED-39. Each drop row's chevron, and the rows indented under their header (DW-E0, feedback-5 spec §0).**
The headless `test_drops_layout` (the chevron and indent cases) and `test_compact_group` cover the
geometry. `/dw test`, full layout → every Drops row draws a small chevron at its left edge, before the item
icon, in a muted white (not gold, not bright white), the same on hover; it points down while the row is
closed. Click a row → its chevron points up while its detail card is open, and the card sits indented with
the row; click again → down. No chevron is drawn at the row's right edge. Each row (its stripe, its chevron
and every cell) starts about 12 pixels in from its header's left edge, so the row's chevron sits under the
header's text, not under its gold chevron; the column labels move with the rows and still sit over their
cells. History's rows draw no chevron and are not indented (they do not expand). `/dw compact` → each card
is indented the same and draws the same muted-white chevron before its item button, centered on line 1,
pointing up while its detail card is open. Result:

**FEED-40. The Actions column is wide enough (DW-E0, feedback-5 spec §0).** The headless `test_drops_layout`
(`Actions is 84 pixels`) covers the width. Research `01-actions-cramped.png` shows `Queued` filling the old
64-pixel button. `/dw test`, full layout → Drops' Ask button, in every state (`Ask`, `Asked`, `Queued`,
`Retry`, `Traded`), and Offer on your own drop (`Offer`, `Offered`), show their icon and word with room on
both sides, nothing touching the button's edge; the column label `Actions` sits over it. `/dw compact` →
each card's button is the same width. Result:

**FEED-41. A Trade window column for every drop, ticking each second (DW-E1, feedback-5 spec §1).** The
headless `test_window_group` (the Trade window cases), `test_mine_cells` (`TradeWindow`) and
`test_compact_group` cover the words, the estimate and the ticker. `/dw test`, full layout → a `Trade
window` column sits between Trade and Actions, its label gold, on every row, not only yours. Another
player's drop reads an estimate from when it dropped, `~1:42:10`, over a thin green bar; hover it → the
tooltip says it is estimated and names the looter, not your bags. Your own drop in your bags reads the exact
time with no `~`. A bind-on-equip drop reads `No limit (BoE)` over a full bar; a drop that cannot be traded
reads its short reason (`Bonus roll`, `Window passed`, `Their upgrade`), no bar, the whole sentence in the
tooltip; a drop still loading reads `Checking`. Watch for ten seconds → every countdown moves each second,
with no lag between rows and no frame hitch. A drop with ten minutes or less left reads its time in bold
amber, its bar amber, with no `ending soon` words in the cell; its tooltip adds `Ending soon: …`. The
countdown text and its bar never overlap (the row is taller by the bar's room). Settings › Window › Columns
→ untick Trade window → the column goes and the rows return to the row height; tick it back. In a real
dungeon, a member's drop shows the estimate too, and the column keeps moving while the window is open.
Result:

**FEED-42. Your own drop's Trade counts the upgrades (DW-E2, feedback-5 spec §2).** (Superseded by
feedback-7, 2026-10-13: the cell reads `Yes`, the count in its tooltip; FEED-61.) The headless
`test_own_drops` (`Trade appends the upgrade count`) covers the words. `/dw test`, or `/dw sim start key` and play to its loot
step, or loot a tradeable item yourself in a group → your own drop is listed on Drops (always: no setting
hides it), and its Trade cell reads `Yes (2)` or `Likely (1)`, the count of members it would be an upgrade
for, or the bare word when it is nobody's upgrade. Hover it → the tooltip adds `Upgrades 2 members: Offer
shows who.` Settings › Feed › Filters has no `Show my own loot in Group drops` row, and a profile that had it
on loads with no error. Result:

**FEED-43. Them reads (Details) on your own drop; the keep? rule (DW-E2, feedback-5 spec §2; (Details) and
one Them since DW-F1 and DW-F3).** (Superseded by feedback-7, 2026-10-13: `(Details)` reads
`Upgrade for N`; FEED-61, FEED-62.)
The headless `test_own_drops`, `test_tip_marks` and `test_detail_card` cover the tooltip and the rule. On
your own drop that is not an upgrade for you → Them reads `(Details)` (`(Multiple)` in Them and Their eq
until DW-F1 and DW-F3), green when it upgrades at least one member, muted when nobody. Hover it → one line
per member it upgrades, biggest gain first: `Butterz wears 276 Bloodthorn Treads` then a green arrow and
`11` (FEED-52); with none, `Not an upgrade for anyone whose gear was
read.`; `n checking` while inspects run; solo, `Nobody else in your group.` On your own drop that is an
upgrade for you → Trade shows no count, Them reads `Hidden`, and the tooltip says `An upgrade for
you: nobody is offered it unless you choose to. Offer shows who it would help.` Click its Offer → the panel
opens, and from then on (this session) the count and `(Details)` are drawn. Expand the row → the detail
card's Them row reads the same, with the same tooltip. `/dw compact` → line 3's Them reads the same.
Result:

**FEED-44. Offer on your own drop, and its tones (DW-E2, feedback-5 spec §2).** The headless
`test_own_drops` and `test_offer_panel` cover the states. Your own tradeable drop's Actions is `Offer` (cyan since
DW-F2, red before: FEED-51), not Ask; there is no Announce button in the table. Click it → the Offer panel opens for that drop (FEED-43's
reveal), and Announce to group is in the panel's footer. Offer a member from the panel → the row's Offer reads
yellow (sent or queued); once the drop is traded away (HIST-1) → green. A drop of yours that cannot be traded
shows a gray dash whose tooltip gives the reason (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72). The detail card's first button is the same Offer, the same
tone. The detail card no longer says `offer it from My drops`: its reason reads `Your own drop: Offer shows
who it would help.` Result:

**FEED-45. The strip under Drops and Post my tradeables (DW-E3, feedback-5 spec §3).** (Superseded by
feedback-7, 2026-10-13, in the full layout: the strip always shows, with Scan group beside Post, and Post
sits above Sort at its size; FEED-63. Superseded again by feedback-10, 2026-10-14: the row reads `[Post my tradeables]
[Scan group] [Sort]` on the strip; FEED-70.) The headless
`test_drops_strip` covers it. With two or more tradeable drops of your own on Drops (`/dw test`, or a
dungeon) → under the table, above the footer, a strip reads `2 tradeable · next expiry 0:08:41` with
`Post my tradeables` beside it; the next expiry moves each second, also with the drop's group collapsed.
Filter your drops out (Search for another item) → the count follows what the tab lists; with none of the
listed drops tradeable the strip goes and the table takes its room back. Click Post my tradeables → the
one-line post (ASK-7). `/dw compact` → the strip under the cards reads `2 tradeable · next 0:08:41` with a
`Post` button, the same tooltip; switch to full → the full strip again. (Superseded by feedback-15, 2026-10-16:
the compact strip is always shown and its button reads `Post my tradeables` at the full width; FEED-78.) Result:

**FEED-46. Two tabs, Drops and History (DW-E3, feedback-5 spec §3).** The headless `test_drops_strip` (`the
tabs are Drops and History`) and `test_slash` cover it. `/dw show` → the tab strip reads `Drops` and
`History` only; hover Drops → `Every drop your group receives, your own included, …`. On a profile last
left on the My drops tab, `/reload` → the window opens on Drops with no error. `/dw mine` → Drops. `/dw
help` → `mine` reads `Open the Drops tab, where your own drops are listed`. `/dw compact` → the short tabs read
`Drops` and `History`. Settings › Window › Layout › Row height's tooltip names Drops and History, and Font
size's says both tabs.
Result:

**FEED-47. The least width, full and compact, and the compact card's line 2 (DW-E4, feedback-5 spec §4; line
2 since DW-E1).** The headless `test_drops_layout` (`at the least width no tab sheds a column`) and
`test_compact_group` (the least compact width) cover the arithmetic. FEED-37's checks at 1038 (since DW-F1: FEED-54) and 440: on
Drops at 1038, the indent, the chevron, every column at its width with Trade window and the 84-pixel Actions,
nothing shed and nothing cut. `/dw compact` at 440 → every Drops card's line 2 reads looter (a twelve-letter
cross-realm name with its ⊕), slot, type and a counted trade (`Yes (2)` on your own), then on the right the
countdown and its bar, none of it cut; a drop with no countdown shows the inspect freshness there instead
(`2m`, `cached`, `…`). The countdown moves each second and turns bold amber, its bar amber, under ten
minutes. (Superseded by feedback-10, 2026-10-14: the card has no countdown or bar, the freshness is on line 1
and line 2 ends in the action button, its left pieces never cut at 440; FEED-69.) Result:

**FEED-48. The Trade window column fits its widest answer (DW-F0, feedback-6 spec §0).** The headless
`test_drops_layout` (`the Trade window column is its widest answer plus its bar's padding`) measures every
answer at the harness's character measure and pins 76 pixels (104 before). Research
`01-trade-window-wide.png` shows the old empty margin. `/dw test`, full layout, Drops at the default size →
the Trade window column ends a few pixels after its longest text: `~1:57:43`, `1:49:43`, `Their upgrade`,
`Your upgrade`, `No limit (BoE)`, `Bonus roll`, `Window passed`, `Legacy loot`, `Warbound`, `Not loaded`,
`Checking` and `Not tradeable` each show whole, none cut or touching Actions, with no wide empty margin after
the countdowns. Each bar spans the narrower column, its right end a few pixels short of the column's edge.
At a larger Font size (Settings › Window › Layout) record whether the longest answers still fit. Result:

**FEED-49. My eq merged into Me, Their eq into Them (DW-F1, feedback-6 spec §1).** The headless
`test_side_cells` covers the cells, the tooltip, the widths and the shed order; `test_compact_cards` and
`test_compact_group` line 3. Research `02-eq-and-verdict-columns.png` shows the four old columns. `/dw test`,
full layout, Drops → no `My eq` or `Their eq` label; Me and Them each read the worn item's icon (two for a
ring, trinket or one-hand weapon), its item level (`321`, or `321/308` for two) in plain white, then the
verdict's glyph and the item-level difference with no sign, `▲6` green, `≈1` yellow, `▼8` red, the glyph
and number in one color and the glyphs drawn, not boxes. `Can't use` and `Not wanted` stay gray words after
the gear; nothing worn reads a muted `empty` before the verdict; an unread looter's Them reads `…`,
`range`, `combat`, `!` or `–` with no `?` after it. Hover Me's icon → the game's tooltip for your equipped
item; hover Them → its tooltip lists each worn item and the inspect's age, then the verdict's reasons.
Swap a piece of gear → Me follows within a second. Your own drop's Them reads `(Details)` (FEED-52). History →
Me and Them read the verdict alone in the same unsigned form (`▼4`, `≈0`), since a kept drop holds no worn
items. `/dw compact` → line 3 reads `You 321/308 ▼8` and `Them 276 ▲12` (no icons), `Them (Details)` on
your own card, `⊘ Can't use` for a worded verdict, each part in the table's tone, nothing cut at 440.
Result:

**FEED-50. The My eq and Their eq toggles are retired (DW-F1, feedback-6 spec §1).** The headless
`test_database` (`step 7 retires window.columns.myEq and theirEq`) and `test_schema_rows` cover the
migration and the rows. Settings › Window › Columns → no `My eq` or `Their eq` checkbox; `Me` and `Them` are
there. Untick Me → the whole merged cell goes (gear and verdict); tick it back. On a profile that had My eq or
Their eq unticked, `/reload` → it loads with no error, Me and Them show the gear, and `/dw diagnostics`
reads `schema stored=7 code=7`. Result:

**FEED-51. Offer in cyan (DW-F2, feedback-6 spec §2).** The headless `test_own_drops`, `test_detail_card`,
`test_compact_cards` and `test_offer_panel` (`each member's Offer is cyan, Offered yellow, Retry red`) cover
the tones. Research `03-offer-red.png` shows Offer in Ask's red. `/dw test` → your own tradeable drop's
`Offer` on its Drops row is cyan (a light blue-green, not the blue of a link and not the red of Ask), while
another player's `Ask` and any `Retry` stay red. Expand your own row → the detail card's Offer is the same
cyan. Open the Offer panel → each member's `Offer` is cyan; offer one → it and the row's Offer read
`Offered` in yellow; a failed offer's `Retry` is red; `Announce to group` stays red until sent. Once traded
away → green. `/dw compact` → your own card's Offer is the same cyan. Result:

**FEED-52. The (Details) tooltip's lines, and the tooltip fits them (DW-F3, feedback-6 spec §3).**
(Superseded by feedback-7, 2026-10-13: `(Details)` reads `Upgrade for N` and its tooltip is a grid with the
table's glyphs; FEED-61, FEED-62.) The
headless `test_tip_marks` (the `details:` cases) and `test_own_drops` cover the lines. Research
`04-details-tooltip-boxes.png` shows the old wrapped line with a box for the arrow. `/dw test` (or a group
with members inspected) → hover your own drop's `(Details)` on its row, its detail card's Them row and the
compact card's line 3 → one line per member it upgrades, biggest gain first, each reading `<Name> wears
<item level> <Item>` then a small green up arrow and the gain without a sign (`11`): the name in its class
color, the item in its quality color. A member wearing two rings, trinkets or one-hand weapons is named with
the lower one, the one it would replace. No line wraps: a long item name widens the tooltip instead. The
explanatory lines (the keep? rule's `Hidden`, `n checking`, `Not an upgrade for anyone whose gear was read.`,
`Nobody else in your group.`) still wrap at the usual width. Result:

**FEED-53. No glyph boxes in any tooltip (DW-F3, feedback-6 spec §3).** The headless `test_tip_marks` (its
three `audit:` cases) covers every column tip, every localized string and every test-mode tooltip on both
tabs and both layouts. `/dw test` → hover the `Me` and `Them` column labels on Drops and the `Me` and
`Them` labels on History → any verdict mark in them is a small texture (an up arrow green, a two-way mark
yellow, a down arrow red), never an empty box or a question mark. Hover a dozen Me, Them and Trade cells, the detail card's
verdict chips and their reasons, and the compact cards' line 3 → no tooltip line shows a box where a
glyph should be. The table cells and compact lines themselves still draw `▲ ≈ ▼ ⊘` in the monospace face.
Result:

**FEED-54. The least width, 1038 (DW-F1, feedback-6 spec §0-§1).** The headless `test_window_shell` (`the
default size is 1038 x 600`) and `test_drops_layout` (`at the least width no tab sheds a column`) cover the
arithmetic (the comment beside `C.WINDOW.WIDTH`). On a new profile, `/dw show` → the full window is about
1038 wide; drag its corner left → it stops there. At that width every Drops column shows: the indent and
chevron, Item, Ilvl, Slot, Type, Looter, Me and Them whole with two icons, `321/308` and `Not wanted`, Trade,
the 76-pixel Trade window and the 84-pixel Actions, nothing shed, cut or overlapping; History's columns too.
A profile stored at 1132 (M14's least) keeps its width, and one under 1038 opens at 1038. Result:

**FEED-55. No glyph boxes outside tooltips (DW-F5, feedback-6 spec §3).** The default face (`GameFont*`)
has no `→` and none of `▲ ▼ ≈ ⊘ ⊕`; only text set to the monospace face draws them. The headless
`test_tip_marks` (`audit: no text in the default face carries a glyph`) walks every text test mode draws
on Drops, the detail card, the Offer panel and History, both layouts, and `test_toast` pins the toast's
line. `/dw test` → expand a row: the detail card's `FOR YOU` and looter verdict chips start with a small
arrow texture (green up, yellow two-way, red down), and the `Item level` (`292 → 311 · +19`) and `Track`
(`Champion 6/6 → Hero 2/6`, then its mark) rows show a small gray arrow texture between the values, never
an empty box. Open the Offer panel on one of your drops → the `Eq → drop` column label and its tooltip
title, and every member's eq text (`276 → 295`), show the gray arrow texture (superseded by feedback-7,
2026-10-13: the column is Their eq, in the Them cell's monospace glyphs; FEED-56). With `toast.enabled` on,
an upgrade for you that someone else loots → the toast's line reads `Looted by <name> · +n` and a green
up-arrow texture (superseded by feedback-9, 2026-10-13: the toast's verdicts are the table's monospace
glyphs, `You ▲n · Them ▼n`; FEED-66). The table cells and compact lines still draw `▲ ≈ ▼ ⊘ ⊕` in the monospace face. Result:

**FEED-56. The Offer panel's Their eq column, and no Trade button (DW-G0, feedback-7 spec §0).** The headless
`test_offer_panel` and `test_side_cells` (the `Offer panel's Their eq` cases) cover the cell and its widths.
Research `01-offer-panel-columns.png` and `03-offer-trade-button.png` show the old `Eq -> drop` and Status
columns and the always-gray Trade. `/dw test` → Offer on one of your sample drops → the panel's columns are
Member, Their eq and Actions, nothing else. Each Their eq cell reads like the Drops table's Them cell: the
member's worn icon(s), the item level (`276`, or `321/308` for rings, trinkets and one-hand weapons), then the
glyph and the difference without a sign in the verdict's color (`▲19` green, `≈0` yellow, `▼4` red), the
glyphs drawn, never boxes. A member who can't use it reads `Can't use` (gray), one still being read `…`, one
never read `Unavailable` (muted), one wearing nothing there `empty`. The widest cell (`321/308 ▼13` with two
icons) is not cut and does not run into Actions. Actions holds one Offer button per member (or a dash; superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72); there
is no second, grayed button. Hover Their eq → the gear grid (FEED-62) and the verdict's explanation, the
words the old pill's tooltip held. Result:

**FEED-57. The Offer panel's rows: no class bar, alternating stripes (DW-G0, feedback-7 spec §0).** The
headless `test_offer_panel` (`no class bar; every second row striped`) covers the regions. Research
`08-offer-panel-rows.png` shows the class-colored bar. `/dw test` → open the Offer panel on a sample drop with
four or more members → no colored bar at any row's start; the member's name is still in their class color;
every second row has the same faint light stripe as the main window's Drops and History rows, across the
whole row, and the two look alike side by side. Result:

**FEED-58. An icon on every action button (DW-G1, feedback-7 spec §1).** The headless `test_mine_cells`
(`action icons:` cases) and `test_drops_layout` (`every action button's icon and word fit its width`) cover the
look tables and the arithmetic. Research `04-action-buttons.png` shows Ask and Offer without one. `/dw test` →
on Drops, `Ask` shows a chat-bubble icon and your own drop's `Offer` an export (hand-out) icon (superseded by feedback-10, 2026-10-14: `external-link`, a
box with an arrow leaving it; FEED-68), each tinted
with the button's color; `Asked`, `Queued`, `Retry` and `Traded` keep theirs. The same on the compact cards
(`/dw compact`), the detail card's Ask or Offer, each member's Offer in the Offer panel (`Offer`, `Offered`,
`Queued`, `Retry` all fit their 72-pixel button, icon and word, nothing cut; 80 pixels since feedback-11,
2026-10-14, so `No action` fits: FEED-72) and Announce to group. With
`toast.enabled` on, the toast's Ask shows the chat icon too. Result:

**FEED-59. Trade `No` in red (DW-G2, feedback-7 spec §2).** The headless `test_window_group` and
`test_own_drops` cover the tone. Research `07-trade-no-gray.png` shows the gray. `/dw test` → a sample drop its
looter can't trade reads `No` in the addon's red (the red of the down arrow and Retry), not gray, in the Drops
Trade column, the History Trade column, the compact card's trade piece (`/dw compact`) and the detail card's
`NOT TRADEABLE` chip. `Yes` and `Likely` stay green and `Unknown` muted. Result:

**FEED-60. Your own drop's looter `Name [YOU]` (DW-G2, feedback-7 spec §2).** The headless `test_own_drops`,
`test_compact_cards` and `test_detail_card` cover the text. Research `09-looter-column.png` shows the plain
name. `/dw test` → each of your own sample drops reads your name in your class color and ` [YOU]` after it in
gold, in the Drops and History Looter columns, the compact card's line 2 and the detail card's Looter row.
At the least width, and on a character with a long name if you have one → the name is cut first,
`[YOU]` always drawn whole; on the compact card the slot follows the mark without overlap. Result:

**FEED-61. `Upgrade for N`, and Trade without its count (DW-G2, feedback-7 spec §2).** The headless
`test_side_cells` and `test_own_drops` cover the words. Research `10-details-cell.png` shows `(Details)`.
`/dw test` → your own sample drop that upgrades two members reads `Upgrade for 2` in green in Them (the row,
the compact card's line 3 and the detail card's Them row); one that upgrades nobody `No upgrades` (muted); an
upgrade for you `Hidden` until you open its Offer panel. Trade reads `Yes` or `Likely` with no `(2)`; hover
it → the line `Upgrades 2 members: Offer shows who.` is still there. Result:

**FEED-62. Columnar gear tooltips with the table's arrows (DW-G3, feedback-7 spec §3).** The headless
`test_tip_marks` (`grid:` and `tooltip: a grid reserves a line per row` cases) and `test_side_cells` cover the
data and a headless paint; only the client lays out the font strings on GameTooltip. Research
`06-tooltip-arrow.png`, `11-details-tooltip.png` and `12-them-tooltip.png` show the old run-on lines. `/dw
test` → hover your own drop's `Upgrade for 2` → one row per member, biggest gain first, in four aligned
columns: the name in class color, the worn item level, the worn item in its quality color, then `▲` and the
gain, glyph and number both green, the `▲` the table's glyph (not a thin texture arrow, never a box). Each
column starts at the same x on every row, with a clear gap between columns, and the tooltip is wide enough
for the widest row. Hover Them on another player's drop → one row for the looter (two for rings, trinkets or
one-hand weapons, the arrow on the lower, the other's last column empty; `empty` muted for a slot worn
empty), then the read's age and the verdict's reasons as before, with no `X wears` or `Item level A against
B` lines. Hover Me → the same with `You`. The Offer panel's Their eq and the detail card's verdict chips too.
Then hover an item icon, a column label and another addon's frame → no leftover grid text in those
tooltips. Result:

**FEED-63. Post my tradeables above Sort, Scan group beside it (DW-G4, feedback-7 spec §4).** (Superseded by
feedback-10, 2026-10-14: Sort leaves the footer for the strip, which reads `[Post my tradeables] [Scan group]
[Sort]`, and Scan group keeps its place beside Sort while Post is hidden; FEED-70.) The headless
`test_drops_strip` (`Post my tradeables is Sort's size`, `the slots, pure`, `full layout, nothing tradeable`)
covers the geometry. Research `13-post-and-sort.png` and `14-scan-group-button.png` show the old places. `/dw
test` in the full layout → Post my tradeables is exactly as wide and as tall as the footer's Sort dropdown,
its right edge on Sort's, directly above it; Scan group sits just left of it (about 8 pixels), the same
height, and works (`/dw debug on` shows the scan). The title bar has no Scan group; the orange restriction
lock (under a boss's chat lockdown) sits beside the layout toggle. With drops listed but nothing of yours
tradeable (out of test mode and a group, `/dw sim start dungeon`, then `/dw sim loot 2` until none lands on
you) → the strip still shows, with no summary, Post gone and Scan group in Post's place above Sort. On History → no Scan group. `/dw compact` → the title bar's Scan group icon is back and
the shortened strip is unchanged. (Superseded by feedback-15, 2026-10-16: Scan group is Post's width, the
row reads `[Post my tradeables] [Scan group] [Expand all] [Sort]`; FEED-78.) Result:

**FEED-64. The empty state's buttons centered as a pair (DW-G4, feedback-7 spec §4).** The headless
`test_window_group` (`the empty state's two buttons are centered as a pair`) covers the arithmetic. Research
`15-empty-state-full.png` and `16-empty-state-compact.png` show the pair pushed left. With no drop at all
(out of test mode, `/dw clear`) → `No drops yet`, its line, then `Preview with test data`
and `Scan group` side by side with a small gap, the pair's middle under the text's middle, in the full and
the compact layout. Result:

**FEED-65. When to show as one table (DW-H0, feedback-8 spec §0).** The headless `test_settings_pages`
(the `when to show:` cases) covers the rows, the paint, the writes, the dimming, Defaults, a profile switch
and the re-hosting. Research `docs/superpowers/research/2026-10-13-feedback-8/01-when-to-show-today.png`
shows the old blocks, `02-loothistory-price-sources.png` the look. Open General › When to show → Auto-open
the window at the top, then one table: gold, left-aligned headers Situation, Track, Auto-open and Quality in
a band, then one line per situation in order (Mythic+ first, Solo last), every second line faintly striped,
the checkboxes the panel's gold tick and the Quality dropdowns sized to their column, nothing clipped or
overlapping. Hover a Track, Auto-open or Quality cell → its row's label and tooltip; hover a name → the
situation. Untick Delve's Track → its name grays and its Auto-open and Quality dim; tick it → they light, and
`/dw get situations.delve.track` follows each click. Set Dungeon's Quality to a mode → `/dw get
situations.dungeon.quality` reads it. Untick Auto-open the window → every line's Auto-open dims; tick it →
they light (an untracked line's stays dim). `/dw set situations.raid.track false` with the page open → Raid's
line repaints. Switch to Master controls and back, close and reopen the panel, and switch to another page and
back → the table draws once, in place, with no stray copy on another tab or page. Change a few cells, press
the header's Defaults and accept → the table shows the defaults (Mythic+, dungeons and raids tracked and
auto-opening, Raid Finder tracked only, the rest off, Quality `Use global`). Switch profile on the Profiles
page and return → the table shows that profile's values. Result:

**FEED-66. The toast as four rows beside a four-row icon (DW-I0, feedback-9 spec §0).** The headless
`test_toast` (`Compose answers the four rows' parts`, `the longest rows fit at Toast.WIDTH`, `the four rows
beside a four-row icon, painted` and the right-click cases) covers the parts, the paint and the widths.
Research `docs/superpowers/research/2026-10-13-feedback-9/01-toast-today.png` shows the old line, cut at
`Likely trad…`, and `02-table-verdict-marks.png` the Me and Them cells' look. Settings › Window › Toast ›
Show a toast on, then `/dw test` → the toast is 350 pixels wide and its item icon spans all four rows (about
56 pixels square, the toast's insets even all round). Row 1: `Big upgrade for you` in gold, Ask and the close
mark at its right. Row 2: the item's name in its quality color (purple for epic), then its item level in
smaller gray text; with a long name the name is cut, never the level. Row 3: `Looted by Seta`, the name in
its class color, then `You ▲19` and `Them` with its verdict, each glyph (`▲`, `≈`, `▼`) drawn in the
monospace face, never a box, glyph and number in one tone (green upgrade, yellow sidegrade, red
downgrade); a verdict in a word (`Can't use`, `Not wanted`, `?`) reads gray with no glyph; `You`, `Them` and
the `·` separators muted; no signed `+19` and no texture arrow. Row 4: `Likely tradeable` in green then the
reason in gray (`not an upgrade for Seta`), cut with `…` only at the right inset; hover the toast → its
tooltip is the Trade cell's, with the full reason. Rows 2 to 4 run to the right inset and nothing overlaps
Ask or the close mark. Right-click anywhere on the toast, the icon included → it goes, as the close mark
does, and the drop does not toast again; a left-click keeps it, and in test mode the left button still
drags it. Result:

**FEED-67. The downgrade glyph is filled (DW-J0, feedback-10 spec §0).** The headless `test_window_group`
(`cells: Me shows ▲ ≈ ▼`), `test_tip_marks` (the arrow cell), `test_toast`, `test_compact_history` and
`test_compact_modes` cover the glyph's text. Research `docs/superpowers/research/2026-10-14-feedback-10/01-hollow-down-arrow.png`
shows the old hollow `▽`. `/dw test` → every downgrade in the Drops table's Me and Them cells reads a filled
`▼` before its difference (`321/308 ▼8`), in red and the monospace face, never a box, the same height and
weight as `▲` beside it; History's Me and Them (`▼4`) the same. `/dw compact` → line 3's downgrades read `▼`
on Drops and History cards. Hover a Me or Them cell → the tooltip grid's arrow column draws `▼` too. Open the
Offer panel on one of your drops → Their eq's downgrades read `▼`. With `toast.enabled` on → the toast's row 3
reads `Them ▼13` for a downgrade. The texture marks (the detail card's `DOWNGRADE` chip, the legends) are the
solid arrow as before. Result:

**FEED-68. Offer wears `external-link` (DW-J1, feedback-10 spec §1).** The headless `test_mine_cells` (`action
icons:` cases), `test_own_drops` and `test_offer_panel` (`each member's Offer is cyan`) cover the look tables.
Research `02-offer-icon.png` shows the old `export` icon and `05-offer-icon-options.png` the options the owner
chose from. `/dw test` → your own drop's `Offer` on its Drops row shows a box with an arrow leaving it,
tinted cyan with the button; the same on its compact card (`/dw compact`), on the detail card's Offer (its Trade
beside it keeps the two opposing arrows, a different mark) and on each
member's Offer in the Offer panel, the 72-pixel button (80 since feedback-11, 2026-10-14: FEED-72) still fitting icon and word. `Queued`, `Offered`,
`Traded` and `Retry` keep their own icons; Ask keeps its chat bubble. Result:

**FEED-69. The compact card, simplified (DW-J2, feedback-10 spec §2).** The headless `test_compact_cards` (`no
trade window on the card`), `test_compact_group` (`no card shows a trade window`, `a second's tick leaves the
cards as they are`, `at the least width line 2's pieces end before the action button`) and
`test_compact_history` cover the pieces and their places. Research `03-compact-cards.png` shows the old cards.
`/dw test`, `/dw compact` at 440 → each Drops card's line 1 reads the item level then, a small gap after it,
the name in its quality color (`292 Item name`); with a long name the name is cut, never the level; no item
level at the right; the inspect freshness follows the name in brackets, dimmed (`(2m)`, `(cached)`, `(…)`;
no `(…)` since feedback-11, 2026-10-14, Them's `…` says it: FEED-71),
and is left out where there is nothing to say (your own drop: no `–`), a long name cut before it. Line 2:
looter · slot · type · trade, then the action button at the right (Ask, Offer on your own, their states); with
no action the slot is empty, hovering it still says why (superseded by feedback-11, 2026-10-14: the gray
`No action` button with its reason; FEED-72); nothing overlapping at 440 with a twelve-letter
cross-realm looter.
No card shows a trade window countdown or bar, your own drops included; the full table's Trade window column
and the strip's `next 0:08:41` still tick. Line 3: `You` and `Them` in gold, Them a short gap (about 12
pixels) after You's last piece rather than at mid-card (`You 321/308 ▼13   Them 298/296 ⊘ Can't use`). On
History → the same line 1 with the outcome at the right, the time on line 2, line 3 the same. Result:

**FEED-70. Sort on the tab's strip (DW-J3, feedback-10 spec §3).** The headless `test_drops_strip` (`one row,
right-aligned`, `Sort follows the active tab`, `the slots, pure`, `full layout, nothing tradeable`) and
`test_compact_chrome` (`the full layout takes every control back`) cover the anchors. Research
`04-strip-sort.png` shows Sort in the footer. `/dw test` in the full layout → the Drops strip reads, at its
right, `[Post my tradeables] [Scan group] [Sort]`, about 8 pixels apart, Sort at the strip's right edge, Post
as wide and tall as Sort; the footer holds only its health segments, nothing beside the corner grip. With
nothing of yours tradeable (as FEED-63) → Post is gone and Scan group stays beside Sort, nothing slides.
Click History → Sort is at the right edge of History's strip, Clear history just left of it; set Sort to
Oldest there, back to Drops → Sort is on the Drops strip again and reads Drops' own value. `/dw compact` →
Sort is in the Filters panel, Clear at the History strip's right edge; `/dw full` → Sort back on the active
tab's strip. Hover Sort → its tooltip opens above it. Result:

**FEED-71. Pending once, and the card's full width (DW-K0, feedback-11 spec §0).** The headless
`test_compact_cards` (`the freshness mark is bracketed, and left out where there is nothing to say`),
`test_compact_modes` and `test_compact_group` (`at the least width line 3's fullest halves fit`) cover the mark
and the bound. Research `docs/superpowers/research/2026-10-14-feedback-11/01-pending-twice.png` shows `(…)`
after the name and `Them …` on the same card. `/dw test`, `/dw compact` at 440 → a Drops card whose looter's
read is still pending shows nothing after the name, while its line 3 reads `Them …`; the other freshness marks
still follow the name in brackets, dimmed: `(2m)`, `(cached)`, `(range)`, `(combat)`, `(!)`. A card with a long
Them half (two worn items and a worded verdict) has its last piece cut with `…` at the card's right inset,
never running past the card's edge or under the scroll bar; line 1's long name likewise runs to the right
inset before it is cut. Line 2 alone stops short of the action button. Result:

**FEED-72. No action (DW-K1, feedback-11 spec §1).** The headless `test_window_group` (`a drop with no ask
offered shows the gray No action button with its reason`), `test_compact_group` (`no ask offered shows No action
and why`), `test_detail_card`, `test_own_drops`, `test_offer_panel` and `test_drops_layout` (`every action
button's icon and word fit its width`) cover the look and the fit. `/dw test`, full layout, Drops → every row
with no action (Trade `No`, a bonus roll, not an upgrade for you, the looter unknown, your own drop that cannot
be traded) shows, in Actions, a gray `⊘ No action` button, dimmed like a disabled button, where a dash was;
clicking it does nothing; hovering it shows a tooltip titled `No action` with the reason. The icon and word fit
the 84-pixel button, nothing cut. Expand such a row → the detail card's first action is the same gray
`No action` (no disabled `Ask` or `Offer`). `/dw compact` → the same card's line 2 ends in the gray `No action`
button, never an empty slot, with the same tooltip. Open the Offer panel on one of your drops → a member it is
no upgrade or equal for shows the gray `No action` in Actions, its tooltip the reason, fitting the 80-pixel
button; an untradeable drop of yours shows it on every member's row. Result:

**FEED-73. History's outcomes in the action buttons' colors (DW-L0, feedback-12 spec §0).** The headless
`test_history` (`each row's outcome painted`), `test_compact_cards` (`every History outcome keeps its word and
tone`) and `test_compact_history` cover the tones. `/dw test`, History, full layout → the Outcome column reads
`Asked` and `Offered` in yellow, `Received` and `Traded away` in green, `Expired` in red, `Seen` and `Declined`
in gray (the No action gray), the same colors as the action buttons on Drops. `/dw compact` → each History card's
outcome at line 1's right in the same colors. Result:

**FEED-74. No `0 shown` header where Character or Content left a group empty (DW-L1, feedback-12 spec §1).**
The headless `test_char_filter` (`a group Character and Content leave empty shows no header, full or compact`)
and `test_window_group` (`KeepsHeader`) cover it. With History holding groups kept before the Character dropdown
(no recorder) or seen by an alt: History, `Character: Current`, `Content: All` → no header reads `· 0 shown`,
only groups with a drop shown are listed; the footer still counts every kept group. `/dw compact` → the same.
`View: Interesting` hiding a group's every drop → its header still shows, `n drops · 0 shown`. Result:

**FEED-75. Each tab's default filters (DW-M0, feedback-13 spec §0).** The headless `test_window_shell` (`each tab
opens on its own defaults`), `test_sim_e2e` and `test_compact_chrome` cover it. On a profile that never changed
Settings › Feed › Content: `/reload`, `/dw` → Drops reads `View: All`, `Quality: Rare+`, `Content: This session`,
`Character: Current`. Select History → `View: All`, `Quality: Rare+` grayed, `Content: All`, `Character: All`, and
every character's groups are listed. Back to Drops → its own values again. `/dw compact` → History's Filters
button reads `Filters` with no count; pick `Character: Current` there → `Filters · 1`. Result:

**FEED-76. No Lua error from a gear tooltip in combat (DW-N0, feedback-14 spec §0).** The headless
`test_tip_marks` (`a secret width or line count in combat`) covers it. In a dungeon or raid, with BugSack on: let
another player loot a drop during a pull, then hover its Me and Them cells (and a compact card's You and Them)
while still in combat → the gear grid shows, its columns perhaps a little wider than out of combat, and BugSack
records nothing from `TipGrid.lua`. Hover again out of combat → the columns fit as before. Result:

**FEED-77. Content per tab (DW-Q1, feedback-15 spec §1).** The headless `test_content_tabs`, `test_compact_chrome`
and `test_compact_modes` cover it. `/dw` → open Drops' Content → `This instance` and `This session` only; hover
it → the tooltip names This instance (since you entered this instance or started this key), This session (since
you logged in; a /reload keeps them) and All (History only). Select History, open Content → `This instance`,
`This session` and `All`, the tab still on `All`, the same tooltip. Drops on `This session`, `/reload` → every drop
since the login is still listed. `/dw compact` → the Filters panel's Content offers the same values per tab. On a
profile whose Settings › Feed › Content was `All` before this version → it reads `This session`, and so does
Drops. Result:

**FEED-78. One footer button kind, and Expand all / Collapse all (DW-Q2, feedback-15 spec §2).** The headless
`test_footer_row`, `test_drops_strip` and `test_compact_history` cover it. `/dw test` in the full layout → the
Drops strip reads, right to left, Sort, `Expand all`, `Scan group` and `Post my tradeables`, the three buttons
exactly as wide as Sort, about 8 pixels apart, each with its icon; the `n tradeable · next expiry` text on the
left ends before Post, and narrowing the window cuts it with `…` rather than run it under the buttons. With
the older groups collapsed (the default) click `Expand all` → every group opens and the button reads `Collapse
all`; click it → every group closes and it reads `Expand all`; open one header by hand → still `Expand all`.
Search for something no drop matches → the button is grayed out. Select History → Sort, `Expand all`, `Clear
history` (each the same width) and the toggle works there on its own: History's groups open or close, Drops'
stay as they were. `/dw compact` → Drops' strip shows even with nothing of yours tradeable, `Expand all` at its
right and `Post my tradeables` (full label, same width) left of it while something is tradeable, no `Post`;
Sort is in the Filters panel and Scan group the title bar's icon; History's strip reads `Expand all` with
`Clear history` (no `Clear`) left of it; the toggle opens and closes the cards' headers on both tabs. (Since
DW-Q3 History's strips carry no Clear history: it is in Settings, HIST-6.) Result:

## Roster

The resolver's rules are headless-tested (`test_roster`); these checks confirm the client's spelling
of names and realms. Each reads the `roster` lines of `/dw diagnostics`, with `/dw debug on` for the
`[ROSTER]` change lines.

**ROSTER-1. Names and realms.** In a party with at least one player from another realm, ideally one
whose realm has a space or a hyphen (`Area 52`, `Azjol-Nerub`) → one `roster:` line per member,
the same-realm ones as `Name-<YourRealm>` and the cross-realm ones as `Name-<Realm>` with no space
or hyphen, each with the right `unit=party1..4` and `class=`. Then compare each cross-realm name
against how a loot line in chat spells it: the same `Name-Realm`, realm spelled the same way.
Record any member whose realm differs. Result:

**ROSTER-2. Raid and online state.** In a raid (or a converted party) → `unit=raid1..N`, your own
line carrying `player=true`. Have a member log out → after the next `[ROSTER]` line their
`online=false`. Leave the group → `roster: 1 members` with you alone at `unit=player`. Result:

**ROSTER-3. The roster survives a raising handler on its shared event (DW-P18, review C-03).** In a
party with a second character, `/console scriptErrors 1`. Run
`/run local D=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); D._s=D.OnSituationEvent; D.OnSituationEvent=function() error("probe") end`,
then have the second character leave and rejoin the party → one Lua error `probe` per roster update,
and `/dw diagnostics`'s `roster:` lines (and the window's group header tooltip) show the member gone,
then back. With `/dw debug on` the console has an `[Init] GROUP_ROSTER_UPDATE: OnSituationEvent
raised: …probe` line for each. Restore with
`/run local D=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); D.OnSituationEvent=D._s` (or
`/reload`). A roster that stays stale while the error shows is the failure. Result:

## Item facts

The facts and the load are headless-tested (`test_item_facts`); these checks confirm the shapes the
client answers, which the mock models from the API documentation. Each is a `/dump` on an item link
(shift-click the item into the chat box after `/dump `).

**ITEM-1. The readers' shapes.** On a unique-equipped ring or trinket →
`/dump C_Item.GetItemUniquenessByID(link)` answers four values, the last a category id above 0 when
the item names a category ("Unique-Equipped: <Category> (2)"). On a drop with spec icons →
`/dump C_Item.GetItemSpecInfo(link)` answers a list of spec ids. On a tier token →
`/dump C_TooltipInfo.GetHyperlink(link)` holds a line whose `type` equals
`Enum.TooltipDataLineType.RestrictedRaceClass` and whose `leftText` reads `Classes: ...`. On a piece
you have collected → `/dump C_TransmogCollection.PlayerHasTransmogByItemInfo(link)` answers `true`.
Record any reader that answers another shape. Result:

**ITEM-2. The track ids.** On one item of each upgrade track you can find (Adventurer, Veteran,
Champion, Hero, Myth) → `/dump C_Item.GetItemUpgradeInfo(link)` answers `trackString` and
`trackStringID`. Record each pair: they fill `C.TRACK_TIER_BY_STRING_ID` so a localized client gets
a track tier. Result:

**ITEM-3. A real drop reads at its real level and quality (BUG-1).** `/dw debug on`, run a Mythic+
dungeon (or any content whose loot carries an upgrade track or scales to your level) and loot an
item yourself, ideally one that also reaches the feed through the encounter's report. → Drops
lists it at the item level and in the quality color its own game tooltip shows (the owner's case:
*Lustrous Golden Plumage*, 311 and Epic, never 19 and Rare). If the console showed `also reported by
encounter` before the chat line, it also shows `(its more complete link taken)` on the chat line's merge. Once the
item is in your bags (a second or two after the loot window closes) the console shows `read from its
bag item <bag>:<slot>`, and `/dw diagnostics` shows a `drops:` line for it reading `complete=true
ilvl=<the tooltip's level> (current) quality=<4 for Epic> (location) mine=true bag=yes`. Its Me
verdict and its Trade window agree with the game tooltip's own "You may trade this item…" line.
Record any drop whose level or color differs from its tooltip, and paste its `drops:` line. Result:

**ITEM-4. The real game tooltip, everywhere (BUG-2).** Hover an item in each place: a Drops row of
your own (the icon and the name), another player's Drops row (the icon and the name), the detail card's icon, name and
Replaces row for you and for the looter, the Offer panel's icon and name, a History row, the toast's
icon, and the Them icons (the Their eq column until DW-F1). → Each shows the game's own item tooltip, exactly as hovering the
item in your bags or on the character sheet does, with the addon's line (shift-click to link,
ctrl-click to try on) after the game's lines. Your own drop that is still tradeable shows the
client's "You may trade this item with players that were also eligible to loot this item for the
next …" line; your own worn item in the Replaces row shows your equipped copy (its enchant and gems).
Move your own drop to another bag slot and hover again → still the right tooltip. Record any place
that shows a tooltip built from text, or misses the trade line. Result:

**ITEM-5. A multi-stat item is judged for every primary stat (2026-10-15, Fireproof Drape).** In a
group with a player of another primary stat than yours (as a hunter: a Blood death knight or a
Retribution paladin), loot or watch a cloak, or a plate, leather or mail piece, whose tooltip lists
more than one primary stat (the inactive ones grayed). → The detail card's primary-stat chip reads
every one of them (`Str/Agi/Int` on a cloak), never yours alone; the drop is judged for that player
by item level against what they wear (Them, or your own drop's Upgrade for), never `Its primary
stat does not suit the spec`. A genuinely single-stat item (an Agility trinket) still reads as
unusable for a Strength spec. Record any multi-stat item judged by your own primary stat alone, with
its link. Result:

## Gear

The snapshot, the owned best and the throttle are headless-tested (`test_gear`); these checks
confirm the client's answers. Each reads the `gear` lines of `/dw diagnostics`, with `/dw debug on`
for the `[GEAR]` change lines.

**GEAR-1. Worn and owned.** With a full set on → `gear: class=<YOURCLASS> spec=<your spec id>` and
one line per slot whose `ilvl=` matches the item level on that item's tooltip, the shirt and tabard
slots `empty` when you wear none. Put a better item for one slot (a higher-level ring, say) in your
bags → after the next `[GEAR]` line that slot shows `owned=<its level>`. A dual wielder with a spare
one-hander → the off hand shows it as owned when it beats the worn one. Record any slot whose level
differs from the tooltip. Result:

**GEAR-2. The rebuild events.** Swap one item → one `[GEAR]` line about half a second later, naming
the event that started it (`PLAYER_EQUIPMENT_CHANGED` or `BAG_UPDATE_DELAYED`); swapping several in
a burst still writes one line. Change your
specialization → a `[GEAR]` line with the new spec, naming `PLAYER_SPECIALIZATION_CHANGED`. Right
after login, any slot still `loading` turns into its level without another action. In combat, use a
potion or loot an item → no `[GEAR]` line until the fight ends, then at most one, naming
`afterCombat` (when the bags changed what you own). Result:

## Inspect

The queue, its timeouts, the hook and the cache are headless-tested on a mocked clock
(`test_inspect`); these checks confirm what the client really does. Until `/dw scan` (DW-42) the
warm-up starts every inspect: be in a party inside a dungeon (a tracked situation). Each reads the
`inspect` lines of `/dw diagnostics`, with `/dw debug on` for the `[INSPECT]` lines (one per job).

**INSPECT-1. Warm-up and spacing.** In a dungeon with four others, all near you, `/dw debug on`
then `/reload` → about two seconds after the load, one `[INSPECT]` line per member, never two
within two seconds of each other, each `fresh` (or `cached`) with `spec=` that member's spec id and
`slots=` the number of items they wear (16 or so). `/dw diagnostics` then shows `queued=0
inFlight=none` and one `inspect:` line per member, `status=fresh` with the same spec. Record a
member whose spec or slot count is wrong. Result:

**INSPECT-2. The waits and the cache.** With one member far away (another zone, or across the
dungeon) during the warm-up → that member's line reads `outOfRange (range)` about 25 seconds later,
and the others are not held up behind it. Have a near member swap one item → within a few seconds
one new `[INSPECT]` line for them (stale, re-queued), and no further line for them after it: the
inspect's own arrival must not set off another (the five-second echo guard). Record a loop of lines
for one member, or a `fresh ... (incomplete)` line (a slot that never completed). Result:

**INSPECT-3. Courtesy and combat.** During a warm-up, right-click a member → Inspect, and keep
Blizzard's inspect window open → no `[INSPECT]` line while it is open, and its contents are not
blanked under you (the broker clears only its own inspect); close it → the queue moves on within a
second or two. Start a pull while members are still queued → no `[INSPECT]` line until the combat
ends, then the rest follow. With another inspect addon loaded (Details!, an item-level addon), the
two take turns: no `failed (timeout)` lines in a quiet group. Result:

**INSPECT-4. The inspected item level, and the fast path.** After INSPECT-1, for one member
compare `/dump C_TooltipInfo.GetInventoryItem("party1", 1)` (its `ItemLevel` line) with
`/dump C_Item.GetDetailedItemLevelInfo(GetInventoryItemLink("party1", 1))`. Record whether they
differ, in normal content and in scaled content (timewalking): if they never do, the tooltip read
is not needed. Then `/reload` again in the same group → members whose data the client still holds
show `cached` (no inspect sent); record whether a `cached` line ever carries a wrong spec or a
missing slot. Then, for a member never inspected this session (one who just joined), `/dump
GetInventoryItemLink("party1", 2), GetInventoryItemLink("party1", 11)` before any inspect → record
whether the neck and ring answer nil while the chest (5) answers a link: the fast path refuses a
read whose neck, rings or trinkets are empty for that reason. Last, during a warm-up, open and close
Blizzard's inspect window on the member in flight → no `fresh` line with `slots=0` ever; a
`failed (empty)` line, or a second send, is the expected answer. Result:

## Trade

The estimator's decision is headless-tested (`test_trade_rules`); TRADE-1..4 confirm it against the
game's own trade rules. They read the Trade column's chips; the rules are the
`trade.rules.<situation>` rows, drawn on Settings › Trade › Rules (and `/dw list`). Read each chip's tooltip, and the `TRADE` debug lines with `/dw debug on`.
TRADE-5 (the own-item timer, DW-28) and TRADE-6 (the trade helper, DW-29) are below.

**TRADE-1. Binds.** A BoE drop shows `Yes` (BoE) whatever the looter's gear. A warbound or
account-bound drop and a bonus-roll drop show `No` with that reason. A drop in a follower dungeon or
a PvP reward shows `No` (legacy). Result:

**TRADE-2. The looter's item level.** In a dungeon or a key, a BoP drop for an inspected looter
whose equipped item in that slot is at or above the drop's item level shows `Likely` with both item
levels; one above their equipped item shows `No` (an upgrade for them); before the looter is
inspected the chip shows `Unknown` with the inspect state. Confirm one `Likely` by asking for the
item and seeing the trade succeed. More than four hours after the drop, the chip shows `No` (expired)
within half a minute, with no other event needed (the sweep). For your own BoP drop that is not an
upgrade, the chip shows `Yes` with the timer's countdown once the bag scan has read it, and `No`
(expired) once the countdown ends. Result:

**TRADE-3. The raid rule.** In a Normal or Heroic raid, find a BoP drop the game lets its looter
trade although it is an item-level upgrade for them, or one it refuses although it is not. Record
which rule the game applied: if raid loot is tradeable whatever the item level, the raid's default
rule changes from `personal` to `group` before release (design spec §7.2). Confirm too that
Settings › Trade's raid override to `group` turns the raid chips to `Likely` (group loot), and that
the reset restores `personal`. Result:

**TRADE-4. Equipped versus owned.** A looter whose equipped item is below the drop's item level but
who carries a higher one in their bags: record whether the game lets them trade the drop. The
estimator compares equipped gear only (an inspect sees nothing else); if the game counts the bags,
record it so the `Likely` chip's tooltip can say so. Result:

**TRADE-5. Your own item's trade timer.** The scan, the matching, the decoder, the ticker and the
warning are headless-tested (`test_trade_timer`); this check confirms the client's side. In a
dungeon, loot a BoP item that is not an upgrade for you (its tooltip says "You may trade this item
with players that were also eligible to loot this item for the next …"). With `/dw debug on`, a
`[TRADE]` line reads `scan (…): 1 own drops, 1 live timers` within about two seconds of the loot,
and `/dw diagnostics` shows `trade: timers live=1` and a `trade: drop … left=…s` line whose seconds
match the tooltip's time to the minute. Move the item to another bag slot → the same line, the same
`guid`. With the window closed `ticker=60s`; `/dw show` → `ticker=1s`; close it again → `60s`. For
the warning, wait until ten minutes are left (or `/dw set trade.warnAt 1800` and loot the item) → one chat line `[item]: 10 min left to trade it.` (or the minutes left),
once only, with no second line after a bag move or `/dw disable` then `/dw enable` (a `/reload`
forgets the warning, and warns again once).
Loot an upgrade you equip or an item with no trade line → `expired=true`, no countdown. Loot a
BoE drop → its `trade: drop` line reads `expired=false boe=true`, no countdown, and its Drops row reads
`No limit (BoE)`. The failure
looks like no `trade:` line for a tradeable item (the tooltip line or its sentence did not read:
record the tooltip text as shown), a time that drifts from the tooltip's, or a repeated warning.
Result:

**TRADE-6. The trade helper.** The guards and the call are headless-tested (`test_trade_helper`);
this check confirms the client's side, through the detail card's Trade (the Offer panel's Trade and
the give path behind it were retired with feedback-7 spec §0). In a dungeon, with a member standing
next to you who looted a drop: open that drop's detail card and click Trade → an empty trade window
with that member; cancel it. Walk out of trade range (about 11 yards) → the button is disabled with
"That player is out of trade range."; in combat → "You cannot trade in combat.", with no error from
the client and no Lua error from `CheckInteractDistance`. With `/dw debug on`, each click leaves a
`[TRADE]` `open:` line, or a `refused:` line with its reason; `/dw diagnostics` shows
`trade helper: opens=… refused=… last=…`. The failure looks like no trade window, a client
"Interface action failed" message, or a Lua error. Result:

## Ask

The messaging core's decisions (token expansion, the length limit, the one-ask guard, the queue's
order and cancel) are headless-tested (`test_messaging`), and the edge's send, queue, flush, cancel
and test-mode routing too (`test_asks`); these checks confirm the client's side. Your own drops'
Offer, the Offer panel's buttons and the strip's Post my tradeables are ASK-5..7 (DW-33, on Drops since
DW-E2/DW-E3) and auto-ask is ASK-8 (DW-54); ASK-1..4
drive the edge from the chat box, with a drop already in the feed (`/dw diagnostics` names the drops; `/dw debug on`
shows the `[MSG]` lines):

```
/run local DW = LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); local d = DW.LootFeed.Drops()[1]; print(d.id, d.looter.name, DW.Asks.Request("ask", d.looter.name, d.id))
```

Use a friend who knows the test is coming: every check whispers them.

**ASK-1. A whisper and its confirmation.** In a group, out of combat and outside any encounter, with
a drop the friend looted: run the line above → the friend receives "Hi <name>, if you don't need
[item], could I have it? It'd be +N for me. No worries if not!" with the item link intact, the chat
frame shows your own outgoing whisper, and the addon prints one line `Whispered <name>: [item]`;
the print reads `sent`. Run it again → `refused alreadyAsked`, and nothing is whispered. Swap
`"ask"` for `"announce"` (the target is ignored) → "[item] is up for grabs, whisper me." in party
chat (raid chat in a raid, instance chat in a dungeon finder group) and `Announced in <channel>:
[item]`. In a party (not a raid), `/dw set messages.announceChannel RAID` and announce again → the
print reads `failed noChannel`, nothing is posted and no `Announced` line appears; Post my
tradeables prints `Not announced: You are not in a group, ...` (DW-P17). Set it back to `auto`. The failure looks like a Lua error, no whisper with `sent` printed, a broken link, or a
`[MSG] send failed` line (record its reason). Result:

**ASK-2. Queued under a restriction, flushed at the kill.** In a dungeon, pull a boss and, during
the fight, run the line for a drop of an earlier boss → the print reads `queued`, a `[MSG] queued
... (encounter)` line appears, and nothing is whispered. Kill the boss → within about a second of
the kill the whisper goes out with its `Whispered` line and a `[MSG] flush (restrictionLifted)` or
`flush (ENCOUNTER_END)` line. With two or three asks queued (several drops, or two friends), they
leave about 1.5 seconds apart in the order they were asked. In a Mythic+ key, an ask queued between
pulls (record whether `challengeMode` holds it) goes out at the end of the key. The failure looks
like a whisper that never leaves after the kill (`/dw diagnostics` → `messaging: queued ...` still
listed), all of them at once, or a client "Interface action failed" message. Result:

**ASK-3. Cancel.** Queue an ask during a boss fight as in ASK-2, then run it again with `Press` in
place of `Request` → the print reads `ready canceled`, `[MSG] canceled ...`, and the kill sends
nothing. Queue another, then have the friend leave the group before the kill → `[MSG] canceled ...:
left the group`, and nothing is whispered after the kill. Result:

**ASK-4. A whisper during an encounter.** The design queues every ask while the Encounter
restriction is active, because the client is expected to block addon chat then. In a boss fight
(outside a key), run `/run C_ChatInfo.SendChatMessage("test", "WHISPER", nil, "<friend-Realm>")`
→ record whether the friend receives it, and any error or "Interface action failed" message. If it
arrives, the queue holds asks longer than it must (design spec §9.2 and COMBAT-2's reasons are
then revisited). Then, outside combat, turn test mode on (`/dw test`) and run the ASK-1 line with
`oneAsk` in mind (a drop not asked yet) → `Test mode, not sent: ...` is printed, the print reads
`sent`, and nobody is whispered. Result:

**ASK-5. Your own drops on Drops (the My drops tab until DW-E3).** In a dungeon, loot three or four items
of your own: one you will not wear (a downgrade), one that is an upgrade for you, and, if the boss drops it,
a bonus-roll item. Open the window → Drops lists them with everyone's, one row each (no tab of their own,
no count on the tab): the item button, its item level, Me (your worn item, then `▼5` in red, or `▲3` in green;
FEED-49), Trade with the count of members it upgrades (`Yes (2)`; FEED-42), Them as `(Details)` (`Hidden` on
your upgrade; FEED-43), `Trade window` (`1:59:40` over a green bar that shortens, matching the item tooltip's
time to the minute once the item is in your bags, `~1:59:40` for a moment before that) and `Offer`. The
bonus-roll row reads `Bonus roll` in its Trade window and a dash in Actions whose tooltip says why (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72), and no
Hide (DW-D2); it stays listed. With ten minutes or less left, the countdown turns bold amber (no `ending
soon` words since DW-E1), and the trade timer's chat warning prints once. The strip under the table reads
`2 tradeable · next expiry 0:08:41` (FEED-45). `Offer` is cyan before anything is sent (DW-F2; red from DW-D1). There is no
Announce button in the table: the Offer panel's `Announce to group` posts "[item] is up for grabs, whisper
me." in party (instance) chat and reads `Announced`, yellow and grayed; in a boss fight it reads `Queued`
and goes out at the kill. Hover every cell and button → each tooltip says why; nothing is blank. Result:

**ASK-6. The Offer panel, Offer and Trade.** (Superseded by feedback-7, 2026-10-13: the stripe, the
`291 → 305` text and the pill are one Their eq column in the Them look, and the panel's `Trade` button is
removed; FEED-56, FEED-57. The rest holds.) On the downgrade's row click `Offer` → a panel
`Who could use this? YOUR DROP` opens docked to the window's right edge (move the window to the screen's
right edge and it docks on the left instead; make the window nearly screen-wide and it floats over the
window's right half). Its header shows the item, `You: -5 ilvl · 305 · Trade window 1:47:12`, then every
other member with a class-colored stripe, `291 → 305` and a pill (`+14 UPGRADE`, `EQUAL`, `NO UPGRADE`,
`CAN'T USE`, `CHECKING`), upgrades first by gain; in a raid the list scrolls. Click `Offer` (cyan since DW-F2) on the top
member → they are whispered "Hi <name>, [item] is tradeable and looks like +14 for you. Want it?" and the
button reads `Offered` in yellow, as does the row's `Offer` on Drops (FEED-32). Standing far from them,
`Trade` is grayed with "That player is out of trade range."; walk up → click it → the trade window opens
with the item already placed; cancel it. `Announce to group` posts the announce once. On the upgrade's row,
`Offer` opens the panel and the row's Trade count and `(Details)` are now drawn (FEED-43). Close the panel
with its close mark. Result:

**ASK-7. Post my tradeables.** With two or more tradeable drops of yours, click `Post my
tradeables` on the strip under the Drops table (since DW-E3) → one party (instance) chat line `Up for trade, whisper me:
[item] [item]` with every link intact; with enough drops to pass 255 characters (or long names in a
raid) it is two or more lines, none cut mid-link. Click it again → it posts again. With none
tradeable the strip, and the button with it, is not shown (FEED-45). In test mode (`/dw test`) the lines are printed, not sent. Result:

**ASK-8. Auto-ask.** Its timing, its checks and its cancel rules are headless-tested (`test_auto_ask`); this
confirms the client's side. Settings › Messages › Auto-ask › Ask automatically on → chat reads the one-time
notice (`Auto-ask is on: … 5 or more item levels … 10 seconds after the boss kill or the drop.` and how to
turn it off); turn it off and on again → no second notice, and none after a `/reload`. `/dw test` with it on
→ about 10 seconds later chat reads `Test mode, not sent: …` for the sample drops that qualify, and nothing
is whispered. In a dungeon with `/dw debug on`, kill a boss whose loot gives someone else a likely tradeable
upgrade of 5+ item levels for you → `[MSG] auto-ask scheduled` when the drop lands, then 10 seconds after
the kill (or the drop, if later) the whisper goes with `Whispered <name>: [item]` and the row's Ask reads
`Asked`. Repeat with each cancel: press Ask yourself first (one whisper only) or have the looter leave the
group (none; dismissing the row was a cancel until DW-D2 removed it); each logs `[MSG] auto-ask canceled`
with its reason. Pull the next boss while one is waiting → nothing goes during the fight, and it goes 10
seconds after that boss dies. Result:

**ASK-9. Auto-ask after leaving an encounter (DW-62).** Auto-ask on, `/dw debug on`, in a dungeon
group. Pull a boss, then hearth out (or release and run out) before it dies. After the loading
screen (or a moment later, when the client reports the Encounter restriction lifted after it;
M6 review) the console reads `[MSG] auto-ask: left the encounter without its end; …` (only when
one was held) and `/dw diagnostics` shows auto-ask `inEncounter=false`. Have a member loot a likely
tradeable upgrade for you (or `/dw add` one naming them) → the whisper goes after the delay, not at
the next boss or `/reload`. Back inside, pull a boss and cross into another part of the instance
during the fight → nothing is asked until the boss dies. Result:

**ASK-10. A stored announce channel without its group is refused (DW-P17, review ANN-1).** One of
your own drops in the feed (`/dw add <item link>`), Settings › Messages › Announce channel = **Party**.
Solo: open the drop's Offer panel and press **Announce to group** → chat says `Not announced: You are
not in a group, so there is no channel to post in.`, no red system line about the party, and the
button stays pressable. Join a party with the second character and press it again → `Announced in
Party: [item]`, and the party sees it. Then set Announce channel = **Instance**, stay in the home
party (ANN-1b: a premade group outside an instance) and press it → refused with the same line,
nothing posted. Post my tradeables in the same two states → `Not announced: …` solo, posted in the
party. Set it back to Automatic after. A step that prints `Announced in` without the line appearing
in that channel is the failure. Result:

## Situations

The classifier's truth table is headless-tested (`test_situations`); these checks confirm that the
real client's answers land in the right row. Each reads the `situation` lines of `/dw diagnostics`,
with `/dw debug on` for the `[SIT]` change lines. The settings are General › When to show (PANEL-4);
the `/dw situation` verb's check is SLASH-5.

**SIT-1. Open world.** Alone in a city → `situation: solo`. Invite a friend → a `[SIT] situation
solo -> openWorldGroup (GROUP_ROSTER_UPDATE)` line, and the report reads `openWorldGroup`. Leave the
group → back to `solo`. Result:

**SIT-2. Dungeons and Mythic+.** Zone into a Normal or Heroic dungeon and a Mythic 0 → `dungeon`
with `difficulty=1`, `2` or `23`. Start a keystone → `mythicPlus` (the line names
`CHALLENGE_MODE_START`, `challengeMode=true`); after the timer ends it stays `mythicPlus` until you
leave. Result:

**SIT-3. Raids.** Queue for LFR → `raidLFR` (`difficulty=17`). A Normal, Heroic or Mythic raid →
`raid` (14, 15 or 16). A legacy raid run solo still reads `raid`. Result:

**SIT-4. Follower dungeons, delves, scenarios and PvP.** A follower dungeon → `followerDungeon`
(`difficulty=205`, `follower=true`). A delve → `delve` (`difficulty=208`, `delve=true`). Any other
scenario → `scenario`. A battleground or an arena → `pvp`. If a difficulty id reads differently from
these, record it: the ids live in `core/Constants.lua`. Result:

**SIT-5. Disabled and back.** With `/dw debug on`, `/dw disable` in the open world, zone into a
dungeon, `/dw enable` → one `[SIT] situation nil -> dungeon (standUp)` line, and no `[SIT]` line while
disabled. Result:

## Quality

The gate's decision is headless-tested (`test_quality_gate`); these checks confirm it on real loot.
Set the `feed.quality.*` rows on Settings › Feed › Quality (or with `/dw set`); its closing line,
`In force now: …`, must read what the filter bar reads.

**QUAL-1. Fixed.** Feed › Quality mode `Fixed` at Rare, upgrade override off. In a dungeon, an
Uncommon drop for another player is not listed and a Rare or Epic one is; the filter bar reads
`Quality: Rare+`. With `/dw debug on`, the hidden drop's debug line names the threshold. Result:

**QUAL-2. Upgrade override.** Same settings with the upgrade override on: an Uncommon drop that is an
upgrade for you (an empty or low slot) is listed; one that is not an upgrade stays hidden. Result:

**QUAL-3. Dynamic per slot and whole character.** Mode `Dynamic per slot`: a Rare drop for a slot where
you wear Epic is hidden, and a Rare ring is shown when your lower ring is Rare; the filter bar reads
`Quality: Match slot`. Mode `Dynamic whole character`: the filter bar reads
`Quality: Match gear (<quality>+)` with the most common quality you wear (shirt and tabard not
counted), and the diagnostics report shows the same threshold. Result:

**QUAL-4. Per-situation override.** Global mode `Fixed`, and General › When to show sets the dungeon's
`Quality` to `Dynamic per slot`. Entering a dungeon switches the filter bar to `Quality: Match slot`;
leaving it, back to `Quality: Rare+`. `Use global` restores the global mode. Result:

## Scoring

**SCORE-1. Pawn.** With Pawn installed and Settings › Comparison › Scoring › Score with on
`Automatic`: `/dw diagnostics` → `scoring: scorer=auto inUse=pawn` and `pawn ready=true scale=<your
spec's scale>`. `/dw add <shift-click a ring you carry>` → the detail card's **Pawn** line shows a
signed score, and a drop at a higher item level that Pawn scores lower reads `SIDEGRADE` with the
reason "Item level and score disagree". On a looter's drop once they are inspected, their side's
score uses their spec's scale. Turn Pawn off in the AddOns list and `/reload` → `inUse=none` (or
`weights` when you have set any), the footer reads `Pawn: off`, and verdicts are item level alone.
Score with `Pawn` while Pawn is off → `scorer=pawn inUse=none`. Result:

**SCORE-3. Pawn counts once it is initialized (DW-62).** Pawn installed, weights set for your spec,
Score with on `Automatic`. `/reload` and type `/dw diagnostics` straight away, then again ten
seconds later → the scoring line never pairs `inUse=pawn` with `pawn ready=false`: before Pawn is
ready it reads `inUse=weights`, after it `inUse=pawn`. Result:

**SCORE-2. Your weights and the Pawn import.** Without Pawn, set Score with to `My weights`. In
Settings › Comparison › Weights, paste a Pawn scale string (Pawn's Export of your spec's scale) into
**Import a Pawn scale** and press Enter → chat reads `Imported <name> into <spec>: n weights.` and
lists the Pawn keys not scored; the sliders show the imported values; the other specs keep theirs.
Paste `hello` → chat says it is not a Pawn scale string and nothing changes. `/dw diagnostics` →
`scorer=weights inUse=weights`. `/dw add` two drops of one slot whose stats differ → the score line, labeled **Weights**,
shows the weighted score's change and the verdict follows it as SCORE-1 describes. Result:

## History

**HIST-1. A completed trade.** Needs a group member and a tradeable drop. In a dungeon, let a
member loot an item that is a downgrade for them and an upgrade for you; press its Ask. Trade with
them (they put the item in), both accept → with `/dw debug on`, the console shows `[TRADE] trade
with <name> completed: gave 0, got 1` and `history: <item> received`; the Drops row's Ask
button reads `Traded ✓` and the History tab's row `Received`. Then trade one of your own drops away
(its Drops row's Offer › Trade, both accept) → its History row reads `Traded away` and the row's Offer
turns green. Cancel a trade
before both accept → nothing changes. Then a trade that fails after both accept (the partner's bags
full, or one of you walks out of range as the second accept lands) → no `completed` line and the
History row keeps its outcome. If no `completed` line appears after a real trade, record what
`/etrace` shows for `TRADE_ACCEPT_UPDATE`, `TRADE_CLOSED` and `UI_INFO_MESSAGE` (its message type
beside `/dump LE_GAME_ERR_TRADE_COMPLETE`) around the accept, and in which order. Result:

**HIST-2. The History tab, and the Drops tab across a reload (DW-51; DW-Q0, feedback-15 spec §0).**
In a dungeon, after a few drops (one of them yours, still tradeable), note the Drops tab's headers
and rows, then `/reload` → the Drops tab shows the same drops under the same boss or key headers
(Content: This session), each judged again: Me against your gear now, Them as the inspects return,
your own drop's countdown, Offer and Post my tradeables back once the bag scan matches it. No
window opens on its own, no toast shows and no automatic ask is sent for them. Loot one more item →
it joins the feed as usual, and the History tab gains that one drop only (no restored drop is
recorded twice). Log out and back in → the Drops tab is empty (the session is the login) while
History keeps everything; This session there now starts at the login.
Then `/dw history` → the tab opens on View:
All, Content: All and Character: All (feedback-13 spec §0), the drops are under their encounter's header (the newest open), each row
with its Outcome; a header of an older day reads `n days ago`. Right-click a row → a menu with
`Mark as declined`; choose it → the row reads `Declined`; right-click again → `Clear declined`
puts the earlier outcome back. Content: This session → only this login's drops, a reload's included. Settings ›
Window › Layout › Clear history (since DW-Q3; HIST-6) → a confirmation; No keeps everything, Yes empties the tab on this and your other characters, and chat
reads `History cleared.` Result:

**HIST-3. Keep history for (DW-A5, feedback-2 spec §5).** On the first login on this build, `/dw
debug on` → one held `[Migrate] v3 -> v4` line, and every kept group is still there; the History
footer reads `n groups, m drops · kept for 30 days` (no `of 20 groups kept`). Settings › Window ›
Layout › Keep history for lists 7, 14, 30, 60, 90 and 180 days and Never delete. Pick 90 → taken at
once, no question. With a group older than 7 days kept (or `/dw test`, whose `Placeholder boss
(alt)` is ten days old), pick 7 days → a confirmation, `This deletes n groups (m drops) older than 7
days.`; No → the dropdown reads 90 again, chat says nothing was deleted, and every group stays; pick
7 again and Yes → the older groups leave the tab at once. Pick 7 days with an older group kept and
`/reload` while the confirmation is still open → after the login the dropdown reads the window
agreed before, and no group leaves the tab (an unanswered confirmation deletes nothing). Never delete → the footer reads `kept
forever`. `/reload` with a group older than the window kept → about five seconds after the login it
leaves the tab (`/dw debug on` shows `history: login prune`). Log on to an alt → the same window and
the same groups (account-wide); switch profile → the window does not change. `/dw diagnostics` →
`feed: history groups=n drops=m/5000 keep=30d`. Result:

**HIST-4. The prune after a disabled start, and a stale confirmation (DW-A9, feedback-2 spec §8,
FB2-10).** The headless `test_history_retention` (`enabled later in a session that started
disabled`, `a later change that deletes nothing retires the open popup`, `only the latest popup's
answer counts`) covers the same ground. With a group older than the window kept, `/dw disable`,
`/reload`, wait ten seconds, then `/dw enable` → about five seconds later the old group leaves the
History tab (`/dw debug on` shows `history: login prune`), once only: `/dw disable` and `/dw enable`
again prunes nothing more. With an older group kept, pick 7 days so the confirmation opens; leave it
open and pick 90 days (deletes nothing) → the confirmation closes; if it stays on screen, its Yes
deletes nothing and the dropdown still reads 90. Pick 7 days, then 14 days while the first
confirmation is open → only the 14-day question counts: Yes deletes what 14 days puts out of reach
and the dropdown reads 14. Result:

**HIST-5. The undone Expired, and This instance across a reload (DW-Q0, feedback-15 spec §0).**
The headless `test_feed_restore` covers both. A drop of yours whose History row reads `Expired`
while its bag tooltip still shows a trade time (a false Expired from a rule estimate, the owner's
2026-10-16 report): once the trade timer reads it (open the bags, or wait for the scan) → the row
returns to what it read before (`Seen`, `Asked` or `Offered`); a drop whose trade time really ran
out stays `Expired`, and a row you marked `Declined` keeps that. In a dungeon with drops from the
first boss, Content: This instance, `/reload` → the same drops still show (This instance kept its
start); leave and enter another instance, or log out and in → This instance starts again. Result:

**HIST-6. Clear history lives in Settings (DW-Q3, feedback-15 spec §3).** The headless
`test_settings_pages`, `test_history`, `test_footer_row` and `test_compact_history` cover it. The
History tab's strip reads, right to left, Sort and `Expand all` in the full layout and `Expand all`
alone in compact: no `Clear history` on either. `/dw config` → Window › Layout → `Clear history` sits
on the line of Keep history for, at its right; hover it → its tooltip. Click it → the confirmation
`Clear the drop history on every character? This cannot be undone.`; No keeps everything; Yes
empties the History tab on this and your other characters and chat reads `History cleared.`. With
`/dw test` on, Yes empties only the sample groups: turn test mode off → the account's history is
still there. Result:

**HIST-7. The History tab's detail card (DW-Q4, feedback-15 spec §4).** The headless
`test_history_card` covers it. On the History tab each row has the Drops rows' chevron and is
indented under its header. Click a row → a card opens under it in the Drops card's style (the rows
below move down, the chevron points up, the row is tinted gold): the item and its chips (slot, type,
`ilvl N`, the outcome in its color), FOR YOU · AT THE TIME with the verdict and its deltas, FOR THE
GROUP with the looter and the Them verdict (on your own drop `Name [YOU]` and a Them line saying it
is not kept), the trade estimate in the Drops card's words, WHEN AND WHERE (the time, the instance,
boss and difficulty, the character that saw it). Click another row → the card moves; click the open
row → it closes. Right-click a row → the menu still opens and nothing expands. Link in chat → the
item's link in the chat box. Mark declined → the outcome reads `Declined` and the button `Clear
declined`; Clear declined → the earlier outcome. On a drop of this session still in the Drops tab,
Show in Drops → the Drops tab, the drop's header open and its card expanded; on an earlier
session's entry it is off and its tooltip says why. `/dw compact` → the same card, stacked, under
the clicked card. Result:

## Toast

**TOAST-1. The upgrade toast.** Settings › Window › Toast › Show a toast on, then `/dw test` → a
toast under the top of the screen reads `Big upgrade for you`, the name of Seta's head item (a real
item since DW-84) and `Looted by Seta · +19 ▲ · Likely tradeable` (superseded by feedback-9,
2026-10-13: four rows, `Looted by Seta · You ▲19 · Them …` then `Likely tradeable · <reason>`; FEED-66), with an Ask button and a close mark; it stays while test mode is
on. Drag it somewhere else, `/dw test` off (it goes), `/reload`, `/dw test` → it comes back where you
left it. Outside test mode it cannot be dragged. Window › Layout › Reset position → back under the
top. With Play a sound on, each toast plays the epic loot sound. In a dungeon with a group member,
when a drop of theirs is a 10+ item-level upgrade for you and likely tradeable → the toast shows
once, goes after 8 seconds, and stays while the pointer is over it (it then has the seconds it had
left); press Ask → the button reads `Queued` or `Asked` and the whisper goes as from the row. A
second qualifying drop waits until the first goes. Pull a mob while one is due → nothing shows in
combat, and it shows when combat ends; with Show in combat on, it shows at once. Result:

**TOAST-2. The toast leaves with its drop and with its switch (DW-62).** Toast on, `/dw test` → the test
toast shows. Untick Settings › Window › Toast › Show a toast → it goes at once (a test toast has no
countdown, so nothing else would take it down). Tick it again and turn test mode off and on → the toast is
back. (The row's × that took the toast down is gone since DW-D2.) Out of test mode, in a group:
`/dw add <a link you would upgrade> <member>` → a toast; `/dw clear` → it goes at once. `/dw add` again,
then Settings › Profiles › switch to a profile with Show a toast off → it goes. In none of these does the
toast's Ask stay pressable for a drop that is gone, and no Lua error shows. Result:

**TOAST-3. An upgrade into an empty slot toasts and auto-asks (DW-62).** Take off a ring. Toast on
with Least gain 50, auto-ask on. In a group: `/dw add <a BoE ring link> <member>` → a toast reading
`Looted by <member> · empty ▲ · Tradeable` (superseded by feedback-9, 2026-10-13: row 3 reads `Looted
by <member> · You ▲ empty · Them …`, `empty` in green, and row 4 `Tradeable` with its reason; FEED-66); after the auto-ask delay the whisper goes and reads
`It'd be an empty-slot upgrade for me`: never the ring's item level, never `+?` and never `+an`.
Result:

**TOAST-4. The toast with LibKa0s present (DW-P21).** Toast on, `/dw test` → the close mark sits in the
toast's top-right corner and Ask to its left; click the mark → the toast goes. (Without the library the
mark is absent, never a typed `×`: DEGRADED-2.) Result:

## Transmog

**TMOG-1. The look chip and the For transmog ask.** `/dw test`, open the Drops tab and expand
Seta's head item (real items since DW-84) → its header has a gray `Look known` chip; expand
Littlewolf's one-hand weapon → a green `New look` chip, and its Ask is a dash (`It is not an upgrade
for you.`; superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72). Settings › Messages › Sending › Ask for transmog on → the weapon's Ask is offered, its tooltip reads `Ask for
transmog`; press it → chat prints the For transmog template (`… could I have it for transmog? …`),
not the plain ask. Messages › Templates shows four editors; edit Ask for transmog and its preview
follows. In a group, on a real drop someone else looted that is no gain for you: `/dump
C_TransmogCollection.PlayerHasTransmogByItemInfo(link)` → `false` for a look you lack, and the card
shows `New look`; the Ask whispers the For transmog text. With CanIMogIt installed, `/dw diagnostics`
→ `transmog: source=CanIMogIt`, and an item whose look you know from another item shows `Look
known` (CanIMogIt's own tooltip agrees); without it → `source=C_TransmogCollection`. Record a cloth
or mail drop on a plate character: whether the card says `New look` for a look your class cannot
collect. Result:

## Simulator

**SIM-1. Start and stop, the refusals, nothing sent (DW-70).** The headless `test_sim_core` covers
the same ground. Solo, outside an instance and out of combat:
`/dw sim start dungeon` → chat says `Simulation started (…): nothing is sent, and your saved history
is not touched.` Ask for a simulated drop → chat prints `[sim] WHISPER to <name>: <text>` and your
whisper tab shows nothing sent. `/dw sim stop` → `Simulation stopped.`, the simulated drops leave the
Drops tab, and the History tab shows only your real history. Each refusal prints its own line:
in a group (`… cannot start in a group: leave it first.`), inside an instance, in combat, with test
mode on (`Turn test mode off before starting a simulation.`), and a second start while one runs.
While one runs, `/dw test` → `Test mode is not available while a simulation runs.` Start one, then
join a group → `Simulation stopped: you joined a group.`; start one, then `/dw disable` →
`Simulation stopped: the addon was disabled.` After a `/reload`, no simulation is running and
`/dw history` shows no simulated drop. Result:

**SIM-2. A full `key` run (DW-73).** The headless `test_sim_scenario` (`sim e2e key`) covers the same
ground. Solo, outside an instance, out of combat, with `/dw debug on`: `/dw sim start key` → chat says
`Simulation ready: 4 members, <n> items. …`, the window opens with cyan `SIMULATION` text beside the title
(its tooltip names `Scenario: key (Mythic+)`), and the footer reads `Simulating: Mythic+ · 4 members`.
`/dw sim run` → over about half a minute the badge shows `Mythic+ key`, then each boss's `Encounter`
in turn, then `Chat lockdown` after the completion; the completion's loot lands in Drops, yours among
it, the debug log shows one `[SIM] event …` line per injected event and one `[SIM] timeline step
n/11: …` per step, and chat ends with `The simulation's timeline has finished.` Press Ask on a member's
drop while the lockdown holds → it waits in the badge's queue; when it lifts, chat prints `[sim]
WHISPER to <member>: <text>` and the whisper tab shows nothing sent. Each drop shows your verdict and,
within a few seconds, the looter's. `/dw diagnostics` → the `sim:` lines show `scenario=key`, the
pool's size and `source=journal`, `timeline step=11/11` and the sends printed. Result:

**SIM-3. A `raid` run with a large roster (DW-73).** The headless `test_sim_scenario` (`sim e2e raid`)
covers the same ground. `/dw sim start raid 19` → the Drops tab's roster shows 19 invented
members besides you (raid2 onward), the footer reads `Simulating: Raid · 19 members`, and `/dw
situation` says Raid. Turn on Settings > Messages > Auto-ask, then `/dw sim run` → two bosses, each
with a loot burst of five lines from random looters (a member from another realm named Name-Realm).
Record how long the inspect warm-up takes to read all 19 (the footer's `Inspect n/19 fresh`), whether
any automatic ask goes out (`[sim] WHISPER`, never a real whisper) once the second boss is down, and
the frame rate while the burst lands. `/dw sim trade <id>` on a member's drop → the History tab shows
it `Received`. `/dw sim stop` → the roster is you alone, and the History tab shows only your real
history. Result:
**SIM-4. Inspect replies, the lockdown queue and its flush (DW-72).** The headless `test_sim_events`
covers the same ground. Solo, outside an instance, with `/dw
debug on`: `/dw sim start dungeon` → the Drops tab's roster shows four invented members, and
the footer's situation is the dungeon. `/dw sim loot 1 <member>` → the drop shows the looter's name
(a member from another realm as Name-Realm) and, within a few seconds, a Them verdict; the debug log
shows `[SIM] inspect of <member>: reply in <n>s` and no real inspect window opens. Record whether the
member's spec shows on the drop's detail card (the broker reads it after its own clear; the
simulator answers as the client does). `/dw sim pull` → the badge shows the encounter; press Ask on
a member's drop → it is queued, nothing is printed. `/dw sim kill` → within a few seconds chat prints
`[sim] WHISPER to <member>: <text>`, and the whisper tab shows nothing sent. Result:

**SIM-5. Your own drops' trade windows and a simulated trade (DW-72).** The headless `test_sim_events`
covers the same ground. `/dw sim start dungeon`, then `/dw
sim loot 2 me` → Drops shows both with Offer, the first with about 9 minutes left in its Trade window (it warns at once, since
the warning is at 10 minutes) and the second with about 4 hours; your real bags are unchanged.
Open a member's drop's detail card and press Trade → chat prints `[sim] Would open a trade with <unit>.`
and no trade window opens. `/dw sim trade <its id>` → the History tab shows it `Traded away`; loot a
member's drop and `/dw sim trade <its id>` → `Received`. After `/dw sim stop` the History tab shows
only your real history. Result:

**SIM-6. The item pool: the Encounter Journal and its fallback (DW-71).** The headless `test_sim_pool`
covers the same ground. Solo, outside an instance, with `/dw
debug on`: open the Encounter Journal, pick an older instance, a difficulty and a class filter,
and close it. `/dw sim start key` → the debug log shows `[SIM] pool: <n> items from the journal (0
still loading)` within a few seconds, and a simulated drop's tooltip shows a current-season item at
the keystone item level. Reopen the Encounter Journal → it shows the instance, difficulty and class
filter you left, not the last one the simulator read. `/dw sim stop`, then `/dw sim start raid` →
the pool line again, with raid items. The fallback: leave the Encounter Journal open and start one
→ no pool line while it stays open; after 5 seconds chat says `The Encounter Journal gave no items,
so this simulation drops your own gear instead.` and the drops are your own items. Stop and start
again with it still open → the line is not printed a second time this session. Close it before the
5 seconds instead → the journal pool is read once it closes. Record the item count of each pool.
Result:

**SIM-7. The verbs' refusals and the automatic stop end to end (DW-73).** The headless
`test_sim_scenario` and `test_sim_core` cover the same ground. With no simulation running, `/dw sim
run`, `step`, `pull`, `kill`, `loot`, `lockdown on`, `trade 1` and `stop` each print `No simulation is
running: start one with /dw sim start <scenario>.`; `/dw sim start nowhere` prints `Unknown
scenario.`; `/dw disable`, then `/dw sim start dungeon` → the disabled line, and no simulation starts.
With one running: `/dw sim pull` twice → `A simulated boss is already engaged: /dw sim kill first.`;
`/dw sim run` twice → `The timeline is already playing.` Start one and `/dw sim run`, then accept a
real group invite mid-run → `Simulation stopped: you joined a group.`, the `SIMULATION` text goes, no further
step plays, and the footer shows the real situation. Start one, then zone into an instance (a
follower dungeon will do) → `Simulation stopped: you entered an instance.` Result:

**SIM-8. Real loot during a simulation stays real (DW-70 review).** The headless `test_sim_core`
(`sim history: a real drop while a simulation runs …`) covers the same ground. Solo in the open
world: `/dw sim start world`, then loot a real item from a mob or chest → it appears in the feed
with your real situation (solo), not the simulated group's, and it is not marked as simulated. `/dw sim stop` → the simulated
drops go, the real one stays in the feed, and the History tab (the account's log again) shows it.
`/reload` → it is still in History. Result:

**SIM-9. A sim run fills the window under the default filters (DW-90, sim feedback §0).** The
headless `test_sim_e2e` covers the same ground in every scenario, at the content's level and
outgearing it. Solo, out of an instance, with the window's filters at their defaults (View:
All, Quality: Rare+, Content: This session, as `test_sim_e2e` asserts) and your usual gear: `/dw sim start key`, then
`/dw sim run` → chat prints one line per step (`Simulation step 1 of 11: runStart.` … `Simulation
step 10 of 11: loot: 2 drops.` … `step 11 of 11: lockdownOff.`), the footer reads `Simulating:
Mythic+ · 4 members` and `Inspect 4/4 fresh` once the inspects land, and Drops shows at least one
member's drop and at least one of yours. Repeat with `/dw sim start delve` and `/dw sim
start world` (both untracked by default) → each fills the window the same way. `/dw sim start lfr`
→ an ask's announce goes to instance chat (`[sim] INSTANCE_CHAT: …`). In `/dw sim start raid 12`
→ you show online in the roster (`/dw diagnostics`, `unit=raid1`). Result:

**SIM-10. The simulation step panel (DW-91, sim feedback §1).** The headless `test_sim_panel` covers
the same ground. Solo, out of an instance: `/dw sim` → the panel `Ka0s Drop Watcher - Simulation`
opens beside the window (not over it), in the perf-run panel's look: a dot, the step and its
command on each row, the close mark at the top right, a scenario choice and Start at the foot. Pick
Raid and a member count → the rows preview the raid's steps and `Start: Raid` reads `/dw sim start
raid <n>`; Start → the simulation starts and the foot shows Run all, Pause, Restart and Stop. Click
the third step ahead → chat prints one step line for each step in between, in order, and the rows
turn green with a check up to it, the last one gold, the next one bright and the rest gray. Hover a
completed row → its tooltip says when it ran; clicking it does nothing. Type `/dw sim step` → the
panel moves on too. Run all → the gold highlight follows each step, and after the second step Pause is
still live and Run all still spent; Pause → it stops, and Resume plays on. Restart → the same scenario starts again at its first step; Stop → the simulation ends and
the picker returns. Drag the panel, `/reload`, `/dw sim panel` → it opens where you left it; Reset
position on the Window page → it docks beside the window again. Close the window, then
`/dw sim start raid 30` on a fresh login (the journal still loading) → once the window opens the
panel moves beside it, not over it. Result:

**SIM-11. The simulation step delay (DW-A7, feedback-2 spec §8).** The headless `test_sim_scenario`
and `test_sim_panel` (`sim step delay`) cover the same ground. Settings › General › Simulation →
`Simulation step delay` reads 2 and runs from 0.5 to 10 in steps of 0.5. `/dw sim start dungeon`,
hover Run all → `one every 2 seconds`; Run all → the steps come about two seconds apart. Set the
slider to 6 while it plays → the step already waiting keeps its time, and the next ones come about
six seconds apart; hover Run all → `one every 6 seconds`. `/dw set sim.stepDelay 1.5` → the steps
speed up from the next one, and `/dw get sim.stepDelay` reads 1.5. Result:

**SIM-12. The loot step says where its drops went, and the window reconciles (DW-B0, feedback-3 spec
§0; one tab since DW-E3).** The headless `test_sim_report` covers the same ground in every scenario. Solo,
with the window's filters at their defaults: `/dw sim start key`, then play it to its loot step → the
panel row and the chat line read `Loot: 2 drops` (`Simulation step 10 of 11: loot: 2 drops.`; the
`(1 yours)` is gone since DW-E2); hover the row → it names each drop, its looter and where it is
(`… (you): Drops`, `… (<member>): Drops`). Drops shows both under a header reading `2 drops`, yours
with Offer, even when your drop is an upgrade you keep. `/dw set feed.minIlvlMode absolute` and
`/dw set feed.minIlvl 900`, then `/dw sim loot 2` → chat reads `Simulated loot: 2 drops (2
hidden).` and the tables gain nothing (set both back afterwards). Result:

**SIM-13. The loot step honors the feed the window shows (DW-B5, feedback-3 spec §5).** The headless
`test_sim_report` (its `View` cases) covers it. `/dw sim start key` and play to its loot step → the panel
row and the chat line read `Loot: 2 drops`. Turn test mode on (`/dw test`) with the step played → the row
reads `Loot: 2 drops (2 not shown in test mode)` and its tooltip `… not shown while test mode is on`; turn
test mode off → the places come back. (`feed.showOwn`, and with it the `Group drops and My drops` and
`not on My drops` places this check also read, are gone since DW-E2/DW-E3: `/dw get feed.showOwn` finds no
setting.) Result:

## Compact

**COMPACT-1. The layout switch (DW-C0).** With the window open in its full layout, hover the title bar's new
mark between Scan group and minimize → `Compact view`, naming the Layout setting. Click it → the same window
narrows to 440 x 460 with its top-right corner where the full window's was, and the mark turns to the
enlarge mark (`Full view`). Drag it somewhere else and size it from the corner → it stops at 440 (its
default, since DW-E4; 380 from DW-D4, 320 before) and 520 wide (220 and 900 tall). Click the mark → the full window comes
back at its own size and place; click again → compact returns where you left it. `/dw compact` and
`/dw full` do the same and print `Compact view.` / `Full view.`; Settings → Window → Layout shows the choice
and switching it there moves the window too. `/reload` → the window opens in the layout it was in, each at
its own place; Reset position puts both back. An account that had the old compact preset on opens compact
after the update. Result:

**COMPACT-2. Drops cards (DW-C2).** Turn test mode on (`/dw test`) and switch to the compact layout
(`/dw compact`) → each drop is a three-line card about 50 pixels tall under a one-line header
(`Instance · Boss · Difficulty · 3m · 2 · <you>`, no `ago` and no `drops`; its tooltip has the long form and
any hidden drops; its chevron gold since DW-E0). Each card sits indented under its header with a
muted-white chevron before its icon (DW-E0: FEED-39). Line 1: the icon spans the three lines, the item name in its quality color with a thin
bar of that color at the left edge, the item level right-aligned and `Ask` (no × since DW-D2). Line 2: the
looter in class color (⊕ on one from another realm, the realm in its tooltip), the slot, the type (since
DW-D3: FEED-34), the trade state in its tone, and on the right the countdown and its bar for a drop with
one (since DW-E1: FEED-47), else the inspect freshness dimmed (`2m`, `cached`, `…`, `range`). (Superseded by
feedback-10, 2026-10-14: line 1 reads the item level before the name, the freshness at its right; line 2 ends in
the Ask; no countdown or bar on the card; line 3's `You` and `Them` in gold, Them close after You;
FEED-69.) Line 3: `You 292 ▲19`-style and `Them 321/308 ▼13`-style halves, the worn item levels then the
verdict, unsigned, as the table's Me and Them without icons (since DW-F1: FEED-49; `You ▲ +19 (292)`
before), `Them 298/296 ⊘ Can't use` for a worded verdict, no `?` after a gear part that already says why (`…`, `range`), each
in the full table's tone (FEED-31). Check every test-mode state: the Ask button reads Ask,
Queued, Asked, Retry or Traded, in the full table's tones (FEED-32), and a drop with no ask shows a dash
whose tooltip says why (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72). Hover the icon or the name → the game's own item tooltip. Click a card → the detail
card opens right under it at the compact width, For you, For the looter and the trade box one under another,
the actions on two or three lines, nothing cut off on the right; click it again → it closes; switch to full
with it open → the same row is open there. Settings → Window → Font size 14 → the cards grow with the text.
Run `/dw sim start` and step it → the cards fill the same way. On each tab, switch to full and back → the
same drops under the same headers, in the same order, and the same counts on the tabs (DW-C5). With the
defaults, `/dw sim start key`, close the window and `/dw sim run` → the next drop opens it compact; stop the
simulation, close the window and open it → the full layout. Result:

**COMPACT-3. Your own cards, the countdown, Offer and the strip (DW-C3; on Drops since DW-E3).** Turn test
mode on and switch to the compact layout → on Drops each drop of yours is a three-line card among the
others (no My drops tab since DW-E3). Line 1: the icon, the name in its quality color, the item level and
`Offer` (cyan since DW-F2, red from DW-D1; yellow once an offer is out, green once traded away; it was gold
when someone would gain), or a dash whose tooltip says why on a drop that cannot be traded (superseded by feedback-11, 2026-10-14: the gray `No action` button with its reason; FEED-72). Line 2: you, the slot, the
type and the trade with its upgrade count (`Yes (2)`; FEED-42), then the countdown and a short bar after it
on the right, bold amber under ten minutes, `Not tradeable` with no bar on a dead drop, `No limit (BoE)`
with a full bar on a bind-on-equip one (superseded by feedback-10, 2026-10-14: Offer is at line 2's right, the
item level before the name on line 1, and the card shows no countdown or bar; FEED-69). Line 3: You and Them, Them reading `(Details)` (or `Hidden` on
your upgrade; `(Multiple)` until DW-F3) with the full table's tooltip (FEED-43). No Announce on the card (since DW-E2) and no Hide
(since DW-D2). The countdown moves every second (gone from the card since DW-J2: FEED-69). The strip under the cards reads `n tradeable · next
0:08:41` with a `Post` button whose tooltip is Post my tradeables' (`Post my tradeables` at the full width, beside
Expand all, since DW-Q2: FEED-78). Click Offer → the Offer panel opens beside the compact window
at its usual width, on the right; drag the window to the screen's right edge → it moves to the left side;
make the window short → the panel keeps a usable height. Switch to full → the strip and the table are back
as before. Run `/dw sim start` and step it → your own drops fill the cards the same way. Result:

**COMPACT-4. History cards and their outcomes (DW-C3).** In the compact layout, open History → each
kept group is a one-line header (`Boss · Dungeon · 2m · 2 · <you>`, `3d` once a day old) and each
entry a three-line card: the item and its level (the level first since DW-J2: FEED-69) with the outcome on the right in its tone (Seen,
Asked, Offered, Received, Traded away, Expired, Declined); the looter in class color (⊕ from another
realm), slot, trade and the time on the right (`17:02`, or `Oct 9` past a day); `You` and `Them`
verdicts. Right-click a card → Mark as declined; its outcome reads Declined; right-click again →
Clear declined. The strip's button reads `Clear` with the Clear history tooltip, and it still asks
first. Switch to full → `Clear history` again (left of Sort since DW-J3: FEED-70). (Superseded by feedback-15,
2026-10-16: it reads `Clear history` at the one footer width in both layouts; FEED-78. Then by DW-Q3: Clear
history left both strips for Settings; HIST-6.) Result:

**COMPACT-5. The compact chrome and the Filters ▾ menu (DW-C4).** Switch to the compact layout →
the title reads `Drop Watcher`, centered; turn test mode on → `TEST` in red beside it, the two
centered together, and the yellow strip's shorter text, on two lines if the window is narrow; run
`/dw sim start` → `SIM` in cyan instead. Scan group is an icon button with its tooltip; the layout
toggle, minimize and close sit at the right. Start a boss encounter with an ask queued → the badge
at the bar's left is its lock and `1`, its tooltip the full reason and queue. The tabs read `Drops`
and `History` (since DW-E3; `Group`, `Mine · n` and `History` before), with their tooltips. The filter bar is one row: View, the
search box reading `Filter…`, and `Filters` on the right. Click Filters → a small panel under it
holds Quality, Content, Character and Sort; open each → the same choices as the full bar and the
tab's Sort, Character still multi-select with Current (Content: This instance and This session on Drops, All too on History, since DW-Q1). Pick Content: This instance and Character: All →
the button reads `Filters · 2`, and its tooltip lists every value with a dot on those two. Pick a
Sort → the cards reorder, and the count does not change. Click Filters again, minimize, close or
switch to full → the panel closes. The footer is one line, `Inspect 4/4 · Mythic+`-style, and its
tooltip lists the last loot, the situation and Pawn. Switch to full → every control is back on the
bar and Sort back at the right edge of the tab's strip (in the footer until feedback-10, 2026-10-14; FEED-70),
each at its place. Result:

**COMPACT-6. Open in compact view during a run (DW-C0).** With the Layout on Full and Settings →
Window → Open in compact view during a run on (the default), close the window and start a Mythic+
key → the first drop (the chest, right after the key completes) opens the window compact; the
Layout setting still reads Full. Keep it open past two minutes after the completion → it stays
compact; close it and reopen it (`/dw show`) → it opens full, and a later drop in the same instance
opens it full too.
Close it inside a dungeon run, let a drop open it → compact; click the toggle → full at once, and it
stays the player's choice. Turn the option off → an auto-open in a run keeps the Layout. Result:

**COMPACT-7. Card tooltips at the card's top right (DW-C2).** In the compact layout, hover each piece of a
card (the item level, the looter, the slot, the trade, the freshness, You, Them, the worn levels and Ask)
and a header → each tooltip rises from the card's top-right corner, just outside the window's right edge (or
its left edge when the window sits against the right of the screen), never over the cards. Result:

## Non-English client

**LOC-1. A deDE or frFR client.** What this build reads that a locale can change, enumerated from the
code: the loot lines (`modules/LootParser.lua` reads `CHAT_MSG_LOOT` with patterns built from the
client's own `LOOT_ITEM*`, `CHANGED_OWN_ITEM`, `LOOT_ITEM_CREATED_SELF*` and `CREATED_ITEM*`
GlobalStrings, positional `%2$s` arguments in their own order), and the readers in
`core/Compat.lua` (the trade-time sentence and its duration, the `ITEM_LEVEL` and upgrade-level
lines, the class restriction line), headless-tested in enUS, deDE and ruRU shapes. Track names come
from the API, never from parsing (ITEM-2). Its own strings are English through `NS.L`, which answers
the key itself on any client. On a deDE or frFR client: `/reload`, open the window, run `/dw help`
and `/dw diagnostics` → English text throughout, no Lua error, and no stray `%s` or `%d` in any
line. Then repeat FEED-1's loot steps with `/dw debug on` → every loot line chat shows has its
`[PARSE]` line with the right kind, link, quantity and looter, and `/dw diagnostics` shows
`ignored` counting only roll lines. The failure looks like a raw format token in chat, a missing
label, or a loot line with no `[PARSE]` line (its GlobalString did not compile: record
`/dump LOOT_ITEM, LOOT_ITEM_SELF, LOOT_ITEM_MULTIPLE` and the line as chat shows it). Then the
trade-time decode: loot a tradeable bind-on-pickup item → its Drops row's Trade window is exact (no
`~`) within a few seconds of the item reaching your bags, and `/dw diagnostics`'s `trade` lines
show its seconds left close to the tooltip's `… remaining` sentence; an item that stays `~` or reads
expired while the tooltip still shows the sentence is the failure (record the sentence and `/dump
INT_SPELL_DURATION_HOURS, INT_SPELL_DURATION_MIN, TIME_UNIT_DELIMITER`). Last, the track names:
expand a drop that has an upgrade track → the detail card's track chip shows the client's own
(localized) track name and rank, never an English name; the track change line may be missing on
this client (Known Limitations), and its absence is not a failure. Result:

**LOC-2. The enUS catalog reads the same (DW-P19).** On an enUS client: open the window on both tabs,
expand a drop's detail card, open the Offer panel, every settings page and tab, `/dw help`,
`/dw diagnostics` and the minimap tooltip → every string reads as it did before DW-P19 (the catalog
now carries every routed string, so a typo in a key would show as different text). No raw key, no
stray `%s` or `%d`, and no Lua error. Result:

## Pending sign-off

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-1..3, SLASH-1..3, PANEL-1..3, PROFILE-1..2, STATE-1..2, COMBAT-3, DIAG-1..2, DEGRADED-1 | DW-02, the scaffold | No client pass recorded yet |
| QUAL-1..4 | DW-12, the minimum-quality gate | No client pass recorded yet |
| SIT-1..5 | DW-13, the situation classifier | No client pass recorded yet |
| TRADE-1..4 | DW-14, the trade estimator (TRADE-3 is the raid rule, TRADE-4 equipped vs owned) | No client pass recorded yet |
| FEED-7 | DW-10 / DW-11, the class data and the verdict kernel | No client pass recorded yet |
| COMPAT-1..3 | DW-20, the compat seam | No client pass recorded yet |
| DIAG-3 | DW-43, the State and Scoring diagnostics sections | No client pass recorded yet |
| COMBAT-2 | DW-21, the restriction tracker | No client pass recorded yet |
| ROSTER-1..2 | DW-22, the roster | No client pass recorded yet |
| ITEM-1..2 | DW-23, the item facts | No client pass recorded yet |
| GEAR-1..2 | DW-24, the gear snapshot | No client pass recorded yet |
| FEED-1, COMBAT-1, LOC-1 | DW-25, the loot parser (LOC-1 re-armed: its sign-off without the client no longer holds) | No client pass recorded yet |
| INSPECT-1..4 | DW-26, the inspect broker | No client pass recorded yet |
| FEED-2..6 | DW-27, the feed | No client pass recorded yet |
| TRADE-5 | DW-28, the trade timer | No client pass recorded yet |
| TRADE-6 | DW-29, the trade helper | No client pass recorded yet |
| ASK-1..4 | DW-2A, the messaging edge | No client pass recorded yet |
| STATE-3, FEED-8..9 | DW-30 / DW-34, the window shell and test mode | No client pass recorded yet |
| FEED-10..12 | DW-31, the Group drops table (Drops since DW-E3) | No client pass recorded yet |
| FEED-13..15 | DW-32, the detail card | No client pass recorded yet |
| FEED-16 | DW-81, the header matched to Loot History | No client pass recorded yet |
| FEED-17 | DW-82, the filter bar matched to Loot History | No client pass recorded yet |
| FEED-18 | DW-83, My eq, Their eq, the two new filters, auto-open on every drop | No client pass recorded yet |
| FEED-19 | DW-A0, the two-Yoke regression, every hidden or refused drop counted by reason, `n drops · m shown` | No client pass recorded yet |
| FEED-20 | DW-A1, View: All by default, the multi-select View, its tooltip and the migration | No client pass recorded yet |
| FEED-21 | DW-A2, item tooltips beside the window, right or else left, on every tab | No client pass recorded yet |
| FEED-22 | DW-A3, the party kept with every group, on the header tooltip's `Group:` line (DW-B4), and in History | No client pass recorded yet |
| FEED-23 | DW-A4, the Character dropdown on every tab, History filtered by who saw each drop | No client pass recorded yet |
| FEED-24 | DW-A8, the tables' font and row height like Loot History's, on both tabs (the Trade window's taller rows since DW-E1) | No client pass recorded yet |
| FEED-25 | DW-A9, your own drops under the group headers (on Drops since DW-E3), the tooltip beside the docked Offer panel | No client pass recorded yet |
| FEED-26 | DW-B2, every row tooltip at the row's top right (else top left), both tabs and the Offer panel | No client pass recorded yet |
| FEED-27 | DW-B1, the filter bar's tooltips above their controls, top right (else top left) | No client pass recorded yet |
| FEED-28 | DW-B4, group headers: the instance, the boss, the difficulty name and only your character, on Drops and History | No client pass recorded yet |
| FEED-29 | DW-B5, filter-bar tooltips below their controls near the top of the screen (the tab counts retired by DW-E3) | No client pass recorded yet |
| FEED-30 | DW-B4, a delve's header, and whether the client names its tier | No client pass recorded yet |
| FEED-31 | DW-D0, one tone per verdict in Me and Them, the arrow before the number, full and compact and the detail card | No client pass recorded yet |
| FEED-32 | DW-D1, action buttons red, yellow or green by whose move it is: Ask, your own drop's Offer, the Offer panel, both layouts | No client pass recorded yet |
| FEED-33 | DW-D2, no ×, Hide or Hide this item anywhere; a dead drop of yours stays listed | No client pass recorded yet |
| FEED-34 | DW-D3, the Type column's values on Drops, History, the compact cards and the detail card's chip | No client pass recorded yet |
| FEED-35 | DW-D4, gold column labels on both full tables | No client pass recorded yet |
| FEED-36 | DW-D4, the search box 8px after Character to the bar's right edge, tracking a resize live | No client pass recorded yet |
| FEED-37 | DW-D4, the window never narrower than its default, full 1038 (since DW-F1) and compact 440; a stored narrower width raised | No client pass recorded yet |
| FEED-38 | DW-E0, the group header's chevron gold, on both tabs and in both layouts | No client pass recorded yet |
| FEED-39 | DW-E0, each drop row's muted-white chevron (down, up while open), the rows and cards indented under their header, History's not | No client pass recorded yet |
| FEED-40 | DW-E0, the 84-pixel Actions column: every Ask and Offer state's icon and word fit | No client pass recorded yet |
| FEED-41 | DW-E1, the Trade window column on every drop, another player's an estimate, ticking each second, ending soon in tone only | No client pass recorded yet |
| FEED-42 | DW-E2, your own drop always listed, its Trade counting the members it upgrades | No client pass recorded yet |
| FEED-43 | DW-E2, Them reads `(Details)` (since DW-F3) with each upgrade in the tooltip; the keep? rule's `Hidden` | No client pass recorded yet |
| FEED-44 | DW-E2, Offer on your own drop opening the Offer panel, its tones, no Announce in the table | No client pass recorded yet |
| FEED-45 | DW-E3, the strip under Drops (full and compact) and Post my tradeables | No client pass recorded yet |
| FEED-46 | DW-E3, two tabs, Drops and History; a stored My drops tab and `/dw mine` open Drops | No client pass recorded yet |
| FEED-47 | DW-E4, the least width (full 1132 then, 1038 since DW-F1; compact 440) and the compact card's line 2 with its countdown | No client pass recorded yet |
| FEED-48 | DW-F0, the Trade window column 76 pixels: every answer fits, `Their upgrade` and `No limit (BoE)` included, no empty margin | No client pass recorded yet |
| FEED-49 | DW-F1, My eq merged into Me and Their eq into Them (`321/308 ▼8`), History's verdict alone, compact line 3 without icons | No client pass recorded yet |
| FEED-50 | DW-F1, the My eq and Their eq toggles retired (schema step 7); Me and Them toggle the merged cells | No client pass recorded yet |
| FEED-51 | DW-F2, Offer cyan while it is your move on the row, the card, the detail card and the Offer panel; Ask and Retry red | No client pass recorded yet |
| FEED-52 | DW-F3, the (Details) tooltip: one non-wrapping line per member, class-colored name, item in its quality color, arrow texture | No client pass recorded yet |
| FEED-53 | DW-F3, no glyph boxes in any tooltip: column tips and verdict marks drawn as textures | No client pass recorded yet |
| FEED-54 | DW-F1, the least width 1038: nothing shed or cut on Drops or History, Me and Them whole | No client pass recorded yet |
| FEED-55 | DW-F5, no glyph boxes outside tooltips: the toast's mark, the detail card's chips, Item level and Track rows, the Offer panel's arrows as textures | No client pass recorded yet |
| FEED-56 | DW-G0, the Offer panel's Their eq column in the Them look (Member, Their eq, Actions); no Trade button | No client pass recorded yet |
| FEED-57 | DW-G0, the Offer panel's rows: no class bar, every second row the main window's faint stripe | No client pass recorded yet |
| FEED-58 | DW-G1, an icon on every action button (Ask `chat`, Offer `export`, `external-link` since DW-J1: FEED-68), every view; icon and word fit | No client pass recorded yet |
| FEED-59 | DW-G2, Trade `No` in the palette's red on Drops, History, the compact card and the detail card | No client pass recorded yet |
| FEED-60 | DW-G2, your own drop's looter `Name [YOU]`, the mark gold and never cut, every looter text | No client pass recorded yet |
| FEED-61 | DW-G2, `Upgrade for N` / `No upgrades` / `Hidden`; Trade's `Yes` without its count, the count in the tooltip | No client pass recorded yet |
| FEED-62 | DW-G3, columnar gear tooltips: aligned columns, the table's glyph, glyph and number toned; no leftover grid | No client pass recorded yet |
| FEED-63 | DW-G4, Post my tradeables at Sort's size directly above it, Scan group beside it or in its slot; compact's icon kept (superseded by DW-J3: FEED-70) | No client pass recorded yet |
| FEED-64 | DW-G4, the empty state's Preview with test data and Scan group centered as a pair, both layouts | No client pass recorded yet |
| FEED-65 | DW-H0, General › When to show as one table: renders, toggles, disables, Defaults and a profile switch repaint it | No client pass recorded yet |
| FEED-66 | DW-I0, the toast's four rows beside a four-row icon: quality and class colors, You/Them verdict marks, the trade reason, the 56-pixel icon, right-click closes | No client pass recorded yet |
| FEED-67 | DW-J0, the filled downgrade glyph `▼` in the tables, compact cards, toast, tooltip grids and the Offer panel | No client pass recorded yet |
| FEED-68 | DW-J1, Offer wears `external-link` on the row, the compact card, the detail card and the Offer panel | No client pass recorded yet |
| FEED-69 | DW-J2, compact cards: ilvl before the name, `(freshness)` after it or nothing, the button right on line 2 or an empty slot (`No action` since DW-K1: FEED-72; no `(…)` since DW-K0: FEED-71), no countdown or bar, gold You/Them close together; History's cards too | No client pass recorded yet |
| FEED-70 | DW-J3, Sort on the Drops strip right of Scan group and Post, on History's right of Clear history, following tab and layout switches; no Sort in the footer | No client pass recorded yet |
| FEED-71 | DW-K0, compact cards: no `(…)` after the name while Them reads `…`, the other freshness marks still bracketed; Them cut at the card's right inset, line 1's name the full width | No client pass recorded yet |
| FEED-72 | DW-K1, the gray `⊘ No action` button wherever a drop has no action: Drops rows, compact cards, the detail card's first action, Offer panel rows; not clickable, its tooltip `No action` and the reason; fits 84px and the Offer panel's 80px | No client pass recorded yet |
| FEED-73 | DW-L0, History's outcomes in the action buttons' colors, the table and the compact cards | No client pass recorded yet |
| FEED-74 | DW-L1, no `0 shown` header where Character or Content left a group empty, the table and the compact cards | No client pass recorded yet |
| FEED-75 | DW-M0, each tab's default filters: Drops This session and Current, History All throughout | No client pass recorded yet |
| FEED-76 | DW-N0, no Lua error from a gear tooltip in combat (a secret width) | No client pass recorded yet |
| FEED-77 | DW-Q1, Content per tab: Drops This instance and This session, History adds All; the tooltip; step 8 | No client pass recorded yet |
| FEED-78 | DW-Q2, one footer button kind; Expand all / Collapse all on both tabs and layouts; the compact Drops strip always shown | No client pass recorded yet |
| STATE-4 | DW-84, test mode with real items, History test data, no trailing ellipsis | No client pass recorded yet |
| ASK-5..7 | DW-33, your own drops (the My drops tab until DW-E3), the Offer panel and Post my tradeables | No client pass recorded yet |
| SLASH-4..6 | DW-42, the feature slash verbs | No client pass recorded yet |
| PROFILE-3 | DW-40, the settings rows, defaults and step 2 | No client pass recorded yet |
| PANEL-4..6 | DW-41, the settings pages | No client pass recorded yet |
| PANEL-7 | DW-40 / DW-41 review, the rows that act | No client pass recorded yet |
| SCORE-1..2 | DW-50, the scorers | No client pass recorded yet |
| SCORE-3 | DW-62, Pawn counts once it is initialized | No client pass recorded yet |
| HIST-1..2 | DW-51, the history and the History tab | No client pass recorded yet |
| HIST-3 | DW-A5, Keep history for, its confirmation, the login prune and step 4 | No client pass recorded yet |
| HIST-4 | DW-A9, the prune after a disabled start, a stale confirmation | No client pass recorded yet |
| HIST-2, HIST-5 | DW-Q0, the session is the login: the Drops tab across a reload, the undone Expired, This instance across a reload | No client pass recorded yet |
| HIST-6 | DW-Q3, Clear history in Settings › Window › Layout beside Keep history for; none on History's strips | No client pass recorded yet |
| HIST-7 | DW-Q4, the History tab's detail card from the snapshot, both layouts; Link in chat, Mark / Clear declined, Show in Drops | No client pass recorded yet |
| TOAST-1 | DW-52, the upgrade toast | No client pass recorded yet |
| TOAST-2 | DW-62, the toast leaves with its drop and its switch | No client pass recorded yet |
| TOAST-3 | DW-62, an empty-slot upgrade toasts and auto-asks | No client pass recorded yet |
| TMOG-1 | DW-53, the transmog-known flag and the For transmog ask | No client pass recorded yet |
| ASK-8 | DW-54, auto-ask | No client pass recorded yet |
| ASK-9 | DW-62, auto-ask after leaving an encounter | No client pass recorded yet |
| SIM-1 | DW-70, the simulator's core: the seam, its safety and the session log | No client pass recorded yet |
| SIM-2 | DW-73, a full `key` run | No client pass recorded yet |
| SIM-3 | DW-73, a `raid` run with a large roster | No client pass recorded yet |
| SIM-4 | DW-72, inspect replies, the lockdown queue and its flush | No client pass recorded yet |
| SIM-5 | DW-72, your own drops' trade windows and a simulated trade | No client pass recorded yet |
| SIM-6 | DW-71, the simulator's item pool and its fallback | No client pass recorded yet |
| SIM-7 | DW-73, the verbs' refusals and the automatic stop end to end | No client pass recorded yet |
| SIM-8 | DW-70 review, real loot during a simulation kept and saved | No client pass recorded yet |
| SIM-9 | DW-90, a sim run fills the window under the default filters | No client pass recorded yet |
| SIM-10 | DW-91, the simulation step panel | No client pass recorded yet |
| SIM-11 | DW-A7, the simulation step delay setting | No client pass recorded yet |
| SIM-12 | DW-B0, the loot step says where its drops went; the window reconciles | No client pass recorded yet |
| SIM-13 | DW-B5, the loot step honors test mode's feed (`feed.showOwn` and My drops' filters retired since DW-E2/DW-E3) | No client pass recorded yet |
| COMPACT-1, COMPACT-6 | DW-C0, compact mode's switch and the run override | No client pass recorded yet |
| COMPACT-2, COMPACT-7 | DW-C2, compact Drops cards, the stacked detail card and the card tooltips; DW-C5, the same drops in both layouts and a simulated key's compact auto-open | No client pass recorded yet |
| COMPACT-3, COMPACT-4 | DW-C3, compact cards of your own drops (on Drops since DW-E3) and History cards, the countdown, Offer and the strip, the docked Offer panel | No client pass recorded yet |
| COMPACT-5 | DW-C4, compact chrome: the title, badge, Scan group, short tabs, one-row filter bar and its Filters panel, strip and footer | No client pass recorded yet |
| ASK-1 (its `noChannel` sentence), ASK-10 | DW-P17, a stored announce channel honors the not-in-a-group refusal, Post my tradeables included | No client pass recorded yet |
| STATE-5, DIAG-2 (its perf-hold sentence) | DW-P16, `NS.StoodDownRefusal()` for every stood-down refusal | No client pass recorded yet |
| ROSTER-3 | DW-P18, the shared event dispatcher isolates each handler | No client pass recorded yet |
| LOC-2 | DW-P19, the completed enUS catalog | No client pass recorded yet |
| COMPAT-4 | DW-P20, the optional-addon probe through Compat | No client pass recorded yet |
| PANEL-8, DEGRADED-2, TOAST-4 | DW-P21, When to show's OnRelease park; the toast's close degrading to nothing | No client pass recorded yet |
| INSTALL-4 | DW-P22, the LibKa0s v1.72.0 re-vendor | DW-P22 has landed (`ff567d3`); no client pass recorded yet |
| DIAG-4 | DW-P24, `evaluate` and `quality.gate` within `feed.add` (review C-04, X05) | DW-P22 (`ff567d3`) and DW-P24 (`917449f`) have landed; owed the owner's capture recorded under `docs/perf-analysis/`; none is invented |
| SLASH-7 | Review 2026-10-14, the cross-addon census's in-client half | No client pass recorded yet |
| ITEM-5 | The Fireproof Drape fix: every primary stat read off the tooltip, the spec list held to its own class | No client pass recorded yet |

### Review 2026-10-14 (M24) sign-off

The review's in-client checks (`reviews/2026-10-14/03_SMOKE_TESTS.md`, a frozen bundle) live above
under these IDs, and this table is where their sign-off is recorded. The owner fills it; an agent
never marks a row passed. DW-P25 (the disabled-state suite), DW-P26 (TOC labels) and DW-P27 (the
documentation spill) change no code the client runs, and have no in-client check.

| Review ID | Check here | Tested? | Pass/Fail | Notes |
|---|---|---|---|---|
| C-01 | STATE-5 (its combat and zone half) | | | |
| C-02 (ANN-1, ANN-1b) | ASK-10, ASK-1 | | | |
| C-03 | ROSTER-3 | | | |
| C-04 | DIAG-4 | | | DW-P22 and DW-P24 landed; owed the owner's capture |
| C-05 | LOC-2 | | | |
| C-06 | COMPAT-4 | | | |
| C-07 | none | n/a | | Comment only |
| C-08 | STATE-5, DIAG-2 | | | |
| U-1/U-2 re-vendor | INSTALL-4 | | | DW-P22 landed (`ff567d3`); owed the owner's client pass |
| DW-P21 (F11, F12) | PANEL-8, DEGRADED-2, TOAST-4 | | | |
| Regression | INSTALL-1..3, PROFILE-1, STATE-1, STATE-3, PANEL-3, SIM-1 | | | |
| Cross-addon | SLASH-7 | | | |
