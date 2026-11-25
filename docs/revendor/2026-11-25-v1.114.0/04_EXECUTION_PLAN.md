# 04 — Execution plan

1. **The re-vendor commit (SF-DW-01):** both payloads copied whole from the v1.114.0 extract, then the tag's `tools/prune-icons.lua` (the 32 declared icons kept; the undeclared icons and 362 voice-pack files removed); `CLAUDE.md`'s provenance line rolled to v1.114.0, the `LibKa0s icons:` line kept; this bundle and the span bundle. README credits unchanged (Open Iconic and Phosphor still ship).
2. **Characterization (SF-DW-01):** a case pinning the detail card's painted header chips as exactly `DC.Chips(drop)`, before the card is touched.
3. **The adoption (SF-DW-01):**
   - `core/ForeverDBSetup.lua`, the seam: `NS.ForeverDB`, the library or its all-absent stand-in, held to the library by a parity case;
   - `modules/ItemSources.lua`: the pure model and chip (the top three sources merged over creatures, objects and containers, most likely first; the world-drop level; up to three vendors), and the gated reader (`C.FEATURE.itemSources`, WoW Forever alone; `window.itemSources`, default on; `Available()` first, so the first card opened is what loads);
   - `modules/DetailCard.lua`: the header gains the Sources chip, last, kept when the chips are full;
   - the setting row on Window > Layout > Detail card (Forever only), its tooltip saying it needs ForeverDB;
   - `## OptionalDeps` gains `ForeverDB`, `.pkgmeta` gains `optional-dependencies: forever-db`;
   - tests on the kit's `mock_foreverdb` with `present`, `missing`, `reshaped` and `loadfails`, and a Retail-profile case proving it inert;
   - the perf note, the smoke rows, the docs and the regenerated `docs/test-cases.md`.

Gate at each commit: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` through `ka0s-bounded` (0 failed), `ka0s-bounded luacheck .` 0/0, `python3 -m pytest -q tools/seeds`, every Lua file at 1500 lines or fewer.
