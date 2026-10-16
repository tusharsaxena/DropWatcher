local _, NS = ...
-- core/Database.lua — the schemaVersion migration runner (savedvariables-§1).
--
-- The defaults tree is built by settings/Schema.lua's Settings.BuildDefaults (profile rows from the
-- schema, plus defaults/Profile.lua's tables) and handed to AceDB in OnInitialize, which runs this
-- runner straight after AceDB:New, before anything reads db.profile, and again from every profile
-- callback. global.schemaVersion defaults to 0, never the current version: AceDB strips a value
-- equal to its default at logout and would backfill it onto a legacy account.
--
-- The runner owns the stamp: it advances it to a step's `to` only after that step returned, so a
-- step that raises is retried on the next load. A `perProfile` step runs for EVERY stored profile
-- (the raw SavedVariables `profiles` table), not only the active one. Each step is idempotent
-- against a fresh default profile.

-- ── step 2: the settings rows (DW-40) ───────────────────────────────────────────────────────

-- The Lua type each declared row type stores.
local STORED_TYPE = { bool = "boolean", number = "number", string = "string", map = "table" }

-- Whether `row` refuses the stored `v`: the wrong type, or its own check says no.
local function refuses(row, v)
    local want = STORED_TYPE[row.type]
    if want and type(v) ~= want then return true end
    if type(row.validate) ~= "function" then return false end
    local ok, pass = pcall(row.validate, v)
    return not (ok and pass)
end

