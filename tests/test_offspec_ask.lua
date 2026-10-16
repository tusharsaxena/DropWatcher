-- tests/test_offspec_ask.lua — Ask, the whisper and the toast for off-spec (feedback-19 spec §2,
-- DW-O2): a drop your current spec cannot use but another spec of your class can (eval.offSpec,
-- modules/OffSpec.lua) is askable with its own template, `askOffSpec`. Case by case: the template's
-- pick (main spec, then off-spec, then transmog), its default text and length, its settings row and
-- editor, {mygain} read from the off-spec result (OffSpec.EvalFor), the Ask button's tooltip, the
-- toast's third value and title, and auto-ask, where main spec always goes first.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local AXE  = "|cffa335ee|Hitem:212::|h[Venom-Etched Crescent]|h|r"
local BAG  = "|cffa335ee|Hitem:400::|h[Bag Mace]|h|r"
local BRAKK = "Player-1-0000000A"

local NONE = {}
local HOLY, PROT = 65, 66

local DEFAULT = "Hi {player}, if you don't need {item}, could I have it for my off-spec? It'd be +{mygain} for me. No worries if not!"

local function with(t, over)
    for k, v in pairs(over or {}) do
        if v == NONE then t[k] = nil else t[k] = v end
    end
    return t
end

-- The off-spec answer: Holy can use the Crescent, +20 over the 291 mace in your bags.
local function off(over)
    return with({ specID = HOLY, mainSpecID = PROT, verdict = "upgrade", ilvlDelta = 20,
        baseline = { link = BAG, ilvl = 291, bag = 0, bagSlot = 3 }, baselineSlot = 16, reasons = {} }, over)
end

-- Protection cannot use it (an Intellect weapon); Holy can.
local function cantMain(o)
    return { verdict = "cantUse", reasons = { { key = "primaryStat" } }, offSpec = o }
end

