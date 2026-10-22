Delta: LibKa0s v1.72.0 -> v1.75.0

# 01 — Delta

Re-vendor item DW-RV of the cross-repo run "LibKa0s issues #45-#58"
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`). The mechanics are
`/dev-copilot:wow-revendor-libka0s` at dev-copilot 2.4.0, Steps 2 to 4. The owner pre-decided every
adoption in that bundle's `items.tsv` (DW-01 to DW-09), so Step 5 records the candidates as decided
and Step 6 does not interview (`02_CANDIDATES.md`, `03_DECISIONS.md`).

## The source is the local tag v1.75.0

```sh
git -C ../LibKa0s cat-file -t v1.75.0                 # tag (annotated)
git -C ../LibKa0s rev-parse 'v1.75.0^{commit}'        # 265a89eba3db44f2d85e61287d1691cca6b1effd
git -C ../LibKa0s ls-remote --tags origin v1.75.0     # (nothing: the tag is local until the owner's go-ahead)
git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>
```

The copy is taken from the tag, never from the LibKa0s working tree. `tools/` is extracted only for
`prune-icons.lua`, and is not copied into the addon.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.72.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # ff567d3 (DW-P22)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.72.0
git -C ../LibKa0s archive v1.72.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq --strip-trailing-cr <scratch>/old/LibKa0s libs/LibKa0s && \
  diff -rq --strip-trailing-cr <scratch>/old/testkit tests/_kit && echo payload-matches
# payload-matches
```

The base is **v1.72.0**. The line, the last payload commit and the payload agree. v1.73.0 and
v1.74.0 were never vendored here; the range below covers them, so they need no span bundle (3h).

```sh
git -C ../LibKa0s log --oneline v1.72.0..v1.75.0 | wc -l      # 46 commits
git -C ../LibKa0s diff --stat v1.72.0 v1.75.0 -- LibKa0s testkit | tail -1
# 5748 files changed, 8565 insertions(+), 108 deletions(-)   (5,723 of them are v1.74.0's icon art)
```

Step 0 pre-flight: the newest single-tag bundle, `2026-10-14-v1.72.0`, states base v1.71.0, and the
provenance line before its re-vendor commit `ff567d3` named v1.71.0. `ok`; no base correction.

## 3b. Actual version

The minors in `libs/LibKa0s/*.lua` before the copy were v1.72.0's, file for file (the `old` column
below). The line and the bytes agreed.

## 3c. Per-file minor delta

```sh
for f in $(git -C ../LibKa0s show v1.75.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do
  printf '%s  old: %s  new: %s\n' "$f" \
    "$(grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/"$f" 2>/dev/null)" \
    "$(git -C ../LibKa0s show v1.75.0:LibKa0s/"$f" | grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+')"
done
```

The tag ships 40 files (34 at v1.72.0). The same loop, run tag to tag, places each move:

| Tag | File | Constant | Old | New |
|---|---|---|---|---|
| v1.73.0 | `Options.lua` | `MINOR` | 28 | **29** |
| v1.73.0 | `OptionsDrawer.lua` | `DRAWER_MINOR` | (new) | **1** |
| v1.74.0 | `Media.lua` | `MINOR` | 4 | **5** |
| v1.74.0 | `MediaIcons.lua` | `ICONS_MINOR` | (new) | **1** |
| v1.75.0 | `OptionsTabs.lua` | `TABS_MINOR` | 8 | **9** |
| v1.75.0 | `OptionsIdList.lua` | `IDLIST_MINOR` | 4 | **5** |
| v1.75.0 | `Core.lua` | `MINOR` | 10 | **11** |
| v1.75.0 | `DebugLog.lua` | `MINOR` | 19 | **20** |
| v1.75.0 | `DebugLogDiagnostics.lua` | `DIAG_MINOR` | 2 | **3** |
| v1.75.0 | `Widgets.lua` | `MINOR` | 12 | **13** |
| v1.75.0 | `Item.lua` | `MINOR` | 2 | **3** |
| v1.75.0 | `PerfPanel.lua` | `PANEL_MINOR` | 6 | **7** |
| v1.75.0 | `Glow.lua` | `MINOR` (`LibKa0s-Glow-1.0`, new major) | (new) | **1** |
| v1.75.0 | `Sim.lua` | `MINOR` (`LibKa0s-Sim-1.0`, new major) | (new) | **1** |
| v1.75.0 | `SimTimeline.lua` | `TIMELINE_MINOR` | (new) | **1** |
| v1.75.0 | `SimPanel.lua` | `SIM_PANEL_MINOR` | (new) | **1** |

Composite keys at the tag: Options **29.2.34.2.5.9.1.7.4.2.1** (was 28.2.34.2.4.8.1.7.4.2), Widgets
**13.1.4.3.2** (was 12.1.4.3.2), DebugLog **20.3.1** (was 19.2.1), Perf **15.1.1.7** (was
15.1.1.6), Media **5.1** (was 4), Sim **1.1.1**. PerfPanel 7 is comment-only: LK-11 took outcome B,
so `W.StepPanel` never shipped (no `WidgetsStepPanel.lua`) and the step-panel renderer is private to
`LibKa0s-Sim-1.0`. The library is seventeen majors across forty files. No consumer file was behind,
so there is no cross-major skew.

