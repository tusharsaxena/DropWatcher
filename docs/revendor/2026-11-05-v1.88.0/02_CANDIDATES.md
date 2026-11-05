# Candidates

Sources: `git -C ../#Worktrees/LibKa0s-toast-stack log --oneline v1.85.0..v1.88.0`, the CHANGELOG blocks v1.86.0, v1.87.0 and v1.88.0 at the tag, and the API documents of the majors that moved (Widgets 22 -> 23, Toast 3 -> 4, DebugLog key 22.6.1.4 -> 22.7.1.4, IconBrowser new). No interview was held and no issue was filed (the run's instruction for `DW-T1`); every candidate is listed here instead, and adoption is decided by the run plan (`docs/superpowers/plans/2026-11-05-issues-10-14/items.tsv`).

## Class A: delivered on the copy, no host change

- **A hold drops no payload** (Toast 4; `v1.88.0:CHANGELOG.md:21`, `docs/api/Toast/version-4-docs.md:28`). This addon's combat hold (`Toast.OnCombatStart`, `modules/Toast.lua`) keeps every drop it held.
- **`Attach` before the first `Show`** builds the first frame hidden and wires the control (`CHANGELOG.md:22`, `version-4-docs.md:28`).
- **Diagnostics' `LibKa0s running:` line names `IconBrowser`** (DebugLogDiagnostics minor 7, `CHANGELOG.md:69`). No member moves.
- **Flat menus draw what minor 22 drew** (Widgets 23, `docs/api/Widgets/version-23.5.12.6.7.5-docs.md:22,36`). `W.CloseMenu()`, which this addon calls from `NS.CloseMenu` (`core/WidgetsSetup.lua:89-91`), closes every level.

## Class B: host change required

1. **Toast minor 4's stack** (`CHANGELOG.md:21`; `version-4-docs.md`, descriptor `stack`, `stackGrow`, `stackGap`, instance `SetStack`, `Visible`, `FrameFor`). **Already adopted, as `DW-T2` (`a50f465`).** Listed for the record; nothing to decide.
2. **Cascading `W.ContextMenu` rows: `submenu`, `radio`, `selected`, `opts.check`** (`CHANGELOG.md:44`; `version-23.5.12.6.7.5-docs.md:25-36`). The library's shared menu, now with child levels and a tick column. Files it would touch: `modules/WindowHistory.lua:328` (the History row's right-click, today `NS.Compat.ContextMenu` over Blizzard's `MenuUtil`), `core/WidgetsSetup.lua`, tests. **Recommendation: not now.** The addon's one menu has a single entry and no nesting, so the new fields buy nothing; moving it onto `W.ContextMenu` would be a skinning change of its own, not this release's. Blast radius: replaces code the addon owns (the Compat path), small.

## Class C: whole-module adoption

1. **`LibKa0s-IconBrowser-1.0`** (new at v1.86.0; `CHANGELOG.md:68`; `docs/api/IconBrowser/version-1.1.1-docs.md`). **Recommendation: never, structurally**, as the superseded bundle reasoned: this addon has no setting where the player chooses an icon, and adopting it would ship the whole icon catalog (`all (icon browser).`) for no surface. Blast radius: additive. No recorded decision yet (`gh issue list --search "IconBrowser"` and `grep -rn 'IconBrowser' docs` as of the first `DW-T1`). **Not filed** (no issue filing in `DW-T1`).
