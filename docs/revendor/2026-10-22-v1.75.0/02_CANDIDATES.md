# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.72.0..v1.75.0`, the v1.73.0, v1.74.0 and v1.75.0 blocks
of `../LibKa0s/CHANGELOG.md` at the tag (each with its *What a consumer owes* list), and the API
documents those blocks link: Options `version-29.2.34.2.5.9.1.7.4.2.1-docs.md`, Widgets
`version-13.1.4.3.2-docs.md`, Item `version-3-docs.md`, Media `version-5.1-docs.md`, Glow
`version-1-docs.md`, Sim `version-1.1.1-docs.md`, testkit `version-41-docs.md`.

The interview is not run here. The cross-repo bundle
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`, its `items.tsv` and
`inputs/OWNER_SCOPE.md`) decided every candidate in advance, and the run files no GitHub issue in
this milestone. Each adoption is its own later item.

## A. Delivered on the re-vendor alone

- **Options 29: a structural refresh keeps the page's scroll offset.** The editors and Profiles
  pages re-render in place without jumping to the top.
- **Core 11, DebugLog 20, OptionsIdList 5, PerfPanel 7: corrected comments only.**
- **DebugLogDiagnostics 3:** the report's `LibKa0s running:` line names Glow and Sim once they load.
- **Kit 41:** a crashed lizard run is a fail with its files named (`crashedFiles`), never 58 blind
  files; the icon gate holds the copy to the declaration.

## B. Host change required

| Candidate | Evidence | Decision |
|---|---|---|
| `W.SearchBox` (Widgets 13) | CHANGELOG v1.75.0 "Widgets minor 13: W.SearchBox (#52)"; Widgets `version-13.1.4.3.2-docs.md` | decided in the cross-repo bundle: adopt (DW-01..DW-09) |
| `W.TestStrip` (Widgets 13) | CHANGELOG v1.75.0 "Widgets minor 13: W.TestStrip (#48)" | decided in the cross-repo bundle: adopt (DW-01..DW-09) |
| launcher-§6 binding | the cross-repo bundle's items.tsv | decided in the cross-repo bundle: adopt (DW-01..DW-09) |
| `Item.BonusIDsFromLink` (Item 3) | CHANGELOG v1.75.0 "Item minor 3"; Item `version-3-docs.md` | not adopted in this run: OWNER_SCOPE A.#51 names BankLedger and LootHistory only; this addon keeps its own modifier walk |
| `O.Drawer` (Options 29, OptionsDrawer 1) | CHANGELOG v1.73.0 "OptionsDrawer minor 1: the drawer" | not adopted in this run: no consumer need on this addon's pages (the stub gains the no-op, `01_DELTA.md` blocker 1) |
| `Media.ICON_SETS`, `Media.IconAuthor` (Media 5) | CHANGELOG v1.74.0 "Media minor 5 and MediaIcons minor 1" | not adopted in this run: this addon has no icon chooser and ships no Game-icons mark |
| `Kit.assertLatchHoldOrder` (kit 39) | `testkit/latch.lua`; testkit README | not adopted in this run: no new latch case is owed by this run (DW-P25 already took the reach count) |

## C. Whole-module adoption

| Candidate | Evidence | Decision |
|---|---|---|
| `LibKa0s-Glow-1.0` | CHANGELOG v1.75.0 "LibKa0s-Glow-1.0 (new major)"; Glow `version-1-docs.md` | decided in the cross-repo bundle: adopt (DW-01..DW-09) |
| `LibKa0s-Sim-1.0` and its private step panel | CHANGELOG v1.75.0 "LibKa0s-Sim-1.0"; Sim `version-1.1.1-docs.md` | decided in the cross-repo bundle: adopt (DW-01..DW-09) |
