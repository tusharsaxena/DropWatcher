#!/usr/bin/env python3
"""tools/seeds/recipes.py — generate WoW Forever's recipe-reagent table from a pinned wago.tools build.

WHAT THIS IS
    Item Search (Drop Watcher, DropWatcher#17, the 2026-11-25 Item Search spec §4.2) lists, for an
    item, the recipes that use it as a reagent. ForeverDB has no reagent lists, so the table comes
    from the WoW Forever client's own DB2 data on wago.tools (product `wowf`, always with `?build=`,
    clients-§10), the same source and build pin as the class seeds (`seeds.py`). It is GENERATED,
    not curated: no candidate, flag or ruling. A re-run on the same bundle writes the same bytes,
    and the gate test (tools/seeds/test_recipes.py) fails when the shipped file differs from the
    generator's output for its recorded bundle, so a hand edit is caught.

    The join, per recipe spell:
        SkillLineAbility   Spell, SkillLine, MinSkillLineRank, TrivialSkillLineRankLow (yellow),
                           TrivialSkillLineRankHigh (gray); crafting professions only (PROFESSIONS)
        SpellReagents      Reagent_0..7 and ReagentCount_0..7
        SpellEffect        Effect 24 (CREATE_ITEM): EffectItemType, the item the recipe makes
        SpellName          Name_lang, the recipe's name
        SkillLine          DisplayName_lang: the coverage gate's profession names
        ItemEffect         an item's spell: TriggerType 6 (LEARN_SPELL_ID) with SpellID the recipe spell,
                           or any trigger whose SpellID has a SpellEffect Effect 36 (LEARN_SPELL) whose
                           EffectTriggerSpell is the recipe spell
        ItemXItemEffect    ItemEffectID -> ItemID: the teaching item (the recipe item)
    A recipe the build gives no SpellReagents row is left out (it can use no reagent); Item Search's
    profession-window fallback (spec §4.2 B) learns such a recipe in game. A recipe no item teaches
    is a trainer's (ISR3-DW-08): the window's Crafting tab says "Trainer" for it.

THE STEPS (driven through seeds.py, which hands its `recipes` subcommand to main() below)
    python3 tools/seeds/seeds.py recipes status
    python3 tools/seeds/seeds.py recipes derive --bundle docs/seed-research/<date>-forever-recipes --date <date> --build <build> [--replay]
    python3 tools/seeds/seeds.py recipes apply  --bundle docs/seed-research/<date>-forever-recipes
    python3 tools/seeds/seeds.py recipes check
    python3 tools/seeds/seeds.py recipes crosscheck --bundle B --foreverdb <cache>/foreverdb.json   (dev time)

    `derive` downloads the five tables whole into tools/seeds/.cache/ (git-ignored), runs the
    coverage gate, and freezes the EXTRACT into the bundle's raw/: the rows of the crafting skill
    lines and of their spells only (the whole SpellEffect table is ~4 MB, the extract ~0.1 MB), each
    table's header kept. MANIFEST.json and SOURCES.md record the build, the date, every whole
    table's sha256 and row count as served, and the extract's digest. `--replay` re-derives the
    manifest from raw/ alone, with no network. `apply` writes core/RecipeReagentsForever.lua from
    the bundle; `check` exits 1 unless that file equals the generator's output for the bundle its
    own header names. `crosscheck` (dev time only) counts how many recipes' yellow and gray agree
    with ForeverDB's `sla` positions 3 and 4 and prints counts and spell ids, never a ForeverDB
    value (GPL-3.0, clients-§10). The date is always an argument; the tool never reads the clock.

Python 3.8+ and its standard library only.
"""

from __future__ import annotations

import csv
import gzip
import hashlib
import io
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import seeds  # noqa: E402

PRODUCT = "wowf"
OUTPUT = "core/RecipeReagentsForever.lua"
CREATE_ITEM = 24
LEARN_SPELL = 36
TRIGGER_LEARN = 6
MAX_REAGENTS = 8

