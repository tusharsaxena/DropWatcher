local _, NS = ...
-- modules/Messaging.lua — the messaging core (design spec §9.1-§9.2): templates, tokens, the
-- length check, the one-ask guard and the send queue's state machine.
--
-- PURE. It makes no WoW API call, sends nothing and reads no saved variable: the edge
-- (modules/Asks.lua) holds one book (NewBook), passes the restriction answer and the owner's templates in `opts`,
-- sends what Request or Dequeue hands it, and reports the result with MarkSent or MarkFailed. The
-- defaults are data in core/Constants.lua (C.MESSAGE_*).
--
--   req  = { kind = "ask" | "offer" | "announce", target, dropID, ctx = token values, text?,
--            template? = the template to fill instead of the kind's (an ask's `transmog`) }
--   opts = { canSend = true, oneAsk = true, templates = { [kind] = text }, now }
--
-- Request answers { action = "send" | "queue" | "refuse", ask, reason, length }. An ask record is
-- { key, kind, target, dropID, text, state, reason, at, sentAt }, and its state is "ready" (about
-- to be sent, or never asked), "queued", "sent" or "failed". A refusal (alreadyAsked, tooLong,
-- badRequest) leaves no record. A canceled ask leaves the book, so its button is ready again.
--
-- It NEVER THROWS on garbage: bad requests are refused, bad templates expand to "".

NS.Messaging = NS.Messaging or {}
local M = NS.Messaging
local C = NS.Constants

local function isTable(v) return type(v) == "table" end

local function nonEmpty(v) return type(v) == "string" and v ~= "" end

local KNOWN = {}
for _, name in ipairs(C.MESSAGE_TOKENS) do KNOWN[name] = true end

local KIND = {}
for _, kind in ipairs(C.MESSAGE_KINDS) do KIND[kind] = true end

local TEMPLATE = {}
for _, name in ipairs(C.MESSAGE_TEMPLATES) do TEMPLATE[name] = true end

-- ---------------------------------------------------------------------------------------------
-- Templates and tokens (spec §9.1)
-- ---------------------------------------------------------------------------------------------

