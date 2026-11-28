# 05 — Final summary (written as if every change in 02 landed and 03 passed)

## Headline

The Item Search split branch was reviewed and its follow-ups applied. Drop Watcher now runs its verdicts on `LibKa0s-Verdict-1.0` through an explicit read set, so it cannot silently shadow the library with stale copies. Its vendored LibKa0s is on a tag no other addon claims with different bytes. The vendor-sync gate waives only the one pre-tag case it was written for, and that waiver is on the deviation register. The golden suite is under the release gate's complexity ceiling, and the leftovers of the move are gone: unused view members, an unreachable seed-tool writer, and a test-only mutator in shipped code.

## Counts

Critical fixed: 0 · High fixed: 0 · Medium fixed: 5 (F-001 to F-005) · Low fixed: 6 (F-006 to F-010, F-012). F-011 is comment-only, by design: no migration step is removed.

**Deferred:** the three pre-existing CCN warnings (`RT.FlushOverlaps`, `buildMembers`, `RC.Left`). They predate this branch, but they still block the tag gate.

## Changes by theme

### A. LibKa0s release coordination

- **What changed:** Drop Watcher was re-vendored onto a distinct LibKa0s tag. The pre-tag shim now matches one tag, and its deviation is recorded.
- **Why it mattered:** two `v1.119.0` payloads with one DIAG minor resolved by load order.
- **Findings / changes:** F-001, F-002, F-012 / C-01, plus the upstream set.
- **Files:** `libs/LibKa0s/**`, `tests/_kit/**` (re-vendor only), `CLAUDE.md`, `tests/test_vendor_sync.lua`, `docs/ARCHITECTURE.md`.

### B. Explicit engine reads

- **What changed:** the host names the reads it owns, and the engine reads the rest from its own `lib.Reads`. (With shape B2, a parity suite pins the overlap instead.)
- **Why it mattered:** 33 duplicate reads could drift from the library unseen.
- **Findings / changes:** F-003 / C-02.
- **Files:** `core/VerdictSetup.lua`, `core/SimSetup.lua`, `core/Compat*.lua` (B1 deletions).

### C. Test hygiene

- **What changed:** the golden `seed` was split, the kernel half reduced to wiring, and the seed tool's dead writer removed.
- **Why it mattered:** a red release gate, duplicated library coverage, and an untestable tool path.
- **Findings / changes:** F-004, F-005, F-006 / C-03, C-04, C-05.
- **Files:** `tests/test_verdict_golden.lua`, `tests/fixtures/verdict_golden.lua`, `tools/seeds/*`, `docs/validate-seeds.md`, `docs/test-cases.md`, `README.md`.

### D. Cleanups

- **What changed:** the unused `NS.Gear` members were removed, `CD.Install` was fenced, the host got a plain-field perf gate with a paired offline scenario, and settings now register before the engine stands up.
- **Findings / changes:** F-007 to F-011 / C-06 to C-10.
- **Files:** `core/VerdictViews.lua`, `core/VerdictSetup.lua`, `core/DropWatcher.lua`, `core/Database.lua`, `tests/perf.lua`, `docs/performance.md`.

## API / behavior changes

No slash verb, binding, setting or default changes. Diagnostics' identity header lists both `Verdict` and `Feed` once re-vendored.

## Saved-variable notes

No new schema step. The branch's own step 19 (`itemSearch` removed from `global`, `char.*` and `profiles.*`) is unchanged.

## Deprecated-API migrations

None.

## Performance impact

Fill this in from the C-08 offline pair (`gearRebuildCaptureOff`/`On`, equal allocations) and the `docs/perf-analysis/` capture's `gear.rebuild` bucket. No number is claimed here before those are measured.

## Test and complexity movement

- **Before:** Retail 2669 passed / 8 skipped; Forever 2556 / 116; pytest 22; complexity 4 warnings (max 20).
- **After:** pending. C-04 lowers the case count and C-05 lowers pytest to 21. `docs/test-cases.md` and the README badge move in the same commits.
- **Watch list:** `seed` is expected to leave the `docs/automated-tests/RESULTS.md` watch list at the next release regeneration.

## Known follow-ups

- The three pre-existing CCN > 15 functions, which block the release gate on their own.
- Moving the class-list seed check into LibKa0s (F-006 alternative).
- Collapsing the unreleased schema steps 10 to 19 at the next release, if the owner rules it.

## Verification evidence

- `03_SMOKE_TESTS.md`, with its sign-off table filled.
- The commit range of the IS-REV1..7 commits.

## Suggested PR description

```
Item Search split: review follow-ups (docs/reviews/2026-11-28)

- Vendor-sync pre-tag shim pinned to v1.119.0 and registered as a deviation (F-002)
- Golden suite seed split below CCN 15 (F-005); kernel half reduced to wiring (F-004)
- Verdict host owns an explicit read set; no silent shadowing of lib.Reads (F-003)
- Seed tool's unreachable writer retired (F-006); NS.Gear view trimmed, CD.Install fenced (F-007, F-008)
- Host perf gate is a plain field; gearRebuild offline pair (F-009); settings register before the engine (F-010)
- Re-vendor LibKa0s to the renumbered tag after the Feed/Verdict v1.119.0 collision (F-001, upstream)
```
