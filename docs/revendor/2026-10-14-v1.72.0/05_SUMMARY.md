# 05 — Summary

- **Tag:** LibKa0s v1.71.0 -> v1.72.0. The base, v1.71.0, comes from the `CLAUDE.md` provenance
  line and the last payload commit, `86b6634`. The copy is
  taken from tag v1.72.0 (annotated, pushed, at `785c297`), and both payloads match it byte for byte.
- **Minors:** `Perf.lua` moved from 14 to 15. The other 33 shipped files are unchanged. Kit revision
  moved from 38 to 39 (`latch.lua` new; `framework.lua`, `mock_base.lua`, `mock_record.lua` and
  `README.md` changed).
- **Span bundle:** none. This is the first bundle in the store.
- **Delivered free (class A):** Perf 15's report wording, and kit 39's `__fireUnconditional` reach.
- **Contract blockers:** none (`01_DELTA.md` 3g).
- **Adopted:** nothing in this run. DW-P24 (Perf parent keys) and DW-P25 (latch helper and reach
  count) own the two class-B candidates.
- **Declined:** none.
- **Documented deviations:** all six register rows in `docs/ARCHITECTURE.md` were re-checked against
  v1.72.0 (X06). No re-check trigger fired. v1.72.0 adds no major. LibKa0s#49, #51 and #53 and
  WowAddonStandards#11 are still open. Each row's Decided cell now records the re-check.
- **Gate:** `luacheck .` gives 0 warnings / 0 errors in 170 files. `lua tests/run.lua` gives 1417
  passed, 0 failed, 1 skipped (1418 total), `test_vendor_sync`'s two payload cases included. Both run
  through `ka0s-bounded`. The new kit needed no host change: the suite was green on it as copied.
