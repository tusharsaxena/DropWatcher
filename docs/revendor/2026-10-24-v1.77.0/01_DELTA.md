Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta

Re-vendor item DW-RV of the cross-repo run "keybindings (015), settings layout (020), frame strata
(030)" (`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`). The mechanics are
`/dev-copilot:wow-revendor-libka0s` at dev-copilot 2.4.0 (the installed plugin), Steps 2 to 4. The
owner pre-decided the adoptions this run makes (DW-KB and DW-ZS in that bundle's
`plan-data/items.json`), so Step 5 records the candidates as decided or deferred and Step 6 does not
interview (`02_CANDIDATES.md`, `03_DECISIONS.md`). No issue is filed.

## The source is the local tag v1.77.0

```sh
git -C ../LibKa0s cat-file -t v1.77.0                 # tag (annotated, 7380d36)
git -C ../LibKa0s rev-parse 'v1.77.0^{commit}'        # 78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f
git -C ../LibKa0s ls-remote --tags origin v1.77.0     # (nothing: the tag is local until the owner's go-ahead)
git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C <scratch>
```

The copy is taken from the tag, never from the LibKa0s working tree, and the tag was never checked
out. `tools/` is extracted only for `prune-icons.lua`, and is not copied into the addon.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # 6f69e6e (DW-RV2: Refresh ... moved local tag v1.76.0)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq --strip-trailing-cr <scratch>/old/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>/old/LibKa0s/media/icons'   # (empty)
diff -rq --strip-trailing-cr <scratch>/old/testkit tests/_kit && echo kit-matches                                        # kit-matches
```

The base is **v1.76.0**. The line, the last payload commit and the payload agree.

One note on the base tag. `v1.76.0` now resolves to commit `e692491` (LK-92, a README pointer
change in LibKa0s), not the `7e81ff7` that the v1.76.0 bundle's refresh section names. The tag moved
again, still local, after DW-RV2. That move touched no file under `LibKa0s/` or `testkit/`: the
payload diff above against today's `v1.76.0` is empty. So nothing in this addon needed a third
refresh, and the frozen v1.76.0 bundle stays as it is.

```sh
git -C ../LibKa0s log --oneline v1.76.0..v1.77.0 | wc -l                     # 15 commits
git -C ../LibKa0s diff --stat v1.76.0 v1.77.0 -- LibKa0s testkit | tail -1
# 18 files changed, 1672 insertions(+), 34 deletions(-)
```

Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-10-23-v1.76.0`, states base
v1.75.2, and the provenance line before its re-vendor commit `da44ec7` named v1.75.2. `ok`; no base
correction.

## 3b. Actual version

The minors in `libs/LibKa0s/*.lua` before the copy were v1.76.0's, file for file (the `old` column
below). The line and the bytes agreed.

## 3c. Per-file minor delta

```sh
for f in $(git -C ../LibKa0s show v1.77.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do
  printf '%s  old: %s  new: %s\n' "$f" \
    "$(grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/"$f" 2>/dev/null)" \
    "$(git -C ../LibKa0s show v1.77.0:LibKa0s/"$f" | grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+')"
done
```

The tag ships 41 files (v1.76.0 shipped 40). Twelve moved, one of them new:

| File | Constant | Old | New |
|---|---|---|---|
| `Core.lua` | `MINOR` (`LibKa0s-Core-1.0`) | 11 | **12** |
| `DebugLog.lua` | `MINOR` (`LibKa0s-DebugLog-1.0`) | 20 | **21** |
| `PerfPanel.lua` | `PANEL_MINOR` | 8 | **9** |
| `SimPanel.lua` | `SIM_PANEL_MINOR` | 5 | **6** |
| `Widgets.lua` | `MINOR` (`LibKa0s-Widgets-1.0`) | 14 | **15** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 4 | **5** |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR` | 2 | **3** |
| `Options.lua` | `MINOR` (`LibKa0s-Options-1.0`) | 29 | **30** |
| `OptionsIds.lua` | `IDS_MINOR` | 2 | **3** |
| `OptionsCombat.lua` | `COMBAT_MINOR` | 1 | **2** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | **8** |
| `OptionsKeybinds.lua` | `KEYBINDS_MINOR` | (new file) | **3** |

Composite keys at the tag: Core **12**, DebugLog **21.3.1**, Perf **15.1.1.9**, Sim **2.3.6**,
Widgets **15.1.5.3.3**, Options **30.2.34.3.5.9.2.8.4.2.1.3**. Seventeen majors across forty-one
files. No consumer file was behind, so there is no cross-major skew.

## 3d. Both diffs

Before the copy, against the tag:

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>/LibKa0s/media/icons'
# the twelve files above differ (OptionsKeybinds.lua: Only in <scratch>/LibKa0s), and LibKa0s.xml
diff -rq <scratch>/testkit tests/_kit
# README.md, framework.lua differ; Only in <scratch>/testkit: bindings_xml.lua, mock_bindings.lua, mock_layers.lua
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing removed upstream needed deleting.

After `cp -r` and **before** the prune, both diffs, content and bytes, were empty against the whole
copy. After the prune:

```sh
diff -r <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>/LibKa0s/media/icons'   # (empty)
diff -r <scratch>/LibKa0s libs/LibKa0s | wc -l     # 198: 196 undeclared Open Iconic marks + 2 set folders
diff -r <scratch>/testkit tests/_kit               # (empty)
```

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Seventeen majors looked up (Bus, Compat, Core, DebugLog, Env, Glow, Item, Launcher, Lifecycle,
Media, Options, Perf, Pool, Schema, Sim, Slash, Widgets), the same as at v1.76.0. Every major whose
minor moved is consumed: Core (23 lookup sites), DebugLog (3), Perf (4), Sim (4), Widgets (7) and
Options (11, the instance built in `settings/OptionsSetup.lua`).

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION *=' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# tag: Kit.VERSION = 42    vendored before: Kit.VERSION = 41
```

