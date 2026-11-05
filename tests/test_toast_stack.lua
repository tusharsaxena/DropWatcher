-- tests/test_toast_stack.lua — the upgrade toast's stack (issue #14, DW-T2; LibKa0s-Toast-1.0 minor
-- 4's opt-in `stack`): at the default `toast.stack` of 3, N qualifying drops give min(N, 3) toasts,
-- each on its own frame, the first at the saved point and the rest below it (or above it with
-- `toast.stackGrow` up); a toast that goes closes the gap and the next waiting one comes up; past the
-- stack they queue; the combat hold sends every one back and brings them all again; the two rows
-- apply live; and every path that acts on one toast (Prune, Ask, Dismiss, the Ask repaint) acts on
-- the toast whose drop it concerns, not on the first. A stack of 1 is tests/test_toast.lua's.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function drop(id)
    return {
        id = id, link = link(500 + id), itemID = 500 + id, isMine = false,
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }
end

-- An enabled instance at the default stack whose feed answers drops 1 to `n` by id.
local function enabled(n)
    local NS, _, m = T.enableAddon()
    local byId = {}
    for i = 1, n do byId[i] = drop(i) end
    NS.LootFeed.Get = function(id) return byId[id] end
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    return NS, m, byId
end

local function addAll(NS, n)
    for i = 1, n do NS.addon:SendMessage(NS.MSG.DROP_ADDED, i) end
end

local function visible(NS) return NS.Toast.Stats().visible end

local function sameList(got, want, what)
    what = what or "list"
    assertEqual(#got, #want, what .. ": " .. table.concat(got, ","))
    for i = 1, #want do assertEqual(got[i], want[i], what .. " #" .. i) end
end

-- The point a frame hangs by: { point, relativeTo, relativePoint, x, y }.
local function pointOf(f) return { f:GetPoint(1) } end

test("toast stack: the default is 3; N drops give min(N, 3) toasts, each on its own painted frame", function()
    local NS = enabled(2)
    assertEqual(NS.Setting("toast.stack"), 3, "the owner's default (issue #14)")
    assertEqual(NS.Setting("toast.stackGrow"), "down")
    addAll(NS, 2)
    sameList(visible(NS), { 1, 2 }, "two drops, two toasts")
    local f1, f2 = NS.Toast.Frame(1), NS.Toast.Frame(2)
    assertTrue(f1 ~= nil and f2 ~= nil and f1 ~= f2, "a frame each")
    assertEqual(f1, NS.Toast.Frame(), "the first is the head")
    assertEqual(f1.item:GetText(), "|cffa335eeItem 501|r")
    assertEqual(f2.item:GetText(), "|cffa335eeItem 502|r", "each painted with its own drop")
    assertTrue(f1:IsShown() and f2:IsShown())
    assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast stack: past the stack the drops queue, and the queue still keeps the newest MAX_QUEUE", function()
    local NS = enabled(9)
    addAll(NS, 4)
    sameList(visible(NS), { 1, 2, 3 }, "three on screen")
    sameList(NS.Toast.Stats().queue, { 4 }, "the fourth waits")
    addAll(NS, 9)
    assertEqual(NS.Toast.Stats().waiting, NS.Toast.MAX_QUEUE)
    sameList(NS.Toast.Stats().queue, { 5, 6, 7, 8, 9 }, "4 dropped as the oldest")
end)

test("toast stack: Down hangs each toast under the one before, from the saved point", function()
    local NS = enabled(3)
    addAll(NS, 3)
    local f1, f2, f3 = NS.Toast.Frame(1), NS.Toast.Frame(2), NS.Toast.Frame(3)
    local p1 = pointOf(f1)
    assertEqual(p1[1], "TOP"); assertEqual(p1[5], -160, "the head at the saved (default) point")
    local p2, p3 = pointOf(f2), pointOf(f3)
    assertEqual(p2[1], "TOP"); assertEqual(p2[2], f1); assertEqual(p2[3], "BOTTOM")
    assertTrue(p2[5] < 0, "a gap below the one before")
    assertEqual(p3[2], f2, "the third under the second")
end)

test("toast stack: Up hangs each toast above the one before", function()
    local NS = enabled(3)
    assertTrue(NS.SchemaRuntime.Set("toast.stackGrow", "up"))
    addAll(NS, 3)
    local f1, f2, f3 = NS.Toast.Frame(1), NS.Toast.Frame(2), NS.Toast.Frame(3)
    local p2, p3 = pointOf(f2), pointOf(f3)
    assertEqual(p2[1], "BOTTOM"); assertEqual(p2[2], f1); assertEqual(p2[3], "TOP")
    assertTrue(p2[5] > 0, "a gap above the one before")
    assertEqual(p3[2], f2)
    assertEqual(pointOf(f1)[5], -160, "the head stays at the saved point")
end)

test("toast stack: a toast that closes re-flows the rest onto the head, and the next waiting comes up", function()
    local NS = enabled(4)
    addAll(NS, 4)
    local f2 = NS.Toast.Frame(2)
    f2:GetScript("OnMouseUp")(f2, "RightButton")
    sameList(visible(NS), { 1, 3, 4 }, "2 closed, 4 came up at the tail")
    local f1, f3 = NS.Toast.Frame(1), NS.Toast.Frame(3)
    assertEqual(pointOf(f3)[2], f1, "3 hangs off 1 now")
    assertEqual(pointOf(NS.Toast.Frame(4))[2], f3)
    NS.Toast.Frame(1).close:GetScript("OnClick")(NS.Toast.Frame(1).close)
    sameList(visible(NS), { 3, 4 }, "the head's close mark: the next becomes the head")
    assertEqual(pointOf(NS.Toast.Frame(3))[5], -160, "at the saved point")
end)

test("toast stack: each toast has its own countdown and its own hover pause", function()
    local NS, m = enabled(3)
    addAll(NS, 3)
    m.advance(5)
    local f2 = NS.Toast.Frame(2)
    f2.__mouseOver = true
    f2:GetScript("OnEnter")(f2)
    m.advance(3.1)
    sameList(visible(NS), { 2 }, "the others ran out; the hovered one waits")
    f2.__mouseOver = false
    f2:GetScript("OnLeave")(f2)
    m.advance(3.1)
    sameList(visible(NS), {}, "and runs out with the 3s it had left")
end)

test("toast stack: the combat hold sends every toast back in order and brings them all again", function()
    local NS, m = enabled(4)
    addAll(NS, 4)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    sameList(visible(NS), {}, "nothing on screen in combat")
    sameList(NS.Toast.Stats().queue, { 1, 2, 3, 4 }, "back at the head of the queue, in their order")
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    sameList(visible(NS), { 1, 2, 3 }, "all three again")
    sameList(NS.Toast.Stats().queue, { 4 })
end)

test("toast stack: Show in combat turned off mid-combat keeps the whole stack up", function()
    local NS, m = enabled(4)
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", true))
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    addAll(NS, 3)
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", false))
    sameList(visible(NS), { 1, 2, 3 }, "kept on screen (Hold(true))")
    NS.Toast.Dismiss(2)
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 4)
    sameList(visible(NS), { 1, 3 }, "the next waits for combat's end")
end)

