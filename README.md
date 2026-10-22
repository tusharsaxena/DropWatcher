# Ka0s Drop Watcher

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1748054)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1670%2F1670_passing-green)

When a piece of loot drops for somebody in your group, Drop Watcher tells you whether it beats yours, whether it beats theirs, and whether they could hand it over at all. If you want it, one click sends a polite whisper asking for it.

It watches what your party or raid receives and compares each item with your gear and with the looter's. Your own drops are listed with everyone else's, with the time left to trade each one and the people it would help. Out of the box it stays in its window. Alerts and sounds are opt-in, and nobody gets a whisper unless you click Ask or turn on auto-ask.

## Screenshots

**_Drops (compact view)_**

![Drops (compact view)](https://media.forgecdn.net/attachments/2064/342/dropwatcher-screenshot-01-png.png)

**_Drop details (compact view)_**

![Drop details (compact view)](https://media.forgecdn.net/attachments/2064/343/dropwatcher-screenshot-02-png.png)

**_History (compact view)_**

![History (compact view)](https://media.forgecdn.net/attachments/2064/344/dropwatcher-screenshot-03-png.png)

**_Drops (full view)_**

![Drops (full view)](https://media.forgecdn.net/attachments/2064/345/dropwatcher-screenshot-04-png.png)

**_Drop details (full view)_**

![Drop details (full view)](https://media.forgecdn.net/attachments/2064/346/dropwatcher-screenshot-05-png.png)

**_History (full view)_**

![History (full view)](https://media.forgecdn.net/attachments/2064/347/dropwatcher-screenshot-06-png.png)

**_Offer window_**

![Offer window](https://media.forgecdn.net/attachments/2064/348/dropwatcher-screenshot-07-png.png)

**_Toast_**

![Toast](https://media.forgecdn.net/attachments/2064/349/dropwatcher-screenshot-08-png.png)

## Usage

Type `/dw show`, or right-click the minimap button and pick **Show window**. Drag it by the title bar, resize it from the corner and lock it with `/dw lock`. You won't often open it yourself, though: in a dungeon, key or raid it pops up when someone loots an item it shows. During a run it opens as a narrow column of cards, the compact view, and goes back to the full table afterwards. The button next to minimize switches views, as do `/dw compact` and `/dw full`, and each view keeps its own size and place.

**Drops** lists every drop, yours included, under the boss or key run it came from. The two columns that matter are **Me** and **Them**: is this an upgrade for you, and is it one for the person who looted it? Each shows the gear worn in that slot and the item-level difference, green ▲ for an upgrade, yellow ≈ for a sidegrade and red ▼ for a downgrade. Rings, trinkets and one-hand weapons (when you can dual wield) get a mark for each item you wear, so `321 ▼10 / 324 ▼23` means the drop is 10 levels under one ring and 23 under the other; the same goes for the compact cards, the toast and the detail card's Item level. A ring slot always shows both rings, even a unique-equipped ring you already wear: the drop can only replace that copy, so its mark is the verdict, but you still see how it compares with the other one. A one-hander when you can't dual wield shows just your main hand, a two-hander weighed against both hands at once keeps a single mark, and so does a cell too narrow for two at a large font size. If your current spec can't use an item but another spec of your class can, Me tells you how it would do in that spec instead, in cyan with the spec's name: `▲20 Holy` means 20 item levels over the best Holy item you own. An upgrade you could actually get glows too, a yellow pixel border for your current spec and a blue one for an off-spec, in the table, the compact cards and the detail card. One the looter can't trade, or whose trade isn't worked out yet, doesn't glow, and the toast never does since it only shows upgrades. **Trade** says Yes, No or ? and why in a few gray words: `No Bonus roll`, `Yes Not their upgrade`, `? Not inspected`. If none of your specs can use the item it reads `Yes Can't use` in dim red, because there's nothing for you to ask for. **Trade window** counts down how long they have. If you want it, **Ask** whispers them once, and for an off-spec item the whisper says that's what it's for. During a boss fight the whisper waits until the fight ends. Click a row for the full reasoning, or hover any cell for the facts behind it, one per line.

Your own drops show who in the group would gain from them. **Offer** opens a panel that ranks everyone by how much they'd gain (anyone who could only use it in another spec comes after the people who'd use it now), with a whisper button per person and **Announce to group** to tell everyone at once. While any of your drops can still be traded, the strip at the bottom counts them, and **Post my tradeables** lists them in group chat in one line. That strip also has **Scan group**, which reads everyone's gear before the loot starts so you aren't waiting on inspects later, and **Expand all**.

**History** remembers what the feed showed for 30 days, across logouts and alts, and what became of each drop: asked, offered, expired, received, traded away or declined. Click a row for its detail card, or right-click it to mark it declined. How long it keeps things, and the button that clears it, are under Settings › Window › Layout. A `/reload` loses nothing: this session's drops come back on the Drops tab.

Two extras are off until you turn them on: the **toast**, a popup when someone loots a big upgrade you could ask for (Settings › Alerts › Toast sets its size, 50 to 200 %, and it grows or shrinks where you put it), and **auto-ask**, which sends the whisper for you after the boss dies. Both handle off-spec upgrades with their own wording, and your main spec still comes first: auto-ask holds an off-spec whisper until any main-spec one has gone out. To see it all without waiting for loot, `/dw test` fills the window with sample drops in every state. `/dw sim start key` goes further and plays a made-up group through a whole key, sending nothing. Settings › Window › Icons gives every item icon the same look: by default the art is zoomed in a little inside a thin black border, and you can change the zoom and the border's texture, thickness and color, or use your class color or each item's quality color. The rest is under **Settings → AddOns → Ka0s Drop Watcher**, and `/dw help` lists every command.

## How the loot watching works

- Drop Watcher reads your group's loot lines as they come in, along with the boss-loot and loot-history events, and merges the reports of one item into one drop.
- Drops you don't care about stop there. Where you are (dungeons, keys and raids are watched by default), the minimum quality and the filters decide that before anyone is inspected.
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
| Does it work in raids? | Yes. Dungeons, keys and raids are watched out of the box. Delves, scenarios and the open world are off until you turn them on under Settings › Situations. |
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
| The window opens small in a key or raid | That's the compact view for runs. Click the button next to minimize for the full window, or untick **Open in compact view during a run** under Settings › Window › Layout. |
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
| 1.0.0 | 2026-10-17 | - First release: the window's Drops and History tabs, with Me and Them verdicts, the trade estimate and a trade countdown on each drop<br>- Ask, Offer and Announce each send with one click, and wait while encounter restrictions block chat<br>- History keeps 30 days of drops across logouts and alts, and the Drops tab comes back after a `/reload`<br>- Pawn scores or your own stat weights, plus the opt-in toast and auto-ask<br>- The compact view for runs, the settings pages, the minimap button, `/dw test` and `/dw sim` |

## Credits

The debug console uses [JetBrains Mono](https://www.jetbrains.com/lp/mono/), licensed under the SIL Open Font License 1.1, and the window's icons are drawn from [Open Iconic](https://github.com/iconic/open-iconic) by Waybury (MIT).
