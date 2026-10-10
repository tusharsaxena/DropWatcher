# Ka0s Drop Watcher

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-566%2F566_passing-green)

When a ring drops for somebody else in your group, Drop Watcher tells you whether it beats yours,
whether it beats theirs, and whether they could hand it over at all. If you want it, one click
sends a polite whisper asking for it.

It watches what your party or raid receives and compares each item with your gear and with the
looter's. Your own tradeable drops get a list of their own, with the time left to trade each one and
the people it would help. Out of the box it stays in its window. Alerts and sounds are opt-in, and
nothing is whispered unless you click.

**This is an early build.** Version 0.1.0 is the frame of the addon: the window, the settings, the
minimap button, the slash command and the test mode. The loot feed, the comparisons and the asking
arrive in the releases that follow, and this page will grow with them.

## Usage

Type `/dw show`, or right-click the minimap button and pick **Show window**, to open the window. Drag
it by its title bar and resize it from the bottom-right corner. Once it sits where you like, lock it
with `/dw lock` or the **Lock frame** box in the settings, and it stops
moving. Escape or the close mark puts it away.

Test mode fills the window with placeholder content so you can see it and place it before a real
drop arrives. `/dw test` turns it on and off, and so does the **Test mode** box. Entering combat ends
it, since you have better things to look at then.

The **General visibility** setting decides when the window may show at all: always, only in combat,
only out of combat, or never. Master scale and Master alpha size and fade it.

Everything is configured under **Settings → AddOns → Ka0s Drop Watcher**, and `/dw help` (or
`/dropwatcher help`) prints the full command list.

## How the loot watching works

The design, in the order the pieces are being built:

- Loot lines from your group are read as they arrive, along with the boss-loot and loot-history
  events, and merged into one entry per item.
- Each drop is compared against what you have in that slot, and against what the looter has once
  their gear has been inspected.
- A trade estimate says whether the item can change hands, and why: bind type, the trade window, and
  whether the item would be an upgrade for the person who got it.
- Your own tradeable drops get a live countdown and a list of group members they would help.
- Asking is one click. While Blizzard's encounter restrictions block chat, the whisper waits in a
  queue and goes out when they lift.

## FAQ

| Question | Answer |
|---|---|
| Does it whisper people on its own? | No. Every whisper is a click, unless you turn on the optional auto-ask once it ships. |
| Does it need Pawn? | No. If Pawn is installed, a later release will use its scores; without it, items are compared by item level. |
| Will it work in raids? | Yes, it is being built for parties and raids alike. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The window does not open | Check **General visibility** is not set to Never, and that the addon is enabled (`/dw enable`). |
| The window will not move | It is locked. Untick **Lock frame** or type `/dw unlock`. |
| Test mode turned itself off | Combat ends test mode. Turn it back on after the fight. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/dw debug on` and reproduce the bug.
- Type `/dw diagnostics`.
- If the debug window isn't open, open it with `/dw debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Bugs and ideas are tracked in the
[GitHub issues](https://github.com/tusharsaxena/DropWatcher/issues). Please file them there rather
than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 0.1.0 | Unreleased | - The window, its settings, the minimap button, the `/dw` command and test mode |
