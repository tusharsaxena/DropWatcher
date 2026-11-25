-- tests/test_item_search_tip.lua — Item Search's block on every item tooltip (DropWatcher#17, Item
-- Search spec §4.4, mockup board 1; modules/ItemSearchTip.lua). The client's TooltipDataProcessor is
-- this addon's own test double (tests/mock_tooltip_data.lua): the kit models none. Every ForeverDB
-- value is the kit fake's invented data (tests/_kit/mock_foreverdb.lua); the Crafting rows read the
-- shipped recipe table (Blizzard client DB2 data, core/RecipeReagentsForever.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is inert" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's inert case; the Forever cases cover WoW Forever" or nil

local LINEN = 2589   -- Linen Cloth: a First Aid and Tailoring reagent in the shipped table

-- The addon enabled with the ForeverDB fake and the tooltip double; `load` runs the 5 s login load.
-- `setup(m)` runs on the mock before the load. Answers NS, the mock, the double, the fake.
local function enabled(opts)
    opts = opts or {}
    local tdp, fake
    local NS, _, m = T.enableAddon{ mock = function(mm)
        fake = FDB.install(mm, { preset = opts.preset or "present" })
        tdp = TDP.install(mm)
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        if opts.setup then opts.setup(mm) end
    end }
    if opts.load ~= false then
        m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        m.advance(5)
    end
    return NS, m, tdp, fake
end

local function tipSettings(NS) return NS.addon.db.profile.itemSearch.tooltip end

-- The block's lines on `tip` (the double writes one client line first: the item's name).
local function block(tdp, tip)
    local out = tdp.texts(tip)
    table.remove(out, 1)
    return out
end

local function find(lines, needle)
    for i, s in ipairs(lines) do
        if s:find(needle, 1, true) then return i end
    end
    return nil
end

-- ── the hook ────────────────────────────────────────────────────────────────────────────────

test("item search tip: one Item post call is registered at OnEnable, once a session", function()
    local NS, _, tdp = enabled({ load = false })
    -- red under: no Install at OnEnable, or a second registration on a second Install
    assertEqual(tdp.count(), 1)
    assertTrue(NS.ItemSearchTip.Install())
    assertEqual(tdp.count(), 1, "Install again registers nothing")
end, FOREVER_ONLY)

