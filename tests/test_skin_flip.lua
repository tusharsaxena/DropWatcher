-- tests/test_skin_flip.lua — the HUD follows the skin (FS-DW-FLIP, causes D4, D5 and D6 of
-- Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING). What this addon owes (LibKa0s Options doc,
-- "Moving to this version"): a "Use the skin's ..." companion, default on, for the icon border's color,
-- the two glow colors and the tables' shadow, each behind its class or quality color and in front of
-- the stored value; Ka0s Default keeps this addon's pixels through its owner tokens; and one
-- per-profile step moves existing profiles onto the skin, naming companions and the From skin flags
-- only, so every stored pick and color survives for a player who turns a companion off.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local OWNER = "DropWatcher"
local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local COMPANIONS = {
    "window.tableFontFromSkin", "window.tableFontShadowFromSkin", "icons.borderStyleFromSkin",
    "icons.borderColorFromSkin", "glow.main.colorFromSkin", "glow.offSpec.colorFromSkin",
}

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local out = {}
    for k, x in pairs(v) do out[#out + 1] = tostring(k) .. "=" .. dump(x) end
    table.sort(out)
    return "{" .. table.concat(out, ";") .. "}"
end

local function leaf(p, path)
    local node = p
    for seg in path:gmatch("[^.]+") do
        if type(node) ~= "table" then return nil end
        node = node[seg]
    end
    return node
end

local function fakeButton()
    local art = {}
    function art:SetTexCoord(...) self.tc = { ... } end
    return { art = art, GetFrameLevel = function() return 5 end }
end

local function glowDrop()
    return { id = 1, isMine = false, trade = { state = "yes" }, me = { verdict = "upgrade" } }
end

-- ── the rows and the defaults ────────────────────────────────────────────────────────────────

test("skin flip: every companion is a bool row, on by default in both places", function()
    local NS = T.bootAddon()
    for _, path in ipairs(COMPANIONS) do
        local row = NS.SchemaRuntime.FindRow(path)
        assertTrue(row ~= nil, "no row " .. path)
        assertEqual(row.type, "bool", path)
        assertEqual(row.default, true, path .. " defaults on on the row")
        assertEqual(leaf(NS.C.PROFILE, path), true, path .. " defaults on in AceDB")
    end
    for _, path in ipairs({ "window.tableFontShadowFromSkin", "icons.borderColorFromSkin",
        "glow.main.colorFromSkin", "glow.offSpec.colorFromSkin" }) do
        local row = NS.SchemaRuntime.FindRow(path)
        assertTrue(row.tooltip:find("not read while this is on", 1, true) ~= nil,
            path .. "'s tooltip says the row it governs is not read")
    end
    assertTrue(NS.SchemaRuntime.FindRow("icons.borderColorFromSkin").label == "Use the skin's color")
    assertTrue(NS.SchemaRuntime.FindRow("window.tableFontShadowFromSkin").label == "Use the skin's shadow")
end)

test("skin flip: no swatch carries disabledIf, and a class color has no companion", function()
    local NS = T.bootAddon()
    local S = NS.SchemaRuntime
    for _, path in ipairs({ "icons.borderColor", "glow.main.color", "glow.offSpec.color", "window.tableFontShadow" }) do
        assertNil(S.FindRow(path).disabledIf, path)
    end
    for _, path in ipairs({ "icons.useClassColorBorderFromSkin", "glow.main.useClassColorFromSkin",
        "icons.borderQualityFromSkin", "window.tableFontClassColorFromSkin" }) do
        assertNil(S.FindRow(path), path)
    end
end)

test("skin flip: the font pick's default moved to the Ka0s pick, in both places", function()
    local NS = T.bootAddon()
    assertEqual(NS.C.PROFILE.window.tableFont, "Ka0s Prototype")
    assertEqual(NS.SchemaRuntime.FindRow("window.tableFont").default, "Ka0s Prototype")
    assertEqual(NS.C.PROFILE.window.tableFontFlags, "@skin")
    assertEqual(NS.SchemaRuntime.FindRow("window.tableFontFlags").default, "@skin")
end)

test("skin flip: the panel's exception is not touched", function()
    local NS = T.bootAddon()
    assertEqual(NS.C.PROFILE.skin.ignorePanel, true)
    assertEqual(NS.C.PROFILE.skin.ignoreFonts, false)
end)

-- ── the step ─────────────────────────────────────────────────────────────────────────────────

test("skin flip: a stored partial profile moves, and nothing but companions and flags is written", function()
    local NS = T.newAddon()
    local p = {
        window = { tableFont = "Morpheus", tableFontFlags = "THICKOUTLINE", tableFontColor = { r = 0.1 },
            tableFontShadow = false, tableFontClassColor = true, tableFontFromSkin = false },
        icons = { borderColor = { r = 1 }, borderStyle = "Blizzard Tooltip", useClassColorBorder = true,
            borderQuality = true, borderStyleFromSkin = false },
        glow = { main = { color = { g = 0.5 }, useClassColor = true }, offSpec = {} },
        skin = { ignorePanel = false, ignoreFonts = true },
    }
    local before = dump(p)
    assertTrue(NS.ResetProfileToSkin(p) == true, "the first run moves it")
    for _, path in ipairs(COMPANIONS) do assertEqual(leaf(p, path), true, path) end
    assertEqual(p.skin.fullSkinReset, true, "recorded on the profile")
    assertEqual(p.window.tableFontFlags, "@skin", "the one key that takes the sentinel")
    -- Take off what the step owed: the rest is the profile it was handed.
    for _, path in ipairs(COMPANIONS) do
        local parent, key = path:match("^(.*)%.([^.]+)$")
        leaf(p, parent)[key] = nil
    end
    p.window.tableFontFromSkin, p.icons.borderStyleFromSkin = false, false
    p.window.tableFontFlags, p.skin.fullSkinReset = "THICKOUTLINE", nil
    assertEqual(dump(p), before, "every stored pick, color and class toggle is byte-identical")
end)

test("skin flip: a sub-table the profile never stored is skipped, and the record still lands", function()
    local NS = T.newAddon()
    local p = { icons = {} }
    assertTrue(NS.ResetProfileToSkin(p))
    assertNil(p.window); assertNil(p.glow)
    assertEqual(p.icons.borderColorFromSkin, true)
    assertEqual(p.skin.fullSkinReset, true)
    assertFalse(NS.ResetProfileToSkin(nil)); assertFalse(NS.ResetProfileToSkin(3))
end)

test("skin flip: a second run writes nothing, so a companion turned off stays off", function()
    local NS = T.newAddon()
    local p = { icons = {}, window = {} }
    NS.ResetProfileToSkin(p)
    p.icons.borderColorFromSkin = false
    local before = dump(p)
    assertFalse(NS.ResetProfileToSkin(p), "the record answers")
    assertEqual(dump(p), before)
end)

test("skin flip: without the library the same write, with the record written by hand", function()
    local D = T.newAddon{ skip = T.loadAddon.libFiles }
    local p = { window = { tableFontFlags = "OUTLINE", tableFontColor = { r = 1 } }, icons = {} }
    assertTrue(D.ResetProfileToSkin(p))
    assertEqual(p.window.tableFontShadowFromSkin, true)
    assertEqual(p.window.tableFontFlags, "@skin")
    assertEqual(p.icons.borderColorFromSkin, true)
    assertNil(p.glow, "a path through a missing table is skipped")
    assertEqual(p.skin.fullSkinReset, true)
    p.icons.borderColorFromSkin = false
    assertFalse(D.ResetProfileToSkin(p))
    assertEqual(p.icons.borderColorFromSkin, false)
end)

test("skin flip: the ladder moves every stored profile once, and a later off survives the next load", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 10 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { icons = { borderColorFromSkin = false, borderColor = { r = 1, g = 0, b = 0, a = 1 } } },
            Alt = { glow = { main = { colorFromSkin = false } } },
        },
    }
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(p.Default.icons.borderColorFromSkin, true)
    assertEqual(p.Default.icons.borderColor.r, 1, "the stored color stays")
    assertEqual(p.Alt.glow.main.colorFromSkin, true)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 11)
    p.Default.icons.borderColorFromSkin = false
    NS.addon:RunMigrations()
    assertEqual(p.Default.icons.borderColorFromSkin, false, "the record keeps a later off")
