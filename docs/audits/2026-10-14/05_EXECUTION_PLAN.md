# Execution plan: Ka0s Drop Watcher (standards audit, 2026-10-14)

Hand-off to the remediation engagement. The green gate holds after every step:
`lua tests/run.lua` and `luacheck .` at 0/0, both through `ka0s-bounded`. Never edit `libs/` or
`tests/_kit/`.

## Sprint 1: code (Medium first)

- [ ] **S1.1 (DRW-05).** Add `NS.StoodDownRefusal()` to `core/LifecycleSetup.lua` and the locale key
  `"Not available during a performance capture."`. Route `core/DropWatcher.lua:120`, `:177-178`,
  `:282-283`, `:393-394` and `modules/Sim.lua:128` through it. Add a test asserting the perf-only
  hold prints the perf line and the disabled hold prints the disabled line.
- [ ] **S1.2 (DRW-06).** Set `holder`'s `"OnRelease"` to `P.ParkSituationTable(ctx)` in
  `settings/PageEditors.lua` `P.SituationTable`. Add a release-without-renderer test.
- [ ] **S1.3 (DRW-01).** Give the degraded test-mode toast a countdown and delete the typed `×`
  fallback at `modules/Toast.lua:270-272`. Or record a register row, if the owner prefers to keep
  the fallback.

## Sprint 2: conformance suite

- [ ] **S2.1 (DRW-04).** In `tests/test_disabled.lua`: add step 10 in both hold orders; drive every
  `NS.COMMANDS` row and the bare `/dw` (step 7); fire every pinned event and assert zero writes,
  prints and shows (step 6); add the left-click case (step 8); write the `-- red under:` comments
  on steps 6 and 10.
- [ ] **S2.2.** Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and
  update the README `[tests]` badge in the same commit (testing-§5).

## Sprint 3: TOC and docs

- [ ] **S3.1 (DRW-08).** Relabel the 51 load-bearing `Conventional:` blocks in `DropWatcher.toc`
  `LOAD-BEARING:`. Add the harness case that rejects a `Conventional:` comment stating a load-time
  read.
- [ ] **S3.2 (DRW-03).** Re-spill `docs/ARCHITECTURE.md`: Module Map down to a summary and one link,
  Settings Schema down to about 60 lines (the named-state list stays), and Known Limitations
  trimmed into `design-readings.md`. Target under about 400 lines.
- [ ] **S3.3 (DRW-07).** Fix `docs/ARCHITECTURE.md:45` (97, or no count) and `:532` (83 across the
  family, with the command).
- [ ] **S3.4.** Run `dev-copilot:sync-docs`, then the full automated-test bundle
  (`bash tests/_kit/run-automated-tests.sh`) so the record catches up with HEAD (DRW-10).

## Not actioned here

- **DRW-09:** nothing owed. Re-check the six register rows at the next LibKa0s tag.
- **DRW-10:** closed by S3.4's bundle.
- Upstream findings U-1 to U-6 (see the audit's chat summary and the remediation spec) go to
  `WowAddonStandards` and `dev-copilot`, not to this repo. DRW-08's relabel follows the standard as
  written now, and U-1's ruling may later let the label relax.
