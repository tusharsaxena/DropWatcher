-- tests/test_trade_helper.lua — modules/TradeHelper.lua (design spec §4): an empty trade opened
-- with a group member (InitiateTrade). Every guard refuses with its reason before the client is
-- touched: disabled, combat, not a member, yourself, offline, out of range and a missing API.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"

-- An enabled instance in a party with Brakk (party1).
local function setup()
    local NS, _, m = T.enableAddon()
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    m.advance(0)
    return NS, m, NS.TradeHelper
end

local function calls(m)
    local out = {}
    for _, c in ipairs(m.tradeCalls) do out[#out + 1] = c[1] .. "(" .. table.concat({ select(2, unpack(c)) }, ",") .. ")" end
    return table.concat(out, " ")
end

-- ---------------------------------------------------------------------------------------------
-- The target guards
-- ---------------------------------------------------------------------------------------------

test("guards: combat refuses before the range is read", function()
    local _, m, TH = setup()
    local ranged = 0
    local real = m.CheckInteractDistance
    m.CheckInteractDistance = function(...) ranged = ranged + 1; return real(...) end
    m.__fire("PLAYER_REGEN_DISABLED")
    local ok, reason = TH.CanTradeWith(BRAKK)
    assertFalse(ok); assertEqual(reason, "combat")
    ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "combat")
    assertEqual(ranged, 0, "the protected range read is never made in combat")
    assertEqual(#m.tradeCalls, 0)
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue((TH.Open(BRAKK)))
end)

test("guards: a stranger, yourself, an offline member and one out of range are refused", function()
    local NS, m, TH = setup()
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
    local ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "range")
    m.tradeFar.party1 = nil
    m.units.party1.connected = false
    NS.Roster.Refresh("test")
    assertEqual(reasonOf(BRAKK), "offline")
    assertEqual(#m.tradeCalls, 0)
end)

test("guards: stood down, nothing is traded", function()
    local NS, m, TH = setup()
    NS.addon:OnSlashCommand("disable")
    local ok, reason = TH.CanTradeWith(BRAKK)
    assertFalse(ok); assertEqual(reason, "stoodDown")
    ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "stoodDown")
    assertEqual(#m.tradeCalls, 0)
end)

test("guards: every reason has its tooltip line, and none has none", function()
    local _, _, TH = setup()
    for _, reason in ipairs({ "stoodDown", "combat", "noTarget", "self", "offline", "range", "noApi" }) do
        assertTrue(type(TH.ReasonText(reason)) == "string", reason)
    end
    assertNil(TH.ReasonText(nil))
end)

-- ---------------------------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------------------------

test("open: InitiateTrade with the member's unit; noApi without it", function()
    local _, m, TH = setup()
    assertTrue((TH.Open("Brakk")))
    assertEqual(calls(m), "InitiateTrade(party1)")
    assertEqual(TH.Stats().opens, 1)
    m.InitiateTrade = nil
    local ok, reason = TH.Open(BRAKK)
    assertFalse(ok); assertEqual(reason, "noApi")
end)

test("diagnostics: the trade section reports the helper's counts once it has been used", function()
    local NS, _, TH = setup()
    TH.Open(BRAKK)
    TH.Open("Nobody")
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("trade helper: opens=1 refused=1 last=noTarget", 1, true) ~= nil, text)
end)
