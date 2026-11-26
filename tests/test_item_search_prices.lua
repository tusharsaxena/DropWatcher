-- tests/test_item_search_prices.lua — Item Search round 3's Sold by and ForeverDB_Full work (spec
-- §4.4, §4.6, items 8 and 10): the merchant window's prices recorded (modules/ItemSearchPrices.lua)
-- and preferred over ForeverDB's, "Horde only" / "Alliance only", "No known spawn", and when
-- ForeverDB_Full loads (modules/ItemSearch.lua's policy, the `itemSearch.fullDB` setting). Every
-- ForeverDB value is the kit fake's invented data (tests/_kit/mock_foreverdb.lua) or invented below.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is inert" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's inert case; the Forever cases cover WoW Forever" or nil

local GUID = "Creature-0-1234-0-12-%d-0000ABCDEF"

-- The addon enabled with the ForeverDB fake (opts.full: the ForeverDB_Full fake's preset) and a
-- merchant window that sells `opts.slots` (`{ item, price, quantity, extended }`).
local function enabled(opts)
    opts = opts or {}
    local fake, tdp
    local NS, _, m = T.enableAddon{ mock = function(mm)
        fake = FDB.install(mm, { preset = opts.preset or "present", full = opts.full })
        tdp = TDP.install(mm)
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        mm.issecretvalue = function(v) return T.isSecret(v) end
        mm.merchantNpc = IDS.vendor
        mm.merchantSlots = opts.slots or { { item = IDS.blade, price = 900, quantity = 1 } }
        mm.UnitGUID = function(unit)
            if unit == "npc" and mm.merchantNpc then return GUID:format(mm.merchantNpc) end
            return nil
        end
        mm.GetMerchantNumItems = function() return #mm.merchantSlots end
        mm.GetMerchantItemID = function(i) return mm.merchantSlots[i] and mm.merchantSlots[i].item end
        mm.C_MerchantFrame = { GetItemInfo = function(i)
            local s = mm.merchantSlots[i]
            return s and { price = s.price, stackCount = s.quantity, hasExtendedCost = s.extended == true } or nil
        end }
        if opts.setup then opts.setup(mm) end
    end }
    if opts.load ~= false then
        m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        m.advance(5)
    end
    return NS, m, fake, tdp
end

local function prices(NS) return NS.addon.db.global.itemSearch and NS.addon.db.global.itemSearch.prices end

-- ── the client reads ────────────────────────────────────────────────────────────────────────

test("item search prices: the merchant's npc id is the creature id in UnitGUID(\"npc\"); anything else is none", function()
    local NS, m = enabled({ load = false })
    local Compat = NS.Compat
    assertEqual(Compat.MerchantNpcID(), IDS.vendor)
    m.UnitGUID = function() return "Player-1234-0ABCDEF0" end
    assertNil(Compat.MerchantNpcID(), "a player")
    m.UnitGUID = function() return "GameObject-0-1234-0-12-990301-0000ABCDEF" end
    assertNil(Compat.MerchantNpcID(), "an object")
    m.UnitGUID = function() return T.secret(GUID:format(IDS.vendor)) end
    assertNil(Compat.MerchantNpcID(), "a secret GUID")
    m.UnitGUID = function() error("boom") end
    assertNil(Compat.MerchantNpcID(), "an error")
end, FOREVER_ONLY)

test("item search prices: the merchant's slots, a token slot left out, the legacy API as the second rung", function()
    local NS, m = enabled({ load = false, slots = {
        { item = 101, price = 250, quantity = 5 }, { item = 102, price = 0, quantity = 1, extended = true },
        { item = 103, price = 40, quantity = 1, extended = true }, { item = 104, price = 10 } } })
    local got = {}
    for i, s in ipairs(NS.Compat.MerchantItems()) do got[i] = ("%d=%d/%d"):format(s.item, s.price, s.quantity) end
    -- red under: a token vendor's slot (an extended cost, no copper) recorded at 0
    assertEqual(table.concat(got, ","), "101=250/5,103=40/1,104=10/1")
    m.C_MerchantFrame = nil
    m.GetMerchantItemInfo = function(i) local s = m.merchantSlots[i]; return "x", 1, s.price, s.quantity, -1, true, true, s.extended end
    got = {}
    for i, s in ipairs(NS.Compat.MerchantItems()) do got[i] = s.item end
    assertEqual(table.concat(got, ","), "101,103,104", "GetMerchantItemInfo's answers")
    m.GetMerchantNumItems = nil
    assertEqual(#NS.Compat.MerchantItems(), 0, "no API")
end, FOREVER_ONLY)

-- ── recording ───────────────────────────────────────────────────────────────────────────────

test("item search prices: MERCHANT_SHOW records each slot's price, quantity and time, account-wide", function()
    local NS, m = enabled({ slots = { { item = IDS.blade, price = 900, quantity = 1 }, { item = 101, price = 250, quantity = 5 } } })
    m.fireEvent("MERCHANT_SHOW")
    local p = prices(NS)
    -- red under: no recorder, or a per-character store
    assertEqual(p[IDS.vendor][IDS.blade].p, 900); assertEqual(p[IDS.vendor][101].q, 5)
    assertEqual(p[IDS.vendor][IDS.blade].t, m.time())
    -- the next read prefers it (the cache was emptied by the visit)
    local f = NS.ItemSearch.Get(IDS.blade)
    assertEqual(f.vendors[1].price .. "/" .. f.vendors[1].priceOrigin, "900/seen", "seen beats vendx's 1400")
    assertEqual(f.vendors[2].priceOrigin, "vp", "the trainer, never visited: ForeverDB's")
end, FOREVER_ONLY)

test("item search prices: MERCHANT_UPDATE is debounced while open; a nil GUID, the setting off or a close records nothing", function()
    local NS, m = enabled()
    m.merchantNpc = nil
    m.fireEvent("MERCHANT_SHOW")
    assertTrue(prices(NS) == nil or next(prices(NS)) == nil, "no npc id: the visit is skipped")
    m.merchantNpc = IDS.vendor
    m.fireEvent("MERCHANT_UPDATE"); m.fireEvent("MERCHANT_UPDATE")
    assertTrue(prices(NS) == nil or prices(NS)[IDS.vendor] == nil, "not before the debounce")
    m.advance(0.5)
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 900, "one read after the last update")
    m.merchantSlots[1].price = 950
    m.fireEvent("MERCHANT_CLOSED")
    m.fireEvent("MERCHANT_UPDATE"); m.advance(1)
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 900, "closed: nothing read")
    NS.SchemaRuntime.Set("itemSearch.recordPrices", false)
    m.fireEvent("MERCHANT_SHOW")
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 900, "Record vendor prices off")
    NS.SchemaRuntime.Set("itemSearch.recordPrices", true)
    m.fireEvent("MERCHANT_SHOW")
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 950, "a later visit overwrites")
end, FOREVER_ONLY)