--- The template named `name` (a kind, or `transmog`): the owner's text in `templates` when it is
--- a non-empty string, else the default (defaults/Profile.lua's `messages.templates`). Nil for an
--- unknown name.
function M.Template(name, templates)
    if not TEMPLATE[name] then return nil end
    local own = isTable(templates) and templates[name] or nil
    if nonEmpty(own) then return own end
    return NS.C.PROFILE.messages.templates[name]
end

-- The verdicts for you an ask is offered for, with the plain ask template.
local USEFUL = { upgrade = true, sidegrade = true }

--- Which template an ask for `drop` fills (design spec §4 transmog-known, §9.1): `ask` when the
--- drop is an upgrade or a sidegrade for you; else `transmog` when `transmogAsk` is on and you
--- have not collected its appearance (facts.transmogKnown is false, not merely unknown); else nil,
--- no ask is offered. Reads the drop record alone.
--- @param drop table a feed record
--- @param transmogAsk boolean the `messages.transmogAsk` setting
--- @return string|nil
function M.AskTemplate(drop, transmogAsk)
    if not isTable(drop) then return nil end
    local v = isTable(drop.me) and drop.me.verdict or nil
    if USEFUL[v] then return "ask" end
    local f = isTable(drop.facts) and drop.facts or nil
    if transmogAsk == true and f and f.transmogKnown == false then return "transmog" end
    return nil
end

-- A number with one decimal at most, and none when it is whole ("5", "4.3"); else tostring.
local function formatValue(v)
    if type(v) ~= "number" then return tostring(v) end
    if v == math.floor(v) then return string.format("%d", v) end
    local s = string.format("%.1f", v):gsub("%.0$", "")
    return s
end

local function noteOnce(list, seen, name)
    if not seen[name] then
        seen[name] = true
        list[#list + 1] = name
    end
end

--- Fills each `{token}` of `template` from `ctx`. An unknown token is left as it is; a known one
--- with no value reads "?". A `+` right before a token whose value is words, not a number (an
--- empty-slot upgrade's gain), is dropped, so `+{mygain}` reads `an empty-slot upgrade`. Answers
--- the text, the unknown tokens and the missing ones (each list in order of first appearance, once
--- each).
function M.Expand(template, ctx)
    local unknown, missing, seen = {}, {}, {}
    if type(template) ~= "string" then return "", unknown, missing end
    ctx = isTable(ctx) and ctx or {}
    local text = template:gsub("(%+?){(%w+)}", function(plus, name)
        if not KNOWN[name] then
            noteOnce(unknown, seen, name)
            return nil
        end
        local v = ctx[name]
        if v == nil then
            noteOnce(missing, seen, name)
            return plus .. "?"
        end
        if type(v) ~= "number" then plus = "" end
        return plus .. formatValue(v)
    end)
    return text, unknown, missing
end

--- The settings preview: { text, length, tooLong, unknown, missing } for `template` over `ctx`.
--- The length is in bytes, which is what the chat limit counts.
function M.Preview(template, ctx)
    local text, unknown, missing = M.Expand(template, ctx)
    return { text = text, length = #text, tooLong = #text > C.MESSAGE_MAX_LEN,
             unknown = unknown, missing = missing }
end

-- ---------------------------------------------------------------------------------------------
-- The book: the one-ask registry and the queue (spec §9.2)
-- ---------------------------------------------------------------------------------------------

--- An empty book: `asks` by key, and `queue`, the queued keys first in, first out.
function M.NewBook()
    return { asks = {}, queue = {} }
end

--- The registry key of one (kind, target, dropID).
function M.Key(kind, target, dropID)
    return tostring(kind) .. "\031" .. tostring(target) .. "\031" .. tostring(dropID)
end

local function isBook(book) return isTable(book) and isTable(book.asks) and isTable(book.queue) end

-- How far a state has come, for M.FurthestState: a sent one outranks a queued one, a queued one a
-- failed one.
local STATE_RANK = { failed = 1, queued = 2, sent = 3 }

--- The state of one ask and its reason ("ready" when it was never asked, or was canceled).
function M.StateOf(book, kind, target, dropID)
    local a = isBook(book) and book.asks[M.Key(kind, target, dropID)] or nil
    if not a then return "ready" end
    return a.state, a.reason
end

--- The furthest state any `kind` ask for one drop has reached, whoever it went to: `sent`, else
--- `queued`, else `failed`, else `ready` (My drops' Offer button: whether an offer is out;
--- feedback-4 spec §1).
--- @param book table
--- @param kind string
--- @param dropID any
--- @return string
function M.FurthestState(book, kind, dropID)
    local best, rank = "ready", 0
    if not isBook(book) then return best end
    for _, a in pairs(book.asks) do
        local r = a.kind == kind and a.dropID == dropID and STATE_RANK[a.state] or 0
        if r > rank then best, rank = a.state, r end
    end
    return best
end

local function refuse(reason, length)
    return { action = "refuse", reason = reason, length = length }
end

local function validRequest(book, req)
    return isBook(book) and isTable(req) and KIND[req.kind] and nonEmpty(req.target)
        and req.dropID ~= nil
end

-- Step 1, the guard: an ask queued or in flight is never repeated, and a sent one only with
-- oneAsk off. A failed ask may be retried.
local function guarded(existing, oneAsk)
    if not existing then return false end
    if existing.state == "sent" then return oneAsk end
    return existing.state ~= "failed"
end

-- Step 2: the edited text when given, else the template expanded.
local function messageText(req, opts)
    if nonEmpty(req.text) then return req.text end
    local name = TEMPLATE[req.template] and req.template or req.kind
    return (M.Expand(M.Template(name, opts.templates), req.ctx))
end

local function newAsk(req, key, text, opts)
    return { key = key, kind = req.kind, target = req.target, dropID = req.dropID, text = text,
             state = "ready", at = opts.now }
end

--- One request through the guard, the expansion with its length check, and the restriction check
--- (spec §9.2 steps 1-3). `send` means the caller sends `ask.text` now and reports the result;
--- `queue` means it waits for a flush.
function M.Request(book, req, opts)
    if not validRequest(book, req) then return refuse("badRequest") end
    opts = isTable(opts) and opts or {}
    local key = M.Key(req.kind, req.target, req.dropID)
    if guarded(book.asks[key], opts.oneAsk ~= false) then return refuse("alreadyAsked") end
    local text = messageText(req, opts)
    if #text > C.MESSAGE_MAX_LEN then return refuse("tooLong", #text) end
    local a = newAsk(req, key, text, opts)
    book.asks[key] = a
    if opts.canSend == false then
        a.state = "queued"
        book.queue[#book.queue + 1] = key
        return { action = "queue", ask = a }
    end
    return { action = "send", ask = a }
end

local function readyAsk(book, key)
    local a = isBook(book) and book.asks[key] or nil
    if a and a.state == "ready" then return a end
    return nil
end

--- The send succeeded: a ready ask becomes sent. Answers the ask, or nil when none was ready.
function M.MarkSent(book, key, now)
    local a = readyAsk(book, key)
    if not a then return nil end
    a.state, a.reason, a.sentAt = "sent", nil, now
    return a
end

--- The send failed or was throttled: a ready ask becomes failed with `reason`, and may be retried.
function M.MarkFailed(book, key, reason)
    local a = readyAsk(book, key)
    if not a then return nil end
    a.state, a.reason = "failed", reason
    return a
end

-- ---------------------------------------------------------------------------------------------
-- Flush and cancel (spec §9.2 steps 5-6)
-- ---------------------------------------------------------------------------------------------

local function queuedCount(book)
    local n = 0
    for _, key in ipairs(book.queue) do
        local a = book.asks[key]
        if a and a.state == "queued" then n = n + 1 end
    end
    return n
end

--- True when `trigger` (C.MESSAGE_FLUSH_TRIGGERS) should start a flush: the player can send and
--- something is queued.
function M.ShouldFlush(book, trigger, canSend)
    if not isBook(book) or canSend ~= true then return false end
    return C.MESSAGE_FLUSH_TRIGGERS[trigger] == true and queuedCount(book) > 0
end

--- The next queued ask, first in, first out, now ready to send; nil when the queue is empty. The
--- caller sends one every C.MESSAGE_FLUSH_INTERVAL seconds.
function M.Dequeue(book)
    if not isBook(book) then return nil end
    while #book.queue > 0 do
        local a = book.asks[table.remove(book.queue, 1)]
        if a and a.state == "queued" then
            a.state = "ready"
            return a
        end
    end
    return nil
end

local function dropQueued(book, key)
    local a = book.asks[key]
    if not a or a.state ~= "queued" then return nil end
    book.asks[key] = nil
    for i = #book.queue, 1, -1 do
        if book.queue[i] == key then table.remove(book.queue, i) end
    end
    a.state = "canceled"
    return a
end

--- Cancels a queued ask (its button clicked again). Answers the ask, marked "canceled", or nil
--- when `key` was not queued.
function M.Cancel(book, key)
    if not isBook(book) then return nil end
    return dropQueued(book, key)
end

--- Cancels every ask queued to `target` (the looter left the group), in queue order.
function M.CancelTarget(book, target)
    local out = {}
    if not isBook(book) then return out end
    local keys = {}
    for _, key in ipairs(book.queue) do
        local a = book.asks[key]
        if a and a.target == target then keys[#keys + 1] = key end
    end
    for _, key in ipairs(keys) do out[#out + 1] = dropQueued(book, key) end
    return out
end

--- Diagnostics: { asks, ready, queued, sent, failed }, the one-ask registry by state.
function M.Counts(book)
    local c = { asks = 0, ready = 0, queued = 0, sent = 0, failed = 0 }
    if not isBook(book) then return c end
    for _, a in pairs(book.asks) do
        c.asks = c.asks + 1
        c[a.state] = (c[a.state] or 0) + 1
    end
    return c
end