# The tables read, in digest order, and why.
TABLES = (
    ("SkillLine", "the crafting professions' names (the coverage gate)"),
    ("SkillLineAbility", "recipe spell x skill line: MinSkillLineRank, TrivialSkillLineRankLow (yellow), "
                         "TrivialSkillLineRankHigh (gray)"),
    ("SpellReagents", "a recipe's reagents and counts (Reagent_0..7, ReagentCount_0..7)"),
    ("SpellEffect", "Effect 24 (CREATE_ITEM): EffectItemType, the item a recipe makes; Effect 36 (LEARN_SPELL): "
                    "EffectTriggerSpell, the recipe a learning spell teaches"),
    ("SpellName", "a recipe's name (Name_lang)"),
    ("ItemEffect", "an item's spell and TriggerType: 6 (LEARN_SPELL_ID) teaches SpellID, or SpellID is a learning spell"),
    ("ItemXItemEffect", "ItemEffectID -> ItemID: the item that teaches a recipe"),
)

# The crafting professions Item Search lists (spec §4.2) -> (the build's DisplayName_lang, required).
# Jewelcrafting is kept only when the build has it; gathering lines (Mining's smelting, Herbalism,
# Skinning) and Fishing are not crafting professions here.
PROFESSIONS = {
    171: ("Alchemy", True),
    164: ("Blacksmithing", True),
    333: ("Enchanting", True),
    202: ("Engineering", True),
    165: ("Leatherworking", True),
    197: ("Tailoring", True),
    185: ("Cooking", True),
    129: ("First Aid", True),
    755: ("Jewelcrafting", False),
}
# Lua rows packed per line up to this width: the file is TOC-loaded, so the 1500-line cap binds it
# (layout-§1), and one recipe per line would be ~2,500 lines (three a line is ~850).
WRAP = 320
HEADER_RE = re.compile(r"^-- (Build|Date|Inputs|Bundle): +(\S+)")


# ---------------------------------------------------------------------------
# The extract
# ---------------------------------------------------------------------------

def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    """`(header, rows)` of a CSV (gzip or plain)."""
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return list(reader.fieldnames or []), rows


def read_rows_text(text: str) -> tuple[list[str], list[dict]]:
    """`(header, rows)` of CSV text."""
    reader = csv.DictReader(io.StringIO(text, newline=""))
    rows = list(reader)
    return list(reader.fieldnames or []), rows


def csv_text(header: list[str], rows: list[dict]) -> str:
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=header, lineterminator="\n")
    writer.writeheader()
    for row in rows:
        writer.writerow(row)
    return out.getvalue()


def extract(full: dict[str, tuple[list[str], list[dict]]]) -> dict[str, str]:
    """`{table: CSV text}`: the professions' rows of each whole table, in the source's row order."""
    lines = set(PROFESSIONS)
    out = {}
    header, rows = full["SkillLine"]
    out["SkillLine"] = csv_text(header, [r for r in rows if seeds.as_int(r["ID"]) in lines])
    header, rows = full["SkillLineAbility"]
    sla = [r for r in rows if seeds.as_int(r["SkillLine"]) in lines]
    out["SkillLineAbility"] = csv_text(header, sla)
    spells = {seeds.as_int(r["Spell"]) for r in sla}
    header, rows = full["SpellReagents"]
    out["SpellReagents"] = csv_text(header, [r for r in rows if seeds.as_int(r["SpellID"]) in spells])
    header, rows = full["SpellEffect"]
    effects = [r for r in rows if (seeds.as_int(r["Effect"]) == CREATE_ITEM and seeds.as_int(r["SpellID"]) in spells)
               or (seeds.as_int(r["Effect"]) == LEARN_SPELL and seeds.as_int(r["EffectTriggerSpell"]) in spells)]
    out["SpellEffect"] = csv_text(header, effects)
    learners = {seeds.as_int(r["SpellID"]) for r in effects if seeds.as_int(r["Effect"]) == LEARN_SPELL}
    header, rows = full["SpellName"]
    out["SpellName"] = csv_text(header, [r for r in rows if seeds.as_int(r["ID"]) in spells])
    header, rows = full["ItemEffect"]
    item_effects = [r for r in rows if seeds.as_int(r["SpellID"]) in spells | learners]
    out["ItemEffect"] = csv_text(header, item_effects)
    ids = {seeds.as_int(r["ID"]) for r in item_effects}
    header, rows = full["ItemXItemEffect"]
    out["ItemXItemEffect"] = csv_text(header, [r for r in rows if seeds.as_int(r["ItemEffectID"]) in ids])
    return out