test("item search prices: a merchant opened in combat records at combat's end, if still open", function()
    local NS, m = enabled()
    m.InCombatLockdown = function() return true end
    m.fireEvent("MERCHANT_SHOW")
    -- red under: a visit (a count of every entry, a sort past the cap) run mid-fight
    assertTrue(prices(NS) == nil or prices(NS)[IDS.vendor] == nil, "in combat: nothing recorded")
    m.fireEvent("MERCHANT_UPDATE"); m.advance(0.5)
    assertTrue(prices(NS) == nil or prices(NS)[IDS.vendor] == nil, "the debounced update in combat: nothing")
    m.InCombatLockdown = function() return false end
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 900, "combat over, still open: recorded")
    m.merchantSlots[1].price = 950
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 900, "nothing waited: a later combat end reads nothing")
    m.InCombatLockdown = function() return true end
    m.fireEvent("MERCHANT_SHOW")
    m.fireEvent("MERCHANT_CLOSED")
    m.InCombatLockdown = function() return false end
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(prices(NS)[IDS.vendor][IDS.blade].p, 900, "closed before combat ended: nothing read")
end, FOREVER_ONLY)

test("item search prices: on Retail a merchant records nothing", function()
    local NS, m = enabled()
    m.fireEvent("MERCHANT_SHOW")
    assertNil(NS.addon.db.global.itemSearch)
    assertEqual(NS.ItemSearchPrices.Visit(), 0)
end, RETAIL_ONLY)