end)

test("skin flip: a profile that arrives after the stamp moved still takes the step", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 11 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = { Default = { icons = { borderColorFromSkin = false } } },
    }
    NS.addon:OnInitialize()
    assertEqual(_G.DropWatcherDB.profiles.Default.icons.borderColorFromSkin, true)
    assertEqual(_G.DropWatcherDB.profiles.Default.skin.fullSkinReset, true)
end)

test("skin flip: the record has no row, so no Defaults path walks it, and a companion stays off", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    assertNil(S.FindRow("skin.fullSkinReset"), "no row: nothing draws it, nothing resets it")
    assertEqual(NS.C.PROFILE.skin.fullSkinReset, false, "the AceDB default")
    assertEqual(NS.addon.db.profile.skin.fullSkinReset, true, "the step ran on the active profile")
    assertTrue(S.Set("icons.borderColorFromSkin", false))
    for _, row in ipairs(NS.addon.Settings.Schema) do
        if type(row) == "table" and row.path and row.path ~= "icons.borderColorFromSkin" and not row.sessionOnly
            and type(row.set) ~= "function" then
            S.Set(row.path, row.default)
        end
    end
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(NS.addon.db.profile.skin.fullSkinReset, true, "every Defaults path leaves the record")
    S.Set("icons.borderColorFromSkin", false)
    NS.addon:RunMigrations()
    assertEqual(NS.addon.db.profile.icons.borderColorFromSkin, false)
end)

