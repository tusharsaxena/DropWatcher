-- tests/test_offspec_offer.lua — Offer for off-spec (feedback-19 spec §3, DW-O3): a member whose
-- current spec cannot use your drop but another spec of their class can (eval.offSpec,
-- modules/OffSpec.lua) is an Offer candidate of its own, ranked after every main-spec upgrade and
-- equal. Case by case: MineCells' two statuses, their rank and explanations, offerable, the gain
-- sort within a tier and the baseline from the off-spec part; the Their eq cell in the offspec cyan
-- with the spec's name (`311 ▲14 Holy`, NS.SideCells.Candidate); Upgrade for N and the keep-hidden
-- rule staying main-spec only; and the Offer whisper's {gain} reading the off-spec gain.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local AXE  = "|cffa335ee|Hitem:212::|h[Venom-Etched Crescent]|h|r"
local MACE = "|cffa335ee|Hitem:400::|h[Kaelith's Mace]|h|r"
local WORN = "|cffa335ee|Hitem:401::|h[Worn Sword]|h|r"
local SHIELD = "|cffa335ee|Hitem:402::|h[Worn Shield]|h|r"

local NONE = {}
local HOLY, PROT, RET = 65, 66, 70
local NOW = 1000

local function with(t, over)
    for k, v in pairs(over or {}) do
        if v == NONE then t[k] = nil else t[k] = v end
    end
    return t
end

-- An off-spec answer: Holy can use the Crescent, +14 over the 311 mace they wear.
local function off(over)
    return with({ specID = HOLY, mainSpecID = PROT, verdict = "upgrade", ilvlDelta = 14,
        baseline = { link = MACE, ilvl = 311, slot = 16 }, baselineSlot = 16, reasons = {} }, over)
end

-- Their current spec cannot use it (an Intellect weapon); `o` is what another spec makes of it.
local function cantMain(o)
    return { verdict = "cantUse", reasons = { { key = "primaryStat" } }, offSpec = o }
end

local function cand(name, classFile, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = status, eval = eval }
end

local function main(verdict, d, over)
    return with({ verdict = verdict, ilvlDelta = d, baseline = { ilvl = 300 }, reasons = {} }, over)
end

-- Every tier once, the two off-spec upgrades out of their gain order, and the main-spec upgrade's
-- gain the smallest, so the tier (not the gain) puts it first.
local function everyone()
    local list = {
        cand("Ohnine", "MAGE", "unavailable"),
        cand("Eight", "DRUID", "checking"),
        cand("Seven", "MAGE", "ready", { verdict = "unknown", reasons = {} }),
        cand("Sixa", "ROGUE", "ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }),
        cand("Sixb", "PALADIN", "ready", cantMain(off({ verdict = "downgrade", ilvlDelta = -6 }))),
        cand("Five", "WARRIOR", "ready", main("downgrade", -3)),
        cand("Fourth", "PALADIN", "ready", cantMain(off({ verdict = "sidegrade", ilvlDelta = 1 }))),
        cand("Kaelith", "PALADIN", "ready", cantMain(off())),
        cand("Ardent", "PALADIN", "ready", cantMain(off({ specID = RET, ilvlDelta = 30 }))),
        cand("Second", "PRIEST", "ready", main("sidegrade", 0)),
        cand("First", "MAGE", "ready", main("upgrade", 2)),
    }
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

local function drop(over)
    return with({
        id = 1, at = NOW - 700, link = AXE, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 325, equipLoc = "INVTYPE_WEAPON", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6432 }, expiresAt = NOW + 6432 },
        candidates = everyone(),
    }, over)
end

local function addon()
    local NS, _, m = T.newAddon()
    m.specNames[HOLY], m.specNames[PROT], m.specNames[RET] = "Holy", "Protection", "Retribution"
    return NS, m
end

local function byShort(list, short)
    for _, e in ipairs(list) do if e.short == short then return e end end
end

local function has(tip, line)
    for _, l in ipairs(tip) do if T.tipText(l) == line then return true end end
    return false
end

-- ── the statuses, their rank and the sort ───────────────────────────────────────────────────

test("off-spec offer: an off-spec upgrade or sidegrade is its own status, ranked after main-spec equals", function()
    local MC = addon().MineCells
    local list = MC.Candidates(drop())
    local names, statuses, ranks = {}, {}, {}
    for i, e in ipairs(list) do names[i], statuses[i], ranks[i] = e.short, e.status, tostring(e.rank) end
    assertEqual(table.concat(names, ","), "First,Second,Ardent,Kaelith,Fourth,Five,Sixb,Sixa,Seven,Eight,Ohnine")
    assertEqual(table.concat(statuses, ","),
        "upgrade,sidegrade,offSpecUpgrade,offSpecUpgrade,offSpecSidegrade,downgrade,cantUse,cantUse,unknown,checking,unavailable")
    assertEqual(table.concat(ranks, ","), "1,2,3,3,4,5,6,6,7,8,9")
    assertEqual(list[7].gain, -6, "a Can't use with an off-spec downgrade carries its difference, so it leads its tier")
end)

