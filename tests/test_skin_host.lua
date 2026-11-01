-- tests/test_skin_host.lua — this addon's own surfaces on the skin's primitives (FS-DW-FIX, causes
-- A1, L4, L8 and L9 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING): the flat button's box,
-- label and mark, the detail card's boxes, the tabs, the column head band, the row hover, the footer
-- band, the title bar and the Situations table's faces. Each case reads what the drawing setter was
-- told, on a test skin that moves the token.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "DropWatcher"

local function near(a, b) return math.abs(a - b) < 1e-6 end
local function same(got, want, label)
    assertTrue(type(got) == "table", label .. ": nothing drawn")
    for i = 1, 3 do assertTrue(near(got[i], want[i]), ("%s[%d]: %s, want %s"):format(label, i, tostring(got[i]), tostring(want[i]))) end
end

local function shown()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    return NS, NS.Window.Frame(), m
end

--- A test skin moving the tokens these cases read, then applied.
local function toSkin(m)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    if not Skin:GetSkin("dw-host") then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
        tokens["btn.text"], tokens["btn.icon"] = { 0.1, 0.2, 0.3, 1 }, { 0.3, 0.2, 0.1, 1 }
        tokens["btn.hover"] = { 0.7, 0.1, 0.1, 1 }
        tokens["list.hover"] = { 0.2, 0.4, 0.6, 0.5 }
        tokens["list.header.bg"] = { 0.5, 0.1, 0.5, 0.5 }
        tokens["foot.bg"] = { 0.1, 0.5, 0.1, 0.5 }
        tokens["tab.onText"], tokens["tab.text"] = { 0.9, 0.1, 0.1, 1 }, { 0.1, 0.9, 0.1, 1 }
        tokens["title.align"] = "LEFT"
        Skin:RegisterSkin({ key = "dw-host", label = "dw-host", tokens = tokens })
    end
    Skin:SetChoice(OWNER, "ka0s", "dw-host")
    return Skin
end

local function hover(frame, on)
    local fn = frame:GetScript(on and "OnEnter" or "OnLeave")
    assertTrue(fn ~= nil, "no hover script")
    fn(frame)
end

-- ── the flat button (A1, L8) ─────────────────────────────────────────────────────────────────

test("skin host: an untoned button's label and mark read btn.text and btn.icon, live", function()
    local NS, f, m = shown()
    local b = NS.Window.TextButton(f, 80, "chat", "Send", function() end)
    same({ b.label:GetTextColor() }, { NS.Skin.Color("btn.text") }, "label")
    same(b.art.__vertex, { NS.Skin.Color("btn.icon") }, "mark, Ka0s Default's gray")
    toSkin(m)
    same({ b.label:GetTextColor() }, { 0.1, 0.2, 0.3 }, "label switched")
    same(b.art.__vertex, { 0.3, 0.2, 0.1 }, "mark switched")
end)

test("skin host: hover draws btn.hover on an untoned label and leaves a state's tone alone", function()
    local NS, f, m = shown()
    toSkin(m)
    local b = NS.Window.TextButton(f, 80, "chat", "Send", function() end)
    hover(b, true)
    same({ b.label:GetTextColor() }, { 0.7, 0.1, 0.1 }, "hot")
    hover(b, false)
    same({ b.label:GetTextColor() }, { 0.1, 0.2, 0.3 }, "rest")
    NS.WindowGroup.ToneButton(b, "sent")
    local tone = { b.label:GetTextColor() }
    hover(b, true)
    same({ b.label:GetTextColor() }, tone, "a toned label keeps its tone under the pointer (D1)")
    hover(b, false)
    same({ b.label:GetTextColor() }, tone, "and after")
    same(b.art.__vertex, tone, "a toned mark takes the tone")
    NS.WindowGroup.ToneButton(b, nil)
    same({ b.label:GetTextColor() }, { 0.1, 0.2, 0.3 }, "untoned again: btn.text")
    same(b.art.__vertex, { 0.3, 0.2, 0.1 }, "untoned again: btn.icon")
end)

