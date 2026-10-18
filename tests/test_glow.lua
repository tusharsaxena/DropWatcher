-- tests/test_glow.lua — the upgrade glow on a drop's icon (feedback-21): which glow a drop wears
-- (pure), Apply's decision on the button with and without LibCustomGlow-1.0, each style's call as
-- the knob table maps it, the repaint that changes nothing costing nothing, then the three surfaces
-- painted headless (the full table's row, the compact card, the detail card's header), the toast's
-- icon never glowing, a pooled row reused or left unused losing its glow, and a glow row's write
-- re-applying it.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RING = "|cffa335ee|Hitem:213::|h[Band of Embers]|h|r"
local HOLY, PROT = 65, 66

local NONE = {}

local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function offSpec(verdict)
    return { verdict = "cantUse", reasons = { { key = "primaryStat" } },
        offSpec = { specID = HOLY, mainSpecID = PROT, verdict = verdict or "upgrade", ilvlDelta = 20 } }
end

-- A sidegrade on a ring: no glow.
local function side(id) return drop({ id = id, link = RING, me = { verdict = "sidegrade", ilvlDelta = 2, reasons = {} } }) end

-- A LibCustomGlow-1.0 stand-in on the instance's LibStub: every call recorded as { name, args... }.
local function fakeLib(m)
    local lib = m.LibStub:NewLibrary("LibCustomGlow-1.0", 24)
    lib.calls = {}
    for _, name in ipairs({ "ButtonGlow", "ProcGlow", "PixelGlow", "AutoCastGlow" }) do
        for _, edge in ipairs({ "_Start", "_Stop" }) do
            lib[name .. edge] = function(...) lib.calls[#lib.calls + 1] = { name .. edge, ... } end
        end
    end
    return lib
end

local function names(lib)
    local out = {}
    for i, c in ipairs(lib.calls) do out[i] = c[1] end
    return table.concat(out, ",")
end

local function button(m, size)
    return m.CreateFrame("Button"):__setGeom(size or 20, size or 20)
end

-- ── which glow ──────────────────────────────────────────────────────────────────────────────

test("glow: KindOf is main for your upgrade, offSpec for an off-spec upgrade, nothing else glows", function()
    local K = T.newAddon().Glow.KindOf
    assertEqual(K(drop()), "main")
    assertEqual(K(drop({ me = offSpec() })), "offSpec")
    assertNil(K(drop({ me = offSpec("sidegrade") })), "an off-spec sidegrade")
    assertNil(K(drop({ me = offSpec("downgrade") })))
    for _, v in ipairs({ "sidegrade", "downgrade", "cantUse", "doesntWant", "unknown" }) do
        assertNil(K(drop({ me = { verdict = v } })), v)
    end
    assertNil(K(drop({ isMine = true })), "never your own drop")
    assertNil(K(drop({ isMine = true, me = offSpec() })))
    assertNil(K(drop({ me = NONE })))
    assertNil(K(nil))
end)

-- ── Apply on a button ───────────────────────────────────────────────────────────────────────

test("glow: without the library Apply still records its decision; a glow turned off clears it", function()
    local NS, _, m = T.enableAddon()
    local G, b = NS.Glow, button(m)
    assertEqual(G.Apply(b, drop()), "main"); assertEqual(b.glowKind, "main")
    assertEqual(G.Apply(b, drop({ me = offSpec() })), "offSpec"); assertEqual(b.glowKind, "offSpec")
    assertNil(G.Apply(b, side(2))); assertNil(b.glowKind, "a sidegrade clears it")
    assertTrue(NS.SchemaRuntime.Set("glow.offSpec.enabled", false))
    assertNil(G.Apply(b, drop({ me = offSpec() })), "the off-spec glow is off")
    assertEqual(G.Apply(b, drop()), "main", "the main glow is its own")
    assertTrue(NS.SchemaRuntime.Set("glow.main.enabled", false))
    assertNil(G.Apply(b, drop())); assertNil(b.glowKind)
    G.Stop(b); G.Stop(nil); assertNil(G.Apply(nil, drop()))
end)

test("glow: each style starts with the knob table's arguments, under the addon's key", function()
    local NS, _, m = T.enableAddon()
    local G, lib, S = NS.Glow, fakeLib(m), NS.SchemaRuntime.Set
    local b = button(m)
    -- main: proc, the upgrade green, opaque (defaults/Profile.lua)
    G.Apply(b, drop())
    local c = lib.calls[1]
    assertEqual(c[1], "ProcGlow_Start"); assertTrue(c[2] == b)
    local tone = NS.Constants.TONE.good
    assertEqual(c[3].color[1], tone.r); assertEqual(c[3].color[3], tone.b); assertEqual(c[3].color[4], 1)
    assertEqual(c[3].duration, 1); assertEqual(c[3].startAnim, true); assertEqual(c[3].key, G.KEY)
    assertEqual(c[3].frameLevel, G.FRAME_LEVEL); assertEqual(c[3].xOffset, 0)
    -- off-spec: pixel, length 0 is automatic (nil), the border a boolean (nil would draw it)
    lib.calls = {}
    G.Apply(b, drop({ me = offSpec() }))
    assertEqual(names(lib), "ProcGlow_Stop,PixelGlow_Start", "the old style stops first")
    c = lib.calls[2]
    assertEqual(c[4], 8); assertEqual(c[5], 0.25); assertNil(c[6]); assertEqual(c[7], 1)
    assertEqual(c[10], true); assertEqual(c[11], G.KEY); assertEqual(c[12], G.FRAME_LEVEL)
    assertTrue(S("glow.offSpec.pixelLength", 6)); assertTrue(S("glow.offSpec.pixelBorder", false))
    lib.calls = {}
    G.Apply(b, drop({ me = offSpec() }))
    c = lib.calls[2]
    assertEqual(c[6], 6); assertEqual(c[10], false)
    assertTrue(S("glow.main.type", "button")); assertTrue(S("glow.main.buttonFrequency", 0.5))
    lib.calls = {}
    G.Apply(b, drop())
    assertEqual(names(lib), "PixelGlow_Stop,ButtonGlow_Start")
    assertEqual(lib.calls[2][4], 0.5); assertEqual(lib.calls[2][5], G.FRAME_LEVEL)
    assertTrue(S("glow.main.type", "autocast")); assertTrue(S("glow.main.autocastParticles", 6))
    assertTrue(S("glow.main.xOffset", -3))
    lib.calls = {}
    G.Apply(b, drop())
    assertEqual(names(lib), "ButtonGlow_Stop,AutoCastGlow_Start")
    c = lib.calls[2]
    assertEqual(c[4], 6); assertEqual(c[5], 0.125); assertEqual(c[6], 1); assertEqual(c[7], -3)
    assertEqual(c[9], G.KEY); assertEqual(c[10], G.FRAME_LEVEL)
    lib.calls = {}
    G.Apply(b, side(2))
    assertEqual(names(lib), "AutoCastGlow_Stop"); assertNil(b.glowStyle)
end)

test("glow: a repaint that changes nothing calls the library not at all; a setting or a size restarts it", function()
    local NS, _, m = T.enableAddon()
    local G, lib = NS.Glow, fakeLib(m)
    local b = button(m)
    G.Apply(b, drop())
    for _ = 1, 5 do G.Apply(b, drop({ id = 9 })) end
    assertEqual(names(lib), "ProcGlow_Start", "the same kind on the same button: once")
    G.Apply(b, side(2)); G.Apply(b, side(3))
    assertEqual(names(lib), "ProcGlow_Start,ProcGlow_Stop", "nothing to stop twice")
    G.Apply(b, drop())
    lib.calls = {}
    assertTrue(NS.SchemaRuntime.Set("glow.main.procDuration", 2))
    G.Apply(b, drop())
    assertEqual(names(lib), "ProcGlow_Stop,ProcGlow_Start", "a glow row's write restarts it")
    assertEqual(lib.calls[2][3].duration, 2)
    lib.calls = {}
    b:__setGeom(32, 32)
    G.Apply(b, drop())
    assertEqual(names(lib), "ProcGlow_Stop,ProcGlow_Start", "a new size restarts it")
end)

-- options-ui-§17: Use class color takes the PLAYER'S class (the mock's Mage), whoever looted the
-- drop (a Priest here), keeps the swatch's alpha, and falls through to the swatch when the class
-- has no color.
test("glow: Use class color draws in the player's class color with the swatch's alpha, and restarts it", function()
    local NS, _, m = T.enableAddon()
    local G, lib, S = NS.Glow, fakeLib(m), NS.SchemaRuntime.Set
    local b = button(m)
    assertTrue(S("glow.main.color", { r = 1, g = 0, b = 0, a = 0.5 }))
    G.Apply(b, drop())
    local c = lib.calls[1][3].color
    assertTrue(c[1] == 1 and c[2] == 0 and c[3] == 0 and c[4] == 0.5, "off: the swatch")
    lib.calls = {}
    assertTrue(S("glow.main.useClassColor", true))
    G.Apply(b, drop())
    assertEqual(names(lib), "ProcGlow_Stop,ProcGlow_Start", "turning it on restarts the glow")
    c = lib.calls[2][3].color
    local mage = m.RAID_CLASS_COLORS.MAGE
    assertTrue(c[1] == mage.r and c[2] == mage.g and c[3] == mage.b, "the player's Mage blue, not the looter's")
    assertEqual(c[4], 0.5, "the swatch's alpha survives the mode")
    lib.calls = {}
    G.Apply(b, drop({ me = offSpec() }))
    c = lib.calls[2]
    assertEqual(c[3][1], NS.Constants.TONE.offspec.r, "the off-spec glow's own companion is still off")
    lib.calls = {}
    assertTrue(S("glow.main.useClassColor", false))
    G.Apply(b, drop())
    c = lib.calls[2][3].color
    assertTrue(c[1] == 1 and c[2] == 0 and c[3] == 0, "off again: the swatch")
end)

