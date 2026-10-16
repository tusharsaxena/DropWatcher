local _, NS = ...
-- modules/FeedRestore.lua — the Drops tab survives a reload (feedback-15 spec §0, DW-Q0): after a
-- /reload, this session's drops come back into the live feed from the History log, under their
-- headers, judged again and linked to the entries that recorded them.
--
-- WHEN. Once per load, on the first PLAYER_ENTERING_WORLD, and only when it says isReloadingUi: an
-- initial login starts an empty feed, which is what "since login" means (the session is the login,
-- modules/Session.lua). Its row runs after modules/Situations.lua's and modules/HistoryRetention.lua's
-- (the TOC loads it after them), so the situation is fresh; the retention's prune is deferred anyway.
--
-- WHAT. The account's log (NS.History.Store, never a test-mode or simulation log): the groups whose
-- key ends in `@<session start>`, their entries the current character saw (`seenBy ==
-- CharFilter.CurrentKey()`), entries marked `gone` skipped, and those dated before the live feed's
-- last clear (`/dw clear`, Clear on boss kill: NS.Session.Cleared), so a clear outlasts a reload,
-- oldest first by `at`, the newest LootFeed.MAX_DROPS of them.
--
-- HOW. Each entry is one receipt for LootFeed.Restore (`restore`): the link, the looter (Name-Realm,
-- classFile, and the GUID when the roster places them now, else none), your own when `isMine`; its
-- time the epoch `at` turned into the client clock (GetTime() - (time() - at)); its group the
-- History group's (the feed key without its `@<start>` suffix, the label, kind, situation,
-- instance, difficulty and roster), so the boss and key headers return as they were. The feed
-- judges it as a fresh drop (the item facts, Me against your gear now, Them through the inspect
-- broker, the trade estimate anew) past the situation gate and the filters, which it passed when
-- it was first recorded; the quality gate still runs. History.Adopt links it to its entry before
-- its DropAdded, so nothing is recorded twice and DropUpdated refreshes that entry. The trade timer
-- matches your restored drops to their bag items as it does any (it reads LootFeed.Drops).
--
-- PURE: Pick and Receipt take plain tables and the clocks as arguments; test_feed_restore drives
-- them through the edge.

NS.FeedRestore = NS.FeedRestore or {}
local FR = NS.FeedRestore

local TAG = "FEED"

local done = false   -- the first PLAYER_ENTERING_WORLD of this load has been answered

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

-- The feed key of a group of this session (its key ends in `suffix`, `@<start>`), without the
-- suffix; nil for any other group.
local function sessionFeedKey(g, suffix)
    local key = type(g.key) == "string" and g.key or ""
    if #key > #suffix and key:sub(-#suffix) == suffix then return key:sub(1, -#suffix - 1) end
    return nil
end

-- Whether an entry comes back: not gone, not dated before the clear, seen by `current`, a link.
local function pickable(e, current, cleared)
    if e.gone or e.seenBy ~= current or type(e.itemLink) ~= "string" then return false end
    return not (cleared and (num(e.at) or 0) < cleared)
end

--- The entries to restore: this session's (`@<start>`), seen by `current`, not gone, not dated
--- before `cleared` (a drop in the clear's own second is kept), oldest first by `at` (a tie keeps
--- the log's order), the newest `max`.
--- @param groups table the log's groups, oldest first
--- @param start number the session start
--- @param current string|nil your recorder key
--- @param max number
--- @param cleared number|nil the live feed's last clear (time()), or nil
--- @return table { { group, entry, feedKey }, ... }
function FR.Pick(groups, start, current, max, cleared)
    local suffix, out = "@" .. tostring(start), {}
    if not current then return out end
    for _, g in ipairs(type(groups) == "table" and groups or {}) do
        local feedKey = sessionFeedKey(g, suffix)
        if feedKey then
            for _, e in ipairs(type(g.drops) == "table" and g.drops or {}) do
                if pickable(e, current, cleared) then
                    out[#out + 1] = { group = g, entry = e, feedKey = feedKey, n = #out + 1 }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local x, y = num(a.entry.at) or 0, num(b.entry.at) or 0
        if x ~= y then return x < y end
        return a.n < b.n
    end)
    local cut = {}
    for i = math.max(1, #out - max + 1), #out do cut[#cut + 1] = out[i] end
    return cut
end

--- One pick as LootFeed.Restore's receipt: `looter` = { name, guid, classFile, isSelf } (the guid
--- given by the caller), the entry's epoch turned into the client clock, and its History group's
--- place as the drop's group spec.
--- @param pick table FR.Pick's
--- @param looter table
--- @param epochNow number time()
--- @param clockNow number GetTime()
--- @return table
function FR.Receipt(pick, looter, epochNow, clockNow)
    local g, e = pick.group, pick.entry
    return {
        link = e.itemLink, itemID = e.itemID, qty = 1, kind = "loot", source = "restore", force = true,
        looter = looter, at = clockNow - (epochNow - (num(e.at) or epochNow)), situation = g.situation,
        group = { key = pick.feedKey, label = g.label, kind = g.kind, instance = g.instance,
            difficulty = g.difficulty, roster = NS.GroupRoster.Copy(g.roster) },
    }
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- The looter as the roster places them now (their GUID while they are in the group), else as kept.
local function looterOf(e)
    local m = type(e.looter) == "string" and NS.Roster.Resolve(e.looter, e.class) or nil
    return { name = m and (m.fullName or m.name) or e.looter, guid = m and m.guid or nil,
        classFile = m and m.classFile or e.class, isSelf = e.isMine == true }
end

--- Rebuild this session's drops from the History log (after a reload). Answers how many were
--- handed to the feed.
--- @return number
function FR.Run()
    local H, LF = NS.History, NS.LootFeed
    local hist = H.Store()
    if not hist then return 0 end
    local picks = FR.Pick(hist.groups, H.SessionStart(), NS.CharFilter.CurrentKey(), LF.MAX_DROPS,
        NS.Session.Cleared())
    local epochNow, clockNow = time(), GetTime()
    for _, p in ipairs(picks) do
        local e = p.entry
        LF.Restore(FR.Receipt(p, looterOf(e), epochNow, clockNow), function(id) H.Adopt(id, e) end)
    end
    NS.Debug(TAG, "restored %d drops of this session after a reload", #picks)
    return #picks
end

--- PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi): the first one of the load, when it is a
--- reload, rebuilds the feed.
function FR.OnEnteringWorld(isInitialLogin, isReloadingUi)
    if done then return end
    done = true
    if isReloadingUi == true and not isInitialLogin then FR.Run() end
end

-- ── events ──────────────────────────────────────────────────────────────────────────────────

-- PLAYER_ENTERING_WORLD is shared (core/DropWatcher.lua's dispatcher).
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_ENTERING_WORLD", "OnRestoreWorldEvent" }

function NS.addon.OnRestoreWorldEvent(_, _, isInitialLogin, isReloadingUi)
    FR.OnEnteringWorld(isInitialLogin, isReloadingUi)
end
