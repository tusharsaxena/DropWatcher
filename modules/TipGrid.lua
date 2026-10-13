local _, NS = ...
-- modules/TipGrid.lua — the frame edge that paints a tooltip's grid (feedback-7 spec §3): a tooltip
-- line `{ grid = rows }` (NS.TipMarks.Grid) laid out as columns, `[Name]  [Item level]  [Item name]
-- [Arrow and difference]`, each column as wide as its widest cell and a fixed gap between them.
--
-- HOW. The tooltip stays GameTooltip (its skin, its placement through NS.RowTooltip). TG.Add reserves
-- one tooltip line per row (a blank line); after the tooltip is shown TG.Paint draws each cell as a
-- font string on a pooled child frame of the tooltip, anchored to the row's reserved line
-- (`<tooltip>TextLeft<n>`, NS.Compat.TooltipLeftLine), measures the columns, and makes room for the
-- widest row through SetMinimumWidth (guarded: an older client or the headless mock may lack it),
-- showing the tooltip again so it takes the width. A string cell draws in the lines' own font, its
-- colors in its own codes; a `{ glyph, text, tone }` cell draws the glyph in the monospace face
-- (C.FONT_MONO: the tooltip's face has no ▲ ≈ ▽) and the number after it, both in the tone (C.TONE).
--
-- RELEASE. The pool hides, and the minimum width goes back to 0, on the next TG.Begin, when the
-- tooltip hides (the pool frame's OnHide) and when it is cleared for someone else (OnTooltipCleared):
-- GameTooltip is the whole UI's, so nothing of a grid outlives it.
--
-- TG.Columns is pure (the suites read it); TG.Painted answers what the last paint drew, for the
-- suites, which have no tooltip lines to anchor to.

NS.TipGrid = NS.TipGrid or {}
local TG = NS.TipGrid
local C  = NS.Constants
local TM = NS.TipMarks

TG.GAP = 14          -- between two columns, in pixels
TG.GLYPH_GAP = 3     -- between a glyph and its number (WindowGroup.SIDE's GLYPH_GAP)
TG.GLYPH_SIZE = 12   -- the monospace glyph's size, the table's
TG.CHAR_W = 7        -- a character's width when the client has not measured the text yet

local holder         -- the pool's frame, a child of the tooltip, built on the first paint
local pools = { plain = {}, mono = {} }
local used = { plain = 0, mono = 0 }
local pending = {}   -- { line = n, rows = rows } reserved since TG.Begin
local painted = {}   -- { { text, x, line, mono }, ... } of the last paint
local widened = nil  -- the tooltip whose minimum width a grid set

local WHITE = { r = 1, g = 1, b = 1 }

--- The columns' left edges and the grid's width, from each cell's width: a column is as wide as its
--- widest cell, `gap` between two columns; a column with nothing drawn in any row takes no room.
--- @param widths table { { w, ... }, ... } one list per row
--- @param gap number
--- @return table xs, number total
function TG.Columns(widths, gap)
    local colW, n = {}, 0
    for _, row in ipairs(widths) do
        for c, w in ipairs(row) do
            colW[c] = math.max(colW[c] or 0, w or 0)
            if c > n then n = c end
        end
    end
    local xs, x, total = {}, 0, 0
    for c = 1, n do
        xs[c] = x
        local w = colW[c] or 0
        if w > 0 then
            total = x + w
            x = total + gap
        end
    end
    return xs, total
end

local function release()
    for kind, list in pairs(pools) do
        for i = 1, used[kind] do list[i]:Hide() end
        used[kind] = 0
    end
    pending, painted = {}, {}
    if widened and widened.SetMinimumWidth then widened:SetMinimumWidth(0) end
    widened = nil
end

local function ensureHolder(tip)
    if holder then return holder end
    holder = CreateFrame("Frame", nil, tip)
    holder:SetAllPoints(tip)
    holder:SetScript("OnHide", release)
    if tip.HookScript and tip.HasScript and tip:HasScript("OnTooltipCleared") then
        tip:HookScript("OnTooltipCleared", release)
    end
    return holder
end

local lineFont   -- the tooltip lines' font object, for a plain cell (read per paint)

local function acquire(kind)
    used[kind] = used[kind] + 1
    local fs = pools[kind][used[kind]]
    if not fs then
        fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        if kind == "mono" then fs:SetFont(C.FONT_MONO, TG.GLYPH_SIZE, "") end
        pools[kind][used[kind]] = fs
    end
    if kind == "plain" and lineFont then fs:SetFontObject(lineFont) end
    fs:Show()
    return fs
end

local function widthOf(fs, text)
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()
    if type(w) ~= "number" then w = TM.Chars(text) * TG.CHAR_W end
    return w
end

local function textFs(kind, text, tone)
    local fs = acquire(kind)
    fs:SetText(text)
    local c = tone and C.TONE[tone] or WHITE
    fs:SetTextColor(c.r, c.g, c.b)
    return fs, widthOf(fs, text)
end

-- One cell's font strings and width: { parts = { { fs, dx, text, mono } }, w }.
local function cellOf(cell)
    if type(cell) ~= "table" then
        local text = tostring(cell or "")
        if text == "" then return { parts = {}, w = 0 } end
        local fs, w = textFs("plain", text)
        return { parts = { { fs = fs, dx = 0, text = text } }, w = w }
    end
    local parts, w = {}, 0
    if cell.glyph then
        local fs, gw = textFs("mono", cell.glyph, cell.tone)
        parts[1], w = { fs = fs, dx = 0, text = cell.glyph, mono = true }, gw
    end
    local text = tostring(cell.text or "")
    if text ~= "" then
        if w > 0 then w = w + TG.GLYPH_GAP end
        local fs, tw = textFs("plain", text, cell.tone)
        parts[#parts + 1] = { fs = fs, dx = w, text = text }
        w = w + tw
    end
    return { parts = parts, w = w }
end

local function place(tip, part, n, x)
    local fs = part.fs
    fs:ClearAllPoints()
    local anchor = NS.Compat.TooltipLeftLine(tip, n)   -- nil in the headless harness
    if anchor then fs:SetPoint("LEFT", anchor, "LEFT", x + part.dx, 0) end
    painted[#painted + 1] = { text = part.text, x = x + part.dx, line = n, mono = part.mono == true }
end

--- Forget the last grid: called before a tooltip is built.
function TG.Begin() release() end

--- Reserve one tooltip line per row of `line` (a TM.Grid), to be painted by TG.Paint.
--- @param tip table the tooltip (GameTooltip)
--- @param line table { grid = rows }
function TG.Add(tip, line)
    for _, row in ipairs(line.grid) do
        tip:AddLine(" ", 1, 1, 1, false)
        local n = tip.NumLines and tip:NumLines()
        pending[#pending + 1] = { line = type(n) == "number" and n or #pending + 2, row = row }
    end
end

--- Paint the rows TG.Add reserved, once the tooltip is shown: the cells, the columns, the width.
--- @param tip table the tooltip, shown
function TG.Paint(tip)
    if #pending == 0 then return end
    ensureHolder(tip)
    local first = NS.Compat.TooltipLeftLine(tip, pending[1].line)
    lineFont = first and first.GetFontObject and first:GetFontObject() or nil
    local cells, widths = {}, {}
    for r, p in ipairs(pending) do
        cells[r], widths[r] = {}, {}
        for c, cell in ipairs(p.row) do
            cells[r][c] = cellOf(cell)
            widths[r][c] = cells[r][c].w
        end
    end
    local xs, total = TG.Columns(widths, TG.GAP)
    for r, p in ipairs(pending) do
        for c, cl in ipairs(cells[r]) do
            for _, part in ipairs(cl.parts) do place(tip, part, p.line, xs[c]) end
        end
    end
    pending = {}
    if tip.SetMinimumWidth then
        tip:SetMinimumWidth(math.ceil(total))
        widened = tip
        tip:Show()
    end
end

--- What the last paint drew: { { text, x, line, mono }, ... } in row then column order.
--- @return table
function TG.Painted() return painted end
