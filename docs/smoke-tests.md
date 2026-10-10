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
| SLASH-1..3 | Slash | `/dw` and `/dropwatcher`, help, the window verbs |
| PANEL-1..3 | Settings panel | Landing page, General → Master controls, the Defaults button |
| PROFILE-1..2 | Profiles | The Profiles page and the `profile` verb |
| STATE-1..3 | State | Enable/disable, lock, test mode |
| COMPAT-1..3 | Compat | The client facts `core/Compat.lua` relies on (lands with DW-20) |
| COMBAT-1..3 | Combat | Loot reads mid-encounter, restrictions, test mode ended by combat |
| DIAG-1..2 | Diagnostics | The debug console, the report, perf |
| DEGRADED-1 | Degraded | The install with LibKa0s missing |
| FEED-1..9 | Feed | The loot parser (FEED-1, DW-25), the feed (FEED-2..6, DW-27), a Devourer looter (FEED-7, reserved) and the window's shell (FEED-8..9, DW-30) |
| ROSTER-1..2 | Roster | The group's members and the name resolver (lands with DW-22) |
| ITEM-1..2 | Item facts | The item readers' shapes and the track ids (lands with DW-23) |
| GEAR-1..2 | Gear | Your gear snapshot, the owned best and the rebuild events (lands with DW-24) |
| INSPECT-1..4 | Inspect | The inspect broker: warm-up and spacing, the waits and the cache, courtesy and combat, the item level (DW-26) |
| TRADE-1..6 | Trade | Trade estimates and the raid rule (TRADE-1..4, DW-14), timers (TRADE-5, DW-28), the trade helper (TRADE-6, DW-29) |
| ASK-1..8 | Ask | Sending and its confirmation, the queue and its flush, cancel, a whisper during an encounter (ASK-1..4, DW-2A); the buttons and auto-ask (ASK-5..8, DW-33, DW-54) |
| SIT-1..5 | Situations | Where the addon is active (lands with DW-13) |
| QUAL-1..4 | Quality | The minimum-quality gate (lands with DW-12) |
| LOC-1 | [Non-English client](#non-english-client) | What a deDE or frFR client changes |

## Before you start

- Install the addon folder as `Interface\AddOns\DropWatcher` and `/reload`.
- Have a second character or a friend available for the window and trade checks once those land.
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

## Settings panel

**PANEL-1. Landing page.** Settings → AddOns → Ka0s Drop Watcher → the logo once (not twice after
switching pages back and forth), the notes line, and the slash command list. Result:

**PANEL-2. Master controls.** General → the `Master controls` tab: Enable, General visibility,
Master scale, Master alpha, Lock frame, Debug console, Minimap button, Test mode, then Reset position
and Reset all settings. Each control changes the window at once. Result:

**PANEL-3. Defaults and Reset all.** Hide the minimap button, change the scale, press the header's
Defaults button and accept → the scale is back to 1.0 and the minimap button stays hidden. Result:

## Profiles

**PROFILE-1. The Profiles page.** Settings → Ka0s Drop Watcher → Profiles → AceDB's page draws;
create a profile, change the scale, switch back → each profile keeps its own scale. Result:

**PROFILE-2. The profile verb.** `/dw profile` lists the profiles; `/dw profile <name>` switches,
and works while the addon is disabled. Result:

## State

**STATE-1. Disable stands everything down.** Open the window and turn test mode on, then
`/dw disable` → the window closes, test mode ends, `/dw show` and `/dw test` answer `Ka0s Drop Watcher
is disabled — enable it with /dw enable`; the minimap menu grays every entry but Enabled;
`/dw enable` → the window comes back. Result:

**STATE-2. Launcher menu.** Right-click the minimap button → Enabled, Locked, Test mode, Show window,
each ticking the state it shows and toggling it. Result:

**STATE-3.** *Reserved — DW-34 (test mode populates every drop state).*

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

## Degraded

**DEGRADED-1. LibKa0s missing.** Rename `libs\LibKa0s` and `/reload` → no Lua error; one chat line
says the library is missing; `/dw show` opens the window without the skin; `/dw disable` and
`/dw enable` still work; `/dw list` says the settings CLI is unavailable. Restore the folder after.
Result:

## Feed

The parser's patterns, the rebuild and the secret guards are headless-tested (`test_loot_parser`),
and the feed's dedupe, grouping and gate order are too (`test_feed`); FEED-1 confirms the client's
real lines and FEED-2..6 what the feed makes of the client's real events, read through `/dw debug on`
and the `feed:` lines of `/dw diagnostics` until the window's feed tabs draw them (DW-30, DW-31; the
table's own checks take the next free numbers). Reserved: FEED-7 (a Devourer Demon Hunter looter
before inspect: a warglaive or one-hander reads as usable and a held off hand as not, matching the
item's own spec list; the class data of DW-10, judged by DW-11).

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

**FEED-8. The window's shell.** `/dw show` on a clean `/reload` → a window about 940 × 600 with the
Ka0s edge (a hard black line with a gray line inside it), the logo and the gold `Ka0s Drop Watcher`
title, a `Scan group` button with a people mark, a minimize mark and the close mark; the `Group
drops` tab gold with a gold underline, `My drops` and `History` gray; the filter bar reads `View:
Interesting`, `Quality: Rare+`, `Content: This instance`, an unticked `Likely tradeable only` and
the `Filter looter or item…` box; the footer reads `Inspect: no group`, `No loot seen yet` (or
`Last loot …`), `Not tracking in Solo · change in settings`, `Pawn: on` or `off`, and `Sort:
Newest` beside the corner grip. Hover each control → every one shows a tooltip with a reason.
Click `My drops` → View, Quality and Likely tradeable only gray out (their tooltips say the tab
does not use them); set Sort to Oldest there, go back to Group drops → Sort reads Newest again.
Open each dropdown and press Escape → the window and the open menu both close. Drag by the title
bar and resize from the corner, `/reload` → the same place and size. In a party, `Scan group` →
the chat line `Inspecting <n> group members, one at a time.`, and within a minute the footer reads
`Inspect <n>/<n> fresh`. Result:

**FEED-9. Minimize and auto-open.** With the window open, the minimize mark → the window shrinks
to its title bar where it stood, the mark becomes a plus; `/reload` → it comes back minimized. In a
Heroic dungeon with the window minimized, let a member loot an upgrade for you → a `1 new` chip
appears beside the title; a double-click on the title bar expands it and the chip goes. Then close
the window, leave and enter another dungeon (or zone out and back), and let the first upgrade for
you drop → the window opens by itself once; close it and the next upgrade leaves it closed. In the
open world solo nothing opens it. Result:

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
game's own trade rules. They run once the feed (DW-27, DW-31) shows trade chips and Settings › Trade
(DW-40) lists the rules. Read each chip's tooltip, and the `TRADE` debug lines with `/dw debug on`.
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
the warning, wait until ten minutes are left (or, once DW-40 adds the row, `/dw set trade.warnAt
7200` and loot the item) → one chat line `[item]: 10 min left to trade it.` (or the minutes left),
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
and test-mode routing too (`test_asks`); these checks confirm the client's side. The row buttons
arrive with DW-33 (ASK-5..7) and auto-ask with DW-54 (ASK-8); until then each check drives the edge
from the chat box, with a drop already in the feed (`/dw diagnostics` names the drops; `/dw debug on`
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

## Situations

The classifier's truth table is headless-tested (`test_situations`); these checks confirm that the
real client's answers land in the right row. Each reads the `situation` lines of `/dw diagnostics`,
with `/dw debug on` for the `[SIT]` change lines. The settings, the window footer and the
`/dw situation` verb land with DW-41, DW-30 and DW-42, and their checks join these then.

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
They run once the feed (DW-27, DW-31) and the Feed › Quality settings (DW-40) land.

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
`/dump LOOT_ITEM, LOOT_ITEM_SELF, LOOT_ITEM_MULTIPLE` and the line as chat shows it). Result:

## Pending sign-off

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-1..3, SLASH-1..3, PANEL-1..3, PROFILE-1..2, STATE-1..2, COMBAT-3, DIAG-1..2, DEGRADED-1 | DW-02, the scaffold | No client pass recorded yet |
| COMPAT-1..3 | DW-20, the compat seam | No client pass recorded yet |
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
