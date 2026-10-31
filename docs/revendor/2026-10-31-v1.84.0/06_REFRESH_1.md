# 06 — Refresh 1: the re-cut v1.84.0

The local-only tag `v1.84.0` moved before its release was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing), so this is a refresh and not a new re-vendor. Line 1 of `01_DELTA.md` stands. The owner's ruling of 2026-11-01 drove the re-cut: Ka0sMedia_* is the only media picker in the collection.

- **Old tag commit:** `e917ccd833768b8fe68e9542d3fbf6b38cab6659` (the payload this repo carried matches it with `diff -r --strip-trailing-cr`: both payloads, no line).
- **New tag commit:** `7a8bc0f133ed118d2c79c7c5288b97964e24fae5`.
- **Kit revision:** 47, unchanged, and `tests/_kit/` took no byte from the re-cut.

## Per-file minors

Only these moved (3c's loop, against each commit).

| File | Constant | Old | New |
|---|---|---|---|
| `SkinAce.lua` | ACE_MINOR | 5 | 6 |
| `Options.lua` | MINOR | 35 | 36 |
| `OptionsWidgets.lua` | WIDGETS_MINOR | 40 | 41 |
| `OptionsCompose.lua` | COMPOSE_MINOR | 15 | 16 |
| `OptionsScroll.lua` | SCROLL_MINOR | 9 | 10 |
| `OptionsMedia.lua` | MEDIA_MINOR | 1 | 2 |

## Contract

`OptionsCompose` now writes `dialogControl = "Ka0sMedia_Border"` where it wrote `LSM30_Border`, and `lib.__PatchLSM30Border` is a no-op answering false. The addon never called it. The one pin on the old name, `tests/test_schema_rows.lua`, moved in this commit.

## Copy and gate

- The icon line is unchanged. The prune kept 31 files and removed 5809.
- Before the prune, both content diffs were empty.
- `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 208 files.
- `ka0s-bounded lua tests/run.lua`: 1849 passed, 0 failed, 1 skipped, 1850 total.
