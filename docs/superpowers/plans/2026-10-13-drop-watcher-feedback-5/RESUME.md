# Resuming the feedback-5 run (M14)

Run `./resume-state.sh -v` in this folder: an item is done when a commit whose subject opens with its id exists on
`feat/2026-10-13-drop-watcher-feedback-5` or `master`. Pick up at the first remaining item in `items.tsv`, read its
spec section (`docs/superpowers/specs/2026-10-13-drop-watcher-feedback-5-design.md`), and keep the green gate
(`ka0s-bounded lua tests/run.lua`, `ka0s-bounded luacheck .`, 0/0) before every commit. Push the branch after DW-E2,
DW-E4 and DW-E5. Never merge without the owner's go-ahead; after the merge, delete the run's branches
(`feat/2026-10-13-drop-watcher-feedback-4` and `-5`, local and origin), stashes and worktrees.

## Log
