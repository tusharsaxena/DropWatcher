Delta: LibKa0s v1.85.0 -> v1.88.0

Part of this repo's run `docs/superpowers/plans/2026-11-05-issues-10-14.md` (item `DW-T1`, redone; milestone M2, issue #14). This bundle supersedes `docs/revendor/2026-11-05-v1.87.0/`.

## Why this bundle exists, and why its base is v1.85.0

The first `DW-T1` vendored LibKa0s `dab6407`, the tip of `feat/2026-11-05-toast-stack`, under the label v1.87.0, because that tag was to be cut at the merge. Before it was cut, another session released the real v1.87.0 (`758cbd4`, cascading context menus, Widgets minor 23). The toast-stack branch was rebased onto it and released as **v1.88.0**:

    git -C ../#Worktrees/LibKa0s-toast-stack rev-parse v1.88.0              ->  072dcb60527ab4422567d7dfc907948093225c0e (annotated)
    git -C ../#Worktrees/LibKa0s-toast-stack rev-parse 'v1.88.0^{commit}'   ->  3555d432f65d20851fd993a28fc230e2bf34dfc1
    git -C ../#Worktrees/LibKa0s-toast-stack rev-parse v1.87.0              ->  a8727b25225e6c572eab36d3233d8a2ed2ebd378
    git -C ../#Worktrees/LibKa0s-toast-stack merge-base --is-ancestor v1.87.0 v1.88.0   -> succeeds

The provenance line this re-vendor replaces names v1.87.0, but the bytes behind it were never the release of that name (`dab6407` carries Widgets minor 22; v1.87.0 carries 23). The last real release this addon vendored is **v1.85.0** (`docs/revendor/2026-11-01-v1.85.0/`), so the delta is taken from there, as the run's instruction for this item says. Step 3a's rule (the base is the tag the provenance line names) is set aside for that reason. A later Step 0 pre-flight that compares this line's base (v1.85.0) with the provenance line before this commit (v1.87.0) will report a MISMATCH; this paragraph is the explanation.

Payload source, taken from the tag:

    git -C ../#Worktrees/LibKa0s-toast-stack archive v1.88.0 LibKa0s testkit tools | tar -x -C <scratch>/

The delta against what the addon actually carried (`dab6407`) is one file:

    git -C ../#Worktrees/LibKa0s-toast-stack diff --stat dab6407 v1.88.0 -- LibKa0s testkit
      LibKa0s/Widgets.lua | 349 +++++++++++++++++++++++++++++++++++------------
      1 file changed, 270 insertions(+), 79 deletions(-)

## Pre-flight (Step 0)

