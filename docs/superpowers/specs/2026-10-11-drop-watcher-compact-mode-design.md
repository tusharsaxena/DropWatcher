# Ka0s Drop Watcher: compact mode (M12)

- **Owner request (2026-10-11).** The full window is good for detail, but it is annoying when it pops up in the middle
  of a run. The owner wants a compact view of the **same data** at a much smaller width, on all three tabs, that can be
  swapped with the full view from the settings and from the window header. The suggestion is that each table row
  becomes a three-line card. WhoGotLoots' cards are the idea to follow, not a look to copy (the reference screenshot
  is in `research/2026-10-11-compact/01-wgl-reference.png`). The owner delegated the design: build it, and the owner
  will test and iterate.
- **Builds on:** everything merged through M11 and DW-B4, including the headers that name the instance, boss and
  difficulty and show your character, the row-tooltip placement from DW-B2, View All by default, and the Character
  dropdown.
- **Items:** DW-C0..DW-C6, branch `feat/2026-10-11-drop-watcher-compact` (stacked on the M11 branch until that
  merges).

## 1. What compact mode is

- **Two layouts, one window.** `window.mode` is `full` or `compact`. Both layouts read the same feed, filters,
  settings and engine, and only the presentation differs. Switching keeps the active tab, the filters, the scroll
  position (as near as it can) and the expanded detail card.
- **Separate geometry per mode.** Each mode keeps its own size and position (`window.geometry.full`,
  `window.geometry.compact`). Compact defaults to **380 × 460** and is resizable between 320 and 520 wide and 220 and
  900 tall. Its default position is the full window's top-right corner, so it opens where the eye already is.
- **The retired preset.** Compact mode retires M3's *compact preset* (`window.compact`, which hid columns). A
  migration maps `window.compact = true` to `window.mode = "compact"` and removes the old key. `/dw compact` now
  toggles the mode.
- **Swapping.**
  - A **title-bar toggle** sits between Scan group and minimize. Its icon is from the LibKa0s Media catalog; if no
    fitting icon exists, use a text glyph and draft a LibKa0s issue. Its tooltip says "Compact view" or "Full view"
    and names the setting.
  - The **Window settings page** gets a *Layout* choice (Full or Compact), stored in the profile.
  - The **slash verb** is `/dw compact`, and `/dw full` sets it back.
  - The **launcher menu** gets no new entry.
- **The mid-run case** the owner described, as an option:
  - **What it is.** *Open in compact view during a run* (`window.compactInRuns`) **opens the window in compact mode
    whenever an auto-open happens inside a dungeon, raid, key or delve**, whatever the stored mode.
  - **When it lets go.** The override ends when the run ends (`CHALLENGE_MODE_COMPLETED`, or leaving the instance).
    After that the window returns to the stored mode the next time it opens.
  - **Default: on.** It is the behavior the owner asked for. It is easy to turn off, and the README says so.

## 2. The compact card (Group drops)

Each drop is a three-line card, about 50 px tall at the default font (three text lines plus padding). The item icon
spans all three lines.

```
┌──────────────────────────────────────────────────────────────┐
│ [ICON] Vile Vial of Volatile Venom             295  [Ask] [×]│  line 1: item (quality color) · ilvl · action · dismiss
│ [ 36 ] Lysandra · Trinket · Likely             Inspect: 2m   │  line 2: looter (class color) · slot · trade state · freshness
│ [ px ] You ▽ -13  (321/308)    Them ⊘ Can't use  (298/296)   │  line 3: verdict for you (and what you wear) · verdict for them (and what they wear)
└──────────────────────────────────────────────────────────────┘
```

- **Line 1.**
  - **Item and level:** the item link text in its quality color, then the item level, right-aligned.
  - **Ask button:** same states as the full table, with no ellipsis.
  - **Dismiss ×.**
- **Line 2.**
  - **Who and what:** the looter in class color (a ⊕ marks a cross-realm looter; the realm is in the tooltip), then
    the slot.
  - **Trade state:** in its tone. The words are short (Yes, Likely, Unknown, No).
  - **Inspect freshness:** right-aligned and dimmed (`2m`, `cached`, `…`, `range`).
- **Line 3.** Two halves.
  - **You:** the verdict glyph and delta in its tone (`▲ +19`, `≈ +0`, `▽ -13`, `⊘ Can't use`), then your equipped
    level(s) dimmed (`321/308` for two-slot items).
  - **Them:** the same for the looter.
  - **Track:** where the track differs (Champion vs Hero), the tooltip says so. Line 3 stays short.
- **Interaction.**
  - **Tooltips:** every element keeps its full-view reason tooltip, placed by DW-B2's row-tooltip helper at the
    card's top right, just outside the window (or the top left).
  - **Hovering the icon or the item** shows the real game tooltip.
  - **Clicking the card** expands the same detail card the full view uses, inline under the card and resized to the
    compact width. Its two comparisons stack vertically instead of side by side.
- **Group headers.** One line: `Gate of the Setting Sun · Commander Ri'mok · Timewalking · 3m · 2 · Tiamât`.
  - The short form drops "ago" and "drops". The tooltip has the long form, the hidden-drop explanation (DW-A0) and
    the reconciling counts (DW-B0).
  - The header collapses as now. A long instance name is truncated with the full name in the tooltip.

## 3. My drops and History cards

**My drops.** Three lines, with the countdown bar under line 2.

