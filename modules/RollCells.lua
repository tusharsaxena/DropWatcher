local _, NS = ...
-- modules/RollCells.lua — what a group-loot roll table says (Forever port design §5.3, plan
-- DW-FP15): the one-line summary, one row per player, and the time left while it is open. The
-- Rolling now section (modules/WindowPending.lua, both layouts), the resolved drop's Rolls box
-- (modules/DetailCard.lua through NS.DetailCells.RollsBox) and the row tooltip's summary line
-- (modules/RowTooltip.lua) all read these, so the three never disagree.
--
-- PURE. Every composer takes the plain roll table NS.Compat.LootHistoryRolls answers
-- (core/CompatLoot.lua: { link, startTime, duration, allPassed, isTied, leader, winner, rolls =
-- { { name, guid, classFile, isSelf, state, roll, isWinner } } }) and the clock it is on
-- (NS.Compat.LootHistoryNow), and answers plain tables; NS.TipMarks and NS.Compat.ClassColor are
-- read at call time for a name's class color. A field the reader dropped (a secret name, a nil
-- roll) degrades its row, never the table (Review Focus 2): a nameless row reads `?`.
--
-- THE TIME LEFT (rolls UX design §3.4). A roll your own popup claimed (the pending item's
-- `rollID`) reads the client's timer, NS.Compat.LootRollTimeLeft, read at call time. Any other
-- roll derives it from startTime + duration on the history's clock, and only a plausible answer
-- (at most RC.MAX_LEFT seconds) is shown: a duration in milliseconds over a startTime in seconds
-- reads no time at all, never 2717:57, and never ends the roll.
--
-- THE STATES are Enum.EncounterLootDropRollState's plain numbers: 0 Need, 1 Need (off-spec),
-- 2 Transmog, 3 Greed, 4 waiting (not chosen yet), 5 Pass. Each row carries its word, a glyph (the
-- game's own roll button art, a texture both clients ship: dice for a Need, a coin for Greed and
-- Transmog, the cross for a Pass; none while waiting) and a tone. RC.DISENCHANT (6) is this file's
-- own key, not the enum's: the loot history has no Disenchant state, so a table that carries one
-- (none of today's readers do; docs/known-limitations.md) is counted as Disenchant on Retail and as
-- Greed on WoW Forever, which never says the word (clients-§4).
--
-- THE COUNT LINE (rolls UX design §3.2, rulings 1 and 2; RC.CountLine, RC.Counts) is the open
-- roll's summary and sits beside a resolved roll's result in the Rolls box: an icon and a count per
-- choice, in RC.GROUPS' order, Need (the dice; an off-spec Need too), Greed (the coin; a Transmog
-- too), Disenchant (Retail only), Pass, and still to roll (the LibKa0s `clock` icon, in the
-- muted tone), a choice nobody made left out. THE TOOLTIP (RC.Tooltip) lists every roll: the item's
-- name, each choice with its players highest roll first, those still to roll, the time left while
-- open, and your verdict at the foot. A name is shown only as the reader gave it plain (`?`
-- otherwise) and a class is read only when it is a plain string, so a secret degrades its row.
--
-- THE ORDER (design §5.3): the winner, then the numbered rolls high to low, then the choices with
-- no number yet, then waiting, then pass; a tie keeps the state order, then the name.
-- `isWinner` is the truth, never the highest number (R2 §4): once a drop is won, a row with a
-- higher number that did not win is Blizzard's win protection (the player already won a copy) and
-- is shown, marked `protected`.
--
--   cell = { text, tone, tip = { title, lines... } }
--   row  = { name, classFile, word, glyph, tone, roll, winner, protected, state, isSelf }

NS.RollCells = NS.RollCells or {}
local RC = NS.RollCells
local L  = NS.L

local floor = math.floor

RC.MAX_LEFT = 300   -- seconds: the longest time left a derived roll timer may read (5 min)

RC.NEED, RC.OFFSPEC, RC.TRANSMOG, RC.GREED, RC.WAITING, RC.PASS = 0, 1, 2, 3, 4, 5
RC.DISENCHANT = 6   -- this file's own key: the history's enum has no Disenchant state

