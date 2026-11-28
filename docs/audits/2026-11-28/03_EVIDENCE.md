# Evidence: Ka0s Drop Watcher (standards audit, 2026-11-28)

Every command below was run from the repo root at `c7b9bbc` on 2026-11-28. Each `file:line` was
re-read before it was written here, and the cited text is quoted beside it. **Scope legend:**
*default* = `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` (263 files; `tests/` in,
`libs/` and `tests/_kit/` out). *load list* = authored `.lua` the TOC loads (131 files; `tests/`
out). *whole* = every tracked file (1402).

## Standard source

- `curl -fsSL --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2` for `AUDIT.md`,
  `standards/STANDARDS.md` (`# Ka0s WoW Addon Standard (v2.122.0, 2026-11-28)`),
  `standards/ADDONS.md` and `standards/CHANGELOG.md`, then 32 section files fetched in parallel via
  `xargs -P 8`. No fetch failed.
- Sibling `../WowAddonStandards`: `rev-parse HEAD` = `b83f039c…`, `ls-remote origin
  refs/heads/master` = `1647801c…`. They differ, so the sibling was not used.

## Gates (testing, lint)

```
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
  2648 passed, 0 failed, 6 skipped, 2654 total          EXIT 0
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
  2535 passed, 0 failed, 114 skipped, 2649 total        EXIT 0
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
  Total: 0 warnings / 0 errors in 263 files              EXIT 0
python3 -m pytest -q tools/seeds
  14 passed in 0.22s                                     EXIT 0
```

On Retail, the 6 skips are 5 Forever-pinned verdict goldens and the diagnostics opt-out case
(`this addon keeps the default`). `.luacheckrc:11` reads `exclude_files = { "libs/", "docs/audits/",
"docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }`, so `tests/` is linted. `:35` is
`files["tests/"] = {`. The one ignore, `:134`, is `ignore = { "212/self" },`. The 263 files luacheck
counted equal the default census.

## Complexity (automated-tests)

```
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
DropWatcher 1.1.0 — automated tests — 20261128-202105
  complexity  pass  — 0 warnings (fun rate 0.00), 74053 NLOC / 8942 funcs, avg NLOC 7.6, avg CCN 2.5 (max 15), …
  verdict: green
  record:  newest bundle 20261116-102800 measured c03cddd, 218 commit(s) behind HEAD — …
```

- `tests/_kit/framework.lua:20` `Kit.VERSION = 67`. `test_lizard_sighted` is declared
  (`tests/run.lua:445`).
- Every bundle's `manifest.json` has `blindFiles` 0. `crashedFiles` is 0 from `20261025-152417`
  onward.
- Releases: `git tag` gives `1.1.0-release` (2026-10-25) and `1.0.0-release`. The 1.1.0 release
  bundle is `20261025-153954`, and its `ANALYSIS.md:84` is `## Preview and simulation data`, with
  `**Answer:** Current`.
- **DRW-19:** `wc -l` today gives `core/Compat.lua` 748, `modules/Window.lua` 977,
  `modules/LootFeed.lua` 1113, `tests/test_test_mode.lua` 1445, `tests/test_window_shell.lua` 1298
  and `tests/wow_mock.lua` 1090. `RESULTS.md:137`, `:141` and `:139` carry the Compat, Window and
  LootFeed dispositions, and LootFeed's reads "split the re-judge path out next if it passes 1100".
- **The 1000-1500 band (default scope):**
  `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | awk '$1>=1000 && $1<=1500 && $2!="total"'`
  returns 12 files. Over 1500: none.

## Vendored library (library-stack-§7)

```
git -C ../LibKa0s archive v1.120.0 LibKa0s testkit | tar -x -C <scratch>/lk
diff -r <scratch>/lk/LibKa0s libs/LibKa0s     -> exit 1; every line is under media/icons (5805
                                                "Only in <lk>/…/media/icons" lines) plus one
                                                "Only in <lk>/LibKa0s/media: sounds"
grep -E 'differ|Only in DropWatcher' diff     -> (nothing)
diff -r <scratch>/lk/testkit tests/_kit        -> exit 0, empty
```

