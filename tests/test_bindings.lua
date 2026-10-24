-- tests/test_bindings.lua — the key bindings (launcher-§6, LibKa0s#58) and General > Keybindings
-- (options-ui-§20, item 015).
--
-- A root Bindings.xml declares one CLICK binding on a plain, named, hidden, non-secure Button
-- (DropWatcherToggleWindow, core/LauncherSetup.lua), registered for AnyDown, whose OnClick runs the
-- same handler as the launcher's Show window entry and `/dw toggle`: NS.ToggleWindow. Every
-- <Binding> names the addon's own category, BINDING_HEADER_DROPWATCHER (the brand), and carries no
-- header= and no default key; NS.BINDINGS lists the commands in file order, and the kit's
-- Kit.assertBindingsXml holds the file to it. The General page's last tab, Keybindings, is
-- LibKa0s's O.KeybindingsTab over NS.BINDINGS: its rows, its labels, a key bound through it, a key
-- set elsewhere showing in it, and its combat refusal are pinned here; the capture, slot, conflict
-- and sync cases themselves are the library's (testing-§8). The refusal while stood down is
-- tests/test_disabled.lua's step 8 and step 9.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BUTTON = "DropWatcherToggleWindow"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
local CATEGORY = "BINDING_HEADER_DROPWATCHER"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- Where a chunk's globals land: a plain write in the real _G (tests/_kit/loader.lua's __newindex),
-- a rawset(_G, ...) in the mock (`_G` inside a chunk is the mock). The client has one table.
local function globalsOf(m)
    return setmetatable({}, { __index = function(_, k)
        local v = rawget(m, k)
        if v ~= nil then return v end
        return _G[k]
    end })
end

test("bindings: Bindings.xml puts every binding in the addon's own category, no header, no default, in NS.BINDINGS order, and the TOC does not list it", function()
    _G[CATEGORY] = nil
    local NS, _, m = T.newAddon()
    -- red under: header="DROPWATCHER" category="ADDONS" (the pre-v2.88.0 shape)
    T.assertBindingsXml("Bindings.xml", {
        category = CATEGORY, commands = NS.BINDINGS, brand = NS.BRAND, globals = globalsOf(m),
        labels   = { [BINDING] = "Toggle drop feed" },
    })
    local xml = assert(readFile("Bindings.xml"))
    assertTrue(xml:find("header=", 1, true) == nil, "no header attribute: the category is the heading")
    assertTrue(xml:find("<Binding%s[^>]-/>") ~= nil, "self-closing: no Lua body on the binding")
    local toc = assert(readFile("DropWatcher.toc"))
    assertTrue(toc:find("Bindings.xml", 1, true) == nil, "the client loads Bindings.xml itself; the TOC never lists it")
end)

