Delta: LibKa0s v1.88.0 -> v1.89.0

Item `V89-DW` of the cross-repo run `Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (branch `feat/2026-11-06-revendor-libka0s-v1-89`). Written before the copy.

## Correction to `docs/revendor/2026-11-05-v1.88.0/` (Step 0 MISMATCH)

The run's Step 0 pre-flight reports a MISMATCH for this addon. The newest earlier single-tag bundle, `docs/revendor/2026-11-05-v1.88.0/`, states base **v1.85.0** on its line 1, while the provenance line in `CLAUDE.md` before that tag's re-vendor commit `59e323d` named **v1.87.0**. The history shows v1.87.0. That bundle explains the gap itself: the v1.87.0 label sat on the untagged toast-stack tip `dab6407`, never on the release of that name, so it took its delta from v1.85.0, the last real release the addon carried. Its base is deliberate and its record stands. This paragraph only records the disagreement the pre-flight sees. The old bundle is not edited. The command that shows it:

    tag_at() { git show "$1:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
    c=$(git log --format=%H -- libs/LibKa0s tests/_kit CLAUDE.md | while read -r h; do
          [ "$(tag_at "$h")" = v1.88.0 ] && [ "$(tag_at "$h^")" != v1.88.0 ] && { echo "$h"; break; }; done)
    echo "$(git rev-parse --short "$c") parent-tag $(tag_at "$c^")"     ->  59e323d parent-tag v1.87.0
    head -1 docs/revendor/2026-11-05-v1.88.0/01_DELTA.md                 ->  Delta: LibKa0s v1.85.0 -> v1.88.0

## Source

    git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-dw-1492250/ex
    git -C ../LibKa0s rev-parse 'v1.89.0^{commit}'          ->  df00e5f09fc71b59001b9e83afb22f868573b3d2
    git -C ../LibKa0s ls-remote --tags origin v1.89.0       ->  0bd4839... refs/tags/v1.89.0 (pushed)

## 3a. Claimed version, and the base

    grep -n '[Bb]undles' CLAUDE.md
      45:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.88.0 (MIT).
    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   ->  59e323d (DW-T1: Re-vendor LibKa0s from the v1.88.0 tag ...)
    git show "$c:CLAUDE.md" | grep -oE 'Bundles ...'          ->  ... v1.88.0
    git log --format='%h %s' "$c..HEAD" -- CLAUDE.md          ->  ca77e78 DOCS: Sync the docs ... (does not roll the line)

The two agree. Payload today against the v1.88.0 tag (`git -C ../LibKa0s archive v1.88.0 LibKa0s testkit` into `<scratch>/claimed`): `diff -rq --strip-trailing-cr` on both payloads prints only `Only in <scratch>/claimed/LibKa0s/media/icons` lines for undeclared icons. Base **v1.88.0**.

    git -C ../LibKa0s log --oneline v1.88.0..v1.89.0
      df00e5f LK-K2: Release v1.89.0 adds the release run's record and its notes
      f11b9c0 LK-K2: Release v1.89.0 moves every version line to the tag and records the consumer sweep
      367a9f1 LK-K1: Kit revision 51 clears a callback only where one exists, as CallbackHandler does
    git -C ../LibKa0s diff --stat v1.88.0 v1.89.0 -- LibKa0s testkit
      testkit/README.md     |  2 +-
      testkit/framework.lua |  2 +-
      testkit/mock_ace.lua  | 20 +++++++++++++++-----
      3 files changed, 17 insertions(+), 7 deletions(-)

No `LibKa0s/` file moved in this range.

## 3b. Actual version

    grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua   ->  67 constants

All 67 equal the v1.88.0 tag's (3c). The line and the bytes agree.

## 3c. Per-file minor delta

The loop over the v1.89.0 `LibKa0s/LibKa0s.xml` file list (Step 3c's command) prints `old == new` for every one of the 67 shipped files: Core 15, Widgets 23, Toast 4, DebugLogDiagnostics 7, Options 37, IconBrowserSources 1 / IconBrowserWindow 1 / IconBrowser 1, and the rest unchanged. No file is new in this range and no file is behind. **No cross-major skew.**

## 3d. Both diffs (before the copy)

    diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   ->  only the 194 `Only in <scratch>/LibKa0s/media/icons` lines (undeclared icons; the declaration working)
    diff -r                     <scratch>/LibKa0s libs/LibKa0s   ->  same
    diff -r --strip-trailing-cr <scratch>/testkit tests/_kit     ->  README.md, framework.lua, mock_ace.lua differ
    diff -r                     <scratch>/testkit tests/_kit     ->  same three

The kit has content drift against the tag (the three files v1.89.0 changed); the copy fixes it. No line-ending-only drift, no file removed upstream.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Twenty majors looked up: Charts, DebugLog, Compat, Core, Bus, Skin (`core/Database.lua:229,275`, `core/SkinSetup.lua:93`), Perf, Env, Item, Glow, Media, Lifecycle, Launcher, Sim (`core/SimSetup.lua:34`, `modules/Sim.lua:273`), Pool, Toast, Widgets, Options, Schema, Slash. **`LibKa0s-IconBrowser-1.0` has no lookup** (unwired on purpose, `docs/ARCHITECTURE.md:14`).

## 3f. Kit revision and the pairing rule

    grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
      <scratch>/testkit/framework.lua:20:Kit.VERSION = 51
      tests/_kit/framework.lua:20:Kit.VERSION = 50

Kit 50 -> 51. A consumer of LibKa0s v1.9.0+ takes kit revision 11+ in the same commit; both payloads are copied whole, so the pairing holds by construction.

## 3g. Contract delta

No library minor moved (3c), so no consumed major has a new API document to diff. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit` prints nothing. The kit's change (`docs/api/testkit/version-51-docs.md`; `CHANGELOG.md` v1.89.0, "No member moves and no case name changes; a consumer owes only the re-vendor") tightens no contract.

### Blockers

None.

## 3h. Unrecorded vendored tags

Step 3h's listing (horizon `2026-10-14`):

    vendored: v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0 v1.87.0 v1.88.0
    recorded: v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0 v1.87.0 v1.88.0
    grep -vxF -f recorded.txt vendored.txt   ->  (empty)

Empty, so no span bundle is written.

## 3i. The icon declaration

    grep -n 'LibKa0s icons:' CLAUDE.md
      46:LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, eye, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, move, people, reset, settings, speech-bubble, transfer, volume-high.

It is the next non-blank line under the provenance line (45). The provenance sentence ends its line, so nothing needs splitting. **Kept unchanged** (decided: the run's plan keeps the line unless a fact forces a change). No fact does: `git -C ../LibKa0s diff --stat v1.88.0 v1.89.0 -- LibKa0s/media` is empty, so every declared name still exists, and no host code changes in this item. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`). The owner's in-client smoke is the backstop for a name the host forgot to declare.

## 3j. Tests that assume the whole icon folder

    grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
      tests/prose_waivers.lua:15            (a comment)
      tests/test_mine_cells.lua:149         (opens a named, declared icon)
      tests/test_tip_marks.lua:42, :545     (reads declared icons' TGA sizes; arrow-right is declared)

All of them read declared names only, and they were green against the same pruned set at v1.88.0. No blocker.

## Dead stub mirrors

    grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit   ->  (empty)

No `__` member was removed in this range.
