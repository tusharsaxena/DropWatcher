-- tests/test_messaging.lua — modules/Messaging.lua, the messaging core (design spec §9.1-§9.2):
-- token expansion, the length limit, the one-ask guard, queueing under restriction, the flush
-- order, cancel, a failed send and its retry, and that no input ever makes it throw.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local cached
local function load()
    if not cached then
        local NS = T.newAddon()
        cached = { M = NS.Messaging, C = NS.Constants }
    end
    return cached.M, cached.C
end

local LINK = "|cffa335ee|Hitem:12345::::::::80:::::|h[Signet of the Tides]|h|r"

-- A full token context, with `over` merged in.
local function tokens(over)
    local t = { player = "Seta-Silvermoon", item = LINK, ilvl = 619, slot = "Finger", track = "Hero",
        gain = 4.26, mygain = 12 }
    for k, v in pairs(over or {}) do t[k] = v end
    return t
end

-- An ask request for drop `dropID` from `target`, with `over` merged in.
local function ask(dropID, target, over)
    local r = { kind = "ask", target = target or "Seta-Silvermoon", dropID = dropID or "d1",
        ctx = tokens({ player = target or "Seta-Silvermoon" }) }
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

local SEND = { canSend = true, now = 100 }
local HOLD = { canSend = false, now = 100 }

-- ---------------------------------------------------------------------------------------------
-- templates and tokens (spec §9.1)
-- ---------------------------------------------------------------------------------------------

