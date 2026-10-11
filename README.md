# Ka0s Drop Watcher

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1307%2F1307_passing-green)

When a ring drops for somebody else in your group, Drop Watcher tells you whether it beats yours,
whether it beats theirs, and whether they could hand it over at all. If you want it, one click
sends a polite whisper asking for it.

It watches what your party or raid receives and compares each item with your gear and with the
looter's. Your own tradeable drops get a list of their own, with the time left to trade each one and
the people it would help. Out of the box it stays in its window. Alerts and sounds are opt-in, and
nobody gets a whisper unless you click Ask or turn on auto-ask.

## Usage

Type `/dw show`, or right-click the minimap button and pick **Show window**. Drag the window by its
title bar, resize it from the bottom-right corner, and lock it in place with `/dw lock` or the
**Lock frame** box once you're happy with it. Escape or the close mark puts it away. The minimize
mark folds it down to the title bar, which then counts the drops you missed; double-click
the bar to open it again. In a dungeon, a key or a raid it opens by itself whenever someone loots
an item it shows, yours included, even after you close it. A minimized window stays minimized and
counts the drop instead. Turn this off under General › When to show, for every situation or one at
a time.

The window has three tabs: **Group drops**, **My drops** and **History**. Each keeps its own filters
in the bar under the tabs. The footer tells you how much of the group's gear has been read, when the
last loot line came in, where the addon thinks you are, and whether Pawn is loaded. **Scan group**
reads everyone's gear before the loot starts, which saves waiting later. When a boss fight or a key
blocks addon chat, an orange lock in the title bar says so and counts the asks waiting to go out.

**Group drops** shows every drop, grouped under the boss or key run it came from. Each group's
header says where it dropped, the instance, the boss and the difficulty the game names
(`Gate of the Setting Sun · Commander Ri'mok · Timewalking`, or `Mythic+ 12` for a key), then how
long ago, then counts its drops: `2 drops · 1 shown` means the filters hide one (a group whose every
drop the View hides still shows its header, `· 0 shown`), and it ends with the character that saw
it, in class color. Hovering the header names the party on one `Group:` line and lists what the
filters hid and why. My drops uses the same headers, and History keeps the place, the character and
the party with each group. A row gives the item, its item level and slot, who looted it, what you wear there (**My eq**) and what they wear
there (**Their eq**), each as icons with item levels, then two verdicts: **Me** (is
it an upgrade for you?) and **Them** (is it one for the looter?). ▲ means upgrade, ≈ sidegrade, ▽
downgrade. **Trade** reads Yes, Likely, Unknown or No. Hover any cell to see why; hover Their eq for
how old the read of the looter's gear is. The **View** dropdown starts on All; pick **Interesting**,
**Likely tradeable**, **Usable by me** or **Upgrade for me** to narrow it, several at once if you
like (a drop must pass each), and All again to clear them. Shift-click the
icon to link the item, ctrl-click to try it on. **Ask** whispers the looter once; mid-fight the
whisper waits and goes out when the fight ends, and a second click cancels it. Click the row itself
and a detail card opens under it with the full reasoning: what the item would replace for you and
for the looter, the stat and track changes, Pawn's score, and the trade rule behind the estimate.
From there you can edit the message before it goes, inspect the looter again, or open a trade.

Your own loot goes on **My drops**. Each item shows the time left to trade it (exact once it's in your
bags, bold with ten minutes to go) and the group members it would help most. If it's an upgrade for
you, it asks **keep?** and nobody sees it offered until you decide. **Offer** opens a panel that
ranks everyone by how much they'd gain, with an **Offer** whisper and a **Trade** button that opens
the trade with the item already in it. **Post my tradeables** lists all of them in group chat in one
line. The tab's label, `My drops · 2`, counts the drops it lists, and a Group drops header's `· 1
yours on My drops` counts the same way, so a drop you hid or filtered out leaves both. Hover the
tab to see which of yours it leaves out, and why.

The **History** tab remembers what the feed showed, across logouts and across your characters, for
30 days by default: Settings › Window › Layout › **Keep history for** takes 7 to 180 days, or Never
delete, and asks before a shorter time deletes anything. Its footer says how many bosses or key runs
and drops it holds, and for how long. Each drop says what became of it: asked, offered, expired, received
or traded away, the last two once a trade with that item goes through. Right-click a row to mark it
declined. The **Character** dropdown in the bar starts on **Current**, the character you're playing;
on History it lists every character that saw a drop, with its class icon, so pick another, several,
or **All** (the only choice that shows drops kept before Drop Watcher noted who saw them).

