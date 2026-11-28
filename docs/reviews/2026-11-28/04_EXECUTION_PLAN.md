# 04 — Execution plan

## M0: LibKa0s release coordination (cross-repo; upstream F-001, F-012, F-009 part)

**Done when:** LibKa0s has distinct tags for the Verdict and Feed releases, the DIAG minor is bumped past 13 with both majors listed, and Drop Watcher's **re-vendor commit** (with the `CLAUDE.md` provenance line in the same commit) lands here.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M0-T1 | release-coordinator (LibKa0s) | F-001 | LibKa0s `LibKa0s/DebugLogDiagnostics.lua`, `CHANGELOG.md`, `docs/releasing.md` (in LibKa0s) |
| M0-T2 | standards-owner | F-012 | WowAddonStandards `standards/testing.md` §11, or LibKa0s `testkit/vendor_sync.lua` |
| M0-T3 | lib-perf (LibKa0s) | F-009 (part) | LibKa0s `LibKa0s/Verdict.lua` |
| M0-T4 | revendor-agent | exit criterion | this repo: `libs/LibKa0s/**`, `tests/_kit/**` (whole-folder copy only), `CLAUDE.md` |

**Checkpoint after M0:** the owner confirms which branch took `v1.119.0`. Re-run the Measurement run's vendor-sync and cross-addon class 2 and 3 rows.

## M1: Gate honesty (F-002, F-005)

**Done when:** the shim matches one pinned tag, the deviation row exists, and the complexity run shows 3 warnings.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M1-T1 | test-author | F-002 / C-01 | `tests/test_vendor_sync.lua`, `docs/ARCHITECTURE.md` |
| M1-T2 | lua-refactorer | F-005 / C-03 | `tests/test_verdict_golden.lua` |

Parallelizable: disjoint files.

## M2: Read override (F-003)

**Done when:** C-02 shape B1 or B2 is in place and both kit profiles are green.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M2-T1 | lua-refactorer | F-003 / C-02 | `core/VerdictSetup.lua`, `core/SimSetup.lua` (B1), or a new `tests/test_verdict_reads_parity.lua` (B2), `docs/test-cases.md`, `README.md` (B2 badge) |

**Checkpoint before M2:** the owner picks B1 or B2.

## M3: Post-G1 test consolidation (F-004, F-006)

**Done when:** the golden kernel half is reduced and the seed tool's dead path is gone, with the inventory and badge moved in the same commits.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M3-T1 | test-author | F-004 / C-04 | `tests/test_verdict_golden.lua`, `tests/fixtures/verdict_golden.lua`, `docs/test-cases.md`, `README.md` |
| M3-T2 | tooling | F-006 / C-05 | `tools/seeds/seeds.py`, `tools/seeds/test_seeds.py`, `docs/validate-seeds.md` |

**Serialize:** M3-T1 touches `tests/test_verdict_golden.lua`, which M1-T2 also touches, so M1-T2 must go first. M3-T1 and M2-T1 (B2) both touch `docs/test-cases.md` and `README.md`, so they must also serialize. M3-T2 is parallelizable.

## M4: Cleanups (F-007 to F-011)

| Task | Owner | Covers | Files |
|---|---|---|---|
| M4-T1 | lua-refactorer | F-007, F-008 / C-06, C-07 | `core/VerdictViews.lua`, `tests/test_gear.lua`, `tests/run.lua` |
| M4-T2 | lua-refactorer | F-009 host / C-08 | `core/VerdictSetup.lua`, `tests/perf.lua`, `docs/performance.md` |
| M4-T3 | lua-refactorer | F-010 / C-09 | `core/DropWatcher.lua`, `core/VerdictSetup.lua` |
| M4-T4 | docs | F-011 / C-10 | `core/Database.lua` |

**Serialize:** M4-T2 and M4-T3 both touch `core/VerdictSetup.lua`, which M2-T1 also touches. Run them in the order M2-T1 → M4-T2 → M4-T3. M4-T1 and M4-T4 are parallelizable.

## Commit strategy

Make one commit per task, run the green gate before each, and never `--no-verify`. Suggested messages:

- `IS-REV1: the vendor-sync pre-tag shim matches v1.119.0 alone; deviation registered (F-002)`
- `IS-REV2: split the golden suite's seed below CCN 15 (F-005)`
- `IS-REV3: the verdict host owns an explicit read set (F-003)`
- `IS-REV4: the golden kernel half reduced to wiring; inventory and badge moved (F-004)`
- `IS-REV5: seeds apply retires its unreachable writer (F-006)`
- `IS-REV6: verdict views and host cleanups (F-007..F-010)`
- `IS-REV7: re-vendor LibKa0s vX.Y.Z (F-001)`, the M0 exit commit.

Each message ends with the session's attribution lines. Nothing is staged or committed without the owner's instruction (`CLAUDE.md`).
