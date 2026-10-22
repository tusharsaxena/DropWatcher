# 06 — Refresh: the local tag v1.75.0 moved

Item DW-RV2 of the cross-repo run "LibKa0s issues #45-#58"
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`, addendum 01, OWNER_SCOPE B).
Files 01 to 05 record the DW-RV re-vendor and stay as written; this file records what changed
when the payload was refreshed from the same tag name after it moved.

## Why the tag moved

LK-26 (Sim minor 2: `Start` reads the scenarios live, and `prepare` gets the host's start
options) landed after DW-RV vendored v1.75.0. The tag is local until the owner's go-ahead, so the
lead moved it rather than cutting a new version.

| | Commit |
|---|---|
| Old `v1.75.0^{commit}` (DW-RV's source) | `265a89eba3db44f2d85e61287d1691cca6b1effd` |
| New `v1.75.0^{commit}` (this refresh)   | `6bf5f3e564e7bd96e1bf70a01c52ce93c6508e60` |

## The copy

Same mechanics as DW-RV (`01_DELTA.md`): `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit
tools | tar -x` into scratch, `libs/LibKa0s/` and `tests/_kit/` replaced whole, then the tag's
`tools/prune-icons.lua` against the unchanged `LibKa0s icons:` line in `CLAUDE.md` (28 declared,
29 files kept, 5,811 removed, as before). The provenance line stays `v1.75.0`.

## What changed

| File | Change |
|---|---|
| `libs/LibKa0s/Sim.lua` | `LibKa0s-Sim-1.0` minor 1 -> 2: scenarios read live by `Start`, host start fields kept and handed to `prepare`, `startOpts` on the handshake ctx |
| `libs/LibKa0s/SimTimeline.lua` | timeline attach minor 1 -> 2: `Restart` re-starts with the session's extra host start fields |

`SimPanel.lua` stays at minor 1. `tests/_kit/` is byte-identical to DW-RV's copy (kit 41
unchanged). No other payload file differs.

## Ripple

None. No test or doc in this addon pins a Sim minor, and nothing here calls Sim yet (DW-02 to
DW-05 adopt it). No smoke check is added: INSTALL-5 (SM-DW-1..3) already covers the load.

## Gate

`lua tests/run.lua` 1662 passed, 0 failed, 1 skipped (1663 total), `test_vendor_sync` green
against the moved tag; `luacheck .` 0 warnings / 0 errors in 191 files; no authored `.lua` file
above 1500 lines. Both through `ka0s-bounded`.
