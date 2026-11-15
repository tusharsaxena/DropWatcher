Delta: LibKa0s v1.102.0 -> v1.103.0

Recorded before anything was copied. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.103.0 LibKa0s testkit tools` (tag commit 48a166d5, pushed: `git -C ../LibKa0s ls-remote --tags origin v1.103.0` lists 1512d50). Run under the rolls UX round, item UC-DW (plan M10), on the owner's approval of this re-vendor; the adoption interview is skipped by that approval: the two adoptions are pre-decided (TestStrip docking, Widgets Footer) and every other candidate is listed, not adopted, and no issue is filed.

## Step 0 pre-flight
`bash pre.sh` (the skill's Step 0 loop over `../WowAddonStandards/standards/ADDONS.md`): every roster row `ok`; DropWatcher's `2026-11-15-v1.102.0`: base v1.95.0, vendored-before v1.95.0@e5b131e. No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.102.0 (MIT).`
- `git log -1 --format=%H -- libs/LibKa0s tests/_kit` = 4ee0a01; its CLAUDE.md names v1.102.0. They agree.
- Range: `git -C ../LibKa0s log --oneline v1.102.0..v1.103.0` lists 4 commits (48a166d5, fd70cbdd, 0fb6fabb, bb2788fd).

### Finding: v1.103.0 is not a descendant of v1.102.0
`git -C ../LibKa0s merge-base --is-ancestor v1.102.0 v1.103.0` fails. The library's own CHANGELOG at v1.103.0 says so: "v1.102.0 is a separate tag cut on another branch (`feat/2026-11-14-callout-defaults`) and is not in this release's history; this release is cut from v1.101.0." So the re-vendor takes two files **back** a minor (3c). Neither is looked up by this addon (3e), so nothing on screen changes; the finding is reported, not blocking. The library owes a later tag that carries both lines (Callout 4 / CalloutSettings 5 and Widgets 27); until then a Drop Watcher copy ships the older Callout files, and LibStub keeps whichever loaded copy has the higher minor, so another addon that vendors v1.102.0 still wins the Callout major.

## 3b/3c Per-file minors that moved (old = this addon at v1.102.0, new = v1.103.0)
From the loop over the tag's `LibKa0s.xml` (`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR ...'`):
```
Widgets.lua          old: LibKa0s-Widgets-1.0 26   new: LibKa0s-Widgets-1.0 27
Callout.lua          old: LibKa0s-Callout-1.0 4    new: LibKa0s-Callout-1.0 3   (backwards, see 3a)
CalloutSettings.lua  old: SETTINGS_MINOR 5         new: SETTINGS_MINOR 4        (backwards, see 3a)
```
Every other file matches; the claimed and actual minors agree before the copy. No file is new in the range.

## 3d Diffs (before the copy, against the v1.103.0 extract)
`diff -rq --strip-trailing-cr` and `diff -rq` (both): `Callout.lua`, `CalloutSettings.lua`, `Widgets.lua` differ; `Only in <extract>/media: sounds` (no `LibKa0s sounds:` line, so the prune removes it again) and the undeclared icons. No `Only in libs/LibKa0s` line: nothing to delete by hand. `tests/_kit`: identical (kit revision 56 on both sides).

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`: Bus, Charts, Compat, Role (core/Compat.lua, core/CompatClient.lua), Core, Skin (core/Database.lua twice, core/SkinSetup.lua), DebugLog, Env, Glow, Item, Launcher, Lifecycle, Media, Perf, Pool, Sim (core/SimSetup.lua, modules/Sim.lua), Toast, Widgets (core/WidgetsSetup.lua), Options, Schema, Slash. Unconsumed majors: Callout, WaypointArrow, IconBrowser.

## 3f Kit revision
`grep -n 'Kit.VERSION'`: addon 56, tag 56. The pairing rule (kit 11 or newer with LibKa0s v1.9.0 or newer) holds by construction; both payloads are copied whole.

## 3g Contract delta
Majors that moved and that this addon looks up: Widgets (27). Read: CHANGELOG v1.103.0 at the tag, and `diff` of `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md` (v1.102.0) against `version-27.1.6.13.7.8.5-docs.md` (v1.103.0). The only changed sentences under an existing surface are the TestStrip rows: the strip is "born hidden and unanchored" still, and its header's sixth rejection ("No placement and no body shift") is retired by the ruling, an addition (`opts.dock`, `DockTestStrip`), not a tightened contract. "What a consumer owes at 27.1.6.13.7.8.5": "Nothing breaks. An undocked strip is minor 26's." (version-27 docs, line 74). A stub of the major gains `Footer`, `FOOTER` and `DockTestStrip`; this addon has no Widgets stub (core/WidgetsSetup.lua answers nil without the major).
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: no site.

### Blockers
None.

## 3h Span
The skill's listing (`vendored.txt` minus `recorded.txt`) prints nothing: every tag this addon vendored since its first bundle has one. No span bundle.

## 3i Icon declaration
`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 47, directly under the provenance line. Kept unchanged: the two adoptions draw no new catalog name (the strip keeps its host-passed `info` mark; the footer's marks slot is not used, see 02). No provenance split.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: `tests/test_roll_cells.lua:64`, `tests/test_mine_cells.lua:150`, `tests/test_tip_marks.lua:42,547` each open a declared name's file; none goes red on the prune.

## Dead stub mirrors
`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
