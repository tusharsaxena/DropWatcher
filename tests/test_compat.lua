-- tests/test_compat.lua — core/Compat.lua, the one seam over version-variant client APIs (compat,
-- design spec §4): the secret guards on both load paths, the chat sender's ladder, the localized
-- duration decoder behind the trade timer (spec §7.4) in three client languages, the tooltip line
-- reader and its three readers, the restriction APIs, the bind helpers, the item readers, the Pawn
-- seam (spec §5.4) and the trade actions. Every shim is also driven with its API absent, where it
-- must answer its documented absent value and never raise, the inspect calls (spec §8) and the
-- feed's loot history and keystone map readers included.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function fresh(opts)
    local NS, _, m = T.newAddon(opts)
    return NS.Compat, m
end

local function installSecrets(m)
    m.issecretvalue = function(v) return T.isSecret(v) end
end

-- A C_TooltipInfo answer: each line is { type, leftText } (type nil for an untyped line).
local function tooltip(lines)
    local data = { lines = {} }
    for i, l in ipairs(lines) do data.lines[i] = { type = l[1], leftText = l[2], itemLevel = l[3] } end
    return data
end

local TRADE_LINE = "You may trade this item with players that were also eligible to loot this item "
    .. "for the next 1 hour 59 min."

-- ---------------------------------------------------------------------------------------------
-- Secret guards
-- ---------------------------------------------------------------------------------------------

test("compat: the secret guards are the library's members on a live load", function()
    local Compat = fresh()
    local lib = T.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(lib ~= nil, "the library is vendored")
    -- The live load's own LibStub answers a different table per instance; compare behavior.
    for _, name in ipairs({ "IsSecret", "CanAccess", "IsSafeKey" }) do
        assertEqual(type(Compat[name]), "function", name)
    end
    assertFalse(Compat.IsSecret(5))
    assertTrue(Compat.CanAccess(5))
    assertTrue(Compat.IsSafeKey(5))
    assertFalse(Compat.IsSafeKey(nil))
end)

test("compat: the guards answer the library's answers under the same fixture, on both load paths", function()
    local live, ml = fresh()
    local degraded, md = fresh{ skip = T.loadAddon.libFiles }
    installSecrets(ml); installSecrets(md)
    local values = { 5, "x", false, T.secret(7), T.secret("name") }
    for i, v in ipairs(values) do
        for _, name in ipairs({ "IsSecret", "CanAccess", "IsSafeKey" }) do
            assertEqual(degraded[name](v), live[name](v), name .. " on value " .. i)
        end
    end
    assertEqual(degraded.IsSafeKey(nil), live.IsSafeKey(nil))
    -- red under: a degraded IsSecret that answers false (the stub the library forbids for a guard)
    assertTrue(degraded.IsSecret(T.secret(1)))
    assertFalse(degraded.CanAccess(T.secret(1)))
end)

test("compat: with canaccessvalue present the degraded CanAccess asks it", function()
    local Compat, m = fresh{ skip = T.loadAddon.libFiles }
    m.canaccessvalue = function() return false end
    assertFalse(Compat.CanAccess(5))
end)

-- ---------------------------------------------------------------------------------------------
-- Chat sender
-- ---------------------------------------------------------------------------------------------