Two extras are off until you turn them on. The **toast** (Settings › Window › Toast) pops up when
someone else loots a big upgrade for you, 10 item levels or more, that they can probably trade. It
has an Ask button, goes away after 8 seconds unless your pointer is on it, and keeps out of combat
unless you let it. **Auto-ask** (Settings › Messages › Auto-ask) whispers the looter for you, 10
seconds after the boss dies, when a likely tradeable drop is at least 5 item levels better than
yours. It backs off if you ask first, they leave, you hide the row or the item reaches you.

To see all this without waiting for loot, type `/dw test`. Test mode fills the window with sample
drops of real items from this season's dungeons (your own gear if the Encounter Journal has none),
looted by made-up players, in every state the window can show. The History tab gets sample groups
of its own, one of them seen by a made-up alt, which never touch your real history. Test mode shows the toast so you can drag it
into place, and prints messages instead of sending them. Combat ends it.

To try the whole thing with a group that isn't there, simulate one. Out of a group, outside any
instance and out of combat, type `/dw sim start key` (or `dungeon`, `raid`, `lfr`, `delve` or
`world`, with an optional group size). The simulator makes up a group with real gear from the
Encounter Journal, then `/dw sim run` plays a session: pulls, the boss-fight chat lockdown, kills
and loot. `/dw sim step` plays one event at a time, and `pull`, `kill`, `loot`, `lockdown on|off`
and `trade <drop>` fire single events. The addon's own engine reads all of it, so the verdicts,
trade estimates, inspects and asks you see are the real ones. Cyan **SIMULATION** text sits beside the
title while it runs. Nothing is sent (every message is printed with `[sim]`), nobody is inspected or
traded with, and your saved history is left alone. `/dw sim stop` ends it, and joining a group or
entering an instance stops it too. `/dw sim` alone prints where it stands and the verbs, and opens
the simulation panel: each step of the session as a row you can click (a click ahead runs every step
in between), Run all, Pause, Resume, Restart and Stop, and a scenario choice when none runs.
`/dw sim panel` shows or hides it.

Everything else lives under **Settings → AddOns → Ka0s Drop Watcher**, and `/dw help` (or
`/dropwatcher help`) lists every command.

## How the loot watching works

- Drop Watcher reads your group's loot lines as they come in, along with the boss-loot and
  loot-history events, and merges the reports of one item into one drop.
- Drops you don't care about stop there. Where you are (dungeons, keys and raids are watched by
  default), the minimum quality and the filters decide that before anyone is inspected.
- Each drop is compared with what you wear in that slot, and with what the looter wears once their
  gear has been inspected. Inspects go one at a time and never in combat.
- The trade estimate looks at the bind type, the two-hour trade window and the game's rule that a
  looter can only trade an item that isn't an upgrade for them by item level.
- Your own drops get an exact countdown read from the item's tooltip, and a list of who in the group
  would gain from them.
- An ask is one whisper per item. While Blizzard's encounter restrictions block addon chat, it waits
  in a queue and goes out when they lift.

## FAQ

| Question | Answer |
|---|---|
| Does it whisper people on its own? | Only if you turn on auto-ask (Settings › Messages › Auto-ask). Otherwise every whisper is a click. |
| Does it need Pawn? | No. With Pawn installed, its scale scores each drop next to the item level. Without it you can enter your own stat weights, paste a Pawn scale string in Settings › Comparison, or go by item level alone. |
| Does it work in raids? | Yes. Dungeons, keys and raids are watched out of the box. Delves, scenarios and the open world are off until you turn them on under General › When to show. |
| Can it tell me whether I have the look? | Yes, the detail card says `New look` or `Look known`. CanIMogIt is used when it is installed. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The window does not open | Check **General visibility** is not set to Never, and that the addon is enabled (`/dw enable`). |
| The window will not move | It is locked. Untick **Lock frame** or type `/dw unlock`. |
| Test mode turned itself off | Combat ends test mode. Turn it back on after the fight. |
| A simulation will not start | It refuses in a group, inside an instance, in combat and while test mode is on, and says which. Leave the group or instance, or wait out the fight. |
| The Them column shows `?` | The looter's gear hasn't been read yet. Wait a moment, press **Scan group**, or use **Retry inspect** on the detail card. |
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
| 0.1.0 | Unreleased | - The window with its Group drops, My drops and History tabs, the detail card and the Offer panel<br>- One-click asks, offers and announces, queued while encounter restrictions block chat<br>- Trade estimates and an exact trade countdown on your own drops<br>- Pawn scores, or your own stat weights<br>- The opt-in toast and auto-ask<br>- Settings pages, the minimap button, the `/dw` command and test mode |
