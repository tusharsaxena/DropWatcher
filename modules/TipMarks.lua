local _, NS = ...
-- modules/TipMarks.lua — what a tooltip may draw where a table cell draws a verdict glyph
-- (feedback-6 spec §3, DW-F3). The tooltip's face has no `▲`, `▼`, `≈` or `⊘`: it draws them as
-- boxes. So a verdict mark in a tooltip is an inline texture escape (`|T…|t`) of a LibKa0s media
-- icon, tinted through the escape's own color fields: `arrow-up` green for an upgrade, `transfer`
-- yellow for a sidegrade, `arrow-down` red for a downgrade. Table cells and compact lines keep the
-- monospace glyphs (NS.WindowCells.GLYPH), which render.
--
-- NOT ONLY TOOLTIPS (DW-F5). Every text drawn in the default face (GameFont*, not C.FONT_MONO) takes
-- its marks from here too. The `->` between two values in the detail card's Item level and Track rows
-- is TM.Arrow, the `arrow-right` icon in the muted tone. (The card's verdict chips and those rows drew
-- TM.Mark's textures until feedback-21 H5: they now draw the table's glyphs, TM.ArrowCell's, in a
-- monospace string of their own, modules/DetailCard.lua. The
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
-- one per worn item (two for rings, trinkets and one-hand weapons), the name on the first, `empty`
-- (muted) for a slot worn empty. The row of the item the drop would replace takes the verdict's own
-- arrow; every other worn item takes its own (feedback-21 H3), the drop's item level against its
-- own, judged by NS.Evaluate.ItemVerdict (the kernel's item-level rule and sidegrade band). The
-- cells' dual marks (`321 ▼10 / 324 ▼23`, NS.SideCells, feedback-21 H7) take the same two arrows
-- (TM.ItemArrow, TM.ReplacedRow), so a cell and its tooltip never disagree.
-- A gear grid goes right under the tooltip's title, above its rows (feedback-21 H3).
-- modules/TipGrid.lua paints a grid; TM.Text reads one as plain text for the suites.
--
-- THE ROWS (feedback-21). A tooltip is its title, then one row per data point, never a sentence:
-- `• Label: value` (TM.Row), the bullet and the label in the muted gold (C.TONE.mutedGold,
-- feedback-21 H3; the idle gray C.IDLE before), the value plain or in a C.TONE tone; the label's
-- colon is a routed format, so a locale can space it. A short closing hint (`Click to cancel it.`)
-- is the one free text a tooltip keeps: TM.Hint, unbulleted and in the idle gray.
-- The bullet is TM.BULLET: the media library has no dot-like icon to draw as an escape, so it is the
-- `•` character, which the tooltip face draws (the View and Filters tooltips have drawn it since
-- DW-A1), unlike the glyphs above.

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
--- library is absent, or "" for a verdict with no mark. `tone` (a C.TONE key) tints it instead of
--- the verdict's own: an off-spec verdict's cyan (feedback-19 spec §1).
--- @param verdict string `upgrade`, `sidegrade` or `downgrade`
--- @param tone string|nil
--- @return string
function TM.Mark(verdict, tone)
    local m = TM.MARK[verdict]
    if not m then return "" end
    local path = NS.Icon(m.icon)
    if not path then return FALLBACK[verdict] end
    local t = C.TONE[tone] or C.TONE[m.tone]
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

--- An item's name in its quality's color: NS.QualityColor(quality), else the color code its link
--- opens with (`|cffa335ee`, or a named one such as `|cnIQ4:`), else plain.
--- @param name string
--- @param quality number|nil
--- @param link string|nil
--- @return string
function TM.ItemName(name, quality, link)
    local r, g, b
    if quality ~= nil then r, g, b = NS.QualityColor(quality) end   -- the skin's q.*, else the client's (E4)
    if type(r) == "number" then return NS.GroupRoster.Colored(name, r, g, b) end
    if type(link) ~= "string" then return name end
    local code = link:match("^(|c%x%x%x%x%x%x%x%x)") or link:match("^(|cn[^|:]+:)")   -- `|cffa335ee`, `|cnIQ4:`
    if code then return code .. name .. "|r" end
    return name
end

-- ── the rows (feedback-21) ──────────────────────────────────────────────────────────────────

--- The bullet every row opens with.
TM.BULLET = "•"

-- The hint gray is the skin's tooltip hint (`dw.tipHint`, Ka0s Default 0.62), its own token so a light
-- skin can part it from the window's idle gray (D7).
local function idle(text) return NS.GroupRoster.Colored(text, NS.Skin.Color("dw.tipHint")) end
local function label(text)
    local t = C.TONE.mutedGold
    return NS.GroupRoster.Colored(text, t.r, t.g, t.b)
end

--- The bullet, in the labels' muted gold.
--- @return string
function TM.Bullet() return label(TM.BULLET) end

--- One data point of a tooltip: `• Label: value`, the bullet and the label muted gold, the value
--- plain or in `tone` (a C.TONE key). Nil when there is no value, so a fact not known drops out of
--- the list; with no label, the bullet and the value alone.
--- @param name string|nil the label
--- @param value any
--- @param tone string|nil
--- @return string|nil
function TM.Row(name, value, tone)
    if value == nil then return nil end
    local text, t = tostring(value), C.TONE[tone]
    if t then text = NS.GroupRoster.Colored(text, t.r, t.g, t.b) end
    if name == nil then return ("%s %s"):format(TM.Bullet(), text) end
    return ("%s %s"):format(label(("%s %s"):format(TM.BULLET, L["%s:"]:format(name))), text)
end

--- A tooltip's closing hint: unbulleted, in the idle gray.
--- @param text string
--- @return string
function TM.Hint(text) return idle(text) end

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
--- alone with no difference (into an empty slot). "" for a verdict with no glyph. `tone` (a C.TONE
--- key) replaces the verdict's: an off-spec verdict's cyan (feedback-19 spec §1).
--- @param verdict string|nil
--- @param delta number|nil the signed difference
--- @param tone string|nil
--- @return table|string { glyph, text, tone } or ""
function TM.ArrowCell(verdict, delta, tone)
    local glyph, m = WC.GLYPH[verdict], TM.MARK[verdict]
    if not (glyph and m) then return "" end
    local text = ""
    if type(delta) == "number" and delta == delta then text = tostring(round(math.abs(delta))) end
    return { glyph = glyph, text = text, tone = C.TONE[tone] and tone or m.tone }
end

--- The muted `empty` cell: nothing is worn there.
--- @return table
function TM.EmptyCell() return { text = L["empty"], tone = "muted" } end

--- A worn item's level as a grid (and a cell's dual mark) shows it: whole, or `?` when not read.
--- @param it table { ilvl }
--- @return string
local function levelText(it)
    local n = type(it.ilvl) == "number" and it.ilvl == it.ilvl and it.ilvl or nil
    return n and tostring(round(n)) or "?"
end
TM.LevelText = levelText

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

--- A worn item's own arrow (feedback-21 H3): the drop's item level against the worn one's, judged as
--- the kernel judges an item level (NS.Evaluate.ItemVerdict, the sidegrade band included); "" when
--- either level is not known. The cells' dual marks take it too (NS.SideCells, feedback-21 H7).
--- @param worn number|nil the worn item's level
--- @param ilvl number|nil the drop's
--- @param band number|nil the verdict's sidegrade band
--- @param tone string|nil TM.ArrowCell's tone override
--- @return table|string
function TM.ItemArrow(worn, ilvl, band, tone)
    local n = type(worn) == "number" and worn == worn and worn or nil
    local i = type(ilvl) == "number" and ilvl == ilvl and ilvl or nil
    if not (n and i) then return "" end
    local d = i - n
    return TM.ArrowCell(NS.Evaluate.ItemVerdict(d, band), d, tone)
end

local function ownArrow(it, judge) return TM.ItemArrow(it.ilvl, judge.ilvl, judge.band, judge.tone) end

--- The row of `items` the drop would replace (TM.GearRows' arrow row): the baseline's item, else a
--- slot worn empty (`#items + 1`), else the lowest item level.
--- @param items table
--- @param empty number
--- @param base table|nil
--- @return number
function TM.ReplacedRow(items, empty, base) return replacedRow(items, empty, base) end

--- One member's rows of a gear grid: `[who] [ilvl] [item] [arrow]` for each worn item (the item ""
--- when only its level was read), a muted `empty` row for each slot worn empty (one when nothing is
--- listed at all), the name on the first row only. The row of the item the drop would replace takes
--- `arrow` (the verdict's own); with `judge` and a verdict arrow, every other worn item takes its own
--- (the drop's level against its own, feedback-21 H3), and another empty slot the same arrow as the
--- replaced empty one. Every other last cell "".
--- @param who string the member's name, colored (TM.ClassName)
--- @param items table { { link, ilvl, name?, quality? }, ... }
--- @param empty number|nil how many slots are worn empty
--- @param arrow table|string TM.ArrowCell's answer
--- @param base table|nil the worn item the drop was judged against (NS.Evaluate's baseline)
--- @param judge table|nil { ilvl, band, tone }: the drop's item level, the verdict's sidegrade band
---   (NS.Evaluate's `band`), the arrow's tone override (an off-spec verdict's)
--- @return table rows
function TM.GearRows(who, items, empty, arrow, base, judge)
    items, empty = type(items) == "table" and items or {}, empty or 0
    if #items == 0 and empty == 0 then empty = 1 end
    local judged = type(judge) == "table" and type(arrow) == "table"
    local rows = {}
    for _, it in ipairs(items) do
        rows[#rows + 1] = { "", levelText(it), itemCell(it), judged and ownArrow(it, judge) or "" }
    end
    for _ = 1, empty do rows[#rows + 1] = { "", "", TM.EmptyCell(), "" } end
    rows[1][1] = who
    local at = replacedRow(items, empty, base)
    rows[at][4] = arrow
    if judged and at > #items then
        for i = #items + 1, #rows do rows[i][4] = arrow end
    end
    return rows
end
