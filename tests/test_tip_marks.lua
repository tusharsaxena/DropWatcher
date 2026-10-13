-- tests/test_tip_marks.lua — the tooltips' verdict marks and lines (feedback-6 spec §3, DW-F3;
-- modules/TipMarks.lua): a mark is an inline texture escape of a LibKa0s media icon, tinted through
-- the escape's color fields, never a font glyph the tooltip's face draws as a box; a line may be
-- marked non-wrapping, and the tooltip then grows to fit it (modules/Window.lua). Then (Details)'
-- lines on your own drop, and an audit: no tooltip on either tab, in either layout, carries
-- ▲ ▽ ≈ ⊘ or ⊕.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The marks a tooltip's face cannot draw (the table cells' and compact lines' monospace glyphs).
local GLYPHS = { "▲", "▽", "≈", "⊘", "⊕" }

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

test("details: one non-wrapping line per upgrade, ranked by gain, every part colored, the gain unsigned", function()
    local NS, _, m = T.newAddon()
    m.ITEM_QUALITY_COLORS = { [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }
    local up = NS.TipMarks.Mark("upgrade")
    local c = NS.MineCells.Multiple(own({
        a = cand("Seta", "PRIEST", { verdict = "upgrade", ilvlDelta = 4.4, baseline = { ilvl = 283, name = "Loop", quality = 3 } }),
        b = cand("Butterz", "MAGE", { verdict = "upgrade", ilvlDelta = 11, baseline = { ilvl = 276, name = "Band", quality = 4 } }),
        c = cand("Kael", "ROGUE", { verdict = "downgrade", ilvlDelta = -2, baseline = { ilvl = 289 } }),
    }))
    assertEqual(#c.tip, 3, "the title and the two upgrades; a downgrade is not listed")
    assertEqual(c.tip[2].text, "|cff40c7ebButterz|r wears 276 |cffa336edBand|r " .. up .. "11")
    assertEqual(c.tip[3].text, "|cffffffffSeta|r wears 283 |cff0070deLoop|r " .. up .. "4", "rounded, no sign")
    assertEqual(c.tip[2].wrap, false); assertEqual(c.tip[3].wrap, false)
    local none = NS.MineCells.Multiple(own({ a = cand("Kael", "ROGUE", { verdict = "downgrade", ilvlDelta = -2 }) }))
    assertEqual(type(none.tip[2]), "string", "an explanation still wraps")
    assertEqual(type(NS.MineCells.Multiple(own({})).tip[2]), "string", "solo: it wraps")
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
    local c = NS.MineCells.Multiple(own({ a = cand("Butterz", "MAGE", eval) }))
    local text = c.tip[2].text
    assertTrue(text:find("wears 276 Lower Loop ", 1, true) ~= nil, text)
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

local function auditTips(NS, widgets, where)
    local n = 0
    for _, w in ipairs(widgets) do
        for _, line in ipairs(NS.Window.TooltipOf(w)) do
            local text = NS.TipMarks.Text(line)
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
