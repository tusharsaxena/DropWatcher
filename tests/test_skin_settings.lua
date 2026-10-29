-- tests/test_skin_settings.lua — this addon's own settings widgets and tool surfaces on the skin
-- (core/SkinSetup.lua's NS.SkinPaintAce / NS.SkinPaintAceTree / NS.SkinOnRelease over
-- LibKa0s-Skin-1.0's SkinAce, skinning-§3; DW-04 of the skinning rollout).
--
-- What this pins: every AceGUI widget settings/PageEditors.lua acquires itself is painted for this
-- owner EVEN THROUGH A HANDLE THAT IS NOT THE LIBRARY'S OWNER PROXY (the cases swap the raw AceGUI
-- fake in, so the host's own NS.SkinPaintAce is what paints); a release hands the widget back stock;
-- the Situations placeholder's undo rides the release chain rather than AceGUI's one OnRelease
-- callback and still parks the table; the Situations table's session-held cells follow a skin
-- switch and the Scope's Ignore settings panel, live; the Profiles page paints the tree
-- AceConfigDialog drew; the degraded seam paints nothing and still runs a host's release work; and
-- every library tool surface (debug console, perf panel, sim panel, test strip, toast) is handed
-- this addon as its skin owner.
--
-- The kit's widgets are recorders without AceGUI's regions, so "painted" is read where the library
-- keeps it: `Skin.__ace[widget].owner` (SkinAce.lua's weak state table), set while owned and
-- cleared by the restore. Each case builds its own addon.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "DropWatcher"

local function gui(m) return m.__libs["AceGUI-3.0"] end
local function skinOf(m) return m.LibStub("LibKa0s-Skin-1.0") end

local function ownerOf(m, w)
    local st = skinOf(m).__ace and skinOf(m).__ace[w]
    return st and st.owner or nil
end

-- The types SkinAce has a painter for, among the ones these pages acquire.
local PAINTED = { Button = true, CheckBox = true, Dropdown = true, EditBox = true }

--- An enabled addon whose settings panel is skinned (the Scope's Ignore settings panel off; a new
--- profile has it on), on `skin`, with the Options instance's AceGUI swapped for the raw fake.
local function skinned(skin)
    local NS, _, m = T.enableAddon()
    NS.ArmSkinPicker(false)
    NS.WriteSkinChoice("ka0s", skin, { panel = false, fonts = false })
    NS.ApplySkinChoice()
    m.__fireTimers()
    NS.addon.Settings.Helpers.AceGUI = gui(m)
    return NS, m
end

-- Show a page; answers its ctx.
local function open(NS, key)
    local ctx = NS.addon.Settings.Helpers.__panelFor(key)
    assertTrue(ctx ~= nil, "page " .. key .. " was built")
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    return ctx
end

-- Click a tab; answers the widgets of a painted type that render acquired.
local function tab(m, ctx, label)
    local before = #gui(m).__created
    for _, b in ipairs(ctx.__tabLayout.buttons) do
        b:__fire("OnClick")
        if ctx.activeTab == label then
            local out = {}
            for i = before + 1, #gui(m).__created do
                local w = gui(m).__created[i]
                if PAINTED[w.type] then out[#out + 1] = w end
            end
            return out
        end
        before = #gui(m).__created
    end
    assertTrue(false, "no tab labeled " .. label)
end

-- ── the pages' own widgets ───────────────────────────────────────────────────────────────────

-- Each tab and the widgets settings/PageEditors.lua acquires on it (the library's own rows on the
-- same tab are made through the swapped handle too, and are not this file's to paint). The
-- Situations table's cells are built once, on the page's first render, and read from the table.
local function textOf(w) return w.labelText or w.text end
local OWN = {
    { page = "feed", tab = "Retention",
      mine = function(w) return w.type == "Button" and textOf(w) == "Clear history" end },
    { page = "comparison", tab = "Weights",
      mine = function(w) return w.type == "EditBox" and textOf(w) == "Import a Pawn scale" end },
    { page = "messages", tab = "Templates",
      mine = function(w) return w.type == "Button" and tostring(textOf(w)):sub(1, 1) == "{" end },
}

local function paintsPastProxy(skin)
    local NS, m = skinned(skin)
    local t = open(NS, "feed").dwSituations
    assertTrue(t ~= nil, "the situations table was built")
    for _, r in ipairs(t.rows) do
        assertEqual(ownerOf(m, r.track), OWNER, "a Track cell is painted")
        assertEqual(ownerOf(m, r.quality), OWNER, "a Quality cell is painted")
    end
    for _, c in ipairs(OWN) do
        local ctx = open(NS, c.page)
        local seen = 0
        for _, w in ipairs(tab(m, ctx, c.tab)) do
            if c.mine(w) then
                seen = seen + 1
                assertEqual(ownerOf(m, w), OWNER, c.tab .. ": a " .. w.type .. " is painted for this owner")
                assertTrue(type(rawget(w, "OnRelease")) == "function", c.tab .. ": its release is wrapped")
            end
        end
        assertTrue(seen > 0, c.tab .. " acquired none of its own widgets")
    end
end

test("skin settings: under a non-default skin the pages' own widgets paint, past the proxy", function()
    -- red under: dropping NS.SkinPaintAce from settings/PageEditors.lua's acquire.
    paintsPastProxy("obsidian")
end)

test("skin settings: under Ka0s Default the pages' own widgets paint like every skin's", function()
    paintsPastProxy("ka0s")
end)

test("skin settings: a release hands a painted widget back stock", function()
    -- red under: a host that replaced the widget's OnRelease outright (the restore never runs).
    local NS, m = skinned("obsidian")
    local ctx = open(NS, "feed")
    local ws = {}
    for _, w in ipairs(tab(m, ctx, "Retention")) do if OWN[1].mine(w) then ws[#ws + 1] = w end end
    assertTrue(#ws > 0, "Retention acquired Clear history")
    for _, w in ipairs(ws) do
        assertEqual(ownerOf(m, w), OWNER, "owned before the release")
        if not w.__released then gui(m):Release(w) end
        assertEqual(ownerOf(m, w), nil, "nothing of this owner rides it to the next acquirer")
        assertEqual(rawget(w, "OnRelease"), nil, "the wrapper is taken back")
    end
end)

-- ── Drops › Situations: the placeholder's chained undo and the session-held cells ─────────────

test("skin settings: the Situations placeholder's undo rides the release chain and still parks the table", function()
    -- red under: the placeholder taking AceGUI's one OnRelease callback again (SetCallback).
    local NS, m = skinned("obsidian")
    local ctx = open(NS, "feed")
    assertEqual(ctx.activeTab, "Situations")
    local t = ctx.dwSituations
    local holder
    for _, w in ipairs(gui(m).__created) do
        if w.type == "SimpleGroup" and not w.__released and w.frame == t.host:GetParent() then holder = w end
    end
    assertTrue(holder ~= nil, "the table sits on a placeholder")
    assertTrue(holder.callbacks == nil or holder.callbacks.OnRelease == nil,
        "AceGUI's one OnRelease callback is left free")
    assertTrue(type(rawget(holder, "OnRelease")) == "function", "the undo is chained on")
    gui(m):Release(holder)
    assertEqual(t.host:GetParent(), ctx.panel, "the released placeholder parks the table")
    assertFalse(t.host:IsShown() == true, "and the parked table is hidden")
end)

test("skin settings: the Situations cells follow a skin switch and the Ignore settings panel, live", function()
    -- They are acquired once a session and never released, so the library's re-render never
    -- reaches them. red under: dropping PageEditors' OnLooksChanged repaint.
    local NS, m = skinned("ka0s")
    NS.addon.Settings.Helpers.AceGUI = gui(m)
    local t = open(NS, "feed").dwSituations
    local function each(want, why)
        for _, r in ipairs(t.rows) do
            for _, k in ipairs({ "track", "autoOpen", "quality", "rule" }) do
                assertEqual(ownerOf(m, r[k]), want, k .. ": " .. why)
            end
        end
    end
    each(OWNER, "painted on Ka0s Default")
    NS.ApplySkinChoice("ka0s", "obsidian")
    each(OWNER, "painted on the switch")
    NS.ApplySkinIgnore(true, nil)
    each(nil, "stock with the settings panel ignored")
    NS.ApplySkinIgnore(false, nil)
    each(OWNER, "painted again")
end)

test("skin settings: the Situations headers, labels and stripes stay Ka0s Default with the settings panel ignored", function()
    -- The table's own strings and stripes are painted by the page, not by the library, so they
    -- ask the Scope themselves. red under: paintHeader / paintLabel / paintStripe reading
    -- NS.SkinColor unconditionally (Obsidian's text.headingAlt on an ignored panel).
    local NS = skinned("obsidian")
    -- The panel is a plain stub, whose regions are the frame itself and record no paint; marked
    -- as the mock's recording tree before the first render, the table it builds records.
    local ctx = NS.addon.Settings.Helpers.__panelFor("feed")
    ctx.panel.__dwTree = true
    local t = open(NS, "feed").dwSituations
    local function same(c, want) return c[1] == want[1] and c[2] == want[2] and c[3] == want[3] end
    local function colorOf(fs) return { fs:GetTextColor() } end
    local function headColor() return colorOf(t.headers[1]) end
    local fb = NS.SKIN_FALLBACK
    local live = { NS.Skin.Color("text.headingAlt") }
    assertFalse(same(live, fb["text.headingAlt"]), "Obsidian's header color differs from Ka0s Default's")
    assertTrue(same(headColor(), live), "a skinned panel draws the header in the skin's color")
    NS.ApplySkinIgnore(true, nil)
    assertTrue(same(headColor(), fb["text.headingAlt"]), "an ignored panel draws the header in Ka0s Default's")
    local r = t.rows[1]
    local want = r.label.dwActive and fb["text.bodyAlt"] or fb["text.disabled"]
    assertTrue(same(colorOf(r.label), want), "and a label")
    local stripe = t.rows[2].stripe.__colorTexture
    assertTrue(same(stripe, fb["list.stripe"]) and stripe[4] == fb["list.stripe"][4], "and a stripe")
    NS.ApplySkinIgnore(false, nil)
    assertTrue(same(headColor(), live), "the skin's color comes back with the panel skinned again")
end)

-- ── the Profiles page ────────────────────────────────────────────────────────────────────────

test("skin settings: the Profiles page paints the tree AceConfigDialog drew", function()
    -- AceConfigDialog acquires from AceGUI itself, past the owner proxy. red under: dropping
    -- NS.SkinPaintAceTree from settings/Profiles.lua's renderer.
    local drawn
    local NS, _, m = T.enableAddon({ mock = function(mk)
        mk.__libs["AceDBOptions-3.0"] = { GetOptionsTable = function() return { type = "group" } end }
        mk.__libs["AceConfig-3.0"] = { RegisterOptionsTable = function() end }
        mk.__libs["AceConfigDialog-3.0"] = {
            Open = function(_, _, container)
                container:ReleaseChildren()
                drawn = mk.__libs["AceGUI-3.0"]:Create("CheckBox")
                container:AddChild(drawn)
            end,
        }
    end })
    NS.ArmSkinPicker(false)
    NS.WriteSkinChoice("ka0s", "obsidian", { panel = false, fonts = false })
    NS.ApplySkinChoice()
    m.__fireTimers()
    open(NS, "profiles")
    assertTrue(drawn ~= nil, "AceConfigDialog drew a row")
    assertEqual(ownerOf(m, drawn), OWNER, "the drawn row is painted for this owner")
end)

-- ── the degraded seam ────────────────────────────────────────────────────────────────────────

test("skin settings: degraded, PaintAce and PaintAceTree paint nothing and a release still runs", function()
    local D, _, m = T.enableAddon{ skip = T.loadAddon.libFiles }
    local w = gui(m):Create("SimpleGroup")
    assertEqual(D.SkinPaintAce(w), false, "PaintAce is a no-op")
    assertEqual(D.SkinPaintAceTree(w), 0, "PaintAceTree paints nothing")
    local ran
    D.SkinOnRelease(w, function(released) ran = released end)
    gui(m):Release(w)
    assertTrue(ran == w, "the host's release work runs without the library")
end)

-- ── the tool surfaces: every library factory names this owner ────────────────────────────────

test("skin tools: the debug console, perf panel, sim panel, test strip and toast are this owner's", function()
    -- The debug console (and its copy window) is owned only while the host passes neither `skin`
    -- nor `applySkin` (DebugLog minor 22); the perf panel's owner is its `addonName` (PerfPanel 10),
    -- the sim panel's its descriptor's `name` (SimPanel 7). Read from the source so a rename of
    -- either goes red.
    local function read(path)
        local fh = assert(io.open(path, "rb"))
        local s = fh:read("*a"); fh:close()
        return (s:gsub("%-%-[^\r\n]*", ""))
    end
    local dbg = read("core/DebugLogSetup.lua")
    assertTrue(dbg:find("addonName%s*=%s*addonName") ~= nil, "the console's addonName is the owner")
    assertTrue(dbg:find("applySkin%s*=") == nil and dbg:find("[^%w_]skin%s*=") == nil,
        "a host skin or applySkin opts the console out of its owner")
    assertTrue(read("core/PerfSetup.lua"):find("addonName%s*=%s*addonName") ~= nil, "the perf panel's addonName")
    assertTrue(read("modules/Sim.lua"):find('name%s*=%s*"' .. OWNER .. '"') ~= nil, "the Sim descriptor's name")
    local w = read("core/WidgetsSetup.lua")
    local _, owners = w:gsub("owner%s*=%s*addonName", "")
    assertEqual(owners, 3, "Dropdown, SearchBox and TestStrip each name the owner")
    assertTrue(read("core/ToastSetup.lua"):find("d%.owner%s*=%s*d%.owner%s*or%s*addonName") ~= nil, "the toast's owner")
end)

test("skin tools: the live debug console is painted for this owner", function()
    local NS, _, m = T.enableAddon()
    NS.ArmSkinPicker(false)
    NS.DebugLog:Show()
    local f = NS.DebugLog._frameForTest
    assertTrue(f ~= nil, "the console frame")
    assertTrue(rawget(f, "__logLine") ~= nil, "the console was built unowned (no palette line)")
    local rec = skinOf(m).painted and skinOf(m).painted[f]
    assertTrue(rec ~= nil and rec.owner == OWNER, "the console window is recorded for " .. OWNER)
    NS.DebugLog:Hide()
end)