local function drop(over)
    return with({
        id = 1, link = AXE, itemID = 212, isMine = false,
        looter = { name = "Brakk", guid = BRAKK, classFile = "WARRIOR" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_WEAPON", quality = 4 },
        me = cantMain(off()),
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }, over)
end

local function addon()
    local NS, _, m = T.newAddon()
    m.specNames[HOLY], m.specNames[PROT] = "Holy", "Protection"
    return NS, m
end

-- ── the template an ask fills ───────────────────────────────────────────────────────────────

test("off-spec ask: AskTemplate takes the main spec, then the off-spec, then transmog", function()
    local M = addon().Messaging
    local function rec(me, known) return { me = me, facts = { transmogKnown = known } } end
    assertEqual(M.AskTemplate(rec({ verdict = "upgrade", ilvlDelta = 5, offSpec = off() }, false), true), "ask",
        "a main-spec gain asks plainly")
    assertEqual(M.AskTemplate(rec({ verdict = "sidegrade" }, nil), false), "ask")
    assertEqual(M.AskTemplate(rec(cantMain(off()), nil), false), "askOffSpec", "an off-spec upgrade")
    assertEqual(M.AskTemplate(rec(cantMain(off({ verdict = "sidegrade", ilvlDelta = 1 })), nil), false), "askOffSpec")
    assertEqual(M.AskTemplate(rec(cantMain(off()), false), true), "askOffSpec", "over transmog")
    assertEqual(M.AskTemplate(rec(cantMain(off({ verdict = "downgrade", ilvlDelta = -4 })), false), true), "transmog",
        "an off-spec downgrade is no gain: the transmog fallback")
    assertNil(M.AskTemplate(rec(cantMain(off({ verdict = "downgrade", ilvlDelta = -4 })), nil), true))
    assertNil(M.AskTemplate(rec(cantMain(nil), nil), true), "no off-spec, no ask")
    assertNil(M.AskTemplate(rec({ verdict = "downgrade", offSpec = off() }, nil), false),
        "an off-spec part counts only on a Can't use")
end)

test("off-spec ask: the template is listed after transmog, with its default text inside the limit", function()
    local NS = addon()
    local M, C = NS.Messaging, NS.Constants
    assertEqual(table.concat(C.MESSAGE_TEMPLATES, ","), "ask,transmog,askOffSpec,offer,announce")
    assertEqual(table.concat(C.MESSAGE_KINDS, ","), "ask,offer,announce", "no new kind: it is sent as an ask")
    local default = NS.C.PROFILE.messages.templates.askOffSpec
    assertEqual(default, DEFAULT)
    assertTrue(#default <= C.MESSAGE_MAX_LEN, #default .. " bytes")
    assertEqual(M.Template("askOffSpec", nil), default)
    assertEqual(M.Template("askOffSpec", { askOffSpec = "os {item}?" }), "os {item}?")
    local req = { kind = "ask", target = "Brakk", dropID = 1, template = "askOffSpec", ctx = { player = "Brakk", item = "[Axe]", mygain = 20 } }
    local res = M.Request(M.NewBook(), req, { canSend = true, templates = {} })
    assertEqual(res.action, "send")
    assertEqual(res.ask.text, "Hi Brakk, if you don't need [Axe], could I have it for my off-spec? It'd be +20 for me. No worries if not!")
    assertEqual(res.ask.kind, "ask", "still an ask, under the ask's one-ask key")
end)

-- ── settings ────────────────────────────────────────────────────────────────────────────────

test("off-spec ask: its row sits after the transmog template on the Templates tab", function()
    local NS = T.bootAddon()
    assertEqual(NS.Setting("messages.templates.askOffSpec"), DEFAULT, "AceDB backfills the default")
    assertFalse(NS.SchemaRuntime.Set("messages.templates.askOffSpec", " "), "an empty template is refused")
    assertTrue(NS.SchemaRuntime.Set("messages.templates.askOffSpec", "os {item}?") ~= false)
    assertEqual(NS.Asks.Settings().templates.askOffSpec, "os {item}?")
    local order = {}
    for _, row in ipairs(NS.addon.Settings.Rows) do
        local leaf = row.path and row.path:match("^messages%.templates%.(.+)$")
        if leaf then order[#order + 1] = leaf end
    end
    assertEqual(table.concat(order, ","), "ask,transmog,askOffSpec,offer,announce")
    local row = NS.SchemaRuntime.FindRow("messages.templates.askOffSpec")
    assertEqual(row.label, "Ask for off-spec")
    assertEqual(row.maxLetters, NS.Constants.MESSAGE_MAX_LEN)
end)

test("off-spec ask: the editor names it and previews it over an off-spec drop", function()
    local E = addon().addon.Settings.Editors
    assertEqual(E.KIND_NAME.askOffSpec, "Ask for off-spec")
    assertEqual(E.TEMPLATE_LABEL.askOffSpec, "Ask for off-spec (whisper to the looter)")
    local plain = drop({ id = 1, me = { verdict = "upgrade", ilvlDelta = 4 } })
    local os = drop({ id = 2, looter = { name = "Lyra", guid = "G2" } })
    local newer = drop({ id = 3, looter = { name = "Kael", guid = "G3" }, me = cantMain(nil) })
    local r, who = E.PreviewSample("askOffSpec", { plain, os, newer })
    assertEqual(r.id, 2); assertEqual(who.name, "Lyra")
    local any = E.PreviewSample("askOffSpec", { plain })
    assertEqual(any.id, 1, "any other member's drop when none is an off-spec gain")
    assertNil(E.PreviewSample("askOffSpec", { drop({ isMine = true }) }), "never your own drop")
end)

test("off-spec ask: Reset templates speaks of five messages", function()
    local NS = addon()
    assertEqual(NS.L["Put the five messages back to the shipped wording."], "Put the five messages back to the shipped wording.")
    local src = assert(io.open("settings/PageEditors.lua", "rb")):read("*a")
    assertTrue(src:find("four messages", 1, true) == nil, "no four left in the Templates tab")
    assertTrue(src:find('L["Put the five messages back to the shipped wording."]', 1, true) ~= nil)
end)

-- ── the gain ────────────────────────────────────────────────────────────────────────────────

test("off-spec ask: EvalFor answers the off-spec result when it counts, else the eval itself", function()
    local OS = addon().OffSpec
    local o = off()
    local e = cantMain(o)
    assertTrue(OS.EvalFor(e) == o)
    local up = { verdict = "upgrade", ilvlDelta = 5, offSpec = o }
    assertTrue(OS.EvalFor(up) == up, "a main verdict that is not Can't use counts itself")
    local none = cantMain(nil)
    assertTrue(OS.EvalFor(none) == none)
    assertNil(OS.EvalFor(nil)); assertEqual(OS.EvalFor("x"), "x")
end)

test("off-spec ask: {mygain} reads the off-spec result, and an empty slot its words", function()
    local A = addon().Asks
    assertEqual(A.TokenContext("ask", drop(), { name = "Brakk" }).mygain, 20)
    local empty = drop({ me = cantMain(off({ ilvlDelta = NONE, baseline = NONE, reasons = { { key = "emptySlot" } } })) })
    assertEqual(A.TokenContext("ask", empty, { name = "Brakk" }).mygain, "an empty-slot upgrade")
    assertNil(A.TokenContext("ask", drop({ me = cantMain(nil) }), { name = "Brakk" }).mygain, "no off-spec, no gain")
    assertEqual(A.TokenContext("ask", drop({ them = cantMain(off({ ilvlDelta = 7 })) }), { name = "Brakk" }).gain, 7,
        "the looter's {gain} reads theirs the same way")
end)

-- ── the Ask button ──────────────────────────────────────────────────────────────────────────

test("off-spec ask: the Ask button fills askOffSpec, and its tooltip names the spec", function()
    local WC = addon().WindowCells
    local a = WC.Ask(drop(), "ready", nil)
    assertTrue(a.offered); assertEqual(a.template, "askOffSpec")
    assertEqual(a.tip[1], "Ask for off-spec")
    assertEqual(a.tip[2], "Ask for it for your Holy off-spec.")
    assertEqual(a.tip[#a.tip], "One ask per item per looter.")
    assertFalse(WC.Ask(drop({ me = cantMain(nil) }), "ready", nil).offered, "a plain Can't use has no ask")
    assertEqual(WC.Ask(drop({ me = { verdict = "upgrade", ilvlDelta = 5 } }), "ready", nil).tip[1], "Ask")
end)

-- ── the toast ───────────────────────────────────────────────────────────────────────────────

test("off-spec toast: Qualifies adds a third value, offSpec, and tests the off-spec gain", function()
    local Q = addon().Toast.Qualifies
    local ok, why, how = Q(drop(), 10)
    assertTrue(ok); assertNil(why); assertEqual(how, "offSpec")
    local ok2, why2, how2 = Q(drop({ me = { verdict = "upgrade", ilvlDelta = 19 } }), 10)
    assertTrue(ok2); assertNil(why2); assertNil(how2, "a main-spec upgrade has no third value")
    local _, small = Q(drop({ me = cantMain(off({ ilvlDelta = 3 })) }), 10)
    assertEqual(small, "gain", "the least gain on the off-spec difference")
    assertTrue(Q(drop({ me = cantMain(off({ ilvlDelta = NONE, baseline = NONE, reasons = { { key = "emptySlot" } } })) }), 50),
        "an off-spec empty slot clears any least gain")
    assertEqual(select(2, Q(drop({ me = cantMain(off({ verdict = "sidegrade", ilvlDelta = 1 })) }), 0)), "notUpgrade")
    assertEqual(select(2, Q(drop({ me = cantMain(nil) }), 0)), "notUpgrade")
    assertEqual(select(2, Q(drop({ trade = { state = "unknown" } }), 0)), "trade")
end)

test("off-spec toast: Compose titles it Off-spec upgrade for you (Holy)", function()
    local NS = addon()
    local t = NS.Toast.Compose(drop())
    assertEqual(t.title, "Off-spec upgrade for you (Holy)")
    assertEqual(t.me.tone, "offspec"); assertEqual(t.me.glyph, "▲")
    assertEqual(NS.Toast.Compose(drop({ me = { verdict = "upgrade", ilvlDelta = 19 } })).title, "Big upgrade for you")
end)

-- ── auto-ask ────────────────────────────────────────────────────────────────────────────────

test("off-spec auto-ask: DueAt takes an optional lag; the off-spec lag is 5 seconds", function()
    local AA = addon().AutoAsk
    assertEqual(AA.OFFSPEC_LAG, 5)
    assertEqual(AA.DueAt(100, nil, 10, AA.OFFSPEC_LAG), 115)
    assertEqual(AA.DueAt(100, 130, 10, 5), 145)
    assertEqual(AA.DueAt(100, nil, 10, nil), 110, "no lag")
    assertEqual(AA.DueAt(100, nil, 10, "x"), 110)
end)

local function party()
    local NS, _, m = T.enableAddon()
    m.specNames[HOLY], m.specNames[PROT] = "Holy", "Protection"
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    local byId = {}
    NS.LootFeed.Get = function(id) return byId[id] end
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    local function make(over)
        local d = drop(over)
        d.at = m.GetTime()
        byId[d.id] = d
        return d
    end
    return NS, m, make
end

local function added(NS, id) NS.addon:SendMessage(NS.MSG.DROP_ADDED, id) end

local function whispered(m)
    local out = {}
    for _, s in ipairs(m.chatSent) do
        if s.chatType == "WHISPER" then out[#out + 1] = s.text end
    end
    return out
end

test("off-spec auto-ask: an off-spec upgrade is asked for the lag after the delay, with its own template", function()
    local NS, m, make = party()
    make(); added(NS, 1)
    assertEqual(NS.AutoAsk.Stats().waiting, 1)
    m.advance(14.9)
    assertEqual(#whispered(m), 0, "not before the delay and the lag")
    m.advance(0.2)
    local w = whispered(m)
    assertEqual(#w, 1)
    assertTrue(w[1]:find("for my off-spec? It'd be +20 for me", 1, true) ~= nil, w[1])
    assertEqual(NS.Asks.StateOf("ask", "Brakk", 1), "sent", "filed as the drop's one ask")
end)

test("off-spec auto-ask: main spec goes first; an off-spec ask due while a main one waits is re-armed", function()
    local NS, m, make = party()
    make({ id = 1 }); added(NS, 1)                                     -- off-spec, due at 15
    m.advance(8)
    make({ id = 2, link = "|cffa335ee|Hitem:213::|h[Helm]|h|r", itemID = 213,
        me = { verdict = "upgrade", ilvlDelta = 12 } }); added(NS, 2)   -- main spec, due at 18
    assertEqual(NS.AutoAsk.Stats().waiting, 2)
    m.advance(7.5)
    assertEqual(#whispered(m), 0, "the off-spec ask waits for the main one")
    assertEqual(NS.AutoAsk.Stats().waiting, 2, "re-armed, not dropped")
    m.advance(3)
    local w = whispered(m)
    assertEqual(#w, 1)
    assertTrue(w[1]:find("[Helm]", 1, true) ~= nil and w[1]:find("off-spec", 1, true) == nil, w[1])
    m.advance(6)
    w = whispered(m)
    assertEqual(#w, 2, "then the off-spec one")
    assertTrue(w[2]:find("for my off-spec?", 1, true) ~= nil, w[2])
    local st = NS.AutoAsk.Stats()
    assertEqual(st.scheduled, 2); assertEqual(st.sent, 2); assertEqual(st.waiting, 0)
end)

test("off-spec auto-ask: the least gain applies to the off-spec difference", function()
    local NS, m, make = party()
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.minGain", 25))
    make(); added(NS, 1)
    assertEqual(NS.AutoAsk.Stats().waiting, 0, "+20 is under 25")
    m.advance(30)
    assertEqual(#whispered(m), 0)
end)
