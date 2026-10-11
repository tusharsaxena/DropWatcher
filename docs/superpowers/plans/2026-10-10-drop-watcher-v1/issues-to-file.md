# DW-63: GitHub issues to file

**Status: filed 2026-10-11** on the owner's go-ahead: I01–I08 are DropWatcher#1–#8, I09 LibKa0s#49, I10 LibKa0s#50, I11 WowAddonStandards#11, I12 LibKa0s#51, I13 LibKa0s#52, I14 LibKa0s#53. The text below is the draft as written; it is kept as the record. **Earlier status: drafted, not filed.** The owner held every GitHub write for the v1 run ("Hold the pushes"),
so DW-63 drafts the issues here instead of creating them. Nothing below exists on GitHub yet. When the
hold lifts, the owner runs the snippet at the end of this file, which files them at least 20 seconds
apart (the plan's DW-63 rule).

**Sources.** Design spec §14 (the later-tier list, the LibKa0s promotion and the standards proposal),
plus the issue owed from DW-41: a LibKa0s grid composer for *When to show*
(`docs/settings-panel.md`, `docs/ARCHITECTURE.md` Known Limitations). The audit's DRW-02
(`docs/audits/2026-10-11/02_DEVIATIONS.md`) is closed by filing I09 and I11.

**Checked and not owed.** No LibKa0s Media icon is missing: every name the addon asks `NS.Icon` for
(`chevron-down`, `chevron-up`, `chevron-right`, `clock`, `close`, `confirm`, `help`, `info`, `lock`,
`minimise`, `reset`) is in the v1.71.0 catalog. The base mock needed no addition either:
`tests/wow_mock.lua` carries this addon's client seeds and nothing in `tests/_kit/` was patched.

**Labels.** The `issue-*` conventions: every issue is filed `state:triaged` (decided: not now, still on
the books) with one `severity:` label and the `enhancement` tag. Titles carry neither status nor
severity. `tusharsaxena/LibKa0s` and `tusharsaxena/WowAddonStandards` already have the eight
`state:`/`severity:` labels; `tusharsaxena/DropWatcher` has only GitHub's defaults, so the snippet
creates the eight there first.

## Index

| Id | Repo | Title | Labels |
|---|---|---|---|
| I01 | tusharsaxena/DropWatcher | Wishlist with tiers (BiS, Need, Nice, Mog) and a groupmate-looted alert | state:triaged, severity:low, enhancement |
| I02 | tusharsaxena/DropWatcher | Tier-set and catalyst flags, and a verdict for tier tokens | state:triaged, severity:low, enhancement |
| I03 | tusharsaxena/DropWatcher | Void Core and bonus-roll awareness | state:triaged, severity:low, enhancement |
| I04 | tusharsaxena/DropWatcher | Addon comms between Drop Watcher users | state:triaged, severity:low, enhancement |
| I05 | tusharsaxena/DropWatcher | Read-only interop with the PLH and PLR loot protocols | state:triaged, severity:low, enhancement |
| I06 | tusharsaxena/DropWatcher | Droptimizer or SimC import for a "% DPS" column | state:triaged, severity:low, enhancement |
| I07 | tusharsaxena/DropWatcher | Loot-spec nudge on entering an instance | state:triaged, severity:low, enhancement |
| I08 | tusharsaxena/DropWatcher | Record received trades in Ka0s Loot History as "Traded from X" | state:triaged, severity:low, enhancement |
| I09 | tusharsaxena/LibKa0s | Promotion candidates from Drop Watcher: chat sender, tooltip line reader, loot-line parser, restriction tracker | state:triaged, severity:low, enhancement |
| I10 | tusharsaxena/LibKa0s | Options: a grid composer for rows of mixed controls | state:triaged, severity:low, enhancement |
| I11 | tusharsaxena/WowAddonStandards | Proposal: a rule for chat an addon sends on the player's behalf | state:triaged, severity:low, enhancement |
| I12 | tusharsaxena/LibKa0s | Item-1.0: an exact item read (link detail, better link, level and quality), and a loot-line parser | state:triaged, severity:low, enhancement |
| I13 | tusharsaxena/LibKa0s | Widgets-1.0: a flat search box and a flat checkbox, in the dropdown's skin | state:triaged, severity:low, enhancement |
| I14 | tusharsaxena/LibKa0s | Perf-1.0: generalize PerfPanel into a shared step panel | state:triaged, severity:low, enhancement |

**Added by DW-80 (M8, 2026-10-11).** I12 drafts the promotion ui spec §0 asks for: the item read the
owner's BUG-1 fix wrote as `core/ItemRead.lua`. It is filed with the rest, under the same hold.

**Added by DW-82 (M8, 2026-10-11).** I13 drafts the shared-widget need ui spec §2 (FB-5) asks for:
the flat search box and checkbox the filter bar now hand-builds, as Loot History hand-builds its search
box. It sits beside LibKa0s#48 (the test-mode strip as a shared widget), which already exists; the
two can be merged on filing if the owner prefers one Widgets issue.

**Added by DW-91 (M9, 2026-10-11).** I14 drafts the LibKa0s issue sim feedback spec §1 asks for: a
shared step panel generalized from Perf's `PerfPanel.lua`, which Drop Watcher's simulation panel
(`modules/SimPanel.lua`) copies today. It is filed with the rest, under the same hold.

**After filing.** Swap "is filed at the end of the v1 run" in the three LibKa0s rows and the chat row of
`docs/ARCHITECTURE.md` → `## Documented deviations` for `LibKa0s#<n>` and `WowAddonStandards#<n>`,
and the DW-63 pointers in Known Limitations and `docs/settings-panel.md` for `LibKa0s#<n>` (I10). That
closes DRW-02. The step-panel row of the same register names I14 by its draft id; swap it for
`LibKa0s#<n>` too.

---

## I01: Wishlist with tiers (BiS, Need, Nice, Mog) and a groupmate-looted alert

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I01 -->
````markdown
### Description

A per-character wishlist: items marked BiS, Need, Nice or Mog, with a minimum upgrade track per entry. When a groupmate loots a wishlisted item, the feed raises it above everything else and (opt-in) the toast fires for it, even when the item-level gain alone would not qualify. The Adventure Guide's loot list gets a star to add or remove an entry.

### Motivation

Later-tier feature X12 of the brainstorm (`docs/superpowers/research/2026-10-10-brainstorm/03_FEATURES.md`), out of scope for v1 (design spec §1 non-goals, §14). It was the most valued planning feature in the survey (KeystoneLoot, Beggar, ZolLoot). Raw item-level gain undervalues a BiS trinket or a set piece, so the feed today can rank the drop a player most wants below a bigger but worse item.

### Proposed behavior

- A wishlist store per character (`DB.char`), keyed by item id, with tier and minimum track.
- A wishlist column or badge in the feed and on the detail card, and a sort key that puts wishlisted drops first.
- The toast's qualifier (`modules/Toast.lua`, `Qualifies`) accepts a wishlisted drop at or above its minimum track.
- An entry point from the Adventure Guide's loot list, guarded for the frame being absent.

### Acceptance criteria

_TBD_ (to settle when the feature is designed; the qualifier and sort rules above are the starting point).

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I02: Tier-set and catalyst flags, and a verdict for tier tokens

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I02 -->
````markdown
### Description

Flag a drop that completes a tier-set bonus for its candidate ("gives 2-piece", "gives 4-piece") and a drop that can be catalyzed into a tier piece. Read the slot a tier token makes, so a token gets a real verdict instead of `unknown`.

### Motivation

Later-tier feature X11 of the brainstorm, out of scope for v1 (design spec §14). Tier is worth more than raw item level, so an item-level-only verdict misleads exactly where it matters most. The v1 Known Limitations (`docs/ARCHITECTURE.md`) record the token half: tier tokens are recognized (`modules/ItemFacts.lua`, `isTierToken`) but the slot a token makes is not read, so the verdict for one is `unknown` "until the tier-token follow-up". This is that follow-up.

### Proposed behavior

- The set id from `GetItemInfo` (16th return) and the set's bonuses per spec (`C_Item.GetSetBonusesForSpecializationByItemID`) give the pieces a candidate already wears and what the drop would add.
- A catalyst flag for a drop whose slot and season the catalyst converts.
- A tier token maps to its slot and to the class list it already reads, then takes the ordinary verdict for that slot.
- Each flag has a reason tooltip, as every other cell does.

### Acceptance criteria

_TBD_. At minimum, a tier token for the player's class answers a verdict other than `unknown` in `tests/test_evaluate.lua`.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I03: Void Core and bonus-roll awareness

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I03 -->
````markdown
### Description

Track the player's Void Cores (the bonus-roll currency) and make bonus-roll loot visible as such across the window, not only in the trade estimate.

### Motivation

Later-tier feature X16 of the brainstorm, out of scope for v1 (design spec §1 non-goals, §14). v1 already parses the bonus-roll loot lines (`modules/LootParser.lua`, kind `bonus`) and answers `No` for them in the trade rules (`modules/TradeRules.lua`, reason `bonusRoll`), because bonus-roll loot is never tradeable. What it does not do is say so up front: a bonus-roll drop sits in the feed beside tradeable ones, which confuses players who ask for it (KeystoneLoot and Beggar both track this).

### Proposed behavior

- A bonus-roll badge on the row, so the `No` is explained before the player hovers.
- An option to hide other players' bonus-roll drops from the feed.
- A Void Core count in the footer or the diagnostics, with the currency read through `core/Compat.lua`.

### Acceptance criteria

_TBD_.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I04: Addon comms between Drop Watcher users

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I04 -->
````markdown
### Description

An addon-message channel between players who both run Drop Watcher: a confirmed trade timer from the looter, an "I'll trade it" or "keeping it" answer, and asks that resolve without a whisper.

### Motivation

Later-tier feature X14 of the brainstorm, out of scope for v1 (design spec §1 non-goals, §14; brainstorm open question A5). Comms turn a `Likely` trade estimate into `Yes` (the looter's own client knows the timer), and they spare both players a whisper exchange. PLH and PLR both have it.

### Proposed behavior

- `C_ChatInfo.SendAddonMessage` under a registered prefix of at most 16 characters, through `core/Compat.lua`.
- Messages queued while `AddOnMessageLockdown` holds (encounters and keystones), essential ones kept and the rest dropped, following RCLootCouncil's `CommsRestrictions.lua` as the model to study (brainstorm `02_PLATFORM_CONSTRAINTS.md`).
- The per-prefix budget respected: 255 bytes per message, 10 messages per prefix refilling at one a second.
- Every payload treated as untrusted input; a malformed message is dropped and counted in the diagnostics.
- The trade estimate takes a comms-confirmed `Yes` as a new reason.

### Acceptance criteria

_TBD_.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I05: Read-only interop with the PLH and PLR loot protocols

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I05 -->
````markdown
### Description

Listen to the addon messages Personal Loot Helper (PLH) and PersoLootRoll (PLR) send, read-only at first, so a groupmate running either one can confirm a trade or answer an ask.

### Motivation

Later-tier feature X15 of the brainstorm, out of scope for v1 (design spec §1 non-goals, §14; brainstorm open question A6). PLH has about 2.7M downloads and PLR speaks its protocol, so interop reaches far more groupmates than Drop Watcher's own comms (the I04 issue) ever would.

### Proposed behavior

- First, check both addons' licenses; the brainstorm recorded that as a precondition ("legal check on licenses needed").
- Decode their keep, offer and request messages into the same confirmations I04 defines.
- Never send on their prefixes in the first version.

### Acceptance criteria

_TBD_, after the license check. Depends on the comms layer (the I04 issue).

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I06: Droptimizer or SimC import for a "% DPS" column

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I06 -->
````markdown
### Description

Import a Raidbots Droptimizer result (or a SimC export) and show each drop's simulated gain as a "% DPS" column next to the item-level and stat-weight verdicts.

### Motivation

Later-tier feature X13 of the brainstorm, out of scope for v1 (design spec §1 non-goals, §14). A sim is the strongest signal beyond stat weights (LootPlanner, RCLC-wowaudit, cttLoot). v1 scores with Pawn or imported weights (`modules/Scoring.lua`).

### Proposed behavior

- A paste box in Settings › Comparison taking the export string, parsed by a pure, tested parser.
- Results stored per character and spec, with the date of the sim, and shown stale past a set age.
- The column falls back to the existing score when an item is not in the sim.

### Acceptance criteria

_TBD_.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I07: Loot-spec nudge on entering an instance

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I07 -->
````markdown
### Description

On entering a dungeon, raid or keystone, one chat line (opt-in) when the player's loot specialization differs from their current spec, or from a loot spec they chose for that instance.

### Motivation

Later-tier feature X17 of the brainstorm, out of scope for v1 (design spec §1 non-goals, §14). It is cheap and KeystoneLoot users like it. The brainstorm also flagged the risk: it is scope creep for a loot watcher, so it stays off by default and never changes the loot spec itself.

### Proposed behavior

- A setting, off by default.
- One printed line per instance entry when the specs differ, through `NS.Print`; nothing in combat.
- The situation classifier (`modules/Situations.lua`) decides which instances count.

### Acceptance criteria

_TBD_.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I08: Record received trades in Ka0s Loot History as "Traded from X"

- **Repo:** `tusharsaxena/DropWatcher`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I08 -->
````markdown
### Description

When a trade Drop Watcher asked for completes, tell Ka0s Loot History, so its record of the item reads "Traded from X" instead of an anonymous bag gain.

### Motivation

Later-tier feature X19 of the brainstorm, out of scope for v1 (design spec §14): a synergy within the collection. v1 already matches a completed trade to the ask in its own history (`modules/History.lua`, trade-completion matching), so the fact exists; Loot History simply never hears it.

### Proposed behavior

- A versioned public surface on one side (public-api in the standard): either Loot History exposes a "record a trade source" call, or Drop Watcher publishes the completed trade and Loot History reads it.
- Each addon works unchanged when the other is not loaded.
- A matching Loot History change, filed on that repo once the shape is chosen.

### Acceptance criteria

_TBD_.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I09: Promotion candidates from Drop Watcher: chat sender, tooltip line reader, loot-line parser, restriction tracker

- **Repo:** `tusharsaxena/LibKa0s`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I09 -->
````markdown
## What

Ka0s Drop Watcher (v1, built 2026-10-10 on LibKa0s v1.71.0) wrote four shapes in-addon that a LibKa0s major could carry. Each is a ratified row in its `docs/ARCHITECTURE.md` → `## Documented deviations` (library-stack-§7, anti-patterns #47), and each row promises this issue. Filed so the library decides, against library-stack-§7's three promotion bars, which of them move upstream and which are recorded as rejected.

## The candidates

1. **The chat sender.** `Compat.ChatSender()` answers `C_ChatInfo.SendChatMessage`, else the deprecated `SendChatMessage` global (deprecated since 11.2.0), resolved at call time. `DropWatcher core/Compat.lua:101` and `MultiMeters core/Compat.lua:766` are line-for-line the same function with the same semantics: two consumers, no flags, and a stable shape (it changes only if Blizzard renames the namespace). It clears all three bars today. A natural home is `LibKa0s-Compat-1.0`'s reader arm.
2. **The tooltip line reader and the duration decoder.** `Compat.ReadTooltipLine(data, typeName, parse)` (`core/Compat.lua:256`) returns the first non-nil `parse(leftText)` over the `C_TooltipInfo` lines of a given `Enum.TooltipDataLineType`, falling back to every line when the client lacks the type, and guarding secret or missing text. `Compat.DecodeDuration(text)` (`core/Compat.lua:188`) decodes the client's localized duration sentence from its own GlobalStrings. One consumer today: bar 1 is not met. Re-check when a second addon reads tooltip lines by type.
3. **The loot-line parser.** `modules/LootParser.lua` compiles the `LOOT_ITEM*` GlobalStrings (multiple, bonus roll, pushed) into patterns for every looter, rebuilds them when another addon rewrites the globals, recovers positional arguments, and rejects the upgrade echo (`CHANGED_OWN_ITEM`) and crafting lines. `LootHistory core/Util.lua` carries the only other parser and reads the player's own loot only, so the semantics differ: bar 1 is not met. Re-check if Loot History needs third-person loot.
4. **The restriction tracker.** `modules/Restrictions.lua` folds `ADDON_RESTRICTION_STATE_CHANGED`'s hints, `InChatMessagingLockdown` and the combat edges into four answers: `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason`. AuraMaster and ConsumableMaster react to the same event, but to re-run their own work, not to answer what is allowed. Bar 1 is not met; re-check when a second addon needs the same four answers.

## The ask

- Decide (1). If accepted, ship it additively and Drop Watcher and MultiMeters adopt it on their next re-vendor, each dropping its host copy and its deviation row.
- Record (2)–(4) as "not yet, one consumer" with their re-check triggers (library-stack-§7 asks for rejections to be recorded where the next author looks), unless the library sees a second consumer the census missed.

## Evidence

- `DropWatcher docs/ARCHITECTURE.md`, `## Documented deviations` (the three library-stack-§7 rows).
- `DropWatcher docs/audits/2026-10-11/02_DEVIATIONS.md`, DRW-02 (the register's promised issues).
- Design spec `DropWatcher docs/superpowers/specs/2026-10-10-drop-watcher-v1-design.md` §2 and §14.

**Severity:** `low`: a promotion question, not a defect; nothing is broken while the copies stay in-addon.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I10: Options: a grid composer for rows of mixed controls

- **Repo:** `tusharsaxena/LibKa0s`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I10 -->
````markdown
## What

Ka0s Drop Watcher's *When to show* tab (Settings › General) was designed as a grid: one line per situation (ten of them: Mythic+, dungeon, follower dungeon, LFR, raid, delve, scenario, PvP, open-world group, solo) and one column per setting: `Track` (checkbox), `Auto-open` (checkbox) and `Quality` (a dropdown of `Use global` or a mode). LibKa0s-Options has no composer for that. `O.ChoiceGrid` (OptionsWidgets W16+) draws one **choice** per row over **one shared value list**, so it cannot hold two checkboxes and a dropdown on one line. Drop Watcher fell back to one block per situation, three rows each, which is a 30-row page where the design had a 10-line table.

## The ask

A composer that draws a header line of column labels, then per row the row's label and one cell per column, where each column names the maker that draws its cell (checkbox, dropdown, perhaps slider or input) and each cell is an ordinary schema row read and written through the maker seam. The rest as `ChoiceGrid` already does it: `skipRender` rows kept in the schema for the CLI and the resets, `disabledIf` per cell re-evaluated on `RefreshScalars`, a `pcall`-guarded line per row, the relative widths that keep the last cell clear of the ScrollFrame's clip (options-ui-§8), and pool-safe widgets (options-ui-§19). Additive within `-1.0`.

## Consumers

- Drop Watcher: `settings/SchemaRows.lua`, `whenToShow()` (`situations.<key>.track`, `.autoOpen`, `.quality`), drawn by `settings/Panel.lua`.
- Any per-context matrix elsewhere in the collection is a candidate second consumer; none was surveyed for this draft.

## Evidence

- `DropWatcher docs/settings-panel.md`, *General → When to show*.
- `DropWatcher docs/ARCHITECTURE.md`, Known Limitations (the *When to show* line).
- `docs/api/Options/`, *The choice grid* (the composer that comes closest).

**Severity:** `low`: a layout improvement; the fallback works.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), owed from DW-41.*
````

## I11: Proposal: a rule for chat an addon sends on the player's behalf

- **Repo:** `tusharsaxena/WowAddonStandards`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I11 -->
````markdown
## Summary

The standard has no rule for chat an addon **sends**. events-frames-taint-§5 covers formatting chat that arrives; nothing covers whispers or group messages sent on the player's behalf. Two roster addons now send: MultiMeters (meter exports to a chosen channel, `modules/Export.lua`) and Ka0s Drop Watcher (asks, offers and announces, `modules/Asks.lua`). Each wrote its own rules down, and they agree; Drop Watcher records the gap as a `(no rule yet)` row in its `## Documented deviations`.

## Where

- The standard: events-frames-taint, after §5 (or a new section if the rule grows).
- Evidence: `DropWatcher modules/Asks.lua` and design spec §9 (`docs/superpowers/specs/2026-10-10-drop-watcher-v1-design.md`); `MultiMeters modules/Export.lua`, the "RULE ONE — THE FLOOD" and "RULE TWO — THE HARDWARE EVENT" comments and `Export.NeedsHardwareEvent`.

## Proposed change

A new subsection, "Chat sent by an addon", along these lines:

> If your addon sends chat (SendChatMessage) for the player:
> - **MUST** send through one Compat seam that resolves `C_ChatInfo.SendChatMessage`, else the deprecated global (compat), and **MUST** call it inside `pcall`, so a refusal is a reported failure and never a Lua error.
> - **MUST** send only on a player's action: a click, or a timer draining what a click queued. Never unprompted.
> - **MUST NOT** send SAY, YELL or CHANNEL from a timer: since 8.2.5 they need a hardware event (SAY and YELL are exempt inside instances; CHANNEL never is). WHISPER, PARTY, RAID and INSTANCE_CHAT may be sent from a timer.
> - **MUST** keep each message within 255 bytes and refuse, not truncate, a longer one.
> - **MUST** respect the 12.0 chat lockdown (`InChatMessagingLockdown`, the restriction state): queue and say so, or refuse and say so; never drop silently.
> - **SHOULD** pace multi-line sends (about one line a second, ChatThrottleLib's budget as the reference), print one confirmation line per send, and guard against repeating the same message to the same person.
> - **MUST** print instead of sending in test mode (preview-mode).

## Tests

A conformance line in the testing section's shape: the sender stubbed to raise leaves the addon running and the send marked failed; a SAY send from a timer is refused; a 256-byte message is refused; a send under lockdown is queued or refused with a printed reason.

## Found by

Ka0s Drop Watcher's v1 design spec §14, and its 2026-10-11 standards audit (`DropWatcher docs/audits/2026-10-11/02_DEVIATIONS.md`, DRW-02).

**Severity:** `low`, rated by impact (a new rule for the standard). This is not a repo's audit-carried deviation, so the "-> high" row does not apply. Re-rate it if you disagree.

---
*Drafted by DW-63 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), design spec §14.*
````

## I12: Item-1.0: an exact item read (link detail, better link, level and quality), and a loot-line parser

- **Repo:** `tusharsaxena/LibKa0s`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I12 -->
````markdown
## What

Ka0s Drop Watcher showed a real drop wrongly: the owner's *Lustrous Golden Plumage* (item 159617, Mythic+, item level 311, Epic) was listed at item level 19 and Rare, its base item. The client answers a link's level and quality from the data inside that link, and the feed had kept the first link it saw for the drop, which can lack the bonus ids and upgrade modifier the chat line's link carries. The fix (Drop Watcher DW-80) wrote the reusable part as one library-shaped file, `core/ItemRead.lua`, with no Drop Watcher state and the API `LibKa0s-Item-1.0` would take. Three addons read items this way, so the read is proposed for the library, beside its identity primitives (`ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `LoadItem`).

## The candidates

1. **The item read** (`DropWatcher core/ItemRead.lua`):
   - `LinkDetail(link)`: how complete a link is (its bonus ids, its modifiers by type, its context, `complete`, and a `score` that orders two links of one item).
   - `BetterLink(a, b)`: the more complete of two links of one item (a tie keeps the first).
   - `IdentityKey(link)` / `SameItem(a, b)`: an item's identity, its id and bonus ids, so two reports of one item match when their unique id, link level, spec, context or modifiers differ (a bag copy against a chat line).
   - `EffectiveItemLevel(linkOrLocation)`: gear only (a weapon or armor with a slot): the detailed level, else the base one; at a bag location the exact one.
   - `ItemLevelAt(bag, slot)` / `QualityAt(bag, slot)`: `C_Item.GetCurrentItemLevel` / `C_Item.GetItemQuality` on the slot's `ItemLocation`, which are always exact.
   - `QualityOf(link)`: the client's answer for the link, else the link's color (`QualityFromLink`).

   Adopters: **Loot History** (`core/Compat.lua` `GetItemExtras` and `GearItemLevel` read the same detailed-then-base level for weapons and armor), **Bank Ledger** (its item resolution and quality gate) and **Drop Watcher** (its item facts, its feed's link merge and its own drops' bag read). The read takes no position on the uncached question the module's header records (Loot History guesses, Bank Ledger refuses): every reader answers nil when the client has nothing, and the caller decides.
2. **The loot-line parser**, a second candidate: Loot History's `NS.Util.ParseSelfLoot` reads the player's own `CHAT_MSG_LOOT` lines; Drop Watcher's `modules/LootParser.lua` reads every looter's, compiling the `LOOT_ITEM*` GlobalStrings into patterns, rebuilding them when another addon rewrites the globals, and rejecting the upgrade and crafting echoes. One every-looter parser with a self-only filter would serve both. This is I09's item 3, re-raised with the item read because both are what a loot addon needs from `Item-1.0`.

## The ask

- Decide (1). If accepted, ship it additively in `LibKa0s-Item-1.0` (its client calls behind the module's own guards, as LibKa0s-Compat does), and the three adopters move to it on their next re-vendor, each dropping its copy and Drop Watcher its deviation row.
- Decide (2) with I09's item 3, or record it as "not yet" with its re-check trigger.

## Evidence

- `DropWatcher docs/superpowers/specs/2026-10-11-drop-watcher-ui-feedback-design.md` §0 (BUG-1, the comparison with Loot History).
- `DropWatcher tests/test_item_read.lua`: the reproduction with realistic 12.x links per loot source, and the read's own cases.
- `DropWatcher docs/ARCHITECTURE.md`, `## Documented deviations` (the item read's library-stack-§7 row).
- `LootHistory core/Compat.lua` (`GetItemExtras`, `GearItemLevel`), `LootHistory core/Util.lua` (`ParseSelfLoot`).

**Severity:** `low`: a promotion question. The defect itself is fixed in Drop Watcher; nothing is broken while the read stays in-addon.

---
*Drafted by DW-80 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), ui spec §0.*
````

---

## I13: Widgets-1.0: a flat search box and a flat checkbox, in the dropdown's skin

- **Repo:** `tusharsaxena/LibKa0s`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I13 -->
````markdown
## What

`LibKa0s-Widgets-1.0` gives every Ka0s window its flat dropdown (`W.Dropdown`: a `BackdropTemplate` button, a 1px `WHITE8X8` line, fill `0.1, 0.1, 0.12, 0.9`, line `0.24, 0.24, 0.27, 0.9`, 20px tall). The controls that sit beside it on a filter bar are still hand-built per addon, so each addon re-derives the same skin, or reaches for Blizzard's `InputBoxTemplate` and `UICheckButtonTemplate`, whose rounded art does not match the dropdown next to them.

Ka0s Drop Watcher's owner put its window beside Ka0s Loot History's and saw exactly that: a rounder search box and checkbox (Drop Watcher ui spec §2, FB-5). Drop Watcher DW-82 fixed it by hand-building both the way Loot History builds its search box.

## The candidates

1. **`W.SearchBox(parent, width, opts)`**: an `EditBox` on `BackdropTemplate` in the dropdown's skin, `GameFontHighlightSmall`, 6px text insets, a `GameFontDisableSmall` hint that hides while there is text, Escape and Enter clearing focus, and the line lit gold while focused. It composes with `W.Autocomplete`, which already hooks such a box.
2. **`W.Checkbox(parent, label, opts)`**: a 14px square `CheckButton` in the same skin, the host's tick mark (the `check` path the dropdown already takes, so menus and boxes wear one tick) tinted gold, a `GameFontHighlightSmall` label whose width joins the click target, and the line lit gold on hover.

Copies today: **Loot History** `modules/BrowserFilterBar.lua` (its search box, and the same skin on `makeBarButton`), **Drop Watcher** `modules/WindowFilterBar.lua` (`buildSearch`, `buildCheck`, `flatSkin`). Related: LibKa0s#48, the test-mode strip as a shared widget.

## The ask

Decide whether both join `Widgets-1.0` (additively, the skin values shared with `W.Dropdown`). If accepted, Loot History and Drop Watcher drop their copies on their next re-vendor.

## Evidence

- `DropWatcher docs/superpowers/specs/2026-10-11-drop-watcher-ui-feedback-design.md` §2 (FB-5) and the side-by-side screenshot `docs/superpowers/research/2026-10-11-ui-feedback/04-beside-loot-history.png`.
- `DropWatcher tests/test_window_shell.lua`: the flat-skin cases for the search box, the checkbox and the dropdowns.

**Severity:** `low`: a promotion question; both windows look right today.

---
*Drafted by DW-82 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), ui spec §2.*
````

---

## I14: Perf-1.0: generalize PerfPanel into a shared step panel

- **Repo:** `tusharsaxena/LibKa0s`
- **Labels:** `state:triaged`, `severity:low`, `enhancement`

<!-- body:I14 -->
````markdown
## What

`LibKa0s-Perf-1.0`'s `PerfPanel.lua` is the collection's clickable step panel: a small titled window, three columns per row (a status dot, the step, its typed slash command right-aligned and dimmer), per-state colors shared by the text and the dot (`done` and `used` green, `ready` bright, `busy` gold, `locked` gray, `cancel` muted red), Core's skin and close mark, Escape to close. It is attached to the Perf probe and drives only the perf run's six fixed steps (`STEPS`, read from `Progress()`), so no other workflow can use it.

Ka0s Drop Watcher's owner asked for exactly that panel for the simulator (Drop Watcher sim feedback spec §1): the scenario's timeline as clickable steps. Drop Watcher DW-91 had to copy its geometry, columns and colors into `modules/SimPanel.lua`, because PerfPanel takes no host step list.

## The candidates

A `StepPanel` widget (in Widgets-1.0, or a small major of its own) that PerfPanel would itself be built on:

1. **`StepPanel.New(descriptor)`**: `{ name, addonName, title, steps = function() -> { { key, label, command, state, tip } } , onClick(key), footer = function(frame) }`. The host owns the step list and the states (a varying number of rows, re-read on every `Refresh`); the panel owns the frame, the three columns, the colors, the hover tint, Escape and the close mark.
2. **The states** as today's palette, plus a check texture on a completed row (Drop Watcher shows the catalog's `confirm` tick over the dot; PerfPanel's note about the text tick rendering as tofu applies).
3. **A footer slot** for host controls (Drop Watcher's Run all, Pause / Resume, Restart and Stop, and its scenario picker), and the panel's height following the row count.
4. **`Refresh()`** idempotent and cheap, so a host repaints on every transition, and the headless record PerfPanel already keeps (`__label`, `__state`, `__command`) on every row.

## The ask

Decide whether a shared step panel belongs in LibKa0s. If accepted, Perf's panel is rebuilt on it (its look unchanged) and Drop Watcher drops `modules/SimPanel.lua`'s frame code on its next re-vendor, keeping only its pure `Compose` (the rows) and its controls.

## Evidence

- `LibKa0s/PerfPanel.lua` (minor 6): `STEPS` is a file-local constant and `__AttachPanel` reads `P.Progress()`.
- `DropWatcher modules/SimPanel.lua` (DW-91): the copy, and `docs/ARCHITECTURE.md` → Documented deviations, the row that names this issue as its re-check trigger.
- `DropWatcher docs/superpowers/specs/2026-10-11-drop-watcher-sim-feedback-design.md` §1 and `docs/superpowers/research/2026-10-11-sim-feedback/01-perf-run-panel.png`.

**Severity:** `low`: a promotion question; both panels work today.

---
*Drafted by DW-91 of the Drop Watcher v1 plan (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/`), sim feedback spec §1.*
````

---

## Filing snippet (the owner runs it, once the hold lifts)

Run from the DropWatcher repo root with an authenticated `gh`. It creates the eight `state:`/`severity:`
labels on `tusharsaxena/DropWatcher` (`--force` is idempotent, two seconds apart), then files the fourteen
issues 25 seconds apart, reading each body from this file. It strips the working tree's CRLF from the
bodies. Each URL is printed; note the numbers for the "After filing" step above. To file only some,
delete lines from the `ISSUES` list.

```bash
#!/usr/bin/env bash
set -euo pipefail
DOC=docs/superpowers/plans/2026-10-10-drop-watcher-v1/issues-to-file.md
DW=tusharsaxena/DropWatcher LK=tusharsaxena/LibKa0s WAS=tusharsaxena/WowAddonStandards

# The collection's eight labels, on the one repo that lacks them.
while IFS='|' read -r name color desc; do
  gh label create "$name" -R "$DW" --color "$color" --description "$desc" --force
  sleep 2
done <<'EOF'
state:untriaged|ff0000|Seen and recorded; nobody has been asked yet
state:triaged|ffff00|Decided: not now. Still on the books
state:done|00ff00|Implemented. Terminal
state:will-not-do|0000ff|Will never be done. Terminal
severity:critical|110000|Taint, lockdown, data loss, common-path error
severity:high|110800|User-visible defect, or a standard deviation
severity:medium|111100|Maintainability: stub, drift, dead path
severity:low|001100|Polish, naming, cosmetic, speculative
EOF

# The body between "<!-- body:ID -->" and the closing four-backtick fence.
body() {
  awk -v id="<!-- body:$1 -->" '
    { sub(/\r$/, "") }
    $0 == id { grab = 1; skip = 1; next }
    grab && skip { skip = 0; next }
    grab && /^````$/ { exit }
    grab { print }' "$DOC"
}

ISSUES=(
  "I01|$DW|Wishlist with tiers (BiS, Need, Nice, Mog) and a groupmate-looted alert"
  "I02|$DW|Tier-set and catalyst flags, and a verdict for tier tokens"
  "I03|$DW|Void Core and bonus-roll awareness"
  "I04|$DW|Addon comms between Drop Watcher users"
  "I05|$DW|Read-only interop with the PLH and PLR loot protocols"
  "I06|$DW|Droptimizer or SimC import for a \"% DPS\" column"
  "I07|$DW|Loot-spec nudge on entering an instance"
  "I08|$DW|Record received trades in Ka0s Loot History as \"Traded from X\""
  "I09|$LK|Promotion candidates from Drop Watcher: chat sender, tooltip line reader, loot-line parser, restriction tracker"
  "I10|$LK|Options: a grid composer for rows of mixed controls"
  "I11|$WAS|Proposal: a rule for chat an addon sends on the player's behalf"
  "I12|$LK|Item-1.0: an exact item read (link detail, better link, level and quality), and a loot-line parser"
  "I13|$LK|Widgets-1.0: a flat search box and a flat checkbox, in the dropdown's skin"
  "I14|$LK|Perf-1.0: generalize PerfPanel into a shared step panel"
)

first=1
for row in "${ISSUES[@]}"; do
  IFS='|' read -r id repo title <<<"$row"
  [ "$first" = 1 ] || sleep 25          # >= 20s between GitHub writes (plan rule DW-63)
  first=0
  text=$(body "$id")
  [ -n "$text" ] || { echo "no body for $id" >&2; exit 1; }
  echo "$id -> $repo"
  gh issue create -R "$repo" --title "$title" \
    --label "state:triaged" --label "severity:low" --label "enhancement" \
    --body "$text"
done
```

I04's and I05's bodies name each other by draft id ("the I04 issue"). After filing, edit I05's body to
name I04's real number if wanted (one more write, spaced like the rest).
