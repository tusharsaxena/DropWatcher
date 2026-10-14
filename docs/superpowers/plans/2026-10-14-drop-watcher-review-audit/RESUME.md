# Resuming the review + audit remediation run (M24)

Run `./resume-state.sh -v` in this folder. Items land on `feat/2026-10-14-drop-watcher-review-audit` in
the repo named by `items.tsv` column 3. Keep each repo's green gate. Push after each milestone; never
merge or tag without the owner's go-ahead.

Per-item fix detail: `../../research/2026-10-14-review-audit/findings.md` (by F/X id, mapped in
`items.tsv` column 8).

## Log
- 2026-10-14 — Review + audit run; 34 findings verified, 12 critic items; spec and plan written.
- 2026-10-14 — M24a-d landed in parallel. DW-P22 blocked: vendor_sync needs a LibKa0s tag; owner approved cutting and pushing v1.72.0 early (amends D4 for LibKa0s only).
- 2026-10-15 — DW-P22/P24/P25 landed, DW-P30 added (docs sync + bundle re-cut). All 30 items landed; 46/46 findings closed or non-goal. Waiting on the owner's merge go-ahead.
