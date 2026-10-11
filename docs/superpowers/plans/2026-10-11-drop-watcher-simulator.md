# Ka0s Drop Watcher: the simulator (M7) — plan addendum

- **Spec:** `docs/superpowers/specs/2026-10-11-drop-watcher-simulator-design.md`.
- **Extends:** `2026-10-10-drop-watcher-v1.md`, whose rules of the run, execution model and plan data folder
  (`2026-10-10-drop-watcher-v1/`) apply unchanged. That plan stays frozen; M7 is added here and as rows in its
  `items.tsv`, recorded in its `RESUME.md` log.
- **Why:** the owner asked on 2026-10-11, after M6, for an in-game simulation to test with during ongoing development.
  M7 runs before the merge, because nothing in v1 has been smoke-tested in the client yet.

## Items

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-70 | Sim core: `NS.Sim` session state and answer seam in Compat; safety (refusals, auto-stop, stop cleans all); send seam prints `[sim]`; session-only sim history log; stand-down | — | M |
| DW-71 | Item pool from the Encounter Journal (Compat shims, save/restore, async wait, class filter, own-items fallback) and the sim roster and gear generator | DW-70 | M |
| DW-72 | Event drivers: loot lines from `LOOT_ITEM*` into the real loot handler; encounter start/end; restriction and combat edges; simulated inspect replies; own-drop trade windows; simulated trade completion | DW-71 | M |
| DW-73 | Scenarios and timeline (`run`, `step`), the `/dw sim` verbs, `SIM` chip and footer, diagnostics section, `SIM` debug tag; end-to-end scenario suite | DW-72 | M |
| DW-74 | Docs sync for M7 (README Usage, ARCHITECTURE, slash-dispatch, module map, smoke `SIM` theme) and a fresh automated-test bundle (four suites, CCN ≤ 15, no file over 1000 lines) | DW-73 | S |

## Checkpoint

Gate green; the scenario suite passes headless; the bundle is green; independent review fixed; `checkpoint.sh M7`
pushes the branch and notes (the owner authorized pushing on 2026-10-11). Then stop for the merge go-ahead.