test("glow: Use class color with a class that has no color falls through to the swatch", function()
    local NS, _, m = T.enableAddon()
    local G, lib, S = NS.Glow, fakeLib(m), NS.SchemaRuntime.Set
    m.__context.classToken = "NOPE"
    assertTrue(S("glow.offSpec.useClassColor", true))
    G.Apply(button(m), drop({ me = offSpec() }))
    local c, tone = lib.calls[1], NS.Constants.TONE.offspec
    assertEqual(c[1], "PixelGlow_Start")
    assertTrue(c[3][1] == tone.r and c[3][2] == tone.g and c[3][3] == tone.b and c[3][4] == 1,
        "the stored off-spec cyan, never white or a substitute")
end)

-- The library's proc frame replays its opening burst from its own OnShow, and a repaint hides and
-- shows every pooled row and card: once the button has been on screen the burst is spent.
test("glow: the proc style's opening burst plays once, not again on every repaint's re-show", function()
    local NS, _, m = T.enableAddon()
    local G, lib = NS.Glow, fakeLib(m)
    lib.ProcGlow_Start = function(r, o) r["_ProcGlow" .. o.key] = { startAnim = o.startAnim } end
    local b = button(m)
    G.Apply(b, drop())
    local f = b["_ProcGlow" .. G.KEY]
    assertEqual(f.startAnim, false, "started on screen: the burst has played")
    local hidden = button(m); hidden:Hide()
    G.Apply(hidden, drop())
    local hf = hidden["_ProcGlow" .. G.KEY]
    assertEqual(hf.startAnim, true, "started off screen: the burst waits for its first show")
    hidden:Show(); G.Apply(hidden, drop())
    assertEqual(hf.startAnim, false, "the repaint after that first show spends it")
    assertTrue(NS.SchemaRuntime.Set("glow.main.procDuration", 2))
    G.Apply(b, drop())
    assertEqual(b["_ProcGlow" .. G.KEY].startAnim, false, "a restart plays it once more, then spends it")
end)

