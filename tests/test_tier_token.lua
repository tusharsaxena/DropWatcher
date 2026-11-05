-- tests/test_tier_token.lua — tier tokens judged as gear (issue #13, categories design spec §3.1,
-- §7; modules/TierTokens.lua, the token path of modules/ItemFacts.lua and modules/Evaluate.lua):
-- the slot from the curated table, then the tooltip, else none and `unknown`; a concrete slot
-- becoming the equipLoc and judged upgrade, sidegrade or downgrade against what is worn there; the
-- wrong class `cantUse`; an omni Curio with no class line reaching `ok` and folded to its best slot;
-- the scorer skipped and the caller's opts untouched; the looter's verdict on their own gear; the
-- facts cache never written; a token through the feed; and its Slot, Type and Makes cells.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MISC, JUNK_SUB, CLOTH, PLATE = 15, 0, 1, 4

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

-- A token's tooltip: its class line (nil for none) and any other lines.
local function tip(classes, ...)
    local data = { lines = {} }
    if classes then data.lines[1] = { type = 21, leftText = "Classes: " .. classes } end
    for _, text in ipairs({ ... }) do data.lines[#data.lines + 1] = { type = 0, leftText = text } end
    return data
end

local function token(ilvl)
    return { name = "Token", quality = 4, ilvl = ilvl or 620, equipLoc = "", classID = MISC, subClassID = JUNK_SUB,
        bindType = 1, stats = {} }
end

local function hasReason(res, key)
    for _, r in ipairs(res.reasons or {}) do
        if r.key == key then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- The slot a token makes (ItemFacts and NS.TierTokens.SlotOf)
-- ---------------------------------------------------------------------------------------------

test("tier token: the slot is read off the tooltip, and becomes the equipLoc", function()
    local NS, m = T.enableAddon()
    m.addItem(link(700), token())
    m.tooltips.hyperlink[link(700)] = tip("Mage, Priest", "Head")
    local f = NS.ItemFacts.Get(link(700))
    assertTrue(f.isTierToken); assertEqual(f.category, "tierToken")
    assertEqual(f.tokenSlot, "INVTYPE_HEAD"); assertEqual(f.tokenSlotSource, "tooltip")
    -- red under: ItemFacts leaving the raw slot, so the kernel finds no slot plan
    assertEqual(f.equipLoc, "INVTYPE_HEAD", "the slot the token makes")
    assertEqual(f.rawEquipLoc, "", "the client's own slot is kept")
    assertNil(f.transmogKnown, "a token has no appearance: read from the raw slot")
end)

test("tier token: the curated table beats the tooltip, and lists a Curio with no class line", function()
    local NS, m = T.enableAddon()
    NS.Constants.TIER_TOKENS[701] = { slot = "INVTYPE_LEGS" }
    NS.Constants.TIER_TOKENS[702] = { slot = "any" }
    m.addItem(link(701), token()); m.addItem(link(702), token())
    m.tooltips.hyperlink[link(701)] = tip("Mage", "Head")
    m.tooltips.hyperlink[link(702)] = tip(nil, "Head")
    local legs, curio = NS.ItemFacts.Get(link(701)), NS.ItemFacts.Get(link(702))
    assertEqual(legs.tokenSlot, "INVTYPE_LEGS"); assertEqual(legs.tokenSlotSource, "table")
    assertEqual(legs.equipLoc, "INVTYPE_LEGS")
    -- red under: isTierToken from the class line alone (a Curio names no class)
    assertTrue(curio.isTierToken); assertNil(curio.classes)
    assertEqual(curio.tokenSlot, "any"); assertEqual(curio.equipLoc, "", "any slot keeps the raw one")
end)

test("tier token: a slot line is matched by its whole text; none read leaves the slot nil", function()
    local NS, m = T.enableAddon()
    m.addItem(link(703), token()); m.addItem(link(704), token())
    -- red under: a substring match, which the flavor text would fool
    m.tooltips.hyperlink[link(703)] = tip("Mage", "\"Head of the order.\"", "Hands of a thief")
    m.tooltips.hyperlink[link(704)] = tip("Mage")
    for _, id in ipairs({ 703, 704 }) do
        local f = NS.ItemFacts.Get(link(id))
        assertTrue(f.isTierToken); assertNil(f.tokenSlot); assertEqual(f.equipLoc, "")
    end
    assertNil(NS.TierTokens.SlotOf({ itemID = 9 }, function() return "INVTYPE_FEET" end), "not a tier slot")
    assertNil(NS.TierTokens.SlotOf({ itemID = 9 }, function() return "any" end), "the tooltip never says any")
end)

test("tier token: the tooltip is not read when the table answers", function()
    local NS = T.newAddon()
    NS.Constants.TIER_TOKENS[705] = { slot = "INVTYPE_CHEST" }
    local asked = 0
    local slot, source = NS.TierTokens.SlotOf({ itemID = 705 }, function() asked = asked + 1 return "INVTYPE_HEAD" end)
    assertEqual(slot, "INVTYPE_CHEST"); assertEqual(source, "table"); assertEqual(asked, 0)
    assertFalse(NS.TierTokens.Listed(706)); assertTrue(NS.TierTokens.Listed(705))
end)

-- ---------------------------------------------------------------------------------------------
-- The verdict (NS.Evaluate)
-- ---------------------------------------------------------------------------------------------

local function kernel()
    local NS = T.newAddon()
    return NS.Evaluate, NS.Constants
end

local function worn(C, ilvl, loc, sub)
    return { itemID = 1, ilvl = ilvl, equipLoc = loc, classID = C.ITEM_CLASS.ARMOR, subClassID = sub or CLOTH }
end

-- A mage wearing a head, shoulder, chest, hands and legs at the levels given.
local function mage(C, levels)
    local S, gear = C.SLOT, {}
    gear[S.HEAD], gear[S.SHOULDER] = worn(C, levels[1], "INVTYPE_HEAD"), worn(C, levels[2], "INVTYPE_SHOULDER")
    gear[S.CHEST], gear[S.HANDS] = worn(C, levels[3], "INVTYPE_CHEST"), worn(C, levels[4], "INVTYPE_HAND")
    gear[S.LEGS] = worn(C, levels[5], "INVTYPE_LEGS")
    return { classFile = "MAGE", specID = 64, gear = gear }
end

local function tokenFacts(ilvl, slot, classes)
    return { itemID = 707, ilvl = ilvl, equipLoc = slot ~= "any" and slot or "", rawEquipLoc = "", classID = MISC,
        subClassID = JUNK_SUB, isTierToken = true, tokenSlot = slot, classes = classes, category = "tierToken",
        stats = {} }
end

test("tier token: a concrete slot is upgrade, sidegrade or downgrade against what is worn there", function()
    local E, C = kernel()
    local who = mage(C, { 610, 600, 600, 600, 600 })
    local mages = { MAGE = true, PRIEST = true, WARLOCK = true }
    local up = E.Evaluate(tokenFacts(620, "INVTYPE_HEAD", mages), who)
    assertEqual(up.equip, "ok"); assertEqual(up.verdict, "upgrade"); assertEqual(up.ilvlDelta, 10)
    assertEqual(up.baselineSlot, C.SLOT.HEAD)
    assertEqual(E.Evaluate(tokenFacts(610, "INVTYPE_HEAD", mages), who).verdict, "sidegrade")
    assertEqual(E.Evaluate(tokenFacts(605, "INVTYPE_HEAD", mages), who, { sidegradeBand = 2 }).verdict, "downgrade")
    assertEqual(E.Evaluate(tokenFacts(609, "INVTYPE_HEAD", mages), who, { sidegradeBand = 2 }).verdict, "sidegrade")
end)

test("tier token: another class's token is cantUse; a slot not read is unknown, reason tierToken", function()
    local E, C = kernel()
    local who = mage(C, { 600, 600, 600, 600, 600 })
    local res = E.Evaluate(tokenFacts(620, "INVTYPE_HEAD", { WARRIOR = true, PALADIN = true }), who)
    assertEqual(res.verdict, "cantUse"); assertTrue(hasReason(res, "classRestricted"))
    -- red under: planFor answering notGear for a token with its classes but no slot read
    res = E.Evaluate(tokenFacts(620, nil, { MAGE = true }), who)
    assertEqual(res.verdict, "unknown"); assertTrue(hasReason(res, "tierToken"))
    assertFalse(hasReason(res, "notGear"))
end)

test("tier token: a Curio with no class line folds to its best slot", function()
    local E, C = kernel()
    local who = mage(C, { 630, 625, 600, 640, 610 })
    -- red under: usable() answering unknown/tierToken for a token with no class list
    local res = E.Evaluate(tokenFacts(620, "any", nil), who)
    assertEqual(res.equip, "ok")
    assertEqual(res.verdict, "upgrade"); assertEqual(res.ilvlDelta, 20, "the chest, the largest gain")
    assertEqual(res.tokenSlot, "INVTYPE_CHEST"); assertEqual(res.baselineSlot, C.SLOT.CHEST)
    who.gear[C.SLOT.LEGS] = false
    res = E.Evaluate(tokenFacts(620, "any", nil), who)
    assertEqual(res.tokenSlot, "INVTYPE_LEGS", "an empty slot beats any gain")
    who = mage(C, { 640, 640, 630, 650, 640 })
    res = E.Evaluate(tokenFacts(620, "any", nil), who)
    assertEqual(res.verdict, "downgrade"); assertEqual(res.tokenSlot, "INVTYPE_CHEST", "the least loss")
end)

test("tier token: a Curio of another class is cantUse, naming no slot", function()
    local E, C = kernel()
    local res = E.Evaluate(tokenFacts(620, "any", { WARRIOR = true }), mage(C, { 600, 600, 600, 600, 600 }))
    assertEqual(res.verdict, "cantUse"); assertNil(res.tokenSlot)
end)

test("tier token: the scorer is skipped, and neither the opts nor the facts are written", function()
    local E, C = kernel()
    local scored = 0
    local opts = { scorer = function() scored = scored + 1 return 100 end, sidegradeBand = 0 }
    local facts = tokenFacts(620, "any", { MAGE = true })
    local before = {}
    for k, v in pairs(facts) do before[k] = v end
    local res = E.Evaluate(facts, mage(C, { 600, 600, 600, 600, 600 }), opts)
    -- red under: compare calling the scorer for a token (Pawn cannot value one)
    assertEqual(scored, 0); assertNil(res.scoreDelta)
    assertFalse(hasReason(res, "scorePending"))
    assertNil(opts.skipScore); assertEqual(type(opts.scorer), "function")
    -- red under: the fold setting equipLoc or tokenSlot on the cache's own facts
    for k, v in pairs(before) do assertEqual(facts[k], v, k) end
    for k in pairs(facts) do assertTrue(before[k] ~= nil, k .. " added") end
    local gear = E.Evaluate(worn(C, 620, "INVTYPE_HEAD"), mage(C, { 600, 600, 600, 600, 600 }), opts)
    assertEqual(gear.scoreDelta, 0, "gear is still scored")
end)

test("tier token: the looter is judged on their own class and gear", function()
    local E, C = kernel()
    local facts = tokenFacts(620, "INVTYPE_HAND", { WARRIOR = true, PALADIN = true })
    local brakk = { classFile = "WARRIOR", specID = 71, gear = { [C.SLOT.HANDS] = worn(C, 630, "INVTYPE_HAND", PLATE) } }
    local res = E.Evaluate(facts, brakk)
    assertEqual(res.verdict, "downgrade"); assertEqual(res.ilvlDelta, -10)
    assertEqual(E.Evaluate(facts, mage(C, { 600, 600, 600, 600, 600 })).verdict, "cantUse")
end)

-- ---------------------------------------------------------------------------------------------
-- Through the feed, and the cells
-- ---------------------------------------------------------------------------------------------

-- An enabled mage in a Heroic dungeon, wearing a 600 head, Brakk in the group.
local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    m.addItem(link(710), { name = "Hood", quality = 4, ilvl = 600, equipLoc = "INVTYPE_HEAD", classID = 4,
        subClassID = CLOTH, bindType = 1, stats = {} })
    m.inventory.player[1] = link(710)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    NS.Gear.Refresh("test")
    return NS, m
end

local function iLoot(m, id)
    m.__fire("CHAT_MSG_LOOT", "You receive loot: " .. link(id) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

test("tier token: through the feed, a token is judged against the head you wear", function()
    local NS, m = party()
    m.addItem(link(711), token(620))
    m.tooltips.hyperlink[link(711)] = tip("Mage, Priest, Warlock", "Head")
    iLoot(m, 711)
    local rec = NS.LootFeed.Drops()[1]
    assertEqual(rec.facts.equipLoc, "INVTYPE_HEAD")
    -- red under: the kernel answering unknown for the token's slot
    assertEqual(rec.me.verdict, "upgrade"); assertEqual(rec.me.ilvlDelta, 20)
end)

test("tier token: the minimum item level applies to a token", function()
    local NS, m = party()
    NS.SchemaRuntime.Set("feed.minIlvlMode", "absolute")
    NS.SchemaRuntime.Set("feed.minIlvl", 630)
    m.addItem(link(712), token(620))
    m.tooltips.hyperlink[link(712)] = tip("Mage", "Head")
    iLoot(m, 712)
    -- red under: FeedFilter returning before ilvlCheck for a tier token
    assertEqual(#NS.LootFeed.Drops(), 0, "hidden below the minimum")
end)

test("tier token: the Slot and Type cells name the slot and the classes", function()
    local NS = T.newAddon()
    local WC = NS.WindowCells
    local f = tokenFacts(620, "INVTYPE_HEAD", { PRIEST = true, MAGE = true, WARLOCK = true })
    local slot = WC.Slot({ facts = f })
    assertEqual(slot.text, "Token: Head")
    assertTrue(T.tipPlainJoined(slot.tip):find("Makes: Head", 1, true) ~= nil)
    local kind = WC.ArmorType({ facts = f })
    -- the client's class order, each name in its color
    assertEqual(T.tipPlain(kind.text), "Priest, Mage, Warlock"); assertTrue(kind.known)
    assertTrue(kind.text:find("|c", 1, true) ~= nil, "colored")
    local curio = tokenFacts(620, "any", nil)
    assertEqual(WC.Slot({ facts = curio }).text, "Token: any slot")
    assertEqual(WC.ArmorType({ facts = curio }).text, "Any class")
    local unread = WC.Slot({ facts = tokenFacts(620, nil, { MAGE = true }) })
    assertEqual(unread.text, "Token"); assertEqual(unread.tone, "muted")
end)

test("tier token: the detail card's Makes chip, and no type chip", function()
    local NS = T.newAddon()
    local f = tokenFacts(620, "INVTYPE_HEAD", { MAGE = true, PRIEST = true })
    local chips = NS.DetailCells.Chips({ facts = f })
    assertEqual(T.tipPlain(chips[1].text), "Makes: Head · Priest, Mage")
    for _, c in ipairs(chips) do assertTrue(T.tipPlain(c.text) ~= "Priest, Mage", "no type chip") end
    chips = NS.DetailCells.Chips({ facts = tokenFacts(620, nil, nil) })
    assertEqual(chips[1].text, "Makes: ?")
end)

test("tier token: the Me cell names a Curio's best slot; an unread slot's reason says so", function()
    local NS = T.newAddon()
    local WC = NS.WindowCells
    local cell = WC.Verdict({ verdict = "upgrade", ilvlDelta = 20, tokenSlot = "INVTYPE_LEGS", reasons = {} }, "me", "For you")
    assertTrue(T.tipPlainJoined(cell.tip):find("Best in: Legs", 1, true) ~= nil)
    cell = WC.Verdict({ verdict = "unknown", reasons = { { key = "tierToken" } } }, "me", "For you")
    assertTrue(T.tipPlainJoined(cell.tip):find("a tier token whose slot could not be read", 1, true) ~= nil)
end)
