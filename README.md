# Ka0s Drop Watcher

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1397%2F1397_passing-green)

When a ring drops for somebody else in your group, Drop Watcher tells you whether it beats yours,
whether it beats theirs, and whether they could hand it over at all. If you want it, one click
sends a polite whisper asking for it.

It watches what your party or raid receives and compares each item with your gear and with the
looter's. Your own drops are listed with everyone else's, with the time left to trade each one and
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

The window has two tabs: **Drops** and **History**. Each keeps its own filters
in the bar under the tabs. The footer tells you how much of the group's gear has been read, when the
last loot line came in, where the addon thinks you are, and whether Pawn is loaded. **Scan group**,
on the strip at the bottom of Drops, reads everyone's gear before the loot starts, which saves
waiting later. When a boss fight or a key
blocks addon chat, an orange lock in the title bar says so and counts the asks waiting to go out.

**Drops** shows every drop, yours included, grouped under the boss or key run it came from. Each
group's header says where it dropped, the instance, the boss and the difficulty the game names
(`Gate of the Setting Sun · Commander Ri'mok · Timewalking`, or `Mythic+ 12` for a key), then how
long ago, then counts its drops: `2 drops · 1 shown` means the filters hide one (a group whose every
drop the View hides still shows its header, `· 0 shown`), and it ends with the character that saw
it, in class color. Hovering the header names the party on one `Group:` line and lists what the
filters hid and why. History keeps the place, the character and the party with each group. Each drop
sits a little in from its header, with a small arrow at its left: it points down while the row is
closed and up while its detail card is open. A row gives the item, its item level, its slot and its
type (Cloth, Leather, Mail, Plate, Jewelry, Trinkets, Cloak or Weapons) and who looted it, with a
gold `[YOU]` after your own name. Then
come **Me** (is it an upgrade for you?) and **Them** (is it one for the looter?). Each shows what
that person wears in the slot, as icons with item levels (`321/308` for two rings, trinkets or
one-hand weapons, `empty` when nothing is worn there), then the verdict and by how many item levels:
▲6 means upgrade (green), ≈1 sidegrade (yellow), ▽8 downgrade (red), the same in both columns. Can't
use and Not wanted stay words. **Trade** reads
Yes, Likely, Unknown or a red No. **Trade window** counts down the time left to trade it over a thin bar,
which turns amber and bold in the last ten minutes. For someone else's drop it's an estimate from
when it dropped (`~1:42:10`); a bind-on-equip item says `No limit (BoE)`, and an item that can't be
traded says why. Hover any cell to see why; hover Me or Them for a small table of the gear in that
slot (who wears it, its item level, the item and the arrow with the difference), how old the read
of it is, then the verdict's reasons. The **View** dropdown starts on All; pick **Interesting**, **Likely tradeable**, **Usable by
me** or **Upgrade for me** to narrow it, several at once if you like (a drop must pass each), and
All again to clear them. Shift-click the icon to link the item, ctrl-click to try it on. **Ask**
whispers the looter once; mid-fight the whisper waits and goes out when the fight ends, and a second
click cancels it. The button is red while the move is yours (Ask, Retry), yellow while it waits on
someone else (Asked, Queued) and green once the item is traded. Click the row itself and a detail
card opens under it with the full reasoning: what the item would replace for you and for the looter,
the stat and track changes, Pawn's score, and the trade rule behind the estimate. From there you can
edit the message before it goes, inspect the looter again, or open a trade.

Your own loot is on **Drops** too, with a few differences. Its trade countdown is exact once the
item is in your bags. **Them** reads `Upgrade for 2`, the group members it would be an upgrade for (`No upgrades` when
there are none): hover it for a row per member, biggest gain first, each name in class color with
the item level and item they wear there and how much they'd gain. If it's an upgrade for you,
nobody sees it offered until you decide: it reads `Hidden` until you open its Offer panel.
**Offer**, in place of Ask, opens that panel, which ranks everyone by how much they'd gain. Its
**Their eq** column reads like the Them column (what they wear, its item level, then the arrow and
the difference), and each member gets an **Offer** whisper; **Announce to group** tells everyone at
once. Every action button carries an icon for what it does. The row's Offer is cyan until you've offered it, so it reads apart from
Ask, yellow once you have and green once you've given it away. While any of your listed drops can still be traded, a strip under the
table counts them and gives the next one to run out (`2 tradeable · next expiry 0:08:41`), and
**Post my tradeables**, right above the Sort dropdown, lists all of them in group chat in one line.

