#!/usr/bin/env python3
"""tools/seeds/test_seeds.py — seeds.py against tiny fixture tables, with no network.

Each case writes its own fixture repo (a small core/ClassData.lua or core/ClassDataForever.lua,
core/Constants.lua, modules/CollectCells.lua and core/ItemRead.lua, all CRLF like the real ones)
and fixture CSVs, frozen into a bundle's raw/ the way `derive` freezes them, and drives the CLI
through `--replay`. Run: python3 -m unittest discover -s tools/seeds (or pytest tools/seeds).

Mutation-checked: removing the unruled refusal from plan_apply makes
test_apply_refuses_while_unruled fail (checked 2026-11-15, then restored).
"""

from __future__ import annotations

import gzip
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import seeds  # noqa: E402

CONSTANTS = """local _, NS = ...
C.ITEM_CLASS = fromEnum(Enum.ItemClass, {
    WEAPON        = { "Weapon", 2 },
    ARMOR         = { "Armor", 4 },
})
C.MISC_SUBCLASS = fromEnum(Enum.ItemMiscellaneousSubclass, {
    JUNK            = { "Junk", 0 },
})
C.RECIPE_SUBCLASS = fromEnum(Enum.ItemRecipeSubclass, {
    LEATHERWORKING = { "Leatherworking", 1 },
})
local RS = C.RECIPE_SUBCLASS
C.RECIPE_SKILL_LINE = {
    [RS.LEATHERWORKING] = 165,
}
C.ARMOR_SUBCLASS = fromEnum(Enum.ItemArmorSubclass, {
    CLOTH    = { "Cloth", 1 },
})
C.WEAPON_SUBCLASS = fromEnum(Enum.ItemWeaponSubclass, {
    AXE_1H    = { "Axe1H", 0 },
    FIST      = { "Unarmed", 13 },
})
"""
COLLECT_CELLS = """local PROFESSION = {
    [165] = L["Leatherworking"],
}
"""
ITEM_READ = "IR.GEAR_CLASSES = { [2] = true, [4] = true }\n"

RETAIL_SEED = """local RETAIL = { STAT_GATE = "hard" }
RETAIL.CLASS_ID = {
    WARRIOR = 1, ROGUE = 4, MAGE = 8,
}
RETAIL.ARMOR = {
    WARRIOR = A.PLATE, ROGUE = A.LEATHER, MAGE = A.CLOTH,
}
-- a comment with a brace { that the block reader must skip
RETAIL.WEAPONS = {
    WARRIOR     = set(W.AXE_1H, W.SWORD_2H),
    ROGUE       = set(W.DAGGER, W.WAND),
    MAGE        = set(W.STAFF),
}
RETAIL.SPECS = {
    [71]   = spec("WARRIOR", STR),             -- Arms
    [72]   = spec("WARRIOR", STR, "DT"),       -- Fury
    [259]  = spec("ROGUE", AGI, "D"),          -- Mutilate
    [62]   = spec("MAGE", INT, "O"),           -- Arcane (the fixture's)
}
RETAIL.SPEC_INDEX = {
    [71] = 1, [72] = 2, [259] = 1, [62] = 1,
}
"""

FOREVER_SEED = """local FOREVER = { STAT_GATE = "soft", ARMOR_LOWER_OK = true, ARMOR_LEVEL = 40, PAWN_BY_TREE = true }
FOREVER.CLASS_ID = {
    WARRIOR = 1, ROGUE = 4, MAGE = 8,
}
FOREVER.ARMOR = {
    WARRIOR = A.PLATE, ROGUE = A.LEATHER, MAGE = A.CLOTH,
}
FOREVER.ARMOR_EARLY = { WARRIOR = A.MAIL }
FOREVER.WEAPONS = {
    WARRIOR = set(W.AXE_1H),
    ROGUE   = set(W.DAGGER),
    MAGE    = set(W.STAFF),
}
FOREVER.RELIC = { MAGE = A.IDOL }
FOREVER.SPECS = {
    ["WARRIOR:1"] = tree("WARRIOR", 1, STR, "DS"),        -- Arms
    ["ROGUE:1"]   = tree("ROGUE", 1, AGI, "D"),           -- Assassination
    ["MAGE:1"]    = tree("MAGE", 1, INT, "O"),            -- Arcane
    ["MAGE:2"]    = tree("MAGE", 2, INT, nil, 2, 3),      -- Flame: the fixture's
}
"""

