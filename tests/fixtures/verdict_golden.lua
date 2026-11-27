-- tests/fixtures/verdict_golden.lua — the golden verdict table (Item Search split plan, task A1).
--
-- TODAY'S "my verdict on this item" engine, pinned as plain data before any of it moves into
-- LibKa0s-Verdict-1.0: tests/test_verdict_golden.lua drives Drop Watcher's current seams over it,
-- and the library's own golden suite (plan tasks B1, B2) ports this file UNCHANGED, so the same
-- table pins both sides. Characterization: every expected value is what the engine answers now,
-- not what it ought to answer; a surprise is recorded here, never fixed in this table's task.
--
-- PURE DATA. No addon namespace, no client call, no function a reader must call: the suites turn
-- the declarative fields below into each side's own calls. Item classes, subclasses, qualities and
-- slot ids are the client's own numbers (Enum.ItemClass, Enum.ItemArmorSubclass, INVSLOT_*), the
-- same on Retail and WoW Forever for every slot used here.
--
-- cases: the kernel half, one judgment of plain facts for a plain candidate.
--   { name, client = "retail" | "forever"   the class list the case is written against
--     profile = nil | "retail" | "forever"  the kit profile it runs on alone (a client-gated module)
--     via = "evaluate" (default) | "collect"  NS.Evaluate.Evaluate, or NS.Collectibles.Verdict
--     facts, candidate, opts, forced (collect only),
--     expect = { verdict, reasonKeys = { key, ... } (in order), fields = { field = value },
--                details = { [key] = detail }, offSpec = { field = value }, none = true } }
--   candidate.offSpecGear, when present, is DATA: { [specID] = gear }, answered as the kernel's
--   offSpecGear(specID). opts.scorer is DATA:
--     { kind = "table", scores = { [itemID] = number | "pending" } }  a scorer answering by item
--     { kind = "weights", weights = { [specKey] = { STAT_KEY = weight } } }  the Weights adapter
--
-- me: the read half, a link judged end to end as "my verdict" (NS.ItemFacts.Get, then
-- NS.LootFeed.JudgeMe on Drop Watcher; the instance's Judge in the library).
--   { name, client = "retail" | "forever" (the kit profile it runs on), link,
--     setup = { class, classFile, specID, level, talents = { { name, spent } } (forever),
--               items = { [link] = def }, worn = { [slot] = link }, bags = { [bag] = { [slot] = link } },
--               settings = { [path] = value }, tooltips = { [link] = data }, mounts = { byItem, collected },
--               pawn = { values = { [scale] = { [link] = n } }, upgrades = { [link] = list } }, forced },
--     expect = { verdict, reasonKeys, fields, offSpec } }
--   An item `def` is the mock item cache's shape (name, quality, ilvl, equipLoc, classID,
--   subClassID, bindType, stats, specs).

-- The client's numbers.
local ARMOR, WEAPON, MISC, RECIPE = 4, 2, 15, 9
local CLOTH, LEATHER, PLATE, GENERIC, SHIELD = 1, 2, 4, 0, 6
local SWORD_1H = 7
local JUNK, MOUNT, PET = 0, 5, 2
local HEIRLOOM = 7
local HEAD, SHOULDER, CHEST, LEGS, HANDS = 1, 3, 5, 7, 10
local FINGER1, FINGER2, MAINHAND, OFFHAND = 11, 12, 16, 17
local STR, AGI, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT"

-- An item's facts as the kernel takes them; `over` replaces or adds fields.
local function item(itemID, ilvl, equipLoc, classID, subClassID, over)
    local f = { itemID = itemID, ilvl = ilvl, equipLoc = equipLoc, classID = classID, subClassID = subClassID,
        quality = 4 }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

local function plate(itemID, ilvl, equipLoc, over) return item(itemID, ilvl, equipLoc or "INVTYPE_HEAD", ARMOR, PLATE, over) end
local function cloth(itemID, ilvl, equipLoc, over) return item(itemID, ilvl, equipLoc or "INVTYPE_HEAD", ARMOR, CLOTH, over) end

-- A candidate; `gear` is { [slot] = facts | false }.
local function who(classFile, specID, gear, over)
    local c = { classFile = classFile, specID = specID, gear = gear }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

-- A worn plate helm at 600 (item 900), the baseline most cases judge against.
local function helm600(over) return { [HEAD] = plate(900, 600, "INVTYPE_HEAD", over) } end

