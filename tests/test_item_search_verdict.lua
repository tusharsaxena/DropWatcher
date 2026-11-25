-- tests/test_item_search_verdict.lua — the item tooltip's Keep / Hold / Sell / Toss badge (Item
-- Search round 3 spec §4.5, item 14c; modules/ItemSearchVerdict.lua, and its line in
-- modules/ItemSearchTip.lua). The score, the verdict and the confidence are pure (IS.Verdict,
-- IS.Confidence): every facts table below is invented. The tooltip cases read the kit's ForeverDB
-- fake (tests/_kit/mock_foreverdb.lua, invented data) through this addon's tooltip double.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the badge rides the Item Search tooltip block" or nil

local TAILORING, ALCHEMY = 197, 171

local function addon()
    local NS = T.newAddon()
    return NS, NS.ItemSearch
end

-- Invented facts: ForeverDB loaded, no row of any kind unless given.
local function facts(t)
    t = t or {}
    t.fdb = t.fdb or "loaded"
    t.quests, t.crafting, t.vendors = t.quests or {}, t.crafting or {}, t.vendors or {}
    return t
end

-- The client's facts, every input answered: a white item a vendor buys for 5 copper.
local function item(t)
    local out = { quality = 1, sellPrice = 5, inDB = true }
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

local ME = { level = 20, ranks = { [TAILORING] = 100 } }

local function quest(state, extra)
    local q = { id = 1, title = "Invented Errand", state = state }
    for k, v in pairs(extra or {}) do q[k] = v end
    return q
end

local function recipe(t)
    local r = { spell = 1, skillLine = TAILORING, rank = 100, known = true, yellow = 110, gray = 140 }
    for k, v in pairs(t) do r[k] = v end
    return r
end

local function scoreOf(IS, f, it, me)
    return IS.Verdict(facts(f), me or ME, item(it)).score
end

-- ── the parts ───────────────────────────────────────────────────────────────────────────────

test("verdict: quest parts: +60 in the log or ready, +35 one you can pick up, +50 a quest it starts, 80 in all", function()
    local _, IS = addon()
    assertEqual(scoreOf(IS, { quests = { quest("log") } }), 60, "in the log")
    assertEqual(scoreOf(IS, { quests = { quest("ready") } }), 60, "ready to turn in")
    assertEqual(scoreOf(IS, { quests = { quest("todo", { minLevel = 23 }) } }), 35, "your level + 3 can pick it up")
    -- red under: a quest four levels above you counted as one you can pick up
    assertEqual(scoreOf(IS, { quests = { quest("todo", { minLevel = 24 }) } }), 0, "four levels above you")
    assertEqual(scoreOf(IS, { quests = { quest("done") } }), 0, "done: nothing")
    assertEqual(scoreOf(IS, { startsQuest = { id = 9, title = "Invented Start" } }, nil,
        { level = 20, questState = function() return "todo" end }), 50, "starts a quest")
    assertEqual(scoreOf(IS, { startsQuest = { id = 9 } }, nil,
        { level = 20, questState = function() return "log" end }), 0, "the quest it starts is already in the log")
    -- red under: the quests uncapped (60 + 60 = 120, clamped to 100)
    assertEqual(scoreOf(IS, { quests = { quest("log"), quest("log", { id = 2 }) } }), 80, "capped at 80")
end)

test("verdict: crafting parts: known orange 30, yellow 20, green 8, gray 0; learnable +10; 50 in all; others +3 to 9", function()
    local _, IS = addon()
    for color, points in pairs({ orange = 30, yellow = 20, green = 8, gray = 0 }) do
        local want = color == "gray" and 0 or points
        -- a gray known recipe is also the item's one use, and it is gray: the trivial damper (-15)
        assertEqual(scoreOf(IS, { crafting = { recipe({ color = color }) } }), want, color)
    end
    assertEqual(scoreOf(IS, { crafting = { recipe({ known = false, rank = 100, gray = 140 }) } }), 10,
        "a recipe you could learn: your rank under its gray")
    assertEqual(scoreOf(IS, { crafting = { recipe({ known = false, rank = 150, gray = 140 }) } }), 0,
        "your rank past its gray: nothing to learn there")
    local rows = {}
    for i = 1, 3 do rows[i] = recipe({ spell = i, color = "orange" }) end
    assertEqual(scoreOf(IS, { crafting = rows }), 50, "three orange recipes capped at 50")
    local others = {}
    for i = 1, 4 do others[i] = recipe({ spell = i, skillLine = ALCHEMY, rank = false, known = false }) end
    assertEqual(scoreOf(IS, { crafting = { others[1] } }), 3, "one recipe of a profession you lack")
    assertEqual(scoreOf(IS, { crafting = others }), 9, "four: capped at 9")
    -- red under: the others counted before your skills are read (no profession is known missing)
    assertEqual(scoreOf(IS, { crafting = others }, nil, { level = 20 }), 0, "skills not read")
end)

