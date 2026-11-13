# Midnight quirks — Ka0s Drop Watcher

The first part of this file is the collection's client-quirks catalog, vendored whole from the Ka0s WoW Addon Standard (client-quirks-§1) and replaced wholesale by `/dev-copilot:wow-revendor-standards`; never edit inside its markers. A correction belongs in this addon's own section, which follows it.

<!-- BEGIN VENDORED: quirks catalog v2.103.1 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into every addon's `docs/midnight-quirks.md` (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Client quirks

The client behaviors the collection paid for more than once. Each entry here was discovered
**independently in two or more Ka0s repositories**, written up in each, and promoted by a harvest so the
next addon reads it instead of rediscovering it. A behavior one repo found stays in that repo's
`docs/midnight-quirks.md` until a second repo meets it.

*Why this section exists.* By 2026-11-06 eleven addons kept a private `docs/midnight-quirks.md`, 2,073
lines and about 133 entries between them, and about 81 of those entries were 21 behaviors written up
independently two to eight times. Nine of the eleven opened with their own restatement of the 12.0 secret
rules. Three write-ups contradicted this standard, and one contradiction was this standard's own error
(events-frames-taint-§2, *The combat-start edge*). A catalog was proposed and deferred twice, on
2026-08-25 and 2026-09-22, because an inventory rots; the build stamp per entry (§1) is the answer to that
objection (WowAddonStandards `harvests/2026-11-06/02_FINDINGS.md`, F3-01; every write-up quoted in
`harvests/2026-11-06/03_EVIDENCE.md`, Part A).

### 1. How an entry is written, and how it expires (MUST)

Every entry **MUST** carry:

- **The behavior**, stated as what the client does, not as advice.
- **Measured:** the client build or date it was observed on, where any write-up recorded one. An entry with
  no measurement says *not measured*; that is a weaker entry, not a missing field.
- **Cost:** what happened to an addon that did not know it.
- **Client:** the client it was measured on, `Retail` or `Forever` (clients-§1). An entry that names none is a Retail entry, which is every entry written before v2.103.0; a Forever behavior is written with `Forever` and its build, and it is not assumed to hold on Retail.
- **Do:** the workaround, as a rule an addon can follow.
- **Source:** the deepest write-up — the repo and document that probed furthest — and the harvest that
  promoted it. Every version is quoted in that harvest's `03_EVIDENCE.md`.

**Expiry.** An entry describes a client, and clients move. When the retail interface number moves past the
newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a standard
release — not worked around in the addon. An entry nobody can reproduce moves to §6 as an open probe rather
than being deleted, because the behavior may only have moved.

**What an addon does with this section (MUST): carry it as a vendored block.** This section is the one
part of the standard an addon carries a **copy** of, because it is reference data about the game client
that a working addon needs offline, next to the code that works around it — not a rule, which is only ever
pointed at. Every addon's `docs/midnight-quirks.md` (documentation-§3) is two parts: the vendored block,
opened by a `BEGIN VENDORED` HTML comment naming the catalog's version and source and closed by an
`END VENDORED` HTML comment, each spelled exactly as `/dev-copilot:wow-revendor-standards` writes it; then
the addon's own section. The markers are described here rather than shown, because this text travels
inside them: a literal marker in the vendored copy would give the file a second end marker for the next
re-vendor to cut at.

```markdown
[the BEGIN VENDORED comment, stamped quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own quirks: one no second repo has met, its per-event costs, its own probe tables …
```

