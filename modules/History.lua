local _, NS = ...
-- modules/History.lua — the history (design spec §10): every drop the feed shows, kept across
-- sessions in a capped log on the account (DropWatcherDB.global.history), grouped by encounter or
-- run, each with its outcome.
--
--   history = { maxGroups (the schema row's), v = 1, groups = {
--       { key, label, kind, situation, at, drops = {
--           { itemLink, itemID, looter, class, isMine, ilvl, equipLoc, quality,
--             me = { verdict, ilvlDelta, scoreDelta }, them = { ... } | nil,
--             trade = { state, reasonKey, basis, args }, outcome, before, at } } } } }
--
-- `at` is time() (seconds since the epoch), never GetTime(), so it means the same after a reload.
-- `looter` is the Name-Realm and `class` its classFile. `before` is the outcome a hand-set
-- `declined` replaced, so clearing it puts that back. The table is the account's: History never
-- replaces `global.history` whole (the cap row lives in it), only its `groups` list.
--
-- THE CAP (spec §10). At most `global.history.maxGroups` groups (default 20, read through
-- NS.Setting), the oldest dropped first, and MAX_DROPS (50) drops per group, the oldest first.
--
-- RECORDING. A live drop's DropAdded records it (a test drop never is) under its feed group, keyed
-- by the group's key and this session's start, so a group of an earlier session never collects
-- today's drops. DropUpdated refreshes its verdicts and trade estimate; a trade estimate that
-- turns `no expired` makes its outcome `expired`. Which entry a live drop is lives in a session-only
-- index (drop ids restart each session), so after a reload the old entries are read-only.
--
-- THE OUTCOMES (spec §10): `seen` at first, `asked` when your ask is sent (AskStateChanged `sent`,
-- kind `ask`), `offered` when your offer or announce is, `expired`, `received` and `tradedAway`
-- from a completed trade, and `declined`, set by hand from a History row's menu. An automatic
-- outcome only moves forward (seen, then asked or offered, then expired, then received or traded
-- away); `declined` is the player's and stands until they clear it, unless a trade then completes.
--
-- TRADE COMPLETION (spec §10). TRADE_SHOW opens a trade with its partner (UnitName("NPC")); every
-- TRADE_PLAYER_ITEM_CHANGED / TRADE_TARGET_ITEM_CHANGED and a TRADE_ACCEPT_UPDATE with both sides
-- accepted re-read the window's items (core/Compat.lua, TradeItemLinks), since they are gone by
-- the time it closes; an item change or a withdrawn accept clears the both-accepted state. The
-- TRADE_CLOSED that follows a both-accepted state completes it: each item you got marks the most
-- recent matching drop (its item id, someone else's drop, not yet received; the partner's own drop
-- first) `received`, each item you gave marks your own matching drop `tradedAway`. The second
-- TRADE_CLOSED the client sends finds nothing open.
--
-- PURE: Normalize, Snapshot, Refresh, Record, Trim, Advance, SetDeclined and MatchTrade take plain
-- tables and the clock as arguments and read nothing else; test_history drives them. The edge
-- below reads the account table, the feed and the bus, and sends HistoryChanged on every change.

NS.History = NS.History or {}
local H = NS.History
local L = NS.L

local TAG = "FEED"

H.VERSION = 1
H.MAX_DROPS = 50

-- How far each outcome has come: an automatic move never goes back. `declined` is the player's.
H.RANK = { seen = 0, asked = 1, offered = 1, expired = 2, declined = 3, received = 4, tradedAway = 4 }
H.OUTCOMES = { "seen", "asked", "offered", "received", "tradedAway", "expired", "declined" }

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- Make `hist` the current shape in place: a `groups` list and the version stamp. Anything else in
--- it (the cap) is left alone.
--- @param hist table
--- @return table hist
function H.Normalize(hist)
    if type(hist.groups) ~= "table" then hist.groups = {} end
    if hist.v == nil then hist.v = H.VERSION end
    return hist
end

-- A verdict, kept small: the verdict and its deltas, nothing that names a frame or a table.
local function verdictSnap(eval)
    if type(eval) ~= "table" or type(eval.verdict) ~= "string" then return nil end
    return { verdict = eval.verdict, ilvlDelta = num(eval.ilvlDelta), scoreDelta = num(eval.scoreDelta) }
end

-- The trade estimate, kept small: its arguments only when they are plain numbers or strings.
local function tradeSnap(t)
    if type(t) ~= "table" or type(t.state) ~= "string" then return nil end
    local args
    if type(t.args) == "table" then
        args = {}
        for i, a in ipairs(t.args) do
            if type(a) == "number" or type(a) == "string" then args[i] = a else break end
        end
    end
    return { state = t.state, reasonKey = t.reasonKey, basis = t.basis, args = args }
