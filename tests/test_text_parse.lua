-- tests/test_text_parse.lua — core/TextParse.lua, the pure text parsers behind core/Compat.lua's
-- tooltip and duration readers (DW-61): pattern building and the plural grammar, the duration
-- decoder (design spec §7.4) with its templates passed in, and the item level, upgrade track and
-- class list lines. Every localized string is an argument here; tests/test_compat.lua drives the
-- same parsers through the Compat members that read the client's GlobalStrings.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

local cached
local function TP()
    if not cached then cached = T.newAddon().TextParse end
    return cached
end

-- The enUS unit templates, as core/Compat.lua hands them over.
local EN_UNITS = {
    { template = "%d |4day:days;", seconds = 86400 },
    { template = "%d |4hour:hrs;", seconds = 3600 },
    { template = "%d min", seconds = 60 },
    { template = "%d sec", seconds = 1 },
}

test("textparse: the module is pure — it names no client global and reads no _G", function()
    local fh = assert(io.open(T.root .. "/core/TextParse.lua", "rb"))
    local code = fh:read("*a"):gsub("%-%-[^\r\n]*", ""); fh:close()
    -- red under: a parser that reads a GlobalString itself instead of taking it as an argument
    assertNil(code:find("_G"), "no _G read")
    for _, name in ipairs({ "C_%u", "Enum", "issecretvalue", "LOCALIZED_", "INT_SPELL_DURATION_%u+%f[^%w_\"]" }) do
        assertNil(code:find("[^%w_.\"]" .. name), "names " .. name)
    end
end)

test("textparse: EscapePattern makes every magic character literal", function()
    local s = "50% [a]+?^$().*-"
    assertTrue(s:find("^" .. TP().EscapePattern(s) .. "$") ~= nil)
end)

test("textparse: FormatToPattern captures %s and %d, positional forms included", function()
    local who, what = ("Seta receives loot: [Ring]."):match("^" .. TP().FormatToPattern("%s receives loot: %s.") .. "$")
    assertEqual(who, "Seta"); assertEqual(what, "[Ring]")
    local a, b = ("x 3 (y) 4"):match(TP().FormatToPattern("%1$s %2$d (y) %d"))
    assertEqual(a, "x"); assertEqual(b, "3")
end)

test("textparse: ExpandPlural spells out two- and three-form grammars, and leaves plain text alone", function()
    local two = TP().ExpandPlural("%d |4hour:hrs;")
    assertEqual(#two, 2); assertEqual(two[1], "%d hour"); assertEqual(two[2], "%d hrs")
    local three = TP().ExpandPlural("%d |4час:часа:часов;")
    assertEqual(#three, 3); assertEqual(three[3], "%d часов")
    local nested = TP().ExpandPlural("|4a:b; |4c:d;")
    assertEqual(#nested, 4); assertEqual(nested[4], "b d")
    local plain = TP().ExpandPlural("%d min")
    assertEqual(#plain, 1); assertEqual(plain[1], "%d min")
end)

test("textparse: DecodeDuration sums the terms it is given and refuses leftovers", function()
    local TextParse = TP()
    assertEqual(TextParse.DecodeDuration("1 hour 59 min", EN_UNITS, " "), 7140)
    assertEqual(TextParse.DecodeDuration("2 days", EN_UNITS), 172800, "a nil delimiter is a space")
    assertEqual(TextParse.DecodeDuration("  30 sec ", EN_UNITS, " "), 30, "surrounding space is trimmed")
    assertNil(TextParse.DecodeDuration("1 hour banana", EN_UNITS, " "))
    assertNil(TextParse.DecodeDuration("", EN_UNITS, " "))
    assertNil(TextParse.DecodeDuration("1 hour", {}, " "), "no units, no reading")
    local ru = { { template = "%d |4час:часа:часов;", seconds = 3600 }, { template = "%d мин.", seconds = 60 } }
    assertEqual(TextParse.DecodeDuration("1 час, 2 мин.", ru, ", "), 3720, "a multi-character delimiter")
end)

test("textparse: TradeTimeRemaining reads only the whole trade line", function()
    local fmt = "You may trade this item for %s."
    assertEqual(TP().TradeTimeRemaining("You may trade this item for 1 hour 59 min.", fmt, EN_UNITS, " "), 7140)
    assertNil(TP().TradeTimeRemaining("You may trade this item for 1 hour. extra", fmt, EN_UNITS, " "))
    assertNil(TP().TradeTimeRemaining("Binds when picked up", fmt, EN_UNITS, " "))
end)

test("textparse: ItemLevel and UpgradeLine read their lines and nothing else", function()
    assertEqual(TP().ItemLevel("Item Level 639", "Item Level %d"), 639)
    assertNil(TP().ItemLevel("Binds when picked up", "Item Level %d"))
    local up = TP().UpgradeLine("Upgrade Level: Hero 2/6", "Upgrade Level: %s %d/%d")
    assertEqual(up.trackString, "Hero"); assertEqual(up.currentLevel, 2); assertEqual(up.maxLevel, 6)
    assertEqual(up.source, "tooltip")
    assertNil(TP().UpgradeLine("Upgrade Level: Hero", "Upgrade Level: %s %d/%d"))
end)

test("textparse: ClassSet maps the listed names and asks for the map only on a match", function()
    local asked = 0
    local function byName() asked = asked + 1; return { Warrior = "WARRIOR", Paladin = "PALADIN" } end
    local set = TP().ClassSet("Classes: Warrior, Paladin, Nobody", "Classes: %s", ", ", byName)
    assertTrue(set.WARRIOR and set.PALADIN); assertEqual(asked, 1)
    -- red under: a parser that builds the class map for every tooltip line it is offered
    assertNil(TP().ClassSet("Item Level 639", "Classes: %s", nil, byName))
    assertEqual(asked, 1, "a foreign line never builds the map")
    assertNil(TP().ClassSet("Classes: Nobody", "Classes: %s", nil, byName), "no known class")
end)
