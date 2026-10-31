-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; DW-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec, so
-- `/dw skin` shows the picker a new profile shows whatever skin.pickerSeen says. Refused while the
-- addon is disabled (the dispatcher's gate), a gray line on every call in combat (the library's),
-- and the library-absent line without LibKa0s.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function options(NS) return NS.addon.Settings.Helpers end
local function strings(m) return m.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

local function run(NS, m, input)
    local mark = #m.prints
    NS.addon:OnSlashCommand(input)
    local out = {}
    for i = mark + 1, #m.prints do out[#out + 1] = m.prints[i] end
    return out
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
    return false
end

--- Run `fn(calls)` with the Options instance's SkinVerb replaced by a recorder of each call's spec.
local function spying(NS, fn)
    local O = options(NS)
    local real = O.SkinVerb
    local calls = {}
    O.SkinVerb = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    O.SkinVerb = real
    if not ok then error(err, 0) end
end

--- Logged in, the login fuse out and the first-run picker closed, so only the verb brings it back.
local function seenProfile()
    local NS, _, m = T.enableAddon()
    NS.ArmSkinPicker(false)
    NS.SchemaRuntime.Set("skin.pickerSeen", true)
    return NS, m
end

test("skin verb: the row sits right after config, with the library's help words", function()
    local NS, _, m = T.newAddon()
    local at
    for i, c in ipairs(NS.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    assertTrue(at ~= nil, "a skin row")
    assertEqual(NS.COMMANDS[at - 1][1], "config", "after config")
    assertEqual(NS.COMMANDS[at][2], strings(m).VERB_HELP, "one wording for every host")
end)

test("skin verb: /dw skin shows the library's picker on a profile that has closed it", function()
    -- red under: no skin row (the dispatcher answers "unknown command").
    local NS, m = seenProfile()
    local out = run(NS, m, "skin")
    assertFalse(anyLine(out, "unknown command"), "a known verb")
    local win = NS.RunSkinVerb()
    assertTrue(win ~= nil and win:IsShown(), "the picker is up")
    assertEqual(NS.SchemaRuntime.Get("skin.pickerSeen"), true, "the verb leaves the profile's mark alone")
end)

test("skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function()
    local NS = seenProfile()
    spying(NS, function(calls)
        NS.RunSkinVerb()
        assertEqual(#calls, 1)
        local spec = calls[1]
        assertEqual(spec.owner, "DropWatcher")
        assertTrue(rawequal(spec.get, NS.SkinChoice), "the read seam")
        assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "the write seam")
        assertEqual(spec.page, "general")
        assertEqual(spec.tab, "Appearance")
    end)
end)

test("skin verb: in combat every call prints the library's gray line and shows nothing", function()
    local NS, m = seenProfile()
    m.inCombat = true
    local first = run(NS, m, "skin")
    local second = run(NS, m, "skin")
    assertTrue(anyLine(first, strings(m).VERB_COMBAT), "the first call says why")
    assertTrue(anyLine(second, strings(m).VERB_COMBAT), "and so does every later one")
    local win, why = NS.RunSkinVerb()
    assertTrue(win == nil, "no picker mid-combat")
    assertEqual(why, "combat")
end)

test("skin verb: refused while the addon is disabled, and the picker is never asked", function()
    local NS, m = seenProfile()
    NS.addon:OnSlashCommand("disable")
    spying(NS, function(calls)
        local out = run(NS, m, "skin")
        assertEqual(#out, 1, "one refusal line")
        assertTrue(out[1]:find(NS.SlashCommands:DisabledLine(), 1, true) ~= nil, "the disabled line")
        assertEqual(#calls, 0)
    end)
end)

test("skin verb: without LibKa0s the verb prints the library-absent line", function()
    local NS, _, m = T.newAddon{ skip = T.loadAddon.libFiles }
    local out = run(NS, m, "skin")
    assertTrue(anyLine(out, "/dw skin is unavailable: the LibKa0s library did not load."), "names the verb")
end)
