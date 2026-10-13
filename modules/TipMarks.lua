local _, NS = ...
-- modules/TipMarks.lua — what a tooltip may draw where a table cell draws a verdict glyph
-- (feedback-6 spec §3, DW-F3). The tooltip's face has no `▲`, `▽`, `≈` or `⊘`: it draws them as
-- boxes. So a verdict mark in a tooltip is an inline texture escape (`|T…|t`) of a LibKa0s media
-- icon, tinted through the escape's own color fields: `arrow-up` green for an upgrade, `transfer`
-- yellow for a sidegrade, `arrow-down` red for a downgrade. Table cells and compact lines keep the
-- monospace glyphs (NS.WindowCells.GLYPH), which render.
--
-- A NON-WRAPPING LINE. A tooltip line is a string (it wraps at the tooltip's width) or
-- `{ text, wrap = false }`, which does not wrap, so the tooltip grows to fit it
-- (modules/Window.lua's showTooltip reads both). TM.Text answers either as its string.
--
-- THE COLORS. TM.ClassName and TM.ItemName put a name in its class or quality color, read at call
-- time from the client's tables (NS.Compat.ClassColor; ITEM_QUALITY_COLORS, else the link's own
-- color); plain when neither is known. Otherwise nothing here reads a module's state or a saved
-- variable, so test_tip_marks pins every escape string.

NS.TipMarks = NS.TipMarks or {}
local TM = NS.TipMarks
local C  = NS.Constants

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

--- A tooltip line that does not wrap: the tooltip grows to fit it.
--- @param text string
--- @return table { text, wrap = false }
function TM.NoWrap(text) return { text = text, wrap = false } end

--- A tooltip line's text, whether it is a string or a TM.NoWrap table.
--- @param line string|table
--- @return string
function TM.Text(line)
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
