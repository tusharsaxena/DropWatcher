-- tests/test_window_compact.lua — compact mode's switch (compact spec §1, DW-C0): the two layouts
-- over one frame, each layout's own size and point, the migration from the retired preset, the
-- title-bar toggle, the Layout row, and the run override (`window.compactInRuns`).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function shown()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    return NS, NS.Window.Frame(), m
end

local function pointOf(f) return table.concat({ f:GetPoint(1) }, ",", 1, 1) .. "," ..
    table.concat({ select(3, f:GetPoint(1)) }, ",") end

local function bounds(f) return table.concat({ f:GetResizeBounds() }, ",", 1, 2) .. "," ..
    table.concat({ select(3, f:GetResizeBounds()) }, ",") end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

test("compact: the layout in force is the stored one, compact while a run holds it, full for junk", function()
    local WC = T.newAddon().WindowCompact
    assertEqual(WC.Effective("full", false), "full")
    assertEqual(WC.Effective("compact", false), "compact")
    assertEqual(WC.Effective("full", true), "compact", "the run override wins")
    assertEqual(WC.Effective(nil, false), "full"); assertEqual(WC.Effective("tiny", nil), "full")
    assertTrue(WC.ValidMode("compact")); assertFalse(WC.ValidMode("Compact")); assertFalse(WC.ValidMode(nil))
    assertEqual(table.concat(WC.MODES, ","), "full,compact")
end)

test("compact: a run is a dungeon, raid, key or delve, and nothing else", function()
    local WC = T.newAddon().WindowCompact
    for _, key in ipairs({ "mythicPlus", "dungeon", "followerDungeon", "raidLFR", "raid", "delve" }) do
        assertTrue(WC.IsRun(key), key)
    end
    for _, key in ipairs({ "scenario", "pvp", "openWorldGroup", "solo" }) do assertFalse(WC.IsRun(key), key) end
    assertFalse(WC.IsRun(nil))
end)

test("compact: each layout's default size and bounds; a stored size is kept within them", function()
    local WC = T.newAddon().WindowCompact
    assertEqual(table.concat({ WC.DefaultSize("full") }, "x"), "1038x600")
    assertEqual(table.concat({ WC.DefaultSize("compact") }, "x"), "440x460")
    assertEqual(table.concat({ WC.Bounds("compact") }, ","), "440,220,520,900")
    local minW, minH, maxW, maxH = WC.Bounds("full")
    assertEqual(minW .. "," .. minH, "1038,260"); assertTrue(maxW == nil and maxH == nil, "the screen")
    assertEqual(table.concat({ WC.ClampSize("full", 600, 700) }, "x"), "1038x700", "a stored width under the least is raised")
    assertEqual(table.concat({ WC.ClampSize("compact", 320, 460) }, "x"), "440x460", "compact's least is its default")
    assertEqual(table.concat({ WC.ClampSize("compact", 900, 100) }, "x"), "520x220")
    assertEqual(table.concat({ WC.ClampSize("compact", "wide", nil) }, "x"), "440x460", "junk reads as the default")
    assertEqual(table.concat({ WC.ClampSize("full", 2400, 700) }, "x"), "2400x700", "full: no maximum")
end)

test("compact: CornerPoint puts compact's top right on the full window's, whatever its anchor", function()
    local WC = T.newAddon().WindowCompact
    assertEqual(table.concat(WC.CornerPoint({ "CENTER", "CENTER", 0, 0 }, 1000, 600), ","), "TOPRIGHT,CENTER,500,300")
    assertEqual(table.concat(WC.CornerPoint({ "TOPLEFT", "BOTTOMLEFT", 300, 700 }, 640, 400), ","),
        "TOPRIGHT,BOTTOMLEFT,940,700")
    assertEqual(table.concat(WC.CornerPoint({ "BOTTOMRIGHT", "BOTTOMRIGHT", -10, 20 }, 800, 500), ","),
        "TOPRIGHT,BOTTOMRIGHT,-10,520")
end)

