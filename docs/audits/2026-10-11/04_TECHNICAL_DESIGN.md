# Technical design: Ka0s Drop Watcher (standards audit, 2026-10-11)

Two entries, both small. Neither touches a user-reachable path on a normal install.

## DRW-01: the toast's degraded close

**Where:** `modules/Toast.lua` (`buildClose`, `show`).

**Option A (preferred): remove the reason for the fallback.** The fallback exists because a test-mode
toast has no countdown, so on an install with no close control it could never go. If a test toast
times out like any other when `NS.MakeCloseButton` answers nil, the typed `×` can be deleted and the
toast degrades to no close control, like every other window in the addon. The change: in `show`,
start the countdown for a test drop too when `frame.close` is nil. The cost is one condition and one
case in `tests/test_toast.lua` that loads the addon with the Core library absent (the kit's
degraded loader, never a hand stub).

**Option B: ratify it.** Add a `## Documented deviations` row: rule `standalone-windows`; what
differs is a typed close glyph on the toast when LibKa0s is missing; why is that a test toast must
stay closable; re-check trigger is the Core stub publishing a close control.

**Risk:** none on a normal install. The degraded path is DEGRADED-1's smoke check.

**Ordering:** independent of everything else.

## DRW-02: the register's promised issues

**Where:** GitHub (`tusharsaxena/LibKa0s` and `tusharsaxena/WowAddonStandards`), then
`docs/ARCHITECTURE.md:315-325`.

**Shape:** plan item DW-63 files the LibKa0s promotion issue (the loot parser, the restriction tracker,
`ChatSender`, the tooltip line reader) and the WowAddonStandards proposal for addon-sent chat, at
least 20 seconds apart (the plan's rule). Each register row's `Why` cell then swaps "is filed at the
end of the v1 run" for the issue reference. That is a doc-only edit to the register, which is not
a frozen bundle.

**Risk:** none. **Ordering:** blocked on the owner lifting the hold on GitHub writes.
