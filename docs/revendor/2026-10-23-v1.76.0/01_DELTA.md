Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta

Re-vendor item DW-RV of the cross-repo run "sim auto-run, QC preview selector, mode strips and
MM/KCD simulators" (`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`). The mechanics
are `/dev-copilot:wow-revendor-libka0s` at dev-copilot 2.4.0 (the installed plugin), Steps 2 to 4.
The owner pre-decided every adoption in that bundle's `plan-data/items.json` (DW-01 and DW-10), so
Step 5 records the candidates as decided and Step 6 does not interview (`02_CANDIDATES.md`,
`03_DECISIONS.md`). No issue is filed.

## The source is the local tag v1.76.0

```sh
git -C ../LibKa0s cat-file -t v1.76.0                 # tag (annotated, 546e284)
git -C ../LibKa0s rev-parse 'v1.76.0^{commit}'        # 9949368df8db12e51c9c51e403738989c87709a5
git -C ../LibKa0s ls-remote --tags origin v1.76.0     # (nothing: the tag is local until the owner's go-ahead)
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools | tar -x -C <scratch>
```

The copy is taken from the tag, never from the LibKa0s working tree, and the tag was never checked
out. `tools/` is extracted only for `prune-icons.lua`, and is not copied into the addon.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # 3414a82 (Re-vendor LibKa0s v1.75.2)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2
git -C ../LibKa0s archive v1.75.2 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq --strip-trailing-cr <scratch>/old/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>/old/LibKa0s/media/icons'   # (empty)
diff -rq --strip-trailing-cr <scratch>/old/testkit tests/_kit && echo kit-matches                                        # kit-matches
```

The base is **v1.75.2**. The line, the last payload commit and the payload agree.

```sh
git -C ../LibKa0s log --oneline v1.75.2..v1.76.0 | wc -l                     # 8 commits
git -C ../LibKa0s diff --stat v1.75.2 v1.76.0 -- LibKa0s testkit | tail -1
# 3 files changed, 148 insertions(+), 53 deletions(-)   (SimPanel.lua, SimTimeline.lua, Widgets.lua)
```

Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-10-22-v1.75.0`, states base
v1.72.0, and the provenance line before its re-vendor commit `fd4818d` named v1.72.0. `ok`; no base
correction.

## 3b. Actual version

The minors in `libs/LibKa0s/*.lua` before the copy were v1.75.2's, file for file (the `old` column
below). The line and the bytes agreed.

## 3c. Per-file minor delta

```sh
for f in $(git -C ../LibKa0s show v1.76.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do
  printf '%s  old: %s  new: %s\n' "$f" \
    "$(grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/"$f" 2>/dev/null)" \
    "$(git -C ../LibKa0s show v1.76.0:LibKa0s/"$f" | grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+')"
done
```

The tag ships 40 files, as v1.75.2 did. Three moved:

| File | Constant | Old | New |
|---|---|---|---|
| `Widgets.lua` | `MINOR` (`LibKa0s-Widgets-1.0`) | 13 | **14** |
| `SimTimeline.lua` | `TIMELINE_MINOR` | 2 | **3** |
| `SimPanel.lua` | `SIM_PANEL_MINOR` | 4 | **5** |

Composite keys at the tag: Widgets **14.1.4.3.2** (was 13.1.4.3.2), Sim **2.3.5** (was 2.2.4;
`Sim.lua` stays at 2). Seventeen majors across forty files. No consumer file was behind, so there is
no cross-major skew.

## 3d. Both diffs

Before the copy, against the tag:

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>/LibKa0s/media/icons'
# Files .../SimPanel.lua, SimTimeline.lua, Widgets.lua differ
diff -rq <scratch>/testkit tests/_kit          # (empty)
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing upstream removed needed deleting.

After `cp -r` and **before** the prune, both diffs, content and bytes, were empty against the whole
copy. After the prune:

```sh
diff -r <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in <scratch>/LibKa0s/media/icons'   # (empty)
diff -r <scratch>/LibKa0s libs/LibKa0s | wc -l     # 198: 196 undeclared Open Iconic marks + 2 set folders
diff -r <scratch>/testkit tests/_kit               # (empty)
```

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Seventeen majors looked up (Bus, Compat, Core, DebugLog, Env, Glow, Item, Launcher, Lifecycle,
Media, Options, Perf, Pool, Schema, Sim, Slash, Widgets). Both moved majors are consumed: Widgets
(seven lookup sites; `W.TestStrip` through `NS.MakeTestStrip`, `core/WidgetsSetup.lua:64-66`) and Sim
(four lookup sites; the session in `modules/Sim.lua`, the timeline in `modules/SimScenario.lua`).

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION *=' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# tag: Kit.VERSION = 41    vendored before: Kit.VERSION = 41
```

Kit revision 41 unchanged and byte-identical. Both payloads are copied whole, so the pairing rule
holds by construction.

## 3g. Contract delta

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
# (no host-supplied __Attach* seam)
git -C ../LibKa0s show v1.76.0:CHANGELOG.md     # the v1.76.0 block, "What a consumer owes"
```