def digest(texts: dict[str, str]) -> str:
    """The sha256 of the extract: each table's name, a newline, then its CSV text, in TABLES order."""
    h = hashlib.sha256()
    for table, _why in TABLES:
        h.update(table.encode("utf-8") + b"\n" + texts[table].encode("utf-8"))
    return h.hexdigest()


def freeze_text(text: str, member: Path) -> None:
    """Gzip `text` into raw/ (mtime 0, so a re-freeze of one build is byte-stable)."""
    member.parent.mkdir(parents=True, exist_ok=True)
    with member.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as dst:
            dst.write(text.encode("utf-8"))


def read_extract(bundle: Path) -> dict[str, str]:
    texts = {}
    for table, _why in TABLES:
        member = bundle / "raw" / ("%s.csv.gz" % table)
        if not member.exists():
            raise SystemExit("%s is missing raw/%s.csv.gz." % (bundle, table))
        with gzip.open(member, "rt", encoding="utf-8", newline="") as handle:
            texts[table] = handle.read()
    return texts


def parse_extract(texts: dict[str, str]) -> dict[str, list[dict]]:
    return {t: list(csv.DictReader(io.StringIO(texts[t], newline=""))) for t, _why in TABLES}


# ---------------------------------------------------------------------------
# The model
# ---------------------------------------------------------------------------

def coverage(rows: dict[str, list[dict]]) -> dict:
    """The coverage gate: every required profession is in SkillLine under its name and has a
    recipe. A failure is a SystemExit, never a quiet empty profession: fix the tool's map."""
    names = {seeds.as_int(r["ID"]): r["DisplayName_lang"] for r in rows["SkillLine"]}
    with_rows = {seeds.as_int(r["SkillLine"]) for r in rows["SkillLineAbility"]}
    present, absent = [], []
    for line, (name, required) in sorted(PROFESSIONS.items()):
        if line not in names:
            if required:
                raise SystemExit("Coverage gate: skill line %d (%s) is not in SkillLine." % (line, name))
            absent.append(line)
            continue
        if names[line] != name:
            raise SystemExit("Coverage gate: skill line %d is named %r, not %r." % (line, names[line], name))
        if line not in with_rows:
            if required:
                raise SystemExit("Coverage gate: skill line %d (%s) has no SkillLineAbility row." % (line, name))
            absent.append(line)
            continue
        present.append(line)
    return {"present": present, "absent": absent}


def reagents_of(row: dict, spell: int) -> dict[int, int]:
    out: dict[int, int] = {}
    for i in range(MAX_REAGENTS):
        item = seeds.as_int(row.get("Reagent_%d" % i))
        if item == 0:
            continue
        count = seeds.as_int(row.get("ReagentCount_%d" % i))
        if count <= 0 or item < 0 or item in out:
            raise SystemExit("Spell %d's reagent slot %d is %d x %d: the join needs a rule for it." % (spell, i, item, count))
        out[item] = count
    return out


def teachers(rows: dict[str, list[dict]]) -> dict[int, list[int]]:
    """`{recipe spell: [item, ...]}`, ascending: the items that teach each spell. An item teaches a
    spell when one of its ItemEffect rows has TriggerType 6 (LEARN_SPELL_ID) and SpellID the spell,
    or (any trigger) a SpellID whose SpellEffect Effect 36 (LEARN_SPELL) has EffectTriggerSpell the
    spell (an item teaching several recipes at once)."""
    learns: dict[int, set] = {}
    for r in rows["SpellEffect"]:
        if seeds.as_int(r["Effect"]) == LEARN_SPELL:
            learns.setdefault(seeds.as_int(r["SpellID"]), set()).add(seeds.as_int(r["EffectTriggerSpell"]))
    items_of: dict[int, list[int]] = {}
    for r in rows["ItemXItemEffect"]:
        items_of.setdefault(seeds.as_int(r["ItemEffectID"]), []).append(seeds.as_int(r["ItemID"]))
    out: dict[int, set] = {}
    for r in rows["ItemEffect"]:
        spell, items = seeds.as_int(r["SpellID"]), items_of.get(seeds.as_int(r["ID"]), [])
        taught = set(learns.get(spell, ()))
        if seeds.as_int(r["TriggerType"]) == TRIGGER_LEARN:
            taught.add(spell)
        for s in taught:
            out.setdefault(s, set()).update(i for i in items if i > 0)
    return {s: sorted(v) for s, v in out.items() if v}


