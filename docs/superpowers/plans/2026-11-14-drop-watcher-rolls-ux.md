# Drop Watcher rolls UX Implementation Plan

> **For agentic workers:** items run through a workflow, one implementer and one independent reviewer per item,
> then a milestone gate. Resume with `2026-11-14-drop-watcher-rolls-ux/resume-state.sh`.

**Goal:** the rolls UX round of the design: roll side card and icon counts, line-2 caps, lockboxes, auto-close,
header lock, one-line footer, Forever defaults, and the roll-timer and master-loot threshold fixes.

**Architecture:** extend the existing modules (RollCells, RollPopup, WindowPending, WindowRows/WindowGroup,
CompactCards, FeedFilter/ItemFacts, PendingML/CompatLoot, WindowTitleBar, WindowFooter, Window); no new LibKa0s
surface.

**Spec:** `docs/superpowers/specs/2026-11-14-drop-watcher-rolls-ux-design.md`

**Branch:** `feat/2026-11-14-rolls-ux` (DropWatcher only).

## Global Constraints
- Both kit profiles 0 failed (`lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`), luacheck 0/0 via
  `~/.claude/dev-copilot/bin/ka0s-bounded`, before every commit. Lizard 0 functions over CCN 15.
- `docs/test-cases.md` equals `lua tests/run.lua --list`; README Tests badge in step.
- CRLF line endings (.gitattributes). US spelling in prose and comments.
- Never edit `libs/`, `tests/_kit/`, or earlier runs' files under `docs/superpowers/`. No version bump.
- clients-§4: Disenchant appears on Retail only. Names through `UnitCharacterName` (client-quirks-§5).
- File caps: LootFeed < 1100, WindowGroup and WindowCells < 1250 lines (split before crossing).

## Review Focus
1. **Four roll frames at once near the screen's right edge**: each card flips left and none overlaps another frame.
2. **A two-word name on your own drop at the narrowest window width**: `[YOU]` stays whole; the button is clickable.
3. **A lockbox, a bag and a reagent rolled together**: lockbox and bag show by default as their kind; the reagent
   only with the catch-all on; none reads "Unknown" or shows a gain.
4. **Auto-close while hovering, and after a manual open**: hover restarts the count; a manually opened window never
   closes by itself.
5. **A roll whose startTime/duration are in different units**: time left is either right or absent, never 2717:57.

## M1 — Fixes and defaults

### RX-01: Forever defaults
- Forever: `openWorldGroup = situation(true, true)`; feed quality `fixed = 2` (Uncommon) on Forever, 3 on Retail.
- Tests: per-client defaults cases in `tests/test_schema_rows.lua` / defaults tests. Docs: schema.md, settings-panel.md.

### RX-02: The roll time left
- Spec §3.4. `Compat.LootRollTimeLeft(rollID)` (ms → s) for a claimed popup roll; plausibility guard otherwise.
- Tests: claimed roll uses the client timer; a duration in ms with startTime in s shows no time; a normal roll shows
  m:ss. Probe sheet entry updated with what to read.

### RX-03: Master-loot pending at the group's loot threshold
- Spec ruling 6. `Compat.LootThreshold()` wraps `GetLootThreshold()`; PendingML reads it; fallback 2.
- Tests: Rare under ML with threshold 2 is held; Uncommon below threshold 3 is not; Retail Guild Master Loot holds at
  threshold. Docs: known-limitations, ARCHITECTURE, design-readings.

### RX-04: Lockboxes and the catch-all
- Spec §3.5. Categories `container` (on) and `other` (off); Drops › Items rows; kind word for non-gear verdicts on
  rows, cards, Rolling now and RollPopup; Insights handles the new kinds.
- Tests: an Ornate Bronze Lockbox (container) passes by default; a reagent passes only with `other`; a lockbox's
  verdict text is "Lockbox", no gain; Rolling now admits a rolled lockbox.

## M2 — Rows

### RX-05: Line-2 caps and the button on top
- Spec §3.1, both clients; full rows, compact cards, History cards.
- Tests: a long two-word name is cut with "…" and `[YOU]` is present whole; slot and type cut at their caps; the
  action button's frame level is above the text's; Retail one-word names unchanged.

## M3 — Rolls

### RX-06: The roll count line and the all-rolls tooltip
- Spec §3.2. RollCells renders the icon line and builds the tooltip; Rolling now (full + compact), the Rolls box
  and History use it. Disenchant Retail-only.
