-- tests/test_content_tabs.lua — the Content filter per tab (feedback-15 spec §1, DW-Q1): Drops offers
-- This instance and This session, History adds All, in both layouts; Drops' This session starts at
-- the stored session start (modules/Session.lua) turned into the client clock; the one Content
-- tooltip on both tabs; the `feed.content` row's two values and migration step 8, which turns a
-- stored `all` into `session` in every profile.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local T0 = 1800000000

local function shown(mode)
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    if mode then NS.SetWindowMode(mode) end
    return NS, NS.Window.Frame(), m
end

local function labels(dd)
    local out = {}
    for _, o in ipairs(dd._options or {}) do out[#out + 1] = o.label end
    return table.concat(out, ",")
end

local DROPS = "Content: This instance,Content: This session"
local HISTORY = "Content: This instance,Content: This session,Content: All"

test("content per tab: Drops offers This instance and This session, History adds All", function()
    local NS = T.enableAddon()
    local FB = NS.WindowFilterBar
    -- red under: one shared list, FB.VALUES.content (no FB.ContentValues; Drops took `all`)
    assertEqual(table.concat(FB.ContentValues("group"), ","), "instance,session")
    assertEqual(table.concat(FB.ContentValues("history"), ","), "instance,session,all")
    assertFalse(FB.Set("group", "content", "all"), "Drops has no All")
    assertEqual(FB.State("group").content, "session")
    assertTrue(FB.Set("group", "content", "instance"))
    assertTrue(FB.Set("history", "content", "session"))
    assertTrue(FB.Set("history", "content", "all"), "History keeps All")
    assertEqual(FB.State("history").content, "all")
end)

test("content per tab: the Content menu lists the active tab's values, in both layouts", function()
    for _, mode in ipairs({ "full", "compact" }) do
        local NS = shown(mode)
        local c = NS.WindowFilterBar.Controls()
        -- red under: the menu built once from the shared list (All on Drops)
        assertEqual(labels(c.content), DROPS, mode .. " Drops")
        assertEqual(c.content.text:GetText(), "Content: This session", mode)
        NS.Window.SelectTab("history")
        assertEqual(labels(c.content), HISTORY, mode .. " History")
        assertEqual(c.content.text:GetText(), "Content: All", mode .. ": History still opens on All")
        NS.Window.SelectTab("group")
        assertEqual(labels(c.content), DROPS, mode .. " Drops again")
    end
end)

test("content per tab: the Content tooltip is the same on both tabs and names each value", function()
    local NS = shown()
    local c = NS.WindowFilterBar.Controls()
    local want = "This instance shows the drops since you entered this instance or started this key. This session shows every drop since you logged in; a /reload keeps them. All (History only) shows every kept day."
    for _, tab in ipairs({ "group", "history" }) do
        NS.Window.SelectTab(tab)
        local tip = NS.Window.TooltipOf(c.content)
        assertEqual(tip[1], "Content", tab)
        -- red under: the old text ("…since the situation last changed…")
        assertEqual(tip[2], want, tab)
    end
end)

test("content per tab: Drops' This session starts at the stored session start, in the client clock", function()
    local NS, _, m = T.enableAddon()
    m.time = function() return T0 end
    m.__now = 1000
    NS.addon.db.char = { session = { start = T0 - 100 } }
    local tc = NS.Window.TabContext("group")
    -- red under: no sessionSince on Drops (This session passed every drop)
    assertTrue(type(tc.ctx.sessionSince) == "number", "Drops sets This session's start")
    local FB = NS.WindowFilterBar
    FB.Set("group", "content", "session")
    tc = NS.Window.TabContext("group")
    assertEqual(tc.hiddenBy({ id = 1, at = 850 }), "content", "a drop before the login is cut")
    assertNil(tc.hiddenBy({ id = 2, at = 950 }), "a drop since the login shows")
    assertNil(tc.hiddenBy({ id = 3, at = 899.5 }), "the login's own second (time() is whole seconds) shows")
    FB.Set("group", "content", "instance")
    tc = NS.Window.TabContext("group")
    assertNil(tc.hiddenBy({ id = 1, at = 850 }), "This instance reads the situation mark, not the login")
end)

test("content per tab: the feed.content row offers This instance and This session, default This session", function()
    local NS = T.enableAddon()
    local row = NS.SchemaRuntime.FindRow("feed.content")
    local values = {}
    for _, v in ipairs(row.values) do values[#values + 1] = v.value end
    -- red under: the row's third value, All
    assertEqual(table.concat(values, ","), "instance,session")
    assertEqual(row.default, "session")
    assertFalse(row.validate("all"), "All is refused")
    local FB = NS.WindowFilterBar
    local real = NS.Setting
    NS.Setting = function(path)
        if path == "feed.content" then return "all" end
        return real(path)
    end
    assertEqual(FB.Defaults("group").content, "session", "a stored All never reaches Drops")
    assertEqual(FB.Defaults("history").content, "all", "History opens on All (FB.TAB_FIXED)")
    NS.Setting = real
end)

-- Feedback-15 spec §1 (DW-Q1): Drops has no Content: All; a stored one becomes This session.
test("database: step 8 turns a stored feed.content all into session in every profile, and keeps the rest", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 7 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { feed = { content = "all", sort = "ilvl" } },
            Alt = { feed = { content = "instance" } },
            Bare = { window = { mode = "compact" } },
        },
    }
    -- red under: no step 8 (the stored All stays)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(p.Default.feed.content, "session")
    assertEqual(p.Default.feed.sort, "ilvl", "the other feed settings stay")
    assertEqual(p.Alt.feed.content, "instance", "This instance stays")
    assertNil(p.Bare.feed, "a profile that stored nothing gets nothing")
    assertEqual(NS.addon.db.global.schemaVersion, 8)
    assertEqual(NS.SCHEMA_VERSION, 8)
    local again = { feed = { content = "all" } }
    NS.MigrateContentAll(again); NS.MigrateContentAll(again)
    assertEqual(again.feed.content, "session", "idempotent")
    NS.MigrateContentAll(nil); NS.MigrateContentAll({}); NS.MigrateContentAll({ feed = 3 })
end)
