-- tests/test_auto_ask.lua — modules/AutoAsk.lua, auto-ask (design spec §9.4): the pure timing, then
-- the edge on the bus: off by default, a qualifying drop asked `delay` seconds after the later of
-- the drop and ENCOUNTER_END (held while an encounter is in progress), each drop once, only drops
-- from after it was turned on, the cancel rules (a manual ask, the looter leaving, the row
-- dismissed, the item received, turned off, the stand-down), the one-time notice, test mode routed
-- to print, and the diagnostics line.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRAKK = "Player-1-0000000A"

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("auto-ask: DueAt is the delay after the later of the drop and the encounter's end", function()
    local AA = T.newAddon().AutoAsk
    assertEqual(AA.DueAt(100, nil, 10), 110, "no encounter: from the drop")
    assertEqual(AA.DueAt(100, 130, 10), 140, "the encounter ended after the drop")
    assertEqual(AA.DueAt(100, 50, 10), 110, "an older encounter's end does not count")
    assertEqual(AA.DueAt(nil, nil, 3), 3)
end)

test("auto-ask: ClampDelay keeps the delay inside 3..30 and defaults to 10", function()
    local AA = T.newAddon().AutoAsk
    assertEqual(AA.ClampDelay(10), 10)
    assertEqual(AA.ClampDelay(1), 3); assertEqual(AA.ClampDelay(99), 30)
    assertEqual(AA.ClampDelay("x"), 10); assertEqual(AA.ClampDelay(0 / 0), 10)
end)

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local function row(guid, name, classFile)
    return { guid = guid, name = name, class = classFile, classFile = classFile }
end

-- An enabled instance in a party with Brakk, whose feed answers `drops` by id (made by `make`), and
-- auto-ask turned on unless `off`.
local function party(off)
    local NS, _, m = T.enableAddon()
    m.setGroup({ row(BRAKK, "Brakk", "WARRIOR") })
    NS.Roster.Refresh("test")
    local byId = {}
    NS.LootFeed.Get = function(id) return byId[id] end
    if not off then assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true)) end
    local function make(over)
        local d = {
            id = 1, link = link(500), itemID = 500, isMine = false, at = m.GetTime(),
            looter = { name = "Brakk", guid = BRAKK, classFile = "WARRIOR" },
            facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 12 },
            trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
        }
        for k, v in pairs(over or {}) do d[k] = v end
        byId[d.id] = d
        return d
    end
    return NS, m, make, byId
end

local function added(NS, id) NS.addon:SendMessage(NS.MSG.DROP_ADDED, id) end

local function whispers(m)
    local n = 0
    for _, s in ipairs(m.chatSent) do
        if s.chatType == "WHISPER" then n = n + 1 end
    end
    return n
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

test("auto-ask edge: off by default; a qualifying drop is never asked for", function()
    local NS, m, make = party(true)
    assertEqual(NS.Setting("messages.autoAsk.enabled"), false)
    make(); added(NS, 1)
    m.advance(60)
    assertEqual(whispers(m), 0); assertEqual(NS.AutoAsk.Stats().scheduled, 0)
end)

test("auto-ask edge: a qualifying drop is whispered for after the delay, once, with the ask template", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    assertEqual(NS.AutoAsk.Stats().waiting, 1)
    m.advance(9.9)
    assertEqual(whispers(m), 0, "not before the delay")
    m.advance(0.2)
    assertEqual(whispers(m), 1)
    assertTrue(m.chatSent[1].text:find("could I have it", 1, true) ~= nil, m.chatSent[1].text)
    assertEqual(NS.Asks.StateOf("ask", "Brakk", 1), "sent")
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    m.advance(60)
    assertEqual(whispers(m), 1, "each drop once")
    local st = NS.AutoAsk.Stats()
    assertEqual(st.scheduled, 1); assertEqual(st.sent, 1); assertEqual(st.waiting, 0)
end)

test("auto-ask edge: the delay and the least gain are the settings'", function()
    local NS, m, make = party()
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.delay", 3))
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.minGain", 15))
    make(); added(NS, 1)
    assertEqual(NS.AutoAsk.Stats().waiting, 0, "+12 is under 15")
    make({ id = 2, me = { verdict = "upgrade", ilvlDelta = 15 } }); added(NS, 2)
    m.advance(3)
    assertEqual(whispers(m), 1)
end)

test("auto-ask edge: a sidegrade, your own drop or an unknown trade is not asked for; a later likely is", function()
    local NS, m, make, byId = party()
    make({ id = 1, me = { verdict = "sidegrade", ilvlDelta = 12 } }); added(NS, 1)
    make({ id = 2, isMine = true }); added(NS, 2)
    make({ id = 3, trade = { state = "unknown" } }); added(NS, 3)
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    byId[3].trade = { state = "yes" }
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 3, "inspect")
    assertEqual(NS.AutoAsk.Stats().waiting, 1)
    m.advance(10)
    assertEqual(whispers(m), 1)
end)

test("auto-ask edge: held while an encounter is in progress, then due the delay after its end", function()
    local NS, m, make = party()
    m.__fire("ENCOUNTER_START", 2902, "Boss", 16, 20)
    make(); added(NS, 1)
    assertTrue(NS.AutoAsk.Stats().inEncounter)
    m.advance(60)
    assertEqual(whispers(m), 0, "held through the fight")
    m.__fire("ENCOUNTER_END", 2902, "Boss", 16, 20, 1)
    m.advance(9.9)
    assertEqual(whispers(m), 0)
    m.advance(0.2)
    assertEqual(whispers(m), 1)
end)

