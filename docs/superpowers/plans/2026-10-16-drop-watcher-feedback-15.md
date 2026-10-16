# Ka0s Drop Watcher: owner feedback, fifteenth session (M25) — plan

- **Spec:** `docs/superpowers/specs/2026-10-16-drop-watcher-feedback-15-design.md` (approved section by section
  2026-10-16).
- **Branch:** `feat/2026-10-16-drop-watcher-feedback-15`, cut from `master` at `1c82395`. Pushed to origin after
  each milestone step; merged only on the owner's go-ahead.
- **Resume:** `docs/superpowers/plans/2026-10-16-drop-watcher-feedback-15/RESUME.md`; `resume-state.sh -v` answers
  what has landed straight from git (an item is done when a commit subject opens with `<ID>: `).

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-Q0 | The session is the login; the Drops tab rebuilt from history after a reload (new `modules/FeedRestore.lua`, `LF.Restore`, `H.Adopt`, the undone Expired, This instance across a reload) | — | L |
| DW-Q1 | Content per tab: Drops This instance and This session, History adds All; the schema row and migration step 8 | DW-Q0 | M |
| DW-Q2 | One footer button kind and width; Expand all / Collapse all on both tabs in both layouts | DW-Q1 | M |
| DW-Q3 | Clear history leaves the footers for a Settings row on the Window page (`H.AskClear`) | DW-Q2 | S |
| DW-Q4 | The History tab expands a detail card drawn from the snapshot (new `modules/HistoryCard.lua`), both layouts | DW-Q3 | L |

The items run in order: they share the filter bar, the strips and the History views, so a serial run keeps every
commit green on its own.

## Per item

1. Read the spec section and the code it names. Write the failing case(s) first; run them and see them fail for
   the right reason.
2. Build the change; keep every file under 1000 lines (new logic goes in new modules where a file is near it).
3. Gate through the bounded runner: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` green
   and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` 0/0. The eol suite case must pass: every
   file written outside git's filters is CRLF (`.sh` LF).
4. Sync the docs the item touches (module-map rows, schema, settings-panel, data-flow, known-limitations,
   smoke-tests) in the same commit.
5. Commit with the subject `DW-Qn: <what changed>` and the session's attribution lines; append a row to
   `checkpoints.tsv` and a line to `RESUME.md`'s log.

## Finish

- A review pass over the whole branch diff against the spec and the Ka0s standard; fixes land as `DW-Q*` follow-ups.
- `ARCHITECTURE.md` (module map, message bus, known limitations summary) synced.
- Push the branch; ask the owner to merge. After the merge: delete the run's branches, stashes and worktrees.
