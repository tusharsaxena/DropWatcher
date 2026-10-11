local _, NS = ...
-- modules/WindowFooter.lua — the main window's footer (design spec §11.1, board 01 note 12): a
-- quick health check, so it is clear the addon is listening even with no drop on screen. Inspect
-- freshness, the last loot seen, the situation and Pawn's status on the left; the tab's Sort on the
-- right, beside the resize grip.
--
-- Compose is PURE: plain inputs in, each segment's text and tooltip out, so test_window drives it
-- case by case. Read gathers the inputs through the engine's read-only accessors (the roster, the
-- inspect broker's entries, the loot parser's counters, the situation, the Pawn seam); Build and
-- Refresh are the frame edge. The window repaints it on InspectDone and SituationChanged, on every
-- repaint of its own, and every K.FOOTER_TICK seconds while shown, so the ages move.

NS.WindowFooter = NS.WindowFooter or {}
local WF = NS.WindowFooter
local K  = NS.Constants.WINDOW
local C  = NS.Constants
local L  = NS.L

local floor, max = math.floor, math.max

-- The situations' display names (design spec §6.1), for the footer and anything else that names one.
WF.SITUATION_LABEL = {
    mythicPlus = L["Mythic+"], dungeon = L["Dungeon"], followerDungeon = L["Follower dungeon"],
    raidLFR = L["Raid Finder"], raid = L["Raid"], delve = L["Delve"], scenario = L["Scenario"],
    pvp = L["PvP"], openWorldGroup = L["Open world group"], solo = L["Solo"],
}

WF.SEGMENTS = { "inspect", "loot", "situation", "pawn" }

--- A situation key's display name, or the key itself.
--- @param key string|nil
--- @return string
function WF.SituationLabel(key)
    return WF.SITUATION_LABEL[key] or tostring(key or "?")
end

--- A short age: `12s`, `3m`, `2h`.
--- @param seconds number
--- @return string
function WF.Ago(seconds)
    local s = max(0, floor(tonumber(seconds) or 0))
    if s < 60 then return ("%ds"):format(s) end
    if s < 3600 then return ("%dm"):format(floor(s / 60)) end
    return ("%dh"):format(floor(s / 3600))
end

-- ── the composer (pure) ─────────────────────────────────────────────────────────────────────

local function inspectSegment(i)
    local members = tonumber(i.members) or 0
    if members == 0 then
        return { text = L["Inspect: no group"],
            tip = { L["Inspect"], L["You are not in a group, so there is no one to inspect."] } }
    end
    local text = L["Inspect %d/%d fresh"]:format(i.good or 0, members)
    if (i.outOfRange or 0) > 0 then text = text .. " · " .. L["%d out of range"]:format(i.outOfRange) end
    return { text = text, tip = { L["Inspect"],
        L["How many other group members' gear has been read recently: each drop is judged for its looter from that read."],
        L["Waiting: %d. Out of range: %d. Scan group asks for the rest."]:format(i.pending or 0, i.outOfRange or 0) } }
end

local function lootSegment(i)
    if type(i.lastLootAgo) ~= "number" then
        return { text = L["No loot seen yet"], tip = { L["Last loot"],
            L["No loot line has been read this session. If loot dropped and this stays, see /dw diagnostics."] } }
    end
    local ago = WF.Ago(i.lastLootAgo)
    return { text = L["Last loot %s ago"]:format(ago),
        tip = { L["Last loot"], L["The last loot line read from chat arrived %s ago."]:format(ago) } }
end

local function situationSegment(i)
    local name = WF.SituationLabel(i.situation)
    if i.tracking == false then
        return { text = L["Not tracking in %s · change in settings"]:format(name), tip = { L["Situation"],
            L["Loot is not tracked here. Settings > General > When to show turns tracking on for %s."]:format(name) } }
    end
    return { text = L["Situation: %s"]:format(name),
        tip = { L["Situation"], L["Where you are, as the addon reads it. Each situation has its own tracking and auto-open settings."] } }
end

local function pawnSegment(i)
    if i.pawn == "on" then
        return { text = L["Pawn: on"], tip = { L["Pawn"], L["Pawn is ready: verdicts can use its scale."] } }
    end
    return { text = L["Pawn: off"], tip = { L["Pawn"], L["Pawn is not loaded, or not ready yet: verdicts do not use it."] } }
