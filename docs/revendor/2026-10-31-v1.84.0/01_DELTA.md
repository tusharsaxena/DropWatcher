Delta: LibKa0s v1.83.0 -> v1.84.0

# 01 — Delta

Written before the copy. Tag v1.84.0 is local to the LibKa0s checkout at `e917ccd` (`git -C ../LibKa0s rev-parse v1.84.0^{commit}`; `ls-remote` prints nothing). Taken with `git -C ../LibKa0s archive v1.84.0 LibKa0s testkit tools`.

## Base (3a, 3b)

`grep -n '[Bb]undles' CLAUDE.md` names v1.83.0 at line 44. The newest payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit`, is `f799d32` and its line names v1.83.0, so the two answers agree. `diff -rq --strip-trailing-cr` against `git archive v1.83.0` is clean for both payloads apart from the undeclared icons, so the minors agree with the claim. The kit is revision 46 here and 47 at the tag.

Step 0, run for this addon alone (the other consumers are other agents' in this multi-repo run): the newest single-tag bundle, `2026-10-24-v1.77.0`, states base v1.76.0, and the provenance before `e1423c5` was v1.76.0. No mismatch.

3h: `vendored.txt` minus `recorded.txt` printed nothing. Every vendored tag has a bundle, so no span bundle is written.

## Per-file minors (3c)

Files whose minor moved; every other file in `LibKa0s.xml` is unchanged. An empty `old:` is a new file.

```
Schema.lua  old: local MAJOR, MINOR = "LibKa0s-Schema-1.0", 2  new: local MAJOR, MINOR = "LibKa0s-Schema-1.0", 3
Charts.lua  old:   new: local MAJOR, MINOR = "LibKa0s-Charts-1.0", 1
ChartsRender.lua  old:   new: local RENDER_MINOR = 1
Skin.lua  old: local MAJOR, MINOR = "LibKa0s-Skin-1.0", 10  new: local MAJOR, MINOR = "LibKa0s-Skin-1.0", 11
SkinOwnerTokens.lua  old:   new: local TOKENS_MINOR = 1
SkinDefs.lua  old: local DEFS_MINOR = 18  new: local DEFS_MINOR = 19
SkinDefsOthers.lua  old:   new: local OTHERS_MINOR = 1
WidgetsDragHandle.lua  old: local DRAG_MINOR = 8  new: local DRAG_MINOR = 10
DebugLogDiagnostics.lua  old: local DIAG_MINOR = 5  new: local DIAG_MINOR = 6
Slash.lua  old: local MAJOR, MINOR = "LibKa0s-Slash-1.0", 20  new: local MAJOR, MINOR = "LibKa0s-Slash-1.0", 21
Options.lua  old: local MAJOR, MINOR = "LibKa0s-Options-1.0", 34  new: local MAJOR, MINOR = "LibKa0s-Options-1.0", 35
OptionsWidgets.lua  old: local WIDGETS_MINOR = 38  new: local WIDGETS_MINOR = 40
OptionsFlow.lua  old:   new: local FLOW_MINOR = 2
OptionsIds.lua  old: local IDS_MINOR = 5  new: local IDS_MINOR = 6
OptionsIdSuggest.lua  old:   new: local SUGGEST_MINOR = 1
OptionsTabs.lua  old: local TABS_MINOR = 11  new: local TABS_MINOR = 13
OptionsTabbed.lua  old:   new: local TABBED_MINOR = 2
OptionsCompose.lua  old: local COMPOSE_MINOR = 14  new: local COMPOSE_MINOR = 15
OptionsSkinPicker.lua  old: local PICKER_MINOR = 4  new: local PICKER_MINOR = 5
OptionsSkinPickerRows.lua  old:   new: local ROWS_MINOR = 1
SimPanel.lua  old: local SIM_PANEL_MINOR = 8  new: local SIM_PANEL_MINOR = 9
SimPanelRender.lua  old:   new: local RENDER_MINOR = 1
```

No file was behind the claimed tag, so there is no cross-major skew.

## Diffs (3d)

Against the claimed tag: content clean in both payloads; the only `Only in` lines are the undeclared icons, which is the declaration working.

## Consumption (3e)

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: Env, Bus, Compat, Core, DebugLog, Skin (`core/Database.lua`, `core/SkinSetup.lua`), Perf, Item, Media, Glow, Lifecycle, Pool, Sim (`core/SimSetup.lua`, `modules/Sim.lua`), Launcher, Widgets, Toast, Options, Schema, Slash. Charts, the one new major, has no lookup.

## Kit pairing (3f)

Revision 46 to 47 in the same commit. Both payloads move together, as the pairing rule (revision 11 or later with v1.9.0 or later) has required since v1.9.0.

## Contract delta (3g)

For Options, Schema, Slash, Skin, Sim, Widgets and DebugLog, the newest v1.83.0 document was diffed against the v1.84.0 document and read for removed or changed sentences. Outside the header tables:

- Options, Schema, Slash, Sim, Widgets: nothing removed.
- Skin: the WoW Default row's note and the without-SkinDefs sentence were reworded. No size moves and neither is a host contract.
- DebugLog: the identity header's module list gains Charts. This suite pins no DebugLogDiagnostics minor.

`grep -rn '__Attach' --exclude-dir=libs --exclude-dir=_kit` finds no host-supplied attach here.

### Blockers

- **The Options stub owes `O.PositionBlock`.** `settings/OptionsSetup.lua`'s library-absent branch is pinned by `tests/test_surface_parity.lua`, so the member joins it in the re-vendor commit. Changelog v1.84.0, *Flow seams*: "Consumers' degradation stubs owe the new `O.PositionBlock` at the re-vendor."

No typed file list here needs moving: `tests/test_harness.lua` reads the list from `LibKa0s.xml`. `T.enableAddon{ skip = { "libs/LibKa0s/Skin.lua" } }` in `tests/test_skin_outline.lua` stays: a shell-less `SkinOwnerTokens.lua` or `SkinDefsOthers.lua` returns harmlessly.

## Icons (3i, 3j)

`LibKa0s icons:` stays as it is at `CLAUDE.md:45`, directly under the provenance line, and nothing in this delta draws a new name. A hand list has drifted before, and a pruned icon still resolves to a path and draws blank, so the owner's in-client smoke is the backstop.

`tests/test_mine_cells.lua:149`, `tests/test_tip_marks.lua:42` and `:545` open files by name, each a declared name; no whole-catalog loop exists.

`__releaseChrome`: no mirror here.
