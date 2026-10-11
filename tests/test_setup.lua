-- tests/test_setup.lua — the addon-side wiring of every adopted LibKa0s module (testing-§8).
--
-- The library's internals are covered in the LibKa0s repo; these cases cover what is this addon's:
-- each descriptor is well-formed, the seams resolve in the order the TOC promises, every declared
-- perf bucket is reached by a real bracket, and the degraded path works when the library is
-- genuinely absent.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

-- ── Core ────────────────────────────────────────────────────────────────────────────────────

test("core: NS.Print is NS.Util.print after AceConsole's embed (architecture-§2)", function()
    local NS = T.newAddon()
    -- red under: drop the reclaim line in core/DropWatcher.lua
    assertTrue(NS.Print == NS.Util.print)
    local D = T.newAddon{ skip = NO_LIBKA0S }
    assertTrue(D.Print == D.Util.print, "on the degraded path too")
end)

test("core: the printer tags every line with the cyan [DW] prefix", function()
    local NS, _, m = T.newAddon()
    NS.Print("hello")
    assertEqual(m.prints[#m.prints], "|cff00ffff[DW]|r hello")
end)

test("core: the close-button wrapper passes the addon folder as the third argument", function()
    local NS, _, m = T.newAddon()
    local Core = m.LibStub("LibKa0s-Core-1.0", true)
    local real, seen = Core.MakeCloseButton, nil
    Core.MakeCloseButton = function(parent, onClick, folder) seen = folder; return real(parent, onClick, folder) end
    NS.MakeCloseButton({}, function() end)
    Core.MakeCloseButton = real
    -- red under: drop `addonName` from the wrapper in core/CoreSetup.lua (anti-pattern #64)
    assertEqual(seen, "DropWatcher")
end)

test("core: no file but the wrapper calls a close-button factory directly", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
        local src = fh:read("*a"); fh:close()
        src = src:gsub("%-%-[^\r\n]*", "")   -- comments name the grep; only code is checked
        for pre in src:gmatch("([%w_%.:]*)MakeCloseButton%(") do
            local ok = pre == "NS." or (rel == "core/CoreSetup.lua" and pre == "lib.")
            assertTrue(ok, rel .. " calls " .. pre .. "MakeCloseButton(")
        end
    end
end)

-- ── Media and the console font ──────────────────────────────────────────────────────────────

test("media: FONT_MONO is the shipped face live, and a real client font degraded", function()
    local NS = T.newAddon()
    -- red under: move core\MediaSetup.lua below core\Constants.lua in the TOC
    assertEqual(NS.Constants.FONT_MONO, NS.MediaFont("JetBrains Mono"))
    assertTrue(NS.Constants.FONT_MONO:find("DropWatcher", 1, true) ~= nil, "built from the folder name")
    local D, _, m = T.newAddon{ skip = NO_LIBKA0S, mock = function(mk) mk.STANDARD_TEXT_FONT = "Fonts\\X.TTF" end }
    assertEqual(D.Constants.FONT_MONO, m.STANDARD_TEXT_FONT)
end)

-- ── Bus ─────────────────────────────────────────────────────────────────────────────────────

test("bus: the catalog holds the ten messages of the design, each Ka0s_DropWatcher_<Event>", function()
    local NS = T.newAddon()
    local n = 0
    for _, wire in pairs(NS.MSG) do
        n = n + 1
        assertTrue(wire:find("^Ka0s_DropWatcher_%u%a+$") ~= nil, wire)
    end
    assertEqual(n, 10)
    -- The strict copy: a mistyped constant raises at the call site, publisher or subscriber.
    T.assertError(function() return NS.MSG.DROP_ADDDED end, "a mistyped key raises")
end)

test("bus: a tracked target's registrations come down with the stand-down and back with the stand-up", function()
    local NS, _, m = T.enableAddon()
    local target = NS.Bus:NewTarget()
    local heard = 0
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() heard = heard + 1 end)
    NS.addon:SendMessage(NS.MSG.GEAR_CHANGED)
    assertEqual(heard, 1)
    NS.SchemaRuntime.Set("enabled", false)
    NS.addon:SendMessage(NS.MSG.GEAR_CHANGED)
    -- red under: drop `NS.Bus:StandDown()` from NS.StandDown
    assertEqual(heard, 1, "nothing heard while stood down")
    NS.SchemaRuntime.Set("enabled", true)
    -- The gear snapshot's own stand-up rebuild may announce first (modules/Gear.lua): count from here.
    local before = heard
    NS.addon:SendMessage(NS.MSG.GEAR_CHANGED)
    assertEqual(heard, before + 1, "replayed on the stand-up")
    assertTrue(m ~= nil)
end)

test("bus: the seam answers tracked once; without the library the modules take their receivers down", function()
    local NS = T.newAddon()
    assertTrue(NS.Bus.tracked == true, "the library path")
    local D, _, m = T.enableAddon({ skip = { "libs/LibKa0s/Bus.lua" } })
    assertTrue(D.Bus.tracked == false, "the degraded stub")
    local heard = 0
    local rec = { isMine = true }
    D.LootFeed.Get = function() return rec end
    D.TradeTimer.Schedule = function() heard = heard + 1 end
    D.addon:SendMessage(D.MSG.DROP_ADDED, 1)
    assertEqual(heard, 1, "the trade timer's bare receiver hears DropAdded")
    D.addon:OnSlashCommand("disable")
    D.addon:SendMessage(D.MSG.DROP_ADDED, 1)
    -- red under: a module that skips its manual unregister on the degraded path
    assertEqual(heard, 1, "unregistered by the module itself while stood down")
    D.addon:OnSlashCommand("enable")
    local before = heard
    D.addon:SendMessage(D.MSG.DROP_ADDED, 1)
    assertEqual(heard, before + 1, "registered again on the stand-up")
    assertTrue(m ~= nil)
end)

-- ── Perf ────────────────────────────────────────────────────────────────────────────────────

test("perf: every declared bucket is reached by a real bracket", function()
    local NS, _, m = T.enableAddon()
    local declared = {}
    for _, key in ipairs(NS.Perf.BUCKET_ORDER) do declared[key] = false end
    assertTrue(next(declared) ~= nil, "buckets are declared")
    local real = NS.Perf.Note
    NS.Perf.Note = function(key, ...) declared[key] = true; return real(key, ...) end
    NS.Perf.on = true
    NS.ShowWindow()          -- builds the window and runs its repaint pass (window.refresh)
    m.__fire("CHAT_MSG_LOOT", "You receive loot: |Hitem:1|h[x]|h.")    -- one line parsed (parse)
    -- one member's slots read on the fast path (inspect.read)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    NS.Inspect.Request("Player-1-0000000A")
    m.advance(0)
    -- one drop taken in (feed.add), judged for you (evaluate) and through the quality gate
    local ring = m.addItem("|cnIQ4:|Hitem:2001::::::::90:::::|h[Band]|h|r", { name = "Band", quality = 4,
        ilvl = 600, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, bindType = 1, stats = {} })
    NS.LootFeed.Add(ring)
    -- one scan of your own drops' bag items (tradeTimer.scan)
    NS.TradeTimer.Scan("test")
    NS.Perf.on, NS.Perf.Note = false, real
    for key, reached in pairs(declared) do
        assertTrue(reached, "bucket " .. key .. " declared but never reached")
    end
end)

test("perf: with capture off the bracket notes nothing", function()
    local NS = T.enableAddon()
    local notes = 0
    local real = NS.Perf.Note
    NS.Perf.Note = function(...) notes = notes + 1; return real(...) end
    NS.Perf.on = false
    NS.ShowWindow()
    NS.Window.Refresh()
    NS.Perf.Note = real
    assertEqual(notes, 0)
end)

test("perf: the `perf` hold stands the addon down, and the verbs keep answering", function()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertTrue(NS.IsStoodDown())
    assertFalse(NS.IsWindowShown(), "visibility refused at the source")
    m.prints = {}
    NS.addon:OnSlashCommand("lock")
    -- Stored `enabled` is still true, so a feature verb is not refused as disabled.
    assertTrue(#m.prints > 0 and not m.prints[1]:find("is disabled", 1, true), tostring(m.prints[1]))
    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertFalse(NS.IsStoodDown())
end)

test("perf: the descriptor's SavedVariables global is declared in the TOC", function()
    local NS = T.newAddon()
    assertEqual(NS.Perf.descriptor and NS.Perf.descriptor.sv or "DropWatcherPerfDB", "DropWatcherPerfDB")
end)

-- ── Launcher ────────────────────────────────────────────────────────────────────────────────

test("launcher: one object, labeled with the brand, the logo as its icon, registered on enable", function()
    local NS, _, m = T.enableAddon()
    local obj = m.ldbObjects.DropWatcher
    assertTrue(obj ~= nil, "named for the folder")
    assertEqual(obj.type, "launcher")
    assertEqual(obj.label, "Ka0s Drop Watcher")
    assertEqual(obj.icon, "Interface\\AddOns\\DropWatcher\\media\\logos\\dropwatcher.logo.128.tga")
    local btn = m.minimapButtons.DropWatcher
    assertTrue(btn ~= nil and btn.object == obj, "the same object, registered with LibDBIcon")
    assertTrue(btn.db == NS.addon.db.global.minimap, "LibDBIcon's table is the global store")
end)

-- The right-click menu, opened through a recording MenuUtil: the client's own context menu is the
-- library's (launcher-§2), and its entries are the descriptor's accessor-and-toggle pairs.
local function openMenu(m)
    local root = { boxes = {} }
    function root.CreateTitle(_, t) root.title = t end
    function root.CreateCheckbox(_, label, isChecked, onClick)
        local box = { label = label, checked = isChecked, click = onClick }
        root.boxes[#root.boxes + 1] = box
        return box
    end
    m.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    m.ldbObjects.DropWatcher.OnClick(m.UIParent, "RightButton")
    return root
end

test("launcher: the right-click menu is Enabled, Locked, Test mode, Show window, in that order", function()
    local _, _, m = T.enableAddon()
    local root = openMenu(m)
    assertEqual(root.title, "Ka0s Drop Watcher")
    local labels = {}
    for i, box in ipairs(root.boxes) do labels[i] = box.label end
    assertEqual(table.concat(labels, ","), "Enabled,Locked,Test mode,Show window")
end)

test("launcher: each menu entry calls the same handler its verb and its row call", function()
    local NS, _, m = T.enableAddon()
    local boxes = openMenu(m).boxes
    boxes[2].click()
    assertTrue(NS.SchemaRuntime.Get("locked") == true, "Locked writes `locked` through the seam")
    boxes[3].click()
    assertTrue(NS.State.testMode, "Test mode turns test mode on")
    boxes[3].click()
    assertFalse(NS.State.testMode)
    boxes[4].click()
    assertTrue(NS.IsWindowShown(), "Show window opens the window")
    boxes[1].click()
    assertTrue(NS.IsStoodDown(), "Enabled off stands the addon down")
    assertFalse(NS.addon.db.profile.enabled, "through the stored path")
end)

-- ── Options ─────────────────────────────────────────────────────────────────────────────────

-- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the kit's
-- mock does not model; the in-game check is PROFILE-1 in docs/smoke-tests.md.
test("options: the category registers eagerly, with the General page under it", function()
    local NS, _, m = T.enableAddon()
    assertTrue(NS.addon._settingsRegistered == true)
    assertTrue(m.__mainPanel ~= nil, "the parent category")
    assertTrue(m.__subcategories.General ~= nil, "General")
end)

test("options: the General page's first group is exactly `Master controls`", function()
    local NS = T.newAddon()
    local first = NS.addon.Settings.Schema[1]
    assertEqual(first.group, "Master controls")
    assertEqual(first.path, "enabled")
    for _, row in ipairs(NS.addon.Settings.Schema) do
        assertTrue(type(row.group) == "string" and row.group ~= "", "every row carries a group: " .. tostring(row.path))
    end
end)

test("options: the degraded load completes, and the panel says once that it is unavailable", function()
    local D, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find("settings panel is unavailable", 1, true) then n = n + 1 end
    end
    assertEqual(n, 1)
    D.addon:OnSlashCommand("config")
    local S = D.SchemaRuntime
    assertTrue(S.FindRow("enabled") == nil and S.FindRow("visibility") == nil and S.FindRow("state.testMode") == nil,
        "the composers are hollow ({}), never a host copy")
    assertTrue(S.FindRow("feed.quality.mode") ~= nil, "the hand-written rows stand without the library")
end)
