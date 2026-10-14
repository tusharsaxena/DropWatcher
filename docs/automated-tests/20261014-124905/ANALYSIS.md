# Analysis — 20261014-124905

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** d34072e (feat/2026-10-13-drop-watcher-feedback-5)
- **Previous run:** 20261013-200128 (measured 98688dc)

## Headline

All four suites passed on a clean tree at the end of M19 (owner feedback 10: the filled `▼` downgrade glyph,
Offer's `external-link` icon, the simplified compact cards, Sort on the tab's strip). Tests grew by 2 passing
cases to 1399; lint stayed clean over the same 169 files; complexity barely moved (+12 NLOC, +1 function, the
averages flat) and no function is above CCN 15. The full-layout refresh allocates 120 bytes more per iteration.
Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261013-200128 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 169 files | [`lint.txt`](lint.txt) | unchanged (169 files, 0/0) |
| tests | pass | 1399 passed, 1 skipped, 0 failed, 1400 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +2 passed, +2 total (1397 / 1398 before); skipped unchanged at 1 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; full refresh +120 bytes/iter, compact unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +12 NLOC, +1 function; every average flat |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 41520 |
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

The run is sighted (`blindFiles` 0). The code barely changed in size: M19 removed the compact card's countdown
(its build, paint and per-second tick, `CompactGroup.HalfX` and `CompactCards`' countdown composer) and added about as
much (`CompactGroup.PlaceLineOne`, `PlaceThem`, the freshness painter, `CompactCards.FreshMark`, the strip's
three-slot placement and `WindowFooter`'s strip-following Sort anchor). Max CCN is 14 in the same two functions as
the previous run (`complexity.txt`): `candidateEq@157-176` in `modules/SideCells.lua`, mostly `and`/`or` guarding of
inspect reads, and the test closure `(anonymous)@500-522` in `tests/test_window_group.lua`.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the comparable figure; timings are orientation
only. The full-layout refresh pair allocates 14240.8 bytes per iteration, up from 14120.8 (+120). Not traced to a line: the likeliest source is the Drops strip's `DS.Slots` answer, a
table allocated on each full paint that now always carries three fields (it carried one or two). The compact pair
is unchanged at 10368.9.
`showDecisionStoodDown` still allocates nothing and both parse scenarios are unchanged at 664.2 bytes.

## What moved

- **lint:** unchanged: 169 files, 0 warnings, 0 errors.
- **tests:** 1397 → 1399 passed, 1398 → 1400 total. Added: Sort following the active tab to History's strip and
  back, and the bracketed freshness mark (pure). Rewritten in place: the compact cards' line 1 and line 2 (level then
  name, the freshness after it or left out, the action on line 2 or an empty slot), the countdown cases (now that no
  card shows one and a tick leaves the cards alone), the least-width cases (line 2 against the action button; line 3
  with Them a fixed gap after You), the strip's three-slot row, the icon tables (`external-link`), and every `▽`
  literal (`▼`). The one skip is unchanged.
- **perf:** +120 bytes per full refresh; nothing else moved.
- **complexity:** +12 NLOC, +1 function, max CCN 14 in the same two functions, no warnings, nothing in either band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None. `modules/WindowGroup.lua` is still the largest module near the band, at 968 lines; the next feature there
should split it rather than grow it.

## Actions

None.
