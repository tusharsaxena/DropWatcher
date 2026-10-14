-- tests/test_offer_panel.lua — the Offer panel (design spec §11.4, board 04) opened from your own
-- drop's Offer on the Drops tab (feedback-5 spec §2 and §3), built headless under the mock: docked
-- beside the window (full or compact) on the side with room, the candidates ranked with their Their
-- eq cells in the Drops table's Them look (feedback-7 spec §0: no class bar, alternating rows, no
-- Trade button), every part's reason tooltip, Offer and Announce to group through their host
-- handlers, the Edit message box, closing; then the host handlers Post my tradeables, Offer, Announce
-- and Trade.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRACERS = "|cffa335ee|Hitem:401::|h[Bracers of the Tide]|h|r"
local RING = "|cffa335ee|Hitem:402::|h[Band of Embers]|h|r"
local TRINKET = "|cffa335ee|Hitem:403::|h[Idol of Storms]|h|r"
local BOOTS = "|cffa335ee|Hitem:404::|h[Treads of Dawn]|h|r"

local NONE = {}
local NOW = 1000

local function cand(name, classFile, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = status, eval = eval }
end

-- Board 04's first row: your bracers, a downgrade for you, 1:47:12 left on the item's own timer,
-- an upgrade for Seta (+14) and Butterz (+6), equal for Littlewolf, unusable for Uniquerogue and
-- one member still being checked.
local function candidates()
    local list = {
        cand("Seta", "PRIEST", "ready", { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 291 }, reasons = {} }),
        cand("Butterz", "MAGE", "ready", { verdict = "upgrade", ilvlDelta = 6, baseline = { ilvl = 299 }, reasons = {} }),
        cand("Littlewolf", "ROGUE", "ready", { verdict = "sidegrade", ilvlDelta = 0, baseline = { ilvl = 305 }, reasons = {} }),
        cand("Uniquerogue", "ROGUE", "ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }),
        cand("Fifth", "DRUID", "checking"),
    }
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

local function drop(over)
    local d = {
        id = 1, at = NOW - 700, link = BRACERS, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 305, equipLoc = "INVTYPE_WRIST", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6432 }, expiresAt = NOW + 6432 },
        candidates = candidates(),
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function groupOf(key, at, ids, roster)
    return { key = key, label = key, kind = "encounter", at = at, drops = ids, roster = roster,
        instance = "Zul'Aman", difficulty = "Heroic", seenBy = "Me-Realm", seenByClass = "PALADIN" }
end

local ROSTER = { { name = "Me", class = "PALADIN", me = true }, { name = "Seta", class = "PRIEST" } }

local function seed(NS, drops, groups)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    NS.LootFeed.Groups = function() return groups or {} end
end

