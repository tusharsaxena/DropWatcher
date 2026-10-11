-- tests/test_evaluate.lua — modules/Evaluate.lua, the pure verdict kernel (design spec §5): every
-- equip location and slot plan, dual wield and Titan's Grip, the off hand against a two-hander,
-- unique redirection, empty slots, the spec-unknown fallback to ClassData, preferences, the
-- sidegrade band, the scorer, the track delta, and that no input ever makes it throw.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local cached
local function load()
    if not cached then
        local NS = T.newAddon()
        cached = { E = NS.Evaluate, C = NS.Constants, CD = NS.ClassData }
    end
    return cached.E, cached.C, cached.CD
end

local _, C0 = load()
local S, A, W, IC = C0.SLOT, C0.ARMOR_SUBCLASS, C0.WEAPON_SUBCLASS, C0.ITEM_CLASS
local STR, AGI, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT"

-- An item's facts; `over` replaces or adds fields.
local function item(ilvl, equipLoc, classID, subClassID, over)
    local f = { itemID = 1000, ilvl = ilvl, equipLoc = equipLoc, classID = classID, subClassID = subClassID }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

local function weapon(ilvl, equipLoc, sub, over) return item(ilvl, equipLoc, IC.WEAPON, sub, over) end
local function armor(ilvl, equipLoc, sub, over) return item(ilvl, equipLoc, IC.ARMOR, sub, over) end

-- A full set of equipped gear: each slot at 600 + its slot id, a one-hand sword in each hand.
local function fullGear()
    local g = {}
    for _, slot in pairs(S) do g[slot] = armor(600 + slot, "INVTYPE_HEAD", A.PLATE) end
    g[S.SHIRT], g[S.TABARD] = nil, nil
    g[S.MAINHAND] = weapon(600 + S.MAINHAND, "INVTYPE_WEAPON", W.SWORD_1H)
    g[S.OFFHAND] = weapon(600 + S.OFFHAND, "INVTYPE_WEAPON", W.SWORD_1H)
    return g
end

local function who(classFile, specID, over)
    local c = { classFile = classFile, specID = specID, gear = fullGear() }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

local function hasReason(res, key)
    for _, r in ipairs(res.reasons or {}) do
        if r.key == key then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- Slot plans
-- ---------------------------------------------------------------------------------------------

test("evaluate: every equip location in SLOT_PLAN compares against its slot", function()
    local E, C = load()
    -- { equipLoc, facts, candidate, baselineSlot, baselineIlvl }
    local plate = function(loc) return armor(650, loc, A.PLATE) end
    local cases = {
        { "INVTYPE_HEAD", plate("INVTYPE_HEAD"), who("WARRIOR", 71), S.HEAD, 601 },
        { "INVTYPE_NECK", armor(650, "INVTYPE_NECK", A.GENERIC), who("MAGE", 64), S.NECK, 602 },
        { "INVTYPE_SHOULDER", plate("INVTYPE_SHOULDER"), who("WARRIOR", 71), S.SHOULDER, 603 },
        { "INVTYPE_CHEST", plate("INVTYPE_CHEST"), who("WARRIOR", 71), S.CHEST, 605 },
        { "INVTYPE_ROBE", plate("INVTYPE_ROBE"), who("WARRIOR", 71), S.CHEST, 605 },
        { "INVTYPE_WAIST", plate("INVTYPE_WAIST"), who("WARRIOR", 71), S.WAIST, 606 },
        { "INVTYPE_LEGS", plate("INVTYPE_LEGS"), who("WARRIOR", 71), S.LEGS, 607 },
        { "INVTYPE_FEET", plate("INVTYPE_FEET"), who("WARRIOR", 71), S.FEET, 608 },
        { "INVTYPE_WRIST", plate("INVTYPE_WRIST"), who("WARRIOR", 71), S.WRIST, 609 },
        { "INVTYPE_HAND", plate("INVTYPE_HAND"), who("WARRIOR", 71), S.HANDS, 610 },
        { "INVTYPE_CLOAK", armor(650, "INVTYPE_CLOAK", A.CLOTH), who("WARRIOR", 71), S.BACK, 615 },
        { "INVTYPE_FINGER", armor(650, "INVTYPE_FINGER", A.GENERIC), who("ROGUE", 259), S.FINGER1, 611 },
        { "INVTYPE_TRINKET", armor(650, "INVTYPE_TRINKET", A.GENERIC), who("ROGUE", 259), S.TRINKET1, 613 },
        { "INVTYPE_WEAPON", weapon(650, "INVTYPE_WEAPON", W.SWORD_1H), who("WARRIOR", 71), S.MAINHAND, 616 },
        { "INVTYPE_WEAPONMAINHAND", weapon(650, "INVTYPE_WEAPONMAINHAND", W.MACE_1H), who("PRIEST", 256),
            S.MAINHAND, 616 },
        { "INVTYPE_WEAPONOFFHAND", weapon(650, "INVTYPE_WEAPONOFFHAND", W.SWORD_1H), who("WARRIOR", 72),
            S.OFFHAND, 617 },
        { "INVTYPE_SHIELD", armor(650, "INVTYPE_SHIELD", A.SHIELD), who("WARRIOR", 73), S.OFFHAND, 617 },
        { "INVTYPE_HOLDABLE", armor(650, "INVTYPE_HOLDABLE", A.GENERIC), who("MAGE", 64), S.OFFHAND, 617 },
        { "INVTYPE_2HWEAPON", weapon(650, "INVTYPE_2HWEAPON", W.SWORD_2H), who("WARRIOR", 71), S.MAINHAND,
            616.5 },
        { "INVTYPE_RANGED", weapon(650, "INVTYPE_RANGED", W.BOWS), who("HUNTER", 254), S.MAINHAND, 616.5 },
        { "INVTYPE_RANGEDRIGHT", weapon(650, "INVTYPE_RANGEDRIGHT", W.WAND), who("PRIEST", 256), S.MAINHAND,
            616 },
    }
    local seen = 0
    for _, row in ipairs(cases) do
        local loc = row[1]
        assertTrue(C.SLOT_PLAN[loc] ~= nil, loc .. " has a plan")
        local res = E.Evaluate(row[2], row[3])
        assertEqual(res.equip, "ok", loc .. " equip")
        assertEqual(res.verdict, "upgrade", loc .. " verdict")
        assertEqual(res.baselineSlot, row[4], loc .. " baselineSlot")
        assertEqual(res.ilvlDelta, 650 - row[5], loc .. " ilvlDelta")
        assertTrue(res.baseline ~= nil, loc .. " baseline")
        seen = seen + 1
    end
    local plans = 0
    for _ in pairs(C.SLOT_PLAN) do plans = plans + 1 end
    assertEqual(seen, plans, "every SLOT_PLAN entry has a case")
end)