end

local function itemIDOf(rec)
    if num(rec.itemID) then return rec.itemID end
    return type(rec.link) == "string" and tonumber(rec.link:match("item:(%d+)")) or nil
end

--- One entry from a feed drop record, its outcome `seen`.
--- @param rec table the feed's drop record
--- @param now number time()
--- @return table entry
function H.Snapshot(rec, now)
    local who = type(rec.looter) == "table" and rec.looter or {}
    local facts = type(rec.facts) == "table" and rec.facts or {}
    local e = {
        itemLink = rec.link, itemID = itemIDOf(rec), looter = who.name, class = who.classFile,
        isMine = rec.isMine == true or nil, ilvl = num(facts.ilvl), equipLoc = facts.equipLoc,
        quality = num(facts.quality), outcome = "seen", at = now,
    }
    H.Refresh(e, rec)
    return e
end

--- Advance an entry's outcome: only forward (H.RANK), so `asked` never undoes `expired`.
--- @param e table
--- @param outcome string
--- @return boolean changed
function H.Advance(e, outcome)
    local to, from = H.RANK[outcome], H.RANK[e.outcome] or 0
    if not to or to <= from then return false end
    e.outcome, e.before = outcome, nil
    return true
end

--- Take a drop record's latest verdicts and trade estimate; a trade gone `no expired` makes the
--- outcome `expired` (H.Advance).
--- @param e table
--- @param rec table
--- @return boolean outcomeChanged
function H.Refresh(e, rec)
    e.me, e.them, e.trade = verdictSnap(rec.me), verdictSnap(rec.them), tradeSnap(rec.trade)
    if num(e.ilvl) == nil and type(rec.facts) == "table" then e.ilvl = num(rec.facts.ilvl) end
    local t = e.trade
    if t and t.state == "no" and t.reasonKey == "expired" then return H.Advance(e, "expired") end
    return false
end

--- Mark an entry declined by hand, or clear that and put back the outcome it replaced. A drop
--- received or traded away keeps that.
--- @param e table
--- @param on boolean
--- @return boolean changed
function H.SetDeclined(e, on)
    if on then
        if e.outcome == "declined" or (H.RANK[e.outcome] or 0) >= H.RANK.received then return false end
        e.before, e.outcome = e.outcome, "declined"
        return true
    end
    if e.outcome ~= "declined" then return false end
    e.outcome, e.before = e.before or "seen", nil
    return true
end

local function markGone(group)
    for _, e in ipairs(group.drops) do e.gone = true end
end

--- Hold `hist` to the cap: at most `maxGroups` groups (the oldest go) and MAX_DROPS drops in each
--- (the oldest go). A dropped entry is marked `gone` for the session index.
--- @param hist table
--- @param maxGroups number|nil
--- @return number groups dropped
function H.Trim(hist, maxGroups)
    local cap, n = math.max(1, math.floor(num(maxGroups) or 20)), 0
    while #hist.groups > cap do
        markGone(table.remove(hist.groups, 1))
        n = n + 1
    end
    for _, g in ipairs(hist.groups) do
        while #g.drops > H.MAX_DROPS do table.remove(g.drops, 1).gone = true end
    end
    return n
end

local function findGroup(hist, key)
    for i = #hist.groups, 1, -1 do
        if hist.groups[i].key == key then return hist.groups[i] end
    end
    return nil
end

