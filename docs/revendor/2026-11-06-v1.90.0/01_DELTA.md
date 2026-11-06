Delta: LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-DW` of the cross-repo run `Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (branch `feat/2026-11-06-revendor-libka0s-v1-89`), from that run's owner smoke feedback `SF1_SMOKE_FEEDBACK.md`. Written before the copy.

## Step 0 pre-flight

    tag_at() { git show "$1:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
    tag_at 1a32aec^                                       ->  v1.88.0   (1a32aec = V89-DW, the v1.89.0 re-vendor)
    head -1 docs/revendor/2026-11-06-v1.89.0/01_DELTA.md  ->  Delta: LibKa0s v1.88.0 -> v1.89.0

ok. No base correction is owed.

## Source

    git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/sf1-rv-dw-1707445/ex
    git -C ../LibKa0s rev-parse 'v1.90.0^{commit}'      ->  4485b8f589077b47e61f261405b3008bc4d81838
    git -C ../LibKa0s ls-remote --tags origin v1.90.0   ->  (empty: the tag is local, cut by SF1-L3 and pushed only at the owner's go-ahead)

The provenance line names v1.89.0, not v1.90.0, so this is a new re-vendor and not a refresh.

## 3a. Claimed version, and the base

    grep -n '[Bb]undles' CLAUDE.md
      45:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).
    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   ->  1a32aec (V89-DW: Re-vendor LibKa0s v1.89.0)
    git show "$c:CLAUDE.md" | grep -oE 'Bundles ...'          ->  ... v1.89.0
    git log --format='%h %s' "$c..HEAD" -- CLAUDE.md          ->  (empty)

The two agree. Payload today against the v1.89.0 tag (`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit` into `<scratch>/claimed`): `diff -rq --strip-trailing-cr` on the library prints only `Only in <scratch>/claimed/LibKa0s/media/icons` lines (undeclared icons), and `diff -rq` on the kit prints nothing. Base **v1.89.0**.

    git -C ../LibKa0s log --oneline v1.89.0..v1.90.0
      4485b8f SF1-L3: Release v1.90.0 adds the release run's record and its notes
      4ac9f3c SF1-L3: Release v1.90.0 moves every version line to the tag and records the consumer sweep
      b9f7651 SF1-L2: RegisterOwner's keepScope, a Scope another addon's skin copy never writes
      7d42f4e SF1-L1: Every Widgets edge is one physical pixel at any UI scale, with no skin and under every skin
      e809ca3 Merge feat/2026-11-06-harvest-standards: the 2026-11-06 harvest, standard re-vendor and sync-docs
      72733ee SYNC-DOCS: Name the IconBrowser major everywhere the docs list majors, and DebugLog's current version
      1ca12c6 LK-K3: Merge feat/2026-11-05-kit-unregister-guard (LibKa0s v1.89.0, kit revision 51)
    git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 -- LibKa0s testkit
      LibKa0s/Core.lua                | 137 +++++++++++++++++++++++++++++++++++++++-
      LibKa0s/OptionsAppearance.lua   |  10 ++-
      LibKa0s/Skin.lua                |  12 ++--
      LibKa0s/SkinPaint.lua           |   9 ++-
      LibKa0s/SkinPaintExtras.lua     |  77 ++++++++++------------
      LibKa0s/Widgets.lua             |  16 ++++-
      LibKa0s/WidgetsAutocomplete.lua |   5 +-
      7 files changed, 209 insertions(+), 57 deletions(-)

No `testkit/` file moved in this range.

## 3b. Actual version

    grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua

Every constant equals the v1.89.0 tag's. The line and the bytes agree.

## 3c. Per-file minor delta

Step 3c's loop over the v1.90.0 `LibKa0s/LibKa0s.xml` (67 files). The files that moved:

| File | old | new |
|---|---|---|
| Core.lua | `MAJOR, MINOR = "LibKa0s-Core-1.0", 15` | 16 |
| Skin.lua | `MAJOR, MINOR = "LibKa0s-Skin-1.0", 16` | 17 |
| SkinPaint.lua | `PAINT_MINOR = 18` | 19 |
| SkinPaintExtras.lua | `EXTRAS_MINOR = 17` | 18 |
| Widgets.lua | `MAJOR, MINOR = "LibKa0s-Widgets-1.0", 23` | 24 |
| WidgetsAutocomplete.lua | `AUTOCOMPLETE_MINOR = 7` | 8 |
| OptionsAppearance.lua | `APPEARANCE_MINOR = 6` | 7 |

The other 60 print `old == new`. No file is new in this range and none is behind. **No cross-major skew.**

## 3d. Both diffs (before the copy)

    diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   ->  the seven files above differ, plus the 194 `Only in <scratch>/LibKa0s/media/icons` lines (undeclared icons; the declaration working)
    diff -r                     <scratch>/LibKa0s libs/LibKa0s   ->  same
    diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit    ->  (empty)
    diff -rq                     <scratch>/testkit tests/_kit    ->  (empty)

Content drift in the seven files this tag changed; the copy fixes it. No line-ending-only drift, no file removed upstream.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Twenty-one majors looked up: Bus, Charts, Compat, Core (39 sites), DebugLog, Env, Glow, IconBrowser (2, adopted in this run's V89A commits), Item, Launcher, Lifecycle, Media, Options (20), Perf, Pool, Schema, Sim, Skin (29), Slash, Toast, Widgets (11). Every major whose minor moved (Core, Skin, Widgets, Options) is consumed.

## 3f. Kit revision and the pairing rule

    grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
      <scratch>/testkit/framework.lua:20:Kit.VERSION = 51
      tests/_kit/framework.lua:20:Kit.VERSION = 51

Kit 51 on both sides. A consumer of LibKa0s v1.9.0+ takes kit revision 11+ in the same commit; both payloads are copied whole, so the pairing holds by construction.

## 3g. Contract delta

The moved, consumed majors are Core, Skin, Widgets and Options. Their new documents at the tag: `docs/api/Core/version-16-docs.md`, `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`, `docs/api/Widgets/version-24.5.12.6.8.5-docs.md`, `docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md`. The tag's `CHANGELOG.md` v1.90.0 block: "No `NEEDS_*` floor rises: Widgets and Skin resolve Core's new members at call time and draw as before without them", and "No host owes a facade or stub member."

- Core 16 adds only `__` internals (`__PixelSize`, `__WatchPixels`, `__OnPixelScale`, `__PixelBackdrop`); no member manifest moves.
- Widgets 24 / Autocomplete 8 (Widgets document lines 19-24): the dropdown box, the search box, the shared menu and its cascade levels, and the autocomplete list take `__PixelBackdrop`. On those frames a later `SetBackdrop` reads `edgeSize` and `insets` as physical pixels. This addon never calls `SetBackdrop` on a library control: its `SetBackdrop` sites (`modules/DetailCard.lua:112`, `modules/WindowTitleBar.lua:225`, `modules/IconStyle.lua:207`, `modules/CompactChrome.lua:336`, and the library-absent stub `core/SkinSetup.lua:712`) all paint frames the addon creates itself.
- Skin 17 (Skin document lines 19, 25, 390): `RegisterOwner`'s optional `keepScope`; an owner that does not name it behaves as before. This addon registers at `core/SkinSetup.lua:783` without it.
- OptionsAppearance 7: `lib.__copySkinTo` skips the Scope only for a `keepScope` target. This addon's setter `NS.WriteSkinChoice` already accepts `ignore = nil` (the pre-Skin-5 shape).

    grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit   ->  (empty)

No host-supplied member's call site moved.

### Blockers

None found by reading. The gate after the copy is the check on stubs and pinned sizes; a red there is fixed in this item's commit.

## 3h. Unrecorded vendored tags

Step 3h's listing (horizon `2026-10-14`):

    vendored: v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0 v1.87.0 v1.88.0 v1.89.0
    grep -vxF -f recorded.txt vendored.txt   ->  (empty)

Empty, so no span bundle is written.

## 3i. The icon declaration

    grep -n 'LibKa0s icons:' CLAUDE.md
      46:LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, eye, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, move, people, reset, settings, speech-bubble, transfer, volume-high.

It is the next non-blank line under the provenance line (45), and the provenance sentence ends its line. **Kept unchanged** (decided: the run keeps the line). No fact forces a change: `git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 -- LibKa0s/media` is empty, so every declared name still exists, and this item adds no host art. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`). The owner's in-client smoke is the backstop for a name the host forgot to declare.

## 3j. Tests that assume the whole icon folder

    grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
      tests/prose_waivers.lua:15            (a comment)
      tests/test_mine_cells.lua:149         (opens a named, declared icon)
      tests/test_tip_marks.lua:42, :545     (reads declared icons' TGA sizes)

All read declared names only. No blocker.

## Dead stub mirrors

    grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit   ->  (empty)

No `__` member was removed in this range.
