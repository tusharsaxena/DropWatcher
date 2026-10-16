-- tests/test_compact_modes.lua — the two layouts over one engine (compact spec §5, DW-C5). Compact
-- mode never changes what is recorded, gated, judged or sent, so:
--   * THE SAME DROP SET: for the same feed and filters, the full table and the compact cards draw the
--     same drops (and the same headers) in the same order, on every tab: test mode's samples and a
--     simulated run, under every View, Content, Character, search and Sort the bar offers, with a
--     group collapsed, a card expanded and your own drops shown.
--   * THE ENGINE UNTOUCHED: switching back and forth on every tab leaves every record's verdicts and
--     trade state, the feed's counts, the history and the sends exactly as they were.
--   * EVERY STATE RENDERED: test mode puts every state on a compact card, and each card says what the
--     full row says (the verdicts, the trade word, the ask, the outcome; the trade reason in its
--     tooltip), across Drops (your own drops' countdowns and Offer among them) and History.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function textOf(region) return region and region:GetText() end

-- A text with its color escapes and a leading `· ` separator taken out.
local function plain(s)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^· ", ""))
end

local function hasAll(seen, want, what)
    for _, k in ipairs(want) do assertTrue(seen[k] == true, what .. ": " .. tostring(k)) end
end

local function sameList(a, b, what)
    assertEqual(#b, #a, what .. ": the count")
    for i = 1, math.max(#a, #b) do assertEqual(b[i], a[i], what .. ": item " .. i) end
end

local DRAWN = { group = "WindowGroup", history = "WindowHistory" }

-- A drawn row's identity: its drop id, or on History its kept entry (the same table in both
-- layouts; History's full rows carry no drop id).
local function idOf(tab, row)
    if tab == "history" then return tostring(row.entry) end
    return row.dropId
end

-- What one layout draws on `tab`, as plain lists read at once (the pools hand the frames on).
local function drawnIn(NS, mode, tab)
    NS.SetWindowMode(mode)
    NS.Window.SelectTab(tab)
    NS.Window.Refresh()
    assertEqual(NS.WindowCompact.Mode(), mode)
    local d = NS[DRAWN[tab]].Drawn()
    assertTrue((d.compact == true) == (mode == "compact"), tab .. ": the " .. mode .. " layout is drawn")
    local rows, heads = {}, {}
    for _, r in ipairs(d.rows) do rows[#rows + 1] = idOf(tab, r) end
    for _, h in ipairs(d.headers) do heads[#heads + 1] = tostring(h.groupKey) .. (h.collapsed and "-" or "+") end
    return rows, heads
end

local function assertSameSet(NS, tab, what)
    local fullRows, fullHeads = drawnIn(NS, "full", tab)
    local rows, heads = drawnIn(NS, "compact", tab)
    sameList(fullRows, rows, what .. " " .. tab .. " drops")
    sameList(fullHeads, heads, what .. " " .. tab .. " headers")
    return #fullRows
end

-- Every filter the bar offers, one at a time from the defaults (a tab ignores what it does not
-- honor, the same in both layouts).
local FILTERS = {
    { "defaults" },
    { "view", { interesting = true } },
    { "view", { likely = true } },
    { "view", { usable = true, upgrade = true } },
    { "content", "instance" },
    { "content", "session" },
    { "content", "all" },     -- History's alone: Drops refuses it (feedback-15 spec §1)
    { "char", {} },
    { "search", "vault" },
    { "search", "seta" },
    { "search", "nothing like it" },
    { "sort", "oldest" },
    { "sort", "ilvl" },
    { "sort", "gain" },
}

local function resetFilters(NS)
    NS.State.windowFilters = nil
end

-- Every tab under every filter: the same drops in both layouts. Answers how many drops each tab
-- showed under some filter, so a case knows it compared something.
local function sweep(NS, what)
    local shown = { group = 0, history = 0 }
    for _, tab in ipairs({ "group", "history" }) do
        for _, f in ipairs(FILTERS) do
            resetFilters(NS)
            if f[2] ~= nil then NS.WindowFilterBar.Set(tab, f[1], f[2]) end
            local n = assertSameSet(NS, tab, what .. " [" .. f[1] .. "]")
            shown[tab] = math.max(shown[tab], n)
        end
        resetFilters(NS)
    end
    return shown
end

local function expandAll(NS, feed)
    for _, g in ipairs(NS.LootFeed.Groups(feed)) do
        NS.State.windowGroup.collapsed[g.key] = false
    end
end

local function testWindow()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    expandAll(NS, "test")
    NS.ShowWindow()
    return NS, m
end

-- ── the same drop set ───────────────────────────────────────────────────────────────────────

test("modes: test mode's samples are the same drops in both layouts, on every tab, under every filter", function()
    local NS = testWindow()
    local shown = sweep(NS, "test mode")
    assertTrue(shown.group >= 6, "Drops compared " .. shown.group)
    assertTrue(shown.history >= 1, "History compared " .. shown.history)
end)

test("modes: a collapsed group, an expanded drop and your own drops shown are the same in both layouts", function()
    local NS = testWindow()
    local groups = NS.LootFeed.Groups("test")
    NS.WindowGroup.ToggleGroup(groups[1].key, false)
    assertSameSet(NS, "group", "collapsed")
    NS.WindowGroup.ToggleGroup(groups[1].key, true)
    assertSameSet(NS, "group", "expanded")
    assertSameSet(NS, "group", "your own drops listed")   -- always (feedback-5 spec §2)
    NS.Window.SelectTab("history")
    local hist = NS.WindowHistory.Drawn()
    NS.WindowHistory.ToggleGroup(hist.headers[1].groupKey, hist.headers[1].collapsed)
    assertSameSet(NS, "history", "toggled")
end)

-- A simulated dungeon run, as test_sim_e2e drives one: the journal seeded with rings at every
-- difficulty, the player wearing two at 600.
local function link(id, ilvl)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::%d|h[Item %d]|h|r"):format(id, ilvl or 0, id)
end

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function simRun(name)
    local NS, _, m = T.enableAddon()
    for i, id in ipairs({ 100, 101 }) do
        m.addItem(link(id, 600), ring(600))
        m.inventory.player[10 + i] = link(id, 600)
    end
    m.INVTYPE_FINGER = "Finger"
    local j = m.journal
    j.tiers = { { dungeons = { { id = 101, name = "Ashen Vault" } }, raids = { { id = 201, name = "The Spire" } } } }
    for _, inst in ipairs({ 101, 201 }) do
        j.loot[inst] = {}
        for _, d in ipairs({ 1, 2, 23, 8, 17, 14, 15, 16 }) do
            j.loot[inst][d] = {}
            for n = 1, 2 do
                local id = inst * 1000 + d * 10 + n
                m.addItem(link(id, 590 + n * 5), ring(590 + n * 5))
                j.loot[inst][d][n] = { itemID = id, link = link(id, 590 + n * 5), encounterID = 2000 + n }
            end
        end
    end
    assertTrue(NS.SimScenario.Start(name, nil, { seed = 2 }), name)
    assertTrue(NS.SimScenario.Run(), name)
    local st = NS.SimScenario.Status()
    m.advance(NS.SimScenario.STEP_DELAY * st.steps + 30)
    assertTrue(#NS.LootFeed.Drops("live") > 0, name .. ": the run dropped loot")
    NS.ShowWindow()
    return NS, m
end

test("modes: a simulated run is the same drops in both layouts, on every tab, under every filter", function()
    for _, name in ipairs({ "dungeon", "world" }) do
        local NS = simRun(name)
        local shown = sweep(NS, "sim " .. name)
        assertTrue(shown.group > 0, name .. ": Drops compared " .. shown.group)
        assertTrue(shown.history > 0, name .. ": History compared " .. shown.history)
    end
end)

-- ── the engine untouched ────────────────────────────────────────────────────────────────────

-- Everything the engine owns that a layout could disturb: each record's verdicts, trade state and
-- inspect status, the feed's counts, the history's groups and entries, and the sends.
local function snapshot(NS, m, feed)
    local out = {}
    for _, d in ipairs(NS.LootFeed.Drops(feed)) do
        out[#out + 1] = table.concat({ tostring(d.id), tostring(d.me and d.me.verdict),
            tostring(d.me and d.me.ilvlDelta), tostring(d.them and d.them.verdict),
            tostring(d.trade and d.trade.state), tostring(d.inspect and d.inspect.status) }, "/")
    end
    local st = NS.LootFeed.Stats()
    out[#out + 1] = ("stats %s %s"):format(tostring(st.group), tostring(st.mine))
    local log, entries = NS.History.Log(), 0
    for _, g in ipairs(log.groups) do entries = entries + #g.drops end
    out[#out + 1] = ("history %d %d"):format(#log.groups, entries)
    out[#out + 1] = ("sent %d"):format(#m.chatSent)
    return out
end

test("modes: switching layouts on every tab changes nothing the engine recorded, judged or sent", function()
    for _, case in ipairs({ { "test" }, { "live", "dungeon" } }) do
        local NS, m
        if case[1] == "test" then NS, m = testWindow() else NS, m = simRun(case[2]) end
        local before = snapshot(NS, m, case[1])
        for _ = 1, 3 do
            for _, tab in ipairs({ "group", "history" }) do
                drawnIn(NS, "compact", tab)
                drawnIn(NS, "full", tab)
            end
        end
        sameList(before, snapshot(NS, m, case[1]), case[1])
    end
end)

-- ── every state rendered ────────────────────────────────────────────────────────────────────

-- The full rows' pieces by drop id (or kept entry), read before the compact layout repaints.
local function fullPieces(NS, tab, read)
    NS.SetWindowMode("full")
    NS.Window.SelectTab(tab)
    NS.Window.Refresh()
    local out = {}
    for _, r in ipairs(NS[DRAWN[tab]].Drawn().rows) do out[idOf(tab, r)] = read(r.cells, r) end
    return out
end

local function compactCards(NS, tab)
    NS.SetWindowMode("compact")
    NS.Window.SelectTab(tab)
    NS.Window.Refresh()
    return NS[DRAWN[tab]].Drawn().rows
end

-- An action button's word: its label (Ask, Offer, their states, or No action: feedback-11 spec §1).
local function askWord(a)
    assertTrue(a:IsShown(), "an action button is always shown")
    return textOf(a.label)
end

test("modes: test mode's Drops cards show every state, each saying what its full row says", function()
    local NS = testWindow()
    local full = fullPieces(NS, "group", function(c)
        return { me = textOf(c.me.text), them = textOf(c.them.text), trade = textOf(c.trade.text),
            meLevel = textOf(c.me.level), themLevel = textOf(c.them.level),
            ask = askWord(c.actions.ask), tradeTip = c.trade.tipLines }
    end)
    local seen = { ask = {}, trade = {}, fresh = {}, you = {}, them = {}, eq = {} }
    local cards = compactCards(NS, "group")
    assertTrue(#cards >= 6, "the samples, as cards")
    for _, card in ipairs(cards) do
        local c, f = card.cells, full[card.dropId]
        local what = "card " .. tostring(card.dropId)
        assertTrue(f ~= nil, what .. ": a full row too")
        assertEqual(textOf(c.you.text), f.me, what .. ": You")
        assertEqual(textOf(c.them.text), f.them, what .. ": Them")
        assertEqual(textOf(c.you.level), f.meLevel, what .. ": your worn level, as the Me cell's")
        assertEqual(textOf(c.them.level), f.themLevel, what .. ": their worn level, as the Them cell's")
        assertEqual(plain(textOf(c.trade.text)), f.trade, what .. ": trade")
        assertEqual(askWord(card.ask), f.ask, what .. ": ask")
        assertEqual(c.trade.hit.tipLines[1], f.tradeTip[1], what .. ": the trade reason")
        seen.ask[f.ask] = true
        seen.trade[f.trade] = true
        seen.fresh[textOf(c.fresh.text)] = true
        seen.you[textOf(c.you.glyph)] = true
        seen.them[textOf(c.them.glyph)] = true
        seen.eq[textOf(c.them.level)] = true
    end
    hasAll(seen.ask, { "Ask", "Queued", "Asked", "Retry", "No action" }, "ask")
    hasAll(seen.trade, { "Yes", "Likely", "Unknown", "No" }, "trade")
    hasAll(seen.fresh, { "(cached)", "(range)", "(combat)", "(!)", "" }, "inspect freshness, bracketed or left out (pending: Them says it)")
    hasAll(seen.you, { "▲", "≈", "▼", "⊘" }, "your verdict")
    hasAll(seen.them, { "▲", "≈", "▼", "⊘" }, "their verdict")
    hasAll(seen.eq, { "…", "range", "combat", "!", "290", "300" }, "their worn levels")
end)

test("modes: test mode's own drops on Drops show Offer as the full rows, no countdown on the card", function()
    local NS = testWindow()
    NS.WindowFilterBar.Set("group", "view", {})
    local full = fullPieces(NS, "group", function(c, r)
        return { mine = r.drop.isMine == true, window = textOf(c.tradeWindow.text),
            windowTip = c.tradeWindow.tipLines, offer = askWord(c.actions.ask),
            isOffer = c.actions.ask.offer == true }
    end)
    local seen = { window = {}, offer = {} }
    local n = 0
    for _, card in ipairs(compactCards(NS, "group")) do
        local f = full[card.dropId]
        if f and f.mine then
            n = n + 1
            local what = "card " .. tostring(card.dropId)
            assertEqual(askWord(card.ask), f.offer, what .. ": Offer")
            assertEqual(card.ask.offer == true, f.isOffer, what .. ": your own drop's button is Offer")
            assertTrue(card.cells.countdown == nil, what .. ": no trade window on the card (feedback-10 spec §2)")
            seen.window[f.window:gsub("%d", "9")] = true
            seen.offer[f.offer] = true
        end
    end
    assertEqual(n, 5, "every sample of yours")
    hasAll(seen.window, { "9:99:99", "~9:99:99", "No limit (BoE)" }, "Trade window")
    hasAll(seen.offer, { "Offer", "No action" }, "Offer, or No action on a dead drop")
end)

test("modes: test mode's History cards show every outcome, each saying what its full row says", function()
    local NS = testWindow()
    NS.Window.SelectTab("history")
    for _, h in ipairs(NS.WindowHistory.Drawn().headers) do
        if h.collapsed then NS.WindowHistory.ToggleGroup(h.groupKey, true) end
    end
    local full = fullPieces(NS, "history", function(c)
        return { me = textOf(c.me.text), them = textOf(c.them.text), outcome = textOf(c.outcome.text),
            trade = textOf(c.trade.text) }
    end)
    local seen = {}
    local cards = compactCards(NS, "history")
    assertEqual(#cards, 9, "every kept sample, the alt's too (Character: All, feedback-13 spec §0)")
    for _, card in ipairs(cards) do
        local c, f = card.cells, full[idOf("history", card)]
        local what = "entry " .. tostring(card.dropId)
        assertEqual(textOf(c.outcome.text), f.outcome, what .. ": outcome")
        assertEqual(textOf(c.you.text), f.me, what .. ": You")
        assertEqual(textOf(c.them.text), f.them, what .. ": Them")
        assertEqual(plain(textOf(c.trade.text)), f.trade, what .. ": trade")
        seen[f.outcome] = true
    end
    hasAll(seen, { "Seen", "Asked", "Offered", "Received", "Traded away", "Expired", "Declined" }, "outcome")
end)
