-- tests/test_class_data.lua — core/ClassData.lua (design spec §4, §5.2): the class and spec tables
-- are well-formed for Retail 12.x, Devourer included, and every lookup answers the three-valued way
-- the evaluation kernel's spec-unknown fallback needs (true, false, or nil for "cannot tell").

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function load()
    local NS = T.newAddon()
    return NS.ClassData, NS.Constants
end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
    "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

test("classdata: thirteen classes with their client classIDs, each with an armor type", function()
    local CD, C = load()
    for i, classFile in ipairs(CLASSES) do
        assertEqual(CD.CLASS_ID[classFile], i, classFile)
        local armor = CD.ARMOR[classFile]
        assertTrue(armor == C.ARMOR_SUBCLASS.CLOTH or armor == C.ARMOR_SUBCLASS.LEATHER
            or armor == C.ARMOR_SUBCLASS.MAIL or armor == C.ARMOR_SUBCLASS.PLATE, classFile)
        assertTrue(type(CD.WEAPONS[classFile]) == "table", classFile .. " weapons")
    end
    assertEqual(CD.ARMOR.DEATHKNIGHT, C.ARMOR_SUBCLASS.PLATE)
    assertEqual(CD.ARMOR.EVOKER, C.ARMOR_SUBCLASS.MAIL)
    assertEqual(CD.ARMOR.DEMONHUNTER, C.ARMOR_SUBCLASS.LEATHER)
    assertEqual(CD.ARMOR.WARLOCK, C.ARMOR_SUBCLASS.CLOTH)
end)