test("evaluate: an equip location with no plan is unknown (not gear)", function()
    local E = load()
    local res = E.Evaluate(armor(650, "INVTYPE_TABARD", A.GENERIC), who("WARRIOR", 71))
    assertEqual(res.verdict, "unknown")
    assertTrue(hasReason(res, "notGear"))
end)

test("evaluate: pair compares against the lower of the two slots", function()
    local E = load()
    local c = who("MAGE", 64)
    c.gear[S.FINGER1] = armor(640, "INVTYPE_FINGER", A.GENERIC)
    c.gear[S.FINGER2] = armor(620, "INVTYPE_FINGER", A.GENERIC)
    local res = E.Evaluate(armor(630, "INVTYPE_FINGER", A.GENERIC), c)
    assertEqual(res.baselineSlot, S.FINGER2)
    assertEqual(res.ilvlDelta, 10)
    assertEqual(res.verdict, "upgrade")
    c.gear[S.TRINKET1] = armor(700, "INVTYPE_TRINKET", A.GENERIC)
    c.gear[S.TRINKET2] = armor(690, "INVTYPE_TRINKET", A.GENERIC)
    res = E.Evaluate(armor(680, "INVTYPE_TRINKET", A.GENERIC), c)
    assertEqual(res.baselineSlot, S.TRINKET2)
    assertEqual(res.verdict, "downgrade")
end)

test("evaluate: an empty slot is an upgrade with the emptySlot reason", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = false
    local res = E.Evaluate(armor(500, "INVTYPE_HEAD", A.PLATE), c)
    assertEqual(res.verdict, "upgrade")
    assertTrue(hasReason(res, "emptySlot"))
    assertEqual(res.baselineSlot, S.HEAD)
    assertNil(res.baseline)
    assertNil(res.ilvlDelta)
    -- In a pair, an empty slot wins over the other being unknown.
    c.gear[S.FINGER1], c.gear[S.FINGER2] = nil, false
    res = E.Evaluate(armor(500, "INVTYPE_FINGER", A.GENERIC), c)
    assertEqual(res.verdict, "upgrade")
    assertEqual(res.baselineSlot, S.FINGER2)
end)

test("evaluate: a slot that is not known is unknown, never an upgrade", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = nil
    local res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE), c)
    assertEqual(res.verdict, "unknown")
    assertTrue(hasReason(res, "noBaseline"))
    c.gear[S.FINGER1] = nil
    res = E.Evaluate(armor(650, "INVTYPE_FINGER", A.GENERIC), c)
    assertEqual(res.verdict, "unknown")
    -- No gear table at all: an un-inspected candidate.
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE), { classFile = "WARRIOR", specID = 71 })
    assertEqual(res.verdict, "unknown")
    assertEqual(res.equip, "ok")
    -- A slot entry with no ilvl is not a baseline.
    c.gear[S.HEAD] = { equipLoc = "INVTYPE_HEAD" }
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE), c)
    assertEqual(res.verdict, "unknown")
end)

test("evaluate: a one-hander compares against the main hand only, unless the candidate dual wields", function()
    local E = load()
    local sword = weapon(630, "INVTYPE_WEAPON", W.SWORD_1H)
    local c = who("WARRIOR", 71)
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPON", W.SWORD_1H)
    c.gear[S.OFFHAND] = weapon(610, "INVTYPE_WEAPON", W.SWORD_1H)
    local res = E.Evaluate(sword, c)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.verdict, "downgrade")
    -- Fury dual wields (from its spec): the lower hand.
    c.specID = 72
    res = E.Evaluate(sword, c)
    assertEqual(res.baselineSlot, S.OFFHAND)
    assertEqual(res.verdict, "upgrade")
    -- The candidate's own flag wins over the spec's.
    c.dualWield = false
    res = E.Evaluate(sword, c)
    assertEqual(res.baselineSlot, S.MAINHAND)
    -- Spec unknown, but every Rogue spec dual wields.
    local r = who("ROGUE", nil)
    r.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPON", W.DAGGER)
    r.gear[S.OFFHAND] = weapon(610, "INVTYPE_WEAPON", W.DAGGER)
    res = E.Evaluate(weapon(630, "INVTYPE_WEAPON", W.DAGGER), r)
    assertEqual(res.baselineSlot, S.OFFHAND)
    -- Dual wield with an empty off hand is an empty slot.
    r.gear[S.OFFHAND] = false
    res = E.Evaluate(weapon(630, "INVTYPE_WEAPON", W.DAGGER), r)
    assertEqual(res.verdict, "upgrade")
    assertTrue(hasReason(res, "emptySlot"))
    assertEqual(res.baselineSlot, S.OFFHAND)
end)

test("evaluate: a dual wielder holding a two-hander compares a one-hander against the two-hander", function()
    local E = load()
    local c = who("DEATHKNIGHT", 251)
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_2HWEAPON", W.SWORD_2H)
    c.gear[S.OFFHAND] = false
    local res = E.Evaluate(weapon(630, "INVTYPE_WEAPON", W.SWORD_1H), c)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.verdict, "downgrade")
    assertTrue(hasReason(res, "vsTwoHand"))
    assertTrue(not hasReason(res, "emptySlot"))
