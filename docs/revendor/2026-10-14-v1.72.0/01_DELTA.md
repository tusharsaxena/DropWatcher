Delta: LibKa0s v1.71.0 -> v1.72.0

# 01 — Delta

Re-vendor run DW-P22 of the 2026-10-14 review + audit remediation (findings F17, X06). The mechanics
are `/dev-copilot:wow-revendor-libka0s` Steps 2 to 4. Its interview (Steps 5 to 7) is not run here,
because adoption is plan items DW-P24 and DW-P25 (see `02_CANDIDATES.md`).

## The source is tag v1.72.0

The payload was first prepared from the LibKa0s branch head while `v1.72.0` was still untagged
(decision D4 of `docs/superpowers/specs/2026-10-14-drop-watcher-review-audit-design.md` cut tags only
on the owner's approval). The owner has since approved it, and `v1.72.0` is an annotated tag, pushed,
at that same head commit `785c297`. The copy is therefore taken from the tag, and the prepared bytes
were checked against it before they were committed:

```sh
git -C ../LibKa0s cat-file -t v1.72.0                 # tag
git -C ../LibKa0s rev-parse 'v1.72.0^{commit}'        # 785c29780ad60a858fabde5360890986a4e31bd2
git -C ../LibKa0s rev-parse HEAD                      # 785c29780ad60a858fabde5360890986a4e31bd2
git -C ../LibKa0s ls-remote --tags origin v1.72.0     # a06c900... refs/tags/v1.72.0
git -C ../LibKa0s status --short                      # (clean)
git -C ../LibKa0s archive v1.72.0 LibKa0s testkit | tar -x -C <scratch>/new
diff -r <scratch>/new/LibKa0s libs/LibKa0s && diff -r <scratch>/new/testkit tests/_kit   # (empty)
```

`tests/test_vendor_sync.lua` resolves the provenance tag in `../LibKa0s` and compares both payloads
file by file at that tag; both cases pass.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 41:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # 86b6634 (DW-02 scaffold)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0
git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq --strip-trailing-cr <scratch>/old/LibKa0s libs/LibKa0s && \
  diff -rq --strip-trailing-cr <scratch>/old/testkit tests/_kit && echo payload-matches
# payload-matches
```

The base is **v1.71.0**. The line and the last payload commit agree, and the payload matches it.

```sh
git -C ../LibKa0s log --oneline v1.71.0..v1.72.0
# 785c297 DW-P11: v1.72.0 release record (2/2) (docs/automated-tests/20261014-215316/)
# 0521d49 DW-P11: release v1.72.0 (1/2) - version block, pointers, consumers (X09)
# 3582356 DW-P10: kit revision 39 - Kit.assertLatchHoldOrder, the step-10 helper
# e5d1214 DW-P9: Perf minor 15 - Perf.Note records an observation at top level (parentKey false)
# 3fdd342 DW-P8: kit revision 39 - __fireUnconditional reaches method-name handlers
# 5d22cf1 docs(releasing): add QuickComms as a consumer
# 5f2b478 docs(releasing): add DropWatcher and PremadeGroupsFilterExtension as consumers
# aad51fa SD-FIN-03: revert OptionsIdList.lua comment edit; payload stays byte-identical to v1.71.0
# 16baff4 SD-FIN-02: sync docs to code (collection sync-docs pass 2026-10-09)
# e08dd1d Merge branch 'feat/2026-10-07-review-audit-remediation'
git -C ../LibKa0s diff --stat v1.71.0 v1.72.0 -- LibKa0s testkit
#  LibKa0s/Perf.lua        |  40 ++++++++++----
#  testkit/README.md       |  41 +++++++++++++--
#  testkit/framework.lua   |   4 +-
#  testkit/latch.lua       | 137 ++++++++++++++++++++++++++++++++++++++++++++++++
#  testkit/mock_base.lua   |   8 ++-
#  testkit/mock_record.lua |  18 +++++++
#  6 files changed, 234 insertions(+), 14 deletions(-)
```

Step 0 pre-flight: this is DropWatcher's first `docs/revendor/` bundle, so there is no earlier
bundle whose base could be misstated.

## 3b. Actual version

The minors in `libs/LibKa0s/*.lua` before the copy were v1.71.0's, file for file (the table in 3c,
`old:` column). The line and the bytes agreed.

## 3c. Per-file minor delta

```sh
for f in $(git -C ../LibKa0s show v1.72.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do
  printf '%s  old: %s  new: %s\n' "$f" \
    "$(grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/"$f")" \
    "$(git -C ../LibKa0s show v1.72.0:LibKa0s/"$f" | grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+')"
done
```

All 34 shipped files kept their minor except one:

| File | Constant | Old | New |
|---|---|---|---|
| `Perf.lua` | `MINOR` (`LibKa0s-Perf-1.0`) | 14 | **15** |

No file is new in the range, and no file was removed. No consumer file is behind, so there is no
cross-major skew.

## 3d. Both diffs

Before the copy, against the tag:

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
# Files .../LibKa0s/Perf.lua and libs/LibKa0s/Perf.lua differ
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
# Files .../testkit/README.md and tests/_kit/README.md differ
# Files .../testkit/framework.lua and tests/_kit/framework.lua differ
# Only in .../testkit: latch.lua
# Files .../testkit/mock_base.lua and tests/_kit/mock_base.lua differ
# Files .../testkit/mock_record.lua and tests/_kit/mock_record.lua differ
```

There were no `Only in libs/LibKa0s` or `Only in tests/_kit` lines, so nothing needed deleting.
After the copy, both content diffs are empty (`content-clean`). The byte diffs differ only in line
endings: the archive is LF and this checkout pins `* text=auto eol=crlf`. Git normalises that on
add, and `test_vendor_sync` strips CR from the working-tree side.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Fifteen majors are looked up, one setup file each. Env, Core, Bus, Compat, DebugLog, Widgets, Pool,
Lifecycle, Launcher, Item, Perf and Media are looked up in `core/*Setup.lua` (Bus and Compat in
`core/Bus.lua` and `core/Compat.lua`). Schema, Slash and Options are looked up in `settings/`. No
lookup site is unrecorded. The one major whose minor moved (Perf) is consumed, in
`core/PerfSetup.lua:15`.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION *=' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# new: Kit.VERSION = 39    vendored before: Kit.VERSION = 38
```

Kit revision 39 arrives with the library in the same commit. Both payloads are copied whole, so the
pairing rule (LibKa0s v1.9.0 or newer needs kit revision 11 or newer) holds by construction.

## 3g. Contract delta

**Perf 14 to 15.** `git -C ../LibKa0s show v1.72.0:docs/api/Perf/version-15.1.1.6-docs.md`. Its header
says it supersedes `version-14.1.1.6-docs.md` because "`Note` could not record that a call ran at
top level". Its "What changed at this version" section says, at :77, "What a host must change:
nothing." `P.Note(key, ms,
parentKey)` gains a third state, `parentKey == false`, meaning observed at top level. A nil parent
still means "not stated". The nesting footer is now printed only when something actually nests.
Every DropWatcher call site uses the two-argument form (`modules/LootFeed.lua:225`, `:266`, `:635`,
`modules/LootParser.lua:216`, `modules/Gear.lua:258`, `modules/Inspect.lua:248`,
`modules/TradeTimer.lua:345`), so each call reads exactly as it did under minor 14.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
# (no host-supplied __Attach* seam)
```

**Kit 38 to 39.** `M.__fireUnconditional` now also reaches a handler registered under a method name
that is not the event, or registered as a function, after unregister (`mock_record.lua`, kept on the
`__events` metatable as `__kitEver`). It answers how many handlers it reached. This changes what the
`tests/test_disabled.lua:103-104` reach calls do. Finding F17 predicted those calls would go red;
under revision 39 they stay green. Proving reach by asserting the count is plan item DW-P25 (F04).
`latch.lua` adds `Kit.assertLatchHoldOrder`, which is additive.

**Blockers: none.** No host-supplied member's call site moved, and no new MUST applies to a surface
this addon already uses.

## 3h. Unrecorded vendored tags

This is the first bundle in `docs/revendor/`, so there is no horizon and nothing to back-fill.