test("auto-ask edge: an encounter that ends after the drop pushes the ask back", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    m.advance(5)
    m.__fire("ENCOUNTER_START", 2902, "Boss", 16, 20)
    m.__fire("ENCOUNTER_END", 2902, "Boss", 16, 20, 1)
    m.advance(9.9)
    assertEqual(whispers(m), 0, "10s from the end, not from the drop")
    m.advance(0.2)
    assertEqual(whispers(m), 1)
end)

test("auto-ask edge: asking yourself cancels it", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    NS.PressAsk(1)
    assertEqual(whispers(m), 1)
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    m.advance(60)
    assertEqual(whispers(m), 1, "no second ask")
end)

test("auto-ask edge: the looter leaving the group cancels it", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    m.setGroup({})
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(NS.AutoAsk.Stats().waiting, 0); assertEqual(NS.AutoAsk.Stats().canceled, 1)
    m.advance(60)
    assertEqual(whispers(m), 0)
end)

test("auto-ask edge: dismissing the row cancels it for good", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    NS.DismissDrop(1)
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    assertTrue(NS.State.windowGroup.dismissed[1], "the row is dismissed too")
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    assertEqual(NS.AutoAsk.Stats().waiting, 0, "not scheduled again")
    m.advance(60)
    assertEqual(whispers(m), 0)
end)

test("auto-ask edge: receiving the item cancels it", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    NS.History.OutcomeOf = function(id) if id == 1 then return "received" end end
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    m.advance(60)
    assertEqual(whispers(m), 0)
end)

test("auto-ask edge: a drop gone from the feed, or no longer qualifying, is dropped when due", function()
    local NS, m, make, byId = party()
    make(); added(NS, 1)
    make({ id = 2 }); added(NS, 2)
    byId[1] = nil
    byId[2].trade = { state = "no" }
    m.advance(10)
    assertEqual(whispers(m), 0); assertEqual(NS.AutoAsk.Stats().canceled, 2)
end)

test("auto-ask edge: turning it off cancels the waiting asks; turned on, older drops do not count", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", false))
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    make({ id = 2 })
    m.advance(1)
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 2, "gear")
    assertEqual(NS.AutoAsk.Stats().waiting, 0, "a drop from before it was turned on")
    make({ id = 3, at = m.GetTime() }); added(NS, 3)
    assertEqual(NS.AutoAsk.Stats().waiting, 1)
    m.advance(60)
    assertEqual(whispers(m), 1)
end)

-- A profile `name` saved with auto-ask `on`, then switched to (no row reaction runs).
local function switchProfile(NS, name, on)
    local sv = NS.addon.db.sv
    sv.profiles = sv.profiles or {}
    sv.profiles[name] = { messages = { autoAsk = { enabled = on } } }
    NS.addon.db:SetProfile(name)
end

test("auto-ask edge: a profile switch that turns it on never asks for the drops already there", function()
    local NS, m, make = party(true)
    make(); added(NS, 1)
    m.advance(1)
    switchProfile(NS, "AutoOn", true)
    assertEqual(NS.Setting("messages.autoAsk.enabled"), true)
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    assertEqual(NS.AutoAsk.Stats().waiting, 0, "a drop from before the switch")
    make({ id = 2, at = m.GetTime() }); added(NS, 2)
    assertEqual(NS.AutoAsk.Stats().waiting, 1, "a drop after it counts")
    assertEqual(printed(m, "Auto-ask is on: "), 0, "the notice is the row's alone")
    m.advance(60)
    assertEqual(whispers(m), 1)
end)

test("auto-ask edge: a profile switch that turns it off cancels the waiting asks", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    assertEqual(NS.AutoAsk.Stats().waiting, 1)
    switchProfile(NS, "AutoOff", false)
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    m.advance(60)
    assertEqual(whispers(m), 0)
end)

test("auto-ask edge: the first time it is turned on, a one-time notice explains it", function()
    local NS, m = party(true)
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    assertEqual(printed(m, "Auto-ask is on: "), 1)
    assertEqual(printed(m, "5 or more item levels"), 1, "the current least gain")
    assertEqual(printed(m, "10 seconds after the boss kill"), 1, "the current delay")
    assertTrue(NS.addon.db.global.notices.autoAsk)
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", false))
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    assertEqual(printed(m, "Auto-ask is on: "), 1, "said once")
    assertFalse(NS.AutoAsk.Notice())
end)

test("auto-ask edge: the stand-down cancels every waiting ask", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    assertTrue(NS.SchemaRuntime.Set("enabled", false))
    assertEqual(NS.AutoAsk.Stats().waiting, 0)
    assertTrue(NS.SchemaRuntime.Set("enabled", true))
    m.advance(60)
    assertEqual(whispers(m), 0)
end)

test("auto-ask edge: in test mode a placeholder's ask is printed, never sent", function()
    local NS, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    NS.SetTestMode(true)
    assertTrue(NS.AutoAsk.Stats().waiting >= 1, "the +19 crown qualifies")
    m.advance(10)
    assertEqual(#m.chatSent, 0)
    assertTrue(printed(m, "Test mode, not sent: ") >= 1)
end)

test("auto-ask: the diagnostics' messaging section reports auto-ask", function()
    local NS, _, make = party()
    make(); added(NS, 1)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("auto-ask: enabled=true delay=10 minGain=5 waiting=1 nextDue=10 inEncounter=false", 1, true)
        ~= nil, text)
    assertTrue(text:find("auto-ask: scheduled=1 sent=0 canceled=0", 1, true) ~= nil)
end)