end)

test("evaluate: a two-hander compares against the average of both hands", function()
    local E = load()
    local greatsword = weapon(630, "INVTYPE_2HWEAPON", W.SWORD_2H)
    local c = who("WARRIOR", 71)
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPON", W.SWORD_1H)
    c.gear[S.OFFHAND] = armor(610, "INVTYPE_SHIELD", A.SHIELD)
    local res = E.Evaluate(greatsword, c)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.ilvlDelta, 5)
    assertEqual(res.verdict, "upgrade")
    assertEqual(res.baseline, c.gear[S.MAINHAND])
    -- An empty off hand: main hand alone.
    c.gear[S.OFFHAND] = false
    res = E.Evaluate(greatsword, c)
    assertEqual(res.ilvlDelta, -10)
    -- A two-hander in the main hand: that alone.
    c.gear[S.MAINHAND] = weapon(620, "INVTYPE_2HWEAPON", W.SWORD_2H)
    c.gear[S.OFFHAND] = nil
    res = E.Evaluate(greatsword, c)
    assertEqual(res.ilvlDelta, 10)
    -- An empty main hand is an empty slot.
    c.gear[S.MAINHAND] = false
    res = E.Evaluate(greatsword, c)
    assertEqual(res.verdict, "upgrade")
    assertTrue(hasReason(res, "emptySlot"))
    assertEqual(res.baselineSlot, S.MAINHAND)
    -- An unknown off hand next to a one-hander cannot be averaged.
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPON", W.SWORD_1H)
    c.gear[S.OFFHAND] = nil
    res = E.Evaluate(greatsword, c)
    assertEqual(res.verdict, "unknown")
end)

test("evaluate: Titan's Grip compares a two-hander as a pair over both hands", function()
    local E = load()
    local greatsword = weapon(630, "INVTYPE_2HWEAPON", W.SWORD_2H)
    local c = who("WARRIOR", 72)
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_2HWEAPON", W.SWORD_2H)
    c.gear[S.OFFHAND] = weapon(620, "INVTYPE_2HWEAPON", W.AXE_2H)
    local res = E.Evaluate(greatsword, c)
    assertEqual(res.baselineSlot, S.OFFHAND)
    assertEqual(res.ilvlDelta, 10)
    assertEqual(res.verdict, "upgrade")
    -- Without the grip (an explicit false), the two-hander in the main hand stands alone.
    c.titanGrip = false
    res = E.Evaluate(greatsword, c)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.verdict, "downgrade")
    -- The grip with an empty off hand: an empty slot.
    c.titanGrip = nil
    c.gear[S.OFFHAND] = false
    res = E.Evaluate(greatsword, c)
    assertTrue(hasReason(res, "emptySlot"))
    assertEqual(res.baselineSlot, S.OFFHAND)
end)

test("evaluate: an off hand against a wielded two-hander compares with the two-hander, never an empty slot", function()
    local E = load()
    local c = who("MAGE", 64)
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_2HWEAPON", W.STAFF)
    c.gear[S.OFFHAND] = false
    local res = E.Evaluate(armor(630, "INVTYPE_HOLDABLE", A.GENERIC), c)
    assertEqual(res.verdict, "downgrade")
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.ilvlDelta, -10)
    assertTrue(hasReason(res, "vsTwoHand"))
    assertTrue(not hasReason(res, "emptySlot"))
    res = E.Evaluate(armor(650, "INVTYPE_HOLDABLE", A.GENERIC), c)
    assertEqual(res.verdict, "upgrade")
    -- A one-hander in the main hand and an empty off hand: a real empty slot.
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPON", W.SWORD_1H)
    res = E.Evaluate(armor(500, "INVTYPE_HOLDABLE", A.GENERIC), c)
    assertEqual(res.verdict, "upgrade")
    assertTrue(hasReason(res, "emptySlot"))
    assertEqual(res.baselineSlot, S.OFFHAND)
    -- A shield for a Protection Warrior holding a two-hander.
    local p = who("WARRIOR", 73)
    p.gear[S.MAINHAND] = weapon(640, "INVTYPE_2HWEAPON", W.SWORD_2H)
    p.gear[S.OFFHAND] = false
    res = E.Evaluate(armor(620, "INVTYPE_SHIELD", A.SHIELD), p)
    assertEqual(res.verdict, "downgrade")
    assertTrue(hasReason(res, "vsTwoHand"))
end)

test("evaluate: ranged weapons are two-handers for hunters and main hand for wand users", function()
    local E = load()
    local h = who("HUNTER", 253)
    h.gear[S.MAINHAND] = weapon(640, "INVTYPE_RANGED", W.BOWS)
    h.gear[S.OFFHAND] = false
    -- The client reports guns and crossbows as RANGEDRIGHT, bows as RANGED.
    local res = E.Evaluate(weapon(650, "INVTYPE_RANGEDRIGHT", W.GUNS), h)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.ilvlDelta, 10)
    h.gear[S.MAINHAND] = weapon(640, "INVTYPE_RANGEDRIGHT", W.CROSSBOW)
    res = E.Evaluate(weapon(650, "INVTYPE_RANGED", W.BOWS), h)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.ilvlDelta, 10)
    h.gear[S.MAINHAND] = false
    res = E.Evaluate(weapon(650, "INVTYPE_RANGEDRIGHT", W.GUNS), h)
    assertTrue(hasReason(res, "emptySlot"))
    local p = who("PRIEST", 258)
    p.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPONMAINHAND", W.MACE_1H)
    p.gear[S.OFFHAND] = armor(600, "INVTYPE_HOLDABLE", A.GENERIC)
    res = E.Evaluate(weapon(650, "INVTYPE_RANGEDRIGHT", W.WAND), p)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.ilvlDelta, 10)
end)

