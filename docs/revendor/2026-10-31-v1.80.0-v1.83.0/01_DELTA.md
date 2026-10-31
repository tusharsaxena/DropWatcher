Delta: LibKa0s v1.77.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta: the consolidated span v1.80.0 to v1.83.0

Written 2026-10-31 by plan item `FX-DW-DOCS` of the findings remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-31-FINDINGS_REMEDIATION/`). Four tags this addon vendored from
2026-10-29 to 2026-10-31 have no bundle naming them. This is a back-fill record in the consolidated
span shape, not a re-run of the re-vendor procedure: nothing here was copied.

The tag vendored immediately before the span is **v1.77.0** (`e047dbb`, the DW-RV3 refresh), recorded
by `docs/revendor/2026-10-24-v1.77.0/`. That is the span's base. v1.78.0 and v1.79.0 were never
vendored whole; `8c2660f` (AT-A1, 2026-10-28) took `LibKa0s-Toast-1.0` alone ahead of them, and
v1.80.0 retired that deviation.

## The vendoring commits

| Tag | Vendoring commit | Merged in | Date |
|---|---|---|---|
| v1.80.0 | `6920689` (`DW-RV: Re-vendor LibKa0s v1.80.0 and retire the Toast-ahead deviation`) | `8851923` | 2026-10-29 |
| v1.81.0 | `5b4f552` (`DW-RV: Re-vendor LibKa0s v1.81.0`) | `0d9d843` | 2026-10-30 |
| v1.82.0 | `87b2d52` (`DW-01: Re-vendor LibKa0s v1.82.0 from the local tag`) | `5292888` | 2026-10-30 |
| v1.83.0 | `1c098d1` (`DW-F01: Re-vendor LibKa0s v1.83.0, default the outline to HUD text only`), then the re-cuts `3b78cc5`, `5b1191b` and `f799d32` | `5292888` | 2026-10-31 |

Each tag is read off the `Bundles [LibKa0s](…) vX.Y.Z` provenance line in root `CLAUDE.md` at that
commit. Each commit's own message is the record of what that re-vendor moved.

## Per tag

`git -C ../LibKa0s diff --stat <from> <to> -- LibKa0s testkit`, and the library's CHANGELOG:

- **v1.80.0** (from v1.77.0): 74 files, 10923 insertions, 795 deletions. The skinning rollout's library
  half. What a consumer owed: the Options degradation stub answers `AppearanceTab`, `AppearanceRows`,
  `SkinPicker` and `HideSkinPicker`. No skin owner was registered yet, so the addon drew what it drew
  on v1.77.0.
- **v1.81.0**: 24 files, 971 insertions, 320 deletions. The skin library follow-ups. Kit revision 44.
  Nothing was owed for this addon: no `stockDefault` caller, no `__DrawsKey` call, no `TITLE_FOR`
  translation.
- **v1.82.0**: 31 files, 3520 insertions, 456 deletions. Skin fonts and feedback; `OptionsSwitch.lua` is
  new, the faces change, kit revision 45. Owed and met in the same commit: the Options stub's `SkinVerb`
  and the degraded Skin facade's `FontFlags` and `HudFontSize`.
- **v1.83.0**: 33 files, 2083 insertions, 246 deletions. Font pickers and skin faces;
  `OptionsMedia.lua` is new, kit revision 46. The tag was re-cut, and each re-cut was taken by the commits
  above. The outline default moved to `hud` in the same commit, with no migration.

## Consumption

The span is what the skinning rollout, its follow-ups and the two font runs were built on, so its
surfaces were adopted by those runs' own items, not by a re-vendor interview. Their records are
`docs/2026-10-29-SKINNING_ROLLOUT/`, `docs/2026-10-30-SKIN_LIBRARY_FOLLOWUPS/`,
`docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/` and `docs/2026-10-31-FONT_PICKERS_AND_SKIN_FACES/` in
Ka0sAddonsCommonTasks.
