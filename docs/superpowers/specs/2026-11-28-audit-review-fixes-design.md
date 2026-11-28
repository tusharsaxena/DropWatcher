# Audit and review fixes (2026-11-28)

**Request (owner, 2026-11-28):** run `/dev-copilot:wow-standards-audit` and `/dev-copilot:review` on
Drop Watcher, collate every action item, spec and plan the fixes, execute them; file upstream changes
as issues in their repos.

**Inputs:** `docs/audits/2026-11-28/` (standard v2.122.0, DRW-03..DRW-19, U-1..U-6) and
`docs/reviews/2026-11-28-2/` (F-001..F-005), both at c7b9bbc.

## Owner rulings

| Item | Ruling |
|---|---|
| Target | Drop Watcher only |
| Bundle folder | today's second review goes to `docs/reviews/2026-11-28-2/` |
| F-002 golden suite | drop the 48 copied kernel cases and the fixture's case table; keep the 16 `golden me:` cases; add 2-4 view tests (client naming, the off-spec gate) |
| DRW-10 / DRW-19 | do all now: split `modules/LootFeed.lua` (past its own 1100 trigger) and `tests/test_test_mode.lua` (1445 of 1500), regenerate the automated-test bundle and `RESULTS.md` with fresh watch-list rulings |

## Claude's calls

| Item | Call | Why |
|---|---|---|
| DRW-13 README H1 | keep `# Drop Watcher`, add a register row citing R6-NAME (2df58ad); file U-1 upstream | the owner already ruled; the row is what ratifies it |
| DRW-15 stand-in popup | conform: `SetToplevel(true)` + a test; U-2 not filed | cheap, removes the question |
| DRW-03 hub size | Event Subscriptions -> `docs/data-flow.md`; Skins and Tooltip placement -> new `docs/skins.md`; pointers left; file U-4 for the clients-§4 table | the audit's own fix |
| DRW-17 `.pkgmeta` | ignore `.claude`, `.pytest_cache`, `.ruff_cache`; file U-5 | ignoring is harmless whatever U-5 decides |
| F-001 skin notice | a `noticeHeld` flag consumed on `PLAYER_REGEN_ENABLED`, cleared by `NS.HideSkinPicker` and the stand-down; no timer | library rule: a stand-down leaves nothing armed |
| F-003 rethrow | one `NS.Rethrowable` (xpcall + traceback) in `core/CoreSetup.lua`, used at all seven sites | keeps the handler's stack in reports |
| F-004 refusals | word `collectible` and `badRequest`; one localized fallback, raw key to debug; `A.Preview` refuses collectibles | the review's fix |
| F-005, U-3, U-6 | issues in LibKa0s (F-005, U-3) and WowAddonStandards (U-6) | upstream-only |
| DRW-18 | relabel #19 `state:done` | bookkeeping |
| DRW-09 | nothing | re-check held |

Non-goals: no version bump, no re-vendor, no edit of a frozen bundle, `libs/` or `tests/_kit/`.
