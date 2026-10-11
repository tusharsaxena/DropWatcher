local _, NS = ...
-- modules/HistoryRetention.lua — how long the History is kept (feedback-2 spec §5, FB2-7), like Ka0s
-- Loot History's "Keep history for" (../LootHistory/settings/Schema.lua, settings.retentionDays,
-- and its S:OnRetentionChanged).
--
-- THE SETTING. `global.history.retentionDays` (settings/Schema.lua's account-wide closure row, the
-- `Keep history for` dropdown): 7, 14, 30, 60, 90 or 180 days, or 0, "Never delete". The default is
-- 30 (defaults/Profile.lua, GLOBAL_DEFAULTS). It is account-wide, beside the data in
-- `global.history`, so a profile switch, copy or reset never changes it. It replaced the group cap,
-- `maxGroups`, which the schema's step 4 (core/Database.lua) removes; that step prunes nothing.
--
-- WHAT IS PRUNED. A group whose newest entry (its latest `at`; the group's own `at` when it has no
-- entry) is older than the window, whole. The prune runs once per session, CLEANUP_DELAY seconds
-- after the first PLAYER_ENTERING_WORLD (off the login spike, on a cancelable timer the stand-down
-- takes back), over the account's log (NS.History.Store), and again when the setting changes to a
-- window that would delete something, once the player confirms it.
--
-- THE CONFIRMATION. A change that would delete anything asks first ("This deletes n groups (m
-- drops) older than X days."); the popup takes preferredIndex 3. Yes prunes; No writes back the
-- value the player last agreed to (`confirmed`, seeded by Sync at OnInitialize), so nothing is
-- deleted at the next login either. A change that deletes nothing is taken at once. The count and
-- the prune cover the account's log and, while test mode or a simulation shows its own session-only
-- log (NS.History.Log), that one too, so test mode's older sample group can be pruned without
-- touching the account's.
--
-- THE CEILING. However long the window (Never included), the account's log holds at most
-- NS.History.CEILING drops, the oldest dropped first (NS.History.Trim, on every recording); it is
-- a constant, not a setting, and the diagnostics report it.
--
-- PURE: Label, Choices, FooterText, NewestAt, Count and Prune take plain tables, the days and the clock as arguments and
-- read nothing else; test_history_retention drives them. The edge reads the setting, the logs, the
-- popup and the clock at call time.

NS.HistoryRetention = NS.HistoryRetention or {}
local R = NS.HistoryRetention
local L = NS.L

local TAG = "FEED"

R.DAY = 86400
R.DEFAULT_DAYS = 30
R.CLEANUP_DELAY = 5
R.POPUP = "DROPWATCHER_HISTORY_RETENTION"
R.PATH = "global.history.retentionDays"

-- The dropdown's values, in order: the days, then 0 (never delete).
R.DAYS = { 7, 14, 30, 60, 90, 180, 0 }

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- The window as words: "30 days", or "Never delete" for 0.
--- @param days number
--- @return string
function R.Label(days)
    days = num(days) or 0
    if days <= 0 then return L["Never delete"] end
    return L["%d days"]:format(days)
end

--- The dropdown's value list, in the ordered-array shape the Options dropdown reads.
--- @return table
function R.Choices()
    local out = {}
    for i, d in ipairs(R.DAYS) do out[i] = { value = d, text = R.Label(d) } end
    return out
end

--- The History footer: "n groups, m drops · kept for 30 days", or "· kept forever".
--- @param groups number
--- @param drops number
--- @param days number
--- @return string
function R.FooterText(groups, drops, days)
    days = num(days) or 0
    if days <= 0 then return L["%d groups, %d drops · kept forever"]:format(groups, drops) end
    return L["%d groups, %d drops · kept for %s"]:format(groups, drops, R.Label(days))
end

--- When a group was last added to: its newest entry's `at`, else its own `at`, else 0.
--- @param group table
--- @return number
function R.NewestAt(group)
    local newest = num(group.at) or 0
    for _, e in ipairs(type(group.drops) == "table" and group.drops or {}) do
        local at = num(e.at)
        if at and at > newest then newest = at end
    end
    return newest
end