-- ── the migration (schema step 5) ───────────────────────────────────────────────────────────

test("compact: step 5 maps the retired preset to the compact layout and moves the geometry", function()
    local NS = T.newAddon()
    local p = { window = { compact = true, point = { "TOPLEFT", "BOTTOMLEFT", 10, 20 }, width = 700, height = 500,
        minimized = true, rowHeight = 22 } }
    -- red under: no step 5 (the preset and the flat geometry stay)
    NS.MigrateWindowMode(p)
    local w = p.window
    assertEqual(w.mode, "compact"); assertEqual(w.compact, nil)
    assertTrue(w.point == nil and w.width == nil and w.height == nil, "the flat keys go")
    assertEqual(table.concat(w.geometry.full.point, ","), "TOPLEFT,BOTTOMLEFT,10,20")
    assertEqual(w.geometry.full.width .. "x" .. w.geometry.full.height, "700x500")
    assertTrue(w.minimized == true and w.rowHeight == 22, "the rest is untouched")
    NS.MigrateWindowMode(p)
    assertEqual(w.geometry.full.width, 700, "idempotent")
    local off = { window = { compact = false, mode = "full" } }
    NS.MigrateWindowMode(off)
    assertEqual(off.window.mode, "full"); assertEqual(off.window.compact, nil); assertEqual(off.window.geometry, nil)
    NS.MigrateWindowMode({}); NS.MigrateWindowMode(nil)
end)

test("compact: step 5 runs for every stored profile on load", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 4 },
        profiles = {
            Default = { window = { compact = true } },
            Main = { window = { compact = true, mode = "full" } },
            Raid = { window = { width = 640, height = 400 } },
        },
    }
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(p.Default.window.mode, "compact"); assertEqual(p.Default.window.compact, nil)
    assertEqual(p.Main.window.mode, "compact", "the preset wins over a mode read through the defaults")
    assertEqual(p.Raid.window.geometry.full.width, 640)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 5, "later steps run after it")
end)

-- ── the switch ──────────────────────────────────────────────────────────────────────────────

test("compact: a fresh profile stores the full layout, and opens in a run compact by default", function()
    local NS = T.enableAddon()
    assertEqual(NS.Setting("window.mode"), "full")
    assertTrue(NS.Setting("window.compactInRuns"))
    assertEqual(NS.WindowCompact.Mode(), "full")
end)

test("compact: the title-bar toggle sits left of minimize, with a catalog mark", function()
    local _, f = shown()
    local b = f.modeButton
    assertTrue(b ~= nil)
    local pt = b.__points[1]
    assertEqual(pt[1], "RIGHT"); assertEqual(pt[2], f.minimizeButton); assertEqual(pt[3], "LEFT")
    assertTrue(f.scanButton == nil, "Scan group is the Drops strip's, in both layouts")
    assertEqual(f.badge.__points[1][2], b, "the badge anchors to the toggle")
    assertEqual(b.mark, "fullscreen-exit", "full: the shrink mark")
    assertTrue(b.art:IsShown() and not b.glyph:IsShown(), "the catalog mark, not the glyph")
end)

test("compact: the toggle swaps the layout: compact is 440 x 460 at the full window's top right", function()
    local NS, f = shown()
    assertEqual(f:GetWidth() .. "x" .. f:GetHeight(), "1038x600")
    f.modeButton:__fire("OnClick")
    assertEqual(NS.addon.db.profile.window.mode, "compact", "stored through the seam")
    assertEqual(f:GetWidth() .. "x" .. f:GetHeight(), "440x460")
    assertEqual(pointOf(f), "TOPRIGHT,CENTER,519,300")
    assertEqual(bounds(f), "440,220,520,900")
    assertEqual(f.modeButton.mark, "fullscreen-enter")
    assertTrue(f:IsShown(), "one frame: the same window, laid out again")
    f.modeButton:__fire("OnClick")
    assertEqual(NS.Setting("window.mode"), "full")
    assertEqual(f:GetWidth() .. "x" .. f:GetHeight(), "1038x600")
    assertEqual(pointOf(f), "CENTER,CENTER,0,0")
    local minW = f:GetResizeBounds()
    assertEqual(minW, 1038, "the full layout's least width is its default")
end)

