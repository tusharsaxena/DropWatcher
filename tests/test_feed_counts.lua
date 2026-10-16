-- tests/test_feed_counts.lua — the owner's two-Yoke run (feedback-2 spec §0): the exact chat lines of
-- research/2026-10-11-feedback-2/03-chat-loot-lines.png through the real parser and the real feed.
-- Both Yokes are separate drops with the right looters; the reagent and the altar are hidden by
-- the gear-only rule (the reagent by the quality rule once gear-only is off) and counted by reason;
-- the currency and money lines never reach the feed. Every receipt the feed refuses is counted by
-- reason too, the diagnostics report both, and /dw debug logs each under the FEED tag. A group
-- header counts every drop: `2 drops · 1 shown`, its tooltip naming the hidden drop and its filter.
-- It names the party too (spec §3), class-colored: the color codes are stripped where text is read.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BUNIAN, KEGHUNT = "Player-3209-0000000A", "Player-11-0000000B"

-- An item link named as the client names it.
local function named(id, name, color)
    return ("|c%s|Hitem:%d::::::::90:::::|h[%s]|h|r"):format(color or "ffa335ee", id, name)
end

local YOKE = named(242001, "Yoke of the Charging Bear")
local VOIDWHISPER = named(242002, "Fading Voidwhisper", "ffffffff")
local ALTAR = named(242003, "Amani Ritual Altar")
local RING = named(100, "Band")
local function worn(id) return named(id, "Worn " .. id) end

local function def(equipLoc, ilvl, extra)
    local d = { name = "Item", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = 4, subClassID = 0,
        bindType = 1, stats = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- What a member wears, readable on the fast path (neck, both rings and both trinkets held).
local function wears(m, unit, base, ilvl)
    local slots = { [2] = "INVTYPE_NECK", [11] = "INVTYPE_FINGER", [12] = "INVTYPE_FINGER",
        [13] = "INVTYPE_TRINKET", [14] = "INVTYPE_TRINKET" }
    m.inventory[unit] = {}
    for slot, loc in pairs(slots) do
        local l = worn(base + slot)
        m.addItem(l, def(loc, ilvl))
        m.inventory[unit][slot] = l
    end
end

-- The owner's group in a Mythic+ dungeon: you wear two 600 rings; Bùnian (Azralon, accented,
-- cross-realm) wears 596, so the 596 Yoke is a sidegrade for him; Keghunt (Thrall) wears 630.
local function run(seed)
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "Den of Nalorakk", difficultyID = 8 }
        m.keystoneLevel = 12
        if seed then seed(m) end
    end })
    m.addItem(RING, def("INVTYPE_FINGER", 600))
    m.inventory.player[11], m.inventory.player[12] = RING, RING
    m.addItem(YOKE, def("INVTYPE_FINGER", 596))
    m.addItem(VOIDWHISPER, def("", 1, { quality = 1, classID = 7, subClassID = 0, bindType = 0 }))
    m.addItem(ALTAR, def("", 1, { classID = 15, subClassID = 0, bindType = 0 }))
    m.setGroup({
        { guid = BUNIAN, name = "Bùnian", realm = "Azralon", class = "PALADIN", classFile = "PALADIN" },
        { guid = KEGHUNT, name = "Keghunt", realm = "Thrall", class = "WARRIOR", classFile = "WARRIOR" },
    })
    NS.Roster.Refresh("test")
    wears(m, "party1", 300, 596)
    wears(m, "party2", 400, 630)
    return NS, m, NS.LootFeed
end

