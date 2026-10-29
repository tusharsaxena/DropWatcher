-- tests/test_surface_parity.lua — every degradation stub carries the live surface (testing-§8).
--
-- Each case loads the addon with the whole LibKa0s payload ABSENT (the loader skips its files) and
-- compares the stub against the live surface: by major name where the stub mirrors something
-- tests/run.lua registered as the live half, key for key (two tables) where it mirrors an instance
-- or a set of NS members. A member the live module has and the stub lacks is a crash moved to the
-- one install the stub exists for. Where a member is live-only on purpose, the ignore set names it
-- with the grep that proves this addon has no call site for it.

local T = _G.DW_TEST
local test, assertTrue = T.test, T.assertTrue

local NO_LIBKA0S = T.loadAddon.libFiles

local live = T.newAddon()
local degraded = T.newAddon{ skip = NO_LIBKA0S }

test("parity: the degraded load really is library-absent, and the live one is not", function()
    -- red under: a loader that ignores `skip` (both arms would be live and every case below vacuous)
    assertTrue(degraded.DebugLog.Debug ~= nil and live.DebugLog ~= degraded.DebugLog)
    assertTrue(T.LibStub("LibKa0s-Core-1.0", true) ~= nil, "the live arm has the library")
    local _, m = T.newAddon{ skip = NO_LIBKA0S }
    assertTrue(m.LibStub("LibKa0s-Core-1.0", true) == nil, "the degraded arm has none")
end)

test("parity: the Core seam's namespace surface survives the library's absence", function()
    T.assertSurfaceParity(live, degraded, "the addon namespace (Core seam)")
    T.assertSurfaceParity(live.Util, degraded.Util, "NS.Util (Core printer seam)")
end)

test("parity: the DebugLog stub carries the whole live surface", function()
    T.assertSurfaceParity(degraded.DebugLog, "LibKa0s-DebugLog-1.0", {
        -- The two line formatters are the console's own rendering; the stub has no window to render
        -- into and copies no formatter (debug-logging-§1). `grep -rn "FormatPlain\|FormatColored"
        -- core modules settings` finds no call site.
        "FormatPlain", "FormatColored",
    })
end)

test("parity: the Slash stub carries the whole live surface", function()
    T.assertSurfaceParity(degraded.SlashCommands, "LibKa0s-Slash-1.0")
end)

test("parity: the Slash stub's one library string is the library's, byte for byte", function()
    -- red under: change one byte of DISABLED_LINE_FORMAT in settings/Slash.lua's stub
    T.assertLibraryConstant(degraded.SlashCommands.__disabledLineFormat, "LibKa0s-Slash-1.0",
        "DISABLED_LINE_FORMAT", "settings/Slash.lua stub")
end)

test("parity: the Options helpers stub carries the whole live surface", function()
    T.assertSurfaceParity(degraded.addon.Settings.Helpers, "LibKa0s-Options-1.0", {
        -- Layout constants and the resolved AceGUI: the stub draws nothing, and options-ui-§1
        -- forbids a host copy of a LAYOUT constant.
        "PADDING_X", "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL",
        "CHROME_GAP", "TAB_H", "BANNER_H", "AceGUI",
        -- Reached only from a page body, which the stub never builds (CreateOptionsPanel says the
        -- panel is unavailable instead).
        "BuildLandingPage", "RestoreDefaults",
        -- The composers' value tables and labels, read only inside the live composers.
        "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_VALUES", "VISIBILITY_SORT",
        "MASTER_GROUP", "CLASS_COLOR_NOTE",
    })
end)

test("parity: the Schema host stub's instance carries the whole live instance surface", function()
    T.assertSurfaceParity(live.SchemaRuntime, degraded.SchemaRuntime, "schema instance vs host stub")
end)

test("parity: the Schema host stub carries the library's own members", function()
    T.assertSurfaceParity(degraded.addon.Settings.SchemaLib, "LibKa0s-Schema-1.0", {
        -- The library's default refusal words; the stub refuses in this addon's own words.
        "STRINGS",
    })
end)

test("parity: the Launcher stub carries the whole live surface", function()
    T.assertSurfaceParity(degraded.Launcher, "LibKa0s-Launcher-1.0")
end)

