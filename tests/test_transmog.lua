-- tests/test_transmog.lua — the transmog-known flag (design spec §4, DW-53): the Compat seam
-- (CanIMogIt when it is loaded, else C_TransmogCollection), the detail card's look chip, the ask
-- template it picks (NS.Messaging.AskTemplate: the plain ask, or the opt-in For transmog ask), the
-- Ask button that offers it, the messaging edge that sends it, its settings rows, test mode's
-- placeholders and the diagnostics line.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local CHEST = "|cffa335ee|Hitem:4001::::::::80:::::|h[Placeholder Robe]|h|r"
local BRAKK = "Player-1-0000000A"

local function chestDef(transmog)
    return { name = "Robe", quality = 4, ilvl = 600, equipLoc = "INVTYPE_CHEST", classID = 4,
        subClassID = 1, bindType = 1, stats = {}, transmog = transmog }
end

-- A CanIMogIt stand-in: `known` answers PlayerKnowsTransmog, `transmogable` IsTransmogable; each
-- method is called with the addon object as self, as `CanIMogIt:Method(link)` does.
local function cimi(known, transmogable)
    local seen = {}
    local obj = { seen = seen }
    obj.PlayerKnowsTransmog = function(self, link)
        assertTrue(self == obj, "called as a method")
        seen[#seen + 1] = link
        return known
    end
    obj.IsTransmogable = function() return transmogable ~= false end
    return obj
end

-- ── the Compat seam ─────────────────────────────────────────────────────────────────────────

test("transmog compat: CanIMogIt answers first when it is loaded, else the client's collection", function()
    local NS, _, m = T.newAddon()
    local Compat = NS.Compat
    m.addItem(CHEST, chestDef(false))
    assertFalse(Compat.PlayerHasTransmog(CHEST), "the client says not collected")
    assertEqual(Compat.TransmogSource(), "C_TransmogCollection")
    m.CanIMogIt = cimi(true)
    assertTrue(Compat.PlayerHasTransmog(CHEST), "CanIMogIt knows it from another source")
    assertEqual(m.CanIMogIt.seen[1], CHEST)
    assertEqual(Compat.TransmogSource(), "CanIMogIt")
    m.CanIMogIt = cimi(false)
    assertFalse(Compat.PlayerHasTransmog(CHEST))
end)

test("transmog compat: CanIMogIt's no-appearance answer is nil; a raise or a non-boolean falls back", function()
    local NS, _, m = T.newAddon()
    local Compat = NS.Compat
    m.addItem(CHEST, chestDef(true))
    m.CanIMogIt = cimi(false, false)
    assertNil(Compat.PlayerHasTransmog(CHEST), "nothing to collect")
    m.CanIMogIt = { PlayerKnowsTransmog = function() error("boom") end }
    assertTrue(Compat.PlayerHasTransmog(CHEST), "a raise falls back to the client")
    m.CanIMogIt = { PlayerKnowsTransmog = function() return "yes" end }
    assertTrue(Compat.PlayerHasTransmog(CHEST), "a non-boolean falls back to the client")
    m.CanIMogIt = "not a table"
    assertTrue(Compat.PlayerHasTransmog(CHEST))
    m.CanIMogIt, m.C_TransmogCollection = nil, nil
    assertNil(Compat.PlayerHasTransmog(CHEST), "no source answers")
    assertEqual(Compat.TransmogSource(), "none")
    assertNil(Compat.PlayerHasTransmog(nil))
end)

test("transmog facts: the item facts read the look through CanIMogIt when it is loaded", function()
    local NS, _, m = T.newAddon()
    m.addItem(CHEST, chestDef(false))
    m.CanIMogIt = cimi(true)
    assertTrue(NS.ItemFacts.Read(CHEST).transmogKnown)
end)

-- ── the template an ask fills ───────────────────────────────────────────────────────────────

local function rec(verdict, known)
    return { me = { verdict = verdict }, facts = { transmogKnown = known } }
end

test("transmog template: the plain ask for a gain; For transmog only when on and the look is missing", function()
    local M = T.newAddon().Messaging
    assertEqual(M.AskTemplate(rec("upgrade", false), true), "ask", "a gain asks plainly")
    assertEqual(M.AskTemplate(rec("sidegrade", nil), false), "ask")
    assertEqual(M.AskTemplate(rec("downgrade", false), true), "transmog")
    assertEqual(M.AskTemplate(rec("cantUse", false), true), "transmog")
    assertNil(M.AskTemplate(rec("downgrade", false), false), "off by default")
    assertNil(M.AskTemplate(rec("downgrade", true), true), "already collected")
    assertNil(M.AskTemplate(rec("downgrade", nil), true), "not known is not missing")
    assertNil(M.AskTemplate({ me = { verdict = "downgrade" } }, true), "no facts")
    assertNil(M.AskTemplate(nil, true))
end)

test("transmog template: its default text, the owner's own, and a request that names it", function()
    local NS = T.newAddon()
    local M, C = NS.Messaging, NS.Constants
    assertEqual(table.concat(C.MESSAGE_TEMPLATES, ","), "ask,transmog,offer,announce")
    local default = NS.C.PROFILE.messages.templates.transmog
    assertTrue(default:find("for transmog", 1, true) ~= nil)
    assertTrue(#default <= C.MESSAGE_MAX_LEN)
    assertEqual(M.Template("transmog", nil), default)
    assertEqual(M.Template("transmog", { transmog = "mog {item}?" }), "mog {item}?")
    assertNil(M.Template("nope", nil))
    local book = M.NewBook()
    local req = { kind = "ask", target = "Brakk", dropID = 1, template = "transmog", ctx = { player = "Brakk", item = "[Robe]" } }
    local res = M.Request(book, req, { canSend = true, templates = { transmog = "{player}: {item} for mog?" } })
    assertEqual(res.action, "send")
    assertEqual(res.ask.text, "Brakk: [Robe] for mog?")
    assertEqual(res.ask.kind, "ask", "still an ask, under the ask's key")
    local res2 = M.Request(M.NewBook(), { kind = "ask", target = "B", dropID = 2, template = "bogus" },
        { canSend = true, templates = { ask = "plain" } })
    assertEqual(res2.ask.text, "plain", "an unknown template falls back to the kind's")
end)

-- ── the Ask button and the detail card ──────────────────────────────────────────────────────

local function drop(over)
    local d = {
        id = 1, link = CHEST, isMine = false, looter = { name = "Seta-Realm", guid = BRAKK, classFile = "PRIEST" },
        facts = { ilvl = 600, equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 1, bindType = 1, transmogKnown = false },
        me = { verdict = "downgrade", ilvlDelta = -4, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {}, basis = "rule" },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local function texts(list)
    local out = {}
    for _, c in ipairs(list) do out[#out + 1] = c.text end
    return table.concat(out, ",")
end

test("transmog card: the header's look chip says New look, Look known or nothing", function()
    local DC = T.newAddon().DetailCells
    local missing = DC.Chips(drop())
    assertEqual(texts(missing), "Chest,Cloth,BoP,600,New look")
    assertEqual(missing[5].tone, "good")
    assertTrue(missing[5].tip[2]:find("not collected", 1, true) ~= nil)
    local known = DC.Chips(drop({ facts = { ilvl = 600, equipLoc = "INVTYPE_CHEST", transmogKnown = true } }))
    assertEqual(texts(known), "Chest,600,Look known")
    assertEqual(known[3].tone, "muted")
    local ring = DC.Chips(drop({ facts = { ilvl = 600, equipLoc = "INVTYPE_FINGER" } }))
    assertEqual(texts(ring), "Finger,Jewelry,600", "no appearance, no chip")
end)

test("transmog ask: offered for a missing look only with transmogAsk on, with its own tooltip", function()
    local NS = T.newAddon()
    local WC = NS.WindowCells
    local off = WC.Ask(drop(), "ready", nil)
    assertFalse(off.offered, "opt-in")
    local on = WC.Ask(drop(), "ready", nil, true)
    assertTrue(on.offered); assertEqual(on.template, "transmog")
    assertEqual(on.tip[1], "Ask for transmog")
    assertTrue(on.tip[2]:find("not collected its look", 1, true) ~= nil)
    local upgrade = WC.Ask(drop({ me = { verdict = "upgrade", ilvlDelta = 5 } }), "ready", nil, true)
    assertEqual(upgrade.template, "ask"); assertEqual(upgrade.tip[1], "Ask")
    assertFalse(WC.Ask(drop({ facts = { transmogKnown = true } }), "ready", nil, true).offered)
    assertFalse(WC.Ask(drop({ trade = { state = "no", reasonKey = "legacy" } }), "ready", nil, true).offered,
        "never for an item its looter can't trade")
    local acts = NS.DetailCells.Actions(drop(), { askState = "ready", now = 1, transmogAsk = true })
    assertEqual(acts[1].key, "ask"); assertTrue(acts[1].enabled)
    assertTrue(acts[2].enabled, "Edit message too")
    assertFalse(NS.DetailCells.Actions(drop(), { askState = "ready", now = 1 })[1].enabled)
end)

-- ── the messaging edge ──────────────────────────────────────────────────────────────────────

local function row(guid, name, classFile)
    return { guid = guid, name = name, class = classFile, classFile = classFile }
end

-- An enabled party with Brakk; the player wears a 610 chest, so a 600 chest is a downgrade.
local function party(transmog)
    local NS, _, m = T.enableAddon()
    local worn = "|cffa335ee|Hitem:4002::::::::80:::::|h[Worn Robe]|h|r"
    m.addItem(worn, chestDef(true))
    m.items[worn].ilvl = 610
    m.inventory.player[5] = worn
    m.addItem(CHEST, chestDef(transmog))
    m.setGroup({ row(BRAKK, "Brakk", "WARRIOR") })
    NS.Roster.Refresh("test")
    local id = NS.LootFeed.Add(CHEST, "Brakk")
    m.advance(0)
    return NS, m, id
end

test("transmog edge: with transmogAsk on, an ask for a missing look sends the For transmog text", function()
    local NS, m, id = party(false)
    local r = NS.LootFeed.Get(id)
    assertFalse(r.facts.transmogKnown)
    assertTrue(r.me.verdict ~= "upgrade" and r.me.verdict ~= "sidegrade", "no gain for you: " .. tostring(r.me.verdict))
    assertEqual(NS.Asks.TemplateFor("ask", r), "ask", "off: the plain ask")
    NS.SchemaRuntime.Set("messages.transmogAsk", true)
    assertEqual(NS.Asks.TemplateFor("ask", r), "transmog")
    assertEqual(NS.Asks.TemplateFor("offer", r), "offer")
    local preview = NS.Asks.Preview("ask", "Brakk", id)
    assertTrue(preview.text:find("for transmog", 1, true) ~= nil, preview.text)
    assertEqual((NS.Asks.Request("ask", "Brakk", id)), "sent")
    assertTrue(m.chatSent[1].text:find("could I have it for transmog", 1, true) ~= nil, m.chatSent[1].text)
    assertEqual(NS.Asks.StateOf("ask", "Brakk", id), "sent", "filed as an ask")
end)

test("transmog edge: a collected look keeps the plain ask", function()
    local NS, m, id = party(true)
    NS.SchemaRuntime.Set("messages.transmogAsk", true)
    assertEqual(NS.Asks.TemplateFor("ask", NS.LootFeed.Get(id)), "ask")
    NS.Asks.Request("ask", "Brakk", id)
    assertTrue(m.chatSent[1].text:find("for transmog", 1, true) == nil)
end)

-- ── settings, test mode and the diagnostics ─────────────────────────────────────────────────

test("transmog settings: the template and the opt-in are rows, the opt-in off by default", function()
    local NS = T.bootAddon()
    assertFalse(NS.Setting("messages.transmogAsk"))
    assertEqual(NS.Setting("messages.templates.transmog"), NS.C.PROFILE.messages.templates.transmog)
    assertTrue(NS.SchemaRuntime.Set("messages.transmogAsk", true) ~= false)
    assertTrue(NS.Setting("messages.transmogAsk"))
    assertFalse(NS.SchemaRuntime.Set("messages.templates.transmog", " "), "an empty template is refused")
    assertTrue(NS.SchemaRuntime.Set("messages.templates.transmog", "mog {item}?") ~= false)
    assertEqual(NS.Asks.Settings().templates.transmog, "mog {item}?")
    local E = NS.addon.Settings.Editors
    assertEqual(E.KIND_NAME.transmog, "Ask for transmog")
    assertTrue(E.TEMPLATE_LABEL.transmog ~= nil)
end)

test("transmog settings: the preview sample is a drop whose look you have not collected", function()
    local E = T.newAddon().addon.Settings.Editors
    local known = drop({ id = 1, facts = { transmogKnown = true } })
    local missing = drop({ id = 2, looter = { name = "Lyra", guid = "G2" } })
    local newer = drop({ id = 3, looter = { name = "Kael", guid = "G3" }, facts = { transmogKnown = true } })
    local r, who = E.PreviewSample("transmog", { known, missing, newer })
    assertEqual(r.id, 2); assertEqual(who.name, "Lyra")
    local any = E.PreviewSample("transmog", { known })
    assertEqual(any.id, 1, "any other member's drop when none lacks its look")
end)

test("transmog test mode: one sample's look is collected and one's is not", function()
    local NS = T.newAddon()
    local seen, pool = {}, {}
    for i, loc in ipairs({ "INVTYPE_HEAD", "INVTYPE_WEAPON", "INVTYPE_FINGER" }) do
        pool[i] = { link = ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Real]|h|r"):format(7700 + i), equipLoc = loc, ilvl = 300 }
    end
    local src = NS.TestData.Source(pool, pool, function(e) return { ilvl = e.ilvl, equipLoc = e.equipLoc } end)
    for _, s in ipairs(NS.TestMode.Placeholders(1000, { name = "Tester", guid = "P1", isSelf = true }, src)) do
        if type(s.facts) == "table" and s.facts.transmogKnown ~= nil then seen[s.facts.transmogKnown] = true end
    end
    assertTrue(seen[true] and seen[false])
end)

test("transmog diagnostics: the integrations name the look's source, messaging the opt-in", function()
    local NS, _, m = T.enableAddon()
    m.CanIMogIt = cimi(true)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("transmog: source=CanIMogIt", 1, true) ~= nil, text)
    assertTrue(text:find("transmogAsk=false", 1, true) ~= nil)
    assertTrue(text:find("transmog=", 1, true) ~= nil, "its template's length")
end)
