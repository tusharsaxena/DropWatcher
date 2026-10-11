local _, NS = ...
-- modules/TradeRules.lua — the trade estimator (design spec §7.1-§7.3): can a drop change hands?
--
-- PURE. It takes plain tables and makes no WoW API call, reads no saved variable and keeps no
-- state, so the headless suite drives it row by row (test_trade_rules). The rule tables are data
-- in core/Constants.lua (C.TRADE_RULES); the rule each situation takes by default is the
-- `trade.rules` defaults (defaults/Profile.lua), and the owner's per-situation settings (Settings ›
-- Trade, the `trade.rules.<situation>` rows) reach it as the plain `ctx.rules` map.
--
--   facts      = { ilvl, bindType = Enum.ItemBind, warbound = bool, bonusRoll = bool }  -- ItemFacts
--   looterEval = Evaluate's output for the looter, or nil while they are not inspected
--   ctx        = { situation, rules = { [situation] = ruleName }, now, droppedAt,
--                  inspectAge, inspectReason }
--
-- The answer: { state, reasonKey, args, basis, age, expiresAt, rule }, where state is "yes",
-- "likely", "unknown" or "no" and basis "bind", "rule" or "inspect" (`age` is the inspect's age).
-- expiresAt stays nil: only the own-item timer (TradeTimer, spec §7.4) knows an exact expiry.
--
-- The looter check reads the evaluation's ilvlDelta, not its verdict: the game's rule compares
-- item levels, so a scored sidegrade at a higher item level is still an upgrade for the looter.
--
-- It NEVER THROWS: garbage in answers `unknown` with a reason, and the public entry point runs
-- under pcall as the last line of defense.

NS.TradeRules = NS.TradeRules or {}
local TR = NS.TradeRules
local C = NS.Constants

-- The rule each situation takes when `ctx.rules` names none (design spec §7.2).
local DEFAULT_RULES = NS.C.PROFILE.trade.rules

local function isTable(v) return type(v) == "table" end

-- A real number, or nil (NaN and every non-number are nil).
local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function result(state, reasonKey, basis, args)
    return { state = state, reasonKey = reasonKey, basis = basis, args = args or {} }
end

-- ---------------------------------------------------------------------------------------------
-- The rule per situation and the owner override (spec §7.3)
-- ---------------------------------------------------------------------------------------------

--- True when `name` is one of the rule names (C.TRADE_RULES).
function TR.IsRule(name)
    return type(name) == "string" and C.TRADE_RULES[name] ~= nil
end

local function defaultRule(situation)
    return DEFAULT_RULES[situation] or C.TRADE_RULE_DEFAULT
end

--- The rule in force in `situation`: the override in `rules` when it names a rule, else the
--- situation's default rule (an unknown situation takes C.TRADE_RULE_DEFAULT). The second answer is
--- true only when an override changes the default.
function TR.RuleFor(situation, rules)
    local default = defaultRule(situation)
    local override = isTable(rules) and situation ~= nil and rules[situation] or nil
    if TR.IsRule(override) and override ~= default then return override, true end
    return default, false
end

--- Settings › Trade's list: one row per situation in C.SITUATIONS order,
--- { situation, rule, default, overridden }.
function TR.Rules(rules)
    local out = {}
    for _, s in ipairs(C.SITUATIONS) do
        local rule, overridden = TR.RuleFor(s.key, rules)
        out[#out + 1] = { situation = s.key, rule = rule, default = defaultRule(s.key), overridden = overridden }
    end
    return out
end

--- Empties the override map in place, so every situation takes its default again. Answers the
--- map (nil when it is not a table).
function TR.Reset(rules)
    if not isTable(rules) then return nil end
    for k in pairs(rules) do rules[k] = nil end
    return rules
end

-- ---------------------------------------------------------------------------------------------
-- The estimate (spec §7.2)
-- ---------------------------------------------------------------------------------------------

-- The bind checks, in the table's order: warbound, bonus roll, BoE. Nil when none applies.
local function bindCheck(facts)
    if facts.warbound == true or C.TRADE_ACCOUNT_BIND[facts.bindType] then
        return result("no", "warbound", "bind")
    end
    if facts.bonusRoll == true then return result("no", "bonusRoll", "bind") end
    if C.TRADE_BOE_BIND[facts.bindType] then return result("yes", "boe", "bind") end
    return nil
end

-- `no expired` when the drop is older than the rule's window; nil without a clock or a drop time.
local function expiryCheck(rule, ctx)
    local now, at = num(ctx.now), num(ctx.droppedAt)
    if not now or not at then return nil end
    local window = num(rule.window) or C.TRADE_WINDOW
    local age = now - at
    if age > window then return result("no", "expired", "rule", { age, window }) end
    return nil
end

local function noInspect(looterEval, ctx)
    local reason = ctx.inspectReason
    if reason == nil and isTable(looterEval) then reason = "noBaseline" end
    return result("unknown", "noInspect", "inspect", { reason or "pending" })
end

-- notUpgradeForLooter: the drop's item level against the looter's baseline.
local function looterCheck(facts, looterEval, ctx)
    if not isTable(looterEval) or looterEval.verdict == "unknown" then return noInspect(nil, ctx) end
    local ilvl, delta = num(facts.ilvl), num(looterEval.ilvlDelta)
    local out
    if delta then
        local theirs = ilvl and ilvl - delta or nil
        if delta > 0 then
            out = result("no", "upgradeForLooter", "inspect", { ilvl, theirs })
        else
            out = result("likely", "notUpgrade", "inspect", { ilvl, theirs })
        end
    elseif looterEval.verdict == "upgrade" then
        out = result("no", "upgradeForLooter", "inspect", { ilvl })  -- an empty slot
    else
        return noInspect(looterEval, ctx)
    end
    out.age = num(ctx.inspectAge)
    return out
end

local function estimate(facts, looterEval, ctx)
    if not isTable(facts) then return result("unknown", "badFacts", "rule") end
    ctx = isTable(ctx) and ctx or {}
    local ruleName = TR.RuleFor(ctx.situation, ctx.rules)
    local rule = C.TRADE_RULES[ruleName]
    local out = bindCheck(facts)
    if not out and rule.tradeable == false then out = result("no", "legacy", "rule") end
    out = out or expiryCheck(rule, ctx)
    if not out and rule.ilvlRule == "none" then out = result("likely", "groupLoot", "rule") end
    out = out or looterCheck(facts, looterEval, ctx)
    out.rule = ruleName
    return out
end

--- The trade estimate for a drop (design spec §7.2): the bind checks, then the situation's rule,
--- the trade window and the looter's item level. Never throws.
function TR.Estimate(facts, looterEval, ctx)
    local ok, res = pcall(estimate, facts, looterEval, ctx)
    if ok then return res end
    return result("unknown", "error", "rule", { tostring(res) })
end