def build_model(rows: dict[str, list[dict]]) -> dict:
    """`{recipes: {spell: recipe}, stats: {...}}`. A recipe is `{skillLine, skillLines, min, yellow,
    gray, made, name, taught, reagents: {item: count}}`; `skillLines` lists every line in SkillLineAbility
    order when the spell is in more than one (a recipe two professions share); `taught` the items that
    teach it, ascending (empty: a trainer's recipe)."""
    reagents = {}
    for r in rows["SpellReagents"]:
        spell = seeds.as_int(r["SpellID"])
        if spell in reagents:
            raise SystemExit("Spell %d has two SpellReagents rows." % spell)
        reagents[spell] = reagents_of(r, spell)
    made = {}
    for r in sorted(rows["SpellEffect"], key=lambda e: (seeds.as_int(e["DifficultyID"]), seeds.as_int(e["EffectIndex"]))):
        spell = seeds.as_int(r["SpellID"])
        if seeds.as_int(r["Effect"]) == CREATE_ITEM and spell not in made and seeds.as_int(r["EffectItemType"]) > 0:
            made[spell] = seeds.as_int(r["EffectItemType"])
    names = {seeds.as_int(r["ID"]): r["Name_lang"] for r in rows["SpellName"]}
    taught = teachers(rows)
    recipes: dict[int, dict] = {}
    spells, no_reagents = set(), set()
    for r in sorted(rows["SkillLineAbility"], key=lambda a: seeds.as_int(a["ID"])):
        spell, line = seeds.as_int(r["Spell"]), seeds.as_int(r["SkillLine"])
        if line not in PROFESSIONS:
            continue
        spells.add(spell)
        if not reagents.get(spell):
            no_reagents.add(spell)
            continue
        ranks = (seeds.as_int(r["MinSkillLineRank"]), seeds.as_int(r["TrivialSkillLineRankLow"]),
                 seeds.as_int(r["TrivialSkillLineRankHigh"]))
        if spell in recipes:
            have = recipes[spell]
            if (have["min"], have["yellow"], have["gray"]) != ranks:
                raise SystemExit("Spell %d's skill lines rank it differently: the join needs a rule for it." % spell)
            if line not in have["skillLines"]:
                have["skillLines"].append(line)
            continue
        recipes[spell] = {"skillLine": line, "skillLines": [line], "min": ranks[0], "yellow": ranks[1],
                          "gray": ranks[2], "made": made.get(spell), "name": names.get(spell),
                          "taught": taught.get(spell, []), "reagents": reagents[spell]}
    stats = {"spells": len(spells), "recipes": len(recipes), "noReagents": len(no_reagents),
             "unnamed": sum(1 for r in recipes.values() if r["name"] is None),
             "makesNoItem": sum(1 for r in recipes.values() if r["made"] is None),
             "shared": sum(1 for r in recipes.values() if len(r["skillLines"]) > 1),
             "taught": sum(1 for r in recipes.values() if r["taught"]),
             "taughtByMore": sum(1 for r in recipes.values() if len(r["taught"]) > 1),
             "perLine": {line: sum(1 for r in recipes.values() if r["skillLine"] == line)
                         for line in sorted(PROFESSIONS)}}
    return {"recipes": recipes, "stats": stats}


# ---------------------------------------------------------------------------
# The Lua file
# ---------------------------------------------------------------------------

def lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def lua_row(spell: int, r: dict) -> str:
    parts = [str(spell), str(r["skillLine"]), str(r["min"]), str(r["yellow"]), str(r["gray"]),
             "nil" if r["made"] is None else str(r["made"]),
             "nil" if r["name"] is None else lua_string(r["name"]),
             str(r["taught"][0]) if r["taught"] else "nil"]
    for item in sorted(r["reagents"]):
        parts += [str(item), str(r["reagents"][item])]
    return "r(%s)" % ", ".join(parts)


