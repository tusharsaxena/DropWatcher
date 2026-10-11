local _, NS = ...
-- modules/LootFeed.lua — the feed (design spec §3, §5.3, §6): every drop the group receives, merged
-- from three sources, grouped by encounter or run, gated, judged for you and for its looter, and
-- estimated for trade.
--
--   drop = { id, feed, link, itemID, qty, kind, bonusRoll, looter = { name, guid, classFile, isSelf },
--            isMine, at, situation, encounterID, groupKey, sources = { [source] = n }, source,
--            facts, me, them, inspect = { status, reason, at } | nil, trade, quality = { mode,
--            threshold, reason }, candidates = { [guid] = { guid, name, classFile, status, eval } },
--            test, sim (made while a simulation runs), scoreTries }
--
-- `facts` is the item facts cache's own table (read, never write); `me` and `them` are
-- NS.Evaluate's answers for you and for the looter (`them` nil until the looter's inspect read
-- exists, and always nil for your own drop); `trade` is NS.TradeRules' estimate; `candidates`,
-- for your own drops only, holds every other member's verdict (status `ready`, `checking` while
-- an inspect is queued, `unavailable` otherwise) for the Offer panel and the Best candidates
-- column. A drop's tables are the feed's own: read them, never write them.
--
-- THE SOURCES. CHAT_MSG_LOOT through the loot parser's sink (`chat`), ENCOUNTER_LOOT_RECEIVED
-- (`encounter`, which names the encounter) and C_LootHistory's won group-loot drops on
-- LOOT_HISTORY_UPDATE_DROP (`history`, each drop taken once). Your own `pushed` lines (quest
-- rewards, containers, purchases) are not drops and are skipped. Add(link, looter, opts) is the
-- fourth door (`manual`): `/dw add`. Test mode's placeholders come through AddTest(spec), put in
-- the test feed as given (modules/TestMode.lua).
--
-- DEDUPE. One drop is reported by up to all three sources. A receipt merges into a drop seen in
-- the last DEDUPE_WINDOW seconds with the same item id and the same looter (the same GUID; when
-- either side lacks one, the same name without its realm, ignoring case) that this source has not
-- already reported; anything else is a new drop, so two copies of one item from one source stay
-- two. A merge can teach the drop its looter's GUID, which then asks for their inspect, and keeps
-- the more complete link (NS.FeedRecords.PreferredLink, ui spec §0: a link without its bonus data
-- reads as the base item), reading the facts again from it. Manual and test drops never merge. The
-- matching and the record logic are modules/FeedRecords.lua's (pure).
--
-- GROUPING. ENCOUNTER_START / ENCOUNTER_END and CHALLENGE_MODE_START / CHALLENGE_MODE_COMPLETED keep
-- the context. Inside a keystone run, and for LOOT_GRACE seconds after it completes, every drop
-- joins the run's group (the chest included). Otherwise a drop joins the encounter it names, else
-- the encounter in progress or killed in the last LOOT_GRACE seconds (a wipe opens no loot window),
-- else the area's group: the instance's name, or "Open world", continued while it is the latest
-- group. Groups are made by their first drop, so no group is empty.
--
-- THE GATES, in spec §6.2's order: the situation (not tracked there: hidden, nothing loaded), the
-- item facts (loaded through ItemFacts.Request when uncached; the drop waits), spec §6.3's filters
-- (NS.FeedFilter.Filter, pure, modules/FeedFilter.lua), the verdict for you (your gear only),
-- the quality gate with that verdict for its upgrade override, then the inspect request for the
-- looter, the looter's verdict and the trade estimate. A hidden drop costs no inspect; it is counted by reason and logged once. Manual drops
-- skip the situation gate; test drops skip every gate and ask for no inspect.
--
-- UPDATES. InspectDone(guid) re-judges the drops that looter received and your own drops'
-- candidate of that GUID; GearChanged re-judges you on every drop (and your own drops' trade); a
-- scorer answering "pending" is retried on one shared SCORE_RETRY timer, SCORE_TRIES times per
-- drop; your own drop the trade timer matched to its bag item is read from it on each
-- TradeTimerTick (ReadBagItems: the exact level and quality). Each sends DropUpdated(id, cause):
-- `source`, `inspect`, `gear`, `score` or `bag`. A new drop sends DropAdded(id). Updates re-judge
-- the verdicts and the trade only: a drop once shown stays shown.
-- Test drops are never updated.
--
-- THE TRADE OVER TIME. The estimate is made again at read time's pace: one shared ticker, every
-- TRADE_SWEEP seconds while a live drop's trade is not `no`, re-estimates every drop (so a drop past
-- its rule's window turns `no expired`), and each TradeTimerTick re-estimates your own drops. Your
-- own drop's estimate folds in the trade timer's exact read (spec §7.1's `timer` basis): `yes` with
-- `expiresAt` while its countdown is live, `no expired` once the timer saw it gone; a BoE entry (no
-- window) and the bind checks keep the rule's answer. A changed estimate sends DropUpdated(id,
-- `trade`); your own drop moving off `no` asks for its candidates' inspects then.
--
-- Each feed (live and test) keeps MAX_DROPS drops, the oldest dropped first. Stood down, the
-- timers and the pending loads are dropped with the dedupe window and the encounter context; the
-- drops recorded so far are kept for the session, and the stand-up's GearChanged re-judges them.
--
-- REMOVAL. A drop leaves a feed only through Clear (`/dw clear`, clear on boss kill, the end of
-- test mode), RemoveWhere (the simulator's stop takes its `sim` drops) or the cap's trim. Each tells the removal sinks (AddRemovalSink, the loot parser's
-- AddSink shape) with the feed's name, so a view of one drop (the toast) can let it go. A sink is
-- called under pcall: its error never stops the feed.

NS.LootFeed = NS.LootFeed or {}
local LF = NS.LootFeed
local C = NS.Constants
local L = NS.L
local State = NS.State
local Perf = NS.Perf

local TAG = "FEED"

LF.DEDUPE_WINDOW = 120
LF.LOOT_GRACE = 120
LF.MAX_DROPS = 200
LF.SCORE_RETRY = 1
LF.SCORE_TRIES = 5
LF.TRADE_SWEEP = 30

local timers = {}

local removalSinks = {}

-- Bumped at every stand-down: an item load answering after it is ignored.
local generation = 0

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function newFeed()
    return { drops = {}, byId = {}, groups = {}, groupByKey = {} }
end

local function store()
    local s = State.feed
    if not s then
        s = { seq = 0, live = newFeed(), test = newFeed(), recent = {}, ctx = {}, names = {},
            history = {}, merged = 0, hidden = {} }
        State.feed = s
    end
    return s
end

local function plainString(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

local function plainNumber(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function send(msg, id, cause)
    NS.addon:SendMessage(msg, id, cause)
end

-- ── the settings ────────────────────────────────────────────────────────────────────────────

-- One setting, through the schema seam (NS.Setting): the stored value, or its default.
local function get(path) return NS.Setting(path) end

-- The per-situation trade rules (`trade.rules.<situation>`) as the map TradeRules reads.
local function tradeRules()
    local rules = {}
    for _, s in ipairs(C.SITUATIONS) do rules[s.key] = get("trade.rules." .. s.key) end
    return rules
end

--- The settings the feed reads: `feed.*`, `comparison.*` and `trade.rules.*`, each through the
--- schema seam (`feed.clearOnBossKill` is read at each kill instead).
--- @return table cfg
function LF.Config()
    return {
        gearOnly = get("feed.gearOnly"), includeTokens = get("feed.includeTokens"),
        minIlvlMode = get("feed.minIlvlMode"), minIlvl = get("feed.minIlvl"),
        relativeIlvl = get("feed.relativeIlvl"),
        qualityMode = get("feed.quality.mode"), fixed = get("feed.quality.fixed"),
        floor = get("feed.quality.floor"), upgradeOverride = get("feed.quality.upgradeOverride"),
        sidegradeBand = get("comparison.sidegradeBand"), compareOwned = get("comparison.compareOwned"),
        undesired = get("comparison.undesired"), heirloomProtect = get("comparison.heirloomProtect"),
        rules = tradeRules(),
    }
end

-- ── looters ─────────────────────────────────────────────────────────────────────────────────

-- A looter as the roster knows them, else as the source named them.
local function resolveLooter(name, guid, classFile)
    local m = (guid and NS.Roster.Get(guid)) or (name and NS.Roster.Resolve(name, classFile))
    if m then
        return { name = m.fullName or m.name, guid = m.guid, classFile = m.classFile, isSelf = m.isPlayer == true }
    end
    return { name = name, guid = guid, classFile = classFile, isSelf = false }
end

local function you()
    local me = NS.Roster.Player()
    if me then return resolveLooter(nil, me.guid) end
    return { name = plainString(NS.Compat.UnitName("player")), isSelf = true }
end

-- ── grouping ────────────────────────────────────────────────────────────────────────────────

local function now() return GetTime() end

local function encounterLabel(s, id)
    return (id and s.names[id]) or (id and L["Encounter %s"]:format(id)) or L["Encounter"]
end

local function areaName()
    if NS.Compat.InstanceState() then
        local name = plainString((NS.Compat.InstanceInfo()))
        if name then return name end
    end
    return L["Open world"]
end

-- Where a drop received now belongs: { key, label, kind, encounterID, mapID }.
local function groupSpec(s, encounterID, t)
    local run = NS.FeedRecords.ActiveRun(s.ctx, t, LF.LOOT_GRACE)
    if run then return { key = run.key, label = run.label, kind = "run", mapID = run.mapID } end
    local enc = NS.FeedRecords.ActiveEncounter(s.ctx, t, LF.LOOT_GRACE)
    if encounterID and not (enc and enc.id == encounterID) then
        return { key = "enc:" .. encounterID, label = encounterLabel(s, encounterID), kind = "encounter",
            encounterID = encounterID }
    end
    if enc then return { key = enc.key, label = enc.label, kind = "encounter", encounterID = enc.id } end
    local area = areaName()
    return { key = "area:" .. area, label = area, kind = "area" }
end

-- ── judging ─────────────────────────────────────────────────────────────────────────────────

local function scorer()
    local S = NS.Scoring
    if type(S) == "table" and type(S.Scorer) == "function" then return S.Scorer() end
    return nil
end

local function evalOpts(cfg)
    return { sidegradeBand = cfg.sidegradeBand, compareOwned = cfg.compareOwned, scorer = scorer() }
end

local function evaluate(facts, candidate, opts)
    local t0 = Perf.on and debugprofilestop()
    local out = NS.Evaluate.Evaluate(facts, candidate, opts)
    if t0 then Perf.Note("evaluate", debugprofilestop() - t0) end
    return out
end

-- Your candidate, with the item types you do not want for your spec.
local function myCandidate(cfg)
    local cand = NS.Gear.Candidate()
    local undesired = cfg.undesired and cand.specID and cfg.undesired[cand.specID]
    if type(undesired) == "table" then cand.prefs = { undesired = undesired } end
    return cand
end

-- Heirloom protection (`comparison.heirloomProtect`) is yours alone: a looter's heirloom slot is
-- judged plainly, so a real upgrade for them never reads as one they would give away.
local function judgeMe(rec, cfg)
    local opts = evalOpts(cfg)
    opts.heirloomProtect = cfg.heirloomProtect == true
    rec.me = evaluate(rec.facts, myCandidate(cfg), opts)
end

-- Your average equipped item level (shirt and tabard aside), or nil.
local function myIlvl()
    local sum, n = 0, 0
    for slot, e in pairs(NS.Gear.Snapshot().equipped) do
        if e and type(e.ilvl) == "number" and not C.QUALITY_IGNORED_SLOT[slot] then
            sum, n = sum + e.ilvl, n + 1
        end
    end
    if n == 0 then return nil end
    return sum / n
end

local function qualityGate(rec, cfg)
    local t0 = Perf.on and debugprofilestop()
    local QG, f = NS.QualityGate, rec.facts or {}
    local mode = QG.ResolveMode(cfg.qualityMode, NS.Situations.QualityOverride(rec.situation))
    local ctx = { fixed = cfg.fixed, floor = cfg.floor, upgradeOverride = cfg.upgradeOverride,
        gear = NS.Gear.Qualities(), baselineSlot = rec.me.baselineSlot, equipLoc = f.equipLoc,
        verdict = rec.me.verdict }
    local pass, threshold, reason = QG.Passes(f.quality, mode, ctx)
    rec.quality = { mode = mode, threshold = threshold, reason = reason }
    if t0 then Perf.Note("quality.gate", debugprofilestop() - t0) end
    return pass
end

local CHECKING = { pending = true, combatParked = true }

-- The looter's inspect as the drop shows it.
local function inspectState(guid)
    if not (guid and NS.Roster.Get(guid)) then return { status = "unavailable", reason = "notInGroup" } end
    local e = NS.Inspect.Get(guid)
    if not e then return { status = "pending" } end
    return { status = e.status, reason = e.reason, at = e.at }
end

local function estimate(rec, looterEval, cfg, insp)
    local f = rec.facts
    local facts = f and { ilvl = f.ilvl, bindType = f.bindType, warbound = f.warbound, bonusRoll = rec.bonusRoll }
    local t = now()
    local ctx = { situation = rec.situation, rules = cfg.rules, now = t, droppedAt = rec.at }
    if insp then
        if looterEval then
            ctx.inspectAge = insp.at and t - insp.at
        else
            ctx.inspectReason = insp.reason or insp.status
        end
    end
    rec.trade = LF.FoldTimer(rec, NS.TradeRules.Estimate(facts, looterEval, ctx))
end

--- Your own drop's estimate with the trade timer's exact read folded in (spec §7.1): `yes`
--- (`timer`, with `expiresAt` and the seconds left) while its countdown is live, `no expired`
--- (`timer`) once the timer read its window as gone. The rule's estimate stands for anyone else's
--- drop, a test drop, a bind answer (warbound, bonus roll, BoE), a drop no bag item has matched,
--- and a BoE entry, which has no window.
--- @param rec table the drop
--- @param est table NS.TradeRules.Estimate's answer
--- @return table
function LF.FoldTimer(rec, est)
    local TT = NS.TradeTimer
    if not (rec.isMine and not rec.test and TT and est.basis ~= "bind") then return est end
    local e = TT.ForDrop(rec.id)
    if not e or e.permanent then return est end
    if e.expired then
        return { state = "no", reasonKey = "expired", basis = "timer", args = {}, rule = est.rule }
    end
    if not e.expiresAt then return est end
    return { state = "yes", reasonKey = "timer", basis = "timer", args = { TT.Remaining(e) },
        expiresAt = e.expiresAt, rule = est.rule }
end

-- One other member, judged for your own drop.
local function candidateEntry(rec, m, cfg, ask)
    if ask then NS.Inspect.Request(m.guid, NS.Inspect.PRIORITY.offer) end
    local e = { guid = m.guid, name = m.fullName or m.name, classFile = m.classFile }
    local cand = NS.Inspect.Candidate(m.guid)
    if cand then
        e.status, e.eval = "ready", evaluate(rec.facts, cand, evalOpts(cfg))
        return e
    end
    local entry = NS.Inspect.Get(m.guid)
    e.status = CHECKING[entry and entry.status] and "checking" or "unavailable"
    return e
end

-- Your own drop: every other member judged; their inspects asked for only while it may trade.
local function judgeCandidates(rec, cfg, request)
    local ask = request and not rec.test and rec.trade.state ~= "no"
    local out = {}
    for _, m in ipairs(NS.Roster.Members()) do
        if not m.isPlayer and m.guid then out[m.guid] = candidateEntry(rec, m, cfg, ask) end
    end
    rec.candidates = out
end

-- The looter's side: their verdict and the trade estimate (yours, for your own drop). `request`
-- asks for the inspects the drop needs; a re-judge never does, so a failed inspect is not re-queued
-- by its own InspectDone.
local function judgeLooter(rec, cfg, request)
    if rec.isMine then
        estimate(rec, rec.me, cfg, nil)
        return judgeCandidates(rec, cfg, request)
    end
    local guid = rec.looter.guid
    local inGroup = guid and NS.Roster.Get(guid) ~= nil
    if request and inGroup and not rec.test then NS.Inspect.Request(guid, NS.Inspect.PRIORITY.looter) end
    rec.inspect = inspectState(guid)
    local cand = inGroup and NS.Inspect.Candidate(guid) or nil
    rec.them = cand and evaluate(rec.facts, cand, evalOpts(cfg)) or nil
    estimate(rec, rec.them, cfg, rec.inspect)
end

-- ── the score retry ─────────────────────────────────────────────────────────────────────────

local function scorePending(rec) return NS.FeedRecords.ScorePending(rec) end

local retryScores

local function armScoreRetry()
    if timers.score or stoodDown() then return end
    timers.score = C_Timer.NewTimer(LF.SCORE_RETRY, function()
        timers.score = nil
        retryScores()
    end)
end

-- A drop's first pending score starts its retries; a drop that has used them up keeps its answer.
local function notePending(rec)
    if rec.test or rec.scoreTries ~= nil or not scorePending(rec) then return end
    rec.scoreTries = 0
    NS.Debug("SCORE", "drop %s: the scorer is not ready, retrying up to %d times", rec.id, LF.SCORE_TRIES)
    armScoreRetry()
end

retryScores = function()
    local cfg, again, n = LF.Config(), false, 0
    for _, rec in ipairs(store().live.drops) do
        if rec.scoreTries and rec.scoreTries < LF.SCORE_TRIES then
            rec.scoreTries = rec.scoreTries + 1
            n = n + 1
            judgeMe(rec, cfg)
            judgeLooter(rec, cfg, false)
            if scorePending(rec) and rec.scoreTries < LF.SCORE_TRIES then again = true end
            send(NS.MSG.DROP_UPDATED, rec.id, "score")
        end
    end
    NS.Debug("SCORE", "score retry: %d drops re-scored, still pending=%s", n, again)
    if again then armScoreRetry() end
end

-- ── the trade over time ─────────────────────────────────────────────────────────────────────

-- One drop's trade made again; true when it moved. Your own drop moving off `no` asks for its
-- candidates' inspects (they were skipped while it could not trade).
local function reestimate(rec, cfg)
    local old = rec.trade
    if rec.isMine then estimate(rec, rec.me, cfg, nil) else estimate(rec, rec.them, cfg, rec.inspect) end
    if NS.FeedRecords.SameTrade(old, rec.trade) then return false end
    if rec.isMine and old and old.state == "no" and rec.trade.state ~= "no" then
        judgeCandidates(rec, cfg, true)
    end
    return true
end

local function mayChange(rec)
    return not rec.test and rec.trade ~= nil and (rec.isMine or rec.trade.state ~= "no")
end

--- Re-estimate the live drops' trade (your own only, with `mineOnly`), sending DropUpdated(id,
--- `trade`) for each that moved. Answers how many moved.
--- @param mineOnly boolean|nil
--- @return number
function LF.SweepTrade(mineOnly)
    if stoodDown() then return 0 end
    local cfg, n = LF.Config(), 0
    for _, rec in ipairs(store().live.drops) do
        if mayChange(rec) and (rec.isMine or not mineOnly) and reestimate(rec, cfg) then
            n = n + 1
            send(NS.MSG.DROP_UPDATED, rec.id, "trade")
        end
    end
    return n
end

-- Whether any live drop's trade may still move (a group drop not yet `no`).
local function sweepWanted()
    for _, rec in ipairs(store().live.drops) do
        if mayChange(rec) and not rec.isMine then return true end
    end
    return false
end

local function stopSweep()
    if timers.sweep then timers.sweep:Cancel() end
    timers.sweep = nil
end

--- Start the shared trade sweep when a live drop needs it and none runs; it stops itself once
--- every group drop's trade is `no`.
function LF.ArmTradeSweep()
    if timers.sweep or stoodDown() or not sweepWanted() then return end
    timers.sweep = C_Timer.NewTicker(LF.TRADE_SWEEP, function()
        LF.SweepTrade(false)
        if not sweepWanted() then stopSweep() end
    end)
end

-- ── the records ─────────────────────────────────────────────────────────────────────────────

local function feedOf(rec)
    return store()[rec.feed]
end

--- Be told `fn(feedName)` whenever drops leave a feed: a Clear, a RemoveWhere, or the cap's trim.
--- @param fn function
function LF.AddRemovalSink(fn)
    removalSinks[#removalSinks + 1] = fn
end

local function notifyRemoved(name)
    for _, fn in ipairs(removalSinks) do
        local ok, err = pcall(fn, name)
        if not ok then NS.Debug(TAG, "removal sink failed: %s", NS.SafeToString(err)) end
    end
end

local function verdictOf(eval) return eval and eval.verdict or "-" end

local function add(rec)
    local feed = feedOf(rec)
    local g = NS.FeedRecords.Materialize(feed, rec)
    rec.state, rec.groupKey = "added", g.key
    g.drops[#g.drops + 1] = rec.id
    feed.drops[#feed.drops + 1] = rec
    feed.byId[rec.id] = rec
    local trimmed = #feed.drops > LF.MAX_DROPS
    while #feed.drops > LF.MAX_DROPS do NS.FeedRecords.RemoveAt(feed, 1) end
    if trimmed then notifyRemoved(rec.feed) end
    notePending(rec)
    if not rec.test then LF.ArmTradeSweep() end
    NS.Debug(TAG, "drop %s: %s by %s (%s) in %s: me=%s them=%s trade=%s", rec.id, rec.link,
        tostring(rec.looter.name), rec.source, g.label, verdictOf(rec.me), verdictOf(rec.them),
        tostring(rec.trade and rec.trade.state))
    send(NS.MSG.DROP_ADDED, rec.id)
    return rec.id, "added"
end

local function hide(rec, why)
    rec.state, rec.hidden = "hidden", why
    local s = store()
    s.hidden[why] = (s.hidden[why] or 0) + 1
    if why == "quality" then
        local q = rec.quality
        NS.Debug("QUAL", "hidden %s: quality %s below %s (%s, %s)", rec.link,
            tostring(rec.facts and rec.facts.quality), tostring(q.threshold), q.mode, q.reason)
    else
        NS.Debug(TAG, "hidden %s by %s: %s", rec.link, tostring(rec.looter.name), why)
    end
    return nil, why
end

local start

-- The gates after the facts are in (or given up on), then the looter's side.
local function judge(rec, facts)
    rec.facts = facts
    local cfg = LF.Config()
    if not rec.test then
        local ctx = { myIlvl = cfg.minIlvlMode == "relative" and myIlvl() or nil }
        local ok, why = NS.FeedFilter.Filter(facts, cfg, ctx)
        if not ok then return hide(rec, why) end
    end
    judgeMe(rec, cfg)
    if not rec.test and not qualityGate(rec, cfg) then return hide(rec, "quality") end
    judgeLooter(rec, cfg, true)
    return add(rec)
end

start = function(rec)
    if not (rec.test or rec.force) and not NS.Situations.IsTracking(rec.situation) then
        return hide(rec, "notTracking")
    end
    local gen, link = generation, rec.link
    local facts, status = NS.ItemFacts.Request(link, function(f)
        if gen ~= generation or stoodDown() then return end
        if rec.link ~= link then return start(rec) end   -- a more complete link merged in meanwhile
        judge(rec, f)
    end)
    if status == "loading" then
        rec.state = "loading"
        return rec.id, "loading"
    end
    return judge(rec, facts)
end

-- Simulated only while Sim.Fire delivers (spec §5); a real drop during a sim keeps the real situation.
local function origin()
    local Sim, Sit = NS.Sim, NS.Situations
    if Sim.delivering or not Sim.active then return Sim.delivering or nil, Sit.Current() end
    return nil, Sim.Live(function() return Sit.Classify(Sit.ReadInputs()) end)
end

local function newRecord(s, r)
    s.seq = s.seq + 1
    local t = now()
    local sim, situation = origin()
    return {
        id = s.seq, feed = r.test and "test" or "live", test = r.test, force = r.force, link = r.link,
        itemID = r.itemID, qty = r.qty or 1, kind = r.kind or "loot", bonusRoll = r.kind == "bonus",
        looter = r.looter, isMine = r.looter.isSelf == true, at = t, situation = situation,
        encounterID = r.encounterID, sources = { [r.source] = 1 }, source = r.source,
        group = groupSpec(s, r.encounterID, t), state = "new", sim = sim,
    }
end

-- ── dedupe ──────────────────────────────────────────────────────────────────────────────────

local function prune(s)
    local cutoff, keep = now() - LF.DEDUPE_WINDOW, {}
    for _, rec in ipairs(s.recent) do
        if rec.at >= cutoff then keep[#keep + 1] = rec end
    end
    s.recent = keep
end

-- A hidden drop whose link changed (a more complete one merged in) runs the gates again on it, its
-- hidden count given back. A loading one loads the new link (start's callback); a shown one is
-- re-judged (LF.Refresh).
local function rerun(rec)
    local s = store()
    s.hidden[rec.hidden] = (s.hidden[rec.hidden] or 1) - 1
    rec.hidden = nil
    return start(rec)
end

-- What a second source adds: its count, the looter's GUID, the encounter when missing, and its link
-- when more complete (ui spec §0, BUG-1).
local function merge(rec, r)
    local s = store()
    s.merged = s.merged + 1
    rec.sources[r.source] = 1
    local learned = not rec.looter.guid and r.looter.guid ~= nil
    if learned then rec.looter = r.looter end
    rec.encounterID = rec.encounterID or r.encounterID
    local link = NS.FeedRecords.PreferredLink(rec.link, r.link, r.source)
    local relinked = link ~= rec.link
    rec.link = link
    NS.Debug(TAG, "drop %s: %s also reported by %s%s", rec.id, rec.link, r.source,
        relinked and " (its more complete link taken)" or "")
    if relinked and rec.state == "hidden" then
        rerun(rec)
        return rec.id, "merged"
    end
    if rec.state ~= "added" then return rec.id, "merged" end
    local cfg = LF.Config()
    if learned then judgeLooter(rec, cfg, true) end
    if relinked then return rec.id, LF.Refresh(rec, "source") end
    notePending(rec)
    send(NS.MSG.DROP_UPDATED, rec.id, "source")
    return rec.id, "merged"
end

local function validItem(link)
    link = plainString(link)
    if not link or not link:find("|Hitem:", 1, true) then return nil end
    return link, NS.Item.ItemIDFromLink(link)
end

-- One receipt: { link, qty, kind, source, looter, encounterID, force, test }.
local function receive(r)
    if stoodDown() then return nil, "stoodDown" end
    local link, itemID = validItem(r.link)
    if not itemID or type(r.looter) ~= "table" then return nil, "notItem" end
    r.link, r.itemID = link, itemID
    local s = store()
    prune(s)
    if r.source ~= "manual" then
        local hit = NS.FeedRecords.FindRecent(s.recent, r)
        if hit then return merge(hit, r) end
    end
    local rec = newRecord(s, r)
    if not rec.test and not rec.force then s.recent[#s.recent + 1] = rec end
    return start(rec)
end

--- Take one receipt into the feed. Answers the drop's id and `added`, `loading` (its item facts
--- are loading; DropAdded follows once it passes) or `merged`; or nil and why not (`stoodDown`,
--- `notItem`, `notTracking`, a filter's reason, or `quality`).
--- @param r table { link, qty, kind, source, looter = { name, guid, classFile, isSelf }, encounterID }
--- @return number|nil id, string status
function LF.Receive(r)
    local t0 = Perf.on and debugprofilestop()
    local id, status = receive(r)
    if t0 then Perf.Note("feed.add", debugprofilestop() - t0) end
    return id, status
end

--- Inject a drop: `/dw add` and test mode. `looter` is a name, "Name-Realm" or GUID (you when nil);
--- one the roster cannot place is judged without an inspect. A manual drop skips the situation
--- gate and never merges; `opts.test` puts it in the test feed and skips every gate and inspect.
--- @param link string
--- @param looter string|nil
--- @param opts table|nil { test }
--- @return number|nil id, string status (as Receive)
function LF.Add(link, looter, opts)
    opts = type(opts) == "table" and opts or {}
    local who = looter == nil and you() or resolveLooter(plainString(looter), nil, nil)
    return LF.Receive({ link = link, qty = 1, kind = "loot", source = "manual", looter = who,
        force = true, test = opts.test == true })
end

--- Put one placeholder drop in the test feed as given (test mode, modules/TestMode.lua): its
--- verdicts, trade estimate, inspect state and candidates are the spec's, never judged, and no
--- gate, inspect or timer touches it. `spec.group` is { key, label, kind } (`encounter` or `run`);
--- `spec.ago` dates it that many seconds back. Sends DropAdded.
--- @param spec table { link, looter = { name, guid, classFile, isSelf }, group, situation, ago,
---   kind, facts, me, them, trade, inspect, candidates, testAsk, testInspect }
--- @return number|nil id, string status (`added`, or `stoodDown` / `notItem`)
function LF.AddTest(spec)
    if stoodDown() then return nil, "stoodDown" end
    local link, itemID = validItem(type(spec) == "table" and spec.link or nil)
    if not itemID or type(spec.looter) ~= "table" or type(spec.group) ~= "table" then return nil, "notItem" end
    local s = store()
    s.seq = s.seq + 1
    return add(NS.FeedRecords.TestRecord(s.seq, spec, link, itemID, now()))
end

-- ── reading the feed ────────────────────────────────────────────────────────────────────────

local function feedNamed(name)
    return store()[name == "test" and "test" or "live"]
end

--- A drop by id, from either feed, or nil.
--- @param id number
--- @return table|nil
function LF.Get(id)
    local s = store()
    return s.live.byId[id] or s.test.byId[id]
end

--- A feed's drops, oldest first: `live` (the default) or `test`.
--- @param name string|nil
--- @return table
function LF.Drops(name)
    return feedNamed(name).drops
end

--- A feed's groups, oldest first, each { key, label, kind, encounterID, mapID, situation, at,
--- drops = { id, ... } }.
--- @param name string|nil
--- @return table
function LF.Groups(name)
    return feedNamed(name).groups
end

--- Empty a feed (`/dw clear`, clear on boss kill, the end of test mode), then tell the removal sinks.
--- @param name string|nil
function LF.Clear(name)
    local s = store()
    local which = name == "test" and "test" or "live"
    s[which] = newFeed()
    NS.Debug(TAG, "feed cleared: %s", which)
    notifyRemoved(which)
end

--- Remove every live drop `pred(rec)` answers true for, from the feed and the dedupe window, then
--- tell the removal sinks (the simulator's stop, which also resets the encounter and run context
--- with `resetContext`). Answers how many drops left.
--- @param pred function
--- @param resetContext boolean|nil
--- @return number
function LF.RemoveWhere(pred, resetContext)
    local s, n = store(), 0
    for i = #s.live.drops, 1, -1 do
        if pred(s.live.drops[i]) then NS.FeedRecords.RemoveAt(s.live, i); n = n + 1 end
    end
    local keep = {}
    for _, rec in ipairs(s.recent) do
        if not pred(rec) then keep[#keep + 1] = rec end
    end
    s.recent = keep
    if resetContext then s.ctx = {} end
    NS.Debug(TAG, "removed %d drops", n)
    if n > 0 then notifyRemoved("live") end
    return n
end

--- The counts the diagnostics report shows: { group, mine, test, groups, merged, hidden, loading,
--- encounter (label or nil), run (label or nil) }. Reads stored state only.
--- @return table
function LF.Stats()
    local s = State.feed
    if not s then return nil end
    local out = { group = 0, mine = 0, test = #s.test.drops, groups = #s.live.groups, merged = s.merged,
        hidden = s.hidden, loading = 0 }
    for _, rec in ipairs(s.live.drops) do
        if rec.isMine then out.mine = out.mine + 1 else out.group = out.group + 1 end
    end
    for _, rec in ipairs(s.recent) do
        if rec.state == "loading" then out.loading = out.loading + 1 end
    end
    local t = now()
    local enc, run = NS.FeedRecords.ActiveEncounter(s.ctx, t, LF.LOOT_GRACE), NS.FeedRecords.ActiveRun(s.ctx, t, LF.LOOT_GRACE)
    out.encounter, out.run = enc and enc.label, run and run.label
    return out
end

--- The score retry's state (diagnostics): drops still retrying a pending score, drops that used
--- up their tries still pending, and whether the shared timer is armed. Read-only.
--- @return table { pending, spent, armed }
function LF.ScoreRetries()
    local s, out = State.feed, { pending = 0, spent = 0, armed = timers.score ~= nil }
    if not s then return out end
    for _, rec in ipairs(s.live.drops) do
        if rec.scoreTries and scorePending(rec) then
            if rec.scoreTries < LF.SCORE_TRIES then out.pending = out.pending + 1 else out.spent = out.spent + 1 end
        end
    end
    return out
end

-- ── updates ─────────────────────────────────────────────────────────────────────────────────

--- An inspect job ended: re-judge that looter's drops and your own drops' candidate of that GUID.
--- @param guid any
function LF.OnInspectDone(guid)
    if stoodDown() or not NS.Compat.IsSafeKey(guid) then return end
    local cfg, n = LF.Config(), 0
    for _, rec in ipairs(store().live.drops) do
        local hit = rec.looter.guid == guid and not rec.isMine
        if hit or (rec.isMine and rec.candidates and rec.candidates[guid]) then
            judgeLooter(rec, cfg, false)
            notePending(rec)
            n = n + 1
            send(NS.MSG.DROP_UPDATED, rec.id, "inspect")
        end
    end
    if n > 0 then NS.Debug("EVAL", "re-judged %d drops after an inspect", n) end
end

-- A shown drop judged again on new facts: for you, its looter (no inspect asked) and the trade.
local function rejudge(rec, facts, cause)
    rec.facts = facts
    local cfg = LF.Config()
    judgeMe(rec, cfg)
    judgeLooter(rec, cfg, false)
    notePending(rec)
    send(NS.MSG.DROP_UPDATED, rec.id, cause)
end

--- Read a shown drop's facts again for its (changed) link and re-judge it, sending
--- DropUpdated(id, cause) once they are in. Answers `merged` (the merge's status).
--- @param rec table
--- @param cause string
--- @return string
function LF.Refresh(rec, cause)
    local gen, link = generation, rec.link
    local facts = NS.ItemFacts.Request(link, function(f)
        if gen == generation and not stoodDown() and f and rec.link == link then rejudge(rec, f, cause) end
    end)
    if facts then rejudge(rec, facts, cause) end
    return "merged"
end

--- Your own drop matched to its bag item (the trade timer's entry `e`, ui spec §0): it keeps the
--- bag item's link when that is more complete, and reads its level and quality from the bag item
--- (NS.ItemRead.ItemLevelAt / QualityAt, always exact). Re-judged, with DropUpdated(id, `bag`),
--- only when something moved. Answers whether it did.
--- @param rec table
--- @param e table { link, bag, slot }
--- @return boolean
function LF.ApplyBagItem(rec, e)
    local IR = NS.ItemRead
    local link = IR.BetterLink(rec.link, e.link) or rec.link
    local base = NS.ItemFacts.Get(link)
    if not base then return false end
    local ilvl, quality = IR.ItemLevelAt(e.bag, e.slot), IR.QualityAt(e.bag, e.slot)
    local new, f = NS.FeedRecords.Overlay(base, ilvl, quality), rec.facts
    if link == rec.link and f and f.ilvl == new.ilvl and f.quality == new.quality and f.ilvlSource == new.ilvlSource
        and f.qualitySource == new.qualitySource then
        return false
    end
    NS.Debug(TAG, "drop %s: read from its bag item %s:%s, ilvl %s, quality %s", rec.id, e.bag, e.slot,
        tostring(ilvl), tostring(quality))
    rec.link = link
    rejudge(rec, new, "bag")
    return true
end

--- Every own live drop the trade timer matched to a bag item, read from it (ApplyBagItem).
function LF.ReadBagItems()
    local TT = NS.TradeTimer
    if stoodDown() or not TT then return end
    for _, rec in ipairs(store().live.drops) do
        local e = rec.isMine and not rec.test and TT.ForDrop(rec.id)
        if e and e.bag and e.slot then LF.ApplyBagItem(rec, e) end
    end
end

--- Your gear moved: re-judge you on every drop, and your own drops' trade.
function LF.OnGearChanged()
    if stoodDown() then return end
    local cfg, drops = LF.Config(), store().live.drops
    for _, rec in ipairs(drops) do
        judgeMe(rec, cfg)
        if rec.isMine then judgeLooter(rec, cfg, false) end
        notePending(rec)
        send(NS.MSG.DROP_UPDATED, rec.id, "gear")
    end
    if #drops > 0 then NS.Debug("EVAL", "re-judged %d drops after a gear change", #drops) end
end

-- ── the encounter context ───────────────────────────────────────────────────────────────────

--- ENCOUNTER_START: the encounter in progress, named for its group.
function LF.OnEncounterStart(encounterID, encounterName)
    local s, id, t = store(), plainNumber(encounterID), now()
    local name = plainString(encounterName)
    if id and name then s.names[id] = name end
    s.ctx.encounter = { id = id, key = "enc:" .. tostring(id) .. ":" .. t, label = encounterLabel(s, id),
        startedAt = t }
end

local function isKill(success)
    return not NS.Compat.IsSecret(success) and (success == 1 or success == true)
end

-- Clear on boss kill (`feed.clearOnBossKill`): a kill empties the live feed before its loot
-- arrives, so the table starts over with that boss's drops. The window repaints at once.
local function clearOnKill()
    if get("feed.clearOnBossKill") ~= true or #store().live.drops == 0 then return end
    LF.Clear("live")
    if NS.Window then NS.Window.Refresh() end
end

--- ENCOUNTER_END: a kill opens the loot window for LOOT_GRACE seconds (and, with
--- `feed.clearOnBossKill` on, first empties the live feed); a wipe closes it.
function LF.OnEncounterEnd(encounterID, _, _, _, success)
    local kill = isKill(success)
    if kill then clearOnKill() end
    local enc, id = store().ctx.encounter, plainNumber(encounterID)
    if not enc or (id and enc.id and id ~= enc.id) then return end
    enc.endedAt = now()
    enc.success = kill
end

--- CHALLENGE_MODE_START: a keystone run, named for its group.
function LF.OnRunStart(mapID)
    local t, id = now(), plainNumber(mapID)
    local label = NS.Compat.ChallengeMapName(id) or areaName()
    store().ctx.run = { mapID = id, key = "run:" .. tostring(id) .. ":" .. t, label = label, startedAt = t }
end

--- CHALLENGE_MODE_COMPLETED: the run's group stays open LOOT_GRACE seconds for the chest.
function LF.OnRunEnd()
    local run = store().ctx.run
    if run and not run.endedAt then run.endedAt = now() end
end

-- ── the sources ─────────────────────────────────────────────────────────────────────────────

--- The loot parser's sink: one CHAT_MSG_LOOT receipt.
--- @param loot table the parser's { looterName, looterGUID, link, qty, kind, isSelf }
function LF.OnChatLoot(loot)
    if loot.isSelf and loot.kind == "pushed" then return nil, "pushed" end
    local who = resolveLooter(loot.looterName, loot.looterGUID, nil)
    if loot.isSelf then who.isSelf = true end
    return LF.Receive({ link = loot.link, qty = loot.qty, kind = loot.kind, source = "chat", looter = who })
end

--- ENCOUNTER_LOOT_RECEIVED(encounterID, itemID, itemLink, quantity, playerName, classFile).
function LF.OnEncounterLoot(encounterID, _, link, qty, playerName, classFile)
    local name = plainString(playerName)
    if not name then return nil, "noLooter" end
    local who = resolveLooter(name, nil, plainString(classFile))
    return LF.Receive({ link = link, qty = plainNumber(qty), kind = "loot", source = "encounter",
        looter = who, encounterID = plainNumber(encounterID) })
end

--- LOOT_HISTORY_UPDATE_DROP(encounterID, lootListID): a group-loot drop, taken once it has a winner.
function LF.OnLootHistoryDrop(encounterID, lootListID)
    local drop = NS.Compat.LootHistoryDrop(encounterID, lootListID)
    if not drop then return nil, "noWinner" end
    local key = encounterID .. ":" .. lootListID
    local seen = store().history
    if seen[key] then return nil, "seen" end
    seen[key] = true
    local who = resolveLooter(drop.name, drop.guid, drop.classFile)
    if drop.isSelf then who.isSelf = true end
    return LF.Receive({ link = drop.link, qty = 1, kind = "loot", source = "history", looter = who,
        encounterID = encounterID })
end

-- ── events, messages and the lifecycle ──────────────────────────────────────────────────────

NS.LootParser.AddSink(function(loot) LF.OnChatLoot(loot) end)

-- CHALLENGE_MODE_START and CHALLENGE_MODE_COMPLETED are shared with modules/Situations.lua
-- (core/DropWatcher.lua's dispatcher); its rows come first, so the situation is fresh.
local EVENTS = {
    { "ENCOUNTER_START", "OnFeedEncounterStart", LF.OnEncounterStart },
    { "ENCOUNTER_END", "OnFeedEncounterEnd", LF.OnEncounterEnd },
    { "CHALLENGE_MODE_START", "OnFeedRunStart", LF.OnRunStart },
    { "CHALLENGE_MODE_COMPLETED", "OnFeedRunEnd", LF.OnRunEnd },
    { "ENCOUNTER_LOOT_RECEIVED", "OnFeedEncounterLoot", LF.OnEncounterLoot },
    { "LOOT_HISTORY_UPDATE_DROP", "OnFeedLootHistory", LF.OnLootHistoryDrop },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function(_, _, ...) fn(...) end
end

-- The bus receivers: tracked, so the stand-down takes them down and the stand-up replays them.
-- Without the bus library they are bare targets, unregistered here instead
-- (NS.Bus.tracked, core/Bus.lua's answer, says which).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.INSPECT_DONE, function(_, guid) LF.OnInspectDone(guid) end)
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() LF.OnGearChanged() end)
    target:RegisterMessage(NS.MSG.TRADE_TIMER_TICK, function()
        LF.ReadBagItems()
        LF.SweepTrade(true)
    end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    if timers.score then timers.score:Cancel() end
    stopSweep()
    timers = {}
    local s = State.feed
    if s then s.recent, s.ctx = {}, {} end
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    LF.ArmTradeSweep()
end
