-- tests/test_char_filter.lua — the Character dropdown (feedback-2 spec §4, FB2-6), like Loot
-- History's: the pure core (modules/CharFilter.lua: Key, IconMarkup, Canonical, Passes, IsCurrent,
-- Label, Characters, Options); the recorder stamped on every drop record and kept by each History
-- entry; the filter bar's dropdown on all three tabs (All, Current, each character; Current by
-- default; multi-select); History filtered by who saw each drop, an older entry with no recorder
-- shown only under All; the session tabs never hiding a drop. Test mode's alt group is
-- test_test_mode's; a simulated run's recorder, test_sim_e2e's.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local ME = "Testchar-Testrealm"   -- the mock's player (tests/_kit/mock_base.lua __context, wow_mock's realm)

local function cf() return T.newAddon().CharFilter end

local function uncolored(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("char filter: a recorder key is Name-Realm; a name that carries its realm is kept", function()
    local CF = cf()
    assertEqual(CF.Key("Tiamât", "Frostmourne"), "Tiamât-Frostmourne")
    assertEqual(CF.Key("Bùnian-Azralon", "Testrealm"), "Bùnian-Azralon")
    assertEqual(CF.Key("Solo", nil), "Solo")
    assertNil(CF.Key(nil, "Realm")); assertNil(CF.Key("", "Realm"))
end)

test("char filter: the class icon is the classicon atlas as inline markup, nothing with no class", function()
    local CF = cf()
    assertEqual(CF.IconMarkup("DEATHKNIGHT"), "|A:classicon-deathknight:14:14|a")
    assertEqual(CF.IconMarkup(nil), ""); assertEqual(CF.IconMarkup(""), "")
end)

test("char filter: All passes everything; a recorder passes when chosen; none passes only All", function()
    local CF = cf()
    assertTrue(CF.Passes(nil, {}, ME), "All shows an entry with no recorder")
    assertTrue(CF.Passes("Alt-Testrealm", nil, ME))
    local cur = { [ME] = true }
    assertTrue(CF.Passes(ME, cur, ME))
    assertFalse(CF.Passes("Alt-Testrealm", cur, ME))
    assertFalse(CF.Passes(nil, cur, ME), "unknown: only All shows it")
    assertTrue(CF.Passes("Alt-Testrealm", { [ME] = true, ["Alt-Testrealm"] = true }, ME), "multi-select")
    assertTrue(CF.Passes(ME, { current = true }, ME), "the sentinel is you")
    assertFalse(CF.Passes(ME, { current = true }, nil), "with your key unknown, a named recorder is not you")
    assertTrue(CF.Passes(CF.CURRENT, { current = true }, nil), "a session drop is yours")
    assertTrue(CF.Passes(CF.CURRENT, cur, ME))
    assertFalse(CF.Passes(CF.CURRENT, { ["Alt-Testrealm"] = true }, ME))
end)

test("char filter: Canonical swaps the sentinel for your key once it is known, in a fresh set", function()
    local CF = cf()
    local set = { current = true }
    local out = CF.Canonical(set, ME)
    assertTrue(out[ME]); assertNil(out.current); assertTrue(set.current, "the set given is untouched")
    assertTrue(CF.Canonical(set, nil).current, "kept while your key is unknown")
    assertNil(next(CF.Canonical(nil, ME)))
end)

test("char filter: the label reads All, Current, the one character, or n selected", function()
    local CF = cf()
    assertEqual(CF.Label({}, ME), "Character: All")
    assertEqual(CF.Label({ [ME] = true }, ME), "Character: Current")
    assertEqual(CF.Label({ current = true }, nil), "Character: Current")
    assertEqual(CF.Label({ ["Alt-Testrealm"] = true }, ME), "Character: Alt-Testrealm")
    assertEqual(CF.Label({ [ME] = true, ["Alt-Testrealm"] = true }, ME), "Character: 2 selected")
    assertTrue(CF.IsCurrent({ [ME] = true }, ME)); assertFalse(CF.IsCurrent({}, ME))
    assertFalse(CF.IsCurrent({ [ME] = true, x = true }, ME))
end)

test("char filter: the characters are every recorder in the log once, you always, sorted by name", function()
    local CF = cf()
    local groups = {
        { drops = { { seenBy = "Zed-Testrealm", seenByClass = "ROGUE" }, { seenBy = ME, seenByClass = "MAGE" } } },
        { drops = { { seenBy = "Alt-Other", seenByClass = "PRIEST" }, {}, { seenBy = "Zed-Testrealm" } } },
    }
    local chars = CF.Characters(groups, ME, "MAGE")
    local keys = {}
    for i, c in ipairs(chars) do keys[i] = c.key end
    assertEqual(table.concat(keys, ","), "Alt-Other,Testchar-Testrealm,Zed-Testrealm")
    assertEqual(chars[3].class, "ROGUE")
    assertEqual(#CF.Characters(nil, ME, "MAGE"), 1, "you, with no log")
    assertEqual(#CF.Characters({}, nil, nil), 0)
end)

test("char filter: the menu is All, Current, then each character with its class icon and color", function()
    local CF = cf()
    local rows = CF.Options({ { key = "Alt-Other", class = "PRIEST" }, { key = ME, class = "MAGE" } }, ME,
        function(c) if c == "MAGE" then return 0.25, 0.78, 0.92 end end)
    assertEqual(rows[1].label, "Character: All"); assertEqual(rows[1].value, "all")
    assertEqual(rows[2].label, "Character: Current"); assertEqual(rows[2].value, "current")
    assertTrue(rows[2].isActive({ _selected = { [ME] = true } }), "lit while the selection is exactly you")
    assertFalse(rows[2].isActive({ _selected = {} }))
    assertEqual(rows[3].label, "|A:classicon-priest:14:14|a Alt-Other"); assertNil(rows[3].color)
    assertEqual(rows[4].value, ME); assertEqual(rows[4].color[1], 0.25)
end)

-- ── the recorder ────────────────────────────────────────────────────────────────────────────

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
        bindType = 1, stats = {} }
end

local function link(id) return ("|cffa335ee|Hitem:%d::::::::90:::::|h[Ring %d]|h|r"):format(id, id) end

local KEGHUNT_ROW = { guid = "Player-11-0000000B", name = "Keghunt", realm = "Thrall", class = "WARRIOR",
    classFile = "WARRIOR" }

local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "Den of Nalorakk", difficultyID = 8 }
    end })
    m.addItem(link(501), ring(600))
    m.setGroup({ KEGHUNT_ROW })
    NS.Roster.Refresh("test")
    return NS, m
