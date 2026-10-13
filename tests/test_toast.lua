-- tests/test_toast.lua — the upgrade toast (design spec §11.5, board 06 C): the pure qualifier and
-- composer, then the edge on the bus: off by default, one at a time from a queue, dismissed after
-- its duration and paused while hovered, held in combat unless allowed, each drop once, placed and
-- saved only in test mode, the optional sound, the Ask button, the stand-down and the diagnostics.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function drop(over)
    local d = {
        id = 1, link = link(500), itemID = 500, isMine = false,
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("toast: Qualifies wants someone else's upgrade for you of minGain or more, likely or yes to trade", function()
    local Q = T.newAddon().Toast.Qualifies
    assertTrue(Q(drop(), 10))
    assertTrue(Q(drop({ me = { verdict = "upgrade", ilvlDelta = 10 } }), 10), "exactly the threshold")
    assertTrue(Q(drop({ trade = { state = "yes" } }), 10))
    -- An empty slot is an upgrade with no item-level change (the kernel's emptySlot reason): it
    -- clears any least gain (DW-62 review F-002, design spec §5.2, §11.5).
    local empty = { verdict = "upgrade", reasons = { { key = "emptySlot" } } }
    -- red under: a gain test that reads a missing ilvlDelta as failing (modules/Toast.lua Qualifies)
    assertTrue(Q(drop({ me = empty }), 10))
    assertTrue(Q(drop({ me = empty }), 50))
    local cases = {
        { drop({ isMine = true }), "mine" },
        { drop({ me = { verdict = "sidegrade", ilvlDelta = 19 } }), "notUpgrade" },
        { drop({ me = false }), "notUpgrade" },
        { drop({ me = { verdict = "upgrade", ilvlDelta = 9 } }), "gain" },
        { drop({ me = { verdict = "upgrade" } }), "gain" },
        { drop({ me = { verdict = "upgrade", reasons = { { key = "uniqueEquipped" } } } }), "gain" },
        { drop({ trade = { state = "unknown" } }), "trade" },
        { drop({ trade = { state = "no" } }), "trade" },
        { drop({ trade = false }), "trade" },
        { nil, "mine" },
    }
    for i, c in ipairs(cases) do
        local ok, why = Q(c[1], 10)
        assertFalse(ok, "case " .. i); assertEqual(why, c[2], "case " .. i)
    end
end)

test("toast: Compose reads board 06 C: the title, the item and Looted by · gain · trade", function()
    local Toast = T.newAddon().Toast
    local t = Toast.Compose(drop())
    assertEqual(t.title, "Big upgrade for you")
    assertEqual(t.item, "Item 500"); assertEqual(t.link, link(500))
    assertEqual(T.marks(t.line), "Looted by Seta · +19 [arrow-up] · Likely tradeable")
    assertFalse(t.line:find("▲", 1, true) ~= nil, "the toast's face has no ▲: the mark is a texture (DW-F5)")
    assertEqual(T.marks(Toast.Compose(drop({ trade = { state = "yes" } })).line), "Looted by Seta · +19 [arrow-up] · Tradeable")
    local empty = { verdict = "upgrade", reasons = { { key = "emptySlot" } } }
    assertEqual(T.marks(Toast.Compose(drop({ me = empty })).line), "Looted by Seta · empty [arrow-up] · Likely tradeable",
        "an empty slot reads as the Me column does, never +0")
end)

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- An enabled instance whose feed answers `drops` by id, the toast turned on unless `off`.
local function enabled(drops, off)
    local NS, _, m = T.enableAddon()
    local byId = {}
    for _, d in ipairs(drops or {}) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    if not off then assertTrue(NS.SchemaRuntime.Set("toast.enabled", true)) end
    return NS, m, byId
end

local function added(NS, id) NS.addon:SendMessage(NS.MSG.DROP_ADDED, id) end

local function shown(NS) return NS.Toast.Stats().shown end

test("toast edge: off by default; nothing is built or shown", function()
    local NS = enabled({ drop() }, true)
    assertEqual(NS.Setting("toast.enabled"), false)
    added(NS, 1)
    assertNil(NS.Toast.Frame()); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: a qualifying drop shows at once, painted, and goes after its duration", function()
    local NS, m = enabled({ drop(), drop({ id = 2, me = { verdict = "upgrade", ilvlDelta = 3 } }) })
    added(NS, 2)
    assertNil(NS.Toast.Frame(), "a small gain does not toast")
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertTrue(shown(NS)); assertEqual(NS.Toast.Stats().dropId, 1)
    assertEqual(f.title:GetText(), "Big upgrade for you")
    assertEqual(f.item:GetText(), "Item 500")
    assertEqual(T.marks(f.line:GetText()), "Looted by Seta · +19 [arrow-up] · Likely tradeable")
    assertEqual(f.ask.label:GetText(), "Ask"); assertTrue(f.ask:IsEnabled())
    assertTrue(f.ask.art:IsShown() and f.ask.art:GetTexture() == NS.Icon("chat"), "Ask wears chat (feedback-7 spec §1)")
    assertEqual(#m.sounds, 0, "no sound unless asked for")
    local pt = { f:GetPoint(1) }
    assertEqual(pt[1], "TOP"); assertEqual(pt[5], -160)
    m.advance(7.9)
    assertTrue(shown(NS))
    m.advance(0.2)
    assertFalse(shown(NS)); assertNil(NS.Toast.Stats().dropId)
end)

test("toast edge: one at a time; the next waits its turn, and each drop toasts once", function()
    local NS, m = enabled({ drop(), drop({ id = 2, link = link(501) }), drop({ id = 3, link = link(502) }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 1); assertEqual(NS.Toast.Stats().waiting, 2)
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    added(NS, 1)
    assertEqual(NS.Toast.Stats().waiting, 2, "a drop already toasted is not queued again")
    m.advance(8)
    assertEqual(NS.Toast.Stats().dropId, 2)
    NS.Toast.Dismiss()
    assertEqual(NS.Toast.Stats().dropId, 3, "a click on the close mark shows the next")
    m.advance(8)
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: the queue keeps the newest MAX_QUEUE drops", function()
    local list = {}
    for i = 1, 8 do list[i] = drop({ id = i }) end
    local NS = enabled(list)
    for i = 1, 8 do added(NS, i) end
    assertEqual(NS.Toast.Stats().waiting, NS.Toast.MAX_QUEUE)
    NS.Toast.Dismiss()
    assertEqual(NS.Toast.Stats().dropId, 4, "2 and 3 were dropped as the oldest")
end)

test("toast edge: a drop that turns likely later toasts on its DropUpdated", function()
    local NS, _, byId = enabled({ drop({ trade = { state = "unknown" } }) })
    added(NS, 1)
    assertNil(NS.Toast.Frame())
    byId[1] = drop()
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    assertTrue(shown(NS))
end)

test("toast edge: a hover pauses the countdown, and leaving resumes it with the time left", function()
    local NS, m = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    m.advance(5)
    f.__mouseOver = true
    f:GetScript("OnEnter")(f)
    m.advance(30)
    assertTrue(shown(NS), "paused while hovered")
    f:GetScript("OnLeave")(f)
    assertTrue(shown(NS), "still over the frame (a child took the pointer): no resume")
    f.__mouseOver = false
    f:GetScript("OnLeave")(f)
    m.advance(2.9)
    assertTrue(shown(NS))
    m.advance(0.2)
    assertFalse(shown(NS), "the 3s it had left ran out")
end)

test("toast edge: leaving through the close button resumes the countdown", function()
    local NS, m = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    m.advance(5)
    f.__mouseOver = true
    f:GetScript("OnEnter")(f)
    -- The pointer moves onto the close button: still over the frame, so its OnLeave holds the pause.
    f:GetScript("OnLeave")(f)
    f.close:GetScript("OnEnter")(f.close)
    m.advance(30)
    assertTrue(shown(NS), "paused while over the close button")
    -- Then straight off the toast from the close button.
    f.__mouseOver = false
    f.close:GetScript("OnLeave")(f.close)
    m.advance(2.9)
    assertTrue(shown(NS))
    m.advance(0.2)
    assertFalse(shown(NS), "the 3s it had left ran out")
end)

test("toast edge: not shown in combat; held until it ends, unless toast.inCombat", function()
    local NS, m = enabled({ drop(), drop({ id = 2 }) })
    m.inCombat = true
    added(NS, 1)
    assertNil(NS.Toast.Frame()); assertTrue(NS.Toast.Stats().held)
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(shown(NS)); assertEqual(NS.Toast.Stats().dropId, 1)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 1, "back to the head of the queue")
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", true))
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(shown(NS), "allowed in combat now")
    m.__fire("PLAYER_REGEN_DISABLED")
    assertTrue(shown(NS), "and kept on screen")
end)

test("toast edge: a drop asked for, or gone from the feed, is skipped when its turn comes", function()
    local NS, _, byId = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    local asks = NS.Asks.StateOf
    NS.Asks.StateOf = function(kind, target, id) if id == 2 then return "sent" end return asks(kind, target, id) end
    byId[3] = nil
    NS.Toast.Dismiss()
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: Ask goes through the shared host handler, and the button follows its state", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    local pressed = {}
    NS.PressAsk = function(id) pressed[#pressed + 1] = id end
    NS.Asks.StateOf = function() return "queued" end
    local f = NS.Toast.Frame()
    f.ask:GetScript("OnClick")(f.ask)
    assertEqual(pressed[1], 1)
    assertEqual(f.ask.label:GetText(), "Queued")
    assertTrue(f.ask.art:GetTexture() == NS.Icon("clock"), "Queued wears clock")
    NS.Asks.StateOf = function() return "sent" end
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "sent", "ask", "Seta-Testrealm")
    assertEqual(f.ask.label:GetText(), "Asked"); assertFalse(f.ask:IsEnabled())
end)

test("toast edge: toast.sound plays the client's alert from SOUNDKIT", function()
    local NS, m = enabled({ drop() })
    assertTrue(NS.SchemaRuntime.Set("toast.sound", true))
    added(NS, 1)
    assertEqual(#m.sounds, 1); assertEqual(m.sounds[1][1], m.SOUNDKIT.UI_EPICLOOT_TOAST)
    m.SOUNDKIT = nil
    assertFalse(NS.Compat.PlayAlertSound(), "no SOUNDKIT: nothing played, nothing raised")
end)

test("toast edge: only test mode drags it; the position is saved and Reset position forgets it", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    local moved = 0
    f.StartMoving = function() moved = moved + 1 end
    f:GetScript("OnDragStart")(f)
    assertEqual(moved, 0, "outside test mode it stays put")
    NS.State.testMode = true
    f:GetScript("OnDragStart")(f)
    assertEqual(moved, 1)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 40, 500)
    f:GetScript("OnDragStop")(f)
    local p = NS.addon.db.profile.toast.point
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], "BOTTOMLEFT"); assertEqual(p[4], 500)
    NS.Window.ResetPosition()
    assertNil(NS.addon.db.profile.toast.point)
    assertEqual(({ f:GetPoint(1) })[1], "TOP")
end)

test("toast edge: test mode's placeholder toasts and stays until test mode ends", function()
    local NS, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.seedGearJournal()
    NS.SetTestMode(true)
    local id = NS.Toast.Stats().dropId
    assertTrue(id ~= nil, "the +19 crown qualifies")
    assertTrue(NS.LootFeed.Get(id).test)
    m.advance(60)
    assertTrue(shown(NS), "a test toast waits to be placed")
    NS.SetTestMode(false)
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

-- ── the toast follows its drop and its switch (DW-62 review F-001, F-004) ───────────────────

test("toast edge: a drop that leaves the feed takes its toast and its place in the queue", function()
    local NS, _, byId = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 1); assertEqual(NS.Toast.Stats().waiting, 2)
    -- `/dw clear` and clear-on-boss-kill empty the feed through LootFeed.Clear, which tells its sinks.
    byId[1], byId[2] = nil, nil
    -- red under: a toast with no removal sink (modules/Toast.lua)
    NS.LootFeed.Clear("live")
    assertEqual(NS.Toast.Stats().dropId, 3, "the gone toast went, and the gone drop in the queue was skipped")
    byId[3] = nil
    NS.LootFeed.Clear("live")
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: the cap's trim takes the trimmed drop's toast, through the real feed", function()
    local NS, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    local LF = NS.LootFeed
    local first = LF.AddTest({ link = link(500), looter = { name = "Seta", classFile = "PRIEST" },
        group = { key = "g", label = "G", kind = "encounter" }, me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", args = {} } })
    assertEqual(NS.Toast.Stats().dropId, first)
    LF.MAX_DROPS = 1
    LF.AddTest({ link = link(501), looter = { name = "Seta", classFile = "PRIEST" },
        group = { key = "g", label = "G", kind = "encounter" }, me = { verdict = "downgrade", ilvlDelta = -3 },
        trade = { state = "likely", args = {} } })
    LF.MAX_DROPS = 200
    assertEqual(LF.Get(first), nil, "the first drop was trimmed")
    assertFalse(shown(NS), "and its toast went with it")
    m.advance(1)
end)

test("toast edge: Ask on a toast whose drop is gone takes the toast down and asks nothing", function()
    local NS, _, byId = enabled({ drop() })
    added(NS, 1)
    local pressed = 0
    NS.PressAsk = function() pressed = pressed + 1 end
    byId[1] = nil
    NS.Toast.Ask()
    assertEqual(pressed, 0); assertFalse(shown(NS))
end)

test("toast edge: turning the toast off takes it down and empties the queue; on again, new drops toast", function()
    local NS = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    added(NS, 1); added(NS, 2)
    -- red under: a toast.enabled row with no reaction (settings/SchemaRows.lua)
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    assertFalse(shown(NS), "what was dropped stays dropped")
    added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 3)
end)

test("toast edge: a test toast goes when the toast is turned off, though it has no countdown", function()
    local NS, _, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.seedGearJournal()
    NS.SetTestMode(true)
    assertTrue(shown(NS))
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    assertFalse(shown(NS))
end)

test("toast edge: a profile switch to one with the toast off takes it down", function()
    local NS = enabled({ drop(), drop({ id = 2 }) })
    added(NS, 1); added(NS, 2)
    local db = NS.addon.db
    db:SetProfile("Other")
    assertEqual(NS.Setting("toast.enabled"), false)
    -- red under: reloadProfile without NS.Toast.OnProfileReloaded (core/DropWatcher.lua)
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: the stand-down empties the queue and takes the toast down", function()
    local NS = enabled({ drop(), drop({ id = 2 }) })
    added(NS, 1); added(NS, 2)
    assertTrue(NS.SchemaRuntime.Set("enabled", false))
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast: the diagnostics' window section reports the toast", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("toast: enabled=true built=true shown=true drop=1 waiting=0 held=false", 1, true) ~= nil, text)
    assertTrue(text:find("toast: point", 1, true) ~= nil)
end)