-- The groups a window of `days` deletes at `now`: their indices, oldest first. None for 0 days.
local function expired(hist, days, now)
    local out = {}
    days = num(days) or 0
    if days <= 0 or type(hist) ~= "table" or type(hist.groups) ~= "table" then return out end
    local cutoff = now - days * R.DAY
    for i, g in ipairs(hist.groups) do
        if R.NewestAt(g) < cutoff then out[#out + 1] = i end
    end
    return out
end

--- What a window of `days` would delete at `now`, deleting nothing.
--- @param hist table|nil
--- @param days number
--- @param now number time()
--- @return number groups
--- @return number drops
function R.Count(hist, days, now)
    local groups, drops = 0, 0
    for _, i in ipairs(expired(hist, days, now)) do
        groups, drops = groups + 1, drops + #(hist.groups[i].drops or {})
    end
    return groups, drops
end

--- Delete the groups a window of `days` puts out of reach at `now`; each deleted entry is marked
--- `gone` for History's session index.
--- @param hist table|nil
--- @param days number
--- @param now number time()
--- @return number groups
--- @return number drops
function R.Prune(hist, days, now)
    local list = expired(hist, days, now)
    local drops = 0
    for k = #list, 1, -1 do
        local g = table.remove(hist.groups, list[k])
        for _, e in ipairs(g.drops or {}) do e.gone = true end
        drops = drops + #(g.drops or {})
    end
    return #list, drops
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local confirmed       -- the stored window the player last agreed to (Sync seeds it)
local restoring = false
local timer           -- the login prune's pending timer
local loginSeen, loginDone = false, false

local function clock() return time() end

--- The window in force: `global.history.retentionDays`, through the schema seam.
--- @return number days (0 = never delete)
function R.Days()
    return num(NS.Setting and NS.Setting(R.PATH)) or R.DEFAULT_DAYS
end

--- Seed the confirmed window from the store (OnInitialize, after the migrations).
function R.Sync()
    confirmed = R.Days()
end

-- The logs a change governs: the account's, and the shown session-only log when it differs.
local function logs()
    local H = NS.History
    local store, shown = H.Store(), H.Log()
    local out = {}
    if store then out[#out + 1] = store end
    if shown and shown ~= store then out[#out + 1] = shown end
    return out
end

--- What a window of `days` would delete now, over every log it governs.
--- @param days number
--- @return number groups, number drops
function R.CountAll(days)
    local groups, drops, now = 0, 0, clock()
    for _, hist in ipairs(logs()) do
        local g, d = R.Count(hist, days, now)
        groups, drops = groups + g, drops + d
    end
    return groups, drops
end

local function changed()
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
end

--- Prune every log the window governs, now; HistoryChanged when anything went.
--- @param days number
--- @return number groups, number drops
function R.PruneAll(days)
    local groups, drops, now = 0, 0, clock()
    for _, hist in ipairs(logs()) do
        local g, d = R.Prune(hist, days, now)
        groups, drops = groups + g, drops + d
    end
    if groups > 0 then
        NS.Debug(TAG, "history: kept for %s, deleted %d groups (%d drops)", R.Label(days), groups, drops)
        changed()
    end
    return groups, drops
end

--- The session's prune of the account's log (the login deferral). Once per session.
function R.LoginPrune()
    timer = nil
    if loginDone then return end
    loginDone = true
    local hist, days = NS.History.Store(), R.Days()
    if not hist then return end
    local groups, drops = R.Prune(hist, days, clock())
    NS.Debug(TAG, "history: login prune, kept for %s: deleted %d groups (%d drops)", R.Label(days), groups, drops)
    if groups > 0 then changed() end
end

local function schedule()
    if timer or loginDone or not loginSeen then return end
    timer = C_Timer.NewTimer(R.CLEANUP_DELAY, R.LoginPrune)
end

--- PLAYER_ENTERING_WORLD: the first one arms the session's prune, deferred.
function R.OnEnteringWorld()
    loginSeen = true
    schedule()
end

--- Write `days` through the seam without asking again (the confirmation's own write).
local function writeQuietly(days)
    restoring = true
    local ok, err = pcall(NS.SchemaRuntime.Set, R.PATH, days)
    restoring = false
    if not ok then error(err, 0) end
end

local function ensurePopup()
    if StaticPopupDialogs[R.POPUP] then return end
    StaticPopupDialogs[R.POPUP] = {
        text = L["This deletes %s older than %s. This cannot be undone."],
        button1 = YES or "Yes", button2 = NO or "No",
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        preferredIndex = 3,   -- clear of the slots Blizzard's own popups take first
        OnAccept = function(_, data) R.Confirm(data and data.days, true) end,
        -- A newer change re-shows the popup with reason "override": not the player's No.
        OnCancel = function(_, data, reason)
            if reason == "override" then return end
            R.Confirm(data and data.days, false)
        end,
    }
end

--- The row's onChange: a window that deletes nothing is taken at once; one that would delete asks
--- first (prunes at once when nothing can ask).
--- @param days number
function R.OnChanged(days)
    if restoring then return end
    local groups, drops = R.CountAll(days)
    if groups == 0 then confirmed = days; return end
    if type(StaticPopup_Show) ~= "function" then
        R.PruneAll(days)
        confirmed = days
        return
    end
    ensurePopup()
    local what = L["%d groups (%d drops)"]:format(groups, drops)
    StaticPopup_Show(R.POPUP, what, R.Label(days), { days = days })
end

--- The confirmation's two answers. Yes stores the window agreed to (the store may have moved while
--- the popup was open) and prunes to it; No writes back the last confirmed window and says so.
--- @param days number
--- @param accepted boolean
function R.Confirm(days, accepted)
    if accepted and num(days) then
        if R.Days() ~= days then writeQuietly(days) end
        R.PruneAll(days)
        confirmed = days
        return
    end
    local keep = confirmed or R.DEFAULT_DAYS
    writeQuietly(keep)
    NS.Print(L["History is kept for %s; nothing was deleted."]:format(R.Label(keep)))
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- PLAYER_ENTERING_WORLD is shared (core/DropWatcher.lua's dispatcher).
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_ENTERING_WORLD", "OnRetentionWorldEvent" }

function NS.addon.OnRetentionWorldEvent()
    R.OnEnteringWorld()
end

-- The stand-down takes the pending prune back; the stand-up arms it again if it never ran.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if timer then timer:Cancel() end
    timer = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = schedule
