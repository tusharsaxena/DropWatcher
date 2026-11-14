local _, NS = ...
-- modules/FeedFilter.lua — the feed's filters of design spec §6.3, and the item kinds and item lists
-- of issue #13 (categories design spec §4.1): which items the feed never shows, whatever their
-- verdict, and which it always shows.
--
-- PURE. Filter takes the item facts, the feed's settings (LootFeed.Config()'s fields) and your
-- average item level, and makes no client call; test_feed drives it directly. The feed
-- (modules/LootFeed.lua) runs it after the situation gate and before the verdict, and a drop it
-- refuses is hidden with the reason it answers. Peeled out of the feed (DW-62), which the plan
-- keeps under 1000 lines. PassesForMe is the whole of the feed's pre-looter gates (Forever port
-- design §11.1), the one call the feed and the Pending store (modules/Pending.lua) both make.

NS.FeedFilter = NS.FeedFilter or {}
local FF = NS.FeedFilter
local C = NS.Constants

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

-- An item of no kind: in only rolled on with the catch-all kind on (RX-04), else `notWatched`.
local function kindless(kinds, ctx)
    if ctx.rolled and kinds.other == true then return true end
    return false, "notWatched"
end

-- Is `id` on `list` (`cfg.whitelist` or `cfg.blacklist`, { [itemID] = true })?
local function listed(list, id)
    return id ~= nil and type(list) == "table" and list[id] == true
end