test("toast stack: the two rows apply live, smaller sending the tail back, larger filling", function()
    local NS = enabled(4)
    addAll(NS, 4)
    -- red under: a toast.stack row with no reaction (settings/SchemaRows.lua, NS.Toast.ApplyStack)
    assertTrue(NS.SchemaRuntime.Set("toast.stack", 1))
    sameList(visible(NS), { 1 }, "one at a time now")
    sameList(NS.Toast.Stats().queue, { 2, 3, 4 }, "the tail back at the head of the queue, in order")
    assertTrue(NS.SchemaRuntime.Set("toast.stack", 5))
    sameList(visible(NS), { 1, 2, 3, 4 }, "the larger stack filled from the queue")
    assertEqual(NS.Toast.Stats().stack, 5)
    local f1, f2 = NS.Toast.Frame(1), NS.Toast.Frame(2)
    assertEqual(pointOf(f2)[1], "TOP")
    assertTrue(NS.SchemaRuntime.Set("toast.stackGrow", "up"))
    assertEqual(NS.Toast.Stats().grow, "UP")
    assertEqual(pointOf(f2)[1], "BOTTOM", "re-anchored above at once"); assertEqual(pointOf(f2)[2], f1)
end)

test("toast stack: a profile switch reads the incoming stack and direction", function()
    local NS = enabled(4)
    local db = NS.addon.db
    local home = db:GetCurrentProfile()
    db:SetProfile("Other")
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    assertTrue(NS.SchemaRuntime.Set("toast.stack", 2))
    assertTrue(NS.SchemaRuntime.Set("toast.stackGrow", "up"))
    db:SetProfile(home)
    addAll(NS, 4)
    sameList(visible(NS), { 1, 2, 3 })
    db:SetProfile("Other")
    sameList(visible(NS), { 1, 2 }, "the incoming profile's 2")
    assertEqual(NS.Toast.Stats().grow, "UP")
end)

