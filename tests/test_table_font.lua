-- tests/test_table_font.lua — the drop tables' font as the whole font setting (DW-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, the lead's ruling on D-07): Window ›
-- Layout › Tables carries the library's composed font block (H.FontGroup with fromSkin and
-- flagsFromSkin) in place of the lone Font size slider. Face (with Use the skin's font), size (0 is
-- still Default), color with its class-color companion, flags with From skin, and shadow, each
-- stored and each drawn by the tables on both tabs and in both layouts. The defaults keep today's
-- look: the skin's face, the template's size, the skin's plain text color, the skin's shadow, and
-- flags From skin, which resolve through the Skin tab's Font outline as window text.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local OLD1 = "|cffa335ee|Hitem:300::|h[Old Band]|h|r"

local FONT_PATHS = {
    "window.tableFont", "window.fontSize", "window.tableFontColor", "window.tableFontClassColor",
    "window.tableFontFlags", "window.tableFontShadow", "window.tableFontFromSkin",
}

local function drop()
    return {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4, track = { name = "Hero", rank = 2, max = 6 } },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {}, baseline = { link = OLD1, ilvl = 292 } },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
end

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } }

local function seed(NS)
    local d = drop()
    NS.LootFeed.Groups = function() return { GROUP } end
    NS.LootFeed.Get = function(id) return id == d.id and d or nil end
    NS.LootFeed.Drops = function() return { d } end
end

--- The Drops table shown headless, its first row. Answers NS, the row, the mock.
local function shown(opts)
    local NS, _, m = T.enableAddon(opts)
    m.__now = 100
    seed(NS)
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn().rows[1], m
end

local function redraw(NS) return NS.WindowGroup.Drawn().rows[1] end

local function quietly(m, fn)
    local cf = m.DEFAULT_CHAT_FRAME
    local add = cf.AddMessage
    cf.AddMessage = function() end
    local ok, err = pcall(fn)
    cf.AddMessage = add
    if not ok then error(err, 0) end
end

local function near(a, b) return math.abs((a or -1) - (b or -2)) < 0.002 end

local function sameColor(fs, r, g, b, what)
    local fr, fg, fb = fs:GetTextColor()
    assertTrue(near(fr, r) and near(fg, g) and near(fb, b),
        ("%s: %s,%s,%s, wanted %s,%s,%s"):format(what, tostring(fr), tostring(fg), tostring(fb), r, g, b))
end

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

test("table font: Window › Layout › Tables carries the whole font setting, after Row height", function()
    -- red under: the lone Font size slider (D-07: every font setting carries size, color with a
    -- class-color option, flags with From skin, and shadow).
    local NS = T.newAddon()
    local S = NS.SchemaRuntime
    for _, path in ipairs(FONT_PATHS) do
        local row = S.FindRow(path)
        assertTrue(row ~= nil, path .. " has a row")
        assertEqual(row.page, "window", path .. ": page")
        assertEqual(row.group, "Layout", path .. ": tab")
        assertEqual(row.subgroup, "Tables", path .. ": subsection")
        assertTrue(type(row.validate) == "function", path .. " is checked before it is stored")
        assertTrue(row.validate(row.default), path .. " default passes its check")
        assertTrue(type(row.onChange) == "function", path .. " repaints the window")
    end
    local order = {}
    for i, row in ipairs(NS.addon.Settings.Schema) do order[row.path or ""] = i end
    assertTrue(order["window.rowHeight"] < order["window.tableFont"], "Row height leads the subsection")
    local flags = S.FindRow("window.tableFontFlags")
    assertEqual(flags.default, "@skin", "From skin is the flags' default")
    assertTrue(flags.values["@skin"] ~= nil, "and the row offers it")
    assertTrue(flags.validate("THICKOUTLINE") and flags.validate(""), "a picked flag is stored")
    assertFalse(flags.validate("BOLD"), "a flag the client does not take is refused")
    local color = S.FindRow("window.tableFontColor")
    assertEqual(color.type, "color")
    assertEqual(S.FindRow("window.tableFontClassColor").classColorSource, "player",
        "the tables are the player's own view of the loot")
end)

test("table font: Font size keeps its stored path, its range and `0 (Default)`", function()
    local NS = T.bootAddon()
    local row = NS.SchemaRuntime.FindRow("window.fontSize")
    assertEqual(row.type, "number"); assertEqual(row.default, 0)
    assertEqual(row.min, 0); assertEqual(row.max, NS.Constants.WINDOW.FONT_MAX)
    assertTrue(row.validate(0) and row.validate(20)); assertFalse(row.validate(21))
    local fmt = function(_, v) return tostring(v) end
    assertEqual(NS.addon.Settings.FormatValue(row, 0, fmt), "0 (Default)")
end)

