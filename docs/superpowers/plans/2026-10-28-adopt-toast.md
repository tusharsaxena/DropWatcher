# Plan: adopt LibKa0s-Toast-1.0 for the upgrade toast

Opened 2026-10-28. Branch `feat/2026-10-28-adopt-toast`. Resumable: each step is ticked in the commit that
finishes it; a run that stops resumes at the first unticked box.

## Decisions (the owner, 2026-10-28)

- **Adopt now:** LibKa0s-Toast-1.0 (LibKa0s#60) was built from this addon's `modules/Toast.lua` on LibKa0s
  branch `feat/2026-10-28-toast-1.0` (v1.79.0, unreleased). Adopt it here in the same run so the adoption is
  not lost, the way DpsRace adopted it for its new-best toast.
- **Partial vendor:** another session is changing LibKa0s, so do NOT re-vendor all of it. Copy only
  `LibKa0s/Toast.lua` into `libs/LibKa0s/`, byte-identical to the branch, loaded on its own TOC line after
  `libs\LibKa0s\LibKa0s.xml` (which stays untouched). Recorded as a temporary documented deviation
  (library-stack-§7), re-check trigger: the next full LibKa0s re-vendor, which drops the row.
- **Behavior parity:** the player sees no change: same queue, duration, hover pause, close paths, combat
  hold, test drops that stay until closed, position, scale, sound and test-mode placement. `modules/Toast.lua`
  keeps the content builder, the qualifier and the triggers; the shell moves to the library. Saved position
  and settings keep working with no migration unless one is unavoidable.
- **Library gaps:** a gap found while adopting is fixed in the LibKa0s worktree branch (tests, docs, gate), and
  the file re-copied; never patched in `libs/`.

## Steps

- [x] **A0 Plan** (this file).
- [x] **A1 Vendor Toast-1.0 only:** the file, TOC line, test loader, vendor-sync exception, provenance note in
  `CLAUDE.md`, the deviation row.
- [x] **A2 Adopt:** rebuild `modules/Toast.lua` on the library; tests kept green and adjusted only where they
  pinned shell internals; docs and smoke rows.
- [x] **A3 Review and fixes.**

### Finalize (only on the owner's go-ahead)

- [ ] Merge to master and push, after LibKa0s's Toast branch is merged; the owner re-vendors all of LibKa0s
  later (drop the deviation row then). Delete this run's branch.
