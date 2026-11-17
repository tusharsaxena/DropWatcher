Delta: LibKa0s v1.103.0 -> v1.105.0

Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 79b1d9c4). The tag is local only (`git -C ../LibKa0s ls-remote --tags origin v1.105.0` prints nothing), which is expected for this run: the lead pushes it at finalize. Run as item RV-DW of the cross-repo run `feat/2026-11-16-libka0s-75-plus` (Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, design section 5, plan M8). That run takes the copy and bundle half of `/dev-copilot:wow-revendor-libka0s` only: the adoption interview and every GitHub issue filing are skipped, and the candidates are listed in `02_CANDIDATES.md` as owed in phase [3].

## Step 0 pre-flight
For this addon: the newest single-tag bundle `2026-11-15-v1.103.0` states base v1.102.0; the provenance line before the re-vendor commit that vendored v1.103.0 (`b12996a^`) names v1.102.0. `ok`. No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.103.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = b12996a; its CLAUDE.md names v1.103.0. They agree.
- `diff -rq --strip-trailing-cr <v1.103.0 extract>/LibKa0s libs/LibKa0s` lists only the undeclared icons and the pruned sounds; `diff -rq <v1.103.0 extract>/testkit tests/_kit` is empty. The payload is v1.103.0's.
- `git -C ../LibKa0s merge-base --is-ancestor v1.103.0 v1.105.0` succeeds (v1.104.0 joined the v1.102.0 and v1.103.0 lines, so the Callout pair moves forward again).
- Range: `git -C ../LibKa0s log --oneline v1.103.0..v1.105.0` lists 33 commits. v1.104.0 is inside the range and was never vendored here, so it needs no record of its own.

## 3b/3c Per-file minors that moved (old = this addon at v1.103.0, new = v1.105.0)
From the loop over the tag's `LibKa0s.xml` (`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR ...'`), the files that differ:
```
Core.lua                    Core 17 -> 18
Tooltip.lua                 (new) LibKa0s-Tooltip-1.0 1
Callout.lua                 Callout 3 -> 4
CalloutSettings.lua         SETTINGS_MINOR 4 -> 5
Charts.lua                  Charts 1 -> 2
SkinDefs.lua                DEFS_MINOR 27 -> 28
SkinDefsOthers.lua          OTHERS_MINOR 9 -> 10
WidgetsDropdown.lua         DROPDOWN_MINOR 1 -> 2
WidgetsReorder.lua          REORDER_MINOR 6 -> 7
WidgetsDragHandle.lua       DRAG_MINOR 13 -> 14
WidgetsDragHandleTip.lua    (new) DRAGTIP_MINOR 1
WidgetsCopyWindow.lua       COPY_MINOR 5 -> 6
WidgetsHeader.lua           (new) HEADER_MINOR 1
WidgetsBar.lua              (new) BAR_MINOR 1
DebugLog.lua                DebugLog 22 -> 23
DebugLogDiagnostics.lua     DIAG_MINOR 10 -> 11
DebugLogWindow.lua          WINDOW_MINOR 4 -> 5
Launcher.lua                Launcher 10 -> 11
OptionsSkinPicker.lua       PICKER_MINOR 11 -> 12
OptionsSkinPickerQueue.lua  (new) QUEUE_MINOR 1
IconBrowserWindow.lua       WINDOW_MINOR 1 -> 2
IconBrowser.lua             BROWSER_MINOR 1 -> 2
PerfPanel.lua               PANEL_MINOR 13 -> 14
Sim.lua                     Sim 2 -> 3
SimPanel.lua                SIM_PANEL_MINOR 10 -> 11
SimPanelRender.lua          RENDER_MINOR 3 -> 4
```
Every other file matches. Claimed and actual minors agreed before the copy. No cross-major skew.

## 3d Diffs
Before the copy, against the v1.105.0 extract: the 21 changed files above differ, the five new files are `Only in <extract>`, `Only in <extract>/media: sounds` (no `LibKa0s sounds:` line, so the prune removes it again), and the undeclared icons. No `Only in libs/LibKa0s` line, so nothing is deleted by hand. `tests/_kit`: `README.md`, `framework.lua`, `mock_ace.lua`, `mock_events.lua`, `vendor_sync.lua` differ; `mock_screen.lua` is new.
After the copy and before the prune: `diff -r --strip-trailing-cr`, `diff -r` (both payloads, both directions) all empty.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`: Bus, Charts, Compat, Role, Core, Skin, DebugLog, Env, Glow, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Sim, Slash, Toast, Widgets (the same sites as at v1.103.0). Unconsumed majors: Callout, WaypointArrow, IconBrowser, and the new Tooltip.

## 3f Kit revision
`grep -n 'Kit.VERSION'`: addon 56, tag 57. Both payloads are copied whole, so the pairing rule holds by construction. Revision 57 holds a frame with a raw event registration until it unregisters (LibKa0s#75): this suite stays green under it on both clients.

## 3g Contract delta
Majors that moved and that this addon looks up: Core, Charts, Skin, Widgets, DebugLog, Launcher, Options, Perf, Sim. Read: the CHANGELOG v1.105.0 block at the tag, *What a consumer owes*, and the DebugLog `version-23.11.1.5-docs.md` *What a host owes at its re-vendor*.
- **DebugLog instance gains `Report` and `Serialize`** (DebugLog 23, DebugLogDiagnostics 11). `tests/test_surface_parity.lua`'s by-name DebugLog case went red ("Report is missing; Serialize is missing"). Fixed in this commit: `core/DebugLogSetup.lua`'s library-absent stub gains both, as methods, in the API document's shape (the report streams to chat with no pointer and answers the line count; a serialize answers one line).
- **Ka0s Default's `list.stripe` moved .03 -> .08** (SkinDefs 28, LibKa0s#84). `tests/test_surface_parity.lua`'s host-copy case went red ("list.stripe[4]: host copy 0.03, library 0.08"). Fixed in this commit: `core/SkinSetup.lua` `NS.SKIN_FALLBACK["list.stripe"]` re-copied. The fallback does not carry `list.hover` or `list.sel`, so nothing else moves.
- **Per-skin `icon.hot`** (LibKa0s#82): no suite here went red, so no pin moved. The host fallback's `icon.hot` stays white, which is Ka0s Default's value.
- **`LIBRARY_MARKS` gains `settings`** (kit 57): the declaration already lists `settings`.
- **Options `SideTabs`, Compat identity readers, Sim library table:** this addon's stubs needed nothing (no red case). DropWatcher's Sim parity compares against the `Sim:New` instance, which gains no member.
- No hand-written loader list here (the suite loads the TOC), so no XML-order lines are owed.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: no site.

### Blockers
None beyond the two stub/fallback fixes above, which travel in the re-vendor commit.

## 3h Span
The skill's listing (`vendored.txt` minus `recorded.txt`) prints nothing: every tag this addon vendored since its first bundle has one. No span bundle.

## 3i Icon declaration
`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 47, directly under the provenance line. Kept unchanged (32 names, `settings` already among them). No provenance split.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: `tests/test_mine_cells.lua:150`, `tests/test_tip_marks.lua:42,547` each open a declared name's file; `tests/prose_waivers.lua:15` is a comment. None goes red on the prune.

## Dead stub mirrors
`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