test("compact: each layout remembers its own size and position", function()
    local NS, f = shown()
    NS.SetWindowMode("compact")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 40, 900)
    f.titleBar:GetScript("OnDragStop")(f.titleBar)
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f:SetSize(480, 700)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    local g = NS.addon.db.profile.window.geometry
    assertEqual(table.concat(g.compact.point, ","), "TOPLEFT,BOTTOMLEFT,40,900")
    assertEqual(g.compact.width .. "x" .. g.compact.height, "480x700")
    assertTrue(g.full == nil, "the full layout's geometry is untouched")
    NS.SetWindowMode("full")
    assertEqual(pointOf(f), "CENTER,CENTER,0,0"); assertEqual(f:GetWidth(), 1038)
    NS.SetWindowMode("compact")
    assertEqual(pointOf(f), "TOPLEFT,BOTTOMLEFT,40,900"); assertEqual(f:GetWidth() .. "x" .. f:GetHeight(), "480x700")
    NS.Window.ResetPosition()
    assertEqual(NS.addon.db.profile.window.geometry, nil, "Reset position forgets both")
    assertEqual(f:GetWidth() .. "x" .. f:GetHeight(), "440x460")
end)

test("compact: switching keeps the tab, the minimized state, and builds no second window", function()
    local NS, f = shown()
    NS.Window.SelectTab("history")
    local real, built = _G.CreateFrame, 0
    rawset(_G, "CreateFrame", function(...) built = built + 1; return real(...) end)
    NS.ToggleWindowMode()
    rawset(_G, "CreateFrame", real)
    assertEqual(NS.Window.ActiveTab(), "history")
    assertTrue(NS.Window.Frame() == f)
    assertEqual(built, 0, "no frame built for the switch")
    NS.Window.SetMinimized(true)
    NS.ToggleWindowMode()
    assertTrue(NS.Window.IsMinimized()); assertEqual(f:GetHeight(), 32)
    NS.Window.SetMinimized(false)
    assertEqual(f:GetHeight(), 600)
end)

test("compact: the Layout row lays the window out, and the stored layout is the next build's", function()
    local NS, f = shown()
    assertTrue(NS.SchemaRuntime.Set("window.mode", "compact"))
    assertEqual(f:GetWidth(), 440, "the row's reaction lays the open window out")
    local row = NS.SchemaRuntime.FindRow("window.mode")
    assertEqual(row.page, "window"); assertEqual(row.group, "Layout")
    assertEqual(row.values[1].value .. "," .. row.values[2].value, "full,compact")
    local again = T.enableAddon()
    again.addon.db.profile.window.mode = "compact"
    again.ShowWindow()
    assertEqual(again.Window.Frame():GetWidth(), 440, "built compact")
    assertEqual(table.concat({ again.Window.Frame():GetResizeBounds() }, ","), "440,220,520,900")
end)

test("compact: the toggle's tooltip names the layout it switches to and the setting", function()
    local NS, f = shown()
    local tip = NS.Window.TooltipOf(f.modeButton)
    assertEqual(tip[1], "Compact view")
    assertTrue(T.tipPlainJoined(tip):find("• Stored as: Window settings, Layout", 1, true) ~= nil)
    NS.ToggleWindowMode()
    tip = NS.Window.TooltipOf(f.modeButton)
    assertEqual(tip[1], "Full view")
end)

-- ── the run override ────────────────────────────────────────────────────────────────────────

local function drop(id)
    return { id = id, at = 100, link = "|cffa335ee|Hitem:1::|h[Crown of Roaring Storms]|h|r",
        looter = { name = "Seta-Realm" }, me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely" }, facts = { ilvl = 311 } }
end

local function announce(NS, rec)
    NS.LootFeed.Get = function() return rec end
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, rec.id)
end

