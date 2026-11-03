Delta: LibKa0s v1.84.0 -> v1.85.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` (FS-DW-RV). The tag is local, at `9776130`, cut by that run's `FS-REL`.

## Base (3a)

`grep -n '[Bb]undles' CLAUDE.md` named v1.84.0, the line the last payload commit (`1a39eca`) left. Newest single-tag bundle `2026-10-31-v1.84.0` states base v1.83.0, which is the addon's history. No correction owed.

## Per-file minors (3c), moved files only

`for f in LibKa0s.xml files: grep the [A-Z_]*MINOR constant, old against tag`

| File | old | new |
|---|---|---|
| Glow.lua | 1 | 2 |
| Toast.lua | 1 | 2 |
| Skin.lua | 11 | 14 |
| SkinDefs.lua | 19 | 24 |
| SkinDefsOthers.lua | 1 | 6 |
| SkinPaint.lua | 13 | 16 |
| SkinPaintExtras.lua | 7 | 15 |
| SkinPaintControls.lua | 11 | 14 |
| SkinEUI.lua | 2 | 3 |
| SkinAce.lua | 6 | 9 |
| Widgets.lua | 17 | 20 |
| WidgetsReorder.lua | 3 | 5 |
| WidgetsDragHandle.lua | 10 | 12 |
| WidgetsLineChart.lua | 5 | 6 |
| WidgetsAutocomplete.lua | 5 | 6 |
| WidgetsCopyWindow.lua | 2 | 4 |
| DebugLogWindow.lua | 2 | 3 |
| Launcher.lua | 5 | 6 |
| OptionsWidgets.lua | 41 | 44 |
| OptionsIds.lua | 6 | 7 |
| OptionsIdList.lua | 7 | 8 |
| OptionsTabs.lua | 13 | 15 |
| OptionsCompose.lua | 16 | 17 |
| OptionsScroll.lua | 10 | 13 |
| OptionsNav.lua | 4 | 5 |
| OptionsDrawer.lua | 4 | 5 |
| OptionsKeybinds.lua | 6 | 7 |
| OptionsAppearance.lua | 5 | 6 |
| OptionsSkinPicker.lua | 5 | 7 |
| OptionsMedia.lua | 3 | 4 |
| PerfPanel.lua | 11 | 12 |
| SimPanel.lua | 9 | 10 |
| SimPanelRender.lua | 1 | 2 |

No file is behind the old tag: no cross-major skew.

## Kit (3f)

`grep -n 'Kit.VERSION'`: revision 47 -> 49. The two payloads move together.

## Consumption (3e)

Lookups outside `libs/` and `tests/`: Bus, Charts, Compat, Core, DebugLog, Env, Glow, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Sim, Skin, Slash, Toast, Widgets. Unchanged.

## Blockers (3g, 3j)

- **Facade:** `core/SkinSetup.lua`'s degraded arm owes `Mark`, `MarkText`, `HudTextColor`, `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont`. `tests/test_surface_parity.lua` holds it to the live facade. Added in the re-vendor commit; `MarkText` answers plain markup and `HudFont` draws.
- **Options stub:** `settings/OptionsSetup.lua` owes `H.LabelFont`. Added in the re-vendor commit.
- **Icons (3j):** the tests that open icon files open declared names only. No loop over the catalog.

## Icons (3i)

Decided by the plan and `docs/releasing.md` (Step 8 for v1.85.0): the line owes `chevron-down, chevron-up, close, confirm, info, move, reset, volume-high`. The line already held six; `move` and `volume-high` join it. Hand lists have drifted before, and the owner's in-client smoke is the backstop.

## Tags vendored and unrecorded (3h)

None. No span bundle.
