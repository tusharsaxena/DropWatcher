local _, NS = ...
-- modules/SimPanel.lua — the simulation step panel (sim feedback spec §1): a small titled window,
-- `Ka0s Drop Watcher - Simulation`, that shows the running scenario's timeline as clickable steps,
-- with the run controls and, while no simulation runs, the scenario picker.
--
-- THE LOOK is LibKa0s-Perf-1.0's step panel (libs/LibKa0s/PerfPanel.lua), copied: three columns
-- per row (a status dot, the step's name, its typed slash command right-aligned and dimmer), the
-- title centered at the top, Core's close mark at the top right, Core's skin, Escape closes it.
-- Each row's text and dot share one of PerfPanel's colors (COLORS): a completed step is green with
-- a check, the current one gold, the next clickable one bright, those further ahead gray, and the
-- Stop row muted red while there is a run to stop.
--
-- THE ROWS. `Start: <scenario>`, then one row per timeline step (modules/SimScenario.lua), then
-- `Stop simulation`. Clicking the next step runs it; clicking a later one runs every step up to and
-- including it, in order (RunTo), never skipping one; clicking a completed step does nothing, and
-- its tooltip says when it ran. Every row's tooltip says what the step injects. A played loot step
-- says where its drops went, `Loot: 3 drops (1 hidden)`, and its tooltip names each drop, its looter
-- and its tab or the gate that hid it (modules/SimReport.lua; feedback-3 spec §0).
--
-- THE PANEL NEVER CHANGES THE TIMELINE. Every click and every control goes through the very verbs
-- `/dw sim` types (NS.SimVerbs.Run: `start`, `step`, `run`, `pause`, `resume`, `restart`, `stop`),
-- so a click prints what the typed verb prints, and the panel repaints from the timeline on every
-- move it is told of (NS.SimScenario.AddListener): a typed `/dw sim step` moves it too.
--
-- WHAT IT COMPOSES (Compose, Controls) is PURE: the timeline and the clock in, the rows and the
-- controls' state out. The rest is the frame edge, built on the first Show. Its position is window
-- state (profile `simPanel.point`, absent until the player drags it, written by this file alone,
-- no row addresses it); until then it opens beside the Drop Watcher window, never over it.

NS.SimPanel = NS.SimPanel or {}
local SP = NS.SimPanel
local L  = NS.L
local K  = NS.Constants.WINDOW

local FRAME_NAME = "DropWatcherSimPanel"

-- PerfPanel's geometry: three columns, a status dot, the step and the command.
local ROW_W, ROW_H, GAP = 360, 22, 4
local DOT_X, DOT, CHECK = 8, 8, 12
local LABEL_X, CMD_PAD = 26, 10
local TITLE_H, PAD = 24, 8
local BAR_H = 22             -- the controls strip (or the picker) under the rows
local BUTTON_W, BUTTON_GAP = 84, 6
local WIDTH = ROW_W + PAD * 2

--- PerfPanel's per-state colors, for both a row's text and its dot.
SP.COLORS = {
    done   = { 0.30, 0.85, 0.30 },
    ready  = { 0.90, 0.90, 0.92 },
    busy   = { 1.00, 0.82, 0.00 },
    locked = { 0.40, 0.40, 0.42 },
    cancel = { 0.80, 0.32, 0.32 },
}
local CMD_COLOR = { 0.45, 0.45, 0.48 }
local HOVER = { ready = { 1, 0.82, 0 }, locked = { 1, 0.82, 0 }, cancel = { 1.00, 0.45, 0.45 } }

--- The picker's names for the scenarios (modules/SimScenario.lua's SCENARIOS), in NAMES order.
SP.SCENARIO_LABEL = {
    key = L["Mythic+ key"], dungeon = L["Dungeon"], raid = L["Raid"], lfr = L["Raid Finder"],
    delve = L["Delve"], world = L["Open world"],
}

--- The raid sizes the picker offers (members besides you); 0 is "Random" (no size argument).
SP.SIZES = { 0, 9, 12, 15, 19 }

-- What each timeline step is called, and what it injects (its tooltip).
local KIND_LABEL = {
    runStart = L["Key starts"], runEnd = L["Key complete"],
    lockdownOn = L["Combat and chat lockdown"], lockdownOff = L["Lockdown lifts"],
}

