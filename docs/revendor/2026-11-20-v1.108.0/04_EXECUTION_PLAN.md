# 04 — Execution plan

No adoption. The re-vendor commit `SD-RV-DW` carries:

- both payloads copied whole from the v1.108.0 extract, then the tag's `tools/prune-icons.lua` (the 32 declared icons kept, the undeclared icons and 362 voice-pack files removed);
- `CLAUDE.md`'s provenance line rolled to v1.108.0, the `LibKa0s icons:` line kept;
- the blockers' fixes in `01_DELTA.md` 3g, with their tests (tests/test_table_font.lua, tests/test_database.lua's step 14 case, the re-pins);
- the standard reference refreshed to v2.116.0 (the vendored quirks block in `docs/midnight-quirks.md`, its stamp moved; the catalog text is unchanged since v2.115.0);
- this bundle.

Gate: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` through `ka0s-bounded` (0 failed), `ka0s-bounded luacheck .` 0/0, every Lua file at 1500 lines or fewer.