test("table font: the defaults keep today's look; only the flags are From skin", function()
    local NS = T.newAddon()
    local W = NS.C.PROFILE.window
    assertEqual(W.fontSize, 0, "the template's own size")
    assertEqual(W.tableFontFromSkin, true, "the skin's face")
    assertEqual(W.tableFontFlags, "@skin")
    assertEqual(W.tableFontShadow, true, "the skin's text shadow")
    assertEqual(W.tableFontClassColor, false)
    local plain = NS.SKIN_TOKENS["dw.plain"].default
    local c = W.tableFontColor
    assertTrue(near(c.r, plain[1]) and near(c.g, plain[2]) and near(c.b, plain[3]) and c.a == 1,
        "the swatch starts on Ka0s Default's plain text color")
    for _, path in ipairs(FONT_PATHS) do
        local row = NS.SchemaRuntime.FindRow(path)
        local leaf = path:match("[^.]+$")
        assertTrue(row.default == W[leaf], path .. " default is defaults/Profile.lua's")
    end
end)

-- ── drawn ───────────────────────────────────────────────────────────────────────────────────

test("table font: From skin flags draw the window text's outline, and a picked flag wins", function()
    local NS, row, m = shown()
    local S = NS.SchemaRuntime
    local _, _, flags = row.cells.ilvl.text:GetFont()
    assertEqual(flags, "OUTLINE", "All text: the window's outline")
    quietly(m, function() S.Set("skin.outline", "hud") end)
    _, _, flags = redraw(NS).cells.ilvl.text:GetFont()
    assertEqual(flags, "", "HUD text only: the tables are window text")
    S.Set("window.tableFontFlags", "THICKOUTLINE")
    _, _, flags = redraw(NS).cells.ilvl.text:GetFont()
    assertEqual(flags, "THICKOUTLINE", "a picked flag wins over the Font outline")
    _, _, flags = redraw(NS).cells.looter.text:GetFont()
    assertEqual(flags, "THICKOUTLINE", "on every text of the row")
end)

test("table font: a face of the player's own replaces the skin's, and the glyphs keep theirs", function()
    local NS, row, m = shown()
    local S = NS.SchemaRuntime
    local LSM = m.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    LSM.Fetch = function(_, kind, name) return kind == "font" and name == "Ka0s Fira Sans Medium" and "fonts\\fira.ttf" or nil end
    local skinFace = row.cells.ilvl.text:GetFont()
    local glyphFace = row.cells.me.glyph:GetFont()
    S.Set("window.tableFont", "Ka0s Fira Sans Medium")
    assertEqual(redraw(NS).cells.ilvl.text:GetFont(), skinFace, "not read while Use the skin's font is on")
    S.Set("window.tableFontFromSkin", false)
    row = redraw(NS)
    assertEqual(row.cells.ilvl.text:GetFont(), "fonts\\fira.ttf", "the picked face")
    assertEqual(row.cells.looter.text:GetFont(), "fonts\\fira.ttf", "on every text of the row")
    assertEqual(row.cells.me.glyph:GetFont(), glyphFace, "the verdict glyph keeps its monospace face")
    S.Set("window.tableFontFromSkin", true)
    assertEqual(redraw(NS).cells.ilvl.text:GetFont(), skinFace, "the skin's face again")
end)

test("table font: the color is plain text's; a verdict, a class and a quality keep their own", function()
    local NS, row, m = shown()
    local S, C = NS.SchemaRuntime, NS.Constants
    local P = C.TONE.plain
    sameColor(row.cells.ilvl.text, P.r, P.g, P.b, "the default draws the skin's plain text color")
    local good = C.TONE.good
    local looterR, looterG, looterB = row.cells.looter.text:GetTextColor()
    S.Set("window.tableFontColor", { r = 1, g = 0.5, b = 0, a = 1 })
    row = redraw(NS)
    sameColor(row.cells.ilvl.text, 1, 0.5, 0, "a picked color draws plain text")
    sameColor(row.cells.slot.text, 1, 0.5, 0, "every plain cell")
    sameColor(row.cells.me.text, good.r, good.g, good.b, "an upgrade stays green")
    sameColor(row.cells.looter.text, looterR, looterG, looterB, "the looter keeps their class color")
    S.Set("window.tableFontClassColor", true)
    local cr, cg, cb = NS.ResolveColor({ r = 1, g = 0.5, b = 0, a = 1 }, true, nil)
    sameColor(redraw(NS).cells.ilvl.text, cr, cg, cb, "Use class color: the player's class color")
    assertFalse(near(cr, 1) and near(cg, 0.5) and near(cb, 0), "the mock's class color is not the swatch")
    S.Set("window.tableFontClassColor", false)
    S.Set("window.tableFontColor", NS.C.PROFILE.window.tableFontColor)
    sameColor(redraw(NS).cells.ilvl.text, P.r, P.g, P.b, "the default follows the skin again")
    local _ = m
end)