test("parity: the Lifecycle stand-in carries every member of the live latch", function()
    T.assertSurfaceParity(live.Lifecycle, degraded.Lifecycle, "Lifecycle latch vs host stand-in")
end)

test("parity: the Sim stub carries the whole live instance surface", function()
    -- The live half is tests/run.lua's registered instance (no manifest lists instance members:
    -- Sim:New builds them per host); the stub is LibKa0s tests/test_sim_stub.lua's reference copy.
    T.assertSurfaceParity(degraded.Sim, "LibKa0s-Sim-1.0")
    T.assertSurfaceParity(live.Sim, degraded.Sim, "Sim instance vs host stub")
end)

test("parity: the Sim seam stub carries the live seam surface", function()
    T.assertSurfaceParity(live.SimSeam, degraded.SimSeam, "NS.SimSeam vs host stub")
end)

test("parity: the Bus stand-in carries every member of the live bus", function()
    T.assertSurfaceParity(live.Bus, degraded.Bus, "Bus instance vs host stand-in")
end)

test("parity: the Pool stub carries the LibKa0s-Pool-1.0 surface this addon calls", function()
    T.assertSurfaceParity(degraded.Pool, "LibKa0s-Pool-1.0", {
        -- The keyed family, live-only on purpose: `grep -rnE "Keyed\(" core modules settings`
        -- returns nothing; every pool here is a plain New/Acquire/ReleaseAll pool.
        "NewKeyed", "AcquireKeyed", "ReleaseAllKeyed", "CountsKeyed",
    })
end)

