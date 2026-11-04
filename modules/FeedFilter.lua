local _, NS = ...
-- modules/FeedFilter.lua — the feed's filters of design spec §6.3, and the item kinds and item lists
-- of issue #13 (categories design spec §4.1): which items the feed never shows, whatever their
-- verdict, and which it always shows.
--
-- PURE. Filter takes the item facts, the feed's settings (LootFeed.Config()'s fields) and your
-- average item level, and makes no client call; test_feed drives it directly. The feed
-- (modules/LootFeed.lua) runs it after the situation gate and before the verdict, and a drop it
-- refuses is hidden with the reason it answers. Peeled out of the feed (DW-62), which the plan
-- keeps under 1000 lines.

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
--- nil: NS.Collectibles.CategoryOf's answer) out as `notWatched`; an item kind turned off
--- (`cfg.categories[category] == false`, the `feed.categories.<key>` rows) out as `category`; then
--- equipment and tier tokens take the minimum item level by `minIlvlMode` (`absolute` against
--- `minIlvl`, `relative` against `ctx.myIlvl - relativeIlvl`): a token's level is compared with your
--- gear's (categories design spec Q3); a collectible skips it, its level meaningless. A kind with no
--- entry in `cfg.categories` is on. Pure, and writes nothing it is handed. Facts that could not be
--- read pass, so the feed never hides what it could not judge.
--- @param facts table|nil
--- @param cfg table|nil NS.LootFeed.Config()'s fields
--- @param ctx table|nil { myIlvl }
--- @return boolean pass, string|nil reasonKey (`blacklist`, `heirloom`, `notWatched`, `category`,
--- `minIlvl`), boolean|nil forced (true: the Always watch list let the item through)
function FF.Filter(facts, cfg, ctx)
    if type(facts) ~= "table" then return true end
    cfg = type(cfg) == "table" and cfg or {}
    if listed(cfg.blacklist, facts.itemID) then return false, "blacklist" end
    if listed(cfg.whitelist, facts.itemID) then return true, nil, true end
    if facts.quality == C.QUALITY.HEIRLOOM then return false, "heirloom" end
    local category = facts.category
    if category == nil then return false, "notWatched" end
    local kinds = type(cfg.categories) == "table" and cfg.categories or {}
    if kinds[category] == false then return false, "category" end
    if category ~= "equipment" and category ~= "tierToken" then return true end
    return ilvlCheck(facts, cfg, type(ctx) == "table" and ctx or {})
end
