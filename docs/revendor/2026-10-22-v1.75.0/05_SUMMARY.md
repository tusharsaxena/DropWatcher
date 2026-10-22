# 05 — Summary

- **Tag:** LibKa0s v1.72.0 -> v1.75.0, from the local annotated tag at `265a89e`. The base comes
  from the `CLAUDE.md` provenance line and the last payload commit, `ff567d3`, whose payload matches
  v1.72.0. v1.73.0 and v1.74.0 were never vendored here.
- **Minors:** Options 28 -> 29 and OptionsDrawer 1 (v1.73.0); Media 4 -> 5 and MediaIcons 1
  (v1.74.0); OptionsTabs 8 -> 9, OptionsIdList 4 -> 5, Core 10 -> 11, DebugLog 19 -> 20,
  DebugLogDiagnostics 2 -> 3, Widgets 12 -> 13, Item 2 -> 3, PerfPanel 6 -> 7, and the new majors
  Glow 1 and Sim 1 (SimTimeline 1, SimPanel 1) (v1.75.0). Kit 39 -> 41. Seventeen majors across
  forty files; fifteen are wired here.
- **Span bundle:** none. **Base correction:** none.
- **Delivered free (class A):** the scroll-keeping structural refresh, the corrected comments, the
  diagnostics header naming Glow and Sim, and kit 41's crashed-run handling and icon gate.
- **Blockers, fixed in the re-vendor commit:** the Options stub gains `H.Drawer`; the dead
  `H.__releaseChrome` mirror is removed; the Item parity case names `BonusIDsFromLink` in its ignore
  set (no call site, not adopted); `tests/prose_waivers.lua` waives `minimis` in `CLAUDE.md` for the
  catalog name on the declaration line.
- **Icons:** the line under the provenance line declares 28 names (`01_DELTA.md` 3i, with evidence).
  The prune removed 5,811 files: 196 Open Iconic marks, all of Phosphor (1,435 files) and all of
  Game-icons (4,180 files). What ships: 28 marks and `LICENSE-open-iconic.txt`. No provenance split.
- **Credits:** the README's `## Credits` names Open Iconic by Waybury (MIT), the one set that ships.
  No Phosphor or Game-icons line was ever there, and none is owed.
- **Adopted in this commit:** nothing. **Pre-decided adoptions:** `W.SearchBox`, `W.TestStrip`, the
  launcher-§6 binding, Glow and Sim, each in its own later DW item. **Not adopted in this run:**
  `Item.BonusIDsFromLink`, `O.Drawer`, `Media.ICON_SETS`/`IconAuthor`, `Kit.assertLatchHoldOrder`
  (`03_DECISIONS.md`). No issue filed.
- **Smoke:** `docs/smoke-tests.md` INSTALL-5 (SM-DW-1..3), owed the owner's client pass.
- **Gate:** `luacheck .` 0 warnings / 0 errors in 191 files; `lua tests/run.lua` 1660 passed,
  0 failed, 1 skipped (1661 total), `test_vendor_sync` and `test_surface_parity` included. Both
  through `ka0s-bounded`.
