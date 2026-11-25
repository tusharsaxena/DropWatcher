# Analysis — WoW Forever recipe reagents, 2026-11-26 (build 1.60.1.70938)

The second run of `tools/seeds/recipes.py` (`seeds.py recipes`, contract: `docs/validate-seeds.md` ->
`## Recipe reagents`), for ISR3-DW-08 (Item Search round 3: the window's Crafting tab says where a
recipe you don't know is learned). The generator now also records each recipe's teaching item, the
item that teaches the recipe spell, so it reads two more tables, `ItemEffect` and `ItemXItemEffect`,
and keeps `SpellEffect`'s effect 36 rows beside effect 24. The build is the one the first bundle
pinned, 1.60.1.70938, the class seeds' newest bundle's (`2026-11-15-forever`). The live `wowf` build
on 2026-11-26 is 1.60.1.71139; moving to it is a seed-validation run of its own, with the class seeds.
Nothing is curated, so nothing is ruled.

This bundle supersedes `2026-11-25-forever-recipes`. That one is frozen as it was, with five tables;
the generator reads seven now, so it no longer regenerates the file.

## What the build says

| Check | Result |
| --- | --- |
| The reagent rows | unchanged: `SkillLine`, `SkillLineAbility`, `SpellReagents` and `SpellName` freeze to the first bundle's bytes; the 2,466 recipes, their ranks, reagents and products are the same |
| `ItemEffect`'s shape | no `ParentItemID` on this build: `ItemXItemEffect` (`ItemEffectID`, `ItemID`) ties an effect to its item; every teaching effect has a row there |
| Taught by an item, `TriggerType` 6 (`LEARN_SPELL_ID`) with `SpellID` the recipe | 1,964 recipes (2,005 item and recipe pairs) |
| Taught through a learning spell (`SpellEffect` effect 36, `EffectTriggerSpell` the recipe) | 7 pairs from 3 items, each teaching 2 or 3 recipes at once on use; 2 recipes have no other teaching item |
| `TriggerType` 0 rows whose `SpellID` is the recipe itself | 180: items that cast the recipe on use. They teach nothing and are not counted |
| Recipes with a teaching item | **1,966 of 2,466 (79.7%)**; 43 have more than one (two or three items) |
| Recipes with none (a trainer's) | 500 |
| By profession (teaching item / recipes) | Alchemy 150/196, Blacksmithing 416/506, Enchanting 195/262, Engineering 202/275, Leatherworking 498/592, Tailoring 369/470, Cooking 119/133, First Aid 17/32 |
| Raptor Flesh (12184), the owner's screenshot | its Cooking recipes have a teaching item; Roast Raptor (15855) is taught by item 12228 |
| A minimum rank above 1 | 3 of the taught recipes and 13 of the trainer's: "Learn at N" stays rare |

"No teaching item" is not proof of a trainer: a recipe a quest teaches as a spell reward, or one the
client data does not tie to an item, also has none. The window says "Trainer" for all of them, and
`docs/known-limitations.md` says so.

## The ForeverDB cross-check (dev time)

Not re-run: the ranks it compares (`SkillLineAbility`) freeze to the first bundle's bytes, so its
counts stand (2,466 of 2,466 agree, ForeverDB v2026.11.24.46). The teaching items have no
counterpart in the cross-check; the window reads the teaching item's sources from ForeverDB at run
time, and no ForeverDB value is in this bundle or the repo (GPL-3.0).

## The generated file

1015 lines (913 before; the 1500-line cap binds it, since it is TOC-loaded). Each `r(...)` row gains
the teaching item after the name (`nil` for a trainer's recipe), and 43 `teachers(spell, ...)` rows
list every item where more than one teaches a recipe. Measured headless on Lua 5.1, the same way as
the first run: the chunk holds about 613 KB until the first `Get()` (561 KB before), which builds the
table in about 3 ms into 2059 KB kept with its strings (2044 KB before); on Retail the builder is
never made.

## What a later run should re-check

- A new `wowf` build: compare the 1,966 and the 500. A large move is a DB2 export change to read
  before shipping, as is a build that brings `ItemEffect.ParentItemID` back.
- The 180 `TriggerType` 0 self-casts: if a build moves them to trigger 6, they become teaching items.
- In game (ITEM-SEARCH-45): a "Trainer" recipe no trainer teaches is a gap in this join, worth a
  spell id in the next run's analysis.
