-- tests/test_offer_alone.lua — an Offer only when another player is in your group (DW-07, Addendum 08,
-- image-66): solo, in a follower dungeon (the party's followers are not players), in a delve with a
-- companion (Brann), or in any group whose other members are all non-player units, your own drop's
-- Offer reads No action with the reason, the Offer panel will not open, and Offer, Announce, Post my
-- tradeables and `/dw offer` refuse. A player joining brings the Offer back on the next repaint;
-- the last one leaving takes it away. A test drop judges its own spec roster, so it keeps its Offer.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local EVENT = "GROUP_ROSTER_UPDATE"
local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local REASON = "no other player in your group"

local function human(n, name)
    return { guid = "Player-1-0000000" .. n, name = name, class = "PRIEST", classFile = "PRIEST" }
end

local function npc(n, name)
    return { guid = "Creature-0-1-2-3-21000" .. n .. "-0000000" .. n, name = name, class = "WARRIOR",
        classFile = "WARRIOR", npc = true }
end

-- A follower dungeon's party: four followers.
local FOLLOWERS = { npc(1, "Captain Garrick"), npc(2, "Meredy Huntswell"), npc(3, "Shuja Grimaxe"), npc(4, "Crenna") }

local function own(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 287, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = 100 + 6000 },
        candidates = {},
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } }

-- The window shown on Drops with one drop of yours, in the group `others` (nil: solo).
local function shown(others, drop)
    local NS, _, m = T.enableAddon()
    m.__now = 100
    if others then m.setGroup(others); m.__fire(EVENT) end
    drop = drop or own()
    NS.LootFeed.Groups = function() return { GROUP } end
    NS.LootFeed.Get = function(id) return id == 1 and drop or nil end
    NS.LootFeed.Drops = function() return { drop } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, m
end

local function action(NS)
    for _, r in ipairs(NS.WindowGroup.Drawn().rows) do
        if r.dropId == 1 then return r.cells.actions.ask end
    end
end

local function textOf(region) return region and region:GetText() end

local function says(NS, b, needle)
    return T.tipPlainJoined(NS.Window.TooltipOf(b)):find(needle, 1, true) ~= nil
end

local function printed(m, needle)
    for _, line in ipairs(m.prints) do
        if tostring(line):find(needle, 1, true) then return true end
    end
    return false
end

local function assertNoAction(NS, why)
    local b = action(NS)
    assertEqual(textOf(b.label), "No action", why); assertFalse(b:IsEnabled(), why)
    assertEqual(NS.Window.TooltipOf(b)[1], "No action")
    assertTrue(says(NS, b, REASON), "the tooltip names the reason: " .. T.tipPlainJoined(NS.Window.TooltipOf(b)))
end

local function assertOffer(NS, why)
    local b = action(NS)
    assertEqual(textOf(b.label), "Offer", why); assertTrue(b:IsEnabled(), why); assertTrue(b.offer)
end

-- ── the roster's answer ─────────────────────────────────────────────────────────────────────

test("offer alone: the roster reads who is a player: solo, followers and a companion are nobody", function()
    local NS, _, m = T.enableAddon()
    local Ro = NS.Roster
    assertFalse(Ro.OtherPlayerPresent(), "solo")
    m.setGroup(FOLLOWERS); m.__fire(EVENT)
    assertEqual(Ro.Count(), 5)
    assertFalse(Ro.Get(FOLLOWERS[1].guid).human, "a follower is not a player")
    assertTrue(Ro.Player().human, "you are")
    assertFalse(Ro.OtherPlayerPresent(), "a follower dungeon")
    m.setGroup({ npc(5, "Brann Bronzebeard") }); m.__fire(EVENT)
    assertFalse(Ro.OtherPlayerPresent(), "a delve with Brann")
    m.setGroup({ npc(1, "Captain Garrick"), human(2, "Seta") }); m.__fire(EVENT)
    assertTrue(Ro.OtherPlayerPresent(), "one player among followers")
    m.setGroup({ human(2, "Seta"), human(3, "Butterz") }, true); m.__fire(EVENT)
    assertTrue(Ro.OtherPlayerPresent(), "a raid")
end)

test("offer alone: a secret UnitIsPlayer falls back to the GUID's kind", function()
    local NS, _, m = T.enableAddon()
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
    local f, p = npc(1, "Captain Garrick"), human(2, "Seta")
    f.isPlayer, p.isPlayer = T.secret(true), T.secret(false)
    m.setGroup({ f }); m.__fire(EVENT)
    assertFalse(NS.Roster.OtherPlayerPresent(), "a Creature GUID is no player")
    m.setGroup({ f, p }); m.__fire(EVENT)
    assertTrue(NS.Roster.OtherPlayerPresent(), "a Player GUID is")
end)

test("offer alone: a player who changes into a follower in the same slot moves the roster", function()
    local NS, _, m = T.enableAddon()
    local p = human(2, "Seta")
    m.setGroup({ p }); m.__fire(EVENT)
    assertTrue(NS.Roster.OtherPlayerPresent())
    p.npc = true
    m.__fire(EVENT)
    assertFalse(NS.Roster.OtherPlayerPresent(), "the human flag is part of the roster's signature")
end)

-- ── the pure cell ───────────────────────────────────────────────────────────────────────────

