-- tests/test_constants.lua — the data tables of core/Constants.lua (design spec §4, §5.2, §6.1,
-- §6.2, §7.2): well-formed, consistent with each other, and resolved from Enum when the client has it.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function C() return (T.newAddon()).Constants end

local function keysOf(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

test("constants: without Enum the item ids fall back to the documented literals", function()
    local c = C()
    assertEqual(c.ITEM_CLASS.WEAPON, 2)
    assertEqual(c.ITEM_CLASS.ARMOR, 4)
    assertEqual(c.ITEM_CLASS.MISCELLANEOUS, 15)
    assertEqual(c.ARMOR_SUBCLASS.GENERIC, 0)
    assertEqual(c.ARMOR_SUBCLASS.CLOTH, 1)
    assertEqual(c.ARMOR_SUBCLASS.LEATHER, 2)
    assertEqual(c.ARMOR_SUBCLASS.MAIL, 3)
    assertEqual(c.ARMOR_SUBCLASS.PLATE, 4)
    assertEqual(c.ARMOR_SUBCLASS.COSMETIC, 5)
    assertEqual(c.ARMOR_SUBCLASS.SHIELD, 6)
    assertEqual(c.WEAPON_SUBCLASS.AXE_1H, 0)
    assertEqual(c.WEAPON_SUBCLASS.WARGLAIVE, 9)
    assertEqual(c.WEAPON_SUBCLASS.STAFF, 10)
    assertEqual(c.WEAPON_SUBCLASS.FIST, 13)
    assertEqual(c.WEAPON_SUBCLASS.DAGGER, 15)
    assertEqual(c.WEAPON_SUBCLASS.CROSSBOW, 18)
    assertEqual(c.WEAPON_SUBCLASS.WAND, 19)
    assertEqual(c.QUALITY.POOR, 0)
    assertEqual(c.QUALITY.UNCOMMON, 2)
    assertEqual(c.QUALITY.RARE, 3)
    assertEqual(c.QUALITY.EPIC, 4)
    assertEqual(c.QUALITY.HEIRLOOM, 7)
end)

test("constants: with Enum present the ids are read from it, not from the literals", function()
    local NS = T.newAddon{ mock = function(m)
        m.Enum = {
            ItemClass = { Weapon = 102, Armor = 104, Miscellaneous = 115 },
            ItemArmorSubclass = { Cloth = 201, Shield = 206 },
            ItemWeaponSubclass = { Warglaive = 309, Wand = 319 },
            ItemQuality = { Rare = 403, Epic = 404 },
        }
    end }
    local c = NS.Constants
    assertEqual(c.ITEM_CLASS.WEAPON, 102)
    assertEqual(c.ITEM_CLASS.MISCELLANEOUS, 115)
    assertEqual(c.ARMOR_SUBCLASS.CLOTH, 201)
    assertEqual(c.ARMOR_SUBCLASS.SHIELD, 206)
    -- a member the client's Enum lacks still falls back to its literal
    assertEqual(c.ARMOR_SUBCLASS.PLATE, 4)
    assertEqual(c.WEAPON_SUBCLASS.WARGLAIVE, 309)
    assertEqual(c.WEAPON_SUBCLASS.WAND, 319)
    assertEqual(c.QUALITY.RARE, 403)
    assertEqual(c.QUALITY.UNCOMMON, 2)
end)

test("constants: the quality defaults are Rare fixed and an Uncommon floor (spec §6.2)", function()
    local c = C()
    assertEqual(c.QUALITY_DEFAULT.FIXED, c.QUALITY.RARE)
    assertEqual(c.QUALITY_DEFAULT.FLOOR, c.QUALITY.UNCOMMON)
    assertEqual(c.QUALITY_MODES[1], "fixed")
    assertEqual(c.QUALITY_MODES[2], "dynamicSlot")
    assertEqual(c.QUALITY_MODES[3], "dynamicCharacter")
end)

test("constants: the upgrade tracks ascend Explorer through Myth (spec §5.2 step 3)", function()
    local c = C()
    local order = { "Explorer", "Adventurer", "Veteran", "Champion", "Hero", "Myth" }
    for i, name in ipairs(order) do assertEqual(c.TRACK_TIER[name], i, name) end
    assertEqual(#keysOf(c.TRACK_TIER), #order)
end)

test("constants: the inventory slot ids are the client's, 1 through 19 with no slot 18 in use", function()
    local c = C()
    assertEqual(c.SLOT.HEAD, 1)
    assertEqual(c.SLOT.SHIRT, 4)
    assertEqual(c.SLOT.FINGER1, 11)
    assertEqual(c.SLOT.TRINKET2, 14)
    assertEqual(c.SLOT.BACK, 15)
    assertEqual(c.SLOT.MAINHAND, 16)
    assertEqual(c.SLOT.OFFHAND, 17)
    assertEqual(c.SLOT.TABARD, 19)
    local seen = {}
    for name, id in pairs(c.SLOT) do
        assertTrue(type(id) == "number" and id >= 1 and id <= 19 and id ~= 18, name)
        assertTrue(not seen[id], "slot id " .. id .. " is unique")
        seen[id] = true
    end
end)

test("constants: every slot plan has a known kind and real slot ids", function()
    local c = C()
    local slotIds = {}
    for _, id in pairs(c.SLOT) do slotIds[id] = true end
    for _, equipLoc in ipairs(keysOf(c.SLOT_PLAN)) do
        local plan = c.SLOT_PLAN[equipLoc]
        assertTrue(c.SLOT_KIND[plan.kind] == true, equipLoc .. " kind " .. tostring(plan.kind))
        assertTrue(type(plan.slots) == "table" and #plan.slots >= 1, equipLoc .. " slots")
        for _, id in ipairs(plan.slots) do assertTrue(slotIds[id], equipLoc .. " slot " .. id) end
        assertTrue(equipLoc:find("^INVTYPE_") ~= nil, equipLoc)
    end
end)

test("constants: the slot plan maps each equip location to the spec §5.2 kind", function()
    local c = C()
    local S = c.SLOT
    local cases = {
        INVTYPE_HEAD = { "single", { S.HEAD } },
        INVTYPE_NECK = { "single", { S.NECK } },
        INVTYPE_SHOULDER = { "single", { S.SHOULDER } },
        INVTYPE_CHEST = { "single", { S.CHEST } },
        INVTYPE_ROBE = { "single", { S.CHEST } },
        INVTYPE_WAIST = { "single", { S.WAIST } },
        INVTYPE_LEGS = { "single", { S.LEGS } },
        INVTYPE_FEET = { "single", { S.FEET } },
        INVTYPE_WRIST = { "single", { S.WRIST } },
        INVTYPE_HAND = { "single", { S.HANDS } },
        INVTYPE_CLOAK = { "single", { S.BACK } },
        INVTYPE_FINGER = { "pair", { S.FINGER1, S.FINGER2 } },
        INVTYPE_TRINKET = { "pair", { S.TRINKET1, S.TRINKET2 } },
        INVTYPE_WEAPON = { "weapon1H", { S.MAINHAND, S.OFFHAND } },
        INVTYPE_WEAPONMAINHAND = { "single", { S.MAINHAND } },
        INVTYPE_WEAPONOFFHAND = { "offhand", { S.OFFHAND } },
        INVTYPE_2HWEAPON = { "weapon2H", { S.MAINHAND, S.OFFHAND } },
        INVTYPE_SHIELD = { "offhand", { S.OFFHAND } },
        INVTYPE_HOLDABLE = { "offhand", { S.OFFHAND } },
        INVTYPE_RANGED = { "ranged", { S.MAINHAND, S.OFFHAND } },
        INVTYPE_RANGEDRIGHT = { "ranged", { S.MAINHAND, S.OFFHAND } },
    }
    for equipLoc, want in pairs(cases) do
        local plan = c.SLOT_PLAN[equipLoc]
        assertTrue(plan ~= nil, equipLoc .. " has a plan")
        assertEqual(plan.kind, want[1], equipLoc)
        assertEqual(#plan.slots, #want[2], equipLoc)
        for i, id in ipairs(want[2]) do assertEqual(plan.slots[i], id, equipLoc .. " slot " .. i) end
    end
    -- Shirts, tabards and bags are not gear the feed compares.
    assertTrue(c.SLOT_PLAN.INVTYPE_BODY == nil and c.SLOT_PLAN.INVTYPE_TABARD == nil)
    assertTrue(c.SLOT_PLAN.INVTYPE_BAG == nil and c.SLOT_PLAN.INVTYPE_NON_EQUIP_IGNORE == nil)
    -- `unique` is a kind the kernel applies on top of a plan, never a plan of its own.
    assertTrue(c.SLOT_KIND.unique == true)
    for _, plan in pairs(c.SLOT_PLAN) do assertTrue(plan.kind ~= "unique") end
end)

test("constants: universal and armor-typed equip locations partition the armor plans", function()
    local c = C()
    for _, loc in ipairs({ "INVTYPE_NECK", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK" }) do
        assertTrue(c.UNIVERSAL_EQUIPLOC[loc] == true, loc)
        assertTrue(not c.ARMOR_TYPED_EQUIPLOC[loc], loc)
    end
    for loc in pairs(c.ARMOR_TYPED_EQUIPLOC) do
        assertTrue(c.SLOT_PLAN[loc] ~= nil and c.SLOT_PLAN[loc].kind == "single", loc)
    end
    assertTrue(c.ARMOR_TYPED_EQUIPLOC.INVTYPE_ROBE and c.ARMOR_TYPED_EQUIPLOC.INVTYPE_HAND)
    assertTrue(c.QUALITY_IGNORED_SLOT[c.SLOT.SHIRT] and c.QUALITY_IGNORED_SLOT[c.SLOT.TABARD])
end)

test("constants: every situation key is listed once, in order, with the spec §6.1 defaults", function()
    local c = C()
    local want = {
        { "mythicPlus", true, true }, { "dungeon", true, true }, { "followerDungeon", false, false },
        { "raidLFR", true, false }, { "raid", true, true }, { "delve", false, false },
        { "scenario", false, false }, { "pvp", false, false }, { "openWorldGroup", false, false },
        { "solo", false, false },
    }
    assertEqual(#c.SITUATIONS, #want)
    for i, row in ipairs(want) do
        local s = c.SITUATIONS[i]
        assertEqual(s.key, row[1], "position " .. i)
        assertEqual(s.track, row[2], row[1] .. " track")
        assertEqual(s.autoOpen, row[3], row[1] .. " autoOpen")
        assertTrue(c.SITUATION[row[1]] == s, row[1] .. " is indexed by key")
    end
end)

test("constants: every difficulty id maps to a situation kind the classifier knows", function()
    local c = C()
    local kinds = { mythicPlus = true, dungeon = true, followerDungeon = true, raidLFR = true,
        raid = true, delve = true, scenario = true }
    for name, id in pairs(c.DIFFICULTY) do
        assertTrue(type(id) == "number", name)
        assertTrue(kinds[c.DIFFICULTY_KIND[id]] == true, name .. " -> " .. tostring(c.DIFFICULTY_KIND[id]))
    end
    for id in pairs(c.DIFFICULTY_KIND) do
        local named = false
        for _, v in pairs(c.DIFFICULTY) do if v == id then named = true end end
        assertTrue(named, "difficulty " .. id .. " has a name")
    end
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.MYTHIC_KEYSTONE], "mythicPlus")
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.MYTHIC_DUNGEON], "dungeon")
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.TIMEWALKING_DUNGEON], "dungeon")
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.FOLLOWER_DUNGEON], "followerDungeon")
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.LFR], "raidLFR")
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.MYTHIC_RAID], "raid")
    assertEqual(c.DIFFICULTY_KIND[c.DIFFICULTY.DELVE], "delve")
    assertEqual(c.DIFFICULTY.MYTHIC_KEYSTONE, 8)
    assertEqual(c.DIFFICULTY.LFR, 17)
    assertEqual(c.DIFFICULTY.FOLLOWER_DUNGEON, 205)
    assertEqual(c.DIFFICULTY.DELVE, 208)
end)

test("constants: the trade rules are the spec §7.2 table, and every situation has a rule", function()
    local c = C()
    assertEqual(c.TRADE_RULES.personal.window, 7200)
    assertEqual(c.TRADE_RULES.personal.ilvlRule, "notUpgradeForLooter")
    assertEqual(c.TRADE_RULES.personal.tradeable, true)
    assertEqual(c.TRADE_RULES.group.window, 7200)
    assertEqual(c.TRADE_RULES.group.ilvlRule, "none")
    assertEqual(c.TRADE_RULES.legacy.tradeable, false)
    for _, s in ipairs(c.SITUATIONS) do
        local rule = c.CONTENT_RULE[s.key]
        assertTrue(c.TRADE_RULES[rule] ~= nil, s.key .. " -> " .. tostring(rule))
    end
    assertEqual(#keysOf(c.CONTENT_RULE), #c.SITUATIONS)
    assertEqual(c.CONTENT_RULE.raid, "personal")
    assertEqual(c.CONTENT_RULE.followerDungeon, "legacy")
    assertEqual(c.CONTENT_RULE.pvp, "legacy")
    assertEqual(c.CONTENT_RULE.mythicPlus, "personal")
end)
