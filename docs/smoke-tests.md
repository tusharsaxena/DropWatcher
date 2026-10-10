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
| COMBAT-1..3 | Combat | Loot reads mid-encounter, restrictions, test mode ended by combat |
| DIAG-1..2 | Diagnostics | The debug console, the report, perf |
| DEGRADED-1 | Degraded | The install with LibKa0s missing |
| FEED-1..7 | Feed | The group drops feed (lands with DW-11, DW-25, DW-27, DW-30, DW-31) |
| INSPECT-1..4 | Inspect | The inspect broker (lands with DW-26) |
| TRADE-1..6 | Trade | Trade estimates, the raid rule, timers, the trade helper (lands with DW-14, DW-28, DW-29) |
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

Reserved for DW-14, DW-28 and DW-29: TRADE-1..6, including TRADE-3 (the raid rule, confirmed in game
before release) and TRADE-4 (equipped versus owned for the trade rule).

## Ask

Reserved for DW-2A, DW-33 and DW-54: ASK-1..8, including ASK-4 (does a whisper from a click work
during an encounter?).

## Situations

Reserved for DW-13: SIT-1..5.

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
code: nothing. It reads no localized `_G` string, parses no tooltip line, keys nothing off a display
string, and writes no header another tool parses; its own strings are English through `NS.L`, which
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