test("verdict: gear: +70 an upgrade, +20 a sidegrade, nothing for an item you cannot wear", function()
    local _, IS = addon()
    assertEqual(scoreOf(IS, {}, { equippable = true, gear = "upgrade" }), 70)
    assertEqual(scoreOf(IS, {}, { equippable = true, gear = "sidegrade" }), 20)
    assertEqual(scoreOf(IS, {}, { equippable = true, gear = "downgrade" }), 0)
    assertEqual(scoreOf(IS, {}, { gear = "upgrade" }), 0, "not equippable")
end)

test("verdict: dampers: -20 easy to buy again (3 vendors, or 500 copper a unit), -15 every use gray or done", function()
    local _, IS = addon()
    local log = { quest("log") }
    assertEqual(scoreOf(IS, { quests = log, vendors = { {}, {}, {} } }), 40, "three vendors")
    assertEqual(scoreOf(IS, { quests = log, vendors = { { price = 500 } } }), 40, "500 copper")
    assertEqual(scoreOf(IS, { quests = log, vendors = { { price = 501 } } }), 60, "501 copper")
    -- red under: the stack's price compared, not one unit's (2000 for 5 is 400 each)
    assertEqual(scoreOf(IS, { quests = log, vendors = { { price = 2000, seen = { q = 5 } } } }), 40, "per unit")
    assertEqual(scoreOf(IS, { quests = { quest("done") }, crafting = { recipe({ color = "gray" }) } },
        nil, ME), 0, "every use gray or done: clamped at 0")
    local v = IS.Verdict(facts({ quests = { quest("done") }, crafting = { recipe({ color = "orange" }) } }), ME, item())
    assertEqual(v.score, 30, "an orange recipe left: no damper")
end)

test("verdict: a poor item stays at 15 unless a quest wants it; a quest item is floored at 20", function()
    local _, IS = addon()
    assertEqual(scoreOf(IS, { crafting = { recipe({ color = "orange" }) } }, { quality = 0 }), 15, "poor: capped")
    assertEqual(scoreOf(IS, { quests = { quest("log") } }, { quality = 0 }), 60, "poor, but a quest wants it")
    local v = IS.Verdict(facts(), ME, item({ classID = 12 }))
    assertEqual(v.score, 20); assertEqual(v.verdict, "hold", "a quest item holds")
    assertEqual(v.reasons[1], "Quest item")
    assertEqual(scoreOf(IS, {}, { bindType = 4 }), 20, "bind type 4")
    assertEqual(scoreOf(IS, { crafting = { recipe({ color = "orange" }) } }, { classID = 12 }), 30, "already above 20")
end)

test("verdict: the bars: 19 sells, 20 and 49 hold, 50 keeps; Sell, Toss or Hold under 20 by the sell price", function()
    local _, IS = addon()
    local function at(rows) return IS.Verdict(facts({ crafting = rows }), ME, item()) end
    local learn = function(i) return recipe({ spell = i, known = false }) end
    local other = function(i) return recipe({ spell = 10 + i, skillLine = ALCHEMY, rank = false, known = false }) end
    local v19 = at({ learn(1), other(1), other(2), other(3) })
    assertEqual(v19.score, 19); assertEqual(v19.verdict, "sell")
    local v20 = at({ recipe({ color = "yellow" }) })
    assertEqual(v20.score, 20); assertEqual(v20.verdict, "hold")
    local v49 = at({ recipe({ color = "yellow" }), learn(2), learn(3), other(1), other(2), other(3) })
    assertEqual(v49.score, 49); assertEqual(v49.verdict, "hold")
    local v50 = at({ recipe({ color = "orange" }), recipe({ spell = 2, color = "yellow" }) })
    assertEqual(v50.score, 50); assertEqual(v50.verdict, "keep")
    local f = facts()
    assertEqual(IS.Verdict(f, ME, item({ sellPrice = 7 })).verdict, "sell")
    assertEqual(IS.Verdict(f, ME, item({ sellPrice = 0 })).verdict, "toss")
    -- red under: an unknown price read as no price (a Toss for an item the client has not cached)
    assertEqual(IS.Verdict(f, ME, item({ sellPrice = false })).verdict, "hold", "the price unknown")
end)

