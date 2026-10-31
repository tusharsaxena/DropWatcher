# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`, the CHANGELOG's v1.84.0 block, and the moved majors' `docs/api/` documents.

## A. Reached the addon on the copy, nothing to adopt

- The peels (`SkinOwnerTokens`, `SkinDefsOthers`, `SimPanelRender`, `OptionsSkinPickerRows`, `OptionsIdSuggest`, `OptionsFlow`, `OptionsTabbed`, kit `mock_ace.lua`): pure moves. `LibKa0s.xml` loads the new files, and `tests/test_harness.lua` reads that list.
- Both Options reset walks and `/list` skip a `note`, and `O.ClearScroll` keeps the band's refresher.
- `WidgetsDragHandle` minors 9 and 10: delivered, unused here, since this addon calls no `DragHandle`.
- `DebugLogDiagnostics` minor 6: the identity header names Charts.

## B. Host change required

| Candidate | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|
| `opts.beforeGroup` / `opts.afterSubgroup` | CHANGELOG v1.84.0, OptionsFlow minor 2 | `settings/Pages.lua` | Decline: `afterGroup` and `pairWith` cover every page today | Additive |
| `note` row | CHANGELOG v1.84.0, OptionsFlow minor 2 | `settings/PageEditors.lua` | Decline: the Quality tab's closing lines repaint with the page and carry live text | Replaces |
| `O.PositionBlock` | CHANGELOG v1.84.0, OptionsCompose minor 15 | none today | Decline: no X and Y rows on a settings page | Additive |
| `O.PageBanner{ acts }` | CHANGELOG v1.84.0, OptionsTabs minor 13 | `settings/Pages.lua` | Decline: no page wants banner buttons | Additive |

## C. Whole-module adoption

| Candidate | Evidence | Recommendation | Blast radius |
|---|---|---|---|
| `LibKa0s-Charts-1.0` | `docs/api/Charts/version-1.1-docs.md` | Decline: this addon draws no chart | Additive |
