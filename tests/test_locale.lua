-- tests/test_locale.lua — locales/enUS.lua (with locales/enUS_Settings.lua, the settings panel's
-- strings peeled out of it at the layout-§1 cap) carries every string the code routes through NS.L
-- (localization-§1, §3; review F07, decision D8). The key-on-miss fallback answers an absent key with
-- itself, so a missing entry renders fine on enUS and hides from the translator's base; this suite
-- reads the table RAW so the fallback cannot answer for it.
--
-- Both directions: every literal `L["..."]` / `NS.L["..."]` in an addon file has an enUS entry,
-- and every enUS key is a string literal somewhere in the addon's files (localization-§3: enUS
-- accumulates no key nothing reads). The reverse is looser than an `L[...]` call site, because some
-- keys are reached dynamically (core/SimSeam.lua's `L[line]`, the refusal and situation-label
-- tables), but a key whose text appears nowhere is read by nothing.
--
-- red under: delete any one entry from locales/enUS.lua or locales/enUS_Settings.lua; or leave an
-- entry behind after its last reader goes

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

-- The enUS files' table, loaded in TOC order against a stub namespace, metatable stripped.
local ENUS_FILES = { "locales/enUS.lua", "locales/enUS_Settings.lua" }

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
    assertTrue(#missing == 0, #missing .. " routed key(s) missing from locales/enUS.lua:\n"
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
    for _, path in ipairs(ENUS_FILES) do
        local f = assert(io.open(path, "r"))
        for line in f:lines() do
            local raw = line:match("^L%[(\".-\")%]%s*=")   -- the key as written, quotes kept
            if raw and not src:find(raw, 1, true) then orphans[#orphans + 1] = path .. ": " .. raw end
        end
        f:close()
    end
    assertTrue(#orphans == 0, #orphans .. " enUS key(s) nothing reads:\n"
        .. table.concat(orphans, "\n", 1, math.min(#orphans, 20)))
end)
