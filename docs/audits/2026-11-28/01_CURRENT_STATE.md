# Current state: Ka0s Drop Watcher (standards audit, 2026-11-28)

**Audited against standard v2.122.0 (2026-11-28)**, read by network fetch (`curl -fsSL` from
`raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`: `AUDIT.md`, `standards/STANDARDS.md`,
all 32 section files its Sections list links, `standards/ADDONS.md` and `standards/CHANGELOG.md`).
The sibling checkout `../WowAddonStandards` was **not** used: its `HEAD` (`b83f039c`) differs from
`origin/master` (`1647801c`), so it fails the "provably current" test.

**Tree measured:** branch `feat/2026-11-28-audit-review` at `c7b9bbc` (clean at the start of the run).
**Kind:** Addon (`dev-copilot-profile`: `profile=wow`, `kind=addon`, `reason=toc:## Interface`; it
agrees with `ADDONS.md`, where Drop Watcher is an addon row). Measured against the whole addon rule set.
**Roster row** (`ADDONS.md:24`): Clients `Retail · Forever`; launcher menu entries `Enabled · Locked ·
Test mode · Sim mode · Show window (the drop feed)`; skin picker preview `test`. **Prefix:** `DRW`
(kept from the 2026-10-11 and 2026-10-14 runs). The last audit measured v2.80.0, so this run spans
42 minor releases of the standard.

## Layout and census (layout-§1)

