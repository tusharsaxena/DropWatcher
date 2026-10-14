local _, NS = ...
-- modules/TipMarks.lua — what a tooltip may draw where a table cell draws a verdict glyph
-- (feedback-6 spec §3, DW-F3). The tooltip's face has no `▲`, `▼`, `≈` or `⊘`: it draws them as
-- boxes. So a verdict mark in a tooltip is an inline texture escape (`|T…|t`) of a LibKa0s media
-- icon, tinted through the escape's own color fields: `arrow-up` green for an upgrade, `transfer`
-- yellow for a sidegrade, `arrow-down` red for a downgrade. Table cells and compact lines keep the
-- monospace glyphs (NS.WindowCells.GLYPH), which render.
--
-- NOT ONLY TOOLTIPS (DW-F5). Every text drawn in the default face (GameFont*, not C.FONT_MONO) takes
-- its marks from here too: the detail card's verdict chips and Item level and Track rows. The `->`
-- between two values in those rows is TM.Arrow, the `arrow-right` icon in the muted tone. (The
-- toast drew its gain's mark from here until feedback-9 spec §0: its verdicts are now monospace
-- glyphs in segments of their own, and its names take TM.ItemName and TM.ClassName.) TM.Chars counts
-- what such a text draws (an escape as two characters, a color code as none), for a width estimated
-- before the client measures.
--
-- A NON-WRAPPING LINE. A tooltip line is a string (it wraps at the tooltip's width) or
-- `{ text, wrap = false }`, which does not wrap, so the tooltip grows to fit it
-- (modules/Window.lua's showTooltip reads strings, these and TM.Grid's lines). TM.Text answers any
-- of them as its string. TM.NoWrap has no caller since the gear lines became grids: it is kept as
-- API, pinned by test_tip_marks.
--
-- THE COLORS. TM.ClassName and TM.ItemName put a name in its class or quality color, read at call
-- time from the client's tables (NS.Compat.ClassColor; ITEM_QUALITY_COLORS, else the link's own
-- color); plain when neither is known. Otherwise nothing here reads a module's state or a saved
-- variable, so test_tip_marks pins every escape string.
--
-- A GRID (feedback-7 spec §3). A tooltip that lists worn gear against a drop lists it as columns,
-- `[Name]  [Item level]  [Item name]  [Arrow and difference]`: a line `{ grid = { row, ... } }`
-- (TM.Grid), each row a list of cells, a cell a string (colors in its own codes) or
-- `{ text, tone, glyph }`. The arrow cell (TM.ArrowCell) is the table's own glyph
-- (NS.WindowCells.GLYPH, drawn in the monospace face, so it renders) and the unsigned difference,
-- both in the verdict's tone; no texture mark inside a grid. TM.GearRows builds a member's rows:
-- one per worn item (two for rings, trinkets and one-hand weapons), the name on the first, the
-- arrow on the row of the item the drop would replace, `empty` (muted) for a slot worn empty.
-- modules/TipGrid.lua paints a grid; TM.Text reads one as plain text for the suites.

NS.TipMarks = NS.TipMarks or {}
local TM = NS.TipMarks
local C  = NS.Constants
local L  = NS.L
local WC = NS.WindowCells

local floor = math.floor

--- The media icons' canvas, in pixels (LibKa0s media: every icon is a 64x64 TGA). The escape's
--- texture coordinates span all of it.
TM.TEX_SIZE = 64

--- Each verdict's mark: the media icon and the C.TONE key that tints it.
TM.MARK = {
    upgrade   = { icon = "arrow-up", tone = "good" },
    sidegrade = { icon = "transfer", tone = "yellow" },
    downgrade = { icon = "arrow-down", tone = "red" },
}

-- With the library absent (NS.Icon answers nil) a mark falls back to a character every face has.
local FALLBACK = { upgrade = "+", sidegrade = "~", downgrade = "-" }

local function byte(v) return floor(math.max(0, math.min(1, v)) * 255 + 0.5) end

