-- tests/test_collectibles.lua — modules/Collectibles.lua (issue #13, categories design spec §1,
-- §3.1, §3.2): CategoryOf for each category, its precedence and the classes it does not watch;
-- Verdict's new, collected, unknown, pet partial, recipe without the profession and whitelisted
-- answers; and Read, the edge that asks NS.Compat for the probes and the collection state.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- The client's 12.x numbers, which core/Constants.lua falls back to without Enum.
local ARMOR, WEAPON, RECIPE, MISC, CONSUMABLE, REAGENT_CLASS, CONTAINER = 4, 2, 9, 15, 0, 7, 1
local COSMETIC_SUB, MOUNT_SUB, PET_SUB, JUNK_SUB = 5, 5, 2, 0
local TAILORING_SUB, BOOK_SUB = 2, 0

local function CO() return (T.newAddon()).Collectibles end

-- ---------------------------------------------------------------------------------------------
-- CategoryOf
-- ---------------------------------------------------------------------------------------------

test("collectibles: CategoryOf names each category", function()
    local c = CO()
    assertEqual(c.CategoryOf({ classID = ARMOR, subClassID = 4 }), "equipment", "plate")
    assertEqual(c.CategoryOf({ classID = WEAPON, subClassID = 7 }), "equipment", "a sword")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = JUNK_SUB, isTierToken = true }), "tierToken")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = 4 }, { mountID = 9 }), "mount", "the journal")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = MOUNT_SUB }), "mount", "the class rung")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = 4 }, { speciesID = 3 }), "pet", "the journal")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = PET_SUB }), "pet", "the class rung")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = 4 }, { toy = true }), "toy")
    assertEqual(c.CategoryOf({ classID = RECIPE, subClassID = TAILORING_SUB }), "recipe")
    assertEqual(c.CategoryOf({ classID = ARMOR, subClassID = COSMETIC_SUB }), "cosmetic", "the subclass")
end)

test("collectibles: CategoryOf's precedence", function()
    local c = CO()
    -- red under: a check order that tests the gear class before the tier-token flag
    assertEqual(c.CategoryOf({ classID = ARMOR, subClassID = 4, isTierToken = true }), "tierToken",
        "a tier token beats equipment")
    assertEqual(c.CategoryOf({ classID = WEAPON, subClassID = 7 }, { cosmetic = true }), "cosmetic",
        "a cosmetic weapon is not equipment")
    assertEqual(c.CategoryOf({ classID = ARMOR, subClassID = COSMETIC_SUB }), "cosmetic",
        "cosmetic armor is not equipment")
    assertEqual(c.CategoryOf({ classID = ARMOR, subClassID = COSMETIC_SUB }, { toy = true }), "toy",
        "a toy flagged cosmetic stays a toy")
    assertEqual(c.CategoryOf({ classID = WEAPON, subClassID = 7 }, { cosmetic = true, mountID = 4 }), "mount",
        "a mount flagged cosmetic stays a mount")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = MOUNT_SUB }, { speciesID = 3 }), "mount",
        "mount before pet")
    assertEqual(c.CategoryOf({ classID = RECIPE, subClassID = 1 }, { toy = true }), "toy", "toy before recipe")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = 4 }, { cosmetic = true }), nil,
        "the cosmetic flag counts on armor and weapons only")
end)

test("collectibles: the out-of-scope classes are not watched", function()
    local c = CO()
    for _, f in ipairs({
        { classID = CONSUMABLE, subClassID = 0 }, { classID = REAGENT_CLASS, subClassID = 1 },
        { classID = MISC, subClassID = JUNK_SUB }, { classID = MISC, subClassID = JUNK_SUB, quality = 0 },
        { classID = MISC, subClassID = 6 }, { classID = 13, subClassID = 0 }, {},
    }) do
        assertNil(c.CategoryOf(f), "class " .. tostring(f.classID) .. "/" .. tostring(f.subClassID))
    end
    assertNil(c.CategoryOf(nil)); assertNil(c.CategoryOf("x"))
end)

test("collectibles: IsCollectible is true for the collectible categories alone", function()
    local c = CO()
    for _, key in ipairs({ "mount", "pet", "toy", "recipe", "cosmetic" }) do
        assertTrue(c.IsCollectible({ category = key }), key)
    end
    for _, key in ipairs({ "equipment", "tierToken" }) do
        assertFalse(c.IsCollectible({ category = key }), key)
    end
    assertFalse(c.IsCollectible({})); assertFalse(c.IsCollectible(nil))
end)

