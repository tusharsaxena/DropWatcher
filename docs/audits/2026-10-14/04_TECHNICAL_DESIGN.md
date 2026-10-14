# Technical design: Ka0s Drop Watcher (standards audit, 2026-10-14)

Keyed to `02_DEVIATIONS.md`. Each change below is local. None needs a re-vendor or a schema bump.

## DRW-05: refuse on the hold that is actually taken (code)

- **Shape.** Add one helper beside `NS.IsStoodDown` in `core/LifecycleSetup.lua`:
  `NS.StoodDownRefusal()`. It answers `NS.SlashCommands:DisabledLine()` when
  `NS.Lifecycle:IsHeld(NS.HOLD_DISABLED)`. When only `perf` is held it answers
  `L["Not available during a performance capture."]`. When nothing is held it answers nil. The
  library-absent latch stub already answers `IsHeld`, so the helper works on both branches.
- **Callers.** `core/DropWatcher.lua:120` (`testModeRefusal`), `:177-178`, `:282-283` and
  `:393-394` (`ScanGroup`, `RetryInspect`, `PostTradeables`), and `modules/Sim.lua:128`
  (`Sim.Refusal`). Each prints the helper's line in place of `DisabledLine()`. The `PressAsk`,
  `PressOffer` and `PressAnnounce` reason `"disabled"` (`:252`, `:345`, `:370`) is a state string,
  not a printed line. Leave it, or split it into `"disabled"` / `"perf"` if a caller renders it.
- **Locale.** One new `enUS` key. The prose gate covers it.
- **Tests.** In `test_disabled.lua` or a new `test_lifecycle_refusal.lua`: under `HOLD_PERF` alone,
  `/dw scan` prints the perf line, never `"is disabled"`. Under `HOLD_DISABLED` it prints the
  disabled line.
- **Risk.** Low. Only refusal text changes, and the gating is unchanged.

## DRW-04: complete the conformance suite (tests only)

- **Step 10.** Two cases. In each, take a hold, write `enabled = false` through the seam, release the
  first hold, and assert `registered(m) == ""`. Then write `enabled = true` and assert the pinned
  set is back. Run it in both orders. Use `NS.Lifecycle:Hold(NS.HOLD_PERF)` and `:Release` directly:
  that is the harness's route.
- **Step 7.** Dispatch every `NS.COMMANDS[i][1]` and the empty string. Partition the verbs with
  `lib.LIVE_VERBS` plus `profile`. Assert that each live verb prints no `"is disabled"` line, that
  `config` and the bare `/dw` reach the panel opener (stub `DW.OpenSettings` and count calls), and
  that each feature verb prints exactly one refusal line and records no `__svWrites`.
  `resetall` opens a confirmation popup, so assert the popup was shown rather than a write.
- **Step 6.** After disable, `__resetSvWrites`, clear prints, snapshot shown frames, then
  `__fireUnconditional` every pinned event. Assert zero writes, zero prints, and no new shown frame.
- **Step 8.** Add `OnClick(m.UIParent, "LeftButton")`. Assert the opener was called and nothing was
  written or shown.
- **Falsification comments** on steps 6 and 10, for example
  `-- red under: drop the Bus:StandDown in NS.StandDown` and
  `-- red under: make NS.StandUp ignore the disabled hold`.
- **Risk.** None to the addon. Expect the case count to rise by about 6, so regenerate
  `docs/test-cases.md` and the README badge in the same commit (testing-§5).

## DRW-06: make the widget's own `OnRelease` park the table (code)

- In `P.SituationTable` (`settings/PageEditors.lua:213-230`), after `scroll:AddChild(holder)`, add
  `holder:SetCallback("OnRelease", function() P.ParkSituationTable(ctx) end)`. AceGUI fires
  `OnRelease` before it clears callbacks, so setting it on every acquisition is safe
  (options-ui-§19). `holder` comes from `AceGUI:Create`, not from a library maker, so the addon owns
  its callback.
- Keep the renderer's `ParkSituationTable` call. It is idempotent.
- **Test.** Release the holder directly (`AceGUI:Release(holder)` in the mock, or the widget's
  `Release`). Assert `t.host:GetParent() == ctx.panel` and that the host is hidden.

## DRW-03 and DRW-07: re-spill the hub (docs only)

- **Module Map** → three to six summary lines plus the one link to `module-map.md`. The per-module
  narrative already exists there or belongs there.
- **Settings Schema** → keep the seam paragraph short (seam, read, row source, page/tab rule) and the
  named-state **list** (keys, owners, writers), which architecture-§5 requires in this section.
  Move the per-row narrative, migrations and filter-bar session-state prose to `schema.md` (where
  they are partly duplicated already). Target is about 60 lines. If the named-state list alone
  exceeds that, keep it here anyway and note upstream finding U-2.
- **Known Limitations** → keep the top five player-relevant bullets and move the simulator and
  compact-mode bullets to `design-readings.md` (Tier 3, already registered).
- **Counts** → drop "Ninety-four" in favor of "every TOC-loaded file", or write 97. Write the
  compat row as "83 shims across the family (`cat core/Compat*.lua | grep -cE …`)".
- **Risk.** None. Run `dev-copilot:sync-docs` afterward.

## DRW-08: relabel the TOC (TOC comments only)

- Mechanical. Every `# Conventional:` block whose text states a load-time read or an in-group order
  becomes `# LOAD-BEARING:`. The other 15 keep `Conventional`, and each group keeps its one
  conventional note (toc-file-§5 SHOULD).
- Extend `tests/test_harness.lua` with a case: a TOC comment beginning `Conventional:` must not
  contain `at load`, `load-time upvalue` or `so its handler runs`. That stops the drift recurring.
- **Risk.** None to runtime. The TOC file order is unchanged.

## DRW-01: drop the toast's typed fallback (code, optional)

- On the degraded path, give the test-mode toast its normal countdown (`Toast` already has a timer
  for live toasts) so it closes itself, and delete `modules/Toast.lua:270-272`'s fallback. Or keep
  it and add a register row. The design prefers deletion, because the chrome degrading to nothing
  is the rule.

## Ordering constraints

DRW-04's step-10 case and DRW-05's refusal test both touch hold handling. Land DRW-05 first so the
new test can assert the perf line. The doc work (DRW-03, -07) comes last, after the code changes,
so the hub describes the final state.