test("bindings: NS.BINDINGS is the one table, Show window first, with a localized tooltip, on a library-less install too", function()
    for _, opts in ipairs({ {}, { skip = T.loadAddon.libFiles } }) do
        local NS = T.newAddon(opts)
        -- red under: drop NS.BINDINGS from core/LauncherSetup.lua
        assertEqual(type(NS.BINDINGS), "table")
        assertEqual(#NS.BINDINGS, 1, "one binding")
        assertEqual(NS.BINDINGS[1].command, BINDING, "Show window first")
        assertEqual(NS.BINDINGS[1].tooltip, NS.L["Shows or hides the drop feed."])
        assertEqual(NS.BINDINGS[1].tooltip, "Shows or hides the drop feed.")
    end
end)

test("bindings: the button is a plain hidden Button named DropWatcherToggleWindow, registered for AnyDown only", function()
    local _, _, m = T.newAddon()
    local b = m[BUTTON]
    -- red under: drop the CreateFrame in core/LauncherSetup.lua
    assertTrue(b ~= nil, "filed in _G under its permanent name")
    assertEqual(b.__frameType, "Button")
    assertEqual(b.__name, BUTTON)
    assertTrue(b.__parent == m.UIParent, "parented to UIParent")
    assertEqual(b.__template, nil, "no template: plain, not secure")
    assertFalse(b:IsShown() == true, "hidden: a key press clicks it, nothing draws it")
    assertEqual(table.concat(b.__clicks or {}, ","), "AnyDown", "one click per key press, on the down stroke")
    assertTrue(b:GetScript("OnClick") ~= nil, "it has a click handler")
end)

test("bindings: one press is one NS.Window.Toggle", function()
    local NS, _, m = T.enableAddon()
    local toggles = 0
    local real = NS.Window.Toggle
    NS.Window.Toggle = function(...) toggles = toggles + 1; return real(...) end
    assertFalse(NS.IsWindowShown())
    m.prints = {}
    m[BUTTON]:__fire("OnClick", "LeftButton", true)
    assertEqual(toggles, 1, "the press runs the toggle once")
    assertTrue(NS.IsWindowShown(), "the first press opens the window")
    m[BUTTON]:__fire("OnClick", "LeftButton", true)
    assertEqual(toggles, 2)
    assertFalse(NS.IsWindowShown(), "the second press closes it")
    assertEqual(#m.prints, 0, "standing up, a press prints nothing")
end)

-- A plain global write from an addon chunk lands in the real _G (tests/_kit/loader.lua's
-- __newindex), and `_G` inside a chunk is the mock: so the category is read from _G after clearing
-- it, and the row's rawset from the mock.
test("bindings: the category label is the brand and the binding label is localized, with no brand in it", function()
    _G[CATEGORY] = nil
    local NS, _, m = T.newAddon()
    -- red under: drop the two label writes in core/LauncherSetup.lua
    assertEqual(_G[CATEGORY], NS.BRAND)
    assertEqual(rawget(m, "BINDING_NAME_" .. BINDING), NS.L["Toggle drop feed"])
    assertEqual(rawget(m, "BINDING_NAME_" .. BINDING), "Toggle drop feed")
end)

test("bindings: the button exists on a library-less install too", function()
    local _, _, m = T.newAddon{ skip = T.loadAddon.libFiles }
    -- red under: create the button below core/LauncherSetup.lua's `if not lib` exit
    assertTrue(m[BUTTON] ~= nil and m[BUTTON]:GetScript("OnClick") ~= nil)
end)

-- ── General > Keybindings (options-ui-§20) ──────────────────────────────────────────────────

-- Show the General page and answer its ctx.
local function openGeneral(NS)
    local ctx = NS.addon.Settings.Helpers.__panelFor("general")
    assertTrue(ctx ~= nil, "the General page was built")
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    return ctx
end

-- The strip's tabs in order, read as the active tab each button selects.
local function stripOf(ctx)
    local out = {}
    for i, b in ipairs(ctx.__tabLayout.buttons) do
        b:__fire("OnClick")
        out[i] = ctx.activeTab
    end
    return out
end

-- Click the Keybindings tab and answer its row records, in draw order (the library's live-row
-- set, filtered to this page).
local function keybindRows(m, ctx)
    local buttons = ctx.__tabLayout.buttons
    buttons[#buttons]:__fire("OnClick")
    assertEqual(ctx.activeTab, "Keybindings")
    local lib = m.LibStub("LibKa0s-Options-1.0")
    local rows = {}
    for row, owner in pairs(lib.__keybindLive) do
        if owner == ctx then rows[#rows + 1] = row end
    end
    -- The set is unordered: order the rows as their groups were drawn.
    local drawn = {}
    for i, w in ipairs(m.__libs["AceGUI-3.0"].__created) do drawn[w] = i end
    table.sort(rows, function(a, b) return drawn[a.group] < drawn[b.group] end)
    return rows
end

-- Kit.keybindThroughTab resolves the Options library through the global LibStub; each case here
-- has its own mock, so the case's LibStub stands in for the duration of the press.
local function bindThroughTab(m, row, slot, key)
    local saved = rawget(_G, "LibStub")
    rawset(_G, "LibStub", m.LibStub)
    local ok, out = pcall(T.keybindThroughTab, row, slot, key)
    rawset(_G, "LibStub", saved)
    if not ok then error(out, 0) end
    return out
end

test("keybindings: the General page's strip ends with Keybindings", function()
    local NS = T.enableAddon()
    local strip = stripOf(openGeneral(NS))
    -- red under: drop the tabs entry from settings/Panel.lua's renderGeneral
    assertEqual(strip[1], "Master controls", "Master controls stays first")
    assertEqual(strip[#strip], "Keybindings", "the last tab")
end)

test("keybindings: the tab's rows are NS.BINDINGS, in order, labeled with the BINDING_NAME_ globals", function()
    local NS, _, m = T.enableAddon()
    local rows = keybindRows(m, openGeneral(NS))
    -- red under: an empty `bindings` list in settings/Panel.lua
    assertEqual(#rows, #NS.BINDINGS)
    for i, b in ipairs(NS.BINDINGS) do
        assertEqual(rows[i].command, b.command, "row " .. i)
        assertEqual(rows[i].label.text, rawget(m, "BINDING_NAME_" .. b.command), "row " .. i .. "'s label")
    end
    assertEqual(rows[1].label.text, "Toggle drop feed")
end)

test("keybindings: a key bound through the tab is the binding's key, saved to the set in force", function()
    local NS, _, m = T.enableAddon()
    local rows = keybindRows(m, openGeneral(NS))
    -- red under: an empty `bindings` list in settings/Panel.lua
    local line = bindThroughTab(m, rows[1], 1, "F7")
    assertEqual(line, m.KEY_BOUND)
    assertEqual(m.GetBindingKey(BINDING), "F7")
    assertEqual(m.GetBindingAction("F7"), BINDING)
    assertEqual(table.concat(m.__savedBindingSets, ","), tostring(m.GetCurrentBindingSet()))
end)

test("keybindings: a key set on the client's page shows in the tab after UPDATE_BINDINGS", function()
    local NS, _, m = T.enableAddon()
    local rows = keybindRows(m, openGeneral(NS))
    local slot = rows[1].slots[1]
    assertEqual(slot.text, m.NOT_BOUND, "nothing bound yet")
    -- red under: no tab (nothing repaints)
    m.SetBinding("SHIFT-K", BINDING)
    m.SaveBindings(m.GetCurrentBindingSet())
    m.__fireTimers()
    assertEqual(slot.text, "SHIFT-K", "the slot repainted from GetBindingKey")
end)

test("keybindings: in combat the tab refuses and calls no binding API", function()
    local NS, _, m = T.enableAddon()
    local rows = keybindRows(m, openGeneral(NS))
    m.inCombat = true
    -- A click on a slot is refused before it listens, so there is no key to press after it.
    rows[1].slots[1]:__fire("OnClick", "LeftButton")
    -- red under: an addon-drawn key box that listens without asking the combat lock
    assertEqual(rows[1].status.text, "Key bindings can be changed after combat.")
    rows[1].clear:__fire("OnClick", "LeftButton")
    assertEqual(rows[1].status.text, "Key bindings can be changed after combat.", "Clear is refused too")
    assertEqual(m.GetBindingKey(BINDING), nil)
    assertEqual(#m.__bindingWrites, 0, "no SetBinding")
    assertEqual(#m.__savedBindingSets, 0, "no SaveBindings")
end)

test("keybindings: the General page's Defaults tooltip says the keys are not changed", function()
    local NS = T.enableAddon()
    local ctx = NS.addon.Settings.Helpers.__panelFor("general")
    local tip = ctx.panel.defaultsTooltip
    -- red under: the pre-015 tooltip, without O.KEYBINDS_UNCHANGED
    assertEqual(tip:sub(-#"Key bindings are not changed."), "Key bindings are not changed.")
end)