-- Retail's Arms warrior (71) and Forever's warrior (class-wide spec 1491, Arms tree, level 60).
local function arms(gear, over) return who("WARRIOR", 71, gear or helm600(), over) end
local function fWarrior(gear, over)
    local o = { tree = 1, level = 60 }
    for k, v in pairs(over or {}) do o[k] = v end
    return who("WARRIOR", 1491, gear or helm600(), o)
end

local function scores(t) return { kind = "table", scores = t } end

local cases = {
    -- ── the four compared verdicts and the band (Retail, ilvlFirst) ───────────────────────────
    { name = "upgrade: a plate helm 10 levels over the worn one", client = "retail",
      facts = plate(1001, 610), candidate = arms(), opts = {},
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { equip = "ok", ilvlDelta = 10, baselineSlot = HEAD } } },
    { name = "downgrade: a plate helm 10 levels under", client = "retail",
      facts = plate(1001, 590), candidate = arms(), opts = {},
      expect = { verdict = "downgrade", reasonKeys = {}, fields = { ilvlDelta = -10 } } },
    { name = "sidegrade: equal item level", client = "retail",
      facts = plate(1001, 600), candidate = arms(), opts = {},
      expect = { verdict = "sidegrade", reasonKeys = {}, fields = { ilvlDelta = 0 } } },
    { name = "sidegrade: at the band's edge (+10, band 10)", client = "retail",
      facts = plate(1001, 610), candidate = arms(), opts = { sidegradeBand = 10 },
      expect = { verdict = "sidegrade", reasonKeys = {}, fields = { band = 10 } } },
    { name = "upgrade: one past the band's edge (+11, band 10)", client = "retail",
      facts = plate(1001, 611), candidate = arms(), opts = { sidegradeBand = 10 },
      expect = { verdict = "upgrade", reasonKeys = {} } },
    { name = "downgrade: one past the band's lower edge (-11, band 10)", client = "retail",
      facts = plate(1001, 589), candidate = arms(), opts = { sidegradeBand = 10 },
      expect = { verdict = "downgrade", reasonKeys = {} } },
    { name = "upgrade: an empty slot", client = "retail",
      facts = plate(1001, 500), candidate = arms({ [HEAD] = false }), opts = {},
      expect = { verdict = "upgrade", reasonKeys = { "emptySlot" }, fields = { baselineSlot = HEAD } } },
    { name = "upgrade: a ring against the lower of two worn rings", client = "retail",
      facts = item(1002, 630, "INVTYPE_FINGER", ARMOR, GENERIC),
      candidate = arms({ [FINGER1] = item(901, 640, "INVTYPE_FINGER", ARMOR, GENERIC),
          [FINGER2] = item(902, 620, "INVTYPE_FINGER", ARMOR, GENERIC) }), opts = {},
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { baselineSlot = FINGER2, ilvlDelta = 10, either = true } } },

    -- ── what cannot be compared ───────────────────────────────────────────────────────────────
    { name = "cantUse: plate for a mage", client = "retail",
      facts = plate(1001, 610), candidate = who("MAGE", 64, { [HEAD] = cloth(903, 600) }), opts = {},
      expect = { verdict = "cantUse", reasonKeys = { "armorType" }, fields = { equip = "cant" } } },
    { name = "cantUse: an intellect plate helm for Arms (primary stat)", client = "retail",
      facts = plate(1001, 610, nil, { stats = { [INT] = 50 } }), candidate = arms(), opts = {},
      expect = { verdict = "cantUse", reasonKeys = { "primaryStat" } } },
    { name = "cantUse: the item's class list leaves the warrior out", client = "retail",
      facts = plate(1001, 610, nil, { classes = { PALADIN = true } }), candidate = arms(), opts = {},
      expect = { verdict = "cantUse", reasonKeys = { "classRestricted" } } },
    { name = "doesntWant: plate is on Arms' undesired list", client = "retail",
      facts = plate(1001, 610), candidate = arms(nil, { prefs = { undesired = { ["4:4"] = true } } }), opts = {},
      expect = { verdict = "doesntWant", reasonKeys = { "undesired" }, fields = { equip = "doesntWant" } } },
    { name = "unknown: the slot was never read", client = "retail",
      facts = plate(1001, 610), candidate = arms({}), opts = {},
      expect = { verdict = "unknown", reasonKeys = { "noBaseline" } } },
    { name = "unknown: a tabard is not gear", client = "retail",
      facts = item(1003, 610, "INVTYPE_TABARD", ARMOR, GENERIC), candidate = arms(), opts = {},
      expect = { verdict = "unknown", reasonKeys = { "notGear" } } },
    { name = "unknown: no item level", client = "retail",
      facts = plate(1001, nil), candidate = arms(), opts = {},
      expect = { verdict = "unknown", reasonKeys = { "noIlvl" } } },
    { name = "unknown: facts that are not a table", client = "retail",
      facts = false, candidate = arms(), opts = {},
      expect = { verdict = "unknown", reasonKeys = { "badFacts" }, fields = { equip = "unknown" } } },

    -- ── the scorer under ilvlFirst (Retail) ───────────────────────────────────────────────────
    { name = "ilvlFirst: item level and score agree", client = "retail",
      facts = plate(1001, 610), candidate = arms(), opts = { scorer = scores({ [1001] = 110, [900] = 100 }) },
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { scoreDelta = 10, ilvlDelta = 10 } } },
    { name = "ilvlFirst: the score disagrees, a sidegrade", client = "retail",
      facts = plate(1001, 610), candidate = arms(), opts = { scorer = scores({ [1001] = 90, [900] = 100 }) },
      expect = { verdict = "sidegrade", reasonKeys = { "scoreDisagrees" }, fields = { scoreDelta = -10 } } },
    { name = "ilvlFirst: Pawn pending, item level alone with scorePending", client = "retail",
      facts = plate(1001, 610), candidate = arms(), opts = { scorer = scores({ [1001] = "pending", [900] = 100 }) },
      expect = { verdict = "upgrade", reasonKeys = { "scorePending" } } },
    { name = "ilvlFirst: the weights scorer values strength", client = "retail",
      facts = plate(1001, 610, nil, { stats = { [STR] = 120 } }),
      candidate = arms(helm600({ stats = { [STR] = 100 } })),
      opts = { scorer = { kind = "weights", weights = { [71] = { [STR] = 1 } } } },
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { scoreDelta = 20 } } },

    -- ── scoreFirst (WoW Forever) ──────────────────────────────────────────────────────────────
    { name = "scoreFirst: the score decides over a lower item level", client = "forever",
      facts = plate(1001, 595), candidate = fWarrior(),
      opts = { verdictMode = "scoreFirst", scorer = scores({ [1001] = 120, [900] = 100 }) },
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { led = "score", scoreDelta = 20, ilvlDelta = -5 } } },
    { name = "scoreFirst: a tie within 1% falls to item level", client = "forever",
      facts = plate(1001, 595), candidate = fWarrior(),
      opts = { verdictMode = "scoreFirst", scorer = scores({ [1001] = 100.5, [900] = 100 }) },
      expect = { verdict = "downgrade", reasonKeys = {}, fields = { led = "ilvl" } } },
    { name = "scoreFirst: no score, item level with noScore", client = "forever",
      facts = plate(1001, 610), candidate = fWarrior(), opts = { verdictMode = "scoreFirst" },
      expect = { verdict = "upgrade", reasonKeys = { "noScore" }, fields = { led = "ilvl" } } },
    { name = "scoreFirst: Pawn pending, scorePending and noScore", client = "forever",
      facts = plate(1001, 610), candidate = fWarrior(),
      opts = { verdictMode = "scoreFirst", scorer = scores({ [1001] = "pending", [900] = 100 }) },
      expect = { verdict = "upgrade", reasonKeys = { "scorePending", "noScore" }, fields = { led = "ilvl" } } },
    { name = "scoreFirst: the weights scorer by talent tree", client = "forever",
      facts = plate(1001, 595, nil, { stats = { [STR] = 30 } }),
      candidate = fWarrior(helm600({ stats = { [STR] = 20 } })),
      opts = { verdictMode = "scoreFirst", scorer = { kind = "weights", weights = { ["WARRIOR:1"] = { [STR] = 1 } } } },
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { led = "score", scoreDelta = 10 } } },
    { name = "forever: an intellect plate helm passes the soft stat gate", client = "forever",
      facts = plate(1001, 610, nil, { stats = { [INT] = 50 } }), candidate = fWarrior(), opts = { verdictMode = "scoreFirst" },
      expect = { verdict = "upgrade", reasonKeys = { "noScore" } } },
    -- A refusal answers before the score is weighed, so no noScore rides it (as found, A1).
    { name = "forever: plate below level 40 is cantUse (armorLevel)", client = "forever",
      facts = plate(1001, 610), candidate = fWarrior(nil, { level = 30 }), opts = { verdictMode = "scoreFirst" },
      expect = { verdict = "cantUse", reasonKeys = { "armorLevel" } } },

    -- ── owned items, heirlooms ────────────────────────────────────────────────────────────────
    { name = "compareOwned on: a better helm in the bags is the baseline", client = "retail",
      facts = plate(1001, 610), candidate = arms(nil, { owned = { [HEAD] = plate(904, 620) } }),
      opts = { compareOwned = true },
      expect = { verdict = "downgrade", reasonKeys = {}, fields = { ilvlDelta = -10 } } },
    { name = "compareOwned off: the bags are not read", client = "retail",
      facts = plate(1001, 610), candidate = arms(nil, { owned = { [HEAD] = plate(904, 620) } }),
      opts = { compareOwned = false },
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { ilvlDelta = 10 } } },
    { name = "heirloomProtect on: an upgrade over an heirloom reads as a sidegrade", client = "retail",
      facts = plate(1001, 610), candidate = arms(helm600({ quality = HEIRLOOM })), opts = { heirloomProtect = true },
      expect = { verdict = "sidegrade", reasonKeys = { "heirloomProtected" } } },
    { name = "heirloomProtect off: the upgrade stands", client = "retail",
      facts = plate(1001, 610), candidate = arms(helm600({ quality = HEIRLOOM })), opts = { heirloomProtect = false },
      expect = { verdict = "upgrade", reasonKeys = {} } },

    -- ── tier tokens ───────────────────────────────────────────────────────────────────────────
    { name = "tier token: an omni token folds to its best tier slot", client = "retail",
      facts = item(1004, 620, "", MISC, 0, { isTierToken = true, tokenSlot = "any", classes = { WARRIOR = true } }),
      candidate = arms({ [HEAD] = plate(905, 615), [SHOULDER] = plate(906, 615, "INVTYPE_SHOULDER"),
          [CHEST] = plate(907, 600, "INVTYPE_CHEST"), [HANDS] = plate(908, 610, "INVTYPE_HAND"),
          [LEGS] = plate(909, 619, "INVTYPE_LEGS") }), opts = { scorer = scores({ [1004] = 1 }) },
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { tokenSlot = "INVTYPE_CHEST", ilvlDelta = 20 } } },
    { name = "tier token: another class's token is cantUse", client = "retail",
      facts = item(1004, 620, "INVTYPE_HEAD", MISC, 0, { isTierToken = true, tokenSlot = "INVTYPE_HEAD",
          classes = { MAGE = true } }),
      candidate = arms(), opts = {},
      expect = { verdict = "cantUse", reasonKeys = { "classRestricted" } } },

    -- ── a group candidate (Inspect-shaped: another player, their spec and gear) ───────────────
    { name = "group: a looter's upgrade over their inspected chest", client = "retail",
      facts = cloth(1005, 620, "INVTYPE_CHEST"),
      candidate = who("PRIEST", 256, { [CHEST] = cloth(910, 615, "INVTYPE_CHEST") }, { isPlayer = false }), opts = {},
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { ilvlDelta = 5, baselineSlot = CHEST } } },
    { name = "group: the item's spec list leaves the looter's spec out", client = "retail",
      facts = cloth(1005, 620, "INVTYPE_CHEST", { specs = { [257] = true }, specsClass = "PRIEST" }),
      candidate = who("PRIEST", 256, { [CHEST] = cloth(910, 615, "INVTYPE_CHEST") }, { isPlayer = false }), opts = {},
      expect = { verdict = "cantUse", reasonKeys = { "specList" } } },

    -- ── off-spec (Retail's alone: the module initializes on Retail) ───────────────────────────
    { name = "off-spec: a shield Fury cannot use is an upgrade for Protection", client = "retail", profile = "retail",
      facts = item(1006, 610, "INVTYPE_SHIELD", ARMOR, SHIELD),
      candidate = who("WARRIOR", 72, { [MAINHAND] = item(911, 600, "INVTYPE_WEAPON", WEAPON, SWORD_1H),
          [OFFHAND] = item(912, 600, "INVTYPE_WEAPON", WEAPON, SWORD_1H) }, {
          offSpecGear = { [71] = { [MAINHAND] = item(911, 600, "INVTYPE_WEAPON", WEAPON, SWORD_1H), [OFFHAND] = false },
              [73] = { [MAINHAND] = item(911, 600, "INVTYPE_WEAPON", WEAPON, SWORD_1H),
                  [OFFHAND] = item(913, 590, "INVTYPE_SHIELD", ARMOR, SHIELD) } } }), opts = {},
      expect = { verdict = "cantUse", reasonKeys = { "shield" },
          offSpec = { specID = 73, mainSpecID = 72, verdict = "upgrade", ilvlDelta = 20 } } },

    -- ── collectibles and the kind words (NS.Collectibles.Verdict) ─────────────────────────────
    { name = "collect: a mount not yet learned is newCollect", client = "retail", via = "collect",
      facts = { itemID = 2001, classID = MISC, subClassID = MOUNT, category = "mount", collect = { kind = "mount", known = false } },
      expect = { verdict = "newCollect", reasonKeys = { "collectNew" }, fields = { equip = "collect", category = "mount" } } },
    { name = "collect: a known mount is collected", client = "retail", via = "collect",
      facts = { itemID = 2001, classID = MISC, subClassID = MOUNT, category = "mount", collect = { kind = "mount", known = true } },
      expect = { verdict = "collected", reasonKeys = { "collectKnown" } } },
    { name = "collect: a pet with no answer yet is collectUnknown", client = "retail", via = "collect",
      facts = { itemID = 2002, classID = MISC, subClassID = PET, category = "pet", collect = { kind = "pet" } },
      expect = { verdict = "collectUnknown", reasonKeys = { "collectNoAnswer" } } },
    { name = "collect: a pet held 1 of 3 is collected, petPartial", client = "retail", via = "collect",
      facts = { itemID = 2002, classID = MISC, subClassID = PET, category = "pet",
          collect = { kind = "pet", known = true, count = 1, limit = 3 } },
      expect = { verdict = "collected", reasonKeys = { "collectKnown", "petPartial" }, details = { petPartial = "1/3" },
          fields = { count = 1, limit = 3 } } },
    { name = "collect: a recipe of a profession you lack is cantUse", client = "retail", via = "collect",
      facts = { itemID = 2003, classID = RECIPE, subClassID = 1, category = "recipe",
          collect = { kind = "recipe", known = false, hasProfession = false } },
      expect = { verdict = "cantUse", reasonKeys = { "notYourProfession" } } },
    { name = "collect: an appearance not learned is newCollect", client = "retail", via = "collect",
      facts = { itemID = 2004, classID = ARMOR, subClassID = 5, category = "cosmetic", transmogKnown = false,
          collect = { kind = "cosmetic" } },
      expect = { verdict = "newCollect", reasonKeys = { "collectNew" } } },
    { name = "collect: a whitelisted known mount adds whitelisted", client = "retail", via = "collect", forced = true,
      facts = { itemID = 2001, classID = MISC, subClassID = MOUNT, category = "mount", collect = { kind = "mount", known = true } },
      expect = { verdict = "collected", reasonKeys = { "collectKnown", "whitelisted" } } },
    { name = "collect: a lockbox answers its kind word", client = "retail", via = "collect",
      facts = { itemID = 2005, classID = MISC, subClassID = JUNK, category = "lockbox" },
      expect = { verdict = "lockbox", reasonKeys = { "notGear" }, fields = { category = "lockbox", equip = "collect" } } },
    { name = "collect: a whitelisted lockbox adds whitelisted", client = "forever", via = "collect", forced = true,
      facts = { itemID = 2005, classID = MISC, subClassID = JUNK, category = "lockbox" },
      expect = { verdict = "lockbox", reasonKeys = { "notGear", "whitelisted" } } },
    { name = "collect: an item of no kind is item, category other", client = "retail", via = "collect",
      facts = { itemID = 2006, classID = MISC, subClassID = 4 },
      expect = { verdict = "item", reasonKeys = { "notGear" }, fields = { category = "other" } } },
    { name = "collect: gear has no collection verdict", client = "retail", via = "collect",
      facts = plate(1001, 610, nil, { category = "equipment" }),
      expect = { none = true } },
    { name = "collect: a forced item whose class is not read is unknown", client = "forever", via = "collect", forced = true,
      facts = { itemID = 2007 },
      expect = { verdict = "unknown", reasonKeys = { "whitelisted" }, fields = { equip = "collect" } } },
}

