# Analysis — WoW Forever seed validation, 2026-11-15 (build 1.60.1.70938)

The first run of `tools/seeds/seeds.py` on WoW Forever (contract: `docs/validate-seeds.md`, tracking
issue Ka0sAddonsCommonTasks#1). It checks Forever's own class list, `core/ClassDataForever.lua`, and
the shared enum fallback literals against the live Forever build on wago.tools (product `wowf`,
1.60.1.70938), never against Retail's data (clients-§5). The list's header calls its rows INFERRED,
not probed: vanilla-era game knowledge from the port's research (R4 §5). This is the first time they
meet the client's own data. Every candidate and flag is ruled in `tools/seeds/forever_rulings.json`,
and `RULINGS.md` lists each one with its reason. Claude made the rulings under the contract's
precedent; the open questions are marked `needs owner review`.

## What the build says

Most of the inferred list is confirmed:

| Check | Shipped rows | Result |
| --- | --- | --- |
| `CLASS_ID` against `ChrClasses` | 9 | all agree; the build has exactly these nine classes |
| `ARMOR` against the heaviest armor skill line and `ArmorTypeMask` | 9 | all agree |
| `ARMOR_EARLY` and `ARMOR_LEVEL` against the heavier line's `MinLevel` | 4, and 40 | all agree: Plate Mail is level 40 for Warrior and Paladin, Mail level 40 for Hunter and Shaman, and their early types are Mail and Leather |
| `ARMOR_LOWER_OK` against the lighter lines | 9 classes | every lighter type has its line, as the no-specialization rule assumes |
| `RELIC` against `ArmorTypeMask` bits 7 to 9 | 3 | all agree: Paladin libram, Druid idol, Shaman totem, no other class |
| `WEAPONS` against the weapon skill lines | 65 | no shipped subclass lacks its line; 2 lines the sets leave out (below) |
| `SPECS` against `TalentTab` (the class, the tree's `OrderIndex + 1`, the comment's name) | 27 | all present and in the talent frame's order; one name differs (below) |
| `S` and `D` against the Shield and Dual Wield lines | 27 | every flagged tree's class has the line |
| The enum fallback literals and the recipe skill lines | 76 | 8 flags (below), all for Retail-only rows |

193 shipped rows were checked. `ChrSpecialization` holds one class-wide spec per class on Forever
(1482 to 1491); the list keys its rows by talent tree and seeds no spec id, so nothing there is
compared.

## What the run proposed

### 3 candidates, all rejected for the owner

| Candidate | Ruling | Why |
| --- | --- | --- |
| Druid: polearms | reject, **needs owner review** | `SkillRaceClassInfo` has a Druid-only Polearms row from level 20, and `SkillLineAbility` agrees. The research says druids had no polearms in vanilla, and `tests/test_class_data.lua` pins `CanUseWeapon("DRUID", POLEARM)` false |
| Rogue: one-handed axes | reject, **needs owner review** | The Axes rows grant Rogues (shared with Warriors, split by race), and `SkillLineAbility` agrees. The research's vanilla list has no axes for rogues |
| Shaman: dual wield | reject, **needs owner review** | A Shaman row of Dual Wield exists (Availability 0, no level). The research records no shaman dual wield in vanilla, and a row with no level looks talent- or rune-granted, which one class-wide `D` cannot express |

Each of the three contradicts recorded research the build alone cannot overturn, since the rows
are what a class can learn, not what it is offered or when. So they go to the owner rather than
being accepted. Nothing was accepted, so `apply` changed nothing, `core/ClassDataForever.lua` is
unchanged and no smoke check is owed.

### 9 flags, all kept

- `tree-name:DRUID:2`: the comment says Feral, `TalentTab` says Feral Combat. It is the same tree
  (`OrderIndex` 1), and the comment uses the short name.
- `enum:RECIPE_SUBCLASS:JEWELCRAFTING`, `enum:RECIPE_SUBCLASS:INSCRIPTION`,
  `enum:MISC_SUBCLASS:MOUNT_EQUIPMENT`: absent on Forever. `core/Constants.lua`'s literals are
  Retail's documented fallbacks, shared by both clients, and no Forever item carries those
  subclasses, so they never match.
- `enum:MISC_SUBCLASS:COMPANION_PET`: the same id (2) with the same meaning, which Forever calls
  `Pet`.
- `skill-line:RECIPE_SKILL_LINE:755` and `:773`, `skill-line:PROFESSION:755` and `:773`:
  Jewelcrafting and Inscription do not exist on Forever. The rows are never reached there.

## In-game checks for the open questions

On Forever, with the item in your bags, run `/run print(IsUsableItem(<itemID>))` and try to equip
it:

- a Druid of level 20 or more with a polearm;
- a Rogue with a one-handed axe;
- a Shaman with a one-handed weapon in the off hand. Check whether the off-hand slot takes it, and
  whether that needs a talent or a rune.

Each result goes to the owner, who re-rules the key (`weapon:DRUID:POLEARM`, `weapon:ROGUE:AXE_1H`,
`dualWield:SHAMAN`). An accepted weapon is written by `apply`. An accepted `dualWield:SHAMAN` is a
hand edit to the Shaman trees' flags, and `tests/test_class_data.lua`'s pins move with it.

## What a later run should re-check

- The three open rows, and whether a newer `wowf` build changes them.
- The research's other inferences that this build confirms: Hunters have no mace line, and
  Paladins no staff or dagger line. The stat gate and the Pawn indexes stay the design's, since DB2
  has no answer for them.
