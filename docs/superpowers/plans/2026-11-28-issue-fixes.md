# Item Search split follow-ups: fix the filed issues (2026-11-28)

**Goal:** fix the 16 issues the Item Search split run (#19) filed, plus the owner's tooltip request
(the "Item Search" label 2px larger), across LibKa0s, WowAddonStandards, Drop Watcher and Item Search.

**Branch:** `feat/2026-11-28-issue-fixes` in all four repos. LibKa0s and WowAddonStandards run in
worktrees at `<repo>/.worktrees/issue-fixes` (their main checkouts belong to another session),
hidden through `.git/info/exclude`. Push after each phase; **no merge without the owner's go-ahead**.
At the end: delete the branches, worktrees and any stashes this run made.

**Gates** (all through `~/.claude/dev-copilot/bin/ka0s-bounded`): each repo's documented green gate
(both kit profiles where the addon has both; luacheck 0/0; seed pytest where present;
`tools/check-standard.sh` in the standard).

## Owner rulings (2026-11-28)

| Issue | Ruling |
|---|---|
| ItemSearch#2 | Rename Test mode's creatures to plainly invented names |
| ItemSearch#3 | Drop Watcher-era `dw` private fields take LibKa0s's `_` prefix (`.dwHot` -> `._hot`); check each for a collision with a LibKa0s/AceGUI widget field first |
| ItemSearch#4 | Build the lines cache now, without waiting for a client capture |
| LibKa0s#107 | Widen the weight slider to -5..20 |
| LibKa0s#110 | The kit changes: an unresolvable provenance ref is a declared skip; a resolvable tag that differs still fails |
| LibKa0s#111 | Seam-wrapping: a host overrides only the reads it names; Drop Watcher drops its duplicate compat reads |
| WowAddonStandards#17 | Narrow reading: a color row wholly unread under a condition may be dimmed (also settles #13) |
| Versions | LibKa0s v1.120.0, standard v2.122.0 (the other session's Feed and lh-farm branches renumber after) |
| Owner request | The tooltip's "Item Search" label line is drawn 2px larger than the tooltip's line font |

Owner-side, not code: ItemSearch#5 (in-game smoke), DropWatcher#22 (CurseForge page; this run drafts
the text as an issue comment).

## Ledger

| Task | Repo | What | Status | Commit |
|---|---|---|---|---|
| L1 | LibKa0s | #107 slider -5..20, case for an out-of-range import | todo | |
| L2 | LibKa0s | #108 `StandUp{ lazy = true }`: first gear read deferred to first ask, no gear announce for it | todo | |
| L3 | LibKa0s | #110 kit vendor_sync: unresolvable ref -> skip with reason; kit revision bump | todo | |
| L4 | LibKa0s | #111 seam-wrapping design note + implementation; docs/api | todo | |
| L5 | LibKa0s | #109 class-list seed contract (spec, derive, apply + CRLF WEAPONS writer, tests, docs/validate-seeds.md) | todo | |
| L6 | LibKa0s | v1.120.0 bump, CHANGELOG, docs, release gate; push | todo | |
| W1 | Standards | #15 seed-research frozen store; #16 clients-§11 Forever-only sentence; #17 narrow reading (+#13); counts if LibKa0s moved; v2.122.0; push | todo | |
| D1 | DropWatcher | Re-vendor LibKa0s v1.120.0 (payload + kit) | todo | |
| D2 | DropWatcher | #21 events from `lib.EventsFor`; #108 drop the provisional read; #111 drop duplicate compat reads; #109 drop class-list flavor + fixture writer test | todo | |
| D3 | DropWatcher | #20 split RT.FlushOverlaps, buildMembers, RC.Left to CCN <= 15 | todo | |
| D4 | DropWatcher | Docs/test-cases/badge, gate; #22 draft comment; push | todo | |
| I1 | ItemSearch | Re-vendor v1.120.0; #6 events from `lib.EventsFor`; #108/#111 host follow-through | todo | |
| I2 | ItemSearch | #2 invented creature names; #3 `_` prefix rename | todo | |
| I3 | ItemSearch | #4 lines cache; label +2px (restored on tooltip clear) | todo | |
| I4 | ItemSearch | Docs/test-cases/badge, smoke rows for the new behavior, gate; push | todo | |
| G1 | all | Owner merge go-ahead, merge, tag v1.120.0, close issues, cleanup | todo | |

Order: L and W in parallel; D and I after L6 (they vendor from the branch, provenance v1.120.0;
vendor-sync skips until the tag exists, which is L3's own behavior).