-- An enabled addon in a Heroic dungeon, in a group: an auto-open situation and a run.
local function inDungeon()
    local NS, _, m = T.enableAddon()
    m.__context.inInstance, m.__context.instanceType, m.__context.inGroup = true, "party", true
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    assertEqual(NS.Situations.Current(), "dungeon")
    return NS, m
end

-- The player closes the window. The mock's Hide clears the flag without running OnHide; the client
-- runs it, and the override's visibility listener hears it there.
local function close(NS)
    NS.HideWindow()
    local f = NS.Window.Frame()
    f:GetScript("OnHide")(f)
end

local function leave(NS, m)
    m.__context.inInstance, m.__context.instanceType = false, "none"
    m.instance.difficultyID = 0
    m.__fire("ZONE_CHANGED_NEW_AREA")
    assertTrue(NS.Situations.Current() ~= "dungeon")
end

test("compact: an auto-open inside a run opens compact, and the stored layout is untouched", function()
    local NS = inDungeon()
    announce(NS, drop(1))
    assertTrue(NS.IsWindowShown())
    assertEqual(NS.WindowCompact.Mode(), "compact"); assertTrue(NS.WindowCompact.InRun())
    assertEqual(NS.Window.Frame():GetWidth(), 440)
    assertEqual(NS.Setting("window.mode"), "full", "the stored layout is unchanged")
    assertTrue(table.concat(NS.Window.TooltipOf(NS.Window.Frame().modeButton), " "):find("until this run ends", 1, true) ~= nil)
end)

test("compact: the run ending lets go when the window is next hidden, so the next open is full", function()
    local NS, m = inDungeon()
    announce(NS, drop(1))
    leave(NS, m)
    local f = NS.Window.Frame()
    assertEqual(f:GetWidth(), 440, "shown: the layout does not jump under the player")
    close(NS)
    assertFalse(NS.WindowCompact.InRun())
    NS.ShowWindow()
    assertEqual(NS.WindowCompact.Mode(), "full"); assertEqual(f:GetWidth(), 1038)
end)

test("compact: a run ending while the window is hidden lets go at once", function()
    local NS, m = inDungeon()
    announce(NS, drop(1))
    close(NS)
    assertTrue(NS.WindowCompact.InRun(), "closed mid-run: still the run's")
    announce(NS, drop(2))
    assertEqual(NS.Window.Frame():GetWidth(), 440, "the next auto-open in the run is compact too")
    close(NS)
    leave(NS, m)
    assertFalse(NS.WindowCompact.InRun())
    NS.ShowWindow()
    assertEqual(NS.Window.Frame():GetWidth(), 1038)
end)

test("compact: a parent's hide (Alt-Z) is not the window closing, so the run's layout stays", function()
    local NS, m = inDungeon()
    announce(NS, drop(1))
    leave(NS, m)
    local f = NS.Window.Frame()
    f:GetScript("OnHide")(f)   -- the parent hid: the frame's own flag is still set
    assertTrue(NS.WindowCompact.InRun())
end)

test("compact: with Open in compact view during a run off, an auto-open keeps the stored layout", function()
    local NS = inDungeon()
    NS.SchemaRuntime.Set("window.compactInRuns", false)
    announce(NS, drop(1))
    assertTrue(NS.IsWindowShown())
    assertEqual(NS.WindowCompact.Mode(), "full"); assertFalse(NS.WindowCompact.InRun())
end)

test("compact: the player's own toggle during a run lets the override go", function()
    local NS = inDungeon()
    announce(NS, drop(1))
    local f = NS.Window.Frame()
    f.modeButton:__fire("OnClick")
    assertFalse(NS.WindowCompact.InRun())
    assertEqual(NS.WindowCompact.Mode(), "full"); assertEqual(f:GetWidth(), 1038)
end)

