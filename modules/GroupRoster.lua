local _, NS = ...
-- modules/GroupRoster.lua — who was in the group for a run or an encounter (feedback-2 spec §3,
-- FB2-5): each feed group's roster snapshot, the History group's kept copy, and the one `Group: ...`
-- line a group header's tooltip shows, each name in its class color, you first.
--
--   roster = { { name, realm, class, me }, ... }
--
-- `name` is the short name, `realm` the normalized realm only when it differs from yours, `class`
-- the classFile and `me` true on your own entry. Two entries are the same character when their
-- names and realms match without case.
--
-- THE SNAPSHOT. A feed group takes the group's members when its first drop makes it (Note, from
-- modules/LootFeed.lua's add), and every later drop merges the members again, so someone who joined
-- mid-run is added. A roster change between drops grows the group a drop received now would join
-- (NS.LootFeed.OpenGroup) and the History group it is recorded under (NS.History.GrowRoster), and
-- the shown window repaints (NS.Window.ScheduleRepaint): the roster's change sink
-- (NS.Roster.AddChangeSink) runs Grow. A test drop takes its spec's roster
-- (modules/TestData.lua's samples) instead of the client's. A simulation's members come through
-- NS.Compat like a real group's, so its runs carry its drawn group.
--
-- THE HEADER. Since feedback-3 spec §4 (DW-B4) the header itself names only the character that saw
-- the drop (modules/GroupPlace.lua's Who), never the party. The roster is still captured and kept,
-- and the tooltip's TipRows name it (feedback-17): a `Group (n)` row beside the first TIP_PER_ROW
-- names, then the rest TIP_PER_ROW a row under it, every member named, each class-colored, with the
-- realm when it is not yours. A History group recorded before the roster existed has none, and its
-- tooltip has no such rows.
--
-- PURE: Entry, FromMembers, Merge, Copy, Names and TipRows take plain tables (and a color function)
-- and read nothing else; test_group_roster drives them. Current, Note and Grow are the edge: they
-- read NS.Roster, NS.Compat, NS.LootFeed, NS.History and NS.Window at call time.

NS.GroupRoster = NS.GroupRoster or {}
local GR = NS.GroupRoster
local L = NS.L

-- The tooltip's Group rows name this many members a row.
GR.TIP_PER_ROW = 5

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function plain(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

local function keyOf(e)
    return e.name:lower() .. "-" .. (e.realm or ""):lower()
end

--- One roster entry from a member (NS.Roster's, or a test looter), or nil when it has no name.
--- @param member table { name, realm, classFile, isPlayer | isSelf }
--- @param ownRealm string|nil your normalized realm
--- @return table|nil { name, realm, class, me }
function GR.Entry(member, ownRealm)
    if type(member) ~= "table" then return nil end
    local name = plain(member.name)
    if not name then return nil end
    name = name:match("^([^%-]+)") or name
    local realm = plain(member.realm)
    if realm and ownRealm and realm:lower() == tostring(ownRealm):lower() then realm = nil end
    local me = (member.isPlayer or member.isSelf) and true or nil
    return { name = name, realm = realm, class = plain(member.classFile), me = me }
end

--- Every member as an entry, in order, the nameless left out.
--- @param members table|nil
--- @param ownRealm string|nil
--- @return table
function GR.FromMembers(members, ownRealm)
    local out = {}
    for _, m in ipairs(type(members) == "table" and members or {}) do
        out[#out + 1] = GR.Entry(m, ownRealm)
    end
    return out
end

local function copyEntry(e)
    return { name = e.name, realm = e.realm, class = e.class, me = e.me }
end

local function find(list, key)
    for i, e in ipairs(list) do
        if keyOf(e) == key then return i, e end
    end
    return nil
end

-- Take one entry into `list`: a new one goes last (yours first); a known one gains a missing class.
local function takeEntry(list, e)
    local _, have = find(list, keyOf(e))
    if have then
        if not have.class and e.class then
            have.class = e.class
            return true
        end
        return false
    end
    if e.me then table.insert(list, 1, copyEntry(e)) else list[#list + 1] = copyEntry(e) end
    return true
end

--- Merge `entries` into `list` in place (the snapshot only grows): new entries are copied in, in
--- order, yours first. Malformed entries are skipped.
--- @param list table
--- @param entries table|nil
--- @return boolean changed
function GR.Merge(list, entries)
    local changed = false
    for _, e in ipairs(type(entries) == "table" and entries or {}) do
        if type(e) == "table" and plain(e.name) and takeEntry(list, e) then changed = true end
    end
    return changed
end

--- A copy of a roster (its entries copied too), or nil for none.
--- @param list table|nil
--- @return table|nil
function GR.Copy(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    GR.Merge(out, list)
    return out
end

--- `text` in a color, as an inline escape; plain when the color is unknown.
--- @param text string
--- @param r number|nil
--- @param g number|nil
--- @param b number|nil
--- @return string
function GR.Colored(text, r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return text end
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return ("|cff%02x%02x%02x%s|r"):format(byte(r), byte(g), byte(b), text)
end

local function paint(e, text, colorOf)
    if type(colorOf) ~= "function" or not e.class then return text end
    return GR.Colored(text, colorOf(e.class))
end

--- The first `limit` names, each in its class color with the realm when it is not yours, then
--- `+n`. Nil for no roster.
--- @param list table|nil
--- @param limit number|nil (every name)
--- @param colorOf function|nil classFile -> r, g, b
--- @return string|nil
function GR.Names(list, limit, colorOf)
    if type(list) ~= "table" or #list == 0 then return nil end
    local cap = math.max(1, tonumber(limit) or #list)
    local parts = {}
    for i = 1, math.min(cap, #list) do
        local e = list[i]
        parts[i] = paint(e, e.realm and (e.name .. "-" .. e.realm) or e.name, colorOf)
    end
    if #list > cap then parts[#parts + 1] = L["+%d"]:format(#list - cap) end
    return table.concat(parts, ", ")
end

--- A header tooltip's roster rows, { label, names } each (feedback-17): `Group (n)` beside the first
--- GR.TIP_PER_ROW names, then the rest that many a row under an empty label, every member named
--- (GR.Names), a row that more follow ending in a comma. Empty for no roster.
--- @param list table|nil
--- @param colorOf function|nil
--- @return table rows
function GR.TipRows(list, colorOf)
    local rows = {}
    if type(list) ~= "table" or #list == 0 then return rows end
    local per = GR.TIP_PER_ROW
    for i = 1, #list, per do
        local slice = {}
        for k = i, math.min(i + per - 1, #list) do slice[#slice + 1] = list[k] end
        local names = GR.Names(slice, nil, colorOf)
        if i + per <= #list then names = names .. "," end
        rows[#rows + 1] = { i == 1 and L["Group (%d)"]:format(#list) or "", names }
    end
    return rows
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

--- The group's members now, as entries (you alone outside a group).
--- @return table
function GR.Current()
    local Ro = NS.Roster
    if type(Ro) ~= "table" or type(Ro.Members) ~= "function" then return {} end
    return GR.FromMembers(Ro.Members(), NS.Compat.NormalizedRealm())
end

--- A feed group takes the members of the drop just added to it: a test drop's spec roster (and a
--- restored drop's, its History group's: feedback-15 spec §0), else the group's members now (the
--- snapshot grows, never shrinks).
--- @param group table a feed group
--- @param rec table the drop's record
--- @return boolean changed
function GR.Note(group, rec)
    group.roster = group.roster or {}
    if rec.test or rec.source == "restore" then
        local spec = type(rec.group) == "table" and rec.group.roster or nil
        return GR.Merge(group.roster, spec)
    end
    return GR.Merge(group.roster, GR.Current())
end

--- The roster changed: the open live group (the one a drop received now would join) and its History
--- group take the newcomers, and the shown window repaints its headers on the next frame.
--- @return boolean grown
function GR.Grow()
    local LF = NS.LootFeed
    local g = LF and LF.OpenGroup and LF.OpenGroup()
    if not g then return false end
    g.roster = g.roster or {}
    if not GR.Merge(g.roster, GR.Current()) then return false end
    if NS.History and NS.History.GrowRoster then NS.History.GrowRoster(g) end
    local W = NS.Window
    if W and W.ScheduleRepaint then W.ScheduleRepaint() end
    return true
end

if NS.Roster and NS.Roster.AddChangeSink then NS.Roster.AddChangeSink(GR.Grow) end
