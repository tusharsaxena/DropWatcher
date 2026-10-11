local _, NS = ...
-- settings/Schema.lua — the schema rows and the one write seam every settings path goes through.
--
-- One row per setting drives the panel widget, `/dw list|get|set|reset` and the defaults reset
-- (architecture-§5). The rows are declared by the page files (settings/Panel.lua) and spliced in at
-- load; this file owns the array, the seam, the reactions every surface shares, the defaults tree
-- and the global reset.

local DW = NS.addon
local L  = NS.L
local C  = NS.C

DW.Settings = DW.Settings or {}
local Settings   = DW.Settings
Settings.Schema  = {}
Settings.Helpers = Settings.Helpers or {}
local Schema  = Settings.Schema
local Helpers = Settings.Helpers

local function pout(...) return NS.Print(...) end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do c[k] = deepcopy(val) end
    return c
end

-- ── storage that is not a profile path ──────────────────────────────────────────────────────

-- Session-only rows: never SavedVariables. The console's own flag, and test mode's.
local SESSION = {
    ["state.debugConsole"] = {
        get = function()
            local DL = NS.DebugLog
            local spec = DL and DL.ConsoleCheckbox and DL:ConsoleCheckbox()
            return spec and spec.get() or false
        end,
        set = function(v)
            local DL = NS.DebugLog
            local spec = DL and DL.ConsoleCheckbox and DL:ConsoleCheckbox()
            if spec then spec.set(v and true or false) end
        end,
    },
    ["state.testMode"] = {
        get = function() return NS.State.testMode == true end,
        set = function(v) NS.SetTestMode(v and true or false) end,
    },
}

-- The Minimap button row reads and writes LibDBIcon's own `hide` in the GLOBAL store, inverted
-- (launcher-§3). There is no `shown` key anywhere.
local MINIMAP_PATH = "global.minimap.shown"
Settings.MINIMAP_PATH = MINIMAP_PATH
local function minimapStore()
    local db = DW.db
    return db and db.global and db.global.minimap
end
-- The History tab's cap (design spec §10, §12.1) is account-wide: `global.history.maxGroups`.
local HISTORY_CAP_PATH = "global.history.maxGroups"
Settings.HISTORY_CAP_PATH = HISTORY_CAP_PATH
local function historyStore(create)
    local g = DW.db and DW.db.global
    if not g then return nil end
    if create and type(g.history) ~= "table" then g.history = {} end
    return type(g.history) == "table" and g.history or nil
end

local GLOBAL = {
    [MINIMAP_PATH] = {
        get = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        set = function(v)
            v = v and true or false
            local t = minimapStore()
            if t then t.hide = not v end
            if NS.Launcher then NS.Launcher:SetShown(v) end
        end,
        backing = { "minimap", "hide" },
    },
    [HISTORY_CAP_PATH] = {
        get = function()
            local h = historyStore(false)
            return h and h.maxGroups
        end,
        set = function(v)
            local h = historyStore(true)
            if h then h.maxGroups = v end
        end,
        backing = { "history", "maxGroups" },
    },
}

--- Bind get/set closures onto the rows whose storage is not a profile path.
--- @param rows table
function Settings.StampClosureRows(rows)
    for _, row in ipairs(rows or {}) do
        local path = type(row) == "table" and row.path or nil
        local spec = SESSION[path] or GLOBAL[path]
        if spec then
            row.get = spec.get
            row.set = spec.set
        end
    end
end

-- ── the reactions every surface shares ──────────────────────────────────────────────────────

local function applyWindow()
    if NS.Window then NS.Window.ApplySettings() end
end

-- What a write to each Master controls path does, whichever surface made it: the panel checkbox,
-- the CLI, the launcher or a host verb. settings/Panel.lua binds these as the composed rows'
-- onChange; on a load where the composers are hollow the same paths are written through
-- (`writeThrough` below) and `announce` runs the same reaction.
Settings.REACTIONS = {
    enabled    = function(v)
        if NS.Lifecycle then NS.Lifecycle:Set(NS.HOLD_DISABLED, v == false) end
    end,
    visibility = applyWindow,
    scale      = applyWindow,
    alpha      = applyWindow,
    locked     = applyWindow,
}

local function announce(row, path, value)
    if row.writeThrough then
        local react = Settings.REACTIONS[path]
        if react then react(value) end
    end
    if Helpers.RefreshAll then Helpers.RefreshAll() end
end

-- ── the write seam ──────────────────────────────────────────────────────────────────────────

-- The panel checkbox, the CLI, the launcher and the resets all land in S.Set.
local S = Settings.SchemaLib:New{
    rows         = Schema,
    resolveRoot  = function() return DW.db and DW.db.profile, 1 end,
    announce     = announce,
    debug        = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    debugEnabled = function() return NS.State.debug == true end,
    print        = pout,
    -- options-ui-§1 route (a): the host verbs that write a composed row still land on a load where
    -- the composer is hollow.
    writeThrough = { "enabled", "locked" },
    -- The minimap button is a per-installation display preference: neither reset may touch it.
    resetExempt  = { [MINIMAP_PATH] = true },
}
NS.SchemaRuntime = S

Helpers.Get, Helpers.Set, Helpers.FindSchema, Helpers.ApplyDefault =
    S.Get, S.Set, S.FindRow, S.ApplyDefault
Settings.ConsumeResetCount = S.ConsumeResetCount

