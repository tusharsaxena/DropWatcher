# 05 — Summary

- **Tag:** LibKa0s v1.76.0 -> v1.77.0, from the local annotated tag (`7380d36`, commit `78240f7`).
  The base, v1.76.0, comes from the `CLAUDE.md` provenance line and agrees with the last payload
  commit `6f69e6e`. Today's `v1.76.0` (commit `e692491`, moved again for a LibKa0s README change)
  carries the same payload. The provenance line rolled in the same commit as the bytes.
- **Minors:** Core 11 -> 12, DebugLog 20 -> 21, PerfPanel 8 -> 9, SimPanel 5 -> 6, Widgets 14 -> 15,
  WidgetsDragHandle 4 -> 5, WidgetsAutocomplete 2 -> 3, Options 29 -> 30, OptionsIds 2 -> 3,
  OptionsCombat 1 -> 2, OptionsCompose 7 -> 8, and the new OptionsKeybinds at 3. Kit 41 -> 42.
  That makes seventeen majors across forty-one files, all seventeen wired here. The copy deleted
  nothing from either payload.
- **Span bundle:** none needed (Step 3h prints nothing). **Base correction:** none (Step 0 `ok`).
- **Delivered free (class A):** the toplevel tool windows and their confirmation re-raise, the
  clamped popups, and the id-list suggestion list closing at combat start.
- **Blocker, fixed in the re-vendor commit:** `parity: the Options helpers stub carries the whole
  live surface` went red on the four new Options instance members. The library-absent branch of
  `settings/OptionsSetup.lua` now carries `StrataTooltip`, `KeybindingsTab`, `KeybindRows` and
  `KEYBINDS_UNCHANGED` (`01_DELTA.md` 3g). Nothing else went red. `tests/test_bindings.lua` (the
  pre-v2.88.0 `Bindings.xml` shape) is DW-KB's, and nothing was marked pending.
- **Icons:** the 28-name `LibKa0s icons:` line is kept. The prune removed 5,811 files (196 Open
  Iconic marks, 1,435 Phosphor, 4,180 Game-icons), and none of them reached git. No provenance split
  was needed.
- **Credits and dead stub mirrors:** README `## Credits` is unchanged, because Open Iconic is still
  the only set that ships. `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs
  --exclude-dir=_kit` finds no mirror.
- **Docs:** `docs/testing.md:19` names kit revision 42.
- **Refresh file:** none (a new tag, so a new bundle).
- **Adopted in this commit:** nothing. **Pre-decided adoptions:** the Keybindings tab and kit binding
  checks (DW-KB) and the kit layer recorder (DW-ZS). **Deferred (run 2026-10-24):**
  `O.StrataTooltip`, DragHandle `level` / `ApplyLevel` / `ignoreParentAlpha`, and a host call of
  `Core.RaiseStaticPopups()`. **Declined:** none, and no issue was filed. **Unreached:** none.
- **Smoke:** this item adds none.
- **Gate after the copy, both through `ka0s-bounded`:** `lua tests/run.lua` 1689 passed, 0 failed,
  1 skipped (1690 total), with `test_vendor_sync` included (both payloads match v1.77.0 in the
  declared icon shape). `luacheck .` gives 0 warnings / 0 errors in 193 files. No authored `.lua`
  file is above 1500 lines (the largest is `locales/enUS.lua` at 1316). Complexity is a release
  check and was not run.

## The standard reference (same item, part 2)

This part ran per the installed `/dev-copilot:wow-revendor-standards` 2.4.0 against standard
**v2.88.0, 2026-10-24**. The standard was read from the local `../WowAddonStandards` checkout on
`feat/2026-10-24-keybinds-layout-strata`, because WS-90 closed v2.88.0 there and it is not pushed.
v2.88.0 adds `frame-layering` (seven sections) and changes `anti-patterns`, `debug-logging`,
`events-frames-taint`, `launcher`, `library-stack`, `open-evolutions`, `options-ui`,
`preview-mode` and `standalone-windows`. `documentation` and `automated-tests` are unchanged, and no
section file was removed. Nothing needed changing:

- **3a, the three places:** `DropWatcher.toc:12` `## X-Standard:
  https://github.com/tusharsaxena/WowAddonStandards`; `README.md:6` the bare
  `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)`; and `CLAUDE.md:6`
  `## Standards compliance (read first)`, with the stop-and-flag directive and the two-way
  classification. The command writes no version into any of them (its Step 5 rule), so none of
  them moves.
