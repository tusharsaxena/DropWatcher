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
| INSTALL-1..3 | Install | Load, reload, first run, the logo |
| SLASH-1..6 | Slash | `/dw` and `/dropwatcher`, help, the window verbs (SLASH-1..3); the feature verbs of design spec §12.3 (SLASH-4..6, DW-42) |
| PANEL-1..7 | Settings panel | Landing page, General → Master controls, the Defaults button (PANEL-1..3); the pages of design spec §12.2: General → When to show and Feed (PANEL-4), Comparison (PANEL-5), Messages (PANEL-6), DW-41; the rows that act on the feed, the verdict, the sends and the table (PANEL-7) |
| PROFILE-1..3 | Profiles | The Profiles page, the `profile` verb, and the settings rows kept per profile (PROFILE-3, DW-40) |
| STATE-1..4 | State | Enable/disable, lock, test mode (STATE-3); test mode with real items, History test data and no trailing ellipses (STATE-4, DW-84) |
| COMPAT-1..3 | Compat | The client facts `core/Compat.lua` relies on (DW-20) |
| COMBAT-1..3 | Combat | Loot reads mid-encounter, restrictions, test mode ended by combat |
| DIAG-1..3 | Diagnostics | The debug console, the report, perf (DIAG-1..2); the State and Scoring sections of design spec §13 (DIAG-3, DW-43) |
| DEGRADED-1 | Degraded | The install with LibKa0s missing |
| FEED-1..30 | Feed | The loot parser (FEED-1, DW-25), the feed (FEED-2..6, DW-27), a Devourer looter (FEED-7, DW-10/DW-11), the window's shell (FEED-8..9, DW-30), the Group drops table (FEED-10..12, DW-31), the detail card (FEED-13..15, DW-32), the header beside Loot History (FEED-16, DW-81), the filter bar beside it (FEED-17, DW-82) and the equipment columns, the two new filters and auto-open on every drop (FEED-18, DW-83); the two-Yoke regression, nothing hidden or refused silently and `n drops · m shown` (FEED-19, DW-A0); View: All by default, the checkboxes as multi-select View values, the bullet tooltip and the settings migration (FEED-20, DW-A1); item tooltips beside the window (FEED-21, DW-A2); group headers naming the party, class-colored, on Group drops and History (FEED-22, DW-A3); the Character dropdown, Current by default, filtering History by who saw each drop (FEED-23, DW-A4); the tables' font and row height beside Loot History's, on all three tabs (FEED-24, DW-A8); My drops under the same group headers, and a tooltip that never covers the docked Offer panel (FEED-25, DW-A9) every row tooltip at the row's top right (FEED-26, DW-B2) and the filter bar's tooltips above their controls (FEED-27, DW-B1); group headers naming the instance, the boss, the difficulty and only your character (FEED-28, DW-B4); the My drops count and the Group drops suffix agreeing with what My drops lists, and the filter bar's tooltips below their controls near the top of the screen (FEED-29, DW-B5); what a delve's header names, and whether the client gives its tier (FEED-30, DW-B4) |
| ROSTER-1..2 | Roster | The group's members and the name resolver (DW-22) |
| ITEM-1..4 | Item facts | The item readers' shapes and the track ids (ITEM-1..2, DW-23); a real drop read at its real level and quality, and the `drops` diagnostics line (ITEM-3, DW-80, BUG-1); the real game tooltip on every item (ITEM-4, DW-80, BUG-2) |
| GEAR-1..2 | Gear | Your gear snapshot, the owned best and the rebuild events (DW-24) |
| INSPECT-1..4 | Inspect | The inspect broker: warm-up and spacing, the waits and the cache, courtesy and combat, the item level (DW-26) |
| TRADE-1..6 | Trade | Trade estimates and the raid rule (TRADE-1..4, DW-14), timers (TRADE-5, DW-28), the trade helper (TRADE-6, DW-29) |
| ASK-1..9 | Ask | Sending and its confirmation, the queue and its flush, cancel, a whisper during an encounter (ASK-1..4, DW-2A); the My drops tab, the Offer panel and Post my tradeables (ASK-5..7, DW-33); auto-ask (ASK-8, DW-54); auto-ask after leaving an encounter (ASK-9, DW-62) |
| SIT-1..5 | Situations | Where the addon is active (DW-13) |
| QUAL-1..4 | Quality | The minimum-quality gate (DW-12) |
| SCORE-1..3 | Scoring | The Pawn adapter (SCORE-1), your weights and the Pawn scale import (SCORE-2), DW-50; Pawn counts only once initialized (SCORE-3), DW-62 |
| HIST-1..4 | [History](#history) | A completed trade recorded (HIST-1), the History tab across a reload, its row menu and Clear history (HIST-2), DW-51; Keep history for, its confirmation, the login prune and step 4 (HIST-3), DW-A5; the prune after a disabled start and a stale confirmation (HIST-4), DW-A9 |
| TOAST-1..3 | [Toast](#toast) | The opt-in upgrade toast: shown, paused, held in combat, placed in test mode and its sound (TOAST-1), DW-52; it leaves with its drop and with its switch (TOAST-2) and fires for an empty slot (TOAST-3), DW-62 |
| TMOG-1 | [Transmog](#transmog) | The look chip and the opt-in For transmog ask, with and without CanIMogIt (TMOG-1), DW-53 |
| SIM-1..13 | [Simulator](#simulator) | Start and stop, the refusals, the automatic stop, nothing sent and saved history untouched (SIM-1, DW-70); a full `key` run and a `raid` run with a large roster, with the `SIMULATION` title text, the footer and the `sim` diagnostics section (SIM-2..3, DW-73), the inspect replies, the lockdown queue and its flush (SIM-4, DW-72), your own drops' trade windows and a simulated trade into History (SIM-5, DW-72), the item pool from the Encounter Journal and its own-gear fallback (SIM-6, DW-71), the verbs' refusals and the automatic stop end to end (SIM-7, DW-73), real loot during a simulation kept and saved (SIM-8), a sim run that fills the window under the default filters, every step in chat, Raid Finder's instance chat and you online in a raid (SIM-9, DW-90), the step panel: its highlight following the run, a click ahead running the steps in between, Pause and Resume, Restart and Stop, the picker (SIM-10, DW-91), the step delay (SIM-11, DW-A7), the loot step saying where its drops went and the tabs reconciling with it (SIM-12, DW-B0), the loot step honoring `feed.showOwn` and test mode (SIM-13, DW-B5) |
| COMPACT-1, COMPACT-6 | [Compact](#compact) | Compact mode (compact spec §1, DW-C0): the title-bar toggle, `/dw compact` and `/dw full` swap the layouts, each remembering its own size and position, and the old preset migrates (COMPACT-1); Open in compact view during a run opens an auto-open inside a key compact and the stored layout after it ends (COMPACT-6). COMPACT-2..5 and 7 arrive with DW-C2..C5 |
| LOC-1 | [Non-English client](#non-english-client) | What a deDE or frFR client changes: the loot lines, the trade-time decode, the track names (spec §15) |

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

## Slash

**SLASH-1. Help.** `/dw help` and `/dropwatcher help` → the same index, gold commands, white
descriptions, every row present; `/dw` alone opens the settings panel. Result:

**SLASH-2. Window verbs.** `/dw show`, `/dw hide`, `/dw toggle` → the window opens, closes and
toggles; Escape closes it too. Result:

**SLASH-3. Lock verbs.** `/dw lock` → the window cannot be dragged by its title bar or resized from
its corner; `/dw unlock` → both work again; the Lock frame box follows. Result:

**SLASH-4. Feed verbs.** In a group, `/dw scan` → `Inspecting n group members, one at a time.` and
the footer's inspect freshness moves as they are read. `/dw add <shift-click an item>` → `Added
[item] for you (drop n).` and the drop is on My drops; `/dw add <item> <a member's name>` → the drop
is on Group drops under that member; `/dw add <item> Nobody` → it shows, with no inspect asked.
`/dw clear` → `Cleared this session's drops.`, both tabs empty; with test mode on, its sample drops
stay. Result:

**SLASH-5. View verbs.** `/dw history` and `/dw mine` → the window opens on that tab, expanded even
when it was minimized. `/dw compact` → `Compact view.` and the window narrows to its compact layout
(COMPACT-1); again → `Full view.`; `/dw full` → `Full view.` and stays full; the Window page's
Layout choice follows. `/dw situation` in a Heroic dungeon →
three lines: `Situation: Dungeon (dungeon) · Track yes · …`, then the inputs (in instance yes, type
party, difficulty 2); outdoors alone → `Solo (solo)`. Result:

**SLASH-6. Offer verb.** `/dw offer <one of your drops>` → the window opens on My drops with the
Offer panel docked for that drop. `/dw offer <a tradeable bag item the feed never saw>` → it is added
as your drop and the panel opens for it. `/dw offer <an item not in your bags>` → `[item] is not in
your bags.`; `/dw offer` alone → the usage line. While disabled, every one of these verbs answers
the one disabled line. Result:

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
name; untick Delve's Track → its Auto-open and Quality dim, tick it → they light; untick the master
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
and Font size to 15 → the rows grow and their text with them, at once, on Group drops, My drops and
History. Result:

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

**STATE-3. Test mode populates every drop state.** Solo, outside an instance and out of combat, open
the window with no drop yet → the Group drops tab shows `No drops yet`, `Loot your group receives
appears here, grouped by boss.` and two buttons, each with a tooltip; Scan group answers in chat.
Click Preview with test data → test mode turns on, bright-red `TEST MODE` text sits beside the title and an
amber banner (`Nothing is whispered. Combat ends it.`) above the table, both with the same tooltip;
View reads All. Two groups show, `Placeholder boss` open and `Placeholder key run` collapsed; expand
it (since DW-84 the items are real: see STATE-4). Across the rows: Me shows ▲ ≈ ▽, Can't use, Not wanted and `?`; Them shows ▲ ≈ ▽, Can't use and
`?`; Trade shows Yes, Likely, Unknown and No; Their eq shows worn item levels, `…`,
`range`, `combat`, `!` and `–`, the read's age on hover; Actions shows Ask, Queued, Asked, Retry and a dash. Hover a dozen cells → each has a reason,
none is blank, and the text fits its column at the default size and at the minimum size. Expand the
head-slot row Seta looted → the detail card names the looter's spec and `inspected 40s ago`. Click Ask on
a ready row → chat prints `Test mode, not sent: …` and the button reads Asked; nothing is whispered.
Open My drops → the tab reads `My drops · 4`, the countdowns move each second (one in bold `ending
soon`, one estimated with `~`, one `No limit (BoE)`, one not tradeable), and Offer on the trinket
opens the panel with `+14 UPGRADE`, `+6 UPGRADE`, `EQUAL`, `NO UPGRADE`, `CAN'T USE`,
`CHECKING` and `UNAVAILABLE`; Offer and Post my tradeables print and send nothing. Drag the window
and minimize it: the `TEST MODE` text stays on the title bar. `/dw test` → the text, the banner and the rows go,
View is back to Interesting and the empty state returns. Result:

**STATE-4. Test mode shows real items, History test data and no trailing ellipsis (DW-84).** Solo,
outside an instance and out of combat, `/dw test` → for a moment the Group drops tab may read
`Gathering real items for test mode.`, then the rows fill. Every row's icon is a real item's (no red
question mark anywhere: Item, My eq, Their eq, the detail card, My drops, the Offer panel), the
names are real items of the current season's dungeons (or your own gear, with the chat line `The
Encounter Journal gave no items, so test mode shows your own gear instead.`), each in its slot (the
head row a helm, the ring rows rings), and the Ilvl column shows each item's real level: hover an
item → the game's own tooltip agrees with it. Their eq shows a real worn item and its level for the
inspected looters. The looter names stay invented (Seta, Butterz, …). Every state of STATE-3 is
still there. Open History → two groups, `Placeholder key run` (a day ago) and `Placeholder boss` (two
hours ago), whose rows read Seen, Asked, Offered, Received, Traded away, Expired and Declined, over
real items. `/dw test` off → the History tab shows your own kept groups again, untouched (none of the
samples among them, after a `/reload` too). My drops → the button reads `Offer`, with no ellipsis;
an expired row's Trade window reads `Window passed` in full (its tooltip still says `Not tradeable`
and why); a candidates cell still being read reads `1 checking`, the pill `CHECKING`. Look over
every button and cell at the default and the minimum width → none ends in an ellipsis or is cut
short. Then in a Heroic dungeon (an auto-open situation), out of combat, with the window closed:
`/dw test` → the window opens with the test rows; `/dw test` again → the window closes (test mode
opened it, even though its drops arrived first). Result:

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
the report lists `window.refresh`, and `parse` when a loot line arrived during the run. Result:

**DIAG-3. State and Scoring.** In a dungeon, `/dw diagnostics` → `state: enabled=true
situation=dungeon testMode=false restriction=none queuedSends=0`; pull a boss and run it again →
`restriction=encounter`. The `scoring:` lines name the scorer setting, `pawn ready=true scale=<your
spec's Pawn scale>` with Pawn installed (`ready=false scale=none` without it), and `retries pending=0
spent=0 timer=off` out of loot. Result:

## Degraded

**DEGRADED-1. LibKa0s missing.** Rename `libs\LibKa0s` and `/reload` → no Lua error; one chat line
says the library is missing; `/dw show` opens the window without the skin; `/dw disable` and
`/dw enable` still work; `/dw list` says the settings CLI is unavailable. Restore the folder after.
Result:

## Feed

The parser's patterns, the rebuild and the secret guards are headless-tested (`test_loot_parser`),
and the feed's dedupe, grouping and gate order are too (`test_feed`); FEED-1 confirms the client's
real lines and FEED-2..6 what the feed makes of the client's real events, read through `/dw debug on`
and the `feed:` lines of `/dw diagnostics`, FEED-10..12 how the Group drops table draws them
(DW-31), FEED-13..15 the detail card a row expands into (DW-32), FEED-16 the title bar side by side with Ka0s Loot History's (DW-81), FEED-17 the filter bar beside Loot History's (DW-82), FEED-18 My eq, Their eq, Usable by me, Upgrade for me and auto-open on every drop (DW-83), FEED-19 the two-Yoke regression (DW-A0), FEED-20 the multi-select View (DW-A1), FEED-21 item tooltips beside the window (DW-A2), FEED-22 the party named in every group header (DW-A3), FEED-23 the Character dropdown (DW-A4), FEED-24 the tables' font and row height beside Loot History's (DW-A8), and FEED-25 the My drops group headers and the tooltip beside the docked Offer panel (DW-A9), FEED-26 every row tooltip at the row's top right (DW-B2), FEED-27 the filter bar's tooltips above their controls (DW-B1), FEED-28 the group headers' instance, boss, difficulty and recorder (DW-B4), FEED-29 the tab counts beyond the defaults and the filter bar's tooltips near the top of the screen (DW-B5), FEED-30 a delve's header and its tier (DW-B4). FEED-7 checks the class data (DW-10, judged by DW-11) for the one spec the client data could not
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

**FEED-8. The window's shell.** `/dw show` on a clean `/reload` → a window about 1000 × 600 with the
Ka0s edge (a hard black line with a gray line inside it), the gold `Ka0s Drop Watcher` title centered
on the title bar (no logo), a `Scan group` button with a people mark, a minimize mark and the close mark; the `Group
drops` tab gold with a gold underline, `My drops` and `History` gray; the filter bar reads `View:
All`, `Quality: Rare+`, `Content: This instance` and the `Filter looter or item…` box (no checkbox:
DW-A1 made them View values, FEED-20); the footer reads `Inspect: no group`, `No loot seen yet` (or
`Last loot …`), `Not tracking in Solo · change in settings`, `Pawn: on` or `off`, and `Sort:
Newest` beside the corner grip. Hover each control → every one shows a tooltip with a reason.
Click `My drops` → View and Quality gray out (their tooltips say the tab
does not use them); set Sort to Oldest there, go back to Group drops → Sort reads Newest again.
Open each dropdown and press Escape → the window and the open menu both close. Drag by the title
bar and resize from the corner, `/reload` → the same place and size. In a party, `Scan group` →
the chat line `Inspecting <n> group members, one at a time.`, and within a minute the footer reads
`Inspect <n>/<n> fresh`. Result:

**FEED-9. Minimize and auto-open.** With the window open, the minimize mark → the window shrinks
to its title bar where it stood, the mark becomes a plus; `/reload` → it comes back minimized. In a
Drag the window to the middle of the screen and minimize it again → the title bar stays exactly
where it was, and the expand grows the window downward from it. Press Alt-Z twice → the window
comes back with the UI; enter and leave combat → it stays open. On My drops open `Offer`; on Group
drops expand a row and click `Edit message`; then minimize → both close with the body. In a
Heroic dungeon with the window minimized, let a member loot an item → a `1 new` chip
appears beside the title and the window stays minimized; a double-click on the title bar expands it
and the chip goes. Superseded in part by FEED-18 (DW-83): every drop now opens it, not only the
first upgrade. In the open world solo nothing opens it. Result:

**FEED-10. The Group drops table.** In a Heroic dungeon with the window open, let the group loot a
boss → under the filter bar a row of gray column labels (`Item`, `Ilvl`, `Slot`, `Looter`, `My eq`,
`Their eq`, `Me`, `Them`, `Trade`, `Actions`), then a gold header `<boss> · Dungeon · <age> ago · <n>
drops` with a down chevron, then one row per drop: the item's own icon and its name in its quality
color, its item level, its slot, the looter's short name in their class color, your worn item and
the looter's (two for a ring, trinket or weapon) as icons with item levels, or `…`, `range`,
`combat`, `!`, then Me and Them as a signed number beside `▲`, `≈` or `▽` (the glyphs drawn, not boxes),
Trade as `Yes`, `Likely`, `Unknown` or `No`, and an `Ask` button or a dash with an `×`. An upgrade
for you is green in Me; in Them the looter's upgrade is amber and their downgrade green. With View:
Interesting the rows are your upgrades plus the drops their looter has no use for that read Yes or
Likely; View: All (the default since DW-A1) lists every drop. Your own loot is not listed here (it is on My drops) until
`/run LibStub("AceAddon-3.0"):GetAddon("DropWatcher").db.profile.feed = { showOwn = true }`, which
lists it too; set it back. Resize the window to its narrowest → Slot, Looter, My eq, Their eq and Ilvl go
in turn, the column labels with them, and the Ask button and the × stay inside the window; on My
drops the Offer and Announce buttons stay inside it too. Hover
every cell, every column label and the header → each one shows a tooltip with a reason (Trade's
reads like `Personal loot: 311 is not an upgrade over the 324 <name> wears, so they may trade
it.`); no cell is blank. Result:

**FEED-11. Headers, item buttons, dismiss, compact.** After FEED-10, kill a second boss → its group
is on top and open, the first one collapsed with a right chevron and `(collapsed)`; click each
header → it opens or collapses. Hover an item icon → the game's item tooltip with a `Shift-click to
link it in chat; ctrl-click to try it on.` line; shift-click it with the chat box open → the link is
inserted; ctrl-click it → the dressing room shows it. Click a row's `×` → the row goes for the
session. Switch to the compact layout (`/dw compact`) → the table gives way to cards (COMPACT-2);
set it back. Resize the window → the Item
column takes the width. Scroll with the mouse wheel when the rows pass the bottom. Result:

**FEED-12. The table's Ask button.** In a party, on a drop that is an upgrade for you and Likely
tradeable, click `Ask` → the looter is whispered your ask template and the chat line `Whispered
<name>: [item]` appears; the button reads `Asked` with a check mark and is grayed; its tooltip says
it cannot be sent twice. In a boss fight, click `Ask` on another such drop → it reads `Queued` with
a clock mark and the title bar's badge counts it; click it again → it is canceled and reads `Ask`;
click once more and let the fight end → it is sent and reads `Asked`. A drop of your own, one with
Trade `No`, or one that is not an upgrade for you shows a dash whose tooltip says why. Result:

**FEED-13. The detail card opens inline.** After FEED-10, click a drop's row (anywhere but a button)
→ a card opens right under it and the rows below move down; the row gets a faint gold tint and an
up chevron at its right edge. The card shows the item's icon and name in its quality color, then
chips: the slot, the armor type (Cloth, Leather, Mail, Plate), the bind (BoP, BoE), the track with
rank and item level (`Hero 2/6 · 311`), the primary stat, and Socket or a tertiary stat when the
item has them. Click the row again → the card closes and the rows move back. Click another row →
the card moves to it: one card at a time. Fold the row's header, or type a search that hides the
row → the card goes with it; clear the search → it comes back still open. Result:

**FEED-14. Both comparisons and the trade box.** On a drop the looter's inspect has read, the card's
left box `FOR YOU` and right box `FOR <NAME> (LOOTER)` each show a verdict chip (`UPGRADE ▲`,
`DOWNGRADE ▽`, …), the item it replaces with its icon and item level, `292 → 311 · +19`, the track
change (`Champion 6/6 → Hero 2/6 ▲`), the secondary stats gained and lost (`+130 Haste -119
Mastery`), and for you Pawn's score (or `–`, whose tooltip says whether Pawn is loaded), for the
looter their spec and `inspected 40s ago`. The values match the item tooltips the game shows
(compare each by hovering the icons). Below, the trade box shows a chip (`LIKELY TRADEABLE`), the
reason in a sentence, and `Rule: personal loot, Mythic+ · Basis: inspect 40s ago`. Hover every line
and chip → each tooltip names it and says why; nothing is blank. Result:

**FEED-15. The card's actions.** On another player's drop that is an upgrade for you: `Ask <name>`
whispers them as the row's Ask does; `Edit message` opens a small box over the window with the ask
filled in and `n / 255 bytes`; change the text and click `Send` → the edited text is whispered and
the box closes; type past 255 bytes → Send grays out; `Cancel` or Escape closes it unsent.
`Link in chat` puts the item's link in the chat box. `Retry inspect` is grayed while the looter's
read is fresh (its tooltip gives the age); on a looter whose inspect failed or ran out of range it
queues them (`/dw debug on` shows the inspect). Standing far from the looter, `Trade` reads `Trade ·
out of range` grayed, with the reason on hover; walk up to them → it lights up, and a click opens a
trade window with them; in combat it reads `Trade · in combat`. `Hide this item` removes the row and
closes the card. On your own drop, Ask, Edit message, Retry inspect and Trade are grayed and each
says why. Result:

**FEED-16. The header beside Loot History (DW-81).** Open Ka0s Loot History (`/lh`) and put the two
windows side by side. → Drop Watcher's title bar has no logo (the minimap button and the AddOns list
keep it), and its gold `Ka0s Drop Watcher` title sits centered on the bar in the same font as Loot
History's. `/dw test` and Loot History's test mode → each shows `TEST MODE` in bright red, the same
size and color, 10px right of its title, with no box behind it; Drop Watcher's hover still shows the
test-mode tooltip. The yellow strip under the filter bar (`TEST MODE: sample drops of real items in
every state. …`) is unchanged. On the right, the restriction badge, `Scan group`, minimize and the close
mark keep their places. `/dw test` off, then `/dw sim start key` → `SIMULATION` in cyan, the same
style and place. Minimize with a new drop pending → the `n new` counter sits after the mode's words.
Resize to the minimum width (520) with test mode on → the title stays centered; record whether
`TEST MODE` reaches `Scan group` or the restriction badge (at that width the centered title leaves
them little room). Result:

**FEED-17. The filter bar beside Loot History (DW-82).** With the two windows side by side as in
FEED-16 → Drop Watcher's search box is a flat, square-cornered box, the same dark fill, thin gray
line and height as Loot History's `Search items…` box, with its gray hint 6px in; click into it →
its line turns gold, and click away → gray again. (The `Likely tradeable only` checkbox this check
covered is a View value since DW-A1: FEED-20.) The View, Quality and Content dropdowns match Loot
History's (same flat box, chevron, font and height), 8px apart. Switch to My drops → the controls it
does not use gray out the same way. Result:

**FEED-18. My eq, Their eq, the two new filters and auto-open on every drop (DW-83).** In a Heroic
dungeon with the window open, let the group loot a boss → the `My eq` column sits before `Their
eq`; each row shows the icon of what you wear in the drop's slot (two icons for a ring, trinket or
one-hand weapon) with its item level (`300/296` for two), and `empty slot` where you wear nothing.
Hover a My eq icon → the game's own tooltip for your equipped item (its enchant and gems). Swap a
piece of gear → My eq follows within a second. Their eq shows the looter's worn icon(s) and item
level(s); hover the cell → its tooltip names each item and says `Inspected 2m ago.` (or `From the
inspect cache, read …`); an uninspected looter still shows `…`, `range` or `–`. Settings › Window ›
Columns → untick My eq → the column goes. Narrow the window → My eq goes before Their eq. Tick
`Usable by me` → the rows reading Can't use or Not wanted in Me go; tick `Upgrade for me` → only
your ▲ rows stay; untick both. (Since DW-A1 these two are View values, not checkboxes: pick them in
the View dropdown, and FEED-20 covers the grayed tabs and the settings.) Close the window, then let any
member loot an item the feed shows → the window opens by itself; close it again and the next drop
opens it again; loot an item yourself → it opens too. Minimize it, let another drop come → it stays
minimized and its `n new` count rises. Untick General › When to show › Dungeon › Auto-open → drops
no longer open it; tick it back. Enter combat with the window closed and let an item drop → it opens
with no Lua error and no "Interface action blocked" message. `/dw sim start key` with the window
closed → the simulator's first drop opens it. Result:

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
tooltip line is gray with `(not on this tab)`; switch to My drops → View grays out. Settings › Feed
› Filters → four rows, `View: Interesting`, `View: Likely tradeable`, `View: Usable by me`, `View:
Upgrade for me`, all unticked; Trade › Timers no longer has Likely tradeable only. `/dw get
feed.view.likely` → `false`; `/dw set feed.view.usable true`, `/reload`, `/dw show` → a fresh
Group drops tab reads `Usable by me`; `/dw set feed.view.usable false`. On a character that had
ticked Usable by me or Likely tradeable only in the old settings (or `View: All` saved), the first
load of this version → the same choices show as View values. Result:

**FEED-21. Item tooltips beside the window (DW-A2, feedback-2 spec §2).** `/dw test`, window in the
middle of the screen. Hover an item in each place: a Group drops row (icon and name), My eq and Their
eq, the detail card's icon, name and Replaces rows, a My drops row, the Offer panel's icon and name,
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
bar holds `Character: Current`. Open it on Group drops and on My drops → `Character: All`,
`Character: Current` and your own character alone, its class icon beside the name, in class color.
Loot something on this character, log on to an alt and loot something there, then open History on
the alt → `Character: Current` shows the alt's drops only; the menu lists both characters, each with
its class icon and color. Tick the main as well → the label reads `Character: 2 selected` and both
characters' groups show. Untick the alt → the label is the main's row and only its drops show. Pick
Current → exactly the alt again, and the Current row lights gold. Pick All → every group, and a group
kept before this version (no recorder) shows its rows only now (under Current or a character it
keeps a header, `n drops · 0 shown`, its tooltip naming `Character: Current`). Hover a group header while the dropdown hides
some of its drops → the tooltip names them with `Character: Current`. Turn on `/dw test` → History
lists you and `Emberwick`, and Current hides the alt's `Placeholder boss (alt)` until All. `/dw sim
start key` then `/dw sim run` → the simulated run shows under Current on every tab. Result:

**FEED-24. The tables' font and row height beside Loot History's (DW-A8, feedback-2 spec §8, FB2-9).**
The headless `test_window_group` (`rows:`, `table: the Window page's row height`), `test_window_mine`
(`a row is the row height plus its bar's room`) and `test_history` (`rows take the Window page's row
height`) cover the same ground. On a profile that never moved Row height or Font size, `/dw test`, then
open Ka0s Loot History beside the window → the Group drops rows are as tall as Loot History's (18
pixels), the item icon fits inside the row, and the text is the same small table font at the same size
(compare research `11-font-vs-loothistory.png`, where Drop Watcher's was larger). My drops → the
same text size; each row is taller by the room its countdown bar needs, and the countdown and its bar
do not overlap. History → the same rows as Group drops. Settings › Window › Layout → Row height reads
18 and Font size reads 0, all the way left (Default). Drag Font size to 15 → the text grows on all
three tabs, the My drops countdown included (also while it reads `ending soon` in bold), and the My
drops rows grow with it so an upgrade's verdict never touches its `keep?` line and the countdown never
runs into its bar (also at Font size 20 with Row height 18); drag it back
to 0 → the original size returns. `/dw get window.fontSize` → `0 (Default)`. On a profile where you had
stored another row height or font size before this version, it is unchanged. Result:

**FEED-25. My drops headers and the tooltip beside the Offer panel (DW-A9, feedback-2 spec §8,
FB2-10).** The headless `test_window_mine` (`rows sit under their run's or encounter's header`, `the
rows sit under a header naming the party`) and `test_window_group` (`beside the docked Offer panel`,
`a docked panel's row never opens over the window`) cover the same ground. `/dw sim start key` then
`/dw sim run` until your own drops fall, or `/dw test` → My drops shows its rows under the same
headers as Group drops: `Den of Nalorakk · Mythic+ · 6m ago · 2 drops · You, A, B, C, D`, the party
in class color, every group open. Click a header → its rows fold away and it reads `(collapsed)`,
while the summary strip still counts their tradeables; click again → they return. Search for one
item → the header reads `n drops · 1 shown`. Open a row's Offer panel, docked on the window's right,
then hover a My drops row's item → the tooltip opens to the RIGHT of the panel, never over it; drag
the window toward the screen's right edge until the panel has no room beside it (or the tooltip
does not fit) → the tooltip opens on the window's LEFT. Hover an item in the panel → the tooltip
never covers the window (right of the panel, else left of the window). Close the panel and hover a
row → the tooltip is beside the window again. Result:

**FEED-26. Every row tooltip at the row's top right, like Loot History (DW-B2, feedback-3 spec §2).**
The headless `test_row_tooltip` covers the same ground. `/dw test`, window in the middle of the
screen, Ka0s Loot History open for comparison (research `06-loothistory-tooltip-top-right.png`). On
Group drops hover a row's item, then its Looter, My eq, Their eq, Me, Them and Trade cells, the Ask
button and the dismiss ×, then a group header → every tooltip's bottom-left corner sits at the
hovered row's top-right corner, just outside the window's right edge, rising above the row, never
over the table (compare `04-cell-tooltip-in-row.png`, where a reason opened over other columns). On
My drops hover each cell of a row, its Offer and Announce buttons (or the dash and Hide), and a
header → the same corner. On History hover each cell of a row and a header → the same. Open a
row's Offer panel (docked right) and hover a window row → the tooltip rises outside the panel's
right edge; hover a candidate's cells, pill, Offer and Trade → the same corner, never over the
window. Drag the window to the screen's right edge and repeat a few → each rises from the row's
top-LEFT corner instead, just outside the window's left edge. The column labels, the tabs, the title
bar, the footer and the filter bar keep their own anchors. Result:

**FEED-27. The filter bar's tooltips open above their controls (DW-B1, feedback-3 spec §1).**
The headless `test_window_shell` (its three `filter bar tooltip` cases) covers the placement math. `/dw test`, window in
the middle of the screen (research `03-view-tooltip-over-dropdown.png` shows the old overlap). Hover View,
Quality, Content, Character, the search box and the footer's Sort in turn → each tooltip's bottom-left
corner sits on the control's top-right corner, the tooltip rising above the control and never covering
it; click a dropdown open while its tooltip shows → the menu is never under the tooltip. Drag the
window to the screen's right edge and hover the right-most controls → the tooltip's bottom-right
corner sits on the control's top-left corner instead, still above it. Result:

**FEED-28. Group headers name where it dropped and only your character (DW-B4, feedback-3 spec §4).**
The headless `test_group_place` covers the names and the capture. Research `07-my-drops-real-timewalking-drop.png`
shows the old header (`Commander Ri'mok · Dungeon · ... · Euthanàsia, Deathllanira, ...`) and
`08-header-roster-too-long.png` the roster crowding it. Run a Timewalking dungeon and kill a boss that
drops something → the Group drops (or My drops) header reads `Gate of the Setting Sun · Commander
Ri'mok · Timewalking · 3m ago · 1 drop · <you>`: the instance, the boss, the client's difficulty name
(never the generic `Dungeon`), the time, the count, then only your character, in class color. Do the
same on Normal, Heroic, Mythic, in Raid Finder and in a delve → each header names that difficulty as
the client does. Finish a key and loot the chest → `<Dungeon> · Mythic+ <key level> · ... · <you>`.
Open History → the same groups read the same; `/reload` → they still do; log in on an alt and open
History with `Character: All` → a group the first character saw ends with that character's name, not
the alt's. A History group kept before this version still reads `Label · Situation · ...`. In the open
world → `Open world · Open world group` (or `Solo`). `/dw test` → the key run is a real dungeon at
`Mythic+ 10` and the boss sits in a real instance at Heroic, on Group drops, My drops and History.
`/dw sim start dungeon` then `/dw sim run` → the boss headers name the pool's dungeon and `Mythic`;
`/dw sim start key` → the run's header names the dungeon and `Mythic+ 12`. Result:

**FEED-29. The tabs agree beyond the defaults, and a tooltip near the top of the screen opens below
(DW-B5, feedback-3 spec §5).** The headless `test_sim_report` (its `tab counts` cases) and
`test_window_shell` (its `near the top` cases) cover the counts and the placement. Solo, `/dw sim
start key`, then play it to its loot step → the tab reads `My drops · 1` and the Group drops header
`· 1 yours on My drops`. On My drops, press your drop's Hide → the tab reads `My drops` with no count,
the Group drops header loses `· 1 yours on My drops`, and the tab's tooltip ends `Not listed here:`,
`<item>: you hid it`. `/reload` (Hide is session-only), play to the loot step again, then type text
no drop matches in My drops' search box → the same: no count, no suffix, and the tooltip names the
drop with `Search`. Clear the box → `My drops · 1` and the suffix return. Then drag the window to the
top edge of the screen and hover View, the search box and the footer's Sort → each tooltip opens
below the control, its top-left corner on the control's bottom-right corner (its top-right on the
bottom-left at the screen's right edge), never over the control or its menu; drag the window back
down → above again. Result:

**FEED-30. A delve's header, and whether the client names its tier (DW-B4, feedback-3 spec §4).**
The spec names `a delve tier` among the header's difficulties; offline, neither GetInstanceInfo's
difficultyName nor GetDifficultyInfo is known to give it (both are read as `Delves` for difficulty
208), so the header names `Delves` and the tier is a known limitation (ARCHITECTURE.md). The headless
`test_group_place` covers the order the two names are read in. Enter a delve at a known tier (say
Tier 8) → `/dump GetInstanceInfo()` and record its fourth return (difficultyName) and its third
(the difficulty id), then `/dump GetDifficultyInfo(<id>)`'s first. Loot something from its chest →
the Group drops (or My drops) header reads `<Delve> · <label> · <the difficultyName recorded> · ... ·
<you>`. If either dump names the tier, the header shows it; if neither does, record that here so
the tier can be read from another source or the gap ratified. Result:

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
item yourself, ideally one that also reaches the feed through the encounter's report. → My drops
lists it at the item level and in the quality color its own game tooltip shows (the owner's case:
*Lustrous Golden Plumage*, 311 and Epic, never 19 and Rare). If the console showed `also reported by
encounter` before the chat line, it also shows `(its more complete link taken)` on the chat line's merge. Once the
item is in your bags (a second or two after the loot window closes) the console shows `read from its
bag item <bag>:<slot>`, and `/dw diagnostics` shows a `drops:` line for it reading `complete=true
ilvl=<the tooltip's level> (current) quality=<4 for Epic> (location) mine=true bag=yes`. Its For me
verdict and its trade window agree with the game tooltip's own "You may trade this item…" line.
Record any drop whose level or color differs from its tooltip, and paste its `drops:` line. Result:

**ITEM-4. The real game tooltip, everywhere (BUG-2).** Hover an item in each place: a My drops row
(the icon and the name), a Group drops row (the icon and the name), the detail card's icon, name and
Replaces row for you and for the looter, the Offer panel's icon and name, a History row, the toast's
icon, and the Their eq column. → Each shows the game's own item tooltip, exactly as hovering the
item in your bags or on the character sheet does, with the addon's line (shift-click to link,
ctrl-click to try on) after the game's lines. Your own drop that is still tradeable shows the
client's "You may trade this item with players that were also eligible to loot this item for the
next …" line; your own worn item in the Replaces row shows your equipped copy (its enchant and gems).
Move your own drop to another bag slot and hover again → still the right tooltip. Record any place
that shows a tooltip built from text, or misses the trade line. Result:

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
item and seeing the trade succeed. More than two hours after the drop, the chip shows `No` (expired)
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
BoE drop → its `trade: drop` line reads `expired=false boe=true`, no countdown, and Give is offered
for it. The failure
looks like no `trade:` line for a tradeable item (the tooltip line or its sentence did not read:
record the tooltip text as shown), a time that drifts from the tooltip's, or a repeated warning.
Result:

**TRADE-6. The trade helper.** The guards, the GUID lookup and the call order are headless-tested
(`test_trade_helper`); this check confirms the client's side, and runs once the My drops tab and the
Offer panel (DW-33) carry the Trade and Offer buttons. In a dungeon, with a tradeable own drop
(TRADE-5's `live=1`) and a member standing next to you: click Trade on the drop for that member →
the trade window opens with the item already in it; cancel it. Move the item to another bag slot
and click again → the same. Click Open trade (no item) → an empty trade window. Walk out of trade
range (about 11 yards) → the button is disabled with "That player is out of trade range."; in
combat → "You cannot trade in combat.", with no error from the client and no Lua error from
`CheckInteractDistance`. Hold another item on the cursor and click → "Your cursor is holding an
item.", and the held item stays on the cursor. With `/dw debug on`, each click leaves a `[TRADE]`
`give:` or `open:` line, or a `refused:` line with its reason; `/dw diagnostics` shows
`trade helper: gives=… opens=… refused=… last=…`. The failure looks like the trade opening empty
when an item was meant (the drop did not land), the wrong item handed over, a client "Interface
action failed" message, or an item left on the cursor. Result:

## Ask

The messaging core's decisions (token expansion, the length limit, the one-ask guard, the queue's
order and cancel) are headless-tested (`test_messaging`), and the edge's send, queue, flush, cancel
and test-mode routing too (`test_asks`); these checks confirm the client's side. The My drops
tab's and the Offer panel's buttons are ASK-5..7 (DW-33) and auto-ask is ASK-8 (DW-54); ASK-1..4
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
[item]`. The failure looks like a Lua error, no whisper with `sent` printed, a broken link, or a
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

**ASK-5. The My drops tab.** In a dungeon, loot three or four items of your own: one you will not
wear (a downgrade), one that is an upgrade for you, and, if the boss drops it, a bonus-roll item.
Open the window and click `My drops · n` → n counts every drop of yours, and the tab's tooltip how many you can trade; one row per drop of
yours: the item button, its item level, `For me` (`-5 ▽`, or `+3 ▲` over `keep?` for the upgrade),
`Trade window` (`1:59:40` over a green bar that shortens, matching the item tooltip's time to the
minute once the item is in your bags, `~1:59:40` for a moment before that), `Best candidates`
(`Seta +14 · Butterz +6`, `2 checking` while their inspects run, or `Hidden: an upgrade for you`
on your upgrade) and `Offer` and `Announce`. The bonus-roll row reads `Bonus roll`
with a dash and `Hide`; Hide removes it. With ten minutes or less left, the countdown reads
`0:09:59 ending soon`, in bold amber, and the trade timer's chat warning prints once. The summary
under the rows reads `2 tradeable · next expiry 0:08:41`. Click `Announce` → "[item] is up for
grabs, whisper me." in party (instance) chat, the button reads `Announced` grayed; in a boss fight
it reads `Queued` and goes out at the kill. Hover every cell and button → each tooltip says why;
nothing is blank. Result:

**ASK-6. The Offer panel, Offer and Trade.** On the downgrade's row click `Offer` → a panel
`Who could use this? YOUR DROP` opens docked to the window's right edge (move the window to the
screen's right edge and it docks on the left instead; make the window nearly screen-wide and it
floats over the window's right half). Its header shows the item, `You: -5 ilvl · 305 · Trade window
1:47:12`, then every other member with a class-colored stripe, `291 → 305` and a pill (`+14
UPGRADE`, `EQUAL`, `NO UPGRADE`, `CAN'T USE`, `CHECKING`), upgrades first by gain; in a raid the
list scrolls. Click `Offer` on the top member → they are whispered "Hi <name>, [item] is tradeable
and looks like +14 for you. Want it?" and the button reads `Offered`. Standing far from them,
`Trade` is grayed with "That player is out of trade range."; walk up → click it → the trade window
opens with the item already placed; cancel it. `Announce to group` posts the announce once. On the
upgrade's row, `Offer` opens the panel and the row's `Best candidates` now shows the names. Close
the panel with its close mark. Result:

**ASK-7. Post my tradeables.** With two or more tradeable drops of yours, click `Post my
tradeables` under the My drops rows → one party (instance) chat line `Up for trade, whisper me:
[item] [item]` with every link intact; with enough drops to pass 255 characters (or long names in a
raid) it is two or more lines, none cut mid-link. Click it again → it posts again. With none
tradeable the button is grayed. In test mode (`/dw test`) the lines are printed, not sent. Result:

**ASK-8. Auto-ask.** Its timing, its checks and its cancel rules are headless-tested
(`test_auto_ask`); this confirms the client's side. Settings › Messages › Auto-ask › Ask automatically
on → chat reads the one-time notice (`Auto-ask is on: … 5 or more item levels … 10 seconds after the
boss kill or the drop.` and how to turn it off); turn it off and on again → no second notice, and
none after a `/reload`. `/dw test` with it on → about 10 seconds later chat reads `Test mode, not
sent: …` for the sample drops that qualify, and nothing is whispered. In a dungeon with
`/dw debug on`, kill a boss whose loot gives someone else a likely tradeable upgrade of 5+ item
levels for you → `[MSG] auto-ask scheduled` when the drop lands, then 10 seconds after the kill (or
the drop, if later) the whisper goes with `Whispered <name>: [item]` and the row's Ask reads
`Asked`. Repeat with each cancel: press Ask yourself first (one whisper only), dismiss the row with
its × (none), or have the looter leave the group (none); each logs `[MSG] auto-ask canceled` with
its reason. Pull the next boss while one is waiting → nothing goes during the fight, and it goes
10 seconds after that boss dies. Result:

**ASK-9. Auto-ask after leaving an encounter (DW-62).** Auto-ask on, `/dw debug on`, in a dungeon
group. Pull a boss, then hearth out (or release and run out) before it dies. After the loading
screen (or a moment later, when the client reports the Encounter restriction lifted after it;
M6 review) the console reads `[MSG] auto-ask: left the encounter without its end; …` (only when
one was held) and `/dw diagnostics` shows auto-ask `inEncounter=false`. Have a member loot a likely
tradeable upgrade for you (or `/dw add` one naming them) → the whisper goes after the delay, not at
the next boss or `/reload`. Back inside, pull a boss and cross into another part of the instance
during the fight → nothing is asked until the boss dies. Result:

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
with <name> completed: gave 0, got 1` and `history: <item> received`; the Group drops row's Ask
button reads `Traded ✓` and the History tab's row `Received`. Then trade one of your own drops away
(My drops › Offer › Trade, both accept) → its History row reads `Traded away`. Cancel a trade
before both accept → nothing changes. Then a trade that fails after both accept (the partner's bags
full, or one of you walks out of range as the second accept lands) → no `completed` line and the
History row keeps its outcome. If no `completed` line appears after a real trade, record what
`/etrace` shows for `TRADE_ACCEPT_UPDATE`, `TRADE_CLOSED` and `UI_INFO_MESSAGE` (its message type
beside `/dump LE_GAME_ERR_TRADE_COMPLETE`) around the accept, and in which order. Result:

**HIST-2. The History tab.** After a few drops, `/reload` and `/dw history` → the tab opens on View:
All and Content: All, the drops are under their encounter's header (the newest open), each row
with its Outcome; a header of an older day reads `n days ago`. Right-click a row → a menu with
`Mark as declined`; choose it → the row reads `Declined`; right-click again → `Clear declined`
puts the earlier outcome back. Content: This session → only today's drops. Clear history →
a confirmation; No keeps everything, Yes empties the tab on this and your other characters, and chat
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

## Toast

**TOAST-1. The upgrade toast.** Settings › Window › Toast › Show a toast on, then `/dw test` → a
toast under the top of the screen reads `Big upgrade for you`, the name of Seta's head item (a real
item since DW-84) and `Looted by Seta · +19 ▲ · Likely tradeable`, with an Ask button and a close mark; it stays while test mode is
on. Drag it somewhere else, `/dw test` off (it goes), `/reload`, `/dw test` → it comes back where you
left it. Outside test mode it cannot be dragged. Window › Layout › Reset position → back under the
top. With Play a sound on, each toast plays the epic loot sound. In a dungeon with a group member,
when a drop of theirs is a 10+ item-level upgrade for you and likely tradeable → the toast shows
once, goes after 8 seconds, and stays while the pointer is over it (it then has the seconds it had
left); press Ask → the button reads `Queued` or `Asked` and the whisper goes as from the row. A
second qualifying drop waits until the first goes. Pull a mob while one is due → nothing shows in
combat, and it shows when combat ends; with Show in combat on, it shows at once. Result:

**TOAST-2. The toast leaves with its drop and with its switch (DW-62).** Toast on, `/dw test` → the
test toast shows. Untick Settings › Window › Toast › Show a toast → it goes at once (a test toast has
no countdown, so nothing else would take it down). Tick it again and turn test mode off and on → the
toast is back. On Group drops, click the toasted row's × → the toast goes, and no other takes its
place. Out of test mode, in a group: `/dw add <a link you would upgrade> <member>` → a toast; `/dw
clear` → it goes at once. `/dw add` again, then Settings › Profiles › switch to a profile with Show a
toast off → it goes. In none of these does the toast's Ask stay pressable for a drop that is gone or
dismissed, and no Lua error shows. Result:

**TOAST-3. An upgrade into an empty slot toasts and auto-asks (DW-62).** Take off a ring. Toast on
with Least gain 50, auto-ask on. In a group: `/dw add <a BoE ring link> <member>` → a toast reading
`Looted by <member> · empty ▲ · Tradeable`; after the auto-ask delay the whisper goes and reads
`It'd be an empty-slot upgrade for me`: never the ring's item level, never `+?` and never `+an`.
Result:

## Transmog

**TMOG-1. The look chip and the For transmog ask.** `/dw test`, open the Group drops tab and expand
Seta's head item (real items since DW-84) → its header has a gray `Look known` chip; expand
Littlewolf's one-hand weapon → a green `New look` chip, and its Ask is a dash (`It is not an upgrade
for you.`). Settings › Messages › Sending › Ask for transmog on → the weapon's Ask is offered, its tooltip reads `Ask for
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
Group drops tab, and the History tab shows only your real history. Each refusal prints its own line:
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
in turn, then `Chat lockdown` after the completion; the completion's loot lands in Group drops and My
drops, the debug log shows one `[SIM] event …` line per injected event and one `[SIM] timeline step
n/11: …` per step, and chat ends with `The simulation's timeline has finished.` Press Ask on a member's
drop while the lockdown holds → it waits in the badge's queue; when it lifts, chat prints `[sim]
WHISPER to <member>: <text>` and the whisper tab shows nothing sent. Each drop shows your verdict and,
within a few seconds, the looter's. `/dw diagnostics` → the `sim:` lines show `scenario=key`, the
pool's size and `source=journal`, `timeline step=11/11` and the sends printed. Result:

**SIM-3. A `raid` run with a large roster (DW-73).** The headless `test_sim_scenario` (`sim e2e raid`)
covers the same ground. `/dw sim start raid 19` → the Group drops tab's roster shows 19 invented
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
debug on`: `/dw sim start dungeon` → the Group drops tab's roster shows four invented members, and
the footer's situation is the dungeon. `/dw sim loot 1 <member>` → the drop shows the looter's name
(a member from another realm as Name-Realm) and, within a few seconds, a Them verdict; the debug log
shows `[SIM] inspect of <member>: reply in <n>s` and no real inspect window opens. Record whether the
member's spec shows on the drop's detail card (the broker reads it after its own clear; the
simulator answers as the client does). `/dw sim pull` → the badge shows the encounter; press Ask on
a member's drop → it is queued, nothing is printed. `/dw sim kill` → within a few seconds chat prints
`[sim] WHISPER to <member>: <text>`, and the whisper tab shows nothing sent. Result:

**SIM-5. Your own drops' trade windows and a simulated trade (DW-72).** The headless `test_sim_events`
covers the same ground. `/dw sim start dungeon`, then `/dw
sim loot 2 me` → My drops shows both, the first with about 9 minutes left (it warns at once, since
the warning is at 10 minutes) and the second with about 2 hours; your real bags are unchanged.
Offer the second to a member and press Trade → chat prints `[sim] Would hand the item to <unit>.` and
no trade window opens. `/dw sim trade <its id>` → the History tab shows it `Traded away`; loot a
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
Interesting, Quality: Rare+, Content: This instance) and your usual gear: `/dw sim start key`, then
`/dw sim run` → chat prints one line per step (`Simulation step 1 of 11: runStart.` … `Simulation
step 10 of 11: loot: 2 drops (1 yours).` … `step 11 of 11: lockdownOff.`), the footer reads `Simulating:
Mythic+ · 4 members` and `Inspect 4/4 fresh` once the inspects land, Group drops shows at least one
member's drop and My drops at least one of yours. Repeat with `/dw sim start delve` and `/dw sim
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

**SIM-12. The loot step says where its drops went, and the tabs reconcile (DW-B0, feedback-3 spec
§0).** The headless `test_sim_report` covers the same ground in every scenario. Solo, with the
window's filters at their defaults: `/dw sim start key`, then play it to its loot step → the panel
row and the chat line read `Loot: 2 drops (1 yours)` (`Simulation step 10 of 11: loot: 2 drops (1
yours).`); hover the row → it names each drop, its looter and where it is (`… (you): My drops`,
`… (<member>): Group drops`). Group drops shows the member's drop under a header reading `1 drop · 1
yours on My drops`; the tab reads `My drops · 1` even when your drop is an upgrade you keep, and its
tooltip says how many of your drops you can still trade. `/dw set feed.minIlvlMode absolute` and
`/dw set feed.minIlvl 900`, then `/dw sim loot 2` → chat reads `Simulated loot: 2 drops (2
hidden).` and the tables gain nothing (set both back afterwards). Result:

**SIM-13. The loot step honors `feed.showOwn` and the feed the window shows (DW-B5, feedback-3 spec
§5).** The headless `test_sim_report` (its `showOwn` and `View` cases) covers it. `/dw set
feed.showOwn true`, `/dw sim start key` and play to its loot step → the panel row and the chat line
read `Loot: 2 drops` (no `1 yours`: Group drops lists both), and the row's tooltip says `… (you):
Group drops and My drops`; Group drops shows both drops and its header has no `yours on My drops`.
`/dw set feed.showOwn false` → the row reads `Loot: 2 drops (1 yours)` again on the next repaint.
Turn test mode on (`/dw test`) with the step played → the row reads `Loot: 2 drops (2 not shown in
test mode)` and its tooltip `… not shown while test mode is on`; turn test mode off → the places come
back. On My drops, Hide your drop → the tab reads `My drops`, and the row `Loot: 2 drops (1 not on My
drops)` with the tooltip `… (you): not on My drops: you hid it`; type a search your drop fails on
My drops instead → the same, the tooltip ending `not on My drops: Search`. Result:

## Compact

**COMPACT-1. The layout switch (DW-C0).** With the window open in its full layout, hover the
title bar's new mark between Scan group and minimize → `Compact view`, naming the Layout setting.
Click it → the same window narrows to 380 x 460 with its top-right corner where the full window's
was, and the mark turns to the enlarge mark (`Full view`). Drag it somewhere else and size it from
the corner → it stops at 320 and 520 wide (220 and 900 tall). Click the mark → the full window comes
back at its own size and place; click again → compact returns where you left it. `/dw compact` and
`/dw full` do the same and print `Compact view.` / `Full view.`; Settings → Window → Layout shows
the choice and switching it there moves the window too. `/reload` → the window opens in the layout
it was in, each at its own place; Reset position puts both back. An account that had the old compact
preset on opens compact after the update. Result:

**COMPACT-2. Group drops cards (DW-C2).** Turn test mode on (`/dw test`) and switch to the compact
layout (`/dw compact`) → each drop is a three-line card about 50 pixels tall under a one-line header
(`Instance · Boss · Difficulty · 3m · 2 · <you>`, no `ago` and no `drops`; its tooltip has the long
form and any hidden drops). Line 1: the icon spans the three lines, the item name in its quality
color with a thin bar of that color at the left edge, the item level right-aligned, `Ask` and the ×.
Line 2: the looter in class color (⊕ on one from another realm, the realm in its tooltip), the slot,
the trade state in its tone and the inspect freshness dimmed on the right (`2m`, `cached`, `…`,
`range`). Line 3: `You ▲ +19 (292)`-style and `Them ▽ -13 (…)`-style halves, `⊘ Can't use` for a
worded verdict. Check every test-mode state: the Ask button reads Ask, Queued, Asked, Retry or
Traded as on the full table, and a drop with no ask shows a dash whose tooltip says why. Hover the
icon or the name → the game's own item tooltip. Click a card → the detail card opens right under
it at the compact width, For you, For the looter and the trade box one under another, the actions on
two or three lines, nothing cut off on the right; click it again → it closes; switch to full with it
open → the same row is open there. Click × → the card goes for the session. Settings → Window → Font
size 14 → the cards grow with the text. Run `/dw sim start` and step it → the cards fill the same
way. Result:

**COMPACT-3. My drops cards, the countdown, Offer and Announce (DW-C3).** Turn test mode on and
switch to the compact layout, then open My drops → each drop of yours is a three-line card under a
one-line header. Line 1: the icon, the name in its quality color, the item level and `Offer` (gold
when someone would gain from it), or a dash whose tooltip says why on a drop that cannot be traded.
Line 2: `For you ▲ +49 (keep?)`-style, then the countdown and a short bar after it on the right,
amber with `ending soon` under ten minutes, `Not tradeable` with no bar on a dead drop, `No limit
(BoE)` with a full bar on a bind-on-equip one. Line 3: the best candidates in their class colors
(`Seta +14 · Butterz +6`), then `Announce`, or `Hide` on a drop that cannot be traded. The countdown
moves every second. Click Announce → the template goes to the group and the button reads
Announced. Click Hide → the card goes for the session. The strip under the cards reads `n tradeable ·
next 0:08:41` with a `Post` button whose tooltip is Post my tradeables'. Click Offer → the Offer
panel opens beside the compact window at its usual width, on the right; drag the window to the
screen's right edge → it moves to the left side; make the window short → the panel keeps a usable
height. Switch to full → the strip and the table are back as before. Run `/dw sim start` and step it
→ your own drops fill the cards the same way. Result:

**COMPACT-4. History cards and their outcomes (DW-C3).** In the compact layout, open History → each
kept group is a one-line header (`Boss · Dungeon · 2m · 2 · <you>`, `3d` once a day old) and each
entry a three-line card: the item and its level with the outcome on the right in its tone (Seen,
Asked, Offered, Received, Traded away, Expired, Declined); the looter in class color (⊕ from another
realm), slot, trade and the time on the right (`17:02`, or `Oct 9` past a day); `You` and `Them`
verdicts. Right-click a card → Mark as declined; its outcome reads Declined; right-click again →
Clear declined. The strip's button reads `Clear` with the Clear history tooltip, and it still asks
first. Switch to full → `Clear history` again. Result:

**COMPACT-7. Card tooltips at the card's top right (DW-C2).** In the compact layout, hover each piece
of a card (the item level, the looter, the slot, the trade, the freshness, You, Them, the worn
levels, Ask and ×) and a header → each tooltip rises from the card's top-right corner, just outside
the window's right edge (or its left edge when the window sits against the right of the screen),
never over the cards. Result:

**COMPACT-6. Open in compact view during a run (DW-C0).** With the Layout on Full and Settings →
Window → Open in compact view during a run on (the default), close the window and start a Mythic+
key → the first drop opens the window compact; the Layout setting still reads Full. Complete the key
with the window still open → it stays compact; close it and reopen it (`/dw show`) → it opens full.
Close it inside a dungeon run, let a drop open it → compact; click the toggle → full at once, and it
stays the player's choice. Turn the option off → an auto-open in a run keeps the Layout. Result:

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
trade-time decode: loot a tradeable bind-on-pickup item, open My drops → its countdown is exact (no
`~`) within a few seconds of the item reaching your bags, and `/dw diagnostics`'s `trade` lines
show its seconds left close to the tooltip's `… remaining` sentence; an item that stays `~` or reads
expired while the tooltip still shows the sentence is the failure (record the sentence and `/dump
INT_SPELL_DURATION_HOURS, INT_SPELL_DURATION_MIN, TIME_UNIT_DELIMITER`). Last, the track names:
expand a drop that has an upgrade track → the detail card's track chip shows the client's own
(localized) track name and rank, never an English name; the track change line may be missing on
this client (Known Limitations), and its absence is not a failure. Result:

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
| FEED-10..12 | DW-31, the Group drops table | No client pass recorded yet |
| FEED-13..15 | DW-32, the detail card | No client pass recorded yet |
| FEED-16 | DW-81, the header matched to Loot History | No client pass recorded yet |
| FEED-17 | DW-82, the filter bar matched to Loot History | No client pass recorded yet |
| FEED-18 | DW-83, My eq, Their eq, the two new filters, auto-open on every drop | No client pass recorded yet |
| FEED-19 | DW-A0, the two-Yoke regression, every hidden or refused drop counted by reason, `n drops · m shown` | No client pass recorded yet |
| FEED-20 | DW-A1, View: All by default, the multi-select View, its tooltip and the migration | No client pass recorded yet |
| FEED-21 | DW-A2, item tooltips beside the window, right or else left, on every tab | No client pass recorded yet |
| FEED-22 | DW-A3, the party kept with every group, on the header tooltip's `Group:` line (DW-B4), and in History | No client pass recorded yet |
| FEED-23 | DW-A4, the Character dropdown on every tab, History filtered by who saw each drop | No client pass recorded yet |
| FEED-24 | DW-A8, the tables' font and row height like Loot History's, on all three tabs | No client pass recorded yet |
| FEED-25 | DW-A9, My drops under the group headers, the tooltip beside the docked Offer panel | No client pass recorded yet |
| FEED-26 | DW-B2, every row tooltip at the row's top right (else top left), all three tabs and the Offer panel | No client pass recorded yet |
| FEED-27 | DW-B1, the filter bar's tooltips above their controls, top right (else top left) | No client pass recorded yet |
| FEED-28 | DW-B4, group headers: the instance, the boss, the difficulty name and only your character, all three tabs and History | No client pass recorded yet |
| FEED-29 | DW-B5, the My drops count and the Group drops suffix agree with what My drops lists; filter-bar tooltips below their controls near the top of the screen | No client pass recorded yet |
| FEED-30 | DW-B4, a delve's header, and whether the client names its tier | No client pass recorded yet |
| STATE-4 | DW-84, test mode with real items, History test data, no trailing ellipsis | No client pass recorded yet |
| ASK-5..7 | DW-33, the My drops tab, the Offer panel and Post my tradeables | No client pass recorded yet |
| SLASH-4..6 | DW-42, the feature slash verbs | No client pass recorded yet |
| PROFILE-3 | DW-40, the settings rows, defaults and step 2 | No client pass recorded yet |
| PANEL-4..6 | DW-41, the settings pages | No client pass recorded yet |
| PANEL-7 | DW-40 / DW-41 review, the rows that act | No client pass recorded yet |
| SCORE-1..2 | DW-50, the scorers | No client pass recorded yet |
| SCORE-3 | DW-62, Pawn counts once it is initialized | No client pass recorded yet |
| HIST-1..2 | DW-51, the history and the History tab | No client pass recorded yet |
| HIST-3 | DW-A5, Keep history for, its confirmation, the login prune and step 4 | No client pass recorded yet |
| HIST-4 | DW-A9, the prune after a disabled start, a stale confirmation | No client pass recorded yet |
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
| SIM-12 | DW-B0, the loot step says where its drops went; the tabs reconcile | No client pass recorded yet |
| SIM-13 | DW-B5, the loot step honors `feed.showOwn`, test mode's feed and My drops' Hide and filters | No client pass recorded yet |
| COMPACT-1, COMPACT-6 | DW-C0, compact mode's switch and the run override | No client pass recorded yet |
| COMPACT-2, COMPACT-7 | DW-C2, compact Group drops cards, the stacked detail card and the card tooltips | No client pass recorded yet |
| COMPACT-3, COMPACT-4 | DW-C3, compact My drops and History cards, the countdown, Offer and Announce, the docked Offer panel | No client pass recorded yet |