-- ── the read half ─────────────────────────────────────────────────────────────────────────────

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

-- A mock item-cache definition; `over` replaces or adds fields.
local function def(equipLoc, ilvl, classID, subClassID, over)
    local d = { name = "Item", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = classID,
        subClassID = subClassID, bindType = 1, stats = {} }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local function leather(ilvl, over) return def("INVTYPE_HEAD", ilvl, ARMOR, LEATHER, over) end
local function plateDef(ilvl, over) return def("INVTYPE_HEAD", ilvl, ARMOR, PLATE, over) end

-- A Retail Outlaw rogue (260) wearing a leather helm at 600 (item 3000), the drop `drop` (item
-- 3001) in the cache; `extra` adds setup fields.
local function rogue(drop, extra)
    local s = { class = "Rogue", classFile = "ROGUE", specID = 260, level = 80,
        items = { [link(3000)] = leather(600, { stats = { [AGI] = 80 } }), [link(3001)] = drop },
        worn = { [HEAD] = link(3000) }, settings = { ["comparison.scorer"] = "none" } }
    for k, v in pairs(extra or {}) do
        if k == "items" or k == "settings" then
            for kk, vv in pairs(v) do s[k][kk] = vv end
        else
            s[k] = v
        end
    end
    return s
end

-- A WoW Forever warrior at level `level` (60) in the Arms tree, wearing a plate helm at 60 (item
-- 3100), the drop (item 3101) in the cache.
local function warrior(drop, extra, level)
    local s = { class = "Warrior", classFile = "WARRIOR", specID = 1491, level = level or 60,
        talents = { { name = "Arms", spent = 31 }, { name = "Fury", spent = 5 }, { name = "Protection", spent = 0 } },
        items = { [link(3100)] = plateDef(60, { stats = { [STR] = 20 } }), [link(3101)] = drop },
        worn = { [HEAD] = link(3100) }, settings = { ["comparison.scorer"] = "none" } }
    for k, v in pairs(extra or {}) do
        if k == "items" or k == "settings" then
            for kk, vv in pairs(v) do s[k][kk] = vv end
        else
            s[k] = v
        end
    end
    return s
