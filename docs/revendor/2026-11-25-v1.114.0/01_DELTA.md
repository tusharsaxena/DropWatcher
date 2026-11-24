Delta: LibKa0s v1.113.0 -> v1.114.0

Payload taken from the tag, never the sibling tree: `git -C ~/ka0s-scratch/seeds/LibKa0s archive v1.114.0 LibKa0s testkit tools` (tag commit 2eaa8fc9). The tag is local only (`git ls-remote --tags origin v1.114.0` prints nothing), which is expected: it sits on the library's run branch `feat/2026-11-25-seeds-foreverdb` and the lead pushes it at finalize. Run as item SF-DW-01 of the cross-repo run `feat/2026-11-25-seeds-foreverdb` (Ka0sAddonsCommonTasks `docs/2026-11-25-SEEDS_AND_FOREVERDB/`, spec §9). That run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`; its adoption interview is skipped because the run pre-decides the one adoption (`LibKa0s-ForeverDB-1.0`), and no GitHub issue is filed here.

## Step 0 pre-flight
The newest single-tag bundle `2026-11-20-v1.108.0` states base v1.107.0; the provenance line before the commit that vendored v1.108.0 (`284fad9`) named v1.107.0 (`git show 284fad9^:CLAUDE.md`). `ok`. No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.113.0 (MIT).` before the copy.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 593d22b (FB2-DW-02, the re-cut v1.113.0); its CLAUDE.md names v1.113.0. They agree.
- `diff -rq --strip-trailing-cr <v1.113.0 extract>/LibKa0s libs/LibKa0s` lists only the undeclared icons and the pruned sounds; `diff -rq <v1.113.0 extract>/testkit tests/_kit` is empty. The payload was v1.113.0's.
- Range: `git log --oneline v1.113.0..v1.114.0` lists 8 commits (one of them the merge of v1.112.0 and v1.113.0's branch).

## 3b/3c Per-file minors that moved
```
ForeverDB.lua            new: MAJOR "LibKa0s-ForeverDB-1.0", MINOR 1
DebugLogDiagnostics.lua  DIAG_MINOR 11 -> 12
```
Every other file is at its v1.113.0 minor (3c's loop over the tag's `LibKa0s.xml`). One file is added (`ForeverDB.lua`, loaded after `Item.lua`) and none is removed. No cross-major skew.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s`, the byte diff and `diff -rq <extract>/testkit tests/_kit` are all empty. After the prune, the only differences are `Only in <extract>/LibKa0s/media/icons…` (undeclared icons) and `Only in <extract>/LibKa0s/media/sounds…` (no `LibKa0s sounds:` line, so none ship).

## 3e Consumption
Of the majors that moved, this addon looks up `LibKa0s-DebugLog-1.0` (core/DebugLogSetup.lua); the diagnostics report it builds through the library gains the ForeverDB line on its own. `LibKa0s-ForeverDB-1.0` is new and unconsumed before this run; SF-DW-01 adopts it (02_CANDIDATES.md).

## 3f Kit
`Kit.VERSION` 60 -> 62 (revision 61: `testkit/mock_foreverdb.lua`, the ForeverDB fake; revision 62: `client_globals_forever.lua` regenerated from Ketho's `forever` branch, SF-LK-02). Both payloads move together in one commit, as the pairing rule requires.

## 3g Blockers
None. `docs/api/DebugLog/version-23.12.1.5-docs.md` against `version-23.11.1.5-docs.md`: the report's `LibKa0s running:` line names the new major and the identity section ends with one ForeverDB line from `Status()`, which never loads the data addon; "No member change". This addon pins no `DebugLogDiagnostics` minor, and its diagnostics cases stay green. The regenerated Forever name set (kit 62) leaves `client globals: no call of a global a client lacks` green on both profiles.

## 3h Span
Three vendored tags had no bundle: v1.109.0, v1.112.0 and v1.113.0. The consolidated span bundle `docs/revendor/2026-11-25-v1.109.0-v1.113.0/` records them.

## 3i Icon declaration
Kept unchanged (32 names); the ForeverDB chip draws no catalog icon. The prune refused nothing: it kept the declared icons and removed the undeclared icons and 362 voice-pack files.

## 3j Tests assuming the whole icon folder
None new (`tests/test_mine_cells.lua:150` and `tests/test_tip_marks.lua:42,547` open declared icons only).
