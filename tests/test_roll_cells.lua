-- tests/test_roll_cells.lua — modules/RollCells.lua, what a group-loot roll table says (Forever
-- port design §5.3, plan DW-FP15): the open summary's counts, the won summary, the rows' order
-- (winner, numbers high to low, chosen without a number, waiting, pass), win protection, the time
-- left and the grid a box flows its rows into. Pure, and rolls are a both-clients feature, so every
-- case runs on both kit profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function RC() return T.newAddon().RollCells end

local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function r(name, state, roll, isWinner, classFile)
    return { name = name, guid = "Player-" .. name, classFile = classFile or "WARRIOR", state = state, roll = roll,
        isWinner = isWinner == true }
end

-- Three Need, two Greed, one Pass and four waiting: an open roll.
local function openRoll()
    return { link = "x", startTime = 100, duration = 60, allPassed = false, isTied = false,
        leader = { name = "Brakk", classFile = "WARRIOR", roll = 87 },
        rolls = { r("Brakk", 0, 87), r("Lyra", 0), r("Seta", 0, 12), r("Dorn", 3), r("Ira", 3, 40), r("Pell", 5),
            r("A", 4), r("B", 4), r("C", 4), r("D", 4) } }
end

local function names(rows)
    local out = {}
    for i, e in ipairs(rows) do out[i] = e.name end
    return table.concat(out, ",")
end

test("roll cells: summary counts Need 3 · Greed 2 · Pass 1 · waiting 4", function()
    local C = RC()
    local s = C.Summary(openRoll(), 110)
    assertEqual(s.text, "Need 3 · Greed 2 · Pass 1 · waiting 4")
    assertEqual(s.tone, "plain")
    assertEqual(s.tip[1], "Rolling now")
    local tip = plain(T.tipPlainJoined(s.tip))
    assertTrue(tip:find("Brakk (87)", 1, true) ~= nil, "the leader and their number")
    assertTrue(tip:find("0:50", 1, true) ~= nil, "the time left")
    -- An off-spec Need and a Transmog are their own words, in the state order.
    local o = openRoll()
    o.rolls[2].state, o.rolls[4].state = 1, 2
    assertEqual(C.Summary(o, 110).text, "Need 2 · Need (off-spec) 1 · Transmog 1 · Greed 1 · Pass 1 · waiting 4")
    -- Nobody listed yet, everyone passed, and the time run out.
    assertEqual(C.Summary({ rolls = {} }, 110).text, "no one has chosen yet")
    assertEqual(C.Summary({ rolls = { r("Pell", 5) }, allPassed = true }, 110).text, "Everyone passed")
    assertEqual(C.Summary(openRoll(), 200).text, "Roll ended", "past startTime + duration")
    assertEqual(C.Summary(openRoll(), 110, "expired").text, "Roll ended", "the store says it ended")
    assertEqual(C.Summary(nil).text, "Roll ended", "no table read")
end)

test("roll cells: won reads Won by Name (Need 87)", function()
    local C = RC()
    local won = openRoll()
    won.winner = { name = "Brakk", guid = "Player-Brakk", classFile = "WARRIOR", roll = 87 }
    won.rolls[1].isWinner = true
    local s = C.Summary(won, 110)
    assertEqual(plain(s.text), "Won by Brakk (Need 87)")
    assertTrue(s.text:find("|c", 1, true) ~= nil, "the name in its class color")
    assertEqual(s.tone, "good")
    -- A Greed win names Greed; a winner with no number on its own row still reads the row's.
    local greed = { winner = { name = "Ira", classFile = "MAGE" }, rolls = { r("Ira", 3, 40, true, "MAGE"), r("Pell", 5) } }
    assertEqual(plain(C.Summary(greed).text), "Won by Ira (Greed 40)")
    assertNil(C.Timer(won, 110), "no time left once won")
end)

test("roll cells: rows sort winner first, then numbers high to low, waiting, pass", function()
    local C = RC()
    local won = openRoll()
    won.rolls[3].isWinner, won.winner = true, { name = "Seta", classFile = "PRIEST", roll = 12 }
    local rows = C.Rows(won)
    assertEqual(names(rows), "Seta,Brakk,Ira,Lyra,Dorn,A,B,C,D,Pell")
    assertTrue(rows[1].winner); assertFalse(rows[2].winner)
    assertEqual(rows[1].word, "Need"); assertEqual(rows[1].roll, 12)
    assertEqual(rows[3].word, "Greed"); assertEqual(rows[3].tone, "yellow")
    assertEqual(rows[6].word, "waiting"); assertNil(rows[6].glyph, "waiting has no glyph")
    assertEqual(rows[10].word, "Pass")
    assertTrue(rows[1].glyph:find("Dice", 1, true) ~= nil)
    assertTrue(rows[3].glyph:find("Coin", 1, true) ~= nil)
    assertTrue(rows[10].glyph:find("Pass", 1, true) ~= nil)
    -- A secret name the reader dropped reads `?`, and the row stays (Review Focus 2).
    local rows2 = C.Rows({ rolls = { { state = 0, roll = 50 }, r("Lyra", 4) } })
    assertEqual(names(rows2), "?,Lyra")
    assertEqual(#C.Rows(nil), 0)
end)

test("roll cells: a higher roll that did not win is protected", function()
    local C = RC()
    local won = openRoll()
    won.rolls[3].isWinner, won.winner = true, { name = "Seta", classFile = "PRIEST", roll = 12 }
    local rows = C.Rows(won)
    assertTrue(rows[2].protected, "Brakk's 87 over the winner's 12")
    assertTrue(rows[3].protected, "Ira's 40 too")
    assertFalse(rows[1].protected, "the winner is not")
    assertFalse(rows[4].protected, "a choice with no number is not")
    assertTrue(T.tipPlainJoined(C.RowTip(rows[2])):find("protected", 1, true) ~= nil)
    -- While open, nothing is protected: the leader is only leading.
    for _, e in ipairs(C.Rows(openRoll())) do assertFalse(e.protected, e.name) end
end)

test("roll cells: the timer reads the time left on the history's clock, and the grid flows rows", function()
    local C = RC()
    assertEqual(C.Timer(openRoll(), 100), "1:00")
    assertEqual(C.Timer(openRoll(), 118), "0:42")
    assertEqual(C.Timer(openRoll(), 999), "0:00")
    assertNil(C.Timer(openRoll(), nil), "no clock read")
    assertNil(C.Timer({ rolls = {} }, 100), "no times")
    -- 40 rows at 180 px: four columns of ten in 760 px, one column with a last `and n more` slot in 200.
    local cols, lines, shown = C.Grid(40, 760, 180, 10)
    assertEqual(cols, 4); assertEqual(lines, 10); assertEqual(shown, 40)
    cols, lines, shown = C.Grid(40, 200, 180, 10)
    assertEqual(cols, 1); assertEqual(lines, 10); assertEqual(shown, 9)
    cols, lines, shown = C.Grid(3, 760, 180, 10)
    assertEqual(cols, 3); assertEqual(lines, 1, "a short table takes one line"); assertEqual(shown, 3)
    cols, lines, shown = C.Grid(0, 760, 180, 10)
    assertEqual(cols, 1); assertEqual(lines, 0); assertEqual(shown, 0)
end)
