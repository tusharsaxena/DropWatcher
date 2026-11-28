# Fix pass — 2026-11-28 review

Task `IS-F1` of the plan `docs/superpowers/plans/2026-11-27-itemsearch-split.md`, Drop Watcher's
half. Each finding was checked against the code before it was acted on; the two behavior fixes were
test-first (a `red under:` case seen failing, then green). Before the fixes, `libs/LibKa0s/` and
`tests/_kit/` were re-vendored whole from the LibKa0s release branch at `37bc229b` (its own F1 fix
pass; still v1.119.0, untagged), commit `IS-F1: re-vendor LibKa0s branch HEAD`, where the
library-absent stand-in gained the instance's new `Events`. The five files above are as the reviewer
wrote them; this note is the only file added.

| Finding | Outcome | Commit |
|---|---|---|
| F-001 | **Open, upstream.** Two LibKa0s branches both open v1.119.0 with `DebugLogDiagnostics` minor 13; the renumbering is LibKa0s's at G1 (the second branch to merge takes the next version and minor 14), then its consumer re-vendors | — |
| F-002 | **Header fixed; the rest rejected.** The header no longer says nothing is reimplemented. The breadth is not a defect: testing-§11 says a ref that cannot be resolved is a skip carrying its reason, never a failure, so a mistyped tag skipping is the standard's own rule, and the shim is no deviation (no register row). The kit failing instead is F-012 | `IS-F1.5` |
| F-003 | **Open for the owner.** Confirmed: 50 of the library's 53 reads resolve to a same-named `NS.Compat` member, by design (C1: every read through `NS.Compat` so the simulator's seam guards it, and the role override's `PlayerRole`). Removing the duplicates needs the seam to wrap the instance's reads instead, a design ruling across LibKa0s-Sim and LibKa0s-Verdict; a parity test over 50 reads is the other way. Neither is a local fix | — |
| F-004 | **Open for G1 / the owner.** The kernel half of the golden suite is the plan's move-time cross-check (C1 step 3); dropping it, or pinning its fixture to the library's at the provenance tag, waits on the tag. The views' members only the suites call (the kernel mirrors, `NS.ClassData.Install`, `NS.Gear.OffSpecGear`, `NS.Gear.IsScheduled`) are not in testing.md's seam table and go with that ruling | — |
| F-005 | Fixed: `seed` split as the library split its copy. The three older functions over CCN 15 (`RT.FlushOverlaps` 20, `buildMembers` 19, `RC.Left` 17) predate the branch and stay for the release | `IS-F1.1` |
| F-006 | **Confirmed, deferred.** `apply` can only refuse; its WEAPONS writer belongs with the class-list seed contract, which moves to LibKa0s (C1 builder note 7), not deleted here first | — |
| F-007 | Fixed: `Signature`, `Read`, `Schedule`, `OnEvent`, `OnCombatEnd` removed; the two gear cases that reached two of them (the review's census missed `tests/test_gear.lua:519`, `:646`) drive the instance instead | `IS-F1.2` |
| F-008 | **Rejected:** a documented suite seam (module-map.md row 33, "`Install(list)` for the suites"); no shipped caller, and the suites that use it judge the kernel alone. Its listing goes with F-004 | — |
| F-009 | Host half fixed: the host's perf is `NS.Perf` itself, a plain `on` field; new case. The per-verdict opts table is **rejected for now**, unmeasured (no judge scenario). `PerfStart`'s colon method is upstream | `IS-F1.3` |
| F-010 | Fixed: the settings category registers before the engine stands up, and the re-raise keeps its traceback (`xpcall`); new case | `IS-F1.4` |
| F-011 | **Rejected:** schema steps are append-only history, and the owner's development SavedVariables do carry the data; dropping a step would strand those at a middle version. No player cost | — |
| F-012 | **Open, upstream** (LibKa0s kit or WowAddonStandards): the kit fails an unresolvable ref where testing-§11 says skip | — |

Gate at the last fix commit: Retail 2671 passed / 0 failed / 8 skipped, WoW Forever 2558 / 0 / 116,
luacheck 0/0 in 263 files, `pytest tools/seeds` 22 passed. Inventory and README badge 2671.
