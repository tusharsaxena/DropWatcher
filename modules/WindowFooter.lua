local _, NS = ...
-- modules/WindowFooter.lua — the main window's footer (design spec §11.1, board 01 note 12): a
-- quick health check, so it is clear the addon is listening even with no drop on screen. Inspect
-- freshness, the last loot seen, the situation and Pawn's status. While a simulation runs, the
-- situation reads `Simulating: <situation> · n members` (simulator spec §6).
--
-- THE TAB'S SORT is built here, once, and kept here (Parts, Refresh's state), but it no longer sits
-- in the footer (feedback-10 spec §3): in the full layout it is at the right edge of the active tab's
-- strip (`pane.sortHost`: Drops' summary strip, after Post my tradeables, Scan group and Expand all;
-- History's, after Expand all; feedback-15 spec §2, §3), re-anchored on every pass so it follows a
-- tab switch; in the compact layout it is in the Filters panel (modules/CompactChrome.lua).
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

-- A tooltip row and the closing hint: NS.TipMarks loads after this file (DropWatcher.toc), so read
-- at call time.
local function row(label, value, tone) return NS.TipMarks.Row(label, value, tone) end
local function hint(text) return NS.TipMarks.Hint(text) end

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
--
-- Each segment is two functions of the same inputs: its text, painted on every pass, and its
-- tooltip rows, built only when they are read (a hover, or Compose for the suites). A repaint
-- builds no tooltip rows (feedback-21, PF1: the rows' color codes and tables cost every pass).

local INSPECT, LOOT, SITUATION, PAWN = {}, {}, {}, {}

function INSPECT.text(i)
    local members = tonumber(i.members) or 0
    if members == 0 then return L["Inspect: no group"] end
    local text = L["Inspect %d/%d fresh"]:format(i.good or 0, members)
    if (i.outOfRange or 0) > 0 then text = text .. " · " .. L["%d out of range"]:format(i.outOfRange) end
    return text
end

function INSPECT.tip(i)
    local members = tonumber(i.members) or 0
    if members == 0 then return { L["Inspect"], row(L["Group"], L["none, so no one to inspect"]) } end
    return { L["Inspect"], row(L["Read recently"], ("%d/%d"):format(i.good or 0, members)),
        row(L["Waiting"], i.pending or 0), row(L["Out of range"], i.outOfRange or 0),
        row(L["Each drop"], L["judged for its looter from that read"]), hint(L["Scan group asks for the rest."]) }
end

function LOOT.text(i)
    if type(i.lastLootAgo) ~= "number" then return L["No loot seen yet"] end
    return L["Last loot %s ago"]:format(WF.Ago(i.lastLootAgo))
end

function LOOT.tip(i)
    if type(i.lastLootAgo) ~= "number" then
        return { L["Last loot"], row(L["Loot lines read"], L["none this session"]),
            hint(L["If loot dropped and this stays, see /dw diagnostics."]) }
    end
    return { L["Last loot"], row(L["Last loot line"], L["%s ago"]:format(WF.Ago(i.lastLootAgo))), row(L["Read from"], L["chat"]) }
end

function SITUATION.text(i)
    local name = WF.SituationLabel(i.situation)
    if type(i.sim) == "table" then return L["Simulating: %s · %d members"]:format(name, i.sim.members or 0) end
    if i.tracking == false then return L["Not tracking in %s · change in settings"]:format(name) end
    return L["Situation: %s"]:format(name)
end

function SITUATION.tip(i)
    local name = WF.SituationLabel(i.situation)
    if type(i.sim) == "table" then
        return { L["Simulation"], row(L["Situation"], name), row(L["Members"], i.sim.members or 0),
            row(L["Both"], L["made up"]), hint(L["/dw sim stop ends it."]) }
    end
    if i.tracking == false then
        return { L["Situation"], row(L["Situation"], name), row(L["Loot tracked"], L["no"]),
            row(L["Turned on in"], L["Settings > General > When to show"]) }
    end
    return { L["Situation"], row(L["Where you are"], name), row(L["Its own"], L["tracking and auto-open settings"]) }
end

function PAWN.text(i) return i.pawn == "on" and L["Pawn: on"] or L["Pawn: off"] end

function PAWN.tip(i)
    if i.pawn == "on" then
        return { L["Pawn"], row(L["Status"], L["ready"], "good"), row(L["Verdicts"], L["can use its scale"]) }
    end
    return { L["Pawn"], row(L["Status"], L["not loaded, or not ready yet"]), row(L["Verdicts"], L["do not use it"]) }
end

local SEGMENT = { inspect = INSPECT, loot = LOOT, situation = SITUATION, pawn = PAWN }

--- One segment's tooltip from plain inputs: its title, then its rows.
--- @param key string a WF.SEGMENTS key
--- @param i table WF.Read's inputs
--- @return table { title, lines... }, or an empty list for an unknown key
function WF.SegmentTip(key, i)
    local seg = SEGMENT[key]
    if not seg then return {} end
    return seg.tip(type(i) == "table" and i or {})
end

--- Each segment's text and tooltip from plain inputs.
--- @param i table { members, good, outOfRange, pending, lastLootAgo, situation, tracking, pawn,
---   sim = { members } while a simulation runs }
--- @param textOnly boolean|nil true for the texts alone (a repaint: the rows wait for a hover)
--- @return table { inspect, loot, situation, pawn }, each { text, tip = { title, lines... } }
function WF.Compose(i, textOnly)
    i = type(i) == "table" and i or {}
    local out = {}
    for key, seg in pairs(SEGMENT) do
        out[key] = { text = seg.text(i), tip = not textOnly and seg.tip(i) or nil }
    end
    return out
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
    if NS.Sim.IsActive() then i.sim = { members = #NS.SimRoster.Get() } end
    i.pawn = NS.Compat.PawnIsReady() and "on" or "off"
    return i
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

local segments = {}   -- [key] = { frame, text }
local sortDropdown
local footerHost

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
    -- The compact layout's line sets tipLines (NS.CompactChrome.PaintFooter); the full layout's
    -- segment keeps its read and builds its rows on the hover.
    NS.Window.AttachTooltip(s, function()
        local tip = s.tipLines or (s.tipRead and WF.SegmentTip(key, s.tipRead)) or {}
        return unpack(tip)
    end)
    segments[key] = s
    return s
end

--- The Sort control's width (the one footer button width, K.FOOTER_BUTTON_W, so it lines up with the
--- strip's buttons; feedback-15 spec §2) and its right edge's inset from its strip's right edge
--- (feedback-10 spec §3).
WF.SORT_W = K.FOOTER_BUTTON_W
WF.SORT_INSET = 0

local function buildSort(host)
    local dd = NS.MakeDropdown(host, WF.SORT_W)
    if not dd then return nil end
    local opts = {}
    local FB = NS.WindowFilterBar
    for _, v in ipairs(FB.VALUES.sort) do opts[#opts + 1] = { value = v, label = FB.LABELS.sort[v] } end
    dd:SetOptions(opts)
    dd.onSelect = function(v) FB.Set(NS.Window.ActiveTab(), "sort", v) end
    NS.Window.AttachTooltip(dd, function()
        return L["Sort"], row(L["Sets"], L["the order of the rows on this tab"])
    end, "above")
    return dd
end

--- Build the footer on `host` (the window's footer frame). Once per window.
--- @param host table
function WF.Build(host)
    segments, footerHost = {}, host
    local prev
    for _, key in ipairs(WF.SEGMENTS) do prev = buildSegment(host, key, prev) end
    sortDropdown = buildSort(host)
    WF.AnchorSort()
end

-- The full layout's place for Sort: the active tab's strip (its pane's `sortHost`), else the footer
-- (a tab whose pane is not built yet).
local function sortHost()
    local f = NS.Window.Frame()
    local pane = f and f.panes and f.panes[NS.Window.ActiveTab()]
    return pane and pane.sortHost or footerHost
end

--- Put the Sort control at its place in the full layout: the right edge of the active tab's strip
--- (feedback-10 spec §3). Every full pass calls it (Refresh), so it follows a tab switch, and so does
--- the full layout taking it back from the compact Filters panel (modules/CompactChrome.lua).
function WF.AnchorSort()
    local dd, host = sortDropdown, sortHost()
    if not (dd and host) then return end
    if dd.dwHost == host and dd:GetParent() == host then return end
    dd.dwHost = host
    dd:SetParent(host)
    dd:ClearAllPoints()
    dd:SetPoint("RIGHT", host, "RIGHT", -WF.SORT_INSET, 0)
    dd:SetWidth(WF.SORT_W)
end

--- Repaint every segment from a fresh read, and the Sort control from the active tab's state. The
--- compact layout's one line is NS.CompactChrome.PaintFooter's (compact spec §4).
function WF.Refresh()
    if not segments.inspect then return end
    local read = WF.Read()
    local composed = WF.Compose(read, true)
    if NS.WindowCompact.Mode() == "compact" then
        NS.CompactChrome.PaintFooter(segments, read, composed)
    else
        WF.AnchorSort()
        for key, s in pairs(segments) do
            local seg = composed[key]
            s.text:SetText(seg.text)
            s.tipLines, s.tipRead = nil, read
            s:SetWidth(textWidth(s.text))
        end
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
