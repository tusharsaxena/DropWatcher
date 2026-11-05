Delta: LibKa0s v1.85.0 -> v1.87.0

Part of this repo's run `docs/superpowers/plans/2026-11-05-issues-10-14.md` (item `DW-T1`, milestone M2, issue #14).

## Source: the branch tip, not the tag (a recorded deviation from Step 2)

The tag `v1.87.0` does not exist yet. The release is prepared on LibKa0s `feat/2026-11-05-toast-stack` (worktree `../#Worktrees/LibKa0s-toast-stack`) and the plan cuts the tag at the merge, on the owner's go-ahead. The payload was therefore taken from that branch's tip commit:

    git -C ../LibKa0s rev-parse feat/2026-11-05-toast-stack   ->  dab6407daaecbef88db16488f60c4453c9452d4f
    git -C ../LibKa0s archive dab6407 LibKa0s testkit tools | tar -x -C <scratch>/

`v1.87.0` is to be cut at the merge from that same commit, `dab6407`. That holds as long as the merge is a fast-forward: `feat/2026-11-04-icon-browser` sits at `cad1609`, which is `v1.86.0`, and `dab6407` descends from it (`git merge-base --is-ancestor v1.86.0 dab6407` succeeds), so merging icon-browser and then toast-stack moves master to `dab6407` without a merge commit. If the tag lands anywhere else, the `LibKa0s/` and `testkit/` trees at the tag must still equal `dab6407`'s, or this addon re-vendors.

Until the tag exists, `tests/test_vendor_sync.lua` cannot resolve `v1.87.0` in `../LibKa0s` and its two payload cases cannot pass in this checkout. See `05_SUMMARY.md` for how the gate was run.

## Pre-flight (Step 0)

The roster walk, with the folder pattern read as backticked paths (`` `\.\./\.\./[A-Za-z0-9]+/` ``; the spec's `\]\(\.\./\.\./...\)` pattern matches nothing in today's `ADDONS.md`): every addon's newest single-tag bundle states the base its history shows. DropWatcher: `2026-11-01-v1.85.0`, base v1.84.0, provenance before `e797f00` was v1.84.0, ok. No MISMATCH row.

## Base (3a)

`grep -n '[Bb]undles' CLAUDE.md` -> `44:Bundles [LibKa0s](...) v1.85.0 (MIT).` The last payload commit, `git log -1 -- libs/LibKa0s tests/_kit` -> `932575f` (R6-RV2), left the same line. Both payloads match v1.85.0 (`git archive v1.85.0 LibKa0s testkit`, `diff -rq` clean apart from the undeclared icons). Base v1.85.0. v1.86.0 was never vendored here, so it is covered by the range and needs no record of its own.

    git -C ../LibKa0s log --oneline v1.85.0..dab6407      # 20 commits, 10 under LibKa0s/ or testkit/
    git -C ../LibKa0s diff --stat v1.85.0 dab6407 -- LibKa0s testkit
      LibKa0s/DebugLogDiagnostics.lua |   8 +-
      LibKa0s/IconBrowser.lua         | 958 +++
      LibKa0s/IconBrowserSources.lua  | 563 +++
      LibKa0s/IconBrowserWindow.lua   | 377 +++
      LibKa0s/LibKa0s.xml             |   3 +
      LibKa0s/Toast.lua               | 528 ++++----
      6 files changed, 2289 insertions(+), 148 deletions(-)

## Actual version (3b) and per-file minors (3c), moved files only

`for f in dab6407:LibKa0s/LibKa0s.xml files: grep the [A-Z_]*MINOR constant, old against new`. The line and the bytes agree at v1.85.0.

| File | old | new | Version |
|---|---|---|---|
| Toast.lua | 3 | 4 | v1.87.0 |
| DebugLogDiagnostics.lua | 6 | 7 | v1.86.0 |
| IconBrowserSources.lua | (new) | 1 | v1.86.0 |
| IconBrowserWindow.lua | (new) | 1 | v1.86.0 |
| IconBrowser.lua | (new) | 1 | v1.86.0 |

