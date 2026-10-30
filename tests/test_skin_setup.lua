-- tests/test_skin_setup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§1 to §3).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams and its owner tokens;
-- the skin.* keys default to Ka0s Default and are skip-render schema rows on General's Skin tab,
-- which sits after Simulator and before Keybindings; the profile's skin is applied right after
-- AceDB exists and again on every profile event; one pick, from the tab or a bare `/dw set`, is ONE
-- effective SetChoice (one OnLooksChanged); and every library factory this addon calls is handed the
-- owner. Each case builds its own addon, so no skin outlives a case.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "DropWatcher"

local function skinOf(m) return m.LibStub("LibKa0s-Skin-1.0") end

-- A listener counting this owner's repaints, registered once per addon.
local function countLooks(NS)
    local n = { looks = 0 }
    NS.Skin.OnLooksChanged(function() n.looks = n.looks + 1 end)
    return n
end

-- A slash line run with chat silenced; answers what it printed.
local function quietly(m, fn)
    local cf, said = m.DEFAULT_CHAT_FRAME, {}
    local add = cf.AddMessage
    cf.AddMessage = function(_, line) said[#said + 1] = tostring(line) end
    local ok, err = pcall(fn)
    cf.AddMessage = add
    if not ok then error(err, 0) end
    return said
end

local function sameColor(label, got, want)
    for i = 1, 4 do
        local a, b = got[i] or 1, want[i] or 1
        assertTrue(math.abs(a - b) < 1e-6, ("%s[%d]: %s, want %s"):format(label, i, tostring(a), tostring(b)))
    end
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the owner is the folder name, and NS.Skin is its facade", function()
    -- red under: registering under the brand or a typo (the library keys every frame and listener
    -- by owner), or publishing some other owner's facade.
    local NS, _, m = T.newAddon()
    local Skin = skinOf(m)
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"DropWatcher\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), NS.BRAND, "the copy confirmation names the addon by its brand")
end)

test("Skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD, before AceDB; a getter that raised there would be a
    -- Lua error on every login.
    local NS = T.newAddon()
    local ok, source, skin = pcall(NS.SkinChoice)
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
end)

-- ── the owner tokens (X1, X2, X12) ───────────────────────────────────────────────────────────

test("Skin seam: every owner token is namespaced dw. and taken by the library", function()
    -- red under: a name outside the addon's namespace or in a library family (refused and logged),
    -- or a follow that names no library color token.
    local NS, _, m = T.newAddon()
    local Skin = skinOf(m)
    local n = 0
    for name, def in pairs(NS.SKIN_TOKENS) do
        n = n + 1
        assertTrue(name:sub(1, 3) == "dw.", name .. " is not in the dw. namespace")
        assertTrue(type(def.follow) == "string", name .. " follows a library role token")
        assertTrue(type(Skin:ResolveSkin("ka0s")[def.follow]) == "table", name .. ": " .. def.follow .. " is a library color")
        assertTrue(NS.Skin.Color(name) ~= nil, name .. " does not resolve: refused by the library")
    end
    assertTrue(n > 0, "no owner token is declared")
end)

test("Skin seam: under Ka0s Default each owner token is today's pixel; elsewhere its follow token's", function()
    -- X1: Ka0s Default keeps the exact value the addon drew before skins. red under: a default
    -- snapped to the follow token, or a follow ignored in another skin.
    local NS, _, m = T.bootAddon()
    local Skin = skinOf(m)
    for name, def in pairs(NS.SKIN_TOKENS) do
        sameColor(name .. " (ka0s)", { NS.Skin.Color(name) }, def.default)
    end
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local obsidian = Skin:ResolveSkin("obsidian")
    for name, def in pairs(NS.SKIN_TOKENS) do
        sameColor(name .. " (obsidian)", { NS.Skin.Color(name) }, obsidian[def.follow])
    end
end)

