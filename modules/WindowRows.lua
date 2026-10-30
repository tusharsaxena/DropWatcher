local addonName, NS = ...
-- modules/WindowRows.lua — the drop tables' row metrics and font, shared by both tabs and both
-- layouts (feedback-2 spec §8, FB2-9): Drops and History read their rows' height and font from the
-- Window page's Layout rows, `window.rowHeight` and the Tables font block (`window.fontSize` and the
-- `window.tableFont*` rows, DW-01's whole font setting: the lead's ruling on D-07).
--
-- LIKE KA0S LOOT HISTORY. Its table draws `GameFontHighlightSmall` at the template's own size in
-- 18-pixel rows (../LootHistory/modules/BrowserTable.lua, ROW_H_DEFAULT). So `window.fontSize`'s
-- default is 0, "Default": the cells keep their template's own size, and a size from FONT_MIN to
-- FONT_MAX replaces it (a stored 1 to 7 reads as FONT_MIN). The row height defaults to 18; the item
-- button is ROW_ICON at most and 2 pixels under a shorter row's height. A Drops row while its Trade
-- window column shows (feedback-5 spec §1) is COUNTDOWN_EXTRA taller than the
-- row height (its countdown bar sits under the text), and tall enough for its two lines of text at
-- the chosen size.
--
-- PURE: FontSize, RowHeight, IconSize, CountdownRowHeight. The frame edge: Metrics reads the rows
-- through the schema seam (NS.Setting) once per repaint, the font block through ReadFont; SetFontSize
-- sets a font string's size, keeping its face and flags, and puts the template's own size back for
-- Default; ApplyRowFont gives a row's texts the whole font (SetTableFont) and its glyphs the size.
--
-- THE FONT BLOCK (DW-01, D-07). The face is the skin's while Use the skin's font is on (the face the
-- skin painted, read off the string), else the picked LibSharedMedia face. The flags are From skin by
-- default, resolved as window text (S.FontFlags(v, "window"): the Skin tab's Font outline), a picked
-- flag as stored. The shadow is the block's: a 12.0.7 client draws a font object's shadow and not a
-- runtime SetShadow* on a string (libs/LibKa0s/SkinPaint.lua), so with CreateFont each look is one
-- named font object, made once; without it (the harness) the string takes the face and the shadow
-- itself. The color is plain text's (SetTone): a text the tables drew in the `plain` tone takes the
-- block's color, the player's class color while Use class color is on, and the skin's plain color
-- while the swatch is at its default, so a fresh profile looks as it did before the block. A verdict,
-- an item's quality and a looter's class keep their own colors. The glyphs (the monospace face) keep
-- their face and flags and take the size, as before; a glyph drawn in the `plain` tone takes the
-- block's color too, as a text does.
-- NewMark and PlaceMark draw a gold mark after a cell's text that is never cut (feedback-7 spec §2:
-- ` [YOU]` after your own name on every looter text): the text is cut first.

NS.WindowRows = NS.WindowRows or {}
local WR = NS.WindowRows
local C  = NS.Constants
local K  = C.WINDOW

local min, max, floor = math.min, math.max, math.floor

-- The default row height, read from defaults/Profile.lua (savedvariables-§2: the one place a
-- default value is written), which loads before this file.
WR.ROW_H = NS.C.PROFILE.window.rowHeight

--- The text size a stored `window.fontSize` asks for: nil for Default (0, nil or not a number),
--- the template's own size; else a whole size from FONT_MIN to FONT_MAX.
--- @param v any
--- @return number|nil
function WR.FontSize(v)
    if type(v) ~= "number" or v ~= v or v <= 0 then return nil end
    return min(K.FONT_MAX, max(K.FONT_MIN, floor(v + 0.5)))
end

--- The row height a stored `window.rowHeight` asks for: a whole height from ROW_H_MIN to
--- ROW_H_MAX, the default (WR.ROW_H) for anything not a number.
--- @param v any
--- @return number
function WR.RowHeight(v)
    if type(v) ~= "number" or v ~= v then return WR.ROW_H end
    return min(K.ROW_H_MAX, max(K.ROW_H_MIN, floor(v + 0.5)))
