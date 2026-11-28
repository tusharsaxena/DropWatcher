# Execution plan — Ka0s Drop Watcher (2026-11-28, second pass)

Gate after every task (CLAUDE.md): `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua`
(both 0 failed), `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0), and
`python3 -m pytest -q tools/seeds`. Any task that moves the pass count regenerates `docs/test-cases.md`
(`lua tests/run.lua --list > docs/test-cases.md`) and the README badge in the same commit.

## M0: owner rulings (checkpoint, before any code)

- **R-1 (F-002):** drop the golden suite's kernel half (recommended), or keep it as a documented
  deviation with a pin.
- **R-2 (F-005):** confirm the LibKa0s Feed branch takes `DIAG_MINOR = 14` and the next version, as the
  2026-11-28 plan already says.

Done when both are recorded in the run's plan ledger.

## M1: Drop Watcher fixes

| Task | Role | Findings / change | Files |
|---|---|---|---|
| T1 | lua-refactorer | F-001 / C-001 | `core/SkinSetup.lua`, `tests/test_skin_picker.lua`, `docs/test-cases.md`, `README.md` |
| T2 | test-author | F-002 / C-002 (per R-1) | `tests/test_verdict_golden.lua`, `tests/fixtures/verdict_golden.lua`, `tests/test_verdict_setup.lua`, `docs/test-cases.md`, `README.md`, `docs/testing.md` (golden-suite paragraph) |
| T3 | lua-refactorer | F-003 / C-003 | `core/CoreSetup.lua`, `core/DropWatcher.lua`, `core/SkinSetup.lua`, `modules/HistoryRetention.lua`, `modules/LootFeed.lua`, `modules/Pending.lua`, `settings/Schema.lua`, `settings/SchemaSetup.lua`, `tests/test_setup.lua` |
| T4 | ux-cleanup | F-004 / C-004 | `core/DropWatcher.lua`, `modules/Asks.lua`, `locales/enUS.lua`, a messaging test file (`tests/test_asks.lua`), `docs/test-cases.md`, `README.md` |

Done when the gate is green on both profiles and the inventory and badge agree.

### Concurrency map

- T1 and T3 both touch `core/SkinSetup.lua`, so they **must serialize** (T1 first: it rewrites the
  notice section, and T3 then changes `:571`).
- T3 and T4 both touch `core/DropWatcher.lua`, so they **must serialize** (T3 first).
- T1, T2 and T4 each regenerate `docs/test-cases.md` and edit the `README.md` badge, so they
  **serialize on those two files**. Write the code in parallel if you like, but commit one at a time
  and regenerate the inventory last in each.
- No pair of tasks is fully parallelizable at commit time. Order: T1 → T3 → T4 → T2.

### Checkpoint

After T1: the in-client C-001 smoke (`03_SMOKE_TESTS.md`). The combat edge is the only behavior change
a headless run cannot fully show.

## M2: upstream and cross-addon (handoff)

| Task | Repo | Findings | Exit |
|---|---|---|---|
| U1 | LibKa0s (`feat/2026-11-27-feed`) | F-005 | `DIAG_MINOR = 14`, naming Verdict and Feed; release tagged (v1.121.0) |
| U2 | LootHistory | F-005 | re-vendor of that release, whole, as its own commit; provenance line moved |

Drop Watcher's exit for M2 is **no commit**: its copy is the tag's. Its next routine re-vendor picks
up minor 14. If an issue is filed, it goes to LibKa0s, citing this bundle's F-005.

## Commit strategy

One commit per task:

- `T1: the skin notice waits for the combat-end edge, no timer (review 2026-11-28-2 F-001)`
- `T3: re-raise with the stack at the seven pcall sites (F-003)`
- `T4: words for the collectible and badRequest refusals; Preview refuses collectibles (F-004)`
- `T2: the golden suite keeps Drop Watcher's half (F-002, testing-§8)`
