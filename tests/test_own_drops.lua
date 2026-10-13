-- tests/test_own_drops.lua — your own drops on the Drops tab (feedback-5 spec §2, DW-E2):
-- always listed (`feed.showOwn` retired); Trade counts the members a drop upgrades (`Yes (2)`); Them
-- reads `(Details)` (renamed from `(Multiple)`, feedback-6 spec §3) with each upgrade ranked by gain in
-- the tooltip; the keep? rule hides both until the Offer panel is opened; Actions is Offer, toned by the furthest offer sent.
-- The pure composers (modules/MineCells.lua), the reveal state and click (modules/WindowOwn.lua),
-- then the table, the detail card and the compact card painted headless.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local NONE = {}

local function cand(name, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = "MAGE", status = status, eval = eval }
end

local function up(gain, base)
    return { verdict = "upgrade", ilvlDelta = gain, baseline = base, reasons = {} }
end

-- Butterz +11 over her Bloodthorn Treads (276), Seta +4 (no name read), Vaela a downgrade.
local function members()
    local list = {
        cand("Seta", "ready", up(4, { ilvl = 283 })),
        cand("Butterz", "ready", up(11, { ilvl = 276, name = "Bloodthorn Treads" })),
        cand("Vaela", "ready", { verdict = "downgrade", ilvlDelta = -6, baseline = { ilvl = 293 }, reasons = {} }),
    }
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

-- Your own drop: a downgrade for you (so nobody is hidden), likely tradeable, two upgrades.
local function own(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 287, equipLoc = "INVTYPE_FEET", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 287, 296 }, basis = "inspect", age = 5 },
        candidates = members(),
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local KEEP = { verdict = "upgrade", ilvlDelta = 9, reasons = {} }

local function MC() return T.newAddon().MineCells end

local function joined(tip) return table.concat(tip, " | ") end

-- ── the pure cells ──────────────────────────────────────────────────────────────────────────