test("off-spec offer: doesntWant ranks with cantUse, and an off-spec downgrade stays Can't use", function()
    local MC = addon().MineCells
    local d = drop({ candidates = {
        a = cand("Picky", "MAGE", "ready", { verdict = "doesntWant", reasons = {} }),
        b = cand("Sixb", "PALADIN", "ready", cantMain(off({ verdict = "downgrade", ilvlDelta = -6 }))),
        c = cand("Junk", "PALADIN", "ready", cantMain(off({ verdict = "doesntWant" }))),
    } })
    for _, e in ipairs(MC.Candidates(d)) do
        assertEqual(e.rank, 6, e.short)
        assertFalse(e.offerable, e.short .. " is not offerable")
    end
    assertEqual(byShort(MC.Candidates(d), "Sixb").status, "cantUse")
    assertEqual(byShort(MC.Candidates(d), "Junk").status, "cantUse", "an off-spec verdict OffSpec.Of refuses is ignored")
end)

test("off-spec offer: both off-spec statuses are offerable, read the off-spec gain and baseline", function()
    local MC = addon().MineCells
    local list = MC.Candidates(drop())
    local k, a, f = byShort(list, "Kaelith"), byShort(list, "Ardent"), byShort(list, "Fourth")
    assertTrue(k.offerable and a.offerable and f.offerable)
    assertEqual(k.gain, 14); assertEqual(a.gain, 30, "the larger off-spec gain sorts first within its tier")
    assertEqual(f.gain, 1)
    assertEqual(k.baseline.link, MACE, "the item the off-spec verdict was judged against")
    assertEqual(k.eval.verdict, "cantUse", "the eval itself is untouched")
    assertFalse(byShort(list, "Five").offerable); assertTrue(byShort(list, "Second").offerable)
end)

test("off-spec offer: an off-spec upgrade into an empty slot sorts last in its tier", function()
    local MC = addon().MineCells
    local d = drop({ candidates = {
        a = cand("Empty", "PALADIN", "ready", cantMain(off({ ilvlDelta = NONE, baseline = NONE, reasons = { { key = "emptySlot" } } }))),
        b = cand("Kaelith", "PALADIN", "ready", cantMain(off())),
    } })
    local list = MC.Candidates(d)
    assertEqual(list[1].short, "Kaelith"); assertEqual(list[2].short, "Empty")
    assertNil(list[2].gain); assertNil(list[2].baseline); assertTrue(list[2].offerable)
end)

test("off-spec offer: each off-spec status explains itself", function()
    local MC = addon().MineCells
    local list = MC.Candidates(drop())
    assertEqual(byShort(list, "Kaelith").explain, "An upgrade for one of their other specs (off-spec).")
    assertEqual(byShort(list, "Fourth").explain, "About what one of their other specs has there (off-spec): within the sidegrade band.")
    assertEqual(byShort(list, "Sixa").explain, "Their class or spec cannot use it.", "a plain Can't use is unchanged")
end)

-- ── Upgrade for N and the keep-hidden rule stay main-spec only ──────────────────────────────

