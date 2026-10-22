# 07 — Refresh: the local tag v1.75.0 moved again

Item DW-RV3 of the cross-repo run "LibKa0s issues #45-#58"
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`, addendum 02, OWNER_SCOPE B).
Files 01 to 06 stay as written; this file records the second refresh of the payload from the same
tag name after it moved.

## Why the tag moved

LK-27 (SimPanel minor 2: the picker reads its scenario at use, plus the review's fixes) landed after
DW-RV2 refreshed the payload. The tag is local until the owner's go-ahead, so the lead moved it
rather than cutting a new version.

| | Commit |
|---|---|
| Old `v1.75.0^{commit}` (DW-RV2's source) | `6bf5f3e564e7bd96e1bf70a01c52ce93c6508e60` |
| New `v1.75.0^{commit}` (this refresh)    | `9e5c4e212ae0d3b189ff3c83d603def5a98b2d61` |

## The copy

Same mechanics as DW-RV and DW-RV2: `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools |
tar -x` into scratch, `libs/LibKa0s/` and `tests/_kit/` replaced whole, then the tag's
`tools/prune-icons.lua` against the unchanged `LibKa0s icons:` line in `CLAUDE.md` (28 declared,
29 files kept, 5,811 removed, as before). The provenance line stays `v1.75.0`.

## What changed

| File | Change |
|---|---|
| `libs/LibKa0s/SimPanel.lua` | step panel minor 1 -> 2: the picker's scenario is read at use (its choice while that def resolves, else the first name `d.scenarios.names` lists now); with nothing listed the Start row is locked and the picker's Start disabled |

`Sim.lua` stays at minor 2 and `SimTimeline.lua` at its attach minor 2 (Sim key 2.2.2).
`tests/_kit/` is byte-identical to DW-RV2's copy (kit 41 unchanged). No other payload file differs.

## Ripple

None. No test or doc in this addon pins a Sim or SimPanel minor. No smoke check is added:
INSTALL-5 (SM-DW-1..3) already covers the load, and the panel's own checks arrive with DW-04.

## Gate

`lua tests/run.lua` 1671 passed, 0 failed, 1 skipped (1672 total), `test_vendor_sync` green
against the moved tag; `luacheck .` 0 warnings / 0 errors in 191 files; no authored `.lua` file
above 1500 lines (largest `locales/enUS.lua`, 1338). Both through `ka0s-bounded`.
