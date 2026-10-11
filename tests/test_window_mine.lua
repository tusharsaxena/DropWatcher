-- tests/test_window_mine.lua — the My drops tab and the Offer panel (design spec §11.4, board 04):
-- every cell's text, tone and reason tooltip (modules/MineCells.lua, pure), the countdown, the
-- candidates ranked with their pills, the buttons' lifecycles, the summary, Post my tradeables'
-- lines and the dock; then the tab and the panel built headless under the mock: pooled rows, the
-- countdown that moves on TradeTimerTick, Hide, Announce, Offer (the row's and the panel's), Trade
-- and Post my tradeables through their host handlers.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRACERS = "|cffa335ee|Hitem:401::|h[Bracers of the Tide]|h|r"
local RING = "|cffa335ee|Hitem:402::|h[Band of Embers]|h|r"
local TRINKET = "|cffa335ee|Hitem:403::|h[Idol of Storms]|h|r"
local BOOTS = "|cffa335ee|Hitem:404::|h[Treads of Dawn]|h|r"

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
    assertEqual(soon.text, "0:08:41 ending soon"); assertTrue(soon.bold); assertEqual(soon.tone, "warn")
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

test("mine cells: For me asks `keep?` under an upgrade for you", function()
    local M = MC()
    local up = M.ForMe(drop({ me = { verdict = "upgrade", ilvlDelta = 3, reasons = {} } }))
    assertEqual(up.text, "+3"); assertEqual(up.glyph, "▲"); assertEqual(up.sub, "keep?")
    assertTrue(joined(up.tip):find("keep it, or offer it anyway") ~= nil)
    local down = M.ForMe(drop())
    assertEqual(down.text, "-5"); assertEqual(down.glyph, "▽"); assertTrue(down.sub == nil)
end)

-- ── the candidates ──────────────────────────────────────────────────────────────────────────

