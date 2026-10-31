-- tests/test_locale.lua — locales/enUS.lua (with locales/enUS_Settings.lua, the settings panel's
-- topic file split out of it at the layout-§1 cap, localization-§6) carries every string the code
-- routes through NS.L (localization-§1, §3; review F07, decision D8). The key-on-miss fallback answers
-- an absent key with itself, so a missing entry renders fine on enUS and hides from the translator's
-- base; this suite reads the table RAW so the fallback cannot answer for it.
--
-- The gates read the union of every enUS file (localization-§6): the list comes from the TOC, the
-- files load in its order into one namespace, and a key written in two files fails, read from their
-- text because the loaded table keeps only the last write. A topic file fills the base file's NS.L
-- and nothing else, and holds only what its folder alone reads.
--
-- Both directions: every literal `L["..."]` / `NS.L["..."]` in an addon file has an enUS entry,
-- and every enUS key is a string literal somewhere in the addon's files (localization-§3: enUS
-- accumulates no key nothing reads). The reverse is looser than an `L[...]` call site, because some
-- keys are reached dynamically (core/SimSetup.lua's `L[line]`, the refusal and situation-label
-- tables), but a key whose text appears nowhere is read by nothing.
--
-- red under: delete any one entry from locales/enUS.lua or locales/enUS_Settings.lua; or leave an
-- entry behind after its last reader goes; or write one key in both files; or move a key a module
-- reads into enUS_Settings.lua; or give a topic file its own table or a name not of the enUS_<Topic> form

local T = _G.DW_TEST
local test, assertTrue = T.test, T.assertTrue

local Loader = dofile("tests/_kit/loader.lua")

