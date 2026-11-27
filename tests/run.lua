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

-- ... plus OnInitialize (ADDON_LOADED): the db exists, migrations have run. Then the one login
-- event the client delivers before OnEnable, to the one frame that hears it on its own: since
-- LibKa0s v1.78.0 the first RegisterOwner (core/SkinSetup.lua) makes LibKa0s-Skin-1.0's EllesmereUI
-- retry frame, registered for ADDON_LOADED and PLAYER_LOGIN, and at PLAYER_LOGIN it unregisters
-- both. The headless run fires no client event, so without this the frame would stand in every
-- registration survey as two game events that are the library's, not this addon's (LootHistory's
-- tests/test_disabled.lua settles it the same way).
local function bootAddon(opts)
    local NS, env, m = newAddon(opts)
    NS.addon:OnInitialize()
    local skin = m.LibStub("LibKa0s-Skin-1.0", true)
    local retry = skin and skin.__euiEventFrame
    if retry then retry:__fire("OnEvent", "PLAYER_LOGIN") end
    return NS, env, m
end

-- ... plus OnEnable (PLAYER_LOGIN): events registered, settings category and launcher registered,
-- and the latch taken from the stored `enabled` path. The first-run skin picker's login fuse is put
-- out unless `opts.pickerFuse`: since R6-PV the picker shown with the window hidden turns test mode
-- on (spec.preview), so a case that advances the clock past two seconds would find placeholder
-- drops it never asked for. test_skin_picker's fuse cases light it.
local function enableAddon(opts)
    local NS, env, m = bootAddon(opts)
    NS.addon:OnEnable()
    if not (opts and opts.pickerFuse) and NS.ArmSkinPicker then NS.ArmSkinPicker(false) end
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
    ["LibKa0s-Sim-1.0"]       = surfaceNS.Sim,
    ["LibKa0s-Glow-1.0"]      = surfaceMock.LibStub("LibKa0s-Glow-1.0", true),
    ["LibKa0s-ForeverDB-1.0"] = surfaceMock.LibStub("LibKa0s-ForeverDB-1.0", true),
}

-- A bare simulation session on LibKa0s-Sim-1.0: the scenario `test`, with no timeline and no
-- world, so a case drives the session's own members (the seam, Fire, After, the stop) alone. Its
-- prepare readies at once (after NS.SimHost.Begin, which every start runs); every other scenario
-- still builds its world. Answers NS.Sim.
local function simBare(NS)
    local defs = NS.SimScenarioDefs
    if not defs.defs.test then
        defs.names[#defs.names + 1] = "test"
        defs.defs.test = { timeline = function() return {} end }
        local prepare = NS.SimScenario.Prepare
        NS.SimScenario.Prepare = function(s, def, opts, ready)
            if s.scenario == "test" then return ready() end
            return prepare(s, def, opts, ready)
        end
    end
    return NS.Sim
end

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

-- A tooltip line as the player reads it (feedback-21): tipText with its color codes taken out, so a
-- row (NS.TipMarks.Row) reads `• Rule: personal loot`.
local function tipPlain(line)
    return (tipText(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- A tooltip's lines joined by `sep` (" | " when nil), each read by tipPlain.
local function tipPlainJoined(tip, sep)
    local out = {}
    for i, l in ipairs(tip or {}) do out[i] = tipPlain(l) end
    return table.concat(out, sep or " | ")
end

-- A detail card chip or line (modules/DetailCells.lua's shapes) as the player reads it (feedback-21
-- H5): a chip's `glyph` before its words, a line's `lead` before its text and its `arrow` (glyph and
-- number) after it, the marks as `[icon]` and the color codes out: `292 [arrow-right] 311 ▲ 19`.
local function cardText(m)
    local s = marks(m.text)
    if m.glyph then s = m.glyph .. " " .. s end
    if m.lead then s = m.lead .. " " .. s end
    local a = m.arrow
    if type(a) == "table" then s = s .. " " .. a.glyph .. ((a.text or "") ~= "" and " " .. a.text or "") end
    return tipPlain(s)
end

-- Another player in the mock's group (DW-07: your own drop is offered only while one is): you and
-- Seta, a same-realm priest, in a party, the roster re-read. Answers `m`.
local function withPlayer(m)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Seta", class = "PRIEST", classFile = "PRIEST" } })
    m.__fire("GROUP_ROSTER_UPDATE")
    return m
end

-- The kit profile in use (clients-§6), and the name the roster gives a mock unit row on it
-- (forever-quirks-§4): on Forever (regional names) a row's `realm` stands for UnitName's second
-- value, the surname, so the member is "First Surname" with no realm; on Retail it is `Name-Realm`,
-- the realm normalized, and the player's own (the mock's Testrealm) when the row names none.
local FOREVER = (os.getenv("KA0S_KIT_CLIENT") or "retail") == "forever"

-- Pins Retail's class list (core/ClassData.lua's CD.LISTS.retail) as NS.ClassData's active one on
-- `NS`, on either kit profile: a case written against Retail's spec model (its specIDs, off-specs,
-- Titan's Grip, Pawn's spec index) drives the same pure code under the forever profile, where the
-- client installed Forever's list. The Forever list's own cases stand beside them (clients-§6).
-- Answers NS.
local function retailList(NS)
    NS.ClassData.Install(NS.ClassData.LISTS.retail)
    return NS
