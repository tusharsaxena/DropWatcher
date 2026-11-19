Delta: LibKa0s v1.106.0 -> v1.107.0

Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit 427e108d). The tag is local only, which is expected: the lead pushes it at finalize. Run as item AF-RV-DW of the cross-repo run `feat/2026-11-19-adoption-feedback` (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, plan M2). That run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s` only: its adoption interview is skipped and no GitHub issue is filed here.

## Step 0 pre-flight
The newest single-tag bundle `2026-11-16-v1.105.0` states base v1.103.0; the provenance line before the commit that vendored v1.105.0 named v1.103.0. `ok`. No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 3ef0e9f (Re-vendor LibKa0s v1.106.0); its CLAUDE.md names v1.106.0. They agree.
- `diff -rq --strip-trailing-cr <v1.106.0 extract>/LibKa0s libs/LibKa0s` lists only the undeclared icons and the pruned sounds; `diff -rq <v1.106.0 extract>/testkit tests/_kit` is empty. The payload was v1.106.0's.
- Range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` lists 7 commits.

## 3b/3c Per-file minors that moved
```
WidgetsDragHandle.lua     DRAG_MINOR 14 -> 15
WidgetsDragHandleTip.lua  DRAGTIP_MINOR 1 -> 2
```
Every other file is at its v1.106.0 minor (`diff -rq` of the two extracts' `LibKa0s/` names only these two files). No file is added or removed. No cross-major skew.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s` and `diff -rq <extract>/testkit tests/_kit` are both empty. After the prune, the only differences are `Only in <extract>/LibKa0s/media/icons…` (undeclared icons) and `Only in <extract>/LibKa0s/media/sounds…` (no `LibKa0s sounds:` line, so none ship).

## 3e Consumption
This addon looks up no `LibKa0s-Widgets-1.0` `DragHandle` and no `Callout` (the library's one internal strip): `grep -rn 'DragHandle' modules core settings` finds no call. The two files that moved are unconsumed here, so the release reaches this addon as bytes only.

## 3f Kit
`Kit.VERSION = 57` at both tags; the testkit is unchanged.

## 3g Blockers
None. The release's "What a consumer owes" list binds strip hosts (an `onClose`, the `settings` icon, removing a strip `tooltipPlace` hook); this addon hosts no strip.

## 3h Span
v1.106.0 was vendored by `3ef0e9f` with no bundle; recorded in the span bundle `../2026-11-19-v1.106.0-v1.106.0/`.

## 3i Icon declaration
Kept unchanged (32 names, `settings` included, as the release asks of a strip host; this addon declares it for its window headers). The prune refused nothing: `kept` the declared icons, removed the undeclared icons and 362 voice-pack files.

## 3j Tests assuming the whole icon folder
None new.
