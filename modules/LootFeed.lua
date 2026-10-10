local _, NS = ...
-- modules/LootFeed.lua — the feed (design spec §3, §5.3, §6): every drop the group receives, merged
-- from three sources, grouped by encounter or run, gated, judged for you and for its looter, and
-- estimated for trade.
--
--   drop = { id, feed, link, itemID, qty, kind, bonusRoll, looter = { name, guid, classFile, isSelf },
--            isMine, at, situation, encounterID, groupKey, sources = { [source] = n }, source,
--            facts, me, them, inspect = { status, reason, at } | nil, trade, quality = { mode,
--            threshold, reason }, candidates = { [guid] = { guid, name, classFile, status, eval } },
--            test, scoreTries }
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
-- fourth door (`manual`): `/dw add` and test mode.
--
-- DEDUPE. One drop is reported by up to all three sources. A receipt merges into a drop seen in
-- the last DEDUPE_WINDOW seconds with the same item id and the same looter (the same GUID; when
-- either side lacks one, the same name without its realm, ignoring case) that this source has not
-- already reported; anything else is a new drop, so two copies of one item from one source stay
-- two. A merge can teach the drop its looter's GUID, which then asks for their inspect. Manual and
-- test drops never merge.
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
-- (Filter, pure), the verdict for you (your gear only), the quality gate with that verdict for its
-- upgrade override, then the inspect request for the looter, the looter's verdict and the trade
-- estimate. A hidden drop costs no inspect; it is counted by reason and logged once. Manual drops
-- skip the situation gate; test drops skip every gate and ask for no inspect.
--
-- UPDATES. InspectDone(guid) re-judges the drops that looter received and your own drops'
-- candidate of that GUID; GearChanged re-judges you on every drop (and your own drops' trade); a
-- scorer answering "pending" is retried on one shared SCORE_RETRY timer, SCORE_TRIES times per
-- drop. Each sends DropUpdated(id, cause): `source`, `inspect`, `gear` or `score`. A new drop sends
-- DropAdded(id). Updates re-judge the verdicts and the trade only: a drop once shown stays shown.
-- Test drops are never updated.
--
-- Each feed (live and test) keeps MAX_DROPS drops, the oldest dropped first. Stood down, the
-- timers and the pending loads are dropped with the dedupe window and the encounter context; the
-- drops recorded so far are kept for the session, and the stand-up's GearChanged re-judges them.

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

local timers = {}

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

local function section(name)
    local p = NS.db and NS.db.profile
    local t = p and p[name]
    if type(t) == "table" then return t end
    return nil
end

-- t[key] when it has the default's type, else the default.
local function pick(t, key, default)
    local v = t and t[key]
    if v == nil or type(v) ~= type(default) then return default end
    return v
end

local function tableAt(t, key)
    local v = t and t[key]
    if type(v) == "table" then return v end
    return nil
end

--- The settings the feed reads, from `profile.feed`, `profile.comparison` and `profile.trade`
--- (the rows DW-40 adds), with C.FEED_DEFAULT and the spec defaults for anything not stored.
--- @return table cfg
function LF.Config()
    local D, Q = C.FEED_DEFAULT, C.QUALITY_DEFAULT
    local f, cmp = section("feed"), section("comparison")
    local q = tableAt(f, "quality")
    return {
        gearOnly = pick(f, "gearOnly", D.gearOnly), includeTokens = pick(f, "includeTokens", D.includeTokens),
        minIlvlMode = pick(f, "minIlvlMode", D.minIlvlMode), minIlvl = pick(f, "minIlvl", D.minIlvl),
        relativeIlvl = pick(f, "relativeIlvl", D.relativeIlvl),
        qualityMode = pick(q, "mode", D.qualityMode), fixed = pick(q, "fixed", Q.FIXED),
        floor = pick(q, "floor", Q.FLOOR), upgradeOverride = pick(q, "upgradeOverride", D.upgradeOverride),
        sidegradeBand = pick(cmp, "sidegradeBand", 0), compareOwned = pick(cmp, "compareOwned", false),
        undesired = tableAt(cmp, "undesired"), rules = tableAt(section("trade"), "rules"),
    }
end

-- ── the filters (pure) ──────────────────────────────────────────────────────────────────────

local function isGearClass(facts)
    return facts.classID == C.ITEM_CLASS.ARMOR or facts.classID == C.ITEM_CLASS.WEAPON
end

-- Heirlooms and cosmetics are never shown: the reason, or nil.
local function alwaysOut(facts)
    if facts.quality == C.QUALITY.HEIRLOOM then return "heirloom" end
    if facts.classID == C.ITEM_CLASS.ARMOR and facts.subClassID == C.ARMOR_SUBCLASS.COSMETIC then
        return "cosmetic"
    end
    return nil
end

local function ilvlCheck(facts, cfg, ctx)
    local ilvl, mode = facts.ilvl, cfg.minIlvlMode
    if type(ilvl) ~= "number" then return true end
    if mode == "absolute" and type(cfg.minIlvl) == "number" and ilvl < cfg.minIlvl then
        return false, "minIlvl"
    end
    local mine = ctx.myIlvl
    if mode == "relative" and type(mine) == "number" and type(cfg.relativeIlvl) == "number"
        and ilvl < mine - cfg.relativeIlvl then
        return false, "minIlvl"
    end
    return true
end

--- Spec §6.3's filters: heirlooms and cosmetics always out; tier tokens by `includeTokens`; with
--- `gearOnly`, armor and weapons only (jewelry and trinkets are armor); the minimum item level by
--- `minIlvlMode` (`absolute` against `minIlvl`, `relative` against `ctx.myIlvl - relativeIlvl`).
--- Pure. Facts that could not be read pass, so the feed never hides what it could not judge.
--- @param facts table|nil
--- @param cfg table|nil LF.Config()'s fields
--- @param ctx table|nil { myIlvl }
--- @return boolean pass, string|nil reasonKey (`heirloom`, `cosmetic`, `token`, `notGear`, `minIlvl`)
function LF.Filter(facts, cfg, ctx)
    if type(facts) ~= "table" then return true end
    cfg = type(cfg) == "table" and cfg or {}
    local why = alwaysOut(facts)
    if why then return false, why end
    if facts.isTierToken then
        if cfg.includeTokens == false then return false, "token" end
        return true
    end
    if cfg.gearOnly ~= false and not isGearClass(facts) then return false, "notGear" end
    return ilvlCheck(facts, cfg, type(ctx) == "table" and ctx or {})
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

local function shortName(name)
    if type(name) ~= "string" then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

local function sameLooter(a, b)
    if a.guid and b.guid then return a.guid == b.guid end
    local an = shortName(a.name)
    return an ~= nil and an == shortName(b.name)
end

local function you()
    local me = NS.Roster.Player()
    if me then return resolveLooter(nil, me.guid) end
    return { name = plainString(UnitName("player")), isSelf = true }
end

-- ── grouping ────────────────────────────────────────────────────────────────────────────────

local function now() return GetTime() end

local function activeRun(ctx, t)
    local run = ctx.run
    if not run or (run.endedAt and t - run.endedAt > LF.LOOT_GRACE) then return nil end
    return run
end

local function activeEncounter(ctx, t)
    local enc = ctx.encounter
    if not enc then return nil end
    if not enc.endedAt then return enc end
    if enc.success and t - enc.endedAt <= LF.LOOT_GRACE then return enc end
    return nil
end

local function encounterLabel(s, id)
    return (id and s.names[id]) or (id and L["Encounter %s"]:format(id)) or L["Encounter"]
end

local function areaName()
    if IsInInstance() == true then
        local name = plainString((GetInstanceInfo()))
        if name then return name end
    end
    return L["Open world"]
end

-- Where a drop received now belongs: { key, label, kind, encounterID, mapID }.
local function groupSpec(s, encounterID, t)
    local run = activeRun(s.ctx, t)
    if run then return { key = run.key, label = run.label, kind = "run", mapID = run.mapID } end
    local enc = activeEncounter(s.ctx, t)
    if encounterID and not (enc and enc.id == encounterID) then
        return { key = "enc:" .. encounterID, label = encounterLabel(s, encounterID), kind = "encounter",
            encounterID = encounterID }
    end
    if enc then return { key = enc.key, label = enc.label, kind = "encounter", encounterID = enc.id } end
    local area = areaName()
    return { key = "area:" .. area, label = area, kind = "area" }
end

-- The group a drop joins in its feed, made by its first drop. An area group continues while it is
-- the latest group; an area visited again later starts a new one.
local function materialize(feed, rec)
    local spec = rec.group
    local g = feed.groupByKey[spec.key]
    if spec.kind == "area" then
        local last = feed.groups[#feed.groups]
        if last and last.kind == "area" and last.label == spec.label then return last end
        g = nil
        spec.key = spec.key .. ":" .. rec.id
    end
    if g then return g end
    g = { key = spec.key, label = spec.label, kind = spec.kind, encounterID = spec.encounterID,
        mapID = spec.mapID, situation = rec.situation, at = rec.at, drops = {} }
    feed.groups[#feed.groups + 1] = g
    feed.groupByKey[g.key] = g
    return g
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

local function judgeMe(rec, cfg)
    rec.me = evaluate(rec.facts, myCandidate(cfg), evalOpts(cfg))
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
    rec.trade = NS.TradeRules.Estimate(facts, looterEval, ctx)
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

local function hasReason(eval, key)
    if type(eval) ~= "table" then return false end
    for _, r in ipairs(eval.reasons or {}) do
        if r.key == key then return true end
    end
    return false
end

local function scorePending(rec)
    if hasReason(rec.me, "scorePending") or hasReason(rec.them, "scorePending") then return true end
    for _, c in pairs(rec.candidates or {}) do
        if hasReason(c.eval, "scorePending") then return true end
    end
    return false
end

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
    armScoreRetry()
end

retryScores = function()
    local cfg, again = LF.Config(), false
    for _, rec in ipairs(store().live.drops) do
        if rec.scoreTries and rec.scoreTries < LF.SCORE_TRIES then
            rec.scoreTries = rec.scoreTries + 1
            judgeMe(rec, cfg)
            judgeLooter(rec, cfg, false)
            if scorePending(rec) and rec.scoreTries < LF.SCORE_TRIES then again = true end
            send(NS.MSG.DROP_UPDATED, rec.id, "score")
        end
    end
    if again then armScoreRetry() end
end

-- ── the records ─────────────────────────────────────────────────────────────────────────────

local function feedOf(rec)
    return store()[rec.feed]
end

local function removeOldest(feed)
    local rec = table.remove(feed.drops, 1)
    feed.byId[rec.id] = nil
    local g = feed.groupByKey[rec.groupKey]
    if not g then return end
    for i, id in ipairs(g.drops) do
        if id == rec.id then table.remove(g.drops, i) break end
    end
    if #g.drops > 0 then return end
    feed.groupByKey[g.key] = nil
    for i, other in ipairs(feed.groups) do
        if other == g then table.remove(feed.groups, i) break end
    end
end

local function verdictOf(eval) return eval and eval.verdict or "-" end

local function add(rec)
    local feed = feedOf(rec)
    local g = materialize(feed, rec)
    rec.state, rec.groupKey = "added", g.key
    g.drops[#g.drops + 1] = rec.id
    feed.drops[#feed.drops + 1] = rec
    feed.byId[rec.id] = rec
    while #feed.drops > LF.MAX_DROPS do removeOldest(feed) end
    notePending(rec)
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

-- The gates after the facts are in (or given up on), then the looter's side.
local function judge(rec, facts)
    rec.facts = facts
    local cfg = LF.Config()
    if not rec.test then
        local ctx = { myIlvl = cfg.minIlvlMode == "relative" and myIlvl() or nil }
        local ok, why = LF.Filter(facts, cfg, ctx)
        if not ok then return hide(rec, why) end
    end
    judgeMe(rec, cfg)
    if not rec.test and not qualityGate(rec, cfg) then return hide(rec, "quality") end
    judgeLooter(rec, cfg, true)
    return add(rec)
end

local function start(rec)
    if not (rec.test or rec.force) and not NS.Situations.IsTracking(rec.situation) then
        return hide(rec, "notTracking")
    end
    local gen = generation
    local facts, status = NS.ItemFacts.Request(rec.link, function(f)
        if gen ~= generation or stoodDown() then return end
        judge(rec, f)
    end)
    if status == "loading" then
        rec.state = "loading"
        return rec.id, "loading"
    end
    return judge(rec, facts)
end

local function newRecord(s, r)
    s.seq = s.seq + 1
    local t = now()
    return {
        id = s.seq, feed = r.test and "test" or "live", test = r.test, force = r.force, link = r.link,
        itemID = r.itemID, qty = r.qty or 1, kind = r.kind or "loot", bonusRoll = r.kind == "bonus",
        looter = r.looter, isMine = r.looter.isSelf == true, at = t, situation = NS.Situations.Current(),
        encounterID = r.encounterID, sources = { [r.source] = 1 }, source = r.source,
        group = groupSpec(s, r.encounterID, t), state = "new",
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

local function findRecent(s, r)
    for _, rec in ipairs(s.recent) do
        if rec.itemID == r.itemID and not rec.sources[r.source] and sameLooter(rec.looter, r.looter) then
            return rec
        end
    end
    return nil
end

-- What a second source adds: its count, the looter's GUID and the encounter, when missing.
local function merge(rec, r)
    local s = store()
    s.merged = s.merged + 1
    rec.sources[r.source] = 1
    local learned = not rec.looter.guid and r.looter.guid ~= nil
    if learned then rec.looter = r.looter end
    rec.encounterID = rec.encounterID or r.encounterID
    NS.Debug(TAG, "drop %s: %s also reported by %s", rec.id, rec.link, r.source)
    if rec.state ~= "added" then return rec.id, "merged" end
    if learned then
        local cfg = LF.Config()
        judgeLooter(rec, cfg, true)
        notePending(rec)
    end
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
        local hit = findRecent(s, r)
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

--- Empty a feed (`/dw clear`, the end of test mode).
--- @param name string|nil
function LF.Clear(name)
    local s = store()
    s[name == "test" and "test" or "live"] = newFeed()
    NS.Debug(TAG, "feed cleared: %s", name or "live")
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
    local enc, run = activeEncounter(s.ctx, t), activeRun(s.ctx, t)
    out.encounter, out.run = enc and enc.label, run and run.label
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

--- ENCOUNTER_END: a kill opens the loot window for LOOT_GRACE seconds; a wipe closes it.
function LF.OnEncounterEnd(encounterID, _, _, _, success)
    local enc, id = store().ctx.encounter, plainNumber(encounterID)
    if not enc or (id and enc.id and id ~= enc.id) then return end
    enc.endedAt = now()
    enc.success = not NS.Compat.IsSecret(success) and (success == 1 or success == true)
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
-- Without the bus library they are bare targets, unregistered here instead.
local TRACKED = LibStub and LibStub("LibKa0s-Bus-1.0", true) ~= nil
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.INSPECT_DONE, function(_, guid) LF.OnInspectDone(guid) end)
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() LF.OnGearChanged() end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    if timers.score then timers.score:Cancel() end
    timers = {}
    local s = State.feed
    if s then s.recent, s.ctx = {}, {} end
    if target and not TRACKED then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not TRACKED then listen() end
end