test("verdict: a new collectible is a Keep at 100, nothing else worked out", function()
    local _, IS = addon()
    local v = IS.Verdict(facts({ vendors = { {}, {}, {} } }), ME, item({ newCollect = true, quality = 0 }))
    assertEqual(v.score, 100); assertEqual(v.verdict, "keep")
    assertEqual(#v.reasons, 1); assertEqual(v.reasons[1], "New to your collection")
end)

-- ── the confidence ──────────────────────────────────────────────────────────────────────────

test("verdict: confidence tiers: High at 80, Medium from 50 to 79, Low under 50", function()
    local _, IS = addon()
    assertEqual(IS.ConfidenceTier(80), "high"); assertEqual(IS.ConfidenceTier(79), "medium")
    assertEqual(IS.ConfidenceTier(50), "medium"); assertEqual(IS.ConfidenceTier(49), "low")
    assertEqual(IS.ConfidenceTier(100), "high"); assertEqual(IS.ConfidenceTier(0), "low")
end)

test("verdict: each confidence input is needed only when the score needs it, and counts when answered", function()
    local _, IS = addon()
    local C = IS.Confidence
    assertEqual((C(facts(), ME, item())), 100, "fdb 3, item 2, source 1: all answered")
    assertEqual((C(facts(), ME, item({ sellPrice = false }))), 67, "the item info not answered: 4 of 6")
    assertEqual((C(facts(), ME, item({ inDB = false }))), 83, "ForeverDB lacks the item: 5 of 6")
    -- ranks needed with a recipe row: 9 of 9, then 6 of 9 unread
    assertEqual((C(facts({ crafting = { recipe({}) } }), ME, item())), 100)
    assertEqual((C(facts({ crafting = { recipe({}) } }), { level = 20 }, item())), 67, "ranks unread")
    -- gear needed for an equippable item: 6 of 8 while the verdict is pending
    assertEqual((C(facts(), ME, item({ equippable = true }))), 75, "the gear verdict pending")
    assertEqual((C(facts(), ME, item({ equippable = true, gear = "downgrade" }))), 100)
    -- quests needed with a quest row; a row with no state is unanswered (6 of 9)
    assertEqual((C(facts({ quests = { quest("log") } }), ME, item())), 100)
    assertEqual((C(facts({ quests = { { id = 1 } } }), ME, item())), 67, "a quest's state unread")
    -- without ForeverDB: fdb, quests and source unanswered: item info 2 of 9
    local conf, tier = C(facts({ fdb = "loading" }), ME, item())
    assertEqual(conf, 22); assertEqual(tier, "low")
end)

test("verdict: under High the hint names the heaviest unanswered input's fix", function()
    local _, IS = addon()
    local C = IS.Confidence
    assertNil(select(3, C(facts(), ME, item())), "High: no hint")
    assertEqual(select(3, C(facts({ fdb = "loading" }), ME, item())), "ForeverDB is not loaded")
    assertEqual(select(3, C(facts({ crafting = { recipe({}) } }), { level = 20 }, item())),
        "open your profession window to rank recipes")
    assertEqual(select(3, C(facts(), ME, item({ sellPrice = false }))), "item info is still loading")
    assertEqual(select(3, C(facts(), ME, item({ equippable = true }))), "Pawn is still scoring")
    -- the ranks (3) outweigh the item info (2)
    assertEqual(select(3, C(facts({ crafting = { recipe({}) } }), { level = 20 }, item({ sellPrice = false }))),
        "open your profession window to rank recipes")
end)

test("verdict: a Low confidence never says Toss: it holds", function()
    local _, IS = addon()
    local v = IS.Verdict(facts({ fdb = "loading" }), ME, item({ sellPrice = 0 }))
    assertEqual(v.tier, "low")
    -- red under: a Toss for an item the addon could not judge
    assertEqual(v.verdict, "hold"); assertEqual(#v.reasons, 0)
    assertEqual(v.hint, "ForeverDB is not loaded")
    assertEqual(IS.Verdict(facts(), ME, item({ sellPrice = 0 })).verdict, "toss", "High: tossed")
end)

-- ── the reasons ─────────────────────────────────────────────────────────────────────────────

test("verdict: the reasons are the top two by points; Sell and Toss name the price first", function()
    local _, IS = addon()
    local v = IS.Verdict(facts({
        quests = { quest("todo"), quest("ready", { id = 2, title = "Invented Errand Two" }) },
        crafting = { recipe({ color = "orange" }) },
    }), ME, item())
    assertEqual(#v.reasons, 2)
    assertEqual(v.reasons[1], "Ready to turn in: Invented Errand Two")
    assertEqual(v.reasons[2], "Quest you can pick up: Invented Errand")
    v = IS.Verdict(facts({ crafting = { recipe({ color = "orange" }) } }), ME, item())
    assertEqual(v.reasons[1], "Tailoring skill-up (orange)")
    v = IS.Verdict(facts({ vendors = { {}, {}, {} } }), ME, item({ sellPrice = 12 }))
    assertEqual(v.verdict, "sell")
    assertEqual(v.reasons[1], "Sells for 12"); assertEqual(v.reasons[2], "Easy to buy again", "a damper by its size")
    v = IS.Verdict(facts(), ME, item({ sellPrice = 0 }))
    assertEqual(v.reasons[1], "No use found, and no vendor buys it"); assertEqual(#v.reasons, 1)
    v = IS.Verdict(facts({ crafting = { recipe({ known = false }) } }), ME, item())
    assertEqual(v.reasons[2], "Tailoring recipe you could learn")
    v = IS.Verdict(facts({ crafting = { recipe({ skillLine = ALCHEMY, rank = false, known = false }) } }), ME, item())
    assertEqual(v.reasons[2], "Other professions use it (1 recipes)")
end)

-- ── the badge and the tooltip ───────────────────────────────────────────────────────────────

local function enabled(opts)
    opts = opts or {}
    local tdp
    local NS, _, m = T.enableAddon{ mock = function(mm)
        FDB.install(mm, { preset = "present" })
        tdp = TDP.install(mm)
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        if opts.setup then opts.setup(mm) end
    end }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    return NS, m, tdp
end

local function block(tdp, tip)
    local out = tdp.texts(tip)
    table.remove(out, 1)
    return out
end

test("verdict: the badge is <icon> <Verdict> <score> · <Tier>, the icon, word and score in the verdict's tone", function()
    local NS = enabled()
    local IST, C = NS.ItemSearchTip, NS.Constants
    local function hex(tone)
        local t = C.TONE[tone]
        return ("%02x%02x%02x"):format(math.floor(t.r * 255 + 0.5), math.floor(t.g * 255 + 0.5), math.floor(t.b * 255 + 0.5))
    end
    for verdict, look in pairs({ keep = { "lock", "good", "Keep" }, hold = { "hourglass", "yellow", "Hold" },
        sell = { "coins", "warn", "Sell" }, toss = { "trash", "bad", "Toss" } }) do
        local badge = IST.Badge({ verdict = verdict, score = 42, tier = "medium", reasons = {} })
        assertTrue(badge:find("phosphor\\" .. look[1] .. ":14:14", 1, true) ~= nil, verdict .. "'s icon at 14 px")
        assertTrue(badge:find("|cff" .. hex(look[2]) .. look[3] .. " 42|r", 1, true) ~= nil, verdict .. "'s word and score")
        assertTrue(badge:find("|cff" .. hex("muted") .. "· Medium|r", 1, true) ~= nil, verdict .. "'s tier, muted")
    end
    local v = { verdict = "keep", score = 72, tier = "high", reasons = { "Invented reason" } }
    -- red under: a new string or line table built per hover
    assertTrue(IST.Badge(v) == IST.Badge(v)); assertTrue(IST.ReasonLines(v)[1] == IST.ReasonLines(v)[1])
    local lines = IST.ReasonLines(v)
    assertEqual(#lines, 1, "High: no confidence line")
    assertEqual(lines[1].text, "  |cff" .. hex("mutedGold") .. "·|r Invented reason"); assertEqual(lines[1].tone, "plain")
    lines = IST.ReasonLines({ verdict = "hold", score = 30, tier = "medium", reasons = {}, hint = "item info is still loading" })
    assertEqual(lines[1].text, "Confidence Medium: item info is still loading"); assertEqual(lines[1].tone, "muted")
end, FOREVER_ONLY)

test("verdict: on the tooltip the badge sits right of Drop Watcher, its reasons under it; both settings", function()
    local NS, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    -- the blade: no client item info (the double caches none), so Hold under a Medium confidence
    assertTrue(b[2]:find("^Drop Watcher | ") ~= nil, "the badge at the label line's right")
    assertTrue(b[2]:find("Hold 0", 1, true) ~= nil and b[2]:find("· Medium", 1, true) ~= nil, b[2])
    assertEqual(b[3], "Confidence Medium: item info is still loading", "the hint under the badge")
    assertEqual(b[4], "Drops from")
    local S = NS.addon.db.profile.itemSearch.tooltip
    S.reasons = false
    tdp.hide(tip); tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    assertTrue(b[2]:find("Hold 0", 1, true) ~= nil); assertEqual(b[3], "Drops from", "Explain the badge off")
    S.badge, S.reasons = false, true
    tdp.hide(tip); tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    -- red under: the reasons drawn with the badge off
    assertEqual(b[2], "Drop Watcher"); assertEqual(b[3], "Drops from")
    assertFalse(NS.ItemSearchTip.Options().badge)
end, FOREVER_ONLY)

test("verdict: the client's sell price and bind type reach the verdict; a cached item answers the item info", function()
    local NS, m = enabled()
    local real = m.C_Item.GetItemInfo
    m.C_Item.GetItemInfo = function(id)
        if id == IDS.blade then
            return "Fixture Blade", "item:990101", 2, 15, 10, "", "", 1, "", 7, 250, 15, 0, 0
        end
        return real(id)
    end
    local it = NS.Compat.ItemInfoByID(IDS.blade)
    assertEqual(it.sellPrice, 250); assertEqual(it.bindType, 0); assertEqual(it.equipLoc, "")
    local client, cached = NS.ItemSearchVerdict.ClientFacts(IDS.blade, NS.ItemSearch.Get(IDS.blade))
    assertTrue(cached); assertEqual(client.sellPrice, 250); assertTrue(client.inDB, "ForeverDB has the blade's row")
    assertFalse(client.equippable)
    client = NS.ItemSearchVerdict.ClientFacts(990999, { fdb = "loaded", item = { quality = 3 } })
    assertEqual(client.quality, 3, "uncached: the quality from ForeverDB's row"); assertNil(client.sellPrice)
end, FOREVER_ONLY)

test("verdict: the memo keeps one answer per item until a quest, skill, level or cache event, or its retry", function()
    local NS, m = enabled()
    local IVD, IS = NS.ItemSearchVerdict, NS.ItemSearch
    -- invented facts the case moves under the memo: a quest that wants the item, not picked up
    local q = quest("todo")
    local f = facts({ quests = { q }, item = { inDB = true } })
    local me = { level = 20 }
    local function score() return IVD.For(IDS.blade, f, me).score end
    assertEqual(score(), 35)
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP",
        "NEW_RECIPE_LEARNED" }) do
        q.state = q.state == "todo" and "log" or "todo"
        -- red under: a warm hover working the verdict out again (it would read the moved state)
        assertEqual(score(), q.state == "log" and 35 or 60, event .. ": kept before the event")
        m.__fire(event)
        assertEqual(score(), q.state == "log" and 60 or 35, event .. " makes it stale")
    end
    q.state = q.state == "todo" and "log" or "todo"
    local want = q.state == "log" and 60 or 35
    IS.Invalidate()
    assertEqual(score(), want, "Item Search's cache emptied")
    -- a verdict worked out again to the same answer is the same table: no garbage, the same badge
    local kept = IVD.For(IDS.blade, f, me)
    m.__fire("QUEST_LOG_UPDATE")
    assertTrue(IVD.For(IDS.blade, f, me) == kept, "unchanged: the same answer")
    -- the blade's item info is not cached (the double caches none): worked out again a second on
    q.state = q.state == "todo" and "log" or "todo"
    m.advance(0.5)
    assertEqual(score(), want, "half a second: kept")
    m.advance(0.6)
    assertEqual(score(), q.state == "log" and 60 or 35, "past the retry")
end, FOREVER_ONLY)
