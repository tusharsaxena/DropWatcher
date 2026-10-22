-- tests/test_bindings.lua — the Show window key binding (launcher-§6, LibKa0s#58).
--
-- A root Bindings.xml declares one CLICK binding on a plain, named, hidden, non-secure Button
-- (DropWatcherToggleWindow, core/LauncherSetup.lua), registered for AnyDown, whose OnClick runs the
-- same handler as the launcher's Show window entry and `/dw toggle`: NS.ToggleWindow. No default
-- key. The client reads the file without the TOC listing it. The refusal while stood down is
-- tests/test_disabled.lua's step 8 and step 9.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BUTTON = "DropWatcherToggleWindow"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

test("bindings: Bindings.xml carries one CLICK binding on DropWatcherToggleWindow under DROPWATCHER, category ADDONS, with no default key, and the TOC does not list it", function()
    local xml = readFile("Bindings.xml")
    -- red under: delete Bindings.xml
    assertTrue(xml ~= nil, "Bindings.xml sits at the repo root")
    local rows = {}
    for attrs in xml:gmatch("<Binding%s+(.-)/?>") do rows[#rows + 1] = attrs end
    assertEqual(#rows, 1, "exactly one binding")
    local a = rows[1]
    assertEqual(a:match('name="(.-)"'), BINDING)
    assertEqual(a:match('header="(.-)"'), "DROPWATCHER")
    assertEqual(a:match('category="(.-)"'), "ADDONS")
    assertTrue(a:find("default", 1, true) == nil, "no default key: the player picks one")
    assertTrue(xml:find("<Bindings>", 1, true) ~= nil and xml:find("</Bindings>", 1, true) ~= nil)
    assertTrue(xml:find("<Binding%s[^>]-/>") ~= nil, "self-closing: no Lua body on the binding")
    local toc = assert(readFile("DropWatcher.toc"))
    assertTrue(toc:find("Bindings.xml", 1, true) == nil, "the client loads Bindings.xml itself; the TOC never lists it")
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
-- __newindex), and `_G` inside a chunk is the mock: so the header is read from _G after clearing
-- it, and the row's rawset from the mock.
test("bindings: the header label is the brand and the binding label is localized", function()
    _G.BINDING_HEADER_DROPWATCHER = nil
    local NS, _, m = T.newAddon()
    -- red under: drop the two label writes in core/LauncherSetup.lua
    assertEqual(_G.BINDING_HEADER_DROPWATCHER, NS.BRAND)
    assertEqual(rawget(m, "BINDING_NAME_" .. BINDING), NS.L["Toggle Drop Watcher window"])
    assertEqual(rawget(m, "BINDING_NAME_" .. BINDING), "Toggle Drop Watcher window")
end)

test("bindings: the button exists on a library-less install too", function()
    local _, _, m = T.newAddon{ skip = T.loadAddon.libFiles }
    -- red under: create the button below core/LauncherSetup.lua's `if not lib` exit
    assertTrue(m[BUTTON] ~= nil and m[BUTTON]:GetScript("OnClick") ~= nil)
end)
