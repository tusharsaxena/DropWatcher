# Resuming the Drop Watcher v1 build

## 1. Find out where the run stands

```sh
bash docs/superpowers/plans/2026-10-10-drop-watcher-v1/resume-state.sh -v
```

Run this from `../DropWatcher`. Its last line names the milestone and items to continue with. It reads only
git, so nothing a crashed session left behind can mislead it.

## 2. Clean up an interrupted item

```sh
cd /mnt/d/Profile/Users/Tushar/Documents/GIT/DropWatcher
git status --short
git branch --show-current
```

The branch should be `feat/2026-10-10-drop-watcher-v1`.

If the tree is dirty, read the diff before doing anything:

| What the diff is | What to do |
|---|---|
| Matches the next unlanded item | Finish it: tests, gate, then commit as `DW-NN: …` |
| Not understood | `git stash push -m "dw-resume <date>"` and note it in the log below |

**Never** `reset --hard` or `checkout .` work that has not been read.

Then run the gate before continuing:

```sh
lua tests/run.lua && luacheck .
```

## 3. Relaunch

**The exact procedure is in `orchestration/README.md`.** That folder holds the milestone workflow script
`dw-milestone.workflow.js`, every milestone's args in `milestones.json`, and `checkpoint.sh`, so a fresh
session can resume from the repository alone.

In short:

Hand the next run:
- the spec
- the plan
- this file
- the `RESUME at` line

Milestones run in order M0 → M6. Items inside a milestone follow `items.tsv` order and dependencies.

## 4. Milestone checkpoint

1. Gate green, run by the orchestrator itself.
2. The reviewer's notes are attached: `git notes --ref=ka0s-review show HEAD`.
3. Append a row to `checkpoints.tsv` with the date, the milestone and the evidence: test totals, luacheck,
   the HEAD of each repo touched.
4. Push the branch and its notes:

   ```sh
   git push -u origin feat/2026-10-10-drop-watcher-v1
   git push origin refs/notes/ka0s-review
   ```

   Push `../Ka0sAddonsCommonTasks` and `../WowAddonStandards` too whenever they changed.

**After M6, stop.** The merge waits for the owner's go-ahead. Once the owner approves, `/dev-copilot:finalize`
merges `--no-ff`, pushes, and deletes the run branches. It then cleans up the run's stashes and worktrees.

## Log

Record anything unusual here: stashes, exceptions or reruns.

- **2026-10-10:** M0 was launched twice. The first launch was stopped within a minute because its review base was wrong, and it left no commits and a clean tree.
- **2026-10-11:** the orchestration files were committed to `orchestration/` while M2 was running, as an owner request. M2 was launched with exactly the `milestones.json` M2 args. The workflow run ids are wf_9b95c354-c8a (M0), wf_c73336da-006 (M1) and wf_c4583449-d63 (M2); they are only usable for a same-session resume.
- **2026-10-11:** the owner held pushes after M1 (auto mode refused the M2 checkpoint), then authorized the push after M6; `Checkpoint M6` (26b9079) covers M2–M6. Before that, DW-61 also split the pure text parsers out of `core/Compat.lua` (9def3b0) at the owner's request.
- **2026-10-11:** the owner asked for an in-game simulator. It is milestone **M7** (DW-70..74), added by `../2026-10-11-drop-watcher-simulator.md` and its spec; this plan stays frozen. `items.tsv`, `resume-state.sh` (milestone list) and `orchestration/milestones.json` gained M7.
- **2026-10-11:** M7 checkpoint pushed (c68f2b5). The owner's first in-game look produced milestone **M8** (DW-80..85), added by `../2026-10-11-drop-watcher-ui-feedback.md` and its spec, with the screenshots under `docs/superpowers/research/2026-10-11-ui-feedback/`.
- **2026-10-11:** M8 checkpoint pushed (4b6ac75). The owner's first `/dw sim run` produced milestone **M9** (DW-90..92), added by `../2026-10-11-drop-watcher-sim-feedback.md` and its spec, with evidence under `docs/superpowers/research/2026-10-11-sim-feedback/`.
