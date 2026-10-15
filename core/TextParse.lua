local _, NS = ...
-- core/TextParse.lua — the pure text parsers behind core/Compat.lua's tooltip and duration readers
-- (DW-61): Lua patterns from printf-style GlobalStrings, the `|4a:b;` plural grammar, the localized
-- duration decoder (design spec §7.4), the tooltip line scan and the item level, upgrade track and
-- class list lines.
--
-- PURE. Nothing here calls a client API or reads a global: every localized GlobalString arrives as
-- an argument, already read and secret-guarded by core/Compat.lua, which stays the only file that
-- touches the client (compat-§1). Every text argument is a plain string, except the raw tooltip
-- lines ScanLines walks, whose fields it reads only through the secret guards it is handed.

NS.TextParse = NS.TextParse or {}
local TextParse = NS.TextParse

-- ---------------------------------------------------------------------------------------------
-- Pattern building
-- ---------------------------------------------------------------------------------------------

--- `s` with every Lua pattern magic character escaped.
--- @param s string
--- @return string
function TextParse.EscapePattern(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

--- A Lua pattern from a printf-style GlobalString: `%s` captures text, `%d` captures digits, the
--- positional forms (`%1$s`) read as their plain spelling and every other character is literal.
--- The order a positional string gives its arguments is the caller's to recover
--- (modules/LootParser.lua does).
--- @param fmt string
--- @return string
function TextParse.FormatToPattern(fmt)
    local marked = fmt:gsub("%%%d+%$", "%%"):gsub("%%s", "\1"):gsub("%%d", "\2")
    return (TextParse.EscapePattern(marked):gsub("\1", "(.+)"):gsub("\2", "(%%d+)"))
end

--- Every spelling of a template's `|4singular:plural;` grammar (some locales carry three forms), as
--- a list of plain templates. A template without the grammar is its own one spelling.
--- @param template string
--- @return table
function TextParse.ExpandPlural(template)
    local head, forms, tail = template:match("^(.-)|4([^;]*);(.*)$")
    if not head then return { template } end
    local out = {}
    for form in (forms .. ":"):gmatch("([^:]*):") do
        for _, rest in ipairs(TextParse.ExpandPlural(tail)) do out[#out + 1] = head .. form .. rest end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The duration decoder (design spec §7.4)
-- ---------------------------------------------------------------------------------------------
--
-- The client writes a remaining time as unit terms joined by TIME_UNIT_DELIMITER, each term
-- formatted from INT_SPELL_DURATION_<UNIT> ("%d |4hour:hrs;", "%d min", "%d sec" in enUS). The
-- decoder reads the text back with the same templates, so it works in every client language: it
-- walks the text from the left, matching one unit term anchored at the cursor, then skipping one
-- delimiter. Splitting on the delimiter instead would break, because a term ("2 hrs") can contain
-- it. Written here from that idea; no other addon's code was copied.

--- The GlobalString each unit's template is read from (by core/Compat.lua), and its seconds.
TextParse.DURATION_UNITS = {
    { name = "INT_SPELL_DURATION_DAYS",  seconds = 86400 },
    { name = "INT_SPELL_DURATION_HOURS", seconds = 3600 },
    { name = "INT_SPELL_DURATION_MIN",   seconds = 60 },
    { name = "INT_SPELL_DURATION_SEC",   seconds = 1 },
}

-- Every unit term as an anchored pattern with its multiplier, longest spelling first so "hrs" is
-- tried before a "hr" that is its prefix.
local function durationTerms(units)
    local terms = {}
    for _, unit in ipairs(units) do
        for _, spelling in ipairs(TextParse.ExpandPlural(unit.template)) do
            terms[#terms + 1] = { spelling = spelling, seconds = unit.seconds,
                pattern = "^" .. TextParse.FormatToPattern(spelling) }
        end
    end
    table.sort(terms, function(a, b) return #a.spelling > #b.spelling end)
    return terms
end

-- One unit term at `pos`: the seconds it is worth and the position after it, or nil.
local function matchTerm(text, pos, terms)
    for _, term in ipairs(terms) do
        local s, e, n = text:find(term.pattern, pos)
        if s and n then return tonumber(n) * term.seconds, e + 1 end
    end
    return nil
end

--- Seconds in a localized duration ("1 hour 59 min"), or nil when the text is not one. Every term
--- must be a known unit; anything left over makes the whole text unreadable rather than a guess.
--- @param text string
--- @param units table  { { template = INT_SPELL_DURATION_<UNIT>, seconds = n }, ... }
--- @param delim string|nil  TIME_UNIT_DELIMITER (" " when nil)
--- @return number|nil
function TextParse.DecodeDuration(text, units, delim)
    text = text:match("^%s*(.-)%s*$")
    local terms = durationTerms(units)
    if text == "" or #terms == 0 then return nil end
    delim = delim or " "
    local total, pos = 0, 1
    while pos <= #text do
        local seconds, nextPos = matchTerm(text, pos, terms)
        if not seconds then return nil end
        total, pos = total + seconds, nextPos
        if text:sub(pos, pos + #delim - 1) == delim then pos = pos + #delim end
    end
    return total
end

--- Seconds left on a trade-time line (`fmt` is BIND_TRADE_TIME_REMAINING, its one `%s` the
--- duration), or nil when the text is not that whole line.
--- @return number|nil
function TextParse.TradeTimeRemaining(text, fmt, units, delim)
    local duration = text:match("^" .. TextParse.FormatToPattern(fmt) .. "$")
    return duration and TextParse.DecodeDuration(duration, units, delim) or nil
end

-- ---------------------------------------------------------------------------------------------
-- Tooltip lines
-- ---------------------------------------------------------------------------------------------

--- The item level an ITEM_LEVEL line ("Item Level %d") starts with, or nil.
--- @return number|nil
function TextParse.ItemLevel(text, fmt)
    return tonumber(text:match("^" .. TextParse.FormatToPattern(fmt)))
end

--- The value on a stat line written from `fmt` (ITEM_MOD_AGILITY's "%c%s Agility" in enUS, `%c`
--- the sign), whatever its sign and with its grouping marks dropped ("+1,689" reads 1689), or nil.
--- @return number|nil
function TextParse.StatLine(text, fmt)
    local pattern = TextParse.FormatToPattern((fmt:gsub("%%c", "\3"))):gsub("\3", "[%%+%%-]")
    local value = text:match("^" .. pattern .. "$")
    if not value then return nil end
    return tonumber((value:gsub("%D", "")))
end

--- The track name and ranks on an ITEM_UPGRADE_TOOLTIP_FORMAT_STRING line ("Upgrade Level: %s
--- %d/%d" in enUS), as `{ trackString, currentLevel, maxLevel, source = "tooltip" }`, or nil.
--- @return table|nil
function TextParse.UpgradeLine(text, fmt)
    local track, cur, max = text:match("^" .. TextParse.FormatToPattern(fmt) .. "$")
    if not (track and tonumber(cur) and tonumber(max)) then return nil end
    return { trackString = track, currentLevel = tonumber(cur), maxLevel = tonumber(max),
        source = "tooltip" }
end

--- The classes on an ITEM_CLASSES_ALLOWED line ("Classes: Warrior, Paladin"), as a set of
--- classFiles, or nil when the line is not that one or names no class `byName()` knows. `byName`
--- answers the localized name -> classFile map and is called only once the line matches.
--- @param delim string|nil  LIST_DELIMITER (", " when nil)
--- @param byName function
--- @return table|nil
function TextParse.ClassSet(text, fmt, delim, byName)
    local list = text:match("^" .. TextParse.FormatToPattern(fmt) .. "$")
    if not list then return nil end
    delim = delim or ", "
    local map, set = byName(), nil
    for name in (list .. delim):gmatch("(.-)" .. TextParse.EscapePattern(delim)) do
        local classFile = map[name]
        if classFile then
            set = set or {}
            set[classFile] = true
        end
    end
    return set
end

--- The first non-nil `parse(text, line)` answer over the tooltip `lines` whose type is `wanted`
--- (every line when nil). The lines are the client's, raw: `plainString` and `plainNumber`
--- (core/Compat.lua's secret guards) answer a field's plain value or nil, so no secret is compared.
--- @return any
function TextParse.ScanLines(lines, wanted, parse, plainString, plainNumber)
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            local text = plainString(line.leftText)
            if text and (wanted == nil or plainNumber(line.type) == wanted) then
                local value = parse(text, line)
                if value ~= nil then return value end
            end
        end
    end
    return nil
end
