# Execution plan: Ka0s Drop Watcher remediation (standards audit, 2026-11-28)

Hand-off to the remediation engagement. Each step names its deviation ID and the design section in
`04_TECHNICAL_DESIGN.md`. Gate after every sprint: `ka0s-bounded lua tests/run.lua`,
`KA0S_KIT_CLIENT=forever ka0s-bounded lua tests/run.lua`, `ka0s-bounded luacheck .` (0/0) and
`python3 -m pytest -q tools/seeds`. Never edit `libs/` or `tests/_kit/`.

**Scope:** 13 root deviations (10 Low, 3 Info) and 1 dependent (DRW-19, Info). 10 roots fail a
MUST. These are the same figures as `02_DEVIATIONS.md`.

## Sprint 0: owner rulings (ask before Sprint 2)

- [ ] **DRW-13:** register row for the unbranded H1 (default), or restore `# Ka0s Drop Watcher`.
- [ ] **DRW-15:** is the simulator's stand-in popup a "movable window" (add `SetToplevel`, the
      default) or a preview stand-in (record the ruling)?
- [ ] **DRW-17:** `.pytest_cache` and `.ruff_cache`: ignore lines (default), or a comment pending U-5.

## Sprint 1: record and config (no Lua)

- [ ] **DRW-16:** write `docs/revendor/2026-11-28-v1.120.0/` (`01_DELTA.md` line 1 `Delta: LibKa0s
      v1.119.0 -> v1.120.0`). Re-run the re-vendor comparison from `03_EVIDENCE.md`. Expect
      `unrecorded:` to be empty.
- [ ] **DRW-17:** `.pkgmeta`: uncomment `.claude` and drop the false "has none today", then add the
      two caches. Re-run packaging checks (a)-(c). Expect only `.git` from (b).
- [ ] **DRW-18:** `gh issue edit 19 --remove-label state:untriaged --add-label state:done`.
- [ ] **DRW-11:** re-ratify the options-ui-§17 row (`docs/ARCHITECTURE.md:845`). Add the dated
      re-check note and narrow the trigger.

## Sprint 2: docs

- [ ] **DRW-07:** rewrite `docs/ARCHITECTURE.md:806` with 100 shims (43/10/17/18/4/5/3), dated, and
      the command beside it.
- [ ] **DRW-14:** `README.md:49`: add "or Settings → General → Keybindings".
- [ ] **DRW-13:** apply the Sprint 0 ruling (register row, or the H1).
- [ ] **DRW-03:** spill Event Subscriptions into `data-flow.md`, and Skins plus Tooltip placement
      into a registered Tier 3 doc. Re-run the map coverage check (expect 25+1 live docs, each in one
      table), and fix every `ARCHITECTURE.md#` anchor. Expected hub: about 570 lines.

## Sprint 3: TOC comments

- [ ] **DRW-12:** `DropWatcher.toc:263`, `:293`, `:545`: `modules\Gear.lua's` becomes
      `core\VerdictSetup.lua's (the verdict engine's rows)`. Re-run the missing-path scan from
      `03_EVIDENCE.md` §TOC and expect `[]`. Confirm `test_eol` stays green (CRLF kept).

## Sprint 4: code and tests

- [ ] **DRW-15:** `modules/RollPopup.lua:515`: add `f:SetToplevel(true)`, with a case asserting it
      (mock permitting; otherwise file the mock gap against LibKa0s testkit).
- [ ] **DRW-04:** `tests/test_disabled.lua` case 2: capture `F_on` (window, Rolls panel, a toast),
      assert it non-empty, and assert each hidden after the disable, with a `-- red under:` comment.
      Prove the comment by temporarily removing `modules/RollsPanel.lua`'s `NS.STAND_DOWN` step (red),
      then restore it (green).
- [ ] Update the README Tests badge to the new Retail pass count (testing-§5), and update
      `docs/test-cases.md` through the runner.

## At the next release (not now)

- [ ] **DRW-10 / DRW-19:** the release run regenerates `RESULTS.md`. Rule on
      `tests/test_window_shell.lua` and `tests/wow_mock.lua`, retire the Compat and Window band rows,
      act on LootFeed's 1100 trigger (or re-rule it with a date), and split `tests/test_test_mode.lua`
      before 1500.

## Upstream issues to file

- [ ] **U-1** (WowAddonStandards): may the README H1 drop the brand (documentation-§1 item 1)?
- [ ] **U-2** (WowAddonStandards): frame-layering-§4 and draggable preview stand-ins.
- [ ] **U-3** (LibKa0s, testkit): a static check that every file a TOC comment names exists.
- [ ] **U-4** (WowAddonStandards): the documentation-§3 hub cap vs the clients-§4 per-client table.
- [ ] **U-5** (WowAddonStandards): packaging check (b) and self-gitignored tool caches.
- [ ] **U-6** (WowAddonStandards): `AUDIT.md` line-ending (b)/(c) greps miss on CRLF; add
      `tr -d '\r'`.

## Done when

All Sprint 1-4 boxes are ticked, both suites and lint are green, the re-vendor and packaging checks
print nothing, the map coverage check is clean, and the upstream issues are filed and cited back in
the relevant register rows or notes.
