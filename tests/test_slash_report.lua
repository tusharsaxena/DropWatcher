-- tests/test_slash_report.lua — the report verbs write to the debug console with one chat pointer
-- (debug-logging-§15, slash-commands-§4 "Chat or the console", the owner's ruling of 2026-11-08,
-- LibKa0s#79). A report is a multi-line read-out the player asks for: `/dw situation` and the item
-- lists' `list` (`/dw whitelist list`, `/dw blacklist list`, and either bare verb). Each goes through
-- NS.DebugLog:Report, ungated, so it lands with logging off and leaves it off; the console is
-- revealed when hidden; chat gets exactly one pointer line. A usage or refusal line inside a report
-- verb stays in chat and writes no report. `/dw scan` is not a report: it acts and answers one line.
-- Library-absent, the stub streams the report to chat with no pointer.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local POINTER = "^|cff00ffff%[DW%]|r (.-): (%d+) lines written to the debug console%. Use Copy to share it%.$"

local REPORTS = {
    { line = "situation",      title = "situation" },
    { line = "whitelist list", title = "whitelist list" },
    { line = "whitelist",      title = "whitelist list" },
    { line = "blacklist list", title = "blacklist list" },
    { line = "blacklist",      title = "blacklist list" },
}

-- Run one slash line; answer the chat lines and the console lines it appended.
local function run(NS, m, line)
    local from = #NS.DebugLog.buffer
    m.prints = {}
    NS.addon:OnSlashCommand(line)
    local console = {}
    for i = from + 1, #NS.DebugLog.buffer do console[#console + 1] = NS.DebugLog.buffer[i] end
    return m.prints, console
end

test("slash report: every report verb writes to the console with logging off, one chat pointer", function()
    local NS, _, m = T.enableAddon()
    NS.ItemLists.Add("whitelist", "300")
    assertFalse(NS.DebugLog:IsEnabled(), "trace logging is off")
    for _, r in ipairs(REPORTS) do
        local chat, console = run(NS, m, r.line)
        -- red under: the report printed to chat line by line (the pre-#79 routing)
        assertEqual(#chat, 1, "/dw " .. r.line .. ": exactly one chat line: " .. table.concat(chat, " | "))
        local title, n = tostring(chat[1]):match(POINTER)
        assertEqual(title, r.title, "/dw " .. r.line .. ": the pointer names the report: " .. tostring(chat[1]))
        assertEqual(tonumber(n), #console, "/dw " .. r.line .. ": and counts the lines it wrote")
        assertTrue(#console >= 2, "/dw " .. r.line .. ": a header and a body")
        assertTrue(console[1]:find("[Report] /dw " .. r.title, 1, true) ~= nil,
            "/dw " .. r.line .. ": the header names the command: " .. tostring(console[1]))
        -- red under: a report written through the gated sink, which drops it with logging off
        assertFalse(NS.DebugLog:IsEnabled(), "/dw " .. r.line .. ": logging is left off")
    end
end)

test("slash report: the reports carry the read-outs chat used to carry", function()
    local NS, _, m = T.enableAddon{ mock = function(mk)
        mk.__context.inInstance, mk.__context.instanceType = true, "party"
        mk.instance = { name = "The Rookery", difficultyID = 2 }
    end }
    NS.ItemLists.Add("blacklist", "300")
    local _, console = run(NS, m, "situation")
    assertEqual(#console, 4, "the header and the three situation lines")
    assertTrue(console[2]:find("(dungeon)", 1, true) ~= nil, console[2])
    assertTrue(console[3]:find("in instance yes · type party · difficulty 2", 1, true) ~= nil, console[3])
    _, console = run(NS, m, "blacklist list")
    local text = table.concat(console, "\n")
    assertTrue(text:find("Never watch (1)", 1, true) ~= nil, text)
    assertTrue(text:find("  item 300", 1, true) ~= nil, text)
    _, console = run(NS, m, "whitelist")
    text = table.concat(console, "\n")
    assertTrue(text:find("Always watch (0)", 1, true) ~= nil and text:find("(none)", 1, true) ~= nil, text)
end)

test("slash report: a hidden console is revealed, a shown one stays shown", function()
    local NS, _, m = T.enableAddon()
    NS.DebugLog:Hide()
    assertFalse(NS.DebugLog:IsShown(), "hidden before the report")
    -- red under: a report that writes without revealing the console
    run(NS, m, "situation")
    assertTrue(NS.DebugLog:IsShown(), "the report reveals the console")
    run(NS, m, "whitelist list")
    assertTrue(NS.DebugLog:IsShown(), "and a second report leaves it shown")
end)

test("slash report: usage and refusals inside a report verb stay in chat and write nothing", function()
    local NS, _, m = T.enableAddon()
    local chat, console = run(NS, m, "blacklist drop 300")
    assertEqual(#console, 0, "the usage line writes no report")
    assertEqual(#chat, 1)
    assertTrue(chat[1]:find("/dw blacklist add|remove|list", 1, true) ~= nil, chat[1])
    chat, console = run(NS, m, "whitelist add 300")
    assertEqual(#console, 0, "an acknowledgment is not a report")
    assertTrue(chat[1]:find("Added item 300 to Always watch.", 1, true) ~= nil, chat[1])
    NS.addon:OnSlashCommand("disable")
    chat, console = run(NS, m, "situation")
    assertEqual(#console, 0, "the disabled refusal writes no report")
    assertEqual(#chat, 1); assertTrue(chat[1]:find("is disabled", 1, true) ~= nil, chat[1])
end)

test("slash report: `scan` is an action with a one-line answer, not a report", function()
    local NS, _, m = T.enableAddon()
    local chat, console = run(NS, m, "scan")
    assertEqual(#chat, 1, table.concat(chat, " | "))
    assertTrue(chat[1]:find("lines written to the debug console", 1, true) == nil, chat[1])
    assertEqual(#console, 0)
end)

test("slash report: library-absent, the stub streams the report to chat with no pointer", function()
    local NS, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    NS.addon:OnSlashCommand("situation")
    assertEqual(#m.prints, 3, "the three situation lines, in chat: " .. table.concat(m.prints, " | "))
    for _, line in ipairs(m.prints) do
        assertTrue(line:find("lines written to the debug console", 1, true) == nil, "no pointer: " .. line)
    end
    m.prints = {}
    NS.addon:OnSlashCommand("whitelist list")
    assertEqual(#m.prints, 2, table.concat(m.prints, " | "))
    assertTrue(m.prints[1]:find("Always watch (0)", 1, true) ~= nil, m.prints[1])
end)
