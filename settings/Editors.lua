local _, NS = ...
-- settings/Editors.lua — the pure halves of the settings pages' own editors (design spec §12.2).
--
-- Every page draws its rows through the library's flow engine. Three things on them are not its to
-- draw (the Comparison page's two editors are LibKa0s-Verdict-1.0's Settings): Drops › Situations' table (the per-situation rows, `skipRender`, one table row
-- per situation), the Messages page's template editors (their live counters, the token chips and
-- the preview) and the Drops page's "in force now" readout. Their widgets are
-- settings/PageEditors.lua's; what they show and what they write is decided here, with no widget
-- and no client call, so the suites can pin it. A map write is always a fresh table: the seam
-- stores what it is handed, and an edit made in place on the stored table would skip the seam's
-- check and its announce.

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L
local K        = NS.Constants

local E = {}
Settings.Editors = E

local function isTable(v) return type(v) == "table" end

-- ── Messages › Templates ────────────────────────────────────────────────────────────────────

-- What each token fills in, for the chip's tooltip (design spec §9.1).
E.TOKEN_TIPS = {
    player = L["The player's name: the looter for an ask, the candidate for an offer, the master looter for a master-loot ask."],
    item   = L["The item's link."],
    ilvl   = L["The item's level."],
    slot   = L["The slot the item goes in."],
    track  = L["The item's upgrade track."],
    gain   = L["The item levels the looter, or the candidate, would gain."],
    mygain = L["The item levels you would gain."],
}

-- Each template's editor label (design spec §9.1, board 08).
E.TEMPLATE_LABEL = {
    ask      = L["Ask (whisper to the looter)"],
    transmog = L["Ask for transmog (whisper to the looter)"],
    askOffSpec = L["Ask for off-spec (whisper to the looter)"],
    askML    = L["Ask the master looter (whisper to the master looter)"],
    offer    = L["Offer (whisper to a candidate)"],
    announce = L["Announce (group, raid or instance)"],
}

-- A refusal in the skin's alternate bad red (`sem.badAlt`, Ka0s Default ff4040), read at each use so
-- it follows a skin switch.
local function red(text) return (NS.SkinEscape("sem.badAlt") or "") .. text .. "|r" end

-- A template's short name, for the preview's header.
E.KIND_NAME = {
    ask = L["Ask"], transmog = L["Ask for transmog"], askOffSpec = L["Ask for off-spec"],
    askML = L["Ask the master looter"], offer = L["Offer"], announce = L["Announce"],
}


--- An editor's label with its live counter: `Ask (whisper to the looter)   104 / 255`, the
--- count red past the chat limit. Counted in bytes, which is what the limit counts.
--- @param kind string
--- @param text string|nil
--- @return string label, boolean over
function E.CounterLabel(kind, text)
    local n = type(text) == "string" and #text or 0
    local count = ("%d / %d"):format(n, K.MESSAGE_MAX_LEN)
    local over = n > K.MESSAGE_MAX_LEN
    if over then count = red(count) end
    return ("%s   %s"):format(E.TEMPLATE_LABEL[kind] or kind, count), over
end

local function isMine(rec)
    return rec.isMine == true or (isTable(rec.looter) and rec.looter.isSelf == true)
end

-- The candidate an offer preview is written to: the one who gains most, ties by name.
local function bestCandidate(rec)
    local best, bestGain
    for guid, c in pairs(isTable(rec.candidates) and rec.candidates or {}) do
        local gain = isTable(c.eval) and type(c.eval.ilvlDelta) == "number" and c.eval.ilvlDelta or nil
        if gain and gain > 0 and (not best or gain > bestGain or (gain == bestGain and tostring(c.name) < tostring(best.name))) then
            best, bestGain = { name = c.name, guid = guid }, gain
        end
    end
    return best
end

local function myGain(rec)
    local d = isTable(rec.me) and rec.me.ilvlDelta or nil
    return type(d) == "number" and d or nil
end

-- Per kind, who a drop's preview is written to, or nil when the drop does not fit. `strict` asks for
-- the drop the message is written for (an ask: an upgrade for you); the second pass takes any.
local function lookMissing(rec)
    return isTable(rec.facts) and rec.facts.transmogKnown == false
end

local OFF_GAIN = { upgrade = true, sidegrade = true }

local function offSpecGain(rec)
    local off = NS.OffSpec.Of(rec.me)
    return off ~= nil and OFF_GAIN[off.verdict] == true
end

local SAMPLE = {
    ask = function(rec, strict)
        if isMine(rec) or not isTable(rec.looter) then return nil end
        if strict and (myGain(rec) or 0) <= 0 then return nil end
        return { name = rec.looter.name, guid = rec.looter.guid }
    end,
    -- A drop whose look you have not collected, when there is one.
    transmog = function(rec, strict)
        if isMine(rec) or not isTable(rec.looter) then return nil end
        if strict and not lookMissing(rec) then return nil end
        return { name = rec.looter.name, guid = rec.looter.guid }
    end,
    -- A drop your spec can't use but another of your specs gains from, when there is one.
    askOffSpec = function(rec, strict)
        if isMine(rec) or not isTable(rec.looter) then return nil end
        if strict and not offSpecGain(rec) then return nil end
        return { name = rec.looter.name, guid = rec.looter.guid }
    end,
    -- No pending item lives in the feed: another member's drop, an upgrade for you when there is
    -- one, stands in for it, its looter for the master looter.
    askML = function(rec, strict)
        if isMine(rec) or not isTable(rec.looter) then return nil end
        if strict and (myGain(rec) or 0) <= 0 then return nil end
        return { name = rec.looter.name, guid = rec.looter.guid }
    end,
    offer = function(rec)
        if not isMine(rec) then return nil end
        return bestCandidate(rec)
    end,
    announce = function(rec)
        if not isMine(rec) then return nil end
        return {}
    end,
}

