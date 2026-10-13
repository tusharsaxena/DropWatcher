-- tests/test_own_drops.lua — your own drops on the Drops tab (feedback-5 spec §2, DW-E2):
-- always listed (`feed.showOwn` retired); Trade reads its word alone, its tooltip counting the
-- members a drop upgrades (feedback-7 spec §2); Them reads `Upgrade for N` (`No upgrades` with none;
-- `(Details)` before feedback-7, `(Multiple)` before feedback-6) with each upgrade ranked by gain in
-- the tooltip, one non-wrapping line each; Looter reads `Name [YOU]`, the mark in gold; the keep?
-- rule hides the count and Them until the Offer panel is opened; Actions is Offer, toned by the
-- furthest offer sent.
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

-- One Upgrade for N tooltip line as feedback-6 spec §3 draws it, built here from its parts so the suite pins the
-- format rather than reading it back from NS.TipMarks: a mage's name in the class color, `wears`,
-- the worn item, then the green arrow texture (LibKa0s media `arrow-up`, its 64x64 canvas whole,
-- tinted C.TONE.good as 0..255) and the unsigned gain.
local function detailsLine(NS, who, worn, gain)
    local arrow = ("|T%s:0:0:0:0:64:64:0:64:0:64:77:217:102|t"):format(NS.Icon("arrow-up"))
    return ("|cff40c7eb%s|r wears %s %s%d"):format(who, worn, arrow, gain)
end

-- A non-wrapping tooltip line's text (NS.TipMarks.NoWrap), checking that it does not wrap.
local function noWrap(line)
    assertEqual(type(line), "table", "an upgrade line is a non-wrapping line")
    assertEqual(line.wrap, false)
    return line.text
end

-- ── the pure cells ──────────────────────────────────────────────────────────────────────────

