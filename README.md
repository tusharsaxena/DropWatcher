# Ka0s Drop Watcher

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1748054)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1844%2F1844_passing-green)

When a piece of loot drops for somebody in your group, Drop Watcher tells you whether it beats yours, whether it beats theirs, and whether they could hand it over at all. If you want it, one click sends a polite whisper asking for it.

It watches what your party or raid receives and compares each item with your gear and with the looter's. Your own drops are listed with everyone else's, with the time left to trade each one and the people it would help. Out of the box it stays in its window, apart from a small popup when someone loots a big upgrade you could ask for. Sounds are opt-in, and nobody gets a whisper unless you click Ask or turn on auto-ask.

## Screenshots

**_Drops (compact view)_**

![Drops (compact view)](https://media.forgecdn.net/attachments/2103/61/dropwatcher-screenshot-01-png.png)

**_Drop details (compact view)_**

![Drop details (compact view)](https://media.forgecdn.net/attachments/2103/62/dropwatcher-screenshot-02-png.png)

**_History (compact view)_**

![History (compact view)](https://media.forgecdn.net/attachments/2103/63/dropwatcher-screenshot-03-png.png)

**_Drops (full view)_**

![Drops (full view)](https://media.forgecdn.net/attachments/2103/64/dropwatcher-screenshot-04-png.png)

**_Drop details (full view)_**

![Drop details (full view)](https://media.forgecdn.net/attachments/2103/65/dropwatcher-screenshot-05-png.png)

**_History (full view)_**

![History (full view)](https://media.forgecdn.net/attachments/2103/70/dropwatcher-screenshot-06-png.png)

**_Offer window_**

![Offer window](https://media.forgecdn.net/attachments/2103/67/dropwatcher-screenshot-07-png.png)

**_Toast_**

![Toast](https://media.forgecdn.net/attachments/2103/68/dropwatcher-screenshot-08-png.png)

## Usage

Type `/dw show`, or right-click the minimap button. You often won't need to: in a dungeon, key or raid the window opens by itself when someone loots something it shows. During a run it's a narrow column of cards (the compact view), and afterwards it goes back to the full table. The button next to minimize switches between them, as do `/dw compact` and `/dw full`. Bind a key under Options → Keybindings → Ka0s Drop Watcher if you like, and `/dw lock` pins the window in place.

**Drops** lists every drop, yours included, under the boss or key it came from.

- Me and Them tell you whether it's an upgrade for you and for the looter: green ▲ up, yellow ≈ about the same, red ▼ down, with the item-level difference. Rings, trinkets and one-handers get a mark for each item you wear, so `321 ▼10 / 324 ▼23` means 10 levels under one ring and 23 under the other. If your spec can't use it but another of yours can, Me says so in cyan: `▲20 Holy`.
- Trade is Yes, No or ?, plus a short reason like `No Bonus roll` or `Yes Not their upgrade`. Trade window is how long they have left.
- **Ask** whispers the looter, once. In a boss fight it waits until the fight ends.

Upgrades you could actually get glow, yellow for your spec and blue for an off-spec. Click a row for the full reasoning, or hover any cell to see what it's based on.

Your own drops get **Offer** instead. It ranks the group by how much each person would gain, and you can whisper one of them or **Announce to group**. While you have something tradeable the strip at the bottom counts it, and **Post my tradeables** lists it all in group chat. **Scan group** sits there too: use it before the loot starts and you won't be waiting on inspects later.

**History** keeps 30 days of drops across logouts and alts, along with what became of each. Right-click a row to mark it declined. Retention and Clear history are in Settings › Window › Layout.

When someone loots a big upgrade you could ask for, a toast pops up. It's on by default, and Settings › Alerts › Toast turns it off or resizes it. Auto-ask is the other way round: off until you turn it on. Then it sends the whisper for you after the boss dies, main-spec asks first.

The look is yours to pick: Settings → General → Skin offers nine skins (or EllesmereUI's, when it's installed), and a small picker offers them the first time you log in.

`/dw test` fills the window with sample drops if you want a look around first. `/dw sim start key` goes further and plays a made-up group through a whole key, sending nothing. Everything else is in **Settings → AddOns → Ka0s Drop Watcher**, and `/dw help` lists the commands.

## How the loot watching works

- Drop Watcher reads your group's loot lines as they come in, along with the boss-loot and loot-history events, and merges the reports of one item into one drop.
- Drops you don't care about stop there. Where you are (keys, dungeons, follower dungeons, raids, delves, scenarios and solo play are watched by default), the minimum quality and the filters decide that before anyone is inspected.
- Each drop is compared with what you wear in that slot, and with what the looter wears once their gear has been inspected. Inspects go one at a time and never in combat.
- The trade estimate looks at the bind type, the four-hour trade window and the game's rule that a looter can only trade an item that isn't an upgrade for them by item level.
- Your own drops get an exact countdown read from the item's tooltip, and a list of who in the group would gain from them.
- An ask is one whisper per item. While Blizzard's encounter restrictions block addon chat, it waits in a queue and goes out when they lift.

## FAQ

| Question | Answer |
|---|---|
| Does it whisper people on its own? | Only if you turn on auto-ask (Settings › Messages › Auto-ask). Otherwise every whisper is a click. |
| Does it look at my other specs? | Yes, when your current spec can't use a drop. It compares the drop with the best item you own for each of your other specs, worn or in your bags, by item level only. For other players it can only see what they have on. |
| Does it need Pawn? | No. With Pawn installed, its scale scores each drop next to the item level, with Pawn's own default settings and no setup. Without it you can enter your own stat weights, paste a Pawn scale string in Settings › Comparison, or go by item level alone. |
| Does it work in raids? | Yes. Dungeons, keys and raids are watched out of the box. Delves, scenarios and the open world are off until you turn them on under Settings › Drops › Situations. |
| Can I change or turn off the glow on upgrades? | Yes, under Settings › Alerts › Upgrade glow. The main-spec and off-spec glows each have their own switch, style (rotating rays, a proc flash, a pixel border or sparkles), color (or your class color) and animation settings. |
| Can the item icons have a border? | Yes, they have a thin black one by default. Under Settings › Window › Icons you can turn Show border off, or pick its texture, thickness and color (or your class color), or tick Color by item quality to draw each border in its item's quality color. Icon zoom on the same tab crops the dark edge most item icons have. Both apply to every item icon, from the table to the toast. |
| Can it tell me whether I have the look? | Yes, the detail card says `New look` or `Look known`. CanIMogIt is used when it is installed. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The window does not open | Check **General visibility** is not set to Never, and that the addon is enabled (`/dw enable`). |
| The window will not move | It is locked. Untick **Lock frame** or type `/dw unlock`. |
| Test mode turned itself off | Combat ends test mode. Turn it back on after the fight. |
| A simulation will not start | It refuses in a group, inside an instance, in combat and while test mode is on, and says which. Leave the group or instance, or wait out the fight. |
| The window opens small in a key or raid | That's the compact view for runs. Click the button next to minimize for the full window, or untick **Compact view when it auto-opens in a run** under Settings › Window › Layout. |
| The Them column shows `?` | The looter's gear hasn't been read yet. Wait a moment, press **Scan group**, or use **Retry inspect** on the detail card. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/dw debug on` and reproduce the bug.
- Type `/dw diagnostics`.
- If the debug window isn't open, open it with `/dw debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Please raise them on GitHub:
<https://github.com/tusharsaxena/DropWatcher/issues>

## Version History

| Version | Date | Highlights |
|---|---|---|
| 1.1.0 | 2026-10-25 | - An upgrade you could actually get now glows on its icon, and Settings › Window › Icons sets every item icon's zoom and border<br>- Rings, trinkets and one-handers get a mark for each item you wear, and Trade says Yes, No or ? with a short reason<br>- Pawn works with no setup, and the toast is on for a new profile, with a size you can set<br>- The compact view is narrower, with Trade above You and Them on every card<br>- The settings pages are regrouped, you can bind a key to show the window, and a started simulation plays through on its own |
| 1.0.0 | 2026-10-17 | - First release: the window's Drops and History tabs, with Me and Them verdicts, the trade estimate and a trade countdown on each drop<br>- Ask, Offer and Announce each send with one click, and wait while encounter restrictions block chat<br>- History keeps 30 days of drops across logouts and alts, and the Drops tab comes back after a `/reload`<br>- Pawn scores or your own stat weights, plus the opt-in toast and auto-ask<br>- The compact view for runs, the settings pages, the minimap button, `/dw test` and `/dw sim` |

## Credits

The window's icons, and the skin picker's preview and settings buttons, are drawn from [Open Iconic](https://github.com/iconic/open-iconic) by Waybury (MIT). Only the icons the addon draws are shipped. The icons are bundled inside the LibKa0s payload, with their license text beside them.