test("messaging: the default templates are the spec §9.1 text, one per kind", function()
    local _, C = load()
    assertEqual(#C.MESSAGE_KINDS, 3)
    assertEqual(C.MESSAGE_TEMPLATES.ask,
        "Hi {player}, if you don't need {item}, could I have it? It'd be +{mygain} for me. No worries if not!")
    assertEqual(C.MESSAGE_TEMPLATES.offer, "Hi {player}, {item} is tradeable and looks like +{gain} for you. Want it?")
    assertEqual(C.MESSAGE_TEMPLATES.announce, "{item} is up for grabs, whisper me.")
    assertEqual(C.MESSAGE_MAX_LEN, 255)
    assertEqual(C.MESSAGE_FLUSH_INTERVAL, 1.5)
    assertEqual(#C.MESSAGE_TOKENS, 7)
end)

test("messaging: Template takes the owner's text, and the default for an empty or absent one", function()
    local M, C = load()
    assertEqual(M.Template("ask", nil), C.MESSAGE_TEMPLATES.ask)
    assertEqual(M.Template("ask", { ask = "" }), C.MESSAGE_TEMPLATES.ask)
    assertEqual(M.Template("ask", { ask = 42 }), C.MESSAGE_TEMPLATES.ask)
    assertEqual(M.Template("offer", { offer = "yours? {item}" }), "yours? {item}")
    assertNil(M.Template("shout", { shout = "x" }))
end)

test("messaging: Expand fills every token, and formats the gains as numbers", function()
    local M = load()
    local text = M.Expand("{player}|{item}|{ilvl}|{slot}|{track}|{gain}|{mygain}", tokens())
    assertEqual(text, "Seta-Silvermoon|" .. LINK .. "|619|Finger|Hero|4.3|12")
    assertEqual(M.Expand("+{gain}", tokens({ gain = 5.0 })), "+5")
    assertEqual(M.Expand("+{gain}", tokens({ gain = 0.04 })), "+0")
end)

test("messaging: unknown tokens are left as they are, and reported once each in order", function()
    local M = load()
    local text, unknown = M.Expand("{player} {foo} {Player} {foo} {bar}", tokens())
    assertEqual(text, "Seta-Silvermoon {foo} {Player} {foo} {bar}")
    assertEqual(#unknown, 3)
    assertEqual(unknown[1], "foo")
    assertEqual(unknown[2], "Player")
    assertEqual(unknown[3], "bar")
end)

test("messaging: a known token with no value reads as ?, and is reported as missing", function()
    local M = load()
    local text, unknown, missing = M.Expand("+{mygain} for {player}", { player = "Seta" })
    assertEqual(text, "+? for Seta")
    assertEqual(#unknown, 0)
    assertEqual(#missing, 1)
    assertEqual(missing[1], "mygain")
end)

test("messaging: a value with pattern characters is inserted literally", function()
    local M = load()
    assertEqual(M.Expand("{item}", { item = "100% [x]%1" }), "100% [x]%1")
end)

test("messaging: Preview gives the text, its length and the too-long flag", function()
    local M, C = load()
    local p = M.Preview(C.MESSAGE_TEMPLATES.announce, tokens())
    assertEqual(p.text, LINK .. " is up for grabs, whisper me.")
    assertEqual(p.length, #p.text)
    assertFalse(p.tooLong)
    local long = M.Preview(string.rep("a", 256), {})
    assertEqual(long.length, 256)
    assertTrue(long.tooLong)
    assertFalse(M.Preview(string.rep("a", 255), {}).tooLong)
end)

-- ---------------------------------------------------------------------------------------------
-- the request pipeline (spec §9.2 steps 1-3)
-- ---------------------------------------------------------------------------------------------

test("messaging: a request that can send answers send, with the expanded text, state ready", function()
    local M = load()
    local book = M.NewBook()
    local out = M.Request(book, ask("d1"), SEND)
    assertEqual(out.action, "send")
    assertEqual(out.ask.state, "ready")
    assertEqual(out.ask.text, M.Expand(M.Template("ask"), ask("d1").ctx))
    assertEqual(out.ask.kind, "ask")
    assertEqual(out.ask.target, "Seta-Silvermoon")
    assertEqual(out.ask.dropID, "d1")
    assertEqual(out.ask.at, 100)
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d1"), "ready")
end)

test("messaging: the owner's template and an edited text override the default", function()
    local M = load()
    local out = M.Request(M.NewBook(), ask("d1"), { canSend = true, templates = { ask = "pls {item}" } })
    assertEqual(out.ask.text, "pls " .. LINK)
    out = M.Request(M.NewBook(), ask("d1", nil, { text = "edited by hand" }), SEND)
    assertEqual(out.ask.text, "edited by hand")
end)

test("messaging: the one-ask guard refuses a repeat once sent, alreadyAsked", function()
    local M = load()
    local book = M.NewBook()
    local first = M.Request(book, ask("d1"), SEND)
    assertTrue(M.MarkSent(book, first.ask.key, 110) ~= nil)
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d1"), "sent")
    local again = M.Request(book, ask("d1"), SEND)
    assertEqual(again.action, "refuse")
    assertEqual(again.reason, "alreadyAsked")
    -- Another drop, another target or another kind is a different ask.
    assertEqual(M.Request(book, ask("d2"), SEND).action, "send")
    assertEqual(M.Request(book, ask("d1", "Bob-Silvermoon"), SEND).action, "send")
    assertEqual(M.Request(book, ask("d1", nil, { kind = "offer" }), SEND).action, "send")
end)

test("messaging: with oneAsk off a sent ask can be repeated; an ask in flight never can", function()
    local M = load()
    local book = M.NewBook()
    local first = M.Request(book, ask("d1"), { canSend = true, oneAsk = false })
    local dup = M.Request(book, ask("d1"), { canSend = true, oneAsk = false })
    assertEqual(dup.action, "refuse")
    assertEqual(dup.reason, "alreadyAsked")
    M.MarkSent(book, first.ask.key)
    assertEqual(M.Request(book, ask("d1"), { canSend = true, oneAsk = false }).action, "send")
end)

test("messaging: a message over 255 characters is refused tooLong, with its length", function()
    local M = load()
    local book = M.NewBook()
    local out = M.Request(book, ask("d1"), { canSend = true, templates = { ask = string.rep("x", 250) .. "{item}" } })
    assertEqual(out.action, "refuse")
    assertEqual(out.reason, "tooLong")
    assertEqual(out.length, 250 + #LINK)
    -- A refusal leaves no record: the button is still ready.
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d1"), "ready")
    assertEqual(M.Counts(book).asks, 0)
end)

test("messaging: the guard runs before the length check", function()
    local M = load()
    local book = M.NewBook()
    M.MarkSent(book, M.Request(book, ask("d1"), SEND).ask.key)
    local out = M.Request(book, ask("d1"), { canSend = true, templates = { ask = string.rep("x", 300) } })
    assertEqual(out.reason, "alreadyAsked")
end)

test("messaging: a malformed request is refused badRequest", function()
    local M = load()
    local book = M.NewBook()
    assertEqual(M.Request(book, ask("d1", nil, { kind = "shout" }), SEND).reason, "badRequest")
    assertEqual(M.Request(book, ask("d1", nil, { target = "" }), SEND).reason, "badRequest")
    assertEqual(M.Request(book, { kind = "ask", target = "Seta" }, SEND).reason, "badRequest")
    assertEqual(M.Request(book, nil, SEND).reason, "badRequest")
    assertEqual(M.Request(nil, ask("d1"), SEND).reason, "badRequest")
end)

test("messaging: under restriction a request is queued, state queued", function()
    local M = load()
    local book = M.NewBook()
    local out = M.Request(book, ask("d1"), HOLD)
    assertEqual(out.action, "queue")
    assertEqual(out.ask.state, "queued")
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d1"), "queued")
    assertEqual(M.Counts(book).queued, 1)
    local dup = M.Request(book, ask("d1"), HOLD)
    assertEqual(dup.reason, "alreadyAsked")
    assertEqual(M.Counts(book).queued, 1)
end)

-- ---------------------------------------------------------------------------------------------
-- send results, flush and cancel (spec §9.2 steps 4-6, the state side only)
-- ---------------------------------------------------------------------------------------------

test("messaging: a failed send is failed with its reason, and a retry is allowed", function()
    local M = load()
    local book = M.NewBook()
    local out = M.Request(book, ask("d1"), SEND)
    local failed = M.MarkFailed(book, out.ask.key, "throttled")
    assertEqual(failed.state, "failed")
    local state, reason = M.StateOf(book, "ask", "Seta-Silvermoon", "d1")
    assertEqual(state, "failed")
    assertEqual(reason, "throttled")
    local retry = M.Request(book, ask("d1"), SEND)
    assertEqual(retry.action, "send")
    assertEqual(retry.ask.state, "ready")
    assertNil(retry.ask.reason)
end)

test("messaging: MarkSent and MarkFailed act only on an ask that is ready", function()
    local M = load()
    local book = M.NewBook()
    assertNil(M.MarkSent(book, "nope"))
    assertNil(M.MarkFailed(book, "nope", "x"))
    local queued = M.Request(book, ask("d1"), HOLD)
    assertNil(M.MarkSent(book, queued.ask.key))
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d1"), "queued")
    local sent = M.Request(book, ask("d2"), SEND)
    M.MarkSent(book, sent.ask.key, 120)
    assertEqual(sent.ask.sentAt, 120)
    assertNil(M.MarkFailed(book, sent.ask.key, "late"))
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d2"), "sent")
end)

test("messaging: the flush hands back queued asks first in, first out, each ready to send", function()
    local M = load()
    local book = M.NewBook()
    M.Request(book, ask("d1"), HOLD)
    M.Request(book, ask("d2", "Bob-Silvermoon"), HOLD)
    M.Request(book, ask("d3"), HOLD)
    local a = M.Dequeue(book)
    assertEqual(a.dropID, "d1")
    assertEqual(a.state, "ready")
    assertEqual(M.Dequeue(book).dropID, "d2")
    assertEqual(M.Dequeue(book).dropID, "d3")
    assertNil(M.Dequeue(book))
    assertEqual(M.Counts(book).queued, 0)
end)

test("messaging: the flush triggers are a lift to can-send, ENCOUNTER_END and CHALLENGE_MODE_COMPLETED", function()
    local M = load()
    local book = M.NewBook()
    assertFalse(M.ShouldFlush(book, "ENCOUNTER_END", true))   -- nothing queued
    M.Request(book, ask("d1"), HOLD)
    assertTrue(M.ShouldFlush(book, "restrictionLifted", true))
    assertTrue(M.ShouldFlush(book, "ENCOUNTER_END", true))
    assertTrue(M.ShouldFlush(book, "CHALLENGE_MODE_COMPLETED", true))
    assertFalse(M.ShouldFlush(book, "restrictionLifted", false))
    assertFalse(M.ShouldFlush(book, "ENCOUNTER_END", false))
    assertFalse(M.ShouldFlush(book, "PLAYER_REGEN_ENABLED", true))
    assertFalse(M.ShouldFlush(nil, "ENCOUNTER_END", true))
end)

test("messaging: cancel drops a queued ask, which the flush then skips", function()
    local M = load()
    local book = M.NewBook()
    local one = M.Request(book, ask("d1"), HOLD)
    M.Request(book, ask("d2"), HOLD)
    local canceled = M.Cancel(book, one.ask.key)
    assertEqual(canceled.state, "canceled")
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d1"), "ready")
    assertEqual(M.Counts(book).queued, 1)
    assertEqual(M.Dequeue(book).dropID, "d2")
    assertNil(M.Dequeue(book))
    -- Only a queued ask cancels.
    assertNil(M.Cancel(book, one.ask.key))
    local sent = M.Request(book, ask("d3"), SEND)
    M.MarkSent(book, sent.ask.key)
    assertNil(M.Cancel(book, sent.ask.key))
    assertEqual(M.StateOf(book, "ask", "Seta-Silvermoon", "d3"), "sent")
end)

test("messaging: a canceled ask can be asked again", function()
    local M = load()
    local book = M.NewBook()
    M.Cancel(book, M.Request(book, ask("d1"), HOLD).ask.key)
    assertEqual(M.Request(book, ask("d1"), SEND).action, "send")
end)

test("messaging: a looter leaving drops every ask queued to them, and only theirs", function()
    local M = load()
    local book = M.NewBook()
    M.Request(book, ask("d1"), HOLD)
    M.Request(book, ask("d2", "Bob-Silvermoon"), HOLD)
    M.Request(book, ask("d3"), HOLD)
    local gone = M.CancelTarget(book, "Seta-Silvermoon")
    assertEqual(#gone, 2)
    assertEqual(gone[1].dropID, "d1")
    assertEqual(gone[2].dropID, "d3")
    assertEqual(M.Dequeue(book).target, "Bob-Silvermoon")
    assertNil(M.Dequeue(book))
    assertEqual(#M.CancelTarget(book, "Nobody"), 0)
    assertEqual(#M.CancelTarget(nil, "Seta-Silvermoon"), 0)
end)

test("messaging: Counts reports the registry for diagnostics", function()
    local M = load()
    local book = M.NewBook()
    M.MarkSent(book, M.Request(book, ask("d1"), SEND).ask.key)
    M.MarkFailed(book, M.Request(book, ask("d2"), SEND).ask.key, "x")
    M.Request(book, ask("d3"), HOLD)
    local c = M.Counts(book)
    assertEqual(c.asks, 3)
    assertEqual(c.sent, 1)
    assertEqual(c.failed, 1)
    assertEqual(c.queued, 1)
    assertEqual(M.Counts(nil).asks, 0)
end)

test("messaging: garbage never throws", function()
    local M = load()
    assertEqual(M.Expand(nil, nil), "")
    assertEqual(M.Expand(42, {}), "")
    assertEqual(M.Expand("{item}", "x"), "?")
    assertEqual(M.StateOf(nil, "ask", "x", "d"), "ready")
    assertEqual(M.Preview(nil, nil).length, 0)
    local out = M.Request(M.NewBook(), ask("d1", nil, { ctx = "x" }), nil)
    assertEqual(out.action, "send")
    assertNil(M.Dequeue(nil))
    assertNil(M.Cancel(nil, "k"))
end)
