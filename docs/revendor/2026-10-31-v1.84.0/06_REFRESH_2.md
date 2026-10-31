# 06 — Refresh 2: the v1.84.0 re-cut that deletes the stub

The local-only tag `v1.84.0` moved again before its release was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing), so this is a refresh and not a new re-vendor. Line 1 of `01_DELTA.md` stands. The owner's ruling of 2026-11-01 drove the re-cut: `__PatchLSM30Border` goes, with no stub in its place.

- **Old tag commit:** `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` (the payload this repo carried matches it with `diff -r --strip-trailing-cr`: both payloads, no line apart from the icons the declaration prunes).
- **New tag commit:** `b5229b876e803768322fb4d8c66be69f01c8e4a1`.
- **Kit revision:** 47, unchanged, and `tests/_kit/` took no byte from the re-cut.

## Per-file minors

Only these moved (3c's loop, against each commit).

| File | Constant | Old | New |
|---|---|---|---|
| `Options.lua` | MINOR | 36 | 37 |
| `OptionsDrawer.lua` | DRAWER_MINOR | 3 | 4 |
| `OptionsMedia.lua` | MEDIA_MINOR | 2 | 3 |

## Contract

`lib.__PatchLSM30Border` no longer exists. This addon never called it: outside `libs/` the name appears only in this bundle, so no call, stub, guard or test had to go. No test pins the moved minors.

## Copy and gate

- The icon line is unchanged. The prune kept 31 files and removed 5809.
- Before the prune, both content diffs were empty.
- `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 208 files.
- `ka0s-bounded lua tests/run.lua`: 1849 passed, 0 failed, 1 skipped, 1850 total.
