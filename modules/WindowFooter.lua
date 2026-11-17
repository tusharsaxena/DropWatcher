local _, NS = ...
-- modules/WindowFooter.lua — the main window's status line (design spec §11.1, board 01 note 12): a
-- quick health check, so it is clear the addon is listening even with no drop on screen. Inspect
-- freshness, the last loot seen, the situation and Pawn's status. While a simulation runs, the
-- situation reads `Simulating: <situation> · n members` (simulator spec §6).
--
-- THE FOOTER'S WORDS (RX-24; WowAddonStandards v2.110.0 standalone-windows' *The footer*,
-- anti-pattern #118). The window's footer is LibKa0s Widgets' Footer (no fill, its hairline,
-- FOOTER.HEIGHT, the resize grip in its corner: modules/Window.lua), and every word on it is its own
-- left line, set through `foot:SetLeft`: the active tab's info (Drops' tradeable count, next expiry
-- and new count; History's kept-history line; Insights' period) and then the status line, ` · `
-- between (WF.LineText, pure; ruling 9 of the rolls-UX spec, the status after the count), one line
-- the library cuts with an ellipsis where its marks start. Full, the status is every segment's words
-- (WF.StatusText); compact, the short line (NS.CompactChrome.FooterLine). One tooltip over the line
-- (WF.LineTip): the tab info's own lines, then every status segment's words and reasons
-- (WF.StatusTip). The host lays nothing over the footer but that tooltip's mouse frame, which draws
-- nothing; the right line is unused. Each tab keeps its words and controls in its pane's `foot`
-- (`info`, `tip`, `controls`) and hands them over on its paint (WF.PaintTab); the controls are the
-- footer's marks (modules/FooterRow.lua). Until RX-24 the status was a font string of the host's on
-- each tab's strip, laid over the footer.
--
-- THE TAB'S SORT is on the filter bar (modules/WindowFilterBar.lua; RX-24), no longer here.
--
-- Compose is PURE: plain inputs in, each segment's text and tooltip out, so test_window drives it
-- case by case. Read gathers the inputs through the engine's read-only accessors (the roster, the
-- inspect broker's entries, the loot parser's counters, the situation, the Pawn seam); Build and
-- Refresh are the frame edge. The window repaints it on InspectDone and SituationChanged, on every
-- repaint of its own, and every K.FOOTER_TICK seconds while shown, so the ages move.

