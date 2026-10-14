# Resuming the feedback-4 run (M13)

Run `./resume-state.sh -v` in this folder: an item is done when a commit whose subject opens with its id exists on
`feat/2026-10-13-drop-watcher-feedback-4` or `master`. Pick up at the first remaining item in `items.tsv`, read its
spec section, and keep the green gate (`lua tests/run.lua`, `luacheck .`) before every commit.

## Log