-- Clears one row's stored leaf in a raw profile when the row refuses it; answers 1 when it did.
local function repairLeaf(profile, row)
    local parts = {}
    for seg in row.path:gmatch("[^.]+") do parts[#parts + 1] = seg end
    local node = profile
    for i = 1, #parts - 1 do
        node = node[parts[i]]
        if type(node) ~= "table" then return 0 end
    end
    local leaf = parts[#parts]
    local v = node[leaf]
    if v == nil or not refuses(row, v) then return 0 end
    node[leaf] = nil
    return 1
end

-- The rows whose storage is a profile path: not session-only, no closure of their own.
local function profileRows()
    local S = NS.addon and NS.addon.Settings
    local out = {}
    for _, row in ipairs(S and S.Schema or {}) do
        if type(row) == "table" and type(row.path) == "string" and not row.sessionOnly
            and type(row.set) ~= "function" then
            out[#out + 1] = row
        end
    end
    return out
end

--- Step 2's work on one stored profile. Before the settings rows existed, a few paths were written
--- straight onto the profile (`feed.quality.mode`, `window.compact`) and others were read with
--- forgiving fallbacks (`trade.rules`, `messages.*`, `situations.*`): a stored value the row now
--- refuses is dropped, so the default shows and the next write goes through the seam's checks. A
--- valid value, and every default, passes through unchanged.
--- @param profile table a raw stored profile
--- @return number the leaves cleared
function NS.RepairStoredSettings(profile)
    if type(profile) ~= "table" then return 0 end
    local cleared = 0
    for _, row in ipairs(profileRows()) do cleared = cleared + repairLeaf(profile, row) end
    return cleared
end

-- ── step 3: the View becomes a set (DW-A1, feedback-2 spec §1) ──────────────────────────────

-- The three filter bar checkboxes that became View values: where each was stored, and its value.
local FOLDED = {
    { parent = "trade", leaf = "likelyOnly", view = "likely" },
    { parent = "feed", leaf = "usableOnly", view = "usable" },
    { parent = "feed", leaf = "upgradeOnly", view = "upgrade" },
}

-- The set an old `feed.view` string stands for. AceDB strips a value equal to its default at
-- logout, so a stored `interesting` (the old default) is rare: kept when it is there, and a profile
-- that only inherited the old default stores nothing and opens on the new one, All.
local function viewFrom(old)
    if type(old) == "table" then return old end
    return old == "interesting" and { interesting = true } or {}
end

-- Moves each folded checkbox that was on into the set, and drops its old leaf.
local function foldChecks(profile, set)
    for _, f in ipairs(FOLDED) do
        local parent = profile[f.parent]
        if type(parent) == "table" then
            if parent[f.leaf] == true then set[f.view] = true end
            parent[f.leaf] = nil
        end
    end
end

--- Step 3's work on one stored profile: `feed.view` becomes a set ({ [value] = true }), and
--- `trade.likelyOnly`, `feed.usableOnly` and `feed.upgradeOnly` fold into it, so each player keeps
--- the choices they had. Idempotent: a profile already in the new shape passes through.
--- @param profile table a raw stored profile
function NS.MigrateViewSet(profile)
    if type(profile) ~= "table" then return end
    local feed = type(profile.feed) == "table" and profile.feed or nil
    local set = viewFrom(feed and feed.view)
    foldChecks(profile, set)
    if next(set) == nil then
        if feed and type(feed.view) ~= "table" then feed.view = nil end
        return
    end
    profile.feed = feed or {}
    profile.feed.view = set
end

--- Step 4's work: the History's group cap, `global.history.maxGroups`, is retired (feedback-2 spec
--- §5: the History is kept by days now). Only the key goes; nothing is pruned here.
--- @param sv table|nil the raw SavedVariables
function NS.RetireHistoryCap(sv)
    local g = type(sv) == "table" and sv.global
    local h = type(g) == "table" and g.history
    if type(h) == "table" then h.maxGroups = nil end
end

-- ── step 5: compact mode (DW-C0, compact spec §1) ───────────────────────────────────────────

-- The geometry the single-layout window stored straight on `window`, now the full layout's.
local GEOMETRY_KEYS = { "point", "width", "height" }

-- Moves `window.point`, `width` and `height` into `window.geometry.full`, keeping any value
-- already there.
local function moveGeometry(w)
    local full
    for _, k in ipairs(GEOMETRY_KEYS) do
        if w[k] ~= nil then
            if type(w.geometry) ~= "table" then w.geometry = {} end
            full = full or (type(w.geometry.full) == "table" and w.geometry.full) or {}
            if full[k] == nil then full[k] = w[k] end
            w[k] = nil
        end
    end
    if full then w.geometry.full = full end
end

--- Step 5's work on one stored profile: the retired compact preset (`window.compact = true`)
--- becomes the compact layout (`window.mode = "compact"`) and its key goes; the window's single
--- geometry becomes the full layout's (`window.geometry.full`). The preset decides the layout even
--- over a `mode` already there: AceDB's defaults can answer `full` for a key the player never set,
--- and a profile that held the preset never chose a layout. Idempotent: the preset's key goes, so a
--- profile already in the new shape passes through.
--- @param profile table a raw stored profile
function NS.MigrateWindowMode(profile)
    local w = type(profile) == "table" and profile.window
    if type(w) ~= "table" then return end
    if w.compact == true then w.mode = "compact" end
    w.compact = nil
    moveGeometry(w)
end

-- ── step 6: own drops always listed (DW-E2, feedback-5 spec §2) ─────────────────────────────

--- Step 6's work on one stored profile: `feed.showOwn` (Show my own loot in Group drops) is retired,
--- since Drops always lists your own drops; only the key goes.
--- @param profile table a raw stored profile
function NS.RetireShowOwn(profile)
    local feed = type(profile) == "table" and profile.feed
    if type(feed) == "table" then feed.showOwn = nil end
end

-- ── step 7: My eq and Their eq merged into Me and Them (DW-F1, feedback-6 spec §1) ──────────

--- Step 7's work on one stored profile: the `window.columns` toggles `myEq` and `theirEq` are
--- retired, since the worn gear now shows in the Me and Them cells (which `me` and `them` toggle);
--- only the two keys go.
--- @param profile table a raw stored profile
function NS.RetireEqColumns(profile)
    local w = type(profile) == "table" and profile.window
    local cols = type(w) == "table" and w.columns
    if type(cols) == "table" then cols.myEq, cols.theirEq = nil, nil end
end

-- ── step 8: Content: All is History's alone (DW-Q1, feedback-15 spec §1) ────────────────────

--- Step 8's work on one stored profile: `feed.content` no longer offers `all` (the Drops tab holds
--- this session's drops alone; History opens on All by itself), so a stored `all` becomes
--- `session`, the row's default. Idempotent: anything else passes through.
--- @param profile table a raw stored profile
function NS.MigrateContentAll(profile)
    local feed = type(profile) == "table" and profile.feed
    if type(feed) == "table" and feed.content == "all" then feed.content = "session" end
end

-- ── the steps ───────────────────────────────────────────────────────────────────────────────

NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself; nothing to reshape
    { to = 2, perProfile = true,         -- 1 -> 2: every setting has a row; drop what it refuses
      run = function(_, profile) NS.RepairStoredSettings(profile) end },
    { to = 3, perProfile = true,         -- 2 -> 3: the View is a set; its checkboxes fold into it
      run = function(_, profile) NS.MigrateViewSet(profile) end },
    { to = 4, run = function(sv) NS.RetireHistoryCap(sv) end },   -- 3 -> 4: History by days
    { to = 5, perProfile = true,         -- 4 -> 5: compact mode; the window's geometry per layout
      run = function(_, profile) NS.MigrateWindowMode(profile) end },
    { to = 6, perProfile = true,         -- 5 -> 6: own drops always listed; their switch goes
      run = function(_, profile) NS.RetireShowOwn(profile) end },
    { to = 7, perProfile = true,         -- 6 -> 7: the eq columns merged into Me and Them; toggles go
      run = function(_, profile) NS.RetireEqColumns(profile) end },
    { to = 8, perProfile = true,         -- 7 -> 8: Content: All is History's alone; a stored one is session
      run = function(_, profile) NS.MigrateContentAll(profile) end },
}

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = NS.MIGRATIONS[#NS.MIGRATIONS].to

local function runStep(db, step)
    local sv = db.sv
    if not step.perProfile then return step.run(sv) end
    local profiles = type(sv) == "table" and sv.profiles
    for _, profile in pairs(type(profiles) == "table" and profiles or {}) do
        if type(profile) == "table" then step.run(sv, profile) end
    end
end

function NS:RunMigrations()
    local db = self.db
    local g = db and db.global
    if not g then return end
    local from = g.schemaVersion or 0
    for _, step in ipairs(NS.MIGRATIONS) do
        if (g.schemaVersion or 0) < step.to then
            runStep(db, step)
            g.schemaVersion = step.to   -- the runner owns the stamp; reached only if the step returned
        end
    end
    local D = NS.DebugLog
    if from ~= g.schemaVersion and D and D.DebugAtEnable then
        D.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
end