The **History** tab remembers what the feed showed, across logouts and across your characters, for
30 days by default: Settings › Window › Layout › **Keep history for** takes 7 to 180 days, or Never
delete, and asks before a shorter time deletes anything. Its footer says how many bosses or key runs
and drops it holds, and for how long. Each drop says what became of it: asked, offered, expired,
received or traded away, the last two once a trade with that item goes through. Right-click a row to
mark it declined. The **Character** dropdown in the bar starts on **Current**, the character you're
playing; on History it lists every character that saw a drop, with its class icon, so pick another,
several, or **All** (the only choice that shows drops kept before Drop Watcher noted who saw them).

There is also a compact view: a narrow window, 440 pixels wide, where each drop is a small card of
three lines instead of a table row. The top line has the item, its level and Ask (Offer on your
own). The middle one says who looted it, the slot, the type and whether they can trade it, with the
trade countdown and its bar on the right, and the bottom one reads like the table's Me and Them
without the icons: `You 321/308 ▽8` and `Them 276 ▲12` (`Them Upgrade for 2` on your own). History cards show what became of the drop, and the strip under
the Drops cards is shorter (`2 tradeable · next 0:08:41` and **Post**). Quality, Content, Character
and Sort fold into a **Filters** button beside View, and Scan group is the icon in the title bar. Hovering still explains everything, and
clicking a Drops card opens the same detail card. The button next to minimize switches views, as do
`/dw compact` and `/dw full`, and each view remembers its own size and place. When a drop opens the
window by itself in a dungeon, key, raid or delve, it opens compact, then goes back to your usual
view the next time it opens after the run. If you'd rather keep the full window in runs too, untick
**Open in compact view during a run** under Settings › Window › Layout, where **Layout** picks the
view you normally get.

Two extras are off until you turn them on. The **toast** (Settings › Window › Toast) pops up when
someone else loots a big upgrade for you, 10 item levels or more, that they can probably trade.
Beside the item's icon it names the item in its quality color with its item level, the looter in
their class color, how the drop compares for you and for them (`You ▲19 · Them ▽13`), and why they
can likely trade it. It has an Ask button, goes away after 8 seconds unless your pointer is on it (a
right-click closes it), and keeps out of combat unless you let it. **Auto-ask** (Settings › Messages › Auto-ask) whispers the looter for you, 10
seconds after the boss dies, when a likely tradeable drop is at least 5 item levels better than
yours. It backs off if you ask first, they leave or the item reaches you.

To see all this without waiting for loot, type `/dw test`. Test mode fills the window with sample
drops of real items from this season's dungeons (your own gear if the Encounter Journal has none),
looted by made-up players, in every state the window can show. The History tab gets sample groups of
its own, one of them seen by a made-up alt, which never touch your real history. Test mode shows the
toast so you can drag it into place, and prints messages instead of sending them. Combat ends it.

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
| The window opens small in a key or raid | That's the compact view for runs. Click the button next to minimize for the full window, or untick **Open in compact view during a run** under Settings › Window › Layout. |
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
| 0.1.0 | Unreleased | - The window with its Drops and History tabs, the detail card and the Offer panel<br>- One-click asks, offers and announces, queued while encounter restrictions block chat<br>- Trade estimates and a trade countdown on every drop, exact on your own<br>- Pawn scores, or your own stat weights<br>- The opt-in toast and auto-ask<br>- A compact view of the same window, which it opens in during a run<br>- Settings pages, the minimap button, the `/dw` command and test mode |