SRCI_HEAD = "ID,SkillID,ClassMask,Flags,Availability,MinLevel,SkillTierID,RaceMasks_0,RaceMasks_1"


def srci(rows):
    """`(skill, classMask[, minLevel[, raceMask]])` -> SkillRaceClassInfo rows."""
    out = [SRCI_HEAD]
    for i, row in enumerate(rows, 1):
        skill, mask = row[0], row[1]
        level = row[2] if len(row) > 2 else 0
        race = row[3] if len(row) > 3 else -1
        out.append("%d,%d,%d,128,1,%d,0,%d,0" % (i, skill, mask, level, race))
    return "\n".join(out) + "\n"


SKILL_LINE = "DisplayName_lang,ID,CategoryID\n" + "\n".join(
    "%s,%d,6" % (name if "," not in name else '"%s"' % name, sid)
    for sid, (name, _k, _t, _f) in seeds.SKILL_LINES.items()) + "\nLeatherworking,165,11\n"
COMMON = {
    "SkillLine": SKILL_LINE,
    "SkillLineAbility": "ID,SkillLine,Spell,ClassMask\n1,173,1180,136\n",
    "ItemClass": "ID,ClassName_lang,ClassID\n3,Weapon,2\n5,Armor,4\n",
    "ItemSubClass": ("DisplayName_lang,VerboseName_lang,ID,ClassID,SubClassID\n"
                     "Axe,One-Handed Axes,1,2,0\nCloth,Cloth,2,4,1\nLeatherworking,,3,9,1\nJunk,,4,15,0\n"),
}
RETAIL_TABLES = dict(COMMON, **{
    "ChrClasses": "ID,Filename,ArmorTypeMask\n1,WARRIOR,113\n4,ROGUE,37\n8,MAGE,35\n",
    "ChrSpecialization": ("ID,ClassID,OrderIndex,Name_lang,PrimaryStatPriority\n71,1,0,Arms,5\n72,1,1,Fury,5\n"
                          "73,1,2,Protection,5\n259,4,0,Assassination,3\n62,8,0,Arcane,0\n1446,1,4,Initial,5\n"),
    "SkillRaceClassInfo": srci([(415, -1), (414, 9), (293, 1, 1), (44, 1), (55, 1), (43, 1), (173, 136), (136, 128),
                                (45, 8, 0, 0)]),
    "SpecializationSpells": "ID,SpecID,SpellID\n1,72,46917\n",
})
FOREVER_TABLES = dict(COMMON, **{
    "ChrClasses": "ID,Filename,ArmorTypeMask\n1,WARRIOR,127\n4,ROGUE,39\n8,MAGE,35\n",
    "ChrSpecialization": "ID,ClassID,OrderIndex,Name_lang,PrimaryStatPriority\n1491,1,0,Warrior,0\n1488,4,0,Rogue,0\n1482,8,0,Mage,0\n",
    "SkillRaceClassInfo": srci([(415, -1), (414, 9), (413, 1), (293, 1, 40), (44, 1), (43, 1), (173, 8), (136, 128),
                                (433, 1), (118, 1, 20), (118, 8, 10), (118, 128)]),
    "TalentTab": ("ID,Name_lang,OrderIndex,ClassMask\n161,Arms,0,1\n164,Fury,1,1\n182,Assassination,0,8\n"
                  "81,Arcane,0,128\n41,Fire,1,128\n"),
})
SEED_FILE = {"retail": (seeds.CLASS_DATA, RETAIL_SEED), "forever": (seeds.CLASS_DATA, FOREVER_SEED)}
BUILD = {"retail": "12.1.5.1", "forever": "1.60.1.1"}


def crlf(text: str) -> bytes:
    return text.replace("\n", "\r\n").encode("utf-8")


