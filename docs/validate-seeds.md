# Seed validation — Drop Watcher

The seed-validation contract `/dev-copilot:validate-seeds DropWatcher <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Drop Watcher's procedure: the tool, the files it writes, the
precedent a ruling follows and the nuances of each client. The headings below are the interface
the command reads, so keep their names.

The seeds checked here are Drop Watcher's own files: the item enum fallback literals in
`core/Constants.lua` (`C.ITEM_CLASS`, `C.WEAPON_SUBCLASS`, `C.ARMOR_SUBCLASS`, `C.RECIPE_SUBCLASS`,
`C.MISC_SUBCLASS`) and the recipe skill lines (`C.RECIPE_SKILL_LINE`, `modules/CollectCells.lua`'s
`PROFESSION`). These are name and existence checks only, with no candidates: they mirror the
client's enums and are not a curated list. Nothing else in `core/` or `modules/` is a seed: the
inventory slots (`C.SLOT`) are FrameXML constants that no DB2 table holds, and
`core/CompatJournal.lua`, `modules/TestData.lua` and the simulator's files hold reads or invented
test data, not game ids.

**The class lists are LibKa0s's.** The hand-curated class lists (clients-§5: the class ids, armor
and the level-40 switch, weapons, specs and talent trees, Titan's Grip, shields, dual wield, relics)
are LibKa0s-Verdict-1.0's `VerdictClassData.lua` since the Item Search split (DropWatcher#19),
vendored here at `libs/LibKa0s/`, and the gear classes (`IR.GEAR_CLASSES`) its `VerdictFacts.lua`.
Their seed contract moved beside them (LibKa0s#109): LibKa0s's `tools/seeds/classseeds.py`, flavors
`retail-classes` and `forever-classes` of LibKa0s's `docs/validate-seeds.md`, with the class-list
rulings this repo held. A ruled edit there reaches Drop Watcher by a re-vendor.

Each run ends in a frozen bundle under `docs/seed-research/<date>-<flavor>/`. The tool is
`tools/seeds/seeds.py`, and its docstring is the reference for every flag kind. The first runs,
`docs/seed-research/2026-11-15-retail/` and `docs/seed-research/2026-11-15-forever/`, checked the class
lists too, while this repo held that contract; they stay as the frozen record.

Item Search's two WoW Forever seeds, the generated recipe reagents (`core/RecipeReagentsForever.lua`,
`tools/seeds/recipes.py`) and the hand-curated gathering nodes (`core/GatherNodes.lua`), went with
Item Search to Ka0s Item Search (DropWatcher#19), whose own `docs/validate-seeds.md` keeps them. The
`*-forever-recipes*` bundles under `docs/seed-research/` stay here as the frozen record of the runs
made while Drop Watcher held them.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `core/Constants.lua`'s enum literals and `C.RECIPE_SKILL_LINE`, `modules/CollectCells.lua`'s `PROFESSION` (checked only) | `tools/seeds/seeds.py --flavor retail` |
| `forever` | wago.tools product `wowf` (WoW Forever) | the same files, against the Forever build (checked only) | `tools/seeds/seeds.py --flavor forever` |

The class lists' flavors are LibKa0s's `retail-classes` and `forever-classes` (LibKa0s's
`docs/validate-seeds.md`, `tools/seeds/classseeds.py`).

## Rules

- **Nothing is written by the tool.** Every flag is ruled `keep` (the row stands, with its reason)
  or `fix` (a hand edit is owed). `apply` is the gate: it refuses while anything is unruled or a
  `fix` is open, and writes nothing. Once the file carries the edit, a `derive --replay` stops
  raising the flag.
- **Rulings are data.** They live in `tools/seeds/retail_rulings.json` and
  `tools/seeds/forever_rulings.json`, written only by `seeds.py rule`. A ruling is keyed
  `shipped:<kind>:<subject>`, never by build, and it holds until the thing it ruled on stops being
  proposed.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the seed file's own header and comments (`core/Constants.lua`'s *Item ids* header: each literal
     is the documented 12.x value, used only when `Enum` or the member is absent, and `fromEnum`
     reads the client's own value first);
  3. `docs/design-readings.md` and `docs/known-limitations.md`.
- **Evidence.** The bundle's `raw/*.csv.gz`: `ItemClass` and `ItemSubClass` (the enum literals'
  ids and names) and `SkillLine` (the recipe skill lines' names).
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/seeds/seeds.py status --flavor retail
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`, comparing the
live `wow` build with the newest `*-retail` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor retail --build <build> --bundle docs/seed-research/<date>-retail --date <date>
```

It downloads three small tables (`SkillLine`, `ItemClass`, `ItemSubClass`, cached in
`tools/seeds/.cache/`) and runs the coverage gate: the sentinel item classes (Weapon 2, Armor 4) and
skill lines (Blacksmithing 164, Tailoring 197) must be there under those names. **If the gate fails,
stop**: fix the tool, not the rulings. Report the flag count and the unruled count.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-retail
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and exits 1, and must print `OK` after `rule`.

- **Flags** (`keep` or `fix`): `enum` (a fallback literal the build has not, or names otherwise) and
  `skill-line` (a recipe skill line the build has not, or names otherwise).
- A name that differs by design is an alias in the tool (`ENUM_ALIASES`: `GENERIC` is
  Miscellaneous), not a ruling.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` writes the bundle's `RULINGS.md`; `apply` refuses while anything is unruled or a `fix` is
open, and writes nothing.

### After

- Write the bundle's `ANALYSIS.md` by hand: what the build says, what was flagged and how it was
  ruled, and what a later run should re-check.
- A `fix` is a hand edit to `core/Constants.lua` or `modules/CollectCells.lua`, with its test, under
  this repo's green gate.

### Stage

`tools/seeds/retail_rulings.json`, `docs/seed-research/<date>-retail`, plus any hand edit, test or
citation edits. Commit message: `Seeds (retail): re-validated against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 tools/seeds/seeds.py status --flavor forever
```

Prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`, comparing the live `wowf` build with the
newest `*-forever` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor forever --build <build> --bundle docs/seed-research/<date>-forever --date <date>
```

The same tables and the same gate as Retail.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-forever
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-forever
```

Nuances:

- **The shared literals are Retail's.** `core/Constants.lua` and `C.RECIPE_SKILL_LINE` are one table
  for both clients. A Retail-only subclass or skill line (Jewelcrafting, Inscription, Mount
  Equipment) is absent on Forever and is kept, because no Forever item ever carries it.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

As for Retail: `report` first, then `apply`, which refuses on anything unruled or owed by hand.

### After

- Write the bundle's `ANALYSIS.md` by hand.
- A `fix` is a hand edit, under both kit profiles.

### Stage

`tools/seeds/forever_rulings.json` and `docs/seed-research/<date>-forever`, plus any hand edit, test
or citation edits. Commit message: `Seeds (forever): re-validated against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. Without pytest,
`python3 -m unittest discover -s tools/seeds` runs the same cases: `tools/seeds/test_seeds.py`, on
fixture tables, with no network.

## Notes

- **The class-list questions of the first run** (the Retail Demon Hunter's daggers, and on Forever
  the druid's polearms, the rogue's one-handed axes and the shaman's dual wield, each a `needs owner
  review` rejection) moved to LibKa0s with their rulings (`retail-classes_rulings.json`,
  `forever-classes_rulings.json`); the 2026-11-15 bundles' `ANALYSIS.md` gives the in-game check for
  each.
- **The next Retail run** has a flag waiting: `C.ITEM_CLASS.TRADEGOODS` (added by DW-RG1 after the
  2026-11-15 run) reads `Tradeskill` on the 12.1.5 build, so `shipped:enum:ITEM_CLASS:TRADEGOODS` comes
  up for a ruling.
- **A ruling outlives its flag.** Once a flag stops being raised its ruling stays in the file as
  provenance, and that is not an error.
- **A shared helper** for the build pin, the cache, the bundle and the rulings is LibKa0s#91's to
  decide; until then the tool copies AuraMaster's pattern and imports nothing across repos.