test("own drops: Trade reads its word alone and counts the upgrades in its tooltip (feedback-7 spec §2)", function()
    local M = MC()
    local c = M.OwnTrade(own())
    assertEqual(c.text, "Likely"); assertEqual(c.tone, "good"); assertEqual(c.upgrades, 2)
    assertEqual(c.tip[#c.tip], "Upgrades 2 members: Offer shows who.")
    local yes = M.OwnTrade(own({ trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 600 } } }))
    assertEqual(yes.text, "Yes", "not Yes (2)")
    local one = M.OwnTrade(own({ candidates = { x = cand("Seta", "ready", up(4)) } }))
    assertEqual(one.text, "Likely"); assertEqual(one.tip[#one.tip], "Upgrades 1 member: Offer shows who.")
    local none = M.OwnTrade(own({ candidates = {} }))
    assertEqual(none.text, "Likely", "the bare word"); assertEqual(none.upgrades, 0)
    assertFalse(joined(none.tip):find("Upgrades", 1, true) ~= nil)
    local no = M.OwnTrade(own({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }))
    assertEqual(no.text, "No", "nothing counted on a drop that cannot be traded")
    assertEqual(no.tone, "red", "No in the palette's red, not the gray (feedback-7 spec §2)")
end)

test("own drops: the keep? rule: an upgrade for you says no count until its Offer panel is opened", function()
    local M = MC()
    local kept = M.OwnTrade(own({ me = KEEP }))
    assertEqual(kept.text, "Likely"); assertTrue(kept.upgrades == nil)
    assertEqual(kept.tip[#kept.tip],
        "An upgrade for you: nobody is offered it unless you choose to. Offer shows who it would help.")
    local revealed = M.OwnTrade(own({ me = KEEP }), true)
    assertEqual(revealed.text, "Likely"); assertEqual(revealed.upgrades, 2, "revealed")
    assertEqual(revealed.tip[#revealed.tip], "Upgrades 2 members: Offer shows who.")
end)

test("own drops: Them reads Upgrade for N, green, each one ranked by gain", function()
    local NS = T.newAddon()
    local M = NS.MineCells
    local c = M.Details(own(), false, "For the group")
    assertEqual(c.text, "Upgrade for 2"); assertEqual(c.tone, "good"); assertEqual(c.upgrades, 2)
    assertEqual(c.tip[1], "For the group", "the caller's title")
    assertEqual(noWrap(c.tip[2]), detailsLine(NS, "Butterz", "276 Bloodthorn Treads", 11))
    assertEqual(noWrap(c.tip[3]), detailsLine(NS, "Seta", "283", 4), "no item name read: the level alone")
    assertEqual(#c.tip, 3, "a downgrade is not listed")
    assertEqual(M.Details(own()).tip[1], "Them", "Them by default")
    local empty = M.Details(own({ candidates = { x = cand("Seta", "ready", up(30)) } }))
    assertEqual(empty.text, "Upgrade for 1")
    assertEqual(noWrap(empty.tip[2]), detailsLine(NS, "Seta", "nothing there", 30),
        "nothing worn in the slot")
end)

test("own drops: No upgrades is muted and says why: nobody's, checking, solo", function()
    local M = MC()
    local down = { verdict = "downgrade", ilvlDelta = -6, baseline = { ilvl = 293 }, reasons = {} }
    local nobody = M.Details(own({ candidates = { a = cand("Vaela", "ready", down) } }))
    assertEqual(nobody.text, "No upgrades"); assertEqual(nobody.tone, "muted")
    assertEqual(nobody.tip[2], "Not an upgrade for anyone whose gear was read.")
    local checking = M.Details(own({ candidates = { a = cand("Vaela", "ready", down), b = cand("Seta", "checking"),
        c = cand("Kael", "checking") } }))
    assertEqual(checking.tone, "muted"); assertEqual(checking.tip[#checking.tip], "2 checking")
    local solo = M.Details(own({ candidates = {} }))
    assertEqual(solo.text, "No upgrades"); assertEqual(solo.tone, "muted"); assertEqual(solo.tip[2], "Nobody else in your group.")
    assertEqual(#solo.tip, 2)
    local hidden = M.Details(own({ me = KEEP }))
    assertEqual(hidden.text, "Hidden"); assertEqual(hidden.tone, "muted"); assertTrue(hidden.hidden)
    assertTrue(hidden.tip[2]:find("Offer shows who it would help.", 1, true) ~= nil)
    assertEqual(M.Details(own({ me = KEEP }), true).text, "Upgrade for 2")
    local dead = M.Details(own({ trade = { state = "no", reasonKey = "bonusRoll" } }))
    assertEqual(dead.text, "–"); assertTrue(dead.tip[2]:find("Not tradeable", 1, true) ~= nil)
end)

test("own drops: Offer is labeled and toned by the furthest offer sent, a dash where it cannot be traded", function()
    local M = MC()
    local ready = M.OwnOffer(own(), "ready")
    assertTrue(ready.offered and ready.offer and ready.enabled)
    assertEqual(ready.text, "Offer"); assertEqual(ready.state, "ready"); assertEqual(ready.kind, "offer")
    assertEqual(ready.icon, "export", "handing the item out (feedback-7 spec §1)")
    assertTrue(ready.tip[2]:find("Open the panel of who could use it", 1, true) ~= nil)
    local expect = { queued = { "Queued", "clock" }, sent = { "Offered", "confirm" }, tradedAway = { "Traded", "confirm" },
        failed = { "Offer", "export" } }
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

test("own drops table: listed with the others: Trade's word, Upgrade for N in Them, Offer", function()
    local NS = shown(own())
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 2, "your own drop is listed, whatever showOwn said")
    local r = rowFor(drawn, 1)
    assertEqual(textOf(r.cells.trade.text), "Likely")
    assertEqual(textOf(r.cells.them.text), "Upgrade for 2")
    local g = NS.Constants.TONE.good
    assertEqual(select(1, r.cells.them.text:GetTextColor()), g.r)
    assertEqual(noWrap(NS.Window.TooltipOf(r.cells.them)[2]), detailsLine(NS, "Butterz", "276 Bloodthorn Treads", 11))
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

test("own drops table: Offer opens the Offer panel and reveals a kept upgrade's Upgrade for N", function()
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
    assertEqual(textOf(r.cells.trade.text), "Likely")
    assertEqual(textOf(r.cells.them.text), "Upgrade for 2")
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

test("own drops: the detail card shows Offer in place of Ask and Upgrade for N for Them", function()
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
    assertEqual(textOf(them.value), "Upgrade for 2")
    assertEqual(noWrap(them.tipLines[2]), detailsLine(NS, "Butterz", "276 Bloodthorn Treads", 11))
    local opened
    NS.OfferPanel.Open = function(id) opened = id end
    b:__fire("OnClick")
    assertEqual(opened, 1)
end)

test("own drops compact: line 1's Offer, line 2's trade word and line 3's Upgrade for N with its tooltip", function()
    local NS = shown(own())
    NS.SetWindowMode("compact")
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact)
    local card = rowFor(drawn, 1)
    assertEqual(textOf(card.ask.label), "Offer"); assertTrue(card.ask.offer); assertEqual(card.ask.tone, "cyan")
    assertEqual(select(3, card.ask.label:GetTextColor()), NS.Constants.TONE.cyan.b)
    assertEqual(rowFor(drawn, 2).ask.tone, "red", "another player's Ask stays red")
    assertEqual(textOf(card.cells.trade.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^· ", ""), "Likely")
    assertEqual(textOf(card.cells.them.text), "Upgrade for 2")
    assertEqual(noWrap(card.cells.them.hit.tipLines[2]), detailsLine(NS, "Butterz", "276 Bloodthorn Treads", 11))
    local opened
    NS.OfferPanel.Open = function(id) opened = id end
    card.ask:__fire("OnClick")
    assertEqual(opened, 1)
    assertFalse(rowFor(drawn, 2).ask.offer, "another player's card keeps its Ask")
end)

-- ── Name [YOU] on every looter text (feedback-7 spec §2) ────────────────────────────────────

test("own drops: the Looter cell marks your own drop [YOU], never another player's", function()
    local NS = T.newAddon()
    local mine = NS.WindowCells.Looter(own())
    assertEqual(mine.text, "Me"); assertEqual(mine.you, "[YOU]"); assertEqual(mine.classFile, "PALADIN")
    assertTrue(NS.WindowCells.Looter(other()).you == nil)
end)

test("own drops: the name is cut before the mark: WindowRows.MarkedWidth", function()
    local WR = T.newAddon().WindowRows
    assertEqual(WR.MarkedWidth(104, 40, 25), 41, "room to spare: the name keeps its own width")
    assertEqual(WR.MarkedWidth(104, 200, 25), 104 - 25 - WR.MARK_GAP, "too long: the name is cut, the mark kept")
    assertEqual(WR.MarkedWidth(104, nil, 25), 76, "an unmeasured name takes what the mark leaves")
    assertEqual(WR.MarkedWidth(104, 40, nil), 104, "no mark: the whole cell")
    assertEqual(WR.MarkedWidth(20, 200, 25), 10, "never under 10")
end)

-- The mark's color, as the mock reports it.
local function isGold(NS, fs)
    local r, g, b = fs:GetTextColor()
    local G = NS.Constants.GOLD
    return r == G.r and g == G.g and b == G.b
end

test("own drops table: Looter reads Name [YOU], the name in class color and the mark in gold", function()
    local NS, m = shown(own({ looter = { name = "Artyemisthelongnamed-Realm", guid = "Player-1-ME",
        classFile = "PALADIN", isSelf = true } }))
    m.textCharWidth = 5
    local cell = rowFor(NS.WindowGroup.Drawn(), 1).cells.looter
    local width
    cell.text.SetWidth = function(_, w) width = w end   -- the stub records no width: spy on it
    NS.Window.Refresh()
    cell = rowFor(NS.WindowGroup.Drawn(), 1).cells.looter
    assertEqual(textOf(cell.text), "Artyemisthelongnamed")
    assertTrue(cell.mark:IsShown()); assertEqual(textOf(cell.mark), "[YOU]"); assertTrue(isGold(NS, cell.mark))
    assertEqual(width, 104 - 25 - NS.WindowRows.MARK_GAP,
        "100 wide does not fit beside [YOU] (25) in 104: the name is cut and the mark kept")
    local pt = cell.mark.__points[1]   -- the mock's recorded anchor
    assertEqual(pt[1], "LEFT"); assertEqual(pt[2], cell.text, "the mark hangs off the name's right edge")
    local other2 = rowFor(NS.WindowGroup.Drawn(), 2).cells.looter
    assertFalse(other2.mark:IsShown(), "another player's name has no mark")
end)

test("own drops: the detail card's Looter row and the compact card's line 2 read Name [YOU]", function()
    local NS = shown(own())
    NS.WindowGroup.ToggleExpand(1)
    local looter
    for _, row in ipairs(NS.WindowGroup.Drawn().card.them.rows) do if row.key == "mine" then looter = row end end
    assertEqual(textOf(looter.value), "Me"); assertTrue(looter.mark:IsShown())
    assertEqual(textOf(looter.mark), "[YOU]"); assertTrue(isGold(NS, looter.mark))
    NS.SetWindowMode("compact")
    local drawn = NS.WindowGroup.Drawn()
    local card = rowFor(drawn, 1)
    assertEqual(textOf(card.cells.looter.text), "Me")
    assertTrue(card.cells.looter.mark:IsShown()); assertEqual(textOf(card.cells.looter.mark), "[YOU]")
    assertTrue(isGold(NS, card.cells.looter.mark))
    assertFalse(rowFor(drawn, 2).cells.looter.mark:IsShown())
end)