class Fixture:
    """A temporary repo, bundle and tool dir for one flavor."""

    def __init__(self, flavor: str, seed: str | None = None, tables: dict | None = None):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.flavor = flavor
        rel, default = SEED_FILE[flavor]
        files = {rel: seed or default, seeds.CONSTANTS: CONSTANTS, seeds.COLLECT_CELLS: COLLECT_CELLS,
                 seeds.ITEM_READ: ITEM_READ}
        for path, text in files.items():
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            (self.root / path).write_bytes(crlf(text))
        self.seed = self.root / rel
        self.bundle = self.root / "docs" / "seed-research" / ("2026-11-15-" + flavor)
        raw = self.bundle / "raw"
        raw.mkdir(parents=True)
        for table, text in (tables or (RETAIL_TABLES if flavor == "retail" else FOREVER_TABLES)).items():
            with gzip.open(raw / ("%s.csv.gz" % table), "wb") as handle:
                handle.write(crlf(text))
        self.tool = self.root / "tools" / "seeds"
        self.tool.mkdir(parents=True)

    def run(self, *argv) -> int:
        return seeds.main(["--repo", str(self.root), "--tool-dir", str(self.tool), *argv])

    def derive(self) -> dict:
        self.run("derive", "--flavor", self.flavor, "--bundle", str(self.bundle), "--date", "2026-11-15",
                 "--build", BUILD[self.flavor], "--replay")
        return seeds.load_doc(self.bundle)

    def rule(self, rows) -> None:
        tsv = self.root / "rulings.tsv"
        tsv.write_text("".join("%s\t%s\t%s\n" % row for row in rows), encoding="utf-8")
        self.run("rule", "--tsv", str(tsv), "--bundle", str(self.bundle))

    def close(self):
        self.tmp.cleanup()


def keys(doc, part):
    return sorted(row["key"] for row in doc[part])