test("evaluate: a gun, crossbow or wand in the main hand is a two-hander for off hands and one-handers", function()
    local E = load()
    -- A priest with a wand and an empty off hand: an off hand compares with the wand.
    local p = who("PRIEST", 258)
    p.gear[S.MAINHAND] = weapon(640, "INVTYPE_RANGEDRIGHT", W.WAND)
    p.gear[S.OFFHAND] = false
    local res = E.Evaluate(armor(630, "INVTYPE_HOLDABLE", A.GENERIC), p)
    assertEqual(res.verdict, "downgrade")
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertTrue(hasReason(res, "vsTwoHand"))
    assertTrue(not hasReason(res, "emptySlot"))
    -- A dual-wielding hunter holding a gun: a one-hander compares with the gun.
    local h = who("HUNTER", 255, { dualWield = true })
    h.gear[S.MAINHAND] = weapon(640, "INVTYPE_RANGEDRIGHT", W.GUNS)
    h.gear[S.OFFHAND] = false
    res = E.Evaluate(weapon(630, "INVTYPE_WEAPON", W.AXE_1H), h)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertTrue(hasReason(res, "vsTwoHand"))
    -- A two-hander drop against a crossbow compares with the crossbow alone.
    local w = who("HUNTER", 255)
    w.gear[S.MAINHAND] = weapon(640, "INVTYPE_RANGEDRIGHT", W.CROSSBOW)
    w.gear[S.OFFHAND] = false
    res = E.Evaluate(weapon(650, "INVTYPE_2HWEAPON", W.POLEARM), w)
    assertEqual(res.baselineSlot, S.MAINHAND)
    assertEqual(res.ilvlDelta, 10)
end)

test("evaluate: a unique-equipped drop compares against the item holding its category", function()
    local E = load()
    local c = who("MAGE", 64)
    c.gear[S.FINGER1] = armor(620, "INVTYPE_FINGER", A.GENERIC)
    c.gear[S.FINGER2] = armor(660, "INVTYPE_FINGER", A.GENERIC, { unique = { cat = 7, max = 1 } })
    local ring = armor(650, "INVTYPE_FINGER", A.GENERIC, { unique = { cat = 7, max = 1 } })
    local res = E.Evaluate(ring, c)
    assertEqual(res.baselineSlot, S.FINGER2)
    assertEqual(res.verdict, "downgrade")
    assertTrue(hasReason(res, "uniqueEquipped"))
    -- The maximum not reached: the normal pair rule.
    ring.unique = { cat = 7, max = 2 }
    res = E.Evaluate(ring, c)
    assertEqual(res.baselineSlot, S.FINGER1)
    assertTrue(not hasReason(res, "uniqueEquipped"))
    -- Two holders at max 2: the lower of them.
    c.gear[S.FINGER1].unique = { cat = 7, max = 2 }
    c.gear[S.FINGER2].unique = { cat = 7, max = 2 }
    res = E.Evaluate(ring, c)
    assertEqual(res.baselineSlot, S.FINGER1)
    assertTrue(hasReason(res, "uniqueEquipped"))
    -- A holder in another slot family (a trinket sharing the category).
    c.gear[S.FINGER1].unique, c.gear[S.FINGER2].unique = nil, nil
    c.gear[S.TRINKET1] = armor(700, "INVTYPE_TRINKET", A.GENERIC, { unique = { cat = 9 } })
    local trinketish = armor(650, "INVTYPE_FINGER", A.GENERIC, { unique = { cat = 9 } })
    res = E.Evaluate(trinketish, c)
    assertEqual(res.baselineSlot, S.TRINKET1)
    assertEqual(res.ilvlDelta, -50)
    -- A different category leaves the plan alone.
    trinketish.unique = { cat = 10 }
    res = E.Evaluate(trinketish, c)
    assertEqual(res.baselineSlot, S.FINGER1)
end)

test("evaluate: a unique drop whose own slot holds the category replaces that item", function()
    local E = load()
    local c = who("MAGE", 64)
    c.gear[S.FEET] = armor(600, "INVTYPE_FEET", A.CLOTH, { unique = { cat = 3, max = 2 } })
    c.gear[S.WRIST] = armor(590, "INVTYPE_WRIST", A.CLOTH, { unique = { cat = 3, max = 2 } })
    local boots = armor(595, "INVTYPE_FEET", A.CLOTH, { unique = { cat = 3, max = 2 } })
    local res = E.Evaluate(boots, c)
    assertEqual(res.baselineSlot, S.FEET)
    assertEqual(res.ilvlDelta, -5)
    assertEqual(res.verdict, "downgrade")
    -- A ring: of its own two slots, only the one holding the category can take it.
    c.gear[S.FINGER1] = armor(580, "INVTYPE_FINGER", A.GENERIC)
    c.gear[S.FINGER2] = armor(620, "INVTYPE_FINGER", A.GENERIC, { unique = { cat = 3, max = 2 } })
    c.gear[S.FEET].unique = nil
    local ring = armor(610, "INVTYPE_FINGER", A.GENERIC, { unique = { cat = 3, max = 2 } })
    res = E.Evaluate(ring, c)
    assertEqual(res.baselineSlot, S.FINGER2)
    assertEqual(res.ilvlDelta, -10)
    assertTrue(hasReason(res, "uniqueEquipped"))
end)

test("evaluate: compareOwned takes the better of equipped and owned per slot", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = armor(620, "INVTYPE_HEAD", A.PLATE)
    c.owned = { [S.HEAD] = armor(660, "INVTYPE_HEAD", A.PLATE) }
    local helm = armor(650, "INVTYPE_HEAD", A.PLATE)
    assertEqual(E.Evaluate(helm, c).verdict, "upgrade")
    local res = E.Evaluate(helm, c, { compareOwned = true })
    assertEqual(res.verdict, "downgrade")
    assertEqual(res.baseline, c.owned[S.HEAD])
    -- A worse owned item does not lower the baseline.
    c.owned[S.HEAD] = armor(600, "INVTYPE_HEAD", A.PLATE)
    res = E.Evaluate(helm, c, { compareOwned = true })
    assertEqual(res.ilvlDelta, 30)
    -- An owned item fills an empty slot.
    c.gear[S.HEAD] = false
    c.owned[S.HEAD] = armor(660, "INVTYPE_HEAD", A.PLATE)
    res = E.Evaluate(helm, c, { compareOwned = true })
    assertEqual(res.verdict, "downgrade")
    assertTrue(not hasReason(res, "emptySlot"))
end)