test("toast stack: Prune takes only the toasts whose drops left the feed, wherever they sit", function()
    local NS, _, byId = enabled(4)
    addAll(NS, 4)
    byId[2], byId[4] = nil, nil
    NS.LootFeed.Clear("live")
    sameList(visible(NS), { 1, 3 }, "the second went; the gone fourth was not brought up")
    assertEqual(NS.Toast.Stats().waiting, 0)
    assertEqual(pointOf(NS.Toast.Frame(3))[2], NS.Toast.Frame(1), "the gap closed")
end)

test("toast stack: Ask on a toast below the head asks for its own drop and repaints its own button", function()
    local NS = enabled(3)
    addAll(NS, 3)
    local pressed = {}
    NS.PressAsk = function(id) pressed[#pressed + 1] = id end
    local states = {}
    NS.Asks.StateOf = function(_, _, id) return states[id] or "ready" end
    states[2] = "queued"
    local f1, f2 = NS.Toast.Frame(1), NS.Toast.Frame(2)
    -- red under: an Ask that reads the head (`toast:Current()`) instead of its own frame's drop
    f2.ask:GetScript("OnClick")(f2.ask)
    sameList(pressed, { 2 }, "the second toast's drop")
    assertEqual(f2.ask.label:GetText(), "Queued")
    assertEqual(f1.ask.label:GetText(), "Ask", "the head's button untouched")
    states[3] = "sent"
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 3, "sent", "ask", "Seta-Testrealm")
    assertEqual(NS.Toast.Frame(3).ask.label:GetText(), "Asked", "the third's Ask follows its own ask")
    assertEqual(f1.ask.label:GetText(), "Ask")
end)

test("toast stack: Ask on a toast below the head whose drop is gone takes only that toast down", function()
    local NS, _, byId = enabled(3)
    addAll(NS, 3)
    local pressed = 0
    NS.PressAsk = function() pressed = pressed + 1 end
    byId[2] = nil
    local f2 = NS.Toast.Frame(2)
    f2.ask:GetScript("OnClick")(f2.ask)
    assertEqual(pressed, 0, "nothing asked")
    sameList(visible(NS), { 1, 3 }, "the head stays")
    NS.Toast.Ask(9)
    sameList(visible(NS), { 1, 3 }, "an id not on screen does nothing")
end)

test("toast stack: a skin switch repaints every toast on screen, not only the head", function()
    local NS, m = enabled(3)
    addAll(NS, 3)
    local f3 = NS.Toast.Frame(3)
    f3.item:SetText("stale")
    -- A switch to a test-only copy of the default skin (tests/test_skin_chrome.lua's shape).
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local tokens = {}
    for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
    Skin:RegisterSkin({ key = "dw-stack-switch", label = "Stack switch (test)", tokens = tokens })
    -- red under: an OnLooksChanged listener that repaints only the head (`toast:Frame()`)
    Skin:SetChoice("DropWatcher", "ka0s", "dw-stack-switch")
    assertEqual(f3.item:GetText(), "|cffa335eeItem 503|r", "the third toast repainted")
end)

test("toast stack: in test mode the sticky placeholders stack too", function()
    local NS, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.seedGearJournal()
    NS.SetTestMode(true)
    local ids = visible(NS)
    assertTrue(#ids >= 2, "more than one placeholder on screen: " .. #ids)
    assertTrue(#ids <= 3, "no more than the stack")
    for _, id in ipairs(ids) do assertTrue(NS.LootFeed.Get(id).test, "a test drop") end
    assertEqual(pointOf(NS.Toast.Frame(ids[2]))[2], NS.Toast.Frame(ids[1]), "stacked under the first")
    m.advance(60)
    assertEqual(#visible(NS), #ids, "sticky: they wait to be placed")
    NS.SetTestMode(false)
    sameList(visible(NS), {}, "test mode off: every one goes"); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast stack: the diagnostics name the stack and every toast on screen", function()
    local NS = enabled(4)
    addAll(NS, 4)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("toast: stack=3 grow=DOWN visible=3", 1, true) ~= nil, text)
    assertTrue(text:find("toast: on screen", 1, true) ~= nil, text)
    assertTrue(text:find("drop=1 waiting=1", 1, true) ~= nil, "the head and the one waiting")
    local onScreen = text:match("toast: on screen[^\n]*")
    assertTrue(onScreen ~= nil and onScreen:find("1, 2, 3", 1, true) ~= nil, tostring(onScreen))
    assertNil(onScreen:find("4", 1, true), "4 waits, not on screen")
    assertTrue(text:match("toast: queue[^\n]*4") ~= nil, "the waiting one is listed in the queue")
end)