- The block is **copied whole and replaced wholesale** by `/dev-copilot:wow-revendor-standards`, stamped with
  the standard version it came from, under the same discipline as `libs/LibKa0s/` (anti-pattern #45): never
  a subset, **never edited inside the markers**. A local edit inside them is reverted by the next revendor,
  and the behavior it fixed comes back with no cause in the addon's history; a correction belongs in the
  addon's own section, where the next harvest finds it.
- The addon's own section **MUST NOT** restate a behavior the block carries. When a harvest promotes an
  entry, the revendor prunes the addon's copy: the upstream entry is the deeper write-up, and two live
  copies of one finding is the shape that drifted three times into contradiction.
- An addon with no quirks of its own still carries the block, with an empty own section.

**Contested behaviors are not rules.** Where two repos recorded opposite behavior and nobody has probed
the difference, the entry goes in §6 with both sides and the probe that would settle it.

Behaviors this standard already states elsewhere are not repeated here: the unknown-event raise
(events-frames-taint-§1), `Settings.OpenToCategory`'s numeric ID and collapsed parent (options-ui-§2),
the protected category switch in combat (options-ui-§2, anti-pattern #88), a secret through `tostring` and
`..` (events-frames-taint-§8), lockdown at `PLAYER_REGEN_DISABLED` (events-frames-taint-§2), the spec
readers' move to `C_SpecializationInfo` (compat, `LibKa0s-Compat-1.0`) and `SendChatMessage`'s move to
`C_ChatInfo` (compat).

### 2. Secret values

**A secret boolean cannot be tested at all.** `if`, `not`, `==` and `and`/`or` on a secret boolean raise
("attempt to compare … (a secret boolean value)"); the value is unusable in Lua, not merely unprintable.
`DurationObject`'s `HasExpired`, `HasStarted`, `IsActive` and `IsZero` come back secret in combat, and an
engine button's `IsShown` has answered a secret boolean out of combat. *Measured:* 12.0.7 (probe table);
12.1 (`IsShown`). *Cost:* a raise on every refresh tick of the path that tests it. *Do:* check
`issecretvalue` before any test; route a secret boolean to a C-side consumer
(`C_CurveUtil.EvaluateColorValueFromBoolean`, `SetAlphaFromBoolean`), or treat it as the cautious answer
(a secret lockdown reads as locked, a secret restriction as active, a secret claim as no claim). Two repos
disagree on whether to gate before the C-side call; that disagreement is recorded in `LibKa0s`
`docs/api/Compat` and is not ruled here. *Source:* KickCD `docs/midnight-quirks.md`, "Secret booleans are
unusable"; seven repos (harvest 2026-11-06, Q6).

**A secret cannot be a table key.** Indexing or assigning with a secret key raises "attempted to perform
indexed assignment on a table that cannot be indexed with secret keys". `UnitGUID` on a follower-dungeon
pet (`party3pet`) answers a secret string. *Cost:* a raise on every refresh tick for a roster keyed by
GUID. *Do:* guard a key with `IsSafeKey` (`LibKa0s-Compat-1.0`) or `issecretvalue` before keying; a
secret GUID is never a handle. *Source:* MultiMeters `docs/midnight-quirks.md`, the follower-dungeon pet
GUID; seven repos (Q7).

**A secret never reaches SavedVariables, and one that does is written as `nil`.** A value captured as
secret stays secret after combat ends, and the client writes a secret to SavedVariables as `nil` — or,
where it was a key, loses the entry. *Measured:* a reload probe, 2026-10-25. *Cost:* silent data loss on
the next reload. *Do:* store a plain value or nothing; never store a captured secret to read later.
*Source:* DpsRace `docs/known-limitations.md`, the reload probe; three repos (Q21).

**A frame handed a secret has secret geometry, and so does everything anchored to it.** After
`StatusBar:SetValue(secret)` (or `SetAlphaFromBoolean`, or anchoring to an aura engine container) the
frame `HasSecretValues`: its width, points and frame level read secret, out of combat too, and the
taint runs down the anchor chain to every frame anchored to it; a tooltip showing hidden information has
secret geometry. A secret size's `type` is `"number"`, so a type check lets it through, and
`BackdropTemplate`'s own arithmetic on a secret size raises. *Cost:* a raise inside Blizzard code, or a
layout computed from a secret. *Do:* compute layout from configuration and never read geometry back from a
frame that was handed a value; keep a record of the alpha you set rather than calling `GetAlpha()`; read a
frame level under a restricted anchor through a secret-safe guard (frame-layering). *Source:* AuraMaster
`docs/midnight-quirks.md`, the aura engine container entries (measured and dated); six repos and
`LibKa0s` `docs/api/Widgets` (Q8).

**A restricted spell's cooldown: branch on `isActive`, paint with the duration object.** In a restricted
state `C_Spell.GetSpellCooldown`'s timings are secret while `isEnabled` and `isActive` stay plain
(documented NeverSecret). `GetSpellCooldownDuration` answers a **zeroed** object, not `nil`, when there is
no cooldown, and a fresh object per call. *Cost:* raw `SetCooldown` with a secret start or duration raises;
a nil check passes the zeroed object. *Do:* decide from `isActive`; paint with
`Cooldown:SetCooldownFromDurationObject`, which accepts the object from tainted code. *Source:* KickCD
`docs/midnight-quirks.md`, the cooldown probe table; four repos (Q9).

**`notInterruptible` is secret, and the interruptibility events make it plain.** The cast info's
`notInterruptible` is secret; `UNIT_SPELLCAST_INTERRUPTIBLE` / `_NOT_INTERRUPTIBLE` deliver it plain.
`CastingBarFrameTemplate`'s built-in `OnUpdate` compares `GetTime()` with a secret `maxValue` and raises
when the bar shows another unit. *Do:* split the gate — the color path takes the secret C-side, the logic
path takes the event's plain value; do not inherit `CastingBarFrameTemplate` for a unit other than the
player. *Source:* KickCD `docs/midnight-quirks.md`, "split the gate in two"; two repos (Q13).

**`InChatMessagingLockdown` can answer a secret.** *Do:* read it through a guard and treat a secret as
locked. *Source:* DropWatcher and QuickComms `core/Compat.lua` (byte-identical), DpsRace; three repos (Q27).

### 3. Events

**A valid event can register without complaint and never fire.** `GUILDBANKFRAME_OPENED` registers and
never fires (*Measured:* 12.0.7); `UNIT_SPELLCAST_SUCCEEDED` is suppressed for protected interrupts;
`UNIT_HEALTH` and `UNIT_NAME_UPDATE` never fire for compound tokens such as `party1target`;
`GET_ITEM_INFO_RECEIVED` does not fire for an item already cached. This is the inverse of the
unknown-event raise (events-frames-taint-§1) and it is silent: nothing errors. *Cost:* a feature that
never runs, with nothing in the log. *Do:* confirm a new event fires in game before building on it, and
prefer an edge with a second source (a frame's `OnShow`, a gated timer) where the event is known to be
silent. *Source:* BankLedger `docs/midnight-quirks.md`, `GUILDBANKFRAME_OPENED`; four repos (Q20).

**Client state can lag its own event, or change with no event at all.** `IsMounted()` has flipped by the
time `PLAYER_MOUNT_DISPLAY_CHANGED` arrives while `C_PlayerInfo.GetGlidingInfo`'s `canGlide` sometimes has
not; after `INSPECT_READY` some slots still answer an item id with no link; switching bank tabs fires no
event, and the live warband tab has taken over a second to catch up; chat lockdown clears with no event.
*Cost:* a read at the edge answers the old state, and the display stays wrong until the next unrelated
event. *Do:* answer at the edge **and once more after a short settle** (a fraction of a second, a bounded
retry), never a poll. *Source:* MultiMeters `docs/midnight-quirks.md`, "some client state lags its own
event"; six repos (Q19).

**An empowered cast fires `UNIT_SPELLCAST_EMPOWER_*`, not the channel events.** `UnitChannelInfo`
reports it, but `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` do not fire for it, and its release fires
`UNIT_SPELLCAST_SUCCEEDED` with the same cast GUID. *Do:* register the `EMPOWER_*` events wherever channels
are tracked. *Source:* KickCD `docs/midnight-quirks.md`, empowered casts; three repos (Q12).

**`ADDON_RESTRICTION_STATE_CHANGED` fires *before* enforcement.** The `Activating` state arrives before the
restriction begins, and access is still permitted during that dispatch; a dungeon restriction type has
gone active on entry and not cleared. Read the restriction type by its `Enum.AddOnRestrictionType` member
name — a member can be missing on some builds. *Measured:* 12.1.0, 2026-09-18. *Do:* treat `Activating`
as the last moment to read, not as the start of the restriction. The payload's second argument is
contested (§6). *Source:* AuraMaster `docs/midnight-quirks.md`, the restriction types; six repos (Q10).

### 4. Combat and secure frames

**Blizzard's aura buttons are forbidden to addon code, and `IsForbidden()` can say otherwise.** In
combat every call on a Blizzard aura button's objects raises "Attempt to access forbidden object from code
tainted by an AddOn"; in an instance (seen in Mythic+) the same buttons answer `IsForbidden()` `false` and
still refuse every read, `GetChildren` included. *Do:* never read Blizzard aura buttons; where a frame
must be inspected, `pcall` the read and treat a failure as forbidden. *Source:* PartyFrameEnhanced
`docs/midnight-quirks.md`, forbidden aura buttons; three repos (Q14).

**Escape runs a protected `Hide()` in combat.** A secure or protected frame listed in `UISpecialFrames` is
hidden by `CloseSpecialWindows`, which is a protected action in combat. *Do:* list a non-secure proxy in
`UISpecialFrames` and hide the protected frame from it out of combat, or keep protected frames out of the
list. *Source:* WhatGroup `docs/midnight-quirks.md`, the escape proxy; two repos (Q24).

### 5. Item, tooltip, enum and realm data

**Item data is nil until cached, and the load event has holes.** `GetItemInfo` answers nothing for an
uncached item; `GET_ITEM_INFO_RECEIVED` does not fire on an addon's first scan for an item the client
already holds; an uncached item's tooltip is not empty but a legible `RETRIEVING_ITEM_INFO` line; a failed
load drops its wait and nothing asks again. *Cost:* a blank or wrong row that never repairs. *Do:* load
through `LibKa0s-Item-1.0`'s cache-then-callback path (library-stack-§7), treat `RETRIEVING_ITEM_INFO` as
not-yet-loaded, and re-ask after a failed load. *Source:* ConsumableMaster `docs/midnight-quirks.md`, the
first-scan hole; seven repos (Q15).

**`C_TooltipInfo` returns raw templates.** Tooltip lines can carry the unexpanded plural grammar
`|4singular:plural;` (*Measured:* 12.1.5, "for the next 3 |4hour:hrs; 49 min") and a no-break space that
Lua's `%s` does not match. *Cost:* a parser that knew only the expanded words read no duration and called a
tradeable drop expired. *Do:* expand `|4…;` before matching, and match the no-break space explicitly.
*Source:* DropWatcher `docs/midnight-quirks.md`, the trade window; two repos (Q16).

**Tooltip line text can be secret** under an addon restriction, including through `TooltipDataProcessor`.
*Do:* guard each line before matching. *Source:* DropWatcher `docs/midnight-quirks.md`; two repos (Q17).

**Blizzard renumbers enums; resolve a member by name, never by number.** One build's
`Enum.TooltipDataLineType` and bank-tab values are not the next build's, and a member can be absent on a
build. *Cost:* a numeric guess for a member the build does not expose landed on an unrelated bank
container. *Do:* read `Enum.X.Member`, and handle its absence; localization-§4 already forbids the string
spelling. *Source:* DropWatcher `docs/midnight-quirks.md`, the research's enum values; five repos (Q18).

**`GetNormalizedRealmName` is nil early in login.** *Cost:* a stored `Name-` key with no realm. *Do:* never
build a `Name-Realm` key before the realm is known; defer, or fall back to `GetRealmName` with its spaces
and hyphens removed. *Source:* DropWatcher `docs/midnight-quirks.md`, realm names; four repos (Q25).

**A template-less `FontString` with no font raises on `SetText`.** "Font not set" from a `FontString`
created without a template or `SetFontObject` takes the addon down at load; a mock that does not enforce it
passes every test. *Do:* give every bare `FontString` a font object before its first `SetText`; the kit's
mock enforces it. *Source:* MultiMeters `tests/mock_frame.lua`, the font-not-set guard; three repos and
`LibKa0s` (Q22).

### 6. Open probes — contested behaviors (not rules)

Each needs an in-game probe, recorded with the build, before any section of this standard changes.

- **WoW Forever behaviors (none recorded yet).** The catalog was written on Retail. The Forever client (build 70790) has a missing-API surface, `SetDesaturation` among it, that LibKa0s tracks in LibKa0s#44, and no quirk entry yet meets this section's two-repo bar for it. Record a Forever behavior in the repo that meets it, with the build, and promote it by a harvest like any other.

- **`string.format` on a secret.** events-frames-taint-§8 says it raises, with three repos; two say it
  works, one with a mid-combat observation. The likely difference is the specifier (`%s` against `%d` and
  `%.1f`) or that the result is itself a secret string. Probe each specifier, in combat, on a damage-meter
  value and a `UnitHealth` value. Until then §8's rule stands.
- **`ADDON_RESTRICTION_STATE_CHANGED`'s second argument.** One repo documents an
  `Enum.AddOnRestrictionState` value; three (one measured) record a boolean as well. Handle both shapes.
  The 2026-09-22 harvest called this settled, and it is not.
- **`SetAllPoints(parent)` on a secure button at load.** One repo records "Cannot anchor protected frames
  to regions" and uses the implicit-parent form; another anchors its secure rows with `SetAllPoints(row)`
  at birth and treats it as working, with its in-game smoke check still owed.
<!-- END VENDORED -->

## DropWatcher-specific quirks

The client-version workarounds this addon carries of its own (documentation-§3, Tier 2). Each one's
client read lives in `core/Compat.lua` ([`compat-layer.md`](compat-layer.md)) and is pinned by
`test_compat`; where a module carries the rest of the workaround the row names it, pinned by that
module's suite (the loot line's in `modules/LootParser.lua`, `test_loot_parser`; the tooltip
width's in `modules/TipGrid.lua`, `test_tip_marks`).
What is still unconfirmed in game is owed as a `COMPAT-*` check in
[`smoke-tests.md`](smoke-tests.md).

| Quirk | What the client does | What the addon does |
|---|---|---|
| Secret values (12.0) | During an encounter, a keystone or a PvP match, many payloads arrive as secret values that tainted code may store and pass but not compare, match or concatenate. | Every possibly-secret value meets `IsSecret` first: a secret tooltip line is skipped, a secret upgrade table is ignored, a secret bind answer reads as not bound. The guards come from `LibKa0s-Compat-1.0`, with the one-rung bodies re-implemented when the library is absent. |
| A secret font-string width on GameTooltip | In combat a font string parented to GameTooltip may answer `GetUnboundedStringWidth` (and the tooltip `NumLines`) as a secret number, whose `type` is `number`, so a type check alone lets it through. | `modules/TipGrid.lua` checks `IsSecret` before each read: a secret width falls back to the per-character estimate and a secret line count to the reserved rows' own count (feedback-14 spec §0). |
| A secret answer to a yes/no gate | A secret boolean cannot be tested at all. | The cautious answer: a secret chat lockdown reads as locked and a secret restriction state as active, so a send is queued rather than attempted. |
| The item globals moved to `C_Item` | `GetItemInfo`, `GetDetailedItemLevelInfo`, `GetItemStats`, `GetItemSpecInfo` and `GetItemUniqueness` are deprecated globals with `C_Item` spellings (`GetItemUniquenessByID` answers `(isUnique, name, count, categoryID)` where the global answered `(family, max)`). `GetItemInfo` answers nothing until the item is cached. | Each item reader calls the `C_Item` spelling only: every client at this TOC's interface has it, so the global was a dead rung and is deleted (compat). Uniqueness reads `GetItemUniquenessByID`'s shape. An uncached item reads as nil, and `modules/ItemFacts.lua` loads it through LibKa0s-Item-1.0's `LoadItem`, retrying on its callback. |
| Item stats and specs answer for the character playing | `C_Item.GetItemStats` answers the primary stat of the spec you play alone: a cloak carrying Strength, Agility and Intellect reads Intellect alone on a Restoration druid and Agility alone on a Beast Mastery hunter, whatever spec the link carries. `C_Item.GetItemSpecInfo` lists the specs of your own class alone (the same cloak on a druid: 102 to 105). The hyperlink tooltip lists every primary stat, the inactive ones grayed. Confirmed in game on 2026-10-15. | `Compat.ItemPrimaryStats` reads every primary stat off the tooltip and `modules/ItemFacts.lua` adds them to the stats; the spec list carries the class it was read on (`specsClass`), and `modules/Evaluate.lua` holds only that class to it (smoke ITEM-5). |
| `SendChatMessage` deprecated (11.2.0) | The bare global moved to `C_ChatInfo.SendChatMessage`, with the same arguments. | `ChatSender()` takes the namespaced one first and the global second. |
| `PickupContainerItem` moved (10.0) | The bag functions moved to `C_Container`. | `BagSlotCount` and `BagItemLink` call the `C_Container` spelling only; the bare globals were removed in 10.0.2, so no rung is kept for them. |
| The spec readers moving to `C_SpecializationInfo` | `GetSpecialization` and `GetSpecializationInfo` have `C_SpecializationInfo` spellings, and the global is deprecated. | `PlayerSpecID` reads both through LibKa0s-Compat-1.0, which takes the namespaced spelling first; no rung is written here. |
| Restriction state `Activating` | `ADDON_RESTRICTION_STATE_CHANGED` fires just before a restriction starts, with the state `Activating`. | Anything but `Inactive` counts as active, so the addon stops sending before the lockdown bites. |
| The restriction event's payload | `ADDON_RESTRICTION_STATE_CHANGED` has been seen carrying `(type, active)` with a boolean, as well as the numeric state. The Combat type follows the `PLAYER_REGEN` edges; Encounter and Chat go active at `ENCOUNTER_START` and clear at `ENCOUNTER_END`; Map goes active on entering a dungeon and stays so. | `IsRestrictionStateActive` takes either shape. The tracker (`modules/Restrictions.lua`) lets the Map type block nothing, and counts a type as active while the event or the client says so. |
| Realm spelling | `GetNormalizedRealmName` answers nil early in the login; chat and `UnitName` spell a realm with its spaces and hyphens dropped (`Area52`, `AzjolNerub`), while `GetRealmName` keeps them. A member whose data has not arrived is named `Unknown` (`UNKNOWNOBJECT`). | `NormalizedRealm()` falls back to `GetRealmName` with spaces and hyphens dropped. The roster normalizes both sides of every realm comparison the same way, counts `Unknown` as no name, and re-reads the group once when a name does not resolve. ROSTER-1 confirms the spelling. |
| Enum numbers move | Blizzard renumbers enums between patches; the research's `TradeTimeRemaining = 36` and `ItemUpgradeLevel = 32` are one build's values. | Every enum member is resolved by name at call time. When no line of the wanted type parses (the client lacks the type, or tagged the line with another one), every line is offered to the localized-text parser. |
| Inspected links carry the unscaled item level | An item link read off an inspected player shows the base level, not the scaled one. | `InventoryItemLevel` reads the tooltip's `ItemLevel` line for the inspected unit (spec §8). |
| Inspect data arrives in pieces | After `INSPECT_READY` some slots can still answer an item id with no link, or a nameless link, and the inspect's arrival can itself raise `UNIT_INVENTORY_CHANGED`. The inspect gates (`CanInspect`, `CheckInteractDistance`) may answer secret. | The broker reads 0.15s after the event and retries incomplete slots three times, 0.3s apart; it ignores an inventory change within five seconds of its read. A read with no item at all (the data cleared before it ran) is never stored. A secret gate answer reads as "not now" (no inspect, out of range). INSPECT-2 and INSPECT-3 confirm both in game. |
| No upgrade-track API on some builds | `C_Item.GetItemUpgradeInfo` is in the 12.1.0 docs; whether it answers for another player's drop link is unconfirmed. | Falls back to the hyperlink tooltip's `ItemUpgradeLevel` line, read with the localized `ITEM_UPGRADE_TOOLTIP_FORMAT_STRING`. English is never parsed. |
| The trade timer is text | The remaining trade time exists only as a tooltip sentence on your own bag item. | The `TradeTimeRemaining` line (or the `BIND_TRADE_TIME_REMAINING` sentence) is decoded with the client's own duration globals, so it reads in every client language ([`compat-layer.md`](compat-layer.md#the-duration-decoder)). |
| The trade line's grammar is left raw (12.1.5) | The bag item's `TradeTimeRemaining` line carries its hour term unexpanded (`for the next 3 \|4hour:hrs; 49 min (including time offline).`, captured in game 2026-10-16), so a decoder that knew only `hour` and `hrs` read no window and called the drop expired. | The decoder takes each grammar template itself as one more spelling beside its expansions. |
| Loot lines are localized text that other addons rewrite | `CHAT_MSG_LOOT` carries a sentence built from the `LOOT_ITEM*` GlobalStrings in the client's language. Chat addons (PrettyChat) rewrite those globals at runtime. Mid-encounter the line may arrive secret (COMBAT-1). | The parser builds its patterns from the live globals, and rebuilds them on the next line whenever any of them is no longer the exact string it was built from. A positional string (`%2$s`) is read in its own order. A secret line is counted and dropped before it meets a pattern. PrettyChat's defaults spell `LOOT_ITEM_PUSHED*` exactly as `LOOT_ITEM*`, so no line can say which it is: a pushed, bonus or rejected string spelled as a loot one is left out of the set and the line reads as loot (found 2026-10-23, when every loot line read as pushed and your own drops were refused). |
| The other loot sources | `ENCOUNTER_LOOT_RECEIVED` names the looter as a bare name or a Name-Realm with a classFile, and no GUID; `C_LootHistory` answers a drop before anyone has won it (rolls still open) and again on each roll. Mid-encounter any payload may arrive secret. The same drop also arrives as a chat line. | The feed guards every payload with `IsSecret` before it is compared or used as a key (a secret link or name drops the report; a secret encounter id groups by context instead), resolves the name through the roster, takes a loot history drop only once it has a winner and only once, and merges the reports of one drop. Whether the M+ chest's report names an encounter is FEED-6. |
| The trade range read in combat | `CheckInteractDistance` is not to be called by addon code in combat, and its answer may be secret. | The trade helper checks combat (`NS.Restrictions.CanTrade()`) first and reads `InTradeRange` (index 2, the trade distance) only out of combat; a secret answer is out of range. TRADE-6 confirms it in game. |
| Pawn's readiness | Pawn answers nil until it has initialized and until an item is cached. | Every Pawn call waits on Pawn's `PawnIsReady()`, runs under `pcall`, and a nil answer means "not ready yet". |

### WoW Forever

Client: **Forever**, measured on build 1.60.1 (70790), interface 16001 (the Forever port's research,
`docs/superpowers/research/2026-11-13-forever-port/`, R2 and R4). None is assumed to hold on Retail,
and none has met a second repo yet, so each stays here (client-quirks-§1). Each client read lives in
`core/Compat*.lua` and is picked once by `NS.Compat.ClientKey()` (clients-§3).

| Quirk | What the client does | What the addon does |
|---|---|---|
| The spec is the class | Every class has one class-wide spec, named for the class: a Hunter's spec reads `1485`, "Hunter", for you and for an inspected unit alike. The classic talent trees are what Retail's specs were, and a talent change fires `TRAIT_CONFIG_UPDATED` and `CHARACTER_POINTS_CHANGED`, not `PLAYER_SPECIALIZATION_CHANGED`. A lookup keyed by Retail's spec ids finds no row, so the class tables and Pawn's scale index answered nil. | Forever's class data is its own list (`core/ClassDataForever.lua`), keyed `"<classFile>:<tree>"`; your top talent tree comes from LibKa0s-Role-1.0's groups (`NS.Compat.PlayerTalentTree`, nil on a tie or no points), and the two talent events re-read it (DW-FP05). |
| Pawn has no specs | Pawn 2.14.1 on Forever has no specs (`SpecsExist` false), so its Automatic mode is off, and one Classic scale per talent tree (`HUNTER1` to `HUNTER3`; the Druid's Feral 2 for damage and 3 for tanking, Restoration 4), every one of your class's shown at first login. Its upgrade test answers across all the shown scales, so it picks the tree that gains most, not the one you play. | You are scored with your visible custom scale, else your top tree's Classic scale, else the best of your class's; a looter with the best of their class's (`NS.Compat.PawnClassScales`, `modules/Scoring.lua`, DW-FP07). |
| The ranged slot | Slot 18 (`INVSLOT_RANGED`) is a slot of its own: bows, guns, crossbows, wands, thrown weapons and relics equip there, and the paper doll shows it. Retail's plan, where a bow fills both hands and a relic is not gear, compared them against the wrong items. | Forever's slot plan sends `INVTYPE_RANGED`, `INVTYPE_RANGEDRIGHT`, `INVTYPE_THROWN` and `INVTYPE_RELIC` to `C.SLOT.RANGED`, and the gear snapshot and the inspect read slot 18 (`core/Constants.lua`, DW-FP06). |
| `lootListKey` | `C_LootHistory`'s drop key is named `lootListKey` on Forever, as `GetSortedInfoForDrop`'s second parameter, `LOOT_HISTORY_UPDATE_DROP`'s second argument and the `EncounterLootDropInfo` field, where Retail names it `lootListID` (measured in the 1.60.1 interface files, not yet in game). A reader of the field by Retail's name gets nil. | The feed takes the key from the event's positional argument and never reads the field by name (`LootFeed.OnLootHistoryDrop`, `NS.Compat.LootHistoryDrop`); a reader of the field reads `lootListID or lootListKey`. |