- `CLAUDE.md:48` `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.120.0 (MIT).`
- `CLAUDE.md:49` `LibKa0s icons: add, arrow-down, … transfer, volume-high.` (32 names). There is no
  `LibKa0s sounds:` line, which means `none`, and that matches the absent `media/sounds`.
- `find libs/LibKa0s/media/icons -type f` lists the 32 declared `.tga` files plus `CREDITS.txt`,
  `LICENSE-open-iconic.txt`, `phosphor/LICENSE-phosphor.txt`, `game-icons/LICENSE-game-icons.txt`
  and `game-icons/AUTHORS.txt`.
- `grep -n 'Bundles \[LibKa0s\]' README.md` finds nothing. The library-inventory heading grep finds
  nothing.
- `README.md:6` `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)` is bare.
- `README.md:141` credits Open Iconic (Waybury, MIT), Phosphor (MIT), and Game-icons `help` by Sbed
  (CC BY 3.0, "changed from the original"). The font grep (`grep -inE 'font|OFL' README.md`) hits
  only `:73`, the skin prose about the font setting, which is not a font credit.

## Re-vendor bundles (audit-review-history), DRW-16

The playbook's script, with `horizon=2026-10-14` (the store's first bundle, `2026-10-14-v1.72.0`):

```
vendored: 36 recorded: 35
unrecorded:
v1.120.0
git log --oneline -1 -- libs/LibKa0s tests/_kit   -> 161927d D1: re-vendor LibKa0s v1.120.0
ls docs/revendor | tail -1                        -> 2026-11-28-v1.119.0
```

## Register and issues

- `docs/ARCHITECTURE.md:830` `## Documented deviations`, followed by rows `:837-845`.
- `:845` `| options-ui-§17 | the class-color companion sits below its swatch in the tab's mirrored
  two-column layout | owner's choice: … | 2026-10-18 | the next options-ui-§17 edit, or LibKa0s
  gaining a mirrored color-pair layout |`
- `standards/CHANGELOG.md:8` (v2.119.0, 2026-11-24): "options-ui-§17: an unresolvable class falls
  through …; the new bullets *The precedence is class, then the skin's color, then the swatch* and *A
  preview shows a class*". `STANDARDS.md:106` (v2.122.0): "a new §17 MAY bullet lets a color row that
  is wholly unread … be dimmed". So the row's trigger fired twice (DRW-11).
- `gh issue view 11 -R tusharsaxena/WowAddonStandards` gives `OPEN … state:triaged`. LibKa0s#49 is
  `CLOSED … state:will-not-do` and LibKa0s#51 is `CLOSED … state:done`. Both Ka0sAddonsCommonTasks
  input paths `ls` cleanly (DRW-09).
- `gh issue list --state all --limit 200 --json number,title,state,labels` returns 22 issues. The
  only closed issue with an open-state label is `19 CLOSED enhancement,state:untriaged,severity:medium
  Separate Item Search into its own Ka0s addon, Item Search` (DRW-18). No issue is
  `state:will-not-do`, there is no `docs/pending/`, and no title carries a `[status]` prefix.

## README (documentation-§1), DRW-13, DRW-14

- `README.md:1` `# Drop Watcher`.
- `git show -s 2df58ad`: "R6-NAME: The README's title names the addon Drop Watcher, without Ka0s …
  The owner's ruling on the rename preview (Ka0sAddonsCommonTasks
  docs/2026-11-03-SMOKE_ROUND6/inputs/OWNER_ANSWERS.md, 2026-11-04)". No register row names
  documentation-§1 (`grep -n 'documentation-§1' docs/ARCHITECTURE.md` hits no row in `:837-845`).
  `git show 1.1.0-release:README.md | head -1` gives `# Ka0s Drop Watcher`, so the change post-dates
  the last release.
- `README.md:49` "… Bind a key under Options → Keybindings → Ka0s Drop Watcher if you like, …". No
  other line names Keybindings (`grep -n 'Keybindings' README.md` finds only `:49`). The standard
  (`launcher.md:156`): "The README's `## Usage` names the binding and both places to set it: Options →
  Keybindings → `Ka0s <Name>`, and General → Keybindings in the addon's settings."