end

test("recorder: you are Name-Realm and your class, read live and kept", function()
    local NS = T.enableAddon()
    local me = NS.CharFilter.Recorder()
    assertEqual(me.key, ME); assertEqual(me.class, "MAGE")
    assertEqual(NS.CharFilter.CurrentKey(), ME)
end)

test("recorder: unknown while the client has no realm yet, then known", function()
    local NS, _, m = T.enableAddon()
    local realm = m.normalizedRealm
    m.normalizedRealm = nil
    m.GetRealmName = function() return nil end
    assertNil(NS.CharFilter.Recorder())
    m.normalizedRealm = realm
    assertEqual(NS.CharFilter.CurrentKey(), ME)
end)

test("recorder: every drop record and its History entry say who saw it", function()
    local NS = party()
    local id = NS.LootFeed.Add(link(501), "Keghunt-Thrall")
    local rec = NS.LootFeed.Get(id)
    assertEqual(rec.seenBy, ME); assertEqual(rec.seenByClass, "MAGE")
    local e = NS.History.Log().groups[1].drops[1]
    assertEqual(e.seenBy, ME); assertEqual(e.seenByClass, "MAGE")
end)

test("recorder: a test placeholder is stamped too, and a stamp already there is kept", function()
    local NS = T.enableAddon()
    local rec = NS.CharFilter.Stamp({ seenBy = "Alt-Other" })
    assertEqual(rec.seenBy, "Alt-Other")
    assertEqual(NS.CharFilter.Stamp({}).seenBy, ME)
    local id = NS.LootFeed.AddTest({ link = link(501), looter = { name = "Seta" },
        group = { key = "t", label = "Boss", kind = "encounter" } })
    assertEqual(NS.LootFeed.Get(id).seenBy, ME)
end)