- Tests: counts per state; DE hidden on Forever; tooltip groups and order; a secret name degrades.

### RX-07: The roll side card
- Spec §3.3. Re-anchor and reskin RollPopup's cards; flip logic; tooltip; sim stand-ins stack.
- Tests: right anchor; flip near the right edge; four frames no overlap; skin tokens used; non-gear kind line;
  tooltip shown on hover; sim twice stacks two.

## M4 — Window chrome

### RX-08: Header lock button
- Spec §3.7. Full and compact title bars; bound to `locked`; grip hidden when locked.
- Tests: toggle writes the setting; `/dw lock` updates the button; grip hidden/shown.

### RX-09: One footer line
- Spec §3.7. Status text into the footer row; status bar removed; grip in footer corner.
- Tests: footer text contains the status; status bar absent; tooltip kept; narrow width cuts with "…".

### RX-10: Auto-close
- Spec §3.6. Setting rows, timer logic, hover pause, manual-open cancel.
- Tests: closes after X s once idle after an auto-open; a new drop resets; hover restarts; manual open never
  closes; disabled when auto-open is off; defaults on with 10 s on both clients.

## M5 — Docs, review, bundle

### RX-11: Docs and smoke
- README Usage, ARCHITECTURE, schema.md, settings-panel.md, smoke-tests.md (new checks for each item, both clients),
  forever-probes.md.

### RX-12: Whole-run review and the automated-test bundle
- Multi-lens adversarial review of `master..feat/2026-11-14-rolls-ux` (correctness + Review Focus, taint, standard,
  Retail regressions, Forever behavior); fix verified Critical/Important; `/dev-copilot:wow-automated-tests` bundle.
- **Stop:** owner smoke and merge go-ahead.

## M6 — Owner smoke follow-ups (2026-11-15)

Owner rulings after the first smoke: the lock button moves to the title bar's top-right cluster; the waiting
mark is an hourglass everywhere the clock icon was used (re-vendor LibKa0s, which ships the hourglass only from
v1.102.0); quivers and ammo pouches are containers, and lockboxes are their own kind, not containers; Insights keeps
Lockbox, Container and Other loot as separate labels.

### RX-13: LibKa0s re-vendor and the hourglass
- Re-vendor LibKa0s v1.95.0 → v1.102.0 with the re-vendor skill; declare `ph:hourglass`; the roll waiting mark and
  the Queued offer state use it; drop `clock` from the declaration if nothing else uses it. Adopt no other new surface
  in this item: list the candidates for the owner.
- Tests: the waiting mark and the Queued offer icon read the hourglass; both kit profiles green on the new kit.

### RX-14: The lock button at the top right
- Full and compact title bars: the lock button joins the right-hand button cluster (left of the layout toggle);
  the left of the title bar is empty again. Behavior unchanged.
- Tests: the lock button's anchor is in the right cluster on both layouts; buttons do not overlap at minimum width.

### RX-15: Lockboxes are their own kind; quivers and ammo pouches are containers
- Categories `lockbox` (on by default; kind word "Lockbox") and `container` (on; bags, quivers, ammo pouches; kind
  word "Container"); `other` unchanged (off). Drops › Items rows for both. Insights lists Lockbox, Container and
  Other loot separately.
- Tests: an Ornate Bronze Lockbox is `lockbox`; a bag and a Forever quiver/ammo pouch are `container`; each passes by
  default and can be switched off on its own; Insights labels.

### RX-16: A roll popup for a watched item opens the window
- Owner request (2026-11-15): the window opens when a Blizzard loot-roll popup appears for an item that would show in
  Drop Watcher (it passes the feed's gates and lands in Rolling now). Same rules as a drop's auto-open: master
  Auto-open on, the situation's Auto-open on, not already open, nothing for a restored roll; opens on Drops; compact
  in runs as today; it is an auto-open, so auto-close arms (and waits until the roll is done). A master-loot hold has
  no roll popup and opens nothing. Implemented on Pending's `open` change for a roll item (Window.lua's
  maybeAutoOpen path, not a hook on the Blizzard frame).
- Tests: a roll for a watched item opens the window when closed; an unwatched (filtered) roll does not; situation
  Auto-open off or master off does not; an ML hold does not; auto-close arms and does not close while the roll runs;
  a window already open keeps its tab.

## M7 — The Rolls panel (2026-11-15)