test("Skin seam: the palette's Ka0s Default values are the owner tokens' defaults", function()
    -- The tokens were cut from core/Constants.lua's palette as it stood before skins (C.TONE, C.IDLE,
    -- C.CHEVRON_ROW and the chrome literals the DW-G gaps name), written out here because the palette
    -- now reads them: a default that drifts from the value the palette held is a Ka0s Default pixel
    -- moved (X1).
    local NS = T.newAddon()
    local want = {
        ["dw.upgrade"] = { 0.30, 0.85, 0.40 }, ["dw.sidegrade"] = { 1.00, 0.96, 0.42 },
        ["dw.downgrade"] = { 1.00, 0.36, 0.32 }, ["dw.offer"] = { 0.35, 0.82, 0.95 },
        ["dw.offSpec"] = { 0.30, 0.85, 0.85 }, ["dw.cantUse"] = { 0.72, 0.36, 0.34 },
        ["dw.notWanted"] = { 0.55, 0.55, 0.58 }, ["dw.urgent"] = { 1.00, 0.65, 0.15 },
        ["dw.statGain"] = { 0.42, 0.74, 0.46 }, ["dw.plain"] = { 0.92, 0.92, 0.92 },
        ["dw.idle"] = { 0.62, 0.62, 0.64 }, ["dw.tipHint"] = { 0.62, 0.62, 0.64 },
        ["dw.tipLabel"] = { 0.80, 0.68, 0.36 }, ["dw.chevron"] = { 1, 1, 1, 0.55 },
        ["dw.restricted"] = { 1, 0.6, 0.2 }, ["dw.rowOpen"] = { 1, 0.82, 0, 0.08 },
        ["dw.btnBg"] = { 0.12, 0.12, 0.14, 1 }, ["dw.btnBorder"] = { 0.24, 0.24, 0.27, 0.85 },
        ["dw.rule"] = { 1, 1, 1, 0.1 }, ["dw.cardBg"] = { 0.08, 0.08, 0.10, 0.9 },
        ["dw.cardBorder"] = { 0.24, 0.24, 0.27, 0.85 },
    }
    for name, c in pairs(want) do
        assertTrue(NS.SKIN_TOKENS[name] ~= nil, name .. " is declared")
        sameColor(name, NS.SKIN_TOKENS[name].default, c)
    end
end)