-- An enabled addon in a running Mythic+ key: difficulty 8, the key active.
local function inKey()
    local NS, _, m = T.enableAddon()
    m.__context.inInstance, m.__context.instanceType, m.__context.inGroup = true, "party", true
    m.instance.difficultyID, m.challengeModeActive = 8, true
    m.__fire("CHALLENGE_MODE_START")
    assertEqual(NS.Situations.Current(), "mythicPlus")
    return NS, m
end

-- The key completes; the client still reports difficulty 8, so the situation stays mythicPlus.
local function complete(NS, m)
    m.challengeModeActive = false
    m.__fire("CHALLENGE_MODE_COMPLETED")
    assertEqual(NS.Situations.Current(), "mythicPlus", "a completed key still reads as mythicPlus")
end

-- The completed key's chest grace runs out.
local function graceOut(NS, m) m.advance(NS.LootFeed.LOOT_GRACE + 1) end

test("compact: the chest after a key completes still belongs to the run, so its auto-open is compact", function()
    local NS, m = inKey()
    complete(NS, m)
    announce(NS, drop(1))   -- the chest: the window's first open in this key
    assertTrue(NS.IsWindowShown())
    assertTrue(NS.WindowCompact.InRun()); assertEqual(NS.Window.Frame():GetWidth(), 440)
end)

test("compact: a key's grace running out with the window shown lets go when it is next hidden, and nothing re-arms it", function()
    local NS, m = inKey()
    announce(NS, drop(1))
    local f = NS.Window.Frame()
    complete(NS, m)
    graceOut(NS, m)
    assertTrue(NS.WindowCompact.InRun(), "shown: the layout does not jump under the player")
    assertEqual(f:GetWidth(), 440)
    close(NS)
    assertFalse(NS.WindowCompact.InRun())
    announce(NS, drop(2))   -- a late drop, same instance, still mythicPlus
    assertTrue(NS.IsWindowShown())
    assertFalse(NS.WindowCompact.InRun(), "a completed key never re-arms the override")
    assertEqual(f:GetWidth(), 1038)
end)

test("compact: a key's grace running out with the window hidden lets go at once", function()
    local NS, m = inKey()
    announce(NS, drop(1))
    close(NS)
    complete(NS, m)
    assertTrue(NS.WindowCompact.InRun(), "within the grace: still the run's")
    graceOut(NS, m)
    assertFalse(NS.WindowCompact.InRun())
    NS.ShowWindow()
    assertEqual(NS.Window.Frame():GetWidth(), 1038)
end)

test("compact: the completion latch clears on leaving, so the next run opens compact again", function()
    local NS, m = inKey()
    announce(NS, drop(1))
    close(NS)
    complete(NS, m)
    graceOut(NS, m)
    assertEqual(NS.State.compactRunSpent, "mythicPlus")
    leave(NS, m)
    assertEqual(NS.State.compactRunSpent, nil)
    m.challengeModeActive = true
    m.instance.difficultyID = 8
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.__fire("CHALLENGE_MODE_START")
    announce(NS, drop(2))
    assertTrue(NS.WindowCompact.InRun()); assertEqual(NS.Window.Frame():GetWidth(), 440)
end)

test("compact: a window the player opened is never switched by a drop", function()
    local NS = inDungeon()
    NS.ShowWindow()
    announce(NS, drop(1))
    assertFalse(NS.WindowCompact.InRun(), "no auto-open, no override")
    assertEqual(NS.Window.Frame():GetWidth(), 1038)
end)

test("compact: the diagnostics report names the layout, the override and each layout's geometry", function()
    local NS = inDungeon()
    announce(NS, drop(1))
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("layout=compact stored=full run=dungeon compactInRuns=true", 1, true) ~= nil, text)
    assertTrue(text:find("window: compact point", 1, true) ~= nil, text)
    assertTrue(text:find("window: full size=default", 1, true) ~= nil, text)
end)
