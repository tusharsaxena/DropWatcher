# Resuming the feedback-2 run (M10)

1. In `../DropWatcher`: `bash docs/superpowers/plans/2026-10-11-drop-watcher-feedback-2/resume-state.sh -v`. It reads
   git; its last line names the items still owed.
2. On a dirty tree read the diff first; finish the item it belongs to or stash it. Never `reset --hard` unread work.
3. Relaunch with the Workflow tool: `scriptPath` =
   `docs/superpowers/plans/2026-10-10-drop-watcher-v1/orchestration/dw-milestone.workflow.js`, `args` =
   `milestones.json` (this folder) `M10`, items filtered to the ids still owed, `base` = the run's first commit's
   parent on this branch (`git merge-base master HEAD`).
4. Checkpoint: gate, append to `checkpoints.tsv`, commit, push the branch and `refs/notes/ka0s-review`. Then stop for
   the owner's merge go-ahead.

## Log
