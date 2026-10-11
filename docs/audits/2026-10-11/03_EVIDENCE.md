# Evidence: Ka0s Drop Watcher (standards audit, 2026-10-11)

Every command below was run on 2026-10-11 from the repo root at `87d8694` with a clean tree, unless
another directory is named. Heavy runs went through `~/.claude/dev-copilot/bin/ka0s-bounded`. Every
count states its scope.

## Lint and the headless suite

```
$ ka0s-bounded luacheck .
Total: 0 warnings / 0 errors in 109 files
$ ka0s-bounded lua tests/run.lua
886 passed, 0 failed, 1 skipped, 887 total
```

`.luacheckrc:11` is
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }`.
`tests/` is linted. The harness global is in `files["tests/"]` (`.luacheckrc:34`), and there is no
top-level `ignore` (`.luacheckrc:13`, `-- No top-level \`ignore\`: a blanket suppression reaches every file (lint).`).

## Vendored

The provenance line is at `CLAUDE.md:41`:
`Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).` `grep -n 'Bundles \[LibKa0s\]'
README.md` printed nothing.

```
$ git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C <scratch>/lk
$ diff -r <scratch>/lk/LibKa0s libs/LibKa0s && echo payload-clean
payload-clean
$ diff -r <scratch>/lk/testkit tests/_kit && echo kit-clean
kit-clean
```

`Kit.VERSION = 38` (`tests/_kit/framework.lua:20`).

## Line endings

```
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes      -> 26:* text=auto eol=crlf
$ grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes            -> 36:*.sh text eol=lf / 37:*.py text eol=lf
$ grep -c ' binary$' .gitattributes                               -> 23
$ diff <(tr -d '\r' < .gitattributes) <canonical client-bound body extracted from
       ../WowAddonStandards/standards/standards/line-endings.md §5 (84 lines)>   -> no output
$ <AUDIT.md step 4 (e) loop over git ls-files -z>                 -> 0
```

Scope of (e): the whole tracked set, with no exclusions.

## Packaging

The checks were run under `bash` with `.pkgmeta`'s CRs stripped:

```
(a) NOT IGNORED            -> (nothing)
(b) UNACCOUNTED            -> .git   (exempt by rule)
(c) FALSE CLAIM            -> (nothing; the three conditional lines are commented out)
```

## Over-cap census

```
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l \
    | awk '$2!="total" && $1>1000'
   1107 core/Compat.lua
```

Scope: the tracked, authored Lua, with `tests/` included. Nothing is over 1500. The census heading
is at `docs/ARCHITECTURE.md:327`, and `:332` reads "Nothing is over the cap today." `test_layout_cap` is
declared from the kit (`tests/run.lua:137`).

## Bus

```
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/)' | xargs grep -nE '(Send|Register)Message\("Ka0s_'
(nothing)
$ ... | xargs grep -noE '"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"'
core/Bus.lua:22..31   "Ka0s_DropWatcher_DropAdded" … "Ka0s_DropWatcher_HistoryChanged" (10, all PascalCase tails)
```

## Close controls

```
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/)' | xargs grep -n 'MakeCloseButton('
core/CoreSetup.lua:92   (a comment quoting the grep)
core/CoreSetup.lua:95       return lib.MakeCloseButton(parent, onClick, addonName)
modules/DetailCard.lua:409  e.closeButton = NS.MakeCloseButton(e, function() e:Hide() end)
modules/OfferPanel.lua:134  p.closeButton = NS.MakeCloseButton(p, function() OP.Close() end)
modules/Toast.lua:163       local close = NS.MakeCloseButton(f, function() Toast.Dismiss() end)
modules/WindowTitleBar.lua:205  f.closeButton = NS.MakeCloseButton(bar, function() W.Close() end)
```

The one wrapper is at `core/CoreSetup.lua:94-96`, and its degraded twin at `core/CoreSetup.lua:49`
(`NS.MakeCloseButton = function() return nil end`). **DRW-01:** `modules/Toast.lua:164-166`:

