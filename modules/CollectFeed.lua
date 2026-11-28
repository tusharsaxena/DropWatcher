local _, NS = ...
-- modules/CollectFeed.lua — the feed's re-read of the collections (issue #13, categories design
-- spec §4.6), Drop Watcher's only. The collections themselves are the verdict engine's
-- (LibKa0s-Verdict-1.0, core/VerdictSetup.lua): NEW_MOUNT_ADDED, NEW_PET_ADDED, NEW_TOY_ADDED,
-- NEW_RECIPE_LEARNED, SKILL_LINES_CHANGED and TRANSMOG_COLLECTION_UPDATED arm its one coalescing
-- timer, which reads the cached collectibles again and tells the host (onChange "collection"). The
-- feed's pass then runs at once (CF.OnCollectionsChanged): each live collectible whose verdict moved
-- (NS.Collectibles.Verdict) goes through NS.LootFeed.Refresh(rec, "collection"), which re-judges it
-- and sends DropUpdated(id, "collection"). PLAYER_REGEN_ENABLED arms this file's own REREAD_DELAY
-- timer for the drops still at collectUnknown alone (a protected answer reads once combat ends),
-- which reads the cache again itself. The stand-down cancels the timer.
--
-- IsFeedOnly is the feed's too: it reads a feed record (NS.Collectibles.IsFeedOnly).

NS.CollectFeed = NS.CollectFeed or {}
local CF = NS.CollectFeed

CF.REREAD_DELAY = 0.5

-- The regen pass's timer (the drops still at collectUnknown alone). The full pass has no timer
-- here: the engine coalesces the collection events itself.
local pending = { timer = nil }

-- A verdict's state as the re-read compares it: the verdict and a pet's count.
local function stateOf(me)
    return type(me) == "table" and (tostring(me.verdict) .. ":" .. tostring(me.count)) or nil
end

-- Whether a live drop's collection verdict may be read again by a pass of `scope`.
local function wanted(rec, scope)
    if rec.test or not NS.Collectibles.IsFeedOnly(rec) then return false end
    return scope == "all" or rec.me.verdict == "collectUnknown"
end

-- The pass: the cache's collectibles read again (the engine writes its own cache; `fresh` when it
-- just did), then each live collectible whose verdict moved is re-judged through the feed's
-- Refresh (DropUpdated `collection`).
local function reread(scope, fresh)
    if not fresh then NS.ItemFacts.RereadCollections() end
    local n = 0
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        local facts = wanted(rec, scope) and NS.ItemFacts.Get(rec.link)
        local now = facts and NS.Collectibles.Verdict(facts, rec.forced)
        if now and stateOf(now) ~= stateOf(rec.me) then
            NS.LootFeed.Refresh(rec, "collection")
            n = n + 1
        end
    end
    NS.Debug("EVAL", "collections read again (%s): %d drops moved", scope, n)
    return n
end

-- Arm the regen pass's timer; later calls join the one already armed.
local function arm()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if pending.timer then return end
    pending.timer = C_Timer.NewTimer(CF.REREAD_DELAY, function()
        pending.timer = nil
        reread("unknown")
    end)
end

--- The verdict engine read the collections again (core/VerdictSetup.lua's onChange "collection":
--- a collection learned, coalesced by the engine's own timer): the feed's pass now.
function CF.OnCollectionsChanged()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    reread("all", true)
end

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnCollectRegenEvent" }

-- Combat ended: a protected answer may read now, so the drops still at collectUnknown are read again.
function NS.addon.OnCollectRegenEvent()
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        if wanted(rec, "unknown") then return arm() end
    end
end

--- Whether a drop is feed-only (categories design spec §6.2): its verdict for you is a collection
--- verdict (`me.collect`), so it is watched and never asked for, toasted, auto-asked, offered,
--- announced, posted or glowed. Pure: reads the drop record alone.
--- @param drop table|nil a feed record
--- @return boolean
function NS.Collectibles.IsFeedOnly(drop)
    return type(drop) == "table" and type(drop.me) == "table" and drop.me.collect == true
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending.timer then pending.timer:Cancel() end
    pending.timer = nil
end