test("parity: the Item stub carries the LibKa0s-Item-1.0 surface this addon calls", function()
    T.assertSurfaceParity(degraded.Item, "LibKa0s-Item-1.0", {
        -- Item minor 3's bonus-id walk, live-only on purpose: this addon keeps its own modifier
        -- walk and does not adopt it (OWNER_SCOPE A.#51 names BankLedger and LootHistory only).
        -- `grep -rn "BonusIDsFromLink" core modules settings` finds no call site.
        "BonusIDsFromLink",
    })
end)

test("parity: the Glow stub carries the whole LibKa0s-Glow-1.0 surface", function()
    -- red under: drop `Stop` from core/GlowSetup.lua's stub
    T.assertSurfaceParity(degraded.GlowLib, "LibKa0s-Glow-1.0")
end)

test("parity: the Toast stub carries the whole LibKa0s-Toast-1.0 instance surface", function()
    -- red under: drop `Hold` from core/ToastSetup.lua's stub
    T.assertSurfaceParity(live.NewToast({ build = function() end }), degraded.ToastStub, "Toast instance vs stub")
    T.assertTrue(degraded.NewToast({ build = function() end }) == degraded.ToastStub, "absent: the stub answers")
end)

-- The Perf members the addon can reach: the gate fields, the bracket sinks, the hold pair and the
-- slash entry point. The live instance publishes far more (the panel, the record, the run state),
-- which the stub is not obliged to carry.
local PERF_MEMBERS = { "on", "suspended", "BUCKET_ORDER", "Note", "Open", "Close", "Suspend",
    "Resume", "OnCommand" }

test("parity: the Perf stub carries every Perf member the addon reaches", function()
    local l, d = {}, {}
    for _, k in ipairs(PERF_MEMBERS) do l[k], d[k] = live.Perf[k], degraded.Perf[k] end
    T.assertSurfaceParity(l, d, "Perf reached members")
    -- And the list is honest: every member the addon's own source names on Perf is in it.
    -- red under: add a `Perf.Reset()` call to modules/Window.lua without adding it above
    local listed = {}
    for _, k in ipairs(PERF_MEMBERS) do listed[k] = true end
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
        local src = fh:read("*a"); fh:close()
        for member in src:gmatch("[^%w_]Perf[.:]([%a_][%w_]*)") do
            assertTrue(listed[member], rel .. " reaches Perf." .. member .. ", missing from PERF_MEMBERS")
        end
    end
end)

-- The NS members a seam file publishes, found the way the grep in each case's comment finds them.
-- Env and Media publish onto NS itself, like Core, so the member list is derived, never re-typed.
local function seamMembers(path)
    local fh = assert(io.open(T.root .. "/" .. path, "rb"))
    local src = fh:read("*a"); fh:close()
    local found = {}
    for line in src:gmatch("[^\r\n]+") do
        local key = line:match("^%s*function NS%.([A-Za-z_][A-Za-z0-9_]*)")
            or line:match("^%s*NS%.([A-Za-z_][A-Za-z0-9_]*)%s*=")
        if key then found[key] = true end
    end
    return found
end

local function assertSeamParity(path, known, label)
    local found = seamMembers(path)
    assertTrue(found[known], "the derivation found no NS." .. known .. " in " .. path)
    local l, d = {}, {}
    for key in pairs(found) do l[key], d[key] = live[key], degraded[key] end
    T.assertSurfaceParity(l, d, label)
end

test("parity: the Env seam publishes the same NS members on both paths", function()
    -- Members from: grep -nE '^\s*function NS\.[A-Za-z_]+|^\s*NS\.[A-Za-z_]+\s*=' core/EnvSetup.lua
    assertSeamParity("core/EnvSetup.lua", "Version", "Env seam (NS members)")
end)

test("parity: the Media seam publishes the same NS members on both paths", function()
    -- Members from: grep -nE '^\s*function NS\.[A-Za-z_]+|^\s*NS\.[A-Za-z_]+\s*=' core/MediaSetup.lua
    assertSeamParity("core/MediaSetup.lua", "MediaFont", "Media seam (NS members)")
end)

-- The six spell and spec readers of LibKa0s-Compat-1.0 that core/Compat.lua does not publish as
-- members: nothing here reads a spell, and the two spec readers are called on the library inside
-- Compat.PlayerSpecID only (`grep -rnE "Compat\.(GetSpell|GetSpecialization)" core modules settings`
-- finds no call site).
local COMPAT_READERS_UNWIRED = { "GetSpellInfo", "GetSpellName", "GetSpellTexture", "GetSpellCooldown",
    "GetSpecialization", "GetSpecializationInfo" }

test("parity: the Compat seam carries every library member it wires", function()
    T.assertSurfaceParity(degraded.Compat, "LibKa0s-Compat-1.0", COMPAT_READERS_UNWIRED)
end)

test("parity: the Compat seam publishes the same members on both load paths", function()
    T.assertSurfaceParity(live.Compat, degraded.Compat, "NS.Compat")
end)

-- ── Skin (the owner's facade, and its host copy of the library's tokens) ─────────────────────

test("parity: the degraded Skin facade answers every name the live facade carries", function()
    -- core/SkinSetup.lua: live, NS.Skin is LibKa0s-Skin-1.0's `Skin:For("DropWatcher")`; without the
    -- library it is the host's table, whose painting names are no-ops (Shell routes to NS.ApplySkin)
    -- and whose Token / Color answer the host copy NS.SKIN_FALLBACK and the owner tokens' defaults.
    -- A facade is per owner and built by `For`, not a major's lib-level surface, so this is the
    -- two-table form, key for key, with nothing ignored: a vocabulary name the library adds fails
    -- here until the stub answers it.
    T.assertSurfaceParity(live.Skin, degraded.Skin, "Skin facade vs host stub")
end)

test("parity: each host-copy skin token is the live library's Ka0s Default value", function()
    -- A copy is the thing that drifts, so every NS.SKIN_FALLBACK entry is held to
    -- LibKa0s-Skin-1.0's resolved Ka0s Default here.
    -- red under: a token added to the copy with a value of its own, or the library moving a value.
    local want = T.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("ka0s")
    local n = 0
    for name, c in pairs(degraded.SKIN_FALLBACK) do
        n = n + 1
        local w = want[name]
        assertTrue(type(w) == "table", name .. " is not a Ka0s Default color token in the library")
        for i = 1, 4 do
            local a, b = c[i] or 1, w[i] or 1
            assertTrue(math.abs(a - b) < 1e-6, ("%s[%d]: host copy %s, library %s"):format(name, i, a, b))
        end
    end
    assertTrue(n > 0, "the host copy is empty, so this case asserts nothing")
end)
