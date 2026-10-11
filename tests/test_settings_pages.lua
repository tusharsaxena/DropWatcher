-- tests/test_settings_pages.lua — the settings pages of design spec §12.2: the page list and each
-- page's strip, the rows each page draws, the dimmed rows, the Feed page's "in force now" readout,
-- the Comparison page's per-spec editors, the Messages page's template editors (live counters,
-- token chips, preview, Reset templates), each page's Defaults button, and the pure halves of the
-- editors (settings/Editors.lua). Built headless under the kit's AceGUI recorder: a page's body is
-- drawn on its first OnShow, and a tab is reached by clicking the strip's button.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The pages after the landing page, and each page's strip, in order. Stated here rather than read
-- from the rows, so a tab that moves is a named failure.
local PAGES = {
    { key = "general",    title = "General",    strip = { "Master controls", "When to show", "Simulation" } },
    { key = "feed",       title = "Feed",       strip = { "Quality", "Filters" } },
    { key = "comparison", title = "Comparison", strip = { "Scoring", "Weights", "Preferences" } },
    { key = "trade",      title = "Trade",      strip = { "Rules", "Timers" } },
    { key = "messages",   title = "Messages",   strip = { "Templates", "Sending", "Auto-ask" } },
    { key = "window",     title = "Window",     strip = { "Columns", "Layout", "Toast" } },
}

local function gui(m) return m.__libs["AceGUI-3.0"] end

local function created(m, from)
    local out, list = {}, gui(m).__created
    for i = from + 1, #list do out[#out + 1] = list[i] end
    return out
end

-- Show a page and answer its ctx and the widgets its first render drew.
local function open(NS, m, key)
    local H = NS.addon.Settings.Helpers
    local ctx = H.__panelFor(key)
    assertTrue(ctx ~= nil, "page " .. key .. " was built")
    local before = #gui(m).__created
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    return ctx, created(m, before)
end

-- Click a tab and answer the widgets that render drew. BY POSITION, as the strip's buttons come
-- back in tab order, then checked against the tab the library says is active.
local function tab(m, ctx, label)
    local before = #gui(m).__created
    for _, b in ipairs(ctx.__tabLayout.buttons) do
        b:__fire("OnClick")
        if ctx.activeTab == label then return created(m, before) end
        before = #gui(m).__created
    end
    assertTrue(false, "no tab labeled " .. label)
end

local function find(list, wtype, label)
    for _, w in ipairs(list) do
        if w.type == wtype and (w.labelText == label or w.text == label) then return w end
    end
end

