# Evidence: Ka0s Drop Watcher (standards audit, 2026-10-14)

All commands ran from the repo root at `3eadd89`, clean tree. Each `file:line` below was re-read
before it was written, and the quoted text is what is there. Scope legend: **default** means the
tracked authored Lua (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, `tests/` in), **TOC**
means the TOC-loaded files, and **whole** means `git ls-files` with no exclusion.

## Standard resolution

```
curl -fsSL $RAW/AUDIT.md                -> 1183 lines
curl -fsSL $RAW/standards/STANDARDS.md  -> "# Ka0s WoW Addon Standard (v2.80.0, 2026-10-13)"
27 section files from the Sections list, plus standards/ADDONS.md
diff -rq ../WowAddonStandards/standards/standards <fetched>/standards/standards   -> (empty)
diff -q  ../WowAddonStandards/AUDIT.md <fetched>/AUDIT.md                          -> (empty)
git -C ../WowAddonStandards log --oneline -1 -> 8aad69d QC: Bindings.xml is a client-mandated root file, beside the TOC (v2.80.0)
```

Kind: `dev-copilot-profile` → `profile=wow kind=addon name=DropWatcher reason=toc:## Interface`.

## Mechanical runs

| Check | Command | Real output | Scope |
|---|---|---|---|
| Tests | `ka0s-bounded lua tests/run.lua` | `1402 passed, 0 failed, 1 skipped, 1403 total`, rc 0 | the suite list in `tests/run.lua` |
| Lint | `ka0s-bounded luacheck .` | `Total: 0 warnings / 0 errors in 169 files`, rc 0 | everything but `.luacheckrc:11`'s `exclude_files` (`libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/`, `tests/_kit/`) |
| Complexity | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | `complexity pass — 0 warnings (fun rate 0.00), 41618 NLOC / 5314 funcs, avg NLOC 7.3, avg CCN 2.4 (max 14)`; `newest bundle 20261014-133254 measured 5996818, 7 commit(s) behind HEAD` | the runner's sighted shadow, whose scope is the runner's own |
| Kit revision | `grep -n 'VERSION *=' tests/_kit/framework.lua` | `20:Kit.VERSION = 38` | n/a |
| blindFiles | `grep -o '"blindFiles"[^,}]*' docs/automated-tests/20261014-133254/manifest.json` | `"blindFiles": 0` | newest bundle |

## Vendored (library-stack-§7, #45, #48)

```
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md  -> 41:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
grep -n 'Bundles \[LibKa0s\]' README.md  -> (none)
git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C $T
diff -rq $T/LibKa0s libs/LibKa0s | wc -l -> 0     (37 entries each side)
diff -rq $T/testkit tests/_kit   | wc -l -> 0
git -C ../LibKa0s tag --sort=-v:refname | head -1 -> v1.71.0  (HEAD v1.71.0-5-g5d22cf1, docs only)
```

## README (documentation-§1)

```
grep -n 'WoW_Addon_Standard' README.md   -> 5:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)   (bare, not linked)
grep -nE '^## (Libraries|Bundled libraries|…)' README.md -> (none)
grep -nE '^[[:space:]]*[0-9]+[.)][[:space:]]' README.md -> (none)
grep -nE '!\[.*\]\(media/logos|<img' README.md -> (none)
README.md:3  ![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)      TOC:1 "## Interface: 120100"
README.md:6  ![Tests](https://img.shields.io/badge/Tests-1402%2F1402_passing-green)   docs/test-cases.md "| **Total** | **1402** |", "| Skipped | 1 |"
README.md:181 "## Reporting a bug" (between ## Troubleshooting :169 and ## Issues and feature requests :189)
```

## Line endings (line-endings) — scope: whole

```
(a) test -f .gitattributes                         -> present
(b) grep -n '^\* text=auto eol=\(crlf\|lf\)$'      -> 26:* text=auto eol=crlf
(c) grep -nE '^\*\.(sh|py) text eol=lf$'           -> 36:*.sh text eol=lf / 37:*.py text eol=lf
(d) grep -c ' binary$'                             -> 20   (grep -c binary -> 23: three comment lines also match)
    diff <(head -84 .gitattributes | tr -d '\r') <canonical client-bound body, line-endings.md:164-247> -> IDENTICAL
(e) the AUDIT.md one-liner, verbatim               -> 0
```

