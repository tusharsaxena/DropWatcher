-- tests/test_item_search_tip.lua — Item Search's block on every item tooltip (DropWatcher#17, Item
-- Search spec §4.4, mockup board 1; modules/ItemSearchTip.lua). The client's TooltipDataProcessor is
-- this addon's own test double (tests/mock_tooltip_data.lua): the kit models none. Every ForeverDB
-- value is the kit fake's invented data (tests/_kit/mock_foreverdb.lua); the Crafting rows read the
-- shipped recipe table (Blizzard client DB2 data, core/RecipeReagentsForever.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is inert" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's inert case; the Forever cases cover WoW Forever" or nil

local LINEN = 2589   -- Linen Cloth: a First Aid and Tailoring reagent in the shipped table

local function tipSettings(NS) return NS.addon.db.profile.itemSearch.tooltip end

-- The addon enabled with the ForeverDB fake and the tooltip double; `load` runs the 5 s login load.
-- `setup(m)` runs on the mock before the load. The verdict badge (round 3 spec §4.5) is switched
-- off unless `badge` is true, so the cases about the sections read their lines where they were;
-- tests/test_item_search_verdict.lua covers the badge on the tooltip. Answers NS, the mock, the
-- double, the fake.
local function enabled(opts)
    opts = opts or {}
    local tdp, fake
    local NS, _, m = T.enableAddon{ mock = function(mm)
        fake = FDB.install(mm, { preset = opts.preset or "present" })
        tdp = TDP.install(mm)
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        if opts.setup then opts.setup(mm) end
    end }
    if NS.addon.db and NS.addon.db.profile.itemSearch then tipSettings(NS).badge = opts.badge == true end
    if opts.load ~= false then
        m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        m.advance(5)
    end
    return NS, m, tdp, fake
end

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

test("item search tip: separator, label line, Drops from and Sold by, in order; Also off; no hint unbound", function()
    local _, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    -- red under: the old 160-wide rule escape (round 3 spec §4.2, item 14b: it set the tooltip's width)
    assertEqual(b[1], " ", "the separator's spacer line, no escape")
    -- red under: the old "Drop Watcher · Item Search" title (item 14a)
    assertEqual(b[2], "Drop Watcher", "the label line, nothing at its right yet")
    assertTrue(find(b, "Item Search") == nil, "no title line")
    assertEqual(b[3], "Drops from")
    -- ranked for a level-80 player standing nowhere (feedback spec §3): the object and the
    -- container (no level) before the creatures far below the band, each tier by chance
    assertEqual(b[4], "  Fixture Crate | 100%")
    assertEqual(b[5], "  Fixture Coffer | 5.0%")
    assertEqual(b[6], "  Fixture Gnoll (10-12) | 25%")
    -- red under: the old default of 5 rows per section (ISR3-DW-07: 3), which listed the Kobold too
    assertEqual(b[7], "  World drop | level 8+")
    assertEqual(b[8], "  and 1 more")
    assertEqual(b[9], "Sold by")
    -- neither vendor is in your zone or on your continent: the cheaper first, each with its own
    -- price (round 3 spec §4.4: the trainer's vp 1200, the vendor's vendx 1400)
    assertEqual(b[10], "  Fixture Trainer | 1200c"); assertEqual(b[11], "  Fixture Vendor | 1400c")
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

-- The separator texture's first two points, as { point, relative, relPoint, x, y } each.
local function rulePoints(tex)
    return { tex:GetPoint(1) }, { tex:GetPoint(2) }
end

local function pointText(p, rel)
    return table.concat({ p[1], tostring(p[2] == rel), p[3], p[4], p[5] }, ",")
end

test("item search tip: the separator hangs from the spacer line on two invisible edges, 8 in, one pixel, dw.tipRule", function()
    local NS, m, tdp = enabled()
    local IST, C = NS.ItemSearchTip, NS.Constants
    local tip = tdp.tooltip("GameTooltip")
    assertNil(IST.RuleOf(tip), "no texture before the first block")
    tdp.show(tip, IDS.blade)
    local tex = IST.RuleOf(tip)
    assertTrue(tex ~= nil and tex.__owner == tip, "a texture of the tooltip's own")
    -- red under: a measured line (R4-DW-06: two zero-alpha edge textures carry it, no geometry read)
    assertEqual(#tdp.textures(tip), 3, "the line and its two edges")
    assertTrue(tex:IsShown(), "shown with the block")
    assertEqual(C.ITEM_SEARCH.RULE_INSET, 8)
    local left, right = rulePoints(tex)
    local edgeL, edgeR = left[2], right[2]
    assertTrue(edgeL ~= tip and edgeR ~= tip and edgeL ~= edgeR, "hung from the edges, not from the tooltip")
    assertEqual(pointText(left, edgeL), "TOPLEFT,true,BOTTOMLEFT,8,0")
    assertEqual(pointText(right, edgeR), "TOPRIGHT,true,BOTTOMRIGHT,-8,0")
    -- the spacer is line 2 (the client's item name is line 1): each edge's bottom is its left middle
    local spacer = m.GameTooltipTextLeft2
    assertEqual(pointText({ edgeL:GetPoint(1) }, tip), "TOPLEFT,true,TOPLEFT,0,0")
    assertEqual(pointText({ edgeL:GetPoint(2) }, spacer), "BOTTOMRIGHT,true,LEFT,0,0")
    assertEqual(pointText({ edgeR:GetPoint(1) }, tip), "TOPRIGHT,true,TOPRIGHT,0,0")
    assertEqual(pointText({ edgeR:GetPoint(2) }, spacer), "BOTTOMLEFT,true,LEFT,0,0")
    assertEqual(edgeL:GetAlpha(), 0, "an invisible edge"); assertEqual(edgeR:GetAlpha(), 0)
    assertEqual(tex:GetHeight(), 1, "one physical pixel (no PixelUtil in the harness: 1)")
    assertEqual(tex.__texture, "Interface\\Buttons\\WHITE8X8")
    assertTrue(tex.__snap == true, "snapped to the pixel grid: the client places it, so the client rounds it")
    local want = NS.SKIN_TOKENS["dw.tipRule"].default
    assertEqual(table.concat(want, ","), "0.55,0.46,0.25,0.9", "a dim gold")
    assertEqual(NS.SKIN_TOKENS["dw.tipRule"].follow, "divider")
    local r, g, b, a = NS.SkinColor("dw.tipRule")
    assertEqual(table.concat(tex.__vertex, ","), table.concat({ r, g, b, a or 1 }, ","), "tinted dw.tipRule")
    -- a hide or a clear marks it stale; nobody claims it, so it comes off on the next frame
    tdp.hide(tip)
    assertTrue(tex:IsShown(), "kept through the hide, for a refill of the same item")
    m.advance(0)
    assertFalse(tex:IsShown(), "unclaimed: off on the next frame")
    tdp.show(tip, IDS.blade)
    assertTrue(tex:IsShown())
    tip:ClearLines()
    assertTrue(tex:IsShown(), "kept through the clear")
    m.advance(0)
    -- red under: a stale line left on a tooltip that shows something else now
    assertFalse(tex:IsShown(), "unclaimed after a clear: off on the next frame")
    tdp.show(tip, IDS.blade)
    assertEqual(#tdp.textures(tip), 3, "made once per tooltip")
end, FOREVER_ONLY)

-- The client's refill (R4-DW-06, recon (g) H1): about five times a second it clears the tooltip,
-- sometimes hides it (SetOwner on a bag-slot refill), and fills it again, before the lines are laid out.
local function refill(m, tdp, tip, itemID)
    tip:ClearLines()
    tdp.hide(tip)
    tip.__top = nil
    tdp.show(tip, itemID)
    return m
end

test("item search tip: a refill of the same item keeps the separator up: no one-frame gap", function()
    local NS, m, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local tex = NS.ItemSearchTip.RuleOf(tip)
    local hides, hide = 0, tex.Hide
    tex.Hide = function(self) hides = hides + 1; return hide(self) end
    refill(m, tdp, tip, IDS.blade)
    -- red under: hidden on the clear or the hide, and put back only once the tooltip is laid out
    assertTrue(tex:IsShown(), "shown through the refill, before the next frame")
    assertEqual(hides, 0, "never hidden on a refill of the same item")
    m.advance(0)
    assertTrue(tex:IsShown(), "claimed again: still up after the next frame")
    assertEqual(hides, 0)
    -- another item with no block: the stale line comes off on the next frame
    refill(m, tdp, tip, IDS.pebble)
    m.advance(0)
    assertFalse(tex:IsShown(), "an item with no block: off")
end, FOREVER_ONLY)

test("item search tip: a refill never draws the separator at a second height: no ghost line", function()
    local NS, m, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local tex = NS.ItemSearchTip.RuleOf(tip)
    -- the spacer's font string answers the previous pass's rect while the tooltip's top moves, and a
    -- later post call (another addon's) adds a line and shows the tooltip again, which resizes it
    local spacer = m.GameTooltipTextLeft2
    spacer.GetTop = function() return 476 end
    spacer.GetBottom = function() return 464 end
    m.TooltipDataProcessor.AddTooltipPostCall(m.Enum.TooltipDataType.Item, function(t)
        t:AddLine("Another addon")
        t.__top = 513
        tdp.resize(t)
    end)
    local ys, seen = {}, 0
    local setPoint = tex.SetPoint
    tex.SetPoint = function(self, ...)
        local y = select(5, ...)
        if not ys[tostring(y)] then ys[tostring(y)] = true; seen = seen + 1 end
        return setPoint(self, ...)
    end
    tip.__top = 520
    tdp.refresh(tip, IDS.blade)
    m.advance(0)
    -- red under: measured three times a rebuild from half-finished layout passes (recon (g) H2)
    assertTrue(seen <= 1, "one height a refill, got " .. seen)
    assertTrue(tex:IsShown())
end, FOREVER_ONLY)

test("item search tip: the post call never shows the tooltip mid-fill; a paint outside a fill does", function()
    local NS, _, tdp = enabled()
    local IST = NS.ItemSearchTip
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local before = tip.shows
    tdp.refresh(tip, IDS.blade)
    -- red under: DW's own Show inside the client's fill (it resized the tooltip before later post calls)
    assertEqual(tip.shows - before, 1, "the client's own show alone")
    before = tip.shows
    IST.Paint(tip, { { text = "x", tone = "plain" } })
    assertEqual(tip.shows - before, 1, "a shown tooltip painted outside a fill lays itself out again")
end, FOREVER_ONLY)

test("item search tip: Separator line off: no spacer and no hairline; the label line stays", function()
    local NS, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    local tex = NS.ItemSearchTip.RuleOf(tip)
    tipSettings(NS).header = false
    tdp.show(tip, IDS.blade)
    local b = block(tdp, tip)
    -- red under: the label line tied to the separator's switch (14a: always drawn with the block)
    assertEqual(b[1], "Drop Watcher"); assertEqual(b[2], "Drops from")
    assertFalse(tex:IsShown(), "no hairline")
    local label = tip.__lines[2]
    local t = NS.Constants.TONE.mutedGold
    assertEqual(table.concat({ label.r, label.g, label.b }, ","), table.concat({ t.r, t.g, t.b }, ","), "the label's muted gold")
    -- the settings row's name and words (spec §5)
    local row = NS.SchemaRuntime.FindRow("itemSearch.tooltip.header")
    assertEqual(row.label, "Separator line")
    assertTrue(row.tooltip:find("thin line", 1, true) ~= nil)
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
    assertEqual(b[1], "Drop Watcher")
    assertEqual(b[2], "Also"); assertEqual(b[3], "  Reward from | Fixture Errand")
    assertEqual(b[4], "Sold by")
    assertTrue(find(b, "Drops from") == nil)
    tdp.show(tip, IDS.letter)
    assertEqual(block(tdp, tip)[3], "  Starts quest | Fixture Summons")
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

-- The quest-log double: `states[id]` is "log", "ready" (in the log and ReadyForTurnIn) or "done".
local function questLog(mm, states)
    mm.UnitRace = function() return "R", "R", 1 end
    mm.UnitClass = function() return "C", "C", 4 end
    mm.C_QuestLog = {
        GetLogIndexForQuestID = function(id) if states[id] == "log" or states[id] == "ready" then return 2 end end,
        IsQuestFlaggedCompleted = function(id) return states[id] == "done" end,
        ReadyForTurnIn = function(id) return states[id] == "ready" end,
    }
end

local GOSSIP = "Interface\\GossipFrame\\"

test("item search tip: quest marks in the game's style: yellow !, dim !, gray ?, green ?, a green check; completed hidden by default", function()
    local states = {}
    local NS, m, tdp = enabled({ setup = function(mm) questLog(mm, states) end })
    local IST, C = NS.ItemSearchTip, NS.Constants
    local tip = tdp.tooltip("GameTooltip")
    tipSettings(NS).header = false
    tdp.show(tip, IDS.leather)
    local b = block(tdp, tip)
    local q = find(b, "Quests")
    assertTrue(q ~= nil, "a Quests section")
    -- red under: the old text `?` for a quest not picked up (round 3 item 13: the game's yellow `!`)
    assertTrue(b[q + 1]:find(GOSSIP .. "AvailableQuestIcon:14:14:0:0:64:64:0:64:0:64:255:255:255|t Fixture Errand", 1, true) ~= nil,
        "not picked up: the yellow !, untinted, 14 px")
    assertTrue(b[q + 2]:find("AvailableQuestIcon:14:14:", 1, true) ~= nil and b[q + 2]:find("Fixture Hunt", 1, true) ~= nil)
    m.__context.level = 9
    tdp.hide(tip)
    tdp.show(tip, IDS.leather)
    b = block(tdp, tip)
    q = find(b, "Quests")
    -- red under: the tooltip not telling can from high (it reads the quest's minimum level now)
    assertTrue(b[q + 2]:find("AvailableQuestIcon:14:14:0:0:64:64:0:64:0:64:128:128:128|t Fixture Hunt", 1, true) ~= nil,
        "level 9 under the hunt's 10: the ! dimmed by half")
    m.__context.level = 80
    states[IDS.errand], states[IDS.hunt] = "done", "log"
    tdp.show(tip, IDS.leather)
    b = block(tdp, tip)
    q = find(b, "Quests")
    -- red under: a completed quest shown with Hide completed quests on, or the state cached
    assertTrue(b[q + 1]:find(GOSSIP .. "IncompleteQuestIcon:14:14:0:0:64:64:0:64:0:64:255:255:255|t Fixture Hunt", 1, true) ~= nil,
        "in the log: the gray ?")
    assertTrue(find(b, "Fixture Errand") == nil, "completed: hidden")
    tipSettings(NS).hideCompleted = false
    states[IDS.hunt] = "ready"
    tdp.show(tip, IDS.leather)
    b = block(tdp, tip)
    q = find(b, "Quests")
    local function tinted(tone)
        local t = C.TONE[tone]
        return (":%d:%d:%d|t"):format(math.floor(t.r * 255 + 0.5), math.floor(t.g * 255 + 0.5), math.floor(t.b * 255 + 0.5))
    end
    -- ranked: the quest in your log first, the completed one last (feedback spec §3)
    assertTrue(b[q + 1]:find(GOSSIP .. "ActiveQuestIcon:14:14:", 1, true) ~= nil and b[q + 1]:find(tinted("good"), 1, true) ~= nil
        and b[q + 1]:find("Fixture Hunt", 1, true) ~= nil, "complete, not turned in: the ? tinted green")
    -- red under: the boxed `confirm` (the owner: a check with no background)
    assertTrue(b[q + 2]:find("phosphor\\check-fat:14:14:", 1, true) ~= nil and b[q + 2]:find(tinted("good"), 1, true) ~= nil
        and b[q + 2]:find("Fixture Errand", 1, true) ~= nil, "turned in: the green fat check")
    assertTrue(find(b, "icons\\confirm:") == nil, "confirm is no longer a quest mark")
    T.assertGlyphSafe(table.concat(b, "\n"), "the quest marks")
    assertEqual(C.ITEM_SEARCH.MARK_SIZE, C.ITEM_SEARCH.GLYPH_SIZE, "one size for marks and glyphs")
    -- the media library absent: the characters, colored
    local icon = NS.Icon
    NS.Icon = function() return nil end
    IST.ForgetLooks()
    local chars = {}
    for _, state in ipairs({ "can", "high", "log", "ready", "done" }) do chars[#chars + 1] = IST.QuestMark(state):match("|c%x%x%x%x%x%x%x%x(.)|r") end
    NS.Icon = icon
    IST.ForgetLooks()
    assertEqual(table.concat(chars, ""), "!!??+", "the fallbacks")
end, FOREVER_ONLY)

test("item search tip: the window's quest marks are the tooltip's, at MARK_SIZE", function()
    local NS = enabled()
    local IST, C = NS.ItemSearchTip, NS.Constants
    assertEqual(IST.QuestMark("can"), IST.QuestMark("can", C.ITEM_SEARCH.MARK_SIZE), "the default size is MARK_SIZE")
    assertTrue(IST.QuestMark("log", 20):find("IncompleteQuestIcon:20:20:", 1, true) ~= nil, "a size is honored")
    assertEqual(IST.QuestMark("bogus"), IST.QuestMark("can"), "an unknown state reads as can")
    assertTrue(IST.QuestMark("ready") ~= IST.QuestMark("log"), "ready and log differ")
end, FOREVER_ONLY)

test("item search tip: crafting glyphs: a fat up arrow for a skill-up, a gray left-right arrow for none, a dark gray lock for not known", function()
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
    -- glyph the tooltip's face cannot draw. No rank here, so no skill-up color: the left-right arrow.
    assertTrue(b[c + 1]:find("phosphor\\arrows-horizontal:14:14:", 1, true) ~= nil, "known, no skill-up: the left-right arrow, 14 px")
    assertTrue(b[c + 1]:find(rows[1].name, 1, true) ~= nil, "a known recipe ranks first")
    assertTrue(b[c + 2]:find("phosphor\\lock:", 1, true) ~= nil, "not known: the padlock")
    assertTrue(find(b, "circle") == nil, "no dot or ring is left")
    T.assertGlyphSafe(table.concat(b, "\n"), "the block")
    -- the right side: the recipe's skill breakpoints (round 3 item 4), then its profession, since
    -- Linen's recipes mix professions (no skills read yet: every profession shows)
    local profession = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
        [185] = "Cooking", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting" }
    assertTrue(b[c + 1]:find(" | |cff", 1, true) ~= nil, "the colored parts on the right")
    local pt = NS.Constants.TONE[NS.ItemSearchTip.ProfessionTone(rows[1].skillLine)]
    local named = NS.GroupRoster.Colored(profession[rows[1].skillLine], pt.r, pt.g, pt.b)
    assertTrue(b[c + 1]:find("·|r " .. named, 1, true) ~= nil, "then the profession, in its own tone")
    local IST = NS.ItemSearchTip
    local C = NS.Constants
    local function tinted(mark, tone)
        local g = C.TONE[tone]
        return mark:find((":%d:%d:%d|t"):format(math.floor(g.r * 255 + 0.5), math.floor(g.g * 255 + 0.5),
            math.floor(g.b * 255 + 0.5)), 1, true) ~= nil
    end
    for color, tone in pairs({ orange = "skillOrange", yellow = "skillYellow", green = "skillGreen" }) do
        local mark = IST.CraftMark({ known = true, color = color })
        -- red under: the thin ph:arrow-up (round 3 item 1), or no explicit size (item 2)
        assertTrue(mark:find("phosphor\\arrow-fat-up:14:14:", 1, true) ~= nil and tinted(mark, tone), color .. ": the fat up arrow in its hue")
    end
    local gray = IST.CraftMark({ known = true, color = "gray" })
    assertTrue(gray:find("phosphor\\arrows-horizontal:14:14:", 1, true) ~= nil and tinted(gray, "glyphKnown"),
        "gray: the light gray left-right arrow")
    local locked = IST.CraftMark({ known = false, color = "orange" })
    assertTrue(locked:find("phosphor\\lock:14:14:", 1, true) ~= nil and tinted(locked, "glyphLocked"), "not known: the dark gray lock")
    assertEqual(C.ITEM_SEARCH.GLYPH_SIZE, 14, "one size for every glyph")
    assertTrue(not IST.CraftMark({ known = true, color = "gray" }):find("phosphor\\minus", 1, true), "the dash is gone")
    -- the media library absent: the characters every face has (`=` for no skill-up, was `-`)
    local icon = NS.Icon
    NS.Icon = function() return nil end
    local up, flat, lock = IST.CraftMark({ known = true, color = "orange" }), IST.CraftMark({ known = true, color = "gray" }),
        IST.CraftMark({ known = false })
    NS.Icon = icon
    assertTrue(up:find("^", 1, true) ~= nil and flat:find("=", 1, true) ~= nil and lock:find("x", 1, true) ~= nil,
        "the fallbacks: ^ = x")
    assertEqual(C.TONE.glyphKnown.r, 176 / 255, "#b0b0b0"); assertEqual(C.TONE.glyphLocked.r, 90 / 255, "#5a5a5a")
    assertEqual(IST.CraftGlyph({ known = true }), "flat", "no breakpoints: no skill-up to show")
end, FOREVER_ONLY)

test("item search tip: recipe rows show their skill breakpoints in their hues, memoized per recipe and emptied by a skin switch", function()
    local NS, m, tdp = enabled()
    local IS, IST, C = NS.ItemSearch, NS.ItemSearchTip, NS.Constants
    local row
    for _, r in ipairs(IS.Get(LINEN).crafting) do
        if #IS.SkillParts(r) > 0 then row = r; break end
    end
    assertTrue(row ~= nil, "a Linen recipe with breakpoints")
    -- the window's Skill column and the tooltip read one function (item 3 stays dropped)
    assertEqual(NS.ItemSearchCells.SkillParts, IS.SkillParts)
    local want = {}
    for _, p in ipairs(IS.SkillParts(row)) do
        local t = C.TONE[p.tone]
        want[#want + 1] = NS.GroupRoster.Colored(p.text, t.r, t.g, t.b)
    end
    assertEqual(IST.SkillText(row), table.concat(want, " "), "each part in its skill-up hue")
    assertNil(IST.SkillText({ spell = -1 }), "no breakpoints: nothing")
    -- red under: the parts rebuilt on every hover (the warm path's new strings)
    local real, calls = IS.SkillParts, 0
    IS.SkillParts = function(r) calls = calls + 1; return real(r) end
    IST.SkillText(row)
    assertEqual(calls, 0, "memoized per recipe")
    -- red under: a memo kept across a skin switch (the hues are the skin's palette)
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice("DropWatcher", "ka0s", "obsidian")
    IST.SkillText(row)
    IS.SkillParts = real
    assertEqual(calls, 1, "a skin switch empties the memo")
    -- round 4 (R4-DW-05): the memo is per recipe AND band, so a skill-up redraws the cue
    local banded = {}
    for k, v in pairs(row) do banded[k] = v end
    banded.rank = (banded.yellow or 1)
    local before = IST.SkillText(banded)
    assertTrue(before:find("[" .. banded.yellow .. "]", 1, true) ~= nil, "the band bracketed: " .. before)
    banded.rank = banded.gray
    local after = IST.SkillText(banded)
    assertTrue(after ~= before and after:find("[" .. banded.gray .. "]", 1, true) ~= nil, "a new band, a new string: " .. after)
    -- Show recipe skill levels off: today's right side, the profession, muted
    local tip = tdp.tooltip("GameTooltip")
    tipSettings(NS).craftSkill = false
    tdp.show(tip, LINEN)
    local b = block(tdp, tip)
    local c = find(b, "Crafting")
    local line = tip.__lines[c + 2]
    local first = IS.Ranked(IS.Get(LINEN), NS.ItemSearch.Me(), true).crafting[1].skillLine
    local pt = C.TONE[IST.ProfessionTone(first)]
    -- the profession alone, in its own tone (round 4, R4-DW-04), no breakpoints
    assertEqual(line.right, NS.GroupRoster.Colored(IST.ProfessionName(first), pt.r, pt.g, pt.b))
    assertEqual(NS.ItemSearchTip.Options().craftSkill, false)
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
    assertEqual(b[3], "  Fixture Crate | 100%")
    assertEqual(b[4], "  Fixture Gnoll (10-12) | 25%", "in the band [6, 14]: with the object and the container, by chance")
    assertEqual(b[5], "  Fixture Coffer | 5.0%")
    m.C_Map = { GetBestMapForUnit = function() return IDS.mapA end,
        GetMapInfo = function(id) if id == IDS.mapA then return { mapType = 3 } end end }
    m.__context.level = 80
    tdp.hide(tip)
    tdp.show(tip, IDS.blade)
    b = block(tdp, tip)
    assertEqual(b[3], "  Fixture Gnoll (10-12) | 25%", "a spot in your zone first, whatever its level")
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
    -- red under: other professions' recipes shown, or the count left out. One profession shown: the
    -- skill parts alone on the right, no profession name (round 3 spec §4.2)
    local tailored = {}
    for _, r in ipairs(all) do if r.skillLine == 197 then tailored[r.name] = true end end
    for i = c + 1, c + tailoring do
        local name = b[i]:match("|t (.-) | ")
        assertTrue(tailored[name] == true, b[i])
        assertTrue(b[i]:find("Tailoring", 1, true) == nil, "one profession: no name after the parts: " .. b[i])
    end
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