--- The average item level of `equipped` ({ [slot] = { ilvl } }, NS.Gear's snapshot), the shirt and
--- the tabard aside (C.QUALITY_IGNORED_SLOT), or nil when none is known: the relative minimum's
--- `ctx.myIlvl`. Pure; peeled out of the feed (feedback-15 spec §0), which stays under 1000 lines.
--- @param equipped table|nil
--- @return number|nil
function FF.AverageIlvl(equipped)
    local sum, n = 0, 0
    for slot, e in pairs(type(equipped) == "table" and equipped or {}) do
        if e and type(e.ilvl) == "number" and not C.QUALITY_IGNORED_SLOT[slot] then
            sum, n = sum + e.ilvl, n + 1
        end
    end
    if n == 0 then return nil end
    return sum / n
end

--- The feed's filters, in order (categories design spec §4.1): an item on the Never watch list
--- (`cfg.blacklist[itemID]`) out as `blacklist`, gear included and whatever else holds; one on the
--- Always watch list (`cfg.whitelist[itemID]`) in, answering `forced`, past the kinds, the heirloom
--- rule and the minimum item level (§4.2; the feed's quality gate lets it through too, the
--- situation gate does not); heirlooms always out; an item in no watched category (facts.category
--- nil: NS.Collectibles.CategoryOf's answer) out as `notWatched`, unless it is rolled on
--- (`ctx.rolled`) and the catch-all kind is on (`cfg.categories.other == true`, off by default: RX-04,
--- rolls UX design §3.5), which lets it in with no item level check; an item kind turned off
--- (`cfg.categories[category] == false`, the `feed.categories.<key>` rows) out as `category`; then
--- equipment and tier tokens take the minimum item level by `minIlvlMode` (`absolute` against
--- `minIlvl`, `relative` against `ctx.myIlvl - relativeIlvl`): a token's level is compared with your
--- gear's (categories design spec Q3); a collectible skips it, its level meaningless. A kind with no
--- entry in `cfg.categories` is on. Pure, and writes nothing it is handed. Facts that could not be
--- read pass, so the feed never hides what it could not judge.
--- @param facts table|nil
--- @param cfg table|nil NS.LootFeed.Config()'s fields
--- @param ctx table|nil { myIlvl, rolled }
--- @return boolean pass, string|nil reasonKey (`blacklist`, `heirloom`, `notWatched`, `category`,
--- `minIlvl`), boolean|nil forced (true: the Always watch list let the item through)
function FF.Filter(facts, cfg, ctx)
    if type(facts) ~= "table" then return true end
    cfg = type(cfg) == "table" and cfg or {}
    if listed(cfg.blacklist, facts.itemID) then return false, "blacklist" end
    if listed(cfg.whitelist, facts.itemID) then return true, nil, true end
    if facts.quality == C.QUALITY.HEIRLOOM then return false, "heirloom" end
    ctx = type(ctx) == "table" and ctx or {}
    local category = facts.category
    local kinds = type(cfg.categories) == "table" and cfg.categories or {}
    if category == nil then return kindless(kinds, ctx) end
    if kinds[category] == false then return false, "category" end
    if category ~= "equipment" and category ~= "tierToken" then return true end
    return ilvlCheck(facts, cfg, ctx)
end

--- Whether `cfg` forces `facts` in: on the Always watch list and not on the Never watch list, the
--- answer Filter's `forced` gives when it passes (the feed reads it for a drop no filter runs on).
--- @param facts table|nil
--- @param cfg table|nil
--- @return boolean
function FF.Forced(facts, cfg)
    local id = type(facts) == "table" and facts.itemID or nil
    cfg = type(cfg) == "table" and cfg or {}
    return listed(cfg.whitelist, id) and not listed(cfg.blacklist, id)
end

-- The filters, or (ctx.skipFilter) the Always watch list alone; `out.forced` takes the answer.
local function admit(facts, ctx, out)
    local cfg = type(ctx.cfg) == "table" and ctx.cfg or {}
    if ctx.skipFilter then
        out.forced = FF.Forced(facts, cfg) or nil
        return true
    end
    local ok, why, forced = FF.Filter(facts, cfg, ctx)
    out.forced = ok and forced or nil
    return ok, why
end

-- The quality gate on your verdict `out.me`; `out.quality` takes { mode, threshold, reason }.
local function qualityPasses(facts, ctx, out)
    local cfg, f, me = type(ctx.cfg) == "table" and ctx.cfg or {}, type(facts) == "table" and facts or {}, out.me
    local qctx = { fixed = cfg.fixed, floor = cfg.floor, upgradeOverride = cfg.upgradeOverride, gear = ctx.gear,
        baselineSlot = me.baselineSlot, equipLoc = f.equipLoc, verdict = me.verdict, forced = out.forced == true }
    local passes = type(ctx.passes) == "function" and ctx.passes or NS.QualityGate.Passes
    local pass, threshold, reason = passes(f.quality, ctx.mode, qctx)
    out.quality = { mode = ctx.mode, threshold = threshold, reason = reason }
    return pass
end

--- The feed's pre-looter gates in their order (Forever port design §11.1): the situation's on/off
--- (`ctx.tracking == false` refuses as `notTracking`; nil skips it), the filters above (`ctx.rolled`
--- for an item a group rolls on: the catch-all kind's; or, with
--- `ctx.skipFilter`, the Always watch list alone), your verdict (`ctx.judge(forced)`, the caller's
--- judge, so the feed's own judgeMe path runs), then the quality gate in `ctx.mode` against
--- `ctx.gear` (skipped with `ctx.skipQuality`; `ctx.passes` may stand in for QualityGate.Passes, so
--- the feed can time it). The looter-dependent gates are not here: a pending roll has no looter.
--- Pure apart from the two callbacks it is handed. `out` is { forced, me, quality }, filled as far
--- as the gates got.
--- @param facts table|nil
--- @param ctx table { cfg, myIlvl, rolled, tracking, skipFilter, skipQuality, judge, mode, gear, passes }
--- @return boolean pass, string|nil why, table out
function FF.PassesForMe(facts, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local out = {}
    if ctx.tracking == false then return false, "notTracking", out end
    local ok, why = admit(facts, ctx, out)
    if not ok then return false, why, out end
    if type(ctx.judge) == "function" then out.me = ctx.judge(out.forced) end
    if ctx.skipQuality or type(out.me) ~= "table" then return true, nil, out end
    if not qualityPasses(facts, ctx, out) then return false, "quality", out end
    return true, nil, out
end
