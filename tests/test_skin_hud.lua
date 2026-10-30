-- tests/test_skin_hud.lua — the HUD through the skin (DW-03, skinning-§6): Drop Watcher's HUD is the
-- item icon's border (Window › Icons) and the upgrade glow. The border's style and thickness follow
-- the skin's icon border family (`icon.borderStyle`, `icon.borderSize`) while the composer's
-- `fromSkin = "icon"` companion is on, TRUE by default (the rollout's X3); only style and thickness
-- follow (X4), so the color and its class and quality companions stay the player's, and so do the
-- glow's two colors (E6). Under Ka0s Default the border is today's Solid 2px black. A skin switch
-- restyles every item button; "None" draws no edge; without the library the stored picks draw. The
-- one-time reset (O2) is migration step 10: it turns the companion on in every stored profile once,
-- keeps the stored pick, and a player's later "off" survives the next load.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local OWNER = "DropWatcher"
local EPIC = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local NO_LIBKA0S = T.loadAddon.libFiles

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function fakeButton()
    local art = {}
    function art:SetTexCoord(...) self.tc = { ... } end
    return { art = art, GetFrameLevel = function() return 5 end }
end

-- Every BackdropTemplate frame made from here on, recording what it is told to draw.
local function borderFrames(m)
    local made, create = {}, m.CreateFrame
    m.CreateFrame = function(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        if template == "BackdropTemplate" then
            made[#made + 1] = f
            f.SetBackdrop = function(s, bd) s.drawn = bd end
            f.SetBackdropBorderColor = function(s, ...) s.edge = { ... } end
            f.Show = function(s) s.on = true end
            f.Hide = function(s) s.on = false end
        end
        return f
    end
    return made
end

-- A test-only skin: Ka0s Default with the icon border family set to `style` at `size`.
local function toSkin(m, key, style, size)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    if not Skin:GetSkin(key) then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
        tokens["icon.borderStyle"], tokens["icon.borderSize"] = style, size
        Skin:RegisterSkin({ key = key, label = key, tokens = tokens })
    end
    Skin:SetChoice(OWNER, "ka0s", key)
end

-- ── the drawing ─────────────────────────────────────────────────────────────────────────────

test("skin HUD: the icon border's companion is on by default, and Ka0s Default draws today's Solid 2px black", function()
    local NS, _, m = T.enableAddon()
    assertEqual(NS.C.PROFILE.icons.borderStyleFromSkin, true, "X3: a new profile follows the skin")
    assertEqual(NS.Setting("icons.borderStyleFromSkin"), true)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    assertEqual(Skin:Token(OWNER, "icon.borderStyle"), "Solid", "Ka0s Default's icon family is DW's look")
    assertEqual(Skin:Token(OWNER, "icon.borderSize"), 2)
    local frames, b = borderFrames(m), fakeButton()
    NS.IconStyle.Apply(b, EPIC)
    assertEqual(frames[1].drawn.edgeFile, NS.IconStyle.SOLID_EDGE, "the flat edge")
    assertEqual(frames[1].drawn.edgeSize, 2)
    assertTrue(near(b.iconBorder[1], 0) and near(b.iconBorder[2], 0) and near(b.iconBorder[3], 0)
        and near(b.iconBorder[4], 1), "black, opaque: the player's swatch")
end)

test("skin HUD: while the companion is on the stored style and thickness are not read; off, they are", function()
    local NS, _, m = T.enableAddon()
    local S, frames = NS.SchemaRuntime.Set, borderFrames(m)
    local LSM = m.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    LSM.Fetch = function(_, kind, name) return kind == "border" and name == "Blizzard Tooltip" and "tex\\tooltip" or nil end
    NS.IconStyle.Apply(fakeButton(), EPIC)
    assertTrue(S("icons.borderStyle", "Blizzard Tooltip")); assertTrue(S("icons.borderSize", 6))
    -- red under: IconStyle reading the stored style while the companion is on
    assertEqual(frames[1].drawn.edgeFile, NS.IconStyle.SOLID_EDGE, "the skin's Solid, not the stored pick")
    assertEqual(frames[1].drawn.edgeSize, 2, "the skin's thickness")
    assertTrue(S("icons.borderStyleFromSkin", false))
    assertEqual(frames[1].drawn.edgeFile, "tex\\tooltip", "the player's pick, kept underneath")
    assertEqual(frames[1].drawn.edgeSize, 6)
    assertEqual(NS.addon.db.profile.icons.borderStyle, "Blizzard Tooltip", "the companion never wrote the pick")
end)

test("skin HUD: a skin switch restyles every item button; its None draws no edge; the color stays the player's", function()
    local NS, _, m = T.enableAddon()
    local frames = borderFrames(m)
    local b = fakeButton()
    NS.IconStyle.Apply(b, EPIC)
    assertTrue(NS.SchemaRuntime.Set("icons.borderColor", { r = 1, g = 0, b = 0, a = 0.5 }))
    toSkin(m, "dw-hud-thick", "Solid", 4)
    assertEqual(frames[1].drawn.edgeSize, 4, "repainted on the switch, no write needed")
    assertTrue(near(b.iconBorder[1], 1) and near(b.iconBorder[4], 0.5), "X4: the swatch is never the skin's")
    toSkin(m, "dw-hud-none", "None", 1)
    assertNil(b.iconBorder, "the skin's None: no edge")
    assertTrue(frames[1].on == false, "the border frame hidden")
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "ka0s")
    assertTrue(frames[1].on == true and frames[1].drawn.edgeSize == 2, "back on Ka0s Default")
end)

test("skin HUD: the glow's two colors are the player's under every skin (E6)", function()
    local NS, _, m = T.enableAddon()
    local main = NS.Setting("glow.main.color")
    local off = NS.Setting("glow.offSpec.color")
    toSkin(m, "dw-hud-thick", "Solid", 4)
    assertTrue(NS.Setting("glow.main.color") == main and NS.Setting("glow.offSpec.color") == off,
        "no skin switch touches the stored swatches")
    assertNil(NS.SchemaRuntime.FindRow("glow.main.colorFromSkin"), "and no companion follows a glow color")
end)

test("skin HUD: the companion is a composed row with a check, dimmed with Show border off, dimming style and size", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    local row = S.FindRow("icons.borderStyleFromSkin")
    assertTrue(row ~= nil, "the composer's fromSkin companion")
    assertEqual(row.type, "bool"); assertEqual(row.default, true, "its default is defaults/Profile.lua's (X3)")
    assertEqual(row.page, "window"); assertEqual(row.subgroup, "Border")
    assertTrue(type(row.validate) == "function" and type(row.onChange) == "function")
    assertFalse(S.Set("icons.borderStyleFromSkin", "yes"))
    assertTrue(S.FindRow("icons.borderStyle").disabledIf(), "the style row is the skin's while it is on")
    assertTrue(S.FindRow("icons.borderSize").disabledIf(), "the thickness row too")
    assertFalse(row.disabledIf())
    assertTrue(S.Set("icons.borderStyleFromSkin", false))
    assertFalse(S.FindRow("icons.borderStyle").disabledIf()); assertFalse(S.FindRow("icons.borderSize").disabledIf())
    assertTrue(S.Set("icons.borderShow", false))
    assertTrue(row.disabledIf(), "nothing to follow with no border")
    assertNil(S.FindRow("icons.borderColor").disabledIf, "anti-pattern #74: the swatch is never dimmed")
    NS.addon:OnSlashCommand("set icons.borderStyleFromSkin true")
    assertEqual(NS.addon.db.profile.icons.borderStyleFromSkin, true, "the CLI writes it through the same seam")
end)

test("skin HUD: without LibKa0s the stored picks draw and the companion's default changes nothing", function()
    local D, _, m = T.bootAddon{ skip = NO_LIBKA0S }
    local frames = borderFrames(m)
    D.IconStyle.Apply(fakeButton(), EPIC)
    assertEqual(frames[1].drawn.edgeFile, D.IconStyle.SOLID_EDGE)
    assertEqual(frames[1].drawn.edgeSize, 2)
    D.addon.db.profile.icons.borderSize = 5   -- no rows without the composer: behind the seam
    D.IconStyle.Refresh()
    assertEqual(frames[1].drawn.edgeSize, 5, "the degraded facade answers no string token: the stored pick")
end)

-- ── the one-time reset (O2): migration step 10 ──────────────────────────────────────────────

test("migrate 10: every stored profile's icon border goes back on the skin once, its pick kept", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 9 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { icons = { borderStyle = "Blizzard Tooltip", borderSize = 3,
                                  borderColor = { r = 1, g = 0, b = 0, a = 1 }, borderShow = false } },
            Alt = { feed = { content = "session" } },
            Off = { icons = { borderStyleFromSkin = false } },
        },
    }
    -- red under: no step 10 (the stored profiles keep their own style)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 10)
    assertEqual(p.Default.icons.borderStyleFromSkin, true, "the companion on")
    assertEqual(p.Default.icons.borderStyle, "Blizzard Tooltip", "the pick kept, never the sentinel")
    assertEqual(p.Default.icons.borderSize, 3, "the thickness is not listed")
    assertEqual(p.Default.icons.borderColor.r, 1, "X4: the color stays the player's")
    assertEqual(p.Default.icons.borderShow, false, "a bool the player set is never switched on")
    assertNil(p.Alt.icons, "a profile that stored no icons keeps the defaults, no table made")
    assertEqual(p.Off.icons.borderStyleFromSkin, true, "a stored off before the reset is reset too (O2)")
