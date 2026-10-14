# Final summary: Ka0s Drop Watcher review (2026-10-14)

*This summary assumes every check in `03_SMOKE_TESTS.md` has passed and every task in
`04_EXECUTION_PLAN.md` has landed.*

## Headline

This cycle made the disabled-state conformance test able to fail. It also closed an announce path
that confirmed messages that were never sent, stopped one faulty module from silencing the others on
a shared game event, and made the perf report say truthfully which timings overlap. Smaller cleanups:
the English catalog became complete, the compat seam became lint-enforced, and the "addon is off"
refusal became a single string.

The test kit, the perf library, the standard and the review tooling were fixed in their own
repositories and re-vendored here, so every Ka0s addon gets the same fixes.

## Counts

Critical fixed: 0, High fixed: 0, Medium fixed: 8, Low fixed: 4. Nothing was deferred.

## Changes by theme

### A. A conformance test that can fail
- **What changed:** "disabled 3" now drives every declared handler, and after the kit fix fires every
  registered event, asserting each reached a handler. It checks for zero writes, prints and shows.
- **Why it mattered:** it asserted on silence and could not go red.
- **Findings:** F-001, F-009, F-011. **Changes:** C-01, U-1, U-3.
- **Files:** `tests/test_disabled.lua`; `tests/_kit/**` (re-vendor).

### B. One announce rule
- **What changed:** a fixed announce channel is used only where the player has that group.
- **Why it mattered:** a refused post read as sent and locked out retries for the session.
- **Findings:** F-002. **Changes:** C-02.
- **Files:** `modules/Asks.lua`, `tests/test_asks.lua`.

### C. Isolated shared events
- **What changed:** each handler of a shared event runs even if an earlier one raises, and the first
  error is still reported.
- **Why it mattered:** one bug could silently disable the roster, inspect and ask upkeep.
- **Findings:** F-003. **Changes:** C-03.
- **Files:** `core/DropWatcher.lua`, `tests/test_setup.lua`.

### D. Truthful perf nesting
- **What changed:** `evaluate` and `quality.gate` declare `within = "feed.add"`, and their call sites
  report where they actually ran.
- **Findings:** F-004, F-010. **Changes:** C-04, U-2.
- **Files:** `core/PerfSetup.lua`, `modules/LootFeed.lua`; `libs/LibKa0s/**` (re-vendor).

### E. Seam and lint
- **What changed:** `Compat.IsAddOnLoaded` was added, and lint now confines the world reads to the
  Compat family.
- **Findings:** F-006. **Changes:** C-06.
- **Files:** `core/CompatWorld.lua`, `core/DropWatcher.lua`, `modules/Diagnostics.lua`, `.luacheckrc`.

### F. Text and naming
- **What changed:** `enUS.lua` lists every routed string, enforced by a gate case. The stranded doc
  block was moved. Disabled refusals use the dispatcher's line.
- **Findings:** F-005, F-007, F-008. **Changes:** C-05, C-07, C-08.
- **Files:** `locales/enUS.lua`, `tests/test_locale.lua`, `core/DropWatcher.lua`,
  `modules/TradeHelper.lua`, `modules/DetailCard.lua`.

### Tooling (no addon file)
- **What changed:** the cross-addon slash census reads constant-registered roots.
- **Findings:** F-012. **Changes:** U-4.

## API and behavior changes

- **Announce channel.** A fixed channel (Instance, Raid or Party) now refuses with the existing
  `noChannel` line when you lack that group, instead of attempting the post.
- **Disabled refusals.** While disabled, Ask, Offer and Announce print the dispatcher's
  `Ka0s Drop Watcher is disabled — enable it with /dw enable` line.
- **New Compat member:** `NS.Compat.IsAddOnLoaded`.
- **Locale keys.** 722 added to `enUS.lua`. `Drop Watcher is disabled.`, `The addon is disabled.` and
  `the addon is disabled` retired. `%s is disabled.` and `%s is disabled` added.
- No slash verb, setting, default or SavedVariables shape changed.

## Saved-variable and migration notes

None. The schema stays at v7.

## Deprecated-API migrations

None. `C_AddOns.IsAddOnLoaded` was already the modern API. It moved behind Compat.

## Performance impact

The only perf-tagged change is C-04, an instrumentation-truth fix. The offline pairs
`refreshCaptureOff` / `On` and `parseCaptureOff` / `On` must still match. The before figures are
14240.8 / 14240.8 and 664.2 / 664.2 B/iter (2026-10-14, `tests/perf.lua`). The after figures come
from the post-M3 run, and the in-client capture C-04 records under `docs/perf-analysis/`.

## Test and complexity movement

- **Pass count:** 1402 → 1410, plus any kit self-cases the U-1 re-vendor adds. The final `--list`
  states the exact number.
- **Inventory and badge:** `docs/test-cases.md` and the README badge moved in each counting commit.
- **Complexity:** no watch-list entry is expected to move. `DW:OnSharedFeatureEvent` gains about two
  decisions. Confirmed at the next release's regeneration.

## Known follow-ups

- **The other 13 roster addons need the same re-vendor**, so classes 2 and 3 return to one line.
  This is the normal sweep after a LibKa0s release.
- **The client's exact reply to a refused channel** (F-002) is confirmed by ANN-1 in client. The fix
  does not depend on it.

## Verification evidence

- `03_SMOKE_TESTS.md`, with its sign-off table filled.
- The commit range of `feat/2026-10-14-drop-watcher-review-audit` (DW-R0..DW-R9), plus the upstream
  PRs in LibKa0s, WowAddonStandards and dev-copilot.

## Suggested PR description

```
Review 2026-10-14: falsifiable disabled test, announce channel guard, isolated shared events

- F-001 disabled 3 drives every declared handler and fires R_on through the kit (was vacuous)
- F-002 a fixed announce channel needs its group, else noChannel (no false "Announced")
- F-003 each shared-event handler isolated; the first error re-raised after all ran
- F-004 evaluate / quality.gate declared and observed within feed.add (LibKa0s Perf 15)
- F-005 enUS.lua is the complete catalog, gated by test_locale
- F-006 Compat.IsAddOnLoaded; world reads fenced to core/Compat*.lua in .luacheckrc
- F-007 SetTestMode doc block moved; F-008 one disabled refusal string
- Re-vendor LibKa0s (kit 39: __fireUnconditional reaches method handlers; Perf 15: top-level observation)

Upstream: LibKa0s (F-009, F-010), WowAddonStandards slash-commands-§7 step 6 (F-011),
dev-copilot class-1 census (F-012).
Tests 1402 -> 1410 (+ kit self-cases); luacheck 0/0.
```