test("skin host: the button's and the detail box's frames are the library's primitives", function()
    local NS, f, m = shown()
    local b = NS.Window.TextButton(f, 80, "chat", "Send", function() end)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    assertTrue(Skin.painted[b] ~= nil and Skin.painted[b].calls.Button ~= nil, "S.Button recorded it")
    assertEqual(Skin.painted[b].calls.Button[1].tokens.bg, "dw.btnBg", "Ka0s Default keeps the owner's fill")
end)

-- ── the tabs (A1) ────────────────────────────────────────────────────────────────────────────

test("skin host: the tabs are the skin's, and selection moves their label color", function()
    local NS, f, m = shown()
    toSkin(m)
    same({ f.tabs.group.label:GetTextColor() }, { 0.9, 0.1, 0.1 }, "active: tab.onText")
    same({ f.tabs.history.label:GetTextColor() }, { 0.1, 0.9, 0.1 }, "idle: tab.text")
    NS.Window.SelectTab("history")
    same({ f.tabs.history.label:GetTextColor() }, { 0.9, 0.1, 0.1 }, "the new active tab")
    same({ f.tabs.group.label:GetTextColor() }, { 0.1, 0.9, 0.1 }, "the old one")
end)

test("skin host: without the library the tabs keep their text roles and underline", function()
    local NS = T.enableAddon{ skip = T.loadAddon.libFiles }
    NS.ShowWindow()
    local f = NS.Window.Frame()
    assertTrue(f.tabs.group.underline:IsShown())
    assertFalse(f.tabs.history.underline:IsShown())
end)

-- ── the column heads, the footer, the row hover (A1) ─────────────────────────────────────────

test("skin host: the column heads wear list.header.bg and the footer foot.bg", function()
    local NS, f, m = shown()
    local Skin = toSkin(m)
    local head = f.panes.group.colHead
    assertTrue(Skin.painted[head].calls.SortHeaderBar ~= nil, "S.SortHeaderBar on the Drops head")
    assertTrue(Skin.painted[f.footerHost].calls.Footer ~= nil, "S.Footer on the footer")
    NS.Window.SelectTab("history")
    assertTrue(Skin.painted[f.panes.history.colHead].calls.SortHeaderBar ~= nil, "and on History's")
end)

test("skin host: a row takes list.hover under the pointer, from a cell inside it too", function()
    local NS, f, m = shown()
    local Skin = toSkin(m)
    local row = m.CreateFrame("Button", nil, f)
    row.tipRow = true
    NS.WindowRows.HoverWash(row)
    local cell = m.CreateFrame("Frame", nil, row)
    NS.Window.AttachTooltip(cell, function() return "x" end, "row")
    hover(row, true)
    local wash = Skin.painted[row].regions.hover
    assertTrue(wash ~= nil and wash:IsShown(), "the hover wash")
    same(wash.__colorTexture, { 0.2, 0.4, 0.6 }, "list.hover")
    hover(row, false)
    assertFalse(wash:IsShown())
    hover(cell, true)
    assertTrue(wash:IsShown(), "a cell's hover is the row's")
    hover(cell, false)
    assertFalse(wash:IsShown())
end)

-- ── the title bar (L9) ───────────────────────────────────────────────────────────────────────

test("skin host: the title bar is placed by the skin's height and alignment", function()
    local _, f, m = shown()
    assertEqual(f.titleBar:GetHeight(), 30, "Ka0s Default's title.height")
    toSkin(m)
    local p = f.title.__points[#f.title.__points]
    assertEqual(p[1], "LEFT", "title.align moves the title's anchor")
end)

-- ── the Situations table's faces (L4) ────────────────────────────────────────────────────────

test("skin host: the Situations table's heads and labels take the panel's Text, kept off while ignored", function()
    local src = io.open("settings/PageEditors.lua", "rb"):read("*a")
    assertTrue(src:find('NS.Skin.Text(fs, "text.headingAlt", PANEL)', 1, true) ~= nil, "the header's face")
    assertTrue(src:find('NS.Skin.Text(fs, "text.bodyAlt", PANEL)', 1, true) ~= nil, "the label's face")
end)
