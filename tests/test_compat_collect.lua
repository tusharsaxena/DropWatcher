-- tests/test_compat_collect.lua — core/CompatCollect.lua, the collection reads on NS.Compat (issue
-- #13, categories design spec §2): each member's answer, its absent value with the API missing, a
-- secret answer reading as absent, never a raise; the recipe's known line and a tier token's slot
-- line matched only by their whole text, and the token's use line (TT-1) only by its class phrase and
-- its "set <slot> item", in the locale table's words; a class's client name; a curated sample's link by its id
-- (DW-CAT6); the simulator's seam wrapping every
-- member; and no other shipped file naming the APIs.

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
-- Mounts
-- ---------------------------------------------------------------------------------------------

test("compat collect: MountFromItem answers the journal's mount id, else nil", function()
    local Compat, m = fresh()
    m.mounts.byItem[100] = 42
    assertEqual(Compat.MountFromItem(100), 42)
    assertNil(Compat.MountFromItem(101), "not a mount item")
    assertNil(Compat.MountFromItem(nil), "no item id")
    m.mounts.byItem[102] = T.secret(43)
    assertNil(Compat.MountFromItem(102), "a secret answer")
    m.C_MountJournal = nil
    assertNil(Compat.MountFromItem(100), "no API")
end)

test("compat collect: MountCollected answers isCollected, the 11th return, else nil", function()
    local Compat, m = fresh()
    m.mounts.collected[42], m.mounts.collected[43] = true, false
    assertTrue(Compat.MountCollected(42))
    assertFalse(Compat.MountCollected(43))
    assertNil(Compat.MountCollected(44), "journal data not loaded yet")
    m.mounts.collected[45] = T.secret(true)
    assertNil(Compat.MountCollected(45), "a secret answer")
    m.C_MountJournal = {}
    assertNil(Compat.MountCollected(42), "no GetMountInfoByID")
end)

-- ---------------------------------------------------------------------------------------------
-- Battle pets
-- ---------------------------------------------------------------------------------------------

test("compat collect: PetSpeciesFromItem answers the 13th return, the species id, else nil", function()
    local Compat, m = fresh()
    m.pets.byItem[200] = 7
    assertEqual(Compat.PetSpeciesFromItem(200), 7)
    assertNil(Compat.PetSpeciesFromItem(201))
    m.pets.byItem[202] = T.secret(8)
    assertNil(Compat.PetSpeciesFromItem(202), "a secret answer")
    m.C_PetJournal = nil
    assertNil(Compat.PetSpeciesFromItem(200), "no API")
end)

test("compat collect: PetCollected answers the count and the limit, else nil, nil", function()
    local Compat, m = fresh()
    m.pets.counts[7] = { 1, 3 }
    local count, limit = Compat.PetCollected(7)
    assertEqual(count, 1); assertEqual(limit, 3)
    m.pets.counts[8] = { 0, 3 }
    assertEqual((Compat.PetCollected(8)), 0, "none collected is 0, not nil")
    count, limit = Compat.PetCollected(9)
    assertNil(count); assertNil(limit)
    m.pets.counts[10] = { T.secret(2), 3 }
    count, limit = Compat.PetCollected(10)
    assertNil(count, "a secret count"); assertNil(limit)
    m.C_PetJournal = nil
    count, limit = Compat.PetCollected(7)
    assertNil(count); assertNil(limit)
end)

-- ---------------------------------------------------------------------------------------------
-- Toys and cosmetics
-- ---------------------------------------------------------------------------------------------

test("compat collect: IsToy answers whether GetToyInfo knows the item, false without", function()
    local Compat, m = fresh()
    m.toys[300] = true
    assertTrue(Compat.IsToy(300))
    assertFalse(Compat.IsToy(301))
    m.C_ToyBox = { GetToyInfo = function() return T.secret(302) end }
    assertFalse(Compat.IsToy(302), "a secret answer")
    m.C_ToyBox = nil
    assertFalse(Compat.IsToy(300), "no API")
end)

test("compat collect: ToyCollected answers PlayerHasToy, else nil", function()
    local Compat, m = fresh()
    m.toysOwned[300] = true
    assertTrue(Compat.ToyCollected(300))
    assertFalse(Compat.ToyCollected(301))
    m.PlayerHasToy = function() return T.secret(true) end
    assertNil(Compat.ToyCollected(300), "a secret answer")
    m.PlayerHasToy = nil
    assertNil(Compat.ToyCollected(300), "no API")
end)

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
-- Recipes and professions
-- ---------------------------------------------------------------------------------------------

local function lines(...)
    local data = { lines = {} }
    for i, text in ipairs({ ... }) do data.lines[i] = { type = 0, leftText = text } end
    return data
end

test("compat collect: RecipeKnown reads the Already known line by its whole text", function()
    local Compat, m = fresh()
    m.tooltips.hyperlink[RECIPE] = lines("Pattern: Cloak", "Already known")
    assertTrue(Compat.RecipeKnown(RECIPE))
    m.tooltips.hyperlink[RECIPE] = lines("Pattern: Cloak", "Requires Tailoring (50)")
    assertFalse(Compat.RecipeKnown(RECIPE), "read, and no such line")
    -- red under: a substring match, which a flavor text quoting the words would fool
    m.tooltips.hyperlink[RECIPE] = lines("Pattern: Cloak", "\"Already known to the elders.\"")
    assertFalse(Compat.RecipeKnown(RECIPE), "a line that only contains the words")
    m.ITEM_SPELL_KNOWN = "Bereits bekannt"
    m.tooltips.hyperlink[RECIPE] = lines("Muster: Umhang", "Bereits bekannt")
    assertTrue(Compat.RecipeKnown(RECIPE), "the localized GlobalString, read at call time")
end)

test("compat collect: RecipeKnown answers nil when it cannot tell", function()
    local Compat, m = fresh()
    assertNil(Compat.RecipeKnown(RECIPE), "no tooltip data")
    m.tooltips.hyperlink[RECIPE] = { lines = "nope" }
    assertNil(Compat.RecipeKnown(RECIPE), "a malformed answer")
    m.tooltips.hyperlink[RECIPE] = lines("Pattern: Cloak", T.secret("Already known"))
    assertNil(Compat.RecipeKnown(RECIPE), "a secret line: not read as unknown-to-you")
    m.tooltips.hyperlink[RECIPE] = T.secret(lines("Already known"))
    assertNil(Compat.RecipeKnown(RECIPE), "a secret answer")
    m.tooltips.hyperlink[RECIPE] = lines("Already known")
    assertNil(Compat.RecipeKnown(T.secret(RECIPE)), "a secret link")
    m.ITEM_SPELL_KNOWN = nil
    assertNil(Compat.RecipeKnown(RECIPE), "no GlobalString")
    m.ITEM_SPELL_KNOWN = "Already known"
    m.C_TooltipInfo = nil
    assertNil(Compat.RecipeKnown(RECIPE), "no C_TooltipInfo")
end)

test("compat collect: ProfessionSkillLines maps every profession slot to its skill line", function()
    local Compat, m = fresh()
    m.professions = { 197, 165, false, 356, 185 }
    local got = Compat.ProfessionSkillLines()
    for _, line in ipairs({ 197, 165, 356, 185 }) do assertTrue(got[line], "skill line " .. line) end
    assertNil(got[202])
    m.professions = {}
    got = Compat.ProfessionSkillLines()
    -- red under: an empty table for no API too, so "no profession" could not be told from "no answer"
    assertEqual(type(got), "table", "no professions is an answer"); assertNil(next(got), "and it is empty")
    m.GetProfessionInfo = function() return "x", 0, 1, 1, 0, 0, T.secret(197) end
    m.professions = { 197 }
    assertNil(Compat.ProfessionSkillLines(), "a secret skill line is no answer")
    m.GetProfessions = function() return T.secret(1) end
    assertNil(Compat.ProfessionSkillLines(), "a secret index is no answer")
    m.GetProfessions = nil
    assertNil(Compat.ProfessionSkillLines(), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- Tier tokens (DW-CAT4)
-- ---------------------------------------------------------------------------------------------

local TOKEN = "|cnIQ4:|Hitem:5003::::::::90:::::|h[Dreadful Helm Module]|h|r"

test("compat collect: TierTokenSlot reads a slot line by its whole text", function()
    local Compat, m = fresh()
    m.tooltips.hyperlink[TOKEN] = lines("Dreadful Helm Module", "Classes: Mage", "Legs")
    assertEqual(Compat.TierTokenSlot(TOKEN), "INVTYPE_LEGS")
    -- red under: a substring match, which a flavor text naming a slot would fool
    m.tooltips.hyperlink[TOKEN] = lines("Dreadful Helm Module", "\"Hands of the fallen.\"")
    assertNil(Compat.TierTokenSlot(TOKEN), "a line that only contains the word")
    m.tooltips.hyperlink[TOKEN] = lines("Feet")
    assertNil(Compat.TierTokenSlot(TOKEN), "not a tier slot")
    m.INVTYPE_HEAD = "Kopf"
    m.tooltips.hyperlink[TOKEN] = lines("Kopf")
    assertEqual(Compat.TierTokenSlot(TOKEN), "INVTYPE_HEAD", "the localized GlobalString, read at call time")
end)

test("compat collect: TierTokenSlot answers nil when it cannot tell", function()
    local Compat, m = fresh()
    assertNil(Compat.TierTokenSlot(TOKEN), "no tooltip data")
    m.tooltips.hyperlink[TOKEN] = { lines = "nope" }
    assertNil(Compat.TierTokenSlot(TOKEN), "a malformed answer")
    m.tooltips.hyperlink[TOKEN] = lines(T.secret("Head"))
    assertNil(Compat.TierTokenSlot(TOKEN), "a secret line")
    m.tooltips.hyperlink[TOKEN] = T.secret(lines("Head"))
    assertNil(Compat.TierTokenSlot(TOKEN), "a secret answer")
    m.tooltips.hyperlink[TOKEN] = lines("Head")
    assertNil(Compat.TierTokenSlot(T.secret(TOKEN)), "a secret link")
    m.INVTYPE_HEAD = nil
    assertNil(Compat.TierTokenSlot(TOKEN), "no GlobalString for the slot")
    m.INVTYPE_HEAD = "Head"
    m.C_TooltipInfo = nil
    assertNil(Compat.TierTokenSlot(TOKEN), "no C_TooltipInfo")
end)

test("compat collect: TierTokenSlot reads the slot a token's use line names (TT-1)", function()
    local Compat, m = fresh()
    local function slotOf(text)
        m.tooltips.hyperlink[TOKEN] = lines("Voidglass Token", "Classes: Mage", text)
        return Compat.TierTokenSlot(TOKEN)
    end
    -- red under: the whole-line read alone, which no current token's tooltip answers
    assertEqual(slotOf("Use: Create a soulbound Voidglass set chest item appropriate for your class."),
        "INVTYPE_CHEST", "Create, with a raid name")
    assertEqual(slotOf("Use: Synthesize a soulbound set hand item appropriate for your class."),
        "INVTYPE_HAND", "Synthesize, no raid name")
    assertEqual(slotOf("Use: Create a soulbound Liberation of Undermine set leg item appropriate for your class"),
        "INVTYPE_LEGS", "a raid name of several words, no full stop")
    assertEqual(slotOf("USE: CREATE A SOULBOUND SET SHOULDER ITEM APPROPRIATE FOR YOUR CLASS."),
        "INVTYPE_SHOULDER", "any case")
    assertEqual(slotOf("Use: Create a soulbound Sunset set head item appropriate for your class."),
        "INVTYPE_HEAD", "a raid name ending in set")
end)

test("compat collect: TierTokenSlot's use-line read refuses lines that only look like one (TT-1)", function()
    local Compat, m = fresh()
    local function slotOf(text)
        m.tooltips.hyperlink[TOKEN] = lines("Voidglass Token", text)
        return Compat.TierTokenSlot(TOKEN)
    end
    assertNil(slotOf("Use: Create a soulbound set feet item appropriate for your class."), "not a tier slot")
    assertNil(slotOf("Create a soulbound set chest item appropriate for your class."), "no Use: prefix")
    assertNil(slotOf("\"Use: Create a soulbound set chest item appropriate for your class.\""), "flavor text")
    assertNil(slotOf("Use: Create a soulbound set chest item."), "no class clause")
    assertNil(slotOf("Use: Create a soulbound Voidset chest item appropriate for your class."), "no set word")
    assertNil(slotOf("Use: Create a soulbound Tier 19 item appropriate for your class."), "no set <slot> item")
    assertNil(slotOf("Use: Create a soulbound set chestpiece item appropriate for your class."), "a longer word")
    m.tooltips.hyperlink[TOKEN] = lines(T.secret("Use: Create a soulbound set chest item appropriate for your class."))
    assertNil(Compat.TierTokenSlot(TOKEN), "a secret line")
end)

test("compat collect: TierTokenSlot prefers a whole slot line, and reads the client's Use: (TT-1)", function()
    local Compat, m = fresh()
    m.tooltips.hyperlink[TOKEN] = lines("Use: Create a soulbound set chest item appropriate for your class.", "Legs")
    -- red under: one pass over both reads, where the earlier use line would win
    assertEqual(Compat.TierTokenSlot(TOKEN), "INVTYPE_LEGS", "the whole-line read runs first")
    m.ITEM_SPELL_TRIGGER_ONUSE = "Benutzen:"
    m.tooltips.hyperlink[TOKEN] = lines("Benutzen: Create a soulbound set chest item appropriate for your class.")
    assertEqual(Compat.TierTokenSlot(TOKEN), "INVTYPE_CHEST", "ITEM_SPELL_TRIGGER_ONUSE, read at call time")
    m.tooltips.hyperlink[TOKEN] = lines("Use: Create a soulbound set chest item appropriate for your class.")
    assertNil(Compat.TierTokenSlot(TOKEN), "the client's own prefix, not a hard-coded one")
    m.ITEM_SPELL_TRIGGER_ONUSE = T.secret("Use:")
    assertEqual(Compat.TierTokenSlot(TOKEN), "INVTYPE_CHEST", "a secret GlobalString falls back to Use:")
end)

test("compat collect: TierTokenSlot's use-line words are the locale table's (TT-1)", function()
    local Compat, m, NS = fresh()
    local L = NS.L
    L["appropriate for your class"], L["set %s item"] = "passend fuer eure Klasse", "Setteil %s"
    L["hand hands"] = "Haende Hand"
    -- red under: the class phrase, the template or the slot words written in the matcher itself
    m.tooltips.hyperlink[TOKEN] = lines("Use: Erschafft ein Setteil Hand, passend fuer eure Klasse.")
    assertEqual(Compat.TierTokenSlot(TOKEN), "INVTYPE_HAND", "the table's words, read")
    m.tooltips.hyperlink[TOKEN] = lines("Use: Create a soulbound set hand item appropriate for your class.")
    assertNil(Compat.TierTokenSlot(TOKEN), "the enUS words, no longer the table's, never matched")
end)

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

local MEMBERS = { "MountFromItem", "MountCollected", "PetSpeciesFromItem", "PetCollected", "IsToy",
    "ToyCollected", "IsCosmeticItem", "RecipeKnown", "ProfessionSkillLines", "TierTokenSlot", "ClassDisplayName",
    "ItemLinkByID" }

test("compat collect: no member raises with every API gone", function()
    local Compat, m = fresh()
    m.C_MountJournal, m.C_PetJournal, m.C_ToyBox, m.PlayerHasToy = nil, nil, nil, nil
    m.C_TooltipInfo, m.GetProfessions, m.GetProfessionInfo, m.C_Item.IsCosmeticItem = nil, nil, nil, nil
    m.LOCALIZED_CLASS_NAMES_MALE = nil
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
    "GetProfessions%f[^%w_]", "GetProfessionInfo", "ITEM_SPELL_KNOWN" }

test("compat collect: no other shipped file names a collection API in code", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "core/CompatCollect.lua" then
            local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = fh:read("*a"); fh:close()
            local code = src:gsub("%-%-[^\r\n]*", ""):gsub('"[^"\r\n]*"', '""')
            for _, api in ipairs(COLLECT_APIS) do
                -- red under: modules/Collectibles.lua calling C_ToyBox.GetToyInfo itself
                assertNil(code:find("[^%w_.]" .. api), rel .. " names " .. api .. " outside core/CompatCollect.lua")
            end
        end
    end
end)
