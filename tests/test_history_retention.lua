-- tests/test_history_retention.lua — Keep history for (feedback-2 spec §5, FB2-7): the pure core
-- (the labels, the newest entry, the count, the prune), the row (account-wide, its values), the
-- confirmation on a shorter window (Yes prunes, No writes the last agreed window back, a window
-- that deletes nothing is taken at once), the login prune (once per session, deferred, taken back
-- by the stand-down), the footer and the diagnostics line, and test mode's older sample group.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local DAY = 86400
local PATH = "global.history.retentionDays"

local function R() return T.newAddon().HistoryRetention end

-- A group whose entries are `ages` days old (its own `at` the oldest).
local function group(key, now, ages)
    local g = { key = key, label = key, at = now - ages[1] * DAY, drops = {} }
    for i, age in ipairs(ages) do
        g.drops[i] = { itemLink = "x", outcome = "seen", at = now - age * DAY, seenBy = "Testchar-Testrealm" }
    end
    return g
end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("retention: the labels, the choices and the footer", function()
    local Re = R()
    assertEqual(Re.Label(30), "30 days"); assertEqual(Re.Label(0), "Never delete")
    local values = {}
    for i, c in ipairs(Re.Choices()) do values[i] = c.value end
    assertEqual(table.concat(values, ","), "7,14,30,60,90,180,0")
    assertEqual(Re.FooterText(4, 7, 30), "4 groups, 7 drops · kept for 30 days")
    assertEqual(Re.FooterText(4, 7, 0), "4 groups, 7 drops · kept forever")
end)

test("retention: a group's age is its newest entry's, else its own", function()
    local Re = R()
    assertEqual(Re.NewestAt({ at = 5, drops = { { at = 9 }, { at = 7 } } }), 9)
    assertEqual(Re.NewestAt({ at = 5, drops = {} }), 5)
    assertEqual(Re.NewestAt({}), 0)
end)

