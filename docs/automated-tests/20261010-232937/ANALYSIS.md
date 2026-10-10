# Analysis — 20261010-232937

The first automated-test run of Ka0s Drop Watcher, recorded on the scaffold commit `43d3792` (plan
item DW-02), clean tree, release label 0.1.0. Nothing is tagged: the release itself waits for the
whole v1 plan and the owner's go-ahead.

## Headline

**Green.** Lint 0/0 over 39 files, 137 of 138 cases passed with 1 declared skip, the three offline
perf scenarios passed their ceilings, and complexity was measured sighted with no function above
CCN 10.

## Suites

| Suite | Result | Reading |
|---|---|---|
| lint | pass, 0/0, 39 files | `libs/` and `tests/_kit/` are excluded (vendored), as are the frozen doc stores |
| tests | pass, 137/1/138 | The skip is the kit's diagnostics opt-out case, which does not apply: this addon keeps the default, so a report turns logging on |
| perf | pass, 3 scenarios | The bracketed window repaint allocates 0 bytes and notes nothing with capture off (zero overhead), notes once per pass with capture on, and the stood-down show decision allocates nothing |
| complexity | pass, 533 functions, avg CCN 2.0, max 10 | Measured through the kit's sighted shadow; `blindFiles` 0. The three functions at 10 are the test loader's `build`, the Profiles page builder and the Schema stub's `prepare` |

## What moved

Nothing: this is the first run, so there is no earlier row to diff against. Every later run's value
is the difference from this one.

## Complexity watch list

Empty. No function was warned on and no authored file is in the 1000–1500 line band. The largest
authored file is `modules/Window.lua` at about 250 lines.

## Actions

- As the feature items land, add each hot path's offline scenario to `tests/perf.lua` with its
  bucket (design spec §13), so the zero-overhead evidence covers every bracket.
- Keep new functions at CCN 10 or below; the evaluate and feed kernels are where the plan expects
  pressure.
