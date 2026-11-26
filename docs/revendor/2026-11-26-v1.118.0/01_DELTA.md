# Delta: LibKa0s v1.117.0 -> v1.118.0

The payload comes from the tag, never from the sibling tree. `git -C ~/ka0s-scratch/r4/LibKa0s archive v1.118.0 LibKa0s testkit tools` (tag commit 0272c7dd) was extracted to a scratch folder and copied whole into `libs/LibKa0s/` and `tests/_kit/`. The tag is local only, and the lead pushes it at finalize. This re-vendor is item R4-DW-00 of the cross-repo run `feat/2026-11-26-owner-feedback-round4` (Ka0sAddonsCommonTasks `docs/2026-11-26-OWNER_FEEDBACK_ROUND4/`), landed in that run's review fix pass (R4-REV): the build pass never ran it. The run uses the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`. The plan already decides the one adoption (`dash` as the no-skill-up glyph, R4-DW-02), so this re-vendor has no interview and files no GitHub issue.

## Base
- `grep -n '[Bb]undles' CLAUDE.md` before the copy: `48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.117.0 (MIT).`
- The last commit touching either payload leaves the same line (v1.117.0), and the payload matched the v1.117.0 extract (`diff -rq --strip-trailing-cr`: only the pruned icons and `media/sounds`).
- The newest single-tag bundle, `2026-11-26-v1.117.0`, gives base v1.116.0, which matches the provenance line before its re-vendor, so no correction is owed. No tag this addon vendored is unrecorded (3h's listing prints nothing), so no span bundle.

## Per-file minors that moved
```
Media.lua   MINOR 13 -> 14  (ICONS gains `dash`, a thick rounded bar the library draws itself)
```
`git -C LibKa0s diff --stat v1.117.0 v1.118.0 -- LibKa0s testkit` lists three files: `LibKa0s/Media.lua` and two new payload files, `media/icons/dash.tga` and `media/icons/CREDITS.txt`. No file removed.

## Diffs
After the copy and before the prune, `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s` and `diff -rq --strip-trailing-cr <extract>/testkit tests/_kit` are both empty. After the prune, the only differences are the undeclared icons and `media/sounds` (no `LibKa0s sounds:` line, so the prune removed the 362 sound files, as last time).

## Kit
`Kit.VERSION` stays at 65; the kit is byte-identical between the two tags. Both payloads still move in one commit.

## Contract notes
None. Media 14 is additive: no name moves, no signature changes. `core/MediaSetup.lua` is the one lookup site and resolves names through `NS.Icon`.

## Blockers
None. The suites that open icon files (`tests/test_tip_marks.lua`, `tests/test_mine_cells.lua`) read declared names only.

## Icons and credits
The `LibKa0s icons:` line gains `dash`, the no-skill-up glyph R4-DW-02 draws (decided by the plan, not re-asked). `ph:arrows-horizontal` stays declared here; R4-DW-02 stops drawing it and removes it then. The prune kept one TGA per declared name, plus `dash.tga`; `CREDITS.txt` ships beside it in the Open Iconic folder. The README credits stay as they are: credit goes to icon sets, never to LibKa0s itself (anti-pattern #58), and the dash is the library's own art, credited in the shipped `CREDITS.txt`.

Hand lists have drifted before (KickCD, WhatGroup); the owner's in-client smoke is the backstop, since a pruned icon resolves to a path and draws blank.

## Gate
- `lua tests/run.lua`: 2850 passed, 0 failed, 126 skipped (2976).
- `KA0S_KIT_CLIENT=forever lua tests/run.lua`: 2859 passed, 0 failed, 115 skipped (2974).
- `ka0s-bounded luacheck .`: 0 warnings, 0 errors in 303 files.
- `pytest tools/seeds`: 33 passed.
- `tests/perf.lua` passes on both clients with the ceilings unchanged.
