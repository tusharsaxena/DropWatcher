# 05 — Summary (LibKa0s v1.89.0 -> v1.90.0)

Item `SF1-RV-DW` of `Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`, from the owner's first smoke feedback (`SF1_SMOKE_FEEDBACK.md`).

- **Tag:** v1.89.0 -> v1.90.0 (`4485b8f`, a local tag, not yet pushed). The base, v1.89.0, is the provenance line's, and it agrees with the last payload commit `1a32aec` (`01_DELTA.md` 3a).
- **Minors moved:** Core 15 -> 16, Skin 16 -> 17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18, Widgets 23 -> 24, WidgetsAutocomplete 7 -> 8, OptionsAppearance 6 -> 7. The other 60 files are unchanged. No cross-major skew. Kit revision 51 on both sides.
- **Span bundle / base correction:** none. Step 0 reads ok, and 3h lists no unrecorded tag.
- **Delivered for free (class A):** every `W.Dropdown`, `W.SearchBox`, shared-menu (cascade levels included) and autocomplete edge is one physical pixel at any UI scale and sub-pixel position. This covers the filter bar's dropdowns and search box, the compact Filters cascade and the History row menu, and it fixes the owner's feedback item 4 (DropWatcher's dropdown edge measured 2 px on top and 1 px on the bottom).
- **Contract blockers:** none (`01_DELTA.md` 3g). No host-supplied member moved, and the addon calls `SetBackdrop` on no library control.
- **Icons:** the `LibKa0s icons:` line is kept unchanged (32 names, all Open Iconic). After the whole-tag copy, the tag's `tools/prune-icons.lua` printed `32 icon(s) declared; kept 33 file(s), removed 5807`. The tree's icon set is the same as at v1.89.0, because the tag adds no icon. No provenance split was needed.
- **README credits:** unchanged, because the shipped sets did not change. **Dead stub mirrors:** none.
- **Refresh file:** none. This is a new tag for this addon, so it is not a refresh.
- **Adopted:** nothing. **Declined:** `RegisterOwner` `keepScope`, not taken per the run's record (`03_DECISIONS.md`). No issue was filed, as the item directs.
- **Skipped / unreached:** none.
- **Gate (after the copy and prune):** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 241 files; `ka0s-bounded lua tests/run.lua` 2239 passed, 0 failed, 1 skipped (2240 total). No addon Lua changed in this commit, so the largest own file (`modules/WindowCells.lua`, 1177 lines) and the CCN 15 picture stay where v1.89.0 left them. The complexity suite is a release check and was not run here.
