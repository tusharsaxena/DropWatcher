local _, NS = ...
-- modules/FeedFilter.lua — the feed's filters of design spec §6.3: which items the feed never
-- shows, whatever their verdict.
--
-- PURE. Filter takes the item facts, the feed's settings (LootFeed.Config()'s fields) and your
-- average item level, and makes no client call; test_feed drives it directly. The feed
-- (modules/LootFeed.lua) runs it after the situation gate and before the verdict, and a drop it
-- refuses is hidden with the reason it answers. Peeled out of the feed (DW-62), which the plan
-- keeps under 1000 lines.

NS.FeedFilter = NS.FeedFilter or {}
local FF = NS.FeedFilter
local C = NS.Constants

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
--- @param cfg table|nil NS.LootFeed.Config()'s fields
--- @param ctx table|nil { myIlvl }
--- @return boolean pass, string|nil reasonKey (`heirloom`, `cosmetic`, `token`, `notGear`, `minIlvl`)
function FF.Filter(facts, cfg, ctx)
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
