local _, NS = ...
-- modules/RollsPanelRows.lua — what the Rolls panel says (rolls panel design §3.1 and §3.2, plan
-- RX-17): one block per watched roll, its header, its rows per player and its foot, and the side
-- of the window it docks on. modules/RollsPanel.lua is the frame edge that draws it.
--
-- PURE. Every composer takes a NS.Pending roll item (its `roll`, NS.Compat.LootHistoryRolls' plain
-- table; `me`, your verdict; `state`) and the loot history's clock, and answers plain tables.
-- NS.RollCells, NS.RollPopup, NS.TipMarks, NS.GroupRoster and NS.Skin are read at call time.
--
-- A BLOCK (design §3.2): the header (the item's name from its link, its quality, the time left by
-- RollCells' rules, RX-02, or `done` once the roll is over), the rows, a result line once resolved
-- (`Won by <name> (<choice> <roll>)`, `Everyone passed`, `Roll ended`) and the foot (your verdict:
-- RollPopup.Verdict, the side card's words, so a non-gear item reads its kind word in the neutral
-- tone). `open` says whether its rows show: every block in a dungeon; raid mode (RX-18) closes all
-- but one.
--
-- THE ROWS come from NS.RollCells.Grouped, so the panel orders a roll as the all-rolls tooltip does:
-- Need, Greed (a Transmog counts as Greed), Disenchant (Retail only, clients-§4), Pass, still to roll
-- (the hourglass, RX-13), highest roll first within each. A row is the choice's mark (the game's own
-- roll art for the player's state, the group's mark for a state with none), the name in its class
-- color (a name the reader could not read plainly is `?`, RollCells' rule, never keyed), `[YOU]` in
-- the skin's accent on yours, and the roll's number. `winner` marks the row the panel washes gold.
--
--   block = { id, link, name, quality, open, done, time, left, header = { text, tone },
--             rows = { { mark, text, roll, winner, isSelf, group } }, result = { text, tone } | nil,
--             foot = { text, tone } }

NS.RollsPanelRows = NS.RollsPanelRows or {}
local RPR = NS.RollsPanelRows
local L = NS.L

RPR.SIDES = { right = true, left = true }

local function num(v) return type(v) == "number" and v or nil end

-- The item's name from its link, or nil.
local function nameOf(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil
end

-- One player's row (a RollCells.Rows row in group `g`).
local function rowOf(r, g)
    local RC = NS.RollCells
    local mark = r.glyph and RC.GlyphEscape(r.state, 0) or RC.Mark(g)
    local text = NS.TipMarks.ClassName(r.name, r.classFile)
    if r.isSelf then text = text .. " " .. NS.GroupRoster.Colored(L["[YOU]"], NS.Skin.Color("accent")) end
    return { mark = mark, text = text, roll = r.roll, winner = r.winner == true, isSelf = r.isSelf == true, group = g.key }
end

--- Every row of a roll, grouped and ordered (NS.RollCells.Grouped), as the panel draws them.
--- @param roll table|nil the plain roll table
--- @return table[] { mark, text, roll, winner, isSelf, group }
function RPR.Rows(roll)
    local out = {}
    for _, e in ipairs(NS.RollCells.Grouped(roll)) do
        for _, r in ipairs(e.rows) do out[#out + 1] = rowOf(r, e.group) end
    end
    return out
end

--- The result line of a roll that is over: `Won by <name> (<choice> <roll>)` (RollCells.Summary's
--- words, in the good tone), `Everyone passed`, else `Roll ended`.
--- @param roll table|nil
--- @return table { text, tone }
function RPR.Result(roll)
    if type(roll) ~= "table" then return { text = L["Roll ended"], tone = "muted" } end
    local s = NS.RollCells.Summary(roll, nil, "expired")
    return { text = s.text, tone = s.tone }
end

--- Whether a pending item's roll is over: not open (won, everyone passed, expired), or `gone` (the
--- store closed it: a won roll leaves Pending at once).
--- @param item table
--- @param gone boolean|nil
--- @return boolean
function RPR.IsDone(item, gone)
    return gone == true or type(item) ~= "table" or item.state ~= "open"
end

--- One block of the panel (design §3.2) for pending item `item`.
--- @param item table a NS.Pending roll item
--- @param opts table|nil { now (NS.Compat.LootHistoryNow), gone (the store closed it), open (rows shown; true by default) }
--- @return table block
function RPR.Block(item, opts)
    opts = opts or {}
    local roll = type(item.roll) == "table" and item.roll or nil
    local done = RPR.IsDone(item, opts.gone)
    local verdict = NS.RollPopup.Verdict(item.me)
    local block = {
        id = item.id, link = item.link, name = nameOf(item.link) or L["Item"],
        quality = type(item.facts) == "table" and item.facts.quality or nil,
        open = opts.open ~= false, done = done, rows = RPR.Rows(roll),
        foot = { text = verdict.text, tone = verdict.tone },
    }
    if done then
        block.time, block.result = L["done"], RPR.Result(roll)
    elseif roll then
        block.left = NS.RollCells.Left(roll, opts.now, item.rollID)
        block.time = NS.RollCells.Timer(roll, opts.now, item.rollID)
    end
    return block
end

--- How full the countdown bar is: `left` over the longest time left this block has read (`total`),
--- 0 to 1; nil with no time read.
--- @param left number|nil
--- @param total number|nil
--- @return number|nil
function RPR.Fraction(left, total)
    left, total = num(left), num(total)
    if not (left and total and total > 0) then return nil end
    return math.max(0, math.min(1, left / total))
end

--- Which side of the window the panel docks on (design §3.1): the `want` side (`right` or
--- `left`) when it fits on the screen, else the other one. All in UIParent's units; unknown geometry
--- answers `want`.
--- @param want string|nil `right` (the default) or `left`
--- @param left number|nil the window's left edge
--- @param right number|nil its right edge
--- @param width number the panel's width
--- @param screen number|nil the screen's width
--- @param gap number between the window and the panel
--- @return string
function RPR.Side(want, left, right, width, screen, gap)
    want = RPR.SIDES[want] and want or "right"
    left, right, screen = num(left), num(right), num(screen)
    if not (left and right and screen and screen > 0) then return want end
    local fitsRight = right + gap + width <= screen
    local fitsLeft = left - gap - width >= 0
    if want == "right" then return (fitsRight or not fitsLeft) and "right" or "left" end
    return (fitsLeft or not fitsRight) and "left" or "right"
end