end

local me = {
    -- ── Retail ────────────────────────────────────────────────────────────────────────────────
    { name = "retail: a leather helm over the worn one is an upgrade", client = "retail", link = link(3001),
      setup = rogue(leather(610)),
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { ilvlDelta = 10, baselineSlot = HEAD } } },
    { name = "retail: a plate helm is cantUse for a rogue", client = "retail", link = link(3001),
      setup = rogue(plateDef(610)),
      expect = { verdict = "cantUse", reasonKeys = { "armorType" } } },
    { name = "retail: the weights scorer disagrees, a sidegrade", client = "retail", link = link(3001),
      setup = rogue(leather(610, { stats = { [AGI] = 50 } }), { settings = { ["comparison.scorer"] = "weights",
          ["comparison.weights"] = { [260] = { [AGI] = 1 } } } }),
      expect = { verdict = "sidegrade", reasonKeys = { "scoreDisagrees" }, fields = { scoreDelta = -30 } } },
    { name = "retail: compareOwned reads the better helm in the bags", client = "retail", link = link(3001),
      setup = rogue(leather(610), { items = { [link(3002)] = leather(620) }, bags = { [0] = { [1] = link(3002) } },
          settings = { ["comparison.compareOwned"] = true } }),
      expect = { verdict = "downgrade", reasonKeys = {}, fields = { ilvlDelta = -10 } } },
    { name = "retail: leather on the spec's undesired list is doesntWant", client = "retail", link = link(3001),
      setup = rogue(leather(610), { settings = { ["comparison.undesired"] = { [260] = { ["4:2"] = true } } } }),
      expect = { verdict = "doesntWant", reasonKeys = { "undesired" } } },
    { name = "retail: an upgrade over a worn heirloom is a sidegrade (the default protects)", client = "retail",
      link = link(3001),
      setup = rogue(leather(610), { items = { [link(3000)] = leather(600, { quality = HEIRLOOM }) } }),
      expect = { verdict = "sidegrade", reasonKeys = { "heirloomProtected" } } },
    { name = "retail: Pawn ready but the drop unread, scorePending", client = "retail", link = link(3001),
      setup = rogue(leather(610), { settings = { ["comparison.scorer"] = "pawn" }, pawn = { values = {}, upgrades = {} } }),
      expect = { verdict = "upgrade", reasonKeys = { "scorePending" } } },
    { name = "retail: Pawn values the drop and the helm on the drop's best scale", client = "retail", link = link(3001),
      setup = rogue(leather(610), { settings = { ["comparison.scorer"] = "pawn" },
          pawn = { values = { Dps = { [link(3001)] = 90, [link(3000)] = 100 } },
              upgrades = { [link(3001)] = { { ScaleName = "Dps", PercentUpgrade = 0.1 } } } } }),
      expect = { verdict = "sidegrade", reasonKeys = { "scoreDisagrees" }, fields = { scoreDelta = -10 } } },
    { name = "retail: a mount not yet learned is newCollect", client = "retail", link = link(3003),
      setup = rogue(leather(610), { items = { [link(3003)] = def("", 1, MISC, MOUNT, { quality = 3 }) },
          mounts = { byItem = { [3003] = 77 }, collected = { [77] = false } } }),
      expect = { verdict = "newCollect", reasonKeys = { "collectNew" }, fields = { category = "mount" } } },
    { name = "retail: a box that reads Locked is a lockbox", client = "retail", link = link(3004),
      setup = rogue(leather(610), { items = { [link(3004)] = def("", 1, MISC, JUNK, { quality = 1 }) },
          tooltips = { [link(3004)] = { lines = { { type = 0, leftText = "Locked" } } } } }),
      expect = { verdict = "lockbox", reasonKeys = { "notGear" } } },
    { name = "retail: off-spec, a shield Fury cannot use is an upgrade for Protection", client = "retail",
      link = link(3201),
      setup = { class = "Warrior", classFile = "WARRIOR", specID = 72, level = 80,
          items = { [link(3200)] = def("INVTYPE_WEAPON", 600, WEAPON, SWORD_1H, { stats = { [STR] = 10 } }),
              [link(3202)] = def("INVTYPE_WEAPON", 600, WEAPON, SWORD_1H, { stats = { [STR] = 10 } }),
              [link(3201)] = def("INVTYPE_SHIELD", 610, ARMOR, SHIELD) },
          worn = { [MAINHAND] = link(3200), [OFFHAND] = link(3202) }, settings = { ["comparison.scorer"] = "none" } },
      expect = { verdict = "cantUse", reasonKeys = { "shield" }, offSpec = { specID = 73, verdict = "upgrade" } } },

    -- ── WoW Forever ───────────────────────────────────────────────────────────────────────────
    { name = "forever: a plate helm over the worn one, no score: item level, noScore", client = "forever",
      link = link(3101), setup = warrior(plateDef(65)),
      expect = { verdict = "upgrade", reasonKeys = { "noScore" }, fields = { led = "ilvl", ilvlDelta = 5 } } },
    { name = "forever: the weights scorer decides over a lower item level", client = "forever", link = link(3101),
      setup = warrior(plateDef(55, { stats = { [STR] = 30 } }), { settings = { ["comparison.scorer"] = "weights",
          ["comparison.weights"] = { ["WARRIOR:1"] = { [STR] = 1 } } } }),
      expect = { verdict = "upgrade", reasonKeys = {}, fields = { led = "score", scoreDelta = 10, ilvlDelta = -5 } } },
    { name = "forever: Pawn ready but the drop unread, scorePending", client = "forever", link = link(3101),
      setup = warrior(plateDef(65), { settings = { ["comparison.scorer"] = "pawn" }, pawn = { values = {}, upgrades = {} } }),
      expect = { verdict = "upgrade", reasonKeys = { "scorePending", "noScore" }, fields = { led = "ilvl" } } },
    -- As the kernel half: a refusal carries no noScore.
    { name = "forever: plate at level 30 is cantUse (armorLevel)", client = "forever", link = link(3101),
      setup = warrior(plateDef(65), nil, 30),
      expect = { verdict = "cantUse", reasonKeys = { "armorLevel" } } },
    { name = "forever: a box that reads Locked is a lockbox", client = "forever", link = link(3104),
      setup = warrior(plateDef(65), { items = { [link(3104)] = def("", 1, MISC, JUNK, { quality = 1 }) },
          tooltips = { [link(3104)] = { lines = { { type = 0, leftText = "Locked" } } } } }),
      expect = { verdict = "lockbox", reasonKeys = { "notGear" } } },
}

return { cases = cases, me = me }
