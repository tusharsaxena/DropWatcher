# Orchestration: how the milestones are driven

Everything a fresh Claude Code session needs to keep the build going is in this folder. Nothing depends on
the session that started the run.

| File | What it is |
|---|---|
| `dw-milestone.workflow.js` | The workflow script, run once per milestone with that milestone's args. It has three stages: **Implement**, where one agent per item works in order, test first, and commits `DW-NN: …` only on a green gate. **Review**, where three independent read-only reviewers check spec conformance, Ka0s standard compliance, and WoW API correctness. **Fix**, where one agent verifies each medium-or-higher finding and fixes the real ones. The script ends by writing a `refs/notes/ka0s-review` note on HEAD. |
| `milestones.json` | The args for every milestone, M0–M6: `base` (the commit the review diffs from), `extra` (context for the whole milestone) and `items` (id, title, notes). M3–M6 were drafted before they ran, and their `base` is filled in at launch time. |
| `checkpoint.sh` | The milestone checkpoint. It refuses to run on a dirty tree. It runs the gate itself through `ka0s-bounded`, appends the evidence row to `../checkpoints.tsv`, commits `Checkpoint <M>: …`, copies the review note to the checkpoint commit, pushes the branch and the notes, and prints `resume-state.sh`. |

## Relaunching

1. Find out where the run stands:

   ```sh
   bash docs/superpowers/plans/2026-10-10-drop-watcher-v1/resume-state.sh -v
   ```

   The script reads git. The `RESUME at Mx: …` line is the milestone and the items still owed.
2. Clean up any interrupted item, following `../RESUME.md` §2.
3. Build the args. Take `milestones.json[Mx]` and keep only the item ids the `RESUME at` line lists. Set
   `base`:

   | Situation | `base` |
   |---|---|
   | Starting a milestone | The last `Checkpoint` commit, found with `git log --grep '^Checkpoint' -1 --format=%h` |
   | Restarting mid-milestone | The milestone's original `base`, so the review sees the whole milestone |

4. Launch it from Claude Code with the Workflow tool:

   ```
   Workflow({ scriptPath: "<repo>/docs/superpowers/plans/2026-10-10-drop-watcher-v1/orchestration/dw-milestone.workflow.js",
              args: <the args object> })
   ```

   **Re-running is safe.** Each implement agent checks `git log` for its id first. It verifies and finishes a
   landed item rather than redoing it.
5. When the workflow returns, read its result: each item's `committed`, the fix summary and the low findings.
   Then run:

   ```sh
   bash docs/superpowers/plans/2026-10-10-drop-watcher-v1/orchestration/checkpoint.sh Mx "<label>"
   ```

   **Ka0sAddonsCommonTasks and WowAddonStandards** carry the same branch name. Push them whenever they change;
   only M0 changed them.
6. **After M6, stop.** Ask the owner for the merge go-ahead. Never merge, tag or bump a version without it.

## Same-session resume

A workflow killed mid-run inside the session that launched it can be resumed with
`Workflow({scriptPath, resumeFromRunId})`. Agents that already completed replay from cache. A new session
cannot use the run id, so it follows the relaunch steps above. Git is the state either way.
