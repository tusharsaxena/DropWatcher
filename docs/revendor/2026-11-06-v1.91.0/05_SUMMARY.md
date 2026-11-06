# 05 — Summary (LibKa0s v1.90.0 -> v1.91.0)

Item `FU-RV-DW` of `Ka0sAddonsCommonTasks/docs/2026-11-06-FOLLOWUPS_V1_91/`.

- **Tag:** v1.90.0 -> v1.91.0 (`55bfbb4`, a local tag, not yet pushed). The base, v1.90.0, is the provenance line's, and it agrees with the last payload commit `78520b7` (`01_DELTA.md` 3a).
- **Minors moved:** Core 16 -> 17, SkinPaintExtras 18 -> 19, Widgets 25 -> 26, WidgetsLineChart 6 -> 7. New files: CorePixel 1, SkinPaintHud 1, SkinAceConfirm 1, WidgetsDropdown 1. The other 63 files are unchanged. No cross-major skew. Kit revision 51 on both sides.
- **Step 0:** skipped as the item directs (the installed skill's roster regex matches nothing; fixed upstream in this run). Checked by hand for this addon: ok.
- **Span bundle / base correction:** none. 3h lists no unrecorded tag.
- **Delivered for free (class A):** the line chart's axis, grid, markers, crosshair and series in physical pixels (this addon draws no line chart, so no visible change), and the four band-file peels, which are pure moves.
- **Contract blockers:** none (`01_DELTA.md` 3g). `tests/loader.lua` reads the library file list from `LibKa0s.xml`, so the four new files load in XML order with no edit; no test pins a moved minor; no stub mirrors a moved member.
- **Icons:** the `LibKa0s icons:` line is kept unchanged (32 names, all Open Iconic). After the whole-tag copy, the tag's `tools/prune-icons.lua` printed `32 icon(s) declared; kept 33 file(s), removed 5807`. The icon set is the same as at v1.90.0. No provenance split was needed.
- **README credits:** unchanged, because the shipped sets did not change. **Dead stub mirrors:** none.
- **Refresh file:** none. This is a new tag for this addon.
- **Adopted:** nothing. **Declined:** nothing. No issue was filed, as the item directs.
- **Skipped / unreached:** none.
- **Gate (after the copy and prune):** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 241 files; `ka0s-bounded lua tests/run.lua` 2239 passed, 0 failed, 1 skipped (2240 total). No addon Lua changed, so the largest own file (`modules/WindowCells.lua`, 1177 lines) and the CCN 15 picture stay where v1.90.0 left them. The complexity suite is a release check and was not run here.