test("own drops: Trade appends the upgrade count, the bare word with none, and says so in its tooltip", function()
    local M = MC()
    local c = M.OwnTrade(own())
    assertEqual(c.text, "Likely (2)"); assertEqual(c.tone, "good"); assertEqual(c.upgrades, 2)
    assertEqual(c.tip[#c.tip], "Upgrades 2 members: Offer shows who.")
    local yes = M.OwnTrade(own({ trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 600 } } }))
    assertEqual(yes.text, "Yes (2)")
    local one = M.OwnTrade(own({ candidates = { x = cand("Seta", "ready", up(4)) } }))
    assertEqual(one.text, "Likely (1)"); assertEqual(one.tip[#one.tip], "Upgrades 1 member: Offer shows who.")
    local none = M.OwnTrade(own({ candidates = {} }))
    assertEqual(none.text, "Likely", "the bare word"); assertEqual(none.upgrades, 0)
    assertFalse(joined(none.tip):find("Upgrades", 1, true) ~= nil)
    local no = M.OwnTrade(own({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }))
    assertEqual(no.text, "No", "nothing counted on a drop that cannot be traded")
end)

test("own drops: the keep? rule: an upgrade for you draws no count until its Offer panel is opened", function()
    local M = MC()
    local kept = M.OwnTrade(own({ me = KEEP }))
    assertEqual(kept.text, "Likely"); assertTrue(kept.upgrades == nil)
    assertEqual(kept.tip[#kept.tip],
        "An upgrade for you: nobody is offered it unless you choose to. Offer shows who it would help.")
    assertEqual(M.OwnTrade(own({ me = KEEP }), true).text, "Likely (2)", "revealed")
end)

test("own drops: Them reads (Details), green with an upgrade, each one ranked by gain", function()
    local M = MC()
    local c = M.Multiple(own(), false, "For the group")
    assertEqual(c.text, "(Details)"); assertEqual(c.tone, "good"); assertEqual(c.upgrades, 2)
    assertEqual(c.tip[1], "For the group", "the caller's title")
    assertEqual(c.tip[2], "Butterz ▲ +11 · wears 276 (Bloodthorn Treads)")
    assertEqual(c.tip[3], "Seta ▲ +4 · wears 283")
    assertEqual(#c.tip, 3, "a downgrade is not listed")
    assertEqual(M.Multiple(own()).tip[1], "Them", "Them by default")
    local empty = M.Multiple(own({ candidates = { x = cand("Seta", "ready", up(30)) } }))
    assertEqual(empty.tip[2], "Seta ▲ +30 · nothing worn there")
end)

test("own drops: (Details) with no upgrade is muted and says why: nobody's, checking, solo", function()
    local M = MC()
    local down = { verdict = "downgrade", ilvlDelta = -6, baseline = { ilvl = 293 }, reasons = {} }
    local nobody = M.Multiple(own({ candidates = { a = cand("Vaela", "ready", down) } }))
    assertEqual(nobody.text, "(Details)"); assertEqual(nobody.tone, "muted")
    assertEqual(nobody.tip[2], "Not an upgrade for anyone whose gear was read.")
    local checking = M.Multiple(own({ candidates = { a = cand("Vaela", "ready", down), b = cand("Seta", "checking"),
        c = cand("Kael", "checking") } }))
    assertEqual(checking.tone, "muted"); assertEqual(checking.tip[#checking.tip], "2 checking")
    local solo = M.Multiple(own({ candidates = {} }))
    assertEqual(solo.tone, "muted"); assertEqual(solo.tip[2], "Nobody else in your group.")
    assertEqual(#solo.tip, 2)
    local hidden = M.Multiple(own({ me = KEEP }))
    assertEqual(hidden.text, "Hidden"); assertEqual(hidden.tone, "muted"); assertTrue(hidden.hidden)
    assertTrue(hidden.tip[2]:find("Offer shows who it would help.", 1, true) ~= nil)
    assertEqual(M.Multiple(own({ me = KEEP }), true).text, "(Details)")
    local dead = M.Multiple(own({ trade = { state = "no", reasonKey = "bonusRoll" } }))
    assertEqual(dead.text, "–"); assertTrue(dead.tip[2]:find("Not tradeable", 1, true) ~= nil)
end)

test("own drops: Offer is labeled and toned by the furthest offer sent, a dash where it cannot be traded", function()
    local M = MC()
    local ready = M.OwnOffer(own(), "ready")
    assertTrue(ready.offered and ready.offer and ready.enabled)
    assertEqual(ready.text, "Offer"); assertEqual(ready.state, "ready"); assertEqual(ready.kind, "offer")
    assertTrue(ready.tip[2]:find("Open the panel of who could use it", 1, true) ~= nil)
    local expect = { queued = { "Queued", "clock" }, sent = { "Offered", "confirm" }, tradedAway = { "Traded", "confirm" },
        failed = { "Offer" } }
    for state, e in pairs(expect) do
        local b = M.OwnOffer(own(), state)
        assertEqual(b.text, e[1], state); assertEqual(b.icon, e[2], state); assertEqual(b.state, state)
        assertTrue(b.enabled, state .. ": the panel always opens")
    end
    assertEqual(M.OwnOffer(own(), nil).state, "ready")
    local dead = M.OwnOffer(own({ trade = { state = "no", reasonKey = "bonusRoll" } }), "ready")
    assertFalse(dead.offered); assertEqual(dead.text, "–"); assertEqual(dead.tip[1], "No offer")
    assertTrue(dead.tip[2]:find("Bonus roll", 1, true) ~= nil)
end)

-- ── the reveal state and the click (modules/WindowOwn.lua) ──────────────────────────────────

test("own drops: Reveal is session state; the tone states read the offer and announce halves", function()
    local NS = T.newAddon()
    local WO = NS.WindowOwn
    assertFalse(WO.IsRevealed(1)); assertFalse(WO.IsRevealed(nil))
    WO.Reveal(1); WO.Reveal(nil)
    assertTrue(WO.IsRevealed(1)); assertTrue(NS.State.windowOwn.revealed[1])
    assertTrue(NS.WindowMine == nil, "the tab that held them is retired (feedback-5 spec §3)")
    NS.History.OutcomeOf = function() return nil end
    NS.Asks.FurthestStateOf = function() return "sent" end
    NS.Asks.StateOf = function() return "queued" end
    local offer, announce = WO.ToneStates({ id = 1 })
    assertEqual(offer, "sent"); assertEqual(announce, "queued")
    NS.History.OutcomeOf = function() return "tradedAway" end
    assertEqual((WO.ToneStates({ id = 1 })), "tradedAway")
    local pressed = {}
    NS.OfferPanel.Open = function(id) pressed[#pressed + 1] = "offer:" .. id end
    NS.PressAsk = function(id) pressed[#pressed + 1] = "ask:" .. id end
    WO.PressAction({ dropId = 4, offer = true }); WO.PressAction({ dropId = 5 })
    assertEqual(table.concat(pressed, ","), "offer:4,ask:5")
end)

-- ── painted: the table, the detail card, the compact card ───────────────────────────────────

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1, 2 } }

local function other()
    return { id = 2, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} }, them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 } }
end

local function shown(mine)
    local NS, _, m = T.enableAddon()
    m.__now = 100
    local byId = { [1] = mine, [2] = other() }
    NS.LootFeed.Groups = function() return { GROUP } end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return { mine, byId[2] } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.addon.db.profile.feed.showOwn = false   -- a stored value from before is ignored
    NS.ShowWindow()
    return NS, m
end

local function rowFor(drawn, id)
    for _, r in ipairs(drawn.rows) do if r.dropId == id then return r end end
end

local function textOf(region) return region and region:GetText() end

test("own drops table: listed with the others: Trade's count, (Details) in Them, Offer", function()
    local NS = shown(own())
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 2, "your own drop is listed, whatever showOwn said")
    local r = rowFor(drawn, 1)
    assertEqual(textOf(r.cells.trade.text), "Likely (2)")
    assertEqual(textOf(r.cells.them.text), "(Details)")
    local g = NS.Constants.TONE.good
    assertEqual(select(1, r.cells.them.text:GetTextColor()), g.r)
    assertEqual(NS.Window.TooltipOf(r.cells.them)[2], "Butterz ▲ +11 · wears 276 (Bloodthorn Treads)")
    assertFalse(r.cells.them.icons[1]:IsShown(), "no worn icons on your own drop")
    assertEqual(textOf(r.cells.them.level), "", "no gear part"); assertEqual(textOf(r.cells.them.glyph), "")
    assertEqual(NS.Window.TooltipOf(r.cells.them)[1], "Them")
    assertTrue(r.cells.theirEq == nil, "no Their eq column (feedback-6 spec §1)")
    local b = r.cells.actions.ask
    assertTrue(b:IsShown()); assertEqual(textOf(b.label), "Offer"); assertTrue(b.offer)
    assertEqual(b.tone, "cyan", "your move until an offer is sent: cyan, not Ask's red (feedback-6 spec §2)")
    local cyan = NS.Constants.TONE.cyan
    assertEqual(select(2, b.label:GetTextColor()), cyan.g); assertEqual(select(3, b.label:GetTextColor()), cyan.b)
    assertFalse(r.cells.actions.dash:IsShown())
    assertFalse(rowFor(drawn, 2).cells.actions.ask.offer, "another player's row keeps its Ask")
    local hd = textOf(drawn.headers[1].text)
    assertTrue(hd:find("2 drops", 1, true) ~= nil and hd:find("yours", 1, true) == nil, hd)
end)

test("own drops table: Offer opens the Offer panel and reveals a kept upgrade's count and (Details)", function()
    local NS, m = shown(own({ me = KEEP }))
    local r = rowFor(NS.WindowGroup.Drawn(), 1)
    assertEqual(textOf(r.cells.trade.text), "Likely", "no count under the keep? rule")
    assertEqual(textOf(r.cells.them.text), "Hidden")
    local opened
    local open = NS.OfferPanel.Open
    NS.OfferPanel.Open = function(id) opened = id; return open(id) end
    local asked = false
    NS.PressAsk = function() asked = true end
    r.cells.actions.ask:__fire("OnClick")
    assertEqual(opened, 1); assertFalse(asked, "not an Ask")
    assertTrue(NS.WindowOwn.IsRevealed(1))
    m.advance(0)
    r = rowFor(NS.WindowGroup.Drawn(), 1)
    assertEqual(textOf(r.cells.trade.text), "Likely (2)")
    assertEqual(textOf(r.cells.them.text), "(Details)")
end)

test("own drops table: Offer turns yellow once offered and green once given away; a dash when untradeable", function()
    local NS = shown(own())
    NS.Asks.FurthestStateOf = function(kind) return kind == "offer" and "sent" or "ready" end
    NS.Window.Refresh()
    local b = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions.ask
    assertEqual(textOf(b.label), "Offered"); assertEqual(b.tone, "yellow"); assertTrue(b:IsEnabled())
    NS.History.OutcomeOf = function(id) return id == 1 and "tradedAway" or nil end
    NS.Window.Refresh()
    b = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions.ask
    assertEqual(textOf(b.label), "Traded"); assertEqual(b.tone, "good")
    local NS2 = shown(own({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }))
    local a = rowFor(NS2.WindowGroup.Drawn(), 1).cells.actions
    assertFalse(a.ask:IsShown()); assertTrue(a.dash:IsShown())
    assertEqual(NS2.Window.TooltipOf(a.dashTip)[1], "No offer")
    assertTrue(NS2.Window.TooltipOf(a.dashTip)[2]:find("Bonus roll", 1, true) ~= nil)
end)

test("own drops: the detail card shows Offer in place of Ask and (Details) for Them", function()
    local NS = shown(own())
    NS.WindowGroup.ToggleExpand(1)
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(drawn.cardDropId, 1)
    local b = drawn.card.actions.ask
    assertEqual(textOf(b.label), "Offer"); assertTrue(b.offer); assertEqual(b.tone, "cyan")
    assertEqual(select(3, b.label:GetTextColor()), NS.Constants.TONE.cyan.b)
    assertEqual(textOf(drawn.card.them.title), "FOR THE GROUP")
    local them
    for _, row in ipairs(drawn.card.them.rows) do if row.key == "them" then them = row end end
    assertEqual(textOf(them.value), "(Details)")
    assertEqual(them.tipLines[2], "Butterz ▲ +11 · wears 276 (Bloodthorn Treads)")
    local opened
    NS.OfferPanel.Open = function(id) opened = id end
    b:__fire("OnClick")
    assertEqual(opened, 1)
end)

test("own drops compact: line 1's Offer, line 2's count and line 3's (Details) with its tooltip", function()
    local NS = shown(own())
    NS.SetWindowMode("compact")
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact)
    local card = rowFor(drawn, 1)
    assertEqual(textOf(card.ask.label), "Offer"); assertTrue(card.ask.offer); assertEqual(card.ask.tone, "cyan")
    assertEqual(select(3, card.ask.label:GetTextColor()), NS.Constants.TONE.cyan.b)
    assertEqual(rowFor(drawn, 2).ask.tone, "red", "another player's Ask stays red")
    assertEqual(textOf(card.cells.trade.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^· ", ""), "Likely (2)")
    assertEqual(textOf(card.cells.them.text), "(Details)")
    assertEqual(card.cells.them.hit.tipLines[2], "Butterz ▲ +11 · wears 276 (Bloodthorn Treads)")
    local opened
    NS.OfferPanel.Open = function(id) opened = id end
    card.ask:__fire("OnClick")
    assertEqual(opened, 1)
    assertFalse(rowFor(drawn, 2).ask.offer, "another player's card keeps its Ask")
end)