test("off-spec offer: Upgrade for N counts main-spec upgrades only", function()
    local MC = addon().MineCells
    local d = drop()
    assertEqual(MC.UpgradeCount(d), 1, "First alone")
    local c = MC.Details(d, true)
    assertEqual(c.text, "Upgrade for 1"); assertEqual(c.upgrades, 1)
    assertEqual(#c.tip[2].grid, 1, "the grid names the main-spec upgrade only")
    local onlyOff = drop({ candidates = { k = cand("Kaelith", "PALADIN", "ready", cantMain(off())) } })
    assertEqual(MC.UpgradeCount(onlyOff), 0)
    assertEqual(MC.Details(onlyOff, true).text, "No upgrades")
    assertEqual(MC.OwnTrade(onlyOff, true).upgrades, 0, "Trade counts no upgrade")
end)

test("off-spec offer: an off-spec upgrade for you does not hide the drop", function()
    local MC = addon().MineCells
    local d = drop({ me = cantMain(off()) })
    local c = MC.Details(d, false)
    assertFalse(c.hidden == true, "keep? is main-spec only"); assertEqual(c.text, "Upgrade for 1")
    assertTrue(MC.Details(drop({ me = main("upgrade", 4) }), false).hidden, "a main-spec upgrade still hides")
end)

-- ── the Their eq cell (NS.SideCells.Candidate) ──────────────────────────────────────────────

local function cell(NS, c, insp)
    local d = drop({ candidates = { [c.guid] = c } })
    return NS.SideCells.Candidate(d, NS.MineCells.Candidates(d)[1], insp, 100)
end

test("off-spec offer: the candidate cell is cyan with the spec's name, 311 ▲14 Holy", function()
    local NS = addon()
    local c = cell(NS, cand("Kaelith", "PALADIN", "ready", cantMain(off())))
    assertEqual(c.level, "311"); assertEqual(c.levelTone, "plain")
    assertEqual(c.glyph, "▲"); assertEqual(c.text, "14 Holy"); assertEqual(c.tone, "offspec")
    assertEqual(c.offSpec, HOLY); assertEqual(c.mainVerdict, "cantUse"); assertEqual(c.verdict, "upgrade")
    assertEqual(#c.items, 1); assertEqual(c.items[1].link, MACE)
    assertTrue(has(c.tip, "An upgrade for one of their other specs (off-spec)."), "the status's explanation")
    assertTrue(has(c.tip, "Protection can't use it: Its primary stat does not suit the spec."), "what the main spec cannot do")
end)

test("off-spec offer: the candidate cell's gear is the item compared with, not the main spec's worn pair", function()
    local NS = addon()
    local read = { status = "fresh", at = 60, gear = { [16] = { link = WORN, ilvl = 300 }, [17] = { link = SHIELD, ilvl = 318 } } }
    local c = cell(NS, cand("Kaelith", "PALADIN", "ready", cantMain(off())), read)
    assertEqual(c.level, "311", "not the 300/318 Protection wears"); assertEqual(#c.items, 1)
    assertTrue(has(c.tip, "Inspected 40s ago."), "the read's age is kept")
    local side = cell(NS, cand("Fourth", "PALADIN", "ready", cantMain(off({ verdict = "sidegrade", ilvlDelta = 1 }))), read)
    assertEqual(side.glyph .. side.text, "≈1 Holy"); assertEqual(side.tone, "offspec")
    local empty = cell(NS, cand("Empty", "PALADIN", "ready",
        cantMain(off({ ilvlDelta = NONE, baseline = NONE, reasons = { { key = "emptySlot" } } }))), read)
    assertEqual(empty.level, "empty"); assertEqual(empty.glyph, "▲"); assertEqual(empty.text, "Holy")
    local plain = cell(NS, cand("Sixa", "ROGUE", "ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }), read)
    assertEqual(plain.text, "Can't use"); assertEqual(plain.tone, "bad"); assertEqual(plain.level, "300/318", "a plain Can't use is unchanged")
end)

-- ── the Offer whisper and the panel's note ──────────────────────────────────────────────────

test("off-spec offer: the Offer whisper's {gain} reads the candidate's off-spec gain", function()
    local NS = addon()
    local d = drop()
    assertEqual(NS.Asks.TokenContext("offer", d, { name = "Kaelith", guid = "Player-1-Kaelith" }).gain, 14)
    assertEqual(NS.Asks.TokenContext("offer", d, { name = "First", guid = "Player-1-First" }).gain, 2)
end)

-- The Offer panel as painted: your drop on Drops, its Offer pressed.
local function openPanel(cands)
    local NS, _, m = T.enableAddon()
    m.specNames[HOLY], m.specNames[PROT] = "Holy", "Protection"
    NS.addon.db.char = { session = { start = m.time() - 86400 } }
    m.__now = NOW
    local d = drop({ candidates = cands })
    NS.LootFeed.Get = function(id) return id == 1 and d or nil end
    NS.LootFeed.Drops = function() return { d } end
    NS.LootFeed.Groups = function()
        return { { key = "Den", label = "Den", kind = "encounter", at = NOW - 3000, drops = { 1 },
            roster = { { name = "Me", class = "PALADIN", me = true } }, seenBy = "Me-Realm", seenByClass = "PALADIN" } }
    end
    NS.Asks.StateOf = function() return "ready" end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    NS.Window.SelectTab("group")
    for _, r in ipairs(NS.WindowGroup.Drawn().rows) do
        if r.dropId == 1 then (r.cells.actions and r.cells.actions.ask or r.ask):__fire("OnClick") end
    end
    return NS, NS.OfferPanel.Drawn()
end

local function textOf(region) return region and region:GetText() end

test("off-spec offer: the panel paints Kaelith 311 ▲ 14 Holy in the offspec cyan, with Offer", function()
    local NS, p = openPanel({
        a = cand("First", "MAGE", "ready", main("upgrade", 2)),
        b = cand("Kaelith", "PALADIN", "ready", cantMain(off())),
        c = cand("Sixa", "ROGUE", "ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }),
    })
    local rows = {}
    for i, r in ipairs(p.rows) do
        local parts = { textOf(r.member.text) }
        for _, fs in ipairs({ r.eq.level, r.eq.glyph, r.eq.text }) do
            local t = textOf(fs)
            if t and t ~= "" then parts[#parts + 1] = t end
        end
        rows[i] = table.concat(parts, " ")
    end
    assertEqual(table.concat(rows, ","), "First 300 ▲ 2,Kaelith 311 ▲ 14 Holy,Sixa Can't use")
    local k, TONE = p.rows[2], NS.Constants.TONE
    assertEqual(select(2, k.eq.glyph:GetTextColor()), TONE.offspec.g, "the glyph in the offspec cyan")
    assertEqual(select(3, k.eq.text:GetTextColor()), TONE.offspec.b, "and the difference with the spec's name")
    assertTrue(k.offer:IsShown()); assertEqual(textOf(k.offer.label), "Offer")
    assertTrue(NS.Window.TooltipOf(p.panel.note)[2]:find("off%-spec upgrades and equals") ~= nil, "the order note names the tier")
end)
