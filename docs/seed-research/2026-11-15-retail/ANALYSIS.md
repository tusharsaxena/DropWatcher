# Analysis — Retail seed validation, 2026-11-15 (build 12.1.5.70783)

The first run of `tools/seeds/seeds.py` (contract: `docs/validate-seeds.md`, tracking issue
Ka0sAddonsCommonTasks#1). It re-checks Retail's class list, `core/ClassData.lua`, and the shared
enum fallback literals against the live Retail build on wago.tools (product `wow`, 12.1.5.70783).
Until now the list was written from game knowledge and the item spec list; no DB2 run had checked
it. Every candidate the run raised is ruled in `tools/seeds/retail_rulings.json`, and `RULINGS.md`
beside this file lists each one with its reason. Claude made the rulings under the contract's
precedent; the open question is marked `needs owner review` for the owner.

## What the build says

The list agrees with the build everywhere the build can speak:

| Check | Shipped rows | Result |
| --- | --- | --- |
| `CLASS_ID` against `ChrClasses` (id and file token) | 13 | all agree. Classes 14 (Adventurer) and 15 (Traveler) are not playable classes (no spec with `OrderIndex` 0 to 3) and are not proposed |
| `ARMOR` against the heaviest armor skill line (`SkillRaceClassInfo`) and the heaviest armor bit of `ArmorTypeMask` | 13 | all agree |
| `WEAPONS` against the weapon skill lines | 84 | no shipped subclass lacks its skill line; 7 skill lines the sets leave out (below) |
| `SPECS` against `ChrSpecialization`: the id, its class, the comment's name | 40 | all agree, Devourer 1480 included |
| `SPEC_INDEX` against `OrderIndex + 1` | 40 | all agree, Monk's Brewmaster 1, Mistweaver 2, Windwalker 3 included |
| The primary stat against `PrimaryStatPriority` (0 and 1 Intellect, 2 and 3 Agility, 5 Strength) | 40 | all agree. The mapping is read off this build, where all 40 rows fit it |
| `T` (Titan's Grip) against `SpecializationSpells` 46917 | 40 | Fury (72) alone, as shipped |
| `S` (shields) against the Shield skill line | 40 | every `S` spec's class has it (Warrior, Paladin, Shaman) |
| The enum fallback literals and the recipe skill lines | 76 | all present and named as the build names them |

So 266 shipped rows were checked and none raised a flag.

## What the run proposed: 7 weapon candidates, all rejected

| Candidate | Ruling | Why |
| --- | --- | --- |
| Warrior: bows, guns, crossbows | reject | Precedent: the note above `RETAIL.WEAPONS` leaves out a skill no loot of the class's stat drops for, and names this very case ("a warrior's bow"): a ranged weapon reads as the hunter's alone |
| Rogue: bows, guns, crossbows | reject | The same note. Agility ranged weapons do drop, but the note's rule is that a ranged weapon is the hunter's alone, and it was written that way on purpose |
| Demon Hunter: daggers | reject, **needs owner review** | `SkillRaceClassInfo` grants Daggers (173) to Demon Hunters, and so does `SkillLineAbility`. It is not new: the same row is there on 10.2.7.55664, 11.2.7.65299 and 12.0.7.68974. The table leaves daggers out and nothing in the repo records why, so it is either a deliberate loot ruling or a gap. With the Intellect Devourer spec now in the class, it matters more than it did |

Nothing was accepted, so `apply` changed nothing, `core/ClassData.lua` is unchanged and no smoke
check is owed.

## What DB2 does not settle

- **Dual wield.** Retail's `D` flags are spec passives the skill tables do not carry:
  `SpecializationSpells` has Dual Wield (674) for Frost (251) alone, and the class rows of skill
  line 118 name Hunter, Rogue, Shaman, Death Knight and Demon Hunter, not Warrior or Monk. The tool
  does not check `D` on Retail, and the contract says so.
- **The off-hand flag `O`** and the Pawn index have no DB2 answer beyond `OrderIndex`.
- **The proficiency rows are what a class can learn**, not what loot it is offered. The
  loot-relevance rule is the file's, and a candidate that it covers stays rejected.

## In-game check for the open question

On a Demon Hunter, with a dagger in your bags:
`/run print(IsUsableItem(<itemID>))`, then try to equip it. If it equips, the owner decides whether
daggers are this class's loot (re-rule `weapon:DEMONHUNTER:DAGGER` to `accept` and run `apply`), or
rules it a loot-relevance rejection.

## What a later run should re-check

- Whether the Demon Hunter dagger row survives the next build, and the owner's ruling on it.
- Devourer (1480): its stat (`PrimaryStatPriority` 0, Intellect) and its place (3) agree today; its
  weapon and off-hand flags stay the known limitation FEED-7 records.
- A new class or spec shows as a `class:` or `spec:` candidate. It needs its stat and four flags by
  hand.