def pack(items: list[str], indent: str) -> list[str]:
    lines, cur = [], ""
    for item in items:
        if cur and len(indent) + len(cur) + 1 + len(item) > WRAP:
            lines.append(indent + cur)
            cur = item
        else:
            cur = item if not cur else cur + " " + item
    if cur:
        lines.append(indent + cur)
    return lines


def render(model: dict, manifest: dict, bundle_rel: str) -> str:
    """The whole of core/RecipeReagentsForever.lua, LF-terminated (the writer makes it CRLF)."""
    recipes, stats = model["recipes"], model["stats"]
    present = ", ".join("%d %s" % (line, PROFESSIONS[line][0]) for line in manifest["professions"]["present"])
    absent = ", ".join("%d %s" % (line, PROFESSIONS[line][0]) for line in manifest["professions"]["absent"]) or "none"
    out = [
        "local _, NS = ...",
        "-- %s — WoW Forever's recipe-reagent table for Item Search (DropWatcher#17)." % OUTPUT,
        "--",
        "-- GENERATED by tools/seeds/recipes.py (`seeds.py recipes apply`) from the WoW Forever client's DB2",
        "-- on wago.tools; never edit it by hand: tools/seeds/test_recipes.py fails when this file differs",
        "-- from the generator's output for the bundle below (docs/validate-seeds.md -> Recipe reagents).",
        "--",
        "-- Build:   %s" % manifest["build"],
        "-- Date:    %s" % manifest["date"],
        "-- Inputs:  %s" % manifest["extractSha256"],
        "-- Bundle:  %s" % bundle_rel,
        "--",
        "-- Inputs is the sha256 of the bundle's frozen extract (SkillLine, SkillLineAbility, SpellReagents,",
        "-- SpellEffect effects 24 and 36, SpellName, ItemEffect, ItemXItemEffect).",
        "-- Skill lines: %s." % present,
        "-- Absent: %s." % absent,
        "-- %d recipes; %d of the lines' spells have no reagent row in the build and are left out (the" % (
            stats["recipes"], stats["noReagents"]),
        "-- profession-window fallback learns those in game, spec §4.2 B).",
        "-- %d recipes are taught by an item (%d by more than one); the other %d are a trainer's." % (
            stats["taught"], stats["taughtByMore"], stats["recipes"] - stats["taught"]),
        "--",
        "-- NS.RecipeReagents.Get() answers { build, recipes, byReagent } on WoW Forever, built the first",
        "-- time it is asked, and the builder is then let go. On Retail (read once at load, NS.Compat.ClientKey)",
        "-- the builder is never even made, so Get() answers nil and nothing below is built (clients-§4).",
        "--   recipes[spell]  = { skillLine, skillLines?, min, yellow, gray, made?, name?, taught?, taughtBy?,",
        "--                       reagents = { [item] = count } }",
        "--   byReagent[item] = { spell, ... }, in this file's order (profession, then skill, then spell)",
        "-- skillLines is set only on a recipe two professions share. yellow and gray are",
        "-- TrivialSkillLineRankLow and TrivialSkillLineRankHigh; green is floor((yellow + gray) / 2).",
        "-- taught is the item that teaches the recipe (the lowest id; ItemEffect -> ItemXItemEffect), nil for",
        "-- a trainer's recipe; taughtBy lists every such item, set only when more than one teaches it.",
        "",
        "local RR = {}",
        "NS.RecipeReagents = RR",
        "",
        "local BUILD = %s" % lua_string(manifest["build"]),
        "",
        "-- The builder exists on WoW Forever alone: on Retail this chunk's code is let go after the load.",
        "local rows",
        "if NS.Compat.ClientKey() == \"forever\" then rows = function()",
        "    local recipes, byReagent = {}, {}",
        "    local function r(spell, skillLine, min, yellow, gray, made, name, taught, ...)",
        "        local reagents = {}",
        "        for i = 1, select(\"#\", ...), 2 do",
        "            local item, count = select(i, ...)",
        "            reagents[item] = count",
        "            local list = byReagent[item]",
        "            if not list then list = {}; byReagent[item] = list end",
        "            list[#list + 1] = spell",
        "        end",
        "        recipes[spell] = { skillLine = skillLine, min = min, yellow = yellow, gray = gray, made = made,",
        "            name = name, taught = taught, reagents = reagents }",
        "    end",
        "    local function shared(spell, ...)",
        "        recipes[spell].skillLines = { ... }",
        "    end",
        "    local function teachers(spell, ...)",
        "        recipes[spell].taughtBy = { ... }",
        "    end",
    ]
    order = sorted(recipes, key=lambda s: (list(PROFESSIONS).index(recipes[s]["skillLine"]), recipes[s]["min"], s))
    for line in PROFESSIONS:
        spells = [s for s in order if recipes[s]["skillLine"] == line]
        if not spells:
            continue
        out.append("    -- %s (%d): %d recipes" % (PROFESSIONS[line][0], line, len(spells)))
        out += pack([lua_row(s, recipes[s]) for s in spells], "    ")
    sharedRows = ["shared(%d, %s)" % (s, ", ".join(str(x) for x in recipes[s]["skillLines"]))
                  for s in order if len(recipes[s]["skillLines"]) > 1]
    if sharedRows:
        out.append("    -- recipes more than one profession teaches")
        out += pack(sharedRows, "    ")
    teachRows = ["teachers(%d, %s)" % (s, ", ".join(str(x) for x in recipes[s]["taught"]))
                 for s in order if len(recipes[s]["taught"]) > 1]
    if teachRows:
        out.append("    -- recipes more than one item teaches")
        out += pack(teachRows, "    ")
    out += [
        "    return recipes, byReagent",
        "end end",
        "",
        "local built",
        "",
        "-- The table, built once on the first call on WoW Forever (then the builder is let go); nil on Retail.",
        "function RR.Get()",
        "    if built == nil and rows then",
        "        local recipes, byReagent = rows()",
        "        built, rows = { build = BUILD, recipes = recipes, byReagent = byReagent }, nil",
        "    end",
        "    return built",
        "end",
        "",
    ]
    return "\n".join(out)


