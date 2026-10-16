local _, NS = ...
-- modules/FeedRecords.lua — the feed's pure record logic (design spec §3, §6, ui spec §0): which
-- recent drop a second source's receipt is, which link a merged drop keeps, the encounter and run
-- in force, the group a drop joins and its removal, a test drop's record, the bag item's exact
-- level laid over a drop's facts, whether two trade estimates are the same, and whether an
-- evaluation still waits on its scorer.
--
-- PURE. No client call and no state of its own: modules/LootFeed.lua hands in its feeds, records,
-- receipts and the time. Peeled out of the feed (DW-80), which the plan keeps under 1000 lines.
--
-- THE LINK A MERGE KEEPS (BUG-1). Each source can hand a different link for one drop, and the
-- client reads a link's level and quality from the data inside it: a link with no bonus ids reads
-- as the base item. A merge keeps the more complete link (NS.ItemRead.BetterLink); on a tie the
-- chat line's wins, because its link always carries the bonus and upgrade data.

NS.FeedRecords = NS.FeedRecords or {}
local FM = NS.FeedRecords

--- A looter's name without its realm, lowercased, or nil.
--- @param name string|nil
--- @return string|nil
function FM.ShortName(name)
    if type(name) ~= "string" then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

--- Whether two looters are one: the same GUID, else (either lacks one) the same short name.
--- @return boolean
function FM.SameLooter(a, b)
    if a.guid and b.guid then return a.guid == b.guid end
    local an = FM.ShortName(a.name)
    return an ~= nil and an == FM.ShortName(b.name)
end

--- The recent drop receipt `r` is a second report of: the same item id and looter, from a source
--- that has not reported it yet. Nil when none is.
--- @param recent table the feed's dedupe window, oldest first
--- @param r table the receipt { itemID, source, looter }
--- @return table|nil
function FM.FindRecent(recent, r)
    for _, rec in ipairs(recent) do
        if rec.itemID == r.itemID and not rec.sources[r.source] and FM.SameLooter(rec.looter, r.looter) then
            return rec
        end
    end
    return nil
end

--- The link a drop keeps when `source` reports it again with `incoming`: the more complete of the
--- two, the chat line's on a tie.
--- @param current string the drop's link
--- @param incoming string the new receipt's link
--- @param source string the new receipt's source
--- @return string
function FM.PreferredLink(current, incoming, source)
    local IR = NS.ItemRead
    if source == "chat" then return IR.BetterLink(incoming, current) or current end
    return IR.BetterLink(current, incoming) or current
end

--- Whether two trade estimates say the same thing (state, reason, basis and expiry).
--- @return boolean
function FM.SameTrade(a, b)
    return a ~= nil and a.state == b.state and a.reasonKey == b.reasonKey and a.basis == b.basis
        and a.expiresAt == b.expiresAt
end

--- Whether an evaluation carries the reason `key`.
--- @return boolean
function FM.HasReason(eval, key)
    if type(eval) ~= "table" then return false end
    for _, r in ipairs(eval.reasons or {}) do
        if r.key == key then return true end
    end
    return false
end

--- Whether any verdict on a drop (yours, the looter's, a candidate's) waits on its scorer.
--- @param rec table
--- @return boolean
function FM.ScorePending(rec)
    if FM.HasReason(rec.me, "scorePending") or FM.HasReason(rec.them, "scorePending") then return true end
    for _, c in pairs(rec.candidates or {}) do
        if FM.HasReason(c.eval, "scorePending") then return true end
    end
    return false
end

-- ── the context, the groups and the records ─────────────────────────────────────────────────

--- The keystone run in force at `t`: in progress, or completed no more than `grace` seconds ago.
--- @return table|nil
function FM.ActiveRun(ctx, t, grace)
    local run = ctx.run
    if not run or (run.endedAt and t - run.endedAt > grace) then return nil end
    return run
end

