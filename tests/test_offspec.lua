-- tests/test_offspec.lua — modules/OffSpec.lua (feedback-19 spec §0): the off-spec verdict the
-- kernel attaches to a main-spec `cantUse` whose refusal depends on the spec. Each other spec of
-- the class is judged against its own gear (the candidate's `offSpecGear`), item level only; the
-- best of them is kept as `eval.offSpec`, and the main verdict is never changed.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local cached
local function load()
    if not cached then
        local NS = T.newAddon()
        cached = { E = NS.Evaluate, C = NS.Constants, OS = NS.OffSpec }
    end
    return cached.E, cached.C, cached.OS
end

local _, C0 = load()
local S, A, W, IC = C0.SLOT, C0.ARMOR_SUBCLASS, C0.WEAPON_SUBCLASS, C0.ITEM_CLASS
local STR, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local HOLY, PROT, RET = 65, 66, 70

local function item(ilvl, equipLoc, classID, subClassID, over)
    local f = { itemID = 1000, ilvl = ilvl, equipLoc = equipLoc, classID = classID, subClassID = subClassID }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

-- The Crescent: an Intellect one-handed axe.
local function intAxe(ilvl) return item(ilvl, "INVTYPE_WEAPON", IC.WEAPON, W.AXE_1H, { stats = { [INT] = 100 } }) end
local function strSword(ilvl) return item(ilvl, "INVTYPE_WEAPON", IC.WEAPON, W.SWORD_1H, { stats = { [STR] = 100 } }) end
local function shield(ilvl, over) return item(ilvl, "INVTYPE_SHIELD", IC.ARMOR, A.SHIELD, over) end

-- A paladin of `specID` wearing a Strength sword; `bySpec` is each other spec's gear, and every call
-- to offSpecGear is counted in `calls`.
local function paladin(specID, bySpec, over)
    local calls = {}
    local c = {
        classFile = "PALADIN", specID = specID, gear = { [S.MAINHAND] = strSword(600), [S.OFFHAND] = false },
        offSpecGear = function(x)
            calls[#calls + 1] = x
            return bySpec[x]
        end,
    }
    for k, v in pairs(over or {}) do c[k] = v end
    return c, calls
end

local function hasReason(res, key)
    for _, r in ipairs(res.reasons or {}) do
        if r.key == key then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- The verdict
-- ---------------------------------------------------------------------------------------------

test("offspec: a Protection paladin's Intellect axe is an off-spec upgrade for Holy over an empty hand", function()
    local E = load()
    local c, calls = paladin(PROT, { [HOLY] = { [S.MAINHAND] = false }, [RET] = { [S.MAINHAND] = strSword(600) } })
    local res = E.Evaluate(intAxe(650), c, { sidegradeBand = 2 })
    -- red under: no off-spec field; the drop reads "Can't use" and nothing lets you ask
    assertEqual(res.verdict, "cantUse", "the main verdict stays")
    assertTrue(hasReason(res, "primaryStat"))
    assertTrue(type(res.offSpec) == "table", "an off-spec verdict")
    assertEqual(res.offSpec.specID, HOLY)
    assertEqual(res.offSpec.mainSpecID, PROT, "the spec that could not use it, for the cells' words")
    assertEqual(res.offSpec.verdict, "upgrade")
    assertNil(res.offSpec.ilvlDelta, "an empty slot has no difference")
    assertNil(res.offSpec.baseline)
    assertEqual(res.offSpec.baselineSlot, S.MAINHAND)
    assertTrue(hasReason(res.offSpec, "emptySlot"), "the off-spec pass's own reasons")
    assertEqual(table.concat(calls, ","), HOLY .. "," .. RET, "every other spec, never the main one")
end)

test("offspec: against the best Holy item owned, the off-spec verdict takes the band", function()
    local E = load()
    local mace = item(640, "INVTYPE_WEAPON", IC.WEAPON, W.MACE_1H, { stats = { [INT] = 90 }, bag = 0, bagSlot = 3 })
    local c = paladin(PROT, { [HOLY] = { [S.MAINHAND] = mace } })
    local res = E.Evaluate(intAxe(650), c, {})
    assertEqual(res.offSpec.verdict, "upgrade")
    assertEqual(res.offSpec.ilvlDelta, 10)
    assertTrue(res.offSpec.baseline == mace, "the bag item it was judged against")
    res = E.Evaluate(intAxe(650), c, { sidegradeBand = 15 })
    assertEqual(res.offSpec.verdict, "sidegrade")
    res = E.Evaluate(intAxe(600), c, { sidegradeBand = 5 })
    assertEqual(res.offSpec.verdict, "downgrade")
    assertEqual(res.offSpec.ilvlDelta, -40)
end)

test("offspec: a refusal on the class skips the pass; so does a drop the main spec can use", function()
    local E = load()
    local c, calls = paladin(PROT, { [HOLY] = {}, [RET] = {} })
    local bow = item(650, "INVTYPE_RANGED", IC.WEAPON, W.BOWS)
    local res = E.Evaluate(bow, c, {})
    assertEqual(res.verdict, "cantUse"); assertTrue(hasReason(res, "weaponType"))
    assertNil(res.offSpec)
    local cloth = item(650, "INVTYPE_CHEST", IC.ARMOR, A.CLOTH)
    res = E.Evaluate(cloth, c, {})
    assertTrue(hasReason(res, "armorType")); assertNil(res.offSpec)
    local restricted = intAxe(650)
    restricted.classes = { MAGE = true }
    res = E.Evaluate(restricted, c, {})
    assertTrue(hasReason(res, "classRestricted")); assertNil(res.offSpec)
    res = E.Evaluate(strSword(650), c, {})
    assertEqual(res.verdict, "upgrade"); assertNil(res.offSpec)
    assertEqual(#calls, 0, "no off-spec gear asked for")
end)

test("offspec: an unknown spec is skipped", function()
    local E = load()
    local calls = {}
    local mage = { classFile = "MAGE", gear = { [S.OFFHAND] = false },
        offSpecGear = function(x) calls[#calls + 1] = x return {} end }
    local res = E.Evaluate(shield(650), mage, {})
    assertEqual(res.verdict, "cantUse"); assertTrue(hasReason(res, "shield"))
    assertNil(res.offSpec)
    mage.specID = "x"
    assertNil(E.Evaluate(shield(650), mage, {}).offSpec)
    assertEqual(#calls, 0)
end)

test("offspec: the spec list and the dual-wield flag are spec refusals too", function()
    local E = load()
    local listed = intAxe(650)
    listed.specs, listed.specsClass = { [HOLY] = true }, "PALADIN"
    local c = paladin(PROT, { [HOLY] = { [S.MAINHAND] = false } })
    local res = E.Evaluate(listed, c, {})
    assertTrue(hasReason(res, "specList"))
    assertEqual(res.offSpec.specID, HOLY)
    -- A Protection warrior cannot wield an off-hand weapon; Fury can, and its flag is its own.
    local warrior = { classFile = "WARRIOR", specID = 73, dualWield = false,
        gear = { [S.MAINHAND] = strSword(600), [S.OFFHAND] = shield(600) },
        offSpecGear = function(x)
            local g = { [S.MAINHAND] = strSword(600) }
            if x == 72 then g[S.OFFHAND] = false end
            return g
        end }
    res = E.Evaluate(item(650, "INVTYPE_WEAPONOFFHAND", IC.WEAPON, W.SWORD_1H), warrior, {})
    assertTrue(hasReason(res, "dualWield"))
    assertEqual(res.offSpec.specID, 72, "Fury, not the main spec's flag copied across")
    assertEqual(res.offSpec.verdict, "upgrade")
end)

-- ---------------------------------------------------------------------------------------------
-- The best spec
-- ---------------------------------------------------------------------------------------------

test("offspec: the best spec wins: verdict, then the larger difference (an empty slot largest), then the lower id", function()
    local E, C = load()
    -- A Retribution paladin cannot use a shield; Holy and Protection can.
    local function judge(holy, prot, opts)
        local c = paladin(RET, { [HOLY] = { [S.MAINHAND] = false, [S.OFFHAND] = holy },
            [PROT] = { [S.MAINHAND] = false, [S.OFFHAND] = prot } })
        return E.Evaluate(shield(630), c, opts or {}).offSpec
    end
    local o = judge(shield(600), shield(620))
    assertEqual(o.specID, HOLY, "the larger difference"); assertEqual(o.ilvlDelta, 30)
    o = judge(shield(620), shield(600))
    assertEqual(o.specID, PROT)
    o = judge(shield(620), shield(620))
    assertEqual(o.specID, HOLY, "a tie goes to the lower spec id")
    o = judge(shield(600), false)
    assertEqual(o.specID, PROT, "an empty slot beats any difference")
    -- An heirloom-protected upgrade is a sidegrade, and any upgrade beats it.
    o = judge(shield(600, { quality = C.QUALITY.HEIRLOOM }), shield(620), { heirloomProtect = true })
    assertEqual(o.specID, PROT); assertEqual(o.verdict, "upgrade")
    -- A sidegrade beats a downgrade.
    o = judge(shield(640), shield(629), { sidegradeBand = 2 })
    assertEqual(o.specID, PROT); assertEqual(o.verdict, "sidegrade")
end)

test("offspec: doesntWant, cantUse and unknown are never chosen; with none left there is no off-spec", function()
    local E = load()
    local key = E.SubClassKey(IC.ARMOR, A.SHIELD)
    local c = paladin(RET, { [HOLY] = { [S.OFFHAND] = false }, [PROT] = { [S.OFFHAND] = shield(600) } },
        { undesiredBySpec = { [HOLY] = { [key] = true } } })
    local res = E.Evaluate(shield(630), c, {})
    assertEqual(res.offSpec.specID, PROT, "Holy does not want shields")
    c.undesiredBySpec[PROT] = { [key] = true }
    assertNil(E.Evaluate(shield(630), c, {}).offSpec, "neither does Protection")
    -- Unknown: a slot nobody has read.
    c = paladin(RET, { [HOLY] = {}, [PROT] = {} })
    assertNil(E.Evaluate(shield(630), c, {}).offSpec, "no baseline for either spec")
end)

test("offspec: item level only: the scorer is never asked, so it never waits on a score", function()
    local E = load()
    local asked = {}
    local scorer = function(_, cand)
        asked[cand.specID] = true
        return "pending"
    end
    local mace = item(640, "INVTYPE_WEAPON", IC.WEAPON, W.MACE_1H, { stats = { [INT] = 90 } })
    local res = E.Evaluate(intAxe(650), paladin(PROT, { [HOLY] = { [S.MAINHAND] = mace } }), { scorer = scorer })
    assertEqual(res.offSpec.verdict, "upgrade")
    assertNil(asked[HOLY]); assertTrue(not hasReason(res.offSpec, "scorePending"))
end)

-- ---------------------------------------------------------------------------------------------
-- Junk
-- ---------------------------------------------------------------------------------------------

test("offspec: junk off-spec gear and junk undesired lists are tolerated and skip the spec", function()
    local E = load()
    local good = { [S.MAINHAND] = false }
    local answers = {
        function() error("boom") end,
        function() return "x" end,
        function() return nil end,
        function() return { [S.MAINHAND] = "x" } end,
    }
    for i, f in ipairs(answers) do
        local c = { classFile = "PALADIN", specID = PROT, gear = { [S.MAINHAND] = strSword(600) },
            offSpecGear = function(x) if x == RET then return good end return f() end }
        local ok, res = pcall(E.Evaluate, intAxe(650), c, {})
        assertTrue(ok, "throws at " .. i)
        assertEqual(res.verdict, "cantUse", "main verdict at " .. i)
        assertNil(res.offSpec, "Holy skipped and Ret cannot use it at " .. i)
    end
    for _, junk in ipairs({ "x", 5, true, {} }) do
        local res = E.Evaluate(intAxe(650), { classFile = "PALADIN", specID = PROT, gear = {},
            offSpecGear = junk, undesiredBySpec = junk }, {})
        assertEqual(res.verdict, "cantUse"); assertNil(res.offSpec)
        res = E.Evaluate(intAxe(650), { classFile = "PALADIN", specID = PROT, gear = {},
            offSpecGear = function() return good end, undesiredBySpec = junk }, {})
        assertEqual(res.offSpec.specID, HOLY, "a junk undesired list is no list")
    end
    -- An unknown class: nothing to walk.
    assertNil(E.Evaluate(intAxe(650), { classFile = "NOPE", specID = 1, gear = {},
        offSpecGear = function() return good end }, {}).offSpec)
end)

test("offspec: Who derives a spec's candidate from ClassData, never from the main spec", function()
    local _, _, OS = load()
    local w = OS.Who("WARRIOR", 72)
    assertEqual(w.classFile, "WARRIOR"); assertEqual(w.specID, 72)
    assertTrue(w.dualWield); assertTrue(w.titanGrip)
    w = OS.Who("WARRIOR", 73)
    assertTrue(w.dualWield == false and w.titanGrip == false)
end)

test("offspec: WornGear keeps each worn item the spec could wear, false where it could not", function()
    local _, _, OS = load()
    local sword, axe = strSword(600), intAxe(610)
    local gear = { [S.MAINHAND] = sword, [S.OFFHAND] = shield(600), [S.HEAD] = false }
    local holy = OS.WornGear(gear, OS.Who("PALADIN", HOLY))
    assertEqual(holy[S.MAINHAND], false, "Holy cannot use a Strength sword")
    assertTrue(holy[S.OFFHAND] == gear[S.OFFHAND])
    assertEqual(holy[S.HEAD], false)
    assertNil(holy[S.CHEST], "a slot still loading stays unknown")
    local ret = OS.WornGear({ [S.MAINHAND] = axe, [S.OFFHAND] = shield(600) }, OS.Who("PALADIN", RET))
    assertEqual(ret[S.MAINHAND], false); assertEqual(ret[S.OFFHAND], false, "Retribution takes no shield")
    assertNil(OS.WornGear("x", OS.Who("PALADIN", RET)))
end)