NS.WindowFooter = NS.WindowFooter or {}
local WF = NS.WindowFooter
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
        return { L["SIM"], row(L["Situation"], name), row(L["Members"], i.sim.members or 0),
            row(L["Both"], L["made up"]), hint(L["/dw sim stop ends it."]) }
    end
    if i.tracking == false then
        return { L["Situation"], row(L["Situation"], name), row(L["Loot tracked"], L["no"]),
            row(L["Turned on in"], L["Settings > Drops > Situations"]) }
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
    if NS.Sim:IsActive() then i.sim = { members = #NS.SimRoster.Get() } end
    i.pawn = NS.Compat.PawnIsReady() and "on" or "off"
    return i
end

-- ── one line (pure) ─────────────────────────────────────────────────────────────────────────

--- The status line from plain inputs (RX-09, rolls-UX spec §3.7): every segment's text in
--- WF.SEGMENTS order, ` · ` between, in the full layout; compact's short line
--- (NS.CompactChrome.FooterLine) in compact.
--- @param i table WF.Read's inputs
--- @param composed table|nil WF.Compose's (text only is enough); composed here when nil
--- @param compact boolean|nil
--- @return string
function WF.StatusText(i, composed, compact)
    if compact then return NS.CompactChrome.FooterLine(i) end
    composed = composed or WF.Compose(i, true)
    local parts = {}
    for _, key in ipairs(WF.SEGMENTS) do parts[#parts + 1] = composed[key].text end
    return table.concat(parts, " · ")
end

local function isHint(line)
    return type(line) == "string" and line:sub(1, 4) == "|cff" and not line:find(NS.TipMarks.BULLET, 1, true)
end

--- The status line's tooltip from plain inputs, in both layouts: `Status`, then per segment its words
--- as a row and its own tooltip's rows under them, then every segment's closing hint. The status
--- bar's four tooltips, kept in one (RX-09).
--- @param i table WF.Read's inputs
--- @return table { title, lines... }
function WF.StatusTip(i)
    i = type(i) == "table" and i or {}
    local out, hints = { L["Status"] }, {}
    for _, key in ipairs(WF.SEGMENTS) do
        local seg = SEGMENT[key]
        out[#out + 1] = NS.TipMarks.Row(nil, seg.text(i))
        local tip = seg.tip(i)
        for n = 2, #tip do
            local line = tip[n]
            if isHint(line) then hints[#hints + 1] = line else out[#out + 1] = line end
        end
    end
    for _, h in ipairs(hints) do out[#out + 1] = h end
    return out
end

-- ── the footer's line (pure) ────────────────────────────────────────────────────────────────

--- The footer's one line (pure, RX-24): the active tab's info, then the status, ` · ` between; the
--- status alone while the tab has nothing to say.
--- @param info string|nil
--- @param status string
--- @return string
function WF.LineText(info, status)
    if info == nil or info == "" then return status end
    return info .. " · " .. status
end

--- The line's tooltip (pure, RX-24): with the tab's own tooltip, its title and lines, then every
--- status line after the status tooltip's title; without, the status tooltip (WF.StatusTip).
--- @param infoTip table|nil { title, lines... }
--- @param i table WF.Read's inputs
--- @return table { title, lines... }
function WF.LineTip(infoTip, i)
    local status = WF.StatusTip(i)
    if type(infoTip) ~= "table" or #infoTip == 0 then return status end
    local out = { unpack(infoTip) }
    for n = 2, #status do out[#out + 1] = status[n] end
    return out
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

local foot          -- the window's footer (W.Footer, or NS.BareFooter with no library)
local line          -- the tooltip's mouse frame over the footer's left line; `line.text` is that line
local statusText    -- the status's words at the last read, in the layout in force
local lastRead      -- that read, for the tooltip
local shownTab      -- the pane whose words and controls the footer shows

-- The active tab's pane, or nil before it is built.
local function activePane()
    local f = NS.Window.Frame()
    return f and f.panes and f.panes[NS.Window.ActiveTab()]
end

local function lineTip()
    local model = shownTab and shownTab.foot
    return unpack(WF.LineTip(model and model.tip, lastRead))
end

--- Take the window's footer (once per window): the tooltip's mouse frame over its left line, as tall
--- as the footer; it draws nothing.
--- @param f table the footer
function WF.Build(f)
    foot = f
    line = CreateFrame("Frame", nil, f)
    line.text = f.left
    line:SetPoint("LEFT", f.left, "LEFT", 0, 0)
    line:SetPoint("RIGHT", f.left, "RIGHT", 0, 0)
    line:SetHeight(NS.FooterMetric("HEIGHT"))
    NS.Window.AttachTooltip(line, lineTip, "chrome")
    statusText, lastRead, shownTab = nil, nil, nil
end

-- Write the left line only when its words moved.
local function setLeft(text)
    if foot.dwLeft == text then return end
    foot.dwLeft = text
    foot:SetLeft(text)
end

-- The pane's words and controls on the footer (the status from the last read).
local function apply(pane)
    shownTab = pane
    local model = pane and pane.foot
    setLeft(WF.LineText(model and model.info, statusText or ""))
    NS.FooterRow.Bind(model and model.controls)
end

--- A tab's paint hands over its words and controls (its pane's `foot`); the footer shows them while
--- that tab is the active one. Cheap: no read, no table built.
--- @param pane table
function WF.PaintTab(pane)
    if foot and pane == activePane() then apply(pane) end
end

--- Repaint the status from a fresh read (its words in the layout in force; its tooltip waits for a
--- hover), and the active tab's words and controls after it.
function WF.Refresh()
    if not foot then return end
    local compact = NS.WindowCompact.Mode() == "compact"
    lastRead = WF.Read()
    statusText = WF.StatusText(lastRead, nil, compact)
    apply(activePane())
end

--- The line's tooltip frame (its `text` the footer's left line) and the footer, for the suites.
--- @return table|nil line, table|nil foot
function WF.Parts() return line, foot end
