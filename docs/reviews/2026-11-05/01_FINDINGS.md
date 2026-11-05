# Findings: whole-run review of issues #10 to #14

**Verdict: minor issues.** Nothing blocks the merge. One cross-cutting data gap (F-001) is worth fixing before merge, and two small items can follow.

**Scope:** branch `feat/2026-11-05-issues-10-14` against `master` (`git diff master...feat/2026-11-05-issues-10-14`, 49 commits, HEAD `0b7a5ba`), which covers issues #10 (ItemRead), #11 (Restrictions), #14 (toast stack and the LibKa0s v1.88.0 re-vendor), #13 (item kinds, collection verdict, tier tokens, item lists) and #12 (Insights). I read the code around the diff wherever an interaction needed it. The earlier per-item and per-milestone reviews already landed their fixes, so this pass looks only for problems that show up across items.

Profile: `dev-copilot-profile` reports `profile=wow kind=addon`. I applied the WoW overlay.

## Measurement run (2026-11-05, HEAD 0b7a5ba)

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 241 files | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` |
| Headless suite | **pass**: 2212 passed, 0 failed, 1 skipped (2213 total). The skip is the kit's `diagnostics contract: an addon that opts out…` case, which does not apply because this addon keeps the default | `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` |
| Fresh `--list` inventory | **pass**: Total 2212. It matches the committed `docs/test-cases.md` (Total 2212) and the README badge `Tests-2212/2212_passing` | `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua --list` (to scratch) |
| Offline perf | **pass**: every ceiling held. `insightsCompute` 4956816.0 bytes/iter (ceiling 5200000) at 39.7 ms/iter over a 5,000-drop log. The refresh pairs are 14288/14288 and 11056/11056, and `showDecisionStoodDown` is 0 | `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/perf.lua` |
| Complexity (sighted) | **pass (non-gating)**: **1 warning**, max CCN 16, 7779 functions, 0 blind files. The warning is `modules/InsightsFilters.lua:174 IF.Period` CCN 16 (F-003) | `~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| `make test` | not applicable (no root Makefile) | — |
| Vendor sync | **pass**: `libs/LibKa0s/` matches `../#Worktrees/LibKa0s-toast-stack/LibKa0s/` (tag v1.88.0) apart from the declared icon prune under `media/icons`. `tests/_kit/` matches `testkit/` | `diff -rq LibKa0s …/libs/LibKa0s \| grep -v media/icons`; `diff -rq testkit …/tests/_kit` |
| Cross-addon | slash roots: **clean** (34 roots, no duplicates). `## Interface:` is **uniform** (`120105`). Toast-1.0 minors: DropWatcher is at **4** and the other 16 addons are at 3. This is expected until they re-vendor, and LibStub serves minor 4, whose `stack`-absent path is the v1 behavior, to all of them whenever DropWatcher loads. Byte identity: not compared, because DropWatcher is the only consumer on v1.88.0 | the overlay's class 1, 2 and 4 commands, run from `../`, over the 17 rows in `ADDONS.md` |

Committed artifacts that disagree with today's run:

- `docs/automated-tests/RESULTS.md` watch list: as of `20261104-042156` (at `5add81d`, 57 commits behind HEAD) it records max CCN **15** and **0** warnings. Today's sighted run measures max CCN **16** with **1** warning: `IF.Period`, a function new on this branch. The record is stale, which is expected because it is regenerated at release. The new entry is F-003.

## Medium

### F-001: A whitelisted item of no kind is recorded with no category, so Insights files it as equipment or as a tier token `[correctness]`

- **Where:**
  - `modules/FeedFilter.lua:72` `if listed(cfg.whitelist, facts.itemID) then return true, nil, true end`: the Always watch list lets through an item that falls in no category (`facts.category == nil`), such as a reagent or a quest item.
  - `modules/LootFeed.lua:281` `if NS.Collectibles.IsCollectible(f) or (forced and f.category == nil) then`: that item is judged feed-only. `modules/Collectibles.lua:128` gives it the verdict `{ verdict = "unknown", equip = "collect", collect = true, … }` with no `category`.
  - `modules/History.lua:189` `category = type(facts.category) == "string" and facts.category or nil,`: the History entry therefore stores no `category`.
  - `modules/InsightsFilters.lua:87` `return e.equipLoc == IF.TOKEN_SLOT and "tierToken" or "equipment"`: Insights applies its **legacy** fallback to that entry. The fallback was written only for drops recorded before #13, but here it catches a drop recorded today.