end)

test("migrate 10: it runs once; a player's later pick survives the next load", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 9 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = { Default = { icons = { borderStyle = "Blizzard Tooltip" } } },
    }
    NS.addon:OnInitialize()
    assertEqual(NS.addon.db.profile.icons.borderStyleFromSkin, true)
    assertTrue(NS.SchemaRuntime.Set("icons.borderStyleFromSkin", false), "the player turns it off")
    local ran = 0
    local real = NS.ResetIconBorderToSkin
    NS.ResetIconBorderToSkin = function(...) ran = ran + 1; return real(...) end
    NS.addon:RunMigrations()   -- the next load: the stamp is at the target
    NS.ResetIconBorderToSkin = real
    assertEqual(ran, 0, "the step never runs again")
    assertEqual(NS.addon.db.profile.icons.borderStyleFromSkin, false, "the player's off is kept")
    assertEqual(NS.addon.db.profile.icons.borderStyle, "Blizzard Tooltip")
end)

test("migrate 10: idempotent on a raw table, the companion set so no sentinel lands; without the library too", function()
    local NS = T.newAddon()
    local raw = { icons = { borderStyle = "Solid" } }
    NS.ResetIconBorderToSkin(raw); NS.ResetIconBorderToSkin(raw)
    assertEqual(raw.icons.borderStyleFromSkin, true)
    assertEqual(raw.icons.borderStyle, "Solid", "never the FROM_SKIN sentinel in an LSM key")
    -- The case the companion matters for: nothing stored, the companion absent (AceDB strips a
    -- value equal to its default). red under: a reset that names the pick without companions.
    local empty = { icons = {} }
    NS.ResetIconBorderToSkin(empty)
    assertEqual(empty.icons.borderStyleFromSkin, true, "the absent companion is set")
    assertNil(empty.icons.borderStyle, "the pick is left alone, never the sentinel")
    NS.ResetIconBorderToSkin(nil); NS.ResetIconBorderToSkin({}); NS.ResetIconBorderToSkin(3)
    local D = T.newAddon{ skip = NO_LIBKA0S }
    local bare = { icons = {} }
    D.ResetIconBorderToSkin(bare)
    assertEqual(bare.icons.borderStyleFromSkin, true, "set directly, as ResetToSkin would")
    assertEqual(#NS.HUD_SKIN_KEYS, 1); assertEqual(NS.HUD_SKIN_KEYS[1], "borderStyle", "X4: the style alone")
end)

test("migrate 10: the library sets the companion itself (ResetToSkin's companions, LibKa0s v1.81.0)", function()
    -- R-6 / LK-07: Skin minor 8's `{ companions = true }` sets every listed pick's companion,
    -- stored or not, so the step hands the raw table over unseeded.
    -- red under: the retired seeding of `borderStyleFromSkin = false` before a plain reset.
    local NS, _, m = T.newAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local real, seen = Skin.ResetToSkin, {}
    Skin.ResetToSkin = function(profile, keys, opts)
        seen.companion = profile.borderStyleFromSkin
        seen.opts = opts
        return real(profile, keys, opts)
    end
    local ok, err = pcall(NS.ResetIconBorderToSkin, { icons = {} })
    Skin.ResetToSkin = real
    assertTrue(ok, tostring(err))
    assertNil(seen.companion, "handed over unseeded")
    assertTrue(type(seen.opts) == "table" and seen.opts.companions == true, "companions = true")
end)
