Delta: LibKa0s v1.95.0 -> v1.102.0

Recorded before anything was copied. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.102.0 LibKa0s testkit tools` (tag commit 2748549, pushed: `git -C ../LibKa0s ls-remote --tags origin v1.102.0` lists it). Run under the rolls UX round, item RX-13, on the owner's ruling of 2026-11-15 (the waiting mark becomes an hourglass; the re-vendor was approved in advance, and the adoption interview is skipped by that ruling: nothing is adopted but the `ph:hourglass` declaration).

## Step 0 pre-flight
Every roster addon's newest single-tag bundle states the base its history shows (`ok` on every row, DropWatcher's `2026-11-07-v1.93.0`: base v1.92.0, vendored-before v1.92.0@7608536). No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.95.0 (MIT).`
- `git log -1 --format=%H -- libs/LibKa0s tests/_kit` = 006e2e5 (DW-FP01); its CLAUDE.md names v1.95.0. They agree.
- Payload before the copy equalled the library at v1.95.0: `diff -rq` of a v1.95.0 extract against `libs/LibKa0s` (bar the undeclared icons) and against `tests/_kit` printed nothing (payload-matches).
- Range: `git -C ../LibKa0s log --oneline v1.95.0..v1.102.0` is 78 commits, tags v1.96.0 to v1.102.0.

## 3b/3c Per-file minors that moved (old = this addon, new = v1.102.0)
From the loop over the tag's `LibKa0s.xml` (`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR ...'`):
```
Callout.lua                old: none  new: LibKa0s-Callout-1.0 4
CalloutSettings.lua        old: none  new: SETTINGS_MINOR 5
WaypointArrow.lua          old: none  new: LibKa0s-WaypointArrow-1.0 2
WaypointArrowSettings.lua  old: none  new: SETTINGS_MINOR 2
Media.lua                  old: 12    new: 13
SkinDefsOthers.lua         old: 8     new: 9
DebugLogDiagnostics.lua    old: 8     new: 10
OptionsWidgets.lua         old: 45    new: 46
OptionsNav.lua             old: 6     new: 7
```
Every other file matched v1.95.0 before the copy, and the claimed and actual minors agree, so there is no cross-major skew.

## 3d Diffs (before the copy, against the v1.102.0 extract)
`diff -rq --strip-trailing-cr` shows the nine files above (four new), `LibKa0s.xml`, `media/fonts/FONTS.md`, the two new faces (Bebas Neue, Russo One, with their OFL texts), the new `media/sounds/` and `media/waypoint/` folders, and in the kit `README.md`, `framework.lua`, `glyphs.lua`, `vendor_sync.lua`. No `Only in libs/LibKa0s` line: nothing was removed upstream, so nothing is deleted by hand.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, outside `libs/` and `tests/`: Bus, Charts, Compat, Role (core/Compat.lua and core/CompatClient.lua), Core, Skin (core/Database.lua twice, core/SkinSetup.lua), DebugLog, Env, Glow, Item, Launcher, Lifecycle, Media, Perf, Pool, Sim (core/SimSetup.lua, modules/Sim.lua), Toast, Widgets, Options, Schema, Slash. Unconsumed majors in the payload: Callout, WaypointArrow, IconBrowser (the last unchanged in this range).

## 3f Kit revision
`grep -n 'Kit.VERSION'`: addon 54, tag 56. Both payloads move together in one commit (the pairing rule, kit 11 or newer for LibKa0s v1.9.0 or newer, is met by construction).

## 3g Contract delta
Majors that moved and that this addon looks up: Media (13), Skin (SkinDefsOthers 9), DebugLog (Diagnostics 10), Options (Widgets 46, Nav 7). Read in `CHANGELOG.md` at v1.102.0 and their `docs/api/` documents:
- Media 13 (`docs/api/Media/version-13.1-docs.md`): `FONTS` gains two faces; additive.
- SkinDefsOthers 9: `__FACE_SIZES` rows for the two faces; no skin draws either; additive.
- DebugLogDiagnostics 9 and 10: the `LibKa0s running:` line names Callout and WaypointArrow; "No member change".
- OptionsWidgets 46 (CHANGELOG v1.101.0, *A slider's box takes no junk*): a slider's box puts junk back; "What a consumer owes: nothing."
- OptionsNav 7 (CHANGELOG v1.100.0, *The one tab*): adds `O.SideTabs`; additive.
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no host attach site.

### Blockers
None. The Callout's v1.102.0 defaults change and the WaypointArrow's v1.101.0 look changes reach no code here: neither major is looked up.

## 3h Span
`vendored.txt` minus `recorded.txt` names v1.95.0 (vendored by 006e2e5, no bundle). A one-tag span bundle, `docs/revendor/2026-11-15-v1.95.0-v1.95.0/`, is written beside this one.

## 3i Icon declaration
`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 47, directly under the provenance line. Decided by the owner's ruling (plan M6, RX-13): add `ph:hourglass` (Phosphor's `hourglass.tga`, present in the catalog at v1.95.0 too: `git -C ../LibKa0s ls-tree -r --name-only v1.95.0 LibKa0s/media/icons | grep phosphor/hourglass.tga`). `clock` stays declared in the re-vendor commit while it is still drawn; RX-13's next commit moves its three uses (RollCells `WAITING_ICON`, the Queued state in `modules/MineCells.lua` and `modules/WindowCells.lua`) to the hourglass and drops it. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop. No `LibKa0s sounds:` line: no line means none, so `media/sounds/` prunes to nothing.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: `tests/test_mine_cells.lua:149`, `tests/test_roll_cells.lua:63`, `tests/test_tip_marks.lua:42,547` each open a declared name's file, so none goes red on the prune. No whole-catalog loop.

## Dead stub mirrors
`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