test("classdata: every spec row is well-formed and its class lists it", function()
    local CD = load()
    local stats = { ITEM_MOD_STRENGTH_SHORT = true, ITEM_MOD_AGILITY_SHORT = true,
        ITEM_MOD_INTELLECT_SHORT = true }
    local count = 0
    for specID, row in pairs(CD.SPECS) do
        count = count + 1
        assertTrue(CD.CLASS_ID[row.class] ~= nil, specID .. " class")
        assertTrue(stats[row.stat] == true, specID .. " stat")
        for _, flag in ipairs({ "dualWield", "titanGrip", "shield", "offhand" }) do
            assertTrue(type(row[flag]) == "boolean", specID .. " " .. flag)
        end
        local listed = false
        for _, id in ipairs(CD.CLASS_SPECS[row.class]) do if id == specID then listed = true end end
        assertTrue(listed, specID .. " in CLASS_SPECS." .. row.class)
        -- a Titan's Grip spec dual wields; a shield and a held off hand never share a dual-wield spec
        if row.titanGrip then assertTrue(row.dualWield, specID) end
        if row.dualWield then assertTrue(not row.offhand, specID .. " offhand") end
    end
    assertEqual(count, 40)
    for _, classFile in ipairs(CLASSES) do
        assertTrue(#CD.CLASS_SPECS[classFile] >= 2, classFile .. " has its specs")
    end
    assertEqual(#CD.CLASS_SPECS.DRUID, 4)
    assertEqual(#CD.CLASS_SPECS.DEMONHUNTER, 3)
end)

test("classdata: the Devourer Demon Hunter spec (1480) is an Intellect leather dual wielder", function()
    local CD, C = load()
    local dev = CD.Spec(1480)
    assertTrue(dev ~= nil)
    assertEqual(dev.class, "DEMONHUNTER")
    assertEqual(dev.stat, "ITEM_MOD_INTELLECT_SHORT")
    assertEqual(dev.dualWield, true)
    assertEqual(CD.ClassOf(1480), "DEMONHUNTER")
    assertEqual(CD.ARMOR[CD.ClassOf(1480)], C.ARMOR_SUBCLASS.LEATHER)
    assertEqual(CD.PrimaryStat("DEMONHUNTER", 1480), "ITEM_MOD_INTELLECT_SHORT")
    -- With Devourer, the class no longer shares one primary stat.
    assertEqual(CD.PrimaryStat("DEMONHUNTER", nil), nil)
    assertEqual(CD.PrimaryStat("DEMONHUNTER", 577), "ITEM_MOD_AGILITY_SHORT")
end)

test("classdata: dual wield and Titan's Grip are the right specs", function()
    local CD = load()
    local dual = { [251] = true, [577] = true, [581] = true, [1480] = true, [268] = true, [269] = true,
        [259] = true, [260] = true, [261] = true, [263] = true, [72] = true }
    for specID in pairs(CD.SPECS) do
        assertEqual(CD.IsDualWield(specID), dual[specID] == true, "dualWield " .. specID)
        assertEqual(CD.IsTitanGrip(specID), specID == 72, "titanGrip " .. specID)
    end
    assertEqual(CD.IsDualWield(nil), nil)
    assertEqual(CD.IsDualWield(999999), nil)
    assertEqual(CD.IsTitanGrip(nil), nil)
end)

test("classdata: shields go to Protection, Holy, Elemental and Restoration Shaman only", function()
    local CD = load()
    local shield = { [73] = true, [66] = true, [65] = true, [262] = true, [264] = true }
    for specID in pairs(CD.SPECS) do
        assertEqual(CD.CanUseShield(CD.ClassOf(specID), specID), shield[specID] == true, "shield " .. specID)
    end
    -- Spec unknown: a class with some shield specs cannot tell; a class with none can.
    assertEqual(CD.CanUseShield("WARRIOR", nil), nil)
    assertEqual(CD.CanUseShield("PALADIN", nil), nil)
    assertEqual(CD.CanUseShield("SHAMAN", nil), nil)
    assertEqual(CD.CanUseShield("MAGE", nil), false)
    assertEqual(CD.CanUseShield("ROGUE", nil), false)
    assertEqual(CD.CanUseShield(nil, nil), nil)
end)

test("classdata: held off hands go to the caster and healer specs", function()
    local CD = load()
    assertEqual(CD.CanUseOffhand("MAGE", nil), true)
    assertEqual(CD.CanUseOffhand("WARLOCK", nil), true)
    assertEqual(CD.CanUseOffhand("PRIEST", nil), true)
    assertEqual(CD.CanUseOffhand("EVOKER", nil), true)
    assertEqual(CD.CanUseOffhand("ROGUE", nil), false)
    assertEqual(CD.CanUseOffhand("WARRIOR", nil), false)
    assertEqual(CD.CanUseOffhand("HUNTER", nil), false)
    assertEqual(CD.CanUseOffhand("DEATHKNIGHT", nil), false)
    assertEqual(CD.CanUseOffhand("DRUID", nil), nil)
    assertEqual(CD.CanUseOffhand("DRUID", 102), true)
    assertEqual(CD.CanUseOffhand("DRUID", 103), false)
    assertEqual(CD.CanUseOffhand("MONK", 270), true)
    assertEqual(CD.CanUseOffhand("MONK", 269), false)
    assertEqual(CD.CanUseOffhand("PALADIN", 65), true)
    assertEqual(CD.CanUseOffhand("SHAMAN", 262), true)
    assertEqual(CD.CanUseOffhand("SHAMAN", 263), false)
    assertEqual(CD.CanUseOffhand("DEMONHUNTER", 1480), false)
end)

test("classdata: a spec of another class is not trusted over the class", function()
    local CD = load()
    -- 72 is Fury; asked as a Mage it answers from the Mage class instead.
    assertEqual(CD.CanUseShield("MAGE", 72), false)
    assertEqual(CD.CanUseOffhand("MAGE", 72), true)
    assertEqual(CD.PrimaryStat("MAGE", 72), "ITEM_MOD_INTELLECT_SHORT")
end)

test("classdata: armor type is exact, and an unknown class or subclass cannot tell", function()
    local CD, C = load()
    local A = C.ARMOR_SUBCLASS
    assertEqual(CD.CanWearArmor("WARRIOR", A.PLATE), true)
    assertEqual(CD.CanWearArmor("WARRIOR", A.MAIL), false)
    assertEqual(CD.CanWearArmor("PRIEST", A.CLOTH), true)
    assertEqual(CD.CanWearArmor("PRIEST", A.LEATHER), false)
    assertEqual(CD.CanWearArmor("EVOKER", A.MAIL), true)
    assertEqual(CD.CanWearArmor("MONK", A.LEATHER), true)
    assertEqual(CD.CanWearArmor("DEMONHUNTER", A.LEATHER), true)
    assertEqual(CD.CanWearArmor("DEMONHUNTER", A.PLATE), false)
    -- Generic and cosmetic subclasses are not armor types.
    assertEqual(CD.CanWearArmor("MAGE", A.GENERIC), nil)
    assertEqual(CD.CanWearArmor("MAGE", A.COSMETIC), nil)
    assertEqual(CD.CanWearArmor("NOTACLASS", A.PLATE), nil)
    assertEqual(CD.CanWearArmor(nil, A.PLATE), nil)
end)

test("classdata: weapon proficiencies by class", function()
    local CD, C = load()
    local W = C.WEAPON_SUBCLASS
    local cases = {
        { "DEMONHUNTER", W.WARGLAIVE, true }, { "DEMONHUNTER", W.FIST, true },
        { "DEMONHUNTER", W.SWORD_1H, true }, { "DEMONHUNTER", W.AXE_1H, true },
        { "DEMONHUNTER", W.STAFF, false }, { "DEMONHUNTER", W.SWORD_2H, false },
        { "WARRIOR", W.WARGLAIVE, false }, { "WARRIOR", W.SWORD_2H, true },
        { "WARRIOR", W.POLEARM, true }, { "WARRIOR", W.BOWS, false },
        { "HUNTER", W.BOWS, true }, { "HUNTER", W.GUNS, true }, { "HUNTER", W.CROSSBOW, true },
        { "HUNTER", W.POLEARM, true }, { "HUNTER", W.MACE_1H, false },
        { "PALADIN", W.MACE_2H, true }, { "PALADIN", W.DAGGER, false },
        { "ROGUE", W.DAGGER, true }, { "ROGUE", W.STAFF, false },
        { "PRIEST", W.WAND, true }, { "PRIEST", W.SWORD_1H, false },
        { "MAGE", W.SWORD_1H, true }, { "MAGE", W.MACE_1H, false },
        { "WARLOCK", W.WAND, true }, { "WARLOCK", W.MACE_1H, false },
        { "DRUID", W.POLEARM, true }, { "DRUID", W.SWORD_1H, false },
        { "MONK", W.STAFF, true }, { "MONK", W.DAGGER, false },
        { "SHAMAN", W.MACE_2H, true }, { "SHAMAN", W.SWORD_1H, false },
        { "DEATHKNIGHT", W.SWORD_2H, true }, { "DEATHKNIGHT", W.FIST, false },
        { "EVOKER", W.SWORD_2H, true }, { "EVOKER", W.POLEARM, false },
    }
    for _, row in ipairs(cases) do
        assertEqual(CD.CanUseWeapon(row[1], row[2]), row[3], row[1] .. " " .. row[2])
    end
    -- Ranged weapons are the hunter's alone; wands the cloth casters'.
    for _, classFile in ipairs(CLASSES) do
        assertEqual(CD.CanUseWeapon(classFile, W.BOWS), classFile == "HUNTER", classFile .. " bows")
    end
    assertEqual(CD.CanUseWeapon("NOTACLASS", W.STAFF), nil)
    assertEqual(CD.CanUseWeapon("MAGE", nil), nil)
end)

test("classdata: primary stat is the spec's, or the class's when every spec shares one", function()
    local CD = load()
    assertEqual(CD.PrimaryStat("ROGUE", nil), "ITEM_MOD_AGILITY_SHORT")
    assertEqual(CD.PrimaryStat("HUNTER", nil), "ITEM_MOD_AGILITY_SHORT")
    assertEqual(CD.PrimaryStat("WARRIOR", nil), "ITEM_MOD_STRENGTH_SHORT")
    assertEqual(CD.PrimaryStat("DEATHKNIGHT", nil), "ITEM_MOD_STRENGTH_SHORT")
    assertEqual(CD.PrimaryStat("MAGE", nil), "ITEM_MOD_INTELLECT_SHORT")
    assertEqual(CD.PrimaryStat("EVOKER", nil), "ITEM_MOD_INTELLECT_SHORT")
    assertEqual(CD.PrimaryStat("PALADIN", nil), nil)
    assertEqual(CD.PrimaryStat("PALADIN", 65), "ITEM_MOD_INTELLECT_SHORT")
    assertEqual(CD.PrimaryStat("PALADIN", 70), "ITEM_MOD_STRENGTH_SHORT")
    assertEqual(CD.PrimaryStat("DRUID", nil), nil)
    assertEqual(CD.PrimaryStat("MONK", nil), nil)
    assertEqual(CD.PrimaryStat("SHAMAN", 263), "ITEM_MOD_AGILITY_SHORT")
    assertEqual(CD.PrimaryStat("NOTACLASS", nil), nil)
end)

test("classdata: lookups never throw on junk input", function()
    local CD = load()
    local junk = { nil, false, 0, -1, "x", {}, 1480.5 }
    for i = 1, 7 do
        local v = junk[i]
        assertTrue(pcall(CD.Spec, v), "Spec " .. i)
        assertTrue(pcall(CD.ClassOf, v), "ClassOf " .. i)
        assertTrue(pcall(CD.IsDualWield, v), "IsDualWield " .. i)
        assertTrue(pcall(CD.PrimaryStat, v, v), "PrimaryStat " .. i)
        assertTrue(pcall(CD.CanUseShield, v, v), "CanUseShield " .. i)
        assertTrue(pcall(CD.CanUseOffhand, v, v), "CanUseOffhand " .. i)
        assertTrue(pcall(CD.CanWearArmor, v, v), "CanWearArmor " .. i)
        assertTrue(pcall(CD.CanUseWeapon, v, v), "CanUseWeapon " .. i)
    end
    assertEqual(CD.Spec({}), nil)
    assertEqual(CD.ClassOf("x"), nil)
end)
