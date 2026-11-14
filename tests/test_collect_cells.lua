-- tests/test_collect_cells.lua — how a collectible looks and what it refuses (issue #13, categories
-- design spec §3.2, §6.1, §6.2; modules/CollectCells.lua and the hooks into the shared cells): the
-- Me cell's words and tones (New green, Collected gray, Collected 1/3, Known, New look, `?`, Can't
-- use) and its tooltip; WindowCells.Verdict delegating on `collect`; the Them cell a dash, never `?`
-- waiting on an inspect; the merged Me and Them cells with no gear part; your own collectible's Them
-- and Offer; and the pure refusals: the Ask button, the ask template (the transmog ask too), the
-- toast, Post my tradeables (and the Drops strip's count), the Interesting view and the glow. A tier
-- token is not refused. History's stored verdict renders through the same cell.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local REINS = "|cffa335ee|Hitem:6001::|h[Reins]|h|r"

local function ns() return T.newAddon() end

-- A collection verdict as NS.Collectibles.Verdict answers it.
local function collect(verdict, over)
    local e = { verdict = verdict, equip = "collect", collect = true, category = "mount", reasons = {} }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

-- Someone else's mount drop, new to your collection, its trade `likely`.
local function drop(over)
    local d = {
        id = 1, link = REINS, itemID = 6001, isMine = false, at = 100,
        looter = { name = "Brakk-Realm", guid = "Player-1-0000000A", classFile = "WARRIOR" },
        facts = { ilvl = 1, equipLoc = "", quality = 4, category = "mount", transmogKnown = false },
        me = collect("newCollect", { reasons = { { key = "collectNew" } } }),
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local function tipHas(tip, needle)
    for _, l in ipairs(tip) do
        if type(l) == "string" and l:find(needle, 1, true) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- The Me cell
-- ---------------------------------------------------------------------------------------------

test("collect cells: each collection verdict's word and tone", function()
    local NS = ns()
    local CC, L = NS.CollectCells, NS.L
    local function check(eval, text, tone)
        local c = CC.Verdict(eval, "me", L["For you"])
        assertEqual(c.text, text, eval.verdict); assertEqual(c.tone, tone, eval.verdict)
        assertTrue(c.collect)
    end
    check(collect("newCollect"), L["New"], "good")
    -- red under: collected in the downgrade red rather than the gray `bad` tone (Q1)
    check(collect("collected"), L["Collected"], "bad")
    check(collect("collected", { category = "pet", count = 1, limit = 3 }), L["Collected"] .. " 1/3", "bad")
    check(collect("collected", { category = "recipe" }), L["Known"], "bad")
    check(collect("newCollect", { category = "cosmetic" }), L["New look"], "good")
    check(collect("collected", { category = "cosmetic" }), L["Look known"], "bad")
    check(collect("collectUnknown"), "?", "muted")
    check(collect("cantUse", { category = "recipe" }), L["Can't use"], "redMuted")
    check(collect("unknown", { category = nil }), "?", "muted")
end)

-- RX-04 (rolls UX design §3.5): a non-gear item's Me cell is its kind word in the neutral tone.
-- red under: CollectCells without the kind words (`?` then shows)
test("collect cells: a lockbox, a bag and an item of no kind read their kind, plain", function()
    local NS = ns()
    local L = NS.L
    for verdict, word in pairs({ lockbox = L["Lockbox"], container = L["Container"], item = L["Item"] }) do
        local c = NS.CollectCells.Verdict(collect(verdict, { category = verdict == "item" and "other" or "container" }),
            "me", L["For you"])
        assertEqual(c.text, word, verdict); assertEqual(c.tone, "plain", verdict)
        assertTrue(c.tip[1]:find(word, 1, true) ~= nil, "titled by its kind")
    end
end)

test("collect cells: the tooltip's title, Means and one Why row per reason", function()
    local NS = ns()
    local L = NS.L
    local c = NS.CollectCells.Verdict(collect("collected", { category = "pet", count = 1, limit = 3,
        reasons = { { key = "collectKnown" }, { key = "petPartial", detail = "1/3" } } }), "me", L["For you"])
    assertEqual(c.tip[1], ("%s: %s"):format(L["For you"], L["Already collected"]))
    assertTrue(tipHas(c.tip, L["already in your collection"]), "the Means row")
    assertTrue(tipHas(c.tip, L["you have %s"]:format("1/3")), "the pet's count")
    c = NS.CollectCells.Verdict(collect("cantUse", { category = "recipe", reasons = { { key = "notYourProfession" } } }),
        "me", L["For you"])
    assertTrue(tipHas(c.tip, L["not one of your professions"]))
end)

test("collect cells: WindowCells.Verdict hands a collection verdict to CollectCells, never a glyph", function()
    local NS = ns()
    local c = NS.WindowCells.Me(drop())
    -- red under: WC.Verdict without its `collect` hook (VERDICT_SHORT's `?` for an unknown word)
    assertEqual(c.text, NS.L["New"]); assertEqual(c.tone, "good"); assertNil(c.glyph)
    assertTrue(c.collect)
    assertEqual(c.tip[1], ("%s: %s"):format(NS.L["For you"], NS.L["New to your collection"]))
end)

test("collect cells: History's stored collection verdict renders through the same cell", function()
    local NS = ns()
    local e = { verdict = "cantUse", collect = true, category = "recipe", reasonKey = "notYourProfession" }
    local c = NS.WindowCells.Verdict(e, "me", NS.L["For you"])
    assertEqual(c.text, NS.L["Can't use"]); assertEqual(c.tone, "redMuted")
    assertTrue(tipHas(c.tip, NS.L["not one of your professions"]))
    c = NS.WindowCells.Verdict({ verdict = "collected", collect = true, category = "pet", count = 2, limit = 3 }, "me", "x")
    assertEqual(c.text, NS.L["Collected"] .. " 2/3")
end)

-- ---------------------------------------------------------------------------------------------
-- Them, the merged cells, your own collectible
-- ---------------------------------------------------------------------------------------------

test("collect cells: Them on someone else's collectible is a dash, never an inspect's `?`", function()
    local NS = ns()
    local c = NS.WindowCells.Them(drop())
    -- red under: WC.Them's `drop.them == nil` branch reached first ("waiting (one inspect at a time)")
    assertEqual(c.text, "–"); assertEqual(c.tone, "muted")
    assertTrue(tipHas(c.tip, NS.L["Collectibles are judged for you alone."]))
    assertFalse(tipHas(c.tip, NS.L["waiting (one inspect at a time)"]))
end)

test("collect cells: the merged Me and Them cells carry no gear part", function()
    local NS = ns()
    local me = NS.SideCells.Me(drop(), {}, "MAGE")
    assertNil(me.level, "no worn level"); assertEqual(me.text, NS.L["New"]); assertEqual(me.tone, "good")
    assertFalse(tipHas(me.tip, NS.L["not worn, or not loaded"]), "no gear lines")
    local them = NS.SideCells.Them(drop(), nil, 0)
    assertNil(them.level); assertEqual(them.text, "–")
end)

test("collect cells: your own collectible has no candidates, a dash for Them and no Offer", function()
    local NS = ns()
    local mine = drop({ isMine = true, candidates = { x = { guid = "x", name = "X", status = "ready",
        eval = { verdict = "upgrade", ilvlDelta = 5 } } } })
    -- red under: MC.Candidates listing the candidates of a collectible
    assertEqual(#NS.MineCells.Candidates(mine), 0)
    local them = NS.MineCells.Details(mine, true, NS.L["Them"])
    assertEqual(them.text, "–")
    assertTrue(tipHas(them.tip, NS.L["Collectible: nobody is judged for it."]))
    local offer = NS.MineCells.OwnOffer(mine, "ready", false)
    -- red under: MC.OwnOffer offering a collectible
    assertFalse(offer.offered); assertTrue(offer.offer); assertEqual(offer.state, "none")
    assertTrue(tipHas(offer.tip, NS.L["collectibles are watched, not offered"]))
end)

-- ---------------------------------------------------------------------------------------------
-- The pure refusals
-- ---------------------------------------------------------------------------------------------

test("collect cells: the Ask button is No action for a collectible, a cosmetic's transmog ask too", function()
    local NS = ns()
    local a = NS.WindowCells.Ask(drop(), nil, nil, true)
    -- red under: noAskReason without the feed-only check
    assertFalse(a.offered); assertEqual(a.state, "none")
    assertTrue(tipHas(a.tip, NS.L["collectibles are watched, not asked for"]))
    local look = drop({ facts = { equipLoc = "INVTYPE_HEAD", category = "cosmetic", transmogKnown = false },
        me = collect("newCollect", { category = "cosmetic" }) })
    -- red under: AskTemplate's transmog fallback reached for a cosmetic
    assertNil(NS.Messaging.AskTemplate(look, true), "no transmog ask")
    assertFalse(NS.WindowCells.Ask(look, nil, nil, true).offered)
end)

test("collect cells: no toast, no Post my tradeables and no glow for a collectible", function()
    local NS = ns()
    assertEqual(select(2, NS.Toast.Qualifies(drop(), 0)), "collectible")
    local mine = drop({ isMine = true, trade = { state = "yes", reasonKey = "boe", args = {} } })
    -- red under: FB.IsTradeableMine posting a collectible
    assertFalse(NS.WindowFilterBar.IsTradeableMine(mine))
    assertNil(NS.Glow.KindOf(drop()), "never an upgrade, so never a glow")
end)

test("collect cells: your own tradeable collectible is not counted by the Drops strip, nor Interesting", function()
    local NS = ns()
    local mine = drop({ isMine = true, trade = { state = "yes", reasonKey = "boe", args = {} } })
    local gear = drop({ id = 2, isMine = true, me = { verdict = "sidegrade", reasons = {} },
        facts = { ilvl = 620, equipLoc = "INVTYPE_HEAD", quality = 4, category = "equipment" },
        trade = { state = "yes", reasonKey = "boe", args = {} } })
    -- red under: MC.Summary counting what Post my tradeables (FB.IsTradeableMine) leaves out
    assertEqual(NS.MineCells.Summary({ mine, gear }, 100).count, 1)
    assertEqual(NS.MineCells.Summary({ mine }, 100).count, 0, "a collectible alone: nothing to post")
    -- red under: FB.IsInteresting without the feed-only guard ahead of its isMine branch
    assertFalse(NS.WindowFilterBar.IsInteresting(mine))
    assertTrue(NS.WindowFilterBar.IsInteresting(gear), "your own tradeable gear still is")
end)

test("collect cells: a tier token is not feed-only: it still asks and toasts as gear", function()
    local NS = ns()
    local token = drop({ facts = { ilvl = 620, equipLoc = "INVTYPE_HEAD", category = "tierToken", isTierToken = true },
        me = { verdict = "upgrade", ilvlDelta = 12, reasons = {} } })
    assertFalse(NS.Collectibles.IsFeedOnly(token))
    assertEqual(NS.Messaging.AskTemplate(token, false), "ask")
    assertTrue(NS.Toast.Qualifies(token, 10))
    assertTrue(NS.WindowCells.Ask(token).offered)
end)