## Packaging (packaging)

```
(a) NOT IGNORED -> (none)   (b) UNACCOUNTED -> .git (expected)   (c) FALSE CLAIM -> (none)
.pkgmeta: "# - .claude", "# - .superpowers", "# - tools" are commented, and none of the three folders exists.
```

## Layout (layout-§1) — scope: default

```
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l             -> 169
… | xargs wc -l | sort -rn | head -3 -> 986 tests/test_window_group.lua / 978 modules/LootFeed.lua / 960 core/Compat.lua
git ls-files '*.py' '*.sh' '*.js'  -> 21 plan-helper scripts under docs/superpowers/ (resume-state.sh,
   checkpoint.sh, dw-milestone.workflow.js, a wireframe support.js) + tests/_kit/run-automated-tests.sh.
   None writes a tracked file, so none is a generator.
ls Bindings.xml -> No such file
docs/ARCHITECTURE.md:566 "### Files over the 1500-line cap" / :571 "Nothing is over the cap today."
```

## TOC (toc-file) — DRW-08

```
TGA header: media/logos/dropwatcher.logo.128.tga bytes 0-17 -> 0 0 2 … 128 0 128 0 32 8   (type 2, 128x128, 32-bit)
```

Labels on load-bearing positions, from a scan of every `# Conventional:` block for "at load", "load-time
upvalue", "so its handler runs" or "after … so the". It found **51** of the TOC's **66** `Conventional` blocks that
mention a load-time read or an ordering. Command (scope: the TOC):

```
tr -d '\r' < DropWatcher.toc | awk '/^# (Conventional|LOAD-BEARING)/{kind=$2; txt=""} /^#/{txt=txt" "$0}
  /^(core|modules|settings|defaults|locales)/{ if (kind=="Conventional:" && txt ~ /at load|load-time upvalue|so its handler runs|after .*so the/) n++;
  if (kind=="Conventional:") c++; kind=""; txt=""} END{print n, c}'      -> 51 66
```

 Quoted (re-read):

- `DropWatcher.toc:47-48` — `# Conventional: NS.Compat (every version-variant client call and the secret guards) is read inside` / `# functions only; it needs LibStub and NS.TextParse (above) at load.`, while `core/Compat.lua:14` reads `local TextParse = NS.TextParse -- core/TextParse.lua, above in the TOC: the pure parsers`.
- `DropWatcher.toc:158-160` — `# Conventional: publishes NS.Roster, …; appends its row to` / `# NS.FEATURE_EVENTS (GROUP_ROSTER_UPDATE, shared with modules\Situations.lua above, so its handler` / `# runs second), …`
- `DropWatcher.toc:190-192` — `# Conventional: publishes NS.Inspect, the inspect broker; appends its rows to NS.FEATURE_EVENTS` / `# (GROUP_ROSTER_UPDATE and PLAYER_ENTERING_WORLD after modules\Roster.lua's and` / `# modules\Situations.lua's, so the roster is fresh; …`
- `DropWatcher.toc:262` + `:265-266` — `# Conventional: publishes NS.TipMarks, …` / `… Above modules\MineCells.lua, modules\DetailCells.lua and` / `# modules\OfferPanel.lua (which take it at load), …`
- `DropWatcher.toc:197` (`modules\LootFeed.lua`), `:204` (`modules\TradeTimer.lua`), `:245` (`modules\WindowCompact.lua`): `# Conventional:` blocks stating event rows ordered after another module's.
- Contrast: `DropWatcher.toc:212` `# LOAD-BEARING: publishes NS.Asks, the messaging edge. …` (file at `:221`), which makes the same kind of shared-event ordering claim.

Why the order matters at runtime: `core/DropWatcher.lua:57-58`, `function DW:OnSharedFeatureEvent(event, ...)`
/ `for _, method in ipairs(sharedHandlers[event] or {}) do self[method](self, event, ...) end`. The
shared handlers run in `NS.FEATURE_EVENTS` row order, which is TOC order.

## Register and issues (audit-review-history, documentation-§3) — DRW-09