--- The encounter in force at `t`: in progress, or killed no more than `grace` seconds ago (a wipe
--- opens no loot window).
--- @return table|nil
function FM.ActiveEncounter(ctx, t, grace)
    local enc = ctx.encounter
    if not enc then return nil end
    if not enc.endedAt then return enc end
    if enc.success and t - enc.endedAt <= grace then return enc end
    return nil
end

--- The group a drop joins in its feed, made by its first drop. An area group continues while it is
--- the latest group; an area visited again later starts a new one. A new group keeps the place its
--- spec names (instance, difficulty) and the drop's recorder (feedback-3 spec §4). A restored drop's
--- spec carries its History group's feed key (feedback-15 spec §0): an area's is taken as it is.
--- A new area's key carries the drop's id and its time: the id restarts at 1 every load and a
--- restored group keeps the key it had before the reload, so the time (GetTime(), which a reload
--- does not reset, as the enc and run keys use) keeps a key made after it from meeting one before.
--- @param feed table { groups, groupByKey }
--- @param rec table the drop, with `group` = { key, label, kind, encounterID, mapID, instance,
---   difficulty }
--- @return table
function FM.Materialize(feed, rec)
    local spec = rec.group
    local g = feed.groupByKey[spec.key]
    if spec.kind == "area" and rec.source ~= "restore" then
        local last = feed.groups[#feed.groups]
        if last and last.kind == "area" and last.label == spec.label then return last end
        g = nil
        spec.key = spec.key .. ":" .. rec.id .. ":" .. tostring(rec.at)
    end
    if g then return g end
    g = { key = spec.key, label = spec.label, kind = spec.kind, encounterID = spec.encounterID,
        mapID = spec.mapID, situation = rec.situation, at = rec.at, drops = {}, instance = spec.instance,
        difficulty = spec.difficulty, seenBy = rec.seenBy, seenByClass = rec.seenByClass }
    feed.groups[#feed.groups + 1] = g
    feed.groupByKey[g.key] = g
    return g
end

--- The group a drop of `spec` would join, when it already exists (the area's: the latest group,
--- while it is that area's), else nil. Nothing is made.
--- @param feed table
--- @param spec table groupSpec's { key, label, kind }
--- @return table|nil
function FM.Existing(feed, spec)
    if spec.kind ~= "area" then return feed.groupByKey[spec.key] end
    local last = feed.groups[#feed.groups]
    if last and last.kind == "area" and last.label == spec.label then return last end
    return nil
end

--- Remove feed.drops[at] and its place in its group; the group goes with its last drop.
--- @param feed table
--- @param at number
function FM.RemoveAt(feed, at)
    local rec = table.remove(feed.drops, at)
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

--- A placeholder drop's record (test mode): the given verdicts, trade and inspect, nothing judged.
--- @param id number
--- @param spec table LootFeed.AddTest's spec
--- @param link string
--- @param itemID number
--- @param t number now
--- @return table
function FM.TestRecord(id, spec, link, itemID, t)
    local who = spec.looter
    return {
        id = id, feed = "test", test = true, link = link, itemID = itemID, qty = 1,
        kind = spec.kind or "loot", bonusRoll = spec.kind == "bonus", looter = who,
        isMine = who.isSelf == true, at = t - (tonumber(spec.ago) or 0),
        situation = spec.situation, sources = { manual = 1 }, source = "manual", group = spec.group,
        facts = spec.facts, me = spec.me, them = spec.them, trade = spec.trade, inspect = spec.inspect,
        candidates = spec.candidates, testAsk = spec.testAsk, testInspect = spec.testInspect,
        state = "new",
    }
end

--- The cached facts with a bag item's exact level (`ilvlSource` "current") and quality
--- (`qualitySource` "location") laid over: a copy, so the cache's table is never written.
--- @param facts table
--- @param ilvl number|nil
--- @param quality number|nil
--- @return table
function FM.Overlay(facts, ilvl, quality)
    local out = {}
    for k, v in pairs(facts) do out[k] = v end
    if ilvl then out.ilvl, out.ilvlSource = ilvl, "current" end
    if quality then out.quality, out.qualitySource = quality, "location" end
    return out
end
