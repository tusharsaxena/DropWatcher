local _, NS = ...
-- settings/SimVerbs.lua — `/dw sim`, the simulator's slash verbs (simulator spec §4): status and
-- usage, `start <scenario> [size]`, `run`, `step`, `pull`, `kill`, `loot [n] [player|me]`,
-- `lockdown on|off`, `trade <dropID>`, `pause`, `resume`, `restart`, `stop` and `panel` (the step
-- panel, modules/SimPanel.lua, which a bare `/dw sim` and a start also open). settings/Slash.lua lists `sim` in NS.COMMANDS
-- (a feature verb, so the dispatcher refuses it while the addon is disabled); this file answers it.
--
-- Parse is PURE (test_sim_scenario drives it): the argument in, { verb, ... } out. Run calls the
-- simulator's own entry points (modules/SimScenario.lua, modules/SimEvents.lua, modules/Sim.lua)
-- and prints what they answered; it never reaches the engine around them.

NS.SimVerbs = NS.SimVerbs or {}
local V = NS.SimVerbs
local L = NS.L

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function words(s)
    local out = {}
    for w in trim(s):gmatch("%S+") do out[#out + 1] = w end
    return out
end

-- ── parse (pure) ────────────────────────────────────────────────────────────────────────────

local BARE = { run = true, step = true, pull = true, kill = true, stop = true, status = true, pause = true,
    resume = true, restart = true, panel = true }

local function parseLoot(w)
    local n = tonumber(w[2])
    local first = n and 3 or 2
    local who = table.concat(w, " ", first)
    if n and (n < 1 or n ~= math.floor(n)) then return { verb = "usage", form = "loot" } end
    return { verb = "loot", n = n, who = who ~= "" and who or nil }
end

local function parseLockdown(w)
    local v = (w[2] or ""):lower()
    if v == "on" or v == "off" then return { verb = "lockdown", on = v == "on" } end
    return { verb = "usage", form = "lockdown" }
end

local function parseStart(w)
    local name = (w[2] or ""):lower()
    if name == "" then return { verb = "usage", form = "start" } end
    return { verb = "start", scenario = name, size = tonumber(w[3]) }
end

local function parseTrade(w)
    local id = tonumber(w[2])
    if not id then return { verb = "usage", form = "trade" } end
    return { verb = "trade", id = id }
end

local PARSERS = { loot = parseLoot, lockdown = parseLockdown, start = parseStart, trade = parseTrade }

--- `/dw sim`'s argument as a command (pure): { verb, ... }. `status` for an empty argument, with
--- `open` (a bare `/dw sim` opens the panel too); `usage` (with the `form` it was missing) for an
--- argument that does not read.
--- @param rest string|nil
--- @return table
function V.Parse(rest)
    local w = words(rest)
    if #w == 0 then return { verb = "status", open = true } end
    local verb = (w[1] or "status"):lower()
    if PARSERS[verb] then return PARSERS[verb](w) end
    if BARE[verb] then return { verb = verb } end
    return { verb = "usage", form = verb }
end

-- ── the lines ───────────────────────────────────────────────────────────────────────────────

-- Why a verb did nothing, as the line to print.
local WHY = {
    notRunning = "No simulation is running: start one with /dw sim start <scenario>.",
    building   = "The simulation is still setting up its items: try again in a moment.",
    done       = "The simulation's timeline has finished. /dw sim stop ends it.",
    playing    = "The timeline is already playing.",
    noPool     = "The simulation has no items to drop.",
    noLooter   = "No one by that name is in the simulated group.",
    engaged    = "A simulated boss is already engaged: /dw sim kill first.",
    notEngaged = "No simulated boss is engaged: /dw sim pull first.",
    noDrop     = "No drop has that id.",
    notSim     = "That drop is not one the simulation made.",
    notInBags  = "That drop is no longer in your simulated bags.",
    expired    = "That drop's trade window has closed.",
    noPartner  = "No simulated member can take part in that trade.",
    notPlaying = "The timeline is not playing: /dw sim run plays it.",
    notPaused  = "The timeline is not paused.",
    unknown    = "Unknown scenario.",
}

local function why(code)
    if code == "refused" then return end   -- the refusal line is already printed
    NS.Print(L[WHY[code] or "Nothing happened."])
end

--- The usage lines.
--- @return table
function V.UsageLines()
    local s = NS.SLASH .. " sim"
    return {
        L["Usage: |cffFFFF00%s|r"]:format(s .. " start <" .. table.concat(NS.SimScenario.NAMES, "|") .. "> [size]"),
        L["  |cffFFFF00%s|r plays the timeline, |cffFFFF00%s|r one event at a time"]:format(s .. " run", s .. " step"),
        L["  |cffFFFF00%s|r, |cffFFFF00%s|r, |cffFFFF00%s|r, |cffFFFF00%s|r"]:format(s .. " pull", s .. " kill",
            s .. " loot [n] [player|me]", s .. " lockdown on|off"),
        L["  |cffFFFF00%s|r, |cffFFFF00%s|r"]:format(s .. " trade <drop id>", s .. " stop"),
        L["  |cffFFFF00%s|r, |cffFFFF00%s|r, |cffFFFF00%s|r, |cffFFFF00%s|r (the step panel)"]:format(s .. " pause",
            s .. " resume", s .. " restart", s .. " panel"),
    }
end

--- The status line: the running simulation at a glance, or that none runs.
--- @return string
function V.StatusLine()
    local st = NS.Sim.Status()
    if not st.active then return L["No simulation is running."] end
    local t = NS.SimScenario.Status() or { pos = 0, steps = 0 }
    return L["Simulating %s (%s): %d members, step %d of %d, %d sends printed."]:format(tostring(st.scenario),
        NS.WindowFooter.SituationLabel(st.situation), #NS.SimRoster.Get(), t.pos, t.steps, st.sends)
end

-- ── run ─────────────────────────────────────────────────────────────────────────────────────

local function status()
    NS.Print(V.StatusLine())
    for _, line in ipairs(V.UsageLines()) do NS.Print(line) end
end

local function answered(ok, code)
    if not ok then why(code) end
    return ok and true or false
end

local DO = {}

-- The verbs that answer with no simulation running.
local FREE = { status = true, usage = true, start = true, panel = true }

local function showPanel()
    if NS.SimPanel then NS.SimPanel.Show() end
end

function DO.status(c)
    status()
    if c.open then showPanel() end
    return true
end

function DO.usage() for _, line in ipairs(V.UsageLines()) do NS.Print(line) end return false end

function DO.start(c)
    local ok = answered(NS.SimScenario.Start(c.scenario, c.size))
    if ok then showPanel() end
    return ok
end

function DO.run() return answered(NS.SimScenario.Run()) end
function DO.pause() return answered(NS.SimScenario.Pause()) end
function DO.resume() return answered(NS.SimScenario.Resume()) end

function DO.restart()
    local ok = answered(NS.SimScenario.Restart())
    if ok then showPanel() end
    return ok
end

function DO.panel()
    if NS.SimPanel then NS.SimPanel.Toggle() end
    return true
end

-- The step prints its own line (modules/SimScenario.lua), as a played one does.
function DO.step()
    local step, code = NS.SimScenario.Step()
    if not step then return answered(false, code) end
    return true
end

function DO.pull()
    local enc, code = NS.SimEvents.Pull()
    if not enc then return answered(false, code) end
    NS.Print(L["Simulated pull: %s."]:format(enc.name))
    return true
end

function DO.kill()
    local enc, code = NS.SimEvents.Kill()
    if not enc then return answered(false, code) end
    NS.Print(L["Simulated kill: %s."]:format(enc.name))
    return true
end

function DO.stop() return NS.Sim.Stop("stop") end

function DO.loot(c)
    local n, code = NS.SimEvents.Loot(c.n, c.who)
    return answered(n > 0, code)
end

function DO.lockdown(c)
    NS.Sim.SetLockdown(c.on)
    NS.Print(c.on and L["Simulated chat lockdown on."] or L["Simulated chat lockdown off."])
    return true
end

function DO.trade(c)
    local ok, code = NS.SimEvents.Trade(c.id)
    if not ok then return answered(false, code) end
    NS.Print(L["Simulated trade completed for drop %d."]:format(c.id))
    return true
end

--- `/dw sim <argument>`: parse it and do it. Answers whether it did something.
--- @param rest string|nil
--- @return boolean
function V.Run(rest)
    local c = V.Parse(rest)
    if not (FREE[c.verb] or NS.Sim.IsActive()) then return answered(false, "notRunning") end
    return DO[c.verb](c)
end