```
docs/ARCHITECTURE.md:552 "## Documented deviations"; rows :558-563 (six)
gh issue list --state all --limit 200 --json number,title,state,labels,url -> #1..#8, all OPEN, state:triaged, severity:low
gh issue view 49 --repo tusharsaxena/LibKa0s -> OPEN "Promotion candidates from Drop Watcher: chat sender, tooltip line reader, loot-line parser, restriction tracker"
gh issue view 51 --repo tusharsaxena/LibKa0s -> OPEN "Item-1.0: an exact item read (link detail, better link, level and quality), and a loot-line parser"
gh issue view 53 --repo tusharsaxena/LibKa0s -> OPEN "Perf-1.0: generalize PerfPanel into a shared step panel"
gh issue view 50 --repo tusharsaxena/LibKa0s -> OPEN "Options: a grid composer for rows of mixed controls"   (cited in Known Limitations)
gh issue view 11 --repo tusharsaxena/WowAddonStandards -> OPEN "Proposal: a rule for chat an addon sends on the player's behalf"
git grep -n 'DW-91' -- docs/superpowers -> docs/superpowers/plans/2026-10-10-drop-watcher-v1/issues-to-file.md:51 "**Added by DW-91 (M9, 2026-10-11).** …"
```

## Hub shape and counts (documentation-§3/§5) — DRW-03, DRW-07

```
wc -l docs/ARCHITECTURE.md -> 571
grep -n '^## ' docs/ARCHITECTURE.md -> 8 Overview / 43 Module Map / 218 Settings Schema / 307 Message Bus /
   349 Slash Commands / 359 Event Subscriptions / 401 Taint Notes / 432 Known Limitations /
   505 Documentation map / 552 Documented deviations
   => Module Map 175 lines, Settings Schema 89, Known Limitations 73
docs/ARCHITECTURE.md:45  "Ninety-four authored files load from the TOC, …"
tr -d '\r' < DropWatcher.toc | grep -vE '^#|^$' | grep -v '^libs' | wc -l  -> 97
docs/module-map.md:106   "| 97 | `settings/Profiles.lua` | settings | the Profiles page (AceDBOptions) |"
docs/ARCHITECTURE.md:532 "| `compat-layer.md` | Present | `core/Compat.lua` publishes 62 addon-specific shims …"
cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'  -> 83   (Compat 62, CompatWorld 16, CompatItem 5)
Docs registered: 20 live .md (stores excluded per documentation-§3); every one is in a map table, and no row dangles.
sed -n 27,88p settings/Slash.lua | grep -cE '^\s*\{"' -> 30 (NS.COMMANDS rows), matching docs/ARCHITECTURE.md:528
core/Bus.lua:22-31 -> 10 messages, matching docs/ARCHITECTURE.md:533
```

## Disabled state (slash-commands-§7) — scope: TOC for runtime claims

Census, as the playbook gives it (default scope, `tests/_kit` and `libs` excluded):

```
git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|…|C_Timer|NewTicker|hooksecurefunc|HookScript'
-> game events: only core/DropWatcher.lua:71 NS.SafeRegisterEvent(self, event, method, NS.rejectedEvents)  (one registrar over NS.FEATURE_EVENTS)
-> bus: tracked NS.Bus targets in Asks, AutoAsk, History, LootFeed, Toast, TradeTimer, Window, WindowCompact, WindowHistory
-> hooksecurefunc: core/Compat.lua:403 (NotifyInspect); body modules/Inspect.lua:565 "if notifying or stoodDown() then return end"
-> timers: C_Timer.NewTimer/NewTicker per module, each canceled by its NS.STAND_DOWN row (case 2 asserts #m.__timers() == 0)
```

- `core/DropWatcher.lua:89-95`: `function NS.StandDown()` / `for _, event in ipairs(NS.FeatureEventNames()) do DW:UnregisterEvent(event) end` / `NS.Bus:StandDown()` / … / `runAll(NS.STAND_DOWN)`.
- `core/LifecycleSetup.lua:14-16`: `function NS.IsStoodDown()` / `return NS.Lifecycle ~= nil and NS.Lifecycle:IsDown() == true` (true under **either** hold).
- `settings/Slash.lua:100-103`: `local function storedEnabled()` / `local S = NS.SchemaRuntime` / `return not (S and S.Get(ENABLED_PATH) == false)`. `:176` `isEnabled    = storedEnabled,`.

**DRW-05 sites** (each prints the disabled line under any hold):

