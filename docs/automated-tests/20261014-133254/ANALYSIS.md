# Analysis — 20261014-133254

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 5996818 (feat/2026-10-13-drop-watcher-feedback-5)
- **Previous run:** 20261014-124905 (measured d34072e)

## Headline

All four suites passed on a clean tree at the end of M20 (owner feedback 11: the pending inspect read said once
on a compact card, Them cut at the card's right inset, and the gray `No action` button in every action slot).
The case count is unchanged at 1399 passing (cases were rewritten, not added); lint stayed clean over the same 169
files; complexity moved by 19 NLOC with no new functions and every average flat. Perf did not move. Nothing to act
on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261014-124905 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 169 files | [`lint.txt`](lint.txt) | unchanged (169 files, 0/0) |
| tests | pass | 1399 passed, 1 skipped, 0 failed, 1400 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged counts; cases rewritten in place |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; every allocation unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +19 NLOC, +0 functions; every average flat |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 41539 |
| Functions | 5304 |
| Avg NLOC / function | 7.3 |
| Avg CCN | 2.4 |
| Max CCN | 14 |
| Avg tokens / function | 72.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0). The function count held because M20 added two (`WindowCells.NoAction`, the
Offer panel's `noOffer`) where it removed the same number's worth of dash builders and painters in the table, the
compact card and the Offer panel. Max CCN is 14 in `candidateEq@157-176` in `modules/SideCells.lua`
(`complexity.txt`), unchanged and mostly `and`/`or` guarding of inspect reads; the test closure that shared the top
spot in the previous run no longer appears at 14.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the comparable figure; timings are orientation
only. Every scenario allocates what it did: 14240.8 bytes per full refresh, 10368.9 per compact refresh, nothing for
`showDecisionStoodDown` and 664.2 per parse.

## What moved

- **lint:** unchanged: 169 files, 0 warnings, 0 errors.
- **tests:** counts unchanged (1399 passed, 1 skipped, 1400 total). Rewritten in place: every case that pinned the
  action dash or the empty action slot now pins the gray `No action` button with its reason (the table, the compact
  card, the detail card's first action, the Offer panel row, your own untradeable drop), the freshness mark's
  pending case, and the least-width line 3 case (Them bounded at the right inset); the button-fit case gained
  `No action` at 84 and at the Offer panel's 80. The one skip is unchanged.
- **perf:** nothing moved.
- **complexity:** +19 NLOC, no new functions, max CCN 14, no warnings, nothing in either band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None. `modules/WindowGroup.lua` is still the largest module near the band, at 959 lines.

## Actions

None.
