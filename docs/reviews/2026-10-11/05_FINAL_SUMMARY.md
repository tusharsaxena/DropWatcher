# Final summary: Ka0s Drop Watcher v1 review (2026-10-11)

Written assuming every check in `03_SMOKE_TESTS.md` passes. The in-client checks are the owner's,
and none has been run yet.

## Headline

The v1 build was measured fresh, and every out-of-game suite was green: 886 tests passing, lint
0/0, no function above CCN 13, vendored copies identical to LibKa0s v1.71.0, and a clean
cross-addon pass across the 13-addon roster. The review found no crash, taint or data-loss risk.
It fixed five behavior bugs in the opt-in toast and auto-ask features and in how the scorer
chooses Pawn. A toast now leaves when its drop leaves the feed, is dismissed or is switched off. An
upgrade into an empty slot now qualifies. Pawn counts only once it has initialized. Auto-ask no
longer waits forever on an encounter the player left. Both confirmation dialogs now ask for
StaticPopup slot 3.

## Counts

Critical fixed: 0. High fixed: 0. Medium fixed: 5 (F-001..F-005). Low fixed: 1 (F-006).
Deferred: F-007 (the toast's degraded-only `×` close), kept on purpose; see Known follow-ups.

## Changes by theme

### A. The toast follows its drop and its switch

- **What changed:** the feed tells its removal sinks when drops leave (a clear or the cap), and the
  toast prunes itself. Dismissing a row forgets its toast. Turning **Show a toast** off, or switching
  to a profile with it off, takes the toast down and empties its queue.
- **Why it mattered:** a stale toast's Ask either refused ("That drop is gone.") or whispered for a
  drop the player had dismissed.
- **Findings:** F-001, F-004. **Changes:** C-01..C-04.
- **Files:** `modules/LootFeed.lua`, `modules/Toast.lua`, `core/DropWatcher.lua`,
  `settings/SchemaRows.lua`.

### B. An empty slot qualifies

- **What changed:** a toast and an auto-ask fire for an upgrade into an empty slot, and the toast
  reads `empty` where a gain would go.
- **Why it mattered:** the clearest upgrades were the one case both features skipped.
- **Findings:** F-002. **Changes:** C-05. **Files:** `modules/Toast.lua`.

### C. Pawn counts once it is initialized

- **What changed:** `auto` and `pawn` pick the Pawn adapter only when `PawnIsInitialized` is true,
  as spec §5.4 says. The unused `Compat.PawnIsLoaded` is removed.
- **Why it mattered:** a loaded but uninitialized Pawn displaced the player's own weights and used
  up the score retries.
- **Findings:** F-003. **Changes:** C-06. **Files:** `modules/Scoring.lua`, `core/Compat.lua`.

### D. Auto-ask lets go of an encounter it left

- **What changed:** on `PLAYER_ENTERING_WORLD` or `ZONE_CHANGED_NEW_AREA`, a held encounter whose
  restriction is no longer active counts as ended.
- **Why it mattered:** a hearth or a release mid-fight could hold every auto-ask until the next boss
  or a `/reload`.
- **Findings:** F-005. **Changes:** C-07. **Files:** `modules/AutoAsk.lua`.

### E. The confirmations take slot 3

- **What changed:** `preferredIndex = 3` on Clear history and Reset all settings.
- **Findings:** F-006. **Changes:** C-08. **Files:** `modules/WindowHistory.lua`,
  `settings/Schema.lua`.

## API and behavior changes

- No slash verb, saved-variable key or default changed. No locale key was added: the toast's
  `empty` reuses the Me column's key.
- Removed: `NS.Compat.PawnIsLoaded` (no caller).
- Added: `NS.LootFeed.AddRemovalSink`, and `NS.Toast.Prune`, `Forget`, `OnEnabledChanged` and
  `OnProfileReloaded`.
- New event rows: AutoAsk on `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA`. Both events were
  already registered by other modules and fan out through the shared dispatcher.

## Saved variables and migrations

None. `schemaVersion` is unchanged.

## Test and complexity movement

The pass count rises from 886 by the new cases. `docs/test-cases.md` and the README `[tests]` badge
move in the same commit as each count change. Two existing assertions that encoded the spec-wrong
behavior (F-002's qualifier row, F-003's "auto prefers a loaded Pawn") are corrected with the code.
No watch-list entry moves.

## Known follow-ups

- **F-007:** the toast's `×` when LibKa0s is missing stays. It is the only way to close a test toast on
  that install. Revisit if `LibKa0s-Core-1.0`'s stub ever publishes a close control.
- **The review playbook's slash census** cannot see a token registered from a constant (Drop
  Watcher's `NS.SLASH:sub(2)`). That is a dev-copilot playbook note, not an addon change.

## Verification evidence

The gate output is in each fix commit's body. `03_SMOKE_TESTS.md` holds the sign-off table, and
`docs/smoke-tests.md` holds TOAST-2 and ASK-9. Commit range: from the bundle commit to the last
`DW-62: fix review —` commit on `feat/2026-10-10-drop-watcher-v1`.

## Suggested PR description

```
DW-62: v1 review and standards audit, with fixes

- Review bundle docs/reviews/2026-10-11/, audit bundle docs/audits/2026-10-11/.
- F-001/F-004: the toast leaves with its drop (clear, cap, dismiss) and with its switch.
- F-002: an empty-slot upgrade toasts and auto-asks.
- F-003: the Pawn adapter waits for PawnIsInitialized (spec §5.4).
- F-005: auto-ask lets go of an encounter the player left.
- F-006: both confirmations take StaticPopup slot 3.
```
