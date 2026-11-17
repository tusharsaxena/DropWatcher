# 05 — Summary: LibKa0s v1.103.0 -> v1.105.0

Run 2026-11-16 by RV-DW of `feat/2026-11-16-libka0s-75-plus` (plan M8). Nothing was pushed.

- **Tag:** v1.103.0 -> v1.105.0 (local tag commit 79b1d9c4), base from the CLAUDE.md provenance line,
  which agreed with the last payload commit (b12996a). Kit revision 56 -> 57. 21 files moved a minor
  and 5 are new (`Tooltip.lua`, `WidgetsDragHandleTip.lua`, `WidgetsHeader.lua`, `WidgetsBar.lua`,
  `OptionsSkinPickerQueue.lua`); table in `01_DELTA.md`. No cross-major skew.
- **Span bundle:** none (every vendored tag recorded; v1.104.0 was never vendored). No base correction.
- **Free (class A):** the skin color moves (#82, #84), header marks on the library's windows (#86), the
  console's footer and plain Copy (#79, #90), the library's tooltips through the placers (#92). All are
  smoke lines for the owner.
- **Contract fixes in the re-vendor commit:** the DebugLog stub's `Report` and `Serialize`; Ka0s
  Default's `list.stripe` re-copied into `NS.SKIN_FALLBACK`. No per-skin `icon.hot` pin was red, so
  none moved.
- **Icons:** the `LibKa0s icons:` line kept (32 names, `settings` included); the prune removed no
  declared icon and the 362 voice-pack files. No provenance split. README credits unchanged (Open
  Iconic and Phosphor still ship; no Game-icons). No dead stub mirrors.
- **Adopted:** nothing (copy and bundle half only).
- **Owed in phase [3]:** #79 (report verbs, `scan` and others to confirm), #92 (3 own tooltip sites),
  #86 (own windows' header strips), #87 (shared sample characters), #82 (own hot tokens), #85 (Callout,
  recommended not now). No issue filed here.
- **Gates:** before the copy: Retail 2598 passed / 0 failed / 1 skipped, Forever 2490 / 0 / 108,
  luacheck 0/0 in 265 files. After the copy: Retail 2596 / 2 / 1 (the two parity cases above). In the
  re-vendor commit: Retail 2598 passed / 0 failed / 1 skipped, Forever 2490 / 0 / 108, luacheck 0/0 in
  265 files, largest Lua file 1304 lines (`tests/test_test_mode.lua`).