-- ---------------------------------------------------------------------------------------------
-- Equippability
-- ---------------------------------------------------------------------------------------------

test("evaluate: a known spec is judged by the item's own spec list", function()
    local E = load()
    local helm = armor(650, "INVTYPE_HEAD", A.PLATE, { specs = { [71] = true, [72] = true } })
    local res = E.Evaluate(helm, who("WARRIOR", 72))
    assertEqual(res.equip, "ok")
    res = E.Evaluate(helm, who("WARRIOR", 73))
    assertEqual(res.equip, "cant")
    assertEqual(res.verdict, "cantUse")
    assertTrue(hasReason(res, "specList"))
    -- The list wins over the class tables: a plate helm listed for a mage spec.
    helm.specs = { [64] = true }
    assertEqual(E.Evaluate(helm, who("MAGE", 64)).equip, "ok")
    -- An empty list is no list: the class tables decide.
    helm.specs = {}
    assertEqual(E.Evaluate(helm, who("MAGE", 64)).equip, "cant")
end)

test("evaluate: spec unknown falls back to ClassData for armor, jewelry, shields and off hands", function()
    local E = load()
    -- { facts, classFile, expected equip, reason or nil }
    local cases = {
        { armor(650, "INVTYPE_HEAD", A.PLATE), "WARRIOR", "ok" },
        { armor(650, "INVTYPE_HEAD", A.PLATE), "MAGE", "cant", "armorType" },
        { armor(650, "INVTYPE_LEGS", A.MAIL), "EVOKER", "ok" },
        { armor(650, "INVTYPE_HEAD", A.COSMETIC), "MAGE", "unknown" },
        { armor(650, "INVTYPE_CLOAK", A.CLOTH), "WARRIOR", "ok" },
        { armor(650, "INVTYPE_NECK", A.GENERIC), "ROGUE", "ok" },
        { armor(650, "INVTYPE_FINGER", A.GENERIC), "DRUID", "ok" },
        { armor(650, "INVTYPE_TRINKET", A.GENERIC), "PRIEST", "ok" },
        { armor(650, "INVTYPE_SHIELD", A.SHIELD), "MAGE", "cant", "shield" },
        { armor(650, "INVTYPE_SHIELD", A.SHIELD), "WARRIOR", "unknown", "shield" },
        { armor(650, "INVTYPE_SHIELD", A.SHIELD), "PALADIN", "unknown", "shield" },
        { armor(650, "INVTYPE_HOLDABLE", A.GENERIC), "WARLOCK", "ok" },
        { armor(650, "INVTYPE_HOLDABLE", A.GENERIC), "ROGUE", "cant", "offhand" },
        { armor(650, "INVTYPE_HOLDABLE", A.GENERIC), "DRUID", "unknown", "offhand" },
        { weapon(650, "INVTYPE_WEAPON", W.DAGGER), "PALADIN", "cant", "weaponType" },
        { weapon(650, "INVTYPE_WEAPON", W.SWORD_1H), "MAGE", "ok" },
        { weapon(650, "INVTYPE_2HWEAPON", W.WARGLAIVE), "DEMONHUNTER", "ok" },
        { weapon(650, "INVTYPE_RANGED", W.BOWS), "WARRIOR", "cant", "weaponType" },
        { weapon(650, "INVTYPE_WEAPONOFFHAND", W.DAGGER), "ROGUE", "ok" },
        { weapon(650, "INVTYPE_WEAPONOFFHAND", W.SWORD_1H), "WARRIOR", "unknown", "dualWield" },
        { item(650, "INVTYPE_HEAD", IC.CONSUMABLE, 0), "WARRIOR", "unknown", "notGear" },
    }
    for i, row in ipairs(cases) do
        local res = E.Evaluate(row[1], who(row[2], nil))
        assertEqual(res.equip, row[3], i .. " " .. row[2] .. " " .. tostring(row[1].equipLoc))
        if row[4] then assertTrue(hasReason(res, row[4]), i .. " reason " .. row[4]) end
        if row[3] == "unknown" then assertEqual(res.verdict, "unknown", i .. " verdict") end
        if row[3] == "cant" then assertEqual(res.verdict, "cantUse", i .. " verdict") end
    end
end)

test("evaluate: a known spec with no item spec list uses the spec's own class data", function()
    local E = load()
    local offSword = weapon(650, "INVTYPE_WEAPONOFFHAND", W.SWORD_1H)
    assertEqual(E.Evaluate(offSword, who("WARRIOR", 71)).equip, "cant")
    assertEqual(E.Evaluate(offSword, who("WARRIOR", 72)).equip, "ok")
    local shield = armor(650, "INVTYPE_SHIELD", A.SHIELD)
    assertEqual(E.Evaluate(shield, who("WARRIOR", 73)).equip, "ok")
    assertEqual(E.Evaluate(shield, who("WARRIOR", 71)).equip, "cant")
    local mace = weapon(650, "INVTYPE_2HWEAPON", W.MACE_2H, { stats = { [STR] = 100 } })
    local res = E.Evaluate(mace, who("PALADIN", 65))
    assertEqual(res.equip, "cant")
    assertTrue(hasReason(res, "primaryStat"))
    assertEqual(E.Evaluate(mace, who("PALADIN", 70)).equip, "ok")
end)

