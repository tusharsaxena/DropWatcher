# 02 — Proposed changes

These changes were checked against **WowAddonStandards v2.121.0** (2026-11-25), fetched over the network. The sibling `../WowAddonStandards` checkout lagged origin (`b83f039c` vs `e23dcd5f`), so it was not used. Finding IDs refer to `01_FINDINGS.md`.

## HLD

### Theme A: release-coordinate LibKa0s v1.119.0 before tagging (F-001, F-002, F-012)

Two LibKa0s branches open `v1.119.0` and both take DIAG minor 13. The fix is a sequencing decision at task G1, not code here:

1. Merge one branch.
2. Renumber the other to the next semver, with DIAG minor 14 listing both `Verdict` and `Feed`.
3. Re-vendor whichever consumer ends up on the renumbered tag.

Until then, the vendor-sync shim must say exactly what it is waiving, and must be on the register.

- **Rejected: edit `libs/LibKa0s/DebugLogDiagnostics.lua` to list both majors.** The next re-vendor silently reverts it, and it is forbidden (library-stack-§5, testing-§1; `CLAUDE.md`: "Never edit `libs/` or `tests/_kit/`").
- **Rejected: keep the broad `preTag` trigger.** It turns a provenance typo into a skip.

### Theme B: make the engine host's read override explicit (F-003)

`core/VerdictSetup.lua`'s `reads` hands the engine every same-named `NS.Compat` member. There are two acceptable shapes:

- **B1 (preferred):** an explicit `OWNED_READS` set (`PlayerRole`, plus the reads the simulator must guard). Everything else reads through to `lib.Reads`, wrapped by the Sim seam the same way `NS.Compat` is. The 33 engine-only Compat duplicates can then be deleted.
- **B2:** keep the override, and add a parity suite that drives each of the 50 overlapping reads on the kit mock through both `NS.Compat` and `lib.Reads` and asserts equal returns.

B1 removes the second implementation; B2 only detects drift. **Rejected: "re-implement the reads locally and drop the library's."** That is the forking anti-pattern.

### Theme C: test-suite hygiene after the move (F-004, F-005, F-006)

- Port LibKa0s's `seed` split (commit `55a7c6dc`) to Drop Watcher's golden suite.
- After G1, reduce the golden kernel half to wiring checks (testing-§8). The `me` read half stays.
- Retire the seed tool's dead apply path, or move the class-list seed check to LibKa0s alongside the data.

### Theme D: small cleanups (F-007 to F-011)

- Delete the unused `NS.Gear` view members.
- Move `CD.Install` behind a test seam, or make it also re-target the instance.
- Give the host a plain-field perf gate.
- Register settings before standing up the engine, and keep the traceback.
- Optionally collapse the unreleased schema steps.

## Upstream change-set

| Finding | Repo / file | Change | Minor bump | Consumer step |
|---|---|---|---|---|
| F-001 | LibKa0s `LibKa0s/DebugLogDiagnostics.lua`, `CHANGELOG.md` | The second branch to merge re-bumps to v1.120.0, with `DIAG_MINOR` 14 and both `Verdict` and `Feed` in the major list | DebugLogDiagnostics 13 → 14 | Re-vendor `libs/LibKa0s` (and `tests/_kit`) whole into each consumer on the renumbered tag, as its own commit, with the `CLAUDE.md` provenance line in the same commit (documentation-§2 item 6) |
| F-012 | LibKa0s `testkit/vendor_sync.lua`, or WowAddonStandards `testing.md` §11 | Reconcile "ref cannot be resolved → skip" (standard) with "missing tag → FAIL" (kit). Whichever loses is updated | kit revision +1 if the kit changes | Re-vendor `tests/_kit` whole |
| F-009 (part) | LibKa0s `LibKa0s/Verdict.lua` `methods:PerfStart` | The dormant gate becomes a plain field read through an upvalue (performance bracket hygiene) | Verdict minor +1 | Re-vendor |

No entry here or below targets a path under `libs/` or `tests/_kit/` in this addon.

## LLD

### C-01 (F-002): narrow the pre-tag shim and register it

- **File:** `tests/test_vendor_sync.lua:40-51`.
- **Before:** `preTag` is true for any provenance tag the sibling lacks.
- **After:** add a pinned constant and match it exactly:
  ```lua
  local PRE_TAG = "v1.119.0"   -- IS-G1 drops this branch (plan task G1)
  local preTag = tag == PRE_TAG and resolves("HEAD:LibKa0s/Core.lua") == true
      and resolves(tag .. ":LibKa0s/Core.lua") == false
  ```
- **Header:** change `:5` to name the shim ("the comparison is the kit's, apart from the pre-tag branch below").
- **Register:** `docs/ARCHITECTURE.md` → `## Documented deviations` gains `| testing-§11, library-stack-§7 | the payload is vendored from an untagged LibKa0s branch and the two payload cases are declared skips until the tag exists | Item Search split, plan task C1 | 2026-11-28 | LibKa0s v1.119.0 (or its renumbered tag) exists |`. CLAUDE.md requires this register row for any accepted deviation.
- **Inventory:** the pass count is unchanged (the skips stay skips).
- **Risk:** none at runtime.

### C-02 (F-003): an explicit read set (preferred shape B1)