Kit revision 41 -> **42**: `mock_bindings.lua` and `mock_layers.lua` (both opt-in), and
`Kit.assertBindingsXml` / `Kit.keybindThroughTab` in `bindings_xml.lua`, loaded by `framework.lua`
(LibKa0s `docs/api/testkit/version-42-docs.md`). Both payloads are copied whole, so the pairing rule
holds by construction. `docs/testing.md:19` names the kit revision and moves to 42 in this commit.

## 3g. Contract delta

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
# (no host-supplied __Attach* seam)
git -C ../LibKa0s show v1.77.0:CHANGELOG.md     # the v1.77.0 block and its "What a consumer owes"
```

- **Core 12, DebugLog 21, PerfPanel 9, SimPanel 6: the tool windows are toplevel and re-raise a shown
  confirmation** (`Core.RaiseStaticPopups`). The CHANGELOG says a consumer owes nothing for this.
  Three surfaces here sit at DIALOG (`modules/CompactChrome.lua:301`, `modules/DetailCard.lua:663`,
  and the floating `modules/OfferPanel.lua:265`). The CHANGELOG asks such an addon to note in its
  LAYERS comment that the console can cover them. This addon has no LAYERS table yet, and DW-ZS
  writes it, so that note is DW-ZS's too. No host code is wrong the moment the bytes land.
- **Widgets 15, WidgetsAutocomplete 3: popups clamped to screen.** Additive. A popup that fits sits
  where it did.
- **WidgetsDragHandle 5: `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha`.** Opt-in;
  absent, the handle is minor 4's. This addon builds no DragHandle.
- **OptionsIds 3, OptionsCombat 2: the suggestion list closes when combat starts.** `__`-prefixed
  members only; nothing owed.
- **Options 30, OptionsKeybinds 1-3, OptionsCompose 8: new instance members.** No existing member's
  call site or return shape moved.

### Blockers

One: the CHANGELOG's "every Options degradation stub gains `KeybindingsTab`, `KeybindRows`,
`KEYBINDS_UNCHANGED` and `StrataTooltip`" (v1.77.0 *What a consumer owes*; Options
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`). On the fresh payload, before any host
change, the gate went red on exactly that, for the stated reason:

```
FAIL  parity: the Options helpers stub carries the whole live surface
      tests/_kit/asserts.lua:330: LibKa0s-Options-1.0: the degraded stub diverges from the live
      surface in 4 place(s) — KEYBINDS_UNCHANGED is missing (live: string); KeybindRows is missing
      (live: function); KeybindingsTab is missing (live: function); StrataTooltip is missing (live:
      function)
1688 passed, 1 failed, 1 skipped, 1690 total
```

The fix lands in this commit, in the library-absent branch of `settings/OptionsSetup.lua`:
`H.StrataTooltip` answers `""`, `H.KeybindingsTab` and `H.KeybindRows` answer `nil`, and
`H.KEYBINDS_UNCHANGED` is `""`. These are the shapes BankLedger and MultiMeters already use for the
same stub. No other suite went red. `tests/test_bindings.lua` still asserts the pre-v2.88.0
`Bindings.xml` shape and passes, because the kit's `Kit.assertBindingsXml` is opt-in. Moving the
file and its test to launcher-§6's category shape is DW-KB's job, so nothing is marked pending here.

## 3h. Unrecorded vendored tags

```sh
# the Step 3h listing, horizon 2026-10-14
# vendored: v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0    recorded: the same five    unrecorded: (none)
```

No span bundle is needed.

## 3i. The icon declaration

`CLAUDE.md:42` is a standalone provenance line. The declaration on the next line is unchanged from
v1.75.0's bundle: 28 names, with the evidence in `docs/revendor/2026-10-22-v1.75.0/01_DELTA.md` 3i.
The tag's `docs/releasing.md` table (*Library-drawn icons are the host's to declare*) is still exactly
`close`, `copy`, `clear` and `info`. OptionsKeybinds, OptionsCompose 8 and WidgetsDragHandle 5 draw no
`Media.Icon` mark of their own (`grep -n 'Icon(' OptionsKeybinds.lua OptionsCompose.lua
WidgetsDragHandle.lua` at the tag finds nothing). This item adds no host draw site.

```
LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, people, reset, speech-bubble, transfer.
```

### The prune

```sh
lua <scratch>/tools/prune-icons.lua .
# prune-icons: .: 28 icon(s) declared; kept 29 file(s), removed 5811
```

That is the same 5,811 as v1.76.0 (196 Open Iconic marks, 1,435 Phosphor files, 4,180 Game-icons
files). All of them arrived with the copy and none reached git. What ships is unchanged: 28 `.tga`
files and `LICENSE-open-iconic.txt`.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

Unchanged from v1.76.0: one comment (`tests/prose_waivers.lua:15`) and three declared-name file reads
(`tests/test_mine_cells.lua:149`, `tests/test_tip_marks.lua:42`, `:546`). No blocker.
