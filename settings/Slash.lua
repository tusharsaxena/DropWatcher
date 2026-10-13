local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table and the LibKa0s-Slash-1.0 descriptor.
--
-- The dispatcher, help renderer, formatters and value parser are the library's (slash-commands-§1).
-- What stays here is the ordered verb table (positional triples {name, desc, fn}) and the host verbs
-- that reach into this addon's own state. Every verb that toggles something calls the same handler
-- its Master controls row and its launcher entry call (core/DropWatcher.lua). The design spec's
-- feature verbs (§12.3) follow the window verbs: `scan`, `compact` and `full` call the window's own
-- host handlers; `clear`, `history`, `situation`, `offer` and `add` are slash-only and answered
-- by settings/SlashVerbs.lua. The simulator's `sim` (simulator spec §4) is answered by
-- settings/SimVerbs.lua.

local DW = NS.addon
local L  = NS.L

local SLASH = NS.SLASH

local function helpers() return DW.Settings and DW.Settings.Helpers end
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local ENABLED_PATH = "enabled"

local Sl   -- forward-declared: the handlers below reach it at call time
local runConfig, runDebug, runReset, runResetAll, runEnabled, runPerf

local COMMANDS = {
    {"help",     L["List available commands"],
        function() Sl:PrintHelp() end},
    {"config",   L["Open the Ka0s Drop Watcher settings panel"],
        function() runConfig() end},
    {"enable",   L["Enable the addon"],
        function() runEnabled(true) end},
    {"disable",  L["Disable the addon"],
        function() runEnabled(false) end},
    {"version",  L["Print the addon version"],
        function() Sl:CliVersion() end},
    {"list",     L["List every setting and its current value"],
        function() Sl:CliList() end},
    {"get",      L["Print a setting's current value — `/dw get <path>`"],
        function(rest) Sl:CliGet(rest) end},
    {"set",      L["Set a setting — `/dw set <path> <value>` (try /dw list)"],
        function(rest) Sl:CliSet(rest) end},
    {"reset",    L["Reset one setting to its default — `/dw reset <path>`"],
        function(rest) runReset(rest) end},
    {"resetall", L["Reset every setting to defaults"],
        function() runResetAll() end},
    {"profile",  L["List profiles, or switch to one: profile <name>"],
        function(rest) Sl:CliProfile(rest) end},
    {"debug",    L["Open/close the debug window — `/dw debug on|off` toggles logging"],
        function(rest) runDebug(rest) end},
    {"diagnostics", L["Write the diagnostics report to the debug console"],
        function() NS.DebugLog:RunDiagnostics() end},
    {"perf",     L["Measure performance — `/dw perf` opens the step panel"],
        function(rest) runPerf(rest) end},
    {"lock",     L["Lock the window in place"],
        function() NS.SetLocked(true) end},
    {"unlock",   L["Unlock the window so it can be moved and resized"],
        function() NS.SetLocked(false) end},
    {"show",     L["Show the window"],
        function() NS.ShowWindow() end},
    {"hide",     L["Hide the window"],
        function() NS.HideWindow() end},
    {"toggle",   L["Show or hide the window"],
        function() NS.ToggleWindow() end},
    {"test",     L["Turn test mode on or off (sample drops; combat ends it)"],
        function() NS.ToggleTestMode() end},
    {"scan",     L["Inspect the whole group, one member at a time"],
        function() NS.ScanGroup() end},
    {"clear",    L["Clear this session's drops from the feed"],
        function() NS.SlashVerbs.Clear() end},
    {"history",  L["Open the History tab"],
        function() NS.SlashVerbs.OpenTab("history") end},
    {"compact",  L["Switch the window between its compact and full view"],
        function() NS.SlashVerbs.Compact() end},
    {"full",     L["Show the window in its full view"],
        function() NS.SlashVerbs.Full() end},
    {"situation", L["Print the situation, its settings and the classifier's inputs"],
        function() NS.SlashVerbs.Situation() end},
    {"offer",    L["Open the Offer panel for a bag item — `/dw offer <item link>`"],
        function(rest) NS.SlashVerbs.Offer(rest) end},
    {"add",      L["Inject a drop for testing — `/dw add <item link> [player]`"],
        function(rest) NS.SlashVerbs.Add(rest) end},
    {"sim",      L["Simulate a group session through the real engine — `/dw sim` for its verbs"],
        function(rest) NS.SimVerbs.Run(rest) end},
}
NS.COMMANDS = COMMANDS