end

--- A row's item button: ROW_ICON at most, 2 pixels under the row's height.
--- @param height number
--- @return number
function WR.IconSize(height)
    return min(K.ROW_ICON, height - 2)
end

--- A Drops row's height while its Trade window column shows: the row height plus the room its
--- countdown bar needs, and never less
--- than its two lines of text at `fontSize` (nil = Default, the template's COUNTDOWN_FONT) need.
--- @param height number
--- @param fontSize number|nil
--- @return number
function WR.CountdownRowHeight(height, fontSize)
    return max(height + K.COUNTDOWN_EXTRA, 2 * (fontSize or K.COUNTDOWN_FONT) + K.COUNTDOWN_PAD)
end

-- ── the font block (DW-01, D-07) ────────────────────────────────────────────────────────────

-- The swatch's default (defaults/Profile.lua): while the stored color is this one, plain text draws
-- the skin's own plain color (C.TONE.plain), so the block changes nothing on a fresh profile.
local COLOR_DEFAULT = NS.C.PROFILE.window.tableFontColor

local function sameColor(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for _, k in ipairs({ "r", "g", "b" }) do
        if math.abs((tonumber(a[k]) or -1) - b[k]) > 0.002 then return false end
    end
    return math.abs((tonumber(a.a) or 1) - (b.a or 1)) <= 0.002
end

--- The block's plain text color for one repaint: { r, g, b, a } picked or class-colored, or nil to
--- draw the skin's plain color (the swatch at its default).
local function plainColor()
    local stored, class = NS.Setting("window.tableFontColor"), NS.Setting("window.tableFontClassColor") == true
    if not class and (type(stored) ~= "table" or sameColor(stored, COLOR_DEFAULT)) then return nil end
    local r, g, b, a = NS.ResolveColor(stored, class, nil)
    if r == nil then return nil end
    return { r, g, b, a or 1 }
end

--- A LibSharedMedia face's path, or nil (none named, no LSM, or not registered).
local function facePath(name)
    if type(name) ~= "string" or name == "" then return nil end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    return LSM and LSM.Fetch and LSM:Fetch("font", name, true) or nil
end

-- The last ReadFont: what SetTone reads between two repaints.
local current

--- The Tables font block, read once per repaint: { face (a path, nil = the skin's painted face),
--- flags, shadow, plain ({ r, g, b, a } or nil = the skin's), key (one string per look) }.
--- @return table
function WR.ReadFont()
    local face
    if NS.Setting("window.tableFontFromSkin") == false then face = facePath(NS.Setting("window.tableFont")) end
    local S = NS.Skin
    local flags = S and S.FontFlags and S.FontFlags(NS.Setting("window.tableFontFlags"), "window")
    if type(flags) ~= "string" then flags = "" end
    local shadow = NS.Setting("window.tableFontShadow") == true
    current = { face = face, flags = flags, shadow = shadow, plain = plainColor(),
        key = (face or "") .. "|" .. flags .. "|" .. (shadow and "s" or "") }
    return current
end

--- The rows' metrics for one repaint, from the Window page's Layout rows:
--- { height, fontSize (nil = Default), icon, countdownHeight, font (WR.ReadFont's) }.
--- @return table
function WR.Metrics()
    local h = WR.RowHeight(NS.Setting("window.rowHeight"))
    local size = WR.FontSize(NS.Setting("window.fontSize"))
    return { height = h, fontSize = size, icon = WR.IconSize(h), countdownHeight = WR.CountdownRowHeight(h, size),
        font = WR.ReadFont() }
end

--- Color a table text in `tone` (a C.TONE key; an unknown one is plain). Plain text of a table row
--- (one ApplyRowFont reached) takes the block's color; every other tone, and a text outside the
--- tables, draws C.TONE as before.
--- @param fs table a FontString
--- @param tone string|nil
function WR.SetTone(fs, tone)
    local c = C.TONE[tone]
    if fs.dwTableText and (c == nil or tone == "plain") then
        local p = (current or WR.ReadFont()).plain
        if p then return fs:SetTextColor(p[1], p[2], p[3], p[4]) end
    end
    c = c or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

-- The skin's generation: bumped on every skin switch (WR.OnLooksChanged, from modules/Window.lua's
-- listener). A switch repaints each text's face at its template's size (the skin's S.Font, the
-- glyphs' NS.SkinPaint), so a face cached before it is stale: SetFontSize reads it anew, and
-- ApplyRowFont applies the size again, once per row.
local gen = 0

--- A skin switch happened: every cached face and row size is read again on its next use.
function WR.OnLooksChanged() gen = gen + 1 end

--- A font string at `size` points, keeping its face and flags; nil puts back the size it had
--- before the first change (its template's, or the monospace face's). The face is the skin's: read
--- from the string after the skin painted it, and again after a skin switch.
--- @param fs table a FontString
--- @param size number|nil
function WR.SetFontSize(fs, size)
    local base = fs.dwBaseFont
    if base and fs.dwFontGen ~= gen then
        -- The skin moved and repainted the face at the template's size: start from that.
        base, fs.dwBaseFont = nil, nil
    end
    if not base then
        if size == nil then return end
        local file, own, flags = fs:GetFont()
        if type(file) ~= "string" then return end
        base = { file, own, flags or "" }
        fs.dwBaseFont, fs.dwFontGen = base, gen
    end
    fs:SetFont(base[1], size or base[2], base[3])
end

-- One named font object per look (CreateFont, the client's), keyed by face, size, flags and shadow.
local objects, made = {}, 0

local function fontObject(path, size, flags, shadow)
    if type(CreateFont) ~= "function" then return nil end
    local key = ("%s\0%.1f\0%s\0%s"):format(path, size, flags, shadow and "s" or "")
    local obj = objects[key]
    if obj == nil then
        made = made + 1
        obj = CreateFont(("%s_TableFont%d"):format(addonName, made)) or false
        if obj then
            obj:SetFont(path, size, flags)
            obj:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
            obj:SetShadowColor(0, 0, 0, shadow and 1 or 0)
        end
        objects[key] = obj
    end
    return obj or nil
end

--- The face, size and flags `fs` was painted in (the skin's, or its template's), read once per
--- skin generation: a switch repaints the string, so the next read is the new skin's. Nil while the
--- string has no font yet.
local function paintedFont(fs)
    local base = fs.dwBaseFont
    if base and fs.dwFontGen == gen then return base end
    local file, own, flags = fs:GetFont()
    if type(file) ~= "string" then
        fs.dwBaseFont = nil
        return nil
    end
    base = { file, own, flags or "" }
    fs.dwBaseFont, fs.dwFontGen = base, gen
    return base
end

-- The string's own shadow, where no font object carries it (the harness: no CreateFont).
local function stringShadow(fs, on)
    if not fs.SetShadowOffset then return end
    fs:SetShadowOffset(on and 1 or 0, on and -1 or 0)
    fs:SetShadowColor(0, 0, 0, on and 1 or 0)
end

--- A table text in the block's look at `size` (nil = the painted size): its face, the skin's or the
--- picked one, the resolved flags and the shadow. The painted color is kept: a font object would
--- otherwise hand the string its own.
--- @param fs table a FontString
--- @param size number|nil
--- @param font table WR.ReadFont's answer
function WR.SetTableFont(fs, size, font)
    local base = paintedFont(fs)
    if not base then return end
    local path, height = font.face or base[1], size or base[2]
    local obj = fontObject(path, height, font.flags, font.shadow)
    if not obj then
        fs:SetFont(path, height, font.flags)
        return stringShadow(fs, font.shadow)
    end
    local r, g, b, a = fs:GetTextColor()
    fs:SetFontObject(obj)
    if r then fs:SetTextColor(r, g, b, a) end
end

local TEXTS  = { "text", "sub", "level", "mark", "leadLevel", "leadText", "sep" }
local GLYPHS = { "glyph", "leadGlyph" }

--- Every text of a row's cells (`row.cells[key].text`, `.sub`, `.level`, `.mark`, and a dual mark's
--- `.leadLevel`, `.leadText`, `.sep`: feedback-21 H7) in the block's font at `size`, and the glyphs
--- (`.glyph`, `.leadGlyph`: the monospace face) at `size`, once per change. Marks each text as a table
--- text, so SetTone gives its plain tone the block's color.
--- @param row table
--- @param size number|nil
--- @param font table|nil WR.ReadFont's answer (nil reads it)
function WR.ApplyRowFont(row, size, font)
    font = font or WR.ReadFont()
    local key = (size or 0) .. "|" .. font.key
    if row.dwFontSize == key and row.dwFontGen == gen then return end
    row.dwFontSize, row.dwFontGen = key, gen
    for _, f in pairs(row.cells) do
        for _, part in ipairs(TEXTS) do
            local fs = f[part]
            if fs then
                fs.dwTableText = true
                WR.SetTableFont(fs, size, font)
            end
        end
        for _, part in ipairs(GLYPHS) do
            local fs = f[part]
            if fs then
                fs.dwTableText = true
                WR.SetFontSize(fs, size)
            end
        end
    end
end

--- A row's item button at `size`, once per change (`row.cells.item.button`).
--- @param row table
--- @param size number
function WR.ApplyRowIcon(row, size)
    if row.dwIcon == size then return end
    row.dwIcon = size
    local b = row.cells.item and row.cells.item.button
    if b then b:SetSize(size, size) end
end

-- ── a mark after a cell's text (feedback-7 spec §2) ─────────────────────────────────────────

--- The gap between a cell's text and its mark, in pixels.
WR.MARK_GAP = 3

--- A gold mark drawn right after `text` (hidden until WR.PlaceMark gives it a word).
--- @param parent table the frame that owns `text`
--- @param text table the FontString the mark follows
--- @param scale number|nil its face's scale (NS.ScaledFontString: the upgrade toast's, DW-05)
--- @return table the mark's FontString
function WR.NewMark(parent, text, scale)
    local m = NS.ScaledFontString(parent, "OVERLAY", "GameFontHighlightSmall", scale)
    m:SetPoint("LEFT", text, "RIGHT", WR.MARK_GAP, 0)
    m:SetWordWrap(false)
    NS.Skin.Text(m, "accent")   -- the skin's accent (Ka0s Default gold) in its face
    m:Hide()
    return m
end

--- The width `text` may take beside a mark of `markWidth` in `width`: its own width (`full`) when
--- that fits, else what is left after the mark and the gap (never under 10), so the text is cut
--- and the mark is not. With no mark the text keeps `width`. Pure.
--- @param width number the room for both
--- @param full number|nil the text's own width, unbounded (nil when not known)
--- @param markWidth number|nil the mark's width (nil: no mark)
--- @return number
function WR.MarkedWidth(width, full, markWidth)
    if not markWidth then return width end
    local room = max(width - markWidth - WR.MARK_GAP, 10)
    return full and min(full + 1, room) or room
end

--- Show `word` in `mark` after `text`, or hide it (nil). `text` already holds its text; it is given
--- WR.MarkedWidth's width out of `width`.
--- @param text table FontString
--- @param mark table FontString (WR.NewMark's)
--- @param word string|nil
--- @param width number the room for both
function WR.PlaceMark(text, mark, word, width)
    mark:SetText(word or "")
    mark:SetShown(word ~= nil)
    local full = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or nil
    local mw = word and (mark:GetStringWidth() or 0) or nil
    text:SetWidth(WR.MarkedWidth(width, full, mw))
end

--- Give a table cell (`f.text`) its mark (`f.mark`, WR.NewMark's): the Looter column's builder.
--- @param f table the cell
--- @return table the cell
function WR.MarkedCell(f)
    f.mark = WR.NewMark(f, f.text)
    return f
end

--- Paint a marked cell's mark for this repaint (`at` its layout entry, nil while the column is shed).
--- @param f table the cell (WR.MarkedCell's)
--- @param word string|nil
--- @param at table|nil { x, w }
function WR.PaintMark(f, word, at)
    if at then WR.PlaceMark(f.text, f.mark, word, at.w) end
end
