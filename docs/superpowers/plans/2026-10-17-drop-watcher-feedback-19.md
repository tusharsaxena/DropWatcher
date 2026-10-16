# Ka0s Drop Watcher: owner feedback, nineteenth session (M26), off-spec: plan

- **Spec:** `docs/superpowers/specs/2026-10-17-drop-watcher-feedback-19-design.md` (settled in conversation and
  auto-approved by the owner, 2026-10-17).
- **Branch:** `feat/2026-10-17-offspec`, cut from `master` at `419bc1e`. Pushed to origin after each milestone item;
  merged only on the owner's go-ahead.
- **Resume:** `docs/superpowers/plans/2026-10-17-drop-watcher-feedback-19/RESUME.md`. `resume-state.sh -v` reads
  what has landed straight from git: an item is done when a commit subject opens with `<ID>: `.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-O0 | The off-spec verdict: modules/OffSpec.lua, the Evaluate hook, Gear's pool and OffSpecGear, Inspect's worn off-spec gear | — | L |
| DW-O1 | How off-spec looks: the offspec tone, WC.Verdict branch, gear half, marks, detail and History cards, History snapshot, filter bar, legends | DW-O0 | L |
| DW-O2 | Ask, the askOffSpec whisper and its row, token gains, the toast and auto-ask (main spec first) | DW-O1 | M |
| DW-O3 | Offer: the off-spec candidate statuses, rank, gain sort and cyan cell | DW-O2 | M |
| DW-O4 | Samples, docs and smoke checks: test-mode off-spec samples, schema/settings/data-flow/module-map/known-limitations/scope/README, FEED-80/81, ASK-11, TOAST-5 | DW-O3 | M |
| DW-O5 | Review: branch diff against the spec and the standard; caps, CCN, perf ceilings, test badge | DW-O4 | M |

The items run in order. Each one builds on the off-spec result the one before it shapes, so a serial run keeps
every commit green on its own.

## Per item

1. Read the spec section and the code it names. Write the failing case(s) first. Run them, and check they fail
   for the right reason.
2. Build the change. Keep every file under 1000 lines, and put new logic in a new module where a file is near
   the cap (LootFeed 992, WindowGroup 983, WindowCells 960, Window 958). Keep every new function at CCN 15 or
   below.
3. Gate through the bounded runner. `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
   must be green, and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` must be 0/0. Every file
   written outside git's filters is CRLF (`.sh` LF).
4. Sync the docs the item touches in the same commit.
5. Commit with the subject `DW-On: <what changed>` and the session's attribution lines. Append a row to
   `checkpoints.tsv` and a line to `RESUME.md`'s log. Push the branch.

## Finish

- DW-O5 reviews the whole branch diff against the spec and the Ka0s standard. Fixes land as `DW-O5:` commits.
- Regenerate `docs/test-cases.md`, and set the README badge to its Total.
- Push the branch and ask the owner to merge. After the merge, delete the run's branches, stashes and
  worktrees.
