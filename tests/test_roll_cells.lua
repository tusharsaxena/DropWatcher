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

-- The count line as the player reads it: each icon as its texture's name (T.marks), color codes out.
local DICE, COIN, DE, PASS, WAIT = "[UI-GroupLoot-Dice-Up]", "[UI-GroupLoot-Coin-Up]", "[UI-GroupLoot-DE-Up]",
    "[UI-GroupLoot-Pass-Up]", "[clock]"
local function seen(s) return plain(T.marks(s)) end

test("roll cells: the count line is an icon and a count per choice", function()
    -- RX-06 (rolls UX design §3.2, rulings 1 and 2): Need (dice), Greed (coin), Pass, still to roll
    -- (the declared LibKa0s `clock` icon: CLAUDE.md's `LibKa0s icons:` line ships no hourglass), each
    -- with its count, the choices with none left out.
    -- red under: the word summary `Need 3 · Greed 2 · Pass 1 · waiting 4`
    local C = RC()
    local s = C.Summary(openRoll(), 110)
    assertEqual(seen(s.text), DICE .. " 3  " .. COIN .. " 2  " .. PASS .. " 1  " .. WAIT .. " 4")
    assertEqual(s.text, C.CountLine(openRoll()), "the summary of an open roll is the count line")
    assertEqual(s.tone, "plain")
    -- An off-spec Need counts as a Need, a Transmog as a Greed: the icons the popup's buttons draw.
    local o = openRoll()
    o.rolls[2].state, o.rolls[4].state = 1, 2
    assertEqual(seen(C.CountLine(o)), DICE .. " 3  " .. COIN .. " 2  " .. PASS .. " 1  " .. WAIT .. " 4")
    -- Only what someone chose: everyone still to roll, and a table with nobody on it.
    local fresh = { rolls = { r("A", 4), r("B", 4), { name = "C" } } }
    assertEqual(seen(C.CountLine(fresh)), WAIT .. " 3", "a row with no state is still to roll")
    local counts = C.Counts(openRoll())
    assertEqual(counts.need, 3); assertEqual(counts.greed, 2); assertEqual(counts.pass, 1)
    assertEqual(counts.waiting, 4); assertNil(counts.disenchant)
    assertEqual(C.CountLine({ rolls = {} }), "")
    assertEqual(C.CountLine(nil), "")
    assertEqual(C.Summary({ rolls = {} }, 110).text, "no one has chosen yet")
    -- The still-to-roll icon is one this addon ships; with the media library absent it is the word.
    local fh = io.open("libs/LibKa0s/media/icons/" .. C.WAITING_ICON .. ".tga", "rb")
    assertTrue(fh ~= nil, "the icon ships under libs/LibKa0s/media/icons/")
    if fh then fh:close() end
    local NS = T.newAddon()
    NS.Icon = function() return nil end
    assertEqual(plain(NS.RollCells.CountLine(fresh)), "Waiting 3")
    -- Everyone passed, and the time run out.
    assertEqual(C.Summary({ rolls = { r("Pell", 5) }, allPassed = true }, 110).text, "Everyone passed")
    assertEqual(C.Summary(openRoll(), 200).text, "Roll ended", "past startTime + duration")
    assertEqual(C.Summary(openRoll(), 110, "expired").text, "Roll ended", "the store says it ended")
    assertEqual(C.Summary(nil).text, "Roll ended", "no table read")
    -- A resolved roll's summary carries the count line beside its result (the Rolls box draws both).
    local won = openRoll()
    won.winner = { name = "Brakk", classFile = "WARRIOR", roll = 87 }
    won.rolls[1].isWinner = true
    assertEqual(C.Summary(won, 110).counts, C.CountLine(won))
end)

test("roll cells: Disenchant counts on Retail only", function()
    -- RX-06 (rolls UX design §3.2, clients-§4): a Disenchant choice is its own icon on Retail; WoW
    -- Forever never draws the icon nor says the word, and counts the choice under Greed.
    -- red under: no Disenchant group
    local C = RC()
    local roll = { rolls = { r("Brakk", 0), r("Lyra", C.DISENCHANT), r("Seta", 3), r("Dorn", 4) } }
    local text, tip = seen(C.CountLine(roll)), plain(T.tipPlainJoined(C.Tooltip(roll)))
    if T.forever then
        assertEqual(text, DICE .. " 1  " .. COIN .. " 2  " .. WAIT .. " 1", "Forever: Greed holds it")
        assertTrue(text:find(DE, 1, true) == nil and tip:find("Disenchant", 1, true) == nil, tip)
        assertNil(C.Counts(roll).disenchant)
    else
        assertEqual(text, DICE .. " 1  " .. COIN .. " 1  " .. DE .. " 1  " .. WAIT .. " 1")
        assertTrue(tip:find("Disenchant (1): Lyra", 1, true) ~= nil, tip)
    end
end)

test("roll cells: the tooltip lists every roll by choice, highest first, then waiting, then the verdict", function()
    -- RX-06 (rolls UX design §3.2): the item's name, then a row per choice, Need, Greed, Pass, each
    -- highest roll first, then the players still to roll; class colors, [YOU] on yours, an
    -- off-spec Need and the winner said, the verdict at the foot.
    -- red under: the summary's old tooltip (leader, players)
    local C = RC()
    local roll = openRoll()
    roll.link = "|cffa335ee|Hitem:300::|h[Band of Embers]|h|r"
    roll.rolls[7].isSelf = true      -- A, still to roll
    roll.rolls[2].state = 1          -- Lyra's Need is off-spec
    local tip = C.Tooltip(roll, { verdict = { text = "+20", tone = "good" } })
    local lines = {}
    for i, l in ipairs(tip) do lines[i] = plain(T.marks(T.tipText(l))) end
    assertEqual(lines[1], "Band of Embers", "the item's name first")
    assertTrue(tip[1]:find("|cffa335ee", 1, true) ~= nil, "in its quality color")
    assertEqual(lines[2], "• " .. DICE .. " Need (3): Brakk 87, Seta 12, Lyra (off-spec)", "highest first")
    assertEqual(lines[3], "• " .. COIN .. " Greed (2): Ira 40, Dorn")
    assertEqual(lines[4], "• " .. PASS .. " Pass (1): Pell")
    assertEqual(lines[5], "• " .. WAIT .. " Waiting (4): A [YOU], B, C, D", "still to roll last, yours marked")
    assertEqual(lines[#lines], "• You: +20", "the verdict at the foot")
    assertTrue(tip[#tip]:find("|c", 1, true) ~= nil, "in its tone")
    assertTrue(tip[2]:find("|cff", 1, true) ~= nil, "names in their class color")
    -- No link and no verdict: the title is Rolls, and the foot is the last group.
    local bare = C.Tooltip({ rolls = { r("Brakk", 0, 50) } })
    assertEqual(plain(bare[1]), "Rolls")
    assertEqual(plain(T.marks(bare[#bare])), "• " .. DICE .. " Need (1): Brakk 50")
    -- The open roll's summary carries it, with the time left; a won roll's too, the winner said.
    local s = C.Summary(roll, 110, nil, nil, { verdict = { text = "+20", tone = "good" } })
    local st = plain(T.tipPlainJoined(s.tip))
    assertTrue(st:find("Band of Embers", 1, true) ~= nil and st:find("Time left: 0:50", 1, true) ~= nil, st)
    assertTrue(st:find("You: +20", 1, true) ~= nil, st)
    roll.winner = { name = "Seta", classFile = "WARRIOR", roll = 12 }
    roll.rolls[3].isWinner = true
    local wt = plain(T.tipPlainJoined(C.Summary(roll, 110).tip))
    assertTrue(wt:find("Brakk 87 (protected), Seta 12 (won it)", 1, true) ~= nil, wt)
end)

test("roll cells: a secret or unreadable name degrades its own tooltip row", function()
    -- RX-06 (rolls UX design §3.2): a name the reader could not read plain reads `?`, the class it
    -- names is not read, and the rest of the table stays.
    -- red under: a tooltip keyed on the name or printing it raw
    local C = RC()
    local roll = { rolls = { { name = T.secret("Brakk"), classFile = T.secret("WARRIOR"), state = 0, roll = 50 },
        { state = 3 }, r("Lyra", 0, 20) } }
    local tip = plain(T.tipPlainJoined(C.Tooltip(roll)))
    assertTrue(tip:find("Need (2): ? 50, Lyra 20", 1, true) ~= nil, "the readable name stays: " .. tip)
    assertTrue(tip:find("Greed (1): ?", 1, true) ~= nil, "a nameless row is still counted")
    assertEqual(seen(C.CountLine(roll)), DICE .. " 2  " .. COIN .. " 1")
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

test("roll cells: your claimed popup's roll reads the client's own timer", function()
    -- RX-02 (rolls UX design §3.4): a roll your popup claimed reads GetLootRollTimeLeft (through
    -- NS.Compat), not the history's startTime + duration; once the client reads no time it falls
    -- back to the history's.
    -- red under: RC.Timer ignoring the rollID
    local NS, _, m = T.newAddon()
    local C = NS.RollCells
    m.lootRolls[11] = { link = "x", timeLeft = 42000 }
    assertEqual(C.Timer(openRoll(), 100, 11), "0:42", "the client's 42 s, not the history's 1:00")
    assertEqual(C.Left(openRoll(), nil, 11), 42, "no history clock needed")
    m.lootRolls[11].timeLeft = 0
    assertEqual(C.Timer(openRoll(), 100, 11), "1:00", "no client time left: the history's")
    assertEqual(C.Timer(openRoll(), 100, 12), "1:00", "no such popup: the history's")
    local tipped = false
    m.lootRolls[11].timeLeft = 42000
    for _, line in ipairs(C.Summary(openRoll(), 100, nil, 11).tip) do
        if plain(line):find("0:42", 1, true) then tipped = true end
    end
    assertTrue(tipped, "the summary's tooltip reads the client's time left")
end)

test("roll cells: a time left in mismatched units reads no time, a normal one m:ss", function()
    -- RX-02 (rolls UX design §3.4, Review Focus 5): duration in milliseconds over a startTime in
    -- seconds (or the reverse) gives an implausible time left; it reads no time, never 2717:57,
    -- and never ends the roll.
    -- red under: no plausibility guard on the derived time left
    local C = RC()
    local ms = openRoll(); ms.duration = 120000
    assertNil(C.Timer(ms, 110), "duration in ms, startTime in s: no time")
    assertNil(C.Left(ms, 110))
    assertTrue(C.Summary(ms, 110).text ~= "Roll ended", "an implausible time never ends the roll")
    local startMs = openRoll(); startMs.startTime, startMs.duration = 100000, 120
    assertNil(C.Timer(startMs, 110), "startTime in ms, now in s: no time")
    local normal = openRoll(); normal.duration = 120
    assertEqual(C.Timer(normal, 110), "1:50", "a two-minute roll ten seconds in")
    normal.duration = 300
    assertEqual(C.Timer(normal, 100), "5:00", "five minutes is the most a roll can read")
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
