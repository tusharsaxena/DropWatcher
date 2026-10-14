# Execution plan: Ka0s Drop Watcher review (2026-10-14)

Implements `02_PROPOSED_CHANGES.md`. The finding and change IDs match `01_FINDINGS.md`.

- **Gate:** every commit here must pass `lua tests/run.lua` and `luacheck .` (0/0) (`CLAUDE.md`).
- **Never edit** `libs/` or `tests/_kit/`. Never bump this addon's version without an explicit
  instruction.

## Milestones

### M1: Local fixes that need no upstream release
Done when C-01, C-02, C-03, C-05, C-06, C-07 and C-08 are committed, the suite reads 1409 passed,
0 failed, 1 skipped, and `docs/test-cases.md` and the README badge match.

| Task | Role | Implements | Files |
|---|---|---|---|
| T1 | test-author | F-001 / C-01 | `tests/test_disabled.lua`, `docs/test-cases.md` |
| T2 | lua-fixer | F-002 / C-02 | `modules/Asks.lua`, `tests/test_asks.lua`, `docs/data-flow.md`, `docs/test-cases.md`, `README.md` |
| T3 | lua-fixer | F-003 / C-03 | `core/DropWatcher.lua`, `tests/test_setup.lua`, `docs/test-cases.md`, `README.md` |
| T4 | lua-fixer | F-007 / C-07 | `core/DropWatcher.lua` |
| T5 | ux-cleanup | F-008 / C-08 | `core/DropWatcher.lua`, `modules/TradeHelper.lua`, `modules/DetailCard.lua`, `locales/enUS.lua`, `tests/test_disabled.lua`, `docs/test-cases.md`, `README.md` |
| T6 | wow-api-migrator | F-006 / C-06 | `core/CompatWorld.lua`, `core/DropWatcher.lua`, `modules/Diagnostics.lua`, `.luacheckrc`, `tests/test_compat.lua`, `docs/compat-layer.md`, `docs/test-cases.md`, `README.md` |
| T7 | locale-cleanup | F-005 / C-05 | `locales/enUS.lua`, `tests/test_locale.lua` (new), `tests/run.lua`, `docs/testing.md`, `docs/test-cases.md`, `README.md` |

### M2: Upstream (cross-repo handoff; one branch per repo, pushed, never merged without the owner)
Done when U-1 and U-2 are released in one LibKa0s tag, U-3 is merged in WowAddonStandards and U-4 is
merged in dev-copilot.

| Task | Role | Implements | Repo / files |
|---|---|---|---|
| U-1 | kit-maintainer | F-009 | `LibKa0s/testkit/mock_record.lua`, kit self-tests, `Kit.VERSION` 39 |
| U-2 | lib-maintainer | F-010 | `LibKa0s/LibKa0s/Perf.lua` (file minor 15), its tests, `CHANGELOG.md` |
| U-3 | standards-editor | F-011 | `WowAddonStandards/standards/standards/slash-commands.md` §7 step 6, `STANDARDS.md` version line |
| U-4 | tooling-maintainer | F-012 | `dev-copilot/profiles/wow/agent-review.md` class-1 census |

### M3: Re-vendor and the blocked local change
Done when one commit re-vendors the whole `libs/LibKa0s/` and `tests/_kit/` from the new LibKa0s
tag, `CLAUDE.md` / `docs/ARCHITECTURE.md` / `DEPENDENCIES.md` name that tag, C-04 is committed, C-01's
`__fireUnconditional` loop is added, the suite is green and `docs/test-cases.md` and the badge match.

| Task | Role | Implements | Files |
|---|---|---|---|
| T8 | revendor | U-1, U-2 exit criterion | `libs/LibKa0s/**`, `tests/_kit/**`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `DEPENDENCIES.md` (via `/dev-copilot:wow-revendor-libka0s`) |
| T9 | perf-instrumenter | F-004 / C-04 | `core/PerfSetup.lua`, `modules/LootFeed.lua`, `tests/test_setup.lua`, `docs/performance.md`, `docs/test-cases.md`, `README.md` |
| T10 | test-author | F-001 follow-up | `tests/test_disabled.lua` |

## Critical path and concurrency map

- **Serialize T3, T4, T5 and T6:** all four touch `core/DropWatcher.lua`. Order T4 → T3 → T5 → T6.
- **Serialize T5 and T7:** both touch `locales/enUS.lua`. T7 runs after T5, so the catalog includes
  T5's new keys and drops its retired ones.
- **Serialize T1, T5 and T10:** all touch `tests/test_disabled.lua`.
- **`docs/test-cases.md` and `README.md` are touched by every counting task:** commits land one at a
  time, each regenerating `--list`.
- **Parallelizable:** T2 (`modules/Asks.lua`) alongside T1, T4 or T7. The four upstream tasks are
  parallel with each other and with M1 (different repos).
- **Blocked:** T9 and T10 wait on T8, and T8 waits on the U-1 and U-2 release.

## Checkpoints

1. **After M1:** run the suite and lint. Confirm the badge reads `1409/1409`, and check the
   `docs/test-cases.md` diff is only the added and renamed cases.
2. **Before M3:** confirm the LibKa0s tag exists, and that its `CHANGELOG.md` "Versions in this
   release" line lists Perf 15 and kit 39.
3. **After M3:** run the cross-addon class 2 and 3 loops. This repo will now differ from the 13
   siblings that have not re-vendored yet. That is expected mid-sweep and is recorded, not fixed here.
   Then run `tests/perf.lua`: the zero-overhead pairs must still match.

## Commit strategy (one commit per task)

- T4 `DW-R0: Move NS.SetTestMode's doc block to the function it documents (F-007)`
- T1 `DW-R1: disabled 3 drives every declared handler and can fail (F-001)`
- T2 `DW-R2: A fixed announce channel needs its group, else noChannel (F-002)`
- T3 `DW-R3: Isolate each handler of a shared event, re-raise the first error (F-003)`
- T5 `DW-R4: One disabled refusal: the dispatcher's line, or the brand (F-008)`
- T6 `DW-R5: Compat.IsAddOnLoaded; fence the world reads to the Compat family (F-006)`
- T7 `DW-R6: enUS.lua is the whole catalog, gated by test_locale (F-005)`
- T8 `DW-R7: Re-vendor LibKa0s vX.Y.Z (kit 39, Perf 15)`
- T9 `DW-R8: evaluate and quality.gate declared and observed within feed.add (F-004)`
- T10 `DW-R9: disabled 3 also fires R_on through the kit and asserts each reached (F-001)`

Upstream commits follow each repo's own convention, on their own branches.