- **Widgets 14 (`W.TestStrip`'s `kind`).** Additive: `opts.kind` absent or anything but `"sim"`
  draws the amber strip it always drew, and `strip.kind` is new and read-only. This addon's one call,
  `W.TestStrip(parent, { text = text, icon = NS.Icon("info") })` (`core/WidgetsSetup.lua:66`), is
  unchanged on screen. Not a blocker.
- **SimTimeline 3 and SimPanel 5: a simulation plays on its own** (Sim
  `docs/api/Sim/version-2.3.5-docs.md`). A typed `/dw sim start`, the picker's Start, the idle Start
  row, a typed `restart` and the controls' Restart arm the run; Run all leaves the panel and
  `RUN_ALL` leaves `Sim.STRINGS`. `sim:Start{}` and `sim:Restart()` arm nothing. No host member's
  call site moved, and no host overrides `RUN_ALL` (`grep -rn RUN_ALL locales modules core settings`
  finds nothing), so no host code is wrong the moment the bytes land.

### Blockers

One, the CHANGELOG's "Re-true suites that typed `start` and then ran". Six cases of
`tests/test_sim_scenario.lua` went red on the fresh payload, all because a typed start now plays:

```
FAIL  sim start: the scenario's pool, group and situation, and the window open   (the library's status line)
FAIL  sim step: the timeline waits for the pool, then plays one step at a time
FAIL  sim run: plays every step a few seconds apart, each with its line, then says it has finished
FAIL  sim step delay: an untouched setting runs the steps one second apart
FAIL  sim step delay: a run waits the set delay, and a change takes effect from the next step
FAIL  sim e2e key: parsed drops, both verdicts, the ask held in the lockdown and flushed, countdowns, a trade
```

The run's item DW-01 owns this fallout in full (new auto-play cases, the re-true of each case, the
ready line, the step-delay tooltip and the docs and smoke procedures that name Run all). The item
spec of DW-RV asks for the minimum adjustment here so the gate stays green, and this commit makes
exactly that:

- `:249` the status line after a typed start reads `, step 0 of 15, playing.` (was `waiting for a
  step`), DW-01's own wording for the case (its pool is ready at once, so not `building`);
- `:270`, `:340`, `:382`, `:416`, `:540` a `slash(NS, "sim pause")` after the typed start, so each
  case keeps its subject (the manual step, the run's pace, the e2e run) and the following `sim run`
  resumes as `run` did before. Each line carries a `DW-RV` comment naming DW-01.

No assertion was dropped and no addon code changed. The player-visible strings and docs that still
name Run all (`docs/settings-panel.md:67`, `docs/schema.md:67`, the smoke procedures, the step-delay
tooltip and the ready line) are DW-01's, by the item spec.

## 3h. Unrecorded vendored tags

```sh
# the Step 3h listing, horizon 2026-10-14
# vendored: v1.72.0 v1.75.0 v1.75.1 v1.75.2    recorded: v1.72.0 v1.75.0    unrecorded: v1.75.1 v1.75.2
```

Back-filled by the consolidated span bundle `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`, written
in this run. After it and this folder, the listing prints nothing.

## 3i. The icon declaration

`CLAUDE.md:42` is a standalone provenance line, and the declaration is the next line, kept
unchanged from v1.75.0's bundle (28 names, evidence in `docs/revendor/2026-10-22-v1.75.0/01_DELTA.md`
3i). This range adds no library-drawn icon, and no host draw site was added since:

```
LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, people, reset, speech-bubble, transfer.
```

`info` stays declared: the strip's mark is host-passed (`NS.Icon("info")`), and DW-10's sim-flavor
strip passes the same mark (the v1.76.0 CHANGELOG: a host that passes `kind = "sim"` still declares
`info`).

### The prune

```sh
lua <scratch>/tools/prune-icons.lua .
# prune-icons: .: 28 icon(s) declared; kept 29 file(s), removed 5811
```

The same 5,811 as v1.75.0 (196 Open Iconic marks, Phosphor 1,435 files, Game-icons 4,180 files),
all of which arrived with the copy and never reached git. What ships: 28 `.tga` and
`LICENSE-open-iconic.txt`, unchanged.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

Unchanged from v1.75.0: a comment and three declared-name assertions. No blocker.
