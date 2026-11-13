-- tests/test_collect_surfaces.lua — the surfaces a collectible reaches beyond its Me and Them cells
-- (issue #13, categories design spec §6.1, DW-CAT7; modules/CollectCells.lua and its hooks): the
-- Slot and Type cells (the kind, a recipe's profession), the detail card's chips and boxes, the
-- History rows and card from the stored verdict, the item tooltip's Kind rows, the Drops strip's
-- `n new`, the diagnostics' `collect:` lines, the compact cards (no ⊘ on the new words) and the
-- View's New to my collection with the other values' answers for collectibles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local REINS = "|cffa335ee|Hitem:6001::|h[Reins]|h|r"
local DASH = "–"

local function ns() return T.newAddon() end

local function collect(verdict, over)
    local e = { verdict = verdict, equip = "collect", collect = true, category = "mount", reasons = {} }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

-- Someone else's mount drop, new to your collection.
local function drop(over)
    local d = {
        id = 1, link = REINS, itemID = 6001, isMine = false, at = 100,
        looter = { name = "Brakk-Realm", guid = "Player-1-0000000A", classFile = "WARRIOR" },
        facts = { ilvl = 1, equipLoc = "", quality = 4, category = "mount", collect = { kind = "mount", known = false } },
        me = collect("newCollect", { reasons = { { key = "collectNew" } } }),
        trade = { state = "unknown", reasonKey = "collectible", args = {} },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

-- A recipe drop: Tailoring (skill line 197), yours or not.
local function recipe(yours)
    return drop({ facts = { ilvl = 1, equipLoc = "", quality = 3, category = "recipe", classID = 9, subClassID = 2,
            collect = { kind = "recipe", skillLine = 197, hasProfession = yours, known = false } },
        me = yours == false and collect("cantUse", { category = "recipe", reasons = { { key = "notYourProfession" } } })
            or collect("newCollect", { category = "recipe" }) })
end

local function tipHas(tip, needle)
    for _, l in ipairs(tip or {}) do
        if type(l) == "string" and l:find(needle, 1, true) then return true end
    end
    return false
end

local function texts(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = c.text end
    return table.concat(out, "|")
end

-- ---------------------------------------------------------------------------------------------
-- The Slot and Type cells
-- ---------------------------------------------------------------------------------------------

test("collect surfaces: the Slot cell is the collectible's kind, a cosmetic's slot in its tooltip", function()
    local NS = ns()
    local WC, L = NS.WindowCells, NS.L
    -- red under: WC.Slot without the CollectCells.SlotOf hook (a dash, "not worn, or not loaded")
    for cat, word in pairs({ mount = "Mount", pet = "Pet", toy = "Toy", recipe = "Recipe" }) do
        local c = WC.Slot({ facts = { category = cat, equipLoc = "" } })
        assertEqual(c.text, L[word], cat); assertEqual(c.tone, "plain", cat)
        assertTrue(tipHas(c.tip, L["your collection, not your gear"]), cat)
    end
    local look = WC.Slot({ facts = { category = "cosmetic", equipLoc = "INVTYPE_HEAD" } })
    assertEqual(look.text, L["Cosmetic"])
    assertTrue(tipHas(look.tip, WC.SlotLabel("INVTYPE_HEAD")), "the slot the look is worn in")
    assertEqual(WC.Slot({ facts = { category = "equipment", equipLoc = "INVTYPE_HEAD" } }).text, WC.SlotLabel("INVTYPE_HEAD"),
        "gear keeps its own slot")
end)

test("collect surfaces: the Type cell is a recipe's profession, a dash for the other collectibles", function()
    local NS = ns()
    local WC, L = NS.WindowCells, NS.L
    -- red under: WC.ArmorType without the CollectCells.TypeOf hook ("not worn (a token, say)")
    local mine = WC.ArmorType(recipe(true))
    assertEqual(mine.text, L["Tailoring"]); assertTrue(mine.known); assertEqual(mine.tone, "plain")
    assertTrue(tipHas(mine.tip, L["yes"]), "yours")
    local theirs = WC.ArmorType(recipe(false))
    assertEqual(theirs.text, L["Tailoring"]); assertEqual(theirs.tone, "redMuted", "not your profession")
    -- the profession from the subclass when the facts carry no skill line
    assertEqual(WC.ArmorType({ facts = { category = "recipe", subClassID = 2 } }).text, L["Tailoring"])
    local book = WC.ArmorType({ facts = { category = "recipe", subClassID = 0 } })
    assertEqual(book.text, DASH); assertFalse(book.known)
    local mount = WC.ArmorType(drop())
    assertEqual(mount.text, DASH); assertFalse(mount.known)
    assertTrue(tipHas(mount.tip, L["a collectible: no armor or weapon type"]))
end)

test("collect surfaces: a token kept with no classes reads a dash, never Any class", function()
    local NS = ns()
    local c = NS.WindowCells.ArmorType({ facts = { isTierToken = true, category = "tierToken", tokenSlot = "INVTYPE_HEAD" } })
    -- red under: CC.TokenType answering `Any class` for every token with no class list
    assertEqual(c.text, DASH); assertFalse(c.known)
    -- red under: the `any` slot taken as a Curio (since TT-1 a token whose text named no slot is `any`)
    local anySlot = NS.WindowCells.ArmorType({ facts = { isTierToken = true, category = "tierToken", tokenSlot = "any" } })
    assertEqual(anySlot.text, DASH); assertFalse(anySlot.known)
    local curio = NS.WindowCells.ArmorType({ facts = { isTierToken = true, tokenSlot = "any", tokenUsers = "every" } })
    assertEqual(curio.text, NS.L["Any class"], "a Curio still names every class")
end)

-- ---------------------------------------------------------------------------------------------
-- The detail card
-- ---------------------------------------------------------------------------------------------

test("collect surfaces: the detail card's chips: the kind, a recipe's profession, a pet's count", function()
    local NS = ns()
    local DC, L = NS.DetailCells, NS.L
    local chips = DC.Chips(drop())
    assertEqual(chips[1].text, L["Mount"], "the slot chip is the kind")
    assertEqual(texts(DC.Chips(recipe(true))):find(L["Tailoring"], 1, true) ~= nil, true, "the profession chip")
    local pet = drop({ facts = { category = "pet", equipLoc = "", collect = { kind = "pet", count = 2, limit = 3 } } })
    -- red under: DC.Chips without CollectCells.CountChip
    assertTrue(texts(DC.Chips(pet)):find(L["Collected %d/%d"]:format(2, 3), 1, true) ~= nil, texts(DC.Chips(pet)))
    local look = drop({ facts = { category = "cosmetic", equipLoc = "INVTYPE_HEAD", transmogKnown = false } })
    -- The look is Retail's alone (Forever port design §4.4): on WoW Forever no chip names it.
    assertEqual(texts(DC.Chips(look)):find(L["New look"], 1, true) ~= nil, not T.forever, "a cosmetic keeps the look's chip")
end)

test("collect surfaces: FOR YOU reads NEW TO COLLECTION over Kind and Collection rows, no gear rows", function()
    local NS = ns()
    local L = NS.L
    local side = NS.DetailCells.ForYou(drop(), "none", "MAGE", {})
    -- red under: verdictChip without the collect branch (VERDICT_CHIP's UNKNOWN for newCollect)
    assertEqual(side.verdict.text, L["NEW TO COLLECTION"]); assertEqual(side.verdict.tone, "good")
    assertNil(side.verdict.glyph)
    local keys = {}
    for i, r in ipairs(side.rows) do keys[i] = r.key end
    -- red under: DC.ForYou's gear rows (Replaces, Item level, Track, Stats, Score) for a collectible
    assertEqual(table.concat(keys, ","), "kind,collection")
    assertEqual(side.rows[1].text, L["Mount"]); assertEqual(side.rows[2].text, L["New"])
    local r = NS.DetailCells.ForYou(recipe(false), "none", "MAGE", {})
    assertEqual(r.verdict.text, L["CAN'T USE"])
    assertEqual(r.rows[3].key, "profession"); assertEqual(r.rows[3].tone, "redMuted")
    local known = NS.DetailCells.ForYou(drop({ me = collect("collected") }), "none", "MAGE", {})
    assertEqual(known.verdict.text, L["COLLECTED"])
    local unread = NS.DetailCells.ForYou(drop({ me = collect("collectUnknown") }), "none", "MAGE", {})
    assertEqual(unread.verdict.text, L["COLLECTION UNKNOWN"])
end)

test("collect surfaces: FOR THE LOOTER on someone else's collectible is a dash, judged for you alone", function()
    local NS = ns()
    local side = NS.DetailCells.ForLooter(drop(), nil, nil, 0)
    -- red under: ForLooter's gear rows and spec row (`waiting` on an inspect never asked for)
    assertEqual(side.verdict.text, DASH); assertEqual(#side.rows, 1)
    assertTrue(tipHas(side.rows[1].tip, NS.L["Collectibles are judged for you alone."]))
end)

-- ---------------------------------------------------------------------------------------------
-- History
-- ---------------------------------------------------------------------------------------------

local function entry(over)
    local e = { itemLink = REINS, itemID = 6001, looter = "Brakk-Realm", class = "WARRIOR", ilvl = 1, equipLoc = "",
        quality = 4, category = "mount", outcome = "seen", at = 100,
        me = { verdict = "newCollect", collect = true, category = "mount" } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

test("collect surfaces: a History row reads the kept kind, verdict and a dash for the looter", function()
    local NS = ns()
    local WH, WC, L = NS.WindowHistory, NS.WindowCells, NS.L
    local d = WH.AsDrop(entry(), 1)
    -- red under: AsDrop without the kept category (the Slot a dash)
    assertEqual(WC.Slot(d).text, L["Mount"])
    assertEqual(WH.MeCell(d).text, L["New"])
    -- red under: ThemVerdict's `not read while it was in the feed` for a collectible
    local them = WH.ThemVerdict(d)
    assertEqual(them.text, DASH); assertTrue(tipHas(them.tip, L["Collectibles are judged for you alone."]))
    local token = WH.AsDrop(entry({ category = "tierToken", tokenSlot = "INVTYPE_HEAD", equipLoc = "INVTYPE_HEAD",
        me = { verdict = "upgrade", ilvlDelta = 7 } }), 2)
    assertEqual(T.tipPlain(WC.Slot(token).text), L["Token: %s"]:format(WC.SlotLabel("INVTYPE_HEAD")))
    assertEqual(WC.ArmorType(token).text, DASH, "the classes are not kept")
    local kept = entry({ equipLoc = "INVTYPE_HEAD", me = { verdict = "upgrade" } })
    kept.category = nil   -- kept before issue #13
    local old = WH.AsDrop(kept, 3)
    assertEqual(WC.Slot(old).text, WC.SlotLabel("INVTYPE_HEAD"), "an old entry reads as equipment")
end)

test("collect surfaces: the History card's FOR YOU keeps the collection verdict, its group a dash", function()
    local NS = ns()
    local L = NS.L
    local d = NS.WindowHistory.AsDrop(entry({ me = { verdict = "collected", collect = true, category = "pet",
        count = 1, limit = 3 }, category = "pet" }), 1)
    local m = NS.HistoryCard.Model(d, { now = 200 })
    assertEqual(m.me.verdict.text, L["COLLECTED"])
    assertEqual(m.me.rows[1].key, "kind"); assertEqual(m.me.rows[2].text, L["Collected"] .. " 1/3")
    -- red under: forGroup's deltas (Item level and Score not kept) on a collectible
    assertEqual(m.them.verdict.text, DASH); assertEqual(#m.them.rows, 1)
    assertEqual(m.them.rows[1].key, "looter")
end)

-- ---------------------------------------------------------------------------------------------
-- The item tooltip, the Drops strip, the compact cards, the diagnostics
-- ---------------------------------------------------------------------------------------------

test("collect surfaces: the item tooltip adds the Kind and the collection now; gear none", function()
    local NS = ns()
    local CC, L = NS.CollectCells, NS.L
    local rows = CC.KindRows({ category = "mount", collect = { kind = "mount", known = true } })
    assertEqual(#rows, 2)
    assertTrue(T.tipPlain(rows[1]):find(L["Mount"], 1, true) ~= nil)
    assertTrue(T.tipPlain(rows[2]):find(L["Collected"], 1, true) ~= nil, "the verdict of the facts")
    local token = CC.KindRows({ isTierToken = true, category = "tierToken", tokenSlot = "INVTYPE_LEGS" })
    assertTrue(T.tipPlain(token[2]):find(NS.WindowCells.SlotLabel("INVTYPE_LEGS"), 1, true) ~= nil, "what it makes")
    assertEqual(#CC.KindRows({ category = "equipment" }), 0, "gear: the game names its kind")
    assertEqual(#CC.KindRows(nil), 0)
    local added = {}
    local tip = { AddLine = function(_, line) added[#added + 1] = line end }
    NS.ItemFacts.Get = function() return { category = "toy", collect = { kind = "toy", known = false } } end
    -- red under: RT.AddKindRows adding nothing (the hook in the item tooltip)
    assertEqual(NS.RowTooltip.AddKindRows(tip, REINS), 2); assertEqual(#added, 2)
    assertEqual(NS.RowTooltip.AddKindRows(tip, nil), 0, "no link, no rows")
end)

test("collect surfaces: the Drops strip ends with `n new`, anyone's, the tab's filters applied", function()
    local NS = ns()
    local DS, L = NS.DropsStrip, NS.L
    local gear = drop({ id = 2, me = { verdict = "upgrade", reasons = {} }, facts = { category = "equipment" } })
    local seen = drop({ id = 3, me = collect("collected") })
    local all = function() return true end
    -- red under: no DS.NewCount (the strip never says what is new to your collection)
    assertEqual(DS.NewCount({ drop(), gear, seen, drop({ id = 4, isMine = true }) }, all), 2)
    assertEqual(DS.NewCount({ drop() }, function() return false end), 0, "a drop the tab hides is not counted")
    local none = { count = 0, text = "", tip = {} }
    assertEqual((DS.Text(none, 0, false)), "", "nothing to say")
    local text, tip = DS.Text(none, 2, false)
    assertEqual(text, L["%d new"]:format(2)); assertTrue(tipHas(tip, L["New to your collection"]))
    local s = { count = 1, text = L["1 tradeable"], tip = { L["Your tradeable drops"] } }
    assertEqual((DS.Text(s, 1, false)), L["1 tradeable"] .. " · " .. L["%d new"]:format(1))
    assertEqual(#s.tip, 1, "MineCells' tooltip is copied, not grown")
end)

test("collect surfaces: the compact cards draw the collection words with no ⊘", function()
    local NS = ns()
    local CC, SC = NS.CompactCards, NS.SideCells
    for _, v in ipairs({ "newCollect", "collected", "collectUnknown" }) do
        local h = CC.Verdict(SC.Me(drop({ me = collect(v) }), {}, "MAGE"))
        -- red under: the collection verdicts added to CompactCards' WORD_VERDICT
        assertNil(h.glyph, v); assertFalse(CC.VerdictText(h):find("⊘", 1, true) ~= nil, v)
    end
    local h = CC.Verdict(SC.Me(drop(), {}, "MAGE"))
    assertEqual(CC.VerdictText(h), NS.L["New"]); assertEqual(h.tone, "good")
end)

test("collect surfaces: the diagnostics name the item kinds on, the lists' sizes and each drop's kind", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("feed.categories.toy", false)
    NS.ItemLists.Add("whitelist", 6001); NS.ItemLists.Add("blacklist", 6002); NS.ItemLists.Add("blacklist", 6003)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    -- red under: no collect lines in the Feed section
    local on = text:match("collect: on([^\n]*)")
    assertTrue(on ~= nil, text)
    assertEqual((on:gsub("%W+", " ")), " equipment tierToken mount pet recipe", "in C.CATEGORIES' order, toy off")
    assertTrue(text:find("collect: whitelist=1 blacklist=2", 1, true) ~= nil, text)
end)

-- ---------------------------------------------------------------------------------------------
-- The View
-- ---------------------------------------------------------------------------------------------

test("collect surfaces: New to my collection lists the new collectibles; the other views' answers", function()
    local NS = ns()
    local FB = NS.WindowFilterBar
    local function hides(d, value) return FB.HiddenBy(d, { view = { [value] = true }, char = {} }, {}) end
    local new, seen = drop(), drop({ me = collect("collected") })
    local wrongProfession, gear = recipe(false), drop({ me = { verdict = "upgrade", reasons = {} }, facts = { category = "equipment" } })
    -- red under: no newCollect view (an unknown value passes every drop)
    assertNil(hides(new, "newCollect")); assertEqual(hides(seen, "newCollect"), "newCollect")
    assertEqual(hides(gear, "newCollect"), "newCollect", "gear is never new to your collection")
    assertEqual(hides(new, "upgrade"), "upgrade", "a collectible is never an upgrade")
    assertEqual(hides(new, "interesting"), "interesting", "it has no action")
    local bom = drop({ isMine = true, trade = { state = "yes", reasonKey = "boe", args = {} } })
    assertEqual(hides(bom, "interesting"), "interesting", "your own BoE mount fails Interesting too")
    assertNil(hides(new, "usable")); assertEqual(hides(wrongProfession, "usable"), "usable", "not your profession")
    assertNil(hides(bom, "likely"), "Likely tradeable reads the estimate alone")
    assertEqual(FB.ReasonLabel("newCollect"), NS.L["View: %s"]:format(NS.L["New to my collection"]))
end)

test("collect surfaces: the View menu, its tooltip and History both carry New to my collection", function()
    local NS = ns()
    local FB, L = NS.WindowFilterBar, NS.L
    assertEqual(FB.VIEWS[#FB.VIEWS], "newCollect", "after Upgrade for me")
    local labels = {}
    for _, o in ipairs(FB.ViewOptions("history")) do labels[o.value] = o end
    assertTrue(labels.newCollect ~= nil and labels.newCollect.color == nil, "History uses it (not grayed)")
    assertTrue(tipHas(FB.ViewTip("group"), L["a mount, pet, toy, recipe or look you have not collected"]))
    assertEqual(FB.ViewLabel({ newCollect = true }), L["New to my collection"])
end)

test("collect surfaces: the feed.view.newCollect row seeds a fresh tab and defaults off", function()
    local NS = T.bootAddon()
    local FB = NS.WindowFilterBar
    local row = NS.SchemaRuntime.FindRow("feed.view.newCollect")
    -- red under: no VIEW_ROWS entry for newCollect
    assertTrue(row ~= nil); assertEqual(row.page, "window"); assertEqual(row.type, "bool")
    assertFalse(NS.C.PROFILE.feed.view.newCollect)
    assertNil(FB.Defaults().view.newCollect)
    NS.SchemaRuntime.Set("feed.view.newCollect", true)
    assertTrue(FB.Defaults().view.newCollect, "the row seeds its value")
    local tail = " With none ticked, a fresh tab lists every drop."
    assertEqual(row.tooltip:sub(-#tail), tail)
end)