test("evaluate: the primary stat decides when every spec agrees, and is ambiguous otherwise", function()
    local E = load()
    local function helm(stats) return armor(650, "INVTYPE_HEAD", A.PLATE, { stats = stats }) end
    local res = E.Evaluate(helm({ [INT] = 50 }), who("WARRIOR", nil))
    assertEqual(res.equip, "cant")
    assertTrue(hasReason(res, "primaryStat"))
    assertEqual(E.Evaluate(helm({ [STR] = 50 }), who("WARRIOR", nil)).equip, "ok")
    -- Paladin specs split Strength and Intellect.
    res = E.Evaluate(helm({ [INT] = 50 }), who("PALADIN", nil))
    assertEqual(res.equip, "unknown")
    assertTrue(hasReason(res, "primaryStat"))
    assertEqual(E.Evaluate(helm({ [INT] = 50, [STR] = 50 }), who("PALADIN", nil)).equip, "ok")
    -- No primary stat on the item: nothing to check.
    assertEqual(E.Evaluate(helm({ ITEM_MOD_CRIT_RATING_SHORT = 50 }), who("WARRIOR", nil)).equip, "ok")
    -- Demon Hunter with Devourer: Agility alone is ambiguous, Agility and Intellect fit every spec.
    local function leather(stats) return armor(650, "INVTYPE_CHEST", A.LEATHER, { stats = stats }) end
    assertEqual(E.Evaluate(leather({ [AGI] = 50 }), who("DEMONHUNTER", nil)).equip, "unknown")
    assertEqual(E.Evaluate(leather({ [AGI] = 50, [INT] = 50 }), who("DEMONHUNTER", nil)).equip, "ok")
    assertEqual(E.Evaluate(leather({ [AGI] = 50 }), who("DEMONHUNTER", 1480)).equip, "cant")
    assertEqual(E.Evaluate(leather({ [STR] = 50 }), who("DEMONHUNTER", nil)).equip, "cant")
    -- A trinket with the wrong primary stat is not the class's.
    local trinket = armor(650, "INVTYPE_TRINKET", A.GENERIC, { stats = { [STR] = 80 } })
    assertEqual(E.Evaluate(trinket, who("MAGE", nil)).equip, "cant")
end)

test("evaluate: an unknown class cannot be judged", function()
    local E = load()
    local res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE), who("NOTACLASS", nil))
    assertEqual(res.equip, "unknown")
    assertEqual(res.verdict, "unknown")
    assertTrue(hasReason(res, "unknownClass"))
end)

test("evaluate: tier tokens are judged by their class list", function()
    local E = load()
    local token = item(650, "INVTYPE_HEAD", IC.MISCELLANEOUS, 0,
        { isTierToken = true, classes = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true } })
    local res = E.Evaluate(token, who("PALADIN", 70))
    assertEqual(res.equip, "ok")
    assertEqual(res.verdict, "upgrade")
    res = E.Evaluate(token, who("MAGE", 64))
    assertEqual(res.verdict, "cantUse")
    assertTrue(hasReason(res, "classRestricted"))
    token.classes = nil
    res = E.Evaluate(token, who("MAGE", 64))
    assertEqual(res.verdict, "unknown")
    assertTrue(hasReason(res, "tierToken"))
end)

test("evaluate: a class-restricted item refuses other classes", function()
    local E = load()
    local ring = armor(650, "INVTYPE_FINGER", A.GENERIC, { classes = { ROGUE = true } })
    assertEqual(E.Evaluate(ring, who("ROGUE", 259)).equip, "ok")
    assertEqual(E.Evaluate(ring, who("MAGE", 64)).equip, "cant")
    -- A candidate whose class is not known yet is unknown, never cantUse.
    local res = E.Evaluate(ring, who(nil, nil))
    assertEqual(res.equip, "unknown")
    assertEqual(res.verdict, "unknown")
    assertTrue(hasReason(res, "unknownClass"))
    assertTrue(not hasReason(res, "classRestricted"))
end)

test("evaluate: an undesired subclass is doesntWant, but only when the item is usable", function()
    local E = load()
    local key = E.SubClassKey(IC.ARMOR, A.SHIELD)
    assertEqual(key, IC.ARMOR .. ":" .. A.SHIELD)
    assertNil(E.SubClassKey(nil, A.SHIELD))
    assertNil(E.SubClassKey("4", 6))
    local shield = armor(650, "INVTYPE_SHIELD", A.SHIELD)
    local c = who("PALADIN", 65, { prefs = { undesired = { [key] = true } } })
    local res = E.Evaluate(shield, c)
    assertEqual(res.equip, "doesntWant")
    assertEqual(res.verdict, "doesntWant")
    assertTrue(hasReason(res, "undesired"))
    -- A mage cannot use it at all: cantUse, not doesntWant.
    local m = who("MAGE", 64, { prefs = { undesired = { [key] = true } } })
    assertEqual(E.Evaluate(shield, m).verdict, "cantUse")
    -- Other subclasses are untouched.
    assertEqual(E.Evaluate(weapon(650, "INVTYPE_WEAPONMAINHAND", W.MACE_1H), c).verdict, "upgrade")
    -- The same subClassID under another classID is another key (weapon 4 is a one-hand mace).
    assertTrue(E.SubClassKey(IC.WEAPON, W.MACE_1H) ~= E.SubClassKey(IC.ARMOR, A.PLATE))
end)

-- ---------------------------------------------------------------------------------------------
-- Verdicts, band and score
-- ---------------------------------------------------------------------------------------------

test("evaluate: the sidegrade band splits upgrade, sidegrade and downgrade", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = armor(640, "INVTYPE_HEAD", A.PLATE)
    -- { drop ilvl, band, verdict }
    local cases = {
        { 641, 0, "upgrade" }, { 640, 0, "sidegrade" }, { 639, 0, "downgrade" },
        { 645, 5, "sidegrade" }, { 646, 5, "upgrade" }, { 635, 5, "sidegrade" }, { 634, 5, "downgrade" },
        { 643, nil, "upgrade" }, { 643, "junk", "upgrade" }, { 643, -5, "sidegrade" },
    }
    for i, row in ipairs(cases) do
        local res = E.Evaluate(armor(row[1], "INVTYPE_HEAD", A.PLATE), c, { sidegradeBand = row[2] })
        assertEqual(res.verdict, row[3], "case " .. i)
        assertEqual(res.ilvlDelta, row[1] - 640, "delta " .. i)
    end
end)

