local _, NS = ...
-- modules/CharFilter.lua — the Character dropdown (feedback-2 spec §4, FB2-6), like Ka0s Loot
-- History's (../LootHistory/modules/BrowserWidgets.lua, charOptions): who saw each drop (its
-- recorder), the menu's rows and label, and the predicate the filter bar applies.
--
-- THE RECORDER. Every drop record (modules/LootFeed.lua: a live receipt and a test placeholder) is
-- stamped with the character that saw it, `seenBy` (Name-Realm) and `seenByClass` (classFile), and
-- each History entry keeps both (modules/History.lua's Snapshot). A History entry recorded before
-- the recorder existed has none: it is "unknown", which only All shows.
--
-- THE SELECTION is a set of recorder keys (empty is All), multi-select like Loot History's. The
-- menu reads `Character: All`, `Character: Current` (a preset: it selects exactly you), then each
-- character Drop Watcher has a record for, in its class color with its class icon. The label reads
-- `Character: Current` while the selection is exactly you, the one character's row when one other
-- is chosen, else `Character: n selected`. The default is Current. CURRENT is the sentinel a
-- selection holds for "you" before your name is known (early in the login); Canonical swaps it for
-- your key once it is.
--
-- THE TABS. History is account-wide, so its menu lists every recorder in the log and its filter
-- hides the others' drops. Drops holds this session's drops, which are only ever yours: its menu
-- lists you alone beside All and Current, and every drop on it counts as yours (`session` scope), so
-- its filter never hides one.
--
-- PURE: Key, IconMarkup, Canonical, Passes, IsCurrent, Label, Characters and Options take plain
-- tables and read nothing else; test_char_filter drives them. Recorder, CurrentKey and Stamp are the
-- edge: they read NS.Compat (the player's live name, realm and class) at call time.

NS.CharFilter = NS.CharFilter or {}
local CF = NS.CharFilter
local L  = NS.L

-- The sentinel for "you" in a selection, and the Current row's value (a preset, never selected).
CF.CURRENT = "current"
CF.ALL = "all"

-- The class icon's size in the menu, Loot History's.
CF.ICON_SIZE = 14

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function plain(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

--- A recorder key, `Name-Realm`, or nil without a name. A name that carries its realm is kept.
--- @param name string|nil
--- @param realm string|nil
--- @return string|nil
function CF.Key(name, realm)
    name = plain(name)
    if not name then return nil end
    if name:find("-", 1, true) then return name end
    realm = plain(realm)
    return realm and (name .. "-" .. realm) or name
end

--- A class's icon as inline atlas markup (`classicon-<class>`), "" with no class. A string the
--- client draws; no call is made.
--- @param classFile string|nil
--- @return string
function CF.IconMarkup(classFile)
    classFile = plain(classFile)
    if not classFile then return "" end
    return ("|A:classicon-%s:%d:%d|a"):format(classFile:lower(), CF.ICON_SIZE, CF.ICON_SIZE)
end

--- A selection with the CURRENT sentinel swapped for your key, when it is known: a fresh set.
--- @param set table|nil
--- @param current string|nil your key
--- @return table
function CF.Canonical(set, current)
    local out = {}
    for k, on in pairs(type(set) == "table" and set or {}) do
        if on then out[(k == CF.CURRENT and current) or k] = true end
    end
    return out
end

local function isYou(key, current)
    return key == CF.CURRENT or (current ~= nil and key == current)
end

--- Whether a drop seen by `seenBy` passes a selection: always under All (the empty set); a drop
--- with no recorder never otherwise. `seenBy` CURRENT is a drop that is yours by definition (a
--- session tab's): it passes a selection that holds you.
--- @param seenBy string|nil the drop's recorder key
--- @param set table|nil the selection
--- @param current string|nil your key
--- @return boolean
function CF.Passes(seenBy, set, current)
    if type(set) ~= "table" or next(set) == nil then return true end
    if type(seenBy) ~= "string" then return false end
    if set[seenBy] then return true end
    if not isYou(seenBy, current) then return false end
    return set[CF.CURRENT] == true or (current ~= nil and set[current] == true)
end

--- Whether a selection is exactly you (the Current row lights, and the label reads Current).
--- @param set table|nil
--- @param current string|nil
--- @return boolean
function CF.IsCurrent(set, current)
    local n, you = 0, false
    for k, on in pairs(type(set) == "table" and set or {}) do
        if on then
            n = n + 1
            you = isYou(k, current)
        end
    end
    return n == 1 and you
end

--- The collapsed label for a selection: `Character: All`, `Character: Current`, `Character: <one>`
--- or `Character: n selected` (a hidden drop's reason in a group header's tooltip says it so).
--- @param set table|nil
--- @param current string|nil
--- @return string
function CF.Label(set, current)
    if CF.IsCurrent(set, current) then return L["Character: Current"] end
    local n, only = 0, nil
    for k, on in pairs(type(set) == "table" and set or {}) do
        if on then n, only = n + 1, k end
    end
    if n == 0 then return L["Character: All"] end
    if n == 1 then return L["Character: %s"]:format(only) end
    return L["Character: %d selected"]:format(n)
end

local function noteChar(out, seen, key, class)
    if not key then return end
    local have = seen[key]
    if have then
        have.class = have.class or class
        return
    end
    have = { key = key, class = class }
    seen[key] = have
    out[#out + 1] = have
end

--- The characters a log has a record for: each History entry's recorder once, you always (first in
--- the scan, so your class is known even with no entry of yours), sorted by name. An entry with no
--- recorder lists nobody.
--- @param groups table|nil History groups ({ drops = { entry } })
--- @param current string|nil your key
--- @param currentClass string|nil your classFile
--- @return table { { key, class }, ... }
function CF.Characters(groups, current, currentClass)
    local out, seen = {}, {}
    noteChar(out, seen, current, currentClass)
    for _, g in ipairs(type(groups) == "table" and groups or {}) do
        for _, e in ipairs(type(g) == "table" and type(g.drops) == "table" and g.drops or {}) do
            noteChar(out, seen, plain(e.seenBy), plain(e.seenByClass))
        end
    end
    table.sort(out, function(a, b) return a.key:lower() < b.key:lower() end)
    return out
end

--- The menu's rows: `Character: All`, `Character: Current` (lit while the selection is exactly
--- you), then each character with its class icon, in its class color.
--- @param chars table CF.Characters'
--- @param current string|nil
--- @param colorOf function|nil classFile -> r, g, b
--- @return table rows { value, label, color?, isActive? }
function CF.Options(chars, current, colorOf)
    local out = {
        { value = CF.ALL, label = L["Character: All"] },
        { value = CF.CURRENT, label = L["Character: Current"],
          isActive = function(dd) return CF.IsCurrent(dd._selected, current) end },
    }
    for _, c in ipairs(type(chars) == "table" and chars or {}) do
        local icon = CF.IconMarkup(c.class)
        local row = { value = c.key, label = icon ~= "" and (icon .. " " .. c.key) or c.key }
        if c.class and type(colorOf) == "function" then
            local r, g, b = colorOf(c.class)
            if r then row.color = { r, g, b } end
        end
        out[#out + 1] = row
    end
    return out
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local cached   -- { key, class } once your name and realm are known; a character's never change

--- You, as a recorder: { key = Name-Realm, class = classFile }, or nil while the client does not
--- know your name or realm yet (early in the login). Read live (the simulator never answers for
--- "player"), and kept once known.
--- @return table|nil
function CF.Recorder()
    if cached then return cached end
    local Compat = NS.Compat
    local name = plain(Compat.UnitName("player"))
    local realm = Compat.NormalizedRealm()
    if not (name and realm) then return nil end
    local _, classFile = Compat.UnitClass("player")
    cached = { key = CF.Key(name, realm), class = plain(classFile) }
    return cached
end

--- Your recorder key, or nil while it is not known.
--- @return string|nil
function CF.CurrentKey()
    local me = CF.Recorder()
    return me and me.key
end

--- Stamp a drop record with its recorder (you), unless it already has one.
--- @param rec table
--- @return table rec
function CF.Stamp(rec)
    if rec.seenBy then return rec end
    local me = CF.Recorder()
    if me then rec.seenBy, rec.seenByClass = me.key, me.class end
    return rec
end