-- ── the three surfaces, and the toast that never glows ──────────────────────────────────────

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1, 2, 3 } }

local function seed(NS, drops)
    local byId, ids = {}, {}
    for i, d in ipairs(drops) do byId[d.id], ids[i] = d, d.id end
    local g = {}
    for k, v in pairs(GROUP) do g[k] = v end
    g.drops = ids
    NS.LootFeed.Groups = function() return { g } end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
end

local function shown(drops, compact)
    local NS, _, m = T.enableAddon()
    m.__now = 100
    seed(NS, drops)
    NS.WindowFilterBar.Set("group", "view", "all")
    if compact then NS.SetWindowMode("compact") end
    NS.ShowWindow()
    return NS, m
end

local function rowFor(NS, id)
    for _, r in ipairs(NS.WindowGroup.Drawn().rows) do if r.dropId == id then return r end end
end

local THREE = function() return { drop(), drop({ id = 2, link = RING, me = offSpec() }), side(3) } end

test("glow: the full table's Drops row icon wears its drop's glow; the detail card's header too", function()
    local NS = shown(THREE())
    assertEqual(rowFor(NS, 1).cells.item.button.glowKind, "main")
    assertEqual(rowFor(NS, 2).cells.item.button.glowKind, "offSpec")
    assertNil(rowFor(NS, 3).cells.item.button.glowKind)
    NS.WindowGroup.ToggleExpand(2)
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(drawn.cardDropId, 2); assertEqual(drawn.card.icon.glowKind, "offSpec")
    NS.WindowGroup.ToggleExpand(3)
    assertNil(NS.WindowGroup.Drawn().card.icon.glowKind, "the card repainted for a sidegrade")
end)

