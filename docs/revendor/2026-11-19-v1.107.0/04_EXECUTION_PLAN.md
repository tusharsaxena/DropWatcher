# 04 — Execution plan

No adoption. The re-vendor commit `AF-RV-DW` carries:

- both payloads copied whole from the v1.107.0 extract, then the tag's `tools/prune-icons.lua` (the 32 declared icons kept, the undeclared icons and 362 voice-pack files removed);
- `CLAUDE.md`'s provenance line rolled to v1.107.0, the `LibKa0s icons:` line kept;
- the standard reference refreshed to v2.115.0 (the vendored quirks block in `docs/midnight-quirks.md`, replaced whole);
- this bundle and the v1.106.0 span bundle.

Gate: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` through `ka0s-bounded` (0 failed), `ka0s-bounded luacheck .` 0/0, every Lua file at 1500 lines or fewer.
