-- tests/test_skin_chrome.lua — the window's own surfaces through the skin (DW-02, skinning-§4, anti-pattern
-- #107): the chrome this addon draws itself (the tabs, the flat buttons, the badge and the mode words,
-- the tables' heads, stripes, washes, chevrons and rules, the detail card's boxes, the Edit message
-- box's refusal red) reads its colors from tokens, library or owner. Under Ka0s Default each is the
-- pixel the addon drew before skins (X1); a skin switch repaints each in the new skin's colors with
-- no reload, and the rows' font size and the verdict glyphs' monospace face survive it.
--
-- The switch goes to SWITCH, a test-only skin registered per addon: Ka0s Default with every color
-- inverted, so each compared token moves whichever way a later round retunes the shipped skins
-- (Ka0s Loot History's tests/skin_support.lua, the same idea). The literal gate is
-- tests/test_skin_literals.lua; the palette's refill is tests/test_skin_setup.lua.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DropWatcher"
local SWITCH = "dw-switch"

local function skinOf(m) return m.LibStub("LibKa0s-Skin-1.0") end

local function isColor(v)
    return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

-- Register SWITCH on this addon's skin library and switch the owner to it.
local function toSwitch(m)
    local Skin = skinOf(m)
    if not Skin:GetSkin(SWITCH) then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do
            tokens[name] = isColor(v) and { 1 - v[1], 1 - v[2], 1 - v[3], v[4] } or v
        end
        Skin:RegisterSkin({ key = SWITCH, label = "Switch (test)", tokens = tokens })
    end
    Skin:SetChoice(OWNER, "ka0s", SWITCH)
end

-- An enabled addon with the window shown (its Drops pane built).
local function shown()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    return NS, NS.Window.Frame(), m
end

local function near(label, got, want)
    assertTrue(type(got) == "table", label .. ": nothing painted")
    for i = 1, #want do
        local a, b = got[i] or 1, want[i] or 1
        assertTrue(math.abs(a - b) < 1e-6, ("%s[%d]: %s, want %s"):format(label, i, tostring(a), tostring(b)))
    end
end

local function textColor(fs) return { fs:GetTextColor() } end
local function token(NS, name) return { NS.Skin.Color(name) } end

-- The surfaces both cases compare, each with its token: { label, read(), token }.
local function surfaces(NS, f)
    local pane = f.panes.group
    local button = NS.Window.TextButton(f, 80, "chat", "Ask", function() end)
    local chevron = NS.WindowGroup.RowChevron(f)
    return {
        { "tab underline", function() return f.tabs.group.underline.__colorTexture end, "tab.onLine" },
        { "active tab", function() return textColor(f.tabs.group.label) end, "text.accent" },
        { "idle tab", function() return textColor(f.tabs.history.label) end, "dw.idle" },
        { "button fill", function() return button.__backdropColor end, "dw.btnBg" },
        { "button edge", function() return button.__backdropBorder end, "dw.btnBorder" },
        { "badge text", function() return textColor(f.badge.text) end, "dw.restricted" },
        { "badge lock", function() return f.badge.art.__vertex end, "dw.restricted" },
        { "TEST MODE", function() return textColor(f.testText.text) end, "sem.modeTest" },
        { "column head", function() return textColor(pane.colHead.labels.item.text) end, "list.header.text" },
        { "strip rule", function() return pane.summary.line.__colorTexture end, "dw.rule" },
        { "detail box fill", function() return pane.card.trade.__backdropColor end, "dw.cardBg" },
        { "detail box edge", function() return pane.card.trade.__backdropBorder end, "dw.cardBorder" },
        { "row chevron", function() return chevron.__vertex end, "dw.chevron" },
    }
end

-- ── Ka0s Default ─────────────────────────────────────────────────────────────────────────────

test("skin chrome: under Ka0s Default the window draws the pixels it drew before skins", function()
    -- X1. red under: a surface left on a literal the skin cannot reach, or a token whose Ka0s Default
    -- value is not the one the surface typed (each pixel below is the old literal).
    local NS, f = shown()
    local want = {
        ["tab underline"] = { 1, 0.82, 0, 1 }, ["active tab"] = { 1, 0.82, 0 }, ["idle tab"] = { 0.62, 0.62, 0.64 },
        ["button fill"] = { 0.12, 0.12, 0.14, 1 }, ["button edge"] = { 0.24, 0.24, 0.27, 0.85 },
        ["badge text"] = { 1, 0.6, 0.2 }, ["badge lock"] = { 1, 0.6, 0.2 }, ["TEST MODE"] = { 1, 0.15, 0.15 },
        ["column head"] = { 1, 0.82, 0 }, ["strip rule"] = { 1, 1, 1, 0.1 },
        ["detail box fill"] = { 0.08, 0.08, 0.10, 0.9 }, ["detail box edge"] = { 0.24, 0.24, 0.27, 0.85 },
        ["row chevron"] = { 1, 1, 1, 0.55 },
    }
    for _, s in ipairs(surfaces(NS, f)) do near(s[1], s[2](), want[s[1]]) end
    near("SIMULATION", textColor(f.simText.text), { 0.35, 0.80, 1.00, 1 })
end)

-- ── a skin switch ────────────────────────────────────────────────────────────────────────────

test("skin chrome: a skin switch repaints every surface in the new skin's colors, with no reload", function()
    -- red under: a color set once at build and never repainted (NS.SkinPaint or the library's
    -- record missing), or a surface read from a token other than its role's.
    local NS, f, m = shown()
    local list = surfaces(NS, f)
    toSwitch(m)
    for _, s in ipairs(list) do
        near(s[1] .. " (switched)", s[2](), token(NS, s[3]))
    end
    -- The SIMULATION word: the strip's cyan at full opacity, in the new skin.
    local r, g, b = NS.Skin.Color("strip.sim")
    near("SIMULATION (switched)", textColor(f.simText.text), { r, g, b, 1 })
    assertTrue(math.abs(f.tabs.group.underline.__colorTexture[1]) < 1e-6,
        "SWITCH inverts gold, so the underline's red channel is 0: the case compared moved values")
end)

test("skin chrome: the tones a cell is painted in are the new skin's after a switch", function()
    -- R1: the tables index C.TONE at paint time; the refill runs first on OnLooksChanged, so the
    -- window's repaint, which runs after it, paints every cell in the new skin's tones.
    local NS, f, m = shown()
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    NS.WindowGroup.ToneButton({ label = fs }, "sent")
    local before = textColor(fs)
    toSwitch(m)
    NS.WindowGroup.ToneButton({ label = fs }, "sent")
    local tone = NS.Constants.TONE[NS.WindowCells.ActionTone("sent")]
    near("toned label", textColor(fs), { tone.r, tone.g, tone.b })
    assertTrue(before[2] ~= textColor(fs)[2], "the tone moved with the skin")
end)

test("skin chrome: the rows' font size holds across a skin switch", function()
    -- R4: a switch repaints each text's face at its template's size, so WindowRows reads the face
    -- anew and applies the Font size row's size again, once per row, on the next repaint.
    local NS, f, m = shown()
    local WR = NS.WindowRows
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    NS.Skin.Font(fs)
    local calls = 0
    local set = fs.SetFont
    fs.SetFont = function(self, ...) calls = calls + 1; return set(self, ...) end
    local row = { cells = { item = { text = fs } } }
    WR.ApplyRowFont(row, 14)
    WR.ApplyRowFont(row, 14)
    assertEqual(calls, 1, "once per change")
    toSwitch(m)
    WR.ApplyRowFont(row, 14)
    assertEqual(calls, 2, "a skin switch applies the size again")
    assertEqual(select(2, fs:GetFont()), 14)
end)

test("skin chrome: the verdict glyphs are the skin's monospace face, Ka0s Default's JetBrains Mono", function()
    -- R5: every Ka0s skin's font.mono carries ▲ ≈ ▼; under Ka0s Default it is the face the glyphs
    -- always used (core/Constants.lua's FONT_MONO).
    local NS, f = shown()
    assertEqual(NS.Skin.Token("font.mono"), "JetBrains Mono")
    assertEqual(NS.SkinMonoFont(), NS.Constants.FONT_MONO)
    local fs = f:CreateFontString(nil, "OVERLAY")
    NS.SkinMono(fs, 12)
    local face, size = fs:GetFont()
    assertEqual(face, NS.Constants.FONT_MONO)
    assertEqual(size, 12)
end)

test("skin chrome: the shown toast repaints its rows' tones on a skin switch", function()
    -- R10: the toast lives off the window, so the window's repaint never reaches it; its own
    -- OnLooksChanged listener repaints the drop on screen. Nothing to do with no toast shown.
    local NS, _, m = shown()
    local painted = 0
    local compose = NS.Toast.Compose
    NS.Toast.Compose = function(...) painted = painted + 1; return compose(...) end
    toSwitch(m)
    assertEqual(painted, 0, "no toast on screen: nothing repainted")
end)

test("skin chrome: a toast on screen repaints once on a skin switch, its tones in the new skin's", function()
    -- red under: the toast's OnLooksChanged listener (modules/Toast.lua) returning at once.
    local NS, _, m = T.enableAddon()
    local d = {
        id = 1, link = "|cffa335ee|Hitem:500::|h[Item 500]|h|r", itemID = 500, isMine = false,
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }
    NS.LootFeed.Get = function(id) return id == 1 and d or nil end
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    local f = NS.Toast.Frame()
    assertTrue(f ~= nil and NS.Toast.Stats().shown, "the drop toasted")
    near("Me (ka0s)", f.meText.__textColor, token(NS, "dw.upgrade"))
    local painted = 0
    local compose = NS.Toast.Compose
    NS.Toast.Compose = function(...) painted = painted + 1; return compose(...) end
    toSwitch(m)
    NS.Toast.Compose = compose
    assertEqual(painted, 1, "the shown toast repainted once")
    local switched = token(NS, "dw.upgrade")
    assertTrue(math.abs(switched[1] - 0.30) > 1e-6, "the switch moved dw.upgrade")
    near("Me (switched)", f.meText.__textColor, switched)
end)

test("skin chrome: the refusal red and the trade reason's gray are escapes of the skin's tokens", function()
    -- red under: an escape built once at file load (it would keep the old skin's bytes) or a literal.
    local NS, _, m = T.bootAddon()
    local E = NS.addon.Settings.Editors
    local label = E.CounterLabel("ask", string.rep("x", 256))
    assertTrue(label:find(NS.SkinEscape("sem.badAlt") .. "256 / 255|r", 1, true) ~= nil, label)
    local reason = NS.WindowCells.TradeText({ text = "No", reason = "Bonus roll" })
    assertEqual(reason, "No |cffb3b3b8Bonus roll|r", "Ka0s Default's text.muted, 0.7, 0.7, 0.72")
    toSwitch(m)
    label = E.CounterLabel("ask", string.rep("x", 256))
    assertTrue(label:find(NS.SkinEscape("sem.badAlt") .. "256 / 255|r", 1, true) ~= nil, "switched: " .. label)
    assertTrue(NS.SkinEscape("sem.badAlt") ~= "|cffff4040", "the switch moved the red")
    assertEqual(NS.WindowCells.TradeText({ text = "No", reason = "x" }), "No " .. NS.SkinEscape("text.muted") .. "x|r")
end)

test("skin chrome: an item quality keeps the client's color unless the skin overrides it", function()
    -- E4, X1: Ka0s Default's q.* tokens are the client's colors rounded to two places, so the client's
    -- own is drawn where no skin overrides; a skin that sets its own q.* draws that.
    local NS, _, m = T.bootAddon()
    m.ITEM_QUALITY_COLORS = { [4] = { r = 163 / 255, g = 53 / 255, b = 238 / 255 } }
    local r, g, b = NS.QualityColor(4)
    near("epic (ka0s)", { r, g, b }, { 163 / 255, 53 / 255, 238 / 255 })
    toSwitch(m)
    r, g, b = NS.QualityColor(4)
    near("epic (switched)", { r, g, b }, token(NS, "q.epic"))
    m.ITEM_QUALITY_COLORS = nil
end)

test("skin chrome: without the library the window's own colors are Ka0s Default's", function()
    -- The degraded facade's Text and the host copy answer every token the window reads, so a
    -- library-absent load colors what it builds as before.
    local degraded = T.newAddon{ skip = T.loadAddon.libFiles }
    for _, name in ipairs({ "list.stripe", "list.box", "list.boxEdge", "list.header.text", "text.heading",
        "text.accent", "text.highlight", "text.disabled", "text.muted", "text.headingAlt", "text.bodyAlt",
        "gtip.title", "gtip.value", "tab.onLine", "icon.hot", "icon.tint", "btn.text", "sem.modeTest",
        "strip.sim", "sem.badAlt", "input.bg", "input.border", "dw.idle", "dw.rowOpen" }) do
        assertTrue(degraded.Skin.Color(name) ~= nil, name .. " has no degraded value")
    end
    local fs = { SetTextColor = function(self, ...) self.c = { ... } end }
    degraded.Skin.Text(fs, "heading")
    near("degraded heading", fs.c, { 1, 0.82, 0 })
    degraded.Skin.Text(fs, "dw.idle")
    near("degraded owner token", fs.c, { 0.62, 0.62, 0.64 })
end)