- `core/DropWatcher.lua:120` — `if NS.IsStoodDown() then return NS.SlashCommands:DisabledLine() end` (test-mode refusal)
- `core/DropWatcher.lua:177-178` — `if NS.IsStoodDown() then` / `NS.Print(NS.SlashCommands:DisabledLine())` (`NS.ScanGroup`)
- `core/DropWatcher.lua:282-283` — same shape (`NS.RetryInspect`)
- `core/DropWatcher.lua:393-394` — same shape (`NS.PostTradeables`)
- `modules/Sim.lua:128` — `if NS.IsStoodDown() then return NS.SlashCommands:DisabledLine() end` (`Sim.Refusal`)
- The perf hold is real: `tests/perf.lua:147` `NS.Lifecycle:Hold(NS.HOLD_PERF)`, and `core/PerfSetup.lua` hands the latch to the harness.

**DRW-04, the suite** (`tests/test_disabled.lua`, 179 lines):

- `:88` `-- red under: drop the UnregisterEvent loop in NS.StandDown (core/DropWatcher.lua)`: the only falsification comment.
- `:90` `for _, event in ipairs(PINNED) do assertEqual(m.__fire(event), 0, event) end`
- `:103-105` `m.__fireUnconditional(NS.addon, "PLAYER_REGEN_DISABLED")` / `…"PLAYER_REGEN_ENABLED")` / `assertEqual(#m.__svWrites(), 0)`
- `:111` `for _, verb in ipairs({ "help", "version", "list", "get enabled", "diagnostics", "profile" }) do`
- `:127` `for _, verb in ipairs({ "show", "test", "lock" }) do`
- `:174` `m.ldbObjects.DropWatcher.OnClick(m.UIParent, "RightButton")` (no `"LeftButton"` case)
- `git grep -n 'HOLD_PERF\|:Hold(' -- tests ':!tests/_kit'` -> only `tests/perf.lua:147` and `:149` (no step-10 case)

## Settings (options-ui) — DRW-06

- `settings/PageEditors.lua:225-227`: `t.host:SetParent(holder.frame)` / `t.host:ClearAllPoints()` / `t.host:SetAllPoints(holder.frame)`, where `holder` is `h.AceGUI:Create("SimpleGroup")` (`:218`).
- `settings/PageEditors.lua:200-206`: `function P.ParkSituationTable(ctx)` … `t.host:SetParent(ctx.panel)`.
- `settings/Panel.lua:75-79`: `local function renderGeneral(c)` / `Settings.PageEditors.ParkSituationTable(c)` / `Helpers.ClearScroll(c)` / ….
- `git grep -n 'OnRelease' -- settings modules` -> only a comment at `settings/Panel.lua:23`. No `"OnRelease"` callback is set on `holder`.
- Other greps were clean: `SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory` → none. `ScrollUp-Up|ScrollDown-Up|LSM30_` → none. No color rows.

## Shared media and close controls — DRW-01

```
git grep -n 'MakeCloseButton(' -- '*.lua' ':!libs' ':!tests'
core/CoreSetup.lua:95:    return lib.MakeCloseButton(parent, onClick, addonName)      (the wrapper, defined :94)
modules/DetailCard.lua:523 / modules/OfferPanel.lua:129 / modules/SimPanel.lua:559 / modules/Toast.lua:269 / modules/WindowTitleBar.lua:257  (calls to NS.MakeCloseButton)
core/CoreSetup.lua:49:    NS.MakeCloseButton = function() return nil end   (degraded twin)
modules/Toast.lua:270-272: if not close then / close = NS.Window.TextButton(f, 20, nil, "×", function() Toast.Dismiss() end) / end
```

## Compat family (compat)

`core/Compat.lua:2-4`: `-- core/Compat.lua — the root of the compat family (compat, design spec §4), the only caller of`
/ `-- version-variant, deprecated and optional client APIs; core/CompatWorld.lua and core/CompatItem.lua` /
`-- add stable reads to the same NS.Compat. …`. TOC: `:49 core\Compat.lua`, `:52 core\CompatWorld.lua`,
`:56 core\CompatItem.lua`. A sweep of bare calls outside the family (`GetInstanceInfo|…|UnitGUID|C_Item`,
comment lines excluded) found only `core/ItemSetup.lua:49-50`, inside the `LibKa0s-Item-1.0`
library-absent stub.

## Re-vendor record (audit-review-history)

```
git log --format=%H -- libs/LibKa0s tests/_kit | (read provenance at each commit) | sort -u
-> Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0      (one tag; docs/revendor/ absent)
```
