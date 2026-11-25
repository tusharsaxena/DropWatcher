# Delta: LibKa0s v1.115.0 -> v1.116.0

Payload taken from the tag, never the sibling tree: `git -C ~/ka0s-scratch/isfb/LibKa0s archive v1.116.0` (tag commit cbd82ed3), extracted to a scratch folder that was removed after the copy. The tag is local only; the lead pushes it at finalize. Run as item ISF-DW-00 of the cross-repo run `feat/2026-11-25-item-search-feedback` (Ka0sAddonsCommonTasks `docs/2026-11-25-ITEM_SEARCH_FEEDBACK/`, spec section 2). The run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`. The one adoption (ForeverDB minor 3, `Object`) is pre-decided by the spec (ISF-DW-02), so there is no interview and no GitHub issue.

## Base
- `grep -n '[Bb]undles' CLAUDE.md` before the copy: `48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.115.0 (MIT).`
- The newest single-tag bundle, `2026-11-25-v1.115.0`, states base v1.114.0, which matches the provenance line before its re-vendor commit `68f1d7c`. No correction is owed.

## Per-file minors that moved
```
ForeverDB.lua   MINOR 2 -> 3  (Object(id): { id, name } or nil)
```
No other library file changed. No file added or removed.

## Diffs
After the copy, before the prune, `diff -rq <extract>/LibKa0s libs/LibKa0s` and `diff -rq <extract>/testkit tests/_kit` are both empty. After the prune, the only differences are the undeclared icons and `media/sounds` (there is no `LibKa0s sounds:` line, so no sounds ship; the prune removed 362 sound files, as before).

## Kit
`Kit.VERSION` 63 -> 64 (revision 64: `mock_foreverdb.lua`'s fixture gains invented object rows: two same-named strongboxes, a nameless row, a non-table row, and a relic dropping from all four). Both payloads move in one commit, as the pairing rule requires. No existing Drop Watcher expectation changed.

## Blockers
One, fixed in the re-vendor commit: `tests/test_surface_parity.lua` holds `core/ForeverDBSetup.lua`'s library-absent stub to the live surface, and minor 3 adds `Object`. The stub gains it, answering nil.

## Icons and credits
The `LibKa0s icons:` line gains eight Phosphor icons for the Item Search feedback run: `ph:arrow-up` (a recipe that skills up), `ph:minus` (known, no skill-up), `ph:lock` (not known), `ph:map-pin` (the waypoint pin), `ph:funnel` (the Filter action), `ph:sort-ascending`, `ph:sort-descending` and `ph:arrows-down-up` (the Sort action and sorted column headers). The prune kept those eight beside the existing set. Phosphor's license already shipped (for `ph:hourglass`), so no license file moved; the README credit line now names what the Phosphor icons draw.