- **3b:** `grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=.git --exclude-dir=libs --exclude-dir=_kit
  --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests` gives 325 hits. Every
  one cites this addon's own design specs (`design spec §N.M`, `v1 §N.M`, and the item and
  milestone tables of `docs/superpowers/`), never the standard, so none of them is retired notation.
  `grep -rnoE '[a-z][a-z-]*-§[0-9]*'` under the same exclusions finds 431 `filename-§N`
  references. Each was range-checked against the v2.88.0 section files (count of `### N.`
  headings): none names an unknown file and none is malformed. Six are **out of range**, flagged
  and not rewritten. All six are `compat-§1`, and `compat.md` has no numbered subsections:
  `docs/superpowers/plans/2026-10-10-drop-watcher-v1/items.tsv:55`, `:56`,
  `docs/superpowers/plans/2026-10-10-drop-watcher-v1/RESUME.md:81`,
  `docs/superpowers/plans/2026-10-10-drop-watcher-v1/orchestration/milestones.json:226`,
  `docs/superpowers/specs/2026-10-11-drop-watcher-simulator-design.md:41` and
  `docs/superpowers/specs/2026-10-11-drop-watcher-ui-feedback-design.md:44`. They predate v2.88.0,
  which leaves `compat` unchanged. They sit in executed v1 plans and specs (plan data, a JSON
  value, design records). The command never guesses a target, and the intended one, the whole
  `compat` section, is the owner's call. One more hit, `Testing-§12` at
  `docs/superpowers/research/2026-10-14-review-audit/findings.md:719`, is `testing-§12`
  capitalized at the start of a sentence, and it is in range.
- **3c-3e:** the `CLAUDE.md` pointers all resolve. The root doc set and the canonical `docs/`
  members are present. There is no `docs/agent-context.md`, and the standard has no quirks catalog
  to vendor.
- **3f:** v2.88.0 does not change `automated-tests`, so no gate statement moved. The
  `docs/automated-tests/RESULTS.md` lead-in is runner-generated, and this sweep did not touch it.
- **3g:** `.gitattributes` is present with the pin `* text=auto eol=crlf` (client-bound), the
  `*.sh` and `*.py` carve-outs, and the binary markings. The worktree straggler count, from the
  command's `git ls-files -z | xargs -0 -n1 sh -c '...' _ | wc -l`, is 0. No renormalization was
  performed.

## Re-vendor after the tag moved (M3)

LK-95 moved the local annotated tag v1.77.0 in `../LibKa0s` to carry the M3 settings-layout
surfaces. DW-RV2 re-vendored it exactly as above, from the installed
`/dev-copilot:wow-revendor-libka0s` 2.4.0 procedure.

- **Tag:** old tag object `7380d36`, commit `78240f7`. New tag object
  `b2b8ee25c5f9fa26db146254bf786b366dec986b`, commit
  `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (`git -C ../LibKa0s rev-parse 'v1.77.0^{}'`).
- **Minors that moved:** OptionsCompose 8 -> 11 (minor 9: `MasterControls` `notes`,
  `resetPositionTooltip`, `lockIsPreview` and Master opacity; minor 10: `tooltips` on the group
  composers; minor 11: `O.ResetAllTooltip(tail)`). No other file changed in either payload, and the
  kit stays at revision 42, so `docs/testing.md:19` is unchanged. The copy deleted nothing.
- **Provenance:** `CLAUDE.md:42` stays `v1.77.0` and records no sha or kit revision, so nothing
  rolled. The 28-name `LibKa0s icons:` line is kept. The prune removed 5,811 files again, and none
  reached git. README `## Credits` is unchanged.
- **Blocker, fixed in this commit:** `parity: the Options helpers stub carries the whole live
  surface` went red on `ResetAllTooltip`. The library-absent branch of `settings/OptionsSetup.lua`
  now carries it as an inert member returning `""`.
- **Adopted:** nothing (DW-LY adopts the layout surfaces).
- **Standard:** no drift. Since the check above, WS-30..WS-38 and WS-95 changed `options-ui`
  (twenty to twenty-one numbered sections, the new one appended), `library-stack`, `anti-patterns`,
  `naming-cheatsheet`, `open-evolutions` and the index. No existing section was renumbered and the
  three standards places carry no version, so nothing in this repo moves.
- **Gate, both through `ka0s-bounded`:** `lua tests/run.lua` 1705 passed, 0 failed, 1 skipped
  (1706 total). `luacheck .` gives 0 warnings / 0 errors in 194 files. No authored `.lua` file is
  above 1500 lines (the largest is `locales/enUS.lua` at 1318).