end

--- Each segment's text and tooltip from plain inputs.
--- @param i table { members, good, outOfRange, pending, lastLootAgo, situation, tracking, pawn }
--- @return table { inspect, loot, situation, pawn }, each { text, tip = { title, lines... } }
function WF.Compose(i)
    i = type(i) == "table" and i or {}
    return {
        inspect = inspectSegment(i), loot = lootSegment(i),
        situation = situationSegment(i), pawn = pawnSegment(i),
    }
end

-- ── the reads (edge) ────────────────────────────────────────────────────────────────────────

local function countInspects(i)
    local Ins = NS.Inspect
    for _, m in ipairs(NS.Roster.Members()) do
        if not m.isPlayer then
            i.members = i.members + 1
            local e = Ins.Get(m.guid)
            local status = e and e.status
            if Ins.IsGood(m.guid) then i.good = i.good + 1
            elseif status == "outOfRange" then i.outOfRange = i.outOfRange + 1
            elseif status == "pending" or status == "combatParked" then i.pending = i.pending + 1 end
        end
    end
end

--- The composer's inputs, read now. Read-only.
--- @return table
function WF.Read()
    local i = { members = 0, good = 0, outOfRange = 0, pending = 0 }
    countInspects(i)
    local lastAt = NS.LootParser.Stats().lastAt
    if type(lastAt) == "number" then i.lastLootAgo = GetTime() - lastAt end
    i.situation = NS.Situations.Current()
    i.tracking = NS.Situations.IsTracking(i.situation)
    i.pawn = NS.Compat.PawnIsReady() and "on" or "off"
    return i
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

local segments = {}   -- [key] = { frame, text }
local sortDropdown

local function textWidth(fs)
    local w = fs:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then return 120 end
    return w
end

local function buildSegment(host, key, prev)
    local s = CreateFrame("Frame", nil, host)
    s:SetHeight(K.FOOTER_H)
    s.text = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    s.text:SetPoint("LEFT", s, "LEFT", 0, 0)
    s.text:SetTextColor(C.IDLE.r, C.IDLE.g, C.IDLE.b)
    if prev then s:SetPoint("LEFT", prev, "RIGHT", 12, 0) else s:SetPoint("LEFT", host, "LEFT", 2, 0) end
    NS.Window.AttachTooltip(s, function()
        local tip = s.tipLines or {}
        return unpack(tip)
    end)
    segments[key] = s
    return s
end

local function buildSort(host)
    local dd = NS.MakeDropdown(host, 150)
    if not dd then return nil end
    local opts = {}
    local FB = NS.WindowFilterBar
    for _, v in ipairs(FB.VALUES.sort) do opts[#opts + 1] = { value = v, label = FB.LABELS.sort[v] } end
    dd:SetOptions(opts)
    -- Left of the resize grip, which sits in the window's bottom-right corner.
    dd:SetPoint("RIGHT", host, "RIGHT", -16, 0)
    dd.onSelect = function(v) FB.Set(NS.Window.ActiveTab(), "sort", v) end
    NS.Window.AttachTooltip(dd, function()
        return L["Sort"], L["The order of the rows on this tab."]
    end)
    return dd
end

--- Build the footer on `host` (the window's footer frame). Once per window.
--- @param host table
function WF.Build(host)
    segments = {}
    local prev
    for _, key in ipairs(WF.SEGMENTS) do prev = buildSegment(host, key, prev) end
    sortDropdown = buildSort(host)
end

--- Repaint every segment from a fresh read, and the Sort control from the active tab's state.
function WF.Refresh()
    if not segments.inspect then return end
    local composed = WF.Compose(WF.Read())
    for key, s in pairs(segments) do
        local seg = composed[key]
        s.text:SetText(seg.text)
        s.tipLines = seg.tip
        s:SetWidth(textWidth(s.text))
    end
    if sortDropdown then
        local tab = NS.Window.ActiveTab()
        local FB = NS.WindowFilterBar
        sortDropdown:SelectValue(FB.State(tab).sort)
        local on = FB.HONORS[tab].sort == true
        sortDropdown:SetEnabled(on)
        sortDropdown:SetAlpha(on and 1 or 0.4)
    end
end

--- The built segments and the Sort control, for the suites.
--- @return table segments, table|nil sort
function WF.Parts() return segments, sortDropdown end
