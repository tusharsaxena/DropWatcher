# Drop Watcher: the Rolls panel (design)

Date: 2026-11-15. Part of the rolls UX round (branch `feat/2026-11-14-rolls-ux`). Mockup signed off by the owner:
https://claude.ai/artifact/72o22p9d8Q8wnqEdbKMcyF (sections 1–6). One codebase: Retail 12.1.5 and WoW Forever 1.60.1.

## 1. Intent

While loot is being rolled, and for a short time after, show a small companion window docked to the Drop Watcher
window that lists every watched item being rolled and every player's roll on it. It must read well in a 5-player
dungeon and in a 40-player raid.

## 2. Owner rulings (2026-11-15, all as recommended in the mockup)

1. **Items:** watched items only, the same set as Rolling now (the feed's filters, with the catch-all for the rest).
2. **Raid layout:** one item open, the others as one-line headers.
3. **Raid mode** starts in any group of more than 5 members.
4. **Linger** after a roll ends is a setting: 0–60 s, default 10.
5. The window's own **Rolling now rows stay** as they are.
6. The panel is **read-only** (no Ask, Offer or other actions).

## 3. Behaviour

### 3.1 Placement
- A separate owned frame, docked to the main window: panel TOPLEFT to window TOPRIGHT with a 3 px gap (side Right),
  or panel TOPRIGHT to window TOPLEFT (side Left). If the chosen side would leave the screen, use the other side.
  Re-check on show, window move/drag stop, resize stop and scale change.
- Same skin as the window (panel, edge, title bar tokens); title "Rolls" (dungeon) or "Rolls · N" (raid, N items).
  Own close button: hides the panel until the next roll starts.
- Width 250 (full layout) or 220 (compact layout), in the window's layout unit (scales with its font). Height follows
  content up to the window's height; beyond that the body scrolls.
- Hidden whenever the window is closed or minimized; it returns with the window if it still has items. The panel
  never opens the window itself (RX-16's roll auto-open does that).

### 3.2 Content
- One block per watched roll, in the order the rolls started. Header: item icon, name in quality color (cut with
  "…"), time left (RollCells time-left rules, RX-02) or "done". A thin countdown bar under an open block's header.
- Rows per player, grouped Need → Greed (Transmog counts as Greed) → Disenchant (Retail only, clients-§4) → Pass →
  still to roll (hourglass, RX-13); highest roll first within a group. Choice icon, class-colored name
  (`UnitCharacterName`, client-quirks-§5; a secret or unreadable name degrades to "?" and is never keyed or printed),
  roll number. `[YOU]` gold on yours. Reuse RollCells' grouping and icons (RC.GROUPS, RC.Tooltip's ordering).
- Foot of a block: your verdict (gear: the verdict text; non-gear: the kind word, neutral).
- On resolution: the winner's row is highlighted gold; a result line "Won by <name> (<choice> <roll>)" or "Everyone
  passed"; the block stays for the linger time, then is removed. In raid mode a resolved block collapses to a dimmed
  header showing the winner and roll.

### 3.3 Raid mode (group > 5 members)
- Exactly one block open; the rest are headers (icon, name, count line, time left).
- Which block opens: the one you still have to roll on (your choice pending), else the one ending soonest. A header
  the player clicks opens and stays open until its roll resolves (then the rule picks again).
- Need and Greed list every player. Pass and Waiting fold to one line each ("Pass 27 · first names…") when the setting
  `foldInRaid` is on; hovering the line shows all names in a tooltip; clicking it unfolds that group for that block.
- Rows come from a pool (no per-refresh frame creation); a 40-player roll must stay within the perf ceilings.

### 3.4 Lifecycle
- Shows when the first watched roll starts (Pending `open` for a roll item) while the window is shown and the setting
  is on. Each new watched roll adds a block. A block is removed `linger` seconds after its roll resolves (0 = at once).
- While the pointer is over the panel nothing is removed or hidden; the linger count restarts when the pointer leaves.
- When the last block is gone the panel hides. WindowAutoClose treats a panel with blocks as not idle (the window
  does not auto-close while the panel lingers).
- `/dw rolls` toggles the panel by hand (shows it even with no rolls, as an empty "No rolls right now" state); a manual
  show stays until closed.

### 3.5 Settings (Drops › Rolls, new "Rolls panel" group)
- `rolls.panel = { enabled = true, side = "right", linger = 10, foldInRaid = true }` on both clients.
- Rows: Show the Rolls panel beside the window (toggle); Side (Right/Left dropdown, tooltip: flips if there is no
  room); Keep a finished roll for (slider 0–60 s); Fold Pass and Waiting in a raid (toggle). Sub-rows disabled when
  the panel is off. Location strings per options-ui-§21.

### 3.6 Test and simulation
- Test mode fills the panel from its pending samples. `/dw sim roll` adds a dungeon roll; a new `/dw sim raid` starts a
  40-player simulated roll (several items) to show raid mode.

## 4. Non-goals
- No change to Blizzard frames; nothing hooked on them for this panel (data comes from Pending / the loot history).
- No actions in the panel; no change to the Rolling now rows.
- No new LibKa0s surface; no version bump.

## 5. Constraints
- Ka0s WoW Addon Standard (deviations STOP and are flagged). Both kit profiles 0 failed, luacheck 0/0, kit complexity
  suite 0 warnings, perf ceilings unchanged, docs/test-cases.md and the README badge in step. CRLF, US spelling.
- Window.lua is at ~1090 lines: the panel lives in its own module(s) (e.g. `modules/RollsPanel.lua`,
  `modules/RollsPanelRows.lua`), registered in the TOC and docs/module-map.md.