--- An inline texture escape for `path`, at the text's height (0:0) and tinted r, g, b (0..1):
--- `|T<path>:0:0:0:0:64:64:0:64:0:64:R:G:B|t`, R, G, B as 0..255.
--- @param path string
--- @param r number
--- @param g number
--- @param b number
--- @return string
function TM.Escape(path, r, g, b)
    local s = TM.TEX_SIZE
    return ("|T%s:0:0:0:0:%d:%d:0:%d:0:%d:%d:%d:%d|t"):format(path, s, s, s, s, byte(r), byte(g), byte(b))
end

--- A verdict's mark for a tooltip: the tinted texture escape, its fallback character when the media
--- library is absent, or "" for a verdict with no mark.
--- @param verdict string `upgrade`, `sidegrade` or `downgrade`
--- @return string
function TM.Mark(verdict)
    local m = TM.MARK[verdict]
    if not m then return "" end
    local path = NS.Icon(m.icon)
    if not path then return FALLBACK[verdict] end
    local t = C.TONE[m.tone]
    return TM.Escape(path, t.r, t.g, t.b)
end

--- The arrow between two values in the default face (`276 -> 295`): the `arrow-right` icon.
TM.ARROW = { icon = "arrow-right", tone = "muted" }

--- The arrow for a text in the default face: the muted `arrow-right` texture escape, or `->` when the
--- media library is absent.
--- @return string
function TM.Arrow()
    local path = NS.Icon(TM.ARROW.icon)
    if not path then return "->" end
    local t = C.TONE[TM.ARROW.tone]
    return TM.Escape(path, t.r, t.g, t.b)
end