test("item search prices: past the cap the oldest tenth goes, and an emptied vendor with it", function()
    local P = T.newAddon().ItemSearchPrices
    local store = {}
    for npc = 1, 4 do
        store[npc] = {}
        for item = 1, 5 do store[npc][item] = { p = 1, q = 1, t = npc * 10 + item } end
    end
    assertEqual(P.Count(store), 20)
    assertEqual(P.Prune(store, 20), 0, "at the cap: nothing")
    -- red under: no prune (the saved variables grow without end), or the newest pruned
    assertEqual(P.Prune(store, 19), 2, "a tenth of 20")
    assertNil(store[1][1]); assertNil(store[1][2]); assertTrue(store[1][3] ~= nil)
    store[9] = { [1] = { p = 1, t = 0 } }
    P.Prune(store, 10)
    assertNil(store[9], "a vendor left with no entry goes")
    assertEqual(P.Record(store, 7, { { item = 3, price = 5, quantity = 2 } }, 100), 1)
    assertEqual(P.Record(store, 7, { { item = 3, price = 5, quantity = 2 } }, 200), 0, "the same price: nothing new")
    assertEqual(store[7][3].t, 200, "but the time moves")
end)

-- ── what the rows show ──────────────────────────────────────────────────────────────────────

test("item search prices: a row's price: seen, else vendx, else vp, else the dash, each with its note", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { vendors = {
        { id = 1, name = "Seen", price = 500, priceOrigin = "seen", seen = { p = 500, q = 5, t = 100 } },
        { id = 2, name = "Vendx", price = 300, priceOrigin = "vendx" },
        { id = 3, name = "None" },
    } }
    local rows = C.Vendors(facts, {}, { coin = function(c) return c .. "c" end, dateText = function(t) return "day" .. t end })
    local by = {}
    for _, r in ipairs(rows) do by[r.cells.vendor.text] = r end
    -- the stack's price shown; the ranking compares one item's (500 / 5 = 100 before 300)
    assertEqual(by.Seen.cells.price.text, "500c"); assertEqual(by.Seen.sort.price, 100)
    assertEqual(rows[1].cells.vendor.text, "Seen", "per unit, the cheaper first")
    local function hasHint(r, want)
        for _, h in ipairs(r.tip.hints) do if h == want then return true end end
        return false
    end
    assertTrue(hasHint(by.Seen, "Seen here day100, for 5"))
    assertTrue(hasHint(by.Vendx, "Recorded by ForeverDB"))
    assertTrue(hasHint(by.None, "No price recorded yet: open this vendor and Drop Watcher remembers it"))
    assertEqual(by.None.cells.price.text, "–")
    assertEqual(NS.ItemSearch.UnitPrice({ price = 500, seen = { p = 500, q = 5 } }), 100)
    assertNil(NS.ItemSearch.UnitPrice({}))
end)

test("item search prices: the tooltip's vendor rows carry each one's price, and the other side's in red", function()
    local NS = T.newAddon()
    local IST = NS.ItemSearchTip
    local facts = { drops = {}, gathered = {}, quests = {}, crafting = {}, skinnedFrom = {}, rewardFrom = {},
        vendors = { { id = 1, name = "Invented Smith", faction = "A", price = 100 },
            { id = 2, name = "Invented Grocer", faction = "AH", price = 40 }, { id = 3, name = "Invented Peddler" } } }
    local o = { order = IST.ORDER, sections = IST.SECTIONS, rows = 5, header = false }
    local out = IST.Lines(facts, o, nil, { faction = "H" })
    local by = {}
    for _, l in ipairs(out) do by[l.text] = l end
    -- red under: "can't buy" (round 3 item 8: the side that can is named), or one cheapest price alone
    assertEqual(by["  Invented Smith"].right, "Alliance only"); assertEqual(by["  Invented Smith"].rightTone, "red")
    assertNil(by["  Invented Peddler"].right, "no price: nothing at the right")
    assertEqual(NS.ItemSearchCells.SideOnly({ faction = "H" }, { faction = "A" }), "Horde only")
    assertNil(NS.ItemSearchCells.SideOnly({ faction = "AH" }, { faction = "A" }))
end)

