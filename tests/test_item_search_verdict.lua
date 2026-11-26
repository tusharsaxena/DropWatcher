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
        "Open your profession window to rank recipes")
    assertEqual(select(3, C(facts(), ME, item({ sellPrice = false }))), "Item info is still loading")
    assertEqual(select(3, C(facts(), ME, item({ equippable = true }))), "Pawn is still scoring")
    -- the ranks (3) outweigh the item info (2)
    assertEqual(select(3, C(facts({ crafting = { recipe({}) } }), { level = 20 }, item({ sellPrice = false }))),
        "Open your profession window to rank recipes")
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

test("verdict: gear whose gear verdict has not answered never says Toss, at any confidence", function()
    local _, IS = addon()
    local v = IS.Verdict(facts(), ME, item({ sellPrice = 0, equippable = true }))
    assertEqual(v.tier, "medium", "Pawn still scoring: 6 of 8")
    -- red under: a Toss for gear the addon has not judged (the gear part could add +70)
    assertEqual(v.verdict, "hold"); assertEqual(v.hint, "Pawn is still scoring")
    v = IS.Verdict(facts(), ME, item({ sellPrice = 0, equippable = true, gear = "downgrade" }))
    assertEqual(v.verdict, "toss", "judged a downgrade, and no use: tossed")
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
    -- red under: "Sells for 12", a bare number (the owner, R5-DW-11: "Sells for 30 what?")
    assertEqual(v.reasons[1], "Sells for 12|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t")
    assertEqual(v.reasons[2], "Easy to buy again", "a damper by its size")
    v = IS.Verdict(facts(), ME, item({ sellPrice = 0 }))
    assertEqual(v.reasons[1], "No use found, and no vendor buys it"); assertEqual(#v.reasons, 1)
    v = IS.Verdict(facts({ crafting = { recipe({ known = false }) } }), ME, item())
    assertEqual(v.reasons[2], "Tailoring recipe you could learn")
    v = IS.Verdict(facts({ crafting = { recipe({ skillLine = ALCHEMY, rank = false, known = false }) } }), ME, item())
    assertEqual(v.reasons[2], "Other professions use it (1 recipes)")
end)

test("compat: money reads in gold, silver and copper coins on both clients, never a bare number (R5-DW-11)", function()
    local NS = T.newAddon()
    local Compat = NS.Compat
    local G, S, K = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
        "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    -- neither client has the bare GetCoinTextureString (BankLedger's probe P9): the coins drawn by hand
    assertEqual(Compat.CoinText(30), "30" .. K)
    assertEqual(Compat.CoinText(120), "1" .. S .. " 20" .. K)
    assertEqual(Compat.CoinText(123456), "12" .. G .. " 34" .. S .. " 56" .. K)
    assertEqual(Compat.CoinText(10000), "1" .. G, "an empty silver and copper left out")
    assertEqual(Compat.CoinText(0), "0" .. K, "nothing is no copper")
    assertNil(Compat.CoinText(nil)); assertNil(Compat.CoinText("x"))
    -- the client's own coin string first, where it has one
    local withClient = T.newAddon({ mock = function(mm)
        mm.C_CurrencyInfo = mm.C_CurrencyInfo or {}
        mm.C_CurrencyInfo.GetCoinTextureString = function(copper) return ("client %d"):format(copper) end
    end })
    assertEqual(withClient.Compat.CoinText(30), "client 30")
end)

test("verdict: the reasons always carry the largest negative part, so the shown parts explain the score", function()
    local _, IS = addon()
    -- a Peacebloom-like item (R4-DW-07, the owner's "what does 65 mean"): two orange recipes (+50 at
    -- the cap), a quest you can pick up (+35), three vendors (-20)
    local v = IS.Verdict(facts({
        quests = { quest("todo") },
        crafting = { recipe({ color = "orange" }), recipe({ spell = 2, color = "orange" }) },
        vendors = { {}, {}, {} },
    }), ME, item())
    assertEqual(v.score, 65); assertEqual(v.verdict, "keep")
    -- red under: the top two alone (the -20 hidden, the 65 left partly unexplained)
    assertEqual(#v.reasons, 3)
    assertEqual(v.reasons[1], "Tailoring skill-up (orange)")
    assertEqual(v.reasons[2], "Quest you can pick up: Invented Errand")
    assertEqual(v.reasons[3], "Easy to buy again", "the largest negative part, after the top two")
    -- already among the top two: not repeated
    v = IS.Verdict(facts({ vendors = { {}, {}, {} } }), ME, item({ sellPrice = 12 }))
    assertEqual(#v.reasons, 2); assertEqual(v.reasons[2], "Easy to buy again")
    -- no negative part: the top two alone
    v = IS.Verdict(facts({ quests = { quest("todo") }, crafting = { recipe({ color = "orange" }) } }), ME, item())
    assertEqual(#v.reasons, 2)
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

test("verdict: the badge is one pill: icon and <Verdict> <score> in dark ink on the verdict's tone; no tier (R5-DW-02)", function()
    local NS = enabled()
    local IST, C = NS.ItemSearchTip, NS.Constants
    local B = C.ITEM_SEARCH.BADGE
    local function hex(tone)
        local t = C.TONE[tone]
        return ("%02x%02x%02x"):format(math.floor(t.r * 255 + 0.5), math.floor(t.g * 255 + 0.5), math.floor(t.b * 255 + 0.5))
    end
    for verdict, look in pairs({ keep = { "lock", "good", "Keep" }, hold = { "hourglass", "yellow", "Hold" },
        sell = { "coins", "warn", "Sell" }, toss = { "trash", "bad", "Toss" } }) do
        local badge = IST.Badge({ verdict = verdict, score = 42, tier = "medium", reasons = {} })
        assertEqual(badge.tone, look[2], verdict .. "'s tone")
        assertTrue(badge.icon:find("phosphor\\" .. look[1], 1, true) ~= nil, verdict .. "'s icon")
        -- red under: the word and the score in two boxes of two shades (R4-DW-07, "shabby")
        assertEqual(badge.text, look[3] .. " 42", "the word and the score in one text")
        local t = C.TONE[look[2]]
        assertEqual(table.concat(badge.fill, ","), table.concat({ t.r, t.g, t.b }, ","), "filled in the verdict's tone")
        -- red under: white text on a mid tone (the owner: "font colors all look bad"); dark ink, as ItemTree's
        assertEqual(table.concat(badge.ink, ","), table.concat({ t.r * B.INK, t.g * B.INK, t.b * B.INK }, ","))
        assertTrue(badge.ink[1] + badge.ink[2] + badge.ink[3] < 0.5, verdict .. ": dark ink")
        assertTrue(badge.text:find("Medium", 1, true) == nil, "no tier")
        assertEqual(badge.width, B.GAP + 2 * B.PAD + B.ICON + B.ICON_GAP + math.ceil(#badge.text * B.FONT * B.EM))
    end
    local v = { verdict = "keep", score = 72, tier = "high", reasons = { "Invented reason" } }
    -- red under: a new table or line built per hover; a badge kept per tier
    assertTrue(IST.Badge(v) == IST.Badge(v)); assertTrue(IST.ReasonLines(v)[1] == IST.ReasonLines(v)[1])
    assertTrue(IST.Badge(v) == IST.Badge({ verdict = "keep", score = 72, tier = "low" }), "one badge whatever the tier")
    local lines = IST.ReasonLines(v)
    assertEqual(#lines, 1, "High: no hint line")
    assertEqual(lines[1].text, "  |cff" .. hex("mutedGold") .. "·|r Invented reason"); assertEqual(lines[1].tone, "plain")
    lines = IST.ReasonLines({ verdict = "hold", score = 30, tier = "medium", reasons = {}, hint = "Item info is still loading" })
    -- red under: "Confidence Medium: ..." (the fix stays, without the tier word)
    assertEqual(lines[1].text, "Item info is still loading"); assertEqual(lines[1].tone, "muted")
end, FOREVER_ONLY)

test("verdict: on the tooltip the pill hangs right after Drop Watcher's text, smooth, never measured, never over the label (R5-DW-01, R5-DW-02)", function()
    local NS, m, tdp = enabled({ setup = function(mm) mm.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF" end })
    local IST, C = NS.ItemSearchTip, NS.Constants
    local B = C.ITEM_SEARCH.BADGE
    local tip = tdp.tooltip("GameTooltip")
    local reads = 0
    local make = tip.CreateFontString
    tip.CreateFontString = function(self, ...)
        local fs = make(self, ...)
        fs.GetStringWidth = function() reads = reads + 1; return 0 end
        fs.GetUnboundedStringWidth = fs.GetStringWidth
        return fs
    end
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    -- the blade: no client item info (the double caches none), so Hold under a Medium confidence.
    -- red under (R5-DW-01): the label's own text padded with the badge's room, the pill hung from that
    -- padded end and sized from a width read in the post call, so the label ran under it at a scale
    local label = tip.__lines[3]
    assertEqual(label.text, "Drop Watcher", "the label alone on the left")
    local room = tonumber(label.right:match("^|T[^:]+:" .. B.HEIGHT .. ":(%d+):0:0:%d+:%d+:0:1:0:1|t$"))
    assertTrue(room ~= nil, "the badge's room is the line's right side: " .. tostring(label.right))
    assertEqual(b[3], "Item info is still loading", "the hint under the badge, no tier")
    assertEqual(b[4], "Drops from")
    for _, line in ipairs(b) do assertTrue(line:find("Medium", 1, true) == nil, "no tier anywhere: " .. line) end
    local badge = IST.BadgeOf(tip)
    assertTrue(badge ~= nil, "the tooltip's badge")
    assertEqual(room, IST.Badge(NS.ItemSearchVerdict.For(IDS.blade, NS.ItemSearch.Get(IDS.blade),
        NS.ItemSearch.Me())).width, "the room reserved is the badge's own estimate")
    assertEqual(reads, 0, "nothing measured in the post call")
    -- hung from the label line's left font string (which ends where "Drop Watcher" ends), GAP out
    local p = { badge.icon:GetPoint(1) }
    assertEqual(table.concat({ p[1], tostring(p[2] == m.GameTooltipTextLeft3), p[3], p[4], p[5] }, ","),
        ("LEFT,true,RIGHT,%d,0"):format(B.GAP + B.PAD), "the icon PAD inside the pill, the pill GAP after the label")
    p = { badge.text:GetPoint(1) }
    assertEqual(table.concat({ p[1], tostring(p[2] == badge.icon), p[3], p[4] }, ","), "LEFT,true,RIGHT," .. B.ICON_GAP)
    assertTrue(badge.text:GetText():find("Hold", 1, true) ~= nil); assertTrue(badge.text:GetText():find("0", 1, true) ~= nil)
    assertEqual(badge.text.__face and badge.text.__face[3], "", "no outline")
    assertEqual(badge.text.__shadow and table.concat(badge.text.__shadow, ","), "0,0", "no shadow")
    -- the fill: seven pieces of the rounded art, never the square white box (the owner: "rough edged")
    local y = C.TONE.yellow
    local n = 0
    for name, t in pairs(badge.piece) do
        n = n + 1
        assertEqual(t.__texture, IST.BadgeArt(), name .. ": the rounded art")
        assertTrue(t.__texture ~= IST.RULE_TEXTURE, name .. ": not WHITE8X8")
        assertTrue(t.__coords ~= nil, name .. ": cut by texture coordinates")
        assertEqual(table.concat(t.__vertex, ",", 1, 3), table.concat({ y.r, y.g, y.b }, ","), name .. ": Hold's yellow")
        assertTrue(t:IsShown(), name .. " shown")
    end
    assertEqual(n, 7, "four corners, two edges and the middle")
    assertTrue(IST.BadgeArt():find("glass-fill", 1, true) ~= nil, "LibKa0s' Ka0s Glass fill")
    assertEqual(table.concat(badge.piece.tl.__coords, ","), "0,0.25,0,0.25", "a corner is the art's corner cell")
    p = { badge.piece.tl:GetPoint(1) }
    assertEqual(table.concat({ p[1], tostring(p[2] == badge.icon), p[3], p[4], p[5] }, ","),
        ("TOPLEFT,true,LEFT,%d,%s"):format(-B.PAD, tostring(B.HEIGHT / 2)))
    p = { badge.piece.br:GetPoint(1) }
    assertEqual(table.concat({ p[1], tostring(p[2] == badge.text), p[3], p[4], p[5] }, ","),
        ("BOTTOMRIGHT,true,RIGHT,%d,%s"):format(B.PAD, tostring(-B.HEIGHT / 2)))
    -- kept through the client's refill of the same item, as the separator is (R4-DW-06)
    local hides, hide = 0, badge.text.Hide
    badge.text.Hide = function(self) hides = hides + 1; return hide(self) end
    tip:ClearLines(); tdp.hide(tip); tdp.show(tip, IDS.blade)
    assertTrue(badge.text:IsShown()); m.advance(0)
    assertTrue(badge.text:IsShown()); assertEqual(hides, 0, "never hidden on a refill of the same item")
    local S = NS.addon.db.profile.itemSearch.tooltip
    S.reasons = false
    tdp.hide(tip); tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    assertTrue(badge.text:IsShown()); assertEqual(b[3], "Drops from", "Explain the badge off")
    S.badge, S.reasons = false, true
    tdp.hide(tip); tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    -- red under: the reasons drawn with the badge off
    assertEqual(b[2], "Drop Watcher"); assertEqual(b[3], "Drops from")
    assertFalse(badge.text:IsShown() or badge.piece.c:IsShown(), "no badge")
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
    -- the score each quest state earns (in the log 60, not picked up 35), and the state moved
    local WORTH = { log = 60, todo = 35 }
    local OTHER = { log = "todo", todo = "log" }
    local function flip() q.state = OTHER[q.state] end
    local function fresh() return WORTH[q.state] end
    local function stale() return WORTH[OTHER[q.state]] end
    assertEqual(score(), 35)
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP",
        "NEW_RECIPE_LEARNED" }) do
        flip()
        -- red under: a warm hover working the verdict out again (it would read the moved state)
        assertEqual(score(), stale(), event .. ": kept before the event")
        m.__fire(event)
        assertEqual(score(), fresh(), event .. " makes it stale")
    end
    flip()
    local want = fresh()
    IS.Invalidate()
    assertEqual(score(), want, "Item Search's cache emptied")
    -- a verdict worked out again to the same answer is the same table: no garbage, the same badge
    local kept = IVD.For(IDS.blade, f, me)
    m.__fire("QUEST_LOG_UPDATE")
    assertTrue(IVD.For(IDS.blade, f, me) == kept, "unchanged: the same answer")
    -- the blade's item info is not cached (the double caches none): worked out again a second on
    flip()
    m.advance(0.5)
    assertEqual(score(), want, "half a second: kept")
    m.advance(0.6)
    assertEqual(score(), fresh(), "past the retry")
end, FOREVER_ONLY)

-- ── the breakdown (round 4 addendum A1, R4-DW-11: the Item Search window's verdict panel) ─────

-- The breakdown's lines' points, summed; and the line of `kind` whose text holds `find`, or nil.
local function sum(b)
    local n = 0
    for _, line in ipairs(b.lines) do n = n + line.points end
    return n
end

local function lineOf(b, kind, find)
    for _, line in ipairs(b.lines) do
        if line.kind == kind and (not find or line.text:find(find, 1, true)) then return line end
    end
    return nil
end

local function kinds(b)
    local out = {}
    for _, line in ipairs(b.lines) do out[#out + 1] = line.kind end
    return table.concat(out, ",")
end

test("verdict breakdown: the score's parts in the order the score adds them, adding up to the score (R4-DW-11)", function()
    local _, IS = addon()
    local f = facts({ quests = { quest("log"), quest("todo", { id = 2, title = "Invented Chore" }) },
        crafting = { recipe({ color = "orange" }), recipe({ spell = 2, color = "orange" }),
            recipe({ spell = 3, known = false }) },
        vendors = { {}, {}, {} } })
    local it = item({ equippable = true, gear = "sidegrade" })
    local b = IS.Breakdown(f, ME, it)
    local v = IS.Verdict(f, ME, it)
    -- red under: a panel score of its own that can disagree with the badge's
    assertEqual(b.score, v.score, "the badge's score"); assertEqual(b.verdict, v.verdict)
    assertEqual(sum(b), b.score, "the lines add up to the score")
    -- quests by quest (60 + 35 = 95, capped at 80), crafting by color (2 orange 60 + learn 10, capped 50),
    -- gear 20, rebuy -20: 80 + 50 + 20 - 20 = 130, clamped to 100
    assertEqual(kinds(b), "quest,quest,cap,craft,craft,cap,gear,damper,clamp")
    assertEqual(lineOf(b, "quest", "Invented Errand").points, 60)
    assertEqual(lineOf(b, "quest", "Invented Chore").points, 35)
    assertEqual(lineOf(b, "cap", "80").points, -15, "the quests' cap shown when hit")
    assertEqual(lineOf(b, "craft", "orange").points, 60, "the known recipes by color")
    assertTrue(lineOf(b, "craft", "orange").text:find("2", 1, true) ~= nil, "with their count")
    assertEqual(lineOf(b, "craft", "learn").points, 10)
    assertEqual(lineOf(b, "cap", "50").points, -20, "the crafting cap shown when hit")
    assertEqual(lineOf(b, "damper").text, "Easy to buy again")
    assertEqual(lineOf(b, "clamp").points, -30)
    assertEqual(b.from, "Keep from 50", "the line the verdict word comes from")
end)

test("verdict breakdown: a zero part is left out; the dampers, the poor cap and the quest-item floor are listed", function()
    local _, IS = addon()
    local b = IS.Breakdown(facts({ crafting = { recipe({ color = "gray" }) } }), ME, item())
    -- the gray recipe (0) left out; every use gray: -15, clamped back to 0
    assertNil(lineOf(b, "craft"), "a part worth 0 is hidden")
    assertEqual(lineOf(b, "damper").text, "Every use is gray or done"); assertEqual(lineOf(b, "damper").points, -15)
    assertEqual(lineOf(b, "clamp").points, 15); assertEqual(sum(b), 0); assertEqual(b.score, 0)
    local poor = IS.Breakdown(facts({ crafting = { recipe({ color = "orange" }) } }), ME, item({ quality = 0 }))
    assertEqual(poor.score, 15)
    assertEqual(lineOf(poor, "cap", "Poor").points, -15, "the poor-quality cap when it applies")
    assertEqual(sum(poor), 15)
    local qi = IS.Breakdown(facts(), ME, item({ classID = 12 }))
    assertEqual(qi.score, 20); assertEqual(lineOf(qi, "floor").points, 20, "the quest-item floor when it applies")
    assertEqual(sum(qi), 20); assertEqual(qi.from, "Hold from 20")
    local others = {}
    for i = 1, 4 do others[i] = recipe({ spell = i, skillLine = ALCHEMY, rank = false, known = false }) end
    local o = IS.Breakdown(facts({ crafting = others }), ME, item())
    assertEqual(lineOf(o, "craft", "Other").points, 12); assertEqual(lineOf(o, "cap", "9").points, -3)
    assertEqual(o.score, 9); assertEqual(sum(o), 9)
end)

test("verdict breakdown: the word's line for each bar, a plain hint for a missing input, never the tier", function()
    local _, IS = addon()
    local f = facts()
    assertEqual(IS.Breakdown(f, ME, item({ sellPrice = 7 })).from, "Sell: under 20, and a vendor buys it")
    assertEqual(IS.Breakdown(f, ME, item({ sellPrice = 0 })).from, "Toss: under 20, and no vendor buys it")
    assertEqual(IS.Breakdown(f, ME, item({ sellPrice = false })).from, "Hold: under 20, and the sell price is not known yet")
    local low = IS.Breakdown(facts({ fdb = "loading" }), ME, item({ sellPrice = 0 }))
    assertEqual(low.verdict, "hold")
    assertEqual(low.from, "Hold: under 20, but too little is known to toss it")
    assertEqual(low.hint, "ForeverDB is not loaded", "a missing input as a plain hint")
    assertNil(low.tier, "no confidence tier"); assertNil(low.confidence)
    local ranks = IS.Breakdown(facts({ crafting = { recipe({}) } }), { level = 20 }, item())
    assertEqual(ranks.hint, "Open your profession window to rank recipes")
    local new = IS.Breakdown(facts({ vendors = { {}, {}, {} } }), ME, item({ newCollect = true }))
    assertEqual(kinds(new), "collect"); assertEqual(sum(new), 100); assertEqual(new.from, "Keep from 50")
end)

test("verdict breakdown: the tooltip's verdict is unchanged by it, and builds no breakdown", function()
    local _, IS = addon()
    local f = facts({ quests = { quest("log") }, vendors = { {}, {}, {} } })
    local before = IS.Verdict(f, ME, item())
    IS.Breakdown(f, ME, item())
    local after = IS.Verdict(f, ME, item())
    assertEqual(after.score, before.score); assertEqual(#after.reasons, #before.reasons)
    for i = 1, #before.reasons do assertEqual(after.reasons[i], before.reasons[i]) end
    assertNil(after.lines, "no breakdown on the hover's answer")
end)
