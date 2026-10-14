# Resuming the feedback-6 run (M15)

Run `./resume-state.sh -v` in this folder. Items land on `feat/2026-10-13-drop-watcher-feedback-5` (M14 is unmerged;
M15 rides on the same branch). Pick up at the first remaining item in `items.tsv`, read its section of
`docs/superpowers/specs/2026-10-13-drop-watcher-feedback-6-design.md`, keep the green gate before every commit, push
after DW-F1 and DW-F4. Never merge without the owner's go-ahead; after the merge delete the feedback-4 and -5
branches (local and origin), stashes and worktrees.

## Log
- 2026-10-13 16:10 — DW-F0..F5 landed and pushed; bundle 20261013-160309 green. Next: owner merge go-ahead, in-game FEED-31..55, then delete feedback-4/-5 branches.