--- Give one headless font string the shadow and font-object calls the client has (tests/wow_mock.lua's
--- regions answer them as no-ops), so a case can read what the tables set on it.
local function modelText(fs)
    fs.SetShadowOffset = function(self, x, y) self.__shadowOffset = { x, y } end
    fs.GetShadowOffset = function(self) local o = self.__shadowOffset or { 0, 0 }; return o[1], o[2] end
    fs.SetShadowColor = function(self, r, g, b, a) self.__shadowColor = { r, g, b, a } end
    fs.GetShadowColor = function(self) local c = self.__shadowColor or { 0, 0, 0, 1 }; return c[1], c[2], c[3], c[4] end
    fs.SetFontObject = function(self, obj) self.__fontObject = obj; self.__font = { obj:GetFont() } end
    fs.GetFontObject = function(self) return self.__fontObject end
    return fs
end

test("table font: the shadow is drawn and taken off (no CreateFont: on the string)", function()
    local NS, row = shown()
    local S = NS.SchemaRuntime
    local fs = modelText(row.cells.ilvl.text)
    S.Set("window.tableFontShadow", false)
    redraw(NS)
    local x, y = fs:GetShadowOffset()
    assertEqual(x, 0); assertEqual(y, 0)
    local _, _, _, a = fs:GetShadowColor()
    assertEqual(a, 0, "and its color is clear")
    S.Set("window.tableFontShadow", true)
    redraw(NS)
    x, y = fs:GetShadowOffset()
    assertEqual(x, 1); assertEqual(y, -1)
    _, _, _, a = fs:GetShadowColor()
    assertEqual(a, 1)
end)

test("table font edge: with CreateFont, each look is a named font object that carries the shadow", function()
    -- A 12.0.7 client draws a font object's shadow, not a runtime SetShadow* on a FontString
    -- (libs/LibKa0s/SkinPaint.lua), so the client path hands the text a font object; the text keeps
    -- the color it was painted in.
    local made = {}
    local NS, row, m = shown()
    m.CreateFont = function(name)
        local obj = { name = name }
        function obj:SetFont(p, s, f) self.font = { p, s, f or "" } end
        function obj:GetFont() return self.font[1], self.font[2], self.font[3] end
        function obj:SetShadowOffset(x, y) self.offset = { x, y } end
        function obj:SetShadowColor(r, g, b, a) self.shadow = { r, g, b, a } end
        made[#made + 1] = obj
        return obj
    end
    local S = NS.SchemaRuntime
    local fs = modelText(row.cells.ilvl.text)
    S.Set("window.tableFontShadow", false)
    redraw(NS)
    local obj = fs:GetFontObject()
    assertTrue(type(obj) == "table" and type(obj.name) == "string", "a named font object")
    assertTrue(obj.name:find("^DropWatcher_TableFont") ~= nil, "named for the addon: " .. tostring(obj.name))
    assertEqual(obj.offset[1], 0); assertEqual(obj.offset[2], 0)
    local _, _, flags = fs:GetFont()
    assertEqual(flags, "OUTLINE", "the object carries the resolved flags")
    local P = NS.Constants.TONE.plain
    sameColor(fs, P.r, P.g, P.b, "the painted color survives the font object")
    S.Set("window.tableFontShadow", true)
    obj = fs:GetFontObject()
    assertEqual(obj.offset[1], 1); assertEqual(obj.offset[2], -1)
    local n = #made
    S.Set("window.tableFontShadow", false)
    S.Set("window.tableFontShadow", true)
    assertEqual(#made, n, "one object per look, made once and reused")
end)

test("table font: History and the compact cards draw the same setting", function()
    local NS, _, m = shown()
    local S = NS.SchemaRuntime
    S.Set("window.tableFontFlags", "MONOCHROME")
    S.Set("window.tableFontColor", { r = 0.2, g = 0.4, b = 0.6, a = 1 })
    NS.SetWindowMode("compact")
    local card = NS.WindowGroup.Drawn().rows[1]
    assertTrue(card ~= nil, "a compact card")
    local _, _, flags = card.cells.slot.text:GetFont()
    assertEqual(flags, "MONOCHROME", "the compact card's text")
    sameColor(card.cells.slot.text, 0.2, 0.4, 0.6, "and its plain text's color")
    local _ = m
end)
