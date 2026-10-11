# Current state: Ka0s Drop Watcher (standards audit, 2026-10-11)

- **Repository:** `DropWatcher`, branch `feat/2026-10-10-drop-watcher-v1`, at `87d8694`, clean tree.
- **Kind resolved:** **Addon**. It has a `.toc` (`DropWatcher.toc`) and is a row of
  `standards/ADDONS.md`'s In-scope table (`| Ka0s Drop Watcher | ../../DropWatcher/ | … |`). Audited
  against the addon rule set: every section and the `anti-patterns` list.
- **Standard:** **v2.78.3** (2026-10-10), read from the local `WowAddonStandards` checkout at
  `c1f1cdc`, whose `master` matches `origin`. The playbook is that checkout's `AUDIT.md`.
- **First audit** of this addon. Prefix assigned: **`DRW`**. It is three letters from the name, chosen
  so it cannot be confused with the build plan's `DW-NN` item ids.
- **Deviation register read first:** `docs/ARCHITECTURE.md:315-332` (`## Documented deviations`, four
  rows). The repo's GitHub issue store holds no issues: `gh issue list --repo tusharsaxena/DropWatcher
  --state all` printed nothing, and the owner has held every GitHub write for this run.

## Section by section

| Area | What the addon does today | Evidence |
|---|---|---|
| Layout (layout-§1) | `core/`, `defaults/`, `locales/`, `modules/`, `settings/`, `media/`, `tests/`, `docs/`. 109 authored `.lua` files, none over 1500 lines. One file is in the 1000–1500 on-notice band (`core/Compat.lua`, 1107), and the watch list carries an accepted disposition for it. The census heading `### Files over the 1500-line cap` is present and reads "Nothing is over the cap today." | `docs/ARCHITECTURE.md:327-332`; `docs/automated-tests/RESULTS.md:96` |
| TOC (toc-file) | Interface 120100, `## IconTexture` names the addon's own 128 logo (an uncompressed type-2 TGA, 128×128, 32-bit), `## X-Standard` present, `## X-Curse-Project-ID` absent with the "not published" comment in its place. One `libs\LibKa0s\LibKa0s.xml` line after Ace3. Every load-bearing line is annotated `LOAD-BEARING` with what it resolves; conventional lines are marked `Conventional` | `DropWatcher.toc:6`, `:12`, `:13`, `:35` |
| Libraries (library-stack) | Ace3 plus LibKa0s **v1.71.0**, vendored whole. The payload and the test kit diff clean against the tag. Majors wired: Core, Media, Env, Pool, Item, Widgets, Bus, Lifecycle, Perf, DebugLog, Launcher, Schema, Options, Slash, and Compat (through `core/Compat.lua`'s guards) | `CLAUDE.md:41`; see `03_EVIDENCE.md` §Vendored |
| Shared subsystems | A descriptor and a stub each: `core/CoreSetup.lua` (printer, skin, `NS.MakeCloseButton` wrapper), `core/MediaSetup.lua` (one `RegisterLSM(addonName)`), `core/DebugLogSetup.lua` (`addonName` passed), `core/PerfSetup.lua`, `core/LifecycleSetup.lua` (holds `disabled` and `perf`), `core/LauncherSetup.lua`, `settings/OptionsSetup.lua`, `settings/SchemaSetup.lua`, `settings/Slash.lua`. No private console, dispatcher, widget set or test framework | `core/CoreSetup.lua:93-96`; `core/MediaSetup.lua:29`; `core/DebugLogSetup.lua:82-84`; `core/LifecycleSetup.lua:45-53` |
| Settings (options-ui, architecture-§5) | One write seam, `NS.SchemaRuntime.Set`; Master controls composed by the library; eight pages, each tabbed; the Profiles page through AceDBOptions. The state written outside the seam is named with its owner and writers | `settings/Panel.lua`; `docs/ARCHITECTURE.md:94-124` |
| Bus (architecture-§4) | Ten messages declared once in `core/Bus.lua` as `Ka0s_DropWatcher_<PascalCase>`; no literal at any call site | `core/Bus.lua:21-32` |
| Events (events-frames-taint-§1) | Every game event is a `NS.FEATURE_EVENTS` row, registered through `NS.SafeRegisterEvent` with the rejected list `NS.rejectedEvents`, which the `[Init]` summary and diagnostics surface | `core/DropWatcher.lua:61-73`, `:568-570` |
| Disabled state (slash-commands-§7) | One latch with two holds (`LibKa0s-Lifecycle-1.0`). The stand-down unregisters every feature event and every tracked bus registration and runs each module's teardown; `tests/test_disabled.lua` asserts on the mock's registration set | `core/DropWatcher.lua:89-103`; `tests/test_disabled.lua:70-94` |
| Slash (slash-commands) | `/dw`, alias `/dropwatcher`; 28 `NS.COMMANDS` rows; library dispatcher; `liveVerbs` built on `lib.LIVE_VERBS` plus `profile` | `settings/Slash.lua:162-172` |
| Launcher (launcher) | One LDB object through `LibKa0s-Launcher-1.0`, label `NS.BRAND`; `isEnabled`/`setEnabled`, `isLocked`/`toggleLock`, `isTestMode`/`toggleTestMode`, `isWindowShown`/`toggleWindow`, as ADDONS.md's column lists; `debug` and `debugAtEnable` passed | `core/LauncherSetup.lua:47-75`; `standards/ADDONS.md:23` |
| Debug and diagnostics (debug-logging) | Library console; `diagnostics` is one `COMMANDS` row; sections in `modules/Diagnostics.lua`; the `## Reporting a bug` README section has the three bullets and closing note | `settings/Slash.lua:50`; `README.md:101-107` |
| Tests (testing) | Kit revision 38. `tests/run.lua` loads the addon from the TOC; 887 cases (886 pass, 1 skip); kit suites `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract` and `test_lizard_sighted` declared by path | `tests/run.lua:135-139` |
| Lint (lint) | `.luacheckrc` excludes `libs/`, the frozen bundles, `_dev/` and `tests/_kit/` only; the harness global sits in `files["tests/"]`; no top-level `ignore` | `.luacheckrc:11`, `:13`, `:34` |
| Performance (performance) | Harness wired, seven buckets; `tests/perf.lua` with paired capture-off/on scenarios; `docs/perf-analysis/README.md` present, with no in-game capture yet | `core/PerfSetup.lua:20`, `:44` |
| Automated tests (automated-tests) | Two bundles; the newest (`20261011-091808`) is green, `blindFiles` 0, max CCN 13 | `docs/automated-tests/RESULTS.md:35` |
| Packaging (packaging) | `.pkgmeta` ignores every dev-only entry; the conditional `.claude`, `.superpowers` and `tools` lines are commented out (none of the three folders exists) | `.pkgmeta` |
| `.gitattributes` (line-endings) | Present. Byte-identical to the canonical client-bound body (84 lines, `* text=auto eol=crlf`, both shebang carve-outs, 23 `binary` lines). 0 tracked files disagree with the pin. Gate `tests/_kit/test_eol.lua` wired | `.gitattributes:26`, `:36-37` |
| Root docs (documentation-§1/§2/§7) | README with a bare standard badge, no logo image, no library inventory, no numbered list. `CLAUDE.md` stub with `## Standards compliance (read first)` and the provenance line. `DEPENDENCIES.md` present | `README.md:5`; `CLAUDE.md:6`, `:41` |
| `docs/` (documentation-§3) | Tier 1 complete. Tier 2: five present, `message-bus.md` *Not applicable* (10 messages, not more than ten). Four-table map plus a Tier 3 table; hub 332 lines | `docs/ARCHITECTURE.md:268-313` |
| Shared media (library-stack-§8) | `media/` holds only `logos/` and `screenshots/`; marks come from `NS.Icon`. One degraded-only typed glyph, in the toast (DRW-01) | `modules/Toast.lua:164-166` |