-- RX-04 (rolls UX design §3.5, ruling 3): a lockbox (Junk whose tooltip says it opens) and a bag
-- are the container kind; Junk that does not open, a reagent and a consumable are not, and a token
-- stays one.
-- red under: CategoryOf without the container rung, or one that takes every Junk item in
test("collectibles: a lockbox and a bag are containers; other Junk and a reagent are not", function()
    local c = CO()
    local junk = { classID = MISC, subClassID = JUNK_SUB, quality = 2 }
    assertEqual(c.CategoryOf(junk, { opens = "locked" }), "container", "a lockbox")
    assertEqual(c.CategoryOf(junk, { opens = "opens" }), "container", "a box that opens")
    assertEqual(c.CategoryOf({ classID = CONTAINER, subClassID = 0, quality = 2 }), "container", "a bag")
    assertNil(c.CategoryOf({ classID = MISC, subClassID = JUNK_SUB, quality = 4 }, { opens = false }), "an altar")
    assertNil(c.CategoryOf(junk), "not read")
    assertNil(c.CategoryOf({ classID = MISC, subClassID = 4 }, { opens = "opens" }), "Junk alone")
    assertNil(c.CategoryOf({ classID = REAGENT_CLASS, subClassID = 1, quality = 2 }), "a reagent")
    assertNil(c.CategoryOf({ classID = CONSUMABLE, subClassID = 0, quality = 2 }), "a potion")
    assertEqual(c.CategoryOf({ classID = MISC, subClassID = JUNK_SUB, isTierToken = true }, { opens = "opens" }),
        "tierToken")
    assertFalse(c.IsCollectible({ category = "container" })); assertFalse(c.IsCollectible({ category = "other" }))
end)