- `docs/settings-panel.md:17` `| General | \`Master controls\`, \`Role\` (WoW Forever alone),
  \`Simulator\`, \`Skin\`, \`Keybindings\` |`.
- Clean: `grep -nE '^[[:space:]]*[0-9]+[.)][[:space:]]' README.md` finds nothing.
  `grep -n 'media/logos\|<img' README.md` finds nothing. `:73` names `` `/dw skin` `` inside Usage
  (`:47-76`). `:118` `## Reporting a bug` sits between Troubleshooting (`:105`) and Issues (`:126`).
  Badge `:7` `Tests-2648%2F2648_passing` matches the Retail run (2648 passes, skips excluded,
  testing-§5).

## TOC (toc-file-§5), DRW-12

```
python3: every core\|modules\|settings\|locales\|defaults\…lua named anywhere in DropWatcher.toc that is absent on disk
  -> ['modules\\Gear.lua']
```

- `DropWatcher.toc:263` `# core\DropWatcher.lua's (PLAYER_REGEN_ENABLED after modules\Gear.lua's
  too); its NS.STAND_DOWN step`
- `:293` `# LOAD-BEARING: appends its BAG_UPDATE_DELAYED row to NS.FEATURE_EVENTS after
  modules\Gear.lua's, so`
- `:545` `# modules\Inspect.lua's (PLAYER_REGEN_ENABLED after modules\Gear.lua's too); its
  NS.STAND_DOWN / NS.STAND_UP steps …`
- `ls modules/Gear.lua` gives `No such file or directory`. Where the rows come from now:
  `core/VerdictSetup.lua:136` `local CLIENTS = { "retail", "forever" }`, then the loop over
  `NS.Verdict.EventsFor(client)` and `:149` `NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event,
  "OnVerdictEvent",`.
- Counts: `grep -c '^# Conventional' DropWatcher.toc` gives 39, and `grep -c '^# LOAD-BEARING'`
  gives 91. Every appender of a shared event (GROUP_ROSTER_UPDATE ×4, PLAYER_ENTERING_WORLD ×4,
  PLAYER_REGEN_ENABLED ×3, PLAYER_REGEN_DISABLED ×2, CHALLENGE_MODE_COMPLETED ×2, counted with
  `grep -rhoE 'FEATURE_EVENTS\[#NS\.FEATURE_EVENTS \+ 1\] = \{ *"[A-Z_]+"' core modules settings |
  sort | uniq -c`) sits under a `# LOAD-BEARING` annotation (DRW-08 closed).

## Docs shape (documentation-§3), DRW-03, DRW-07

- `wc -l docs/ARCHITECTURE.md` gives 856. Section lengths (awk over `^## `): Overview 53, Module Map
  217, Settings Schema 23, Message Bus 17, Slash Commands 45, Event Subscriptions 106, Tooltip
  placement 49, Frame layering 18, Skins 139, Taint Notes 59, Known Limitations 32, Documentation map
  52, Documented deviations 26. `:136` `### Per-client features (clients-§4)` runs to `:278`.
- Map coverage. Live `.md` set:
  `git ls-files 'docs/*.md' | grep -vE '^docs/(audits|reviews|revendor|superpowers|seed-research|investigations)/|^docs/automated-tests/[^/]+/|^docs/perf-analysis/[^/]+/'`
  gives 25 files. The map's row set (`:785-829`) also has 25 rows. `comm -3` leaves only
  `ARCHITECTURE.md` (the hub, not registered, which is the MAY) on one side and `taint.md` (its *Not
  applicable* row) on the other.
- Compat count (DRW-07): `for f in core/Compat*.lua; do grep -cE
  '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' $f; done` gives Compat 43, CompatClient 10, CompatCollect
  3, CompatItem 4, CompatJournal 5, CompatLoot 17, CompatWorld 18. Over the family (`cat
  core/Compat*.lua | grep -cE …`) that is **100**. `docs/ARCHITECTURE.md:806` states "publishes 132
  addon-specific shims … `core/Compat.lua` 59, … `core/CompatCollect.lua` 16".