--- The drop a template's preview is written for, newest first: for an ask another member's drop
--- and its looter (one that is an upgrade for you when there is one; for the transmog ask one whose
--- look you have not collected; for the off-spec ask one another of your specs gains from), for an offer your own drop and the candidate who gains most, for an announce your
--- own drop. Nil when no drop in `drops` fits.
--- @param kind string
--- @param drops table drop records, oldest first
--- @return table|nil rec, table|nil who { name, guid }
function E.PreviewSample(kind, drops)
    local pick = SAMPLE[kind]
    if not (pick and isTable(drops)) then return nil, nil end
    for _, strict in ipairs({ true, false }) do
        for i = #drops, 1, -1 do
            local rec = drops[i]
            local who = isTable(rec) and pick(rec, strict) or nil
            if who then return rec, who end
        end
    end
    return nil, nil
end

--- The preview's three lines for a template over a sample: the header (`Preview: Ask, to Séta`),
--- the text as it would be sent (`To Séta: …`), and the status (its length against the limit, any
--- unknown token, `too long to send`).
--- @param kind string
--- @param template string
--- @param ctx table the token values (NS.Asks.TokenContext)
--- @param to string|nil who it goes to: a name, or the channel's name for an announce
--- @return table { header, body, status, tooLong, unknown }
function E.PreviewLines(kind, template, ctx, to)
    local p = NS.Messaging.Preview(template, ctx)
    local who = to or L["the group"]
    local parts = { ("%d / %d"):format(p.length, K.MESSAGE_MAX_LEN) }
    if p.tooLong then parts[#parts + 1] = red(L["too long to send"]) end
    if #p.unknown > 0 then
        local names = {}
        for i, n in ipairs(p.unknown) do names[i] = "{" .. n .. "}" end
        parts[#parts + 1] = red(L["unknown tokens, sent as typed: %s"]:format(table.concat(names, " ")))
    end
    return {
        header  = L["Preview: %s, to %s"]:format(E.KIND_NAME[kind] or kind, who),
        body    = L["To %s: %s"]:format(who, p.text),
        status  = table.concat(parts, "  \194\183  "),
        tooLong = p.tooLong, unknown = p.unknown,
    }
end

-- ── Situations ──────────────────────────────────────────────────────────────────────────────

--- The table's setting columns, in order: three fields of `situations.<key>`, then (Retail's alone,
--- C.FEATURE_CLIENTS.tradeRuleRows) the situation's loot rule, `trade.rules.<key>` (Trade › Rules
--- until feedback-24). WoW Forever has one rule, `soulbound`, so no column (Forever port design §4.4).
E.SITUATION_FIELDS = { "track", "autoOpen", "quality" }
if K.FEATURE.tradeRuleRows then E.SITUATION_FIELDS[#E.SITUATION_FIELDS + 1] = "rule" end
local SITUATION_PATH = { rule = "trade.rules.%s" }

-- One cell: its schema row, the value stored at its path, and whether it is live. Live unless the
-- row's own `disabledIf` says otherwise (settings/SchemaRows.lua), so the table dims exactly what
-- the row dims and the rule has one home.
local function situationCell(findRow, read, path)
    local row = findRow(path)
    local off = row and type(row.disabledIf) == "function" and row.disabledIf() or false
    return { path = path, row = row, value = read(path), enabled = not off }
end

--- The Situations table: one entry per situation, in K.SITUATIONS order, carrying its
--- key, its label, whether it is tracked (`active`: an untracked row's label dims) and a cell per
--- E.SITUATION_FIELDS field.
--- @param findRow function path -> schema row (NS.SchemaRuntime.FindRow)
--- @param read function path -> stored value (NS.Setting)
--- @param labelOf function situation key -> display name (WindowFooter.SituationLabel)
--- @return table
function E.SituationRows(findRow, read, labelOf)
    local out = {}
    for _, s in ipairs(K.SITUATIONS) do
        local entry = { key = s.key, label = labelOf(s.key) }
        for _, field in ipairs(E.SITUATION_FIELDS) do
            local path = SITUATION_PATH[field] and SITUATION_PATH[field]:format(s.key)
                or ("situations.%s.%s"):format(s.key, field)
            entry[field] = situationCell(findRow, read, path)
        end
        entry.active = entry.track.value == true
        out[#out + 1] = entry
    end
    return out
end

-- ── Drops › Quality ─────────────────────────────────────────────────────────────────────────

--- The "in force now" line under the Quality tab: the threshold the feed applies where you are,
--- naming the situation when its own setting overrides the feed's mode.
--- @param label string the filter bar's label (WindowFilterBar.QualityReadout's third answer)
--- @param situationLabel string|nil the current situation's name when it overrides, else nil
--- @return string
function E.ReadoutText(label, situationLabel)
    if situationLabel then
        return L["In force now: %s (%s's own setting)"]:format(label, situationLabel)
    end
    return L["In force now: %s"]:format(label)
end