--- A setting's value through the seam: the stored one, or the row's default (defaults/Profile.lua)
--- while there is no database yet. The one read every module's settings go through.
--- @param path string
--- @return any
function NS.Setting(path)
    local v = S.Get(path)
    if v == nil then v = S.Default(path) end
    return v
end

--- One settings page's rows, in schema order: those whose `page` is `pageKey`.
--- @param pageKey string
--- @return table
function Settings.RowsForPage(pageKey)
    local out = {}
    for _, row in ipairs(Schema) do
        if row.page == pageKey then out[#out + 1] = row end
    end
    return out
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- How `/dw list|get|set|reset` render a value: a `map` row as its entry count (its editor is the
--- panel's), every other row through the library's own formatter.
--- @param row table
--- @param v any
--- @param format function the library's FormatValue
--- @return string
function Settings.FormatValue(row, v, format)
    if type(row) == "table" and row.type == "map" and type(v) == "table" then
        return ("{%d}"):format(countKeys(v))
    end
    return format(row, v)
end

-- `map` is a whole-value table row (architecture-§5's value route): the per-spec weights and
-- undesired-type sets, validated and written whole through the seam, drawn by their own editors.
local VALID_TYPES = { bool = true, number = true, string = true, map = true }

-- A row carrying BOTH its own get and set owns its storage, so there is no defaults entry at its
-- path: answering nil makes the library skip the resolution check for it (the session rows, and
-- the Minimap button row, whose backing key is resolved explicitly below). Every other row's path
-- must resolve against the profile defaults tree (architecture-§5).
local function defaultsRootFor(profileDefaults)
    return function(_, row)
        if row and type(row.get) == "function" and type(row.set) == "function" then return nil end
        return profileDefaults, 1
    end
end

-- Each global closure row's backing key must resolve in the GLOBAL defaults: the Minimap button
-- row's is LibDBIcon's `hide` (launcher-§3), the history cap's its own key.
local function globalBackingMissing(defaults)
    local missing = 0
    for path, spec in pairs(GLOBAL) do
        local node = defaults.global
        for _, seg in ipairs(spec.backing) do
            if type(node) == "table" then node = node[seg] else node = nil end
        end
        if node == nil then
            pout("|cffff0000schema error|r: " .. path .. ": backing key `global."
                .. table.concat(spec.backing, ".") .. "` does not resolve against the defaults")
            missing = missing + 1
        end
    end
    return missing
end

--- Validate every row; returns the error count plus the paths that do not resolve against the
--- defaults. The `schema error` lines are developer diagnostics for a malformed row, not
--- player-facing text, so they stay literal (not through NS.L).
--- @return number
function Helpers.ValidateSchema()
    local defaults = Settings.BuildDefaults()
    local errors, _, missing = S.Validate{
        types        = VALID_TYPES,
        defaultsRoot = defaultsRootFor(defaults.profile),
    }
    errors = errors + (missing or 0) + globalBackingMissing(defaults)
    for i, def in ipairs(Schema) do
        if type(def) == "table" and type(def.label) ~= "string" then
            pout("|cffff0000schema error|r: row #" .. i .. " (" .. tostring(def.path or "<no path>")
                .. "): missing or non-string `label`")
            errors = errors + 1
        end
    end
    return errors
end

-- ── defaults and the global reset ───────────────────────────────────────────────────────────

--- The AceDB defaults tree: defaults/Profile.lua's two scopes, then every stored schema row.
--- @return table
function Settings.BuildDefaults()
    local out = {
        profile = deepcopy(C.PROFILE),
        global  = deepcopy(C.GLOBAL_DEFAULTS),
    }
    for _, def in ipairs(Schema) do
        if def.path and not def.sessionOnly and not GLOBAL[def.path] then
            local segs = {}
            for part in string.gmatch(def.path, "[^.]+") do segs[#segs + 1] = part end
            local parent = out.profile
            for i = 1, #segs - 1 do
                parent[segs[i]] = parent[segs[i]] or {}
                parent = parent[segs[i]]
            end
            parent[segs[#segs]] = deepcopy(def.default)
        end
    end
    return out
end

local function notGlobal(row) return not GLOBAL[row.path] end

--- The global reset IS a profile reset (options-ui-§12); the walk keeps only session rows.
--- @param row table
--- @return boolean
function Settings.VetoedFromResetAll(row)
    return row.page == "profiles" or not row.sessionOnly
end

function Helpers.RestoreAllDefaults()
    local db = DW.db
    if db and db.ResetProfile then
        local ok, err = pcall(S.ResetCounted, function() db:ResetProfile() end, notGlobal)
        if not ok then
            NS.Debug("Set", "reset profile '%s' to defaults (stopped by an error)", db:GetCurrentProfile())
            error(err, 0)
        end
    end
    S.BulkRun("reset", "profile", function(info)
        info.profileReset = true
        for _, def in ipairs(Schema) do
            if not Settings.VetoedFromResetAll(def) then S.ApplyDefault(def) end
        end
    end)
end

function Helpers.RefreshAll()
    local H = Settings.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
end

Settings.RESET_POPUP = "DROPWATCHER_RESET_ALL"

function Settings.EnsureResetPopup()
    if Settings._resetPopupRegistered then return end
    Settings._resetPopupRegistered = true
    StaticPopupDialogs[Settings.RESET_POPUP] = {
        text         = L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."],
        button1      = YES or "Yes",
        button2      = NO  or "No",
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        preferredIndex = 3,   -- clear of the slots Blizzard's own popups take first
        OnAccept     = function()
            Helpers.RestoreAllDefaults()
            pout(L["all settings reset to defaults"])
        end,
    }
end
