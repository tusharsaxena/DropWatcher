local _, NS = ...
-- modules/WindowRows.lua — the drop tables' row metrics and text size, shared by both tabs
-- (feedback-2 spec §8, FB2-9): Drops and History read their rows' height and font
-- from the Window page's Layout rows, `window.rowHeight` and `window.fontSize`.
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
-- PURE: FontSize, RowHeight, IconSize, CountdownRowHeight. The frame edge: Metrics reads the two rows
-- through the schema seam (NS.Setting) once per repaint; SetFontSize and ApplyRowFont set a font
-- string's size, keeping its face and flags, and put the template's own size back for Default.

NS.WindowRows = NS.WindowRows or {}
local WR = NS.WindowRows
local K  = NS.Constants.WINDOW

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

--- The rows' metrics for one repaint, from the Window page's Layout rows:
--- { height, fontSize (nil = Default), icon, countdownHeight }.
--- @return table
function WR.Metrics()
    local h = WR.RowHeight(NS.Setting("window.rowHeight"))
    local size = WR.FontSize(NS.Setting("window.fontSize"))
    return { height = h, fontSize = size, icon = WR.IconSize(h), countdownHeight = WR.CountdownRowHeight(h, size) }
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

--- A font string at `size` points, keeping its face and flags; nil puts back the size it had
--- before the first change (its template's, or the monospace face's).
--- @param fs table a FontString
--- @param size number|nil
function WR.SetFontSize(fs, size)
    local base = fs.dwBaseFont
    if not base then
        if size == nil then return end
        local file, own, flags = fs:GetFont()
        if type(file) ~= "string" then return end
        base = { file, own, flags or "" }
        fs.dwBaseFont = base
    end
    fs:SetFont(base[1], size or base[2], base[3])
end

local PARTS = { "text", "glyph", "sub" }

--- Every text of a row's cells (`row.cells[key].text`, `.glyph`, `.sub`) at `size`, once per change.
--- @param row table
--- @param size number|nil
function WR.ApplyRowFont(row, size)
    local key = size or 0
    if row.dwFontSize == key then return end
    row.dwFontSize = key
    for _, f in pairs(row.cells) do
        for _, part in ipairs(PARTS) do
            if f[part] then WR.SetFontSize(f[part], size) end
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
