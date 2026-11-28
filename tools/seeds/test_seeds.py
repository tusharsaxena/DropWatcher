#!/usr/bin/env python3
"""tools/seeds/test_seeds.py — seeds.py against tiny fixture tables, with no network.

Each case writes its own fixture repo (a small core/Constants.lua and modules/CollectCells.lua,
CRLF like the real ones) and fixture CSVs, frozen into a bundle's raw/ the way `derive` freezes
them, and drives the CLI through `--replay`. Run: python3 -m unittest discover -s tools/seeds (or
pytest tools/seeds). The class-list half moved to LibKa0s's tools/seeds/classseeds.py with its
cases (LibKa0s#109).

Mutation-checked: removing the unruled refusal from plan_apply makes
test_apply_refuses_while_unruled fail (checked 2026-11-15 and again 2026-11-28, then restored).
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
SKILL_LINE = "DisplayName_lang,ID,CategoryID\nBlacksmithing,164,11\nTailoring,197,11\nLeatherworking,165,11\n"
TABLES = {
    "SkillLine": SKILL_LINE,
    "ItemClass": "ID,ClassName_lang,ClassID\n3,Weapon,2\n5,Armor,4\n",
    "ItemSubClass": ("DisplayName_lang,VerboseName_lang,ID,ClassID,SubClassID\n"
                     "Axe,One-Handed Axes,1,2,0\nCloth,Cloth,2,4,1\nLeatherworking,,3,9,1\nJunk,,4,15,0\n"),
}
BUILD = {"retail": "12.1.5.1", "forever": "1.60.1.1"}


def crlf(text: str) -> bytes:
    return text.replace("\n", "\r\n").encode("utf-8")


class Fixture:
    """A temporary repo, bundle and tool dir for one flavor."""

    def __init__(self, flavor: str, tables: dict | None = None):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.flavor = flavor
        files = {seeds.CONSTANTS: CONSTANTS, seeds.COLLECT_CELLS: COLLECT_CELLS}
        for path, text in files.items():
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            (self.root / path).write_bytes(crlf(text))
        self.seed = self.root / seeds.CONSTANTS
        self.bundle = self.root / "docs" / "seed-research" / ("2026-11-15-" + flavor)
        raw = self.bundle / "raw"
        raw.mkdir(parents=True)
        for table, text in (tables or TABLES).items():
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

    def test_flags_and_no_candidates(self):
        self.assertEqual(keys(self.doc, "flags"), ["shipped:enum:WEAPON_SUBCLASS:FIST"])
        self.assertEqual(self.doc["candidates"], [])
        self.assertEqual(self.doc["seedFiles"], [seeds.CONSTANTS, seeds.COLLECT_CELLS])

    def test_bundle_files_are_crlf(self):
        for name in ("candidates.json", "SOURCES.md"):
            data = (self.fx.bundle / name).read_bytes()
            self.assertEqual(data.count(b"\r\n"), data.count(b"\n"), name)

    def test_check_exits_1_until_ruled(self):
        bundle = str(self.fx.bundle)
        self.assertEqual(self.fx.run("check", "--bundle", bundle), 1)
        self.fx.rule([(k, "keep", "fixture") for k in seeds.all_keys(self.doc)])
        self.assertEqual(self.fx.run("check", "--bundle", bundle), 0)


class ForeverDerive(unittest.TestCase):
    def test_the_same_checks_on_the_forever_product(self):
        fx = Fixture("forever")
        try:
            doc = fx.derive()
            self.assertEqual(doc["product"], "wowf")
            self.assertEqual(keys(doc, "flags"), ["shipped:enum:WEAPON_SUBCLASS:FIST"])
        finally:
            fx.close()


class Apply(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture("retail")
        self.doc = self.fx.derive()

    def tearDown(self):
        self.fx.close()

    def apply(self) -> int:
        return self.fx.run("apply", "--bundle", str(self.fx.bundle), "--date", "2026-11-15")

    def test_apply_refuses_while_unruled(self):
        before = self.fx.seed.read_bytes()
        with self.assertRaises(SystemExit) as ctx:
            self.apply()
        self.assertIn("unruled", str(ctx.exception))
        self.assertEqual(self.fx.seed.read_bytes(), before)

    def test_apply_refuses_an_owed_hand_edit(self):
        self.fx.rule([("shipped:enum:WEAPON_SUBCLASS:FIST", "fix", "fixture")])
        with self.assertRaises(SystemExit) as ctx:
            self.apply()
        self.assertIn("hand edit is owed for shipped:enum:WEAPON_SUBCLASS:FIST", str(ctx.exception))

    def test_apply_once_ruled_writes_nothing(self):
        before = self.fx.seed.read_bytes()
        self.fx.rule([("shipped:enum:WEAPON_SUBCLASS:FIST", "keep", "fixture")])
        self.assertEqual(self.apply(), 0)
        self.assertEqual(self.fx.seed.read_bytes(), before)


class Rulings(unittest.TestCase):
    def test_bad_rulings(self):
        for key, ruling, reason in (("shipped:enum:X:Y", "accept", "x"), ("shipped:enum:X:Y", "remove", "x"),
                                    ("shipped:enum:X:Y", "keep", " "), ("weapon:ROGUE:BOWS", "keep", "x"),
                                    ("not a key", "keep", "x")):
            with self.assertRaises(SystemExit, msg=key):
                seeds.set_ruling({}, key, ruling, reason)

    def test_rule_refuses_a_key_the_bundle_lacks(self):
        fx = Fixture("retail")
        try:
            fx.derive()
            with self.assertRaises(SystemExit):
                fx.rule([("shipped:enum:ITEM_CLASS:NOPE", "keep", "fixture")])
        finally:
            fx.close()


class Gate(unittest.TestCase):
    def test_a_missing_sentinel_item_class_stops_the_run(self):
        tables = dict(TABLES, ItemClass="ID,ClassName_lang,ClassID\n3,Weapon,2\n")
        fx = Fixture("retail", tables=tables)
        try:
            with self.assertRaises(SystemExit) as ctx:
                fx.derive()
            self.assertIn("Coverage gate FAILED", str(ctx.exception))
        finally:
            fx.close()

    def test_a_renamed_skill_line_stops_the_run(self):
        tables = dict(TABLES, SkillLine=SKILL_LINE.replace("Tailoring,197", "Clothworking,197"))
        fx = Fixture("retail", tables=tables)
        try:
            with self.assertRaises(SystemExit):
                fx.derive()
        finally:
            fx.close()


class Pieces(unittest.TestCase):
    def test_enum_names(self):
        self.assertTrue(seeds.enum_names_match("FIST", "Unarmed", ["Fist Weapon", "Fist Weapons"]))
        self.assertTrue(seeds.enum_names_match("AXE_2H", "Axe2H", ["Axe", "Two-Handed Axes"]))
        self.assertTrue(seeds.enum_names_match("GENERIC", "Generic", ["Miscellaneous", ""]))
        self.assertTrue(seeds.enum_names_match("COMPANION_PET", "CompanionPet", ["Companion Pets", ""]))
        self.assertFalse(seeds.enum_names_match("COMPANION_PET", "CompanionPet", ["Pet", ""]))

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
        enums = seeds.read_enums(repo / seeds.CONSTANTS, repo / seeds.COLLECT_CELLS)
        self.assertEqual(set(enums["RECIPE_SKILL_LINE"].values()), set(enums["PROFESSION"]))


if __name__ == "__main__":
    unittest.main()