- Quirks blocks: `docs/midnight-quirks.md:5` `<!-- BEGIN VENDORED: quirks catalog v2.117.0 (source:
  WowAddonStandards) -->` to `:246`, and `docs/forever-quirks.md:5` `<!-- BEGIN VENDORED: forever
  quirks catalog v2.117.0 … -->` to `:189`. `diff` of each block body against the current fetched
  `client-quirks.md` and `forever-quirks.md` shows **0** changed lines.
- documentation-§6, scoped to the reporting-shape command's pathspec (live `.md` only):
  `| xargs -0 grep -nE '[A-Za-z_/]+\.(lua|toc|xml):[0-9]+'` gives **0**.
  `| xargs -0 grep -nE '§[0-9]+\.[0-9]'` gives 148, and reading them, every one is the addon's own
  spec numbering (for example `docs/schema.md:20` "§12.1 (`settings/SchemaRows.lua`)" is design spec
  §12.1). None cites the standard.

## Disabled state (slash-commands-§7), DRW-04

- Teardown: `core/DropWatcher.lua:141` `for _, event in ipairs(NS.FeatureEventNames()) do
  DW:UnregisterEvent(event) end`, then `NS.Bus:StandDown()` and `runAll(NS.STAND_DOWN)`.
- Registration census over the load list: `loadlist | xargs grep -nE
  'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent'` gives 45 lines. The game-event
  registrations all route through `core/DropWatcher.lua:122` `NS.SafeRegisterEvent(self, event,
  method, NS.rejectedEvents)`. The 36 `RegisterMessage` hits are on `NS.Bus` targets, which
  `NS.Bus:StandDown()` releases (suite case 1 pins `PINNED_MESSAGES`, and case 2 asserts
  `registered(m) == ""`).
- Step walk against `tests/test_disabled.lua`:
  1. Baseline: case 1 (`:111`) and case 11 (`:371` `assertTrue(#R_on >= #PINNED + #PINNED_MESSAGES,
     …)`).
  2. Disable through the seam: `DISABLES` (`/dw disable`, `NS.SchemaRuntime.Set("enabled", false)`).
  3. `:126` `-- red under: drop the UnregisterEvent loop in NS.StandDown (core/DropWatcher.lua)` and
     `:127` `assertEqual(registered(m), "", …)`.
  4. `:129` `assertEqual(#m.__timers(), 0, "no live timer")`.
  5. **Partial:** `:130` `assertFalse(NS.IsWindowShown(), "the stand-down hid the window")` and
     `:133`. No `F_on` is captured (`grep -n 'F_on' tests/test_disabled.lua` finds nothing).
  6. `:150` red-under comment, `:152` `assertTrue(m.__fireUnconditional(NS.addon, event) >= 1, …)`,
     and `:157` `assertEqual(#m.__shownFrames(), shownBefore, "no frame shown")`.
  7. Cases 4 and 5 (`:178`, `:204`) cover every `NS.COMMANDS` row.
  8. Case 8 (`:249`) covers `LeftButton` (`:268`), `RightButton` (`:272`) and the binding press
     (`:286`).
  9. Case 6 (`:227`) changes `scale` while off.
  10. Case 11 (`:361`), with its `:363` red-under comment.

## Packaging (packaging), DRW-17

```
(a) NOT IGNORED — .claude
(b) UNACCOUNTED — .claude / .git / .pytest_cache / .ruff_cache      (.git needs no row)
(c) (nothing)
```

- `.pkgmeta:11` `  # - .claude        # ONLY once the repo HAS a .claude/ (packaging); it has none
  today`
- `ls -la .claude` shows an empty directory. `git check-ignore -v .claude` gives `.gitignore:12:.claude/`.

## Line endings (line-endings)

```
tr -d '\r' < .gitattributes > ga; grep -n '^\* text=auto eol=\(crlf\|lf\)$' ga  -> 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' ga                                         -> 36, 37
grep -c ' binary$' ga                                                           -> 20
diff <(head -n 84 ga) <canonical client-bound body from line-endings-§5>        -> empty; no tail
(e) the named-variable working-tree check over git ls-files -z (whole, 1402)    -> 0
```

Run against the raw CRLF file, (b) and (c) print nothing, because `$` does not match before `\r`
(U-6). The kit gate agrees: `PASS eol: every tracked file carries the terminator .gitattributes
declares for it`.

## Frame layering (frame-layering), DRW-15