local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local CLI_MISSING = L["%s, so the settings CLI is unavailable."]:format(NS.LIBKA0S_MISSING)

local function libraryAbsent(verb)
    NS.Print(L["%s is unavailable: the LibKa0s library did not load."]:format(verb))
end

-- The gate the dispatcher asks: the STORED switch, not the latch. A perf capture holds the latch
-- too, and is a reason to be inert, never a reason to refuse the player's verbs.
local function storedEnabled()
    local S = NS.SchemaRuntime
    return not (S and S.Get(ENABLED_PATH) == false)
end

if not lib then
    -- Degrade, never error: `/dw` is registered unconditionally, so something must answer. The
    -- host verbs keep working; the schema CLI names the missing library. The ONE library string the
    -- stub carries verbatim is DISABLED_LINE_FORMAT, pinned by Kit.assertLibraryConstant.
    local function unavailable() NS.Print(CLI_MISSING) end
    local function profileAbsent() libraryAbsent(SLASH .. " profile") end
    local DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"

    local function helpRow(entry) return SLASH .. " " .. entry[1] .. " — " .. entry[2] end

    -- The verbs that answer while disabled: the standard's reserved set, plus `profile`. Any other
    -- verb the addon ships prints the one refusal line instead (slash-commands-§2).
    local LIVE = { help = true, config = true, version = true, enable = true, disable = true,
        debug = true, perf = true, diagnostics = true, get = true, set = true, list = true,
        reset = true, resetall = true, profile = true }

    Sl = {
        OnSlash = function(_, msg)
            local raw = trim(msg)
            if raw == "" then return runConfig() end
            local name, rest = raw:match("^(%S+)%s*(.*)$")
            name = (name or ""):lower()
            for _, entry in ipairs(COMMANDS) do
                if entry[1] == name then
                    if not (LIVE[name] or storedEnabled()) then return NS.Print(Sl:DisabledLine()) end
                    return entry[3](rest or "")
                end
            end
            NS.Print(L["unknown command '%s'"]:format(name))
            Sl:PrintHelp()
        end,
        PrintHelp = function()
            NS.Print(L["v%s slash commands"]:format(NS.Version()))
            for _, entry in ipairs(COMMANDS) do NS.Print("  " .. helpRow(entry)) end
        end,
        HelpRows = function()
            local out = {}
            for i, entry in ipairs(COMMANDS) do out[i] = "  " .. helpRow(entry) end
            return out
        end,
        LandingRows = function()
            local out = {}
            for i, entry in ipairs(COMMANDS) do out[i] = helpRow(entry) end
            return out
        end,
        HelpHeader   = function() return L["v%s slash commands"]:format(NS.Version()) end,
        DisabledLine = function() return DISABLED_LINE_FORMAT:format(NS.BRAND, SLASH .. " enable") end,
        __disabledLineFormat = DISABLED_LINE_FORMAT,
        CliList         = unavailable,
        CliGet          = unavailable,
        CliSet          = unavailable,
        CliReset        = unavailable,
        CliResetAll     = unavailable,
        CliVersion      = function() NS.Print("v" .. NS.Version()) end,
        BuildListLines  = function() return { CLI_MISSING } end,
        SetRowAnnotator = function() end,
        Text            = function(_, key) return key end,
        CliProfile      = function() profileAbsent() end,
        ProfileSwitch   = function() profileAbsent(); return false end,
    }
    NS.SlashCommands = Sl
