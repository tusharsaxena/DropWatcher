-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker 1, LibKa0s#64; the rollout's O3 and X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the Skin tab's page and key, the eye, the close); WHEN it
-- shows (a profile whose `skin.pickerSeen` is false, once a session on the login fuse and after
-- every profile event, never while the addon stands down, held through combat); and that only the
-- player's close marks it seen. The trigger cases spy on O.SkinPicker; the later cases drive the
-- library's real window: a pick previews unsaved, Apply saves through NS.WriteSkinChoice, the close
-- control puts the stored skin back, the gear saves and opens General on its Skin tab, the picker
-- shown with the window hidden turns test mode on, the eye toggles it and every close puts it back
-- (R6-PV), and the stand-down puts a pending preview back, unsaved and unseen. Each
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
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
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
    assertEqual(spec.onPreview, nil, "the one-shot eye is gone (R6-PV)")
    local pv = spec.preview
    assertTrue(type(pv) == "table", "a test mode to preview in: the eye shows (X6, R6-PV)")
    assertEqual(pv.mode, "test", "DropWatcher previews in test mode (round 6, call 2)")
    for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
        assertEqual(type(pv[k]), "function", "spec.preview." .. k)
    end
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
    local NS, _, m = T.enableAddon{ pickerFuse = true }
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
    local NS, _, m = T.enableAddon{ pickerFuse = true }
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

-- ── the preview (R6-PV; LibKa0s OptionsSkinPicker 11, spec.preview) ─────────────────────────────
--
-- The owner's rule: the picker shown with the window hidden turns test mode on, the eye toggles it,
-- and every close puts back what the picker and its eye moved. Every call goes through
-- NS.SetTestMode, the seam /dw test, the launcher and the Master controls checkbox use.

--- An enabled addon, its window hidden and test mode off, with the library's real picker up.
local function onHiddenWindow()
    local NS, m, f, pick = onWindow()
    return NS, m, f, pick
end

--- `fn` with the eye clicked through the library, quiet.
local function eye(m, f) quietly(m, function() f.preview:__fire("OnClick") end) end

test("Skin picker: shown with the window hidden, test mode turns on and the window opens", function()
    -- red under: an onPreview-only spec (nothing runs at show), or a preview whose enter is not
    -- NS.SetTestMode (the placeholders and the window would not follow).
    local NS, _, f = onHiddenWindow()
    assertTrue(NS.State.testMode == true, "the picker's show did not start test mode")
    assertTrue(NS.IsWindowShown(), "test mode's start did not open the window")
    assertTrue(f:IsShown(), "the picker stays up over the window")
    assertTrue(f.preview.lit == true, "the eye is lit while test mode is on")
end)

test("Skin picker: the eye toggles test mode off and on through the write seam", function()
    -- red under: the old enter-only eye (a second click re-shows the window and never ends it).
    local NS, m, f = onHiddenWindow()
    eye(m, f)
    assertFalse(NS.State.testMode == true, "the eye did not turn test mode off")
    assertFalse(NS.IsWindowShown(), "test mode's end did not close the window it opened")
    assertFalse(f.preview.lit == true, "the eye is dimmed while test mode is off")
    assertTrue(f:IsShown(), "the eye leaves the picker up")
    eye(m, f)
    assertTrue(NS.State.testMode == true, "the eye did not turn test mode back on")
    assertTrue(NS.IsWindowShown(), "and the window opens again")
    assertTrue(f.preview.lit == true)
end)

test("Skin picker: every close puts test mode and the window back as they were", function()
    -- red under: no restore (test mode and the window it opened outlive the picker).
    local routes = {
        ["the close control"] = function(_, _, f) f.close:__fire("OnClick") end,
        ["Apply"] = function(_, _, f) f.apply:__fire("OnClick") end,
        -- UISpecialFrames hides it; the client fires OnHide inside Hide(), the mock does not.
        ["Escape"] = function(_, _, f) f:Hide(); f:__fire("OnHide") end,
        ["the gear"] = function(_, m, f) quietly(m, function() f.settings:__fire("OnClick") end) end,
        ["the stand-down"] = function(NS, m) quietly(m, function() set(NS, "enabled", false) end) end,
        ["a profile event's hide"] = function(NS) NS.HideSkinPicker() end,
    }
    for name, close in pairs(routes) do
        local NS, m, f = onHiddenWindow()
        assertTrue(NS.State.testMode == true, name .. ": the show entered test mode")
        quietly(m, function() close(NS, m, f) end)
        assertFalse(f:IsShown(), name .. " did not close the picker")
        assertFalse(NS.State.testMode == true, name .. " left test mode on")
        assertFalse(NS.IsWindowShown(), name .. " left the window open")
    end
end)

