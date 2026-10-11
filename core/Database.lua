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

-- ── the steps ───────────────────────────────────────────────────────────────────────────────

NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself; nothing to reshape
    { to = 2, perProfile = true,         -- 1 -> 2: every setting has a row; drop what it refuses
      run = function(_, profile) NS.RepairStoredSettings(profile) end },
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