DropWatcher only (this item's scope). Newest single-tag bundle before this one: `2026-11-05-v1.87.0`, base v1.85.0; the provenance line before `b2726c7` (its re-vendor) was v1.85.0: ok. No MISMATCH row.

## Base (3a) and range

`grep -n '[Bb]undles' CLAUDE.md` -> `44:Bundles [LibKa0s](...) v1.87.0 (MIT).` (before the roll). Base v1.85.0, for the reason above.

    git -C ../#Worktrees/LibKa0s-toast-stack log --oneline v1.85.0..v1.88.0     # 24 commits
    git -C ../#Worktrees/LibKa0s-toast-stack diff --stat v1.85.0 v1.88.0 -- LibKa0s testkit
      LibKa0s/DebugLogDiagnostics.lua |   8 +-
      LibKa0s/IconBrowser.lua         | 958 ++++
      LibKa0s/IconBrowserSources.lua  | 563 ++++
      LibKa0s/IconBrowserWindow.lua   | 377 ++++
      LibKa0s/LibKa0s.xml             |   3 +
      LibKa0s/Toast.lua               | 528 ++++----
      LibKa0s/Widgets.lua             | 349 +++----
      7 files changed, 2559 insertions(+), 227 deletions(-)

Tags crossed: v1.86.0 (icon browser), v1.87.0 (cascading menus), v1.88.0 (toast stack). None of them was vendored here under its own bytes, so the range covers them.

## Actual version (3b) and per-file minors (3c), moved files only

3c's loop over `v1.88.0:LibKa0s/LibKa0s.xml`, run against the v1.85.0 extract (the real base) and against `libs/LibKa0s/` after the copy:

| File | v1.85.0 | carried (`dab6407`) | v1.88.0 | Moved in |
|---|---|---|---|---|
| Widgets.lua | 22 | 22 | 23 | v1.87.0 |
| Toast.lua | 3 | 4 | 4 | v1.88.0 |
| DebugLogDiagnostics.lua | 6 | 7 | 7 | v1.86.0 |
| IconBrowserSources.lua | (new) | 1 | 1 | v1.86.0 |
| IconBrowserWindow.lua | (new) | 1 | 1 | v1.86.0 |
| IconBrowser.lua | (new) | 1 | 1 | v1.86.0 |

Every other file is at its v1.85.0 minor. No file is behind: no cross-major skew.

## Diffs (3d)

After the copy and before the prune: `diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` and `diff -rq` print only `Only in <scratch>/LibKa0s/media/icons…` lines (the undeclared icons, which the earlier prune had removed). `diff -r <scratch>/testkit tests/_kit`: empty. After the prune, the same `Only in <scratch>` icon lines and nothing else.

## Kit (3f)

`grep -n 'Kit.VERSION' tests/_kit/framework.lua`: revision 50 at v1.85.0, at `dab6407` and at v1.88.0. The pairing rule (kit 11 or newer with LibKa0s v1.9.0 or newer) holds, and both payloads are copied whole together anyway.

## Consumption (3e)

Lookups outside `libs/` and `tests/` are unchanged from the first `DW-T1`: Bus, Charts, Compat, Core, DebugLog, Env, Glow, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Sim, Skin, Slash, Toast, Widgets. `LibKa0s-IconBrowser-1.0` has no lookup (class C). Widgets: one lookup, `core/WidgetsSetup.lua:32`.

## Contract delta (3g)

Majors that moved and are consumed: Widgets (22 -> 23), Toast (3 -> 4), DebugLog (Diagnostics 6 -> 7). Toast and DebugLog were read by the first `DW-T1` (`docs/revendor/2026-11-05-v1.87.0/01_DELTA.md`, *Contract delta*); `Toast.lua` and `DebugLogDiagnostics.lua` are byte-identical between `dab6407` and v1.88.0, so those readings stand. New here, Widgets:

    git -C ../#Worktrees/LibKa0s-toast-stack show v1.88.0:docs/api/Widgets/version-23.5.12.6.7.5-docs.md
    diff <(git … show v1.88.0:docs/api/Widgets/members-22.5.12.6.7.5.json) <(git … show v1.88.0:docs/api/Widgets/members-23.5.12.6.7.5.json)
      -> only versionKey and Widgets' minor differ; no member added or removed

- **Widgets minor 23, cascading `W.ContextMenu`** (`version-23.5.12.6.7.5-docs.md:25-36`; CHANGELOG `v1.88.0:CHANGELOG.md:44`): row fields `submenu`, `radio`, `selected` and `opts.check`, all **Since 23** and additive. "Every single-level menu, a dropdown's and a host's, is unchanged" (`:22`), and "What a consumer owes: nothing for a flat menu; a re-vendor" (`:36`). This addon opens no `W.ContextMenu` of its own (its one menu is `NS.Compat.ContextMenu`, Blizzard's `MenuUtil`, `modules/WindowHistory.lua:328`); `NS.CloseMenu` (`core/WidgetsSetup.lua:89-91`) calls `W.CloseMenu()`, which still closes every level. Not a blocker.
- No `__Attach*` site outside `libs/` (`grep -rn '__Attach[A-Za-z]*' --exclude-dir=libs --exclude-dir=_kit`: none).

## Blockers

- **None new.** The Toast degradation stub's `SetStack`, `Visible`, `FrameFor` and `Stats` fields (`docs/api/Toast/version-4-docs.md:201-224`) were already added to `core/ToastSetup.lua` by `b2726c7`, and the Widgets member list did not move, so `tests/test_surface_parity.lua` stays green with no host change.
- **Icons (3j):** unchanged from the first `DW-T1`; the suites open declared names only.
- **Dead stub mirrors:** `grep -rn '__releaseChrome'` outside `libs/` and `tests/_kit/`: none.

## Icons (3i)

`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 45, the next non-blank line after the provenance line. Kept unchanged: v1.87.0 adds no library-drawn name for a surface this addon wires (Widgets 23's submenu arrow is client art, `Interface\ChatFrame\ChatFrameExpandArrow`, and its tick is the existing `confirm`, already declared; `version-23.5.12.6.7.5-docs.md:27,29`). Every name is unprefixed (Open Iconic). Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`), and the owner's in-client smoke is the backstop.

## Tags vendored and unrecorded (3h)

Vendored (by the provenance roll walk): v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0 v1.87.0; recorded the same (v1.87.0 by the superseded bundle). Unrecorded: none. No span bundle.
