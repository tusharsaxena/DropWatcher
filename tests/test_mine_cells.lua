-- tests/test_mine_cells.lua — what your own drops and the Offer panel say (modules/MineCells.lua,
-- pure; design spec §11.4, board 04; feedback-5 spec §1-§3): the countdown and the Trade window
-- cell, the candidates ranked with their judgments (the Offer panel's Their eq cell is
-- test_side_cells'), the buttons' lifecycles and tones, the Drops strip's
-- summary (and its short compact form, modules/DropsStrip.lua), Post my tradeables' lines, the
-- Offer panel's header and its dock. The frame edges that paint them are test_window_group,
-- test_own_drops, test_drops_strip and test_offer_panel's.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRACERS = "|cffa335ee|Hitem:401::|h[Bracers of the Tide]|h|r"
local RING = "|cffa335ee|Hitem:402::|h[Band of Embers]|h|r"

local NONE = {}
local NOW = 1000

local function cand(name, classFile, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = status, eval = eval }
end

-- Board 04's first row: your bracers, a downgrade for you, 1:47:12 left on the item's own timer,
-- an upgrade for Seta (+14) and Butterz (+6), equal for Littlewolf, unusable for Uniquerogue and
-- one member still being checked.
local function candidates()
    local list = {
        cand("Seta", "PRIEST", "ready", { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 291 }, reasons = {} }),
        cand("Butterz", "MAGE", "ready", { verdict = "upgrade", ilvlDelta = 6, baseline = { ilvl = 299 }, reasons = {} }),
        cand("Littlewolf", "ROGUE", "ready", { verdict = "sidegrade", ilvlDelta = 0, baseline = { ilvl = 305 }, reasons = {} }),
        cand("Uniquerogue", "ROGUE", "ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }),
        cand("Fifth", "DRUID", "checking"),
    }
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

local function drop(over)
    local d = {
        id = 1, at = NOW - 700, link = BRACERS, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 305, equipLoc = "INVTYPE_WRIST", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6432 }, expiresAt = NOW + 6432 },
        candidates = candidates(),
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function MC() return T.newAddon().MineCells end

local function joined(tip) return table.concat(tip, " | ") end

-- ── the countdown ───────────────────────────────────────────────────────────────────────────

test("mine cells: Clock reads h:mm:ss", function()
    local M = MC()
    assertEqual(M.Clock(6432), "1:47:12")
    assertEqual(M.Clock(521), "0:08:41")
    assertEqual(M.Clock(-4), "0:00:00")
    assertEqual(M.Clock(nil), "0:00:00")
end)

test("mine cells: the countdown is exact from the item's timer, estimated from the drop before it", function()
    local M = MC()
    local exact = M.Countdown(drop(), NOW)
    assertEqual(exact.left, 6432); assertTrue(exact.exact)
    assertTrue(math.abs(exact.fraction - 6432 / 7200) < 1e-9)
    local est = M.Countdown(drop({ trade = { state = "likely", reasonKey = "groupLoot", basis = "rule" } }), NOW)
    assertEqual(est.left, 7200 - 700); assertFalse(est.exact)
    assertTrue(M.Countdown(drop({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }), NOW) == nil)
    assertTrue(M.Countdown(drop({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } }), NOW) == nil)
end)

