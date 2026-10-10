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
| FEED-1..7 | Feed | The group drops feed (lands with DW-11, DW-25, DW-27, DW-30, DW-31) |
| INSPECT-1..4 | Inspect | The inspect broker (lands with DW-26) |
| TRADE-1..6 | Trade | Trade estimates and the raid rule (TRADE-1..4, DW-14), timers (TRADE-5, DW-28), the trade helper (TRADE-6, DW-29) |
| ASK-1..8 | Ask | Asking, offering, queueing under restriction, auto-ask (lands with DW-2A, DW-33, DW-54) |
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

**COMBAT-1.** *Reserved — DW-25: is `CHAT_MSG_LOOT` readable mid-encounter (design spec §15)?*

**COMBAT-2.** *Reserved — DW-21: the restriction badge and the queued asks under an encounter.*

**COMBAT-3. Combat ends test mode.** Turn test mode on, pull a training dummy → test mode ends with
the chat line `Test mode ended: you entered combat.`; `/dw test` in combat is refused. With General
visibility `Only in combat`, the open window shows on the pull and hides when combat ends. Result:

## Diagnostics

**DIAG-1. The report.** `/dw diagnostics` → the console opens with both markers naming Ka0s Drop
Watcher and the `identity`, `settings`, `window`, `registration` and `integrations` sections; logging
is on afterwards. `/dw debug diagnostics` writes the same report again below the first. Result:

**DIAG-2. Perf.** `/dw perf` → the step panel opens with its own close mark; run A, B and finish →
the report lists `window.refresh`. Result:

## Degraded

**DEGRADED-1. LibKa0s missing.** Rename `libs\LibKa0s` and `/reload` → no Lua error; one chat line
says the library is missing; `/dw show` opens the window without the skin; `/dw disable` and
`/dw enable` still work; `/dw list` says the settings CLI is unavailable. Restore the folder after.
Result:

## Feed

Checks land with the feed items; reserved here so the IDs the plan and the design name stay stable:
FEED-1 (the parser on real loot, DW-25), FEED-2..4 (the table, DW-31), FEED-5 (`GetItemUpgradeInfo`
on a link that is not yours, DW-23), FEED-6 (`ENCOUNTER_LOOT_RECEIVED` for the M+ chest, DW-27),
FEED-7 (a Devourer Demon Hunter looter before inspect: a warglaive or one-hander reads as usable and
a held off hand as not, matching the item's own spec list; the class data of DW-10, judged by DW-11).

## Inspect

Reserved for DW-26: INSPECT-1..4, including INSPECT-4 (is the tooltip item level still needed?).

## Trade

The estimator's decision is headless-tested (`test_trade_rules`); TRADE-1..4 confirm it against the
game's own trade rules. They run once the feed (DW-27, DW-31) shows trade chips and Settings › Trade
(DW-40) lists the rules. Read each chip's tooltip, and the `TRADE` debug lines with `/dw debug on`.
TRADE-5 (the own-item timer, DW-28) and TRADE-6 (the trade helper, DW-29) land with those items.

**TRADE-1. Binds.** A BoE drop shows `Yes` (BoE) whatever the looter's gear. A warbound or
account-bound drop and a bonus-roll drop show `No` with that reason. A drop in a follower dungeon or
a PvP reward shows `No` (legacy). Result:

**TRADE-2. The looter's item level.** In a dungeon or a key, a BoP drop for an inspected looter
whose equipped item in that slot is at or above the drop's item level shows `Likely` with both item
levels; one above their equipped item shows `No` (an upgrade for them); before the looter is
inspected the chip shows `Unknown` with the inspect state. Confirm one `Likely` by asking for the
item and seeing the trade succeed. More than two hours after the drop, the chip shows `No` (expired).
Result:

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

## Ask

The messaging core's decisions (token expansion, the length limit, the one-ask guard, the queue's
order and cancel) are headless-tested (`test_messaging`); nothing sends until the edge lands.
Reserved for DW-2A, DW-33 and DW-54: ASK-1..8, including ASK-4 (does a whisper from a click work
during an encounter?).

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
code: nothing yet. `core/Compat.lua` holds the localized readers (the trade-time sentence and its
duration, the `ITEM_LEVEL` and upgrade-level lines), headless-tested in enUS, deDE and ruRU shapes,
but no feature calls them until M2's edge items land. Nothing else reads a localized `_G` string,
parses a tooltip line, keys anything off a display string, or writes a header another tool parses; its own strings are English through `NS.L`, which
answers the key itself on any client. The checks that will carry locale risk arrive with the feed
(design spec §15): the `LOOT_ITEM*` GlobalString patterns, the trade-timer duration decode, and track
names taken from the API rather than parsed. Until then, on a deDE or frFR client: `/reload`, open
the window, run `/dw help` and `/dw diagnostics` → English text throughout, no Lua error, and no
stray `%s` or `%d` in any line. The failure looks like a raw format token in chat or a missing
label. **Signed off without the client** while the enumeration above holds: the headless cases
`test_slash`, `test_window` and `test_diagnostics` cover every line printed today, and the English
client's INSTALL and SLASH checks are sufficient. The section is re-armed by the first parser item
(DW-25), whose check replaces this paragraph's "nothing". Result:

## Pending sign-off

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-1..3, SLASH-1..3, PANEL-1..3, PROFILE-1..2, STATE-1..2, COMBAT-3, DIAG-1..2, DEGRADED-1, LOC-1 | DW-02, the scaffold | No client pass recorded yet |
| COMPAT-1..3 | DW-20, the compat seam | No client pass recorded yet |
