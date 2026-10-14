#!/usr/bin/env lua
-- tests/run.lua
--
-- Headless test runner for Ka0s Drop Watcher, on the shared LibKa0s test kit (testing-§1). The
-- registry, assertions, runner, `--list` renderer, sandboxed loader and TOC reader come from
-- tests/_kit/ and are never edited here. What stays is this addon's: the instance factory
-- (tests/loader.lua), the mock extender (tests/wow_mock.lua), the three lifecycle factories below,
-- the surface-parity source map, the kit suites' consumer facts and the ordered suite list.
--
-- Run from the repo root:
--   lua tests/run.lua          -- run all suites (non-zero exit on failure)
--   lua tests/run.lua --list   -- print docs/test-cases.md's body; run nothing

local Kit  = dofile("tests/_kit/framework.lua")
local mock = dofile("tests/wow_mock.lua")

local root      = "."
local loadAddon = dofile("tests/loader.lua")(root, mock)

-- THE THREE FACTORIES. Each returns (NS, env, mock) -- env and mock are the same table -- and each
-- takes the same `opts` table (tests/loader.lua: skip, mock, and the mock fields). Fresh per call.

-- Every file loaded; nothing run.
local function newAddon(opts)
    return loadAddon(opts)
end

-- ... plus OnInitialize (ADDON_LOADED): the db exists, migrations have run.
local function bootAddon(opts)
    local NS, env, m = newAddon(opts)
    NS.addon:OnInitialize()
    return NS, env, m
end

-- ... plus OnEnable (PLAYER_LOGIN): events registered, settings category and launcher registered,
-- and the latch taken from the stored `enabled` path.
local function enableAddon(opts)
    local NS, env, m = bootAddon(opts)
    NS.addon:OnEnable()
    return NS, env, m
end

-- Where Kit.assertSurfaceParity's by-name form finds the LIVE half. Instances, not library tables,
-- because each stub mirrors what `lib:New(descriptor)` returned. One extra load, used for nothing
-- else and handed to no case.
local surfaceNS, surfaceMock = loadAddon()
Kit.setSurfaceSource{
    ["LibKa0s-DebugLog-1.0"]  = surfaceNS.DebugLog,
    ["LibKa0s-Slash-1.0"]     = surfaceNS.SlashCommands,
    ["LibKa0s-Options-1.0"]   = surfaceNS.addon.Settings.Helpers,
    ["LibKa0s-Launcher-1.0"]  = surfaceNS.Launcher,
    ["LibKa0s-Lifecycle-1.0"] = surfaceNS.Lifecycle,
    ["LibKa0s-Schema-1.0"]    = surfaceMock.LibStub("LibKa0s-Schema-1.0", true),
    ["LibKa0s-Pool-1.0"]      = surfaceMock.LibStub("LibKa0s-Pool-1.0", true),
    ["LibKa0s-Item-1.0"]      = surfaceMock.LibStub("LibKa0s-Item-1.0", true),
    ["LibKa0s-Compat-1.0"]    = surfaceMock.LibStub("LibKa0s-Compat-1.0", true),
}