- `grep -rn 'SetFrameStrata("' core modules settings` finds nothing. Absolute `SetFrameLevel(` finds
  nothing. The relative sites all read `C.LAYERS.LEVEL.*` (`modules/DetailCard.lua:733`,
  `modules/IconStyle.lua:197`, `modules/OfferPanel.lua:359`, `modules/WindowRows.lua:424`).
- `SetMovable` appears in `modules/Window.lua` and `modules/RollPopup.lua`. `SetToplevel` appears at
  `modules/Window.lua:479` `f:SetToplevel(true)   -- a click raises it …` and
  `modules/DetailCard.lua:734`. It does not appear in `modules/RollPopup.lua`
  (`grep -n 'Toplevel\|Raise' modules/RollPopup.lua` finds nothing).
- `modules/RollPopup.lua:272` `f:SetFrameStrata(C.LAYERS.STRATA.ALERT)` (inside `skinned`), and
  `:515` `f:SetMovable(true)` (inside `buildStandIn`, `:511`).

## Other checks run, compliant

- Bus: `grep -rnE '(Send|Register)Message\("Ka0s_'` (outside libs and kit) finds nothing. Eleven
  constants are in `core/Bus.lua:22-32`, every one PascalCase.
- Client detection: `grep -rnE 'WOW_PROJECT_|GetBuildInfo'` finds only `core/Compat.lua:44-51`, the
  stub arm, which `compat.md:42` permits ("The one exception is a family file that … carries the
  library-absent stub"). ForeverDB: the clients-§11 grep finds nothing in code.
- Close button: `core/CoreSetup.lua:113` `return lib.MakeCloseButton(parent, onClick, addonName)`
  and `modules/WindowTitleBar.lua:368` `hb.close = spec.close ~= false and NS.MakeCloseButton(bar,
  spec.close) or nil`.
- Launcher: `core/LauncherSetup.lua:87` `label = NS.BRAND,`, and `core/Namespace.lua:13`
  `NS.BRAND = "Ka0s Drop Watcher"`. `settings/Schema.lua:53` `local MINIMAP_PATH =
  "global.minimap.shown"`. No `OnTooltipShow` in host code.
- Skins: `core/SkinSetup.lua:801` `Skin:RegisterOwner(addonName, {`. No `stockDefault`,
  `EllesmereUIDB` or `LSM30_` hits.
- Settings: no `Create("Keybinding")`, `SetBinding(`, `SaveBindings` or `KeybindListener`, and no
  `SettingsPanel`, `HideUIPanel`, `ToggleGameMenu` or `OpenToCategory` in host code. No
  `ScrollUp-Up` or `ScrollDown-Up` in `settings/`. No `DevTools_Dump`. No `ANCHOR_CURSOR` or
  `GetCursorPosition`.
- Display characters: a Python scan of string literals in `core modules settings locales` finds four
  characters outside the safe set, `▲ ≈ ▼` (`modules/WindowCells.lua:45`, `-- glyph: mono`) and `⊘`
  (`modules/CompactCards.lua:63`, `glyph: mono`). Both are monospace-pinned, which is exempt.
- Diagnostics: `core/DebugLogSetup.lua:126` "diagnosticsEnablesLogging is left out, so a run turns
  logging on for the session." No `"diag"`, `"dump"` or `"dx"` alias.
- Removed `__` members: `grep -rn '__releaseChrome\|__PatchLSM30Border'` finds nothing.
- Logo: the TGA header of `media/logos/dropwatcher.logo.128.tga` gives type 2, 128×128, 32 bpp.

## Prior findings (2026-10-14), closures

- DRW-01: `modules/Toast.lua:366-367` "The shell already made the close mark (`f.close`, top-right;
  none without LibKa0s-Core's MakeCloseButton, and Ask takes its corner)". There is no typed glyph.
- DRW-05: `tests/test_disabled.lua:311` `test("disabled 9: under the perf hold alone, each feature
  refusal names the capture, never 'is disabled'", …)`.
- DRW-06: `settings/PageEditors.lua:325` `NS.SkinOnRelease(holder, function(w)`. The park is chained
  onto the widget's `OnRelease`.
- DRW-08: see §TOC above.
