# 05 — Summary: the consolidated span v1.80.0 to v1.83.0

Written 2026-10-31 by `FX-DW-DOCS`. A records-only back-fill: no code, library or kit file moved because
of it, and nothing was pushed. The span's previous base is v1.77.0.

## Per tag

- v1.80.0: carried by `6920689`, the Toast-ahead deviation retired, the Options stub's four members met
- v1.81.0: carried by `5b4f552`, nothing owed for this addon
- v1.82.0: carried by `87b2d52`, the Options stub and the degraded Skin facade met in the same commit
- v1.83.0: carried by `1c098d1` and the re-cuts `3b78cc5`, `5b1191b`, `f799d32`

No tag left a candidate open: each run adopted what it vendored for, so no interview or issue is
owed here.

## Checks

- `libs/LibKa0s` and `tests/_kit` at this bundle's commit are the vendored v1.83.0 of the root
  `CLAUDE.md` provenance line; `tests/test_vendor_sync.lua` passes.
