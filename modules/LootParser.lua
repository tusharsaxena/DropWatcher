local _, NS = ...
-- modules/LootParser.lua — a CHAT_MSG_LOOT line turned into who received which item (design spec
-- §3, §4).
--
--   loot = { looterName, looterGUID, link, qty, kind, isSelf }
--     kind is "loot" (LOOT_ITEM*), "bonus" (LOOT_ITEM_BONUS_ROLL*) or "pushed" (LOOT_ITEM_PUSHED*).
--
-- THE PATTERNS. Built from the client's own GlobalStrings, so every client language reads its own
-- lines: the self and the third-person form of each kind, each with its `*_MULTIPLE` twin. A
-- `*_MULTIPLE` pattern is tried before its single twin, because the single form's greedy link
-- capture would otherwise swallow the trailing "x2"; the self forms are tried before the
-- third-person ones, so no locale can read "You" as a looter's name. A locale that reorders its
-- arguments (`%2$s ... %1$s`) is read in its own order.
--
-- REJECTED, before any receipt is tried: the item-upgrade echo (CHANGED_OWN_ITEM, "Changed %s to
-- %s.") and the crafting echoes (LOOT_ITEM_CREATED_SELF*, CREATED_ITEM*). Neither is a drop.
--
-- REBUILT WHEN THE GLOBALS CHANGE. Another addon may rewrite these globals at runtime (PrettyChat
-- does, on every settings write and combat boundary). The compiled set keeps the exact strings it
-- came from, and every parse compares the live globals against them with rawequal, building no
-- table and no string on the hit path; any difference, a global appearing or vanishing included,
-- rebuilds the set. LootHistory's self-loot parser is the precedent; it reads the player's own loot
-- only, and this one reads every looter.
--
-- SECRETS. A secret line is counted and dropped before it meets a pattern; a secret or empty
-- GlobalString is left out of the set; a secret sender GUID is not used. Captures taken from a
-- plain line are plain.
--
-- THE LOOTER. The player for a self line. Otherwise the captured name (a player hyperlink or color
-- wrapper stripped), resolved through NS.Roster to the member's Name-Realm and GUID; a name the
-- roster cannot place keeps its captured spelling and takes the event's own GUID, when that is a
-- plain player GUID.
--
-- THE EDGE. CHAT_MSG_LOOT is declared in NS.FEATURE_EVENTS, so the stand-down unregisters it. Each
-- parsed line is handed to every sink (LP.AddSink; the feed of DW-27 is the consumer), each in
-- pcall so one failing sink costs that sink only. The counters of spec §13 (lines read, ignored,
-- rejected, secret; the last loot seen) live in NS.State.lootParser for the session and survive a
-- stand-down: they say what the parser has seen since login.

NS.LootParser = NS.LootParser or {}
local LP = NS.LootParser
local State = NS.State
local Perf = NS.Perf

local TAG = "PARSE"

-- The shapes, in match order. `args` names each argument of the GlobalString in its printf order.
local SELF_ARGS, SELF_QTY_ARGS = { "link" }, { "link", "qty" }
local OTHER_ARGS, OTHER_QTY_ARGS = { "name", "link" }, { "name", "link", "qty" }
local NO_ARGS = {}

local function shape(global, kind, isSelf, multiple)
    local args = isSelf and (multiple and SELF_QTY_ARGS or SELF_ARGS)
        or (multiple and OTHER_QTY_ARGS or OTHER_ARGS)
    return { global = global, kind = kind, isSelf = isSelf, args = args }
end

local function reject(global)
    return { global = global, reject = true, args = NO_ARGS }
end

LP.SHAPES = {
    reject("CHANGED_OWN_ITEM"),
    reject("LOOT_ITEM_CREATED_SELF_MULTIPLE"),
    reject("LOOT_ITEM_CREATED_SELF"),
    reject("CREATED_ITEM_MULTIPLE"),
    reject("CREATED_ITEM"),
    shape("LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", "bonus", true, true),
    shape("LOOT_ITEM_PUSHED_SELF_MULTIPLE", "pushed", true, true),
    shape("LOOT_ITEM_SELF_MULTIPLE", "loot", true, true),
    shape("LOOT_ITEM_BONUS_ROLL_SELF", "bonus", true, false),
    shape("LOOT_ITEM_PUSHED_SELF", "pushed", true, false),
    shape("LOOT_ITEM_SELF", "loot", true, false),
    shape("LOOT_ITEM_BONUS_ROLL_MULTIPLE", "bonus", false, true),
    shape("LOOT_ITEM_PUSHED_MULTIPLE", "pushed", false, true),
    shape("LOOT_ITEM_MULTIPLE", "loot", false, true),
    shape("LOOT_ITEM_BONUS_ROLL", "bonus", false, false),
    shape("LOOT_ITEM_PUSHED", "pushed", false, false),
    shape("LOOT_ITEM", "loot", false, false),
}

-- ── compiling ───────────────────────────────────────────────────────────────────────────────

-- The capture index each argument lands in. Without positional markers the captures follow the
-- printf order; with them (`%2$s`), capture i holds argument N of the i-th marker.
local function captureSlots(fmt, args)
    local slots, i = {}, 0
    for n in fmt:gmatch("%%(%d+)%$") do
        i = i + 1
        if args[tonumber(n)] then slots[args[tonumber(n)]] = i end
    end
    if i > 0 then return slots end
    for k, name in ipairs(args) do slots[name] = k end
    return slots
end

-- A usable GlobalString, read bare at call time: a plain, non-empty string, else nil.
local function usable(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

local compiled, sources

--- Compile the pattern set from the live GlobalStrings. Called by Parse whenever they change;
--- exported for the tests and the diagnostics.
--- @return table the compiled entries, in match order
function LP.Rebuild()
    local out, src = {}, {}
    for i, s in ipairs(LP.SHAPES) do
        local raw = NS.Compat.GlobalString(s.global)
        src[i] = raw
        local fmt = usable(raw)
        if fmt then
            out[#out + 1] = { pattern = "^" .. NS.Compat.FormatToPattern(fmt) .. "$", shape = s,
                slots = captureSlots(fmt, s.args) }
        end
    end
    compiled, sources = out, src
    NS.Debug(TAG, "loot patterns built: %d of %d globals", #out, #LP.SHAPES)
    return out
end

-- True when every global still is the exact string the set was built from.
local function fresh()
    if not sources then return false end
    local shapes, read = LP.SHAPES, NS.Compat.GlobalString
    for i = 1, #shapes do
        if not rawequal(sources[i], read(shapes[i].global)) then return false end
    end
    return true
end

-- ── matching ────────────────────────────────────────────────────────────────────────────────

-- The first entry whose pattern matches, with the line's captures.
local function match(text)
    for _, e in ipairs(compiled) do
        local c1, c2, c3 = text:match(e.pattern)
        if c1 then return e, { c1, c2, c3 } end
    end
    return nil
end

-- A captured name without a player hyperlink, color codes or surrounding space; nil when empty.
local function cleanName(s)
    if not s then return nil end
    s = s:gsub("|Hplayer:[^|]*|h%[?([^%]|]*)%]?|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:match("^%s*(.-)%s*$")
    if s == "" then return nil end
    return s
end

local function isItemLink(link)
    return link ~= nil and link:find("|Hitem:", 1, true) ~= nil
end

local function plainPlayerGUID(guid)
    if not NS.Compat.IsSafeKey(guid) or type(guid) ~= "string" then return nil end
    if guid:sub(1, 7) ~= "Player-" then return nil end
    return guid
end

-- The player, as a self line's looter.
local function selfLooter()
    local me = NS.Roster.Player()
    if me then return me.fullName or me.name, me.guid end
    local guid = NS.Compat.UnitGUID("player")
    return usable(NS.Compat.UnitName("player")), NS.Compat.IsSafeKey(guid) and guid or nil
end

-- A third-person looter: the roster's member when it can place the name, else the name as captured
-- and the event's GUID.
local function otherLooter(name, guid)
    local m = NS.Roster.Resolve(name)
    if m then return m.fullName or m.name, m.guid end
    return name, plainPlayerGUID(guid)
end

-- The loot record of a matched receipt, or nil and why not.
local function record(e, caps, guid)
    local s, slots = e.shape, e.slots
    local link = caps[slots.link]
    if not isItemLink(link) then return nil, "notItem" end
    local qty = slots.qty and tonumber(caps[slots.qty]) or 1
    local name, looterGUID
    if s.isSelf then
        name, looterGUID = selfLooter()
    else
        name = cleanName(caps[slots.name])
        if not name then return nil, "noLooter" end
        name, looterGUID = otherLooter(name, guid)
    end
    return { looterName = name, looterGUID = looterGUID, link = link, qty = qty, kind = s.kind,
        isSelf = s.isSelf }
end

local function parse(text, guid)
    if NS.Compat.IsSecret(text) then return nil, "secret" end
    if type(text) ~= "string" or text == "" then return nil, "empty" end
    if not fresh() then LP.Rebuild() end
    local e, caps = match(text)
    if not e then return nil, "noMatch" end
    if e.shape.reject then return nil, "rejected" end
    return record(e, caps, guid)
end

--- Parse one CHAT_MSG_LOOT line.
--- @param text any the event's message (it may be secret)
--- @param guid any the event's GUID argument, used only for a looter the roster cannot place
--- @return table|nil loot the loot record, or nil
--- @return string|nil why "secret", "empty", "noMatch", "rejected", "notItem" or "noLooter"
function LP.Parse(text, guid)
    local t0 = Perf.on and debugprofilestop()
    local loot, why = parse(text, guid)
    if t0 then Perf.Note("parse", debugprofilestop() - t0) end
    return loot, why
end

-- ── the counters ────────────────────────────────────────────────────────────────────────────

local function stats()
    local s = State.lootParser
    if not s then
        s = { hits = 0, ignored = 0, rejected = 0, secret = 0 }
        State.lootParser = s
    end
    return s
end

--- The session's counters: { hits, ignored, rejected, secret, lastAt, lastKind, lastLooter }.
--- The table is the parser's own: read it, never write it.
--- @return table
function LP.Stats()
    return stats()
end

local COUNTER = { secret = "secret", rejected = "rejected" }

local function count(loot, why)
    local s = stats()
    if loot then
        s.hits = s.hits + 1
        s.lastAt, s.lastKind, s.lastLooter = GetTime(), loot.kind, loot.looterName
        return
    end
    local key = COUNTER[why] or "ignored"
    s[key] = s[key] + 1
end

-- ── the sinks and the event ─────────────────────────────────────────────────────────────────

local sinks = {}

--- Hand every parsed loot record to `fn(loot)` from now on.
--- @param fn function
function LP.AddSink(fn)
    sinks[#sinks + 1] = fn
end

local function deliver(loot)
    for _, fn in ipairs(sinks) do
        local ok, err = pcall(fn, loot)
        if not ok then NS.Debug(TAG, "loot sink failed: %s", err) end
    end
end

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "CHAT_MSG_LOOT", "OnChatMsgLoot" }

-- CHAT_MSG_LOOT: text, playerName, languageName, channelName, playerName2, specialFlags,
-- zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid.
function NS.addon.OnChatMsgLoot(_, _, text, ...)
    local guid = select(11, ...)
    local loot, why = LP.Parse(text, guid)
    count(loot, why)
    if not loot then
        if why ~= "noMatch" then NS.Debug(TAG, "loot line skipped: %s", why) end
        return
    end
    NS.Debug(TAG, "%s %s x%s by %s (%s)", loot.kind, loot.link, loot.qty, loot.looterName or "?",
        loot.looterGUID or "no GUID")
    deliver(loot)
end