-- ── the filter bar ──────────────────────────────────────────────────────────────────────────

local function shown()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    return NS, m
end

local function pick(dd, value)
    dd:ToggleSelected(value)
    if dd.onMultiSelect then dd.onMultiSelect(dd._selected) end
end

local function values(dd)
    local out = {}
    for i, o in ipairs(dd._options) do out[i] = o.value end
    return table.concat(out, ",")
end

-- A kept log: you saw a boss, an alt saw a run, and a group from before the recorder existed.
local function seedHistory(NS)
    local function entry(id, by, class)
        return { itemLink = link(id), itemID = id, looter = "Seta", class = "PRIEST", outcome = "seen", at = os.time(),
            seenBy = by, seenByClass = class }
    end
    NS.History.Store().groups = {
        { key = "old", label = "Old boss", kind = "encounter", at = os.time() - 300, drops = { entry(601) } },
        { key = "alt", label = "Alt run", kind = "run", at = os.time() - 200,
          drops = { entry(602, "Alt-Testrealm", "PRIEST") } },
        { key = "me", label = "My boss", kind = "encounter", at = os.time() - 100, drops = { entry(603, ME, "MAGE") } },
    }
end

-- The groups with a drop shown (a header counting `0 shown` is left out here; see emptyHeaders).
local function headerLabels(NS)
    local out = {}
    for _, e in ipairs(NS.WindowHistory.Drawn().entries) do
        if e.kind == "header" and e.count > 0 then out[#out + 1] = e.group.label end
    end
    return table.concat(out, ",")
end

-- The headers that count `0 shown`, each with the filter its tooltip names.
local function emptyHeaders(NS)
    local out = {}
    for _, e in ipairs(NS.WindowHistory.Drawn().entries) do
        if e.kind == "header" and e.count == 0 then out[#out + 1] = e.group.label .. ":" .. e.hidden[1].why end
    end
    return table.concat(out, ",")
end

test("filter bar: the Character dropdown sits after Content, multi-select, Current by default", function()
    local NS = shown()
    local c = NS.WindowFilterBar.Controls()
    assertTrue(c.char ~= nil and c.char.multi)
    local _, rel = c.char:GetPoint(1)
    assertTrue(rel == c.content, "Character follows Content")
    assertEqual(c.char.text:GetText(), "Character: Current", "the default is Current (FB2-6)")
    assertTrue(NS.WindowFilterBar.State("group").char[ME], "the state holds your key")
    assertTrue(c.search:IsShown(), "the default width still leaves room for the search box")
    assertEqual(NS.Window.TooltipOf(c.char)[1], "Character")
end)

test("filter bar: Drops lists All, Current and you alone; History every recorder", function()
    local NS = shown()
    seedHistory(NS)
    local c = NS.WindowFilterBar.Controls()
    assertEqual(values(c.char), "all,current," .. ME)
    assertTrue(c.char:IsEnabled(), "Drops honors it")
    NS.Window.SelectTab("history")
    assertEqual(values(c.char), "all,current,Alt-Testrealm," .. ME, "unknown is not listed")
    local alt = c.char._options[3]
    assertTrue(alt.label:find("classicon-priest", 1, true) ~= nil, "the class icon")
    assertTrue(alt.color ~= nil, "the class color")
end)

test("filter bar: History shows your drops under Current, every recorder chosen, and unknown only under All", function()
    local NS = shown()
    seedHistory(NS)
    NS.Window.SelectTab("history")
    local c = NS.WindowFilterBar.Controls()
    assertEqual(headerLabels(NS), "My boss", "Current: yours alone")
    -- red under: a group the filter hides whole is left out (the upgrade's kept groups vanish)
    assertEqual(emptyHeaders(NS), "Old boss:char", "a group with no recorder is still counted: 1 drop · 0 shown")
    pick(c.char, "Alt-Testrealm")
    assertEqual(c.char.text:GetText(), "Character: 2 selected")
    assertEqual(headerLabels(NS), "My boss,Alt run")
    pick(c.char, ME)
    assertEqual(uncolored(c.char.text:GetText()), "|A:classicon-priest:14:14|a Alt-Testrealm", "one character: its row")
    assertEqual(headerLabels(NS), "Alt run")
    assertEqual(emptyHeaders(NS), "Old boss:char", "a group another character saw is the question asked: left out")
    pick(c.char, "current")
    assertEqual(c.char.text:GetText(), "Character: Current", "Current selects exactly you")
    assertTrue(NS.WindowFilterBar.State("history").char[ME])
    pick(c.char, "all")
    assertEqual(c.char.text:GetText(), "Character: All")
    assertEqual(headerLabels(NS), "My boss,Alt run,Old boss", "All shows the unknown group too")
    assertEqual(emptyHeaders(NS), "")
end)

test("filter bar: a drop the Character filter hides is named in the header's reason", function()
    local NS = T.newAddon()
    local FB = NS.WindowFilterBar
    local st = { view = {}, char = { [ME] = true }, content = "all", search = "", sort = "newest" }
    local ctx = { current = ME }
    assertEqual(FB.HiddenBy({ seenBy = "Alt-Testrealm" }, st, ctx, FB.HONORS.history), "char")
    assertEqual(FB.HiddenBy({}, st, ctx, FB.HONORS.history), "char", "no recorder: hidden under Current")
    assertNil(FB.HiddenBy({ seenBy = ME }, st, ctx, FB.HONORS.history))
    assertNil(FB.HiddenBy({ seenBy = "Alt-Testrealm" }, st, ctx, FB.HONORS.group), "a session tab's drops are yours")
    assertEqual(FB.HiddenBy({}, { char = { ["Alt-Testrealm"] = true } }, ctx, FB.HONORS.group), "char",
        "a session tab's drop is yours, never an alt's")
    assertEqual(FB.ReasonLabel("char", st), "Character: Current")
end)

test("filter bar: a Character selection is a set of keys; anything else is refused", function()
    local NS = T.enableAddon()
    local FB = NS.WindowFilterBar
    assertFalse(FB.Set("history", "char", "all"))
    assertFalse(FB.Set("history", "char", { [ME] = "yes" }))
    assertFalse(FB.Set("history", "char", { [1] = true }))
    assertTrue(FB.Set("history", "char", {}))
    assertNil(next(FB.State("history").char))
    assertTrue(FB.Set("history", "char", { current = true }))
    assertTrue(FB.State("history").char[ME], "the sentinel becomes your key")
    assertFalse(FB.Set("history", "char", { [ME] = true }), "the same set changes nothing")
end)

test("filter bar: Drops keeps every drop under any Character choice it offers", function()
    local NS = shown()
    local c = NS.WindowFilterBar.Controls()
    local tc = NS.Window.TabContext("group")
    assertEqual(tc.ctx.current, ME)
    assertTrue(tc.matches({ id = 1, at = 1, seenBy = ME, looter = { name = "Seta" } }))
    pick(c.char, "all")
    assertTrue(NS.Window.TabContext("group").matches({ id = 1, at = 1, looter = { name = "Seta" } }))
end)

test("filter bar: each sync reuses the Character and View rows; HistoryChanged rebuilds History's", function()
    local NS = shown()
    seedHistory(NS)
    NS.Window.SelectTab("history")
    local c = NS.WindowFilterBar.Controls()
    local chars, views = c.char._options, c.view._options
    NS.Window.Refresh()
    assertTrue(c.char._options == chars, "an unchanged log keeps its Character rows (the refresh pair's ceiling)")
    assertTrue(c.view._options == views, "a tab's View rows never change")
    local g = NS.History.Store().groups[1]
    g.drops[#g.drops + 1] = { itemLink = link(604), itemID = 604, looter = "Seta", class = "PRIEST",
        outcome = "seen", at = os.time(), seenBy = "Bank-Testrealm", seenByClass = "ROGUE" }
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
    NS.Window.Refresh()
    assertEqual(values(c.char), "all,current,Alt-Testrealm,Bank-Testrealm," .. ME, "a new recorder is listed")
end)
