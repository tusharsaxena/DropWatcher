local _, NS = ...
-- settings/SimVerbs.lua — `/dw sim`'s host half (simulator spec §4; OWNER_SCOPE C.7, C.10): the
-- five verbs only DropWatcher's simulation has, `pull`, `kill`, `loot [n] [player|me]`,
-- `lockdown on|off` and `trade <dropID>`, the lines that say why one did nothing, their usage
-- lines and the status line's host part. settings/Slash.lua's `sim` row hands the whole argument
-- to NS.Sim:RunVerb (a feature verb, so the dispatcher refuses it while the addon is disabled), and
-- LibKa0s-Sim-1.0 owns the generic grammar: the bare form (the status, the usage and the step
-- panel), `start <scenario> [size]`, `run`, `step`, `pause`, `resume`, `restart`, `stop`, `status`
-- and `panel`; that every other verb needs a running simulation; the lines for its own failure
-- codes (in this addon's words through the descriptor's `L`, modules/Sim.lua); and that a
-- `refused` start prints nothing more than its refusal. There is no `help` verb.
--
-- THE DESCRIPTOR'S TABLES. modules/Sim.lua (loaded before this file) publishes VERBS, WHY and
-- USAGE empty and passes them to Sim:New, which reads them when a verb runs; this file fills them
-- in place at load, as modules/SimScenario.lua fills NS.SimScenarioDefs. Each VERBS row is
-- { parse = fn(words) -> cmd|nil (nil: the usage), run = fn(cmd, sim) -> ok, code }, words[1] the
-- verb; run calls the simulator's own entry points (modules/SimEvents.lua, modules/SimReport.lua,
-- NS.SimHost) and prints what they answered, never reaching the engine around them. None is
-- `free`: each needs the session.

NS.SimVerbs = NS.SimVerbs or {}
local V = NS.SimVerbs
local L = NS.L

V.VERBS = V.VERBS or {}
V.WHY = V.WHY or {}
V.USAGE = V.USAGE or {}

-- ── the verbs ───────────────────────────────────────────────────────────────────────────────

local function bare() return {} end

-- `loot [n] [player|me]`: n a whole number from 1, the rest a looter's name.
local function parseLoot(w)
    local n = tonumber(w[2])
    if n and (n < 1 or n ~= math.floor(n)) then return nil end
    local who = table.concat(w, " ", n and 3 or 2)
    return { n = n, who = who ~= "" and who or nil }
end

local function parseLockdown(w)
    local v = (w[2] or ""):lower()
    if v == "on" or v == "off" then return { on = v == "on" } end
    return nil
end

local function parseTrade(w)
    local id = tonumber(w[2])
    if not id then return nil end
    return { id = id }
end

local function runPull()
    local enc, code = NS.SimEvents.Pull()
    if not enc then return false, code end
    NS.Print(L["Simulated pull: %s."]:format(enc.name))
    return true
end

local function runKill()
    local enc, code = NS.SimEvents.Kill()
    if not enc then return false, code end
    NS.Print(L["Simulated kill: %s."]:format(enc.name))
    return true
end

-- The burst says where its drops went, as the timeline's loot step does (feedback-3 spec §0).
local function runLoot(c)
    local R = NS.SimReport
    local n, code, report = R.Loot(c.n, c.who)
    if n == 0 then return false, code end
    NS.Print(L["Simulated loot: %s."]:format(R.Summarize(report, NS.LootFeed.Get, R.View()).text))
    return true
end

local function runLockdown(c)
    NS.SimHost.SetLockdown(c.on)
    NS.Print(c.on and L["Simulated chat lockdown on."] or L["Simulated chat lockdown off."])
    return true
end

local function runTrade(c)
    local ok, code = NS.SimEvents.Trade(c.id)
    if not ok then return false, code end
    NS.Print(L["Simulated trade completed for drop %d."]:format(c.id))
    return true
end

for verb, spec in pairs({
    pull     = { parse = bare,          run = runPull },
    kill     = { parse = bare,          run = runKill },
    loot     = { parse = parseLoot,     run = runLoot },
    lockdown = { parse = parseLockdown, run = runLockdown },
    trade    = { parse = parseTrade,    run = runTrade },
}) do V.VERBS[verb] = spec end

-- ── the lines ───────────────────────────────────────────────────────────────────────────────

-- Why a host verb did nothing, by the code its entry point answered.
for code, line in pairs({
    noPool     = L["The simulation has no items to drop."],
    noLooter   = L["No one by that name is in the simulated group."],
    engaged    = L["A simulated boss is already engaged: /dw sim kill first."],
    notEngaged = L["No simulated boss is engaged: /dw sim pull first."],
    noDrop     = L["No drop has that id."],
    notSim     = L["That drop is not one the simulation made."],
    notInBags  = L["That drop is no longer in your simulated bags."],
    expired    = L["That drop's trade window has closed."],
    noPartner  = L["No simulated member can take part in that trade."],
}) do V.WHY[code] = line end

-- The host verbs' usage lines, printed after the library's own.
do
    local s = NS.SLASH .. " sim"
    local lines = {
        L["%s pull: engage the next simulated boss."]:format(s),
        L["%s kill: kill the engaged simulated boss."]:format(s),
        L["%s loot [n] [player|me]: a burst of n simulated drops."]:format(s),
        L["%s lockdown on|off: turn the simulated chat lockdown on or off."]:format(s),
        L["%s trade <drop id>: complete a simulated trade of that drop."]:format(s),
    }
    for i, line in ipairs(lines) do V.USAGE[i] = line end
end

--- The status line's host part (the descriptor's `statusLine`, printed after the library's): the
--- simulated situation, the group's size and the sends printed; nil while none runs.
--- @param status table NS.Sim:Status()
--- @param session table|nil the library's session
--- @return string|nil
function V.StatusLine(status, session)
    if not (status and status.active and session) then return nil end
    return L["Simulated %s: %d members, %d sends printed."]:format(
        NS.WindowFooter.SituationLabel(session.situation), #NS.SimRoster.Get(), NS.SimHost.counts.sends)
end