## 3d. Both diffs

Before the copy, against the tag:

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>'
# Files .../Core.lua, DebugLog.lua, DebugLogDiagnostics.lua, Item.lua, LibKa0s.xml, Media.lua,
#   Options.lua, OptionsIdList.lua, OptionsTabs.lua, PerfPanel.lua, Widgets.lua differ
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -c '^Only in <scratch>'
# 119: Glow, MediaIcons, OptionsDrawer, Sim, SimPanel, SimTimeline; 111 new Open Iconic marks;
#   media/icons/phosphor and media/icons/game-icons
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
# Files .../README.md, framework.lua, inventory.lua, run-automated-tests.sh, vendor_sync.lua differ
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing upstream removed needed deleting.

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

Unchanged from v1.72.0: fifteen majors looked up, one setup file each (Env, Core, Bus, Compat,
DebugLog, Widgets, Pool, Lifecycle, Launcher, Item, Perf, Media; Schema, Slash, Options). The two
new majors, Glow and Sim, have no lookup yet; DW-08 (Glow) and DW-02 (Sim) wire them later in this
run. Every major whose minor moved except those two is consumed.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION *=' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# tag: Kit.VERSION = 41    vendored before: Kit.VERSION = 39
```

Kit revision 41 (carrying revision 40's icon gate) arrives with the library in the same commit.
Both payloads are copied whole, so the pairing rule holds by construction. Revision 41 stops
exporting `Kit.__deviationRows` and `Kit.__declineFor`; `grep -rn '__deviationRows\|__declineFor'
tests/*.lua` finds nothing here. Kit 39's `__fireUnconditional` contract was already in, so
`tests/test_disabled.lua:100-115` is unaffected.

## 3g. Contract delta

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
# (no host-supplied __Attach* seam)
```

- **Options 29 (v1.73.0).** A structural `RefreshPanel` of a page on screen keeps its scroll offset.
  This addon calls `RefreshPanel(ctx, true)` from `settings/Profiles.lua:44` and
  `settings/PageEditors.lua:310` and `:343`, and never scrolls back to the top by hand after it, so
  the change is delivered (class A), not a blocker.
- **Media 5 / `Media.Icon` (v1.74.0, v1.75.0).** `Icon(addonName, name)` still answers a path for
  any catalog name, and a pruned icon draws blank. A host must pass only declared names: that is the
  declaration in 3i.
- **OptionsTabs 9 (v1.75.0).** `O.__releaseChrome` is no longer exported.

### Blockers

Fixed in this commit, beside the payload and the provenance line:

1. **Options stub: `H.Drawer`.** Options v1.73.0 adds `O.Drawer`; the library-absent stub in
   `settings/OptionsSetup.lua` is pinned by `tests/test_surface_parity.lua` ("the Options helpers
   stub carries the whole live surface") and goes red without it. Added
   `H.Drawer = function() end` (a library-absent build draws no panel).
2. **Dead mirror `H.__releaseChrome`** (OptionsTabs 9, LibKa0s#45, `library-stack-§7`'s narrowed
   `__` clause): removed from the same stub. The sibling `__` mirrors still mirror live members and
   stay.
3. **Item stub: `BonusIDsFromLink`.** Not foreseen by the item spec. Item minor 3 adds
   `Item.BonusIDsFromLink`, and `tests/test_surface_parity.lua`'s Item case pinned the stub to the
   whole live surface, so it went red (`BonusIDsFromLink is missing (live: function)`). This addon
   does not adopt the member (`02_CANDIDATES.md`), and `grep -rn "BonusIDsFromLink" core modules
   settings` finds no call site, so the case now names it in its ignore set with that grep, the
   file's own convention for a live-only member (the Pool case's keyed family). No addon code
   changes.
4. **The prose gate over the declaration.** `minimise` is a catalog name (the title-bar mark), and
   the declaration line in `CLAUDE.md` must carry it as spelled, so `tests/_kit/test_prose.lua`
   flagged `CLAUDE.md:43`. `tests/prose_waivers.lua` waives `minimis` for `CLAUDE.md`, per file and
   per word, beside the existing `modules/WindowTitleBar.lua` waiver for the same name.

## 3h. Unrecorded vendored tags

```sh
# the Step 3h listing, horizon 2026-10-14
# vendored: v1.72.0    recorded: v1.72.0    unrecorded: (none)
```

Nothing to back-fill; no span bundle.

## 3i. The icon declaration

`CLAUDE.md:42` is a standalone provenance line, so no split was needed. The declaration is the next
line, pre-decided by the item spec and re-checked against a fresh grep of the draw sites
(`NS.Icon(`, `icon = "`, `TextButton(`, `FR.Button(`, `iconButton(`, `setMark(`, `SetButtonMark(`)
and a sweep of every string literal in `core/`, `modules/` and `settings/` that is also a catalog
name. No new draw site was found and no declared name lacks one:

```
LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, people, reset, speech-bubble, transfer.
```

| Name | Evidence |
|---|---|
| add | `modules/WindowTitleBar.lua:356` (setMark, minimized) |
| minimise | `modules/WindowTitleBar.lua:281`, `:356` |
| fullscreen-enter | `modules/WindowTitleBar.lua:358` |
| fullscreen-exit | `modules/WindowTitleBar.lua:285`, `:360` |
| lock | `modules/WindowTitleBar.lua:234` (restriction badge) |
| chevron-down | `core/WidgetsSetup.lua:30` (dropdown chevron, host-passed), `modules/CompactChrome.lua:287`, `modules/CompactGroup.lua:604`, `modules/WindowGroup.lua:629`, `:637`, `:908`, `modules/WindowHistory.lua:495`, `modules/FooterRow.lua:157`, `:173` |
| chevron-right | `modules/CompactGroup.lua:604`, `modules/WindowGroup.lua:908`, `modules/WindowHistory.lua:495` |
| chevron-up | `modules/WindowGroup.lua:637`, `modules/FooterRow.lua:171` |
| confirm | `core/WidgetsSetup.lua:31` (dropdown tick, host-passed), `modules/SimPanel.lua:427`, `modules/WindowCells.lua:838`, `:840`, `modules/MineCells.lua:393`, `:394`, `:430` |
| chat | `modules/WindowCells.lua:837`, `modules/DetailCells.lua:581`, `modules/DetailCard.lua:629`, `modules/CompactGroup.lua:238`, `modules/WindowGroup.lua:594`, `modules/Toast.lua:400` |
| clock | `modules/WindowCells.lua:839`, `modules/MineCells.lua:392`, `:429` |
| reset | `modules/WindowCells.lua:841`, `modules/MineCells.lua:431`, `modules/DetailCells.lua:630-631`, `modules/HistoryCard.lua:177` |
| ban | `modules/WindowCells.lua:848`, `modules/HistoryCard.lua:181`, `:184` |
| external-link | `modules/MineCells.lua:391`, `modules/DetailCells.lua:567`, `modules/OfferPanel.lua:102` |
| speech-bubble | `modules/DropsStrip.lua:114`, `modules/OfferPanel.lua:174` |
| people | `modules/DropsStrip.lua:116` |
| link-intact | `modules/DetailCells.lua:600-601`, `modules/HistoryCard.lua:170-171` |
| edit | `modules/DetailCells.lua:590-594` |
| transfer | `modules/DetailCells.lua:644-655`, `modules/TipMarks.lua:69` |
| cancel | `modules/DetailCard.lua:636` |
| arrow-up, arrow-down | `modules/TipMarks.lua:68`, `:70` (drawn at `:99`) |
| arrow-right | `modules/TipMarks.lua:106`, `:112`, `modules/HistoryCard.lua:191`, `:194` |
| help | `modules/WindowGroup.lua:486` (the item cell's fallback) |
| info | `modules/Window.lua:445` (the `/dw test` banner; stays declared when DW-06 hands it to `W.TestStrip`, which takes host-passed art) |
| close | library-drawn: `Core.MakeCloseButton` through `NS.MakeCloseButton` (`core/CoreSetup.lua:105-106`: main window, Offer panel, sim panel), the DebugLog console and PerfPanel |
| copy, clear | library-drawn: the DebugLog console's title bar (wired in `core/DebugLogSetup.lua`) |

This addon has no Options id list (no `IdList(` or `helpIcon` call outside the stub), so the
library's own `info` is not owed; `info` is declared for this addon's own draw above.

The catalog names in string literals that are **not** icon draws, checked one by one: `expand`,
`header`, `key`, `list`, `location`, `map`, `search`, `settings`, `shield`, `text`, `timer`,
`unlock` (row kinds, scenario names, slash verbs, filter keys, schema types).

Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`). The owner's in-client smoke (`docs/smoke-tests.md` INSTALL-5,
SM-DW-2 and SM-DW-3) is the backstop: a pruned icon still resolves to a path and draws blank, and
the gate cannot see a name the host forgot to declare.

### The prune

```sh
lua <scratch>/tools/prune-icons.lua .
# prune-icons: .: 28 icon(s) declared; kept 29 file(s), removed 5811
```

| Set | Removed |
|---|---|
| Open Iconic (unprefixed) | 196 marks (224 at the tag, 28 kept) |
| Phosphor (`media/icons/phosphor/`) | 1,435 files: 1,434 marks and `LICENSE-phosphor.txt`; the folder is gone |
| Game-icons (`media/icons/game-icons/`) | 4,180 files: 4,178 marks, `LICENSE-game-icons.txt` and `AUTHORS.txt`; the folder is gone |

What ships: 28 `.tga` and `LICENSE-open-iconic.txt`. Against the v1.72.0 copy the repository loses
85 of its 113 marks.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
# tests/prose_waivers.lua:15      (a comment)
# tests/test_mine_cells.lua:149   opens the icons of the action look tables: all declared
# tests/test_tip_marks.lua:42     arrow-up, arrow-down, transfer: declared
# tests/test_tip_marks.lua:547    arrow-right: declared
```

No whole-catalog loop and no undeclared name; all three pass after the prune. No blocker.
