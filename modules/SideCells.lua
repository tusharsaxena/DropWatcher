local _, NS = ...
-- modules/SideCells.lua — the Me and Them cells of the drop tables (feedback-6 spec §1, DW-F1): what
-- you (or the looter) wear in the drop's slot and the verdict on the drop, in one cell where My eq,
-- Their eq, Me and Them were four columns:
--
--   [icon(s)] [item level] [glyph][difference]      321/308 ▽8 · 276 ▲12 · 311 ≈0 · 334 Can't use
--
-- THE GEAR PART is WindowCells.MyEq's or TheirEq's answer: the worn items (the icons are the
-- edge's; two for rings, trinkets and one-hand weapons) and their item levels (`321`, `321/308`) in
-- the plain tone, else a muted word: `empty` when nothing is worn there, or the state that keeps the
-- gear unread (`…`, `range`, `combat`, `!`, `–`).
-- THE VERDICT PART is WindowCells.Me's or Them's answer: the glyph and the absolute item-level
-- difference with no sign (the glyph says which way), both in the verdict's tone (green up, yellow
-- side, red down); `Can't use` and `Not wanted` stay words (gray). An unknown verdict's `?` is left
-- out when the gear part already says why (a state word), and shown when it does not. A dash in the
-- gear part goes when the verdict part has something to say.
-- YOUR OWN DROP'S THEM is MineCells.Multiple's `(Details)` (or `Hidden`), its tones and its tooltip.
-- History keeps no worn items, so its cells are the verdict part alone (SC.Merge with no gear).
--
-- THE TOOLTIP is the gear tooltip's lines (each worn item, the inspect's age for Them) followed by
-- the verdict's (its title, its explanation, the comparison and the reasons), a line the two share
-- said once.
--
-- PURE. Every composer takes the drop record and plain inputs and answers a plain table; nothing here
-- reads a module's state, the client or a saved variable. The full tables paint it
-- (modules/WindowGroup.lua, modules/WindowHistory.lua) and the compact cards' line 3 reads it
-- (modules/CompactCards.lua).
--
--   cell = { items, level, levelTone, glyph, text, tone, tip, verdict, upgrades, hidden }
--   (`level` nil with no gear part; `text` "" when the verdict part is left out)

NS.SideCells = NS.SideCells or {}
local SC = NS.SideCells
local L  = NS.L
local WC = NS.WindowCells
local MC = NS.MineCells

local DASH = "–"

-- The gear part's words that already say why a verdict is unknown.
local EXPLAINS = { ["…"] = true, [DASH] = true, ["!"] = true, [L["range"]] = true, [L["combat"]] = true }
SC.EXPLAINS = EXPLAINS

-- The gear part: the worn levels (plain), else the muted word; `empty slot` reads `empty`.
local function gearPart(eq)
    if type(eq) ~= "table" then return nil, nil end
    if type(eq.items) == "table" and #eq.items > 0 then return eq.text, "plain" end
    if eq.text == L["empty slot"] then return L["empty"], "muted" end
    return eq.text, "muted"
end

-- The verdict part: the glyph and the unsigned difference, a word, or "" for an unknown verdict
-- the gear part explains.
local function verdictPart(v, level)
    local text = v.text or ""
    if v.glyph then
        local n = text:match("^[%+%-]?(%d+)$")
        if n then return v.glyph, n end
        return v.glyph, level and "" or text   -- no difference (an empty slot): the gear part says so
    end
    if v.verdict == "unknown" and level and EXPLAINS[level] then return nil, "" end
    return nil, text
end

-- The gear tooltip's lines, then the verdict's; a line already said is not said twice.
local function mergedTip(eq, v)
    local out, seen = {}, {}
    local function add(lines)
        for _, l in ipairs(type(lines) == "table" and lines or {}) do
            if not seen[l] then
                seen[l] = true
                out[#out + 1] = l
            end
        end
    end
    if type(eq) == "table" then add(eq.tip) end
    add(v.tip)
    return out
end

--- One merged cell: a verdict cell (WindowCells.Me, Them or Verdict; MineCells.Multiple) after an
--- equipment cell (WindowCells.MyEq or TheirEq; nil for the verdict alone).
--- @param v table the verdict cell
--- @param eq table|nil the equipment cell
--- @return table cell
function SC.Merge(v, eq)
    local level, levelTone = gearPart(eq)
    local glyph, text = verdictPart(v, level)
    if level == DASH and (glyph or text ~= "") then level, levelTone = nil, nil end
    return { items = type(eq) == "table" and eq.items or {}, level = level, levelTone = levelTone,
        glyph = glyph, text = text, tone = v.tone, tip = mergedTip(eq, v), verdict = v.verdict,
        upgrades = v.upgrades, hidden = v.hidden }
end

--- The Me cell: what you wear in the drop's slot (your gear snapshot's) and the drop judged for you.
--- @param drop table
--- @param equipped table|nil the gear snapshot's `equipped`
--- @return table cell
function SC.Me(drop, equipped)
    return SC.Merge(WC.Me(drop), WC.MyEq(drop, equipped))
end

--- The Them cell: what the looter wears there (their inspect read's) and the drop judged for them;
--- on your own drop `(Details)` (MineCells.Multiple), every member it upgrades in the tooltip.
--- @param drop table
--- @param gear table|nil the looter's inspect gear
--- @param now number|nil GetTime()
--- @param revealed boolean|nil your own drop's Offer panel was opened this session
--- @return table cell
function SC.Them(drop, gear, now, revealed)
    if drop.isMine then return SC.Merge(MC.Multiple(drop, revealed, L["Them"])) end
    return SC.Merge(WC.Them(drop, now), WC.TheirEq(drop, gear, now))
end