test("Skin seam: C.TONE is filled from its tokens, and refilled in place by a skin switch", function()
    -- red under: a tone left empty at load, a tone read from the wrong token, a switch that builds a
    -- new table (a file that took C.TONE.good at load would keep the old color) or that leaves the
    -- old skin's values in it.
    local NS, _, m = T.bootAddon()
    local C, Skin = NS.Constants, skinOf(m)
    local good = C.TONE.good
    for key, token in pairs(C.TONE_TOKEN) do
        local t = C.TONE[key]
        sameColor(key .. " (ka0s)", { t.r, t.g, t.b }, { NS.Skin.Color(token) })
    end
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    assertTrue(rawequal(C.TONE.good, good), "the same table, refilled")
    for key, token in pairs(C.TONE_TOKEN) do
        local t, r, g, b = C.TONE[key], NS.Skin.Color(token)
        sameColor(key .. " (obsidian)", { t.r, t.g, t.b }, { r, g, b })
    end
    assertTrue(C.TONE.statCrit.r == 1 and C.TONE.glowMain.r == 25 / 255,
        "the stat names' and the glows' colors are not the skin's (E5, E6)")
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

local PATHS = { "skin.source", "skin.skin", "skin.ignorePanel", "skin.ignoreFonts", "skin.font",
                "skin.texture", "skin.outline", "skin.pickerSeen" }

test("Skin seam: the skin keys default to Ka0s Default, as skip-render rows of General's Skin tab", function()
    -- red under: a default other than today's look, or a row that renders itself on top of the
    -- library's choice grids. O3: pickerSeen is false on every profile, so the picker shows once.
    local NS = T.newAddon()
    local d = NS.C.PROFILE.skin
    assertEqual(d.source, "ka0s")
    assertEqual(d.skin, "ka0s")
    assertEqual(d.ignorePanel, true, "the settings panel stays the client's on a new profile")
    assertEqual(d.ignoreFonts, false)
    assertEqual(d.font, "")
    assertEqual(d.texture, "")
    assertEqual(d.outline, "all")
    assertEqual(d.pickerSeen, false)
    for _, path in ipairs(PATHS) do
        local row = NS.SchemaRuntime.FindRow(path)
        assertTrue(row ~= nil, path .. " is not a schema row")
        assertEqual(row.page, "general", path .. ": page")
        assertEqual(row.group, "Appearance", path .. ": group (the Skin tab's key)")
        assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
    end
end)

test("Skin seam: the skin row's values are every registered skin, in the library's order", function()
    local NS, _, m = T.newAddon()
    local values = NS.SchemaRuntime.FindRow("skin.skin").values
    local skins = skinOf(m):Skins()
    assertEqual(#values, #skins, "one value per registered skin")
    for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
    assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("Skin seam: /dw set refuses a skin that is not registered and applies one that is, once", function()
    local NS, _, m = T.enableAddon()
    local Skin, n = skinOf(m), countLooks(NS)
    quietly(m, function() NS.addon:OnSlashCommand("set skin.skin no-such-skin") end)
    assertEqual(NS.Setting("skin.skin"), "ka0s", "an unknown skin was stored")
    assertEqual(n.looks, 0, "a refused set repainted")
    quietly(m, function() NS.addon:OnSlashCommand("set skin.skin obsidian") end)
    assertEqual(NS.addon.db.profile.skin.skin, "obsidian", "a registered skin was refused")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "obsidian", "the row's onChange moves the applied skin")
    assertEqual(n.looks, 1, "one set, one repaint")
end)

test("Skin seam: /dw set reaches an exception and an override, each its own half", function()
    local NS, _, m = T.enableAddon()
    local Skin = skinOf(m)
    quietly(m, function() NS.addon:OnSlashCommand("set skin.ignoreFonts true") end)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the set applied")
    assertEqual(panel, true, "the other half untouched")
    quietly(m, function() NS.addon:OnSlashCommand("set skin.font Friz Quadrata TT") end)
    assertEqual(NS.addon.db.profile.skin.font, "Friz Quadrata TT")
    assertEqual((Skin:GetOverride(OWNER)), "Friz Quadrata TT", "the font override applied")
end)

test("Skin seam: the write seam writes every half through NS.SchemaRuntime.Set", function()
    -- The tab's and another addon's copy's `set`. red under: a seam that writes the profile around
    -- the schema (no validation, no [Set] line, no onChange).
    local NS = T.enableAddon()
    local S, seen = NS.SchemaRuntime, {}
    local set = S.Set
    S.Set = function(path, value, ...) seen[path] = value; return set(path, value, ...) end
    local ok, err = pcall(NS.WriteSkinChoice, "ka0s", "glass", { panel = false, fonts = true },
        { font = false, texture = "Solid" })
    S.Set = set
    assertTrue(ok, tostring(err))
    assertEqual(seen["skin.source"], "ka0s")
    assertEqual(seen["skin.skin"], "glass")
    assertEqual(seen["skin.ignorePanel"], false)
    assertEqual(seen["skin.ignoreFonts"], true)
    assertEqual(seen["skin.font"], "", "false is stored as the skin's own, \"\"")
    assertEqual(seen["skin.texture"], "Solid")
end)

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

local function gui(m) return m.__libs["AceGUI-3.0"] end

local function openGeneral(NS)
    local ctx = NS.addon.Settings.Helpers.__panelFor("general")
    assertTrue(ctx ~= nil, "the General page was built")
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    return ctx
end

-- Click the tab keyed `key` and answer the widgets that render drew.
local function clickTab(m, ctx, key)
    local before = #gui(m).__created
    for _, b in ipairs(ctx.__tabLayout.buttons) do
        b:__fire("OnClick")
        if ctx.activeTab == key then
            local out, list = {}, gui(m).__created
            for i = before + 1, #list do out[#out + 1] = list[i] end
            return out
        end
        before = #gui(m).__created
    end
    assertTrue(false, "no tab keyed " .. key)
end

test("Skin seam: the Skin tab sits after Simulator and before Keybindings, labeled Skin", function()
    -- skinning-§3 and options-ui-§20: Master controls first, Keybindings last.
    local NS, _, m = T.enableAddon()
    local ctx = openGeneral(NS)
    local keys, buttons = {}, ctx.__tabLayout.buttons
    for i, b in ipairs(buttons) do
        b:__fire("OnClick")
        keys[i] = ctx.activeTab
    end
    assertEqual(table.concat(keys, "|"), "Master controls|Simulator|Appearance|Keybindings")
    clickTab(m, ctx, "Appearance")
    assertEqual(ctx.activeTab, "Appearance")
end)

test("Skin seam: one tab pick is one effective SetChoice, one repaint, and lands in the profile", function()
    -- The tab calls SetChoice first, then the write seam, which writes both rows through the schema;
    -- each row's onChange applies only its own half and finds it applied already. red under: an
    -- onChange that re-applies the whole stored pair (two repaints, the first to a half-written skin).
    local NS, _, m = T.enableAddon()
    local Skin, n = skinOf(m), countLooks(NS)
    local ctx = openGeneral(NS)
    local drawn = clickTab(m, ctx, "Appearance")
    local pick
    for _, w in ipairs(drawn) do
        local label = tostring(w.labelText or "")
        if w.type == "CheckBox" and label:sub(-#"Obsidian") == "Obsidian" then pick = w end
    end
    assertTrue(pick ~= nil, "the Skin tab drew no Obsidian choice")
    pick:SetValue(true); pick:__fire("OnValueChanged", true)
    assertEqual(n.looks, 1, "one pick must repaint exactly once")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.addon.db.profile.skin.skin, "obsidian", "the pick did not reach the profile")
end)

-- ── applying the stored choice ───────────────────────────────────────────────────────────────

test("Skin seam: the profile's skin, scope and overrides are applied right after AceDB exists", function()
    -- red under: OnInitialize never applying the store (every login back on Ka0s Default).
    local NS, _, m = T.newAddon()
    local Skin = skinOf(m)
    local AceDB = m.LibStub("AceDB-3.0")
    local new = AceDB.New
    AceDB.New = function(self, ...)
        local db = new(self, ...)
        db.profile.skin = { source = "ka0s", skin = "ember", ignorePanel = false, ignoreFonts = true,
                            font = "Friz Quadrata TT", texture = "", pickerSeen = true }
        return db
    end
    local ok, err = pcall(NS.addon.OnInitialize, NS.addon)
    AceDB.New = new
    assertTrue(ok, tostring(err))
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ember", "the stored skin")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(panel, false, "the stored panel exception")
    assertEqual(fonts, true, "the stored fonts exception")
    assertEqual((Skin:GetOverride(OWNER)), "Friz Quadrata TT", "the stored font override")
end)

test("Skin seam: a profile switch, copy and reset each apply the incoming profile's skin", function()
    -- skinning-§2. red under: a profile event that leaves the old profile's skin worn.
    local NS, _, m = T.enableAddon()
    local Skin, db = skinOf(m), NS.addon.db
    db:SetProfile("SkinProbe")
    db.profile.skin.skin = "glass"
    db:SetProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    local n = countLooks(NS)
    db:SetProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    assertEqual(n.looks, 1, "one switch, one repaint")
    db:ResetProfile()
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "a reset puts Ka0s Default back on")
    db:SetProfile("Default")
    db.profile.skin.skin = "ember"
    db:SetProfile("SkinProbe")
    db:CopyProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ember", "a copy wears the copied skin")
end)

-- ── the factories (skinning-§1: every library factory that takes an owner is given one) ────────

test("Skin seam: the window edge, dropdowns, search box and mode strips are built for the owner", function()
    -- red under: a factory called without the owner, which draws Ka0s Default whatever the skin.
    local NS, _, m = T.enableAddon()
    local W, Core = m.LibStub("LibKa0s-Widgets-1.0"), m.LibStub("LibKa0s-Core-1.0")
    local seen = {}
    local dd, sb, ts, apply = W.Dropdown, W.SearchBox, W.TestStrip, Core.ApplySkin
    W.Dropdown = function(_, _, opts) seen.dropdown = opts and opts.owner end
    W.SearchBox = function(_, _, opts) seen.search = opts and opts.owner end
    W.TestStrip = function(_, opts) seen.strip = opts and opts.owner end
    Core.ApplySkin = function(_, skin, owner) seen.apply, seen.applySkin = owner, skin end
    local ok, err = pcall(function()
        local parent = m.CreateFrame("Frame")
        NS.MakeDropdown(parent, 100)
        NS.MakeSearchBox(parent, 100, { hint = "x" })
        NS.MakeTestStrip(parent, "x", "sim")
        NS.ApplySkin(parent)
    end)
    W.Dropdown, W.SearchBox, W.TestStrip, Core.ApplySkin = dd, sb, ts, apply
    assertTrue(ok, tostring(err))
    assertEqual(seen.dropdown, OWNER, "W.Dropdown's owner")
    assertEqual(seen.search, OWNER, "W.SearchBox's owner")
    assertEqual(seen.strip, OWNER, "W.TestStrip's owner")
    assertEqual(seen.apply, OWNER, "Core.ApplySkin's owner")
    assertEqual(seen.applySkin, nil, "no skin table, so the owner's skin paints it")
end)

-- ── the TOC ──────────────────────────────────────────────────────────────────────────────────

local function tocLines()
    local fh = assert(io.open("DropWatcher.toc", "r"))
    local out = {}
    for line in fh:lines() do out[#out + 1] = (line:gsub("\r", "")) end
    fh:close()
    return out
end

test("Skin seam: the TOC loads the seam after Core and before the widgets, and names EllesmereUI", function()
    -- skinning-§5: EllesmereUI in OptionalDeps, never Dependencies, so it loads first where it is
    -- installed and offers this addon in its Third-Party list.
    local at, deps = {}, nil
    for i, line in ipairs(tocLines()) do
        at[line] = i
        deps = deps or line:match("^## OptionalDeps:%s*(.*)$")
    end
    assertTrue(deps ~= nil and (", " .. deps .. ","):find(", EllesmereUI,", 1, true) ~= nil,
        "OptionalDeps names EllesmereUI")
    local seam = at["core\\SkinSetup.lua"]
    assertTrue(seam ~= nil, "core\\SkinSetup.lua is in the TOC")
    assertTrue(seam > at["core\\CoreSetup.lua"], "after core\\CoreSetup.lua (NS.ApplySkin, NS.Print)")
    assertTrue(seam < at["core\\WidgetsSetup.lua"], "before core\\WidgetsSetup.lua and every module")
    assertTrue(seam < at["defaults\\Profile.lua"], "before the schema rows read NS.SKIN_OPTIONS")
end)

-- ── the degraded seam ────────────────────────────────────────────────────────────────────────

test("Skin seam: without the library the facade answers Ka0s Default, owner tokens included", function()
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    assertFalse(NS.Skin.IsEnabled(), "a degraded facade is never enabled")
    for name, def in pairs(NS.SKIN_TOKENS) do
        sameColor(name, { NS.Skin.Color(name) }, def.default)
    end
    local r, g, b = NS.Skin.Color("title.text")
    assertTrue(r == 1 and g == 0.82 and b == 0, "the degraded title color is today's gold")
    assertEqual(select(2, NS.SkinChoice()), "ka0s")
    assertFalse(NS.ApplySkinChoice(), "nothing to apply without the library")
end)