end
-- The declared-skip reason (the kit's `test(name, fn, reason)`) for a case of a Retail-only feature
-- (Mythic+, Raid Finder, delves, follower dungeons, scenarios: Forever port design §4.4) on the
-- forever profile, where the feature is absent and its own per-client case asserts the absence
-- (clients-§6); nil on Retail, which runs it.
local RETAIL_ONLY = FOREVER and "Retail-only feature (Forever port design §4.4): absent on Forever, "
    .. "which its per-client case asserts" or nil
local function rosterName(name, realm)
    if FOREVER then return realm and (name .. " " .. realm) or name end
    return name .. "-" .. (realm and (realm:gsub("[%s%-]", "")) or "Testrealm")
end

-- WHERE A TOOLTIP OPENS (AD-92-DW, LibKa0s#92; standalone-windows, *Tooltip placement*). The kit's
-- fake screen (tests/_kit/mock_screen.lua, kit revision 57) on `m`'s UIParent, `opts` its width,
-- height and scale (1920 x 1080 at 1 by default), with the game tooltip `opts.tipW` x `opts.tipH`
-- (320 x 100) at `opts.tipScale` (1): LibKa0s-Tooltip-1.0's placers read a plain number from each,
-- where the base mock answers a table and nothing is placed. Answers the screen.
local function tipScreen(m, opts)
    opts = opts or {}
    local scr = dofile("tests/_kit/mock_screen.lua")(m, opts)
    local tip = m.GameTooltip
    tip.GetWidth = function() return opts.tipW or 320 end
    tip.GetHeight = function() return opts.tipH or 100 end
    tip.GetEffectiveScale = function() return opts.tipScale or 1 end
    return scr
end

-- Give a built frame a rect in its own units: `left`, `bottom`, `right`, `top`, at `scale` (1).
local function tipRect(f, left, bottom, right, top, scale)
    f.GetLeft = function() return left end
    f.GetBottom = function() return bottom end
    f.GetRight = function() return right end
    f.GetTop = function() return top end
    f.GetEffectiveScale = function() return scale or 1 end
    return f
end

-- Every call the addon makes to LibKa0s-Tooltip-1.0's two placers on `m`'s copy, the real placer
-- still running: `spy.calls[i]` is `{ fn = "PlaceBeside" | "PlaceAttached", el, group }`, and
-- `spy.first()` the first since the last `spy.reset()` (PlaceBeside's own fallback calls
-- PlaceAttached after it, so the first call is the one the addon chose).
local function tipSpy(m)
    local spy = { calls = {} }
    local Tip = m.LibStub("LibKa0s-Tooltip-1.0")
    for _, fn in ipairs({ "PlaceBeside", "PlaceAttached" }) do
        local real = Tip[fn]
        Tip[fn] = function(tip, el, a, b)
            spy.calls[#spy.calls + 1] = { fn = fn, el = el, group = fn == "PlaceBeside" and a or nil }
            return real(tip, el, a, b)
        end
    end
    function spy.reset() spy.calls = {} end
    function spy.first() return spy.calls[1] end
    return spy
end

-- The game tooltip's first point as `point>relPoint`, then the frame, x and y.
local function tipPoint(m)
    local point, rel, relPoint, x, y = m.GameTooltip:GetPoint(1)
    return tostring(point) .. ">" .. tostring(relPoint), rel, x, y
end

-- The table every suite reaches as `local T = _G.DW_TEST`. Kit.expose merges `test` and the kit
-- assertions in beside these keys.
_G.DW_TEST = Kit.expose{
    newAddon    = newAddon,
    bootAddon   = bootAddon,
    enableAddon = enableAddon,
    loadAddon   = loadAddon,
    simBare     = simBare,
    withPlayer  = withPlayer,
    marks       = marks,
    tipText     = tipText,
    tipJoined   = tipJoined,
    tipPlain    = tipPlain,
    tipPlainJoined = tipPlainJoined,
    cardText    = cardText,
    tipScreen   = tipScreen,
    tipRect     = tipRect,
    tipSpy      = tipSpy,
    tipPoint    = tipPoint,
    forever     = FOREVER,
    retailList  = retailList,
    RETAIL_ONLY = RETAIL_ONLY,
    rosterName  = rosterName,
    ME          = rosterName("Testchar"),
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

-- The typed-value gate (skinning-§1, kit revision 50).
Kit.skinValues = {
    calls = { Colored = { 2, 3, 4 }, Escape = { 2, 3, 4 }, tone = { 2, 3, 4 } },
    rows  = {   -- DW-FP15's roll glyphs: the game's own group-loot roll-button art, as DPS Race's countdown digits are
        { file = "modules/RollCells.lua", substring = "local DICE =",
          why = "the Need roll button's dice, the game's group-loot art players know, the same under every skin", cause = "A6" },
        { file = "modules/RollCells.lua", substring = "local COIN =",
          why = "the Greed roll button's coin, the game's group-loot art players know, the same under every skin", cause = "A6" },
        { file = "modules/RollCells.lua", substring = "local DE =",
          why = "the Disenchant roll button's art (Retail only), the game's group-loot art players know, the same under every skin", cause = "A6" },
        { file = "modules/RollCells.lua", substring = "local CROSS =",
          why = "the Pass roll button's cross, the game's group-loot art players know, the same under every skin", cause = "A6" },
        -- Kit revision 58 reads keyed { r, g, b } tables, a fallback table and return triples
        -- (LibKa0s v1.108.0). The four secondary stats' hues are a named meaning table (skinning-§9
        -- Meaning colors: "the stat ... hues where the color is the information"; the full-skinning
        -- run's MC, owner ruling of 2026-11-01); the audit's DropWatcher table marks them OVERRIDE.
        { file = "core/Constants.lua", substring = "statCrit    = {",
          why = "the Critical Strike name's hue on the detail card's Stats row, one stat told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "statHaste   = {",
          why = "the Haste name's hue on the detail card's Stats row, one stat told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "statMastery = {",
          why = "the Mastery name's hue on the detail card's Stats row, one stat told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "statVers    = {",
          why = "the Versatility name's hue on the detail card's Stats row, one stat told from another by color", cause = "MC" },
        -- Item Search's skill-up hues (Item Search spec §4.2): the client's trade-skill difficulty colors,
        -- a meaning table like the stats' (skinning-§9 Meaning colors).
        { file = "core/Constants.lua", substring = "skillOrange = {",
          why = "a recipe's orange (optimal) skill-up mark on Item Search's Crafting rows, the client's own hue", cause = "MC" },
        { file = "core/Constants.lua", substring = "skillYellow = {",
          why = "a recipe's yellow (medium) skill-up mark on Item Search's Crafting rows, the client's own hue", cause = "MC" },
        { file = "core/Constants.lua", substring = "skillGreen  = {",
          why = "a recipe's green (easy) skill-up mark on Item Search's Crafting rows, the client's own hue", cause = "MC" },
        { file = "core/Constants.lua", substring = "skillGray   = {",
          why = "a recipe's gray (trivial) skill-up mark on Item Search's Crafting rows, the client's own hue", cause = "MC" },
        -- Item Search round 4 (R4-DW-05): the same hues dimmed, the breakpoints outside your band.
        { file = "core/Constants.lua", substring = "skillOrangeDim = {",
          why = "a recipe's orange start dimmed while your rank is in another band, the client's hue", cause = "MC" },
        { file = "core/Constants.lua", substring = "skillYellowDim = {",
          why = "a recipe's yellow start dimmed while your rank is in another band, the client's hue", cause = "MC" },
        { file = "core/Constants.lua", substring = "skillGreenDim  = {",
          why = "a recipe's green start dimmed while your rank is in another band, the client's hue", cause = "MC" },
        { file = "core/Constants.lua", substring = "skillGrayDim   = {",
          why = "a recipe's gray start dimmed while your rank is in another band, the client's hue", cause = "MC" },
        -- Item Search round 4 (R4-DW-01): each drop source Type's hue, a meaning table like the
        -- skill-up hues' (skinning-§9 Meaning colors).
        { file = "core/Constants.lua", substring = "typeCreature  = {",
          why = "the Creature Type on Item Search's Drops from tab, white by the owner's rule", cause = "MC" },
        { file = "core/Constants.lua", substring = "typeElite     = {",
          why = "the Elite Type on Item Search's Drops from tab, the game's elite gold", cause = "MC" },
        { file = "core/Constants.lua", substring = "typeRare      = {",
          why = "the Rare Type on Item Search's Drops from tab, a teal apart from white", cause = "MC" },
        { file = "core/Constants.lua", substring = "typeRareElite = {",
          why = "the Rare Elite Type on Item Search's Drops from tab, apart from rare and elite", cause = "MC" },
        { file = "core/Constants.lua", substring = "typeBoss      = {",
          why = "the Boss Type on Item Search's Drops from tab, apart from epic purple and the skill-up orange", cause = "MC" },
        { file = "core/Constants.lua", substring = "typeObject    = {",
          why = "the Object Type on Item Search's Drops from tab", cause = "MC" },
        { file = "core/Constants.lua", substring = "typeContainer = {",
          why = "the Container Type on Item Search's Drops from tab", cause = "MC" },
        -- Item Search round 4 (R4-DW-04): each profession's hue, a meaning table like the Types'.
        { file = "core/Constants.lua", substring = "profAlchemy        = {",
          why = "Alchemy's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profBlacksmithing  = {",
          why = "Blacksmithing's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profEngineering    = {",
          why = "Engineering's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profEnchanting     = {",
          why = "Enchanting's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profJewelcrafting  = {",
          why = "Jewelcrafting's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profTailoring      = {",
          why = "Tailoring's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profCooking        = {",
          why = "Cooking's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profFirstAid       = {",
          why = "First Aid's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profLeatherworking = {",
          why = "Leatherworking's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profSkinning       = {",
          why = "Skinning's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profHerbalism      = {",
          why = "Herbalism's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profMining         = {",
          why = "Mining's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        { file = "core/Constants.lua", substring = "profFishing        = {",
          why = "Fishing's name on Item Search's rows, one profession told from another by color", cause = "MC" },
        -- Item Search round 3 (spec §4.2, item 13): the quest marks are the game's own gossip icons.
        { file = "modules/ItemSearchTip.lua", substring = "local QUEST_ICON =",
          why = "Item Search's quest marks, the game's own gossip ! and ? players know, the same under every skin", cause = "A6" },
        -- RC.Grid's answer for no rows: one column, no lines, none shown. Counts, not a color.
        { file = "modules/RollCells.lua", substring = "if n == 0 then return 1, 0, 0 end",
          why = "the roster box's columns, lines and shown count for no rows", category = "not a color" },
    },
}

-- The skin-switch test (skinning-§1, kit revision 50): the painted surfaces are declared there.
Kit.skinSwitch = dofile("tests/skin_switch_facts.lua")(enableAddon, withPlayer)

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
        "test_item_lists_panel",
        "test_skin_setup",
        "test_launcher_skin_entry",
        "test_skin_outline",
        "test_skin_chrome",
        "test_skin_hud",
        "test_skin_flip",
        "test_skin_host",
        "test_header_band",
        "test_title_bar_controls",
        "test_header_marks",
        "test_section_header_bands",
        "test_skin_picker",
        "test_skin_verb",
        "test_skin_settings",
        "test_slash",
        "test_slash_report",
        "test_window",
        "test_window_shell",
        "test_window_compact",
        "test_window_autoclose",
        "test_compact_cards",
        "test_compact_group",
        "test_compact_history",
        "test_history_card",
        "test_compact_chrome",
        "test_compact_modes",
        "test_window_group",
        "test_table_font",
        "test_drops_layout",
        "test_side_cells",
        "test_collect_cells",
        "test_collect_surfaces",
        "test_detail_card",
        "test_recipe_reagents",
        "test_item_search",
        "test_item_search_tip",
        "test_item_search_window",
        "test_item_search_tabs",
        "test_item_search_key",
        "test_item_search_settings",
        "test_item_search_rank",
        "test_item_search_sources",
        "test_item_search_prices",
        "test_item_search_verdict",
        "test_item_search_auction",
        "test_item_search_panel",
        "test_item_search_round7",
        "test_own_drops",
        "test_tip_marks",
        "test_drops_strip",
        "test_footer_row",
        "test_offer_panel",
        "test_offer_alone",
        "test_mine_cells",
        "test_row_tooltip",
        "test_tooltip_placement",
        "test_test_mode",
        "test_sample_names",
        "test_compat",
        "test_compat_client",
        "test_role_override",
        "test_compat_collect",
        "test_compat_loot",
        "test_text_parse",
        "test_constants",
        "test_offspec",
        "test_tier_token",
        "test_offspec_cells",
        "test_offspec_ask",
        "test_offspec_offer",
        "test_scoring",
        "test_quality_gate",
        "test_situations",
        "test_trade_rules",
        "test_messaging",
        "test_restrictions",
        "test_roster",
        "test_item_facts",
        "test_collectibles",
        "test_item_read",
        "test_gear",
        "test_verdict_golden",
        "test_loot_parser",
        "test_inspect",
        "test_feed",
        "test_pending",
        "test_pending_ml",
        "test_ask_ml",
        "test_roll_cells",
        "test_window_pending",
        "test_roll_popup",
        "test_rolls_panel",
        "test_feed_counts",
        "test_collect_feed",
        "test_item_lists",
        "test_group_roster",
        "test_group_place",
        "test_char_filter",
        "test_trade_timer",
        "test_trade_helper",
        "test_asks",
        "test_transmog",
        "test_history",
        "test_history_retention",
        "test_insights_filters",
        "test_insights_stats",
        "test_feed_restore",
        "test_content_tabs",
        "test_insights_rows",
        "test_window_insights",
        "test_insights_sections",
        "test_toast",
        "test_toast_stack",
        "test_glow",
        "test_icon_style",
        "test_layers",
        "test_auto_ask",
        "test_sim_core",
        "test_sim_pool",
        "test_sim_events",
        "test_sim_scenario",
        "test_sim_e2e",
        "test_sim_report",
        "test_sim_panel",
        "test_sim_checkbox",
        "test_bindings",
        "test_disabled",
        "test_diagnostics",
        "test_debug_coverage",
        "test_vendor_sync",
        "test_locale",
        { name = "test_eol",                  dir = "tests/_kit/" },   -- line-endings-§7
        { name = "test_prose",                dir = "tests/_kit/" },   -- localization-§5
        { name = "test_layout_cap",           dir = "tests/_kit/" },   -- layout-§1
        { name = "test_diagnostics_contract", dir = "tests/_kit/" },   -- debug-logging-§14
        { name = "test_lizard_sighted",       dir = "tests/_kit/" },   -- automated-tests-§3
        { name = "test_skin_values",          dir = "tests/_kit/" },   -- skinning-§1
        { name = "test_skin_switch",          dir = "tests/_kit/" },   -- skinning-§1
        { name = "test_client_globals", dir = "tests/_kit/" },   -- clients-§6
    },
}
