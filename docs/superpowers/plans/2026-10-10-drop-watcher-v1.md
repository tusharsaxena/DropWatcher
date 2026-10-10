# Ka0s Drop Watcher v1: implementation plan

- **Spec:** `docs/superpowers/specs/2026-10-10-drop-watcher-v1-design.md`.
- **Plan data:** `docs/superpowers/plans/2026-10-10-drop-watcher-v1/`
  - `items.tsv`: the manifest
  - `resume-state.sh`: progress, read from git
  - `RESUME.md`: how to pick up after a crash
  - `checkpoints.tsv`: milestones that passed
  - `exceptions.tsv`: items that landed without a commit
- **Branch:** `feat/2026-10-10-drop-watcher-v1`, used in every repo this run touches: DropWatcher,
  Ka0sAddonsCommonTasks and WowAddonStandards.

**This plan is frozen once execution starts.** Later developments go in `checkpoints.tsv`, in `RESUME.md`'s log
section, or in commit messages.

## Rules of the run

1. **Git is the only state.** An item is done when a commit whose subject starts with `DW-NN: ` exists in its
   repo. Several items can share one commit, written as `DW-10 + DW-11: …`.
2. **Every commit passes the green gate.** In `../DropWatcher`, run `lua tests/run.lua` and `luacheck .`
   (0 warnings, 0 errors). No file may pass 1500 lines, and none should be left above 1000.
3. **Tests come first** for every pure kernel. Edge modules are tested against the kit mock, extended in
   `tests/wow_mock.lua`.
4. **The standard is followed to the letter.** The context pack is read from scratch and never stored.
   Each LibKa0s module adopted gets one setup file. There are no private copies of library subsystems,
   except the deviations listed in spec §14.
5. **Commits** end with the session's attribution trailers.
6. **Pushes.** The feature branches are pushed after each milestone checkpoint. **Nothing is merged, tagged or
   version-bumped without the owner's go-ahead.** `/dev-copilot:finalize` does the merge once the owner
   approves.
7. **In-game smoke checks** go in `docs/smoke-tests.md` as owed checks. They are never marked passed by an
   agent.
8. **On a dirty tree,** never `reset --hard` or `checkout .` work that has not been read. Continue it or stash
   it.

## Milestones

The items and their dependencies are in `items.tsv`.

| Milestone | Theme | Items | Checkpoint |
|---|---|---|---|
| **M0** | Foundation | DW-00..03 | Gate green on the scaffold; first automated-test bundle; ADDONS.md row committed on the WowAddonStandards branch; push all three branches |
| **M1** | Pure kernels and data | DW-10..15 | Gate green; kernel suites cover every spec table row; push |
| **M2** | Live edges and orchestration | DW-20..2A | Gate green; `/dw add` path works headless (feed → evaluate → estimate); push |
| **M3** | UI | DW-30..34 | Gate green; window builds headless under the mock; test mode populates every state; push |
| **M4** | Settings, slash, launcher, diagnostics | DW-40..43 | Gate green; schema and parity suites; diagnostics contract; push |
| **M5** | v1 features | DW-50..54 | Gate green; scoring, history and auto-ask suites; push |
| **M6** | Docs and release readiness | DW-60..63 | Four-suite automated run with CCN ≤ 15; independent review and audit findings fixed; issues filed; push; **stop and ask the owner for the merge go-ahead** |

## Execution model

The build runs as **ultracode workflows**, one milestone at a time:

- **Implementation.** One agent per milestone, or per item for large items, works in the main checkout of
  `../DropWatcher` on the run branch. It is the only writer in that repo during its step, so commits stay
  linear. Each agent takes its items in `items.tsv` order. For each item it writes the tests, implements the
  code, runs the gate and commits with the `DW-NN: ` subject.
- **Review.** After a milestone's implementation, an independent reviewer agent reads the milestone's diff
  against the spec and the standard. Its findings are fixed in follow-up commits titled
  `DW-NN: fix review …`, and the review summary is recorded as a `refs/notes/ka0s-review` note on the
  milestone's last commit.
- **Checkpoint.** The orchestrator, this session, runs the gate itself, appends a row to `checkpoints.tsv`,
  and pushes the branch along with its notes.

## Item notes beyond items.tsv

- **DW-02 (scaffold).** Follows the `/dev-copilot:wow-new-addon` instructions, using the playbook and context
  pack in the local `../WowAddonStandards` checkout, which matched origin master `1f43a89` on 2026-10-10.
  - LibKa0s `v1.71.0` is copied from `../LibKa0s` at that tag: `LibKa0s/` goes to `libs/LibKa0s/`, and
    `testkit/` goes to `tests/_kit/`.
  - Ace3 libs are copied from a roster addon.
  - Interface is `120100`.
  - The launcher menu carries Enabled · Locked · Test mode · Show window.
  - The first automated-test bundle runs through `ka0s-bounded`.
- **DW-03.** The ADDONS.md row is an Edit on the `feat/2026-10-10-drop-watcher-v1` branch of
  `../WowAddonStandards`, made only if that tree is clean. It is pushed with the M0 checkpoint, under the
  owner's run authorisation.
- **DW-27.** Gate order: situation, then quality (which needs the verdict for me, from my gear only), then
  inspect request, then the looter's verdict and the trade estimate.
- **DW-41.** The `When to show` tab is a grid of situations by setting. It needs a custom row renderer through
  Options composers. If the Options library cannot render a grid, use one row group per situation, and record
  a LibKa0s issue for a grid composer.
- **DW-60.** README de-AI pass (`/humanize`). The `## Reporting a bug` text is copied verbatim from
  `documentation-§1`.
- **DW-62.** Uses the `dev-copilot:review` and `dev-copilot:wow-standards-audit` agents. Their bundles are
  committed under `docs/reviews/<date>/` and `docs/audits/<date>/`.
- **DW-63.** GitHub writes are spaced at least 20s apart.

## Risks during the build

| Risk | Mitigation |
|---|---|
| The mock lacks the APIs used here: `C_TooltipInfo`, `C_ChallengeMode`, `NotifyInspect`, restriction APIs and others | Extend `tests/wow_mock.lua` only, never `tests/_kit/`. If the kit's base mock needs an addition, file it as a LibKa0s issue. |
| Options composers missing for the token chips or the situation grid | Build them with the existing Widgets. If a composer is truly missing, the composition stays in-addon and is recorded in Documented deviations. |
| CCN creep in the evaluate and feed modules | Keep functions small from the start. M6 measures complexity, and M3–M5 reviewers flag functions above 10. |
