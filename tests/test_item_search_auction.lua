-- tests/test_item_search_auction.lua — a Sell verdict's Auction or Vendor answer (R5-DW-13..16;
-- modules/ItemSearchAuction.lua, the Auctionator seam in core/CompatSearch.lua, and its reach into
-- modules/ItemSearchVerdict.lua, the tooltip badge and the verdict panel). Every price below is
-- invented; Auctionator is a double of its public API v1 (Source/API/v1/GetAuctionPrice.lua's two
-- reads), never its code.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the verdict rides the Item Search tooltip block" or nil

-- A rule as IAU.Rule answers it, every field given.
local function rule(t)
    local out = { on = true, duration = T.forever and 8 or 12, cut = 5, margin = 10 }
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

-- The client's facts for a white item a vendor buys for 100 copper a unit, unbound, not stacking.
local function item(t)
    local out = { quality = 1, sellPrice = 100, bindType = 0, stackCount = 1, inDB = true }
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

-- An Auctionator double: its public API v1's two price reads, answering `byLink[link]` and
-- `byID[id]`, recording the caller id; `boom` makes both raise.
local function auctionator(byLink, byID, opts)
    opts = opts or {}
    local seen = {}
    local api = {
        GetAuctionPriceByItemLink = function(caller, link)
            seen[#seen + 1] = caller
            if opts.boom then error("Auctionator boom") end
            return byLink and byLink[link] or nil
        end,
        GetAuctionPriceByItemID = function(caller, id)
            seen[#seen + 1] = caller
            if opts.boom then error("Auctionator boom") end
            return byID and byID[id] or nil
        end,
    }
    return { API = { v1 = api } }, seen
end

-- ── the rule (pure) ─────────────────────────────────────────────────────────────────────────

test("auction: the deposit is the vendor price's share by the auction's length, at least 1 silver a full stack", function()
    local NS = T.newAddon()
    local IAU, A = NS.ItemSearchAuction, NS.Constants.ITEM_SEARCH.AUCTION
    if T.forever then
        -- WoW Forever's 2, 8 and 24 hours (Auctionator's own Forever durations), 5%, 20%, 60%
        assertEqual(table.concat(A.DURATIONS, ","), "2,8,24"); assertEqual(A.DURATION, 8)
        assertEqual(IAU.Deposit(10000, 2, 1), 500); assertEqual(IAU.Deposit(10000, 8, 1), 2000)
        assertEqual(IAU.Deposit(10000, 24, 1), 6000)
    else
        -- Retail has no 8 hours: 12, 24 and 48 at 15%, 30%, 60%, default 12
        assertEqual(table.concat(A.DURATIONS, ","), "12,24,48"); assertEqual(A.DURATION, 12)
        assertEqual(IAU.Deposit(10000, 12, 1), 1500); assertEqual(IAU.Deposit(10000, 48, 1), 6000)
    end
    -- red under: a cheap item's deposit as its share alone (the house asks at least 1 silver)
    assertEqual(IAU.Deposit(10, A.DURATION, 1), 100, "the least deposit")
    assertEqual(IAU.Deposit(10, A.DURATION, 20), 5, "a stack of 20 shares the least deposit")
    assertEqual(IAU.Deposit(10000, 999, 1), IAU.Deposit(10000, A.DURATION, 1), "an unknown length reads the default")
end)

test("auction: Auction when the net beats the vendor by over the margin; else Vendor; bound, off or no price is Vendor", function()
    local NS = T.newAddon()
    local IAU = NS.ItemSearchAuction
    local r = rule({ duration = T.forever and 2 or 12, margin = 10 })
    local deposit = IAU.Deposit(100, r.duration, 1)   -- Forever 2 h: 100 (the least); Retail 12 h: 100
    -- the bar: net > 110. price x 0.95 - deposit > 110 -> price > (110 + deposit) / 0.95
    local bar = (110 + deposit) / 0.95
    local via, net, price = IAU.Via(item({ auctionPrice = math.ceil(bar) + 1 }), r)
    assertEqual(via, "auction"); assertEqual(price, math.ceil(bar) + 1)
    assertTrue(math.abs(net - (price * 0.95 - deposit)) < 1e-9, "the net is the price less the cut and the deposit")
    -- red under: the cut or the deposit left out (a price over 110 alone wins)
    assertEqual((IAU.Via(item({ auctionPrice = 150 }), r)), "vendor", "150 less 5% less the deposit is under 110")
    assertEqual((IAU.Via(item({ auctionPrice = math.floor(bar) }), r)), "vendor", "at the bar: not over it")
    -- red under: X% ignored (the margin) — at 0% the same price auctions
    assertEqual((IAU.Via(item({ auctionPrice = math.floor(bar) }), rule({ duration = r.duration, margin = 0 }))), "auction")
    -- the cut is a setting: a 50% cut sinks the same price
    assertEqual((IAU.Via(item({ auctionPrice = math.ceil(bar) + 1 }), rule({ duration = r.duration, cut = 50 }))), "vendor")
    -- bound (on pickup, a quest item, the account's), switched off, or no price: Vendor, and no comparison
    for _, bind in ipairs({ 1, 4, 7, 8, 9 }) do
        local v, n, p = IAU.Via(item({ auctionPrice = 99999, bindType = bind }), r)
        assertEqual(v, "vendor", "bind type " .. bind); assertNil(n); assertNil(p)
    end
    assertEqual((IAU.Via(item({ auctionPrice = 99999, bindType = 2 }), r)), "auction", "bind on equip auctions")
    assertEqual((IAU.Via(item({ auctionPrice = 99999 }), rule({ on = false }))), "vendor", "switched off")
    assertEqual((IAU.Via(item({ auctionPrice = 99999 }), nil)), "vendor", "no rule")
    local v, n = IAU.Via(item({}), r)
    assertEqual(v, "vendor"); assertNil(n, "no price: no comparison")
end)

test("auction: the rule reads the settings, bounded; the words and the reason line", function()
    local NS = T.enableAddon()
    local IAU, A = NS.ItemSearchAuction, NS.Constants.ITEM_SEARCH.AUCTION
    local r = IAU.Rule()
    if T.forever then
        assertTrue(r.on); assertEqual(r.duration, 8); assertEqual(r.cut, 5); assertEqual(r.margin, 10)
        local s = NS.addon.db.profile.itemSearch.auction
        s.duration, s.cut, s.margin, s.enabled = 7, 99, -1, false
        r = IAU.Rule()
        assertFalse(r.on); assertEqual(r.duration, A.DURATION, "a length the client has not")
        assertEqual(r.cut, A.CUT, "a cut past CUT_MAX"); assertEqual(r.margin, A.MARGIN, "a negative margin")
    else
        -- Retail: no Item Search row, no default (clients-§4); the rule falls back on the constants
        assertTrue(r.on); assertEqual(r.duration, 12); assertEqual(r.cut, A.CUT); assertEqual(r.margin, A.MARGIN)
    end
    assertEqual(IAU.Look({ verdict = "sell", sellVia = "auction" }), "auction")
    assertEqual(IAU.Look({ verdict = "sell" }), "vendor", "a Sell with no answer is Vendor")
    assertEqual(IAU.Look({ verdict = "keep" }), "keep")
    assertEqual(IAU.Word("auction"), "Auction"); assertEqual(IAU.Word("vendor"), "Vendor")
    local coins = NS.Compat.CoinText
    assertEqual(IAU.Reason("auction", 80, 120.4), ("Auction ~%s after the cut and deposit, vendor %s"):format(coins(120), coins(80)))
    assertEqual(IAU.Reason("vendor", 80, 60), ("Vendor %s, auction ~%s after the cut and deposit"):format(coins(80), coins(60)))
    assertEqual(IAU.Reason("vendor", 80, -30), ("Vendor %s, auction ~%s after the cut and deposit"):format(coins(80), coins(0)),
        "a loss reads as nothing")
    assertEqual(IAU.Reason("vendor", 80, nil), ("Sells for %s"):format(coins(80)))
end)

-- ── the Auctionator seam ────────────────────────────────────────────────────────────────────

test("auction: the seam asks Auctionator's public API by link, then by id, as DropWatcher; nil without it or on an error", function()
    local NS, _, m = T.newAddon()
    local Compat = NS.Compat
    assertFalse(Compat.AuctionatorLoaded()); assertNil(Compat.AuctionPrice("item:1", 1), "no Auctionator")
    local seen
    m.Auctionator, seen = auctionator({ ["item:1"] = 1234 }, { [2] = 50 })
    assertTrue(Compat.AuctionatorLoaded())
    assertEqual(Compat.AuctionPrice("item:1", 1), 1234, "by link")
    assertEqual(Compat.AuctionPrice("item:2", 2), 50, "by id when the link has no price")
    assertEqual(seen[1], "DropWatcher", "the caller id")
    assertNil(Compat.AuctionPrice("item:3", 3), "no scan")
    m.Auctionator = auctionator({ ["item:1"] = 0 }, { [1] = "12" })
    assertNil(Compat.AuctionPrice("item:1", 1), "a zero or a non-number is no price")
    m.Auctionator = auctionator(nil, nil, { boom = true })
    assertNil(Compat.AuctionPrice("item:1", 1), "an error answers nil")
    m.Auctionator = { API = {} }
    assertFalse(Compat.AuctionatorLoaded(), "loaded, but its API not yet")
end)

-- ── the verdict ─────────────────────────────────────────────────────────────────────────────

local function facts() return { fdb = "loaded", quests = {}, crafting = {}, vendors = {} } end
local ME = { level = 20, ranks = {} }

test("auction: a Sell keeps its key and says Auction or Vendor, with the prices; the reason names both", function()
    local NS = T.newAddon()
    local IS = NS.ItemSearch
    local r = rule({ duration = T.forever and 2 or 12 })
    local v = IS.Verdict(facts(), ME, item({ auctionPrice = 1000, auctionRule = r }))
    assertEqual(v.verdict, "sell", "the key stays sell")
    -- red under: no sub-answer (every Sell reads Sell)
    assertEqual(v.sellVia, "auction"); assertEqual(v.auctionPrice, 1000)
    assertTrue(v.reasons[1]:find("^Auction ~") ~= nil, "the reason names the auction first: " .. tostring(v.reasons[1]))
    v = IS.Verdict(facts(), ME, item({ auctionPrice = 120, auctionRule = r }))
    assertEqual(v.verdict, "sell"); assertEqual(v.sellVia, "vendor")
    assertTrue(v.reasons[1]:find("^Vendor ") ~= nil, tostring(v.reasons[1]))
    v = IS.Verdict(facts(), ME, item({}))
    assertEqual(v.sellVia, "vendor", "no price"); assertNil(v.auctionNet)
    assertEqual(v.reasons[1], ("Sells for %s"):format(NS.Compat.CoinText(100)))
    v = IS.Verdict(facts(), ME, item({ sellPrice = 0 }))
    assertEqual(v.verdict, "toss"); assertNil(v.sellVia, "only a Sell says how")
    local b = IS.Breakdown(facts(), ME, item({ auctionPrice = 1000, auctionRule = r }))
    assertEqual(b.sellVia, "auction"); assertEqual(b.sellPrice, 100); assertEqual(b.auctionPrice, 1000)
    assertTrue(b.auctionNet ~= nil)
    assertEqual(b.from, "Auction: a score under 20, and an auction beats the vendor by over 10%")
    b = IS.Breakdown(facts(), ME, item({ auctionPrice = 120, auctionRule = r }))
    assertEqual(b.from, "Vendor: a score under 20, and an auction does not beat the vendor by over 10%")
    b = IS.Breakdown(facts(), ME, item({}))
    assertEqual(b.from, "Vendor: a score under 20, and a vendor buys it")
end)

-- The addon enabled with the ForeverDB fake, the tooltip double and an Auctionator double.
local function enabled(prices)
    local NS, _, m = T.enableAddon{ mock = function(mm)
        FDB.install(mm, { preset = "present" })
        TDP.install(mm)
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        if prices then mm.Auctionator = auctionator(prices) end
    end }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    return NS, m
end

local ITEM = 990777

local function cachedItem(m, bindType)
    local real = m.C_Item.GetItemInfo
    m.C_Item.GetItemInfo = function(id)
        if id == ITEM then
            return "Invented Trinket", "item:990777", 1, 5, 1, "", "", 1, "", 7, 100, 15, 0, bindType or 0
        end
        return real(id)
    end
end

test("auction: the hover reads Auctionator's price and the settings; the switch, a bind and the house closing move it", function()
    local NS, m = enabled({ ["item:990777"] = 5000 })
    cachedItem(m)
    local IVD = NS.ItemSearchVerdict
    local f = { fdb = "loaded", item = { inDB = true } }
    local v = IVD.For(ITEM, f, ME)
    assertEqual(v.verdict, "sell"); assertEqual(v.sellVia, "auction"); assertEqual(v.auctionPrice, 5000)
    -- the switch off: Vendor once the memo is bumped (the settings row's onChange bumps it)
    NS.addon.db.profile.itemSearch.auction.enabled = false
    IVD.Bump()
    v = IVD.For(ITEM, f, ME)
    assertEqual(v.sellVia, "vendor"); assertNil(v.auctionPrice, "switched off: no read")
    NS.addon.db.profile.itemSearch.auction.enabled = true
    -- a scan moved the price: kept until the house closes, then read again
    IVD.Bump(); IVD.For(ITEM, f, ME)
    m.Auctionator = auctionator({ ["item:990777"] = 110 })
    assertEqual(IVD.For(ITEM, f, ME).sellVia, "auction", "kept while the house is open")
    m.fireEvent("AUCTION_HOUSE_CLOSED")
    assertEqual(IVD.For(ITEM, f, ME).sellVia, "vendor", "read again once it shuts")
    -- bound on pickup: Vendor whatever the price
    m.Auctionator = auctionator({ ["item:990777"] = 5000 })
    cachedItem(m, 1)
    IVD.Bump()
    assertEqual(IVD.For(ITEM, f, ME).sellVia, "vendor")
end, FOREVER_ONLY)

test("auction: the badge says Auction under the trade arrows in its own tone, Vendor under the coins in amber", function()
    local NS = enabled()
    local IST, C = NS.ItemSearchTip, NS.Constants
    local auction = IST.Badge({ verdict = "sell", sellVia = "auction", score = 5, reasons = {} })
    local vendor = IST.Badge({ verdict = "sell", sellVia = "vendor", score = 5, reasons = {} })
    assertEqual(auction.text, "Auction 5"); assertEqual(vendor.text, "Vendor 5")
    assertTrue(auction.icon:find("icons\\transfer", 1, true) ~= nil, "the trade arrows: " .. tostring(auction.icon))
    assertTrue(vendor.icon:find("phosphor\\coins", 1, true) ~= nil, "the coins")
    assertEqual(vendor.tone, "warn"); assertEqual(auction.tone, "auction")
    -- red under: one badge kept per verdict and score (Auction and Vendor would share Sell's)
    assertFalse(auction == vendor)
    local function rgb(tone) local t = C.TONE[tone]; return ("%.2f,%.2f,%.2f"):format(t.r, t.g, t.b) end
    for _, other in ipairs({ "good", "yellow", "warn", "bad" }) do
        assertTrue(rgb("auction") ~= rgb(other), "Auction's tone is not " .. other .. "'s")
    end
end, FOREVER_ONLY)

test("auction: the (?) help explains Auction and Vendor from the live settings", function()
    local NS, m = enabled({})
    local IVD = NS.ItemSearchVerdict
    local text = table.concat(IVD.ScoringHelp(), "\n")
    assertTrue(text:find("Under 20: Auction or Vendor when a vendor buys it, else Toss.", 1, true) ~= nil)
    assertTrue(text:find("less the 5% cut and the 8-hour deposit (20% of the vendor price), beats the vendor by over 10%", 1, true) ~= nil,
        text)
    NS.addon.db.profile.itemSearch.auction.margin = 25
    NS.addon.db.profile.itemSearch.auction.duration = 24
    text = table.concat(IVD.ScoringHelp(), "\n")
    assertTrue(text:find("the 24-hour deposit (60% of the vendor price), beats the vendor by over 25%", 1, true) ~= nil, text)
    NS.addon.db.profile.itemSearch.auction.enabled = false
    assertTrue(table.concat(IVD.ScoringHelp(), "\n"):find("Compare with Auctionator prices is off", 1, true) ~= nil)
    NS.addon.db.profile.itemSearch.auction.enabled = true
    m.Auctionator = nil
    assertTrue(table.concat(IVD.ScoringHelp(), "\n"):find("Auctionator is not loaded", 1, true) ~= nil)
end, FOREVER_ONLY)

test("auction: the verdict panel shows the vendor's price, Auctionator's and the net, after the word's line", function()
    local NS = enabled()
    local IVP, coins = NS.ItemSearchVerdictPanel, NS.Compat.CoinText
    local base = { score = 5, verdict = "sell", from = "Invented word line", lines = {} }
    local function rows(t)
        local b = {}
        for k, v in pairs(base) do b[k] = v end
        for k, v in pairs(t) do b[k] = v end
        return IVP.Rows(b)
    end
    local r = rows({ sellVia = "auction", sellPrice = 80, auctionPrice = 200, auctionNet = 120.2, auctionOn = true })
    assertEqual(r[1].text, "Invented word line")
    -- red under: the panel showing the score's parts alone (the owner: "show both prices")
    assertEqual(r[2].text, "Vendor price"); assertEqual(r[2].right, coins(80))
    assertEqual(r[3].text, "Auction price (Auctionator)"); assertEqual(r[3].right, coins(200))
    assertEqual(r[4].text, "Auction after the cut and deposit"); assertEqual(r[4].right, coins(120))
    assertEqual(r[4].rightTone, "auction", "the net in Auction's tone when it wins")
    r = rows({ sellVia = "vendor", sellPrice = 80, auctionOn = true })
    assertEqual(#r, 3); assertEqual(r[3].text, "No auction price known (Auctionator)")
    r = rows({ sellVia = "vendor", sellPrice = 80, auctionOn = false })
    assertEqual(#r, 2, "switched off or bound: the vendor's price alone")
    assertEqual(#rows({ verdict = "keep" }), 1, "only a Sell shows prices")
end, FOREVER_ONLY)

-- ── the settings (R5-DW-16) ─────────────────────────────────────────────────────────────────

test("auction settings: four rows under Auction prices, dimmed without Auctionator, the client's lengths, a change re-judges", function()
    local NS, m = enabled()
    local byPath = {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("itemSearch")) do byPath[row.path] = row end
    local on, length = byPath["itemSearch.auction.enabled"], byPath["itemSearch.auction.duration"]
    local cut, margin = byPath["itemSearch.auction.cut"], byPath["itemSearch.auction.margin"]
    assertTrue(on and length and cut and margin, "the four rows")
    assertEqual(on.label, "Compare with Auctionator prices"); assertEqual(on.default, true)
    assertEqual(length.label, "Auction duration"); assertEqual(length.default, 8)
    local values = {}
    for i, e in ipairs(length.values) do values[i] = e.value .. "=" .. e.text end
    assertEqual(table.concat(values, ","), "2=2 hours,8=8 hours,24=24 hours", "WoW Forever's lengths")
    assertEqual(cut.label, "Auction house cut %"); assertEqual(cut.default, 5); assertEqual(cut.max, 50)
    assertEqual(margin.label, "Auction must beat vendor by %"); assertEqual(margin.default, 10)
    assertFalse(cut.validate(2.5), "a whole percent"); assertFalse(length.validate(12), "Retail's 12 hours is not WoW Forever's")
    -- red under: the rows live without Auctionator (they would change nothing)
    for _, row in ipairs({ on, length, cut, margin }) do
        assertTrue(row.disabledIf(), row.path .. " dimmed without Auctionator")
        assertTrue(row.tooltip:find("Needs the Auctionator addon", 1, true) ~= nil, row.path .. " says why")
    end
    m.Auctionator = auctionator({})
    assertFalse(on.disabledIf()); assertFalse(length.disabledIf(), "Auctionator loaded, the comparison on")
    NS.addon.db.profile.itemSearch.auction.enabled = false
    assertTrue(length.disabledIf(), "the comparison off: the length dims"); assertFalse(on.disabledIf())
    -- a change makes every kept verdict stale
    local gen = NS.ItemSearchVerdict.Generation()
    margin.onChange(25)
    assertTrue(NS.ItemSearchVerdict.Generation() > gen, "re-judged")
end, FOREVER_ONLY)