test("item search tip: on Retail nothing is registered and nothing is written", function()
    local NS, _, tdp = enabled()
    assertEqual(tdp.count(), 0)
    assertFalse(NS.ItemSearchTip.Install())
    local tip = tdp.tooltip("GameTooltip")
    assertFalse(NS.ItemSearchTip.OnTooltip(tip, { id = IDS.blade }))
    assertEqual(#block(tdp, tip), 0)
end, RETAIL_ONLY)

-- ── the owner's rule: nothing before ForeverDB loads, or without it ─────────────────────────

test("item search tip: before ForeverDB's load there is no block at all, and a hover never loads it", function()
    local _, m, tdp, fake = enabled({ load = false })
    local tip = tdp.tooltip("GameTooltip")
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    tdp.show(tip, LINEN)
    tdp.show(tip, IDS.blade)
    -- red under: a block before the load (even Crafting: the owner), or a hover that loads ForeverDB
    assertEqual(#block(tdp, tip), 0); assertEqual(fake.loads, 0)
    m.advance(5)
    assertEqual(fake.loads, 1)
    tdp.show(tip, IDS.blade)
    assertTrue(#block(tdp, tip) > 0, "after the load the block shows")
end, FOREVER_ONLY)

test("item search tip: without ForeverDB (or a failed load) no block, not even Crafting", function()
    for _, preset in ipairs({ "missing", "loadfails" }) do
        local _, _, tdp = enabled({ preset = preset })
        local tip = tdp.tooltip("GameTooltip")
        tdp.show(tip, LINEN)
        -- red under: the shipped table's Crafting rows drawn without ForeverDB
        assertEqual(#block(tdp, tip), 0, preset)
    end
end, FOREVER_ONLY)

-- ── what it writes ──────────────────────────────────────────────────────────────────────────

test("item search tip: separator, title, Drops from and Sold by, in order; Also off; no hint unbound", function()
    local _, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    assertTrue(b[1]:find("WHITE8X8:1:160:", 1, true) ~= nil, "the separator: a 160 x 1 rule")
    assertTrue(b[2]:find("Drop Watcher · Item Search", 1, true) ~= nil and b[2]:find("icons\\search:", 1, true) ~= nil,
        "the title with the magnifier")
    assertEqual(b[3], "Drops from")
    assertEqual(b[4], "  Fixture Crate | 100%")
    assertEqual(b[5], "  Fixture Gnoll (10-12) | 25%")
    assertEqual(b[6], "  Fixture Coffer | 5.0%")
    assertEqual(b[7], "  Fixture Kobold (5-6) | rate unknown")
    assertEqual(b[8], "  World drop | level 8+")
    assertEqual(b[9], "Sold by")
    -- the cheapest vendor (the trainer, 1200) carries the price
    assertEqual(b[10], "  Fixture Vendor"); assertEqual(b[11], "  Fixture Trainer | 1200c")
    -- red under: the Also section on by default, or a hint with nothing bound
    assertEqual(#b, 11)
    assertTrue(find(b, "Reward from") == nil)
    assertTrue(find(b, "open in Item Search") == nil)
end, FOREVER_ONLY)

test("item search tip: the hint names the bound key as the client writes it, and its switch hides it", function()
    local NS, m, tdp = enabled()
    m.bindKey("ALT-CTRL-D", NS.Constants.ITEM_SEARCH.BINDING)
    m.GetBindingText = function(key) return key == "ALT-CTRL-D" and "Alt-Ctrl-D" or key end
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    assertEqual(b[#b], "Alt-Ctrl-D: open in Item Search")
    tipSettings(NS).hint = false
    tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    assertTrue(find(b, "open in Item Search") == nil, "the hint's switch")
end, FOREVER_ONLY)

test("item search tip: the separator and title follow their switch; the accent is read at call time", function()
    local NS, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    local real = NS.SkinColor
    NS.SkinColor = function(name)
        if name == "text.accent" then return 0.2, 0.4, 0.6 end
        return real(name)
    end
    tdp.show(tip, IDS.blade)
    NS.SkinColor = real
    -- red under: the accent cached at load (a skin switch would not follow)
    assertTrue(tip.__lines[2].text:find(":51:102:153|t", 1, true) ~= nil, "the rule tinted 0.2, 0.4, 0.6")
    assertEqual(tip.__lines[3].r, 0.2); assertEqual(tip.__lines[3].b, 0.6)
    tipSettings(NS).header = false
    tdp.show(tip, IDS.blade)
    assertEqual(block(tdp, tip)[1], "Drops from", "no separator or title")
end, FOREVER_ONLY)

test("item search tip: sections follow their switches and the stored order; Also lists the rewarding quest", function()
    local NS, _, tdp = enabled()
    local p = tipSettings(NS)
    p.header, p.sections.drops, p.sections.also = false, false, true
    p.order = { "also", "bogus", "vendors", "also" }
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    -- red under: a switched-off section drawn, an unknown key failing, or the stored order ignored
    assertEqual(b[1], "Also"); assertEqual(b[2], "  Reward from | Fixture Errand")
    assertEqual(b[3], "Sold by")
    assertTrue(find(b, "Drops from") == nil)
    tdp.show(tip, IDS.letter)
    assertEqual(block(tdp, tip)[2], "  Starts quest | Fixture Summons")
end, FOREVER_ONLY)

test("item search tip: the drop count setting caps the rows, the rest is \"and N more\"", function()
    local NS, _, tdp = enabled()
    tipSettings(NS).rows = 1
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    assertEqual(b[4], "  Fixture Crate | 100%"); assertEqual(b[5], "  World drop | level 8+")
    assertEqual(b[6], "  and 3 more")
end, FOREVER_ONLY)

test("item search tip: quest marks ! ? and the check mark; completed hidden by default", function()
    local states = {}
    local NS, _, tdp = enabled({ setup = function(mm)
        mm.UnitRace = function() return "R", "R", 1 end
        mm.UnitClass = function() return "C", "C", 4 end
        mm.C_QuestLog = {
            GetLogIndexForQuestID = function(id) if states[id] == "log" then return 2 end end,
            IsQuestFlaggedCompleted = function(id) return states[id] == "done" end,
        }
    end })
    local tip = tdp.tooltip("GameTooltip")
    tipSettings(NS).header = false
    tdp.show(tip, IDS.leather)
    local b = block(tdp, tip)
    local q = find(b, "Quests")
    assertTrue(q ~= nil, "a Quests section")
    assertTrue(b[q + 1]:find("?|r Fixture Errand", 1, true) ~= nil, "not picked up: ?")
    assertTrue(b[q + 2]:find("?|r Fixture Hunt", 1, true) ~= nil)
    states[IDS.errand], states[IDS.hunt] = "done", "log"
    tdp.show(tip, IDS.leather)
    b = block(tdp, tip)
    q = find(b, "Quests")
    -- red under: a completed quest shown with Hide completed quests on, or the state cached
    assertTrue(b[q + 1]:find("!|r Fixture Hunt", 1, true) ~= nil, "in the log: !")
    assertTrue(find(b, "Fixture Errand") == nil, "completed: hidden")
    tipSettings(NS).hideCompleted = false
    tdp.show(tip, IDS.leather)
    b = block(tdp, tip)
    q = find(b, "Quests")
    assertTrue(b[q + 1]:find("icons\\confirm:", 1, true) ~= nil and b[q + 1]:find("Fixture Errand", 1, true) ~= nil,
        "completed: the check mark")
end, FOREVER_ONLY)

test("item search tip: crafting marks a known recipe with a dot in its skill-up color, an unknown one with a ring", function()
    local known
    local NS, _, tdp = enabled({ setup = function(mm)
        mm.IsPlayerSpell = function(spell) return spell == known end
    end })
    local rows = NS.ItemSearch.Get(LINEN).crafting
    known = rows[1].spell
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, LINEN)
    local b = block(tdp, tip)
    local c = find(b, "Crafting")
    assertTrue(c ~= nil, "a Crafting section")
    -- red under: the known mark on an unknown recipe, or a glyph the tooltip's face cannot draw
    assertTrue(b[c + 1]:find("phosphor\\circle:", 1, true) ~= nil, "known: the filled dot")
    assertTrue(b[c + 1]:find(rows[1].name, 1, true) ~= nil)
    assertTrue(b[c + 2]:find("phosphor\\circle-dashed:", 1, true) ~= nil, "unknown: the ring")
    T.assertGlyphSafe(table.concat(b, "\n"), "the block")
    -- the dot's tint is the skill-up color (no rank here: plain); the right side names the profession
    local profession = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
        [185] = "Cooking", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting" }
    assertTrue(b[c + 1]:find(" | " .. profession[rows[1].skillLine], 1, true) ~= nil, "the profession on the right")
    local IST = NS.ItemSearchTip
    local C = NS.Constants
    local mark = IST.CraftMark({ known = true, color = "green" })
    local g = C.TONE.skillGreen
    assertTrue(mark:find((":%d:%d:%d|t"):format(math.floor(g.r * 255 + 0.5), math.floor(g.g * 255 + 0.5),
        math.floor(g.b * 255 + 0.5)), 1, true) ~= nil, "green: the client's easy hue")
end, FOREVER_ONLY)

test("item search tip: an item with nothing to show gets no block, title and hint included", function()
    local NS, m, tdp = enabled()
    m.bindKey("ALT-CTRL-D", NS.Constants.ITEM_SEARCH.BINDING)
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.pebble)
    assertEqual(#block(tdp, tip), 0)
end, FOREVER_ONLY)

-- ── never twice ─────────────────────────────────────────────────────────────────────────────

test("item search tip: never twice per show; the client's refresh, a hide and another item write it again", function()
    local _, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local n = #block(tdp, tip)
    tdp.repost(tip, IDS.blade)
    -- red under: no guard (another processing of the same data adds a second block)
    assertEqual(#block(tdp, tip), n, "a second post call for the same show adds nothing")
    tdp.refresh(tip, IDS.blade)
    assertEqual(#block(tdp, tip), n, "the refresh clears first, so the block is written once again")
    tdp.hide(tip)
    tdp.repost(tip, IDS.blade)
    -- red under: the mark kept past OnHide
    assertEqual(#block(tdp, tip), 2 * n, "after a hide the mark is gone")
    tdp.show(tip, IDS.leather)
    assertTrue(#block(tdp, tip) > 0)
end, FOREVER_ONLY)

-- ── which tooltips ──────────────────────────────────────────────────────────────────────────

test("item search tip: every item tooltip, comparison tooltips only with their setting", function()
    local NS, _, tdp = enabled()
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "SomeAddonTooltip" }) do
        local tip = tdp.tooltip(name)
        tdp.show(tip, IDS.blade)
        assertTrue(#block(tdp, tip) > 0, name)
    end
    local shop, ref = tdp.tooltip("ShoppingTooltip1"), tdp.tooltip("ItemRefShoppingTooltip2")
    tdp.show(shop, IDS.blade); tdp.show(ref, IDS.blade)
    -- red under: the comparison tooltips on by default (the owner: off)
    assertEqual(#block(tdp, shop), 0); assertEqual(#block(tdp, ref), 0)
    tipSettings(NS).comparison = true
    tdp.show(shop, IDS.blade)
    assertTrue(#block(tdp, shop) > 0, "Comparison tooltips too")
end, FOREVER_ONLY)

test("item search tip: Shift-only writes the block only while Shift is held", function()
    local NS, m, tdp = enabled()
    tipSettings(NS).shiftOnly = true
    local tip = tdp.tooltip("GameTooltip")
    m.shift = false
    tdp.show(tip, IDS.blade)
    assertEqual(#block(tdp, tip), 0)
    m.shift = true
    tdp.show(tip, IDS.blade)
    assertTrue(#block(tdp, tip) > 0)
end, FOREVER_ONLY)

test("item search tip: the tooltip switch, a stand-down and a forbidden tooltip write nothing", function()
    local NS, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tipSettings(NS).enabled = false
    tdp.show(tip, IDS.blade)
    assertEqual(#block(tdp, tip), 0, "switched off")
    tipSettings(NS).enabled = true
    NS.SchemaRuntime.Set("enabled", false)
    tdp.show(tip, IDS.blade)
    assertEqual(#block(tdp, tip), 0, "stood down")
    NS.SchemaRuntime.Set("enabled", true)
    tip.forbidden = true
    tdp.show(tip, IDS.blade)
    assertEqual(#block(tdp, tip), 0, "forbidden")
end, FOREVER_ONLY)

-- ── secret-safe ─────────────────────────────────────────────────────────────────────────────

test("item search tip: it reads only data.id and data.hyperlink, and a secret id writes nothing", function()
    local _, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    local read = {}
    local data = setmetatable({}, { __index = function(_, k)
        read[#read + 1] = tostring(k)
        if k == "hyperlink" then return ("|cffffffff|Hitem:%d::::::::|h[x]|h|r"):format(IDS.blade) end
        return nil
    end })
    tdp.show(tip, IDS.blade, data)
    -- red under: a read of any other field (the line texts can be secret)
    assertEqual(table.concat(read, ","), "id,hyperlink")
    assertTrue(#block(tdp, tip) > 0, "the hyperlink's id")
    tdp.show(tip, IDS.blade, { id = T.secret(IDS.blade) })
    assertEqual(#block(tdp, tip), 0, "a secret id")
end, FOREVER_ONLY)