--- Record one entry under the group `info` names (made, newest last, by its first entry), then
--- hold the log to the cap.
--- @param hist table
--- @param info table { key, label, kind, situation }
--- @param entry table H.Snapshot's
--- @param maxGroups number|nil
--- @return table entry
function H.Record(hist, info, entry, maxGroups)
    local g = findGroup(hist, info.key)
    if not g then
        g = { key = info.key, label = info.label, kind = info.kind, situation = info.situation, at = entry.at,
            drops = {} }
        hist.groups[#hist.groups + 1] = g
    end
    g.drops[#g.drops + 1] = entry
    H.Trim(hist, maxGroups)
    return entry
end

local function shortName(name)
    if type(name) ~= "string" then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

local function idOf(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- The newest entry passing `want`, searching every group newest first; `taken` holds entries
-- already matched in this trade.
local function newest(hist, want, taken)
    for gi = #hist.groups, 1, -1 do
        local drops = hist.groups[gi].drops
        for di = #drops, 1, -1 do
            local e = drops[di]
            if not taken[e] and want(e) then return e end
        end
    end
    return nil
end

local function open(e) return (H.RANK[e.outcome] or 0) < H.RANK.received end

-- The entry an item you got matches: someone else's drop of that item id, not yet received, the
-- partner's own drop first.
local function receivedMatch(hist, id, partner, taken)
    local function base(e) return e.itemID == id and not e.isMine and open(e) end
    local hit = partner and newest(hist, function(e) return base(e) and shortName(e.looter) == partner end, taken)
    return hit or newest(hist, base, taken)
end

--- The entries a completed trade settles: each item you got marks the newest matching drop
--- `received`, each item you gave your own matching drop `tradedAway`; one entry per item.
--- @param hist table
--- @param trade table { partner = name|nil, given = { links }, received = { links } }
--- @return table { { entry, outcome }, ... }
function H.MatchTrade(hist, trade)
    local out, taken = {}, {}
    local partner = shortName(trade.partner)
    for _, link in ipairs(trade.received or {}) do
        local id = idOf(link)
        local e = id and receivedMatch(hist, id, partner, taken)
        if e then taken[e] = true; out[#out + 1] = { entry = e, outcome = "received" } end
    end
    for _, link in ipairs(trade.given or {}) do
        local id = idOf(link)
        local e = id and newest(hist, function(x) return x.itemID == id and x.isMine and open(x) end, taken)
        if e then taken[e] = true; out[#out + 1] = { entry = e, outcome = "tradedAway" } end
    end
    return out
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local index = {}        -- [live drop id] = its entry, this session only
local sessionStart      -- time() at the first recording: today's group keys carry it
local trade             -- the open trade: { partner, accepted, given, received } or nil

local function clock() return time() end

local function changed()
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
end

--- The account's history table, made the current shape; nil before the database exists.
--- @return table|nil
function H.Store()
    local g = NS.addon and NS.addon.db and NS.addon.db.global
    if not g then return nil end
    if type(g.history) ~= "table" then g.history = {} end
    return H.Normalize(g.history)
end

--- The cap in force: `global.history.maxGroups`, through the schema seam.
--- @return number
function H.Cap()
    return num(NS.Setting and NS.Setting("global.history.maxGroups")) or 20
end

--- When this session's recording started (time()), for the History tab's This session.
--- @return number
function H.SessionStart()
    sessionStart = sessionStart or clock()
    return sessionStart
end

--- The groups, oldest first (empty before the database exists). Read them, never write them.
--- @return table
function H.Groups()
    local hist = H.Store()
    return hist and hist.groups or {}
end

--- A live drop's entry this session, or nil (never recorded, or dropped by the cap).
--- @param dropId any
--- @return table|nil
function H.EntryOf(dropId)
    local e = index[dropId]
    if e and e.gone then return nil end
    return e
end

--- A live drop's outcome this session, or nil.
--- @param dropId any
--- @return string|nil
function H.OutcomeOf(dropId)
    local e = H.EntryOf(dropId)
    return e and e.outcome
end

--- The Ask button's state once the history knows the drop was received (`traded`), else the
--- state given (the Group drops row and the detail card read it through here).
--- @param drop table
--- @param state string|nil
--- @param reason any
--- @return string|nil state, any reason
function H.AskState(drop, state, reason)
    if type(drop) == "table" and not drop.test and H.OutcomeOf(drop.id) == "received" then return "traded" end
    return state, reason
end

local function groupInfo(rec)
    local spec = type(rec.group) == "table" and rec.group or {}
    return { key = tostring(rec.groupKey or spec.key or "?") .. "@" .. H.SessionStart(), label = spec.label,
        kind = spec.kind, situation = rec.situation }
end

--- DropAdded: record a live drop.
--- @param id any
function H.OnDropAdded(id)
    local rec = NS.LootFeed.Get(id)
    if not rec or rec.test or index[id] then return end
    local hist = H.Store()
    if not hist then return end
    index[id] = H.Record(hist, groupInfo(rec), H.Snapshot(rec, clock()), H.Cap())
    changed()
end

--- DropUpdated: refresh a recorded drop's verdicts and trade.
--- @param id any
function H.OnDropUpdated(id)
    local e, rec = H.EntryOf(id), NS.LootFeed.Get(id)
    if not (e and rec) then return end
    H.Refresh(e, rec)
    changed()
end

local SENT_OUTCOME = { ask = "asked", offer = "offered", announce = "offered" }

--- AskStateChanged: a sent ask is `asked`; a sent offer or announce `offered`.
function H.OnAskState(dropId, state, kind)
    local e = H.EntryOf(dropId)
    if state ~= "sent" or not e or not SENT_OUTCOME[kind] then return end
    if H.Advance(e, SENT_OUTCOME[kind]) then changed() end
end

--- Mark a recorded entry declined by hand, or clear it (a History row's menu).
--- @param e table
--- @param on boolean
function H.SetEntryDeclined(e, on)
    if type(e) == "table" and H.SetDeclined(e, on) then
        NS.Debug(TAG, "history: %s %s", tostring(e.itemLink), on and "declined" or "declined cleared")
        changed()
    end
end

--- Empty the history (the History tab's Clear history, behind its confirmation). The cap stays.
function H.Clear()
    local hist = H.Store()
    if not hist then return end
    for _, g in ipairs(hist.groups) do markGone(g) end
    hist.groups = {}
    NS.Print(L["History cleared."])
    changed()
end

--- Hold the stored log to the cap now (the cap row's change).
function H.ApplyCap()
    local hist = H.Store()
    if hist and H.Trim(hist, H.Cap()) > 0 then changed() end
end

-- ── the trade window ────────────────────────────────────────────────────────────────────────

local function readItems()
    if not trade then return end
    trade.given, trade.received = NS.Compat.TradeItemLinks()
end

local function accepted(v)
    return not NS.Compat.IsSecret(v) and (v == 1 or v == true)
end

--- TRADE_SHOW: a trade opened, with whom.
function H.OnTradeShow()
    trade = { partner = NS.Compat.TradePartnerName(), accepted = false, given = {}, received = {} }
    readItems()
end

--- TRADE_PLAYER_ITEM_CHANGED / TRADE_TARGET_ITEM_CHANGED: the items moved, so any accept is off.
function H.OnTradeItems()
    if not trade then return end
    trade.accepted = false
    readItems()
end

--- TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted).
function H.OnTradeAccept(playerAccepted, targetAccepted)
    if not trade then return end
    trade.accepted = accepted(playerAccepted) and accepted(targetAccepted)
    if trade.accepted then readItems() end
end

local function settle(t)
    local hist = H.Store()
    if not hist then return 0 end
    local n = 0
    for _, m in ipairs(H.MatchTrade(hist, t)) do
        m.entry.outcome, m.entry.before = m.outcome, nil
        n = n + 1
        NS.Debug("TRADE", "history: %s %s (with %s)", tostring(m.entry.itemLink), m.outcome, tostring(t.partner))
    end
    return n
end

--- TRADE_CLOSED: after a both-accepted state, the trade completed.
function H.OnTradeClosed()
    local t = trade
    trade = nil
    if not (t and t.accepted) then return end
    NS.Debug("TRADE", "trade with %s completed: gave %d, got %d", tostring(t.partner), #t.given, #t.received)
    if settle(t) > 0 then changed() end
end

--- The open trade, for the diagnostics report: { partner, accepted, given, received } or nil.
--- @return table|nil
function H.OpenTrade() return trade end

--- The counts the diagnostics report shows: { groups, drops, cap, tracked }.
--- @return table
function H.Stats()
    local groups, drops = H.Groups(), 0
    for _, g in ipairs(groups) do drops = drops + #g.drops end
    local tracked = 0
    for _ in pairs(index) do tracked = tracked + 1 end
    return { groups = #groups, drops = drops, cap = H.Cap(), tracked = tracked }
end

-- ── events, messages and the lifecycle ──────────────────────────────────────────────────────

local EVENTS = {
    { "TRADE_SHOW", "OnHistoryTradeShow", H.OnTradeShow },
    { "TRADE_PLAYER_ITEM_CHANGED", "OnHistoryTradeItems", H.OnTradeItems },
    { "TRADE_TARGET_ITEM_CHANGED", "OnHistoryTradeItems", H.OnTradeItems },
    { "TRADE_ACCEPT_UPDATE", "OnHistoryTradeAccept", H.OnTradeAccept },
    { "TRADE_CLOSED", "OnHistoryTradeClosed", H.OnTradeClosed },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function(_, _, ...) fn(...) end
end

-- Tracked, so the stand-down takes them down and the stand-up replays them. Without the bus
-- library it is a bare target, unregistered here instead (NS.Bus.tracked says which).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    local M = NS.MSG
    target:RegisterMessage(M.DROP_ADDED, function(_, id) H.OnDropAdded(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function(_, id) H.OnDropUpdated(id) end)
    target:RegisterMessage(M.ASK_STATE_CHANGED, function(_, id, state, kind) H.OnAskState(id, state, kind) end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    trade = nil
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
