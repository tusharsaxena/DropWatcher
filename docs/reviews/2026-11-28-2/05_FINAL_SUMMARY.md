# Final summary — Ka0s Drop Watcher review (2026-11-28, second pass)

Written as if every check in `03_SMOKE_TESTS.md` passed and M1 and M2 of `04_EXECUTION_PLAN.md`
landed. Until then it describes intended work, not shipped work.

## Headline

A whole-addon review of Drop Watcher at `c7b9bbc` found no Critical or High defect. Today's gate is
green: Retail 2648/0/6, Forever 2535/0/114, luacheck 0/0, seeds 14 passed, complexity max CCN 15. The
review-and-fix cycle closes four small items in the addon. The skin notice stops polling through combat
and leaves no timer armed past `/dw disable`. The golden verdict suite keeps only Drop Watcher's own
half. Seven error re-raises keep their stack. Two refusals that would have printed an internal key get
words. One cross-addon collision goes to LibKa0s and LootHistory: two different byte sets of
DebugLogDiagnostics minor 13 are in the field.

## Counts

Critical fixed: 0, High fixed: 0, Medium fixed: 2 (F-001, F-002), Low fixed: 2 (F-003, F-004).
Handed upstream: F-005 (Medium, LibKa0s + LootHistory), with no Drop Watcher commit.

## Changes by theme

### A: one combat-end edge, no stray timers

- **What changed:** a skin notice refused in combat now waits for `PLAYER_REGEN_ENABLED`, like the
  picker. The 5-second `C_Timer.After` poll is gone.
- **Why it mattered:** the poll outlived the stand-down, and it could write `db.global.skinNotice` while
  disabled (slash-commands-§7).
- **IDs:** F-001 / C-001. **Files:** `core/SkinSetup.lua`, `tests/test_skin_picker.lua`,
  `docs/test-cases.md`, `README.md`.

### B: the golden suite keeps Drop Watcher's half

- **What changed:** the 48 kernel cases over a byte copy of LibKa0s's fixture are gone. The 16 read
  cases stay, and a few view cases pin the client naming and the off-spec gate.
- **Why it mattered:** testing-§8, two suites over one behavior.
- **IDs:** F-002 / C-002. **Files:** `tests/test_verdict_golden.lua`,
  `tests/fixtures/verdict_golden.lua`, `tests/test_verdict_setup.lua`, `docs/testing.md`,
  `docs/test-cases.md`, `README.md`.

### C: re-raise with the stack

- **What changed:** `NS.Rethrowable` (`xpcall` with the stack) at the seven pcall-and-re-raise sites.
- **Why it mattered:** a report from a shared-event handler named only the dispatcher.
- **IDs:** F-003 / C-003. **Files:** `core/CoreSetup.lua`, `core/DropWatcher.lua`, `core/SkinSetup.lua`,
  `modules/HistoryRetention.lua`, `modules/LootFeed.lua`, `modules/Pending.lua`, `settings/Schema.lua`,
  `settings/SchemaSetup.lua`, `tests/test_setup.lua`.

### D: every refusal has words

- **What changed:** `collectible` and `badRequest` are worded, the raw-key fallback is a localized line,
  and `A.Preview` refuses collectibles as `A.Request` does.
- **IDs:** F-004 / C-004. **Files:** `core/DropWatcher.lua`, `modules/Asks.lua`, `locales/enUS.lua`,
  `tests/test_asks.lua`, `docs/test-cases.md`, `README.md`.

## API / behavior changes

- The skin notice shows at combat end rather than up to 5 s after it.
- New locale keys: `That request could not be made.` and `it could not be sent.`
- New internal helper `NS.Rethrowable`. No slash verb, schema row, default or SavedVariables shape
  changes, and no migration.

## Saved-variable / migration notes

None. The schema stays at 19.

## Deprecated-API migrations

None. The review found no deprecated call.

## Test and complexity movement

- Before: Retail 2648 passed / 6 skipped, Forever 2535 / 114 (measured 2026-11-28 at `c7b9bbc`).
- After: Retail 2648 − 48 + (2 + 2 + n view cases + C-003's extension, which adds 0). The exact figure
  is the post-change `--list` Total. `docs/test-cases.md` and the README badge move in the same commits.
- Complexity: no watch-list entry is expected to move. The next release's regeneration confirms it.
  The committed record is 218 commits behind (`20261116-102800`, `c03cddd`).

## Known follow-ups

- F-005: LibKa0s Feed branch `DIAG_MINOR = 14` and the release, then LootHistory's re-vendor. Drop
  Watcher picks it up at its next routine re-vendor.
- Re-check the standards citations against v2.122.2 once the standard's local commits are pushed (this
  review read v2.122.0).

## Verification evidence

`03_SMOKE_TESTS.md` with its sign-off table filled in, and the commit range of M1 on the run's branch.

## Suggested commit / PR description

```
Review 2026-11-28-2 fixes: no stray timer, golden suite de-duplicated, errors keep their stack

- F-001: the skin notice waits for the combat-end edge; no C_Timer poll survives /dw disable
- F-002: test_verdict_golden keeps Drop Watcher's read half; the kernel half is LibKa0s's (testing-§8)
- F-003: seven pcall re-raise sites keep the stack (NS.Rethrowable)
- F-004: collectible and badRequest refusals are worded; Preview refuses collectibles
F-005 (DebugLogDiagnostics minor 13 split) is LibKa0s + LootHistory's; no change here.
```
