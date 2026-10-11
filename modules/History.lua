local _, NS = ...
-- modules/History.lua — the history (design spec §10): every drop the feed shows, kept across
-- sessions in a log on the account (DropWatcherDB.global.history), grouped by encounter or run,
-- each with its outcome, kept for a number of days.
--
--   history = { retentionDays (the schema row's), v = 1, groups = {
--       { key, label, kind, situation, at, roster = { { name, realm, class, me }, ... }, drops = {
--           { itemLink, itemID, looter, class, isMine, ilvl, equipLoc, quality, seenBy, seenByClass,
--             me = { verdict, ilvlDelta, scoreDelta }, them = { ... } | nil,
--             trade = { state, reasonKey, basis, args }, outcome, before, at } } } } }
--
-- `at` is time() (seconds since the epoch), never GetTime(), so it means the same after a reload.
-- `roster` is who was in the group (feedback-2 spec §3, modules/GroupRoster.lua): copied from the
-- feed group's snapshot by every recorded drop and grown with it; a group kept before it existed
-- has none.
-- `seenBy` is the character that saw the drop (Name-Realm) and `seenByClass` its classFile, for the
-- Character dropdown (feedback-2 spec §4, modules/CharFilter.lua); an entry kept before they existed
-- has neither.
-- `looter` is the Name-Realm and `class` its classFile. `before` is the outcome a hand-set
-- `declined` replaced, so clearing it puts that back. The table is the account's: History never
-- replaces `global.history` whole (the retention row lives in it), only its `groups` list.
--
-- HOW LONG IT IS KEPT (feedback-2 spec §5). By age, not by count: modules/HistoryRetention.lua
-- deletes the groups older than `global.history.retentionDays` (Keep history for, default 30 days).
-- Here, MAX_DROPS (50) drops per group and CEILING (5,000) drops in all, a safety ceiling that keeps
-- SavedVariables bounded even when nothing is deleted by age, the oldest dropped first.
--
-- THE SIMULATOR (simulator spec §5). While a simulation runs, the log is the simulation's own
-- session-only log (NS.Sim.HistoryLog, modules/Sim.lua), never `global.history`: Log() answers it,
-- the History tab shows it, and a simulated drop (`rec.sim`) is never recorded anywhere else. A
-- real drop or trade that arrives while one runs is the account's (LogFor reads the record's or the
-- trade's own origin). The stop lets the simulation's log go (ReleaseLog) and the tab shows the
-- account's log again.
--
-- TEST MODE (ui spec §4, FB-10). While test mode is on, Log() answers test mode's session-only
-- sample log (NS.TestMode.HistoryLog: two groups covering every outcome), so the History tab
-- shows it and Clear history or a hand-set declined touches only it. It is never written to
-- `global.history`; a real drop that arrives meanwhile is still the account's (LogFor).
--
-- RECORDING. A live drop's DropAdded records it (a test drop never is) under its feed group, keyed
-- by the group's key and this session's start, so a group of an earlier session never collects
-- today's drops. DropUpdated refreshes its verdicts and trade estimate, and its link, level and
-- quality when a merge or the bag read improved them (BUG-1); a trade estimate that
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
-- TRADE_PLAYER_ITEM_CHANGED / TRADE_TARGET_ITEM_CHANGED re-reads the window's items (core/Compat.lua,
-- TradeItemLinks), and every TRADE_ACCEPT_UPDATE with either side accepted re-reads them and keeps
-- them as the offer, since the window is empty by the time the trade ends and any later item change
-- makes both sides accept again. Only the client's "Trade complete." (UI_INFO_MESSAGE,
-- Compat.IsTradeCompleteMessage) completes it, whether it comes before TRADE_CLOSED or within
-- CLOSED_GRACE seconds after it: each item you got in the offer marks the most recent matching drop
-- (its item id, someone else's drop, not yet received; the partner's own drop first) `received`,
-- each item you gave marks your own matching drop `tradedAway`. TRADE_CLOSED alone is a cancel or a
-- failure (out of range, a full bag) and completes nothing.
--
-- PURE: Normalize, Snapshot, Refresh, Record, Trim, Advance, SetDeclined and MatchTrade take plain
-- tables and the clock as arguments and read nothing else but the pure link parse
-- (NS.ItemRead.BetterLink); test_history and test_item_read drive them. The edge
-- below reads the account table, the feed and the bus, and sends HistoryChanged on every change
-- to what it stores, never for a DropUpdated that changed nothing kept.

