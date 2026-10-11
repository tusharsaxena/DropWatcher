# Ka0s Drop Watcher

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-689%2F689_passing-green)

When a ring drops for somebody else in your group, Drop Watcher tells you whether it beats yours,
whether it beats theirs, and whether they could hand it over at all. If you want it, one click
sends a polite whisper asking for it.

It watches what your party or raid receives and compares each item with your gear and with the
looter's. Your own tradeable drops get a list of their own, with the time left to trade each one and
the people it would help. Out of the box it stays in its window. Alerts and sounds are opt-in, and
nothing is whispered unless you click.

**This is an early build.** Version 0.1.0 is the frame of the addon: the window with its Group
drops table, the settings, the minimap button, the slash command and the test mode. Your own drops,
offering and trading, and the history arrive in the releases that follow, and this page will grow
with them.

## Usage

Type `/dw show`, or right-click the minimap button and pick **Show window**, to open the window. Drag
it by its title bar and resize it from the bottom-right corner. Once it sits where you like, lock it
with `/dw lock` or the **Lock frame** box in the settings, and it stops
moving. Escape or the close mark puts it away, and the minimize mark folds it down to its title bar,
where a counter shows how many interesting drops came in meanwhile. Double-click the bar to open it
back up.

Three tabs sit under the title: **Group drops**, **My drops** (with a count of your drops you can
still trade) and **History**. The filter bar narrows the current tab, and each tab remembers its own
filters. The footer is a quick health check: how many group members' gear has been read, when the
last loot line came in, where the addon thinks you are, and whether Pawn is loaded. **Scan group**
reads everyone's gear ahead of the loot. During a boss fight or a key, an orange lock badge in the
title bar says chat is restricted and how many asks are waiting to go out.

**Group drops** lists every drop, one row each, under a header per boss or key run; click a header
to fold it away. Each row shows the item, its item level and slot, who looted it, what they wear
there, and two verdicts: **Me** (is it an upgrade for you?) and **Them** (is it one for the
looter?), each a signed item-level change with ▲ for an upgrade, ≈ for a sidegrade and ▽ for a
downgrade. **Trade** says Yes, Likely, Unknown or No. Hover any cell for the reason behind it. Hover
the item's icon for its tooltip, shift-click it to link it in chat, ctrl-click it to try it on. The
**Ask** button whispers the looter once; during a boss fight it waits in the queue and goes out when
the fight ends, and clicking it again cancels it. The × beside it hides the row for the session.

Click a row to open its **detail card** right under it, and click it again to close it. The card
spells out the reasoning: the item's slot, armor type, bind, upgrade track, primary stat and any
socket or tertiary stat; side by side, what it would replace **for you** and **for the looter**,
with the item-level, track and stat changes, Pawn's score for you and the looter's spec; and the
trade estimate in a sentence, with the rule behind it and how fresh the data is. Its buttons ask the
looter, let you edit the message before it goes, link the item in chat, inspect the looter again,
open a trade with them (grayed, with the reason, when they are out of range or you are in combat),
and hide the item.

**My drops** lists your own loot: the item, its item level, whether it is an upgrade for you (an
upgrade asks **keep?**, and nobody is offered it unless you choose to), the time left to trade it on
a bar that shortens (read from the item itself once it is in your bags, and bold when ten minutes
are left), and the group members it would help most. **Announce** posts your announce template to
the group. **Offer…** opens the **Who could use this?** panel beside the window: every member
ranked by how much they would gain, with a status pill (`+14 UPGRADE`, `EQUAL`, `NO UPGRADE`,
`CAN'T USE`, `CHECKING…`), an **Offer** button that whispers them your offer template and a
**Trade** button that opens the trade window with the item already placed (grayed, with the reason,
when they are out of range or you are in combat). Under the rows, a line counts your tradeable
drops and the next one to run out, and **Post my tradeables** posts them all in one line to the
group.

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
