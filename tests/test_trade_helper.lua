-- tests/test_trade_helper.lua — modules/TradeHelper.lua (design spec §4): your own drop handed to a
-- group member (its bag slot found by GUID, PickupContainerItem, then DropItemOnUnit) and an empty
-- trade opened (InitiateTrade). Every guard refuses with its reason before the client is touched:
-- disabled, combat, not a member, yourself, offline, out of range, not in the bags, expired, a busy
-- cursor and a missing API.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"
local GUID = "Item-1-0001"
local NS_BIND_ON_EQUIP = 2    -- Enum.ItemBind.OnEquip
local LINE_TYPE = 36    -- the mock's Enum.TooltipDataLineType.TradeTimeRemaining
local SENTENCE = "You may trade this item with players that were also eligible to loot this item for the next %s."

local function link(id)
    return ("|cnIQ4:|Hitem:%d::::::::90::::::|h[Item %d]|h|r"):format(id, id)
end

local function ring(ilvl, bindType)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = bindType or 1, stats = {} }
end

-- An enabled instance in a party with Brakk (party1), wearing two 600 rings, carrying one own drop
-- (a 590 ring, bind-on-pickup unless `bindType` says otherwise) in bag 0, slot 2, with `duration`
-- left on its trade window (nil: no timer line).
local function setup(duration, bindType)
    local NS, _, m = T.enableAddon()
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    m.addItem(link(100), ring(600)); m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.bags[0], m.bags[1] = { size = 4 }, { size = 4 }
    local item = link(300)
    m.addItem(item, ring(590, bindType))
    local id = NS.LootFeed.Add(item)
    m.bags[0][2] = item
    m.bagGUIDs["0:2"] = GUID
    m.tooltips.bag["0:2"] = { lines = duration and { { type = LINE_TYPE, leftText = SENTENCE:format(duration) } } or {} }
    m.advance(0)
    return NS, m, NS.TradeHelper, id
end

local function calls(m)
    local out = {}
    for _, c in ipairs(m.tradeCalls) do out[#out + 1] = c[1] .. "(" .. table.concat({ select(2, unpack(c)) }, ",") .. ")" end
    return table.concat(out, " ")
end

-- ---------------------------------------------------------------------------------------------
-- Give
-- ---------------------------------------------------------------------------------------------

test("give: the drop's bag item is picked up by GUID and dropped on the member", function()
    local NS, m, TH, id = setup("1 hour")
    assertEqual(NS.TradeTimer.ForDrop(id).guid, GUID, "the timer matched the item")
    local ok, reason = TH.Give(id, BRAKK)
    assertTrue(ok); assertNil(reason)
    assertEqual(calls(m), "PickupContainerItem(0,2) DropItemOnUnit(party1)")
    assertNil(m.cursor, "the drop took the item off the cursor")
    assertEqual(TH.Stats().gives, 1)
end)

test("give: the target may be a name or a Name-Realm as well as a GUID", function()
    local _, m, TH, id = setup("1 hour")
    assertTrue((TH.Give(id, "Brakk")))
    assertTrue((TH.Give(id, "brakk-Testrealm")))
    assertEqual(#m.tradeCalls, 4)
end)

test("give: an item moved since the last scan is found by a walk of the bags", function()
    local _, m, TH, id = setup("1 hour")
    m.bags[0][2], m.bagGUIDs["0:2"] = nil, nil
    m.bags[1][3], m.bagGUIDs["1:3"] = link(300), GUID
    assertTrue((TH.Give(id, BRAKK)))
    assertEqual(calls(m), "PickupContainerItem(1,3) DropItemOnUnit(party1)")
end)

test("give: FindBagSlot takes the hinted slot first and refuses a missing or secret GUID", function()
    local _, m, TH = setup("1 hour")
    m.bagGUIDs["1:1"] = GUID    -- the same GUID twice: the hint wins over the walk
    local bag, slot = TH.FindBagSlot(GUID, 1, 1)
    assertEqual(bag, 1); assertEqual(slot, 1)
    bag, slot = TH.FindBagSlot(GUID)
    assertEqual(bag, 0); assertEqual(slot, 2)
    assertNil((TH.FindBagSlot("Item-1-9999")))
    assertNil((TH.FindBagSlot(nil)))
    m.issecretvalue = T.isSecret
    assertNil((TH.FindBagSlot(T.secret(GUID))))
end)

test("give: an item gone from the bags, or a drop never matched, is notInBags", function()
    local NS, m, TH, id = setup("1 hour")
    m.bagGUIDs["0:2"] = nil
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "notInBags")
    ok, reason = TH.Give(id + 1000, BRAKK)
    assertFalse(ok); assertEqual(reason, "notInBags")
    assertEqual(#m.tradeCalls, 0)
    assertEqual(TH.ReasonText(reason), NS.L["That item is not in your bags."])
end)

test("give: an item whose trade window has passed is expired", function()
    local _, m, TH, id = setup(nil)
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "expired")
    assertEqual(#m.tradeCalls, 0)
end)

test("give: a BoE drop has no trade-time line, and is given all the same", function()
    local NS, m, TH, id = setup(nil, NS_BIND_ON_EQUIP)
    -- red under: every matched item without a timer line read as expired
    assertTrue(NS.TradeTimer.ForDrop(id).permanent)
    assertTrue((TH.CanGive(id, BRAKK)))
    local ok, reason = TH.Give(id, BRAKK)
    assertTrue(ok); assertNil(reason)
    assertEqual(calls(m), "PickupContainerItem(0,2) DropItemOnUnit(party1)")
end)

test("give: a busy cursor is never swapped away", function()
    local _, m, TH, id = setup("1 hour")
    m.cursor = "4:1"
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "cursorBusy")
    assertEqual(#m.tradeCalls, 0); assertEqual(m.cursor, "4:1")
end)

test("give: with no DropItemOnUnit the pickup is put back, and the reason is noApi", function()
    local _, m, TH, id = setup("1 hour")
    m.DropItemOnUnit = nil
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "noApi")
    assertNil(m.cursor); assertEqual(m.cursorCleared, 1)
    m.C_Container.PickupContainerItem = nil
    ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "noApi")
    assertEqual(TH.Stats().refused, 2); assertEqual(TH.Stats().lastReason, "noApi")
end)