test("skin flip: a profile reset runs the step against defaults, which show nothing a player sees", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    db.profile.icons.borderColorFromSkin = false
    db:ResetProfile()
    assertEqual(db.profile.icons.borderColorFromSkin, true)
    assertEqual(db.profile.skin.fullSkinReset, true, "the reset profile holds the record again")
end)

-- ── what the surfaces draw ───────────────────────────────────────────────────────────────────

local function setSkin(m, key) m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", key) end

--- Item buttons' borders: every BackdropTemplate frame records what it is told to draw.
local function borderFrames(m)
    local made, create = {}, m.CreateFrame
    m.CreateFrame = function(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        if template == "BackdropTemplate" then
            made[#made + 1] = f
            f.SetBackdrop = function() end
            f.SetBackdropBorderColor = function(s, ...) s.edge = { ... } end
        end
        return f
    end
    return made
end

--- A test-only skin: every shipped skin answers one `icon.border`, `glow.color` and `sem.warband`
--- (SkinDefs), so a switch among them moves nothing these cases could see.
local function tintedSkin(m)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    if not Skin:GetSkin("dw-flip") then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
        tokens["icon.border"] = { 0.2, 0.3, 0.4, 1 }
        tokens["glow.color"] = { 0.9, 0.1, 0.8, 1 }
        tokens["sem.warband"] = { 0.1, 0.9, 0.2, 1 }
        Skin:RegisterSkin({ key = "dw-flip", label = "dw-flip", tokens = tokens })
    end
    return "dw-flip"
end

test("skin flip: a skin switch redraws the icon border's color; class and quality stay ahead", function()
    local NS, _, m = T.enableAddon()
    local frames, b = borderFrames(m), fakeButton()
    NS.IconStyle.Apply(b, LINK)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    m.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
    m.addItem(LINK, { name = "Crown of Roaring Storms", quality = 4, ilvl = 311 })
    b.link = LINK
    local e = frames[1].edge
    assertTrue(near(e[1], 0) and near(e[2], 0) and near(e[3], 0) and e[4] == 1, "Ka0s Default's black")
    setSkin(m, tintedSkin(m))
    local want = Skin:Token(OWNER, "icon.border")
    e = frames[1].edge
    assertTrue(want[1] == 0.2, "the case's skin has an edge of its own")
    assertTrue(near(e[1], want[1]) and near(e[2], want[2]) and near(e[3], want[3]), "the setter took the token")
    local S = NS.SchemaRuntime.Set
    assertTrue(S("icons.borderColor", { r = 1, g = 0, b = 0, a = 1 }))
    assertTrue(S("icons.borderColorFromSkin", false))
    e = frames[1].edge
    assertTrue(e[1] == 1 and e[2] == 0, "companion off: the stored color under every skin")
    assertTrue(S("icons.borderColorFromSkin", true))
    assertTrue(S("icons.useClassColorBorder", true))
    local mage = m.RAID_CLASS_COLORS.MAGE
    e = frames[1].edge
    assertTrue(e[1] == mage.r and e[2] == mage.g, "a class color comes first")
    assertTrue(S("icons.useClassColorBorder", false))
    assertTrue(S("icons.borderQuality", true))
    e = frames[1].edge
    local qr, qg = NS.IconStyle.QualityColor(LINK)
    assertTrue(near(e[1], qr) and near(e[2], qg), "the quality color comes first")
    assertTrue(S("icons.borderColor", { r = 1, g = 0, b = 0, a = 0.5 }))
    assertEqual(frames[1].edge[4], 0.5, "a quality color draws the swatch's alpha, not the skin's")
    assertTrue(S("icons.borderQuality", false))
    assertEqual(frames[1].edge[4], 1, "the skin's own edge draws the skin's alpha")
    setSkin(m, "ka0s")
end)

test("skin flip: Ka0s Default keeps the glows' own colors; a skin switch restarts them in the skin's", function()
    local NS, _, m = T.enableAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local calls = {}
    NS.GlowLib = { Start = function(_, _, cfg) calls[#calls + 1] = cfg.color; return true end, Stop = function() end }
    local button = m.CreateFrame("Button")
    local tone = NS.Constants.TONE.glowMain
    NS.Glow.Apply(button, glowDrop())
    assertTrue(near(calls[1][1], tone.r) and near(calls[1][2], tone.g) and near(calls[1][3], tone.b),
        "Ka0s Default: the main glow's own green")
    setSkin(m, tintedSkin(m))
    NS.Glow.Apply(button, glowDrop())
    local want = Skin:Token(OWNER, "glow.color")
    assertEqual(#calls, 2, "the skin moved the generation on")
    assertTrue(near(calls[2][1], want[1]) and near(calls[2][2], want[2]) and near(calls[2][3], want[3]),
        "the skin's glow.color")
    local off = { id = 2, isMine = false, trade = { state = "yes" }, me = { verdict = "downgrade",
        offSpec = { verdict = "upgrade" } } }
    NS.OffSpec.Of = function(me) return me.offSpec end
    NS.Glow.Apply(button, off)
    local warband = Skin:Token(OWNER, "sem.warband")
    assertTrue(near(calls[3][1], warband[1]) and near(calls[3][2], warband[2]), "the off-spec glow's own")
    setSkin(m, "ka0s")
end)

test("skin flip: the two glows stay apart in every skin, and class and off stay as they were", function()
    local NS, _, m = T.enableAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    for _, def in ipairs(Skin:Skins()) do
        setSkin(m, def.key)
        assertTrue(dump(Skin:Token(OWNER, "dw.glowMain")) ~= dump(Skin:Token(OWNER, "dw.glowOffSpec")),
            def.key .. ": main spec and off-spec are told apart by hue")
    end
    setSkin(m, tintedSkin(m))
    local calls = {}
    NS.GlowLib = { Start = function(_, _, cfg) calls[#calls + 1] = cfg.color; return true end, Stop = function() end }
    local S, button = NS.SchemaRuntime.Set, m.CreateFrame("Button")
    assertTrue(S("glow.main.color", { r = 1, g = 0, b = 0, a = 0.5 }))
    assertTrue(S("glow.main.colorFromSkin", false))
    NS.Glow.Apply(button, glowDrop())
    assertTrue(calls[1][1] == 1 and calls[1][4] == 0.5, "companion off: the stored swatch")
    assertTrue(S("glow.main.colorFromSkin", true))
    assertTrue(S("glow.main.useClassColor", true))
    NS.Glow.Apply(button, glowDrop())
    local mage = m.RAID_CLASS_COLORS.MAGE
    assertTrue(calls[2][1] == mage.r and calls[2][2] == mage.g, "a class color comes first")
    setSkin(m, "ka0s")
end)

test("skin flip: without the library the stored glow color draws", function()
    local NS, _, m = T.bootAddon{ skip = T.loadAddon.libFiles }
    local calls = {}
    NS.GlowLib = { Start = function(_, _, cfg) calls[#calls + 1] = cfg.color; return true end, Stop = function() end }
    NS.db.profile.glow.main.color = { r = 1, g = 0, b = 0, a = 1 }
    NS.Glow.Refresh()
    NS.Glow.Apply(m.CreateFrame("Button"), glowDrop())
    assertEqual(calls[1][1], 1); assertEqual(calls[1][2], 0)
end)

test("skin flip: without the library S.HudFont writes both shadow arms, so turning the row off clears it", function()
    local NS = T.bootAddon{ skip = T.loadAddon.libFiles }
    local fs = {}
    function fs:SetFont(face) self.face = face end
    function fs:SetShadowOffset(x, y) self.offset = { x, y } end
    function fs:SetShadowColor(_, _, _, a) self.alpha = a end
    NS.Skin.HudFont(fs, { face = "Fonts\\A.ttf", size = 12, shadow = true })
    assertEqual(fs.face, "Fonts\\A.ttf", "the one member that must draw")
    assertEqual(fs.offset[1], 1); assertEqual(fs.offset[2], -1)
    assertEqual(fs.alpha, 1, "on: an opaque shadow")
    NS.Skin.HudFont(fs, { face = "Fonts\\A.ttf", size = 12, shadow = false })
    assertEqual(fs.offset[1], 0); assertEqual(fs.offset[2], 0)
    assertEqual(fs.alpha, 0, "off: a clear one")
end)

-- The table's shadow: S.HudFont is the drawing path, so a case reads the font object it set.
local function fakeCreateFont(m)
    local made = {}
    m.CreateFont = function(name)
        local obj = { name = name }
        function obj:SetFont(p, s, f) self.font = { p, s, f or "" } end
        function obj:GetFont() return self.font[1], self.font[2], self.font[3] end
        function obj:SetShadowOffset(x, y) self.offset = { x, y } end
        function obj:SetShadowColor(r, g, b, a) self.shadow = { r, g, b, a } end
        made[#made + 1] = obj
        return obj
    end
    return made
end

local function tableString(m)
    local f = m.CreateFrame("Frame")
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs.SetFontObject = function(self, obj) self.__fontObject = obj; self.__font = { obj:GetFont() } end
    fs.SetFont = function(self, p, s, fl) self.__font = { p, s, fl or "" } end
    fs.GetFont = function(self) return self.__font[1], self.__font[2], self.__font[3] end
    fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    return fs
end

test("skin flip: Ka0s Default keeps the tables' black shadow; a skin switch redraws it", function()
    local NS, _, m = T.enableAddon()
    local WR = NS.WindowRows
    fakeCreateFont(m)
    local fs = tableString(m)
    WR.SetTableFont(fs, nil, WR.ReadFont())
    local obj = fs.__fontObject
    assertTrue(obj ~= nil and obj.offset[1] == 1 and obj.offset[2] == -1, "1, -1 as the tables drew")
    assertTrue(obj.shadow[1] == 0 and obj.shadow[2] == 0 and obj.shadow[3] == 0 and obj.shadow[4] == 1, "in black")
    setSkin(m, "contrast")
    WR.OnLooksChanged()
    WR.SetTableFont(fs, nil, WR.ReadFont())
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local x, y, r, g, b, a = Skin:For(OWNER).HudShadow("dw.tableShadow")
    obj = fs.__fontObject
    assertEqual(obj.offset[1], x, "the skin's offset"); assertEqual(obj.offset[2], y)
    assertTrue(near(obj.shadow[1], r) and near(obj.shadow[2], g) and near(obj.shadow[3], b) and near(obj.shadow[4], a),
        "the skin's shadow color")
    setSkin(m, "ka0s")
end)

test("skin flip: the row signature signs the resolved shadow, so a skin's new shadow reaches a drawn row", function()
    -- Options doc, Moving to, 5: a cache in front of S.HudFont signs what it draws.
    local NS, _, m = T.enableAddon()
    local WR = NS.WindowRows
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local tokens = {}
    for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
    tokens["hud.shadow"], tokens["hud.shadowX"], tokens["hud.shadowY"] = { 0, 0, 0, 1 }, 3, -3
    Skin:RegisterSkin({ key = "dwshadowa", label = "a", tokens = tokens })
    local onto = {}
    for name, v in pairs(tokens) do onto[name] = v end
    onto["hud.shadowX"], onto["hud.shadowY"] = 5, -5
    Skin:RegisterSkin({ key = "dwshadowb", label = "b", tokens = onto })
    setSkin(m, "dwshadowa")
    local key = WR.ReadFont().key
    setSkin(m, "dwshadowb")
    assertTrue(WR.ReadFont().key ~= key, "two skins differing only in the shadow sign differently")
    setSkin(m, "ka0s")
end)

test("skin flip: companion off draws the stored shadow; Ignore fonts leaves it standing", function()
    local NS, _, m = T.enableAddon()
    local WR, S = NS.WindowRows, NS.SchemaRuntime.Set
    fakeCreateFont(m)
    local fs = tableString(m)
    setSkin(m, "contrast")
    assertTrue(S("window.tableFontShadowFromSkin", false))
    assertTrue(S("window.tableFontShadow", false))
    WR.SetTableFont(fs, nil, WR.ReadFont())
    assertEqual(fs.__fontObject.offset[1], 0, "off under every skin")
    assertEqual(fs.__fontObject.shadow[4], 0)
    assertTrue(S("window.tableFontShadowFromSkin", true))
    m.LibStub("LibKa0s-Skin-1.0"):SetIgnore(OWNER, true, true)
    WR.SetTableFont(fs, nil, WR.ReadFont())
    assertEqual(fs.__fontObject.offset[1], 0, "Ignore fonts: the stored shadow stands")
    m.LibStub("LibKa0s-Skin-1.0"):SetIgnore(OWNER, true, false)
    setSkin(m, "ka0s")
end)

test("skin flip: with the library absent S.BarBorder answers the stored three and S.HoverArt draws nothing", function()
    local NS = T.newAddon({ skip = T.loadAddon.libFiles })
    local style, show, size = NS.Skin.BarBorder("Blizzard Tooltip", true, 3, true)
    assertEqual(style, "Blizzard Tooltip"); assertEqual(show, true); assertEqual(size, 3)
    assertNil(NS.Skin.HoverArt({}))
end)
