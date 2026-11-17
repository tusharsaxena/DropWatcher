# 04 — Execution plan

No adoption in this run (phase [3] owns them). The re-vendor commit `RV-DW` carries:

- both payloads copied whole from the v1.105.0 extract, then the tag's `tools/prune-icons.lua`
  (32 icons declared, the 362 voice-pack files the copy brought back removed);
- `CLAUDE.md`'s provenance line rolled to v1.105.0, the `LibKa0s icons:` line kept;
- `core/DebugLogSetup.lua`: the library-absent stub gains `Report` and `Serialize` (DebugLog 23);
- `core/SkinSetup.lua`: `NS.SKIN_FALLBACK["list.stripe"]` re-copied from Ka0s Default (.08, SkinDefs 28);
- this bundle.

Gate: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` through `ka0s-bounded`
(0 failed, skips unchanged), `ka0s-bounded luacheck .` 0/0, every Lua file at 1500 lines or fewer.
