-- tests/test_harness.lua — the harness loads what the client loads, and the repo has the shape the
-- standard fixes (testing-§9, toc-file, documentation-§7, architecture-§1, documentation-§9).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function read(rel)
    local fh = io.open(T.root .. "/" .. rel, "rb")
    if not fh then return nil end
    local s = fh:read("*a"); fh:close()
    return s
end

local function tocFields()
    local fields, lines = {}, {}
    for line in read("DropWatcher.toc"):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
        local k, v = line:match("^## ([%w%-]+):%s*(.-)%s*$")
        if k then fields[#fields + 1] = { k, v } end
    end
    return fields, lines
end

local function field(fields, key)
    for _, kv in ipairs(fields) do if kv[1] == key then return kv[2] end end
end

-- ── the load ────────────────────────────────────────────────────────────────────────────────

test("harness: the addon's file list is the TOC's, Namespace first and Profiles last", function()
    local files = T.loadAddon.tocFiles
    assertTrue(#files >= 20, "the TOC lists the addon's files")
    assertEqual(files[1], "locales/enUS.lua")
    assertEqual(files[2], "core/Namespace.lua")
    assertEqual(files[#files], "settings/Profiles.lua")
end)

test("harness: every LibKa0s file comes from LibKa0s.xml, in its order", function()
    local libs = T.loadAddon.libFiles
    assertEqual(libs[1], "libs/LibKa0s/Core.lua")
    assertTrue(#libs >= 30, "the whole payload is loaded, not a hand-picked part")
end)

test("harness: every adopted LibKa0s module is the live library, not its stub", function()
    local NS, _, m = T.newAddon()
    local ls = m.LibStub
    -- red under: drop libs/LibKa0s/Pool.lua from the load (the stand-in would answer instead)
    assertTrue(NS.Pool == ls("LibKa0s-Pool-1.0", true), "Pool")
    assertTrue(NS.Item == ls("LibKa0s-Item-1.0", true), "Item")
    assertTrue(NS.addon.Settings.SchemaLib == ls("LibKa0s-Schema-1.0", true), "Schema")
    assertTrue(NS.SafeToString == ls("LibKa0s-Core-1.0", true).SafeToString, "Core")
    assertTrue(type(NS.Perf.Note) == "function" and NS.Perf.OnCommand ~= nil and NS.Perf.BuildRecord ~= nil,
        "Perf is the live instance")
    assertTrue(NS.DebugLog.FormatPlain ~= nil, "DebugLog is the live instance")
    assertTrue(NS.Bus.name == "DropWatcher" and getmetatable(NS.MSG) ~= nil, "Bus catalog is strict")
end)

-- ── the TOC ─────────────────────────────────────────────────────────────────────────────────

test("toc: the fixed field order, a single Retail Interface line and the X-Standard field", function()
    local fields, lines = tocFields()
    local order = {}
    for i, kv in ipairs(fields) do order[i] = kv[1] end
    assertEqual(table.concat(order, ","), "Interface,Title,Notes,Author,Version,IconTexture,"
        .. "SavedVariables,OptionalDeps,DefaultState,Category-enUS,X-License,X-Standard")
    assertEqual(field(fields, "Interface"), "120100")
    assertEqual(field(fields, "Title"), "Ka0s Drop Watcher")
    assertEqual(field(fields, "X-Standard"), "https://github.com/tusharsaxena/WowAddonStandards")
    assertEqual(field(fields, "SavedVariables"), "DropWatcherDB, DropWatcherPerfDB")
    assertEqual(field(fields, "X-License"), "MIT")
    -- Unpublished: the project id is a comment, never a placeholder (toc-file-§1).
    local commented = false
    for _, line in ipairs(lines) do
        if line:find("^# X%-Curse%-Project%-ID:") then commented = true end
    end
    assertTrue(commented and field(fields, "X-Curse-Project-ID") == nil)
end)

test("toc: the icon is the 128x128 logo, and the file exists", function()
    local fields = tocFields()
    assertEqual(field(fields, "IconTexture"),
        "Interface\\AddOns\\DropWatcher\\media\\logos\\dropwatcher.logo.128.tga")
    local tga = read("media/logos/dropwatcher.logo.128.tga")
    assertTrue(tga ~= nil, "the logo file is committed")
    -- TGA header: type 2 (uncompressed true color), 128x128, 32 bpp (layout-§4).
    assertEqual(tga:byte(3), 2, "uncompressed")
    assertEqual(tga:byte(13) + tga:byte(14) * 256, 128, "width")
    assertEqual(tga:byte(15) + tga:byte(16) * 256, 128, "height")
    assertEqual(tga:byte(17), 32, "32-bit")
end)

test("toc: OptionalDeps names Pawn and CanIMogIt, and no hard Dependencies", function()
    local fields = tocFields()
    local deps = field(fields, "OptionalDeps")
    assertTrue(deps:find("Pawn", 1, true) ~= nil and deps:find("CanIMogIt", 1, true) ~= nil)
    assertTrue(field(fields, "Dependencies") == nil, "no hard dependency (library-stack-§6)")
end)

-- ── the repository's shape ──────────────────────────────────────────────────────────────────

test("repo: no stored copy of the context pack (documentation-§3, anti-pattern #49)", function()
    assertTrue(read("docs/agent-context.md") == nil)
    assertTrue(read("docs/complexity.md") == nil, "retired v2.19.0")
    assertTrue(read("docs/file-index.md") == nil and read("docs/conventions.md") == nil, "retired v2.23.0")
    assertTrue(read("CHANGELOG.md") == nil, "no changelog at an addon root")
end)

test("repo: the root doc set is README, the CLAUDE stub, DEPENDENCIES and LICENSE", function()
    for _, rel in ipairs({ "README.md", "CLAUDE.md", "DEPENDENCIES.md", "LICENSE" }) do
        assertTrue(read(rel) ~= nil, rel)
    end
    assertTrue(read("CLAUDE.md"):find("## Standards compliance (read first)", 1, true) ~= nil)
end)

test("repo: every authored file opens with the bootstrap and a comment naming its path", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        local src = read(rel)
        local first, second = src:match("^([^\r\n]*)\r?\n([^\r\n]*)")
        -- red under: swap line 1 and line 2 of any authored file
        assertTrue(first == "local addonName, NS = ..." or first == "local _, NS = ...",
            rel .. " line 1: " .. tostring(first))
        assertTrue(second:find("^%-%- " .. rel:gsub("%p", "%%%0")) ~= nil,
            rel .. " line 2 names its own path: " .. tostring(second))
    end
end)

test("repo: the .pkgmeta has no externals and ignores the dev-only entries", function()
    local pkg = read(".pkgmeta")
    assertFalse(pkg:find("\nexternals:") ~= nil or pkg:find("^externals:") ~= nil)
    for _, entry in ipairs({ ".luacheckrc", ".pkgmeta", ".gitignore", ".gitattributes", "docs", "tests" }) do
        assertTrue(pkg:find("  - " .. entry, 1, true) ~= nil, entry)
    end
end)
