# 03 — Decisions

The owner made every decision below before this re-vendor, in the cross-repo bundle
`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/` (`plan-data/items.json`,
`plan-data/accepted.json`, `inputs/OWNER_SCOPE.md`). DW-RV's item spec says: "do NOT interview;
the adoptions this run needs are the DW-KB and DW-ZS items, so record every other candidate as
'deferred (run 2026-10-24)' in the bundle and file nothing". The interview did not run, and no
GitHub issue is filed.

| Candidate | Decision | Owner / reason |
|---|---|---|
| `O.KeybindingsTab` / `O.KeybindRows`, kit binding mock and checks | adopt | DW-KB (item 015) |
| Kit `mock_layers.lua` | adopt | DW-ZS (item 030), held for the owner; launched later |
| `O.StrataTooltip` | deferred (run 2026-10-24) | no player strata row here |
| WidgetsDragHandle `level` / `ApplyLevel` / `ignoreParentAlpha` | deferred (run 2026-10-24) | no DragHandle here |
| Host `Core.RaiseStaticPopups()` | deferred (run 2026-10-24) | DW-ZS's accepted list decides |

The four Options stub members are a blocker fix, not a decision (`01_DELTA.md`, 3g).
