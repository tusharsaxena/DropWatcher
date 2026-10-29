-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker 1, LibKa0s#64; the rollout's O3 and X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the Skin tab's page and key, the eye, the close); WHEN it
-- shows (a profile whose `skin.pickerSeen` is false, once a session on the login fuse and after
-- every profile event, never while the addon stands down, held through combat); and that only the
-- player's close marks it seen. The trigger cases spy on O.SkinPicker; the later cases drive the
-- library's real window: a pick previews unsaved, Apply saves through NS.WriteSkinChoice, the close
-- control puts the stored skin back, the gear saves and opens General on its Skin tab, the eye opens
-- the window in test mode, and the stand-down puts a pending preview back, unsaved and unseen. Each
-- case builds its own addon, so no picker outlives a case.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "DropWatcher"
local PATH = "skin.pickerSeen"

local function options(NS) return NS.addon.Settings.Helpers end
local function get(NS, path) return NS.SchemaRuntime.Get(path) end
local function set(NS, path, v) return NS.SchemaRuntime.Set(path, v) end

--- Run `fn(calls)` with the Options instance's SkinPicker replaced by a recorder: each call's spec.
local function spying(NS, fn)
    local O = options(NS)
    local real = O.SkinPicker
    local calls = {}
    O.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    O.SkinPicker = real
    if not ok then error(err, 0) end
end

-- Chat silenced for `fn` (a stand-down and test mode each print a line).
local function quietly(m, fn)
    local cf = m.DEFAULT_CHAT_FRAME
    local add = cf.AddMessage
    cf.AddMessage = function() end
    local ok, err = pcall(fn)
    cf.AddMessage = add
    if not ok then error(err, 0) end
end

--- An enabled addon whose login fuse is put out, so a case starts the picker itself.
local function enabled()
    local NS, _, m = T.enableAddon()
    NS.ArmSkinPicker(false)
    return NS, m
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────

test("Skin picker: skin.pickerSeen defaults to false, a skip-render row of General's Skin tab", function()
    -- red under: a default of true (no profile would ever show it), or a row that draws itself.
    local NS = enabled()
    assertEqual(NS.addon.Settings.BuildDefaults().profile.skin.pickerSeen, false)
    local row = NS.SchemaRuntime.FindRow(PATH)
    assertTrue(row ~= nil, PATH .. " is not a schema row")
    assertEqual(row.type, "bool")
    assertEqual(row.page, "general")
    assertEqual(row.group, "Appearance")
    assertTrue(row.skipRender == true, "nothing draws it")
    assertEqual(get(NS, PATH), false, "every profile starts unseen (O3)")
end)