-- `s` without its color escapes.
local function uncolored(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function loot(m, text)
    return m.__fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

-- The owner's lines, in order (03-chat-loot-lines.png). The currency and money lines are their own
-- events, which the addon does not read; they are also put through CHAT_MSG_LOOT, where the parser
-- must not take them for loot.
local CURRENCY = {
    "You receive currency: |cffffffff|Hcurrency:3363:6|h[Community Coupons]|h|r x6.",
    "You receive currency: |cffa335ee|Hcurrency:3290:6|h[Adventurer Mistcrest]|h|r x6.",
}
local MONEY = "You loot 152 Gold, 38 Silver, 20 Copper"
local LATE_CURRENCY = "You receive currency: |cffa335ee|Hcurrency:3292:12|h[Myth Mistcrest]|h|r x12."

local function playLines(m)
    for _, line in ipairs(CURRENCY) do loot(m, line) end
    loot(m, "Bùnian-Azralon receives loot: " .. VOIDWHISPER .. "x50.")
    loot(m, "Bùnian-Azralon receives loot: " .. YOKE .. ".")
    loot(m, "Keghunt-Thrall receives loot: " .. YOKE .. ".")
    loot(m, "Keghunt-Thrall receives loot: " .. ALTAR .. ".")
    loot(m, MONEY)
    loot(m, LATE_CURRENCY)
    m.advance(0)    -- the looters' inspects, on the fast path
end

local function byLooter(LF)
    local out = {}
    for _, rec in ipairs(LF.Drops()) do out[rec.looter.guid] = rec end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The regression
-- ---------------------------------------------------------------------------------------------

test("two yokes: both Yokes are separate drops with the right looters, the accented name resolved", function()
    local NS, m, LF = run()
    playLines(m)
    assertEqual(#LF.Drops(), 2, "two Yokes, nothing else")
    local d = byLooter(LF)
    local b, k = d[BUNIAN], d[KEGHUNT]
    assertTrue(b ~= nil and k ~= nil, "one each")
    assertTrue(b.id ~= k.id)
    assertEqual(b.looter.name, "Bùnian-Azralon"); assertEqual(b.looter.classFile, "PALADIN")
    assertEqual(k.looter.name, "Keghunt-Thrall"); assertEqual(k.looter.classFile, "WARRIOR")
    assertEqual(b.link, YOKE); assertEqual(k.link, YOKE)
    assertEqual(b.me.verdict, "downgrade", "596 against your 600 ring")
    assertEqual(b.them.verdict, "sidegrade", "596 against Bùnian's 596")
    assertEqual(k.them.verdict, "downgrade", "596 against Keghunt's 630")
    assertEqual(#LF.Groups(), 1, "one group for the run")
    assertEqual(#LF.Groups()[1].drops, 2, "the group holds both")
    assertEqual(NS.LootParser.Stats().hits, 4, "four loot lines, no currency or money line")
end)

test("two yokes: the reagent and the altar are hidden by the gear-only rule and counted, not lost", function()
    local _, m, LF = run()
    playLines(m)
    local st = LF.Stats()
    assertEqual(st.hidden.notGear, 2, "Fading Voidwhisper x50 and Amani Ritual Altar")
    assertNil(st.hidden.quality)
    assertEqual(next(st.refused), nil, "nothing refused")
end)

test("two yokes: with gear-only off, the common reagent is hidden by the quality rule", function()
    local NS, m, LF = run()
    NS.addon.db.profile.feed.gearOnly = false
    playLines(m)
    local st = LF.Stats()
    assertEqual(st.hidden.quality, 1, "Fading Voidwhisper is Common")
    assertNil(st.hidden.notGear)
end)

test("two yokes: each hidden drop is logged with its reason under the FEED tag", function()
    local NS, m = run()
    local lines = {}
    local debug = NS.Debug
    NS.Debug = function(tag, fmt, ...)
        if tag == "FEED" then lines[#lines + 1] = fmt:format(...) end
        return debug(tag, fmt, ...)
    end
    playLines(m)
    NS.Debug = debug
    local hits = 0
    for _, l in ipairs(lines) do
        if l:find("hidden", 1, true) and l:find("notGear", 1, true) then hits = hits + 1 end
    end
    assertEqual(hits, 2)
end)

-- ---------------------------------------------------------------------------------------------
-- Refused receipts
-- ---------------------------------------------------------------------------------------------

test("refused: every receipt the feed turns away is counted by reason and logged under FEED", function()
    local NS, m, LF = run()
    local lines = {}
    local debug = NS.Debug
    NS.Debug = function(tag, fmt, ...)
        if tag == "FEED" then lines[#lines + 1] = fmt:format(...) end
        return debug(tag, fmt, ...)
    end
    loot(m, "You receive item: " .. YOKE .. ".")                         -- your own pushed line
    assertEqual(select(2, LF.Receive({ link = "not a link", source = "chat", looter = {} })), "notItem")
    assertEqual(select(2, LF.OnEncounterLoot(1, 1, YOKE, 1, nil, nil)), "noLooter")
    NS.Debug = debug
    local st = LF.Stats()
    assertEqual(st.refused.pushed, 1); assertEqual(st.refused.notItem, 1); assertEqual(st.refused.noLooter, 1)
    assertEqual(#LF.Drops(), 0)
    local refusedLines = 0
    for _, l in ipairs(lines) do if l:find("refused", 1, true) then refusedLines = refusedLines + 1 end end
    assertEqual(refusedLines, 3)
end)

test("refused: a C_LootHistory drop already taken is counted as seen", function()
    local NS, m, LF = run()
    local drop = { name = "Keghunt-Thrall", guid = KEGHUNT, classFile = "WARRIOR", link = YOKE }
    NS.Compat.LootHistoryDrop = function() return drop end
    LF.OnLootHistoryDrop(5, 1)
    LF.OnLootHistoryDrop(5, 1)
    m.advance(0)
    assertEqual(LF.Stats().refused.seen, 1)
    assertEqual(#LF.Drops(), 1)
end)

test("diagnostics: the drops section reports the hidden and the refused counts by reason", function()
    local NS, m = run()
    playLines(m)
    loot(m, "You receive item: " .. YOKE .. ".")
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("drops: hidden notGear=2", 1, true) ~= nil, text)
    assertTrue(text:find("drops: refused pushed=1", 1, true) ~= nil, text)
end)

-- ---------------------------------------------------------------------------------------------
-- The group header counts every drop
-- ---------------------------------------------------------------------------------------------

test("header: View Interesting hides Bùnian's Yoke and the header reads `2 drops · 1 shown`", function()
    local NS, m, LF = run()
    playLines(m)
    local FB, WC = NS.WindowFilterBar, NS.WindowCells
    FB.State("group").view = { interesting = true }
    local ctx = NS.Window.TabContext("group")
    local entries = WC.Entries(LF.Groups(ctx.feed), LF.Get, ctx, {})
    local h = entries[1]
    assertEqual(h.kind, "header")
    assertEqual(h.count, 1); assertEqual(h.total, 2)
    assertEqual(#h.hidden, 1); assertEqual(h.hidden[1].drop.looter.guid, BUNIAN)
    assertEqual(h.hidden[1].why, "interesting")
    local hd = WC.Header(h.group, h.count, nil, nil, false, h.hidden, ctx.filter)
    assertEqual(uncolored(hd.text), "Den of Nalorakk · Mythic+ 12 · 2 drops · 1 shown · Testchar")
    local tip = T.tipJoined(hd.tip, "\n")
    assertTrue(tip:find("Yoke of the Charging Bear (Bùnian): View: Interesting", 1, true) ~= nil, tip)
    FB.State("group").view = {}
    local all = WC.Entries(LF.Groups(ctx.feed), LF.Get, NS.Window.TabContext("group"), {})
    assertEqual(all[1].count, 2); assertEqual(#all[1].hidden, 0)
    assertEqual(uncolored(WC.Header(all[1].group, 2, nil, nil, false, all[1].hidden).text),
        "Den of Nalorakk · Mythic+ 12 · 2 drops · Testchar")
end)

test("header: your own drop is listed in Drops with the others, never counted as hidden", function()
    local NS, m, LF = run()
    loot(m, "You receive loot: " .. YOKE .. ".")
    loot(m, "Keghunt-Thrall receives loot: " .. YOKE .. ".")
    m.advance(0)
    NS.WindowFilterBar.State("group").view = "all"
    local ctx = NS.Window.TabContext("group")
    local h = NS.WindowCells.Entries(LF.Groups(ctx.feed), LF.Get, ctx, {})[1]
    assertEqual(h.count, 2); assertEqual(h.total, 2); assertFalse(#h.hidden > 0)
    assertEqual(h.yours, nil, "no `yours` count (feedback-5 spec §2)")
end)

test("header: History names its hidden drops too, and a long list is cut with a count", function()
    local NS = T.newAddon()
    local WH, WC = NS.WindowHistory, NS.WindowCells
    local hidden = {}
    for i = 1, WC.HIDDEN_TIP_LINES + 2 do
        hidden[i] = { drop = { link = YOKE, looter = { name = "Keghunt-Thrall" } }, why = "search" }
    end
    local g = { label = "Den of Nalorakk", kind = "run", at = 0 }
    local h = WH.Header(g, 1, nil, nil, false, hidden, { search = "x" })
    assertEqual(h.text, "Den of Nalorakk · 11 drops · 1 shown")
    assertEqual(h.tip[4], "Hidden by the filters:", "after the rows and the kind")
    assertEqual(h.tip[5], "Yoke of the Charging Bear (Keghunt): Search")
    assertEqual(h.tip[#h.tip - 1], "and 2 more")
    assertEqual(h.tip[#h.tip], "Click to collapse this group.")
    assertEqual(WH.Header(g, 3, nil, nil, true).text, "Den of Nalorakk · 3 drops (collapsed)")
end)