NS.History = NS.History or {}
local H = NS.History
local L = NS.L

local TAG = "FEED"

H.VERSION = 1
H.MAX_DROPS = 50
H.CEILING = 5000

-- How far each outcome has come: an automatic move never goes back. `declined` is the player's.
H.RANK = { seen = 0, asked = 1, offered = 1, expired = 2, declined = 3, received = 4, tradedAway = 4 }
H.OUTCOMES = { "seen", "asked", "offered", "received", "tradedAway", "expired", "declined" }

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- Make `hist` the current shape in place: a `groups` list and the version stamp. Anything else in
--- it (the retention row) is left alone.
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
        quality = num(facts.quality), outcome = "seen", at = now, sim = rec.sim == true or nil,
        seenBy = rec.seenBy, seenByClass = rec.seenByClass,
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

-- Two snapshots (verdictSnap, tradeSnap, or nil) hold the same values: one level of fields, and
-- the args list one level deeper.
local function sameSnap(a, b)
    if a == nil or b == nil then return a == b end
    for k, v in pairs(a) do
        if k == "args" then
            if not sameSnap(v, b.args) then return false end
        elseif b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-- One field of the entry takes the record's value when it has one that differs.
local function takeField(e, key, v)
    if v == nil or e[key] == v then return false end
    e[key] = v
    return true
end

-- The item itself, read again (ui spec §0, BUG-1): a merge or the bag read keeps the most complete
-- link and reads the level and quality again after the entry was recorded (DropUpdated `source`,
-- `bag`), so the entry takes the more complete link (ItemRead.BetterLink, a tie keeps its own) and
-- the latest level and quality.
local function takeItem(e, rec)
    local IR = NS.ItemRead
    local better = IR and IR.BetterLink(e.itemLink, rec.link) or e.itemLink
    local moved = takeField(e, "itemLink", type(better) == "string" and better or nil)
    local facts = type(rec.facts) == "table" and rec.facts or {}
    moved = takeField(e, "ilvl", num(facts.ilvl)) or moved
    moved = takeField(e, "quality", num(facts.quality)) or moved
    return moved
end

local function takeSnaps(e, rec)
    local me, them, trade = verdictSnap(rec.me), verdictSnap(rec.them), tradeSnap(rec.trade)
    local moved = not (sameSnap(e.me, me) and sameSnap(e.them, them) and sameSnap(e.trade, trade))
    e.me, e.them, e.trade = me, them, trade
    return takeItem(e, rec) or moved
end

--- Take a drop record's latest verdicts, trade estimate, more complete link, level and quality;
--- a trade gone `no expired` makes the
--- outcome `expired` (H.Advance).
--- @param e table
--- @param rec table
--- @return boolean outcomeChanged
--- @return boolean changed whether anything stored changed (the snapshots or the outcome)
function H.Refresh(e, rec)
    local moved = takeSnaps(e, rec)
    local t = e.trade
    local advanced = t ~= nil and t.state == "no" and t.reasonKey == "expired" and H.Advance(e, "expired")
    return advanced, advanced or moved
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

local function totalDrops(hist)
    local n = 0
    for _, g in ipairs(hist.groups) do n = n + #g.drops end
    return n
end

-- The ceiling: the oldest drop of the oldest group goes first, and a group left empty goes too.
local function holdCeiling(hist, ceiling)
    local over, n = totalDrops(hist) - ceiling, 0
    while over > 0 and #hist.groups > 0 do
        local g = hist.groups[1]
        if #g.drops == 0 then
            table.remove(hist.groups, 1)
        else
            table.remove(g.drops, 1).gone = true
            over, n = over - 1, n + 1
        end
    end
    if hist.groups[1] and #hist.groups[1].drops == 0 then table.remove(hist.groups, 1) end
    return n
end

--- Hold `hist` to its limits: MAX_DROPS drops in each group and `ceiling` (CEILING by default)
--- drops in all, the oldest first. A dropped entry is marked `gone` for the session index.
--- @param hist table
--- @param ceiling number|nil
--- @return number drops dropped
function H.Trim(hist, ceiling)
    local n = 0
    for _, g in ipairs(hist.groups) do
        while #g.drops > H.MAX_DROPS do
            table.remove(g.drops, 1).gone = true
            n = n + 1
        end
    end
    return n + holdCeiling(hist, math.max(1, math.floor(num(ceiling) or H.CEILING)))
end

local function findGroup(hist, key)
    for i = #hist.groups, 1, -1 do
        if hist.groups[i].key == key then return hist.groups[i] end
    end
    return nil
end

--- Record one entry under the group `info` names (made, newest last, by its first entry), merge
--- the group's roster in, then hold the log to its limits (H.Trim).
--- @param hist table
--- @param info table { key, label, kind, situation, roster }
--- @param entry table H.Snapshot's
--- @param ceiling number|nil H.Trim's
--- @return table entry
function H.Record(hist, info, entry, ceiling)
    local g = findGroup(hist, info.key)
    if not g then
        g = { key = info.key, label = info.label, kind = info.kind, situation = info.situation, at = entry.at,
            drops = {} }
        hist.groups[#hist.groups + 1] = g
    end
    if type(info.roster) == "table" then
        g.roster = g.roster or {}
        NS.GroupRoster.Merge(g.roster, info.roster)
    end
    g.drops[#g.drops + 1] = entry
    H.Trim(hist, ceiling)
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
local trade             -- the trade: { partner, accepted, given, received, offer, closedAt } or nil

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

--- The log being written: test mode's session-only sample log while test mode is on (ui spec
--- §4, FB-10), the simulation's session-only log while one runs (simulator spec §5), else the
--- account's (H.Store). Nil before the database exists.
--- @return table|nil
function H.Log()
    if NS.State.testMode == true then return H.Normalize(NS.TestMode.HistoryLog()) end
    local log = NS.Sim.active and NS.Sim.HistoryLog()
    if log then return H.Normalize(log) end
    return H.Store()
end

--- The log a record or trade of this origin is written to: the running simulation's for a
--- simulated one (nil once it has stopped), the account's (H.Store) for a real one.
--- @param sim any the origin's `sim` flag
--- @return table|nil
function H.LogFor(sim)
    if not sim then return H.Store() end
    local log = NS.Sim.active and NS.Sim.HistoryLog()
    return log and H.Normalize(log) or nil
end

--- A stopped simulation's log let go: every entry leaves the session index, and the History tab
--- reads the account's log again (HistoryChanged).
--- @param log table|nil
function H.ReleaseLog(log)
    if type(log) ~= "table" or type(log.groups) ~= "table" then return end
    for _, g in ipairs(log.groups) do markGone(g) end
    log.groups = {}
    changed()
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
    local hist = H.Log()
    return hist and hist.groups or {}
end

--- A live drop's entry this session, or nil (never recorded, or since deleted).
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

local function historyKey(feedKey) return tostring(feedKey or "?") .. "@" .. H.SessionStart() end

-- The feed group's roster snapshot for a drop, or nil.
local function feedRoster(rec)
    local groups = NS.LootFeed.Groups(rec.feed)
    for i = #groups, 1, -1 do
        if groups[i].key == rec.groupKey then return groups[i].roster end
    end
    return nil
end

local function groupInfo(rec)
    local spec = type(rec.group) == "table" and rec.group or {}
    return { key = historyKey(rec.groupKey or spec.key), label = spec.label, kind = spec.kind,
        situation = rec.situation, roster = feedRoster(rec) }
end

--- A feed group's roster grew between drops (modules/GroupRoster.lua): the History group it is
--- recorded under (in the running simulation's log while one runs, else the account's) takes the
--- newcomers. HistoryChanged when it did.
--- @param feedGroup table
--- @return boolean grown
function H.GrowRoster(feedGroup)
    local hist = H.LogFor(NS.Sim.active)
    local g = hist and findGroup(hist, historyKey(feedGroup.key))
    if not g then return false end
    g.roster = g.roster or {}
    if not NS.GroupRoster.Merge(g.roster, feedGroup.roster) then return false end
    changed()
    return true
end

--- DropAdded: record a live drop.
--- @param id any
function H.OnDropAdded(id)
    local rec = NS.LootFeed.Get(id)
    if not rec or rec.test or index[id] then return end
    -- A simulated drop goes to the simulation's log only; a real one to the account's, even while
    -- a simulation runs (the record's own origin decides, never whether one runs).
    local hist = H.LogFor(rec.sim)
    if not hist then return end
    index[id] = H.Record(hist, groupInfo(rec), H.Snapshot(rec, clock()))
    changed()
end

--- DropUpdated: refresh a recorded drop's verdicts and trade; HistoryChanged only when the stored
--- entry changed (an inspect, a score retry or a trade sweep often changes nothing it keeps).
--- @param id any
function H.OnDropUpdated(id)
    local e, rec = H.EntryOf(id), NS.LootFeed.Get(id)
    if not (e and rec) then return end
    local _, moved = H.Refresh(e, rec)
    if moved then changed() end
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

--- Empty the history (the History tab's Clear history, behind its confirmation). The retention
--- row stays.
function H.Clear()
    local hist = H.Log()
    if not hist then return end
    for _, g in ipairs(hist.groups) do markGone(g) end
    hist.groups = {}
    NS.Print(L["History cleared."])
    changed()
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
    trade = { partner = NS.Compat.TradePartnerName(), accepted = false, given = {}, received = {},
        sim = NS.Sim.IsDelivering and NS.Sim.IsDelivering() or nil }
    readItems()
end

-- How long a closed trade waits for its "Trade complete." message, in seconds.
H.CLOSED_GRACE = 5

local function openTrade()
    if trade and not trade.closedAt then return trade end
    return nil
end

--- TRADE_PLAYER_ITEM_CHANGED / TRADE_TARGET_ITEM_CHANGED: the items moved, so any accept is off.
function H.OnTradeItems()
    local t = openTrade()
    if not t then return end
    t.accepted = false
    readItems()
end

--- TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted): either side's accept keeps the items as
--- the offer a completion settles.
function H.OnTradeAccept(playerAccepted, targetAccepted)
    local t = openTrade()
    if not t then return end
    t.accepted = accepted(playerAccepted) or accepted(targetAccepted)
    if not t.accepted then return end
    readItems()
    t.offer = { given = t.given, received = t.received }
end

local function settle(t)
    local hist = H.LogFor(t.sim)
    if not hist then return 0 end
    local n = 0
    for _, m in ipairs(H.MatchTrade(hist, t)) do
        m.entry.outcome, m.entry.before = m.outcome, nil
        n = n + 1
        NS.Debug("TRADE", "history: %s %s (with %s)", tostring(m.entry.itemLink), m.outcome, tostring(t.partner))
    end
    return n
end

--- TRADE_CLOSED: the window is gone, completed or not; the trade waits CLOSED_GRACE seconds for
--- its "Trade complete." message. The client's second TRADE_CLOSED changes nothing.
function H.OnTradeClosed()
    if trade and not trade.closedAt then trade.closedAt = GetTime() end
end

local function completable()
    local t = trade
    if not t then return nil end
    if t.closedAt and GetTime() - t.closedAt > H.CLOSED_GRACE then return nil end
    return t
end

--- UI_INFO_MESSAGE(messageType, message): the client's "Trade complete." completes the trade.
function H.OnInfoMessage(messageType, message)
    if not (trade and NS.Compat.IsTradeCompleteMessage(messageType, message)) then return end
    local t = completable()
    trade = nil
    if not t then return end
    local offer = t.offer or t
    local done = { partner = t.partner, given = offer.given, received = offer.received, sim = t.sim }
    NS.Debug("TRADE", "trade with %s completed: gave %d, got %d", tostring(t.partner), #done.given,
        #done.received)
    if settle(done) > 0 then changed() end
end

--- The open trade, for the diagnostics report: { partner, accepted, given, received } or nil
--- (nil once its window has closed).
--- @return table|nil
function H.OpenTrade() return openTrade() end

--- The counts the diagnostics report and the History footer show: { groups, drops, days (the
--- retention, 0 = never delete), ceiling, tracked }.
--- @return table
function H.Stats()
    local groups, drops = H.Groups(), 0
    for _, g in ipairs(groups) do drops = drops + #g.drops end
    local tracked = 0
    for _ in pairs(index) do tracked = tracked + 1 end
    return { groups = #groups, drops = drops, days = NS.HistoryRetention.Days(), ceiling = H.CEILING,
        tracked = tracked }
end

-- ── events, messages and the lifecycle ──────────────────────────────────────────────────────

local EVENTS = {
    { "TRADE_SHOW", "OnHistoryTradeShow", H.OnTradeShow },
    { "TRADE_PLAYER_ITEM_CHANGED", "OnHistoryTradeItems", H.OnTradeItems },
    { "TRADE_TARGET_ITEM_CHANGED", "OnHistoryTradeItems", H.OnTradeItems },
    { "TRADE_ACCEPT_UPDATE", "OnHistoryTradeAccept", H.OnTradeAccept },
    { "TRADE_CLOSED", "OnHistoryTradeClosed", H.OnTradeClosed },
    { "UI_INFO_MESSAGE", "OnHistoryInfoMessage", H.OnInfoMessage },
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