Spec: `docs/superpowers/specs/2026-11-15-drop-watcher-rolls-panel-design.md` (owner signed off the mockup
https://claude.ai/artifact/72o22p9d8Q8wnqEdbKMcyF with every recommended answer). The panel lives in its own
module(s); Window.lua only exposes what the panel needs to dock (frame, layout, shown/minimized state).

### RX-17: The panel, docked, in a dungeon
- Spec §3.1, §3.2, §3.4, §3.5: owned frame docked right/left with the off-screen flip; skin and title bar; close
  button; dungeon layout (all blocks open, per-player rows grouped and sorted, `[YOU]`, verdict foot, winner
  highlight and result line); lifecycle (first watched roll shows it, linger 0–60 s, hover holds, hides with the
  window closed/minimized; WindowAutoClose not idle while the panel has blocks); settings rows and defaults;
  `/dw rolls`.
- Tests: docks right, flips left near the right edge, Left setting; shows on a watched roll, not on a filtered one,
  not with the window closed; rows grouped and sorted with `[YOU]`; Disenchant Retail only; winner highlight and
  result line; a block leaves after linger, 0 at once; hover holds; auto-close waits while the panel lingers;
  setting off shows nothing; `/dw rolls` toggles.

### RX-18: Raid mode
- Spec §3.3: group > 5 members; one block open, rest headers; the open rule (your pending roll, else soonest ending;
  a clicked header sticks until it resolves); folded Pass/Waiting lines with a hover tooltip and click to unfold;
  a resolved block dims to a header with the winner; the body scrolls; title "Rolls · N"; compact layout width 220;
  rows from a pool. A perf scenario for a 40-player, 6-item roll refresh, with a ceiling recorded from its first
  measurement.
- Tests: a 6-member group uses raid mode, 5 does not; the open rule and sticky click; fold and unfold; 40 players
  fit with no frame created per refresh; compact width.

### RX-19: Simulation, test mode and docs
- Spec §3.6: test mode fills the panel; `/dw sim roll` adds a dungeon roll; `/dw sim raid` starts a 40-player
  simulated roll with several items. README Usage, ARCHITECTURE, module-map, schema.md, settings-panel.md,
  smoke-tests.md (checks for both clients and both layouts), slash surface.

## M8 — Rolls panel round 2 (2026-11-15)

Spec: `docs/superpowers/specs/2026-11-15-rolls-panel-round2-and-window-chrome-design.md` part A (owner rulings A1–A11).

### RX-21: The panel's strip, item headers and collapsers, rows and linger
- A1–A10: TestStrip under the title bar (no header word); item headers like Rolling now's section header with a
  collapser; Expand all / Collapse all title buttons; all expanded by default, manual collapse sticks; raid one-open
  rule removed (fold stays); width 290/250; no verdict line; alternate row shading; every roll number shown; tooltips;
  title "Rolls"; panel-level linger replaces per-roll; flush docking.
- Tests: strip shows in test and sim, no header word; headers toggle, Expand/Collapse all; all open by default in a
  40-player group; no verdict line; alt shading; roll numbers on Need/Greed rows, none on Pass/Waiting; tooltips on
  header, rows, buttons; finished rolls stay until all are done, then the panel closes after linger; a new roll
  cancels; gap 0.

### RX-22: Test mode shows the simulated roll popup and side card
- A11. Tests: test mode on shows a stand-in popup with its side card per sample roll; test mode off hides them.

## M9 — Window chrome standards upstream (2026-11-15)

Spec part B. Worktrees cut from each repo's default branch; never touch another session's branch.

### UC-01: WowAddonStandards — strip under the header (windows and HUDs), the footer and its height
- B.1, B.2 as rules; ripple (anti-patterns, audit playbook, context pack, changelog, index); minor bump; merge, tag, push.

### UC-02: LibKa0s — the Footer primitive and TestStrip docking
- B.1 helper and B.2 primitive; tests, docs/api, changelog; minor bump; merge, tag, push.

## M10 — Adoption in every addon (2026-11-15)

### UC-03..: one item per roster addon
- Re-vendor the UC-02 tag; strip under the title bar / HUD top; Footer where a footer exists; gate green; own branch,
  pushed; merge waits for the owner. Drop Watcher adopts on this branch (UC-DW).

**Scope change (owner, 2026-11-15):** no re-vendor into other addons in this run. M9 released WowAddonStandards v2.110.0 and LibKa0s v1.103.0 (Widgets minor 27). M10 is Drop Watcher only (UC-DW) plus LibKa0s issues #88 (strip adoption), #89 (Footer adoption) and #90 (the debug console footer), which track the other addons for the owner's later full re-vendor.