test("give: CanGive answers every guard and touches nothing", function()
    local _, m, TH, id = setup("1 hour")
    assertTrue((TH.CanGive(id, BRAKK)))
    m.inCombat = true
    local ok, reason = TH.CanGive(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "combat")
    m.inCombat = false
    m.bagGUIDs["0:2"] = nil
    ok, reason = TH.CanGive(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "notInBags")
    assertEqual(#m.tradeCalls, 0); assertNil(TH.Stats(), "a check counts nothing")
end)

-- ---------------------------------------------------------------------------------------------
-- The target guards (Give and Open alike)
-- ---------------------------------------------------------------------------------------------

test("guards: combat refuses before the range is read", function()
    local _, m, TH, id = setup("1 hour")
    local ranged = 0
    local real = m.CheckInteractDistance
    m.CheckInteractDistance = function(...) ranged = ranged + 1; return real(...) end
    m.__fire("PLAYER_REGEN_DISABLED")
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "combat")
    ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "combat")
    assertEqual(ranged, 0, "the protected range read is never made in combat")
    assertEqual(#m.tradeCalls, 0)
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue((TH.Open(BRAKK)))
end)

test("guards: a stranger, yourself, an offline member and one out of range are refused", function()
    local NS, m, TH, id = setup("1 hour")
    local function reasonOf(target)
        local ok, reason = TH.CanTradeWith(target)
        assertFalse(ok, tostring(target))
        return reason
    end
    assertEqual(reasonOf("Nobody"), "noTarget")
    assertEqual(reasonOf(nil), "noTarget")
    assertEqual(reasonOf(m.UnitGUID("player")), "self")
    m.tradeFar.party1 = true
    assertEqual(reasonOf(BRAKK), "range")
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "range")
    m.tradeFar.party1 = nil
    m.units.party1.connected = false
    NS.Roster.Refresh("test")
    assertEqual(reasonOf(BRAKK), "offline")
    assertEqual(#m.tradeCalls, 0)
end)

test("guards: stood down, nothing is traded", function()
    local NS, m, TH, id = setup("1 hour")
    NS.addon:OnSlashCommand("disable")
    local ok, reason = TH.Give(id, BRAKK)
    assertFalse(ok); assertEqual(reason, "stoodDown")
    ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "stoodDown")
    assertEqual(#m.tradeCalls, 0)
end)

test("guards: every reason has its tooltip line, and none has none", function()
    local _, _, TH = setup("1 hour")
    for _, reason in ipairs({ "stoodDown", "combat", "noTarget", "self", "offline", "range", "notInBags",
        "expired", "cursorBusy", "noApi" }) do
        assertTrue(type(TH.ReasonText(reason)) == "string", reason)
    end
    assertNil(TH.ReasonText(nil))
end)

-- ---------------------------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------------------------

test("open: InitiateTrade with the member's unit; noApi without it", function()
    local _, m, TH = setup("1 hour")
    assertTrue((TH.Open("Brakk")))
    assertEqual(calls(m), "InitiateTrade(party1)")
    assertEqual(TH.Stats().opens, 1)
    m.InitiateTrade = nil
    local ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "noApi")
end)

test("diagnostics: the trade section reports the helper's counts once it has been used", function()
    local NS, _, TH, id = setup("1 hour")
    TH.Give(id, BRAKK)
    TH.Open("Nobody")
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("trade helper: gives=1 opens=0 refused=1 last=noTarget", 1, true) ~= nil, text)
end)