```lua
    if not close then
        close = NS.Window.TextButton(f, 20, nil, "×", function() Toast.Dismiss() end)
    end
```

## `## IconTexture`

`DropWatcher.toc:6` is `## IconTexture: Interface\AddOns\DropWatcher\media\logos\dropwatcher.logo.128.tga`.

```
$ od -An -tu1 -N18 media/logos/dropwatcher.logo.128.tga
   0   0   2   0   0   0   0   0   0   0   0   0 128   0 128   0  32   8
```

Byte 2 is image type 2 (uncompressed), bytes 12-15 give 128×128, and byte 16 is 32-bit depth.

## Disabled state

- The latch: `core/LifecycleSetup.lua:45-46` (`NS.HOLD_DISABLED = "disabled"`, `NS.HOLD_PERF = "perf"`)
  and `:53` (`NS.Lifecycle = lib:New({`).
- The stand-down: `core/DropWatcher.lua:89-95`. It unregisters every `NS.FeatureEventNames()` entry,
  runs `NS.Bus:StandDown()` and every module's `NS.STAND_DOWN` step, and ends test mode.
- The suite: `tests/test_disabled.lua:77-94` asserts `registered(m) == ""`, no live timer, and that
  every pinned event fires into nothing (`-- red under: drop the UnregisterEvent loop in
  NS.StandDown`). `:96-103` asserts no SavedVariables write on the combat edges while disabled.
- The hook census: the only hook is `hooksecurefunc("NotifyInspect", fn)` (`core/Compat.lua:538`).
  Its body returns at once while stood down (`modules/Inspect.lua:565`,
  `if notifying or stoodDown() then return end`). `HookScript` is used only on the addon's own frames
  (`modules/Toast.lua:150-151`, `modules/Window.lua:136-137`).

## Launcher

`core/LauncherSetup.lua:47-75`: `label = NS.BRAND`, `isEnabled`/`setEnabled`, `isLocked`/`toggleLock`,
`isTestMode`/`toggleTestMode`, `isWindowShown`/`toggleWindow`, `debug`, and `debugAtEnable`. The
`ADDONS.md` row (`standards/ADDONS.md:23`) reads
`Enabled · Locked · Test mode · Show window (the drop feed)`.

## Diagnostics and slash

- `settings/Slash.lua:50`: `{"diagnostics", L["Write the diagnostics report to the debug console"],`
  is the one row.
- `settings/Slash.lua:162-164`: `liveVerbs` is copied from `lib.LIVE_VERBS`, then `profile` is appended.
- `README.md:101-107`: `## Reporting a bug` with the three bullets and the closing note.

## Documentation map

```
$ git ls-files 'docs/*.md' | grep -vE '<the documentation-§3 stores>' | <count rows per file in ARCHITECTURE.md:268-313>
```

Every file counts 1, except `ARCHITECTURE.md` at 0, which is a MAY either way. The hub is 332 lines
(`wc -l docs/ARCHITECTURE.md`).

## The register

`docs/ARCHITECTURE.md:315-325`. Four rows, all `Decided 2026-10-10`. The evidence for DRW-02 is in
each row's `Why` cell: "A LibKa0s promotion issue is filed at the end of the v1 run (design spec §14)",
and in the chat-sending row "A WowAddonStandards proposal issue is filed at the end of the v1 run".
`gh issue list --repo tusharsaxena/DropWatcher --state all` printed nothing.

## Complexity

```
$ ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
  complexity  pass  — 0 warnings (fun rate 0.00), 25529 NLOC / 3369 funcs, avg NLOC 7.0, avg CCN 2.4 (max 13)
  record:  newest bundle 20261011-091808 measured eb7aafb, 1 commit(s) behind HEAD
$ grep -o '"blindFiles"[^,}]*' docs/automated-tests/20261011-091808/manifest.json
"blindFiles": 0
```

The newest row is `docs/automated-tests/RESULTS.md:35`, `eb7aafb`, clean. `git rev-list --count
eb7aafb..HEAD` is 1, and that commit (`87d8694`) only adds the bundle.
