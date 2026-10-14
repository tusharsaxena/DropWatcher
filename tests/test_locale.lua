-- tests/test_locale.lua — locales/enUS.lua carries every string the code routes through NS.L
-- (localization-§1, §3; review F07, decision D8). The key-on-miss fallback answers an absent key with
-- itself, so a missing entry renders fine on enUS and hides from the translator's base; this suite
-- reads the table RAW so the fallback cannot answer for it.
--
-- One direction only: every literal `L["..."]` / `NS.L["..."]` in an addon file has an enUS entry.
-- The reverse is not asserted, because some keys are reached dynamically (core/SimSeam.lua's
-- `L[line]`, the refusal and situation-label tables) and have no literal call site.
--
-- red under: delete any one entry from locales/enUS.lua

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

-- enUS.lua's table, loaded against a stub namespace, metatable stripped.
local function enUS()
    local chunk = assert(loadfile("locales/enUS.lua"))
    local NS = {}
    chunk("DropWatcher", NS)
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
