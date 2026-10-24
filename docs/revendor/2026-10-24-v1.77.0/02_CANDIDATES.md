# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`, the v1.77.0 block of
`../LibKa0s/CHANGELOG.md` at the tag (with its *What a consumer owes* list and its *Consumers
planned at v1.77.0* paragraph), and the API documents it links: Options
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`, Widgets
`docs/api/Widgets/version-15.1.5.3.3-docs.md`, Core `docs/api/Core/version-12-docs.md`, DebugLog
`docs/api/DebugLog/version-21.3.1-docs.md`, Perf `docs/api/Perf/version-15.1.1.9-docs.md`, Sim
`docs/api/Sim/version-2.3.6-docs.md` and the kit's `docs/api/testkit/version-42-docs.md`.

The interview is not run here. The cross-repo bundle
(`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`, its `plan-data/items.json`,
`plan-data/accepted.json` and `inputs/OWNER_SCOPE.md`) decided what this run adopts. Every other
candidate is recorded as deferred (run 2026-10-24), and no GitHub issue is filed.

## A. Delivered on the re-vendor alone

- **Toplevel tool windows that re-raise a shown confirmation** (Core 12 `Core.RaiseStaticPopups`,
  DebugLog 21, PerfPanel 9, SimPanel 6): the debug console, the perf panel and the sim step panel
  raise among their DIALOG peers on a click, and never bury a *Reset all settings* confirmation.
- **Popups clamped to screen** (Widgets 15, WidgetsAutocomplete 3).
- **The id-list suggestion list closes when combat starts** (OptionsIds 3, OptionsCombat 2).

## B. Host change required

| Candidate | Evidence | Decision |
|---|---|---|
| `O.KeybindingsTab` / `O.KeybindRows`: the General > Keybindings tab, with kit `mock_bindings.lua`, `T.assertBindingsXml` and `T.keybindThroughTab` | CHANGELOG v1.77.0 "OptionsKeybinds minor 2" and "minor 3"; testkit `version-42-docs.md` | decided in the cross-repo bundle: adopt (DW-KB) |
| Kit `mock_layers.lua` for the layering suites | CHANGELOG v1.77.0 "Test kit revision 42" | decided in the cross-repo bundle: adopt (DW-ZS) |
| `O.StrataTooltip(values[, strings])` on a player strata row | CHANGELOG v1.77.0 "OptionsCompose minor 8"; Options `version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` | deferred (run 2026-10-24). The library's planned adopters are AuraMaster, MultiMeters, PanelMaster and PartyFrameEnhanced. This addon has no player strata row. |
| WidgetsDragHandle `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha` | CHANGELOG v1.77.0 "WidgetsDragHandle minor 5"; Widgets `version-15.1.5.3.3-docs.md` | deferred (run 2026-10-24). This addon builds no DragHandle, and it is not among the planned adopters. |
| `Core.RaiseStaticPopups()` called from a host window's own `OnShow` | CHANGELOG v1.77.0 "Core minor 12"; Core `version-12-docs.md` | deferred (run 2026-10-24), unless DW-ZS's accepted strata changes name it. |

## C. Whole-module adoption

None. Every major in the payload is already looked up here (`01_DELTA.md` 3e). OptionsKeybinds is a
twelfth file of the Options major this addon already consumes, not a new major.
