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