test("Skin picker: the stand-down's close leaves no window the picker opened for the stand-up", function()
    -- red under: a stand-down that ends test mode with a raw flag write, leaving the window it
    -- opened marked open, so the stand-up shows a window the player never asked for.
    local NS, m = onHiddenWindow()
    assertTrue(NS.State.testMode == true and NS.IsWindowShown(), "the show entered test mode")
    quietly(m, function() set(NS, "enabled", false) end)
    assertFalse(NS.State.testMode == true, "the stand-down ended test mode")
    quietly(m, function() set(NS, "enabled", true) end)
    assertFalse(NS.State.testMode == true, "test mode stays off after the stand-up")
    assertFalse(NS.IsWindowShown(), "the window test mode opened stays closed after the stand-up")
    assertFalse(NS.State.windowOpen == true, "and is not marked open")
end)

test("Skin picker: test mode on at open, turned off by the eye, is on again after the close", function()
    local NS, m = enabled()
    quietly(m, function() NS.SetTestMode(true) end)
    local f
    quietly(m, function() f = NS.MaybeShowSkinPicker() end)
    assertTrue(f ~= nil and f:IsShown())
    eye(m, f)
    assertFalse(NS.State.testMode == true, "the eye turned it off")
    f.close:__fire("OnClick")
    assertTrue(NS.State.testMode == true, "the close put test mode back on")
    assertTrue(NS.IsWindowShown(), "with its window")
end)

test("Skin picker: a window already shown is left alone, and stays shown after the close", function()
    -- red under: an isShown that is not NS.IsWindowShown (test mode would be forced over a live window).
    local NS, m = enabled()
    NS.ShowWindow()
    assertTrue(NS.IsWindowShown(), "the window opens")
    local f
    quietly(m, function() f = NS.MaybeShowSkinPicker() end)
    assertTrue(f ~= nil and f:IsShown())
    assertFalse(NS.State.testMode == true, "a shown window is not put into test mode")
    assertFalse(f.preview.lit == true, "the eye is dimmed: test mode is off")
    f.close:__fire("OnClick")
    assertFalse(NS.State.testMode == true)
    assertTrue(NS.IsWindowShown(), "the player's window stays open")
end)

test("Skin picker: test mode the player turns on with /dw test while the picker is up stays on", function()
    -- red under: a close that ends test mode whatever moved it (the picker moved nothing here).
    local NS, m = enabled()
    NS.ShowWindow()
    local f
    quietly(m, function() f = NS.MaybeShowSkinPicker() end)
    assertFalse(NS.State.testMode == true, "a shown window: the picker enters nothing")
    quietly(m, function() NS.ToggleTestMode() end)
    assertTrue(NS.State.testMode == true, "/dw test's handler turned it on")
    f.close:__fire("OnClick")
    assertTrue(NS.State.testMode == true, "the player's own test mode outlives the close")
    assertTrue(NS.IsWindowShown())
end)

test("Skin picker: in combat the eye's start is refused and the close undoes nothing", function()
    -- red under: an enter that bypasses NS.SetTestMode's combat refusal.
    local NS, m, f = onHiddenWindow()
    eye(m, f)
    assertFalse(NS.State.testMode == true)
    m.inCombat = true
    local before = #m.prints
    local ok, err = pcall(function()
        f.preview:__fire("OnClick")
        assertFalse(NS.State.testMode == true, "combat refuses test mode's start")
        local said = m.prints[#m.prints]
        assertTrue(#m.prints > before and said:find("not available in combat", 1, true) ~= nil,
            "the refusal prints test mode's own line")
        f.close:__fire("OnClick")
    end)
    m.inCombat = false
    if not ok then error(err, 0) end
    assertFalse(NS.State.testMode == true, "nothing moved, so nothing is put back")
    assertFalse(NS.IsWindowShown())
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
