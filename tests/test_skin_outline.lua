-- tests/test_skin_outline.lua — the Font outline (LibKa0s v1.82.0, Skin minor 9; DW-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as
-- skin.outline ("hud", the default since v1.83.0's D-10, "all", "off"), written only through the skin write seam
-- (NS.WriteSkinChoice's `media.outline`) and the row, and applied with Skin:SetOutline at load, on
-- every profile event and on the row's own write. The window, the cards and the toast are window
-- text, so "hud" takes their outline.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DropWatcher"

local function lib(m) return m.LibStub("LibKa0s-Skin-1.0") end
local function profileSkin(NS) return NS.addon.db.profile.skin end

--- Run `fn` with chat output swallowed, so a verb's own lines stay out of the run's log.
local function quietly(m, fn)
    local cf = m.DEFAULT_CHAT_FRAME
    local add = cf.AddMessage
    cf.AddMessage = function() end
    local ok, err = pcall(fn)
    cf.AddMessage = add
    if not ok then error(err, 0) end
end

test("outline: a fresh profile stores HUD text only, the library's default", function()
    local NS, _, m = T.enableAddon()
    assertEqual(profileSkin(NS).outline, "hud")
    assertEqual(NS.C.PROFILE.skin.outline, lib(m).OUTLINE_DEFAULT, "the value lives in defaults/Profile.lua")
    assertEqual(lib(m):GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text starts unoutlined")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
end)

test("outline: a stored All text stays, and is applied (D-10 migrates nothing)", function()
    -- red under: a migration, or a default forced over the stored mode, on the owner's existing pick.
    local NS, _, m = T.newAddon()
    local AceDB = m.LibStub("AceDB-3.0")
    local new = AceDB.New
    AceDB.New = function(self, ...)
        local db = new(self, ...)
        db.profile.skin.outline = "all"
        return db
    end
    local ok, err = pcall(NS.addon.OnInitialize, NS.addon)
    AceDB.New = new
    assertTrue(ok, tostring(err))
    assertEqual(profileSkin(NS).outline, "all")
    assertEqual(lib(m):GetOutline(OWNER), "all")
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE", "window text keeps the outline")
end)

test("outline: the schema row offers the library's three modes, in its order, on the Skin tab", function()
    local NS, _, m = T.newAddon()
    local row = NS.SchemaRuntime.FindRow("skin.outline")
    assertTrue(row ~= nil, "a skin.outline row")
    assertTrue(row.skipRender == true, "the Skin tab draws it")
    assertEqual(row.page, "general")
    assertEqual(row.group, "Appearance")
    local got = {}
    for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
    assertEqual(table.concat(got, ","), table.concat(lib(m).OUTLINE_MODES, ","))
end)

test("outline: the write seam stores media.outline, and leaves it alone when it is nil", function()
    -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and another
    -- addon's copy would move the look and never store it).
    local NS, _, m = T.enableAddon()
    quietly(m, function()
        NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    end)
    assertEqual(profileSkin(NS).outline, "hud")
    quietly(m, function() NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false }) end)
    assertEqual(profileSkin(NS).outline, "hud", "a media without outline leaves it")
    quietly(m, function()
        NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    end)
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: another addon's copy reaches the store through WriteChoice", function()
    local NS, _, m = T.enableAddon()
    quietly(m, function()
        lib(m):WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    end)
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: the row's write applies the mode live", function()
    local NS, _, m = T.enableAddon()
    local S = NS.SchemaRuntime
    quietly(m, function() S.Set("skin.outline", "hud") end)
    assertEqual(lib(m):GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    quietly(m, function() S.Set("skin.outline", "off") end)
    assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
    quietly(m, function() S.Set("skin.outline", "all") end)
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
end)

test("outline: /dw set refuses a mode the library does not know", function()
    local NS, _, m = T.enableAddon()
    quietly(m, function() NS.addon:OnSlashCommand("set skin.outline thick") end)
    assertEqual(profileSkin(NS).outline, "hud")
    quietly(m, function() NS.addon:OnSlashCommand("set skin.outline off") end)
    assertEqual(profileSkin(NS).outline, "off")
    assertEqual(lib(m):GetOutline(OWNER), "off", "a known mode applies")
end)

test("outline: the stored mode is applied right after AceDB exists", function()
    -- red under: ApplySkinChoice's whole-pair path not applying the stored outline.
    local NS, _, m = T.newAddon()
    local AceDB = m.LibStub("AceDB-3.0")
    local new = AceDB.New
    AceDB.New = function(self, ...)
        local db = new(self, ...)
        db.profile.skin.outline = "hud"
        return db
    end
    local ok, err = pcall(NS.addon.OnInitialize, NS.addon)
    AceDB.New = new
    assertTrue(ok, tostring(err))
    assertEqual(lib(m):GetOutline(OWNER), "hud")
end)

test("outline: a profile switch and a reset apply the incoming profile's mode", function()
    local NS, _, m = T.enableAddon()
    local db = NS.addon.db
    quietly(m, function()
        db:SetProfile("OutlineProbe")
        db.profile.skin.outline = "off"
        db:SetProfile("Default")
    end)
    assertEqual(lib(m):GetOutline(OWNER), "hud", "back on Default, Default's mode")
    quietly(m, function() db:SetProfile("OutlineProbe") end)
    assertEqual(lib(m):GetOutline(OWNER), "off", "the switch did not apply the outline")
    quietly(m, function() db:ResetProfile() end)
    assertEqual(lib(m):GetOutline(OWNER), "hud", "a reset puts HUD text only back")
end)

test("outline: without the skin engine the apply is a quiet no-op and the store still takes it", function()
    local NS, _, m = T.enableAddon{ skip = { "libs/LibKa0s/Skin.lua" } }
    assertEqual(NS.ApplySkinOutline(), false)
    quietly(m, function() NS.SchemaRuntime.Set("skin.outline", "off") end)
    assertEqual(profileSkin(NS).outline, "off")
end)

test("outline: without the skin engine From skin answers the default mode, HUD text only", function()
    -- red under: the degraded facade keeping "OUTLINE" for window text, a look no profile asked for.
    local NS = T.enableAddon{ skip = { "libs/LibKa0s/Skin.lua" } }
    assertEqual(NS.SkinOutline(), "hud")
    assertEqual(NS.Skin.FontFlags("@skin", "window"), "", "window text is unoutlined")
    assertEqual(NS.Skin.FontFlags("@skin"), "OUTLINE", "HUD text keeps it")
    assertEqual(NS.Skin.FontFlags("THICKOUTLINE", "window"), "THICKOUTLINE", "a picked flag wins")
end)