-- Board 04's four rows.
local function boardDrops()
    return {
        drop(),
        drop({ id = 2, at = NOW - 1800, link = RING, facts = { ilvl = 298, equipLoc = "INVTYPE_FINGER", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 3, reasons = {} },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 5405 } }),
        drop({ id = 3, at = NOW - 2000, link = TRINKET, facts = { ilvl = 305, equipLoc = "INVTYPE_TRINKET", quality = 4 },
            me = { verdict = "downgrade", ilvlDelta = -11, reasons = {} },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 },
            candidates = { x = cand("Littlewolf", "ROGUE", "ready", { verdict = "upgrade", ilvlDelta = 9, baseline = { ilvl = 296 }, reasons = {} }) } }),
        drop({ id = 4, at = NOW - 100, link = BOOTS, facts = { ilvl = 311, equipLoc = "INVTYPE_FEET", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 6, reasons = {} },
            trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
    }
end

-- Your four drops on Drops (board 04's rows), every View value shown.
local function shownMine(compact)
    local NS, _, m = T.enableAddon()
    m.__now = NOW
    seed(NS, boardDrops(), { groupOf("Den of Nalorakk", NOW - 3000, { 1, 2, 3, 4 }, ROSTER) })
    NS.Asks.StateOf = function() return "ready" end
    NS.WindowFilterBar.Set("group", "view", "all")
    if compact then NS.SetWindowMode("compact") end
    NS.ShowWindow()
    NS.Window.SelectTab("group")
    return NS, NS.WindowGroup.Drawn(), m
end

local function rowFor(drawn, id)
    for _, r in ipairs(drawn.rows) do if r.dropId == id then return r end end
end

local function textOf(region) return region and region:GetText() end

-- A row's (or a compact card's) Offer button.
local function offerOf(row) return row.cells.actions and row.cells.actions.ask or row.ask end

-- ── the Offer panel ─────────────────────────────────────────────────────────────────────────

local function openPanel()
    local NS, drawn, m = shownMine()
    local b = offerOf(rowFor(drawn, 1))
    assertTrue(b.offer, "your own drop's Actions is Offer")
    b:__fire("OnClick")
    return NS, NS.OfferPanel.Drawn(), m
end

-- A Their eq cell as drawn: level, glyph and difference (or word), space-joined.
local function eqOf(row)
    local parts = {}
    for _, fs in ipairs({ row.eq.level, row.eq.glyph, row.eq.text }) do
        local t = textOf(fs)
        if t and t ~= "" then parts[#parts + 1] = t end
    end
    return table.concat(parts, " ")
end

test("offer panel: Offer opens it docked right, the candidates ranked with Their eq in the Them look", function()
    local NS, p = openPanel()
    assertTrue(NS.OfferPanel.IsShown()); assertEqual(NS.OfferPanel.DropId(), 1)
    assertEqual(p.panel.dock, "right")
    assertEqual(textOf(p.panel.name.text), "Bracers of the Tide")
    assertEqual(textOf(p.panel.line.text), "You: -5 ilvl · 305 · Trade window 1:47:12")
    assertEqual(#p.rows, 5)
    local cells = {}
    for i, r in ipairs(p.rows) do cells[i] = textOf(r.member.text) .. " " .. eqOf(r) end
    assertEqual(table.concat(cells, ","), "Seta 291 ▲ 14,Butterz 299 ▲ 6,Littlewolf 305 ≈ 0,Uniquerogue Can't use,Fifth …")
    local r1, TONE = p.rows[1], NS.Constants.TONE
    assertEqual(select(2, r1.eq.glyph:GetTextColor()), TONE.good.g, "the glyph in the verdict's tone")
    assertEqual(select(2, r1.eq.text:GetTextColor()), TONE.good.g, "and the difference")
    assertEqual(r1.eq.glyph.__font[1], NS.Constants.FONT_MONO, "the glyph in the monospace face")
    assertTrue(r1.offer:IsShown()); assertTrue(r1.trade == nil and r1.pill == nil, "no Trade button and no pill")
    local r4 = p.rows[4]
    assertTrue(r4.offer:IsShown()); assertTrue(r4.dash == nil, "no dash (feedback-11 spec §1)")
    assertEqual(textOf(r4.offer.label), "No action"); assertFalse(r4.offer:IsEnabled()); assertEqual(r4.offer.tone, "bad")
    assertEqual(r4.offer.art:GetTexture(), NS.Icon("ban"))
    assertEqual(NS.Window.TooltipOf(r4.offer)[1], "No action")
    assertEqual(NS.Window.TooltipOf(r4.offer)[2], "Offer is shown for members it is an upgrade or an equal for.")
    assertEqual(textOf(p.panel.note.text), "5 members · sorted by gain")
    local heads = {}
    for key, h in pairs(p.panel.heads) do heads[#heads + 1] = key .. "=" .. textOf(h.text) end
    table.sort(heads)
    assertEqual(table.concat(heads, ","), "actions=Actions,eq=Their eq,member=Member")
end)

test("offer panel: no class bar; every second row striped as the main window's; the name in its class color", function()
    local NS, p = openPanel()
    for i, r in ipairs(p.rows) do
        assertEqual(r.stripe:IsShown(), i % 2 == 0, "row " .. i)
        assertEqual(r.stripe.__layer, "BACKGROUND", "a stripe behind the row, not a bar at its start")
    end
    local r, g, b = NS.Compat.ClassColor("PRIEST")
    assertEqual(table.concat({ p.rows[1].member.text:GetTextColor() }, ",", 1, 3), table.concat({ r, g, b }, ","))
end)

test("offer panel: each member's Offer is cyan, Offered yellow, Retry red; Announce to group unchanged", function()
    local NS, p = openPanel()
    local TONE = NS.Constants.TONE
    local b = p.rows[1].offer
    assertEqual(textOf(b.label), "Offer"); assertEqual(b.tone, "cyan")
    assertTrue(b.art:IsShown() and b.art:GetTexture() == NS.Icon("external-link"), "Offer wears external-link (feedback-10 spec §1)")
    assertEqual(b:GetWidth(), NS.Constants.WINDOW.PANEL_BTN_W)
    local ann = p.panel.announce
    assertTrue(ann.art:IsShown() and ann.art:GetTexture() == NS.Icon("speech-bubble"), "Announce to group keeps its mark")
    assertEqual(select(3, b.label:GetTextColor()), TONE.cyan.b)
    assertEqual(p.panel.announce.tone, "red", "Announce keeps its red (feedback-6 spec §2)")
    NS.Asks.StateOf = function(kind) return kind == "offer" and "sent" or "ready" end
    NS.Window.Refresh()
    b = NS.OfferPanel.Drawn().rows[1].offer
    assertEqual(textOf(b.label), "Offered"); assertEqual(b.tone, "yellow")
    assertTrue(b.art:IsShown() and b.art:GetTexture() == NS.Icon("confirm"), "Offered wears confirm")
    NS.Asks.StateOf = function(kind) return kind == "offer" and "failed" or "ready" end
    NS.Window.Refresh()
    b = NS.OfferPanel.Drawn().rows[1].offer
    assertEqual(textOf(b.label), "Retry"); assertEqual(b.tone, "red", "Retry stays red")
end)

test("offer panel: every part has a reason tooltip; Their eq's holds the old pill's explanation", function()
    local NS, p = openPanel()
    local W = NS.Window
    for _, r in ipairs(p.rows) do
        assertTrue(#W.TooltipOf(r.member) >= 2); assertTrue(#W.TooltipOf(r.eq) >= 2)
        for _, b in ipairs({ r.offer, r.dash }) do
            if b:IsShown() then assertTrue(#W.TooltipOf(b) >= 2) end
        end
    end
    local lines = W.TooltipOf(p.rows[1].eq)
    local tip = T.tipJoined(lines)
    assertEqual(lines[1], "For Seta: Upgrade")
    assertTrue(NS.TipMarks.IsGrid(lines[2]), "the worn gear as a grid (feedback-7 spec §3)")
    assertTrue(tip:find("An upgrade for them", 1, true) ~= nil, tip)
    assertTrue(W.TooltipOf(p.rows[5].eq)[1] == "Fifth: Checking")
    assertTrue(table.concat(W.TooltipOf(p.panel.heads.actions), " "):find("Trade", 1, true) == nil, "no Trade sentence")
    assertTrue(#W.TooltipOf(p.panel.line) >= 3); assertTrue(#W.TooltipOf(p.panel.announce) >= 2)
    for _, h in pairs(p.panel.heads) do assertTrue(#W.TooltipOf(h) >= 2) end
end)

test("offer panel: Offer whispers through the shared handler", function()
    local NS, p = openPanel()
    local calls = {}
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, target, id }; return "sent" end
    p.rows[1].offer:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "offer,Seta-Realm,1")
end)

test("offer panel: Their eq shows both worn items from the member's inspect read", function()
    local NS, _, m = shownMine()
    local OLD1, OLD2 = "|cffa335ee|Hitem:300::|h[Old Band]|h|r", "|cffa335ee|Hitem:301::|h[Older Band]|h|r"
    local d = NS.LootFeed.Get(2)
    d.me = { verdict = "downgrade", ilvlDelta = -3, reasons = {} }
    d.candidates = { x = cand("Butterz", "MAGE", "ready", { verdict = "upgrade", ilvlDelta = 6, baseline = { link = OLD2, ilvl = 292 }, reasons = {} }) }
    NS.Inspect.Get = function(guid)
        if guid ~= "Player-1-Butterz" then return nil end
        return { status = "fresh", at = NOW - 30, gear = { [11] = { link = OLD1, ilvl = 308 }, [12] = { link = OLD2, ilvl = 292 } } }
    end
    m.__now = NOW
    NS.OfferPanel.Open(2)
    local r = NS.OfferPanel.Drawn().rows[1]
    assertTrue(r.eq.icons[1]:IsShown() and r.eq.icons[2]:IsShown(), "both rings")
    assertEqual(eqOf(r), "308/292 ▲ 6")
    assertTrue(T.tipJoined(NS.Window.TooltipOf(r.eq)):find("Inspected 30s ago.", 1, true) ~= nil)
end)

test("offer panel: opening an upgrade for you reveals who it would help on its row", function()
    local NS, drawn, m = shownMine()
    assertEqual(textOf(rowFor(drawn, 2).cells.them.text), "Hidden")
    offerOf(rowFor(drawn, 2)):__fire("OnClick")
    assertTrue(NS.WindowOwn.IsRevealed(2))
    m.advance(0)
    assertEqual(textOf(rowFor(NS.WindowGroup.Drawn(), 2).cells.them.text), "Upgrade for 2")
end)

test("offer panel: the close mark closes it, and it closes itself when its drop is gone", function()
    local NS, p = openPanel()
    NS.OfferPanel.Close()
    assertFalse(NS.OfferPanel.IsShown()); assertTrue(NS.State.offerPanel == nil)
    NS.OfferPanel.Open(1)
    assertTrue(NS.OfferPanel.IsShown())
    seed(NS, {})
    NS.Window.Refresh()
    assertFalse(NS.OfferPanel.IsShown())
    assertTrue(p.panel.closeButton ~= nil)
    assertTrue(NS.OfferPanel.Open(99) == nil, "no such drop")
end)

test("offer panel: minimizing the window closes the panel and the Edit message box", function()
    local NS = openPanel()
    assertTrue(NS.OfferPanel.IsShown())
    local e = NS.DetailCard.OpenEditor(1)
    assertTrue(e:IsShown())
    NS.Window.SetMinimized(true)
    assertFalse(NS.OfferPanel.IsShown(), "no panel docked beside a title bar")
    assertTrue(NS.State.offerPanel == nil)
    assertFalse(e:IsShown(), "no editor over a title bar")
    NS.Window.SetMinimized(false)
    assertFalse(NS.OfferPanel.IsShown(), "the expand does not bring it back by itself")
end)

test("offer panel: with Edit before sending on, Offer and Announce open the box for their kind", function()
    local NS, p = openPanel()
    local calls = {}
    NS.Asks.Preview = function(kind, target) return { text = kind .. " to " .. tostring(target), length = 10 } end
    NS.Asks.Press = function(kind, target, id, opts)
        calls[#calls + 1] = { kind, tostring(target), id, opts and opts.text or "-" }
        return "sent"
    end
    NS.SchemaRuntime.Set("messages.editFirst", true)
    p.rows[1].offer:__fire("OnClick")
    local e = NS.DetailCard.Editor()
    assertTrue(e:IsShown()); assertEqual(#calls, 0)
    assertEqual(textOf(e.title), "Edit offer to Seta")
    assertEqual(e.box:GetText(), "offer to " .. p.rows[1].offer.target)
    e.send:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "offer," .. p.rows[1].offer.target .. ",1,offer to " .. p.rows[1].offer.target)
    p.panel.announce:__fire("OnClick")
    assertEqual(textOf(e.title), "Edit the announcement")
    e.box:SetText("Bracers up for grabs")
    e.box:__fire("OnTextChanged")
    e.send:__fire("OnClick")
    assertEqual(table.concat(calls[2], ","), "announce,nil,1,Bracers up for grabs")
end)

test("offer panel: Announce to group announces the drop", function()
    local NS, p = openPanel()
    local calls = {}
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, tostring(target), id }; return "sent" end
    p.panel.announce:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "announce,nil,1")
end)

-- ── the host handlers ───────────────────────────────────────────────────────────────────────

test("handlers: Post my tradeables announces every tradeable drop of yours, line by line", function()
    local NS, _, m = shownMine()
    local sent = {}
    NS.Asks.Request = function(kind, target, id, opts) sent[#sent + 1] = { kind = kind, target = target, id = id, text = opts.text }; return "sent" end
    NS.WindowGroup.Drawn().pane.summary.post:__fire("OnClick")
    assertEqual(#sent, 1)
    assertEqual(sent[1].kind, "announce"); assertTrue(sent[1].target == nil)
    assertEqual(sent[1].text, "Up for trade, whisper me: " .. BRACERS .. " " .. RING .. " " .. TRINKET)
    assertEqual(sent[1].id, "post:1:1")
    assertEqual(NS.PostTradeables(), 1)
    assertEqual(sent[2].id, "post:2:1", "each post files its lines under a key of its own")
    seed(NS, {})
    assertEqual(NS.PostTradeables(), 0)
    assertTrue(m.prints[#m.prints]:find("Nothing to post") ~= nil)
end)

test("handlers: Post my tradeables to a stored PARTY while solo says not announced and sends nothing", function()
    local NS, _, m = shownMine()
    NS.db.profile.messages = { announceChannel = "PARTY" }
    m.setGroup({})
    assertEqual(NS.PostTradeables(), 0)
    assertEqual(#m.chatSent, 0)
    assertTrue(m.prints[#m.prints]:find("Not announced: You are not in a group", 1, true) ~= nil)
end)

test("handlers: Offer and Announce say why they did nothing", function()
    local NS, _, m = shownMine()
    NS.Asks.Press = function() return "refused", "alreadyAsked" end
    NS.PressOffer(1, "Seta-Realm")
    assertTrue(m.prints[#m.prints]:find("You already offered it to Seta%-Realm") ~= nil)
    NS.PressAnnounce(1)
    assertTrue(m.prints[#m.prints]:find("You already announced it") ~= nil)
    assertEqual(select(2, NS.PressOffer(99, "Seta-Realm")), "noDrop")
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(select(2, NS.PressAnnounce(1)), "disabled")
    assertEqual(NS.PostTradeables(), 0)
end)

-- ── beside the compact window (compact spec §3) ─────────────────────────────────────────────

test("offer panel: it keeps its own least height beside the compact window", function()
    local NS = T.newAddon()
    local K = NS.Constants.WINDOW
    assertEqual(NS.OfferPanel.CompactHeight(220), K.OFFER_MIN_H)
    assertEqual(NS.OfferPanel.CompactHeight(700), 700)
    assertEqual(NS.OfferPanel.CompactHeight(nil), K.OFFER_MIN_H)
end)

local function placed(NS, m, left, right, height)
    local win = NS.Window.Frame()
    win.GetLeft = function() return left end
    win.GetRight = function() return right end
    win.GetHeight = function() return height end
    m.UIParent.GetWidth = function() return 1920 end
    return win
end

test("offer panel: Offer on a compact card opens it docked beside the compact window, its width unchanged", function()
    local NS, drawn, m = shownMine(true)
    local K = NS.Constants.WINDOW
    local win = placed(NS, m, 200, 580, 460)
    offerOf(rowFor(drawn, 1)):__fire("OnClick")
    local p = NS.OfferPanel.Drawn().panel
    assertTrue(NS.OfferPanel.IsShown()); assertEqual(NS.OfferPanel.DropId(), 1)
    assertEqual(p.dock, "right"); assertEqual(p:GetWidth(), K.OFFER_W)
    local point, rel, relPoint, x = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPLEFT>TOPRIGHT"); assertTrue(rel == win); assertEqual(x, K.DOCK_GAP)
    assertEqual(p:GetHeight(), 460, "as tall as the window")
    assertEqual(#NS.OfferPanel.Drawn().rows, 5)
end)

test("offer panel: beside the compact window it goes on the side with room, and floats centered when neither has", function()
    local NS, drawn, m = shownMine(true)
    local K = NS.Constants.WINDOW
    local win = placed(NS, m, 1500, 1880, 220)
    offerOf(rowFor(drawn, 1)):__fire("OnClick")
    local p = NS.OfferPanel.Drawn().panel
    assertEqual(p.dock, "left")
    local point, rel, relPoint, x = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT"); assertTrue(rel == win); assertEqual(x, -K.DOCK_GAP)
    assertEqual(p:GetHeight(), K.OFFER_MIN_H, "never shorter than its least height")
    m.UIParent.GetWidth = function() return 800 end
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 580 end
    NS.Window.Refresh()
    assertEqual(p.dock, "float")
    point, rel, relPoint = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOP>TOP"); assertTrue(rel == win)
    NS.SetWindowMode("full")
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 1200 end
    m.UIParent.GetWidth = function() return 1920 end
    NS.Window.Refresh()
    assertEqual(p.dock, "right")
    assertEqual(select(2, p:GetPoint(2)), win, "the full layout docks top and bottom again")
end)
