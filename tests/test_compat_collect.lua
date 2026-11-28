-- tests/test_compat_collect.lua — core/CompatCollect.lua, the collection-side reads this addon
-- still makes on NS.Compat (issue #13, categories design spec §2): each member's answer, its absent
-- value with the API missing, a secret answer reading as absent, never a raise; the cosmetic flag, a
-- class's client name and a curated sample's link by its id (DW-CAT6); the simulator's seam
-- wrapping every member; and no other shipped file naming the APIs. The mount, pet, toy, recipe,
-- profession, tier-token slot and use-text reads are LibKa0s-Verdict-1.0's own (LibKa0s#111), pinned
-- by the library's suites.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local RECIPE = "|cnIQ3:|Hitem:5001::::::::90:::::|h[Pattern: Cloak]|h|r"
local CLOAK  = "|cnIQ4:|Hitem:5002::::::::90:::::|h[Cosmetic Cloak]|h|r"

local function fresh(opts)
    local NS, _, m = T.newAddon(opts)
    m.issecretvalue = function(v) return T.isSecret(v) end
    return NS.Compat, m, NS
end

-- ---------------------------------------------------------------------------------------------
-- Cosmetics
-- ---------------------------------------------------------------------------------------------

test("compat collect: IsCosmeticItem answers the client's flag, false without", function()
    local Compat, m = fresh()
    m.cosmetic[CLOAK] = true
    assertTrue(Compat.IsCosmeticItem(CLOAK))
    assertFalse(Compat.IsCosmeticItem(RECIPE))
    assertFalse(Compat.IsCosmeticItem(T.secret(CLOAK)), "a secret link")
    m.C_Item.IsCosmeticItem = function() return T.secret(true) end
    assertFalse(Compat.IsCosmeticItem(CLOAK), "a secret answer")
    m.C_Item.IsCosmeticItem = nil
    assertFalse(Compat.IsCosmeticItem(CLOAK), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- Class names (DW-CAT4)
-- ---------------------------------------------------------------------------------------------

test("compat collect: ClassDisplayName answers the client's name for a class, else nil", function()
    local Compat, m = fresh()
    assertEqual(Compat.ClassDisplayName("DEATHKNIGHT"), "Death Knight")
    assertNil(Compat.ClassDisplayName("NOBODY"))
    assertNil(Compat.ClassDisplayName(nil))
    m.LOCALIZED_CLASS_NAMES_MALE.MAGE = T.secret("Mage")
    assertNil(Compat.ClassDisplayName("MAGE"), "a secret name")
    m.LOCALIZED_CLASS_NAMES_MALE = nil
    assertNil(Compat.ClassDisplayName("WARRIOR"), "no table")
end)

test("compat collect: ItemLinkByID answers a cached item's link by its id, else nil (DW-CAT6)", function()
    local Compat, m = fresh()
    m.addItem(RECIPE, { name = "Pattern: Cloak", quality = 3, ilvl = 1, classID = 9, subClassID = 2 })
    local byLink = m.C_Item.GetItemInfo
    m.C_Item.GetItemInfo = function(x)
        if x == 5001 then return byLink(RECIPE) end
        if x == 5003 then return "Odd", T.secret(RECIPE) end
        if x == 5004 then return "Odd", "item:5004" end
        return nil
    end
    assertEqual(Compat.ItemLinkByID(5001), RECIPE)
    assertNil(Compat.ItemLinkByID(5002), "not cached")
    assertNil(Compat.ItemLinkByID(5003), "a secret link")
    assertNil(Compat.ItemLinkByID(5004), "not a hyperlink")
    assertNil(Compat.ItemLinkByID(0), "no item id")
    m.C_Item.GetItemInfo = nil
    assertNil(Compat.ItemLinkByID(5001), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- The seam and the family
-- ---------------------------------------------------------------------------------------------

local MEMBERS = { "IsCosmeticItem", "ClassDisplayName", "ItemLinkByID" }

test("compat collect: no member raises with every API gone", function()
    local Compat, m = fresh()
    m.C_MountJournal, m.C_PetJournal, m.C_ToyBox, m.PlayerHasToy = nil, nil, nil, nil
    m.C_TooltipInfo, m.GetProfessions, m.GetProfessionInfo, m.C_Item.IsCosmeticItem = nil, nil, nil, nil
    m.LOCALIZED_CLASS_NAMES_MALE, m.C_Spell, m.C_Item.GetItemSpell = nil, nil, nil
    for _, name in ipairs(MEMBERS) do
        for _, arg in ipairs({ 1, RECIPE, false, {} }) do
            assertTrue(pcall(Compat[name], arg), name .. " raised")
        end
    end
end)

test("compat collect: the simulator's seam wraps every collection member (the TOC order)", function()
    local _, _, NS = fresh()
    local wrapped = {}
    for _, key in ipairs(NS.SimSeam:Keys()) do wrapped[key] = true end
    for _, name in ipairs(MEMBERS) do assertTrue(wrapped[name], name .. " is not wrapped") end
end)

local COLLECT_APIS = { "C_MountJournal", "C_PetJournal", "C_ToyBox", "PlayerHasToy", "IsCosmeticItem",
    "GetProfessions%f[^%w_]", "GetProfessionInfo", "ITEM_SPELL_KNOWN", "C_Spell", "GetItemSpell",
    "GetSpellDescription", "ITEM_SPELL_TRIGGER_ONUSE", "RequestLoadSpellData" }

test("compat collect: no other shipped file names a collection API in code", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "core/CompatCollect.lua" then
            local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = fh:read("*a"); fh:close()
            local code = src:gsub("%-%-[^\r\n]*", ""):gsub('"[^"\r\n]*"', '""')
            for _, api in ipairs(COLLECT_APIS) do
                -- red under: libs/LibKa0s/VerdictCollect.lua calling C_ToyBox.GetToyInfo itself
                assertNil(code:find("[^%w_.]" .. api), rel .. " names " .. api .. " outside core/CompatCollect.lua")
            end
        end
    end
end)