test("evaluate: with a score, the verdict takes the sign only when ilvl and score agree in sign", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = armor(640, "INVTYPE_HEAD", A.PLATE, { score = 100 })
    local function scorer(f) return f.score end
    -- { drop ilvl, drop score, band, verdict, disagrees }
    local cases = {
        { 650, 120, 0, "upgrade" },
        { 630, 80, 0, "downgrade" },
        { 650, 80, 0, "sidegrade", true },
        { 630, 120, 0, "sidegrade", true },
        { 643, 120, 5, "sidegrade", true },  -- ilvl within the band, score up: no agreement
        { 643, 80, 5, "sidegrade", true },
        { 643, 100, 5, "sidegrade" },        -- both within the band
        { 650, 100, 0, "sidegrade", true },  -- an equal score does not agree with an ilvl gain
        { 640, 101, 0, "sidegrade", true },  -- the same ilvl with a better score (spec §5.2 step 4)
    }
    for i, row in ipairs(cases) do
        local drop = armor(row[1], "INVTYPE_HEAD", A.PLATE, { score = row[2] })
        local res = E.Evaluate(drop, c, { scorer = scorer, sidegradeBand = row[3] })
        assertEqual(res.verdict, row[4], "case " .. i)
        assertEqual(res.scoreDelta, row[2] - 100, "scoreDelta " .. i)
        assertEqual(hasReason(res, "scoreDisagrees"), row[5] == true, "disagrees " .. i)
    end
end)

test("evaluate: the scorer is optional, may be pending, and may fail without harm", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = armor(640, "INVTYPE_HEAD", A.PLATE)
    local drop = armor(650, "INVTYPE_HEAD", A.PLATE, { score = 50 })
    -- The baseline has no score: ilvl only.
    local res = E.Evaluate(drop, c, { scorer = function(f) return f.score end })
    assertNil(res.scoreDelta)
    assertEqual(res.verdict, "upgrade")
    -- Pending: reported, ilvl only.
    res = E.Evaluate(drop, c, { scorer = function() return "pending" end })
    assertNil(res.scoreDelta)
    assertTrue(hasReason(res, "scorePending"))
    assertEqual(res.verdict, "upgrade")
    -- A scorer that throws is no score.
    res = E.Evaluate(drop, c, { scorer = function() error("boom") end })
    assertNil(res.scoreDelta)
    assertEqual(res.verdict, "upgrade")
    -- Not a function: ignored.
    res = E.Evaluate(drop, c, { scorer = "pawn" })
    assertEqual(res.verdict, "upgrade")
    -- The scorer is handed the candidate too.
    local seen
    E.Evaluate(drop, c, { scorer = function(_, cand) seen = cand return 1 end })
    assertEqual(seen, c)
end)

test("evaluate: a two-hander's score baseline is the average of both hands' scores", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.MAINHAND] = weapon(640, "INVTYPE_WEAPON", W.SWORD_1H, { score = 100 })
    c.gear[S.OFFHAND] = armor(640, "INVTYPE_SHIELD", A.SHIELD, { score = 60 })
    local res = E.Evaluate(weapon(645, "INVTYPE_2HWEAPON", W.SWORD_2H, { score = 90 }), c,
        { scorer = function(f) return f.score end })
    assertEqual(res.scoreDelta, 10)
    assertEqual(res.verdict, "upgrade")
end)

test("evaluate: verdict precedence is cant, then doesntWant, then unknown, then the comparison", function()
    local E = load()
    local c = who("MAGE", 64)
    c.gear[S.HEAD] = false
    local res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE), c)
    assertEqual(res.verdict, "cantUse")
    assertTrue(not hasReason(res, "emptySlot"))
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.COSMETIC), c)
    assertEqual(res.verdict, "unknown")
end)

-- ---------------------------------------------------------------------------------------------
-- Track delta
-- ---------------------------------------------------------------------------------------------

test("evaluate: the track delta orders tracks by tier, then rank", function()
    local E = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = armor(640, "INVTYPE_HEAD", A.PLATE, { track = { name = "Champion", rank = 6, max = 8 } })
    local res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE,
        { track = { name = "Hero", rank = 1, max = 6 } }), c)
    assertEqual(res.trackDelta.tier, 1)
    assertEqual(res.trackDelta.rank, -5)
    assertEqual(res.trackDelta.sign, 1)
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE,
        { track = { name = "Champion", rank = 4, max = 8 } }), c)
    assertEqual(res.trackDelta.tier, 0)
    assertEqual(res.trackDelta.rank, -2)
    assertEqual(res.trackDelta.sign, -1)
    -- A numeric tier wins over the name (a localized client).
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE,
        { track = { name = "Heldin", tier = 6, rank = 1 } }), c)
    assertEqual(res.trackDelta.tier, 2)
    -- A name the table does not know, and no tier: no delta.
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE, { track = { name = "Heldin", rank = 1 } }), c)
    assertNil(res.trackDelta)
    -- One side without a track: no delta.
    c.gear[S.HEAD].track = nil
    res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE, { track = { name = "Hero", rank = 1 } }), c)
    assertNil(res.trackDelta)
    assertNil(E.TrackDelta(nil, nil))
    assertNil(E.TrackDelta("x", { name = "Hero" }))
    assertEqual(E.TrackDelta({ name = "Myth" }, { name = "Myth" }).sign, 0)
end)

-- ---------------------------------------------------------------------------------------------
-- Output shape and nil safety
-- ---------------------------------------------------------------------------------------------

