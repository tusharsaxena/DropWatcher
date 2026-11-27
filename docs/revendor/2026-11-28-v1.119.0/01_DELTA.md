Delta: LibKa0s v1.118.0 -> v1.119.0

The payload is the v1.119.0 release record on the LibKa0s branch `feat/2026-11-27-itemsearch-split`
at `110e02be` (the worktree `.worktrees/LibKa0s-itemsearch`), extracted with
`git -C .worktrees/LibKa0s-itemsearch archive 110e02be LibKa0s testkit tools` into a scratch folder
and copied whole into `libs/LibKa0s/` and `tests/_kit/`. v1.119.0 is **not tagged yet**: the tag is
task G1's, after the owner approves the LibKa0s merge (ruling R8 of
`docs/superpowers/specs/2026-11-27-itemsearch-split-design.md`). This re-vendor is task C1 of
`docs/superpowers/plans/2026-11-27-itemsearch-split.md` (DropWatcher#19). The run uses the copy,
provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s`; the adoption is the
plan's (Drop Watcher moves onto `LibKa0s-Verdict-1.0`), so there is no interview and no GitHub issue.

## Base
- `grep -n '[Bb]undles' CLAUDE.md` before the copy: `48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.118.0 (MIT).`
- The last commit touching either payload (`1706c61`) leaves the same line (v1.118.0).
- The newest single-tag bundle, `2026-11-26-v1.118.0`, gives base v1.117.0, the provenance line
  before its re-vendor, so no correction is owed. No tag this addon vendored is unrecorded, so no
  span bundle.

## Per-file minors that moved
```
Verdict.lua              new  MAJOR "LibKa0s-Verdict-1.0", MINOR 1
VerdictConstants.lua     new  CONSTANTS_MINOR 1
VerdictClassData.lua     new  CLASSDATA_MINOR 1
VerdictTierTokens.lua    new  TIERTOKENS_MINOR 1
VerdictEvaluate.lua      new  EVALUATE_MINOR 1
VerdictReads.lua         new  READS_MINOR 1
VerdictCollect.lua       new  COLLECT_MINOR 1
VerdictFacts.lua         new  FACTS_MINOR 1
VerdictScore.lua         new  SCORE_MINOR 1
VerdictGear.lua          new  GEAR_MINOR 1
VerdictSettings.lua      new  SETTINGS_MINOR 1
DebugLogDiagnostics.lua  DIAG_MINOR 12 -> 13  (Verdict joins the diagnostics' major list)
```
3c's loop over the extract's `LibKa0s/LibKa0s.xml`. `git diff --stat v1.118.0 110e02be -- LibKa0s
testkit` lists thirteen files: the eleven new Verdict files, `LibKa0s.xml` (eleven lines) and
`DebugLogDiagnostics.lua`. No file removed.

## Diffs
After the copy and before the prune, `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s`
and `diff -rq --strip-trailing-cr <extract>/testkit tests/_kit` are both empty. The prune
(`lua <extract>/tools/prune-icons.lua .`) leaves the declared icons and removes the 362 sound files
(no `LibKa0s sounds:` line), as last time.

## Kit
`Kit.VERSION` stays at 65; the kit is byte-identical between v1.118.0 and `110e02be`. Both payloads
still move in one commit.

## Consumption
`LibKa0s-Verdict-1.0` is new to this addon and this run adopts it whole: `core/VerdictSetup.lua`
makes the one instance (`V:New(host)`) and the views Drop Watcher's readers keep reaching it by
(`NS.Evaluate`, `NS.ClassData`, `NS.OffSpec`, `NS.TierTokens`, `NS.ItemFacts`, `NS.ItemRead`,
`NS.Gear`, `NS.Scoring`, `NS.Collectibles`), and the Comparison page is drawn from `V.Settings`.
The moved Drop Watcher files are deleted in the same run (commits `IS-C1.2` onward).

## Contract notes
None under a major this addon already consumed: DebugLogDiagnostics 13 only adds a name to its
major list.

## Blockers
One, about the gate rather than the bytes. `tests/test_vendor_sync.lua` resolves the provenance
line's tag in `../LibKa0s`, and v1.119.0 does not exist there until G1 tags it, so its two payload
cases fail with `the library repo v1.119.0 carries LibKa0s/` (and `testkit/`) on both profiles.
Tagging is the owner's (R8, G1), and `../LibKa0s` belongs to another session, so no tag was made.
The bytes were proven instead: in a scratch folder, a clone of the LibKa0s worktree with a
throwaway local tag `v1.119.0` at `110e02be`, beside a clone of this branch carrying the copied
payloads and `CLAUDE.md`, the kit's `VendorSync.register` answers all three cases PASS. G1's
re-vendor check (bytes equal the tag) turns the two cases green in place once the tag exists.

## Icons and credits
The `LibKa0s icons:` line is kept as it is; Verdict draws no icon. The README credits are unchanged.

## Gate (the re-vendor alone, before any rewire)
- `lua tests/run.lua`: 2938 passed, 2 failed (the two vendor-sync cases above), 168 skipped (3108).
- `KA0S_KIT_CLIENT=forever lua tests/run.lua`: 2976 passed, 2 failed (the same two), 128 skipped (3106).
- `ka0s-bounded luacheck .`: 0 warnings, 0 errors in 313 files.