class RetailDerive(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture("retail")
        self.doc = self.fx.derive()

    def tearDown(self):
        self.fx.close()

    def test_candidates(self):
        self.assertEqual(keys(self.doc, "candidates"),
                         ["spec:73", "weapon:MAGE:DAGGER", "weapon:WARRIOR:SWORD_1H"])

    def test_a_row_with_no_race_grants_nothing(self):
        self.assertNotIn("weapon:ROGUE:BOWS", keys(self.doc, "candidates"))

    def test_flags(self):
        self.assertEqual(keys(self.doc, "flags"),
                         ["shipped:enum:WEAPON_SUBCLASS:FIST", "shipped:spec-name:259",
                          "shipped:weapon-unlisted:ROGUE:WAND"])

    def test_witness_note(self):
        row = next(c for c in self.doc["candidates"] if c["key"] == "weapon:MAGE:DAGGER")
        self.assertIn("SkillLineAbility agrees", row["notes"])
        self.assertEqual(row["apply"], "weapons")

    def test_bundle_files_are_crlf(self):
        for name in ("candidates.json", "SOURCES.md"):
            data = (self.fx.bundle / name).read_bytes()
            self.assertEqual(data.count(b"\r\n"), data.count(b"\n"), name)

    def test_check_exits_1_until_ruled(self):
        bundle = str(self.fx.bundle)
        self.assertEqual(self.fx.run("check", "--bundle", bundle), 1)
        self.fx.rule([(k, "reject" if not k.startswith("shipped:") else "keep", "fixture") for k in seeds.all_keys(self.doc)])
        self.assertEqual(self.fx.run("check", "--bundle", bundle), 0)


class Apply(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture("retail")
        self.doc = self.fx.derive()
        self.base = [("weapon:WARRIOR:SWORD_1H", "accept", "fixture"), ("weapon:MAGE:DAGGER", "accept", "fixture"),
                     ("shipped:weapon-unlisted:ROGUE:WAND", "remove", "fixture"),
                     ("shipped:enum:WEAPON_SUBCLASS:FIST", "keep", "fixture"),
                     ("shipped:spec-name:259", "keep", "fixture")]

    def tearDown(self):
        self.fx.close()

    def apply(self) -> int:
        return self.fx.run("apply", "--bundle", str(self.fx.bundle), "--date", "2026-11-15")

    def test_apply_refuses_while_unruled(self):
        before = self.fx.seed.read_bytes()
        self.fx.rule(self.base)  # spec:73 left unruled
        with self.assertRaises(SystemExit) as ctx:
            self.apply()
        self.assertIn("unruled", str(ctx.exception))
        self.assertEqual(self.fx.seed.read_bytes(), before)

    def test_apply_refuses_an_owed_hand_edit(self):
        self.fx.rule(self.base + [("spec:73", "accept", "fixture")])
        with self.assertRaises(SystemExit) as ctx:
            self.apply()
        self.assertIn("hand edit is owed for spec:73", str(ctx.exception))

    def test_apply_never_writes_the_vendored_library(self):
        before = self.fx.seed.read_bytes()
        self.fx.rule(self.base + [("spec:73", "reject", "fixture")])
        with self.assertRaises(SystemExit) as ctx:
            self.apply()
        self.assertIn("never writes under libs/", str(ctx.exception))
        self.assertEqual(self.fx.seed.read_bytes(), before)

    def test_apply_writes_weapons_keeps_crlf_and_is_idempotent(self):
        # The mechanism, on a seed file of the repo's own (the class lists are vendored here now).
        own = dict(seeds.FLAVORS["retail"], seed="core/ClassData.lua")
        self.fx.seed = self.fx.root / own["seed"]
        self.fx.seed.parent.mkdir(parents=True, exist_ok=True)
        self.fx.seed.write_bytes(crlf(RETAIL_SEED))
        saved = seeds.FLAVORS["retail"]
        seeds.FLAVORS["retail"] = own
        self.addCleanup(seeds.FLAVORS.__setitem__, "retail", saved)
        self.fx.rule(self.base + [("spec:73", "reject", "fixture")])
        self.apply()
        data = self.fx.seed.read_bytes()
        self.assertEqual(data.count(b"\r\n"), data.count(b"\n"))
        text = data.decode("utf-8")
        self.assertIn("    WARRIOR     = set(W.AXE_1H, W.SWORD_2H, W.SWORD_1H),\r\n", text)
        self.assertIn("    ROGUE       = set(W.DAGGER),\r\n", text)
        self.assertIn("    MAGE        = set(W.STAFF, W.DAGGER),\r\n", text)
        self.assertIn("[71]   = spec(\"WARRIOR\", STR),             -- Arms\r\n", text, "the rest is untouched")
        self.apply()
        self.assertEqual(self.fx.seed.read_bytes(), data, "a second apply changes nothing")
        redo = self.fx.derive()
        self.assertEqual(keys(redo, "candidates"), ["spec:73"], "applied ids are no longer proposed")


class Rulings(unittest.TestCase):
    def test_remove_only_for_a_weapon_flag(self):
        with self.assertRaises(SystemExit):
            seeds.set_ruling({}, "shipped:spec-name:259", "remove", "x")
        rulings = {}
        seeds.set_ruling(rulings, "shipped:weapon-unlisted:ROGUE:WAND", "remove", "x")
        self.assertEqual(rulings["shipped:weapon-unlisted:ROGUE:WAND"]["ruling"], "remove")

    def test_bad_rulings(self):
        for key, ruling, reason in (("weapon:ROGUE:BOWS", "keep", "x"), ("shipped:enum:X:Y", "accept", "x"),
                                    ("weapon:ROGUE:BOWS", "accept", " "), ("not a key", "accept", "x")):
            with self.assertRaises(SystemExit, msg=key):
                seeds.set_ruling({}, key, ruling, reason)

    def test_rule_refuses_a_key_the_bundle_lacks(self):
        fx = Fixture("retail")
        try:
            fx.derive()
            with self.assertRaises(SystemExit):
                fx.rule([("weapon:MAGE:BOWS", "reject", "fixture")])
        finally:
            fx.close()


class ForeverDerive(unittest.TestCase):
    def test_candidates_and_flags(self):
        fx = Fixture("forever")
        try:
            doc = fx.derive()
            self.assertEqual(keys(doc, "candidates"), ["dualWield:MAGE", "tree:WARRIOR:2", "weapon:WARRIOR:SWORD_1H"])
            self.assertEqual(keys(doc, "flags"), ["shipped:enum:WEAPON_SUBCLASS:FIST", "shipped:relic:MAGE",
                                                  "shipped:tree-name:MAGE:2"])
        finally:
            fx.close()

    def test_the_level_switch(self):
        seed = FOREVER_SEED.replace("ARMOR_LEVEL = 40", "ARMOR_LEVEL = 30").replace(
            "FOREVER.ARMOR_EARLY = { WARRIOR = A.MAIL }", "FOREVER.ARMOR_EARLY = {}")
        fx = Fixture("forever", seed=seed)
        try:
            doc = fx.derive()
            self.assertIn("armorEarly:WARRIOR", keys(doc, "candidates"))
            self.assertIn("shipped:armor-level:WARRIOR", keys(doc, "flags"))
        finally:
            fx.close()


class Gate(unittest.TestCase):
    def test_a_missing_sentinel_class_stops_the_run(self):
        tables = dict(RETAIL_TABLES, ChrClasses="ID,Filename,ArmorTypeMask\n4,ROGUE,37\n8,MAGE,35\n")
        fx = Fixture("retail", tables=tables)
        try:
            with self.assertRaises(SystemExit) as ctx:
                fx.derive()
            self.assertIn("Coverage gate FAILED", str(ctx.exception))
        finally:
            fx.close()

    def test_a_renamed_skill_line_stops_the_run(self):
        tables = dict(RETAIL_TABLES, SkillLine=SKILL_LINE.replace("Daggers,173", "Knives,173"))
        fx = Fixture("retail", tables=tables)
        try:
            with self.assertRaises(SystemExit):
                fx.derive()
        finally:
            fx.close()


class Pieces(unittest.TestCase):
    def test_class_masks(self):
        db = seeds.Build.__new__(seeds.Build)
        db.classes = {1: "WARRIOR", 4: "ROGUE", 8: "MAGE"}
        self.assertEqual(db.classes_of(-1), ["WARRIOR", "ROGUE", "MAGE"])
        self.assertEqual(db.classes_of(9), ["WARRIOR", "ROGUE"])
        self.assertEqual(db.classes_of(-17), ["WARRIOR", "ROGUE", "MAGE"])

    def test_enum_names(self):
        self.assertTrue(seeds.enum_names_match("FIST", "Unarmed", ["Fist Weapon", "Fist Weapons"]))
        self.assertTrue(seeds.enum_names_match("AXE_2H", "Axe2H", ["Axe", "Two-Handed Axes"]))
        self.assertTrue(seeds.enum_names_match("GENERIC", "Generic", ["Miscellaneous", ""]))
        self.assertTrue(seeds.enum_names_match("COMPANION_PET", "CompanionPet", ["Companion Pets", ""]))
        self.assertFalse(seeds.enum_names_match("COMPANION_PET", "CompanionPet", ["Pet", ""]))

    def test_wrap(self):
        lines = seeds.format_set("    ", "HUNTER", "      ", ["AXE_1H", "AXE_2H", "BOWS", "GUNS", "CROSSBOW", "POLEARM",
                                                             "SWORD_1H", "SWORD_2H", "STAFF", "FIST", "DAGGER"])
        self.assertTrue(all(len(line) <= seeds.WRAP for line in lines))
        self.assertEqual(len(lines), 2)
        self.assertTrue(lines[1].startswith(" " * len("    HUNTER      = set(") + "W."))
        self.assertTrue(lines[-1].endswith("W.DAGGER),"))

    def test_status_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(seeds.status_line("1.0", []), "NEW 1.0 (no bundle yet)")
            bundle = root / "2026-11-15-retail"
            bundle.mkdir()
            (bundle / "candidates.json").write_text(json.dumps({"build": "1.0"}), encoding="utf-8")
            found = seeds.bundles("retail", root)
            self.assertEqual(seeds.status_line("1.0", found), "CURRENT 1.0 (2026-11-15-retail)")
            self.assertTrue(seeds.status_line("2.0", found).startswith("NEW 2.0 (last ruled 1.0"))

    def test_the_real_seed_files_parse(self):
        repo = HERE.parent.parent
        retail = seeds.read_class_data(repo / seeds.CLASS_DATA, "RETAIL")
        forever = seeds.read_class_data(repo / seeds.CLASS_DATA, "FOREVER")
        self.assertEqual(len(retail["SPECS"]), len(retail["SPEC_INDEX"]))
        self.assertEqual(set(retail["CLASS_ID"]), set(retail["WEAPONS"]))
        self.assertEqual(set(forever["CLASS_ID"]), set(forever["WEAPONS"]))
        self.assertEqual(forever["ARMOR_LEVEL"], 40)
        enums = seeds.read_enums(repo / seeds.CONSTANTS, repo / seeds.COLLECT_CELLS, repo / seeds.ITEM_READ)
        self.assertEqual(set(enums["RECIPE_SKILL_LINE"].values()), set(enums["PROFESSION"]))


if __name__ == "__main__":
    unittest.main()
