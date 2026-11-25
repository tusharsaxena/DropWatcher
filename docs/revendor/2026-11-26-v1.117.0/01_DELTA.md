# Delta: LibKa0s v1.116.0 -> v1.117.0

The payload comes from the tag, never from the sibling tree. `git -C ~/ka0s-scratch/isr3/LibKa0s archive v1.117.0` (tag commit 966a08cd) was extracted to a scratch folder and copied whole into `libs/LibKa0s/` and `tests/_kit/`. The tag is local only, and the lead pushes it at finalize. This re-vendor is item ISR3-DW-00 of the cross-repo run `feat/2026-11-25-item-search-round3` (Ka0sAddonsCommonTasks `docs/2026-11-25-ITEM_SEARCH_ROUND3/`, spec section 3). The run uses the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`. The spec already decides the adoptions of ForeverDB minor 4 (ISR3-DW-03), so this re-vendor has no interview and files no GitHub issue.

The spec names this folder `2026-11-25-v1.117.0`. It is dated 2026-11-26 instead, the day the re-vendor ran and the date of the v1.117.0 release.

## Base
- `grep -n '[Bb]undles' CLAUDE.md` before the copy: `48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.116.0 (MIT).`
- The newest single-tag bundle, `2026-11-25-v1.116.0`, gives base v1.115.0. That matches the provenance line before its re-vendor commit `149e6f7`, so no correction is owed.

## Per-file minors that moved
```
ForeverDB.lua   MINOR 3 -> 4  (Spots via spz > spm > spw, WorldToMap, VendorPriceAt + vendx,
                               FullStatus / LoadFull / FullCost)
```
No other library file changed, and no file was added or removed (`git diff --stat v1.116.0 v1.117.0 -- LibKa0s testkit` lists four files: `LibKa0s/ForeverDB.lua` and the three kit files below).

## Diffs
After the copy and before the prune, `diff -rq <extract>/LibKa0s libs/LibKa0s` and `diff -rq <extract>/testkit tests/_kit` are both empty. After the prune, the only differences are the undeclared icons and `media/sounds`. There is no `LibKa0s sounds:` line, so no sounds ship, and the prune removed 362 sound files, the same as last time.

## Kit
`Kit.VERSION` goes from 64 to 65. Revision 65 adds to `mock_foreverdb.lua` what minor 4 reads: an invented continent 99 in `umaa` with `zbord` polygons, `spw` points for a new creature (the wanderer, 990005, which has no `spm` row), a `vendx` price, and an opt-in ForeverDB_Full fake (`opts.full`, `FDB.fullFixture()`, `fdb.fullLoads`). `meta.counts.npc` goes from 4 to 5. Every earlier row is unchanged. Both payloads move in one commit, as the pairing rule requires.

Re-counting the vendored fixture's expectations: Drop Watcher's ForeverDB suites (`tests/test_item_search*.lua` and `tests/perf.lua`) assert on no fixture count and on no row the revision changed. Every expectation holds as it was, on both kit profiles.

## Contract notes (no signature moved)
- **`Spots(kind, id)` gains a second return**, the origin (`"spz"`, `"spm"` or `"spw"`). A caller that reads only the first return is unaffected. `Spots` now also answers for a source with no `spm` row when its `spw` world coordinates convert, or when ForeverDB_Full is loaded and has an `spz` row, so the tooltip and window can show spots where they showed none before.
- **`VendorPrice(itemID)` can answer a lower price than before**, because each vendor's price now reads `vendx` before `vp`. The fixture keeps the old answer (its `vendx` price is above the trainer's `vp` price).
- `LoadFull()` is the library's only load of ForeverDB_Full. The library never calls it on its own, so this re-vendor loads nothing new. When to call it is Drop Watcher's policy (ISR3-DW-03, spec section 4.6).

## Blockers
One, fixed in the re-vendor commit. `tests/test_surface_parity.lua` holds `core/ForeverDBSetup.lua`'s library-absent stub to the live surface, and minor 4 adds five members. The stub gains them with the values the library's *Degradation* section (`docs/api/ForeverDB/version-4-docs.md`) gives: `VendorPriceAt` answers `nil, nil`, `WorldToMap` and `FullCost` answer nil, `FullStatus` answers `"missing"` and `LoadFull` answers `false, "missing"`. The stub's header now cites version 4 of that doc. This is the minor-4 pin: the parity test fails on any minor-4 member the stub lacks.

## Icons and credits
The `LibKa0s icons:` line gains seven icons for Item Search round 3:
- `ph:arrow-fat-up`, the skill-up glyph;
- `ph:arrows-horizontal`, no skill-up;
- `ph:check-fat`, a quest turned in;
- `ph:coins`, the Sell verdict;
- `ph:trash`, the Toss verdict;
- `sort-up` and `sort-down`, Open Iconic's sorted-column triangles, as LootHistory uses them.

`ph:arrow-up` and `ph:minus` stay declared for now. ISR3-DW-01 stops drawing them, then removes them from the declaration and re-prunes. The prune kept 48 TGAs, one for each declared name. Both icon sets' licenses already ship (Open Iconic's and Phosphor's), so no license file moved. The README's credit line now says that the sorted-column triangles are Open Iconic's, and that the quest check and the verdict badges are Phosphor's.

## Gate
- `lua tests/run.lua`: 2803 passed, 0 failed, 91 skipped (2894).
- `KA0S_KIT_CLIENT=forever lua tests/run.lua`: 2778 passed, 0 failed, 114 skipped (2892).
- `ka0s-bounded luacheck .`: 0 warnings, 0 errors in 297 files.
- `pytest tools/seeds`: 32 passed.
- `tests/perf.lua` passes on both clients with the ceilings unchanged.