test("item search prices: a source with no spot anywhere says No known spawn on its row tooltip", function()
    local NS = T.newAddon()
    local rows = NS.ItemSearchCells.Drops({ drops = {
        { kind = "npc", id = 1, name = "Invented Wanderer", named = true, chance = 0.1 } } }, {}, {})
    local zone
    for _, r in ipairs(rows[1].tip.rows) do if r[1] == "Zone" then zone = r[2] end end
    -- red under: a bare dash (the owner's item 10)
    assertEqual(zone, "No known spawn")
    assertEqual(rows[1].cells.zone.text, "–", "the cell keeps its dash")
end)

-- ── ForeverDB_Full ──────────────────────────────────────────────────────────────────────────

test("item search prices: the window's first open loads ForeverDB_Full once, empties the caches and the footer says Full", function()
    local NS, _, fake = enabled({ full = "present" })
    local IS = NS.ItemSearch
    local forgot, statics = 0, 0
    local forget, static = IS.ForgetSpots, IS.Static
    IS.ForgetSpots = function() forgot = forgot + 1; return forget() end
    IS.Static = function(...) statics = statics + 1; return static(...) end
    IS.Get(IDS.blade)
    assertEqual(statics, 1)
    -- red under: Full loaded at login, or from the tooltip (its perf ceilings)
    assertEqual(fake.fullLoads, 0, "nothing loads Full before the window opens")
    NS.ItemSearchWindow.Open()
    assertEqual(fake.fullLoads, 1, "the window's first open")
    assertTrue(forgot >= 1, "the spot memo emptied")
    IS.Get(IDS.blade)
    assertTrue(statics >= 2, "the static facts read again")
    -- the vendor has no spm row: Full's spz gives it one
    local spots = NS.ForeverDB.Spots("npc", IDS.vendor)
    assertTrue(spots ~= nil and spots[IDS.mapA] ~= nil, "Full's spot")
    NS.ItemSearchWindow.Close(); NS.ItemSearchWindow.Open()
    assertEqual(fake.fullLoads, 1, "once a session")
    assertTrue(NS.ItemSearchView.FooterText("loaded", "1.2", true):find("· Full", 1, true) ~= nil)
    assertEqual(NS.ItemSearchView.FooterText("loaded", "1.2", false), "ForeverDB 1.2 · loaded")
    assertTrue(IS.FullState().ok)
    IS.ForgetSpots, IS.Static = forget, static
end, FOREVER_ONLY)

test("item search prices: in combat the load waits for combat's end; Never and a missing Full load nothing", function()
    local NS, m, fake = enabled({ full = "present" })
    m.InCombatLockdown = function() return true end
    NS.ItemSearchWindow.Open()
    assertEqual(fake.fullLoads, 0, "not in combat")
    assertTrue(NS.ItemSearch.FullState().waitingForCombat)
    m.InCombatLockdown = function() return false end
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(fake.fullLoads, 1, "combat over: it loads")

    local NS2, _, fake2 = enabled({ full = "present" })
    NS2.SchemaRuntime.Set("itemSearch.fullDB", "never")
    NS2.ItemSearchWindow.Open()
    -- red under: no setting (the owner's "make it a setting")
    assertEqual(fake2.fullLoads, 0, "Never")

    local NS3 = enabled({ full = "missing" })
    NS3.ItemSearchWindow.Open()
    assertFalse(NS3.ItemSearch.FullState().ok)
    assertTrue(NS3.SchemaRuntime.FindRow("itemSearch.fullDB").disabledIf(), "the row is disabled without Full")
end, FOREVER_ONLY)

test("item search prices: before ForeverDB loads the window's open waits, and Full follows the base's load", function()
    local NS, m, fake = enabled({ full = "present", load = false })
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    NS.ItemSearchWindow.Open()
    -- red under: LoadFull called before the base (it would load the base itself, out of turn)
    assertEqual(fake.loads, 0); assertEqual(fake.fullLoads, 0)
    m.advance(5)
    assertEqual(fake.loads, 1)
    m.advance(0.1)
    assertEqual(fake.fullLoads, 1, "the frame after the base's load")
end, FOREVER_ONLY)

test("item search prices: the diagnostics name ForeverDB_Full's state and its cost", function()
    local NS = enabled({ full = "present" })
    NS.ItemSearchWindow.Open()
    local lines = {}
    local out = { add = function(_, _, fmt, ...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args))
    end, joined = function() end, list = function() end, nonDefaults = function() end }
    for _, s in ipairs(NS.Diagnostics.Sections()) do if s[1] == "integrations" then s[2](out) end end
    local line
    for _, l in ipairs(lines) do if l:find("itemSearch:", 1, true) then line = l end end
    assertTrue(line ~= nil, "an Item Search line")
    assertTrue(line:find("full=loaded", 1, true) ~= nil, line)
    assertTrue(line:find("fullDB=window", 1, true) ~= nil, line)
end, FOREVER_ONLY)
