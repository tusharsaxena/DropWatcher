# Forever probes — Ka0s Drop Watcher

The in-game reads the Forever port's design leaves open (design spec §12, research notes R1 §10, R2
§13 and R4 §17 in [`superpowers/research/2026-11-13-forever-port/`](superpowers/research/2026-11-13-forever-port/)),
de-duplicated into one sheet. Each probe is a line to type and what to read. Run them on the WoW
Forever client unless a probe says Retail too, and record the answer on its `Result:` line with the
date and the client build. The checks that lean on a probe ([`smoke-tests.md`](smoke-tests.md),
the ROLLS and FOREVER themes) name it. These are the owner's to run; an agent never fills a result.

Where the code already reads a probe's answer one way, the probe says what it assumes, so a different
answer is a finding, not a surprise.

## The loot method

**P-LM1. Which loot methods a group offers.** In a party, a raid and a dungeon:
`/dump C_PartyInfo.GetAvailableLootMethods()`. Read which of 0 to 5 appear; personal loot (5) is
expected absent on Forever. (R1 #1) Result:

**P-LM2. The loot method style.** On Forever and on Retail: `/dump C_PartyInfo.GetLootMethodStyle()`.
Read 0 (Mainline) or 1 (Vanilla). (R1 #2) Result:

**P-LM3. The default method, and the master looter's index.** Right after joining a fresh party, on
entering a dungeon and on entering a raid: `/dump C_PartyInfo.GetLootMethod()`. Under master loot also
read the second and third returns and compare them with `/dump GetRaidRosterInfo(1)`'s eleventh. The
code reads the master looter from those returns (`Compat.LootMethod`). (R1 #3, R4 #14) Result:

**P-LC. The loot threshold.** `/dump GetLootThreshold(), Constants.LootConsts, Constants.LootConsts_Camelot`.
Master-loot pending holds at `GetLootThreshold()` (rolls UX RX-03): confirm it answers the group's
threshold as the party frame's Loot Threshold menu shows it, and that it moves when the leader changes
it. The constants' `MasterLootQualityThreshold` only gates Blizzard's distribution-confirm popup; read
which table exists for the record. (R1 #4) Result:

## Rolls

**P-ROLLINFO. Your own roll's flags.** During an open roll:
`/run for _,id in ipairs(GetActiveLootRollIDs()) do print(id, GetLootRollItemLink(id), select(5, GetLootRollItemInfo(id)), select(6, GetLootRollItemInfo(id)), select(7, GetLootRollItemInfo(id)), select(8, GetLootRollItemInfo(id)), select(13, GetLootRollItemInfo(id))) end`.
Read bindOnPickUp, canNeed, canGreed, canDisenchant and canTransmog; is canTransmog ever true on
Forever? The popup mark's BoP wording reads bindOnPickUp. (R1 #5) Result:

**P-R1. When the numbers appear.** In a group roll, on Forever and Retail:
`/run local f=CreateFrame("Frame") f:RegisterEvent("LOOT_HISTORY_UPDATE_DROP") f:SetScript("OnEvent",function(_,_,e,k) local d=C_LootHistory.GetSortedInfoForDrop(e,k) for _,r in ipairs(d.rollInfos) do print(GetTime(),e,k,r.playerName,r.state,r.roll,r.isWinner) end print("leader",d.currentLeader and d.currentLeader.roll,"winner",d.winner and d.winner.playerName) end)`.
Read whether `roll` turns non-nil when a player picks, or only on the last fire. The Rolls box shows
a number as soon as the client gives one. (design P-R1, R2 P1) Result:

**P-R2. How often the history fires, and in what order.** The same frame as P-R1, plus `/etrace` filtered
to `START_LOOT_ROLL LOOT_HISTORY_UPDATE_DROP LOOT_ROLLS_COMPLETE CANCEL_LOOT_ROLL MAIN_SPEC_NEED_ROLL CHAT_MSG_LOOT`
during one roll. Count the fires per drop against the choices made: one at the start, one per choice,
one at the close? Do two choices in the same instant merge? The one-second ticker covers a history
that fires only at the close. (design P-R2, R1 #7, R2 P2) Result:

**P-R3. Trash and open-world rolls.** Roll on a trash drop and on an open-world elite's, then
`/run for _,e in ipairs(C_LootHistory.GetAllEncounterInfos()) do print(e.encounterID, e.encounterName) for _,d in ipairs(C_LootHistory.GetSortedDropsForEncounter(e.encounterID) or {}) do print(" ", d.lootListKey or d.lootListID, d.itemHyperlink, d.playerRollState, d.winner and d.winner.playerName, #d.rollInfos) end end`.
Read the encounterID and name each gets, and whether it equals any `ENCOUNTER_START` id. Do it on
both clients. A pending item's key is `encounterID:dropKey`. (design P-R3, R1 #6, R2 P3) Result:

**P-R4. rollID against the drop key, and the roll's clock.** On `START_LOOT_ROLL`:
`/run local f=CreateFrame("Frame") f:RegisterEvent("START_LOOT_ROLL") f:SetScript("OnEvent",function(_,_,id,t,h) print("roll",id,t,h,GetLootRollItemLink(id)) end)`
and compare with P-R1's `k`. Then, while the roll is open:
`/run local e=C_LootHistory.GetAllEncounterInfos()[1] local d=e and C_LootHistory.GetSortedDropsForEncounter(e.encounterID) d=d and d[1] if d then local i=C_LootHistory.GetSortedInfoForDrop(e.encounterID, d.lootListID or d.lootListKey) print(i.startTime, i.duration, C_LootHistory.GetLootHistoryTime(), GetTime(), time()) end`.
Read whether rollID and the key are equal or stably related, and **the units of `startTime` and
`duration`**: is `startTime` on `GetLootHistoryTime()`'s clock, and are both seconds or milliseconds?
The code assumes one clock and one unit: Rolling now's time left is `startTime + duration` minus
`GetLootHistoryTime()`, and an open roll with no winner expires there. A roll of about two minutes
should read about 120 left at the start. Also read `GetLootRollTimeLeft(id)` beside it: the code
(since rolls UX RX-02) assumes it answers **milliseconds** and divides by 1000. What the fix
assumes, and what to confirm: a roll your own popup claimed reads `GetLootRollTimeLeft` (through
`Compat.LootRollTimeLeft`) while it answers more than 0, so the client's timer needs neither the
history's clock nor its units; every other roll derives `startTime + duration - GetLootHistoryTime()`
and shows it only when it is at most 300 s (5 min), so a mismatch (the observed 2717:57 is a
`duration` in milliseconds over a `startTime` in seconds) shows no time and never ends the roll.
Record which of `startTime` and `duration` are seconds or milliseconds on each client, and whether
`GetLootRollTimeLeft` still answers after you have chosen (if it answers 0, the history's time
shows). Do it on both clients. (R2 P4; M4 carry; rolls UX design §3.4) Result:

**P-R5. The drop key's field name.** During a roll:
`/dump C_LootHistory.GetSortedDropsForEncounter(<encounterID>)[1]`. Read `lootListID` (Retail) or
`lootListKey` (Forever) at run time; the code reads either. (R2 P8) Result:

**P-SECRET. Secrets inside an instance.** Inside a dungeon, during and after a boss:
`/run local d=C_LootHistory.GetSortedDropsForEncounter((C_LootHistory.GetAllEncounterInfos()[1] or {}).encounterID or 0) print(d and #d, d and d[1] and issecretvalue(d[1].itemHyperlink), C_ChatInfo.InChatMessagingLockdown())`.
Read any secret field, and the chat lockdown state on Forever. A secret field degrades its row, never
the table (Review Focus 2). (R2 P6) Result:

**P-CHAT. The roll lines in chat.**
`/run local f=CreateFrame("Frame") for _,e in ipairs({"CHAT_MSG_LOOT","CHAT_MSG_SYSTEM"}) do f:RegisterEvent(e) end f:SetScript("OnEvent",function(_,e,t) print(e, issecretvalue and issecretvalue(t), (t:gsub("|","||"))) end)`.
In the open world and inside a boss fight, on both clients. Read which event each roll line uses, the
`|HlootHistory:` payload on other players' lines (Forever), and whether the text is secret. The feed
never parses a roll line; this checks the loot lines it does parse are unchanged. (R1 #8, R2 P7) Result:

**P-POPUP. Blizzard's roll popups.** With a roll open:
`/dump GroupLootFrame1.rollID, GroupLootFrame1:IsProtected(), GroupLootFrame1.LootButtonContainer ~= nil, GroupLootFrame1.NeedButton ~= nil, InputUtil.IsGamepadUIEnabled()`.
Read not protected on both clients, the button path (the container on Forever, the frame on Retail),
and the gamepad flag. The popup mark is anchored to these frames and skipped in the gamepad UI.
(R2 P10) Result:

## Master loot and other methods

**P-ML1. A non-master-looter's loot window.** Under master loot, as a raider who is not the master
looter, click the boss corpse:
`/run print(GetNumLootItems()) for i=1,GetNumLootItems() do print(i, GetLootSlotLink(i), select(5, GetLootSlotInfo(i)), select(6, GetLootSlotInfo(i)), GetLootSourceInfo(i)) end`,
with `/etrace` filtered to `LOOT_READY LOOT_OPENED OPEN_MASTER_LOOT_LIST UPDATE_MASTER_LOOT_LIST`.
Read whether the window opens at all, whether the Epic is listed with a readable link, its quality,
whether `locked` is true and the source GUID. Master-loot pending holds only what this lists; if it
lists nothing, nothing is ever held. Retail too, under Guild Master Loot. (design P-ML1, R1 #9) Result:

**P-ML2. Master loot and the loot history.** Under master loot, across one boss and one assignment:
`/etrace LOOT_HISTORY_UPDATE_DROP`, and as the master looter use Request Roll, then
`/dump C_LootHistory.GetAllEncounterInfos()` with P-R1's frame and P-CHAT's. Read whether anything
lands in the loot history and which chat lines appear. The code resolves an awaiting item from the
receipt, not the history. (R1 #10, R2 P9) Result:

**P-FFA. Free for all as a bystander.** Under free for all: `/etrace ENCOUNTER_LOOT_RECEIVED CHAT_MSG_LOOT`
while someone else loots a boss. Read both events and their payloads. (R1 #11) Result:

**P-BOP. A looted bind-on-pickup item.** Hover a just-looted BoP item, then
`/dump C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(<bag>, <slot>))`, and read its tooltip for
the `BIND_TRADE_TIME_REMAINING` line. Expected on Forever: bound and no trade line (owner ruling O2,
the `soulbound` rule); on Retail under group loot, the line. (R1 #12) Result:

## Names

**P-NAME. A two-word name everywhere.** In a party with a member whose name has a surname:
`/dump UnitName("party1"), GetUnitName("party1", true)`, then
`/run C_ChatInfo.SendChatMessage("test","WHISPER",nil,GetUnitName("party1",true))`; after a roll, P-R1's
`playerName` for a same-realm, a cross-realm and the two-word player, and
`/dump C_LootHistory.GetSortedInfoForDrop(<encounterID>, <key>).winner.playerName`. Read whether every
read answers the whole name ("Doom Dock", never "Doom" nor "Doom-Dock"), and whether the whisper
arrives. (design P-NAME, R2 P5, R4 #10, R4 #13) Result:

## Classes, specs, gear and Pawn

**P-SPEC. The one spec.** On a Warrior, a Druid and a Paladin:
`/dump C_SpecializationInfo.GetSpecialization(), C_SpecializationInfo.GetSpecializationInfo(1)`.
Expected one spec, its id (a Warrior's 1491?) and the class name. (R4 #1) Result:

**P-DEPR. The deprecated spec globals.**
`/dump GetSpecialization, GetSpecializationInfo, GetInspectSpecialization, GetCVarBool("loadDeprecationFallbacks")`.
Expected nil, nil, nil, false; if the CVar is false on Retail too, `Compat.InspectSpecID`'s fallback is
dead there. (R4 #2) Result:

**P-TREE. Another player's talent tree.** Inspect a member, then
`/dump C_SpecializationInfo.GetInspectSpecialization("target"), C_Traits.GetConfigInfo(Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID)`.
Read a tree id; if one is there, `C_Traits.GetGroupCurrencyInfo(-1, groupIDs)` may give the tree. A
looter's scale is the best of their class's today, because no tree is read. (R4 #3) Result:

**P-LVL. The armor level rule.** On a level 40 or higher Hunter and Warrior:
`/dump IsSpellKnown(8737), IsSpellKnown(750)`. Expected true (mail, plate). Below 40, false: the code
judges mail and plate as can't use there (reason `armorLevel`, Review Focus 5). (design P-LVL, R4 #6) Result:

**P-SLOT. The ranged slot.** On a Hunter and a Paladin:
`/run local f,m=C_PaperDollInfo.IsRangedSlotShown(),UnitUsesAmmo("player") print(f,m,GetInventoryItemLink("player",18))`.
Expected `true` and the ranged item's or relic's link: slot 18 is `C.SLOT.RANGED`. (design P-SLOT, R4 #4) Result:

**P-ITEM. A vanilla drop's item reads.** Link a vanilla drop:
`/dump C_Item.GetItemSpecInfo(<link>), C_Item.GetItemUpgradeInfo(<link>), C_Item.GetItemStats(<link>)`.
Expected a nil spec list and a nil track; read which stat keys come back. (R4 #5) Result:

**P-STATS. Which secondary stats the weights editor should offer.** The weights strip (Comparison ›
Weights) offers Strength, Agility, Intellect, Stamina, Critical Strike, Haste, Mastery and Versatility
on both clients (`settings/Editors.lua`'s `SECONDARY`). On Forever, link five drops across armor types
and slots (a caster's, a melee's, a tank's, a ranged weapon and a trinket) and run
`/dump C_Item.GetItemStats(<link>)` on each. Read every key that comes back: is any of
`ITEM_MOD_HASTE_RATING_SHORT`, `ITEM_MOD_MASTERY_RATING_SHORT` or `ITEM_MOD_VERSATILITY` ever there, and
which others are (hit, attack power, spell power, defense, dodge, parry, block, spirit, resistances)?
A key the editor does not offer is scored by Pawn's own scale only, never by your weights; a key
it offers that no Forever item carries is a row that never scores. (DW-FP07 carry, R4 §10) Result:

**P-PAWN. Pawn by talent tree.** On a Hunter with Pawn installed:
`/dump PawnOptions.AutoSelectScales, PawnFindScaleForSpec(3, 1), PawnFindScaleForSpec(3, nil)`.
Expected false, the "Hunter: Beast Mastery" scale's name, and a provider scale. Then value a drop with
another class's scale (`PawnGetItemValue` with a Warrior scale) and read whether Pawn answers. The
code takes Pawn's Classic scale per tree, and the best of the class's for a looter. (design P-PAWN,
R4 #9) Result:

## The world, the journals and transmog

**P-INST. Instance groups and difficulties.** In a dungeon-finder group, in a dungeon and in Molten
Core: `/dump IsInGroup(LE_PARTY_CATEGORY_INSTANCE), GetInstanceInfo()`. Read whether the instance
channel exists and which difficulty ids a dungeon and a raid answer (1? 9? 242?); the situations read
them. (R4 #11) Result:

**P-TMOG. Transmog and the journal rule.**
`/dump C_TransmogOutfitInfo.IsTransmogEnabled(), C_GameRules.IsGameRuleActive(Enum.GameRule.EncounterJournalDisabled)`.
Expected false, true: transmog and the journal pool are Retail-only. (R4 #7) Result:

**P-EJ. The Encounter Journal.** `/run EJ_SelectTier(EJ_GetNumTiers()) print(EJ_GetNumTiers(), EJ_GetInstanceByIndex(1, false))`.
Expected 0 or nil: the journal is disabled, so the simulator's pool is your own gear. (R4 #8) Result:

**P-JOURNALS. The collection journals.**
`/dump C_MountJournal.GetNumMounts(), C_ToyBox.GetNumToys(), C_PetJournal.GetNumPets()`. Read which
journals hold anything: a collectible's verdict reads them. (R4 #12) Result:
