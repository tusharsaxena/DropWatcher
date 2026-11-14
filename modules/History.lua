local _, NS = ...
-- modules/History.lua — the history (design spec §10): every drop the feed shows, kept across
-- sessions in a log on the account (DropWatcherDB.global.history), grouped by encounter or run,
-- each with its outcome, kept for a number of days.
--
--   history = { retentionDays (the schema row's), v = 1, groups = {
--       { key, label, kind, situation, at, instance, difficulty, seenBy, seenByClass,
--         roster = { { name, realm, class, me }, ... }, drops = {
--           { itemLink, itemID, looter, class, isMine, ilvl, equipLoc, quality, seenBy, seenByClass,
--             category, tokenSlot, tokenUsers,
--             me = { verdict, ilvlDelta, scoreDelta, offSpec?, collect?, category?, count?, limit?,
--                    reasonKey? }, them = { ... } | nil,
--             trade = { state, reasonKey, basis, args }, outcome, before, beforeExpired, at,
--             askedAt?, offeredAt?, settledAt?, got?,
--             rolls? = { at, allPassed, n, w, r = { { name, class, s, n? }, ... } } } } } } }
--
-- `at` is time() (seconds since the epoch), never GetTime(), so it means the same after a reload.
-- `roster` is who was in the group (feedback-2 spec §3, modules/GroupRoster.lua): copied from the
-- feed group's snapshot by every recorded drop and grown with it; a group kept before it existed
-- has none.
-- A group's `instance` and `difficulty` name where it dropped and `seenBy` / `seenByClass` the
-- character that saw it (feedback-3 spec §4, modules/GroupPlace.lua), from the feed group; a group
-- kept before they existed has none and keeps its old header.
-- `seenBy` is the character that saw the drop (Name-Realm) and `seenByClass` its classFile, for the
-- Character dropdown (feedback-2 spec §4, modules/CharFilter.lua); an entry kept before they existed
-- has neither.
-- `category` is the drop's item kind (issue #13, categories design spec §3.3: equipment, tierToken,
-- mount, pet, toy, recipe, cosmetic, container; `other` for an item of no kind rolled on, RX-04),
-- `tokenSlot` a tier token's made slot and `tokenUsers` who may
-- use a token naming no classes (`every`, a Curio; `yours`, a Use text alone; modules/ItemFacts.lua),
-- since TT-1 (an older token entry has none, and its Type reads a dash); an entry kept before
-- they existed has neither and reads as equipment (Insights: a tier token for the slot
-- INVTYPE_NON_EQUIP_IGNORE). An Always watch item of no kind (a reagent, a quest item) is kept as
-- `watched` (NS.Constants.CATEGORY_WATCHED), a History-only kind, so it never reads as one of those
-- older entries. A collectible's `me` keeps its collection verdict
-- (`collect` true, the `category`, a pet's `count` and `limit`, and `reasonKey` = notYourProfession
-- for a recipe of a profession you lack), so History draws it with no live drop; an entry keeps the
-- verdict its drop last had while live, and an older entry is a record, never judged again. The
-- fields are additive: `v` stays 1.
-- `looter` is the Name-Realm and `class` its classFile. `before` is the outcome a hand-set
-- `declined` replaced, so clearing it puts that back; `beforeExpired` the one an automatic `expired`
-- replaced (feedback-15 spec §0), so a live timer read can put that back. The table is the
-- account's: History never replaces `global.history` whole (the retention row lives in it), only
-- its `groups` list.
-- `askedAt` and `offeredAt` (time()) say when your ask, or your offer or announce, was first sent
-- (issue #12, Insights design spec §1.2): stamped once by AskStateChanged `sent` whether or not
-- the outcome moved, never written again, so an ask survives the outcome moving on. `settledAt` is
-- when a completed trade settled the entry (`received` or `tradedAway`), and `got` (received only)
-- the `me` verdict frozen then (`{ verdict, ilvlDelta, scoreDelta, offSpec?, at }`; `{ at }` when
-- there was none), before equipping the item re-judges `me` against itself; nothing writes it
-- again. An entry settled before they existed has neither (a legacy entry), so WasAsked and
-- WasOffered read a settled trade with no `settledAt` as asked or offered; one asked or offered
-- before them and settled after gets its stamp back-filled at settling (the drop's `at`), since
-- settling overwrites the outcome that held it. Additive: `v` stays 1.
--
-- `rolls` is a group-loot drop's final roll table (Forever port design §5.4, DW-FP16), kept while
-- `rolls.keep` is on: `r` one row per player in NS.RollCells.Rows' order (the winner first),
-- at most ROLL_ROWS (a full raid), each its name, classFile (`class`), state number (`s`, 0 Need
-- to 5 Pass) and roll number (`n`, none for a pass or no roll); `w` the winner's place in `r`;
-- `n` every player who rolled, the rows cut or not; `at` (time()) when it was kept. No GUIDs.
-- RollTable reads it back as the plain roll table the roll cells draw (the History card, and the
-- drop FeedRestore rebuilds). It lands with the drop, or later on the DropUpdated of the merge
-- that attaches it. Additive: `v` stays 1.
--
-- HOW LONG IT IS KEPT (feedback-2 spec §5). By age, not by count: modules/HistoryRetention.lua
-- deletes the groups older than `global.history.retentionDays` (Keep history for, default 30 days).
-- Here, MAX_DROPS (50) drops per group and CEILING (5,000) drops in all, a safety ceiling that keeps
-- SavedVariables bounded even when nothing is deleted by age, the oldest dropped first.
--
-- THE SIMULATOR (simulator spec §5). While a simulation runs, the log is the simulation's own
-- session-only log (NS.SimHost.HistoryLog, modules/Sim.lua), never `global.history`: Log() answers it,
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
-- by the group's key and this session's start (NS.Session.Start: the login, kept by a reload,
-- feedback-15 spec §0), so a group of an earlier session never collects today's drops. DropUpdated
-- refreshes its verdicts and trade estimate, and its link, level and quality when a merge or the
-- bag read improved them (BUG-1); a trade estimate that turns `no expired` makes its outcome
-- `expired`. Which entry a live drop is lives in an index of this load (drop ids restart each
-- load). After a reload, modules/FeedRestore.lua rebuilds this session's drops and links each to
-- its entry (Adopt) before its DropAdded, so it is not recorded again and its DropUpdated
-- refreshes that entry; any other old entry is read-only.
--
-- THE OUTCOMES (spec §10): `seen` at first, `asked` when your ask is sent (AskStateChanged `sent`,
-- kind `ask`), `offered` when your offer or announce is, `expired`, `received` and `tradedAway`
-- from a completed trade, and `declined`, set by hand from a History row's menu. An automatic
-- outcome only moves forward (seen, then asked or offered, then expired, then received or traded
-- away); `declined` is the player's and stands until they clear it, unless a trade then completes.
-- One exception (feedback-15 spec §0): a trade estimate `yes` on the trade timer's own read (basis
-- `timer`) puts an `expired` back to the outcome it replaced (`beforeExpired`; `seen` for an entry
-- expired before that field existed). A rule estimate never does.
--
-- TRADE COMPLETION (spec §10). TRADE_SHOW opens a trade with its partner (TradePartnerName); every
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
-- PURE: Normalize, Snapshot, Refresh, RollTable, Record, Trim, Advance, SetDeclined, Stamp, Settle,
-- WasAsked, WasOffered and MatchTrade take plain
-- tables and the clock as arguments and read nothing else but the pure link parse
-- (NS.ItemRead.BetterLink) and the pure roll rows (NS.RollCells.Rows); test_history and test_item_read drive them. The edge
-- below reads the account table, the feed and the bus, and sends HistoryChanged on every change
-- to what it stores, never for a DropUpdated that changed nothing kept.

NS.History = NS.History or {}
local H = NS.History
local L = NS.L

local TAG = "FEED"

H.VERSION = 1
H.MAX_DROPS = 50
H.CEILING = 5000
H.ROLL_ROWS = 40   -- the roll rows an entry keeps: a full raid

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

-- An off-spec part (feedback-19 spec §1), kept as small: the spec, the main spec, the verdict and
-- its difference; no baseline and no reasons.
local function offSnap(eval)
    local off = NS.OffSpec.Of(eval)
    if not off then return nil end
    return { specID = num(off.specID), mainSpecID = num(off.mainSpecID), verdict = off.verdict, ilvlDelta = num(off.ilvlDelta) }
end

-- A verdict, kept small: the verdict and its deltas, nothing that names a frame or a table.
-- A collection verdict's part (issue #13): its flag, category, a pet's count and limit (plain
-- numbers only) and the one reason a cell names, a recipe of a profession you lack.
local function collectSnap(snap, eval)
    if eval.collect ~= true then return snap end
    snap.collect, snap.count, snap.limit = true, num(eval.count), num(eval.limit)
    snap.category = type(eval.category) == "string" and eval.category or nil
    for _, r in ipairs(type(eval.reasons) == "table" and eval.reasons or {}) do
        if r.key == "notYourProfession" then snap.reasonKey = r.key end
    end
    return snap
end

local function verdictSnap(eval)
    if type(eval) ~= "table" or type(eval.verdict) ~= "string" then return nil end
    return collectSnap({ verdict = eval.verdict, ilvlDelta = num(eval.ilvlDelta), scoreDelta = num(eval.scoreDelta),
        offSpec = offSnap(eval) }, eval)
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

-- The drop's item kind: its own, else Other loot for an item of no kind the catch-all let in (its
-- verdict's `other`, RX-04), else Watched item for one the Always watch list let in with none (a
-- forced drop, or its collection verdict), so Insights never files it as an entry from before #13.
local function categoryOf(rec, facts)
    if type(facts.category) == "string" then return facts.category end
    local me = rec.me
    if rec.forced ~= true and type(me) == "table" and me.category == "other" then return "other" end
    if rec.forced == true or (type(me) == "table" and me.collect == true) then return NS.Constants.CATEGORY_WATCHED end
    return nil
end

local function itemIDOf(rec)
    if num(rec.itemID) then return rec.itemID end
    return type(rec.link) == "string" and tonumber(rec.link:match("item:(%d+)")) or nil
end

-- ── the kept roll table (Forever port design §5.4) ─────────────────────────────────────────

-- The winner's place among the kept rows: the row Blizzard marks, else the one named `winner`.
local function winnerAt(rows, winner)
    for i, r in ipairs(rows) do
        if r.winner then return i end
    end
    local name = type(winner) == "table" and winner.name or nil
    for i, r in ipairs(rows) do
        if name and r.name == name then return i end
    end
    return nil
end

-- A plain roll table, kept compact: the rows in the roll cells' order (the winner first), cut at
-- ROLL_ROWS, with no GUIDs. `count` is a restored table's own tally of every roller.
local function rollSnap(roll, now)
    local rows = NS.RollCells.Rows(roll)
    local r = {}
    for i = 1, math.min(#rows, H.ROLL_ROWS) do
        local x = rows[i]
        r[i] = { name = x.name ~= "?" and x.name or nil, class = x.classFile, s = x.state, n = x.roll }
    end
    local w = winnerAt(rows, roll.winner)
    if w and w > #r then w = nil end
    local n = math.max(#(type(roll.rolls) == "table" and roll.rolls or {}), num(roll.count) or 0)
    return { at = now, allPassed = roll.allPassed == true, n = n, w = w, r = r }
end

local function sameRow(x, y) return x.name == y.name and x.class == y.class and x.s == y.s and x.n == y.n end

-- Two kept roll tables say the same (their `at` aside).
local function sameRolls(a, b)
    if a == nil or b == nil then return a == b end
    if a.allPassed ~= b.allPassed or a.n ~= b.n or a.w ~= b.w or #a.r ~= #b.r then return false end
    for i, x in ipairs(a.r) do
        if not sameRow(x, b.r[i]) then return false end
    end
    return true
end

-- The record's roll table into the entry while rolls are kept (`now` given, `keep` not false); a
-- roll never un-happens, so a record with none leaves the kept one. Answers whether it moved.
local function takeRolls(e, rec, now, keep)
    if keep == false or not num(now) or type(rec.roll) ~= "table" then return false end
    local snap = rollSnap(rec.roll, now)
    if sameRolls(e.rolls, snap) then return false end
    e.rolls = snap
    return true
end

--- A kept roll table read back as the plain roll table NS.RollCells draws: { allPassed, count,
--- winner = { name, classFile, roll }, rolls = { { name, classFile, state, roll, isWinner } } },
--- or nil with none kept.
--- @param rolls table|nil an entry's `rolls`
--- @return table|nil
function H.RollTable(rolls)
    if type(rolls) ~= "table" or type(rolls.r) ~= "table" then return nil end
    local out = { allPassed = rolls.allPassed == true, count = num(rolls.n), rolls = {} }
    for i, x in ipairs(rolls.r) do
        if type(x) == "table" then
            out.rolls[#out.rolls + 1] = { name = type(x.name) == "string" and x.name or nil,
                classFile = type(x.class) == "string" and x.class or nil, state = num(x.s), roll = num(x.n),
                isWinner = i == rolls.w }
        end
    end
    local w = out.rolls[num(rolls.w) or 0]
    if w and w.isWinner then out.winner = { name = w.name, classFile = w.classFile, roll = w.roll } end
    return out
end

--- One entry from a feed drop record, its outcome `seen`; its roll table kept unless `keepRolls`
--- is false (`rolls.keep`).
--- @param rec table the feed's drop record
--- @param now number time()
--- @param keepRolls boolean|nil
--- @return table entry
function H.Snapshot(rec, now, keepRolls)
    local who = type(rec.looter) == "table" and rec.looter or {}
    local facts = type(rec.facts) == "table" and rec.facts or {}
    local e = {
        itemLink = rec.link, itemID = itemIDOf(rec), looter = who.name, class = who.classFile,
        isMine = rec.isMine == true or nil, ilvl = num(facts.ilvl), equipLoc = facts.equipLoc,
        category = categoryOf(rec, facts),
        tokenSlot = type(facts.tokenSlot) == "string" and facts.tokenSlot or nil,
        tokenUsers = type(facts.tokenUsers) == "string" and facts.tokenUsers or nil,
        quality = num(facts.quality), outcome = "seen", at = now, sim = rec.sim == true or nil,
        seenBy = rec.seenBy, seenByClass = rec.seenByClass,
    }
    H.Refresh(e, rec, now, keepRolls)
    return e
end

--- Advance an entry's outcome: only forward (H.RANK), so `asked` never undoes `expired`. An
--- advance to `expired` keeps the outcome it replaced in `beforeExpired` (Refresh's undo).
--- @param e table
--- @param outcome string
--- @return boolean changed
function H.Advance(e, outcome)
    local to, from = H.RANK[outcome], H.RANK[e.outcome] or 0
    if not to or to <= from then return false end
    e.beforeExpired = outcome == "expired" and (e.outcome or "seen") or nil
    e.outcome, e.before = outcome, nil
    return true
end

-- A false Expired undone (feedback-15 spec §0): the trade timer reads the drop live (`yes`, basis
-- `timer`), so the outcome returns to the one `expired` replaced. A hand-set outcome is untouched.
local function unexpire(e)
    local t = e.trade
    if e.outcome ~= "expired" or not (t and t.state == "yes" and t.basis == "timer") then return false end
    e.outcome, e.beforeExpired = e.beforeExpired or "seen", nil
    return true
end

-- Two snapshots (verdictSnap, tradeSnap, or nil) hold the same values: one level of fields, and
-- the args list and the off-spec part one level deeper.
local DEEPER = { args = true, offSpec = true }
local function sameSnap(a, b)
    if a == nil or b == nil then return a == b end
    for k, v in pairs(a) do
        if DEEPER[k] then
            if not sameSnap(v, b[k]) then return false end
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

local function takeSnaps(e, rec, now, keepRolls)
    local me, them, trade = verdictSnap(rec.me), verdictSnap(rec.them), tradeSnap(rec.trade)
    local moved = not (sameSnap(e.me, me) and sameSnap(e.them, them) and sameSnap(e.trade, trade))
    e.me, e.them, e.trade = me, them, trade
    moved = takeRolls(e, rec, now, keepRolls) or moved
    return takeItem(e, rec) or moved
end

--- Take a drop record's latest verdicts, trade estimate, more complete link, level and quality,
--- and its roll table when `now` is given and `keepRolls` is not false (the table stamped `now`
--- when it lands or changes); a trade gone `no expired` makes the outcome `expired` (H.Advance),
--- and the trade timer's live `yes` puts back the outcome it replaced (feedback-15 spec §0).
--- @param e table
--- @param rec table
--- @param now number|nil time()
--- @param keepRolls boolean|nil
--- @return boolean outcomeChanged
--- @return boolean changed whether anything stored changed (the snapshots, the rolls or the outcome)
function H.Refresh(e, rec, now, keepRolls)
    local moved = takeSnaps(e, rec, now, keepRolls)
    local t = e.trade
    local advanced = t ~= nil and t.state == "no" and t.reasonKey == "expired" and H.Advance(e, "expired")
    advanced = advanced or unexpire(e)
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

local STAMP = { ask = "askedAt", offer = "offeredAt", announce = "offeredAt", askML = "askedAt" }

--- Stamp when an ask (kind `ask`, or the master-loot `askML`) or an offer (`offer`, `announce`) was
--- first sent; a later send never moves it.
--- @param e table
--- @param kind string
--- @param now number time()
--- @return boolean stamped
function H.Stamp(e, kind, now)
    local key = STAMP[kind]
    if not key or e[key] ~= nil then return false end
    e[key] = now
    return true
end

-- A copy of the `me` snapshot (its off-spec part copied too), stamped `at`.
local function frozen(me, now)
    local got = {}
    for k, v in pairs(type(me) == "table" and me or {}) do got[k] = v end
    if type(got.offSpec) == "table" then
        local off = {}
        for k, v in pairs(got.offSpec) do off[k] = v end
        got.offSpec = off
    end
    got.at = now
    return got
end

-- Whether a record of `outcome` is in the entry: now, or the one an `expired` or a hand-set
-- `declined` replaced.
local function held(e, outcome)
    return e.outcome == outcome or e.beforeExpired == outcome or e.before == outcome
end

-- Settling overwrites the held outcome, so an ask or offer held only there (an entry from before the
-- stamps) is stamped first, at the drop's own time: it stays asked or offered once settled.
local function keepSent(e, now)
    local at = type(e.at) == "number" and e.at or now
    if e.askedAt == nil and held(e, "asked") then e.askedAt = at end
    if e.offeredAt == nil and held(e, "offered") then e.offeredAt = at end
end

--- A completed trade settles an entry: its outcome (`received` or `tradedAway`), `settledAt`, and
--- for `received` the `me` verdict frozen as `got` (once; see the header). An ask or offer held
--- only in the outcome it replaces is stamped first (at the drop's time), so it is still sent.
--- @param e table
--- @param outcome string
--- @param now number time()
function H.Settle(e, outcome, now)
    keepSent(e, now)
    e.outcome, e.before, e.settledAt = outcome, nil, now
    if outcome == "received" and e.got == nil then e.got = frozen(e.me, now) end
end

--- Whether your ask was sent for an entry: stamped, held (`asked` now or before an expiry or a
--- decline), or, on a legacy entry (no `settledAt`), someone else's drop you received.
--- @param e table
--- @return boolean
function H.WasAsked(e)
    if type(e) ~= "table" then return false end
    if e.askedAt ~= nil or held(e, "asked") then return true end
    return not e.isMine and e.outcome == "received" and e.settledAt == nil
end

--- Whether your offer or announce was sent for an entry: as WasAsked, the legacy case your own
--- drop traded away.
--- @param e table
--- @return boolean
function H.WasOffered(e)
    if type(e) ~= "table" then return false end
    if e.offeredAt ~= nil or held(e, "offered") then return true end
    return e.isMine == true and e.outcome == "tradedAway" and e.settledAt == nil
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
--- @param info table { key, label, kind, situation, instance, difficulty, seenBy, seenByClass, roster }
--- @param entry table H.Snapshot's
--- @param ceiling number|nil H.Trim's
--- @return table entry
function H.Record(hist, info, entry, ceiling)
    local g = findGroup(hist, info.key)
    if not g then
        g = { key = info.key, label = info.label, kind = info.kind, situation = info.situation, at = entry.at,
            instance = info.instance, difficulty = info.difficulty, seenBy = info.seenBy,
            seenByClass = info.seenByClass, drops = {} }
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

local index = {}        -- [live drop id] = its entry, this load only
local trade             -- the trade: { partner, accepted, given, received, offer, closedAt } or nil

local function clock() return time() end

-- Whether a drop's roll table is kept (Drops > Rolls > Keep rolls in History, `rolls.keep`).
local function keepRolls() return NS.Setting("rolls.keep") ~= false end

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
    local log = NS.Sim:IsActive() and NS.SimHost.HistoryLog()
    if log then return H.Normalize(log) end
    return H.Store()
end

--- The log a record or trade of this origin is written to: the running simulation's for a
--- simulated one (nil once it has stopped), the account's (H.Store) for a real one.
--- @param sim any the origin's `sim` flag
--- @return table|nil
function H.LogFor(sim)
    if not sim then return H.Store() end
    local log = NS.Sim:IsActive() and NS.SimHost.HistoryLog()
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

--- When this session started (time()): the login, kept across a reload (NS.Session.Start,
--- feedback-15 spec §0). Today's group keys carry it; the History tab's This session reads it.
--- @return number
function H.SessionStart()
    return NS.Session.Start()
end

--- The groups, oldest first (empty before the database exists). Read them, never write them.
--- @return table
function H.Groups()
    local hist = H.Log()
    return hist and hist.groups or {}
end

--- Link a live drop to its kept entry (modules/FeedRestore.lua, feedback-15 spec §0), before the
--- drop's DropAdded: OnDropAdded then records nothing, and DropUpdated refreshes this entry.
--- @param dropId any
--- @param e table the entry
function H.Adopt(dropId, e)
    if type(e) == "table" then index[dropId] = e end
end

--- A live drop's entry this session, or nil (never recorded, or since deleted).
--- @param dropId any
--- @return table|nil
function H.EntryOf(dropId)
    local e = index[dropId]
    if e and e.gone then return nil end
    return e
end

--- The live drop a kept entry is, this load: its id while the feed still holds it, else nil (the
--- History card's Show in Drops, feedback-15 spec §4).
--- @param e table the entry
--- @return any|nil
function H.DropOf(e)
    if type(e) ~= "table" or e.gone then return nil end
    for id, x in pairs(index) do
        if x == e and NS.LootFeed.Get(id) then return id end
    end
    return nil
end

--- A live drop's outcome this session, or nil.
--- @param dropId any
--- @return string|nil
function H.OutcomeOf(dropId)
    local e = H.EntryOf(dropId)
    return e and e.outcome
end

--- The Ask button's state once the history knows the drop was received (`traded`); `sent` when the
--- Asks book has nothing for it (`ready`) but its entry was asked for, as a drop restored after a
--- reload is (the book lives for one load, the entry across it: one ask per item per looter holds,
--- feedback-15 spec §0); else the state given (the Drops row and the detail card read it here).
--- @param drop table
--- @param state string|nil
--- @param reason any
--- @return string|nil state, any reason
function H.AskState(drop, state, reason)
    if type(drop) ~= "table" or drop.test then return state, reason end
    if H.OutcomeOf(drop.id) == "received" then return "traded" end
    local e = state == "ready" and H.EntryOf(drop.id)
    if e and H.WasAsked(e) then return "sent" end
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
        situation = rec.situation, roster = feedRoster(rec), instance = spec.instance,
        difficulty = spec.difficulty, seenBy = rec.seenBy, seenByClass = rec.seenByClass }
end

--- A feed group's roster grew between drops (modules/GroupRoster.lua): the History group it is
--- recorded under (in the running simulation's log while one runs, else the account's) takes the
--- newcomers. HistoryChanged when it did.
--- @param feedGroup table
--- @return boolean grown
function H.GrowRoster(feedGroup)
    local hist = H.LogFor(NS.Sim:IsActive())
    local g = hist and findGroup(hist, historyKey(feedGroup.key))
    if not g then return false end
    g.roster = g.roster or {}
    if not NS.GroupRoster.Merge(g.roster, feedGroup.roster) then return false end
    changed()
    return true
end

-- What a sent message makes an entry: an ask (or the master-loot ask) `asked`, an offer or an
-- announce `offered`.
local SENT_OUTCOME = { ask = "asked", offer = "offered", announce = "offered", askML = "asked" }

-- A drop that assigned a master-loot item you asked the master looter for (`rec.askedML`, plan
-- DW-FP19) is recorded asked and stamped as an ask is: the ask was filed against the pending item,
-- before the drop existed.
local function askedForML(e, rec)
    if rec.askedML ~= true then return end
    H.Stamp(e, "askML", clock())
    H.Advance(e, SENT_OUTCOME.askML)
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
    local e = H.Snapshot(rec, clock(), keepRolls())
    askedForML(e, rec)
    index[id] = H.Record(hist, groupInfo(rec), e)
    changed()
end

--- DropUpdated: refresh a recorded drop's verdicts and trade; HistoryChanged only when the stored
--- entry changed (an inspect, a score retry or a trade sweep often changes nothing it keeps).
--- @param id any
function H.OnDropUpdated(id)
    local e, rec = H.EntryOf(id), NS.LootFeed.Get(id)
    if not (e and rec) then return end
    local _, moved = H.Refresh(e, rec, clock(), keepRolls())
    if moved then changed() end
end

--- AskStateChanged: a sent ask is `asked`; a sent offer or announce `offered`. Either is stamped
--- (H.Stamp) even when the outcome does not move, and HistoryChanged follows either change. A
--- master-loot ask's id is a pending item's, never a drop's (the two stores' ids may meet): its drop
--- is recorded asked when it arrives (`askedML`), so it is skipped here.
function H.OnAskState(dropId, state, kind)
    if kind == "askML" then return end
    local e = H.EntryOf(dropId)
    if state ~= "sent" or not e or not SENT_OUTCOME[kind] then return end
    local stamped = H.Stamp(e, kind, clock())
    if H.Advance(e, SENT_OUTCOME[kind]) or stamped then changed() end
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

--- Empty the history (Settings › Window › Layout's Clear history, behind its confirmation). The
--- retention row stays.
function H.Clear()
    local hist = H.Log()
    if not hist then return end
    for _, g in ipairs(hist.groups) do markGone(g) end
    hist.groups = {}
    NS.Print(L["History cleared."])
    changed()
end

-- ── Clear history's confirmation (feedback-15 spec §3, DW-Q3) ───────────────────────────────
--
-- Here rather than in a window file: the settings row (settings/PageEditors.lua) asks for it, and
-- the History module is the one both the settings and the UI already depend on. Accepting clears
-- what Log() answers, so with test mode or a simulation on it is that session-only log.

H.CLEAR_POPUP = "DROPWATCHER_CLEAR_HISTORY"

local function ensureClearPopup()
    if StaticPopupDialogs[H.CLEAR_POPUP] then return end
    StaticPopupDialogs[H.CLEAR_POPUP] = {
        text = L["Clear the drop history on every character? This cannot be undone."],
        button1 = YES or "Yes", button2 = NO or "No",
        timeout = 0, whileDead = true, hideOnEscape = true,
        preferredIndex = 3,   -- clear of the slots Blizzard's own popups take first
        OnAccept = function() H.Clear() end,
    }
end

--- Clear history's button: asks first (a StaticPopup); the history is emptied only on Yes.
function H.AskClear()
    ensureClearPopup()
    StaticPopup_Show(H.CLEAR_POPUP)
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
        sim = NS.Sim:IsDelivering() or nil }
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
    local n, now = 0, clock()
    for _, m in ipairs(H.MatchTrade(hist, t)) do
        H.Settle(m.entry, m.outcome, now)
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
