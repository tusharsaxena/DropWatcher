# 02 — Candidates (LibKa0s v1.89.0 -> v1.90.0)

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the tag's `CHANGELOG.md` v1.90.0 block, and the `What changed at this version` sections of the four new API documents named in `01_DELTA.md` 3g.

## Class A: delivered on the re-vendor alone

- **One physical pixel for every Widgets edge** (`SF1-L1`; Widgets document `docs/api/Widgets/version-24.5.12.6.8.5-docs.md:19-24`, Core `docs/api/Core/version-16-docs.md`). This addon's filter-bar dropdowns and search box (`modules/WindowFilterBar.lua`), its compact Filters cascade (`NS.ContextMenu`, `modules/CompactChrome.lua:327`) and its History row menu are `W.Dropdown`, `W.SearchBox` and the shared menu. Their edges now draw one physical pixel at any UI scale and sub-pixel position: this is the fix for the owner's feedback item 4, where DropWatcher's dropdown measured 2 px on top and 1 at the bottom. No host change.
- **Skin's pixel watch moved into Core** (SkinPaint 19, SkinPaintExtras 18): internal, no host change.

## Class B: host change required

- **`RegisterOwner(owner, { keepScope = true })`** (Skin 17; Skin document `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md:19,25,390`; OptionsAppearance 7's `lib.__copySkinTo`). An opt-out that keeps another addon's skin copy from writing this owner's Scope. Files: `core/SkinSetup.lua:783`. Blast radius: additive, one option. Recommendation: **do not adopt**. DropWatcher documents no Scope deviation of its own that a copy could undo, so a copy carrying the source addon's Scope is the behavior the owner chose for Apply to all. The run's feedback record names only Ka0s Skin Tester for this opt-out (`SF1-ST`).

## Class C: whole-module adoption

None. Every major in the payload is looked up (`01_DELTA.md` 3e).