test("compat: ChatSender prefers C_ChatInfo.SendChatMessage", function()
    local Compat, m = fresh()
    m.SendChatMessage = function() error("the deprecated global was called") end
    Compat.ChatSender()("hi", "WHISPER", nil, "Seta-Silvermoon")
    assertEqual(#m.chatSent, 1)
    assertEqual(m.chatSent[1].target, "Seta-Silvermoon")
    assertEqual(m.chatSent[1].chatType, "WHISPER")
end)

test("compat: ChatSender falls back to the global, then to nil", function()
    local Compat, m = fresh()
    local sent
    m.C_ChatInfo = { InChatMessagingLockdown = function() return false end }
    m.SendChatMessage = function(text) sent = text end
    Compat.ChatSender()("hello")
    assertEqual(sent, "hello")
    m.SendChatMessage = nil
    assertNil(Compat.ChatSender())
    m.C_ChatInfo = nil
    assertNil(Compat.ChatSender())
end)

-- ---------------------------------------------------------------------------------------------
-- Pattern building and the duration decoder
-- ---------------------------------------------------------------------------------------------

test("compat: FormatToPattern captures %s and %d and escapes every magic character", function()
    local Compat = fresh()
    local p = Compat.FormatToPattern("%s receives loot: %s.")
    local who, what = ("Seta receives loot: [Ring]."):match("^" .. p .. "$")
    assertEqual(who, "Seta"); assertEqual(what, "[Ring]")
    assertNil(("Seta receives loot: [Ring]x"):match("^" .. p .. "$"), "the dot is literal")
    local a, b = ("x 3 (y) 4"):match(Compat.FormatToPattern("%1$s %2$d (y) %d"))
    assertEqual(a, "x"); assertEqual(b, "3")
    assertTrue(("50% [a]+?"):find(Compat.FormatToPattern("50% [a]+?")) ~= nil, "magic is literal")
end)

test("compat: DecodeDuration reads every enUS unit and their sums", function()
    local Compat = fresh()
    assertEqual(Compat.DecodeDuration("1 hour 59 min"), 7140)
    assertEqual(Compat.DecodeDuration("2 hrs"), 7200)
    assertEqual(Compat.DecodeDuration("1 hour"), 3600)
    assertEqual(Compat.DecodeDuration("45 min"), 2700)
    assertEqual(Compat.DecodeDuration("30 sec"), 30)
    assertEqual(Compat.DecodeDuration("  1 min 5 sec "), 65, "surrounding space is trimmed")
end)

test("compat: DecodeDuration refuses anything that is not wholly a duration", function()
    local Compat = fresh()
    assertNil(Compat.DecodeDuration("soon"))
    assertNil(Compat.DecodeDuration("1 hour banana"))
    assertNil(Compat.DecodeDuration(""))
    assertNil(Compat.DecodeDuration(nil))
    assertNil(Compat.DecodeDuration(42))
end)

test("compat: DecodeDuration never touches a secret", function()
    local Compat, m = fresh()
    installSecrets(m)
    -- red under: a decoder that matches before asking IsSecret (indexing the wrapper raises)
    assertNil(Compat.DecodeDuration(T.secret("1 hour")))
end)

test("compat: DecodeDuration reads the client's own language (deDE, with a two-form plural)", function()
    local Compat, m = fresh()
    m.INT_SPELL_DURATION_HOURS = "%d |4Stunde:Stunden;"
    m.INT_SPELL_DURATION_MIN = "%d Min."
    m.INT_SPELL_DURATION_SEC = "%d Sek."
    assertEqual(Compat.DecodeDuration("1 Stunde 59 Min."), 7140)
    assertEqual(Compat.DecodeDuration("2 Stunden"), 7200)
    assertNil(Compat.DecodeDuration("1 hour"), "the enUS words no longer read")
end)

test("compat: DecodeDuration reads a three-form plural and a multi-character delimiter", function()
    local Compat, m = fresh()
    m.INT_SPELL_DURATION_HOURS = "%d |4час:часа:часов;"
    m.INT_SPELL_DURATION_MIN = "%d мин."
    m.TIME_UNIT_DELIMITER = ", "
    assertEqual(Compat.DecodeDuration("5 часов"), 18000)
    assertEqual(Compat.DecodeDuration("1 час, 2 мин."), 3720)
    assertEqual(Compat.DecodeDuration("3 часа"), 10800)
end)

test("compat: DecodeDuration answers nil when the client has no duration globals", function()
    local Compat, m = fresh()
    m.INT_SPELL_DURATION_HOURS, m.INT_SPELL_DURATION_MIN, m.INT_SPELL_DURATION_SEC = nil, nil, nil
    m.TIME_UNIT_DELIMITER = nil
    assertNil(Compat.DecodeDuration("1 hour"))
end)

test("compat: ParseTradeTimeRemaining reads the whole trade line and nothing else", function()
    local Compat, m = fresh()
    assertEqual(Compat.ParseTradeTimeRemaining(TRADE_LINE), 7140)
    assertNil(Compat.ParseTradeTimeRemaining("Binds when picked up"))
    assertNil(Compat.ParseTradeTimeRemaining(TRADE_LINE .. " extra"))
    m.BIND_TRADE_TIME_REMAINING = nil
    assertNil(Compat.ParseTradeTimeRemaining(TRADE_LINE), "no global, no guess")
end)

-- ---------------------------------------------------------------------------------------------
-- The tooltip line reader and its readers
-- ---------------------------------------------------------------------------------------------

test("compat: TradeTimeRemaining reads the TradeTimeRemaining line of a bag item", function()
    local Compat, m = fresh()
    local TT = m.Enum.TooltipDataLineType
    m.tooltips.bag["0:3"] = tooltip{ { 29, "Ring of Testing" }, { TT.ItemBinding, "Soulbound" },
        { TT.TradeTimeRemaining, TRADE_LINE } }
    assertEqual(Compat.TradeTimeRemaining(0, 3), 7140)
    assertNil(Compat.TradeTimeRemaining(0, 4), "no tooltip")
end)

test("compat: with the line type known, only lines of that type are read", function()
    local Compat, m = fresh()
    -- red under: a reader that ignores the type and parses every line
    m.tooltips.bag["0:1"] = tooltip{ { 7, TRADE_LINE } }
    assertNil(Compat.TradeTimeRemaining(0, 1))
end)

test("compat: without the enum member the reader falls back to the localized text", function()
    local Compat, m = fresh()
    m.Enum.TooltipDataLineType.TradeTimeRemaining = nil
    m.tooltips.bag["1:2"] = tooltip{ { 29, "Ring of Testing" }, { 99, TRADE_LINE } }
    assertEqual(Compat.TradeTimeRemaining(1, 2), 7140)
    m.Enum = nil
    assertEqual(Compat.TradeTimeRemaining(1, 2), 7140, "no Enum at all")
end)

test("compat: the tooltip reader skips a secret line and survives a malformed answer", function()
    local Compat, m = fresh()
    installSecrets(m)
    local TT = m.Enum.TooltipDataLineType
    m.tooltips.bag["0:5"] = tooltip{ { TT.TradeTimeRemaining, T.secret(TRADE_LINE) } }
    assertNil(Compat.TradeTimeRemaining(0, 5))
    m.tooltips.bag["0:6"] = { lines = { "not a table", { type = T.secret(36), leftText = "x" } } }
    assertNil(Compat.TradeTimeRemaining(0, 6))
    m.tooltips.bag["0:7"] = { lines = "nope" }
    assertNil(Compat.TradeTimeRemaining(0, 7))
    m.C_TooltipInfo = nil
    assertNil(Compat.TradeTimeRemaining(0, 3), "no C_TooltipInfo")
end)

test("compat: InventoryItemLevel prefers the line's number, then its text", function()
    local Compat, m = fresh()
    local TT = m.Enum.TooltipDataLineType
    m.tooltips.inventory["party1:1"] = tooltip{ { TT.ItemLevel, "Item Level 639", 640 } }
    assertEqual(Compat.InventoryItemLevel("party1", 1), 640)
    m.tooltips.inventory["party1:2"] = tooltip{ { 29, "Item Level Necklace" },
        { TT.ItemLevel, "Item Level 626" } }
    assertEqual(Compat.InventoryItemLevel("party1", 2), 626)
    assertNil(Compat.InventoryItemLevel("party1", 3))
    m.ITEM_LEVEL = nil
    assertNil(Compat.InventoryItemLevel("party1", 2), "no number on the line and no global")
end)

test("compat: GetItemUpgradeInfo takes the API's table, plain fields only", function()
    local Compat, m = fresh()
    local link = "|cnIQ4:|Hitem:1::::::::|h[Ring]|h|r"
    m.upgradeInfo[link] = { currentLevel = 2, maxLevel = 6, maxItemLevel = 645, trackString = "Hero",
        trackStringID = 975 }
    local info = Compat.GetItemUpgradeInfo(link)
    assertEqual(info.trackString, "Hero"); assertEqual(info.trackStringID, 975)
    assertEqual(info.currentLevel, 2); assertEqual(info.maxLevel, 6)
    assertEqual(info.maxItemLevel, 645); assertEqual(info.source, "api")
    assertTrue(info ~= m.upgradeInfo[link], "a copy, not the client's table")
end)

test("compat: GetItemUpgradeInfo falls back to the ItemUpgradeLevel tooltip line", function()
    local Compat, m = fresh()
    local TT = m.Enum.TooltipDataLineType
    local link = "|cnIQ4:|Hitem:2::::::::|h[Cloak]|h|r"
    m.tooltips.hyperlink[link] = tooltip{ { TT.ItemUpgradeLevel, "Upgrade Level: Champion 3/6" } }
    local info = Compat.GetItemUpgradeInfo(link)
    assertEqual(info.trackString, "Champion"); assertEqual(info.currentLevel, 3)
    assertEqual(info.maxLevel, 6); assertEqual(info.source, "tooltip")
    assertNil(info.trackStringID)
    m.C_Item.GetItemUpgradeInfo = nil
    assertEqual(Compat.GetItemUpgradeInfo(link).trackString, "Champion", "the API absent")
end)

test("compat: GetItemUpgradeInfo answers nil with no track, no API and a secret answer", function()
    local Compat, m = fresh()
    installSecrets(m)
    assertNil(Compat.GetItemUpgradeInfo("|Hitem:3|h[Plain]|h"))
    assertNil(Compat.GetItemUpgradeInfo(nil))
    assertNil(Compat.GetItemUpgradeInfo(T.secret("link")))
    m.upgradeInfo.x = T.secret({ trackString = "Hero" })
    assertNil(Compat.GetItemUpgradeInfo("x"))
    m.C_Item, m.C_TooltipInfo = nil, nil
    assertNil(Compat.GetItemUpgradeInfo("x"))
end)

-- ---------------------------------------------------------------------------------------------
-- Restrictions
-- ---------------------------------------------------------------------------------------------

test("compat: InChatMessagingLockdown reads the client, a secret as locked, absent as open", function()
    local Compat, m = fresh()
    installSecrets(m)
    assertFalse(Compat.InChatMessagingLockdown())
    m.chatLockdown = true
    assertTrue(Compat.InChatMessagingLockdown())
    m.chatLockdown = T.secret(false)
    assertTrue(Compat.InChatMessagingLockdown(), "a secret answer is the cautious one")
    m.C_ChatInfo = nil
    assertFalse(Compat.InChatMessagingLockdown())
end)

test("compat: IsRestrictionActive asks the client, falling back to the state", function()
    local Compat, m = fresh()
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    assertFalse(Compat.IsRestrictionActive(RT.Encounter))
    m.restrictionStates[RT.Encounter] = RS.Active
    assertTrue(Compat.IsRestrictionActive(RT.Encounter))
    m.C_RestrictedActions.IsAddOnRestrictionActive = nil
    m.restrictionStates[RT.Encounter] = RS.Activating
    assertTrue(Compat.IsRestrictionActive(RT.Encounter), "the state rung; Activating counts")
    m.restrictionStates[RT.Encounter] = RS.Inactive
    assertFalse(Compat.IsRestrictionActive(RT.Encounter))
    assertFalse(Compat.IsRestrictionActive(nil))
    m.C_RestrictedActions = nil
    assertFalse(Compat.IsRestrictionActive(RT.Encounter), "no API, no restriction")
end)

test("compat: IsRestrictionStateActive reads the state by the enum's Inactive", function()
    local Compat, m = fresh()
    installSecrets(m)
    assertFalse(Compat.IsRestrictionStateActive(0))
    assertTrue(Compat.IsRestrictionStateActive(1))
    assertTrue(Compat.IsRestrictionStateActive(2))
    assertTrue(Compat.IsRestrictionStateActive(T.secret(0)), "a secret reads as active")
    assertFalse(Compat.IsRestrictionStateActive(nil))
    m.Enum.AddOnRestrictionState.Inactive = 7
    assertFalse(Compat.IsRestrictionStateActive(7), "resolved by name, not by number")
    assertTrue(Compat.IsRestrictionStateActive(0))
end)

test("compat: IsRestrictionStateActive takes the event's boolean payload as it is", function()
    local Compat, m = fresh()
    installSecrets(m)
    assertTrue(Compat.IsRestrictionStateActive(true))
    assertFalse(Compat.IsRestrictionStateActive(false))
    assertTrue(Compat.IsRestrictionStateActive(T.secret(false)), "a secret boolean reads as active")
    assertFalse(Compat.IsRestrictionStateActive("Active"), "an unreadable state is inactive")
end)

test("compat: RestrictionTypes is the enum, or an empty table", function()
    local Compat, m = fresh()
    assertEqual(Compat.RestrictionTypes().Encounter, 1)
    m.Enum = nil
    assertNil(next(Compat.RestrictionTypes()))
end)

-- ---------------------------------------------------------------------------------------------
-- Bind helpers
-- ---------------------------------------------------------------------------------------------

test("compat: the account-bind helpers read C_Item and answer false without it", function()
    local Compat, m = fresh()
    m.accountBound.a, m.accountBoundUE.b = true, true
    assertTrue(Compat.IsItemBindToAccount("a")); assertFalse(Compat.IsItemBindToAccount("b"))
    assertTrue(Compat.IsItemBindToAccountUntilEquip("b"))
    assertFalse(Compat.IsItemBindToAccountUntilEquip("a"))
    assertFalse(Compat.IsItemBindToAccount(nil))
    m.C_Item = nil
    assertFalse(Compat.IsItemBindToAccount("a")); assertFalse(Compat.IsItemBindToAccountUntilEquip("b"))
end)

test("compat: a secret bind answer reads as not bound", function()
    local Compat, m = fresh()
    installSecrets(m)
    m.C_Item.IsItemBindToAccount = function() return T.secret(true) end
    assertFalse(Compat.IsItemBindToAccount("a"))
end)

test("compat: GetBagItemGUID reads through an ItemLocation, nil for an empty slot or no API", function()
    local Compat, m = fresh()
    m.bagGUIDs["0:1"] = "Item-1-0-ABC"
    assertEqual(Compat.GetBagItemGUID(0, 1), "Item-1-0-ABC")
    assertNil(Compat.GetBagItemGUID(0, 2))
    m.ItemLocation = nil
    assertNil(Compat.GetBagItemGUID(0, 1))
end)

-- ---------------------------------------------------------------------------------------------
-- Item readers
-- ---------------------------------------------------------------------------------------------

local RING = "|cnIQ4:|Hitem:1001::::::::90:::::|h[Ring]|h|r"

local function seedRing(m, extra)
    local def = { name = "Ring", quality = 4, ilvl = 250, effectiveIlvl = 263, equipLoc = "INVTYPE_FINGER",
        classID = 4, subClassID = 0, bindType = 1, setID = 7,
        stats = { ITEM_MOD_CRIT_RATING_SHORT = 100, ITEM_MOD_NEW_THING = 3 }, specs = { 71, 72 },
        unique = { false, "Cat", 2, 55 } }
    for k, v in pairs(extra or {}) do def[k] = v end
    m.addItem(RING, def)
end

test("compat: GetItemInfo copies the cached fields, nil while uncached or without a link", function()
    local Compat, m = fresh()
    seedRing(m, { loadsNeeded = 1 })
    assertNil(Compat.GetItemInfo(RING), "uncached")
    m.items[RING].loadsNeeded = 0
    local info = Compat.GetItemInfo(RING)
    assertEqual(info.name, "Ring"); assertEqual(info.quality, 4); assertEqual(info.itemLevel, 250)
    assertEqual(info.equipLoc, "INVTYPE_FINGER"); assertEqual(info.classID, 4)
    assertEqual(info.subClassID, 0); assertEqual(info.bindType, 1); assertEqual(info.setID, 7)
    assertNil(Compat.GetItemInfo(nil)); assertNil(Compat.GetItemInfo(42))
end)

test("compat: GetItemInfo falls back to the global, and answers nil with neither", function()
    local Compat, m = fresh()
    seedRing(m)
    local fn = m.C_Item.GetItemInfo
    m.C_Item.GetItemInfo = nil
    m.GetItemInfo = fn
    assertEqual(Compat.GetItemInfo(RING).name, "Ring")
    m.GetItemInfo = nil
    assertNil(Compat.GetItemInfo(RING))
end)

test("compat: a secret item answer is never copied", function()
    local Compat, m = fresh()
    installSecrets(m)
    m.C_Item.GetItemInfo = function() return T.secret("Ring") end
    assertNil(Compat.GetItemInfo(RING), "a secret name reads as uncached")
    m.C_Item.GetItemInfo = function() return "Ring", RING, T.secret(4), 250 end
    local info = Compat.GetItemInfo(RING)
    assertNil(info.quality); assertEqual(info.itemLevel, 250)
    m.C_Item.GetItemStats = function() return { ITEM_MOD_STAMINA_SHORT = T.secret(5), ITEM_MOD_HASTE_RATING_SHORT = 7 } end
    local stats = Compat.GetItemStats(RING)
    assertNil(stats.ITEM_MOD_STAMINA_SHORT); assertEqual(stats.ITEM_MOD_HASTE_RATING_SHORT, 7)
    assertNil(Compat.GetItemInfo(T.secret(RING)), "a secret link")
end)

test("compat: GetDetailedItemLevel reads the effective level, nil without the API", function()
    local Compat, m = fresh()
    seedRing(m)
    assertEqual(Compat.GetDetailedItemLevel(RING), 263)
    m.C_Item.GetDetailedItemLevelInfo = nil
    assertNil(Compat.GetDetailedItemLevel(RING))
end)

test("compat: GetItemStats copies every key, unknown ones too, and is empty without an answer", function()
    local Compat, m = fresh()
    seedRing(m)
    local stats = Compat.GetItemStats(RING)
    assertEqual(stats.ITEM_MOD_CRIT_RATING_SHORT, 100); assertEqual(stats.ITEM_MOD_NEW_THING, 3)
    assertEqual(next(Compat.GetItemStats("nope")), nil)
    m.C_Item.GetItemStats = nil
    assertEqual(next(Compat.GetItemStats(RING)), nil)
end)

test("compat: GetItemSpecs is a set, nil for an empty list or no API", function()
    local Compat, m = fresh()
    seedRing(m)
    local specs = Compat.GetItemSpecs(RING)
    assertTrue(specs[71]); assertTrue(specs[72]); assertNil(specs[73])
    m.items[RING].specs = {}
    assertNil(Compat.GetItemSpecs(RING))
    m.C_Item.GetItemSpecInfo = nil
    assertNil(Compat.GetItemSpecs(RING))
end)

test("compat: GetItemUniqueness reads the category, the item's own uniqueness, and the global", function()
    local Compat, m = fresh()
    seedRing(m)
    local cat, max = Compat.GetItemUniqueness(RING)
    assertEqual(cat, 55); assertEqual(max, 2)
    m.items[RING].unique = { true, nil, nil, 0 }
    cat, max = Compat.GetItemUniqueness(RING)
    assertNil(cat); assertEqual(max, 1)
    m.items[RING].unique = nil
    cat, max = Compat.GetItemUniqueness(RING)
    assertNil(cat); assertNil(max)
    m.C_Item.GetItemUniquenessByID = nil
    m.GetItemUniqueness = function() return 12, 3 end
    cat, max = Compat.GetItemUniqueness(RING)
    assertEqual(cat, 12); assertEqual(max, 3)
    m.GetItemUniqueness = function() return -1, 1 end
    cat, max = Compat.GetItemUniqueness(RING)
    assertNil(cat); assertEqual(max, 1)
    m.GetItemUniqueness = nil
    assertNil((Compat.GetItemUniqueness(RING)))
end)

test("compat: PlayerHasTransmog answers the collection, nil when absent or secret", function()
    local Compat, m = fresh()
    seedRing(m, { transmog = true })
    assertTrue(Compat.PlayerHasTransmog(RING))
    m.items[RING].transmog = false
    assertFalse(Compat.PlayerHasTransmog(RING))
    installSecrets(m)
    m.C_TransmogCollection.PlayerHasTransmogByItemInfo = function() return T.secret(true) end
    assertNil(Compat.PlayerHasTransmog(RING))
    m.C_TransmogCollection = nil
    assertNil(Compat.PlayerHasTransmog(RING))
end)

test("compat: ItemClassRestriction reads the classes line by type, else by text", function()
    local Compat, m = fresh()
    m.tooltips.hyperlink[RING] = tooltip({ { 20, "Binds when picked up" },
        { 21, "Classes: Warrior, Death Knight, Nobody" } })
    local set = Compat.ItemClassRestriction(RING)
    assertTrue(set.WARRIOR); assertTrue(set.DEATHKNIGHT); assertNil(set.PALADIN)
    m.Enum.TooltipDataLineType.RestrictedRaceClass = nil
    assertTrue(Compat.ItemClassRestriction(RING).DEATHKNIGHT, "the text fallback")
    m.tooltips.hyperlink[RING] = tooltip({ { nil, "Classes: Nobody" } })
    assertNil(Compat.ItemClassRestriction(RING), "no known class")
    m.ITEM_CLASSES_ALLOWED = nil
    assertNil(Compat.ItemClassRestriction(RING))
    m.C_TooltipInfo = nil
    assertNil(Compat.ItemClassRestriction(RING))
end)

test("compat: CanRequestItemLoad needs the load request and a timer", function()
    local Compat, m = fresh()
    assertTrue(Compat.CanRequestItemLoad())
    m.C_Timer = nil
    assertFalse(Compat.CanRequestItemLoad())
    local Compat2, m2 = fresh()
    m2.C_Item.RequestLoadItemDataByID = nil
    assertFalse(Compat2.CanRequestItemLoad())
end)

-- ---------------------------------------------------------------------------------------------
-- The Pawn seam
-- ---------------------------------------------------------------------------------------------

-- A Pawn fake: data for every link but "uncached", one 12% upgrade, a scale and a value.
local function installPawn(m)
    m.PawnIsInitialized = true
    m.PawnGetItemData = function(link) if link ~= "uncached" then return { link = link } end end
    m.PawnIsItemAnUpgrade = function(data)
        if data.link == "up" then return { { ScaleName = "S", PercentUpgrade = 0.12 } } end
        return nil
    end
    m.PawnFindScaleForSpec = function(classID, specID) return classID .. ":" .. specID end
    m.PawnGetSingleValueFromItem = function(data, scale) return scale == "S" and #data.link or nil end
end

test("compat: without Pawn every reader answers nil and nothing raises", function()
    local Compat = fresh()
    assertFalse(Compat.PawnIsReady())
    assertNil(Compat.PawnItemData("up"))
    assertNil(Compat.PawnUpgradeInfo("up"))
    assertNil(Compat.PawnScaleForSpec(1, 71))
    assertNil(Compat.PawnItemValue("up", "S"))
end)

test("compat: Pawn loaded but not initialized is not ready", function()
    local Compat, m = fresh()
    installPawn(m)
    m.PawnIsInitialized = false
    -- red under: a seam that calls Pawn without asking PawnIsInitialized
    m.PawnGetItemData = function() error("called before Pawn initialized") end
    assertFalse(Compat.PawnIsReady())
    assertNil(Compat.PawnUpgradeInfo("up"))
end)

test("compat: Pawn ready answers the upgrade list, an empty list, or nil while uncached", function()
    local Compat, m = fresh()
    installPawn(m)
    assertTrue(Compat.PawnIsReady())
    assertEqual(Compat.PawnUpgradeInfo("up")[1].PercentUpgrade, 0.12)
    assertNil(next(Compat.PawnUpgradeInfo("same")), "not an upgrade is an empty list")
    assertNil(Compat.PawnUpgradeInfo("uncached"), "uncached is pending")
    assertEqual(Compat.PawnScaleForSpec(1, 71), "1:71")
    assertEqual(Compat.PawnItemValue("abc", "S"), 3)
    assertNil(Compat.PawnItemValue("abc", "Other"))
    assertNil(Compat.PawnItemValue("abc", nil))
    assertNil(Compat.PawnItemValue("uncached", "S"))
end)

test("compat: an error inside Pawn reads as not ready, never as this addon's error", function()
    local Compat, m = fresh()
    installPawn(m)
    m.PawnIsItemAnUpgrade = function() error("Pawn broke") end
    m.PawnFindScaleForSpec = function() error("Pawn broke") end
    assertNil(next(Compat.PawnUpgradeInfo("up")))
    assertNil(Compat.PawnScaleForSpec(1, 71))
end)

test("compat: a function-spelled PawnIsInitialized is called", function()
    local Compat, m = fresh()
    installPawn(m)
    m.PawnIsInitialized = function() return true end
    assertTrue(Compat.PawnIsReady())
    m.PawnIsInitialized = function() error("boom") end
    assertFalse(Compat.PawnIsReady())
end)

-- ---------------------------------------------------------------------------------------------
-- Trade actions
-- ---------------------------------------------------------------------------------------------

test("compat: PickupBagItem prefers C_Container, then the global, then reports false", function()
    local Compat, m = fresh()
    assertTrue(Compat.PickupBagItem(0, 3))
    assertEqual(m.tradeCalls[1][1], "PickupContainerItem")
    assertEqual(m.tradeCalls[1][3], 3)
    m.C_Container = nil
    local legacy
    m.PickupContainerItem = function(bag, slot) legacy = bag .. ":" .. slot end
    assertTrue(Compat.PickupBagItem(1, 2))
    assertEqual(legacy, "1:2")
    m.PickupContainerItem = nil
    assertFalse(Compat.PickupBagItem(1, 2))
end)

test("compat: DropItemOnUnit and InitiateTrade call through, and report false when absent", function()
    local Compat, m = fresh()
    assertTrue(Compat.DropItemOnUnit("party1"))
    assertTrue(Compat.InitiateTrade("party2"))
    assertEqual(m.tradeCalls[1][1], "DropItemOnUnit"); assertEqual(m.tradeCalls[1][2], "party1")
    assertEqual(m.tradeCalls[2][1], "InitiateTrade"); assertEqual(m.tradeCalls[2][2], "party2")
    m.DropItemOnUnit, m.InitiateTrade = nil, nil
    assertFalse(Compat.DropItemOnUnit("party1"))
    assertFalse(Compat.InitiateTrade("party1"))
end)

test("compat: InTradeRange reads interact distance 2; secret is out of range, no API lets it through", function()
    local Compat, m = fresh()
    local asked
    m.CheckInteractDistance = function(unit, index) asked = index; return unit == "party1" end
    assertTrue(Compat.InTradeRange("party1"))
    assertEqual(asked, 2, "the trade distance index")
    assertFalse(Compat.InTradeRange("party2"))
    m.CheckInteractDistance = function() return 1 end
    assertTrue(Compat.InTradeRange("party1"), "a numeric true")
    m.issecretvalue = T.isSecret
    m.CheckInteractDistance = function() return T.secret(true) end
    assertFalse(Compat.InTradeRange("party1"))
    m.CheckInteractDistance = nil
    assertTrue(Compat.InTradeRange("party1"))
end)

test("compat: CursorHasItem and ClearCursor call through, and answer false when absent", function()
    local Compat, m = fresh()
    assertFalse(Compat.CursorHasItem())
    m.cursor = "0:1"
    assertTrue(Compat.CursorHasItem())
    assertTrue(Compat.ClearCursor())
    assertFalse(Compat.CursorHasItem())
    assertEqual(m.cursorCleared, 1)
    m.issecretvalue = T.isSecret
    m.CursorHasItem = function() return T.secret(true) end
    assertFalse(Compat.CursorHasItem(), "a secret answer")
    m.CursorHasItem, m.ClearCursor = nil, nil
    assertFalse(Compat.CursorHasItem())
    assertFalse(Compat.ClearCursor())
end)

test("compat: NormalizedRealm reads the normalized realm, then the plain one stripped", function()
    local Compat, m = fresh()
    assertEqual(Compat.NormalizedRealm(), "Testrealm")
    m.normalizedRealm = nil
    m.__context.realm = "Azjol-Nerub Area"
    assertEqual(Compat.NormalizedRealm(), "AzjolNerubArea", "nil early in the login: the plain name, stripped")
    installSecrets(m)
    m.normalizedRealm = T.secret("Secret")
    assertEqual(Compat.NormalizedRealm(), "AzjolNerubArea", "a secret answer is skipped")
    m.GetNormalizedRealmName, m.GetRealmName = nil, nil
    assertNil(Compat.NormalizedRealm())
end)

test("compat: PlayerSpecID reads the index then its spec id, nil without an answer or the library", function()
    local Compat, m = fresh()
    m.specID = 72
    assertEqual(Compat.PlayerSpecID(), 72)
    m.GetSpecialization = function() return nil end
    assertNil(Compat.PlayerSpecID(), "no spec chosen yet")
    m.GetSpecialization = function() return 2 end
    installSecrets(m)
    m.specID = T.secret(72)
    assertNil(Compat.PlayerSpecID(), "a secret answer is never passed on")
    local degraded, md = fresh{ skip = T.loadAddon.libFiles }
    md.specID = 72
    assertNil(degraded.PlayerSpecID(), "the library's reader stubs answer nil; no rung is re-implemented")
end)

test("compat: InventoryItemLink reads the worn link, nil when empty, secret or absent", function()
    local Compat, m = fresh()
    m.inventory.player[1] = "|Hitem:5::|h[Helm]|h"
    assertEqual(Compat.InventoryItemLink("player", 1), "|Hitem:5::|h[Helm]|h")
    assertNil(Compat.InventoryItemLink("player", 2))
    installSecrets(m)
    m.inventory.player[1] = T.secret("x")
    assertNil(Compat.InventoryItemLink("player", 1))
    m.GetInventoryItemLink = nil
    assertNil(Compat.InventoryItemLink("player", 1))
end)

test("compat: the bag readers prefer C_Container, then the globals, then answer empty", function()
    local Compat, m = fresh()
    m.bags[0] = { size = 2, [1] = "|Hitem:7::|h[Ring]|h" }
    assertEqual(Compat.BagSlotCount(0), 2); assertEqual(Compat.BagSlotCount(3), 0)
    assertEqual(Compat.BagItemLink(0, 1), "|Hitem:7::|h[Ring]|h"); assertNil(Compat.BagItemLink(0, 2))
    m.C_Container.GetContainerNumSlots, m.C_Container.GetContainerItemLink = nil, nil
    m.GetContainerNumSlots = function() return 4 end
    m.GetContainerItemLink = function(bag, slot) return bag .. ":" .. slot end
    assertEqual(Compat.BagSlotCount(1), 4, "the deprecated global")
    assertEqual(Compat.BagItemLink(1, 3), "1:3")
    installSecrets(m)
    m.GetContainerNumSlots = function() return T.secret(4) end
    m.GetContainerItemLink = function() return T.secret("x") end
    assertEqual(Compat.BagSlotCount(1), 0); assertNil(Compat.BagItemLink(1, 3))
    m.GetContainerNumSlots, m.GetContainerItemLink = nil, nil
    assertEqual(Compat.BagSlotCount(1), 0); assertNil(Compat.BagItemLink(1, 3))
end)

test("compat: the inspect gates answer plain booleans; a secret answer or no API is the safe side", function()
    local Compat, m = fresh()
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    assertTrue(Compat.CanInspectUnit("party1")); assertFalse(Compat.CanInspectUnit("party4"))
    assertTrue(Compat.InInspectRange("party1"))
    m.inspect.far.party1 = true
    assertFalse(Compat.InInspectRange("party1"))
    installSecrets(m)
    m.CanInspect = function() return T.secret(true) end
    m.CheckInteractDistance = function() return T.secret(true) end
    assertFalse(Compat.CanInspectUnit("party1"), "a secret answer cannot allow an inspect")
    assertFalse(Compat.InInspectRange("party1"), "a secret answer is out of range")
    m.CanInspect, m.CheckInteractDistance = nil, nil
    assertFalse(Compat.CanInspectUnit("party1"))
    assertTrue(Compat.InInspectRange("party1"), "no range API: the inspect's own timeout answers")
end)

test("compat: the inspect calls, the spec, the item id, the inspect window and the hook", function()
    local Compat, m = fresh()
    assertTrue(Compat.NotifyInspect("party1"))
    assertEqual(m.inspect.notified[1].unit, "party1")
    assertTrue(Compat.ClearInspectPlayer()); assertEqual(m.inspect.cleared, 1)
    assertNil(Compat.InspectSpecID("party1"), "0 is not known")
    m.inspect.specs.party1 = 71
    assertEqual(Compat.InspectSpecID("party1"), 71)
    m.inventory.party1 = { [1] = "|Hitem:5::|h[Helm]|h" }
    m.inventoryIDs.party1 = { [5] = 6 }
    assertEqual(Compat.InventoryItemID("party1", 1), 5); assertEqual(Compat.InventoryItemID("party1", 5), 6)
    assertNil(Compat.InventoryItemID("party1", 2))
    assertFalse(Compat.IsInspectFrameShown())
    m.InspectFrame = m.__stubFrame():Show()
    assertTrue(Compat.IsInspectFrameShown())
    local seen = {}
    assertTrue(Compat.HookNotifyInspect(function(unit) seen[#seen + 1] = unit end))
    m.NotifyInspect("target")
    assertEqual(seen[#seen], "target", "anyone's call reaches the hook")
    installSecrets(m)
    m.inspect.specs.party1 = T.secret(71)
    assertNil(Compat.InspectSpecID("party1"))
    m.GetInventoryItemID = function() return T.secret(5) end
    assertNil(Compat.InventoryItemID("party1", 1))
    m.NotifyInspect, m.ClearInspectPlayer, m.GetInspectSpecialization, m.GetInventoryItemID = nil, nil, nil, nil
    m.InspectFrame = nil
    assertFalse(Compat.NotifyInspect("party1")); assertFalse(Compat.ClearInspectPlayer())
    assertNil(Compat.InspectSpecID("party1")); assertNil(Compat.InventoryItemID("party1", 1))
    assertFalse(Compat.IsInspectFrameShown())
    assertFalse(Compat.HookNotifyInspect(function() end), "nothing to hook")
end)

-- ---------------------------------------------------------------------------------------------
-- The loot sources beside chat (the feed)
-- ---------------------------------------------------------------------------------------------

test("compat: LootHistoryDrop answers a won drop's plain fields, else nil", function()
    local Compat, m = fresh()
    local LINK = "|Hitem:9::|h[Band]|h"
    assertNil(Compat.LootHistoryDrop(1, 2), "no answer")
    m.lootHistory["1:2"] = { itemHyperlink = LINK, winner = { playerName = "Brakk",
        playerGUID = "Player-1-0000000A", playerClass = "WARRIOR", isSelf = false } }
    local d = Compat.LootHistoryDrop(1, 2)
    assertEqual(d.link, LINK); assertEqual(d.name, "Brakk"); assertEqual(d.guid, "Player-1-0000000A")
    assertEqual(d.classFile, "WARRIOR"); assertFalse(d.isSelf)
    m.lootHistory["1:2"].winner = {}
    assertNil(Compat.LootHistoryDrop(1, 2), "rolls still open: nobody won it")
    m.lootHistory["1:2"].winner = nil
    assertNil(Compat.LootHistoryDrop(1, 2))
    assertNil(Compat.LootHistoryDrop("1", 2), "the ids must be numbers")
    installSecrets(m)
    m.lootHistory["1:2"] = { itemHyperlink = T.secret(LINK), winner = { playerName = "Brakk" } }
    assertNil(Compat.LootHistoryDrop(1, 2), "a secret link")
    m.lootHistory["1:2"] = { itemHyperlink = LINK, winner = { playerName = T.secret("Brakk"),
        playerGUID = T.secret("Player-1-0000000A"), isSelf = T.secret(true) } }
    assertNil(Compat.LootHistoryDrop(1, 2), "a winner with nothing plain")
    m.lootHistory["1:2"].winner.playerName = "Brakk"
    d = Compat.LootHistoryDrop(1, 2)
    assertEqual(d.name, "Brakk"); assertNil(d.guid); assertFalse(d.isSelf)
    m.lootHistory["1:2"] = T.secret({})
    assertNil(Compat.LootHistoryDrop(1, 2))
    m.C_LootHistory = nil
    assertNil(Compat.LootHistoryDrop(1, 2), "no API")
end)

test("compat: ChallengeMapName answers a keystone dungeon's name, else nil", function()
    local Compat, m = fresh()
    m.challengeMaps[505] = "The Rookery"
    assertEqual(Compat.ChallengeMapName(505), "The Rookery")
    assertNil(Compat.ChallengeMapName(506)); assertNil(Compat.ChallengeMapName(nil))
    m.challengeMaps[507] = ""
    assertNil(Compat.ChallengeMapName(507))
    installSecrets(m)
    m.challengeMaps[505] = T.secret("The Rookery")
    assertNil(Compat.ChallengeMapName(505))
    m.C_ChallengeMode.GetMapUIInfo = nil
    assertNil(Compat.ChallengeMapName(505), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- The seam is the only caller
-- ---------------------------------------------------------------------------------------------

local SEAM_ONLY = { "C_TooltipInfo", "SendChatMessage", "InChatMessagingLockdown", "C_RestrictedActions",
    "GetItemUpgradeInfo", "IsItemBindToAccount", "GetItemGUID", "DropItemOnUnit", "PickupContainerItem",
    "InitiateTrade", "Pawn%u%a+", "issecretvalue", "canaccessvalue", "GetNormalizedRealmName",
    "GetRealmName", "GetItemInfo%f[^%w_]", "GetDetailedItemLevelInfo", "GetItemStats", "GetItemSpecInfo",
    "GetItemUniqueness", "C_TransmogCollection", "LOCALIZED_CLASS_NAMES_%u+", "GetSpecialization",
    "GetInventoryItemLink", "GetContainerNumSlots", "GetContainerItemLink", "C_Container",
    "NotifyInspect", "ClearInspectPlayer", "GetInspectSpecialization", "CheckInteractDistance",
    "CanInspect%f[^%w_]", "GetInventoryItemID", "InspectFrame", "hooksecurefunc", "C_LootHistory",
    "GetMapUIInfo", "CursorHasItem", "ClearCursor" }

test("compat: no other shipped file names a seam-only client API in code", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "core/Compat.lua" then
            local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = fh:read("*a"); fh:close()
            local code = src:gsub("%-%-[^\r\n]*", "")
            for _, api in ipairs(SEAM_ONLY) do
                -- red under: a feature module calling C_TooltipInfo.GetBagItem directly
                assertNil(code:find("[^%w_.]" .. api), rel .. " names " .. api .. " outside core/Compat.lua")
            end
        end
    end
end)