-- The addon's own files in TOC order, less the locale itself (libs/ never reach tocFiles).
local function addonFiles()
    local out = {}
    for _, rel in ipairs(Loader.tocFiles("DropWatcher.toc")) do
        if not rel:match("^locales/") and not rel:match("^libs/") then out[#out + 1] = rel end
    end
    return out
end

-- The enUS files, from the TOC in its order (localization-§6): the base file's line and every
-- locales/enUS_*.lua line, so a topic file added later is read without editing this list.
local function enUSFiles()
    local out = {}
    for _, rel in ipairs(Loader.tocFiles("DropWatcher.toc")) do
        if rel == "locales/enUS.lua" or rel:match("^locales/enUS_.+%.lua$") then out[#out + 1] = rel end
    end
    return out
end
local ENUS_FILES = enUSFiles()

-- Each enUS file's key lines as { path, line, raw }, the key as written with its quotes kept.
local function keyLines()
    local out = {}
    for _, path in ipairs(ENUS_FILES) do
        local f = assert(io.open(path, "r"))
        local n = 0
        for line in f:lines() do
            n = n + 1
            local raw = line:match("^L%[(\".-\")%]%s*=")
            if raw then out[#out + 1] = { path = path, line = n, raw = raw } end
        end
        f:close()
    end
    return out
end

-- The enUS files' table, loaded in TOC order against a stub namespace, metatable stripped.

local function enUS()
    local NS = {}
    for _, path in ipairs(ENUS_FILES) do assert(loadfile(path))("DropWatcher", NS) end
    local L = NS.L
    assertTrue(type(L) == "table", "locales/enUS.lua publishes NS.L")
    return L
end

-- The raw (still escaped) bodies of every `L["..."]` on one line, `NS.L[` included. Lua patterns
-- have no alternation, so the escape-aware scan is a walk: a backslash takes the next byte with it,
-- and an unescaped quote closes the literal, which must be followed by `]` to count.
local function literals(line)
    local out, pos = {}, 1
    while true do
        local s = line:find('L["', pos, true)
        if not s then return out end
        local before = s > 1 and line:sub(s - 1, s - 1) or ""
        local i, closed = s + 3, nil
        while i <= #line do
            local c = line:sub(i, i)
            if c == "\\" then i = i + 2
            elseif c == '"' then closed = i; break
            else i = i + 1 end
        end
        if closed and line:sub(closed + 1, closed + 1) == "]" and not before:match("[%w_]") then
            out[#out + 1] = line:sub(s + 3, closed - 1)
        end
        pos = (closed or #line) + 1
    end
end

-- Every routed literal as { file, line, key }, the key unescaped as Lua would read it.
local function routedKeys()
    local out = {}
    for _, rel in ipairs(addonFiles()) do
        local f = assert(io.open(rel, "r"))
        local n = 0
        for line in f:lines() do
            n = n + 1
            for _, raw in ipairs(literals(line)) do
                local key = assert(loadstring('return "' .. raw .. '"'))()
                out[#out + 1] = { file = rel, line = n, key = key }
            end
        end
        f:close()
    end
    return out
end

test("locale: the enUS files are the TOC's, the base file first and its topic files after it", function()
    assertTrue(ENUS_FILES[1] == "locales/enUS.lua", "the base file is the TOC's first enUS line")
    assertTrue(#ENUS_FILES >= 2, "the TOC lists the settings panel's topic file")
    local toc = Loader.tocFiles("DropWatcher.toc")
    for i, path in ipairs(ENUS_FILES) do
        assertTrue(toc[i] == path, path .. " sits in the contiguous block the base file opens")
        if i > 1 then
            assertTrue(path:match("^locales/enUS_%u%w*%.lua$") ~= nil, path .. " is named enUS_<Topic>")
            local f = assert(io.open(path, "r"))
            local text = f:read("*a")
            f:close()
            assertTrue(text:find("\nlocal L = NS.L\r?\n") ~= nil, path .. " opens with local L = NS.L")
            assertTrue(not text:find("NS%.L%s*=") and not text:find("setmetatable", 1, true),
                path .. " fills the base file's NS.L and keeps no table of its own")
        end
    end
end)

test("locale: every enUS key lives in exactly one enUS file", function()
    local seen, dups = {}, {}
    for _, k in ipairs(keyLines()) do
        local at = k.path .. ":" .. k.line
        if seen[k.raw] then dups[#dups + 1] = at .. ": " .. k.raw .. ", first at " .. seen[k.raw]
        else seen[k.raw] = at end
    end
    assertTrue(#dups == 0, #dups .. " enUS key(s) written twice:\n"
        .. table.concat(dups, "\n", 1, math.min(#dups, 20)))
end)

test("locale: a topic file holds only what its folder alone reads", function()
    local home = {}   -- raw key -> the folder its topic file serves (enUS_Settings.lua -> settings/)
    for _, k in ipairs(keyLines()) do
        local topic = k.path:match("^locales/enUS_(%w+)%.lua$")
        if topic then home[assert(loadstring("return " .. k.raw))()] = topic:lower() .. "/" end
    end
    local strays = {}
    for _, use in ipairs(routedKeys()) do
        local folder = home[use.key]
        if folder and use.file:sub(1, #folder) ~= folder then
            strays[#strays + 1] = ('%s:%d: "%s" is read before %s loads; it belongs in locales/enUS.lua')
                :format(use.file, use.line, use.key, folder)
        end
    end
    assertTrue(#strays == 0, #strays .. " topic-file key(s) read outside their folder:\n"
        .. table.concat(strays, "\n", 1, math.min(#strays, 20)))
end)

test("locale: the scan finds routed literals in the addon's files", function()
    assertTrue(#routedKeys() > 100, "expected the scan to find the addon's L[...] call sites")
end)

test("locale: enUS carries every string routed through NS.L", function()
    local L = enUS()
    local missing = {}
    for _, use in ipairs(routedKeys()) do
        if rawget(L, use.key) == nil then
            missing[#missing + 1] = ('%s:%d: missing enUS key "%s"'):format(use.file, use.line, use.key)
        end
    end
    assertTrue(#missing == 0, #missing .. " routed key(s) missing from every enUS file:\n"
        .. table.concat(missing, "\n", 1, math.min(#missing, 20)))
end)

test("locale: every enUS key is still read by the addon's files", function()
    local parts = {}
    for _, rel in ipairs(addonFiles()) do
        local f = assert(io.open(rel, "r"))
        parts[#parts + 1] = f:read("*a")
        f:close()
    end
    local src = table.concat(parts, "\n")
    local orphans = {}
    for _, k in ipairs(keyLines()) do
        if not src:find(k.raw, 1, true) then orphans[#orphans + 1] = k.path .. ": " .. k.raw end
    end
    assertTrue(#orphans == 0, #orphans .. " enUS key(s) nothing reads:\n"
        .. table.concat(orphans, "\n", 1, math.min(#orphans, 20)))
end)

-- The display-glyph guard (LibKa0s v1.82.0, kit revision 45's tests/_kit/glyphs.lua; DW-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-19): nine skins draw this
-- addon's text in a dozen faces, and a character one of them lacks is a box in that skin only. So
-- every string literal outside libs/ and tests/ carries only characters every shipped face draws;
-- the verdict glyphs, drawn in the mono role (NS.SkinMono, JetBrains Mono), carry `glyph: mono`.
test("locale: display strings use only characters every shipped skin face draws", function()
    -- red under: a ≈, →, ▼ or ▲ in a string the addon paints in a skin face, unmarked.
    T.assertDisplayGlyphs{ label = "DropWatcher" }
end)