local function findPrefix(list, wtype, prefix)
    for _, w in ipairs(list) do
        local l = w.labelText or w.text
        if w.type == wtype and type(l) == "string" and l:sub(1, #prefix) == prefix then return w end
    end
end

-- The strip's tabs in order, read as the active tab each button selects, then back to the first.
local function stripOf(ctx)
    local out, buttons = {}, ctx.__tabLayout.buttons
    out[1] = ctx.activeTab
    for i = 2, #buttons do
        buttons[i]:__fire("OnClick")
        out[i] = ctx.activeTab
    end
    ctx.__tabLayout.buttons[1]:__fire("OnClick")
    return out
end

-- ── the pages and their strips ──────────────────────────────────────────────────────────────

test("pages: General, Feed, Comparison, Trade, Messages and Window are built, in that order", function()
    local NS = T.enableAddon()
    local built = {}
    for _, p in ipairs(NS.addon.Settings.Helpers.__pages()) do
        if p.key ~= "profiles" then built[#built + 1] = p.key end
    end
    local want = {}
    for i, p in ipairs(PAGES) do want[i] = p.key end
    assertEqual(table.concat(built, ","), table.concat(want, ","))
end)

test("pages: each page's strip is its own tabs, one per group, in declaration order", function()
    local NS, _, m = T.enableAddon()
    for _, p in ipairs(PAGES) do
        local ctx = open(NS, m, p.key)
        -- red under: rowsForPage answering the whole schema, which gave General fifteen tabs
        assertEqual(table.concat(stripOf(ctx), "|"), table.concat(p.strip, "|"), p.key)
    end
end)

test("pages: a page's rows are the rows whose page is its key", function()
    local NS = T.enableAddon()
    local S = NS.addon.Settings
    for _, p in ipairs(PAGES) do
        local rows = S.RowsForPage(p.key)
        assertTrue(#rows > 0, p.key .. " has rows")
        for _, row in ipairs(rows) do assertEqual(row.page, p.key, row.path) end
    end
end)

test("pages: every schema row with a page but the Profiles page's is drawn by one of these pages", function()
    local NS = T.enableAddon()
    local keys = {}
    for _, p in ipairs(PAGES) do keys[p.key] = true end
    for _, row in ipairs(NS.addon.Settings.Schema) do
        assertTrue(keys[row.page] == true, tostring(row.path) .. " is on a registered page")
    end
end)

-- ── General › When to show ──────────────────────────────────────────────────────────────────

test("when to show: one block per situation, Track and Auto-open then Quality, under its name", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "general")
    local drawn = tab(m, ctx, "When to show")
    assertTrue(find(drawn, "CheckBox", "Auto-open the window") ~= nil, "the master auto-open first")
    local headings, tracks = 0, 0
    for _, w in ipairs(drawn) do
        if w.type == "Heading" then headings = headings + 1 end
        if w.type == "CheckBox" and w.labelText == "Track" then tracks = tracks + 1 end
    end
    assertEqual(headings, #NS.Constants.SITUATIONS)
    assertEqual(tracks, #NS.Constants.SITUATIONS)
    assertTrue(find(drawn, "Heading", "Mythic+") ~= nil)
end)

test("when to show: an untracked situation's Auto-open and Quality are dimmed, and so is every Auto-open with the master off", function()
    local NS, _, m = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    local ctx = open(NS, m, "general")
    local drawn = tab(m, ctx, "When to show")
    local autoOpens = {}
    for _, w in ipairs(drawn) do
        if w.type == "CheckBox" and w.labelText == "Auto-open" then autoOpens[#autoOpens + 1] = w end
    end
    -- Mythic+ is tracked by default; delve is not.
    assertFalse(autoOpens[1].disabled == true, "mythicPlus auto-open live")
    assertTrue(autoOpens[6].disabled == true, "delve (untracked) auto-open dimmed")
    Set("situations.delve.track", true)
    assertFalse(autoOpens[6].disabled == true, "tracking it lights it")
    Set("autoOpen", false)
    -- red under: a disabledIf that reads the situation's track alone
    assertTrue(autoOpens[1].disabled == true, "the master off dims every situation's")
end)

-- ── Feed › Quality ──────────────────────────────────────────────────────────────────────────

test("feed: the Quality tab closes with the threshold in force now, repainted on a write", function()
    local NS, _, m = T.enableAddon()
    local _, drawn = open(NS, m, "feed")
    local readout = findPrefix(drawn, "Label", "In force now")
    assertTrue(readout ~= nil, "the readout is drawn")
    assertEqual(readout.text, "In force now: Quality: Rare+")
    NS.SchemaRuntime.Set("feed.quality.fixed", NS.Constants.QUALITY.EPIC)
    assertEqual(readout.text, "In force now: Quality: Epic+")
    NS.SchemaRuntime.Set("feed.quality.mode", "dynamicSlot")
    assertEqual(readout.text, "In force now: Quality: Match slot")
end)

test("feed: the fixed minimum is live in the fixed mode only, and the floor in the matching modes only", function()
    local NS, _, m = T.enableAddon()
    local _, drawn = open(NS, m, "feed")
    local fixed, floor = find(drawn, "Dropdown", "Fixed minimum"), find(drawn, "Dropdown", "Floor")
    assertFalse(fixed.disabled == true)
    assertTrue(floor.disabled == true)
    NS.SchemaRuntime.Set("feed.quality.mode", "dynamicCharacter")
    assertTrue(fixed.disabled == true)
    assertFalse(floor.disabled == true)
end)

test("feed: the readout names the situation whose own quality setting is in force", function()
    local NS = T.enableAddon()
    local E = NS.addon.Settings.Editors
    assertEqual(E.ReadoutText("Quality: Rare+", nil), "In force now: Quality: Rare+")
    assertEqual(E.ReadoutText("Quality: Match slot", "Dungeon"),
        "In force now: Quality: Match slot (Dungeon's own setting)")
end)

-- ── Comparison › Weights and Preferences ────────────────────────────────────────────────────

test("comparison: Weights draws your class's specs as a sub-strip and one slider per stat", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Weights")
    -- The mock player is a mage: Arcane, Fire and Frost, the first shown (250 is not a mage's).
    assertEqual(#ctx.__subTabKids, 3)
    assertEqual(ctx.activeSubTab["Weights"], 62)
    assertTrue(find(drawn, "Slider", "Intellect") ~= nil, "the spec's primary stat")
    assertTrue(find(drawn, "Slider", "Strength") == nil, "and not another's")
    assertTrue(find(drawn, "Slider", "Haste") ~= nil)
end)

test("comparison: a weight slider writes the whole map through the seam, for the spec on screen", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Weights")
    find(drawn, "Slider", "Haste"):__fire("OnMouseUp", 1.5)
    local w = NS.Setting("comparison.weights")
    assertEqual(w[62].ITEM_MOD_HASTE_RATING_SHORT, 1.5)
    -- Another spec, by its sub-tab: its own weights, the first spec's kept.
    local before = #gui(m).__created
    ctx.__subTabKids[2]:__fire("OnClick")
    assertEqual(ctx.activeSubTab["Weights"], 63)
    find(created(m, before), "Slider", "Haste"):__fire("OnMouseUp", 0.75)
    w = NS.Setting("comparison.weights")
    assertEqual(w[63].ITEM_MOD_HASTE_RATING_SHORT, 0.75)
    assertEqual(w[62].ITEM_MOD_HASTE_RATING_SHORT, 1.5)
end)

test("comparison: the Pawn import box replaces the spec on screen's weights and says what came in", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Weights")
    local box = find(drawn, "EditBox", "Import a Pawn scale")
    assertTrue(box ~= nil, "the import box")
    NS.SchemaRuntime.Set("comparison.weights", { [63] = { ITEM_MOD_HASTE_RATING_SHORT = 2 } })
    local printed = #m.prints
    box:__fire("OnEnterPressed", '( Pawn: v1: "Mine": Intellect=1.2, HasteRating=0.7, Dps=4 )')
    local w = NS.Setting("comparison.weights")
    assertEqual(w[62].ITEM_MOD_INTELLECT_SHORT, 1.2)
    assertEqual(w[62].ITEM_MOD_HASTE_RATING_SHORT, 0.7)
    assertEqual(w[63].ITEM_MOD_HASTE_RATING_SHORT, 2, "another spec's weights are kept")
    local line = m.prints[printed + 1]
    assertTrue(line and line:find("Imported Mine into", 1, true) ~= nil and line:find("2 weights", 1, true) ~= nil, tostring(line))
    assertTrue(line:find("Not scored: Dps.", 1, true) ~= nil, line)
    -- A string that is not Pawn's writes nothing and says why.
    box:__fire("OnEnterPressed", "Intellect=9")
    assertEqual(NS.Setting("comparison.weights")[62].ITEM_MOD_INTELLECT_SHORT, 1.2)
    assertTrue(m.prints[#m.prints]:find("not a Pawn scale string", 1, true) ~= nil, m.prints[#m.prints])
end)

test("comparison: Preferences lists the class's weapon types and marks one unwanted per spec", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Preferences")
    local daggers = find(drawn, "CheckBox", "Daggers")
    assertTrue(daggers ~= nil, "a mage's daggers")
    assertTrue(find(drawn, "CheckBox", "Shields") == nil, "a mage carries no shield")
    daggers:__fire("OnValueChanged", true)
    local key = NS.Evaluate.SubClassKey(NS.Constants.ITEM_CLASS.WEAPON, NS.Constants.WEAPON_SUBCLASS.DAGGER)
    assertTrue(NS.Setting("comparison.undesired")[62][key] == true, "written for Arcane")
    -- red under: an edit made in place on the stored table, which skips the seam's check
    daggers:__fire("OnValueChanged", false)
    assertTrue(NS.Setting("comparison.undesired")[62] == nil, "the spec's last type cleared leaves no entry")
end)

-- ── Messages › Templates ────────────────────────────────────────────────────────────────────

local function templates(NS, m)
    local ctx, drawn = open(NS, m, "messages")
    local boxes = {}
    for _, kind in ipairs({ "ask", "offer", "announce" }) do
        local label = NS.addon.Settings.Editors.TEMPLATE_LABEL[kind]
        boxes[kind] = findPrefix(drawn, "EditBox", label)
        assertTrue(boxes[kind] ~= nil, kind .. " editor")
    end
    return ctx, drawn, boxes
end

test("messages: three editors whose labels count the template's bytes against 255", function()
    local NS, _, m = T.enableAddon()
    local _, _, boxes = templates(NS, m)
    local ask = NS.Setting("messages.templates.ask")
    assertEqual(boxes.ask.text, ask)
    assertTrue(boxes.ask.labelText:find(("%d / 255"):format(#ask), 1, true) ~= nil, boxes.ask.labelText)
    assertEqual(boxes.ask.maxLetters, 255)
end)

test("messages: typing repaints the counter and the preview live, and stores nothing until Enter", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, boxes = templates(NS, m)
    local body = findPrefix(drawn, "Label", "To ")
    assertTrue(body ~= nil, "the preview's text line")
    local stored = NS.Setting("messages.templates.offer")
    boxes.offer.text = "Want {item}?"
    boxes.offer:__fire("OnTextChanged", "Want {item}?")
    assertTrue(boxes.offer.labelText:find("12 / 255", 1, true) ~= nil, boxes.offer.labelText)
    assertTrue(findPrefix(drawn, "Label", "Preview: Offer") ~= nil, "the preview follows the box being edited")
    assertTrue(body.text:find("Want ", 1, true) ~= nil and body.text:find("{item}", 1, true) == nil, body.text)
    assertEqual(NS.Setting("messages.templates.offer"), stored)
    boxes.offer:__fire("OnEnterPressed", "Want {item}?")
    assertEqual(NS.Setting("messages.templates.offer"), "Want {item}?")
end)

-- Your worn helm, so a preview with no drop in the feed has a real item to name (test mode's
-- samples over your own gear, NS.TestMode.PreviewSpecs).
local function wearHelm(NS, m)
    local helm = m.addItem("|cnIQ4:|Hitem:6101::::::::90:::::|h[Worn Helm]|h|r",
        { name = "Worn Helm", quality = 4, ilvl = 300, equipLoc = "INVTYPE_HEAD", classID = 4, subClassID = 4, stats = {} })
    m.inventory.player[1] = helm
    NS.Gear.Refresh("test")
end

test("messages: the preview flags an unknown token and a text past the chat limit", function()
    local NS, _, m = T.enableAddon()
    wearHelm(NS, m)
    local _, drawn, boxes = templates(NS, m)
    local status
    for _, w in ipairs(drawn) do
        if w.type == "Label" and type(w.text) == "string" and w.text:find("^%d+ / 255") then status = w end
    end
    assertTrue(status ~= nil, "the status line")
    boxes.ask.text = "Hi {who}"
    boxes.ask:__fire("OnTextChanged", "Hi {who}")
    assertTrue(status.text:find("{who}", 1, true) ~= nil, status.text)
    local long = string.rep("x", 250) .. " {item}"
    boxes.ask.text = long
    boxes.ask:__fire("OnTextChanged", long)
    assertTrue(status.text:find("too long to send", 1, true) ~= nil, status.text)
end)

test("messages: an empty template is refused by the seam and the box shows the stored one again", function()
    local NS, _, m = T.enableAddon()
    local _, _, boxes = templates(NS, m)
    local ask = NS.Setting("messages.templates.ask")
    boxes.ask.text = ""
    boxes.ask:__fire("OnEnterPressed", "")
    assertEqual(NS.Setting("messages.templates.ask"), ask)
    assertEqual(boxes.ask.text, ask)
end)

test("messages: a token chip goes into the template last edited and is stored at once", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, boxes = templates(NS, m)
    local chip = find(drawn, "Button", "{mygain}")
    assertTrue(chip ~= nil, "the chips are drawn")
    local ask = NS.Setting("messages.templates.ask")
    chip:__fire("OnClick")
    assertEqual(NS.Setting("messages.templates.ask"), ask .. "{mygain}", "Ask until another is edited")
    boxes.announce:__fire("OnTextChanged", boxes.announce.text)
    find(drawn, "Button", "{item}"):__fire("OnClick")
    assertEqual(NS.Setting("messages.templates.announce"),
        NS.C.PROFILE.messages.templates.announce .. "{item}")
end)

test("messages: Reset templates puts the three back and repaints the boxes", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, boxes = templates(NS, m)
    NS.SchemaRuntime.Set("messages.templates.ask", "Mine?")
    NS.SchemaRuntime.Set("messages.templates.offer", "Yours?")
    assertEqual(boxes.ask.text, "Mine?")
    find(drawn, "Button", "Reset templates"):__fire("OnClick")
    local D = NS.C.PROFILE.messages.templates
    assertEqual(NS.Setting("messages.templates.ask"), D.ask)
    assertEqual(NS.Setting("messages.templates.offer"), D.offer)
    assertEqual(boxes.ask.text, D.ask)
end)

-- ── Defaults, page by page ──────────────────────────────────────────────────────────────────

test("pages: a page's Defaults resets that page's rows and no other page's", function()
    local NS, _, m = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    Set("feed.gearOnly", false)
    Set("trade.warnAt", 120)
    Set("comparison.weights", { [62] = { ITEM_MOD_HASTE_RATING_SHORT = 2 } })
    local ctx = open(NS, m, "feed")
    ctx.panel.defaultsOnClick()
    assertEqual(NS.Setting("feed.gearOnly"), NS.C.PROFILE.feed.gearOnly)
    assertEqual(NS.Setting("trade.warnAt"), 120, "Trade's row untouched")
    local cctx = open(NS, m, "comparison")
    cctx.panel.defaultsOnClick()
    assertTrue(next(NS.Setting("comparison.weights")) == nil, "the weights map reset whole")
end)

-- ── the editors' pure halves ────────────────────────────────────────────────────────────────

test("editors: a weight write is a fresh map; 0 removes the stat and an emptied spec", function()
    local E = T.newAddon().addon.Settings.Editors
    local stored = { [62] = { ITEM_MOD_HASTE_RATING_SHORT = 1 } }
    local out = E.WithWeight(stored, 62, "ITEM_MOD_CRIT_RATING_SHORT", 0.5)
    assertEqual(stored[62].ITEM_MOD_CRIT_RATING_SHORT, nil, "the stored map is not touched")
    assertEqual(out[62].ITEM_MOD_CRIT_RATING_SHORT, 0.5)
    assertEqual(E.Weight(out, 62, "ITEM_MOD_HASTE_RATING_SHORT"), 1)
    assertEqual(E.Weight(out, 63, "ITEM_MOD_HASTE_RATING_SHORT"), 0, "unset reads 0")
    out = E.WithWeight(E.WithWeight(out, 62, "ITEM_MOD_CRIT_RATING_SHORT", 0), 62, "ITEM_MOD_HASTE_RATING_SHORT", 0)
    assertTrue(out[62] == nil)
    assertTrue(E.WithWeight(nil, 70, "ITEM_MOD_STRENGTH_SHORT", 1)[70].ITEM_MOD_STRENGTH_SHORT == 1, "from no map")
end)

test("editors: a spec's stats are its primary stat, Stamina and the four secondaries", function()
    local NS = T.newAddon()
    local E = NS.addon.Settings.Editors
    local fury = E.StatsFor(72)
    assertEqual(fury[1], "ITEM_MOD_STRENGTH_SHORT")
    assertEqual(#fury, 6)
    local unknown = E.StatsFor(nil)
    assertEqual(#unknown, 8, "all three primaries for an unknown spec")
    assertEqual(E.StatLabel("ITEM_MOD_HASTE_RATING_SHORT", {}), "Haste")
    assertEqual(E.StatLabel("ITEM_MOD_HASTE_RATING_SHORT", { ITEM_MOD_HASTE_RATING_SHORT = "Tempo" }), "Tempo",
        "the client's own GlobalString first")
end)

test("editors: unwanted types are the class's weapons, then shields where a spec carries one", function()
    local NS = T.newAddon()
    local E, K = NS.addon.Settings.Editors, NS.Constants
    local keys = {}
    for _, c in ipairs(E.UndesiredChoices("PALADIN")) do keys[#keys + 1] = c.key end
    assertEqual(keys[#keys], NS.Evaluate.SubClassKey(K.ITEM_CLASS.ARMOR, K.ARMOR_SUBCLASS.SHIELD))
    local rogue = E.UndesiredChoices("ROGUE")
    assertEqual(#rogue, 5)
    for _, c in ipairs(rogue) do assertTrue(c.key:match("^" .. K.ITEM_CLASS.WEAPON .. ":") ~= nil, c.key) end
    assertEqual(#E.UndesiredChoices("NOPE"), 0)
end)

test("editors: an unwanted mark is a fresh map, and the last one cleared drops the spec", function()
    local E = T.newAddon().addon.Settings.Editors
    local stored = {}
    local out = E.WithUndesired(stored, 62, "2:15", true)
    assertTrue(next(stored) == nil, "the stored map is not touched")
    assertTrue(E.IsUndesired(out, 62, "2:15"))
    assertFalse(E.IsUndesired(out, 63, "2:15"))
    assertTrue(E.WithUndesired(out, 62, "2:15", false)[62] == nil)
end)

test("editors: the spec strip keeps the remembered spec, else yours, else the first", function()
    local NS = T.newAddon()
    local E = NS.addon.Settings.Editors
    local list = E.ClassSpecs("MAGE", function(id) return id == 63 and "Fire" or nil end)
    assertEqual(#list, 3)
    assertEqual(list[2].label, "Fire")
    assertEqual(list[1].label, "62", "an unnamed spec reads its id")
    assertEqual(E.PickSpec(list, 64, 63), 64)
    assertEqual(E.PickSpec(list, 250, 63), 63)
    assertEqual(E.PickSpec(list, nil, 250), 62)
    assertEqual(E.PickSpec({}, 62, 62), nil)
end)

test("editors: the counter label counts bytes and turns red past the limit", function()
    local E = T.newAddon().addon.Settings.Editors
    local label, over = E.CounterLabel("ask", "abc")
    assertTrue(label:find("3 / 255", 1, true) ~= nil and not over)
    label, over = E.CounterLabel("ask", string.rep("x", 256))
    assertTrue(over and label:find("|cffff4040256 / 255|r", 1, true) ~= nil, label)
end)

test("editors: the preview's drop is the newest that fits its template, an upgrade for you first", function()
    local E = T.newAddon().addon.Settings.Editors
    local me = { name = "Me", isSelf = true }
    local drops = {
        { looter = { name = "Old" }, me = { ilvlDelta = 9 } },
        { looter = { name = "New" }, me = { ilvlDelta = -3 } },
        { looter = me, candidates = {
            g1 = { name = "Bee", eval = { ilvlDelta = 4 } }, g2 = { name = "Ace", eval = { ilvlDelta = 4 } },
            g3 = { name = "Cee", eval = { ilvlDelta = -1 } } } },
    }
    local rec, who = E.PreviewSample("ask", drops)
    assertEqual(who.name, "Old", "an upgrade for you over a newer downgrade")
    assertTrue(rec == drops[1])
    local offerRec, offerTo = E.PreviewSample("offer", drops)
    assertTrue(offerRec == drops[3])
    assertEqual(offerTo.name, "Ace", "the candidate who gains most, ties by name")
    rec = E.PreviewSample("announce", drops)
    assertTrue(rec == drops[3])
    assertEqual(E.PreviewSample("ask", { drops[3] }), nil, "your own drop is no ask")
    local _, anyTo = E.PreviewSample("ask", { drops[2] })
    assertEqual(anyTo.name, "New", "with no upgrade, any drop of another's")
end)

test("editors: the preview's lines name who it goes to, the length and what is wrong", function()
    local E = T.newAddon().addon.Settings.Editors
    local lines = E.PreviewLines("ask", "Hi {player}, {item}? {bogus}", { player = "Seta", item = "[Crown]" }, "Seta")
    assertEqual(lines.header, "Preview: Ask, to Seta")
    assertEqual(lines.body, "To Seta: Hi Seta, [Crown]? {bogus}")
    assertTrue(lines.status:find("{bogus}", 1, true) ~= nil, lines.status)
    assertFalse(lines.tooLong)
    lines = E.PreviewLines("announce", string.rep("y", 300), {}, nil)
    assertEqual(lines.header, "Preview: Announce, to the group")
    assertTrue(lines.tooLong and lines.status:find("too long to send", 1, true) ~= nil)
end)

test("asks: TokenContext fills the tokens from a drop for who it goes to", function()
    local NS = T.newAddon()
    local rec = { link = "[Crown]", facts = { ilvl = 311, track = { name = "Hero" } },
        me = { ilvlDelta = 19 }, them = { ilvlDelta = -13 } }
    local ctx = NS.Asks.TokenContext("ask", rec, { name = "Seta" })
    assertEqual(ctx.player, "Seta")
    assertEqual(ctx.item, "[Crown]")
    assertEqual(ctx.ilvl, 311)
    assertEqual(ctx.track, "Hero")
    assertEqual(ctx.mygain, 19)
    assertEqual(ctx.gain, -13)
    assertEqual(NS.Asks.TokenContext("announce", nil, nil).player, nil, "no drop, no recipient")
end)
