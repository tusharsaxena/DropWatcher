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
    -- red under: the magnifier before the title (feedback spec §7, T2)
    assertEqual(b[2], "Drop Watcher · Item Search", "the title, no icon")
    assertEqual(b[3], "Drops from")
    -- ranked for a level-80 player standing nowhere (feedback spec §3): the object and the
    -- container (no level) before the creatures far below the band, each tier by chance
    assertEqual(b[4], "  Fixture Crate | 100%")
    assertEqual(b[5], "  Fixture Coffer | 5.0%")
    assertEqual(b[6], "  Fixture Gnoll (10-12) | 25%")
    assertEqual(b[7], "  Fixture Kobold (5-6) | rate unknown")
    assertEqual(b[8], "  World drop | level 8+")
    assertEqual(b[9], "Sold by")
    -- neither vendor is in your zone or on your continent: by name; the cheapest (the trainer,
    -- 1200) carries the price
    assertEqual(b[10], "  Fixture Trainer | 1200c"); assertEqual(b[11], "  Fixture Vendor")
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
    -- ranked: the quest in your log first, the completed one last (feedback spec §3)
    assertTrue(b[q + 1]:find("Fixture Hunt", 1, true) ~= nil)
    assertTrue(b[q + 2]:find("icons\\confirm:", 1, true) ~= nil and b[q + 2]:find("Fixture Errand", 1, true) ~= nil,
        "completed: the check mark")
end, FOREVER_ONLY)