# ---------------------------------------------------------------------------
# The bundle
# ---------------------------------------------------------------------------

def format_sources(manifest: dict, bundle_rel: str) -> str:
    rows = "\n".join("| `%s` | %s | %s | %d | %d | `%s` | <%s> |" % (
        t["table"], t["why"], t["served"], t["rows"], t["extractRows"], t["sha256"], t["url"])
        for t in manifest["tables"])
    present = ", ".join("%d %s" % (line, PROFESSIONS[line][0]) for line in manifest["professions"]["present"])
    absent = ", ".join("%d %s" % (line, PROFESSIONS[line][0]) for line in manifest["professions"]["absent"]) or "none"
    s = manifest["stats"]
    return """# Sources — Drop Watcher recipe reagents, %(date)s (WoW Forever)

Generated by `tools/seeds/seeds.py recipes derive`. Frozen: this directory is never edited after the run, apart from the
hand-written `ANALYSIS.md`.

| Field | Value |
| --- | --- |
| Seed | recipe reagents (`%(output)s`, generated) |
| Product | `%(product)s` (WoW Forever) |
| Build | `%(build)s` |
| Date | %(date)s (the run's argument) |
| Extract sha256 | `%(sha)s` (the `Inputs:` line of the generated file's header) |
| Skill lines present | %(present)s |
| Skill lines absent | %(absent)s |
| Recipes | %(recipes)d (%(noReagents)d of the lines' %(spells)d spells have no reagent row and are left out) |
| Recipes making no item | %(makesNoItem)d (enchantments and the like) |
| Recipes two professions share | %(shared)d |
| Recipes an item teaches | %(taught)d (%(taughtByMore)d by more than one item); the other %(trainer)d are a trainer's |

## Tables

`Rows` and `sha256` are the whole table as served; `Extract` is the rows frozen into `raw/` (the professions' rows,
each table's header kept).

| Table | Why | Served | Rows | Extract | sha256 | URL |
| --- | --- | --- | --- | --- | --- | --- |
%(rows)s

`seeds.py recipes derive --replay --bundle %(bundle)s --date %(date)s` re-derives this bundle's manifest from `raw/`
offline; `seeds.py recipes apply --bundle %(bundle)s` regenerates `%(output)s` from it.
""" % {"date": manifest["date"], "output": OUTPUT, "product": PRODUCT, "build": manifest["build"],
       "sha": manifest["extractSha256"], "present": present, "absent": absent, "rows": rows, "bundle": bundle_rel,
       "recipes": s["recipes"], "noReagents": s["noReagents"], "spells": s["spells"],
       "makesNoItem": s["makesNoItem"], "shared": s["shared"], "taught": s["taught"],
       "taughtByMore": s["taughtByMore"], "trainer": s["recipes"] - s["taught"]}