No file is behind: no cross-major skew.

## Diffs (3d)

Before the copy, content and bytes differ only by the files above and the undeclared icons (`Only in <scratch>/LibKa0s/media/icons`). `testkit/` is identical to `tests/_kit/`.

## Kit (3f)

`grep -n 'Kit.VERSION'`: revision 50 at both. The kit does not move in this range; the pairing rule (kit 11 or newer with LibKa0s v1.9.0 or newer) holds, and the two payloads are copied whole together anyway.

## Consumption (3e)

Lookups outside `libs/` and `tests/`: Bus, Charts, Compat, Core, DebugLog, Env, Glow, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Sim, Skin, Slash, Toast, Widgets. Unchanged. `LibKa0s-IconBrowser-1.0` (new) has no lookup: an unadopted module (Step 5, class C). Toast: one lookup, `core/ToastSetup.lua:15`. DebugLog: `core/DebugLogSetup.lua:10` and three more.

## Contract delta (3g)

Majors that moved and are consumed: Toast (3 -> 4), DebugLog (Diagnostics 6 -> 7).

    diff <(git -C ../LibKa0s show v1.85.0:docs/api/Toast/version-3-docs.md) \
         <(git -C ../LibKa0s show dab6407:docs/api/Toast/version-4-docs.md)

- **Toast, one queue rule for every host** (`docs/api/Toast/version-4-docs.md:28`, "One queue rule moves, for every host"): a toast sent back from the screen to wait (`Hold()`) goes to the head of the queue and drops nothing, where version 3 trimmed the newest waiting payload; the queue may hold up to the stack's size over `maxQueue` until the next `Show`. This addon's `Toast.OnCombatStart` (`modules/Toast.lua:593`) calls `Hold()`. Not a blocker: the change only keeps a payload that version 3 dropped, and the one count the addon prints (`modules/Toast.lua:543`, a debug line) is already clamped to `MAX_QUEUE`.
- **Toast, `Attach` before the first `Show`** builds the first frame hidden (`version-4-docs.md:28`, `:138`). This addon's builder calls `Attach` from inside the build, so nothing moves here.
- **DebugLog Diagnostics minor 7**: the report's `LibKa0s running:` line names `IconBrowser` (CHANGELOG v1.86.0). No member moves.
- No `__Attach*` site outside `libs/` (`grep -rn '__Attach[A-Za-z]*' --exclude-dir=libs --exclude-dir=_kit`: none).

## Blockers

- **Toast degradation stub** (`docs/api/Toast/version-4-docs.md:201-224`, "A stub written against version 3 lacks `SetStack`, `Visible` and `FrameFor`, and its parity case reddens on the re-vendor"; version 3's stub at `version-3-docs.md` *The degradation stub*): `core/ToastSetup.lua`'s `NS.ToastStub` gains `SetStack`, `Visible` and `FrameFor`, and its `Stats` gains `visible`, `visibleKeys`, `stack` and `grow`, exactly the document's stub. `tests/test_surface_parity.lua:121` holds it to the live instance. Fixed in the re-vendor commit.
- **Icons (3j):** `tests/test_mine_cells.lua:149` and `tests/test_tip_marks.lua:42,545` open declared names only; no loop over the catalog. No blocker.
- **Dead stub mirrors:** `grep -rn '__releaseChrome'` outside `libs/` and `tests/_kit/`: none.

## Icons (3i)

`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 45, the next non-blank line after the provenance line. Kept unchanged: neither release adds a library-drawn name for a surface this addon wires (`dab6407:docs/releasing.md:354-379`: v1.86.0 adds `search` and `close` for the icon browser only; Toast minor 4's per-frame close mark is `close`, already declared). Every name is unprefixed (Open Iconic). Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`), and the owner's in-client smoke is the backstop.

## Tags vendored and unrecorded (3h)

`horizon=2026-10-14`; vendored v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0; recorded the same. Unrecorded: none. No span bundle: v1.86.0 is a library tag this addon never vendored, which the span line does not carry.