test("mine cells: the Trade window says the countdown, ending soon, not tradeable or no limit", function()
    local M = MC()
    local c = M.TradeWindow(drop(), NOW, 600)
    assertEqual(c.text, "1:47:12"); assertEqual(c.tone, "plain"); assertFalse(c.bold)
    assertTrue(joined(c.tip):find("Read from the item's tooltip") ~= nil)
    local soon = M.TradeWindow(drop({ trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 } }), NOW, 600)
    assertEqual(soon.text, "0:08:41"); assertTrue(soon.bold); assertEqual(soon.tone, "warn")
    assertTrue(joined(soon.tip):find("Ending soon: trade it now") ~= nil, "ending soon is in the tooltip, never the cell")
    local off = M.TradeWindow(drop({ trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 } }), NOW, 0)
    assertFalse(off.bold, "a threshold of 0 turns the warning off")
    local est = M.TradeWindow(drop({ trade = { state = "likely", reasonKey = "groupLoot", basis = "rule" } }), NOW, 600)
    assertEqual(est.text, "~1:48:20"); assertTrue(joined(est.tip):find("Estimated from when it dropped") ~= nil)
    local no = M.TradeWindow(drop({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }), NOW, 600)
    assertEqual(no.text, "Bonus roll"); assertEqual(no.fraction, 0); assertEqual(no.tone, "bad")
    assertEqual(no.tip[2], "Bonus roll loot can't be traded.")
    local boe = M.TradeWindow(drop({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } }), NOW, 600)
    assertEqual(boe.text, "No limit (BoE)"); assertEqual(boe.fraction, 1)
    local none = M.TradeWindow(drop({ trade = NONE }), NOW, 600)
    assertEqual(none.text, "Checking"); assertTrue(#none.tip >= 2)
end)

-- ── the candidates ──────────────────────────────────────────────────────────────────────────

test("mine cells: the candidates are ranked upgrades first by gain, each with its judgment and why", function()
    local M = MC()
    local list = M.Candidates(drop())
    local names, statuses, gains = {}, {}, {}
    for i, e in ipairs(list) do names[i], statuses[i], gains[i] = e.short, e.status, tostring(e.gain) end
    assertEqual(table.concat(names, ","), "Seta,Butterz,Littlewolf,Uniquerogue,Fifth")
    assertEqual(table.concat(statuses, ","), "upgrade,upgrade,sidegrade,cantUse,checking")
    assertEqual(table.concat(gains, ","), "14,6,0,nil,nil")
    assertTrue(list[1].offerable and list[3].offerable); assertFalse(list[4].offerable)
    assertEqual(list[1].eval.verdict, "upgrade"); assertEqual(list[1].baseline.ilvl, 291)
    assertTrue(list[5].eval == nil, "nothing judged while checking")
    for _, e in ipairs(list) do
        assertTrue(type(e.explain) == "string" and e.explain ~= "", e.short .. " has a reason")
        assertTrue(e.pill == nil and e.eq == nil, "no pill and no eq text (feedback-7 spec §0)")
    end
    local gone = M.Candidates(drop({ candidates = { x = cand("Gone", "MAGE", "unavailable") } }))
    assertEqual(gone[1].status, "unavailable")
    local odd = M.Candidates(drop({ candidates = { x = cand("Odd", "MAGE", "ready", { verdict = "strange" }) } }))
    assertEqual(odd[1].status, "unknown", "a verdict the panel does not know reads unknown")
end)

-- ── the buttons and the actions ─────────────────────────────────────────────────────────────

test("mine cells: Offer and Announce follow the ask's lifecycle; the Trade button is gone", function()
    local M = MC()
    local want = { ready = "Offer", queued = "Queued", sent = "Offered", failed = "Retry" }
    for state, text in pairs(want) do
        local b = M.OfferButton(state, "throttled", "Seta")
        assertEqual(b.text, text, state); assertTrue(#b.tip >= 2, state)
    end
    assertFalse(M.OfferButton("sent", nil, "Seta").enabled)
    assertEqual(M.OfferButton("queued", nil, "Seta").icon, "clock")
    assertTrue(M.OfferButton("failed", "throttled", "Seta").tip[2]:find("throttled") ~= nil)
    assertEqual(M.AnnounceButton("sent").text, "Announced")
    assertEqual(M.AnnounceButton(nil).text, "Announce")
    assertEqual(M.OfferButton("ready", nil, "Seta").kind, "offer", "Offer is cyan (feedback-6 spec §2)")
    assertEqual(M.OfferButton("sent", nil, "Seta").kind, "offer")
    assertTrue(M.OfferButton("failed", "throttled", "Seta").kind == nil, "Retry stays red")
    assertTrue(M.AnnounceButton(nil).kind == nil, "Announce is unchanged")
    assertTrue(M.TradeButton == nil, "the Offer panel's Trade button went with feedback-7 spec §0")
end)

-- ── the summary, the post, the dock ─────────────────────────────────────────────────────────

test("mine cells: the summary counts the tradeable drops and names the next expiry", function()
    local M = MC()
    local s = M.Summary({ drop(), drop({ id = 2, trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 } }),
        drop({ id = 3, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }) }, NOW)
    assertEqual(s.text, "2 tradeable · next expiry 0:08:41"); assertEqual(s.count, 2)
    assertEqual(M.Summary({}, NOW).text, "0 tradeable")
    assertEqual(M.Summary({ drop({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } }) }, NOW).text, "1 tradeable")
