Delta: LibKa0s v1.107.0 -> v1.108.0

Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit 56c20b76). The tag is local only (`git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing), which is expected: it sits on the library's run branch `feat/2026-11-20-libka0s-94-97-99-100` and the lead pushes it at finalize. Run as item SD-RV-DW of the cross-repo run `feat/2026-11-20-libka0s-94-97-99-100` (Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, plan M2). That run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`; its adoption interview is skipped and no GitHub issue is filed here.

## Step 0 pre-flight
The newest single-tag bundle `2026-11-19-v1.107.0` states base v1.106.0; the provenance line before the commit that vendored v1.107.0 (`d4231e6`) named v1.106.0. `ok`. No correction is owed. (`712bc54` later re-copied the re-cut v1.107.0 under the same tag; it wrote no refresh file, which is that run's record, not this one's.)

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.107.0 (MIT).` before the copy.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 712bc54 (AF-RV-DW, the re-cut v1.107.0); its CLAUDE.md names v1.107.0. They agree.
- `diff -rq --strip-trailing-cr <v1.107.0 extract>/LibKa0s libs/LibKa0s` lists only the undeclared icons and the pruned sounds; `diff -rq <v1.107.0 extract>/testkit tests/_kit` is empty. The payload was v1.107.0's.
- Range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` lists 15 commits.

## 3b/3c Per-file minors that moved
```
Core.lua                  MINOR 18 -> 19
Callout.lua               MINOR 4 -> 5
CalloutSettings.lua       SETTINGS_MINOR 5 -> 6
WaypointArrow.lua         MINOR 2 -> 3
WaypointArrowSettings.lua SETTINGS_MINOR 2 -> 3
Charts.lua                MINOR 2 -> 3
ChartsRender.lua          RENDER_MINOR 1 -> 2
SkinPaint.lua             PAINT_MINOR 19 -> 20
SkinPaintHud.lua          HUD_MINOR 1 -> 2
SkinPaintControls.lua     CONTROLS_MINOR 18 -> 19
Widgets.lua               MINOR 29 -> 30
WidgetsDropdown.lua       DROPDOWN_MINOR 2 -> 3
WidgetsDragHandle.lua     DRAG_MINOR 15 -> 16
WidgetsDragHandleTip.lua  DRAGTIP_MINOR 2 -> 3
WidgetsLineChart.lua      CHART_MINOR 7 -> 8
WidgetsBar.lua            BAR_MINOR 1 -> 2
OptionsCompose.lua        COMPOSE_MINOR 19 -> 20
```
Every other file is at its v1.107.0 minor (3c's loop over the tag's `LibKa0s.xml`). No file is added or removed. No cross-major skew.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s` and `diff -rq <extract>/testkit tests/_kit` are both empty. After the prune, the only differences are `Only in <extract>/LibKa0s/media/icons…` (undeclared icons) and `Only in <extract>/LibKa0s/media/sounds…` (no `LibKa0s sounds:` line, so none ship).

## 3e Consumption
Of the majors that moved, this addon looks up `LibKa0s-Core-1.0` (core/CoreSetup.lua), `LibKa0s-Widgets-1.0` (core/WidgetsSetup.lua: Footer, TestStrip, Dropdown, ContextMenu, SearchBox), `LibKa0s-Charts-1.0` (core/ChartsSetup.lua, an owner and no `barFill`), `LibKa0s-Skin-1.0` (core/SkinSetup.lua, core/Database.lua) and `LibKa0s-Options-1.0` (settings/OptionsSetup.lua; the composers in settings/ComposedRows.lua). It does not consume `LibKa0s-Callout-1.0`, `LibKa0s-WaypointArrow-1.0`, `W.Bar`, `W.DragHandle` or `W.LineChart`: `grep -rn 'LineChart\|W\.Bar(\|ApplyBarFill\|DragHandle\|skinBands' core modules settings` finds no call.

## 3f Kit
`Kit.VERSION` 57 -> 58. Both payloads move together in one commit, as the pairing rule requires.

## 3g Blockers (fixed in the re-vendor commit)
- **OptionsCompose minor 20: every composed swatch gains its companion.** `docs/api/Options/version-38.5.46.3.7.2.9.17.3.1.4.20.13.7.5.8.7.12.1.1.1.4-docs.md` (v1.108.0) against the v1.107.0 document: `O.FontGroup` now emits `fontColorFromSkin` and `fontShadowFromSkin` unasked, and disables Font shadow while its companion is on. settings/ComposedRows.lua's Tables block already wrote `window.tableFontShadowFromSkin` in `extra`, so the composer does not emit it twice (the library's rule); it now dims Font shadow while it is on. The new `window.tableFontColorFromSkin` replaces the sentinel modules/WindowRows.lua kept (a swatch at its default stood for the skin's plain color). Fixed by: the companion's AceDB default `true` (defaults/Profile.lua), its check and tooltip (settings/ComposedRows.lua, locales/enUS_Settings.lua), the reader on the companion (modules/WindowRows.lua `plainColor`), and migration step 14 (core/Database.lua `NS.KeepTableFontColorPick`), which turns the companion off once for a profile that stored a pick, so the pick still draws (skinning-§9, *Every option default follows the skin*: a stored pick stays). `O.BorderGroup`'s new `borderColorFromSkin` is the host's own `extra` row already (`icons.borderColorFromSkin`), so it is not emitted twice.
- **Test kit revision 58: the family checks.** `test_skin_switch` failed two surfaces (a Drops row's text, an Insights card) on "did not change its font", because the headless client had no LibSharedMedia and every skin's face resolved to the same fallback. Fixed with a LibSharedMedia fake in tests/skin_switch_facts.lua, installed through the kit mock's library seam, as skinning-§9 and the kit's revision-58 document advise. `test_skin_values` reported six new hits in the shapes revision 58 reads: the four secondary-stat hues (rows with cause `MC`, the Meaning colors class), `IR.OTHER_FALLBACK` (removed: modules/InsightsRows.lua now reads the host copy `NS.SKIN_FALLBACK["chart.other"]`, held to the library by tests/test_surface_parity.lua) and `RC.Grid`'s `return 1, 0, 0` (a row, category `not a color`).
- Re-pins: tests/test_skin_flip.lua (Font shadow carries the composer's `disabledIf`; Font color, a swatch, does not), tests/test_schema_rows.lua (the new stored path), tests/test_table_font.lua (a pick draws with the companion off).

## 3h Span
Nothing unrecorded: every vendored tag since the store's first bundle has a bundle.

## 3i Icon declaration
Kept unchanged (32 names). The prune refused nothing: it kept the declared icons and removed the undeclared icons and 362 voice-pack files.

## 3j Tests assuming the whole icon folder
None new.