test("Skin picker: the spec names this owner, its seams, the Skin tab and the eye", function()
    -- red under: a set that is not the write seam (Apply would never reach the profile), or a page
    -- or tab key O.SelectTab does not know (the gear would open the panel on the wrong tab).
    local NS = enabled()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
    assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
    assertEqual(spec.page, "general")
    assertEqual(spec.tab, "Appearance", "the Skin tab's key")
    assertTrue(options(NS).__panelFor("general") ~= nil, "\"general\" is the page O.SelectTab finds")
    assertEqual(type(spec.onPreview), "function", "a test mode to preview in: the eye shows (X6)")
    assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("Skin picker: an unseen profile shows it; a seen one does not", function()
    local NS = enabled()
    spying(NS, function(calls)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen false: the picker shows")
        assertEqual(calls[1].owner, OWNER)
        set(NS, PATH, true)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen true: it does not show again")
    end)
end)

test("Skin picker: the login fuse shows it once a session, two seconds after OnEnable", function()
    -- red under: dropping NS.ArmSkinPicker from OnEnable, or a fuse that is lit again once burned.
    local NS, _, m = T.enableAddon()
    spying(NS, function(calls)
        assertEqual(#calls, 0, "nothing at OnEnable itself")
        m.advance(1.9)
        assertEqual(#calls, 0, "not before two seconds")
        m.advance(0.2)
        assertEqual(#calls, 1, "the fuse shows the picker")
        NS.ArmSkinPicker(true)
        m.__fireTimers()
        assertEqual(#calls, 1, "a burned fuse is not lit again")
    end)
end)

test("Skin picker: the stand-down puts the fuse out; the stand-up lights it again", function()
    -- red under: a fuse the stand-down leaves burning (a disabled addon would show a window), or a
    -- session that started stood down never showing it.
    local NS, _, m = T.enableAddon()
    spying(NS, function(calls)
        quietly(m, function()
            set(NS, "enabled", false)
            assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
            m.__fireTimers()
            assertEqual(#calls, 0, "a stood-down addon shows no picker")
            set(NS, "enabled", true)
        end)
        m.__fireTimers()
        assertEqual(#calls, 1, "the stand-up's fuse shows it")
    end)
end)

test("Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", function()
    local NS, m = enabled()
    spying(NS, function(calls)
        m.inCombat = true
        assertEqual(NS.MaybeShowSkinPicker(), nil)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "nothing shows in combat")
        m.inCombat = false
        m.__fire("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
        m.__fire("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the held start is spent")
    end)
end)

test("Skin picker: a held start is dropped by HideSkinPicker", function()
    local NS, m = enabled()
    spying(NS, function(calls)
        m.inCombat = true
        NS.MaybeShowSkinPicker()
        NS.HideSkinPicker()
        m.inCombat = false
        m.__fire("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
    end)
end)

test("Skin picker: never while the addon is switched off or a perf capture holds it down", function()
    local NS, m = enabled()
    spying(NS, function(calls)
        quietly(m, function()
            set(NS, "enabled", false)
            NS.MaybeShowSkinPicker()
            assertEqual(#calls, 0, "a disabled addon shows no picker")
            set(NS, "enabled", true)
            NS.Lifecycle:Hold(NS.HOLD_PERF)
            NS.MaybeShowSkinPicker()
            assertEqual(#calls, 0, "the perf hold shows no picker")
            NS.Lifecycle:Release(NS.HOLD_PERF)
        end)
    end)
end)

test("Skin picker: a new profile and a reset profile show it again", function()
    -- Both start from the defaults, pickerSeen false. red under: no call on the profile path, or one
    -- before the latch re-reads the new profile's switch.
    local NS, m = enabled()
    local db = NS.addon.db
    set(NS, PATH, true)
    quietly(m, function()
        spying(NS, function(calls)
            db:SetProfile("PickerProbe")
            assertEqual(#calls, 1, "a new profile shows the picker")
            set(NS, PATH, true)
            db:ResetProfile()
            assertEqual(#calls, 2, "a reset profile shows it again")
            set(NS, PATH, true)
            db:SetProfile("Default")
            assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
        end)
    end)
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────

-- Every frame built from here on, by parent, so a case can reach the picker list's rows: the
-- mock's frames do not list their children, and the picker builds its window, rows included, on
-- its first show.
local function recordChildren(m)
    local childrenOf = setmetatable({}, { __mode = "k" })
    local create = m.CreateFrame
    m.CreateFrame = function(frameType, name, parent, ...)
        local f = create(frameType, name, parent, ...)
        if parent ~= nil then
            local list = childrenOf[parent] or {}
            childrenOf[parent] = list
            list[#list + 1] = f
        end
        return f
    end
    return childrenOf
end

--- An enabled addon with the library's real picker up: answers NS, the mock, the window and a
--- pick(key) that opens the list and clicks the row for skin `key`, as the player does.
local function onWindow()
    local NS, m = enabled()
    local childrenOf = recordChildren(m)
    local f
    quietly(m, function() f = NS.MaybeShowSkinPicker() end)
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    local function pick(key)
        f.dd:__fire("OnClick")
        local hit = false
        for _, r in ipairs(childrenOf[f.list] or {}) do
            if r.key == key then r:__fire("OnClick"); hit = true end
        end
        assertTrue(hit, "no row for " .. key)
    end
    return NS, m, f, pick
end

local function worn(m) return select(2, m.LibStub("LibKa0s-Skin-1.0"):GetChoice(OWNER)) end
local function stored(NS) return select(2, NS.SkinChoice()) end

test("Skin picker: the player's close marks it seen; this addon's own hide does not", function()
    local NS, m, f = onWindow()
    NS.HideSkinPicker()
    assertFalse(f:IsShown(), "the hide takes it down")
    assertEqual(get(NS, PATH), false, "a stand-down hide is not the player's close")
    quietly(m, function() f = NS.MaybeShowSkinPicker() end)
    assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
    options(NS).HideSkinPicker()
    assertEqual(get(NS, PATH), true, "the player's close sets pickerSeen")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
end)

test("Skin picker: a pick previews, unsaved; Apply saves it and marks the picker seen", function()
    -- red under: a spec.set that is not the write seam (Apply would save nothing), or an onClose
    -- that does not write pickerSeen (the picker would come back on the next login).
    local NS, m, f, pick = onWindow()
    pick("obsidian")
    assertEqual(worn(m), "obsidian", "the pick is worn at once")
    assertEqual(stored(NS), "ka0s", "a pick alone writes nothing to the profile")
    assertEqual(get(NS, PATH), false, "a pick does not end the showing")
    assertTrue(f:IsShown(), "the window stays up for Apply")
    f.apply:__fire("OnClick")
    assertFalse(f:IsShown(), "Apply closes the window")
    assertEqual(stored(NS), "obsidian", "Apply saves through NS.WriteSkinChoice")
    assertEqual(worn(m), "obsidian")
    assertEqual(get(NS, PATH), true, "Apply marks the picker seen")
end)

test("Skin picker: the close control puts the stored skin back, saves nothing, and marks it seen", function()
    local NS, m, f, pick = onWindow()
    pick("obsidian")
    assertTrue(f.close ~= nil, "the window has a close control")
    f.close:__fire("OnClick")
    assertFalse(f:IsShown(), "the close control closes the window")
    assertEqual(worn(m), "ka0s", "closing puts back the stored skin")
    assertEqual(stored(NS), "ka0s", "and writes nothing")
    assertEqual(get(NS, PATH), true, "a close by the player still counts as seen")
end)

test("Skin picker: the gear saves the pick and opens General on its Skin tab", function()
    -- red under: a page key OpenOptionsPanel does not know (the landing page opens), or a tab key
    -- the General page has no tab for.
    local NS, m, f, pick = onWindow()
    local O = options(NS)
    local realOpen, opened = O.OpenOptionsPanel, {}
    O.OpenOptionsPanel = function(page) opened[#opened + 1] = page; return realOpen(page) end
    local ok, err = pcall(function()
        pick("obsidian")
        quietly(m, function() f.settings:__fire("OnClick") end)
    end)
    O.OpenOptionsPanel = realOpen
    if not ok then error(err, 0) end
    assertEqual(#opened, 1, "the gear opens the settings once")
    assertEqual(opened[1], "general", "on this addon's General page, not the landing page")
    assertEqual(O.__panelFor("general").activeTab, "Appearance", "on its Skin tab")
    assertFalse(f:IsShown(), "the gear closes the window")
    assertEqual(stored(NS), "obsidian", "the gear saves the pending pick")
    assertEqual(get(NS, PATH), true, "and marks the picker seen")
end)

test("Skin picker: the eye opens the window in test mode and leaves the picker up", function()
    local NS, m, f = onWindow()
    quietly(m, function() f.preview:__fire("OnClick") end)
    assertTrue(NS.State.testMode == true, "the eye did not start test mode")
    assertTrue(NS.IsWindowShown(), "the eye did not show the window")
    assertTrue(f:IsShown(), "the eye leaves the picker up")
    NS.HideWindow()
    quietly(m, function() NS.SkinPickerSpec().onPreview() end)
    assertTrue(NS.IsWindowShown(), "with test mode already on, the eye still shows the window")
end)

test("Skin picker: the stand-down with a preview pending puts the stored skin back, unsaved, unseen", function()
    local NS, m, f, pick = onWindow()
    pick("obsidian")
    quietly(m, function() set(NS, "enabled", false) end)
    assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
    assertFalse(f:IsShown(), "the stand-down takes the picker down")
    assertEqual(worn(m), "ka0s", "the pending preview is put back")
    assertEqual(stored(NS), "ka0s", "and never saved")
    assertEqual(get(NS, PATH), false, "a stand-down is not the player's close")
end)

test("Skin picker: a profile switch with a preview pending wears the new profile's skin", function()
    -- red under: taking the picker down after the new profile's skin is applied (the put-back would
    -- wear the old profile's skin over the new one's).
    local NS, m, f, pick = onWindow()
    local db = NS.addon.db
    NS.HideSkinPicker()
    quietly(m, function()
        db:SetProfile("PickerProbe")
        set(NS, PATH, true)
        NS.WriteSkinChoice("ka0s", "azeroth")
        NS.ApplySkinChoice()
        db:SetProfile("Default")
    end)
    assertEqual(stored(NS), "ka0s")
    quietly(m, function() f = NS.MaybeShowSkinPicker() end)
    assertTrue(f ~= nil and f:IsShown(), "Default has not seen the picker")
    pick("obsidian")
    assertEqual(worn(m), "obsidian")
    quietly(m, function() db:SetProfile("PickerProbe") end)
    assertFalse(f:IsShown(), "a profile that has seen it takes the picker down")
    assertEqual(worn(m), "azeroth", "the new profile's skin is worn, not the old one's")
end)

test("Skin picker: degraded, nothing shows and nothing raises", function()
    local D = T.enableAddon{ skip = T.loadAddon.libFiles }
    assertEqual(D.MaybeShowSkinPicker(), nil)
    D.HideSkinPicker()
    assertEqual(type(D.SkinPickerSpec().onClose), "function")
end)