test("evaluate: the output carries every field of spec 5.2 step 5", function()
    local E = load()
    local c = who("WARRIOR", 71)
    local res = E.Evaluate(armor(650, "INVTYPE_HEAD", A.PLATE), c)
    assertEqual(res.verdict, "upgrade")
    assertEqual(res.equip, "ok")
    assertEqual(res.ilvlDelta, 49)
    assertEqual(res.baselineSlot, S.HEAD)
    assertEqual(res.baseline, c.gear[S.HEAD])
    assertTrue(type(res.reasons) == "table")
    assertEqual(#res.reasons, 0)
    assertNil(res.trackDelta)
    assertNil(res.scoreDelta)
end)

test("evaluate: nil and garbage inputs never throw and answer unknown with a reason", function()
    local E = load()
    local junk = { nil, false, true, 0, -1, "x", {}, function() end, 0 / 0 }
    local n = 9
    local good = armor(650, "INVTYPE_HEAD", A.PLATE)
    for i = 1, n do
        for j = 1, n do
            for k = 1, n do
                local ok, res = pcall(E.Evaluate, junk[i], junk[j], junk[k])
                assertTrue(ok, ("throws at %d/%d/%d"):format(i, j, k))
                assertEqual(type(res), "table")
                assertEqual(res.verdict, "unknown", ("verdict at %d/%d/%d"):format(i, j, k))
                assertTrue(#res.reasons > 0, ("reason at %d/%d/%d"):format(i, j, k))
            end
        end
        -- Good facts, junk candidate; junk facts, good candidate.
        local ok, res = pcall(E.Evaluate, good, junk[i])
        assertTrue(ok and res.verdict == "unknown", "junk candidate " .. i)
        ok, res = pcall(E.Evaluate, junk[i], who("WARRIOR", 71))
        assertTrue(ok and res.verdict == "unknown", "junk facts " .. i)
    end
end)

test("evaluate: garbage inside the tables never throws", function()
    local E = load()
    local weird = {
        { ilvl = "650", equipLoc = "INVTYPE_HEAD", classID = IC.ARMOR, subClassID = A.PLATE },
        { ilvl = 650, equipLoc = {}, classID = IC.ARMOR },
        { ilvl = 650, equipLoc = "INVTYPE_HEAD", classID = "4", subClassID = "plate" },
        { ilvl = 650, equipLoc = "INVTYPE_HEAD", classID = IC.ARMOR, subClassID = A.PLATE, specs = "x",
          stats = "x", track = "x", unique = "x", classes = "x" },
        { ilvl = 650, equipLoc = "INVTYPE_FINGER", classID = IC.ARMOR, subClassID = A.GENERIC,
          stats = { [INT] = "lots" }, unique = { cat = {}, max = "x" }, track = { tier = "x", rank = {} } },
        { ilvl = 0 / 0, equipLoc = "INVTYPE_HEAD", classID = IC.ARMOR, subClassID = A.PLATE },
        { ilvl = 650, equipLoc = "INVTYPE_2HWEAPON", classID = IC.WEAPON, subClassID = W.SWORD_2H,
          isTierToken = "yes" },
    }
    local cands = {
        { classFile = "WARRIOR", specID = 71, gear = "x" },
        { classFile = "WARRIOR", specID = "71", gear = { [S.HEAD] = "x", [S.FINGER1] = 5, [S.FINGER2] = true } },
        { classFile = {}, specID = {}, gear = { [S.HEAD] = { ilvl = "x" } } },
        { classFile = "WARRIOR", specID = 72, dualWield = "yes", titanGrip = 1, gear = fullGear(),
          owned = "x", prefs = "x" },
        { classFile = "WARRIOR", specID = 71, gear = fullGear(), owned = { [S.HEAD] = "x" },
          prefs = { undesired = "x" } },
        { classFile = "WARRIOR", specID = 71, gear = { [S.MAINHAND] = { ilvl = 600, unique = "x" },
          [S.OFFHAND] = { ilvl = 600, equipLoc = {} } } },
    }
    local optsList = { nil, {}, { sidegradeBand = {}, compareOwned = "x", scorer = 5 },
        { compareOwned = true, scorer = function() return 0 / 0 end } }
    for i, f in ipairs(weird) do
        for j, c in ipairs(cands) do
            for k = 1, 4 do
                local ok, res = pcall(E.Evaluate, f, c, optsList[k])
                assertTrue(ok, ("throws at %d/%d/%d"):format(i, j, k))
                assertTrue(type(res.verdict) == "string", ("verdict at %d/%d/%d"):format(i, j, k))
            end
        end
    end
end)

test("evaluate: an internal failure is caught and reported as unknown", function()
    local E = load()
    local trap = setmetatable({}, { __index = function() error("trap") end })
    local ok, res = pcall(E.Evaluate, trap, who("WARRIOR", 71))
    assertTrue(ok)
    assertEqual(res.verdict, "unknown")
    assertTrue(hasReason(res, "error"))
end)

test("evaluate: heirloom protection keeps a slot holding an heirloom from being called an upgrade", function()
    local E, C = load()
    local c = who("WARRIOR", 71)
    c.gear[S.HEAD] = armor(580, "INVTYPE_HEAD", A.PLATE, { quality = C.QUALITY.HEIRLOOM })
    local helm = armor(650, "INVTYPE_HEAD", A.PLATE)
    -- Off (the kernel's default): a plain upgrade.
    assertEqual(E.Evaluate(helm, c).verdict, "upgrade")
    -- On: a sidegrade, with the reason.
    local res = E.Evaluate(helm, c, { heirloomProtect = true })
    assertEqual(res.verdict, "sidegrade")
    assertTrue(hasReason(res, "heirloomProtected"))
    assertEqual(res.ilvlDelta, 70)
    -- A downgrade stays one; a slot without an heirloom is not protected; an empty slot neither.
    assertEqual(E.Evaluate(armor(500, "INVTYPE_HEAD", A.PLATE), c, { heirloomProtect = true }).verdict, "downgrade")
    c.gear[S.HEAD].quality = C.QUALITY.EPIC
    assertEqual(E.Evaluate(helm, c, { heirloomProtect = true }).verdict, "upgrade")
    c.gear[S.HEAD] = false
    assertEqual(E.Evaluate(helm, c, { heirloomProtect = true }).verdict, "upgrade")
end)
