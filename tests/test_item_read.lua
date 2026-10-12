-- tests/test_item_read.lua — BUG-1 of the M8 feedback (ui spec §0, DW-80): a real drop read wrongly
-- (Lustrous Golden Plumage, item 159617, shown at its base level 19 and base quality Rare instead
-- of 311 Epic). The reproduction with realistic 12.x links per loot source comes first, then
-- core/ItemRead.lua (the library-shaped reads: LinkDetail, BetterLink, QualityOf,
-- EffectiveItemLevel, ItemLevelAt, QualityAt, SameItem), then the fixes it drives: the merge keeps
-- the most complete link, an own drop matched to its bag item reads its level and quality from
-- that bag item, the bag match tolerates non-identity fields, and the `drops` diagnostics line.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"

-- The owner's item, as each source hands it. The chat line's link is complete: the scaling level
-- (80) and spec (577), the Mythic+ context (35), five bonus ids and an upgrade-track modifier. The
-- encounter event's link, as hypothesis 1 has it, names the same item with no bonus or modifier
-- data, colored at the base quality. The bag item differs from the chat link in non-identity
-- fields only (its unique id and a later link level).
local PLUME = 159617
local FULL = "|cnIQ4:|Hitem:159617::::::::80:577::35:5:10390:6652:10383:10254:1520:1:28:2462:::::|h[Lustrous Golden Plumage]|h|r"
local BARE = "|cnIQ3:|Hitem:159617::::::::80:577::35::::::::|h[Lustrous Golden Plumage]|h|r"
local BAGGED = "|cnIQ4:|Hitem:159617:::::::12345:80:577::35:5:10390:6652:10383:10254:1520:1:28:2462:::::|h[Lustrous Golden Plumage]|h|r"

-- What the client answers for each link: the base item (level 19, Rare) for the bare link, the
-- real one (311, Epic) for a complete link.
local function trinket(quality, effective)
    return { name = "Lustrous Golden Plumage", quality = quality, ilvl = 19, effectiveIlvl = effective,
        equipLoc = "INVTYPE_TRINKET", classID = 4, subClassID = 0, bindType = 1, stats = {} }
end

local function seedPlume(m)
    m.addItem(FULL, trinket(4, 311))
    m.addItem(BARE, trinket(3, 19))
    m.addItem(BAGGED, trinket(4, 311))
end

local function ringLink(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
        bindType = 1, stats = {} }
end

-- In a Heroic dungeon with Brakk, the player wearing two 600 rings and two 300 trinkets.
local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "Atal'Dazar", difficultyID = 8 }
    end })
    m.addItem(ringLink(100), ring(600))
    m.addItem(ringLink(101), ring(600))
    local t = trinket(4, 300)
    m.addItem(ringLink(102), t)
    m.addItem(ringLink(103), t)
    m.inventory.player[11], m.inventory.player[12] = ringLink(100), ringLink(101)
    m.inventory.player[13], m.inventory.player[14] = ringLink(102), ringLink(103)
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    seedPlume(m)
    m.bags[0] = { size = 4 }
    return NS, m, NS.LootFeed
end