```
│ [ICON] Leggings of the Frenzy                       183  [Offer] │  line 1: item · ilvl · Offer
│        For you ▲ +49 (keep?)          1:44:46 ████████░░░░        │  line 2: verdict for you · trade countdown with bar
│        Seta +14 · Butterz +6                        [Announce]    │  line 3: best candidates (class colors) · Announce
```

- A drop that cannot be traded shows `Not tradeable` on line 2 and `Hide` instead of Announce.
- The summary strip ("n tradeable · next expiry …") and Post my tradeables stay in the footer, shortened.
- The Offer panel docks beside the compact window the way it docks beside the full one. Its width is unchanged, and
  it goes on whichever side has room.

**History.** Three lines.

```
│ [ICON] Yoke of the Charging Bear                    311   Seen │  line 1: item · ilvl · outcome (tone)
│        Bùnian ⊕ · Neck · Likely                         17:02  │  line 2: looter · slot · trade state · time
│        You ▽ -4                    Them ≈ +0                   │  line 3: verdicts
```

## 4. Chrome in compact mode

- **Title bar.**
  - **Title:** `Drop Watcher` (the short name) is centered. TEST MODE and SIMULATION are shortened to `TEST` and `SIM`,
    in the same red and cyan style.
  - **Restriction badge:** collapses to its icon plus the queued count. The tooltip is unchanged.
  - **Scan group:** becomes an icon button.
  - **Mode toggle, minimize and close** sit at the right.
- **Tabs.** The tab strip keeps three tabs at a reduced width: `Group`, `Mine · n` and `History`. The full names are
  in their tooltips.
- **Filter bar.** It is one row.
  - **Shown:** View, then a compact search box. The search box's hint is `Filter…`.
  - **Moved into a Filters button:** Quality, Content and Character move into a **Filters ▾** button. The button opens
    one menu with three submenus built from the same LibKa0s Widgets dropdown code, so the choices and their
    multi-select behavior are identical. The button's label shows a count when any of the three is not at its
    default (`Filters · 2`), and its tooltip lists the active values.
  - **Sort:** it moves into the Filters menu too.
- **Yellow strip.** The test-mode and simulation strip stays, with shorter text that wraps to two lines if needed.
- **Footer.** One line with the two most useful facts: inspect freshness and the situation (`Inspect 4/4 · Mythic+`).
  The rest moves to its tooltip.

## 5. Behavior and quality bars

- **Same engine.** Compact mode **never** changes what is recorded, gated, judged or sent. A test asserts that
  compact and full produce the same drop set for the same feed and filters.
- **Pooled cards.** Cards are pooled (LibKa0s-Pool-1.0) like rows. A repaint is batched the same way. The perf
  scenarios gain a compact refresh pair at the same zero-overhead rule.
- **Font size and height.** Text follows `window.fontSize`, so Default means the template's size, as in DW-A8. Card
  height follows from the text.
- **Test mode and the simulator** must populate compact cards in every state. The end-to-end sim suite runs once in
  each mode.
- **File structure.** New files hold the compact layout:
  - `modules/WindowCompact.lua`: chrome and the mode switch;
  - `modules/CompactCards.lua`: pure layout and text;
  - `modules/CompactGroup.lua`, `modules/CompactMine.lua` and `modules/CompactHistory.lua`: per-tab bodies, or fewer
    files if they are small.
  - No authored file passes 1000 lines, and `Window.lua` and `WindowGroup.lua` do not grow.
- **Taint and combat.** Switching modes in combat is allowed, because the window is not a protected frame. Resizing
  waits for the combat end only if the existing resize does.

## 6. Items

| Id | What |
|---|---|
| DW-C0 | Mode switch core: `window.mode` with per-mode geometry, the migration from `window.compact`, the title-bar toggle, the settings Layout row, `/dw compact` and `/dw full`, and the run-time override (`window.compactInRuns`) |
| DW-C1 | Pure compact layout: `CompactCards`, holding each card's three lines of text, tones and tooltips for all three tabs and the header short form, with exhaustive tests |
| DW-C2 | Compact Group drops: pooled cards, headers, inline detail card (stacked), dismiss and Ask, and DW-B2 tooltip placement |
| DW-C3 | Compact My drops and History: cards, countdown bar, Offer and Announce, outcomes, and Offer panel docking |
| DW-C4 | Compact chrome: title bar, tabs, the single-row filter bar with the Filters ▾ menu, the strip and the footer |
| DW-C5 | Test mode, simulator and perf in compact: every state rendered, the end-to-end sim suite in both modes, compact perf pair, and the same-drop-set test |
| DW-C6 | Docs (README with a compact-mode section, settings-panel, ARCHITECTURE, module-map, schema and migration, smoke-tests COMPACT theme as owed checks) and a fresh automated-test bundle |

## 7. Smoke checks (owed, never marked passed by an agent)

- **COMPACT-1:** the title-bar toggle and `/dw compact` swap modes, and each mode remembers its size and position.
- **COMPACT-2:** a Group drops card in every state, from test mode and `/dw sim`.
- **COMPACT-3:** My drops cards, the countdown, and Offer and Announce, with the Offer panel docked beside.
- **COMPACT-4:** History cards and their outcomes.
- **COMPACT-5:** the Filters ▾ menu matches the full bar's choices.
- **COMPACT-6:** an auto-open inside a key opens compact with *Open in compact view during a run* on, and opens the
  stored mode after the key ends.
- **COMPACT-7:** the card's tooltips sit at its top right, outside the window.