- **File:** `core/VerdictSetup.lua:124-132`.
- **After (sketch):**
  ```lua
  local OWNED = { PlayerRole = true, --[[ + the reads the simulator must guard ]] }
  local reads = setmetatable({}, { __index = function(_, name)
      if ITEM_READS[name] then return NS.Item and NS.Item[name] end
      if OWNED[name] then return NS.Compat[name] end
      return nil   -- lib.Reads answers
  end })
  ```
- **What follows:** the Sim seam must then guard the engine's reads. That is a design question for `core/SimSetup.lua`. If it cannot, take shape B2: a new `tests/test_verdict_reads_parity.lua` that drives each overlapping read on the kit mock through both implementations. A new suite moves the pass count, so `docs/test-cases.md` and the README badge move in the same change (testing-§5).
- **Risk:** **medium**. The simulator's replay depends on these reads being wrapped. Run both kit profiles plus `/dw sim` smoke steps.

### C-03 (F-005): split the golden `seed`

- **File:** `tests/test_verdict_golden.lua:123`.
- **Change:** port LibKa0s `55a7c6dc`'s split of the same function. This is a mechanical extraction with no assertion change, and the helper names must describe what each does (anti-pattern #52).
- **Expected:** complexity warnings go from 4 to 3. Note it for the release regeneration of `docs/automated-tests/RESULTS.md`; do not regenerate it now.

### C-04 (F-004): reduce the golden kernel half after G1

- **File:** `tests/test_verdict_golden.lua`, `tests/fixtures/verdict_golden.lua`.
- **Change:** keep the `me` half and a few wiring checks (the client named, opts unwritten, off-spec gated). Drop the remaining `cases` that pin pure `lib.Evaluate` output, which the library's suite owns (testing-§8).
- **Moves:** the pass count moves (today 64 cases), so `docs/test-cases.md` and the README badge move in the same commit.
- **Alternative, if the owner keeps the full pin:** add a case asserting the fixture equals `git show <provenance tag>:tests/fixtures/verdict_golden.lua` in `../LibKa0s` (CR stripped), declared skip when the sibling is absent.

### C-05 (F-006): retire the dead apply path

- **Files:** `tools/seeds/seeds.py` (`apply_bundle`, `edit_weapons`) and `tools/seeds/test_seeds.py:269`.
- **Change:** delete the WEAPONS writer and its fixture test. Keep the `SystemExit` message as the `apply` answer. Alternatively, open a LibKa0s issue to move the class-list seed check there.
- **Moves:** the pytest count moves (22 → 21). `docs/validate-seeds.md` → `## Gate` moves with it.

### C-06 (F-007): drop unused `NS.Gear` view members

- **File:** `core/VerdictViews.lua:190, 194, 196, 204, 206, 207`.
- **Change:** delete `Signature`, `Read`, `Schedule`, `OnEvent` and `OnCombatEnd`. Move `OffSpecGear`'s two test call sites to `NS.VerdictEngine:OffSpecGear`, or keep the member.
- **Inventory:** no count change if the tests are only re-pointed.

### C-07 (F-008): fence `CD.Install`

- **File:** `core/VerdictViews.lua:55-61`.
- **Change:** move it to a test helper (`T.retailList` in `tests/run.lua` can set the view's upvalues through a documented `NS.ClassData.__testInstall`), or make the instance's client follow it as well. The owner should choose.
- **Risk:** test-only.

### C-08 (F-009, host half): a plain-field perf gate

- **File:** `core/VerdictSetup.lua:196-198`.
- **Change:** pass `NS.Perf` itself when it carries `on` and `Note(key, ms)`. Otherwise keep a table whose `on` field `core/PerfSetup.lua` writes as capture starts and stops.
- **Measurement:** add a `gearRebuildCaptureOff`/`On` pair to `tests/perf.lua`. The two must allocate equally (performance-§2). Scenarios are not test cases, so there is no badge change.

### C-09 (F-010): order and traceback

- **File:** `core/DropWatcher.lua:757-760`, `core/VerdictSetup.lua:211-216`.
- **Change:** call `self.Settings.Register()` before `NS.VerdictEnable()`, and re-raise with the original message plus a `debugstack()` line, or let the error propagate unwrapped after restoring the flags.
- **Risk:** low. Check that nothing in `Settings.Register` judges an item.

### C-10 (F-011, optional): note the unreleased steps

- **File:** `core/Database.lua:474-477`.
- **Change:** leave the steps (the runner's stamp must only move forward). Add a header comment that steps 10 to 19 never shipped in a tag, so a future cleanup can collapse them at the next release.
- **Not proposed:** deleting a step. That would need a migration ruling (savedvariables).

## Standards conformance

| Change | Conformance note |
|---|---|
| C-01 | A deviation recorded in the register as `CLAUDE.md` requires. It narrows an existing waiver and introduces no new one. testing-§11 is the rule involved |
| C-02 | Removes a parallel implementation beside a library (the extra section's "hand-rolled subsystem alongside a library"). No library edit |
| C-03 | anti-pattern #52 constrains the helper naming. No gating on complexity is proposed (automated-tests: the release is the checkpoint) |
| C-04 | testing-§8 (no duplicated library coverage). The badge and inventory move with the count (testing-§5) |
| C-05, C-06, C-10 | No rule involved beyond dead-code hygiene |
| C-07 | Keeps test seams out of the shipped surface. No standard rule forbids the alternative, so the owner decides |
| C-08 | performance-§2 (zero-overhead dormant bracket), performance-§9 (offline scenario) |
| C-09 | options-ui-§1 (eager category registration) stays satisfied, and gets earlier |
