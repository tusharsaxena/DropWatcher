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
-- tone). `open` says whether its rows show: every block in a dungeon; raid mode closes all but one.
--
-- RAID MODE (design §3.3, plan RX-18) is a group of more than RPR.RAID_OVER members (RPR.IsRaid, on
-- NS.Compat.GroupSize, or on the most players on one watched roll: RX-19, modules/RollsPanel.lua). One block is open (RPR.PickOpen: a header the player clicked while its roll
-- runs, else the roll you still have to roll on, else the one ending soonest); the rest are headers
-- with the count line (RollCells.CountLine) under the name, a resolved one dimmed with its result
-- (the winner and the roll) in the count line's place. With `rolls.panel.foldInRaid` on, Pass and
-- Waiting fold to one line each (RPR.FOLDS: `Pass 27 · P1, P2, P3…`, the first RPR.FOLD_NAMES names),
-- whose tooltip lists every name; a group the player unfolded lists a row per player again.
--
-- THE ROWS come from NS.RollCells.Grouped, so the panel orders a roll as the all-rolls tooltip does:
-- Need, Greed (a Transmog counts as Greed), Disenchant (Retail only, clients-§4), Pass, still to roll
-- (the hourglass, RX-13), highest roll first within each. A row is the choice's mark (the game's own
-- roll art for the player's state, the group's mark for a state with none), the name in its class
-- color (a name the reader could not read plainly is `?`, RollCells' rule, never keyed), `[YOU]` in
-- the skin's accent on yours, and the roll's number. `winner` marks the row the panel washes gold.
--
--   block = { id, link, name, quality, open, done, dim, time, left, counts,
--             rows = { { mark, text, roll, winner, isSelf, group, fold, tip } },
--             result = { text, tone } | nil, foot = { text, tone } }
--   (a folded group's row carries `fold`, its group's key, and `tip`, its tooltip's lines)

NS.RollsPanelRows = NS.RollsPanelRows or {}
local RPR = NS.RollsPanelRows
local L = NS.L

RPR.SIDES = { right = true, left = true }
RPR.RAID_OVER = 5                            -- a group past this many members is a raid (design §3.3)
RPR.FOLDS = { pass = true, waiting = true }  -- the groups a raid folds to one line
RPR.FOLD_NAMES = 3                           -- the names a folded line spells out
RPR.TIP_NAMES = 5                            -- the names per line of a folded group's tooltip

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

-- A folded group's tooltip: its word and count, then every name in class color, RPR.TIP_NAMES a
-- row (the tooltip row shape: a bulleted row with no label, then the closing hint).
local function foldTip(g, rows)
    local tip, line = { ("%s (%d)"):format(g.word, #rows) }, {}
    for i, r in ipairs(rows) do
        line[#line + 1] = NS.TipMarks.ClassName(r.name, r.classFile)
        if #line == RPR.TIP_NAMES or i == #rows then
            tip[#tip + 1] = NS.TipMarks.Row(nil, table.concat(line, ", "))
            line = {}
        end
    end
    tip[#tip + 1] = NS.TipMarks.Hint(L["Click to list every player"])
    return tip
end

--- A group folded to one line (design §3.3): `<mark> Pass 27 · P1, P2, P3…`, the first
--- RPR.FOLD_NAMES names plain, its tooltip's lines in `tip`.
--- @param g table a RollCells.GROUPS entry
--- @param rows table[] the group's RollCells.Rows rows
--- @return table { mark, text, fold, tip, group }
function RPR.Fold(g, rows)
    local names = {}
    for i = 1, math.min(#rows, RPR.FOLD_NAMES) do names[i] = rows[i].name end
    local more = #rows > RPR.FOLD_NAMES and "…" or ""
    return { mark = NS.RollCells.Mark(g), group = g.key, fold = g.key, tip = foldTip(g, rows),
        text = L["%s %d · %s"]:format(g.word, #rows, table.concat(names, ", ") .. more) }
end

--- Every row of a roll, grouped and ordered (NS.RollCells.Grouped), as the panel draws them; with
--- `fold` (raid mode, `rolls.panel.foldInRaid` on) Pass and Waiting are one RPR.Fold line each,
--- unless `unfolded[key]` (the player clicked that line).
--- @param roll table|nil the plain roll table
--- @param fold boolean|nil
--- @param unfolded table|nil { [group key] = true }
--- @return table[] { mark, text, roll, winner, isSelf, group, fold, tip }
function RPR.Rows(roll, fold, unfolded)
    local out = {}
    for _, e in ipairs(NS.RollCells.Grouped(roll)) do
        local key = e.group.key
        if fold and RPR.FOLDS[key] and not (unfolded and unfolded[key]) then
            out[#out + 1] = RPR.Fold(e.group, e.rows)
        else
            for _, r in ipairs(e.rows) do out[#out + 1] = rowOf(r, e.group) end
        end
    end
    return out
end

--- Whether a group of `size` members is a raid for the panel (design §3.3: more than five).
--- @param size number|nil NS.Compat.GroupSize()
--- @return boolean
function RPR.IsRaid(size)
    size = num(size)
    return size ~= nil and size > RPR.RAID_OVER
end

--- Whether you still have to roll on `roll`: your roll state is still to roll (the history's
--- playerRollState, else your own row's).
--- @param roll table|nil
--- @return boolean
function RPR.YoursPending(roll)
    if type(roll) ~= "table" then return false end
    local RC = NS.RollCells
    if num(roll.myState) then return roll.myState == RC.WAITING end
    for _, r in ipairs(roll.rolls or {}) do
        if r.isSelf then return num(r.state) == RC.WAITING end
    end
    return false
end

-- Whether candidate `a` opens before `b`: a known time left before none, the sooner first.
local function sooner(a, b)
    if b == nil then return true end
    local la, lb = num(a.left), num(b.left)
    if la and lb then return la < lb end
    return la ~= nil and lb == nil
end

--- Which block raid mode opens (design §3.3): `sticky` (the header the player clicked) while its
--- roll runs, else the roll you still have to roll on, else the one ending soonest (a known time
--- before none, the earlier start on a tie); nil when every roll is over.
--- @param list table[] the blocks in start order: { id, done, pending, left }
--- @param sticky any the clicked block's id, or nil
--- @return any the id to open, or nil
function RPR.PickOpen(list, sticky)
    local mine, soon
    for _, e in ipairs(list) do
        if not e.done then
            if e.id == sticky then return e.id end
            if e.pending and sooner(e, mine) then mine = e end
            if sooner(e, soon) then soon = e end
        end
    end
    local pick = mine or soon
    return pick and pick.id or nil
end

--- The panel's title: `Rolls`, or `Rolls · N` in raid mode (N blocks).
--- @param raid boolean
--- @param n number
--- @return string
function RPR.Title(raid, n)
    if raid then return L["Rolls · %d"]:format(n) end
    return L["Rolls"]
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
--- A closed block (raid mode) reads no rows: `rows` is empty, and `counts` holds the count line,
--- or the result's text once the roll is over (`dim`).
--- @param opts table|nil { now (NS.Compat.LootHistoryNow), gone (the store closed it), open (rows
---   shown; true by default), raid (raid mode), fold (fold Pass and Waiting), unfolded }
--- @return table block
function RPR.Block(item, opts)
    opts = opts or {}
    local roll = type(item.roll) == "table" and item.roll or nil
    local done = RPR.IsDone(item, opts.gone)
    local verdict = NS.RollPopup.Verdict(item.me)
    local open = opts.open ~= false
    local block = {
        id = item.id, link = item.link, name = nameOf(item.link) or L["Item"],
        quality = type(item.facts) == "table" and item.facts.quality or nil,
        open = open, done = done, rows = open and RPR.Rows(roll, opts.fold, opts.unfolded) or {},
        foot = { text = verdict.text, tone = verdict.tone },
    }
    if done then
        block.time, block.result = L["done"], RPR.Result(roll)
    elseif roll then
        block.left = NS.RollCells.Left(roll, opts.now, item.rollID)
        block.time = NS.RollCells.Timer(roll, opts.now, item.rollID)
    end
    if opts.raid and not open then
        block.dim = done
        block.counts = done and block.result.text or NS.RollCells.CountLine(roll)
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
