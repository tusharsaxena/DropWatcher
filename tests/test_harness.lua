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
        .. "SavedVariables,OptionalDeps,DefaultState,Category-enUS,X-License,X-Standard,X-Curse-Project-ID")
    assertEqual(field(fields, "Interface"), "120100")
    assertEqual(field(fields, "Title"), "Ka0s Drop Watcher")
    assertEqual(field(fields, "X-Standard"), "https://github.com/tusharsaxena/WowAddonStandards")
    assertEqual(field(fields, "SavedVariables"), "DropWatcherDB, DropWatcherPerfDB")
    assertEqual(field(fields, "X-License"), "MIT")
    -- Published: the CurseForge project id is a real field, last (toc-file-§1), and no commented
    -- placeholder is left behind. red under: the unpublished comment kept
    assertEqual(field(fields, "X-Curse-Project-ID"), "1748054")
    for _, line in ipairs(lines) do assertTrue(line:find("^# X%-Curse%-Project%-ID:") == nil, line) end
    local fh = assert(io.open(T.root .. "/README.md", "rb"))
    local readme = fh:read("*a"); fh:close()
    assertTrue(readme:find("img.shields.io/curseforge/v/1748054", 1, true) ~= nil, "the README's CurseForge badge")
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

-- Every file line of the TOC with the label of the contiguous `# ` comment block right above it
-- ("Conventional", "LOAD-BEARING", ... or nil), the block's text, and its folder (section).
local function tocPositions()
    local _, lines = tocFields()
    local out, block = {}, {}
    for _, line in ipairs(lines) do
        if line:find("^# ") or line == "#" then
            block[#block + 1] = line
        elseif line:find("^##") then
            block = {}
        else
            local label
            for _, b in ipairs(block) do
                label = b:match("^# (Conventional)") or b:match("^# (LOAD%-BEARING)")
                if label then break end
            end
            out[#out + 1] = { file = line:gsub("\\", "/"), label = label, text = table.concat(block, "\n"),
                section = line:match("^(%w+)\\") }
            block = {}
        end
    end
    return out
end

local HANDLER_ORDER = {
    "handler runs", "handlers run", "runs first", "runs second", "run first", "run second",
    "after %w+\\[%w_]+%.lua's",
}

test("toc: no Conventional comment states the order of handlers on a shared event (toc-file-§5)", function()
    -- red under: relabel modules\Roster.lua's comment (GROUP_ROSTER_UPDATE after
    -- modules\Situations.lua's, so its handler runs second) back to `# Conventional:`
    local bad = {}
    for _, p in ipairs(tocPositions()) do
        if p.label == "Conventional" then
            local text = p.text:gsub("\n# ", " ")
            for _, pat in ipairs(HANDLER_ORDER) do
                if text:find(pat) then bad[#bad + 1] = p.file .. " (" .. pat .. ")" end
            end
        end
    end
    assertTrue(#bad == 0, "Conventional comments stating handler order, LOAD-BEARING:\n" .. table.concat(bad, "\n"))
end)

-- The members an authored file publishes at file scope (`NS.X = ...` at column 0).
local function publishes(src)
    local set = {}
    for line in src:gmatch("[^\r\n]+") do
        local name = line:match("^NS%.([%w_]+)%s*=[^=]")
        if name then set[name] = true end
    end
    return set
end

-- The NS members an authored file reads at file scope: column-0 statements that are not a function
-- definition, an `end` or a comment.
local function loadReads(src)
    local set = {}
    for line in src:gmatch("[^\r\n]+") do
        if line:find("^[%a_]") and not line:find("^local function") and not line:find("^function")
            and not line:find("^end") then
            for name in line:gmatch("NS%.([%w_]+)") do set[name] = true end
        end
    end
    return set
end

-- Each authored position's source and the members it publishes, keyed by file.
local function sourcesOf(positions)
    local src, pub = {}, {}
    for _, p in ipairs(positions) do
        if p.section ~= "libs" then
            src[p.file] = read(p.file)
            pub[p.file] = publishes(src[p.file])
        end
    end
    return src, pub
end

-- (b) shared events: the files that declare each NS.FEATURE_EVENTS row, by its method name.
local function eventFiles(positions, src)
    local NS = T.newAddon()
    local filesOf = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        for _, p in ipairs(positions) do
            if src[p.file] and src[p.file]:find('"' .. row[2] .. '"', 1, true) then
                filesOf[row[1]] = filesOf[row[1]] or {}
                filesOf[row[1]][p.file] = true
            end
        end
    end
    return filesOf
end

-- (b) a row on an event another file also handles.
local function flagSharedEvents(p, filesOf, flag)
    for event, files in pairs(filesOf) do
        if files[p.file] then
            local n = 0
            for _ in pairs(files) do n = n + 1 end
            flag(n == 1, p.file .. " has a row on the shared event " .. event .. ": LOAD-BEARING")
        end
    end
end

-- (a) a file-scope read of a member another file of the same section publishes.
local function flagSectionReads(p, s, positions, pub, flag)
    local own = pub[p.file]
    for name in pairs(loadReads(s)) do
        if not own[name] then
            for _, q in ipairs(positions) do
                if q.file ~= p.file and q.section == p.section and pub[q.file] and pub[q.file][name] then
                    flag(false, p.file .. " reads NS." .. name .. " (" .. q.file
                        .. ", same section) at load: LOAD-BEARING")
                end
            end
        end
    end
end

test("toc: no position labeled Conventional is load-bearing under toc-file-§5 (a) or (b)", function()
    -- red under: relabel core\Compat.lua's comment (it takes NS.TextParse, published one line up in
    -- core\, at load) back to `# Conventional:`
    local positions = tocPositions()
    local bad = {}
    local function flag(ok, why) if not ok then bad[#bad + 1] = why end end
    local src, pub = sourcesOf(positions)
    local filesOf = eventFiles(positions, src)
    for _, p in ipairs(positions) do
        if p.label == "Conventional" and src[p.file] then
            local s = src[p.file]
            -- (b) a step on a list walked in TOC order
            flag(s:find("NS%.STAND_DOWN%[#") == nil and s:find("NS%.STAND_UP%[#") == nil,
                p.file .. " appends a NS.STAND_DOWN / NS.STAND_UP step: LOAD-BEARING")
            flagSharedEvents(p, filesOf, flag)
            flagSectionReads(p, s, positions, pub, flag)
        end
    end
    assertTrue(#bad == 0, "Conventional positions that are load-bearing:\n" .. table.concat(bad, "\n"))
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
