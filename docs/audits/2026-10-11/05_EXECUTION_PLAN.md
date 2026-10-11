# Execution plan: Ka0s Drop Watcher (standards audit, 2026-10-11)

## Step 1: DRW-01 (optional, Low)

- [ ] Decide between option A (a test toast times out when there is no close control) and option B
  (a register row), per `04_TECHNICAL_DESIGN.md`.
- [ ] A: write the degraded-load case in `tests/test_toast.lua` first, then change `show` and delete
  the typed fallback in `buildClose`. Run the gate, regenerate `docs/test-cases.md`, and move the
  README badge.
- [ ] B: add the row to `docs/ARCHITECTURE.md` → `## Documented deviations`.
- **Done when:** the grep for `"×"` in `modules/Toast.lua` is empty (A), or the register carries the
  row (B).

## Step 2: DRW-02 (Info; DW-63)

- [ ] When the owner lifts the hold on GitHub writes, DW-63 files the LibKa0s promotion issue and the
  WowAddonStandards chat-sending proposal, at least 20 seconds apart.
- [ ] Put each issue reference into its register row's `Why` cell.
- **Done when:** every register row's promised issue resolves.

Neither step blocks the v1 merge on the standard's terms. No High or Medium entry exists.
