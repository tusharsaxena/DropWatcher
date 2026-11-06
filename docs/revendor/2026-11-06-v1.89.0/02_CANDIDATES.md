# Candidates

Range `v1.88.0..v1.89.0` (base from `CLAUDE.md:45`, 3a). Sources: `git -C ../LibKa0s log --oneline v1.88.0..v1.89.0` (three commits), the tag's `CHANGELOG.md` v1.89.0 block (`CHANGELOG.md:13-34`), and the `Since` markers of every major whose minor moved. No `LibKa0s/` minor moved (01_DELTA 3c), so no major API document changed in this range.

## A. Delivered on the re-vendor alone (not offered)

- **Test kit revision 51, the CallbackHandler unregister guard** (`CHANGELOG.md:21`; `docs/api/testkit/version-51-docs.md`). `mock_ace.lua`'s `Callbacks:unregister` and `unregisterAll` clear an entry only where one exists, so an `Unregister*` of an unregistered target made mid-dispatch no longer raises `invalid key to 'next'` or skips a registrant. "No member moves and no case name changes; a consumer owes only the re-vendor." This addon's headless suite gets the flake fix with no change.

## B. Host change required

None new in this range. Carried forward from the base, and decided by the run's plan (`Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/00_PLAN.md`, *Decisions*):

1. **Widgets 23 cascading rows for the compact Filters ▾** (`submenu`, `radio`, `selected`, `keepOpen`; library `CHANGELOG.md:66`, `docs/api/Widgets/version-23.5.12.6.7.5-docs.md:25-36`). Today Filters ▾ opens a panel holding the four dropdowns, because minor 22 had no submenu rows (`modules/CompactChrome.lua:21-23`, "WHY A PANEL, NOT SUBMENUS"). Minor 23 removes that premise. Files: `modules/CompactChrome.lua`, its tests. Blast radius: **replaces** code the addon owns (the panel frame, its outside-press listener, the dropdown reparenting). The plan's decision: adopt, as `V89A-DW`.
2. **Widgets 23 rows for the History row menu** (`modules/WindowHistory.lua:323-329`, `WH.OpenMenu`, today `NS.Compat.ContextMenu` over the client's `MenuUtil`, one entry, no nesting). Moving it onto `W.ContextMenu` would skin it, but the cascade fields buy nothing for one flat entry. The base bundle recommended *not now* and left it unfiled (`docs/revendor/2026-11-05-v1.88.0/02_CANDIDATES.md:15`). Blast radius: replaces the Compat path, small. **Not named in the plan's decisions table; recorded as undecided** (03_DECISIONS.md).

## C. Whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (new in v1.86.0; no lookup here, 01_DELTA 3e). This addon offers no icon chooser (`docs/ARCHITECTURE.md:14`). Settled by the plan: recorded, no issue.

## Other

- **Toast 4 stack** (v1.88.0): already adopted in the base, `DW-T2` (`a50f465`). Not a candidate.
