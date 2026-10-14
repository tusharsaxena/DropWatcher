# Ka0s Drop Watcher: review + standards audit remediation (M24) — plan

- **Spec:** `docs/superpowers/specs/2026-10-14-drop-watcher-review-audit-design.md`; per-finding
  evidence and verified fixes in `docs/superpowers/research/2026-10-14-review-audit/findings.md`.
- **Branch (all four repos):** `feat/2026-10-14-drop-watcher-review-audit`.
- **Repos:** `DropWatcher`, `../WowAddonStandards`, `../LibKa0s`, `../dev-copilot`.
- **Resume:** `./2026-10-14-drop-watcher-review-audit/resume-state.sh -v` lists what landed (by commit
  subject `DW-Pn: …` in the owning repo) and names the next items. `checkpoints.tsv` records each
  milestone's gate evidence; `RESUME.md` carries the run log.

## Items

| Id | Repo | Title | Depends on | Findings |
|---|---|---|---|---|
| DW-P1 | WowAddonStandards | slash-commands-§7 step 6 proves reach; AUDIT walks steps 1-10 | — | F22 F29 |
| DW-P2 | WowAddonStandards | toc-file-§5 positional load-bearing definition | — | F23 |
| DW-P3 | WowAddonStandards | documentation-§3 spill vs architecture-§5; spill targets for every hub section | — | F24 F25 |
| DW-P4 | WowAddonStandards | options-ui-§19 reparent onto pooled widget, OnRelease cleanup | — | F26 |
| DW-P5 | WowAddonStandards | Perf-hold refusal wording rule | — | F27 |
| DW-P6 | WowAddonStandards | compat root header names every shim file | — | F28 |
| DW-P7 | WowAddonStandards | Release v2.81.0 ripple (version, CHANGELOG, index, context pack, playbooks) | P1-P6 | X09 |
| DW-P8 | LibKa0s | testkit `__fireUnconditional` reaches method handlers, returns count (kit 39) | — | F19 X02 |
| DW-P9 | LibKa0s | `Perf.Note` top-level observation (Perf 15) | — | F20 |
| DW-P10 | LibKa0s | testkit step-10 hold-ordering helper | P8 | F21 |
| DW-P11 | LibKa0s | Release v1.72.0 on branch (no tag) | P8-P10 | X09 |
| DW-P12 | dev-copilot | Slash census sees constant-driven `RegisterChatCommand` | — | F30 |
| DW-P13 | dev-copilot | Audit prompt: census scope; conformance steps 6/8/10 | — | F31 F32 |
| DW-P14 | dev-copilot | curl timeout/retry; zsh-safe playbook snippets | — | F33 F34 |
| DW-P15 | dev-copilot | Release 2.3.5 | P12-P14 | — |
| DW-P16 | DropWatcher | `NS.StoodDownRefusal` for every refusal site; perf line | P5 (wording) | F01 F10 X01 |
| DW-P17 | DropWatcher | Fixed announce channel honours the group refusal | — | F02 X10 |
| DW-P18 | DropWatcher | Shared event dispatcher isolates handlers | — | F03 X12 |
| DW-P19 | DropWatcher | enUS carries every routed string; test enforces it | — | F07 |
| DW-P20 | DropWatcher | luacheck globals scoped; optional-addon probes via Compat | — | F08 X10 |
| DW-P21 | DropWatcher | SetTestMode doc block; When-to-show OnRelease cleanup; Toast close degrades | P4 | F09 F11 F12 |
| DW-P22 | DropWatcher | Re-vendor LibKa0s v1.72.0; re-check deviations register | P11 | F17 X06 |
| DW-P23 | DropWatcher | Refresh the standard reference to v2.81.0 | P7 | X09 |
| DW-P24 | DropWatcher | evaluate/quality.gate nest within feed.add (Perf 15) | P22 | F06 X05 X12 |
| DW-P25 | DropWatcher | Disabled-state suite: step 6 reach, steps 7/8, step 10 | P22 P16 | F04 F05 F18 |
| DW-P26 | DropWatcher | TOC `LOAD-BEARING:` comments + harness gate | P23 | F15 X07 |
| DW-P27 | DropWatcher | ARCHITECTURE.md spill and stale counts | P23 | F13 F14 |
| DW-P28 | DropWatcher | Docs sync, smoke checks (incl. in-client checks), test-case list, README badge | P27 | X04 X05 X08 |
| DW-P29 | DropWatcher | Automated-test bundle (`/dev-copilot:wow-automated-tests`) | P28 | F16 |

## Milestones and checkpoints

| Milestone | Items | Runs | Checkpoint (gate + push) |
|---|---|---|---|
| M24a | P1-P7 | parallel with M24b, M24c, M24d | WowAddonStandards battery green; push branch |
| M24b | P8-P11 | parallel | LibKa0s battery green (`lua tests/run.lua`, luacheck); push branch |
| M24c | P12-P15 | parallel | dev-copilot battery green; push branch |
| M24d | P16-P21 | parallel (DropWatcher tree, one agent at a time) | DropWatcher gate green; push branch |
| M24e | P22-P27 | after M24a + M24b | gate green + vendor-drift empty against LibKa0s branch head; push |
| M24f | P28-P29 | last | gate green, fresh automated-test bundle; push; final standards re-check |

## Rules for every item

- One commit per item (or `DW-Px + DW-Py: …` when two items share files), subject opening with the id.
  Commit trailers as the repo already uses them.
- Test first where the item changes behaviour: the new case fails on the old code, passes on the fix.
- Green gate before each commit in the owning repo; Lua runs and luacheck go through
  `~/.claude/dev-copilot/bin/ka0s-bounded`.
- Never edit DropWatcher's `libs/` or `tests/_kit/` except by the DW-P22 re-vendor copy.
- Never merge, never tag. After each milestone: append a `checkpoints.tsv` row, a `RESUME.md` log
  line, and push the branch.

## After the run (owner go-ahead only)

1. Merge each repo's branch to `master` (`--no-ff`) in dependency order: WowAddonStandards and LibKa0s
   and dev-copilot, then DropWatcher.
2. Tag WowAddonStandards `v2.81.0`, LibKa0s `v1.72.0`, dev-copilot per its release convention.
3. Delete the run branch locally and on origin in all four repos, plus any worktree or stash this run
   created.
4. Follow-ups outside this run: re-vendor LibKa0s v1.72.0 into the other roster addons (X03).
