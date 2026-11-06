# 02 — Candidates (LibKa0s v1.90.0 -> v1.91.0)

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the tag's `CHANGELOG.md` v1.91.0 block, and the `What changed at this version` sections of the three new API documents named in `01_DELTA.md` 3g.

## Class A: delivered on the re-vendor alone

- **The line chart's lines in physical pixels** (`FU-L1`, WidgetsLineChart 7; Widgets document `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md`, *The line chart's lines in physical pixels*). Arrives on the copy. This addon draws no `LineChart`, so nothing on its screens changes.
- **The four peels** (`FU-L2`: `CorePixel.lua`, `WidgetsDropdown.lua`, `SkinPaintHud.lua`, `SkinAceConfirm.lua`). Pure moves with no public member, option or behavior change (Widgets document lines 19-23; the CHANGELOG's *The band files peeled*). The addon's dropdowns, shared menu, HUD looks and profile confirmation box come from the same code, now loaded from the new files. No host change: `tests/loader.lua` reads the file list from `LibKa0s.xml`.

## Class B: host change required

None. The tag adds no member, option or data field.

## Class C: whole-module adoption

None. Every major in the payload is looked up (`01_DELTA.md` 3e); the peels add files, not majors.