test("retention: Count says what a window deletes, and deletes nothing; Prune deletes it", function()
    local Re = R()
    local now = 100 * DAY
    local oldA, mixed, fresh = group("old", now, { 40, 35 }), group("mixed", now, { 50, 10 }), group("new", now, { 1 })
    local hist = { groups = { oldA, mixed, fresh } }
    assertEqual(select(1, Re.Count(hist, 30, now)), 1, "a group with a recent drop stays whole")
    assertEqual(select(2, Re.Count(hist, 30, now)), 2)
    assertEqual(#hist.groups, 3, "counting deletes nothing")
    assertEqual(Re.Count(hist, 7, now), 2)
    assertEqual(Re.Count(hist, 0, now), 0, "Never delete")
    -- red under: prune by count (the retired cap) or by the group's own first `at`
    local groups, drops = Re.Prune(hist, 30, now)
    assertEqual(groups, 1); assertEqual(drops, 2)
    assertEqual(#hist.groups, 2); assertEqual(hist.groups[1].key, "mixed")
    assertTrue(oldA.drops[1].gone and oldA.drops[2].gone, "deleted entries leave the session index")
    assertEqual(Re.Prune(hist, 0, now), 0)
    assertEqual(Re.Prune(hist, 7, now), 1); assertEqual(hist.groups[1].key, "new")
    assertEqual(Re.Prune(nil, 7, now), 0)
end)

-- ── the row and the confirmation ────────────────────────────────────────────────────────────

-- An enabled instance whose account log holds an old group (40 days), a mid one (20) and a new one.
local function withLog()
    local NS, _, m = T.enableAddon()
    local now = m.time()
    NS.History.Store().groups = { group("old", now, { 40 }), group("mid", now, { 20, 19 }), group("new", now, { 0 }) }
    local seen = { changed = 0 }
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.HISTORY_CHANGED, function() seen.changed = seen.changed + 1 end)
    return NS, m, seen
end

local function keys(NS)
    local out = {}
    for i, g in ipairs(NS.History.Store().groups) do out[i] = g.key end
    return table.concat(out, ",")
end

test("retention row: account-wide, on the Window page, the listed windows only", function()
    local NS = T.enableAddon()
    local row = NS.SchemaRuntime.FindRow(PATH)
    assertEqual(row.label, "Keep history for"); assertEqual(row.page, "window")
    assertEqual(row.default, 30)
    assertEqual(NS.HistoryRetention.Days(), 30)
    assertFalse(NS.SchemaRuntime.Set(PATH, 45))
    assertTrue(NS.addon.db.profile.history == nil, "nothing lands in the profile")
end)

test("retention: a longer window, or one that deletes nothing, is taken at once", function()
    local NS, m = withLog()
    assertTrue(NS.SchemaRuntime.Set(PATH, 90))
    assertTrue(NS.SchemaRuntime.Set(PATH, 60))
    assertEqual(#m.popupsShown, 0, "nothing to delete, nothing to ask")
    assertEqual(keys(NS), "old,mid,new")
end)

test("retention: a shorter window that deletes asks first; Yes prunes", function()
    local NS, m, seen = withLog()
    assertTrue(NS.SchemaRuntime.Set(PATH, 14))
    local shown = m.popupsShown[#m.popupsShown]
    assertEqual(shown[1], NS.HistoryRetention.POPUP)
    assertEqual(shown[2], "2 groups (3 drops)"); assertEqual(shown[3], "14 days")
    assertEqual(shown[4].days, 14)
    local popup = m.StaticPopupDialogs[NS.HistoryRetention.POPUP]
    assertEqual(popup.preferredIndex, 3)
    assertEqual(popup.text:format(shown[2], shown[3]),
        "This deletes 2 groups (3 drops) older than 14 days. This cannot be undone.")
    -- red under: prune in the row's onChange, before the answer
    assertEqual(keys(NS), "old,mid,new", "nothing deleted before the answer")
    popup.OnAccept(nil, shown[4])
    assertEqual(keys(NS), "new")
    assertEqual(NS.addon.db.global.history.retentionDays, 14)
    assertTrue(seen.changed >= 1, "HistoryChanged")
end)

test("retention: No writes the last agreed window back and deletes nothing", function()
    local NS, m = withLog()
    assertTrue(NS.SchemaRuntime.Set(PATH, 7))
    local shown = m.popupsShown[#m.popupsShown]
    local popup = m.StaticPopupDialogs[NS.HistoryRetention.POPUP]
    assertEqual(NS.addon.db.global.history.retentionDays, 30, "the store keeps the agreed window while asking")
    popup.OnCancel(nil, shown[4], "override")
    assertEqual(#m.popupsShown, 1, "an override is not the player's No")
    popup.OnCancel(nil, shown[4], "clicked")
    assertEqual(NS.addon.db.global.history.retentionDays, 30, "the confirmed window is back")
    assertEqual(keys(NS), "old,mid,new")
    assertEqual(#m.popupsShown, 1, "the write-back asks nothing")
end)

test("retention: an unanswered popup (a /reload with it open) leaves nothing to prune at the next login", function()
    local NS, m = withLog()
    assertTrue(NS.SchemaRuntime.Set(PATH, 7))
    assertEqual(m.popupsShown[#m.popupsShown][1], NS.HistoryRetention.POPUP)
    -- red under: the shorter window stays stored until the popup is answered
    assertEqual(NS.addon.db.global.history.retentionDays, 30, "nothing unconfirmed is stored")
    -- the next session: Sync at OnInitialize, then the deferred login prune
    NS.HistoryRetention.Sync()
    m.__fire("PLAYER_ENTERING_WORLD", true, false)
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    assertEqual(keys(NS), "mid,new", "only what the agreed 30 days put out of reach")
end)

-- M10 review (FB2-10): a popup left open while the player changes the window again answers for
-- that older choice only if it is still the one pending.
test("retention: a later change that deletes nothing retires the open popup; its Yes does nothing", function()
    local NS, m = withLog()
    assertTrue(NS.SchemaRuntime.Set(PATH, 7))
    local stale = m.popupsShown[#m.popupsShown]
    local popup = m.StaticPopupDialogs[NS.HistoryRetention.POPUP]
    assertTrue(NS.SchemaRuntime.Set(PATH, 60))
    assertEqual(m.popupsHidden[#m.popupsHidden], NS.HistoryRetention.POPUP, "the stale popup is taken down")
    -- red under: the old popup's Yes re-applies 7 days after the player chose 60
    popup.OnAccept(nil, stale[4])
    assertEqual(NS.addon.db.global.history.retentionDays, 60, "the latest choice stands")
    assertEqual(keys(NS), "old,mid,new", "nothing deleted")
    popup.OnCancel(nil, stale[4], "clicked")
    assertEqual(NS.addon.db.global.history.retentionDays, 60, "a stale No writes nothing back")
end)

test("retention: of two deleting changes, only the latest popup's answer counts", function()
    local NS, m = withLog()
    assertTrue(NS.SchemaRuntime.Set(PATH, 7))
    local first = m.popupsShown[#m.popupsShown]
    assertTrue(NS.SchemaRuntime.Set(PATH, 14))
    local latest = m.popupsShown[#m.popupsShown]
    local popup = m.StaticPopupDialogs[NS.HistoryRetention.POPUP]
    popup.OnAccept(nil, first[4])
    assertEqual(keys(NS), "old,mid,new", "the superseded choice deletes nothing")
    popup.OnAccept(nil, latest[4])
    assertEqual(keys(NS), "new")
    assertEqual(NS.addon.db.global.history.retentionDays, 14)
end)

test("retention: headless (no popup), a shorter window prunes at once", function()
    local NS, m = withLog()
    m.StaticPopup_Show = nil
    assertTrue(NS.SchemaRuntime.Set(PATH, 30))
    assertTrue(NS.SchemaRuntime.Set(PATH, 7))
    assertEqual(keys(NS), "new")
end)

-- ── the login prune ─────────────────────────────────────────────────────────────────────────

test("retention: the login prune runs once, deferred off the login, over the account's log", function()
    local NS, m, seen = withLog()
    m.__fire("PLAYER_ENTERING_WORLD", true, false)
    assertEqual(keys(NS), "old,mid,new", "not on the event itself")
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    -- red under: no login prune (the old group outlives the 30-day window)
    assertEqual(keys(NS), "mid,new")
    assertEqual(seen.changed, 1)
    NS.History.Store().groups[1] = group("older", m.time(), { 99 })
    m.__fire("PLAYER_ENTERING_WORLD", false, false)
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    assertEqual(keys(NS), "older,new", "once per session")
end)

test("retention: the stand-down takes the pending prune back; the stand-up arms it again", function()
    local NS, m = withLog()
    m.__fire("PLAYER_ENTERING_WORLD", true, false)
    NS.addon:OnSlashCommand("disable")
    m.advance(NS.HistoryRetention.CLEANUP_DELAY + 1)
    assertEqual(keys(NS), "old,mid,new", "nothing written while disabled")
    NS.addon:OnSlashCommand("enable")
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    assertEqual(keys(NS), "mid,new")
end)

-- M10 review (FB2-10): an addon that starts disabled never hears the session's first
-- PLAYER_ENTERING_WORLD, so the prune must arm when it is enabled later in the session.
test("retention: enabled later in a session that started disabled, the prune still runs once", function()
    local NS, _, m = T.bootAddon()
    NS.addon.db.profile.enabled = false
    NS.addon:OnEnable()
    local now = m.time()
    NS.History.Store().groups = { group("old", now, { 40 }), group("new", now, { 0 }) }
    m.__fire("PLAYER_ENTERING_WORLD", true, false)
    m.advance(NS.HistoryRetention.CLEANUP_DELAY + 1)
    assertEqual(keys(NS), "old,new", "nothing written while disabled")
    NS.addon:OnSlashCommand("enable")
    assertEqual(keys(NS), "old,new", "deferred, not on the stand-up itself")
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    -- red under: loginSeen only from PLAYER_ENTERING_WORLD (the old group outlives the session)
    assertEqual(keys(NS), "new")
    NS.History.Store().groups[1] = group("older", m.time(), { 99 })
    NS.addon:OnSlashCommand("disable")
    NS.addon:OnSlashCommand("enable")
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    assertEqual(keys(NS), "older", "still once per session")
end)

test("retention: Never delete keeps every group at login", function()
    local NS, m = withLog()
    NS.addon.db.global.history.retentionDays = 0
    m.__fire("PLAYER_ENTERING_WORLD", true, false)
    m.advance(NS.HistoryRetention.CLEANUP_DELAY)
    assertEqual(keys(NS), "old,mid,new")
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────

test("retention: in test mode a shorter window prunes test mode's older sample, not the account's", function()
    local NS, m = T.enableAddon()
    local now = m.time()
    m.seedGearJournal()
    NS.History.Store().groups = { group("kept", now, { 3 }) }
    NS.SetTestMode(true)
    local H = NS.History
    assertEqual(#H.Groups(), 3, "test mode's samples")
    assertTrue(NS.SchemaRuntime.Set(PATH, 7))
    local shown = m.popupsShown[#m.popupsShown]
    assertEqual(shown[1], NS.HistoryRetention.POPUP, "the alt's sample group is older than 7 days")
    m.StaticPopupDialogs[NS.HistoryRetention.POPUP].OnAccept(nil, shown[4])
    assertEqual(#H.Groups(), 2)
    assertEqual(#H.Store().groups, 1, "the account's three-day-old group stays")
    NS.Window.SelectTab("history")
    assertEqual(NS.WindowHistory.Drawn().strip.info:GetText(), "2 groups, 7 drops · kept for 7 days")
    NS.SetTestMode(false)
end)
