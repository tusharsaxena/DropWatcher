# Execution plan

## M1: the forced kind (done when C-01 is green and the inventory and badge have moved)

| Task | Role | Implements | Files |
|---|---|---|---|
| T1 | lua-fixer | C-01 / F-001 | `modules/History.lua`, `modules/InsightsFilters.lua`, `tests/test_history.lua`, `tests/test_insights_filters.lua`, `docs/test-cases.md`, `README.md` |
| T2 | docs | C-02 / F-002 | `docs/known-limitations.md`, `modules/InsightsFilters.lua` (header comment only) |

T1 and T2 both touch `modules/InsightsFilters.lua`, so they **must run in that order** (T1, then T2).

## M2: complexity (done when `IF.Period` is split and its tests are unchanged and green)

| Task | Role | Implements | Files |
|---|---|---|---|
| T3 | lua-refactorer | C-03 / F-003 | `modules/InsightsFilters.lua` |

T3 also touches `modules/InsightsFilters.lua`, so it runs after T2.

## Checkpoints

- After M1: the owner runs the C-01 and C-02 smoke steps in the client.
- Before merge: the green gate (`lua tests/run.lua`, bounded `luacheck .`).

## Commits

- `DW-FIN1: A whitelisted item of no kind is recorded as a watched item, and Insights files it under its own kind rather than as a tier token.`
- `DW-FIN1: The Insights legacy note says what the slot fallback reads, not only tier tokens.`
- `DW-FIN1: The Insights period's start is resolved apart from its scan.`
