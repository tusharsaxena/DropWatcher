-- tests/test_tip_marks.lua — the tooltips' verdict marks and lines (feedback-6 spec §3, DW-F3;
-- modules/TipMarks.lua): a mark is an inline texture escape of a LibKa0s media icon, tinted through
-- the escape's color fields, never a font glyph the tooltip's face draws as a box; a line may be
-- marked non-wrapping, and the tooltip then grows to fit it (modules/Window.lua). Then the gear
-- grid (feedback-7 spec §3: TM.Grid, TM.GearRows, TM.ArrowCell; painted by modules/TipGrid.lua),
-- Upgrade for N's rows on your own drop, and an audit: no tooltip on either tab, in either layout,
-- carries → ▲ ▽ ≈ ⊘ or ⊕ outside a grid's glyph cell (drawn in the monospace face). Then the arrow between two values (TM.Arrow) and the drawn-width count
-- (TM.Chars), and the same audit over every text drawn in the default face (DW-F5): the detail card's
-- chips and rows and the Offer panel take textures (the toast's default-face audit is in test_toast);
-- only monospace text keeps glyphs.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The marks the default face cannot draw (the table cells' and compact lines' monospace glyphs, and
-- the arrow between two values).
local GLYPHS = { "→", "▲", "▽", "≈", "⊘", "⊕" }

local function glyphIn(s)
    for _, g in ipairs(GLYPHS) do
        if tostring(s):find(g, 1, true) then return g end
    end
end

-- The width and height of a TGA file, from its header (little-endian at bytes 13..16).
local function tgaSize(path)
    local f = assert(io.open(path, "rb"))
    local h = f:read(18)
    f:close()
    return h:byte(13) + h:byte(14) * 256, h:byte(15) + h:byte(16) * 256
end

-- ── the escape (pure) ───────────────────────────────────────────────────────────────────────

test("tip marks: the escape is the whole 64x64 canvas at the text's height, tinted as 0..255", function()
    local TM = T.newAddon().TipMarks
    assertEqual(TM.Escape("Interface\\X", 1, 0.5, 0), "|TInterface\\X:0:0:0:0:64:64:0:64:0:64:255:128:0|t")
    assertEqual(TM.Escape("p", 2, -1, 0.3), "|Tp:0:0:0:0:64:64:0:64:0:64:255:0:77|t", "clamped, rounded")
    for _, name in ipairs({ "arrow-up", "arrow-down", "transfer" }) do
        local w, h = tgaSize("libs/LibKa0s/media/icons/" .. name .. ".tga")
        assertEqual(w, TM.TEX_SIZE, name .. "'s width is the escape's texture size")
        assertEqual(h, TM.TEX_SIZE, name .. "'s height too")
    end
end)

test("tip marks: up is arrow-up in green, side is transfer in yellow, down is arrow-down in red", function()
    local NS = T.newAddon()
    local TM = NS.TipMarks
    local expect = { upgrade = { "arrow-up", "77:217:102" }, sidegrade = { "transfer", "255:245:107" },
        downgrade = { "arrow-down", "255:92:82" } }
    for verdict, e in pairs(expect) do
        local path = NS.Icon(e[1])
        assertTrue(path ~= nil, e[1] .. " is in the media catalog")
        assertEqual(TM.Mark(verdict), ("|T%s:0:0:0:0:64:64:0:64:0:64:%s|t"):format(path, e[2]), verdict)
        assertFalse(glyphIn(TM.Mark(verdict)) ~= nil)
    end
    assertEqual(TM.Mark("cantUse"), "", "a worded verdict has no mark")
    assertEqual(TM.Mark(nil), "")
end)

test("tip marks: with the media library absent a mark falls back to a plain character", function()
    local NS = T.newAddon()
    NS.Icon = function() return nil end
    assertEqual(NS.TipMarks.Mark("upgrade"), "+")
    assertEqual(NS.TipMarks.Mark("sidegrade"), "~")
    assertEqual(NS.TipMarks.Mark("downgrade"), "-")
end)

test("tip marks: a non-wrapping line and its text; names in class and quality colors", function()
    local NS, _, m = T.newAddon()
    local TM = NS.TipMarks
    local line = TM.NoWrap("Seta wears 283")
    assertEqual(line.text, "Seta wears 283"); assertEqual(line.wrap, false)
    assertEqual(TM.Text(line), "Seta wears 283"); assertEqual(TM.Text("plain"), "plain")
    assertEqual(TM.ClassName("Seta", "MAGE"), "|cff40c7ebSeta|r")
    assertEqual(TM.ClassName("Seta", nil), "Seta", "no class: plain")
    m.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
    assertEqual(TM.ItemName("Treads", 4), "|cffa336edTreads|r", "the quality's color")
    m.ITEM_QUALITY_COLORS = nil
    assertEqual(TM.ItemName("Treads", 4, "|cffa335ee|Hitem:1::|h[Treads]|h|r"), "|cffa335eeTreads|r",
        "else the link's own color")
    assertEqual(TM.ItemName("Treads", nil, "|cnIQ4:|Hitem:1::|h[Treads]|h|r"), "|cnIQ4:Treads|r", "a named color too")
    assertEqual(TM.ItemName("Treads", nil, nil), "Treads", "else plain")
end)

-- ── the tooltip (modules/Window.lua) ────────────────────────────────────────────────────────

test("tooltip: a non-wrapping line is added with wrap off; every other line still wraps", function()
    local NS, _, m = T.newAddon()
    local added = {}
    rawset(m.GameTooltip, "AddLine", function(_, text, _, _, _, wrap)
        added[#added + 1] = { text = text, wrap = wrap }
    end)
    local w = m.CreateFrame("Frame")
    NS.Window.AttachTooltip(w, function()
        return "Them", NS.TipMarks.NoWrap("Seta wears 283"), "Nobody else in your group."
    end)
    w:__fire("OnEnter")
    assertEqual(#added, 2)
    assertEqual(added[1].text, "Seta wears 283"); assertEqual(added[1].wrap, false, "grows to fit instead")
    assertEqual(added[2].text, "Nobody else in your group."); assertEqual(added[2].wrap, true, "explanations wrap")
end)

-- ── the gear grid (feedback-7 spec §3) ──────────────────────────────────────────────────────

test("grid: the arrow cell is the table's glyph and the unsigned difference, both in the verdict's tone", function()
    local TM = T.newAddon().TipMarks
    local up = TM.ArrowCell("upgrade", 12.4)
    assertEqual(up.glyph, "▲"); assertEqual(up.text, "12"); assertEqual(up.tone, "good")
    local side = TM.ArrowCell("sidegrade", 0)
    assertEqual(side.glyph, "≈"); assertEqual(side.text, "0"); assertEqual(side.tone, "yellow")
    local down = TM.ArrowCell("downgrade", -13)
    assertEqual(down.glyph, "▽"); assertEqual(down.text, "13", "no sign: the glyph says which way"); assertEqual(down.tone, "red")
    assertEqual(TM.ArrowCell("upgrade", nil).text, "", "into an empty slot: the glyph alone")
    assertEqual(TM.ArrowCell("cantUse", 3), "", "a worded verdict has no arrow")
end)

test("grid: a member's rows, the name on the first, the arrow on the item it replaces, empty for a slot worn empty", function()
    local NS, _, m = T.newAddon()
    local TM = NS.TipMarks
    m.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
    local a, b = { link = "|cffa335ee|Hitem:1::|h[High]|h|r", ilvl = 308 }, { name = "Low", quality = 4, ilvl = 291.6 }
    local rows = TM.GearRows("Seta", { a, b }, 0, TM.ArrowCell("upgrade", 5))
    assertEqual(#rows, 2)
    assertEqual(T.tipText(TM.Grid(rows)), "Seta  308  |cffa335eeHigh|r\n292  |cffa336edLow|r  ▲5", "the lower one")
    rows = TM.GearRows("Seta", { a, b }, 0, TM.ArrowCell("upgrade", 5), { link = a.link })
    assertEqual(rows[1][4].glyph, "▲", "the judged item, when named"); assertEqual(rows[2][4], "")
    rows = TM.GearRows("Seta", { a }, 1, TM.ArrowCell("upgrade"))
    assertEqual(rows[2][3].text, "empty"); assertEqual(rows[2][3].tone, "muted"); assertEqual(rows[2][4].glyph, "▲")
    rows = TM.GearRows("Seta", {}, 0, "")
    assertEqual(#rows, 1, "nothing listed: one empty row"); assertEqual(rows[1][3].text, "empty")
    assertTrue(TM.IsGrid(TM.Grid(rows))); assertFalse(TM.IsGrid(TM.NoWrap("x"))); assertFalse(TM.IsGrid("x"))
    assertEqual(TM.Text(TM.Grid(rows)), "Seta  empty", "Text reads a grid as its drawn cells")
end)

test("grid: a column is as wide as its widest cell, a fixed gap between, an empty column takes no room", function()
    local TG = T.newAddon().TipGrid
    local xs, total = TG.Columns({ { 40, 20, 90, 0 }, { 0, 25, 60, 30 } }, 10)
    assertEqual(xs[1], 0); assertEqual(xs[2], 50); assertEqual(xs[3], 85); assertEqual(xs[4], 185)
    assertEqual(total, 215)
    xs, total = TG.Columns({ { 40, 0, 90 } }, 10)
    assertEqual(xs[3], 50, "the empty column's gap is not added"); assertEqual(total, 140)
end)

test("tooltip: a grid reserves a line per row and paints its cells as columns, the glyph in the monospace face", function()
    local NS, _, m = T.newAddon()
    local cw = NS.TipGrid.CHAR_W   -- the harness's font strings are not measured: the estimate
    local TM = NS.TipMarks
    local w = m.CreateFrame("Frame")
    NS.Window.AttachTooltip(w, function()
        return "For Seta: Upgrade", TM.Grid(TM.GearRows("Seta", { { name = "High", ilvl = 308 }, { name = "Lowest", ilvl = 291 } }, 0,
            TM.ArrowCell("upgrade", 13))), "Inspected 40s ago."
    end)
    w:__fire("OnEnter")
    local tip = m.GameTooltip
    assertEqual(#tip.__lines, 4, "the title, two reserved rows, the age")
    assertEqual(tip.__lines[2].text, " "); assertEqual(tip.__lines[2].wrap, false)
    assertEqual(tip.__lines[4].text, "Inspected 40s ago.")
    local drawn = NS.TipGrid.Painted()
    local by = {}
    for _, d in ipairs(drawn) do by[d.text] = d end
    assertEqual(by.Seta.line, 2); assertEqual(by.Seta.x, 0)
    assertEqual(by["308"].x, 4 * cw + NS.TipGrid.GAP, "after the widest name")
    assertEqual(by.Lowest.line, 3); assertEqual(by.High.x, by.Lowest.x, "one column")
    assertEqual(by["▲"].line, 3, "the arrow on the lower row"); assertTrue(by["▲"].mono, "the glyph in the monospace face")
    assertFalse(by["13"].mono); assertEqual(by["13"].x, by["▲"].x + cw + NS.TipGrid.GLYPH_GAP)
    assertEqual(tip.__minWidth, by["13"].x + 2 * cw, "the tooltip is at least as wide as the grid")
    tip:Hide()
    w:__fire("OnLeave")
    NS.TipGrid.Begin()
    assertEqual(#NS.TipGrid.Painted(), 0); assertEqual(tip.__minWidth, 0, "the width goes back for the next tooltip")
end)

test("compat: a tooltip's line by number is its TextLeft global; nil for an unnamed tooltip or a missing line", function()
    local NS, env = T.newAddon()
    local line = {}
    env.MyTipTextLeft3 = line
    local named = { GetName = function() return "MyTip" end }
    assertEqual(NS.Compat.TooltipLeftLine(named, 3), line)
    assertTrue(NS.Compat.TooltipLeftLine(named, 4) == nil, "a line it does not have")
    assertTrue(NS.Compat.TooltipLeftLine({ GetName = function() return nil end }, 3) == nil, "unnamed")
    assertTrue(NS.Compat.TooltipLeftLine(nil, 3) == nil)
    env.MyTipTextLeft3 = nil
end)

-- ── (Details) on your own drop (modules/MineCells.lua) ──────────────────────────────────────

local function cand(name, classFile, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = "ready", eval = eval }
end

local function own(candidates)
    return { id = 1, at = 100, isMine = true, link = "|cffa335ee|Hitem:212::|h[Crown]|h|r",
        looter = { name = "Me-Realm", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 287, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", basis = "inspect" }, candidates = candidates }
end

test("details: one grid row per upgrade, ranked by gain, every part colored, the gain unsigned", function()
    local NS, _, m = T.newAddon()
    m.ITEM_QUALITY_COLORS = { [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }
    local c = NS.MineCells.Details(own({
        a = cand("Seta", "PRIEST", { verdict = "upgrade", ilvlDelta = 4.4, baseline = { ilvl = 283, name = "Loop", quality = 3 } }),
        b = cand("Butterz", "MAGE", { verdict = "upgrade", ilvlDelta = 11, baseline = { ilvl = 276, name = "Band", quality = 4 } }),
        c = cand("Kael", "ROGUE", { verdict = "downgrade", ilvlDelta = -2, baseline = { ilvl = 289 } }),
    }))
    assertEqual(#c.tip, 2, "the title and the grid; a downgrade is not listed")
    local g = c.tip[2].grid
    assertEqual(#g, 2, "a row per upgrade")
    assertEqual(g[1][1], "|cff40c7ebButterz|r"); assertEqual(g[1][2], "276"); assertEqual(g[1][3], "|cffa336edBand|r")
    assertEqual(g[1][4].glyph, "▲"); assertEqual(g[1][4].text, "11"); assertEqual(g[1][4].tone, "good")
    assertEqual(T.tipText({ grid = { g[2] } }), "|cffffffffSeta|r  283  |cff0070deLoop|r  ▲4", "rounded, no sign")
    local bare = NS.MineCells.Details(own({ a = cand("Seta", "PRIEST", { verdict = "upgrade", ilvlDelta = 9 }) }))
    assertEqual(T.tipText(bare.tip[2]), "|cffffffffSeta|r  empty  ▲9", "nothing worn there: empty")
    local none = NS.MineCells.Details(own({ a = cand("Kael", "ROGUE", { verdict = "downgrade", ilvlDelta = -2 }) }))
    assertEqual(type(none.tip[2]), "string", "an explanation still wraps")
    assertEqual(type(NS.MineCells.Details(own({})).tip[2]), "string", "solo: it wraps")
end)

test("details: of two worn rings the line names the lower, the one the drop would replace", function()
    local NS = T.newAddon()
    local C = NS.Constants
    local IC, A = C.ITEM_CLASS, C.ARMOR_SUBCLASS
    local function ring(ilvl, name) return { itemID = ilvl, ilvl = ilvl, name = name, equipLoc = "INVTYPE_FINGER",
        classID = IC.ARMOR, subClassID = A.GENERIC } end
    local who = { classFile = "MAGE", specID = 64, gear = { [C.SLOT.FINGER1] = ring(290, "Higher Band"),
        [C.SLOT.FINGER2] = ring(276, "Lower Loop") } }
    local eval = NS.Evaluate.Evaluate(ring(287), who)
    assertEqual(eval.verdict, "upgrade")
    local c = NS.MineCells.Details(own({ a = cand("Butterz", "MAGE", eval) }))
    local text = T.tipText(c.tip[2])
    assertTrue(text:find("  276  Lower Loop  ", 1, true) ~= nil, text)
    assertFalse(text:find("Higher Band", 1, true) ~= nil, "the higher one is kept")
end)

-- ── the audit: no glyph in any tooltip ──────────────────────────────────────────────────────

test("audit: no column tooltip on Drops or History carries a verdict glyph; their marks are textures", function()
    local NS = T.newAddon()
    for _, cols in ipairs({ NS.WindowGroup.COLUMNS, NS.WindowHistory.COLUMNS }) do
        for _, col in ipairs(cols) do
            assertTrue(glyphIn(col.tip) == nil, col.key .. ": " .. (glyphIn(col.tip) or ""))
        end
    end
    local me = NS.WindowGroup.COLUMNS[6]
    assertEqual(me.key, "me")
    assertTrue(me.tip:find(NS.TipMarks.Mark("upgrade") .. " upgrade (green)", 1, true) ~= nil, me.tip)
    assertTrue(me.tip:find(NS.TipMarks.Mark("sidegrade") .. " sidegrade (yellow)", 1, true) ~= nil)
    assertTrue(me.tip:find(NS.TipMarks.Mark("downgrade") .. " downgrade (red)", 1, true) ~= nil)
end)

test("audit: no localized string in the addon's source puts a verdict glyph in a tooltip", function()
    local files = {}
    for path in io.popen('ls modules/*.lua core/*.lua locales/*.lua settings/*.lua 2>/dev/null'):lines() do
        files[#files + 1] = path
    end
    assertTrue(#files > 20, "the sources were listed")
    for _, path in ipairs(files) do
        local f = assert(io.open(path, "rb"))
        local src = f:read("*a")
        f:close()
        for key in src:gmatch('L%["(.-)"%]') do
            assertTrue(glyphIn(key) == nil, path .. ": " .. key)
        end
    end
end)

-- Every tooltip the window attaches, read as a hover would read it.
local function attached(NS)
    local widgets = {}
    local attach = NS.Window.AttachTooltip
    NS.Window.AttachTooltip = function(w, fn, place)
        widgets[#widgets + 1] = w
        return attach(w, fn, place)
    end
    return widgets
end

-- A line's text in the tooltip's face: a grid's glyph cells are drawn in the monospace face
-- (modules/TipGrid.lua), so only their numbers count, and the glyph must be the table's own.
local function faceText(NS, line)
    if not NS.TipMarks.IsGrid(line) then return NS.TipMarks.Text(line) end
    local parts = {}
    for _, row in ipairs(line.grid) do
        for _, cell in ipairs(row) do
            if type(cell) == "table" then
                if cell.glyph then
                    local ok = false
                    for _, g in pairs(NS.WindowCells.GLYPH) do ok = ok or g == cell.glyph end
                    assertTrue(ok, "a grid's glyph is the table's: " .. cell.glyph)
                end
                parts[#parts + 1] = tostring(cell.text or "")
            else
                parts[#parts + 1] = tostring(cell)
            end
        end
    end
    return table.concat(parts, " ")
end

local function auditTips(NS, widgets, where)
    local n = 0
    for _, w in ipairs(widgets) do
        for _, line in ipairs(NS.Window.TooltipOf(w)) do
            local text = faceText(NS, line)
            assertTrue(glyphIn(text) == nil, where .. ": " .. text)
            n = n + 1
        end
    end
    return n
end

test("audit: every tooltip of test mode's drops, both layouts, the detail card and History is glyph-free", function()
    local NS, _, m = T.enableAddon()
    local widgets = attached(NS)
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.ShowWindow()
    NS.Window.Refresh()
    local drops = NS.LootFeed.Drops("test")
    assertTrue(#drops > 0, "test mode filled the feed")
    NS.WindowGroup.ToggleExpand(drops[1].id)
    for _, d in ipairs(drops) do
        if d.isMine then NS.WindowOwn.Reveal(d.id) end
    end
    NS.Window.Refresh()
    local lines = auditTips(NS, widgets, "full")
    NS.SetWindowMode("compact")
    NS.Window.Refresh()
    lines = lines + auditTips(NS, widgets, "compact")
    NS.Window.SelectTab("history")
    NS.Window.Refresh()
    NS.SetWindowMode("full")
    NS.Window.Refresh()
    lines = lines + auditTips(NS, widgets, "history")
    assertTrue(lines > 100, "the tooltips were read: " .. lines)
end)

-- ── the arrow and the drawn width (DW-F5) ───────────────────────────────────────────────────

test("tip marks: the arrow between two values is arrow-right in the muted tone, -> without the library", function()
    local NS = T.newAddon()
    local TM = NS.TipMarks
    local path = NS.Icon("arrow-right")
    assertTrue(path ~= nil, "arrow-right is in the media catalog")
    assertEqual(TM.Arrow(), ("|T%s:0:0:0:0:64:64:0:64:0:64:179:179:184|t"):format(path))
    local w, h = tgaSize("libs/LibKa0s/media/icons/arrow-right.tga")
    assertEqual(w, TM.TEX_SIZE); assertEqual(h, TM.TEX_SIZE)
    NS.Icon = function() return nil end
    assertEqual(TM.Arrow(), "->")
end)

test("tip marks: Chars counts what a text draws: an escape two, a color code none, a UTF-8 character one", function()
    local TM = T.newAddon().TipMarks
    assertEqual(TM.Chars("UPGRADE"), 7)
    assertEqual(TM.Chars(TM.Mark("upgrade") .. " UPGRADE"), 10)
    assertEqual(TM.Chars("292 " .. TM.Arrow() .. " 311"), 10)
    assertEqual(TM.Chars("|cffa335eeTreads|r"), 6); assertEqual(TM.Chars("|cnIQ4:Treads|r"), 6)
    assertEqual(TM.Chars("… –"), 3)
    assertEqual(TM.Chars(nil), 0)
end)

-- Every frame the window and the Offer panel build from here on (the mock's CreateFrame).
local function collected(m)
    local frames = {}
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        frames[#frames + 1] = f
        return f
    end
    return frames
end

-- Every text drawn on `frames` (each frame's own and its font strings'), split by face: a glyph in
-- the default face is a box in game; the monospace face (C.FONT_MONO) draws them.
local function auditFaces(NS, frames, where)
    local plain, mono = 0, 0
    for _, f in ipairs(frames) do
        for _, r in ipairs(f.__regions or {}) do
            local text = r.__objType == "FontString" and r.__text
            if type(text) == "string" and text ~= "" then
                if r.__font and r.__font[1] == NS.Constants.FONT_MONO then
                    mono = mono + 1
                else
                    assertTrue(glyphIn(text) == nil, where .. ": " .. text)
                    plain = plain + 1
                end
            end
        end
        if type(f.__text) == "string" then assertTrue(glyphIn(f.__text) == nil, where .. ": " .. f.__text) end
    end
    return plain, mono
end

test("audit: no text in the default face carries a glyph: Drops, the detail card, the Offer panel, History", function()
    local NS, _, m = T.enableAddon()
    local frames = collected(m)
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.ShowWindow()
    NS.Window.Refresh()
    local drops = NS.LootFeed.Drops("test")
    local ownId
    for _, d in ipairs(drops) do
        NS.WindowGroup.ToggleExpand(d.id)
        if d.isMine then NS.WindowOwn.Reveal(d.id); ownId = ownId or d.id end
    end
    assertTrue(ownId ~= nil, "test mode has a drop of your own")
    NS.OfferPanel.Open(ownId)
    assertTrue(NS.OfferPanel.IsShown())
    NS.Window.Refresh()
    local plain, mono = auditFaces(NS, frames, "full")
    NS.SetWindowMode("compact")
    NS.Window.Refresh()
    auditFaces(NS, frames, "compact")
    NS.Window.SelectTab("history")
    NS.Window.Refresh()
    auditFaces(NS, frames, "history")
    assertTrue(plain > 100, "the default face's texts were read: " .. plain)
    assertTrue(mono > 0, "the table cells' glyphs are in the monospace face: " .. mono)
    local found
    for _, f in ipairs(frames) do
        for _, r in ipairs(f.__regions or {}) do
            if type(r.__text) == "string" and r.__text:find(NS.TipMarks.Arrow(), 1, true) then found = true end
        end
    end
    assertTrue(found, "the detail card's and the Offer panel's arrows are textures")
end)
