Delta: LibKa0s v1.114.0 -> v1.115.0

Payload taken from the tag, never the sibling tree: `git -C ~/ka0s-scratch/itemsearch/LibKa0s archive v1.115.0 LibKa0s testkit tools` (tag commit f8c2ea68). The tag is local only; the lead pushes it at finalize. Run as item IS-DW-01 of the cross-repo run `feat/2026-11-25-item-search` (Ka0sAddonsCommonTasks `docs/2026-11-25-ITEM_SEARCH/`, spec §4.1). The run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`. The one adoption (ForeverDB minor 2, for Item Search) is pre-decided by the spec, so there is no interview and no GitHub issue.

## Base
- `grep -n '[Bb]undles' CLAUDE.md` before the copy: `48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.114.0 (MIT).`
- The newest single-tag bundle, `2026-11-25-v1.114.0`, states base v1.113.0, which matches the provenance line before its re-vendor commit `da0d4a8`. No correction is owed.

## Per-file minors that moved
```
ForeverDB.lua   MINOR 1 -> 2  (SearchItems, QuestsForItem, RewardFrom, StartsQuest, SkinnedFrom)
```
No other file changed (`git -C ../LibKa0s diff --stat v1.114.0 v1.115.0 -- LibKa0s testkit`: ForeverDB.lua and three kit files). No file added or removed.

## Diffs
After the copy, before the prune, `diff -rq <extract>/LibKa0s libs/LibKa0s` and `diff -rq <extract>/testkit tests/_kit` are both empty. After the prune, the only differences are the undeclared icons and `media/sounds` (there is no `LibKa0s sounds:` line, so no sounds ship; the prune removed 362 sound files, as it did at v1.114.0).

## Kit
`Kit.VERSION` 62 -> 63 (revision 63: `mock_foreverdb.lua`'s fixture gains invented `qx`, `rew`, `start` and `skin` rows). Both payloads move in one commit, as the pairing rule requires.

## Blockers
One, fixed in the re-vendor commit: `tests/test_surface_parity.lua` holds `core/ForeverDBSetup.lua`'s library-absent stub to the live surface, and minor 2 adds five members. The stub gains them, answering what the live members answer when ForeverDB is unavailable: `{}` for SearchItems, QuestsForItem, RewardFrom and SkinnedFrom, nil for StartsQuest. (The library's *Degradation* section still says "every other member -> nil"; a `{}` is the safer answer for a list a caller iterates, and the parity test compares types only. Noted for the library.)

## Icons and credits
The `LibKa0s icons:` line is kept unchanged; the prune kept the same files as at v1.114.0 and no icon set's credit changed, so the README is untouched.