test("glow: a pooled row reused for a sidegrade, or left unused, loses its glow", function()
    local NS = shown(THREE())
    local pool = NS.WindowGroup.Drawn().pane.rowPool
    local drops = { side(1), side(2) }
    seed(NS, drops)
    NS.Window.Refresh()
    for _, r in ipairs(pool.active) do assertNil(r.cells.item.button.glowKind, "row " .. tostring(r.dropId)) end
    assertEqual(#pool.free, 1)
    assertNil(pool.free[1].cells.item.button.glowKind, "the row left in the pool")
    seed(NS, THREE())
    NS.Window.Refresh()
    assertEqual(rowFor(NS, 1).cells.item.button.glowKind, "main", "back on a reused row")
end)

test("glow: the compact card's icon wears it; the table's rows stop theirs in the compact layout", function()
    local NS = shown(THREE())
    local pool = NS.WindowGroup.Drawn().pane.rowPool
    NS.SetWindowMode("compact")
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == true)
    local by = {}
    for _, c in ipairs(drawn.rows) do by[c.dropId] = c end
    assertEqual(by[1].icon.glowKind, "main"); assertEqual(by[2].icon.glowKind, "offSpec"); assertNil(by[3].icon.glowKind)
    for _, r in ipairs(pool.free) do assertNil(r.cells.item.button.glowKind) end
    seed(NS, { side(1) })
    NS.Window.Refresh()
    for _, c in ipairs(drawn.pane.compactView.cardPool.free) do assertNil(c.icon.glowKind, "an unused card") end
end)

test("glow: the toast's icon never glows, for a main-spec or an off-spec upgrade (feedback-21 G9)", function()
    local NS, _, m = T.enableAddon()
    local lib = fakeLib(m)
    local byId = { [1] = drop(), [2] = drop({ id = 2, link = RING, me = offSpec() }) }
    NS.LootFeed.Get = function(id) return byId[id] end
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    local f = NS.Toast.Frame()
    assertEqual(NS.Toast.Stats().dropId, 1)
    assertNil(f.icon.glowKind, "a main-spec upgrade's toast")
    assertTrue(NS.SchemaRuntime.Set("glow.main.type", "pixel"))
    assertNil(f.icon.glowKind, "a glow row's write leaves the toast alone")
    NS.Toast.Dismiss()
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 2)
    assertEqual(NS.Toast.Stats().dropId, 2)
    assertNil(f.icon.glowKind, "an off-spec upgrade's toast")
    for _, c in ipairs(lib.calls) do assertTrue(c[2] ~= f.icon, "no library call on the toast's icon: " .. c[1]) end
end)

test("glow: a glow row's write re-applies every drawn icon at once", function()
    local NS, m = shown(THREE())
    local lib = fakeLib(m)
    assertTrue(NS.SchemaRuntime.Set("glow.main.type", "pixel"))
    local b = rowFor(NS, 1).cells.item.button
    assertEqual(b.glowStyle, "pixel")
    local started = 0
    for _, c in ipairs(lib.calls) do if c[1] == "PixelGlow_Start" and c[2] == b then started = started + 1 end end
    assertEqual(started, 1)
    assertTrue(NS.SchemaRuntime.Set("glow.offSpec.enabled", false))
    assertNil(rowFor(NS, 2).cells.item.button.glowKind)
end)

test("glow: a profile switch re-reads the glow settings", function()
    local NS, m = shown(THREE())
    local lib = fakeLib(m)
    NS.addon.db.profile.glow.main.type = "button"   -- written behind the seam, as a profile copy is
    NS.addon:OnProfileCopied(nil, nil, "Other")
    assertEqual(rowFor(NS, 1).cells.item.button.glowStyle, "button")
    assertTrue(#lib.calls > 0)
end)
