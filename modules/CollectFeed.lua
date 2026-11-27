local _, NS = ...
-- modules/CollectFeed.lua — the feed's re-read of the collections (issue #13, categories design
-- spec §4.6), peeled out of modules/Collectibles.lua (Item Search split plan, task A2) so that file
-- keeps the category, the collection verdict and the read alone. Drop Watcher's only.
--
-- NEW_MOUNT_ADDED, NEW_PET_ADDED, NEW_TOY_ADDED, NEW_RECIPE_LEARNED, SKILL_LINES_CHANGED and
-- ItemFacts' TRANSMOG_COLLECTION_UPDATED handler (NS.ItemFacts.OnCollectionsChanged) arm one
-- REREAD_DELAY timer, so a burst reads once. It runs NS.ItemFacts.RereadCollections (the cache is
-- ItemFacts' to write), then sends each live collectible whose verdict moved
-- (NS.Collectibles.Verdict) through NS.LootFeed.Refresh(rec, "collection"), which re-judges it and
-- sends DropUpdated(id, "collection"). PLAYER_REGEN_ENABLED arms the same timer for the drops still
-- at collectUnknown alone (a protected answer reads once combat ends). The stand-down cancels the
-- timer.

NS.CollectFeed = NS.CollectFeed or {}
local CF = NS.CollectFeed

CF.REREAD_DELAY = 0.5

-- The one coalescing timer, and whether the pass it runs is the full one (`all`) or the regen pass
-- (`unknown`: only the drops still at collectUnknown).
local pending = { timer = nil, scope = nil }

-- A verdict's state as the re-read compares it: the verdict and a pet's count.
local function stateOf(me)
    return type(me) == "table" and (tostring(me.verdict) .. ":" .. tostring(me.count)) or nil
end

-- Whether a live drop's collection verdict may be read again by a pass of `scope`.
local function wanted(rec, scope)
    if rec.test or not NS.Collectibles.IsFeedOnly(rec) then return false end
    return scope == "all" or rec.me.verdict == "collectUnknown"
end

-- The pass: the cache's collectibles read again (ItemFacts writes its own cache), then each live
-- collectible whose verdict moved is re-judged through the feed's Refresh (DropUpdated `collection`).
local function reread(scope)
    NS.ItemFacts.RereadCollections()
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

-- Arm the one timer; a full pass asked for while the regen pass waits widens it.
local function arm(scope)
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if scope == "all" or not pending.scope then pending.scope = scope end
    if pending.timer then return end
    pending.timer = C_Timer.NewTimer(CF.REREAD_DELAY, function()
        local s = pending.scope
        pending.timer, pending.scope = nil, nil
        reread(s)
    end)
end

--- A collection changed (a mount, pet, toy or recipe learned, a profession gained or lost, an
--- appearance learned): read the collectibles again, once, CF.REREAD_DELAY seconds from the first
--- call of a burst. ItemFacts' OnCollectionsChanged calls it too.
function CF.Changed() arm("all") end

-- ItemFacts tells its subscribers when an appearance is learned; the feed is one.
NS.ItemFacts.OnCollectionsChanged(function() CF.Changed() end)

for _, event in ipairs({ "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED", "NEW_RECIPE_LEARNED",
    "SKILL_LINES_CHANGED" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnCollectionEvent" }
end
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnCollectRegenEvent" }

function NS.addon.OnCollectionEvent() CF.Changed() end

-- Combat ended: a protected answer may read now, so the drops still at collectUnknown are read again.
function NS.addon.OnCollectRegenEvent()
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        if wanted(rec, "unknown") then return arm("unknown") end
    end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending.timer then pending.timer:Cancel() end
    pending.timer, pending.scope = nil, nil
end