else
    -- `profile` answers while disabled too: it is how a player reaches an enabled profile.
    local liveVerbs = {}
    for i, verb in ipairs(lib.LIVE_VERBS) do liveVerbs[i] = verb end
    liveVerbs[#liveVerbs + 1] = "profile"

    Sl = lib:New({
        slash        = SLASH,
        slashAliases = { NS.SLASH_ALIAS },
        commands     = COMMANDS,                       -- passed IN, never owned by the library
        isEnabled    = storedEnabled,
        brandName    = NS.BRAND,
        liveVerbs    = liveVerbs,
        profiles     = function() return DW.db end,
        print        = function(line) NS.Print(line) end,
        debug        = function(tag, message) NS.Debug(tag, message) end,
        version      = NS.Version,
        get          = NS.SchemaRuntime.Get,
        set          = NS.SchemaRuntime.Set,           -- the single write seam
        findRow      = NS.SchemaRuntime.FindRow,
        allRows      = function() return DW.Settings.Schema end,
        applyDefault = NS.SchemaRuntime.ApplyDefault,
        bulkBegin    = NS.SchemaRuntime.BulkBegin,
        bulkEnd      = NS.SchemaRuntime.BulkEnd,
        groupKey     = function(row) return row.page or "general" end,
        format       = function(row, v) return DW.Settings.FormatValue(row, v, lib.FormatValue) end,
    })
    NS.SlashCommands = Sl
end

--- Open the settings panel (registering the category first if OnEnable has not run yet).
function DW:OpenSettings()
    if self.Settings and self.Settings.Register then self.Settings.Register() end
    local H = helpers()
    if not (H and H.OpenOptionsPanel) then return NS.Print(L["Settings panel is not available."]) end
    H.OpenOptionsPanel()
end

function runConfig() DW:OpenSettings() end

-- `/dw enable|disable`: aliases writing the Enable row's stored path through the write seam. On a
-- library-absent load the path is written through (settings/Schema.lua `writeThrough`).
function runEnabled(on)
    local S = NS.SchemaRuntime
    local ok, err = S.Set(ENABLED_PATH, on)
    if ok == false then return NS.Print(tostring(err)) end
    local value = S.Get(ENABLED_PATH)
    local row = S.FindRow(ENABLED_PATH)
    if lib and row then return NS.Print(lib.FormatKV(row.path, lib.FormatValue(row, value))) end
    NS.Print(ENABLED_PATH .. " = " .. tostring(value))
end

function runReset(rest)
    if trim(rest) == "" then
        NS.Print(L["|cffFFFF00%s|r takes a setting path: |cffFFFF00%s|r (try |cffFFFF00%s|r). To reset everything: |cffFFFF00%s|r."]
            :format(SLASH .. " reset", SLASH .. " reset <path>", SLASH .. " list", SLASH .. " resetall"))
        return
    end
    Sl:CliReset(rest)
end

function runResetAll()
    local H = helpers()
    if not (H and H.RestoreAllDefaults) then return NS.Print(CLI_MISSING) end
    DW.Settings.EnsureResetPopup()
    StaticPopup_Show(DW.Settings.RESET_POPUP)
end

-- `diagnostics` is tested FIRST (inside DebugVerb), then on/off; anything else toggles the window.
function runDebug(rest)
    local DL = NS.DebugLog
    if not DL:DebugVerb(rest) then DL:Toggle() end
end

-- The library returns the lines; the addon prints them (performance-§4).
function runPerf(rest)
    for _, line in ipairs(NS.Perf.OnCommand(rest) or {}) do NS.Print(line) end
end

function DW:SlashEnabled(on) runEnabled(on and true or false) end

function DW:OnSlashCommand(input)
    Sl:OnSlash(input)
end