test("item search tip: crafting glyphs: an up arrow for a skill-up, a light gray dash for none, a dark gray lock for not known", function()
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
    -- red under: the old dots (feedback spec §5.7, T4), the known mark on an unknown recipe, or a
    -- glyph the tooltip's face cannot draw. No rank here, so no skill-up color: the dash.
    assertTrue(b[c + 1]:find("phosphor\\minus:", 1, true) ~= nil, "known, no skill-up: the dash")
    assertTrue(b[c + 1]:find(rows[1].name, 1, true) ~= nil, "a known recipe ranks first")
    assertTrue(b[c + 2]:find("phosphor\\lock:", 1, true) ~= nil, "not known: the padlock")
    assertTrue(find(b, "circle") == nil, "no dot or ring is left")
    T.assertGlyphSafe(table.concat(b, "\n"), "the block")
    -- the dot's tint is the skill-up color (no rank here: plain); the right side names the profession
    local profession = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
        [185] = "Cooking", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting" }
    assertTrue(b[c + 1]:find(" | " .. profession[rows[1].skillLine], 1, true) ~= nil, "the profession on the right")
    local IST = NS.ItemSearchTip
    local C = NS.Constants
    local function tinted(mark, tone)
        local g = C.TONE[tone]
        return mark:find((":%d:%d:%d|t"):format(math.floor(g.r * 255 + 0.5), math.floor(g.g * 255 + 0.5),
            math.floor(g.b * 255 + 0.5)), 1, true) ~= nil
    end
    for color, tone in pairs({ orange = "skillOrange", yellow = "skillYellow", green = "skillGreen" }) do
        local mark = IST.CraftMark({ known = true, color = color })
        assertTrue(mark:find("phosphor\\arrow-up:", 1, true) ~= nil and tinted(mark, tone), color .. ": the up arrow in its hue")
    end
    local gray = IST.CraftMark({ known = true, color = "gray" })
    assertTrue(gray:find("phosphor\\minus:", 1, true) ~= nil and tinted(gray, "glyphKnown"), "gray: the light gray dash")
    local locked = IST.CraftMark({ known = false, color = "orange" })
    assertTrue(locked:find("phosphor\\lock:", 1, true) ~= nil and tinted(locked, "glyphLocked"), "not known: the dark gray lock")
    assertEqual(C.TONE.glyphKnown.r, 176 / 255, "#b0b0b0"); assertEqual(C.TONE.glyphLocked.r, 90 / 255, "#5a5a5a")
    assertEqual(IST.CraftGlyph({ known = true }), "flat", "no breakpoints: no skill-up to show")
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

-- ── the feedback run: ranked, capped, my professions (Item Search feedback spec §3, §4, §7) ─────

-- The player's skill list (C_SkillInfo): `{ [skillLine] = rank }`.
local function skills(mm, ranks)
    local lines = {}
    for line, rank in pairs(ranks) do lines[#lines + 1] = { skillLineID = line, rank = rank } end
    mm.C_SkillInfo = { GetNumSkillLines = function() return #lines end,
        GetSkillLineInfo = function(i) return lines[i] end }
end

test("item search tip: the rows follow the player: the level band and the zone move a creature up", function()
    local NS, m, tdp = enabled()
    tipSettings(NS).header = false
    local tip = tdp.tooltip("GameTooltip")
    m.__context.level = 11
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    -- red under: the old chance-only order (Gnoll after Coffer) for a level-11 player
    assertEqual(b[2], "  Fixture Crate | 100%")
    assertEqual(b[3], "  Fixture Gnoll (10-12) | 25%", "in the band [6, 14]: with the object and the container, by chance")
    assertEqual(b[4], "  Fixture Coffer | 5.0%")
    m.C_Map = { GetBestMapForUnit = function() return IDS.mapA end,
        GetMapInfo = function(id) if id == IDS.mapA then return { mapType = 3 } end end }
    m.__context.level = 80
    tdp.hide(tip)
    tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    assertEqual(b[2], "  Fixture Gnoll (10-12) | 25%", "a spot in your zone first, whatever its level")
    assertEqual(NS.ItemSearch.Me().mapID, IDS.mapA)
end, FOREVER_ONLY)

test("item search tip: every section stops at Rows per section, the rest one \"and N more\" line", function()
    local NS, _, tdp = enabled()
    local p = tipSettings(NS)
    p.header, p.rows = false, 1
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    local v = find(b, "Sold by")
    -- red under: the cap on Drops from alone (the old dropsShown)
    assertEqual(b[v + 1], "  Fixture Trainer | 1200c"); assertEqual(b[v + 2], "  and 1 more")
    tdp.show(tip, IDS.leather)
    b = block(tdp, tip)
    local sk = find(b, "Skinned from")
    assertTrue(sk ~= nil, "the Skinned from section, on by default")
    assertEqual(b[sk + 1], "  Fixture Kobold (5-6) | 75%"); assertEqual(b[sk + 2], "  and 1 more")
    tdp.hide(tip)
    tdp.show(tip, LINEN)
    b = block(tdp, tip)
    local c = find(b, "Crafting")
    assertTrue(b[c + 2]:find("^  and %d+ more$") ~= nil, "Crafting capped too: " .. tostring(b[c + 2]))
    p.sections.skinned = false
    tdp.show(tip, IDS.leather)
    assertTrue(find(block(tdp, tip), "Skinned from") == nil, "its switch")
end, FOREVER_ONLY)

test("item search tip: only the professions you know: the rest counted on one dim line, or that line alone", function()
    local NS, m, tdp = enabled({ setup = function(mm) skills(mm, { [197] = 50 }) end })
    local p = tipSettings(NS)
    p.header, p.rows = false, 20
    local all = NS.ItemSearch.Get(LINEN).crafting
    local tailoring = 0
    for _, r in ipairs(all) do if r.skillLine == 197 then tailoring = tailoring + 1 end end
    assertTrue(tailoring > 0 and tailoring < #all, "the shipped table has Linen in Tailoring and elsewhere")
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, LINEN)
    local b = block(tdp, tip)
    local c = find(b, "Crafting")
    -- red under: other professions' recipes shown, or the count left out
    for i = c + 1, c + tailoring do assertTrue(b[i]:find(" | Tailoring", 1, true) ~= nil, b[i]) end
    assertEqual(b[c + tailoring + 1], ("  +%d in professions you don't know"):format(#all - tailoring))
    skills(m, { [999] = 1 })
    tdp.hide(tip)
    tdp.show(tip, LINEN)
    b = block(tdp, tip)
    c = find(b, "Crafting")
    assertTrue(c ~= nil, "every recipe filtered: the heading stays")
    assertEqual(b[c + 1], ("  +%d in professions you don't know"):format(#all), "and the line alone")
    NS.addon.db.profile.itemSearch.myProfessionsOnly = false
    tdp.hide(tip)
    tdp.show(tip, LINEN)
    b = block(tdp, tip)
    assertTrue(find(b, "professions you don't know") == nil, "off: nothing filtered")
end, FOREVER_ONLY)
