# Audit and review fixes: plan (2026-11-28)

**Spec:** `docs/superpowers/specs/2026-11-28-audit-review-fixes-design.md`.
**Branch:** `feat/2026-11-28-audit-review` (Drop Watcher). Tasks run in order in one checkout, one
commit or more each, each gated (Retail and Forever 0 failed, luacheck 0/0, `pytest tools/seeds`,
all through `ka0s-bounded`); `docs/test-cases.md` and the README Tests badge move in the commit
that moves the count. Push after B5 and after D1; no merge without the owner's go-ahead.

**Resume:** read the ledger; the first row not `done` is next; `git log master..HEAD` confirms.

## Ledger

| Task | What | Findings | Status | Commit |
|---|---|---|---|---|
| U | File upstream issues; relabel DW#19 | U-1, U-3, U-4, U-5, U-6, F-005, DRW-18 | todo | |
| A1 | Docs and metadata: TOC comments, README keybinding sentence, compat count, §17 re-check note, README-H1 register row, `.pkgmeta`, v1.120.0 re-vendor bundle | DRW-12, -14, -07, -11, -13, -17, -16 | todo | |
| A2 | Hub split: Event Subscriptions -> data-flow.md, Skins + Tooltip placement -> docs/skins.md, map registered, anchors fixed | DRW-03 | todo | |
| B1 | Skin notice: no timer, held flag, two tests | F-001 | todo | |
| B2 | `NS.Rethrowable` at the seven rethrow sites, test names the handler | F-003 | todo | |
| B3 | Refusal wording, localized fallback, Preview refuses collectibles, two tests | F-004 | todo | |
| B4 | Disabled suite step 5 captures F_on; stand-in popup SetToplevel + test | DRW-04, DRW-15 | todo | |
| B5 | Golden suite: kernel half and fixture table dropped, view tests added | F-002 | todo | |
| C1 | Split `modules/LootFeed.lua` below its trigger (TOC, load-order test, docs) | DRW-19 | todo | |
| C2 | Split `tests/test_test_mode.lua` | DRW-19 | todo | |
| D1 | Close-out: docs sync, automated-test bundle + RESULTS.md with watch-list rulings, gate, push | DRW-10, DRW-19 | todo | |
| G | Owner go-ahead, merge, cleanup (branch, stashes, worktrees) | | todo | |