local function chatSelf(m, itemLink)
    m.__fire("CHAT_MSG_LOOT", "You receive loot: " .. itemLink .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

local function encounterSelf(m, itemLink)
    m.__fire("ENCOUNTER_LOOT_RECEIVED", 2087, PLUME, itemLink, 1, "Testchar", "WARRIOR")
end

local function only(LF)
    local drops = LF.Drops()
    assertEqual(#drops, 1, "one drop")
    return drops[1]
end

-- ---------------------------------------------------------------------------------------------
-- The reproduction (hypothesis 1: the merge keeps the first source's link)
-- ---------------------------------------------------------------------------------------------

test("BUG-1 repro: chat first, the drop reads 311 Epic", function()
    local _, m, LF = party()
    chatSelf(m, FULL)
    encounterSelf(m, BARE)
    local rec = only(LF)
    assertEqual(rec.facts.ilvl, 311); assertEqual(rec.facts.quality, 4)
end)

test("BUG-1 repro: the encounter's bare link first, then chat's complete one: the complete link wins", function()
    local NS, m, LF = party()
    local seen = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.DROP_UPDATED, function(_, _, cause) seen[#seen + 1] = cause end)
    encounterSelf(m, BARE)
    chatSelf(m, FULL)
    local rec = only(LF)
    assertEqual(rec.link, FULL, "the merge keeps the most complete link")
    assertEqual(rec.facts.ilvl, 311, "not the base level 19")
    assertEqual(rec.facts.quality, 4, "not the base quality Rare")
    assertTrue(rec.sources.encounter == 1 and rec.sources.chat == 1)
    assertEqual(seen[#seen], "source")
end)

test("BUG-1 repro: a complete link first is never replaced by a later bare one", function()
    local _, m, LF = party()
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2087, 1)   -- no winner yet: nothing
    chatSelf(m, FULL)
    encounterSelf(m, BARE)
    assertEqual(only(LF).link, FULL)
end)

test("BUG-1 repro: a merge while the first link is still loading judges the complete link", function()
    local _, m, LF = party()
    m.items[BARE].loadsNeeded = 1
    encounterSelf(m, BARE)
    chatSelf(m, FULL)
    m.advance(1)
    local rec = only(LF)
    assertEqual(rec.link, FULL); assertEqual(rec.facts.ilvl, 311); assertEqual(rec.facts.quality, 4)
end)

-- Hypothesis 2: with a complete link the client's detailed level is right, so the read itself is
-- not the cause; a bare link is what turns it into the base level.
test("BUG-1 hypothesis 2: ItemFacts reads a complete link right and a bare one at the base", function()
    local NS = party()
    assertEqual(NS.ItemFacts.Read(FULL).ilvl, 311)
    assertEqual(NS.ItemFacts.Read(BARE).ilvl, 19)
end)

-- Hypothesis 3: an own drop does match its bag item (by item id, the bag link differing), but its
-- facts were never refreshed from it.
test("BUG-1 hypothesis 3: an own drop recorded from a bare link reads level and quality from its bag item", function()
    local NS, m, LF = party()
    m.items[FULL] = nil   -- only the encounter's bare link reached the feed
    encounterSelf(m, BARE)
    m.bags[0][1] = BAGGED
    m.bagGUIDs["0:1"] = "Item-1-0001"
    m.bagItemReads["0:1"] = { ilvl = 311, quality = 4 }
    m.tooltips.bag["0:1"] = { lines = {} }
    m.advance(0)
    local rec = only(LF)
    assertTrue(NS.TradeTimer.ForDrop(rec.id) ~= nil, "matched to its bag item")
    assertEqual(rec.facts.ilvl, 311, "the bag item's exact level")
    assertEqual(rec.facts.quality, 4, "the bag item's exact quality")
    assertEqual(rec.facts.ilvlSource, "current"); assertEqual(rec.facts.qualitySource, "location")
    assertEqual(rec.link, BAGGED, "the bag item's link is the more complete one")
end)

-- The history records a drop at DropAdded; the merge and the bag read come later, as DropUpdated.
test("BUG-1: the history entry takes the complete link, 311 and Epic when chat merges in", function()
    local NS, m, LF = party()
    encounterSelf(m, BARE)
    local rec = only(LF)
    local e = NS.History.EntryOf(rec.id)
    assertEqual(e.ilvl, 19, "recorded from the bare link first")
    chatSelf(m, FULL)
    e = NS.History.EntryOf(rec.id)
    assertEqual(e.itemLink, FULL, "the most complete link")
    assertEqual(e.ilvl, 311); assertEqual(e.quality, 4)
end)

test("BUG-1: the history entry takes the bag item's link, level and quality", function()
    local NS, m, LF = party()
    m.items[FULL] = nil
    encounterSelf(m, BARE)
    m.bags[0][1] = BAGGED
    m.bagGUIDs["0:1"] = "Item-1-0001"
    m.bagItemReads["0:1"] = { ilvl = 311, quality = 4 }
    m.tooltips.bag["0:1"] = { lines = {} }
    m.advance(0)
    local e = NS.History.EntryOf(only(LF).id)
    assertEqual(e.itemLink, BAGGED); assertEqual(e.ilvl, 311); assertEqual(e.quality, 4)
end)

test("BUG-1: the history's Refresh never trades a complete link for a bare one", function()
    local Hi = T.newAddon().History
    local e = { itemLink = FULL, ilvl = 311, quality = 4, outcome = "seen", at = 1 }
    local _, moved = Hi.Refresh(e, { link = BARE, facts = { ilvl = 311, quality = 4 } })
    assertEqual(e.itemLink, FULL); assertFalse(moved, "nothing kept changed")
    _, moved = Hi.Refresh(e, { link = FULL, facts = { ilvl = 315, quality = 4 } })
    assertEqual(e.ilvl, 315); assertTrue(moved, "a level read again moves the entry")
end)

test("BUG-1: a drop the bare link's base quality hid comes back when the complete link merges in", function()
    local NS, m, LF = party()
    NS.addon.db.profile.feed = { quality = { mode = "fixed", fixed = 4, upgradeOverride = false } }
    encounterSelf(m, BARE)
    assertEqual(#LF.Drops(), 0, "Rare under an Epic floor: hidden")
    chatSelf(m, FULL)
    local rec = only(LF)
    assertEqual(rec.link, FULL); assertEqual(rec.facts.quality, 4)
end)

-- ---------------------------------------------------------------------------------------------
-- core/ItemRead.lua
-- ---------------------------------------------------------------------------------------------

test("ItemRead: LinkDetail reads the bonus ids, the modifiers, the context and how complete a link is", function()
    local NS = T.newAddon()
    local IR = NS.ItemRead
    local d = IR.LinkDetail(FULL)
    assertEqual(d.itemID, PLUME); assertEqual(d.context, 35)
    assertEqual(table.concat(d.bonusIDs, ","), "10390,6652,10383,10254,1520")
    assertEqual(d.numModifiers, 1); assertEqual(d.modifiers[28], 2462)
    assertTrue(d.complete)
    assertEqual(d.itemString, "item:159617::::::::80:577::35:5:10390:6652:10383:10254:1520:1:28:2462:::::")
    local bare = IR.LinkDetail(BARE)
    assertFalse(bare.complete); assertEqual(#bare.bonusIDs, 0); assertEqual(bare.numModifiers, 0)
    assertTrue(d.score > bare.score)
    assertEqual(IR.LinkDetail("item:42").itemID, 42, "a bare item string")
    assertNil(IR.LinkDetail("|Hspell:42|h[Spell]|h")); assertNil(IR.LinkDetail(nil))
end)

test("ItemRead: BetterLink keeps the more complete link, the first on a tie, and never a non-item", function()
    local IR = T.newAddon().ItemRead
    assertEqual(IR.BetterLink(BARE, FULL), FULL)
    assertEqual(IR.BetterLink(FULL, BARE), FULL)
    assertEqual(IR.BetterLink(FULL, BAGGED), FULL, "a tie keeps the first")
    assertEqual(IR.BetterLink(BAGGED, FULL), BAGGED)
    assertEqual(IR.BetterLink(nil, BARE), BARE); assertEqual(IR.BetterLink(BARE, "nonsense"), BARE)
    assertNil(IR.BetterLink(nil, nil))
end)

test("ItemRead: the identity is the item and its bonus ids; unique id, level, spec and modifiers do not count", function()
    local IR = T.newAddon().ItemRead
    assertEqual(IR.IdentityKey(FULL), "159617|1520,6652,10254,10383,10390")
    assertTrue(IR.SameItem(FULL, BAGGED))
    assertFalse(IR.SameItem(FULL, BARE), "other bonus ids: another item")
    assertTrue(IR.SameItem(BARE, "item:159617"))
    assertFalse(IR.SameItem(nil, nil))
end)

test("ItemRead: EffectiveItemLevel answers gear's detailed level, else its base, and nothing for non-gear", function()
    local NS, _, m = T.newAddon()
    local IR = NS.ItemRead
    seedPlume(m)
    local level, source = IR.EffectiveItemLevel(FULL)
    assertEqual(level, 311); assertEqual(source, "detailed")
    m.C_Item.GetDetailedItemLevelInfo = function() return nil end
    level, source = IR.EffectiveItemLevel(FULL)
    assertEqual(level, 19); assertEqual(source, "base")
    local REAGENT = "|cnIQ1:|Hitem:5000::::::::80:::::|h[Ore]|h|r"
    m.addItem(REAGENT, { name = "Ore", quality = 1, ilvl = 70, equipLoc = "", classID = 7, subClassID = 0 })
    assertNil(IR.EffectiveItemLevel(REAGENT), "a reagent's level means nothing")
    assertNil(IR.EffectiveItemLevel("|cnIQ4:|Hitem:999::::::::80:::::|h[Uncached]|h|r"))
end)

test("ItemRead: a bag location answers the exact level and quality; an empty slot answers nothing", function()
    local NS, _, m = T.newAddon()
    local IR = NS.ItemRead
    m.bagGUIDs["0:3"] = "Item-1-0003"
    m.bagItemReads["0:3"] = { ilvl = 311, quality = 4 }
    assertEqual(IR.ItemLevelAt(0, 3), 311); assertEqual(select(2, IR.ItemLevelAt(0, 3)), "current")
    assertEqual(IR.QualityAt(0, 3), 4); assertEqual(select(2, IR.QualityAt(0, 3)), "location")
    assertEqual(IR.EffectiveItemLevel({ bag = 0, slot = 3 }), 311)
    assertNil(IR.ItemLevelAt(0, 4)); assertNil(IR.QualityAt(0, 4))
    m.C_Item.GetCurrentItemLevel = nil
    assertNil(IR.ItemLevelAt(0, 3), "no API: nothing, never a raise")
    m.issecretvalue = T.isSecret
    m.bagItemReads["0:3"].quality = T.secret(4)
    assertNil(IR.QualityAt(0, 3), "a secret answer is no answer")
end)

test("ItemRead: QualityOf answers the client's quality for the link, else the link's color", function()
    local NS, _, m = T.newAddon()
    local IR = NS.ItemRead
    seedPlume(m)
    local q, source = IR.QualityOf(FULL)
    assertEqual(q, 4); assertEqual(source, "item")
    assertEqual(IR.QualityOf(BARE), 3, "a bare link answers the base item")
    m.items[FULL].loadsNeeded = 1
    q, source = IR.QualityOf(FULL)
    assertEqual(q, 4); assertEqual(source, "link", "uncached: the color")
    assertNil(IR.QualityOf("|Hitem:7::::::::80:::::|h[Uncolored]|h"))
end)

test("ItemFacts: the level and quality say where they came from", function()
    local NS = party()
    local f = NS.ItemFacts.Read(FULL)
    assertEqual(f.ilvlSource, "detailed"); assertEqual(f.qualitySource, "item")
end)

test("FeedRecords: a merge keeps the more complete link, chat's on a tie", function()
    local FR = T.newAddon().FeedRecords
    assertEqual(FR.PreferredLink(BARE, FULL, "encounter"), FULL)
    assertEqual(FR.PreferredLink(FULL, BARE, "chat"), FULL)
    assertEqual(FR.PreferredLink(BAGGED, FULL, "chat"), FULL, "a tie: chat's")
    assertEqual(FR.PreferredLink(FULL, BAGGED, "history"), FULL, "a tie: the first")
end)

-- ---------------------------------------------------------------------------------------------
-- The bag match tolerates non-identity fields
-- ---------------------------------------------------------------------------------------------

test("trade timer: two own copies of one item id each match the bag item of their own identity", function()
    local NS, m, LF = party()
    local OTHER = "|cnIQ4:|Hitem:159617::::::::80:577::35:2:10390:1500:::::|h[Lustrous Golden Plumage]|h|r"
    local OTHER_BAGGED = "|cnIQ4:|Hitem:159617:::::::777:80:577::35:2:10390:1500:::::|h[Lustrous Golden Plumage]|h|r"
    m.addItem(OTHER, trinket(4, 300)); m.addItem(OTHER_BAGGED, trinket(4, 300))
    local a = NS.LootFeed.Add(FULL)
    local b = NS.LootFeed.Add(OTHER)
    -- the bag lists the second drop's copy first: by item id alone it would take the first drop
    m.bags[0][1], m.bagGUIDs["0:1"], m.tooltips.bag["0:1"] = OTHER_BAGGED, "Item-1-0001", { lines = {} }
    m.bags[0][2], m.bagGUIDs["0:2"], m.tooltips.bag["0:2"] = BAGGED, "Item-1-0002", { lines = {} }
    m.advance(0)
    assertEqual(NS.TradeTimer.ForDrop(a).slot, 2)
    assertEqual(NS.TradeTimer.ForDrop(b).slot, 1)
    assertEqual(#LF.Drops(), 2)
end)

-- ---------------------------------------------------------------------------------------------
-- The `drops` diagnostics line
-- ---------------------------------------------------------------------------------------------

local function report(NS)
    local lines = {}
    for _, sec in ipairs(NS.Diagnostics.Sections()) do
        if sec[1] == "drops" then
            sec[2]({ add = function(_, _, fmt, ...)
                local args = { ... }
                for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
                lines[#lines + 1] = fmt:format(unpack(args))
            end, joined = function() end })    -- the counts by reason: tests/test_feed_counts.lua
        end
    end
    return lines
end

test("diagnostics: one drops line per drop names its sources, link, level and quality with their sources, and the bag match", function()
    local NS, m = party()
    assertEqual(report(NS)[1], "drops: none")
    encounterSelf(m, BARE)
    chatSelf(m, FULL)
    m.bags[0][1], m.bagGUIDs["0:1"], m.tooltips.bag["0:1"] = BAGGED, "Item-1-0001", { lines = {} }
    m.bagItemReads["0:1"] = { ilvl = 311, quality = 4 }
    m.advance(0)
    local line = report(NS)[1]
    assertTrue(line:find("sources=chat,encounter", 1, true) ~= nil, line)
    assertTrue(line:find("item=item:159617:", 1, true) ~= nil, line)
    assertTrue(line:find("complete=true ilvl=311 (current) quality=4 (location) mine=true bag=yes", 1, true) ~= nil, line)
end)

-- ---------------------------------------------------------------------------------------------
-- BUG-2: the real game tooltip
-- ---------------------------------------------------------------------------------------------

test("BUG-2: your own drop matched to its bag item shows the bag item; moved away, its link", function()
    local NS, m = party()
    local id = NS.LootFeed.Add(FULL)
    m.bags[0][1], m.bagGUIDs["0:1"], m.tooltips.bag["0:1"] = BAGGED, "Item-1-0001", { lines = {} }
    m.advance(0)
    local WG = NS.WindowGroup
    local b = { link = FULL, ownDropId = id }
    assertEqual(WG.SetItemTooltip(m.GameTooltip, b), "bag")
    assertEqual(m.tooltipSets[#m.tooltipSets], "bag:0:1")
    m.bags[0][1] = nil
    assertEqual(WG.SetItemTooltip(m.GameTooltip, b), "link", "the slot no longer holds it")
    assertEqual(m.tooltipSets[#m.tooltipSets], "link:" .. FULL)
    assertEqual(WG.Where(NS.LootFeed.Get(id)).dropId, id)
    assertNil(WG.Where({ isMine = true, test = true, id = 9 }), "a test drop: its link")
    assertNil(WG.Where({ isMine = false, id = 9 }), "someone else's drop: its link")
end)

test("BUG-2: an item you wear shows your inventory slot; someone else's item its link", function()
    local NS, m = party()
    local WG = NS.WindowGroup
    local mine = { link = ringLink(102), worn = { unit = "player", slot = 13 } }
    assertEqual(WG.SetItemTooltip(m.GameTooltip, mine), "inventory")
    assertEqual(m.tooltipSets[#m.tooltipSets], "inventory:player:13")
    mine.worn.slot = 11
    assertEqual(WG.SetItemTooltip(m.GameTooltip, mine), "link", "slot 11 holds another item")
    assertEqual(WG.SetItemTooltip(m.GameTooltip, { link = FULL }), "link")
end)

test("BUG-2: a row's item button and its name show the real tooltip, the addon's line after the game's", function()
    local NS, m = party()
    NS.SchemaRuntime.Set("window.compactInRuns", false)   -- the table first; the compact card below
    local id = NS.LootFeed.Add(FULL)
    m.bags[0][1], m.bagGUIDs["0:1"], m.tooltips.bag["0:1"] = BAGGED, "Item-1-0001", { lines = {} }
    m.advance(0)
    local order = {}
    local add = m.GameTooltip.AddLine
    m.GameTooltip.AddLine = function(self, text, ...)
        order[#order + 1] = "line"
        return add(self, text, ...)
    end
    local set = m.GameTooltip.SetBagItem
    m.GameTooltip.SetBagItem = function(self, ...)
        order[#order + 1] = "game"
        return set(self, ...)
    end
    NS.ShowWindow()
    NS.Window.SelectTab("mine")
    local row = NS.WindowMine.Drawn().rows[1]
    assertEqual(row.dropId, id)
    row.cells.item.button:__fire("OnEnter")
    assertEqual(m.tooltipSets[#m.tooltipSets], "bag:0:1")
    assertEqual(table.concat(order, ","), "game,line")
    row.cells.item:__fire("OnEnter")
    assertEqual(m.tooltipSets[#m.tooltipSets], "bag:0:1", "the name too")
    NS.SetWindowMode("compact")
    local card = NS.WindowMine.Drawn().rows[1]
    assertEqual(card.dropId, id)
    m.tooltipSets[#m.tooltipSets + 1] = "reset"
    card.icon:__fire("OnEnter")
    assertEqual(m.tooltipSets[#m.tooltipSets], "bag:0:1", "the compact card's icon")
    m.tooltipSets[#m.tooltipSets + 1] = "reset"
    card.cells.item.hit:__fire("OnEnter")
    assertEqual(m.tooltipSets[#m.tooltipSets], "bag:0:1", "and its name")
end)

test("BUG-2: the detail card's Replaces row keeps your worn slot for the real tooltip, never the looter's", function()
    local DC = T.newAddon().DetailCells
    local base = { link = ringLink(102), ilvl = 300, slot = 13 }
    local drop = { link = FULL, facts = { ilvl = 311 }, isMine = false,
        me = { verdict = "upgrade", baseline = base, ilvlDelta = 11, reasons = {} },
        them = { verdict = "upgrade", baseline = base, ilvlDelta = 11, reasons = {} },
        looter = { name = "Brakk" } }
    assertEqual(DC.ForYou(drop, "none").rows[1].wornSlot, 13)
    assertNil(DC.ForLooter(drop, nil, nil, 0).rows[1].wornSlot)
end)
