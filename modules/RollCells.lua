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
-- THE STATES are Enum.EncounterLootDropRollState's plain numbers: 0 Need, 1 Need (off-spec),
-- 2 Transmog, 3 Greed, 4 waiting (not chosen yet), 5 Pass. Each row carries its word, a glyph (the
-- game's own roll button art, a texture both clients ship: dice for a Need, a coin for Greed and
-- Transmog, the cross for a Pass; none while waiting) and a tone.
--
-- THE ORDER (design §5.3): the winner, then the numbered rolls high to low, then the choices with
-- no number yet, then waiting, then pass; a tie keeps the state order, then the name.
-- `isWinner` is the truth, never the highest number (R2 §4): once a drop is won, a row with a
-- higher number that did not win is Blizzard's win protection (the player already won a copy) and
-- is shown, marked `protected`.
--
--   cell = { text, tone, tip = { title, lines... } }
--   row  = { name, classFile, word, glyph, tone, roll, winner, protected, state }

NS.RollCells = NS.RollCells or {}
local RC = NS.RollCells
local L  = NS.L

local floor = math.floor

RC.NEED, RC.OFFSPEC, RC.TRANSMOG, RC.GREED, RC.WAITING, RC.PASS = 0, 1, 2, 3, 4, 5

-- Each state's word, in the order the summary counts them.
RC.WORD = {
    [0] = L["Need"], [1] = L["Need (off-spec)"], [2] = L["Transmog"], [3] = L["Greed"],
    [4] = L["waiting"], [5] = L["Pass"],
}
local COUNT_ORDER = { 0, 1, 2, 3, 5, 4 }

local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local COIN = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
local CROSS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
RC.GLYPH = { [0] = DICE, [1] = DICE, [2] = COIN, [3] = COIN, [5] = CROSS }

RC.TONE = { [0] = "good", [1] = "offspec", [2] = "cyan", [3] = "yellow", [4] = "muted", [5] = "muted" }

-- Where a row sorts: the winner, numbered, chosen with no number, waiting, pass.
local RANK_WINNER, RANK_NUMBERED, RANK_CHOSEN, RANK_WAITING, RANK_PASS = 1, 2, 3, 4, 5

local function num(v) return type(v) == "number" and v or nil end

local function nameOf(r) return type(r.name) == "string" and r.name ~= "" and r.name or "?" end

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
--- pass): { name, classFile, word, glyph, tone, roll, winner, protected, state }. `protected` marks a
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
            name = nameOf(r), classFile = r.classFile, state = s, roll = n,
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

--- The seconds left while the roll is open on the history's clock, or nil (no times, or `now`
--- not read).
--- @param roll table|nil
--- @param now number|nil NS.Compat.LootHistoryNow()
--- @return number|nil
function RC.Left(roll, now)
    if type(roll) ~= "table" or roll.winner or roll.allPassed then return nil end
    local start, dur = num(roll.startTime), num(roll.duration)
    if not (start and dur and num(now)) then return nil end
    return math.max(0, start + dur - now)
end

--- The time left while the roll is open, `0:42`, or nil once it has a winner, everyone passed, or
--- the times are not known.
--- @param roll table|nil
--- @param now number|nil NS.Compat.LootHistoryNow()
--- @return string|nil
function RC.Timer(roll, now)
    local left = RC.Left(roll, now)
    if not left then return nil end
    left = floor(left + 0.5)
    return ("%d:%02d"):format(floor(left / 60), left % 60)
end

-- The open roll's counts, `Need 3 · Greed 2 · Pass 1 · waiting 4`, the states with none left out.
local function counts(roll)
    local n = {}
    for _, r in ipairs(roll.rolls or {}) do
        local s = num(r.state) or RC.WAITING
        n[s] = (n[s] or 0) + 1
    end
    local parts = {}
    for _, s in ipairs(COUNT_ORDER) do
        if n[s] then parts[#parts + 1] = ("%s %d"):format(RC.WORD[s], n[s]) end
    end
    return table.concat(parts, " · ")
end

-- The tooltip's rows over a table: the leader while open, the winner once won, and the count.
local function summaryTip(roll, title, now)
    local tip = { title }
    local leader = type(roll.leader) == "table" and roll.leader or nil
    if not roll.winner and leader then
        local n = num(leader.roll)
        tip[#tip + 1] = row(L["Leading"], n and ("%s (%d)"):format(colored(nameOf(leader), leader.classFile), n)
            or colored(nameOf(leader), leader.classFile))
    end
    if roll.isTied then tip[#tip + 1] = row(L["Tied"], L["the highest rolls are equal"]) end
    local t = RC.Timer(roll, now)
    if t then tip[#tip + 1] = row(L["Time left"], t) end
    tip[#tip + 1] = row(L["Players"], num(roll.count) or #(roll.rolls or {}))   -- a kept table's own tally
    return tip
end

--- The roll table on one line: `Need 3 · Greed 2 · Pass 1 · waiting 4` while it is open (nothing
--- chosen yet reads `waiting n`), `Won by Name (Need 87)` once won (the name in its class color),
--- `Everyone passed`, or `Roll ended` when its time ran out (or `state` says so) with no winner read.
--- @param roll table|nil the plain roll table
--- @param now number|nil NS.Compat.LootHistoryNow() (for the time left)
--- @param state string|nil the pending item's state (`expired` reads Roll ended)
--- @return table cell { text, tone, tip }
function RC.Summary(roll, now, state)
    if type(roll) ~= "table" then
        return { text = L["Roll ended"], tone = "muted", tip = { L["Rolls"], row(nil, L["the roll is no longer read"]) } }
    end
    local w = type(roll.winner) == "table" and roll.winner or nil
    if w then
        local wr = winnerRow(roll)
        local word = RC.WORD[wr and num(wr.state)] or RC.WORD[RC.NEED]
        local n = winningRoll(roll)
        local how = n and ("%s %d"):format(word, n) or word
        local name = colored(nameOf(w), w.classFile)
        return { text = L["Won by %s (%s)"]:format(name, how), tone = "good",
            tip = summaryTip(roll, L["Rolls"], now) }
    end
    if roll.allPassed then
        return { text = L["Everyone passed"], tone = "muted", tip = summaryTip(roll, L["Rolls"], now) }
    end
    local left = RC.Left(roll, now)
    if state == "expired" or (left ~= nil and left <= 0) then
        return { text = L["Roll ended"], tone = "muted", tip = summaryTip(roll, L["Rolls"], now) }
    end
    local text = counts(roll)
    if text == "" then text = L["no one has chosen yet"] end
    return { text = text, tone = "plain", tip = summaryTip(roll, L["Rolling now"], now) }
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