-- RX-04: a non-gear item's verdict is its kind word, never Unknown and never a gain.
-- red under: Verdict answering nil for a container (the gear kernel's Unknown then shows)
test("collectibles: a lockbox reads lockbox, a bag container, an item of no kind item; no gain", function()
    local c = CO()
    local v = c.Verdict({ category = "container", classID = MISC, subClassID = JUNK_SUB, lockbox = true })
    assertEqual(v.verdict, "lockbox"); assertTrue(v.collect); assertEqual(v.category, "container")
    assertNil(v.ilvlDelta); assertNil(v.scoreDelta)
    assertEqual(c.Verdict({ category = "container", classID = CONTAINER, quality = 2 }).verdict, "container")
    v = c.Verdict({ classID = REAGENT_CLASS, subClassID = 1, quality = 2 })
    assertEqual(v.verdict, "item"); assertEqual(v.category, "other"); assertTrue(v.collect)
    v = c.Verdict({ category = "container", classID = MISC, subClassID = JUNK_SUB, lockbox = true }, true)
    assertEqual(v.verdict, "lockbox"); assertEqual(v.reasons[#v.reasons].key, "whitelisted")
    -- RX-12 review fix (ruling 3: never Unknown): an Always watch item of a known class and no kind
    -- reads its kind word too, with the whitelisted reason; only one whose class is not read yet
    -- stays unknown (red under: the forced path answering unknown before the class was looked at).
    v = c.Verdict({ classID = REAGENT_CLASS, subClassID = 1 }, true)
    assertEqual(v.verdict, "item", "an Always watch reagent reads Item, never Unknown")
    assertEqual(v.category, "other"); assertEqual(v.reasons[#v.reasons].key, "whitelisted")
    assertEqual(c.Verdict({ itemID = 7 }, true).verdict, "unknown", "its class not read yet: unknown")
end)

-- ---------------------------------------------------------------------------------------------
-- Verdict
-- ---------------------------------------------------------------------------------------------

local function keys(eval)
    local out = {}
    for i, r in ipairs(eval.reasons) do out[i] = r.key end
    return table.concat(out, ",")
end

test("collectibles: Verdict reads new, collected and no answer", function()
    local c = CO()
    local v = c.Verdict({ category = "mount", collect = { kind = "mount", known = false } })
    assertEqual(v.verdict, "newCollect"); assertEqual(keys(v), "collectNew")
    assertEqual(v.equip, "collect"); assertTrue(v.collect); assertEqual(v.category, "mount")
    v = c.Verdict({ category = "toy", collect = { kind = "toy", known = true } })
    assertEqual(v.verdict, "collected"); assertEqual(keys(v), "collectKnown")
    v = c.Verdict({ category = "mount", collect = { kind = "mount" } })
    assertEqual(v.verdict, "collectUnknown"); assertEqual(keys(v), "collectNoAnswer")
    v = c.Verdict({ category = "recipe" })
    assertEqual(v.verdict, "collectUnknown", "no collect table at all")
end)

test("collectibles: a pet carries its count, and a partial collection says n/limit", function()
    local c = CO()
    local v = c.Verdict({ category = "pet", collect = { kind = "pet", known = true, count = 1, limit = 3 } })
    assertEqual(v.verdict, "collected"); assertEqual(v.count, 1); assertEqual(v.limit, 3)
    assertEqual(keys(v), "collectKnown,petPartial"); assertEqual(v.reasons[2].detail, "1/3")
    v = c.Verdict({ category = "pet", collect = { kind = "pet", known = true, count = 3, limit = 3 } })
    assertEqual(keys(v), "collectKnown", "a full collection is not partial")
    v = c.Verdict({ category = "pet", collect = { kind = "pet", known = false, count = 0, limit = 3 } })
    assertEqual(v.verdict, "newCollect"); assertEqual(keys(v), "collectNew")
end)

test("collectibles: a recipe for a profession you lack is can't use", function()
    local c = CO()
    local v = c.Verdict({ category = "recipe", collect = { kind = "recipe", known = false, skillLine = 197,
        hasProfession = false } })
    assertEqual(v.verdict, "cantUse"); assertEqual(keys(v), "notYourProfession")
    v = c.Verdict({ category = "recipe", collect = { kind = "recipe", known = false, skillLine = 197,
        hasProfession = true } })
    assertEqual(v.verdict, "newCollect")
    v = c.Verdict({ category = "recipe", collect = { kind = "recipe", known = true } })
    assertEqual(v.verdict, "collected", "a book: no profession checked")
end)

test("collectibles: a cosmetic reads its live transmogKnown", function()
    local c = CO()
    local f = { category = "cosmetic", collect = { kind = "cosmetic", known = false }, transmogKnown = true }
    assertEqual(c.Verdict(f).verdict, "collected", "the live flag, not the copy")
    f.transmogKnown = false
    assertEqual(c.Verdict(f).verdict, "newCollect")
    f.transmogKnown = nil
    assertEqual(c.Verdict(f).verdict, "collectUnknown")
end)

test("collectibles: whitelisted items get the whitelisted reason; gear and the rest answer nil", function()
    local c = CO()
    local v = c.Verdict({ category = "toy", collect = { known = false } }, true)
    assertEqual(v.verdict, "newCollect"); assertEqual(keys(v), "collectNew,whitelisted")
    v = c.Verdict({ itemID = 7 }, true)
    assertEqual(v.verdict, "unknown"); assertEqual(v.equip, "collect"); assertTrue(v.collect)
    assertEqual(keys(v), "whitelisted")
    assertEqual(c.Verdict({ itemID = 7 }).verdict, "item", "uncategorized, not forced: its kind word (RX-04)")
    assertNil(c.Verdict({ category = "equipment" }), "gear keeps the gear verdict")
    assertNil(c.Verdict({ category = "tierToken" }, false))
    assertNil(c.Verdict(nil))
end)

-- ---------------------------------------------------------------------------------------------
-- Read (the edge) through ItemFacts
-- ---------------------------------------------------------------------------------------------

local MOUNT  = "|cnIQ4:|Hitem:6001::::::::90:::::|h[Reins]|h|r"
local PET    = "|cnIQ3:|Hitem:6002::::::::90:::::|h[Cage]|h|r"
local TOY    = "|cnIQ3:|Hitem:6003::::::::90:::::|h[Toy]|h|r"
local PATTERN = "|cnIQ3:|Hitem:6004::::::::90:::::|h[Pattern]|h|r"
local LOOK   = "|cnIQ4:|Hitem:6005::::::::90:::::|h[Fancy Hat]|h|r"
local HELM   = "|cnIQ4:|Hitem:6006::::::::90:::::|h[Helm]|h|r"
local POTION = "|cnIQ1:|Hitem:6007::::::::90:::::|h[Potion]|h|r"

local function item(classID, subClassID, extra)
    local def = { name = "x", quality = 3, ilvl = 100, equipLoc = "", classID = classID, subClassID = subClassID,
        bindType = 1 }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

local function facts(seed)
    local NS, _, m = T.newAddon({ mock = seed })
    m.issecretvalue = function(v) return T.isSecret(v) end
    return NS.ItemFacts, m, NS
end

test("collectibles: Read fills a mount's, a pet's and a toy's collection state", function()
    local IF = facts(function(m)
        m.addItem(MOUNT, item(MISC, MOUNT_SUB)); m.mounts.byItem[6001] = 77; m.mounts.collected[77] = false
        m.addItem(PET, item(MISC, PET_SUB)); m.pets.byItem[6002] = 12; m.pets.counts[12] = { 1, 3 }
        m.addItem(TOY, item(CONSUMABLE, 8)); m.toys[6003] = true; m.toysOwned[6003] = true
    end)
    local f = IF.Get(MOUNT)
    assertEqual(f.category, "mount"); assertEqual(f.collect.kind, "mount")
    assertEqual(f.collect.mountID, 77); assertFalse(f.collect.known)
    f = IF.Get(PET)
    assertEqual(f.category, "pet"); assertEqual(f.collect.speciesID, 12)
    assertEqual(f.collect.count, 1); assertEqual(f.collect.limit, 3); assertTrue(f.collect.known)
    f = IF.Get(TOY)
    assertEqual(f.category, "toy"); assertTrue(f.collect.known)
end)

test("collectibles: Read fills a recipe's profession and known line", function()
    local IF, m, NS = facts(function(m)
        m.addItem(PATTERN, item(RECIPE, TAILORING_SUB))
        m.tooltips.hyperlink[PATTERN] = { lines = { { type = 0, leftText = "Already known" } } }
        m.professions = { 165, 171 }
    end)
    local f = IF.Get(PATTERN)
    assertEqual(f.category, "recipe"); assertEqual(f.collect.skillLine, 197)
    assertFalse(f.collect.hasProfession, "leatherworking and alchemy, not tailoring")
    assertTrue(f.collect.known)
    assertEqual(NS.Collectibles.Verdict(f).verdict, "cantUse")
    m.professions = {}
    -- red under: an empty profession set read as no answer, so a professionless alt read New
    assertFalse(IF.Read(PATTERN).collect.hasProfession, "no profession at all: not yours")
    assertEqual(NS.Collectibles.Verdict(IF.Read(PATTERN)).verdict, "cantUse")
    m.GetProfessions = nil
    assertNil(IF.Read(PATTERN).collect.hasProfession, "no answer: not claimed")
    m.items[PATTERN].subClassID = BOOK_SUB
    assertNil(IF.Read(PATTERN).collect.skillLine, "a book needs no profession")
end)

-- RX-04: the opens read is the lockbox's: Junk whose tooltip reads Locked is a lockbox, one reading
-- <Right Click to Open> a container, Junk with neither no kind; a reagent's tooltip is never read.
-- red under: Read not asking ItemOpens, or asking it of a class that is not Junk
test("collectibles: Read tells a lockbox and a box that opens from Junk that does not", function()
    local BOX, CRATE, ALTAR = "|cnIQ2:|Hitem:4632::::::::20:::::|h[Ornate Bronze Lockbox]|h|r",
        "|cnIQ2:|Hitem:6010::::::::20:::::|h[Crate]|h|r", "|cnIQ4:|Hitem:6011::::::::90:::::|h[Altar]|h|r"
    local CLOTH = "|cnIQ2:|Hitem:6012::::::::20:::::|h[Cloth]|h|r"
    local IF, m, NS = facts(function(m)
        m.addItem(BOX, item(MISC, JUNK_SUB, { quality = 2 }))
        m.addItem(CRATE, item(MISC, JUNK_SUB, { quality = 2 }))
        m.addItem(ALTAR, item(MISC, JUNK_SUB, { quality = 4 }))
        m.addItem(CLOTH, item(REAGENT_CLASS, 5, { quality = 2 }))
        m.tooltips.hyperlink[BOX] = { lines = { { type = 0, leftText = "Ornate Bronze Lockbox" }, { type = 0, leftText = "Locked" } } }
        m.tooltips.hyperlink[CRATE] = { lines = { { type = 0, leftText = "<Right Click to Open>" } } }
        m.tooltips.hyperlink[ALTAR] = { lines = { { type = 0, leftText = "Altar" } } }
        m.tooltips.hyperlink[CLOTH] = { lines = { { type = 0, leftText = "Locked" } } }
    end)
    local box = IF.Get(BOX)
    assertEqual(box.category, "container"); assertTrue(box.lockbox)
    assertEqual(NS.Collectibles.Verdict(box).verdict, "lockbox")
    local crate = IF.Get(CRATE)
    assertEqual(crate.category, "container"); assertNil(crate.lockbox)
    assertEqual(NS.Collectibles.Verdict(crate).verdict, "container")
    assertNil(IF.Get(ALTAR).category, "Junk that does not open has no kind")
    assertNil(IF.Get(CLOTH).category, "a reagent's tooltip is never read for it")
    assertEqual(NS.Collectibles.Verdict(IF.Get(CLOTH)).verdict, "item")
    m.LOCKED, m.ITEM_OPENABLE = nil, nil
    assertNil(IF.Read(BOX).category, "no GlobalString: not read, no kind claimed")
end)

test("collectibles: Read tells cosmetics from gear, and spends the probes only where they decide", function()
    local calls = {}
    local IF = facts(function(m)
        m.addItem(LOOK, item(ARMOR, 1, { equipLoc = "INVTYPE_HEAD", transmog = false })); m.cosmetic[LOOK] = true
        m.addItem(HELM, item(ARMOR, 4, { equipLoc = "INVTYPE_HEAD" }))
        m.addItem(POTION, item(CONSUMABLE, 1))
        local mj = m.C_MountJournal.GetMountFromItem
        m.C_MountJournal.GetMountFromItem = function(id) calls[#calls + 1] = id; return mj(id) end
    end)
    local f = IF.Get(LOOK)
    assertEqual(f.category, "cosmetic"); assertFalse(f.transmogKnown, "its appearance, not collected")
    assertNil(f.collect.known, "no copy of the appearance flag to go stale")
    assertEqual(IF.Get(HELM).category, "equipment")
    assertNil(IF.Get(POTION).category, "not watched"); assertNil(IF.Get(POTION).collect)
    -- red under: the mount probe asked for every item, plain gear included
    assertEqual(table.concat(calls, ","), "6005,6007", "the cosmetic and the potion; never the helm")
end)

test("collectibles: a cosmetic's verdict follows a learned appearance, with no stale copy", function()
    local IF, m, NS = facts(function(m)
        m.addItem(LOOK, item(ARMOR, COSMETIC_SUB, { equipLoc = "INVTYPE_HEAD", transmog = false }))
    end)
    local f = IF.Get(LOOK)
    assertEqual(NS.Collectibles.Verdict(f).verdict, "newCollect")
    m.items[LOOK].transmog = true
    NS.addon.OnTransmogCollectionUpdated()
    f = IF.Get(LOOK)
    assertTrue(f.transmogKnown); assertEqual(NS.Collectibles.Verdict(f).verdict, "collected")
    -- red under: Read copying transmogKnown into collect.known, which the event never refreshes
    assertNil(f.collect.known, "the state lives in transmogKnown alone")
end, T.RETAIL_ONLY)

test("collectibles: Read leaves a tier token's category to its flag and probes nothing", function()
    local asked = 0
    local IF = facts(function(m)
        m.addItem(HELM, item(MISC, JUNK_SUB))
        m.tooltips.hyperlink[HELM] = { lines = { { type = 21, leftText = "Classes: Warrior, Paladin" } } }
        m.C_ToyBox.GetToyInfo = function() asked = asked + 1 end
    end)
    local f = IF.Get(HELM)
    assertTrue(f.isTierToken); assertEqual(f.category, "tierToken"); assertNil(f.collect)
    assertEqual(asked, 0)
end)

test("collectibles: Read answers its argument and survives no facts", function()
    local c = CO()
    assertNil(c.Read(nil))
    local f = { classID = ARMOR, subClassID = 4, link = HELM, itemID = 6006 }
    assertTrue(c.Read(f) == f)
    assertEqual(f.category, "equipment")
end)
