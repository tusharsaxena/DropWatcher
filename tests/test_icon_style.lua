-- tests/test_icon_style.lua — every item icon's look (feedback-21 G11, Window › Icons): the
-- defaults (feedback-21 H6: zoom 0.1, a Solid black border 2 pixels thick, the Solid name registered
-- with LibSharedMedia and drawn without it) and zoom 0 with no border drawing the icons as before
-- G11, the zoom's crop, the composed
-- border (the swatch, its Use class color companion with the player's class and the swatch's
-- alpha, the item quality color in its place), the repaint that changes nothing costing nothing, a
-- row's write and a profile switch restyling every button made so far, and the surfaces painted
-- headless (the Drops row and its Me icons, the detail card's header, the compact card, the toast).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local EPIC = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RARE = "|cff0070dd|Hitem:213::|h[Band of Embers]|h|r"
local PLAIN = "|Hitem:214::|h[Uncolored Thing]|h"

local QUALITY_COLORS = { [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }

-- An item button as NS.IconStyle sees it: `art`, its texture, counting the crops it is given.
local function fakeButton()
    local art = { crops = 0 }
    function art:SetTexCoord(...) self.crops = self.crops + 1; self.tc = { ... } end
    -- An item button's level, which the border frame is set relative to (frame-layering-§3).
    return { art = art, GetFrameLevel = function() return 5 end }
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function sameColor(c, r, g, b, a)
    return type(c) == "table" and near(c[1], r) and near(c[2], g) and near(c[3], b) and (a == nil or near(c[4], a))
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

-- ── one button ──────────────────────────────────────────────────────────────────────────────

test("icon style: by default an item icon is cropped 0.1 a side in a Solid black border 2 pixels thick", function()
    local NS, _, m = T.enableAddon()
    local IS, frames = NS.IconStyle, borderFrames(m)
    local b = fakeButton()
    IS.Apply(b, EPIC)
    assertTrue(near(b.art.tc[1], 0.1) and near(b.art.tc[2], 0.9) and near(b.art.tc[3], 0.1)
        and near(b.art.tc[4], 0.9), "0.1 cropped off each side (feedback-21 H6)")
    assertEqual(b.iconZoom, 0.1)
    assertEqual(#frames, 1, "the border's frame made at the first paint")
    assertEqual(frames[1].drawn.edgeFile, IS.SOLID_EDGE, "no LibSharedMedia here: Solid still draws the flat edge")
    assertEqual(frames[1].drawn.edgeSize, 2)
    assertTrue(sameColor(b.iconBorder, 0, 0, 0, 1), "black, opaque")
    IS.Apply(nil, EPIC); IS.Apply({}, EPIC)   -- no button, or no texture: nothing
end)

test("icon style: zoom 0 and no border draw an item icon as it was before G11", function()
    local NS, _, m = T.enableAddon()
    local S, frames = NS.SchemaRuntime.Set, borderFrames(m)
    assertTrue(S("icons.zoom", 0)); assertTrue(S("icons.borderShow", false))
    local b = fakeButton()
    NS.IconStyle.Apply(b, EPIC)
    assertTrue(b.art.tc[1] == 0 and b.art.tc[2] == 1 and b.art.tc[3] == 0 and b.art.tc[4] == 1, "no crop")
    assertEqual(b.iconZoom, 0)
    assertNil(b.iconBorder, "no border"); assertNil(b.iconBorderFrame, "and no frame made for one")
    assertEqual(#frames, 0)
end)

test("icon style: Solid is registered with LibSharedMedia as the flat white texture, so the dropdown offers it", function()
    local seen = {}
    local NS = T.enableAddon({ mock = function(m)
        local LSM = m.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
        LSM.Register = function(_, kind, name, path) seen[#seen + 1] = { kind, name, path } end
    end })
    local hit
    for _, r in ipairs(seen) do if r[1] == "border" and r[2] == "Solid" then hit = r end end
    assertTrue(hit ~= nil, "registered at load")
    assertEqual(hit[3], NS.IconStyle.SOLID_EDGE); assertEqual(NS.IconStyle.SOLID_EDGE, "Interface\\Buttons\\WHITE8X8")
    assertEqual(NS.C.PROFILE.icons.borderStyle, NS.IconStyle.SOLID, "the default names it")
end)

test("icon style: a repaint that changes nothing costs nothing; a row's write restyles every button made so far", function()
    local NS = T.enableAddon()
    local IS = NS.IconStyle
    local shown, unshown = fakeButton(), fakeButton()
    shown.link = EPIC
    IS.Apply(shown, EPIC); IS.Apply(unshown, nil)
    IS.Apply(shown, EPIC); IS.Apply(shown, RARE)
    assertEqual(shown.art.crops, 1, "the same settings again: no call")
    assertTrue(NS.SchemaRuntime.Set("icons.zoom", 0.15))
    assertEqual(shown.art.crops, 2, "the write restyled it at once")
    assertTrue(near(shown.art.tc[1], 0.15) and near(shown.art.tc[2], 0.85) and near(shown.art.tc[3], 0.15)
        and near(shown.art.tc[4], 0.85), "0.15 cropped off each side")
    assertTrue(near(unshown.art.tc[1], 0.15), "a button showing nothing (a pooled one) too")
    NS.addon.db.profile.icons.zoom = 0.6   -- written behind the seam, as a hand-edited file is
    IS.Refresh()
    assertEqual(shown.iconZoom, IS.ZOOM_MAX, "clamped to the slider's range")
end)

test("icon style: Show border draws the swatch over the icon; Use class color the player's class with its alpha", function()
    local NS, _, m = T.enableAddon()
    local S, frames = NS.SchemaRuntime.Set, borderFrames(m)
    assertTrue(S("icons.borderShow", false))
    local b = fakeButton()
    NS.IconStyle.Apply(b, EPIC)
    assertEqual(#frames, 0, "none while the border is off")
    assertTrue(S("icons.borderShow", true))
    assertEqual(#frames, 1, "made on first use")
    local f = frames[1]
    assertTrue(b.iconBorderFrame == f and f.__parent == b, "a child frame of the button")
    assertTrue(f.on == true)
    assertEqual(f.drawn.edgeFile, NS.IconStyle.SOLID_EDGE, "no LibSharedMedia here: Solid's flat edge")
    assertEqual(f.drawn.edgeSize, 2)
    assertTrue(sameColor(f.edge, 0, 0, 0, 1), "the black swatch")
    assertTrue(S("icons.borderColor", { r = 1, g = 0, b = 0, a = 0.5 })); assertTrue(S("icons.borderSize", 5))
    assertTrue(sameColor(b.iconBorder, 1, 0, 0, 0.5)); assertEqual(f.drawn.edgeSize, 5)
    assertTrue(S("icons.useClassColorBorder", true))
    local mage = m.RAID_CLASS_COLORS.MAGE
    assertTrue(sameColor(f.edge, mage.r, mage.g, mage.b, 0.5), "the player's Mage blue, the swatch's alpha")
    assertTrue(S("icons.borderShow", false))
    assertTrue(f.on == false, "hidden"); assertNil(b.iconBorder)
    assertEqual(#frames, 1, "and kept for the next time")
end)

test("icon style: a border style LibSharedMedia knows draws its texture", function()
    local NS, _, m = T.enableAddon()
    local frames = borderFrames(m)
    local LSM = m.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    LSM.Fetch = function(_, kind, name) return kind == "border" and name == "Blizzard Tooltip" and "tex\\tooltip" or nil end
    NS.IconStyle.Apply(fakeButton(), EPIC)
    assertTrue(NS.SchemaRuntime.Set("icons.borderStyle", "Blizzard Tooltip"))
    assertEqual(frames[1].drawn.edgeFile, "tex\\tooltip")
    assertTrue(NS.SchemaRuntime.Set("icons.borderStyle", "Gone Addon's Border"))
    assertEqual(frames[1].drawn.edgeFile, NS.IconStyle.BORDER_FALLBACK, "a style nobody registers any more")
    assertTrue(NS.SchemaRuntime.Set("icons.borderStyle", "Solid"))
    assertEqual(frames[1].drawn.edgeFile, NS.IconStyle.SOLID_EDGE, "Solid, even where the library lost it")
end)

test("icon style: Color by item quality draws each item's quality color, the swatch's alpha kept", function()
    local NS, _, m = T.enableAddon()
    local S = NS.SchemaRuntime.Set
    m.ITEM_QUALITY_COLORS = QUALITY_COLORS
    m.addItem(EPIC, { name = "Crown of Roaring Storms", quality = 4, ilvl = 311 })
    local b = fakeButton()
    b.link = EPIC   -- SetItem's, which Refresh repaints it for
    NS.IconStyle.Apply(b, EPIC)
    assertTrue(S("icons.borderShow", true)); assertTrue(S("icons.borderColor", { r = 1, g = 1, b = 1, a = 0.75 }))
    assertTrue(S("icons.borderQuality", true))
    assertTrue(sameColor(b.iconBorder, 0.64, 0.21, 0.93, 0.75), "epic purple, from the item's quality")
    assertTrue(S("icons.useClassColorBorder", true))
    assertTrue(sameColor(b.iconBorder, 0.64, 0.21, 0.93, 0.75), "the quality wins over the class color")
    b.link = RARE
    NS.IconStyle.Apply(b, RARE)   -- not cached: the link's own color, through LibKa0s-Item
    assertTrue(sameColor(b.iconBorder, 0, 0x70 / 255, 0xdd / 255, 0.75), "a new item, its color")
    local mage = m.RAID_CLASS_COLORS.MAGE
    b.link = PLAIN
    NS.IconStyle.Apply(b, PLAIN)
    assertTrue(sameColor(b.iconBorder, mage.r, mage.g, mage.b, 0.75), "no quality known: the swatch's mode")
    assertNil(NS.IconStyle.QualityColor(nil))
    local r, g, bl = NS.IconStyle.QualityColor(EPIC)
    assertTrue(near(r, 0.64) and near(g, 0.21) and near(bl, 0.93))
end)

-- ── the surfaces ────────────────────────────────────────────────────────────────────────────

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90 }

local function drop(over)
    local d = {
        id = 1, at = 100, link = EPIC, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local function shown(drops, compact)
    local NS, _, m = T.enableAddon()
    m.__now = 100
    local byId, ids = {}, {}
    for i, d in ipairs(drops) do byId[d.id], ids[i] = d, d.id end
    local g = {}
    for k, v in pairs(GROUP) do g[k] = v end
    g.drops = ids
    NS.LootFeed.Groups = function() return { g } end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    NS.WindowFilterBar.Set("group", "view", "all")
    if compact then NS.SetWindowMode("compact") end
    NS.ShowWindow()
    return NS, m
end

local function rowFor(NS, id)
    for _, r in ipairs(NS.WindowGroup.Drawn().rows) do if r.dropId == id then return r end end
end

local function crop(b) return (b.art:GetTexCoord()) end

test("icon style: the Drops row's icon, its Me icons and the detail card's header take a row's write live", function()
    local NS = shown({ drop(), drop({ id = 2, link = RARE }) })
    local row = rowFor(NS, 1)
    assertTrue(near(crop(row.cells.item.button), 0.1), "the default zoom (feedback-21 H6)")
    NS.WindowGroup.ToggleExpand(1)
    local card = NS.WindowGroup.Drawn().card
    assertTrue(NS.SchemaRuntime.Set("icons.zoom", 0.08))
    assertTrue(near(crop(row.cells.item.button), 0.08), "the row's item icon")
    for i, icon in ipairs(row.cells.me.icons) do assertTrue(near(crop(icon), 0.08), "Me icon " .. i) end
    assertTrue(near(crop(card.icon), 0.08), "the detail card's header")
    assertTrue(row.cells.item.button.iconBorder ~= nil and card.icon.iconBorder ~= nil, "the default border")
    assertTrue(NS.SchemaRuntime.Set("icons.borderShow", false))
    assertNil(row.cells.item.button.iconBorder); assertNil(card.icon.iconBorder)
    assertTrue(NS.SchemaRuntime.Set("icons.borderShow", true))
    assertTrue(row.cells.item.button.iconBorder ~= nil and card.icon.iconBorder ~= nil)
    assertEqual(row.cells.item.button.iconBorderFrame.__backdrop.edgeSize, 2, "drawn on the decorated frame")
end)

test("icon style: the compact card's icon and the toast's icon wear it too", function()
    local NS = shown({ drop() }, true)
    assertTrue(NS.SchemaRuntime.Set("icons.zoom", 0.2))
    local cards = NS.WindowGroup.Drawn().rows
    assertTrue(#cards > 0 and near(crop(cards[1].icon), 0.2), "the compact card")
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    local f = NS.Toast.Frame()
    assertEqual(NS.Toast.Stats().dropId, 1)
    assertTrue(near(crop(f.icon), 0.2), "the toast, built after the write")
end)

test("icon style: the glow starts over the border, and a profile switch re-reads the look", function()
    local NS = shown({ drop() })
    assertEqual(NS.Glow.FRAME_LEVEL, 2, "the border's child frame is one level over the button, the glow two")
    local b = rowFor(NS, 1).cells.item.button
    NS.addon.db.profile.icons.zoom = 0.15   -- written behind the seam, as a profile copy is
    NS.addon:OnProfileCopied(nil, nil, "Other")
    assertTrue(near(crop(b), 0.15))
end)