-- A text's inline texture escapes (NS.TipMarks) as `[icon]`: `291 [arrow-right] 305`, `[arrow-up]
-- UPGRADE`. A case reads the text the player sees; test_tip_marks pins each escape's exact string.
local function marks(s)
    return (tostring(s):gsub("|T[^:|]-([^\\:|]+):[^|]*|t", "[%1]"))
end

-- A tooltip line as plain text (NS.TipMarks.Text's reading, without an instance): a string as it
-- is, a non-wrapping line by its text, a grid (feedback-7 spec §3) as its rows on lines of their
-- own, each row's drawn cells (glyph and text) two spaces apart.
local function tipText(line)
    if type(line) ~= "table" then return tostring(line) end
    if type(line.grid) ~= "table" then return tostring(line.text) end
    local rows = {}
    for i, row in ipairs(line.grid) do
        local cells = {}
        for _, cell in ipairs(row) do
            local t = type(cell) == "table" and ((cell.glyph or "") .. tostring(cell.text or "")) or tostring(cell or "")
            if t ~= "" then cells[#cells + 1] = t end
        end
        rows[i] = table.concat(cells, "  ")
    end
    return table.concat(rows, "\n")
end

-- A tooltip's lines joined by `sep` (" | " when nil), each read by tipText.
local function tipJoined(tip, sep)
    local out = {}
    for i, l in ipairs(tip or {}) do out[i] = tipText(l) end
    return table.concat(out, sep or " | ")
end

-- The table every suite reaches as `local T = _G.DW_TEST`. Kit.expose merges `test` and the kit
-- assertions in beside these keys.
_G.DW_TEST = Kit.expose{
    newAddon    = newAddon,
    bootAddon   = bootAddon,
    enableAddon = enableAddon,
    loadAddon   = loadAddon,
    marks       = marks,
    tipText     = tipText,
    tipJoined   = tipJoined,
    root        = root,
    LibStub     = surfaceMock.LibStub,
    KIT_VERSION = Kit.VERSION,
    -- The kit's secret-value simulator (tests/_kit/secrets.lua), which Kit.expose leaves out.
    secret      = Kit.secret,
    isSecret    = Kit.isSecret,
}

-- The diagnostics-dump contract's consumer facts (debug-logging-§14): the kit's cases run through
-- THIS addon's dispatcher, on a fresh, fully enabled instance per case, and "disabled" goes through
-- the same write seam the Master controls checkbox and `/dw disable` use.
local diagNS
Kit.diagnostics = {
    brand       = "Ka0s Drop Watcher",
    dispatch    = function(line) diagNS.addon:OnSlashCommand(line) end,
    console     = function() return diagNS.DebugLog end,
    setDebug    = function(on) diagNS.State.debug = on and true or false end,
    setDisabled = function(off) diagNS.SchemaRuntime.Set("enabled", not off) end,
    reset       = function() diagNS = enableAddon() end,
}

-- The layout-§1 census lives in the hub; the repository has no generated data to carve out.
Kit.layoutCap = { hub = "docs/ARCHITECTURE.md" }

-- Order is stable. Kit.assertSuiteInventory (called by Kit.run) fails the run in both directions:
-- a name here with no file, and a test_*.lua on disk (tests/ or tests/_kit/) with no name here.
Kit.run{
    dir    = "tests/",
    suites = {
        "test_harness",
        "test_surface_parity",
        "test_setup",
        "test_database",
        "test_schema",
        "test_schema_rows",
        "test_settings_pages",
        "test_slash",
        "test_window",
        "test_window_shell",
        "test_window_compact",
        "test_compact_cards",
        "test_compact_group",
        "test_compact_history",
        "test_compact_chrome",
        "test_compact_modes",
        "test_window_group",
        "test_drops_layout",
        "test_side_cells",
        "test_detail_card",
        "test_own_drops",
        "test_tip_marks",
        "test_drops_strip",
        "test_offer_panel",
        "test_mine_cells",
        "test_row_tooltip",
        "test_test_mode",
        "test_compat",
        "test_text_parse",
        "test_constants",
        "test_class_data",
        "test_evaluate",
        "test_scoring",
        "test_quality_gate",
        "test_situations",
        "test_trade_rules",
        "test_messaging",
        "test_restrictions",
        "test_roster",
        "test_item_facts",
        "test_item_read",
        "test_gear",
        "test_loot_parser",
        "test_inspect",
        "test_feed",
        "test_feed_counts",
        "test_group_roster",
        "test_group_place",
        "test_char_filter",
        "test_trade_timer",
        "test_trade_helper",
        "test_asks",
        "test_transmog",
        "test_history",
        "test_history_retention",
        "test_toast",
        "test_auto_ask",
        "test_sim_core",
        "test_sim_pool",
        "test_sim_events",
        "test_sim_scenario",
        "test_sim_e2e",
        "test_sim_report",
        "test_sim_panel",
        "test_disabled",
        "test_diagnostics",
        "test_vendor_sync",
        { name = "test_eol",                  dir = "tests/_kit/" },   -- line-endings-§7
        { name = "test_prose",                dir = "tests/_kit/" },   -- localization-§5
        { name = "test_layout_cap",           dir = "tests/_kit/" },   -- layout-§1
        { name = "test_diagnostics_contract", dir = "tests/_kit/" },   -- debug-logging-§14
        { name = "test_lizard_sighted",       dir = "tests/_kit/" },   -- automated-tests-§3
    },
}