-- Disenchant is a Retail choice (clients-§4): read once, at file load.
local RETAIL = NS.Compat.ClientKey() ~= "forever"

-- Each state's word.
RC.WORD = {
    [0] = L["Need"], [1] = L["Need (off-spec)"], [2] = L["Transmog"], [3] = L["Greed"],
    [4] = L["waiting"], [5] = L["Pass"], [6] = RETAIL and L["Disenchant"] or L["Greed"],
}

local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local COIN = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
local DE = "Interface\\Buttons\\UI-GroupLoot-DE-Up"
local CROSS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
RC.GLYPH = { [0] = DICE, [1] = DICE, [2] = COIN, [3] = COIN, [5] = CROSS, [6] = RETAIL and DE or COIN }

RC.TONE = { [0] = "good", [1] = "offspec", [2] = "cyan", [3] = "yellow", [4] = "muted", [5] = "muted",
    [6] = RETAIL and "cyan" or "yellow" }

-- The count line's and the tooltip's choices, in order: each with its word, the game's roll-button
-- art (`glyph`) or a LibKa0s icon (`icon`, tinted `tone`); GROUP_OF names the group each state
-- counts under.
RC.WAITING_ICON = "clock"   -- the declared LibKa0s icon (CLAUDE.md `LibKa0s icons:`)
RC.GROUPS = {
    { key = "need", word = L["Need"], glyph = DICE },
    { key = "greed", word = L["Greed"], glyph = COIN },
}
if RETAIL then RC.GROUPS[#RC.GROUPS + 1] = { key = "disenchant", word = L["Disenchant"], glyph = DE } end
RC.GROUPS[#RC.GROUPS + 1] = { key = "pass", word = L["Pass"], glyph = CROSS }
RC.GROUPS[#RC.GROUPS + 1] = { key = "waiting", word = L["Waiting"], icon = RC.WAITING_ICON, tone = "muted" }
local GROUP_OF = { [0] = "need", [1] = "need", [2] = "greed", [3] = "greed", [4] = "waiting", [5] = "pass",
    [6] = RETAIL and "disenchant" or "greed" }

-- Where a row sorts: the winner, numbered, chosen with no number, waiting, pass.
local RANK_WINNER, RANK_NUMBERED, RANK_CHOSEN, RANK_WAITING, RANK_PASS = 1, 2, 3, 4, 5

local function num(v) return type(v) == "number" and v or nil end

local function nameOf(r) return type(r.name) == "string" and r.name ~= "" and r.name or "?" end

-- A class read only when the reader gave it as a plain string (a secret one is never read).
local function classOf(r) return type(r.classFile) == "string" and r.classFile or nil end

local function row(label, value, tone) return NS.TipMarks.Row(label, value, tone) end

local function colored(name, classFile) return NS.TipMarks.ClassName(name, classFile) end

--- A glyph as an inline texture escape `size` pixels square, or "" for a state with none.
--- @param state number|nil
--- @param size number|nil (14 by default)
--- @return string
function RC.GlyphEscape(state, size)
    local tex = RC.GLYPH[state]
    if not tex then return "" end
    size = size or 14
    return ("|T%s:%d:%d|t"):format(tex, size, size)
end

-- The winner's row in `roll.rolls` (isWinner, else the one matching `roll.winner`), or nil.
local function winnerRow(roll)
    local w = roll.winner
    for _, r in ipairs(roll.rolls or {}) do
        if r.isWinner then return r end
    end
    if type(w) ~= "table" then return nil end
    for _, r in ipairs(roll.rolls or {}) do
        if (w.guid and r.guid == w.guid) or (w.name and r.name == w.name) then return r end
    end
    return nil
end

-- The winning number: the winner's own, else their row's.
local function winningRoll(roll)
    local w = type(roll.winner) == "table" and roll.winner or nil
    local wr = winnerRow(roll)
    return (w and num(w.roll)) or (wr and num(wr.roll)) or nil
end

local function rankOf(r)
    if r.isWinner then return RANK_WINNER end
    local s = num(r.state)
    if s == RC.PASS then return RANK_PASS end
    if s == RC.WAITING or s == nil then return RANK_WAITING end
    if num(r.roll) then return RANK_NUMBERED end
    return RANK_CHOSEN
end

local function before(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.rank == RANK_NUMBERED and a.roll ~= b.roll then return a.roll > b.roll end
    local sa, sb = a.state or 9, b.state or 9
    if sa ~= sb then return sa < sb end
    return a.name < b.name
end

--- One row per player, sorted (the winner, numbers high to low, chosen with no number, waiting,
--- pass): { name, classFile, word, glyph, tone, roll, winner, protected, state, isSelf }. `protected` marks a
--- higher roll than the winner's that did not win, once the drop is won (win protection).
--- @param roll table|nil the plain roll table
--- @return table[]
function RC.Rows(roll)
    local out = {}
    if type(roll) ~= "table" then return out end
    local won = roll.winner ~= nil or winnerRow(roll) ~= nil
    local top = won and winningRoll(roll) or nil
    for _, r in ipairs(roll.rolls or {}) do
        local s, n = num(r.state), num(r.roll)
        out[#out + 1] = {
            name = nameOf(r), classFile = classOf(r), state = s, roll = n, isSelf = r.isSelf == true,
            word = RC.WORD[s] or RC.WORD[RC.WAITING], glyph = RC.GLYPH[s], tone = RC.TONE[s] or "muted",
            winner = r.isWinner == true,
            protected = won and not r.isWinner and n ~= nil and top ~= nil and n > top or false,
            rank = rankOf(r),
        }
    end
    table.sort(out, before)
    for _, e in ipairs(out) do e.rank = nil end
    return out
end

--- The seconds left while the roll is open, or nil. Your claimed popup's roll (`rollID`) reads the
--- client's timer while it reads time left; otherwise startTime + duration on the history's clock,
--- nil with no times, `now` not read, or an implausible answer (over RC.MAX_LEFT: mismatched units).
--- @param roll table|nil
--- @param now number|nil NS.Compat.LootHistoryNow()
--- @param rollID number|nil the pending item's claimed popup id
--- @return number|nil
function RC.Left(roll, now, rollID)
    if type(roll) ~= "table" or roll.winner or roll.allPassed then return nil end
    local own = rollID ~= nil and NS.Compat.LootRollTimeLeft(rollID) or nil
    if own and own > 0 then return own end
    local start, dur = num(roll.startTime), num(roll.duration)
    if not (start and dur and num(now)) then return nil end
    local left = start + dur - now
    if left > RC.MAX_LEFT then return nil end
    return math.max(0, left)
end

--- The time left while the roll is open, `0:42`, or nil once it has a winner, everyone passed, or
--- the times are not known.
--- @param roll table|nil
--- @param now number|nil NS.Compat.LootHistoryNow()
--- @param rollID number|nil the pending item's claimed popup id (RC.Left)
--- @return string|nil
function RC.Timer(roll, now, rollID)
    local left = RC.Left(roll, now, rollID)
    if not left then return nil end
    left = floor(left + 0.5)
    return ("%d:%02d"):format(floor(left / 60), left % 60)
end

-- The group a row's state counts under: an unknown or missing state is still to roll.
local function groupOf(r) return GROUP_OF[num(r.state)] or "waiting" end

--- How many players made each choice: { need, greed, disenchant (Retail only), pass, waiting },
--- a choice nobody made absent. Empty for no table.
--- @param roll table|nil the plain roll table
--- @return table
function RC.Counts(roll)
    local n = {}
    if type(roll) ~= "table" then return n end
    for _, r in ipairs(roll.rolls or {}) do
        local g = groupOf(r)
        n[g] = (n[g] or 0) + 1
    end
    return n
end

-- One group's mark as an inline texture at the text's height: the game's art as it is, a LibKa0s
-- icon in its tone (its word when the library is absent).
local function markOf(g)
    if g.glyph then return ("|T%s:0:0|t"):format(g.glyph) end
    local path = NS.Icon(g.icon)
    if not path then return g.word end
    local t = NS.Constants.TONE[g.tone]
    return NS.TipMarks.Escape(path, t.r, t.g, t.b)
end

--- The count line: each choice's icon and how many made it, in RC.GROUPS' order, two spaces apart
--- (`[dice] 3  [coin] 2  [pass] 1  [clock] 4`); "" for a table with nobody on it.
--- @param roll table|nil the plain roll table
--- @return string
function RC.CountLine(roll)
    local n, parts = RC.Counts(roll), {}
    for _, g in ipairs(RC.GROUPS) do
        if n[g.key] then parts[#parts + 1] = ("%s %d"):format(markOf(g), n[g.key]) end
    end
    return table.concat(parts, "  ")
end

-- The roll's item name in its quality color, from the table's link; nil with none.
local function itemTitle(roll)
    local link = type(roll.link) == "string" and roll.link or nil
    local name = link and link:match("|h%[(.-)%]|h")
    if not name then return nil end
    return NS.TipMarks.ItemName(name, nil, link)
end

-- What a choice inside a group says the group's word does not (an off-spec Need, a Transmog).
local SHADE = { [1] = L["off-spec"], [2] = L["Transmog"] }

-- One player in a group's row: the name in class color, [YOU] on yours, the number, then in
-- brackets an off-spec or Transmog choice, won it, protected: `Brakk 87 (won it)`.
local function playerText(e)
    local text = colored(e.name, e.classFile)
    if e.isSelf then text = text .. " " .. NS.GroupRoster.Colored(L["[YOU]"], NS.Skin.Color("accent")) end
    if e.roll then text = ("%s %d"):format(text, e.roll) end
    local extra = {}
    if SHADE[e.state] then extra[#extra + 1] = SHADE[e.state] end
    if e.winner then extra[#extra + 1] = L["won it"] end
    if e.protected then extra[#extra + 1] = L["protected"] end
    if #extra > 0 then text = ("%s (%s)"):format(text, table.concat(extra, ", ")) end
    return text
end

-- A row's place within its group: the numbers high to low, then the rest by name.
local function highFirst(a, b)
    if (a.roll ~= nil) ~= (b.roll ~= nil) then return a.roll ~= nil end
    if a.roll and a.roll ~= b.roll then return a.roll > b.roll end
    return a.name < b.name
end

-- One group's row: `• [dice] Need (3): Brakk 87, Seta 12, Lyra`, highest roll first.
local function groupRow(g, list)
    table.sort(list, highFirst)
    local names = {}
    for i, e in ipairs(list) do names[i] = playerText(e) end
    return row(("%s %s"):format(markOf(g), L["%s (%d)"]:format(g.word, #list)), table.concat(names, ", "))
end

--- Every roll in a tooltip (rolls UX design §3.2): the item's name (`Rolls` with no link), then a
--- row per choice in RC.GROUPS' order, `• [dice] Need (3): Brakk 87, Seta 12, Lyra`, highest roll
--- first, those still to roll last; the time left while open, and your verdict (`opts.verdict`, a
--- cell { text, tone }) at the foot.
--- @param roll table|nil the plain roll table
--- @param opts table|nil { verdict, now, rollID }
--- @return table tip
function RC.Tooltip(roll, opts)
    opts = opts or {}
    roll = type(roll) == "table" and roll or {}
    local tip = { itemTitle(roll) or L["Rolls"] }
    local by = {}
    for _, e in ipairs(RC.Rows(roll)) do
        local g = groupOf(e)
        by[g] = by[g] or {}
        table.insert(by[g], e)
    end
    for _, g in ipairs(RC.GROUPS) do
        if by[g.key] then tip[#tip + 1] = groupRow(g, by[g.key]) end
    end
    if roll.isTied and not roll.winner then tip[#tip + 1] = row(L["Tied"], L["the highest rolls are equal"]) end
    local t = RC.Timer(roll, opts.now, opts.rollID)
    if t then tip[#tip + 1] = row(L["Time left"], t) end
    local v = type(opts.verdict) == "table" and opts.verdict or nil
    if v and v.text then tip[#tip + 1] = row(L["You"], v.text, v.tone) end
    return tip
end

-- The summary's tooltip: every roll, with the time left and the verdict.
local function summaryTip(roll, now, rollID, opts)
    return RC.Tooltip(roll, { now = now, rollID = rollID, verdict = type(opts) == "table" and opts.verdict or nil })
end

-- What a roll table says on one line, and its tone: won, everyone passed, ended, else the count line.
local function resultOf(roll, now, state, rollID, counts)
    local w = type(roll.winner) == "table" and roll.winner or nil
    if w then
        local wr = winnerRow(roll)
        local word = RC.WORD[wr and num(wr.state)] or RC.WORD[RC.NEED]
        local n = winningRoll(roll)
        local how = n and ("%s %d"):format(word, n) or word
        return L["Won by %s (%s)"]:format(colored(nameOf(w), classOf(w)), how), "good"
    end
    if roll.allPassed then return L["Everyone passed"], "muted" end
    local left = RC.Left(roll, now, rollID)
    if state == "expired" or (left ~= nil and left <= 0) then return L["Roll ended"], "muted" end
    return counts ~= "" and counts or L["no one has chosen yet"], "plain"
end

--- The roll table on one line: the count line while it is open (RC.CountLine; `no one has chosen
--- yet` with nobody on it), `Won by Name (Need 87)` once won (the name in its class color),
--- `Everyone passed`, or `Roll ended` when its time ran out (or `state` says so) with no winner read.
--- A cell over a table carries its count line as `counts` (the Rolls box draws it beside a result)
--- and every roll in its tooltip (RC.Tooltip, `opts.verdict` at the foot).
--- @param roll table|nil the plain roll table
--- @param now number|nil NS.Compat.LootHistoryNow() (for the time left)
--- @param state string|nil the pending item's state (`expired` reads Roll ended; a master-loot
--- item's `awaiting` reads awaiting master looter)
--- @param rollID number|nil the pending item's claimed popup id (RC.Left)
--- @param opts table|nil { verdict } (RC.Tooltip)
--- @return table cell { text, tone, tip, counts }
function RC.Summary(roll, now, state, rollID, opts)
    if state == "awaiting" then   -- a master-loot item (modules/PendingML.lua): no roll to read
        return { text = L["awaiting master looter"], tone = "muted",
            tip = { L["Master loot"], row(nil, L["awaiting master looter"]) } }
    end
    if type(roll) ~= "table" then
        return { text = L["Roll ended"], tone = "muted", tip = { L["Rolls"], row(nil, L["the roll is no longer read"]) } }
    end
    local cell = { tip = summaryTip(roll, now, rollID, opts), counts = RC.CountLine(roll) }
    cell.text, cell.tone = resultOf(roll, now, state, rollID, cell.counts)
    return cell
end

--- One row's tooltip: its name in class color, the choice, the number, and why a protected row
--- did not win.
--- @param r table a RC.Rows row
--- @return table tip
function RC.RowTip(r)
    local tip = { colored(r.name, r.classFile), row(L["Choice"], r.word, r.tone) }
    if r.roll then tip[#tip + 1] = row(L["Roll"], r.roll) end
    if r.winner then tip[#tip + 1] = row(L["Result"], L["won it"], "good") end
    if r.protected then
        tip[#tip + 1] = row(L["Result"], L["protected: already won a copy, so a lower roll took it"], "muted")
    end
    return tip
end

--- How many rows a box shows and how they flow: `n` rows into columns `colW` wide across `width`,
--- at most `maxLines` lines each, column by column. Answers the columns, the lines, and how many
--- rows are shown (the rest are counted on a last `and n more` line).
--- @param n number the rows
--- @param width number
--- @param colW number
--- @param maxLines number
--- @return number cols, number lines, number shown
function RC.Grid(n, width, colW, maxLines)
    n = math.max(0, floor(num(n) or 0))
    if n == 0 then return 1, 0, 0 end
    local cols = math.max(1, floor((num(width) or 0) / math.max(1, colW)))
    local lines = math.min(maxLines, math.ceil(n / cols))
    cols = math.min(cols, math.ceil(n / lines))
    local cap = cols * lines
    if n <= cap then return cols, lines, n end
    return cols, lines, cap - 1   -- the last slot says how many more
end
