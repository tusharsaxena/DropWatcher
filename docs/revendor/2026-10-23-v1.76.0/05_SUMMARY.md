# 05 — Summary

- **Tag:** LibKa0s v1.75.2 -> v1.76.0, from the local annotated tag (`546e284`, commit `9949368`).
  The base, v1.75.2, comes from the `CLAUDE.md` provenance line and agrees with the last payload
  commit `3414a82`. The provenance line rolled in the same commit as the bytes.
- **Minors:** Widgets 13 -> 14 (`LibKa0s-Widgets-1.0` 14.1.4.3.2), SimTimeline 2 -> 3 and SimPanel
  4 -> 5 (`LibKa0s-Sim-1.0` 2.3.5). Kit 41 unchanged. Seventeen majors across forty files, all
  seventeen wired here. Nothing was deleted from either payload by the copy.
- **Span bundle:** `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`, two tags (v1.75.1, v1.75.2)
  vendored on 2026-10-23 with no bundle. **Base correction:** none (Step 0 `ok`).
- **Delivered free (class A):** a started simulation plays on its own; a manual step or click holds
  it; the panel's controls are Pause/Resume, Restart and Stop.
- **Blocker, fixed in the re-vendor commit at its minimum:** six typed-start cases of
  `tests/test_sim_scenario.lua` (`01_DELTA.md` 3g): one status-line expectation reads `playing`,
  five cases pause after the typed start. DW-01 owns the full re-true, the strings and the docs.
- **Icons:** the 28-name `LibKa0s icons:` line kept. The prune removed 5,811 files (196 Open Iconic
  marks, Phosphor 1,435, Game-icons 4,180), none of which reached git. No provenance split.
- **Credits and dead stub mirrors:** README `## Credits` unchanged (Open Iconic is still the only set
  that ships). `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
  finds no mirror.
- **Refresh file:** none (a new tag, so a new bundle).
- **Adopted in this commit:** nothing. **Pre-decided adoptions:** the auto-play re-true (DW-01) and
  `W.TestStrip`'s `kind = "sim"` (DW-10). **Declined:** none; no issue filed. **Unreached:** none.
- **Smoke:** none added by this item. DW-01 and DW-10 carry the run's client checks.
- **Gate after the copy, both through `ka0s-bounded`:** `lua tests/run.lua` 1681 passed, 0 failed,
  1 skipped (1682 total), `test_vendor_sync` included (both payloads match v1.76.0 in the declared
  icon shape); `luacheck .` 0 warnings / 0 errors in 193 files; no authored `.lua` file above 1500
  lines (largest `locales/enUS.lua`, 1312). Complexity is a release check and was not run.

## The standard reference (same item, part 2)

Run per the installed `/dev-copilot:wow-revendor-standards` 2.4.0 against standard **v2.87.0,
2026-10-23**, read from the local `../WowAddonStandards` checkout on
`feat/2026-10-23-sim-preview-mode-strips` (the run's ruling; GitHub master is still v2.86.0).
v2.87.0 changes `preview-mode`, `standalone-windows`, `library-stack`, `automated-tests`,
`versioning-git` and `anti-patterns`; `documentation` is unchanged and no section file was added or
removed. Nothing needed changing:

- **3a, the three places:** `DropWatcher.toc:12` `## X-Standard:
  https://github.com/tusharsaxena/WowAddonStandards`; `README.md:6` the bare
  `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)`; `CLAUDE.md`
  `## Standards compliance (read first)` with the stop-and-flag directive and the two-way
  classification. The command writes no version into any of them (its Step 5 rule), so none moves.
- **3b:** `grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=.git --exclude-dir=libs --exclude-dir=_kit
  --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests` gives 324 hits. Every one
  cites this addon's own design specs (`design spec §N.M`, `v1 §N.M`, and the item and milestone
  tables of `docs/superpowers/`), never the standard, so none is retired notation. Every
  `filename-§N` reference outside the frozen bundles (275) was range-checked against the v2.87.0
  section files: none out of range, malformed or naming an unknown file.
- **3c-3e:** no forbidden pointer, no `docs/agent-context.md`, no quirks section upstream to vendor.
- **3f:** v2.87.0 does not change `automated-tests-§3`'s gate statements; it adds a release-run
  preview and simulation re-look, which `/dev-copilot:bump-version` records at release. The
  `docs/automated-tests/RESULTS.md` lead-in is runner-generated and was not swept.
- **3g:** `.gitattributes` present, pin `* text=auto eol=crlf` (client-bound), `*.sh` and `*.py`
  carve-outs and binary markings present. The worktree straggler count was 1 at the start
  (`docs/smoke-tests.md`, bare LF on disk while the index was right, which the kit's `eol` case
  flagged); it was repaired in the working tree only (`rm docs/smoke-tests.md && git checkout --
  docs/smoke-tests.md`, no diff), and the count is now 0. No renormalization was performed.

## Refresh: the tag moved for LK-91 (DW-RV2)

The local annotated tag v1.76.0 was moved before any push, from commit `9949368` to commit
`7e81ff7` (tag object `2949c78`), to carry LK-91: a step label in the sim and perf panels is one
line and stops 8 short of the command column instead of running under it (the owner's BankLedger
report, `Deposit 1 x Flask ...` over `/bl sim step`). Both payloads were replaced whole again from
the moved tag and `media/icons` pruned to the same 28-name declaration (5,811 files removed, none
reached git).

- **Files that changed:** `libs/LibKa0s/SimPanel.lua` (keeps minor 5, the minor v1.76.0 already
  gave it) and `libs/LibKa0s/PerfPanel.lua` (minor 7 -> 8, `LibKa0s-Perf-1.0` key 15.1.1.8). Nothing
  else in `libs/LibKa0s/`; `tests/_kit/` is byte-identical (kit revision 41).
- **Adoption:** none needed; the fix is delivered free (class A). No member added, no issue filed.
- **Gate after the copy, both through `ka0s-bounded`:** `lua tests/run.lua` 1689 passed, 0 failed,
  1 skipped (1690 total), `test_vendor_sync` included against the moved tag; `luacheck .`
  0 warnings / 0 errors in 193 files; no authored `.lua` file above 1500 lines (largest
  `locales/enUS.lua`, 1316).