end)

test("mine cells: Post my tradeables lists every link, cut at the chat limit without splitting one", function()
    local M = MC()
    local one = M.PostLines({ BRACERS, RING })
    assertEqual(#one, 1)
    assertEqual(one[1], "Up for trade, whisper me: " .. BRACERS .. " " .. RING)
    local links = {}
    for i = 1, 8 do links[i] = ("|cffa335ee|Hitem:%d::|h[A Long Item Name Number %d]|h|r"):format(500 + i, i) end
    local lines = M.PostLines(links)
    assertTrue(#lines > 1, "several lines")
    local seen = 0
    for _, line in ipairs(lines) do
        assertTrue(#line <= 255, #line .. " bytes")
        assertTrue(line:find("^Up for trade, whisper me: ") ~= nil)
        for _ in line:gmatch("|Hitem:") do seen = seen + 1 end
    end
    assertEqual(seen, 8, "every link, each whole")
    assertEqual(#M.PostLines({}), 0)
end)

test("mine cells: the Offer panel docks right, else left, else floats", function()
    local M = MC()
    assertEqual(M.DockSide(100, 1040, 440, 1920, 4), "right")
    assertEqual(M.DockSide(900, 1840, 440, 1920, 4), "left")
    assertEqual(M.DockSide(200, 1800, 440, 1920, 4), "float")
    assertEqual(M.DockSide(nil, nil, 440, nil), "right", "unknown geometry docks right")
end)

test("mine cells: the panel's header reads your change, the item level and the trade window", function()
    local M = MC()
    local h = M.PanelHeader(drop(), NOW, 600)
    assertEqual(h.name, "Bracers of the Tide")
    assertEqual(h.text, "You: -5 ilvl · 305 · Trade window 1:47:12")
    assertTrue(#h.tip >= 3)
end)

-- ── whose move it is (feedback-4 spec §1) ───────────────────────────────────────────────────

test("mine cells: ToneState is the button's own state, or tradedAway once you traded the drop away", function()
    local M = MC()
    assertEqual(M.ToneState(nil, nil), "ready"); assertEqual(M.ToneState("offered", "sent"), "sent")
    assertEqual(M.ToneState("tradedAway", "ready"), "tradedAway")
end)

-- ── the Drops strip, pure (modules/DropsStrip.lua, feedback-5 spec §3) ──────────────────────

test("drops strip: it counts your drops the tab lists, its filters applied, in the feed's order", function()
    local DS = T.newAddon().DropsStrip
    local drops = { drop({ id = 1 }), drop({ id = 2, isMine = false }), drop({ id = 3 }), drop({ id = 4 }) }
    local own = DS.Own(drops, function(d) return d.id ~= 4 end)
    assertEqual(#own, 2); assertEqual(own[1].id, 1); assertEqual(own[2].id, 3)
    assertEqual(#DS.Own(nil, function() return true end), 0)
end)

test("drops strip: the compact layout's summary is shortened", function()
    local DS = T.newAddon().DropsStrip
    assertEqual(DS.SummaryText({ count = 3, next = 521 }), "3 tradeable · next 0:08:41")
    assertEqual(DS.SummaryText({ count = 1 }), "1 tradeable")
    assertEqual(DS.SummaryText({ count = 0 }), "0 tradeable")
end)
