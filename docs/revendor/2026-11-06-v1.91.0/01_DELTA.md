Delta: LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-DW` of the cross-repo run `Ka0sAddonsCommonTasks/docs/2026-11-06-FOLLOWUPS_V1_91/` (branch `feat/2026-11-06-followups-v1-91`). Written before the copy.

## Step 0 pre-flight

Skipped, as the item directs. The installed skill's roster regex expects markdown links, while `../WowAddonStandards/standards/ADDONS.md` writes `` `../../<Folder>/` ``, so it matches no addon; its `tag_at` helper also arrived with its positionals substituted. Both are fixed upstream in this run (`FU-DC1`). For this addon alone, by hand with a named-variable `tag_at`:

    head -1 docs/revendor/2026-11-06-v1.90.0/01_DELTA.md   ->  Delta: LibKa0s v1.89.0 -> v1.90.0
    tag_at 2f1e9fd^   (2f1e9fd = SF1-RV-DW, the v1.90.0 re-vendor)  ->  v1.89.0

ok. No base correction is owed.

## Source

    git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/fu-rv-dw-2224415/ex
    git -C ../LibKa0s rev-parse 'v1.91.0^{commit}'      ->  55bfbb47180ad0b8eb53c8c5277ea7176ab42c36
    git -C ../LibKa0s ls-remote --tags origin v1.91.0   ->  (empty: the tag is local, cut by FU-L3 and pushed only at the owner's go-ahead)

The provenance line names v1.90.0, not v1.91.0, so this is a new re-vendor and not a refresh.

## 3a. Claimed version, and the base

    grep -n '[Bb]undles' CLAUDE.md
      45:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).
    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   ->  78520b7 (SF2-RV-DW: Refresh LibKa0s v1.90.0)
    git show "$c:CLAUDE.md" | grep -oE 'Bundles ...'          ->  ... v1.90.0
    git log --format='%h %s' "$c..HEAD" -- CLAUDE.md          ->  (empty)

The two agree. Base **v1.90.0**.

    git -C ../LibKa0s log --oneline v1.90.0..v1.91.0
      55bfbb4 FU-L3: Release v1.91.0 adds the release run's record and its notes
      1938837 FU-L3: Release v1.91.0 moves every version line to the tag and records the consumer sweep
      3f7be30 FU-L2: Peel the toast stack cases out of test_toast.lua into test_toast_stack.lua
      acc9640 FU-L2: Peel the confirmation box and the HUD looks out of SkinPaintExtras.lua
      c1ed261 FU-L2: Peel the dropdown and its shared menu out of Widgets.lua into WidgetsDropdown.lua
      d72dc4a FU-L2: Peel the pixel edges section out of Core.lua into CorePixel.lua
      55d3b0f FU-L1: The line chart's axis, grid, markers, crosshair and series are physical pixels at any UI scale
      f4be157 Merge feat/2026-11-06-revendor-libka0s-v1-89: LibKa0s v1.90.0 (...)
      06d97b0 V89-FIN: Sync docs to the v1.90.0 re-vendor run
    git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s testkit
      LibKa0s/Core.lua             | 139 +-------
      LibKa0s/CorePixel.lua        | 162 +++++++++
      LibKa0s/LibKa0s.xml          |   4 +
      LibKa0s/SkinAceConfirm.lua   | 189 ++++++++++
      LibKa0s/SkinPaintExtras.lua  | 309 +----------------
      LibKa0s/SkinPaintHud.lua     | 169 +++++++++
      LibKa0s/Widgets.lua          | 769 +----------------------------------------
      LibKa0s/WidgetsDropdown.lua  | 805 +++++++++++++++++++++++++++++++++++++++++++
      LibKa0s/WidgetsLineChart.lua |  71 +++-
      9 files changed, 1414 insertions(+), 1203 deletions(-)

No `testkit/` file moved in this range.

## 3b. Actual version

    grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua

Every constant equals the v1.90.0 tag's (as refreshed by SF2). The line and the bytes agree.

## 3c. Per-file minor delta

Step 3c's loop over the v1.91.0 `LibKa0s/LibKa0s.xml` (71 files). The files that moved:

| File | old | new |
|---|---|---|
| Core.lua | `MAJOR, MINOR = "LibKa0s-Core-1.0", 16` | 17 |
| CorePixel.lua | (new) | `PIXEL_MINOR = 1` |
| SkinPaintExtras.lua | `EXTRAS_MINOR = 18` | 19 |
| SkinPaintHud.lua | (new) | `HUD_MINOR = 1` |
| SkinAceConfirm.lua | (new) | `CONFIRM_MINOR = 1` |
| Widgets.lua | `MAJOR, MINOR = "LibKa0s-Widgets-1.0", 25` | 26 |
| WidgetsDropdown.lua | (new) | `DROPDOWN_MINOR = 1` |
| WidgetsLineChart.lua | `CHART_MINOR = 6` | 7 |

The other 63 print `old == new`. Four files are new (the peels); none is behind. **No cross-major skew.**

The tag's XML adds the four in this order: `CorePixel.lua` after `Core.lua`; `SkinPaintHud.lua` then `SkinAceConfirm.lua` after `SkinPaintExtras.lua`; `WidgetsDropdown.lua` after `Widgets.lua`.

## 3d. Both diffs (before the copy)

    diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   ->  Core.lua, LibKa0s.xml, SkinPaintExtras.lua, Widgets.lua, WidgetsLineChart.lua differ;
                                                                     Only in <scratch>: CorePixel.lua, SkinAceConfirm.lua, SkinPaintHud.lua, WidgetsDropdown.lua;
                                                                     plus 194 `Only in <scratch>/LibKa0s/media/icons` lines (undeclared icons; the declaration working)
    diff -rq                     <scratch>/LibKa0s libs/LibKa0s   ->  same
    diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit    ->  (empty)
    diff -rq                     <scratch>/testkit tests/_kit    ->  (empty)

Content drift in the files this tag changed or added; the copy fixes it. No line-ending-only drift, no file removed upstream.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Twenty-one majors looked up: Bus, Charts, Compat, Core (40 sites), DebugLog, Env, Glow, IconBrowser, Item, Launcher, Lifecycle, Media, Options (20), Perf, Pool, Schema, Sim, Skin (29), Slash, Toast, Widgets (11). Every major whose minor moved (Core, Skin, Widgets) is consumed. The addon draws no `LineChart` (`grep -rn LineChart --include='*.lua' . | grep -v libs/ | grep -v _kit` is empty).

## 3f. Kit revision and the pairing rule

    grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
      <scratch>/testkit/framework.lua:20:Kit.VERSION = 51
      tests/_kit/framework.lua:20:Kit.VERSION = 51

Kit 51 on both sides. A consumer of LibKa0s v1.9.0+ takes kit revision 11+ in the same commit; both payloads are copied whole, so the pairing holds by construction.

## 3g. Contract delta

The moved, consumed majors are Core, Skin and Widgets. Their new documents at the tag: `docs/api/Core/version-17.1-docs.md`, `docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md`, `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md`. The Widgets document's *What changed at this version* (its lines 19-30) and the tag's `CHANGELOG.md` v1.91.0 block state that the three peels are pure moves ("no public member, option or behavior changes, so the member manifest lists the same names"), that no `NEEDS_*` floor rises, and that "No host owes a facade or stub member". WidgetsLineChart 7 reads `series[i].thickness` as physical pixels; this addon draws no line chart.

    grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit   ->  (empty)
    grep -rn '__PixelSize\|__WatchPixels\|__OnPixelScale\|__PixelBackdrop\|__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit   ->  (empty)

No host-supplied member's call site moved, and no addon stub mirrors a moved member.

### Blockers

- **Test file lists of library files.** `tests/loader.lua:17` builds its list with `Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")`, read from the XML in its order, so the four new files load with no edit. `tests/test_harness.lua:41` asserts that same property. `tests/test_window_insights.lua:13` names only `Charts.lua` and `ChartsRender.lua`, which did not move. No list to edit.
- **Pinned exact minors.** No test pins a minor of a file that moved (the `minor N` hits under `tests/` are history comments).
- **Library-absent cases that skip a peeled shell** (`tests/test_compact_chrome.lua:397` and `tests/test_history.lua:498` skip `libs/LibKa0s/Widgets.lua`; `tests/test_skin_outline.lua:143,151` skip `Skin.lua`). The peeled files attach to their shell or return, so they are absent too; the gate after the copy is the check.

