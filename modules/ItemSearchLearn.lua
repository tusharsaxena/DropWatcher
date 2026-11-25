local _, NS = ...
-- modules/ItemSearchLearn.lua — the profession window's reagents, Item Search's fallback for the
-- recipes the shipped table lacks (DropWatcher#17, Item Search spec §4.2 B, the owner's "A with a B
-- fallback"). WoW Forever's alone (C.FEATURE.itemSearch).
--
-- WHEN. A profession window opens (TRADE_SKILL_SHOW) or its list updates
-- (TRADE_SKILL_LIST_UPDATE): C.ITEM_SEARCH.LEARN_DELAY seconds after the last of a burst, the
-- window's recipes are read through NS.Compat.TradeSkillRecipes (C_TradeSkillUI on WoW Forever).
-- Only while Item Search is on (IS.Wanted) and only out of combat: a read asked for in combat waits
-- for PLAYER_REGEN_ENABLED.
--
-- WHAT. Every listed recipe the shipped table (core/RecipeReagentsForever.lua) does NOT carry goes
-- into IS.Learned(), account-wide: `learnedRecipes[spell] = { skillLine, reagents, made, name,
-- build }`, `build` the client's (NS.Compat.ClientBuild). A recipe the table carries is never
-- written, and an entry the table later covers is dropped (IS.Learned's prune). Item Search reads
-- these after the table (modules/ItemSearchModel.lua's IS.CraftingRows). A write that changed
-- anything empties Item Search's cache.

local IS = NS.ItemSearch
local C  = NS.Constants

local LR = {}
IS.Learn = LR

local pending = { timer = nil, combat = false }

-- Whether two reagent maps are the same.
local function sameReagents(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function sameEntry(old, row, build)
    return type(old) == "table" and old.skillLine == row.skillLine and old.made == row.made
        and old.name == row.name and old.build == build and sameReagents(old.reagents, row.reagents)
end

--- Write `rows` (NS.Compat.TradeSkillRecipes' answer) into `learned`, skipping every spell
--- `shipped` (the table's recipes) carries. Pure. Answers how many entries were added or changed.
--- @param learned table
--- @param rows table|nil
--- @param shipped table|nil
--- @param build string|nil
--- @return number
function LR.Merge(learned, rows, shipped, build)
    if type(learned) ~= "table" or type(rows) ~= "table" then return 0 end
    shipped = type(shipped) == "table" and shipped or {}
    local n = 0
    for _, row in ipairs(rows) do
        local spell = type(row) == "table" and row.spell
        if type(spell) == "number" and shipped[spell] == nil and type(row.reagents) == "table"
            and not sameEntry(learned[spell], row, build) then
            local reagents = {}
            for item, count in pairs(row.reagents) do reagents[item] = count end
            learned[spell] = { skillLine = row.skillLine, reagents = reagents, made = row.made,
                name = row.name, build = build }
            n = n + 1
        end
    end
    return n
end

--- Read the open profession window now (out of combat, Item Search on). Answers how many entries
--- were added or changed; in combat it waits for the combat's end and answers 0.
--- @return number
function LR.Scan()
    if not IS.Wanted() then return 0 end
    if NS.Compat.InCombatLockdown() then
        pending.combat = true
        return 0
    end
    pending.combat = false
    local learned = IS.Learned()
    local RR = NS.RecipeReagents
    local recipes = RR and RR.Get()
    local n = LR.Merge(learned, NS.Compat.TradeSkillRecipes(), recipes and recipes.recipes, NS.Compat.ClientBuild())
    if n > 0 then
        IS.Invalidate()
        NS.Debug("SEARCH", "profession window: %d recipe(s) learned", n)
    end
    return n
end

--- A profession window event: read it LEARN_DELAY seconds after the last of a burst.
function LR.Changed()
    if not IS.Wanted() then return end
    if pending.timer then pending.timer:Cancel() end
    pending.timer = C_Timer.NewTimer(C.ITEM_SEARCH.LEARN_DELAY, function()
        pending.timer = nil
        LR.Scan()
    end)
end

--- Whether a read is queued (the burst's timer) and whether one waits for combat's end. For tests.
--- @return boolean queued, boolean waitingForCombat
function LR.Pending()
    return pending.timer ~= nil, pending.combat == true
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- PLAYER_REGEN_ENABLED is shared (core/DropWatcher.lua's dispatcher). Every row is WoW Forever's.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "TRADE_SKILL_SHOW", "OnItemSearchTradeSkill", clients = { "forever" } }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "TRADE_SKILL_LIST_UPDATE", "OnItemSearchTradeSkill", clients = { "forever" } }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnItemSearchLearnRegen", clients = { "forever" } }

function NS.addon.OnItemSearchTradeSkill()
    LR.Changed()
end

function NS.addon.OnItemSearchLearnRegen()
    if pending.combat then LR.Scan() end
end

-- A stand-down drops a queued read; the next window event queues it again.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending.timer then pending.timer:Cancel() end
    pending.timer, pending.combat = nil, false
end