test("offer alone: MineCells.OwnOffer reads No action with the reason when nobody could take it", function()
    local NS = T.newAddon()
    local MC = NS.MineCells
    local none = MC.OwnOffer(own(), "ready", true)
    assertFalse(none.offered); assertTrue(none.offer); assertFalse(none.enabled)
    assertEqual(none.text, "No action"); assertEqual(none.state, "none")
    assertTrue(T.tipPlainJoined(none.tip):find("Why: " .. REASON, 1, true) ~= nil, T.tipPlainJoined(none.tip))
    local dead = MC.OwnOffer(own({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }), "ready", true)
    assertTrue(T.tipPlainJoined(dead.tip):find("not tradeable", 1, true) ~= nil, "untradeable says that first")
    assertEqual(MC.OwnOffer(own(), "ready", false).text, "Offer")
    assertEqual(MC.OwnOffer(own(), "ready").text, "Offer", "nil is the old answer")
end)

test("offer alone: WindowOwn.Alone: a test drop judges its own spec roster", function()
    local NS = T.enableAddon()
    assertTrue(NS.WindowOwn.Alone(own()))
    assertFalse(NS.WindowOwn.Alone(own({ test = true })), "test mode's drops keep their Offer")
end)

-- ── the window ──────────────────────────────────────────────────────────────────────────────

test("offer alone: solo, your tradeable drop reads No action and says why (image-66)", function()
    local NS = shown(nil)
    assertNoAction(NS, "solo")
end)

test("offer alone: a follower dungeon's party of followers is nobody to offer to", function()
    local NS = shown(FOLLOWERS)
    assertNoAction(NS, "follower dungeon")
end)

test("offer alone: a delve with Brann is nobody to offer to", function()
    local NS = shown({ npc(5, "Brann Bronzebeard") })
    assertNoAction(NS, "delve")
end)

test("offer alone: a real party keeps the Offer", function()
    local NS = shown({ human(2, "Seta"), human(3, "Butterz") })
    assertOffer(NS, "party")
end)

test("offer alone: a player joining brings the Offer back on the repaint; leaving takes it away", function()
    local NS, m = shown({ npc(5, "Brann Bronzebeard") })
    assertNoAction(NS, "Brann alone")
    m.setGroup({ npc(5, "Brann Bronzebeard"), human(2, "Seta") }); m.__fire(EVENT)
    m.advance(0)
    assertOffer(NS, "a player joined")
    m.setGroup({ npc(5, "Brann Bronzebeard") }); m.__fire(EVENT)
    m.advance(0)
    assertNoAction(NS, "the player left")
end)

test("offer alone: the detail card's first action and the compact card read No action too", function()
    local NS = shown(FOLLOWERS)
    NS.WindowGroup.ToggleExpand(1)
    local b = NS.WindowGroup.Drawn().card.actions.ask
    assertEqual(textOf(b.label), "No action"); assertFalse(b:IsEnabled())
    assertTrue(says(NS, b, REASON))
    local card = NS.CompactCards.Group(own(), { now = 100, offerTone = "ready", alone = NS.WindowOwn.Alone(own()) })
    assertEqual(card.ask.text, "No action"); assertFalse(card.ask.enabled)
    assertEqual(NS.CompactCards.Group(own(), { now = 100, offerTone = "ready", alone = false }).ask.text, "Offer")
end)

-- ── the Offer panel and the host handlers ───────────────────────────────────────────────────

test("offer alone: the Offer panel does not open, and closes when the last player leaves", function()
    local NS, m = shown(FOLLOWERS)
    assertNil(NS.OfferPanel.Open(1), "nobody to offer to")
    assertFalse(NS.OfferPanel.IsShown())
    m.setGroup({ human(2, "Seta") }); m.__fire(EVENT); m.advance(0)
    assertTrue(NS.OfferPanel.Open(1) ~= nil)
    m.setGroup(FOLLOWERS); m.__fire(EVENT); m.advance(0)
    assertFalse(NS.OfferPanel.IsShown(), "the repaint closes it")
end)

test("offer alone: Offer, Announce and Post my tradeables refuse and say why", function()
    local NS, m = shown({ npc(5, "Brann Bronzebeard") })
    local pressed = 0
    NS.Asks.Press = function() pressed = pressed + 1; return "sent" end
    NS.Asks.Request = function() pressed = pressed + 1; return "sent" end
    assertEqual((NS.PressOffer(1, "Brann Bronzebeard")), "refused")
    assertTrue(printed(m, "Not offered: There is no other player in your group."))
    assertEqual((NS.PressAnnounce(1)), "refused")
    assertTrue(printed(m, "Not announced: There is no other player in your group."))
    NS.WindowFilterBar.IsTradeableMine = function() return true end
    assertEqual(NS.PostTradeables(), 0)
    assertEqual(pressed, 0, "nothing reaches the messaging edge")
    assertEqual(#m.chatSent, 0)
end)

test("offer alone: /dw offer says why and opens nothing", function()
    local NS, m = shown(FOLLOWERS)
    NS.SlashVerbs.Offer(LINK)
    assertFalse(NS.OfferPanel.IsShown())
    assertTrue(printed(m, "There is no other player in your group"), tostring(m.prints[#m.prints]))
end)