None found by reading. A red at the gate is fixed in this item's commit.

## 3h. Unrecorded vendored tags

Step 3h's listing (horizon `2026-10-14`), with `tag_at` rewritten on named variables:

    vendored: v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0 v1.87.0 v1.88.0 v1.89.0 v1.90.0
    grep -vxF -f recorded.txt vendored.txt   ->  (empty)

Empty, so no span bundle is written.

## 3i. The icon declaration

    grep -n 'LibKa0s icons:' CLAUDE.md
      46:LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, eye, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, move, people, reset, settings, speech-bubble, transfer, volume-high.

It is the next non-blank line under the provenance line (45), and the provenance sentence ends its line. **Kept unchanged** (decided: the item keeps the icons line). `git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s/media` is empty, so every declared name still exists, and this item adds no host art. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`). The owner's in-client smoke is the backstop for a name the host forgot to declare.

## 3j. Tests that assume the whole icon folder

    grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
      tests/prose_waivers.lua:15            (a comment)
      tests/test_mine_cells.lua:149         (opens a named, declared icon)
      tests/test_tip_marks.lua:42, :545     (reads declared icons' TGA sizes)

All read declared names only. No blocker.

## Dead stub mirrors

No `__` member was removed in this range (the peels move members between files without renaming them). None to remove.