- 263 authored `.lua` files (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`), 131 of them
  in the TOC load list; every authored non-test `.lua` is loaded, and `docs/module-map.md` numbers
  131 rows.
- Nothing is over the 1500-line cap; the hub's census (`docs/ARCHITECTURE.md:847`, *Files over the
  1500-line cap*, under `## Documented deviations`) says so. Twelve files are in the 1000-1500 band
  (largest `tests/test_test_mode.lua`, 1445). The kit gate `test_layout_cap` is wired
  (`tests/run.lua:443`).
- Root: TOC, `Bindings.xml` (one `CLICK DropWatcherToggleWindow:LeftButton` binding,
  `category="BINDING_HEADER_DROPWATCHER"`, not in the TOC), `README.md`, `CLAUDE.md`,
  `DEPENDENCIES.md`, `LICENSE`, config dotfiles. One authored generator, `tools/seeds/seeds.py`,
  sits under `tools/` and is `.pkgmeta`-ignored.

## TOC (toc-file)

`## Interface: 120105, 16001` with no load-gating line (dual-client shape), `## Title: Ka0s Drop
Watcher`, `## IconTexture` pointing at `media\logos\dropwatcher.logo.128.tga` (TGA header: type 2,
128x128, 32 bpp), `## X-Standard`, `## X-Curse-Project-ID: 1748054`, `EllesmereUI` in
`## OptionalDeps`. `libs\LibKa0s\LibKa0s.xml` once, after Ace3. 91 `# LOAD-BEARING` and 39
`# Conventional` annotations; three of the load-bearing ones still name a deleted file (DRW-12).

## Libraries (library-stack)

- **LibKa0s v1.120.0**, provenance line at `CLAUDE.md:48`, icon declaration on the next line
  (`CLAUDE.md:49`, 32 icons), no `LibKa0s sounds:` line (so `none`).
- `diff -r` at tag v1.120.0: the ship folder differs only by undeclared icons
  (`Only in <LibKa0s>/…/media/icons`, 5805 lines) and the absent `media/sounds` (correct for
  `none`); `testkit` vs `tests/_kit` is **empty**. Kit revision 67.
- The vendored icon folder holds exactly the 32 declared icons plus the attribution files of the
  three shipped sets.
- Setup files, one per major: `core/CoreSetup.lua`, `core/DebugLogSetup.lua`,
  `settings/OptionsSetup.lua`, `settings/Slash.lua`, `core/PerfSetup.lua`, `core/LifecycleSetup.lua`,
  `core/LauncherSetup.lua`, `core/SkinSetup.lua`, `core/SimSetup.lua`, `core/VerdictSetup.lua`,
  `core/ToastSetup.lua`, `core/GlowSetup.lua`, `core/ChartsSetup.lua` and others. The close-button
  wrapper is the one `core/CoreSetup.lua:113` definition, and its one caller is the title-bar factory
  (`modules/WindowTitleBar.lua:368`).
- Register rows keep four host-owned pieces (chat sender, tooltip reader and decoder, loot parser,
  restriction tracker) outside the library, each ratified (see `## Register`).

## Clients (clients)

Dual-client. Detection goes through `LibKa0s-Compat-1.0`; the only `WOW_PROJECT_*` reads are the
Compat stub arm in `core/Compat.lua:47-51`, which compat says is the one permitted place. Per-client
features are declared (`clients = { "retail" }` on `NS.FEATURE_EVENTS` rows and descriptors), and the
hub carries the per-client feature table (`docs/ARCHITECTURE.md:136`). The suite is green on both
kit profiles. `docs/smoke-tests.md` tags every check with its client. Seed lists come from dated
`docs/seed-research/` bundles, which v2.122.0 names as a frozen store.

## Patterns, events, bus (architecture, events-frames-taint)

- Every game event is a row in `NS.FEATURE_EVENTS`, registered through `NS.SafeRegisterEvent`
  (`core/DropWatcher.lua:122`, the library's `pcall`ed family, rejected names kept in
  `NS.rejectedEvents`). Events two modules share go through `DW:OnSharedFeatureEvent`.
- Eleven bus messages, all constants in `core/Bus.lua:22-32`, PascalCase tails, no literal at any
  call site. Receivers live on `NS.Bus` targets.
- Hooks: `hooksecurefunc("NotifyInspect")` (`core/Compat.lua:414`) and `HookScript` on the client's
  roll popups (`core/CompatLoot.lua:343-344`), both gated in their bodies. Every other `HookScript` is
  on the addon's own frames.

## Settings, slash, launcher (options-ui, slash-commands, launcher)

- 35 `NS.COMMANDS` rows (`settings/Slash.lua:28-101`). `skin` comes straight after `config`,
  `diagnostics` has no alias, and `enable`/`disable` write the `enabled` row.
- The launcher descriptor (`core/LauncherSetup.lua`) uses `label = NS.BRAND` ("Ka0s Drop Watcher")
  and passes exactly the roster's five entries plus `debug`/`debugAtEnable`. The minimap row path is
  `global.minimap.shown` (`settings/Schema.lua:53`), backed by `minimap.hide`.
- Skins are adopted (`core/SkinSetup.lua:801` `Skin:RegisterOwner`), with the kit's `test_skin_values`
  and `test_skin_switch` declared.

## Disabled state (slash-commands-§7)

A single latch (`core/LifecycleSetup.lua`) with `NS.StandDown` / `NS.StandUp`
(`core/DropWatcher.lua:140-167`). It unregisters every feature event (`:141`), stands the bus
targets down, runs each module's `NS.STAND_DOWN` step and ends test mode. `tests/test_disabled.lua`
(398 lines, 12 `test(` blocks, 13 registered cases) is listed in `tests/run.lua:436`. It covers steps 1-4 and 6-10, with
`-- red under:` comments on 3, 6 and 10. Step 5 is partial (DRW-04).

## Debug, diagnostics (debug-logging)

The DebugLog descriptor is in `core/DebugLogSetup.lua`. `diagnosticsEnablesLogging` is left at its
default (`:126`), so a run turns logging on. The kit's contract case for the opt-out is the one
expected skip. README `## Reporting a bug` is present (`README.md:118`), as three bullets.

## Tests, lint, complexity (testing, lint, automated-tests)

- Retail: **2648 passed, 0 failed, 6 skipped, 2654 total**. Forever: **2535 passed, 0 failed, 114
  skipped, 2649 total**. `luacheck .`: **0 warnings / 0 errors in 263 files**. `pytest tools/seeds`:
  14 passed. All runs went through `ka0s-bounded`, and every one exited 0.
- `.luacheckrc` excludes `tests/_kit/` and the frozen doc stores only. The test globals sit in
  `files["tests/"]`. The one `ignore` is `212/self`.
- Complexity (vendored runner, `--no-bundle`): pass, 0 warnings, max CCN 15, 8942 functions. The
  record's newest bundle (`20261116-102800`, at `c03cddd`) is **218 commits behind HEAD**. The last
  release bundle is `20261025-153954` (1.1.0), and its `ANALYSIS.md` carries
  `## Preview and simulation data` (Current).

## Performance (performance)

The harness is wired (`core/PerfSetup.lua`), and `docs/performance.md` and
`docs/perf-analysis/README.md` exist. The perf hold shares the disabled latch (case 11).

## Packaging (packaging)

`.pkgmeta` ignores every named dev-only entry except `.claude`. Its commented line says the repo
"has none today", but an empty, gitignored `.claude/` is on disk. `.pytest_cache` and `.ruff_cache`
are on disk and unaccounted for (DRW-17).

## Line endings (line-endings)

`.gitattributes` is the client-bound canonical body, byte for byte (84 lines, `* text=auto
eol=crlf`, both shebang carve-outs, 20 binary marks, no appendix). The working-tree check over all
1402 tracked files counts **0** disagreeing files. The kit gate `test_eol` is green.

## Root doc set (documentation-§1/§2/§7)

- `README.md`: the badge row is five bare badges (Standard unwrapped), there is no logo image and no
  numbered list, no library inventory and no font credit. `## Credits` credits Open Iconic, Phosphor
  and Game-icons (`gi:help`). `## Usage` names `/dw skin`. **The H1 is `# Drop Watcher`** (DRW-13),
  and the binding is named with one of its two places (DRW-14).
- `CLAUDE.md`: the stub, the provenance and icon lines, and the green gate.
- `DEPENDENCIES.md`: Lua 5.1, luacheck, lizard via the runner, `ka0s-bounded`, python3 for the seed
  tool, Pillow for assets.

## docs/ (documentation-§3)

- **Tier 1:** all six docs present.
- **Tier 2:** `slash-dispatch.md` (35 commands), `midnight-quirks.md` and `forever-quirks.md` (both
  required for `Retail · Forever`; both vendored blocks are stamped v2.117.0, and each block's body
  is byte-identical to the current catalog), `compat-layer.md` (100 shims across the family, stated
  as 132: DRW-07), `message-bus.md` (11 messages), `profiles.md`, `debug.md`, `known-limitations.md`,
  and `perf-analysis/README.md`. `taint.md` is *Not applicable* (Taint Notes is 59 lines).
- **Documentation map:** four tables. Every one of the 25 live `.md` files appears exactly once, with
  no dangling row (the hub's own row is not registered, which is the permitted MAY). No non-canonical
  or retired filename.
- **Hub shape:** 856 lines. Module Map is 217 lines (143 of them the mandated per-client table),
  Event Subscriptions 106, Skins 139 (DRW-03).
- **documentation-§6:** 0 present-tense in-repo `path:line` citations in live docs. The 148
  `§N.M`-shaped hits are the addon's own design-spec section numbers, not the standard's retired
  notation.

## Register

`docs/ARCHITECTURE.md:830` `## Documented deviations` holds nine rows. Its re-check results are in
DRW-09 and DRW-11. The issue store (22 issues, read with `gh issue list`) carries no
`state:will-not-do` issue. There is no `docs/pending/LEDGER.md` and no `[status]` title prefix.

## Prior findings carried forward (2026-10-14 bundle)

| ID | Then | Now |
|---|---|---|
| DRW-01 | toast's typed degraded close | **closed**: the toast shell moved to LibKa0s-Toast-1.0, and with Core missing it draws no close (`modules/Toast.lua:366-367`) |
| DRW-03 | hub past the spill threshold (571 lines) | **recurs**: 856 lines |
| DRW-04 | conformance suite missed step 10 and parts of 6-8 | **narrowed**: steps 6-10 now covered; step 5 still partial |
| DRW-05 | perf refusal named "disabled" | **closed**: case 9 pins the capture line |
| DRW-06 | When-to-show table cleaned outside `OnRelease` | **closed**: `settings/PageEditors.lua:325` chains the undo onto `OnRelease` |
| DRW-07 | stale hub counts | **recurs**: the compat count |
| DRW-08 | load-bearing lines labeled `Conventional` | **closed** as filed. A different TOC defect is filed as DRW-12 |
| DRW-09 | register rows hold | re-run, Info |
| DRW-10 | automated-test record behind HEAD | **recurs**: 218 commits behind, no release since 1.1.0 |