test("mine cells: the candidates are ranked upgrades first by gain, each with its pill and eq → drop", function()
    local M = MC()
    local list = M.Candidates(drop())
    local names, pills, eqs = {}, {}, {}
    for i, e in ipairs(list) do names[i], pills[i], eqs[i] = e.short, e.pill.text, e.eq end
    assertEqual(table.concat(names, ","), "Seta,Butterz,Littlewolf,Uniquerogue,Fifth")
    assertEqual(table.concat(pills, ","), "+14 UPGRADE,+6 UPGRADE,EQUAL,CAN'T USE,CHECKING")
    assertEqual(table.concat(eqs, ","), "291 → 305,299 → 305,305 → 305,– → 305,… → 305")
    assertTrue(list[1].offerable and list[3].offerable); assertFalse(list[4].offerable)
    for _, e in ipairs(list) do assertTrue(#e.pill.tip >= 2, e.short .. " has a reason") end
    local gone = M.Candidates(drop({ candidates = { x = cand("Gone", "MAGE", "unavailable") } }))
    assertEqual(gone[1].pill.text, "UNAVAILABLE"); assertEqual(gone[1].pill.tone, "muted")
    local down = M.Candidates(drop({ candidates = { x = cand("Big", "MAGE", "ready", { verdict = "downgrade", ilvlDelta = -9, reasons = {} }) } }))
    assertEqual(down[1].pill.text, "NO UPGRADE"); assertEqual(down[1].eq, "314 → 305")
end)

test("mine cells: Best candidates shows the top three, `+n more`, or why there are none", function()
    local M = MC()
    local c = M.BestCandidates(drop())
    assertEqual(c.text, "Seta +14 · Butterz +6"); assertEqual(c.tone, "good")
    assertTrue(joined(c.tip):find("Littlewolf: EQUAL") ~= nil)
    local many = candidates()
    for i = 1, 3 do
        local x = cand("Extra" .. i, "MAGE", "ready", { verdict = "upgrade", ilvlDelta = i, reasons = {} })
        many[x.guid] = x
    end
    assertEqual(M.BestCandidates(drop({ candidates = many })).text, "Seta +14 · Butterz +6 · Extra3 +3 · +2 more")
    local checking = M.BestCandidates(drop({ candidates = { x = cand("Fifth", "DRUID", "checking") } }))
    assertEqual(checking.text, "1 checking")
    local nobody = M.BestCandidates(drop({ candidates = { x = cand("Big", "MAGE", "ready", { verdict = "downgrade", ilvlDelta = -9, reasons = {} }) } }))
    assertEqual(nobody.text, "Nobody's upgrade")
    assertEqual(M.BestCandidates(drop({ candidates = {} })).text, "Nobody else in your group")
    local no = M.BestCandidates(drop({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }))
    assertEqual(no.text, "–"); assertTrue(#no.tip >= 2)
end)

test("mine cells: an upgrade for you hides its candidates until you choose to offer it", function()
    local M = MC()
    local mine = drop({ me = { verdict = "upgrade", ilvlDelta = 3, reasons = {} } })
    local hidden = M.BestCandidates(mine)
    assertEqual(hidden.text, "Hidden: an upgrade for you"); assertTrue(hidden.hidden)
    assertTrue(hidden.tip[2]:find("unless you choose to") ~= nil)
    assertEqual(M.BestCandidates(mine, true).text, "Seta +14 · Butterz +6")
end)

-- ── the buttons and the actions ─────────────────────────────────────────────────────────────

test("mine cells: Offer and Announce follow the ask's lifecycle; Trade is disabled with its reason", function()
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
    local off = M.TradeButton(false, "That player is out of trade range.", "Seta")
    assertFalse(off.enabled); assertEqual(off.tip[2], "That player is out of trade range.")
    assertTrue(M.TradeButton(true, nil, "Seta").enabled)
end)

test("mine cells: a tradeable row offers Offer and Announce; a dead one a dash and Hide", function()
    local M = MC()
    local d = drop()
    local a = M.Actions(d, M.BestCandidates(d), M.AnnounceButton("ready"))
    assertTrue(a.tradeable); assertTrue(a.offer.primary, "an upgrade for someone: Offer stands out")
    local up = drop({ me = { verdict = "upgrade", ilvlDelta = 3, reasons = {} } })
    assertFalse(M.Actions(up, M.BestCandidates(up), M.AnnounceButton("ready")).offer.primary)
    local dead = drop({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } })
    local b = M.Actions(dead, M.BestCandidates(dead), M.AnnounceButton("ready"))
    assertFalse(b.tradeable); assertTrue(b.dash.tip[2]:find("Bonus roll") ~= nil); assertTrue(#b.hide.tip >= 2)
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

-- ── the entries ─────────────────────────────────────────────────────────────────────────────

test("mine: the entries are your own drops that pass the filter and were not hidden, in the tab's order", function()
    local NS = T.newAddon()
    local WM = NS.WindowMine
    local drops = { drop({ id = 1, at = 10 }), drop({ id = 2, at = 30, isMine = false }), drop({ id = 3, at = 20 }), drop({ id = 4, at = 40 }) }
    local ctx = { matches = function(d) return d.id ~= 4 end, compare = function(a, b) return a.at > b.at end }
    local e = WM.Entries(drops, ctx, {})
    assertEqual(#e, 2); assertEqual(e[1].id, 3); assertEqual(e[2].id, 1)
    assertEqual(#WM.Entries(drops, ctx, { dismissed = { [3] = true } }), 1)
end)

-- M10 review (FB2-10): My drops groups its rows under the same headers as the other two tabs.
local function groupOf(key, at, ids, roster)
    return { key = key, label = key, kind = "encounter", at = at, drops = ids, roster = roster }
end

local function rowsCtx(over)
    local ctx = { matches = function() return true end, compare = function(a, b) return a.at > b.at end,
        hiddenBy = function() return "view" end, filter = {} }
    for k, v in pairs(over or {}) do ctx[k] = v end
    return ctx
end

local function shape(list)
    local out = {}
    for _, e in ipairs(list) do
        out[#out + 1] = e.kind == "header" and ("[" .. e.group.key .. ":" .. e.count .. "/" .. e.total .. "]")
            or tostring(e.drop.id)
    end
    return table.concat(out, " ")
end

test("mine: rows sit under their run's or encounter's header, newest group first, every group open", function()
    local NS = T.newAddon()
    local WM = NS.WindowMine
    local drops = { drop({ id = 1, at = 10 }), drop({ id = 2, at = 30, isMine = false }), drop({ id = 3, at = 20 }),
        drop({ id = 4, at = 40 }), drop({ id = 5, at = 50 }) }
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    local get = function(id) return byId[id] end
    local groups = { groupOf("Boss A", 5, { 1, 2, 3 }), groupOf("Others", 25, { 2 }), groupOf("Boss B", 35, { 4 }) }
    -- red under: one flat list, no header
    assertEqual(shape(WM.Rows(groups, drops, get, rowsCtx(), {})), "[Boss B:1/1] 4 [Boss A:2/2] 3 1 5",
        "a group with none of yours has no header; a drop in no group is still listed, last")
    local ctx = rowsCtx({ matches = function(d) return d.id ~= 3 end })
    assertEqual(shape(WM.Rows(groups, drops, get, ctx, {})), "[Boss B:1/1] 4 [Boss A:1/2] 1 5",
        "a drop the filter hid is counted under its header")
    assertEqual(shape(WM.Rows(groups, drops, get, rowsCtx(), { collapsed = { ["Boss B"] = true } })),
        "[Boss B:1/1] [Boss A:2/2] 3 1 5", "a collapsed group keeps its header only")
    assertEqual(shape(WM.Rows(groups, drops, get, rowsCtx(), { dismissed = { [4] = true } })), "[Boss A:2/2] 3 1 5")
end)

-- ── the tab, headless ───────────────────────────────────────────────────────────────────────

local ROSTER = { { name = "Me", class = "PALADIN", me = true }, { name = "Seta", class = "PRIEST" } }

local function seed(NS, drops, groups)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    NS.LootFeed.Groups = function() return groups or {} end
end

-- Board 04's four rows.
local function boardDrops()
    return {
        drop(),
        drop({ id = 2, at = NOW - 1800, link = RING, facts = { ilvl = 298, equipLoc = "INVTYPE_FINGER", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 3, reasons = {} },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 5405 } }),
        drop({ id = 3, at = NOW - 2000, link = TRINKET, facts = { ilvl = 305, equipLoc = "INVTYPE_TRINKET", quality = 4 },
            me = { verdict = "downgrade", ilvlDelta = -11, reasons = {} },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 },
            candidates = { x = cand("Littlewolf", "ROGUE", "ready", { verdict = "upgrade", ilvlDelta = 9, baseline = { ilvl = 296 }, reasons = {} }) } }),
        drop({ id = 4, at = NOW - 100, link = BOOTS, facts = { ilvl = 311, equipLoc = "INVTYPE_FEET", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 6, reasons = {} },
            trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
    }
end

local function shownMine()
    local NS, _, m = T.enableAddon()
    m.__now = NOW
    seed(NS, boardDrops(), { groupOf("Den of Nalorakk", NOW - 3000, { 1, 2, 3, 4 }, ROSTER) })
    NS.Asks.StateOf = function() return "ready" end
    NS.TradeHelper.CanGive = function() return false, "range" end
    NS.ShowWindow()
    NS.Window.SelectTab("mine")
    return NS, NS.WindowMine.Drawn(), m
end

local function rowFor(drawn, id)
    for _, r in ipairs(drawn.rows) do if r.dropId == id then return r end end
end

local function textOf(region) return region and region:GetText() end

test("mine tab: a narrow row sheds Best candidates, Ilvl and For me, and keeps Actions inside it", function()
    local NS = T.newAddon()
    local K = NS.Constants.WINDOW
    local cols = NS.WindowMine.COLUMNS
    local function names(list)
        local out = {}
        for _, c in ipairs(list) do out[#out + 1] = c.key end
        return table.concat(out, ",")
    end
    assertEqual(names(NS.WindowGroup.Fit(cols, 900)), "item,ilvl,forMe,trade,best,actions")
    local narrow = K.MIN_WIDTH - 2 * K.INSET - K.SCROLL_W
    local layout, kept = NS.WindowGroup.Layout(cols, narrow)
    assertEqual(names(kept), "item,trade,actions")
    assertTrue(layout.actions.x + layout.actions.w <= narrow, "Offer and Announce stay reachable")
end)

test("mine tab: built headless, one row per drop of yours, each column painted", function()
    local NS, drawn = shownMine()
    assertEqual(#drawn.rows, 4)
    local c = rowFor(drawn, 1).cells
    assertEqual(textOf(c.item.text), "Bracers of the Tide"); assertEqual(c.item.button.link, BRACERS)
    assertEqual(textOf(c.ilvl.text), "305")
    assertEqual(textOf(c.forMe.text), "-5"); assertEqual(textOf(c.forMe.glyph), "▽")
    assertEqual(textOf(c.trade.text), "1:47:12")
    assertTrue(math.abs(c.trade.fraction - 6432 / 7200) < 1e-9)
    assertEqual(textOf(c.best.text), "Seta +14 · Butterz +6")
    assertTrue(c.actions.offer:IsShown()); assertTrue(c.actions.announce:IsShown())
    assertFalse(c.actions.hide:IsShown())
    local ring = rowFor(drawn, 2).cells
    assertEqual(textOf(ring.forMe.sub), "keep?")
    assertEqual(textOf(ring.best.text), "Hidden: an upgrade for you")
    local trinket = rowFor(drawn, 3).cells
    assertEqual(textOf(trinket.trade.text), "0:08:41 ending soon"); assertTrue(trinket.trade.bold)
    local boots = rowFor(drawn, 4).cells
    assertEqual(textOf(boots.trade.text), "Bonus roll")
    assertFalse(boots.actions.offer:IsShown()); assertTrue(boots.actions.dash:IsShown()); assertTrue(boots.actions.hide:IsShown())
    assertEqual(drawn.summary.text, "3 tradeable · next expiry 0:08:41")
    assertEqual(textOf(drawn.pane.summary.info.text), "3 tradeable · next expiry 0:08:41")
    assertTrue(drawn.pane.summary.post:IsEnabled())
    assertFalse(drawn.pane.placeholder:IsShown())
    assertEqual(textOf(NS.Window.Frame().tabs.mine.label), "My drops · 3")
end)

-- Feedback-2 spec §8 (FB2-9): the row height plus room for the countdown bar, in the tables' text size.
test("mine tab: a row is the row height plus its bar's room, in the Font size row's size", function()
    local NS, drawn = shownMine()
    local r = rowFor(drawn, 3)
    assertEqual(r:GetHeight(), 28, "18 plus the bar's 10")
    assertEqual(r.cells.trade:GetHeight(), 28)
    local _, size = r.cells.ilvl.text:GetFont()
    assertEqual(size, 10, "the template's own size by default")
    NS.SchemaRuntime.Set("window.rowHeight", 24)
    NS.SchemaRuntime.Set("window.fontSize", 14)
    r = rowFor(NS.WindowMine.Drawn(), 3)
    assertEqual(r:GetHeight(), 34)
    _, size = r.cells.ilvl.text:GetFont()
    assertEqual(size, 14)
    _, size = r.cells.trade.text:GetFont()
    assertEqual(size, 14, "the countdown too, after its bold face")
    _, size = r.cells.forMe.sub:GetFont()
    assertEqual(size, 14, "and the line under the verdict")
end)

test("mine tab: every shown cell has a reason tooltip; nothing is blank", function()
    local NS, drawn = shownMine()
    local W = NS.Window
    for _, row in ipairs(drawn.rows) do
        for key, cell in pairs(row.cells) do
            if key ~= "actions" then
                local itemTip = cell.showItem and cell.itemButton.link ~= nil   -- the real item tooltip (DW-80)
                assertTrue(itemTip or #W.TooltipOf(cell) >= 2, key .. " has a reason")
                assertTrue((cell.text:GetText() or "") ~= "", key .. " is not blank")
            end
        end
        local a = row.cells.actions
        for _, b in ipairs({ a.offer, a.announce, a.dashTip, a.hide }) do
            if b:IsShown() then assertTrue(#W.TooltipOf(b) >= 2, "an action has a reason") end
        end
    end
    for _, label in pairs(drawn.pane.colHead.labels) do assertTrue(#W.TooltipOf(label) >= 2) end
    assertTrue(#W.TooltipOf(drawn.pane.summary.info) >= 2)
    assertTrue(#W.TooltipOf(drawn.pane.summary.post) >= 2)
end)

test("mine tab: rows come from the pool and a repaint reuses them", function()
    local NS, drawn = shownMine()
    local first = drawn.rows[1]
    NS.Window.Refresh()
    drawn = NS.WindowMine.Drawn()
    assertTrue(drawn.rows[1] == first)
    local free, active = NS.Pool.Counts(drawn.pane.rowPool)
    assertEqual(free .. "/" .. active, "0/4")
end)

test("mine tab: the rows sit under a header naming the party; a click collapses the group", function()
    local NS, drawn = shownMine()
    assertEqual(#drawn.headers, 1)
    local h = drawn.headers[1]
    local text = textOf(h.text)
    assertTrue(text:find("Den of Nalorakk", 1, true) == 1, text)
    assertTrue(text:find("4 drops", 1, true) ~= nil, text)
    assertTrue(text:find("Seta", 1, true) ~= nil, "the roster, as on the other tabs: " .. text)
    assertTrue(#NS.Window.TooltipOf(h) >= 3)
    h:__fire("OnClick")
    drawn = NS.WindowMine.Drawn()
    assertEqual(#drawn.rows, 0, "collapsed")
    assertTrue(textOf(drawn.headers[1].text):find("(collapsed)", 1, true) ~= nil)
    assertEqual(drawn.summary.text, "3 tradeable · next expiry 0:08:41", "the summary still counts them")
    drawn.headers[1]:__fire("OnClick")
    assertEqual(#NS.WindowMine.Drawn().rows, 4)
end)

test("mine tab: TradeTimerTick moves the countdown while the tab shows", function()
    local NS, _, m = shownMine()
    m.__now = NOW + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(textOf(rowFor(NS.WindowMine.Drawn(), 1).cells.trade.text), "1:47:00")
end)

test("mine tab: Hide takes a dead row off the tab for the session", function()
    local NS, drawn = shownMine()
    rowFor(drawn, 4).cells.actions.hide:__fire("OnClick")
    drawn = NS.WindowMine.Drawn()
    assertEqual(#drawn.rows, 3); assertTrue(NS.State.windowMine.dismissed[4])
end)

test("mine tab: Announce goes through the shared handler, and AskStateChanged repaints it", function()
    local NS, drawn, m = shownMine()
    local calls, state = {}, "ready"
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, tostring(target), id }; state = "queued"; return "queued" end
    NS.Asks.StateOf = function(kind) return kind == "announce" and state or "ready" end
    rowFor(drawn, 1).cells.actions.announce:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "announce,nil,1")
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "queued", "announce", "group")
    m.advance(0)   -- a bus message repaints on the next frame
    local b = rowFor(NS.WindowMine.Drawn(), 1).cells.actions.announce
    assertEqual(textOf(b.label), "Queued")
    state = "sent"
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "sent", "announce", "group")
    m.advance(0)
    b = rowFor(NS.WindowMine.Drawn(), 1).cells.actions.announce
    assertEqual(textOf(b.label), "Announced"); assertFalse(b:IsEnabled())
end)

test("mine tab: with no drop of yours the empty line says so; a filter that hides them says that", function()
    local NS, _, m = T.enableAddon()
    m.__now = NOW
    NS.ShowWindow()
    NS.Window.SelectTab("mine")
    local pane = NS.WindowMine.Drawn().pane
    assertTrue(pane.placeholder:IsShown())
    assertEqual(textOf(pane.placeholder), "Your tradeable drops appear here, with who each would help.")
    assertFalse(pane.summary.post:IsEnabled(), "nothing to post")
    seed(NS, boardDrops())
    NS.WindowFilterBar.Set("mine", "search", "nothing like it")
    assertEqual(textOf(pane.placeholder), "None of your drops matches the filters.")
end)

-- ── the Offer panel ─────────────────────────────────────────────────────────────────────────

local function openPanel()
    local NS, drawn, m = shownMine()
    rowFor(drawn, 1).cells.actions.offer:__fire("OnClick")
    return NS, NS.OfferPanel.Drawn(), m
end

test("offer panel: Offer opens it docked right, the candidates ranked with their pills", function()
    local NS, p = openPanel()
    assertTrue(NS.OfferPanel.IsShown()); assertEqual(NS.OfferPanel.DropId(), 1)
    assertEqual(p.panel.dock, "right")
    assertEqual(textOf(p.panel.name.text), "Bracers of the Tide")
    assertEqual(textOf(p.panel.line.text), "You: -5 ilvl · 305 · Trade window 1:47:12")
    assertEqual(#p.rows, 5)
    local r1 = p.rows[1]
    assertEqual(textOf(r1.member.text), "Seta"); assertEqual(textOf(r1.eq.text), "291 → 305")
    assertEqual(textOf(r1.pill.text), "+14 UPGRADE")
    assertTrue(r1.offer:IsShown()); assertTrue(r1.trade:IsShown())
    local r4 = p.rows[4]
    assertEqual(textOf(r4.pill.text), "CAN'T USE"); assertFalse(r4.offer:IsShown()); assertTrue(r4.dash:IsShown())
    assertEqual(textOf(p.rows[5].pill.text), "CHECKING")
    assertEqual(textOf(p.panel.note.text), "5 members · sorted by gain")
end)

test("offer panel: every part has a reason tooltip; Trade is disabled with the trade helper's reason", function()
    local NS, p = openPanel()
    local W = NS.Window
    for _, r in ipairs(p.rows) do
        assertTrue(#W.TooltipOf(r.member) >= 2); assertTrue(#W.TooltipOf(r.eq) >= 2); assertTrue(#W.TooltipOf(r.pill) >= 2)
        for _, b in ipairs({ r.offer, r.trade, r.dash }) do
            if b:IsShown() then assertTrue(#W.TooltipOf(b) >= 2) end
        end
    end
    local trade = p.rows[1].trade
    assertFalse(trade:IsEnabled())
    assertEqual(W.TooltipOf(trade)[2], "That player is out of trade range.")
    assertTrue(#W.TooltipOf(p.panel.line) >= 3); assertTrue(#W.TooltipOf(p.panel.announce) >= 2)
    for _, h in pairs(p.panel.heads) do assertTrue(#W.TooltipOf(h) >= 2) end
end)

test("offer panel: Offer whispers through the shared handler; Trade hands the item over", function()
    local NS, p = openPanel()
    local calls, gives = {}, {}
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, target, id }; return "sent" end
    NS.TradeHelper.Give = function(id, target) gives[#gives + 1] = { id, target }; return true end
    NS.TradeHelper.CanGive = function() return true end
    p.rows[1].offer:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "offer,Seta-Realm,1")
    NS.Window.Refresh()
    local trade = NS.OfferPanel.Drawn().rows[1].trade
    assertTrue(trade:IsEnabled())
    trade:__fire("OnClick")
    assertEqual(table.concat(gives[1], ","), "1,Seta-Realm")
end)

test("offer panel: opening an upgrade for you reveals its Best candidates", function()
    local NS, drawn = shownMine()
    assertEqual(textOf(rowFor(drawn, 2).cells.best.text), "Hidden: an upgrade for you")
    rowFor(drawn, 2).cells.actions.offer:__fire("OnClick")
    assertEqual(textOf(rowFor(NS.WindowMine.Drawn(), 2).cells.best.text), "Seta +14 · Butterz +6")
end)

test("offer panel: the close mark closes it, and it closes itself when its drop is gone", function()
    local NS, p = openPanel()
    NS.OfferPanel.Close()
    assertFalse(NS.OfferPanel.IsShown()); assertTrue(NS.State.offerPanel == nil)
    NS.OfferPanel.Open(1)
    assertTrue(NS.OfferPanel.IsShown())
    seed(NS, {})
    NS.Window.Refresh()
    assertFalse(NS.OfferPanel.IsShown())
    assertTrue(p.panel.closeButton ~= nil)
    assertTrue(NS.OfferPanel.Open(99) == nil, "no such drop")
end)

test("offer panel: minimizing the window closes the panel and the Edit message box", function()
    local NS = openPanel()
    assertTrue(NS.OfferPanel.IsShown())
    local e = NS.DetailCard.OpenEditor(1)
    assertTrue(e:IsShown())
    NS.Window.SetMinimized(true)
    assertFalse(NS.OfferPanel.IsShown(), "no panel docked beside a title bar")
    assertTrue(NS.State.offerPanel == nil)
    assertFalse(e:IsShown(), "no editor over a title bar")
    NS.Window.SetMinimized(false)
    assertFalse(NS.OfferPanel.IsShown(), "the expand does not bring it back by itself")
end)

test("offer panel: with Edit before sending on, Offer and Announce open the box for their kind", function()
    local NS, p = openPanel()
    local calls = {}
    NS.Asks.Preview = function(kind, target) return { text = kind .. " to " .. tostring(target), length = 10 } end
    NS.Asks.Press = function(kind, target, id, opts)
        calls[#calls + 1] = { kind, tostring(target), id, opts and opts.text or "-" }
        return "sent"
    end
    NS.SchemaRuntime.Set("messages.editFirst", true)
    p.rows[1].offer:__fire("OnClick")
    local e = NS.DetailCard.Editor()
    assertTrue(e:IsShown()); assertEqual(#calls, 0)
    assertEqual(textOf(e.title), "Edit offer to Seta")
    assertEqual(e.box:GetText(), "offer to " .. p.rows[1].offer.target)
    e.send:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "offer," .. p.rows[1].offer.target .. ",1,offer to " .. p.rows[1].offer.target)
    p.panel.announce:__fire("OnClick")
    assertEqual(textOf(e.title), "Edit the announcement")
    e.box:SetText("Bracers up for grabs")
    e.box:__fire("OnTextChanged")
    e.send:__fire("OnClick")
    assertEqual(table.concat(calls[2], ","), "announce,nil,1,Bracers up for grabs")
end)

test("offer panel: Announce to group announces the drop", function()
    local NS, p = openPanel()
    local calls = {}
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, tostring(target), id }; return "sent" end
    p.panel.announce:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "announce,nil,1")
end)

-- ── the host handlers ───────────────────────────────────────────────────────────────────────

test("handlers: Post my tradeables announces every tradeable drop of yours, line by line", function()
    local NS, _, m = shownMine()
    local sent = {}
    NS.Asks.Request = function(kind, target, id, opts) sent[#sent + 1] = { kind = kind, target = target, id = id, text = opts.text }; return "sent" end
    NS.WindowMine.Drawn().pane.summary.post:__fire("OnClick")
    assertEqual(#sent, 1)
    assertEqual(sent[1].kind, "announce"); assertTrue(sent[1].target == nil)
    assertEqual(sent[1].text, "Up for trade, whisper me: " .. BRACERS .. " " .. RING .. " " .. TRINKET)
    assertEqual(sent[1].id, "post:1:1")
    assertEqual(NS.PostTradeables(), 1)
    assertEqual(sent[2].id, "post:2:1", "each post files its lines under a key of its own")
    seed(NS, {})
    assertEqual(NS.PostTradeables(), 0)
    assertTrue(m.prints[#m.prints]:find("Nothing to post") ~= nil)
end)

test("handlers: Offer, Announce and Trade say why they did nothing", function()
    local NS, _, m = shownMine()
    NS.Asks.Press = function() return "refused", "alreadyAsked" end
    NS.PressOffer(1, "Seta-Realm")
    assertTrue(m.prints[#m.prints]:find("You already offered it to Seta%-Realm") ~= nil)
    NS.PressAnnounce(1)
    assertTrue(m.prints[#m.prints]:find("You already announced it") ~= nil)
    assertEqual(select(2, NS.PressOffer(99, "Seta-Realm")), "noDrop")
    NS.TradeHelper.Give = function() return false, "combat" end
    NS.GiveDrop(1, "Seta-Realm")
    assertTrue(m.prints[#m.prints]:find("You cannot trade in combat") ~= nil)
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(select(2, NS.PressAnnounce(1)), "disabled")
    assertEqual(NS.PostTradeables(), 0)
end)