local KIND_TIP = {
    runStart    = L["CHALLENGE_MODE_START and the ChallengeMode restriction through the real handlers."],
    runEnd      = L["CHALLENGE_MODE_COMPLETED through the real handlers; the ChallengeMode restriction lifts."],
    pull        = L["ENCOUNTER_START, the combat edge and the Encounter restriction through the real handlers."],
    kill        = L["ENCOUNTER_END through the real handlers; combat and the Encounter restriction lift."],
    lockdownOn  = L["The simulated chat lockdown: an ask made now waits until it lifts."],
    lockdownOff = L["The chat lockdown lifts: a waiting ask goes out (printed, never sent)."],
    loot        = L["%s through the real loot handler (CHAT_MSG_LOOT)."],
}

local START_TIP = L["Builds the item pool from the Encounter Journal, invents the group and opens the window."]
local STOP_TIP = L["Ends the simulation and cleans up everything it made."]

-- ── composing (pure) ────────────────────────────────────────────────────────────────────────

local function slashOf(rest) return NS.SLASH .. " sim " .. rest end

--- The typed form of starting `name` at `size` (0 or nil: no size).
--- @param name string
--- @param size number|nil
--- @return string
function SP.StartCommand(name, size)
    local n = tonumber(size)
    if n and n > 0 then return slashOf(("start %s %d"):format(name, n)) end
    return slashOf("start " .. name)
end

local function lineCount(n)
    if n == 1 then return L["1 loot line"] end
    if n then return L["%d loot lines"]:format(n) end
    return L["1 to 3 loot lines"]
end

-- A played loot step reads its report again (modules/SimReport.lua; feedback-3 spec §0), so a drop
-- still loading when it ran is placed once it lands: `Loot: 3 drops (1 hidden)`. It reads the window's
-- view each time too (SimReport.View: test mode; feedback-3 spec §5).
local function lootLabel(step)
    local R = NS.SimReport
    if step.report then return L["Loot: %s"]:format(R.Summarize(step.report, NS.LootFeed.Get, R.View()).text) end
    if step.detail then return L["Loot: %s"]:format(step.detail) end
    if step.n == 1 then return L["Loot: 1 drop"] end
    if step.n then return L["Loot: %d drops"]:format(step.n) end
    return L["Loot: 1 to 3 drops"]
end

--- A timeline step's name. `boss` is the encounter a pull or a kill is about: the one it named
--- once played, else the one it will name.
--- @param step table { kind, n, detail }
--- @param boss string|nil
--- @return string
function SP.StepLabel(step, boss)
    if step.kind == "pull" then return L["Pull: %s"]:format(boss or "?") end
    if step.kind == "kill" then return L["Kill: %s"]:format(boss or "?") end
    if step.kind == "loot" then return lootLabel(step) end
    return KIND_LABEL[step.kind] or step.kind
end

local function stepTip(step)
    if step.kind == "loot" then return KIND_TIP.loot:format(lineCount(step.n)) end
    return KIND_TIP[step.kind] or ""
end

