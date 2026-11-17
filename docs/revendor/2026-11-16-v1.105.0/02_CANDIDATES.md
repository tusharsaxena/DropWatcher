# 02 — Candidates: LibKa0s v1.103.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.103.0..v1.105.0` (33 commits), the CHANGELOG blocks
v1.104.0 and v1.105.0 at the tag, and Ka0sAddonsCommonTasks
`docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md`. By that run's design (section 5) the
adoption interview is skipped and no GitHub issue is filed here: every class B and C item below is
**owed in phase [3]**, tracked by the LibKa0s issue named.

## Class A: reached the addon on the re-vendor alone (delivered, not offered)
These are the visible changes, and each is a smoke line (`06_SMOKE_TESTS.md` of the run):
- **Skin colors (#82, #84).** Ka0s Default's rows (stripe .08, hover .16, selection .26); seven skins'
  `icon.hot`; Glass's and High Contrast's `icon.tint`.
- **Header marks on the library's windows (#86).** The debug console, copy window, perf panel, sim
  panel and skin picker carry extras, settings and close on their title band; the settings mark opens
  this addon's settings (the launcher registers the opener).
- **The console (#79, #90).** Its status line is a 24 px Widgets footer; Copy hands out plain text.
- **The library's own tooltips (#92)** go through `LibKa0s-Tooltip-1.0`: dropdown entries, the sim
  panel's controls and step rows, Charts' default tooltip (beside `host.group`; the Insights charts use
  the default hover, `core/ChartsSetup.lua:11`), and the minimap button's tooltip.
- **The Callout pair moves forward** to 4 / 5 (unconsumed here).

## Owed in phase [3] (class B: host change required)
1. **#79 `D:Report` / `D:Serialize`:** move the report verbs onto the seam. The adoption plan names
   `scan`; confirm `history`, `insights`, `situation` and `rolls` against their handlers
   (`settings/Slash.lua`).
2. **#92 tooltip placers:** this addon's own `GameTooltip:SetOwner` sites move to
   `PlaceBeside`/`PlaceAttached`: `modules/RollsPanel.lua:358`, `modules/Window.lua:243` (its
   `ANCHOR_BOTTOM` fallback), `modules/WindowGroup.lua:458`.
3. **#86 `W.HeaderButtons`:** this addon's own windows (`modules/WindowTitleBar.lua`, the detail card,
   the Offer panel, the Rolls panel) put their title marks on the strip, with a settings mark.
4. **#87 `Sim.Sample(client)`:** the shared sample characters replace the addon's own sample names;
   the seeded crowd lists stay (adoption plan).
5. **#82 host owner tokens:** check the addon's own `*.hot` aliases against the new contrast floors.

## Class C: whole-module candidates
6. **#85 Callout:** the adoption plan's recommendation for this addon is **not now**.
7. **Tooltip major** is item 2. WaypointArrow and IconBrowser: settled in earlier bundles, unchanged.

## Not this addon's
#80 (`W.Bar`) and #81 (`extraEntries`) are Skill Master's by the owner's ruling Q1. #88 and #89
(docked strips, `W.Footer`) are already done here (v1.103.0 bundle).
