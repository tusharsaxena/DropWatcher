local _, NS = ...
-- modules/FeedCounts.lua — what the feed turned away, counted by reason (feedback-2 spec §0): no
-- receipt is dropped silently.
--
-- HIDDEN is a receipt the feed took and judged, then kept out of every table by a gate: the
-- situation (`notTracking`), a filter of spec §6.3 (`heirloom`, `cosmetic`, `token`, `notGear`,
-- `minIlvl`) or the quality gate (`quality`). REFUSED is a receipt the feed never took: the
-- addon stood down (`stoodDown`), no item link (`notItem`), your own pushed line (`pushed`), no
-- looter named (`noLooter`), a C_LootHistory drop with no winner yet (`noWinner`) or one already
-- taken (`seen`). Both counts live in the feed's session store (NS.State.feed.hidden and
-- .refused), the diagnostics' `drops` section reports them, and /dw debug logs each one with its
-- reason under the FEED tag. Peeled out of modules/LootFeed.lua, which the plan keeps under 1000
-- lines; the feed calls these with its own store.

NS.FeedCounts = NS.FeedCounts or {}
local FC = NS.FeedCounts

local TAG = "FEED"

local function bump(map, why)
    map[why] = (map[why] or 0) + 1
end

--- Count a drop a gate hid, mark it hidden, and log it under FEED with its reason (and, for
--- `quality`, the gate's mode, threshold and why under QUAL as well).
--- @param s table the feed's store
--- @param rec table the drop
--- @param why string
function FC.Hide(s, rec, why)
    rec.state, rec.hidden = "hidden", why
    bump(s.hidden, why)
    NS.Debug(TAG, "hidden %s by %s: %s", rec.link, tostring(rec.looter and rec.looter.name), why)
    if why == "quality" and type(rec.quality) == "table" then
        local q = rec.quality
        NS.Debug("QUAL", "hidden %s: quality %s below %s (%s, %s)", rec.link,
            tostring(rec.facts and rec.facts.quality), tostring(q.threshold), q.mode, q.reason)
    end
end

--- Give a hidden drop's count back: a more complete link merged in, and the gates run again.
--- @param s table the feed's store
--- @param rec table the drop
function FC.Unhide(s, rec)
    local why = rec.hidden
    if why and s.hidden[why] then
        s.hidden[why] = s.hidden[why] > 1 and s.hidden[why] - 1 or nil
    end
    rec.hidden = nil
end

--- Count a receipt the feed refused and log it under FEED. Answers nil and the reason, the shape
--- every feed door answers a refusal with.
--- @param s table the feed's store
--- @param why string
--- @param what any the receipt's link or name, for the log
--- @return nil, string
function FC.Refuse(s, why, what)
    bump(s.refused, why)
    NS.Debug(TAG, "refused %s: %s", NS.SafeToString(what), why)
    return nil, why
end

--- The counts the diagnostics report shows: { group, mine, test, groups, merged, hidden, refused,
--- loading, encounter (label or nil), run (label or nil) }. Reads stored state only.
--- @param s table|nil the feed's store
--- @param t number GetTime()
--- @param grace number the feed's LOOT_GRACE
--- @return table|nil
function FC.Stats(s, t, grace)
    if not s then return nil end
    local out = { group = 0, mine = 0, test = #s.test.drops, groups = #s.live.groups, merged = s.merged,
        hidden = s.hidden, refused = s.refused, loading = 0 }
    for _, rec in ipairs(s.live.drops) do
        if rec.isMine then out.mine = out.mine + 1 else out.group = out.group + 1 end
    end
    for _, rec in ipairs(s.recent) do
        if rec.state == "loading" then out.loading = out.loading + 1 end
    end
    local FR = NS.FeedRecords
    local enc, run = FR.ActiveEncounter(s.ctx, t, grace), FR.ActiveRun(s.ctx, t, grace)
    out.encounter, out.run = enc and enc.label, run and run.label
    return out
end

--- One count map as sorted `reason=n` parts, for a joined diagnostics line.
--- @param map table|nil
--- @return table
function FC.Parts(map)
    local out = {}
    for reason, n in pairs(map or {}) do out[#out + 1] = reason .. "=" .. n end
    table.sort(out)
    return out
end