-- The bosses each pull and kill names: what it named once played, else the simulator's next name
-- in its rotation (modules/SimEvents.lua's BOSSES, by pull count).
local function bossNames(steps)
    local names, pulls, current = {}, 0, nil
    local list = NS.SimEvents and NS.SimEvents.BOSSES or {}
    for i, step in ipairs(steps) do
        if step.kind == "pull" then
            pulls = pulls + 1
            current = step.detail or list[(pulls - 1) % math.max(#list, 1) + 1]
            names[i] = current
        elseif step.kind == "kill" then
            names[i] = step.detail or current
        end
    end
    return names
end

local function stepState(i, pos, live)
    if not live then return "locked" end
    if i < pos then return "done" end
    if i == pos then return "busy" end
    if i == pos + 1 then return "ready" end
    return "locked"
end

local function startState(m)
    if not m.running then return "ready" end
    if not m.ready or m.pos == 0 then return "busy" end
    return "done"
end

local function ranLine(now, at)
    local ago = NS.WindowFooter.Ago((tonumber(now) or 0) - (tonumber(at) or 0))
    return L["Ran %s ago."]:format(ago)
end

local function tipOf(row, what, m)
    if row.ranAt and not row.actionable then
        return { row.label, ranLine(m.now, row.ranAt), L["Already played: clicking it does nothing."] }
    end
    local act
    if row.ahead then act = L["Click to run every step up to this one, in order."]
    elseif row.actionable then act = L["Click to run it."] end
    return { row.label, what, act or L["Not yet: run the steps before it first."], L["Typed: %s"]:format(row.command) }
end

local function startRow(m)
    local label = L["Start: %s"]:format(SP.SCENARIO_LABEL[m.scenario] or tostring(m.scenario))
    local row = { key = "start", index = 0, label = label, command = SP.StartCommand(m.scenario, m.size),
        state = startState(m), actionable = not m.running, ranAt = m.startedAt }
    row.tip = tipOf(row, START_TIP, m)
    return row
end

local function timelineRow(m, i, step, boss)
    local live = m.running and m.ready
    local row = { key = "step", index = i, label = SP.StepLabel(step, boss), command = slashOf("step"),
        state = stepState(i, m.pos, live), actionable = live and i > m.pos or false,
        ahead = live and i > m.pos + 1 or false, ranAt = step.ranAt }
    row.tip = tipOf(row, stepTip(step), m)
    -- A played loot step's tooltip names each drop and where it went, after when it ran.
    if step.report then
        local R = NS.SimReport
        for k, line in ipairs(R.TipLines(step.report, NS.LootFeed.Get, R.View())) do table.insert(row.tip, 2 + k, line) end
    end
    return row
end

local function stopRow(m, index)
    local row = { key = "stop", index = index, label = L["Stop simulation"], command = slashOf("stop"),
        state = m.running and "cancel" or "locked", actionable = m.running == true }
    row.tip = { row.label, STOP_TIP, L["Typed: %s"]:format(row.command) }
    return row
end

--- The panel's rows (pure): `Start`, one per timeline step, `Stop`. `m` = { running, ready,
--- scenario, size, steps, pos, startedAt, now }; each row { key = start|step|stop, index, label,
--- command, state = done|busy|ready|locked|cancel, actionable, ahead, ranAt, tip = { lines } }.
--- @param m table
--- @return table rows
function SP.Compose(m)
    local steps = m.steps or {}
    local rows = { startRow(m) }
    local bosses = bossNames(steps)
    for i, step in ipairs(steps) do rows[#rows + 1] = timelineRow(m, i, step, bosses[i]) end
    rows[#rows + 1] = stopRow(m, #steps + 1)
    return rows
end

--- The run controls' state (pure), from NS.SimScenario.Status() (nil: no timeline) and whether a
--- simulation runs: { running, run, pause = { verb, label, enabled }, restart, stop }.
--- @param st table|nil
--- @param running boolean
--- @return table
function SP.Controls(st, running)
    if not running then return { running = false } end
    local left = st ~= nil and st.ready and st.pos < st.steps
    local pause = { verb = "pause", label = L["Pause"], enabled = st ~= nil and st.playing == true }
    if st and st.paused then pause = { verb = "resume", label = L["Resume"], enabled = left == true } end
    return { running = true, run = left == true and not st.playing, pause = pause,
        restart = st ~= nil, stop = true }
end

-- ── the model ───────────────────────────────────────────────────────────────────────────────

-- The picker's choice, session-only: the scenario and the raid size (0: random).
local choice = { scenario = "key", size = 0 }

-- The running simulation's model. A session started without a scenario (no timeline) has no steps.
local function runningModel()
    local SC = NS.SimScenario
    local s = NS.Sim.Session() or {}
    local st = SC.Status() or { ready = false, pos = 0 }
    return { running = true, ready = st.ready, scenario = s.scenario or "custom", size = st.size,
        steps = SC.Steps() or {}, pos = st.pos, startedAt = s.startedAt, now = GetTime() }, SC.Status()
end

-- With no simulation running: the picker's scenario, previewed.
local function previewModel()
    local SC = NS.SimScenario
    return { running = false, scenario = choice.scenario, size = choice.size,
        steps = SC.Timeline(SC.SCENARIOS[choice.scenario]), pos = 0, now = GetTime() }, nil
end

local function model()
    if NS.Sim.IsActive() then return runningModel() end
    return previewModel()
end

-- ── actions: the typed verbs ────────────────────────────────────────────────────────────────

local function verb(line)
    return NS.SimVerbs.Run(line)
end

local function isRaid(name)
    local def = NS.SimScenario.SCENARIOS[name]
    return def ~= nil and def.kind == "raid"
end

--- Start the picker's scenario, through `/dw sim start`.
--- @return boolean
function SP.StartChosen()
    local size = isRaid(choice.scenario) and tonumber(choice.size) or 0
    local line = "start " .. choice.scenario
    if size > 0 then line = line .. " " .. size end
    return verb(line)
end

--- Run every step up to and including timeline step `index`, in order, through `/dw sim step`;
--- stops early when a step does nothing (the pool not ready, the timeline done). Answers how many ran.
--- @param index number
--- @return number
function SP.RunTo(index)
    local SC, n = NS.SimScenario, 0
    local st = SC.Status()
    while st and st.pos < index and n < st.steps do
        if not verb("step") then break end
        n = n + 1
        st = SC.Status()
    end
    return n
end

--- Click row `index` of the composed rows (1 is Start): re-composed first, so a stale or locked
--- row never acts. Answers whether it acted.
--- @param index number
--- @return boolean
function SP.ClickRow(index)
    local row = SP.Compose((model()))[index]
    if not (row and row.actionable) then return false end
    if row.key == "start" then return SP.StartChosen() end
    if row.key == "stop" then return verb("stop") end
    return SP.RunTo(row.index) > 0
end

--- Choose the picker's scenario (a SCENARIOS name) and raid size (0: random).
--- @param name string|nil
--- @param size number|nil
function SP.Choose(name, size)
    if name and NS.SimScenario.SCENARIOS[name] then choice.scenario = name end
    if size then choice.size = tonumber(size) or 0 end
    SP.Refresh()
end

--- The picker's choice: { scenario, size }.
--- @return table
function SP.Choice()
    return { scenario = choice.scenario, size = choice.size }
end

-- ── the frame ───────────────────────────────────────────────────────────────────────────────

local frame

local function store()
    local db = NS.addon and NS.addon.db
    local p = db and db.profile
    if not p then return {} end
    if type(p.simPanel) ~= "table" then p.simPanel = {} end
    return p.simPanel
end

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then store().point = { point, relativePoint, x, y } end
end

local function edge(f, method)
    local v = f[method] and f[method](f)
    return type(v) == "number" and v or nil
end

local function screenWidth()
    local w = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    return type(w) == "number" and w or nil
end

-- Beside the Drop Watcher window (right, else left, else at the screen's right edge), or right of
-- center while the window is closed.
local function dock()
    local W = NS.Window
    local win = W and W.IsShown() and W.Frame()
    if not win then
        frame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)
        frame.dock = "center"
        return
    end
    local side = NS.MineCells.DockSide(edge(win, "GetLeft"), edge(win, "GetRight"), WIDTH, screenWidth(), K.DOCK_GAP)
    if side == "right" then
        frame:SetPoint("TOPLEFT", win, "TOPRIGHT", K.DOCK_GAP, 0)
    elseif side == "left" then
        frame:SetPoint("TOPRIGHT", win, "TOPLEFT", -K.DOCK_GAP, 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
    end
    frame.dock = side
end

local function applyPoint()
    frame:ClearAllPoints()
    local pt = store().point
    if type(pt) == "table" then
        frame:SetPoint(pt[1], UIParent, pt[2], pt[3] or 0, pt[4] or 0)
        frame.dock = "saved"
        return
    end
    dock()
end

local function setColor(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function onRowEnter(b)
    local c = b.row and b.row.actionable and HOVER[b.row.state]
    if c then setColor(b.text, c) end
end

local function onRowLeave(b)
    if b.row then setColor(b.text, SP.COLORS[b.row.state] or SP.COLORS.locked) end
end

local function rowTip(b)
    return unpack(b.row and b.row.tip or {})
end

local function newRow(i)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(ROW_W, ROW_H)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_H + PAD + (i - 1) * (ROW_H + GAP)))
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(DOT, DOT)
    b.dot:SetPoint("LEFT", b, "LEFT", DOT_X, 0)
    -- The check of a completed step: the catalog's tick, as a texture (PerfPanel's note: a text
    -- tick renders as tofu in the default font).
    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetSize(CHECK, CHECK)
    b.check:SetPoint("CENTER", b.dot, "CENTER", 0, 0)
    b.check:SetTexture(NS.Icon("confirm"))
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b, "LEFT", LABEL_X, 0)
    b.text:SetJustifyH("LEFT")
    b.cmd = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.cmd:SetPoint("RIGHT", b, "RIGHT", -CMD_PAD, 0)
    b.cmd:SetJustifyH("RIGHT")
    setColor(b.cmd, CMD_COLOR)
    b.index = i
    b:SetScript("OnClick", function() SP.ClickRow(b.index) end)
    NS.Window.AttachTooltip(b, function() return rowTip(b) end)
    b:HookScript("OnEnter", onRowEnter)
    b:HookScript("OnLeave", onRowLeave)
    return b
end

local function paintRow(b, row)
    b.row = row
    b.text:SetText(row.label)
    b.cmd:SetText(row.command)
    local c = SP.COLORS[row.state] or SP.COLORS.locked
    setColor(b.text, c)
    local done = row.state == "done" and b.check:GetTexture() ~= nil
    if b.dot.SetColorTexture then b.dot:SetColorTexture(c[1], c[2], c[3], row.state == "locked" and 0.35 or 1) end
    b.dot:SetShown(not done)
    b.check:SetVertexColor(c[1], c[2], c[3])
    b.check:SetShown(done)
    if row.actionable then b:Enable() else b:Disable() end
    -- What was painted, for the headless suite (PerfPanel records the same three).
    b.__label, b.__state, b.__command = row.label, row.state, row.command
    b:Show()
end

-- ── the picker and the controls ─────────────────────────────────────────────────────────────

local function button(parent, width, text, onClick, tip)
    local b = NS.Window.TextButton(parent, width, nil, text, onClick)
    if b.label then
        b.label:ClearAllPoints()
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    NS.Window.AttachTooltip(b, tip)
    return b
end

local function scenarioOptions()
    local out = {}
    for _, name in ipairs(NS.SimScenario.NAMES) do out[#out + 1] = { value = name, label = SP.SCENARIO_LABEL[name] } end
    return out
end

local function sizeOptions()
    local out = {}
    for _, n in ipairs(SP.SIZES) do
        out[#out + 1] = { value = n, label = n == 0 and L["Members: random"] or L["Members: %d"]:format(n) }
    end
    return out
end

local function buildPicker(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetSize(ROW_W, BAR_H)
    bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
    bar.scenario = NS.MakeDropdown(bar, 140)
    if bar.scenario then
        bar.scenario:SetPoint("LEFT", bar, "LEFT", 0, 0)
        bar.scenario:SetOptions(scenarioOptions())
        bar.scenario.onSelect = function(v) SP.Choose(v) end
        NS.Window.AttachTooltip(bar.scenario, function() return L["Scenario"], L["The scenario Start simulates."] end)
    end
    bar.size = NS.MakeDropdown(bar, 120)
    if bar.size then
        bar.size:SetPoint("LEFT", bar, "LEFT", 146, 0)
        bar.size:SetOptions(sizeOptions())
        bar.size.onSelect = function(v) SP.Choose(nil, v) end
        NS.Window.AttachTooltip(bar.size, function() return L["Members"], L["How many members a raid has besides you."] end)
    end
    bar.start = button(bar, BUTTON_W, L["Start"], function() SP.StartChosen() end,
        function() return L["Start"], L["Typed: %s"]:format(SP.StartCommand(choice.scenario, choice.size)) end)
    bar.start:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    f.picker = bar
end

local CONTROLS = {
    { key = "run", label = L["Run all"], tip = function()
        return L["Plays every step left, one every %s seconds, as `/dw sim run` does."]:format(
            NS.SimScenario.DelayText(NS.SimScenario.StepDelay()))
    end },
    { key = "pause", label = L["Pause"], tip = L["Pause holds the next step; Resume plays on from it."] },
    { key = "restart", label = L["Restart"], tip = L["Stops this scenario and starts the same one again."] },
    { key = "stop", label = L["Stop"], tip = STOP_TIP },
}

local function controlVerb(key)
    if key == "pause" then return frame.controls.pause.verb or "pause" end
    return key
end

local function buildControls(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetSize(ROW_W, BAR_H)
    bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
    for i, c in ipairs(CONTROLS) do
        local b = button(bar, BUTTON_W, c.label, function() verb(controlVerb(c.key)) end,
            function()
                local tip = type(c.tip) == "function" and c.tip() or c.tip
                return c.label, tip, L["Typed: %s"]:format(slashOf(controlVerb(c.key)))
            end)
        b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (BUTTON_W + BUTTON_GAP), 0)
        bar[c.key] = b
    end
    f.controls = bar
end

local function setEnabled(b, on)
    if on then b:Enable() else b:Disable() end
    b:SetAlpha(on and 1 or 0.45)
end

local function paintControls(ctl)
    local bar = frame.controls
    bar:SetShown(ctl.running)
    frame.picker:SetShown(not ctl.running)
    if not ctl.running then return end
    setEnabled(bar.run, ctl.run)
    bar.pause.verb = ctl.pause.verb
    if bar.pause.label then bar.pause.label:SetText(ctl.pause.label) end
    bar.pause.__label = ctl.pause.label
    setEnabled(bar.pause, ctl.pause.enabled)
    setEnabled(bar.restart, ctl.restart)
    setEnabled(bar.stop, ctl.stop)
end

local function paintPicker()
    local bar = frame.picker
    if bar.scenario then bar.scenario:SelectValue(choice.scenario) end
    if bar.size then
        bar.size:SelectValue(choice.size)
        bar.size:SetShown(isRaid(choice.scenario))
    end
end

-- ── building and painting ───────────────────────────────────────────────────────────────────

local function buildTitle(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -6)
    f.title:SetText(L["%s - Simulation"]:format(NS.BRAND))
    f.closeButton = NS.MakeCloseButton(f, function() SP.Hide() end)
    if f.closeButton then f.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -(TITLE_H - 18) / 2) end
end

local function build()
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame = f
    f:SetSize(WIDTH, TITLE_H + PAD * 3 + BAR_H)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePoint()
    end)
    buildTitle(f)
    f.rows = {}
    buildPicker(f)
    buildControls(f)
    NS.ApplySkin(f)
    f:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, FRAME_NAME) end
    return f
end

local function paintRows(rows)
    for i, row in ipairs(rows) do
        frame.rows[i] = frame.rows[i] or newRow(i)
        paintRow(frame.rows[i], row)
    end
    for i = #rows + 1, #frame.rows do frame.rows[i]:Hide() end
    frame:SetHeight(TITLE_H + PAD * 3 + #rows * (ROW_H + GAP) + BAR_H)
end

-- Opened while the window was closed, the panel waited right of center; once the window opens (a
-- slow pool opens it later, in modules/SimScenario.lua's ready()) it docks beside it instead of
-- sitting over it. A dragged (saved) position is never moved.
local function redock()
    if frame.dock ~= "center" or not frame:IsShown() then return end
    local W = NS.Window
    if W and W.IsShown() then applyPoint() end
end

--- Repaint every row and control from the timeline. Cheap and idempotent: called on every move
--- the timeline reports and on every show. A no-op before the first show.
function SP.Refresh()
    if not frame then return end
    redock()
    local m, st = model()
    if m.running and NS.SimScenario.SCENARIOS[m.scenario] then choice.scenario = m.scenario end
    frame.__rows = SP.Compose(m)
    paintRows(frame.__rows)
    paintControls(SP.Controls(st, m.running))
    paintPicker()
end

--- Open the panel (built on the first call), placed beside the window unless the player moved it.
function SP.Show()
    if NS.IsStoodDown() then return end
    if not frame then build() end
    applyPoint()
    SP.Refresh()
    frame:Show()
end

function SP.Hide()
    if frame then frame:Hide() end
end

--- @return boolean
function SP.IsShown()
    return frame ~= nil and frame:IsShown() == true
end

--- `/dw sim panel`: open it, or close it when it is open.
function SP.Toggle()
    if SP.IsShown() then SP.Hide() else SP.Show() end
end

--- Forget the dragged position: the panel docks beside the window again (Reset position).
function SP.ResetPosition()
    store().point = nil
    if frame then applyPoint() end
end

--- The built frame, or nil before the first Show. For the suites.
function SP.Frame() return frame end

--- The panel at a glance, for the suites: { built, shown, dock, point, rows (the composed rows) }.
--- @return table
function SP.Stats()
    return { built = frame ~= nil, shown = SP.IsShown(), dock = frame and frame.dock, point = store().point,
        rows = frame and frame.__rows or {} }
end

-- Every move of the timeline repaints the panel (typed, clicked or played).
NS.SimScenario.AddListener(function() SP.Refresh() end)

-- Standing down closes it; the simulation it drove has already stopped (modules/Sim.lua's step
-- runs first).
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    SP.Hide()
end