- **Problem:** #13 (the whitelist) and #12 (the legacy category fallback) each assume that a drop recorded after #13 always has a category. The whitelist breaks that assumption.
- **Impact:** a whitelisted non-gear item is counted under the wrong kind. In retail it most likely counts as **Tier tokens** (a non-equippable item's slot is `INVTYPE_NON_EQUIP_IGNORE`; I could not verify this in the client, see F-002), otherwise as **Equipment**. This affects the Category dropdown and its counts, the Drops by category section and the Category filter. The Drops by slot section also labels it "Tier token". There is no value to filter these drops on their own.
- **Reachability:** any player who adds an item of no watched kind (a reagent, a quest item, a container) to the Always watch list, through the Drops › Item lists tab or `/dw whitelist add`, and then opens Insights. This hits every such drop, on the default profile, with no flag needed.
- **Coverage:** `tests/test_insights_filters.lua` checks `CategoryOf` with a stored category and with the legacy `INVTYPE_NON_EQUIP_IGNORE` slot. No case records a forced, uncategorized drop through `H.Snapshot` and reads it back. The gap is uncovered rather than a test that cannot fail.
- **Fix direction (requirements only):** the snapshot should record that a forced drop has no kind, so that a post-#13 entry can be told apart from a legacy one. Insights then needs a bucket for it (for example a "Watched item" kind, the word `CollectCells.DetailRows` already uses) instead of the legacy fallback.

## Low

### F-002: The documented legacy fallback contradicts itself: "only a tier token has" `INVTYPE_NON_EQUIP_IGNORE` `[correctness]` `[docs]`

- **Where:** `docs/known-limitations.md:107`: "a slot of `INVTYPE_NON_EQUIP_IGNORE`, which only a tier token has and which reads as a tier token. A mount, pet, toy, recipe or cosmetic recorded before then reads as equipment." The same claim appears in the header comment at `modules/InsightsFilters.lua:11`, and the rule is `modules/InsightsFilters.lua:39` `IF.TOKEN_SLOT = "INVTYPE_NON_EQUIP_IGNORE"`.
- **Problem:** in the retail client, any non-equippable item (mounts, pets, toys, recipes) reports an equip slot of `INVTYPE_NON_EQUIP_IGNORE`, which is `Enum.InventoryType` 0. A pre-#13 mount, pet, toy or recipe entry would therefore read as a **Tier token**, not as equipment as the document says. **Unverified:** I have not checked this in the client. The Insights spec's own data table (`…insights-design.md:40`) already lists non-token items under that slot ("Venomforged Icon/Remnant").
- **Impact:** for legacy entries only, Insights counts non-gear items as tier tokens, and the limitation note tells the player the opposite.
- **Reachability:** only a player who ran `master` with `feed.gearOnly` off, which was not the default, and who still has non-gear drops inside the retention window (30 days by default). The window ages this out on its own.
- **Fix direction:** correct the note and the header comment so they describe what the rule actually does. The rule itself was the owner's call (plan, "#12 Q3, refined"), so leave it unless the owner revisits it.

### F-003: `IF.Period` is the first function in the addon above CCN 15 `[complexity]`

- **Where:** `modules/InsightsFilters.lua:174` `function IF.Period(rows, days, range, now)`. Today's sighted lizard run: 16 NLOC, **CCN 16**.
- **Problem:** it is new on this branch and newly crosses the watch-list threshold. Before this branch the repo maximum was 15 with 0 warnings.
- **Impact:** maintainability only. The gate is non-gating.
- **Reachability:** none at runtime. This is the complexity record only.
- **Fix direction:** split the range-start resolution (`Since` against the window or the first drop) from the scan over the rows. The next release's regeneration should confirm the entry is gone.

## Cross-cutting areas checked and found clean

These are recorded so the next pass does not redo them.

- **#13 × #14:** no collectible ever reaches the toast or its stack. `Toast.Qualifies` refuses `collectible`, which also gates AutoAsk. `Asks.Request` refuses `collectible`, including Press. `Messaging.AskTemplate` returns nil. A forced item of no kind is feed-only too.
- **#14:** the degradation stub (`core/ToastSetup.lua`) answers every shell method `modules/Toast.lua` calls: Attach, Clear, Current, Dismiss, Frame, FrameFor, Hold, Pause, Refresh, Release, Remove, ResetPosition, Resume, SetStack, Show, Stats and Visible.
- **Migration step 13:** `NS.MigrateItemKinds` is idempotent and uses a frozen key list. The two lists are `resetExempt` from the page Defaults only, and `/dw reset` and a profile reset still clear them, as documented.
- **#12 × #13:** `IS.Gain` leaves a received collectible in `gainNone`, because it has no `ilvlDelta`. `VERDICT_ORDER` includes the three collection verdicts. Section K labels a token or collectible slot by its kind.
- **#11:** `inCombat()` is defined (`modules/Restrictions.lua:55`) before the signature reads it (`:147`).
- **#10:** a negative or absent count is clamped with `math.max(…, 0)`. The modifier index now advances by the declared count.