--- What a text draws, in characters: an inline texture escape counts two (it is square at the
--- text's height), a color code none, a UTF-8 character one.
--- @param text string|nil
--- @return number
function TM.Chars(text)
    local s = tostring(text or "")
    local n
    s, n = s:gsub("|T.-|t", "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^|:]+:", ""):gsub("|r", "")
    s = s:gsub("[\128-\191]", "")   -- a UTF-8 continuation byte draws nothing of its own
    return #s + 2 * n
end

--- A tooltip line that does not wrap: the tooltip grows to fit it.
--- @param text string
--- @return table { text, wrap = false }
function TM.NoWrap(text) return { text = text, wrap = false } end

--- A tooltip line's text, whether it is a string, a TM.NoWrap table or a TM.Grid (its rows on lines
--- of their own, each row's drawn cells two spaces apart).
--- @param line string|table
--- @return string
function TM.Text(line)
    if TM.IsGrid(line) then
        local rows = {}
        for i, row in ipairs(line.grid) do
            local cells = {}
            for _, cell in ipairs(row) do
                local t = TM.CellText(cell)
                if t ~= "" then cells[#cells + 1] = t end
            end
            rows[i] = table.concat(cells, "  ")
        end
        return table.concat(rows, "\n")
    end
    if type(line) == "table" then return tostring(line.text) end
    return tostring(line)
end

--- `name` in its class's color; plain when the class has none.
--- @param name string
--- @param classFile string|nil
--- @return string
function TM.ClassName(name, classFile)
    return NS.GroupRoster.Colored(name, NS.Compat.ClassColor(classFile))
end

--- An item's name in its quality's color: ITEM_QUALITY_COLORS[quality], else the color code its link
--- opens with (`|cffa335ee`, or a named one such as `|cnIQ4:`), else plain.
--- @param name string
--- @param quality number|nil
--- @param link string|nil
--- @return string
function TM.ItemName(name, quality, link)
    local qc = type(ITEM_QUALITY_COLORS) == "table" and quality and ITEM_QUALITY_COLORS[quality]
    if type(qc) == "table" and type(qc.r) == "number" then return NS.GroupRoster.Colored(name, qc.r, qc.g, qc.b) end
    if type(link) ~= "string" then return name end
    local code = link:match("^(|c%x%x%x%x%x%x%x%x)") or link:match("^(|cn[^|:]+:)")   -- `|cffa335ee`, `|cnIQ4:`
    if code then return code .. name .. "|r" end
    return name
end

-- ── the grid (feedback-7 spec §3) ───────────────────────────────────────────────────────────

local function round(n) return floor(n + 0.5) end

--- A tooltip line laid out as columns: `rows` is a list of rows, each a list of cells.
--- @param rows table
--- @return table { grid = rows }
function TM.Grid(rows) return { grid = rows } end

--- Whether a tooltip line is a grid.
--- @param line any
--- @return boolean
function TM.IsGrid(line) return type(line) == "table" and type(line.grid) == "table" end

--- A grid cell's text as drawn: its glyph and its text (a string cell is its own text).
--- @param cell string|table|nil
--- @return string
function TM.CellText(cell)
    if type(cell) ~= "table" then return tostring(cell or "") end
    return (cell.glyph or "") .. tostring(cell.text or "")
end

--- The arrow cell: the verdict's glyph (NS.WindowCells.GLYPH, the monospace face) and the unsigned
--- item-level difference, both in the verdict's tone (TM.MARK's: green, yellow, red); the glyph
--- alone with no difference (into an empty slot). "" for a verdict with no glyph.
--- @param verdict string|nil
--- @param delta number|nil the signed difference
--- @return table|string { glyph, text, tone } or ""
function TM.ArrowCell(verdict, delta)
    local glyph, m = WC.GLYPH[verdict], TM.MARK[verdict]
    if not (glyph and m) then return "" end
    local text = ""
    if type(delta) == "number" and delta == delta then text = tostring(round(math.abs(delta))) end
    return { glyph = glyph, text = text, tone = m.tone }
end

--- The muted `empty` cell: nothing is worn there.
--- @return table
function TM.EmptyCell() return { text = L["empty"], tone = "muted" } end

local function levelText(it)
    local n = type(it.ilvl) == "number" and it.ilvl == it.ilvl and it.ilvl or nil
    return n and tostring(round(n)) or "?"
end

-- The worn item's name in its quality color; "" when only its level was read.
local function itemCell(it)
    local name = it.name or WC.ItemName(it.link)
    if not name then return "" end
    return TM.ItemName(name, it.quality, it.link)
end

-- The row the drop would replace: the baseline's item when it is listed, else a slot worn empty,
-- else the lowest item level (of two, the one the drop is compared with).
local function replacedRow(items, empty, base)
    local baseLink = type(base) == "table" and base.link or nil
    for i, it in ipairs(items) do
        if baseLink and it.link == baseLink then return i end
    end
    if empty > 0 then return #items + 1 end
    local at, low = 1, math.huge
    for i, it in ipairs(items) do
        local n = type(it.ilvl) == "number" and it.ilvl or math.huge
        if n < low then at, low = i, n end
    end
    return at
end

--- One member's rows of a gear grid: `[who] [ilvl] [item] [arrow]` for each worn item (the item ""
--- when only its level was read), a muted
--- `empty` row for each slot worn empty (one when nothing is listed at all), the name on the first
--- row only and the arrow on the row of the item the drop would replace; every other last cell "".
--- @param who string the member's name, colored (TM.ClassName)
--- @param items table { { link, ilvl, name?, quality? }, ... }
--- @param empty number|nil how many slots are worn empty
--- @param arrow table|string TM.ArrowCell's answer
--- @param base table|nil the worn item the drop was judged against (NS.Evaluate's baseline)
--- @return table rows
function TM.GearRows(who, items, empty, arrow, base)
    items, empty = type(items) == "table" and items or {}, empty or 0
    if #items == 0 and empty == 0 then empty = 1 end
    local rows = {}
    for _, it in ipairs(items) do rows[#rows + 1] = { "", levelText(it), itemCell(it), "" } end
    for _ = 1, empty do rows[#rows + 1] = { "", "", TM.EmptyCell(), "" } end
    rows[1][1] = who
    rows[replacedRow(items, empty, base)][4] = arrow
    return rows
end