def rel(path: Path, repo: Path) -> str:
    try:
        return path.resolve().relative_to(repo.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def derive(bundle: Path, date: str, build: str, replay: bool, cache_dir: Path, repo: Path) -> dict:
    tables = []
    if replay:
        texts = read_extract(bundle)
        old = json.loads((bundle / "MANIFEST.json").read_text(encoding="utf-8"))
        if old["build"] != build or old["date"] != date:
            raise SystemExit("--replay: the bundle is %s (%s), not %s (%s)." % (old["build"], old["date"], build, date))
        why = dict(TABLES)
        tables = [dict(t, why=why[t["table"]]) for t in old["tables"]]
    else:
        full = {}
        for table, why in TABLES:
            source, served = seeds.fetch_table(table, build, cache_dir)
            full[table] = read_rows(source)
            tables.append({"table": table, "why": why, "served": served or "cache", "rows": len(full[table][1]),
                           "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                           "url": seeds.CSV_URL.format(table=table, build=build)})
        texts = extract(full)
    rows = parse_extract(texts)
    professions = coverage(rows)
    model = build_model(rows)
    for t in tables:
        t["extractRows"] = len(rows[t["table"]])
    manifest = {"build": build, "date": date, "product": PRODUCT, "extractSha256": digest(texts),
                "professions": professions, "tables": tables,
                "stats": {k: v for k, v in model["stats"].items() if k != "perLine"},
                "perLine": {str(k): v for k, v in model["stats"]["perLine"].items()}}
    if not replay:
        for table, _why in TABLES:
            freeze_text(texts[table], bundle / "raw" / ("%s.csv.gz" % table))
    seeds.write_json(bundle / "MANIFEST.json", manifest)
    seeds.write_repo_text(bundle / "SOURCES.md", format_sources(manifest, rel(bundle, repo)))
    return manifest


def generate(bundle: Path, repo: Path) -> str:
    """The generator's output for `bundle`: the Lua text, LF-terminated."""
    manifest = json.loads((bundle / "MANIFEST.json").read_text(encoding="utf-8"))
    texts = read_extract(bundle)
    sha = digest(texts)
    if sha != manifest["extractSha256"]:
        raise SystemExit("%s: raw/ digests to %s, the manifest records %s." % (bundle, sha, manifest["extractSha256"]))
    rows = parse_extract(texts)
    if coverage(rows) != manifest["professions"]:
        raise SystemExit("%s: the extract's professions differ from the manifest's." % bundle)
    return render(build_model(rows), manifest, rel(bundle, repo))


def crosscheck(model: dict, sla: dict) -> dict:
    """Dev time only: compare each recipe's min, yellow and gray with ForeverDB's `sla[spell]` rows
    (`{skillLine, min, yellow, gray, ...}`, positions 1-4) and answer COUNTS and spell ids only.
    ForeverDB is GPL-3.0 evidence: nothing it holds is written into the repo (clients-§10)."""
    out = {"recipes": len(model["recipes"]), "inSla": 0, "match": 0, "minMatch": 0, "noLineRow": 0,
           "mismatch": []}
    for spell, r in sorted(model["recipes"].items()):
        rows = sla.get(str(spell)) or sla.get(spell)
        if not rows:
            continue
        out["inSla"] += 1
        row = next((x for x in rows if isinstance(x, list) and len(x) >= 4 and x[0] == r["skillLine"]), None)
        if row is None:
            out["noLineRow"] += 1
            continue
        if (row[2], row[3]) == (r["yellow"], r["gray"]):
            out["match"] += 1
        else:
            out["mismatch"].append(spell)
        if row[1] == r["min"]:
            out["minMatch"] += 1
    return out


def header_fields(text: str) -> dict[str, str]:
    out = {}
    for line in text.splitlines()[:20]:
        m = HEADER_RE.match(line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def check(repo: Path) -> tuple[bool, str]:
    """`(ok, message)`: does the shipped file equal the generator's output for its own bundle?"""
    path = repo / OUTPUT
    if not path.exists():
        return False, "%s is missing." % OUTPUT
    shipped = path.read_bytes().decode("utf-8").replace("\r\n", "\n")
    fields = header_fields(shipped)
    if "Bundle" not in fields:
        return False, "%s names no bundle in its header." % OUTPUT
    want = generate(repo / fields["Bundle"], repo)
    if shipped != want:
        return False, "%s differs from the generator's output for %s: regenerate it with `recipes apply`." % (
            OUTPUT, fields["Bundle"])
    return True, "OK %s (%s, %s)" % (OUTPUT, fields.get("Build"), fields["Bundle"])


# ---------------------------------------------------------------------------
# The CLI (seeds.py recipes <action>)
# ---------------------------------------------------------------------------

def add_parser(sub) -> None:
    rec = sub.add_parser("recipes", help="generate WoW Forever's recipe-reagent table (core/RecipeReagentsForever.lua)")
    acts = rec.add_subparsers(dest="action", required=True)
    acts.add_parser("status", help="is the live wowf build newer than the generated file's?")
    der = acts.add_parser("derive", help="freeze the extract and write MANIFEST.json and SOURCES.md")
    der.add_argument("--bundle", type=Path, required=True)
    der.add_argument("--date", type=seeds._date, required=True)
    der.add_argument("--build", help="pin this build instead of the live one")
    der.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    app = acts.add_parser("apply", help="write the Lua file from the bundle")
    app.add_argument("--bundle", type=Path, required=True)
    acts.add_parser("check", help="exit 1 unless the Lua file equals the generator's output")
    cross = acts.add_parser("crosscheck", help="dev time: counts of yellow/gray agreeing with ForeverDB's sla")
    cross.add_argument("--bundle", type=Path, required=True)
    cross.add_argument("--foreverdb", type=Path, required=True,
                       help="foreverdb.json from dev-copilot's scripts/foreverdb.py fetch (its cache folder)")


def main(args) -> int:
    repo = args.repo
    if args.action == "status":
        live = seeds.live_build(PRODUCT)
        path = repo / OUTPUT
        built = header_fields(path.read_text(encoding="utf-8")).get("Build") if path.exists() else None
        print(("CURRENT %s (%s)" if built == live else "NEW %s (generated from %s)") % (live, built or "nothing"))
        return 0
    if args.action == "derive":
        build = args.build
        if not build and args.replay:
            build = json.loads((args.bundle / "MANIFEST.json").read_text(encoding="utf-8"))["build"]
        build = build or seeds.live_build(PRODUCT)
        m = derive(args.bundle, args.date, build, args.replay, args.cache_dir, repo)
        s = m["stats"]
        print("derived %s: %d recipes (%d spells without reagents), lines %s, absent %s, extract %s" % (
            build, s["recipes"], s["noReagents"], m["professions"]["present"], m["professions"]["absent"],
            m["extractSha256"]))
        return 0
    if args.action == "apply":
        text = generate(args.bundle, repo)
        path = repo / OUTPUT
        old = path.read_bytes() if path.exists() else None
        seeds.write_repo_text(path, text)
        lines = text.count("\n")
        print("%s %s (%d lines)" % ("unchanged" if old == path.read_bytes() else "wrote", OUTPUT, lines))
        return 0
    if args.action == "crosscheck":
        sla = json.loads(args.foreverdb.read_text(encoding="utf-8")).get("sla") or {}
        model = build_model(parse_extract(read_extract(args.bundle)))
        c = crosscheck(model, sla)
        print("recipes %d, in sla %d, yellow+gray agree %d, min agrees %d, no row for the line %d, disagree %d%s" % (
            c["recipes"], c["inSla"], c["match"], c["minMatch"], c["noLineRow"], len(c["mismatch"]),
            (" (spells %s)" % ", ".join(str(s) for s in c["mismatch"][:20])) if c["mismatch"] else ""))
        return 0
    ok, msg = check(repo)
    print(msg)
    return 0 if ok else 1
