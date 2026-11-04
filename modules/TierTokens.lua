local _, NS = ...
-- modules/TierTokens.lua — tier tokens judged as gear (issue #13, categories design spec §7): the slot
-- a token makes, and the best slot of an omni token (a Curio, which makes any tier piece).
--
-- PURE, like the kernel it serves: plain tables in, plain tables out, no WoW API, no saved
-- variable, no state. modules/ItemFacts.lua calls Listed and SlotOf while it builds the facts, and
-- hands SlotOf the tooltip rung as a reader (NS.Compat.TierTokenSlot); NS.Evaluate's run calls Fold
-- at call time, inside its own pcall.
--
-- THE SLOT (SlotOf), first rung that answers wins:
--   1. the curated table, C.TIER_TOKENS[itemID].slot: one of C.TIER_SLOTS, or "any" (a Curio);
--   2. the tooltip: a line naming one of the tier slots (read only when the table has no answer);
--   3. nothing: the slot stays nil and the kernel's verdict `unknown`, reason `tierToken`.
-- ItemFacts then sets the facts' equipLoc to a concrete slot, so every gear reader works unchanged.
--
-- THE FOLD (Fold) runs the kernel once per tier slot, each on a shallow copy of the facts with that
-- slot, and keeps the best answer: upgrade beats sidegrade beats downgrade, then the larger
-- ilvlDelta (an empty slot the largest), then the earlier slot in C.TIER_SLOTS. The chosen slot is
-- the answer's `tokenSlot` (the Me cell names it). With no slot ranked, the first slot's answer
-- stands, with no `tokenSlot` (a class refusal reads the same in every slot). The facts table is
-- never written.

NS.TierTokens = NS.TierTokens or {}
local TT = NS.TierTokens
local C = NS.Constants

-- The verdicts the fold ranks, best first.
local RANK = { upgrade = 3, sidegrade = 2, downgrade = 1 }

local TIER_SLOT = {}
for _, slot in ipairs(C.TIER_SLOTS) do TIER_SLOT[slot] = true end

-- A slot a token may name: a tier slot, or "any" where `allowAny`.
local function validSlot(slot, allowAny)
    if type(slot) ~= "string" then return nil end
    if TIER_SLOT[slot] or (allowAny and slot == "any") then return slot end
    return nil
end

--- True when the curated table lists the item as a tier token (C.TIER_TOKENS).
--- @param itemID number|nil
--- @return boolean
function TT.Listed(itemID)
    return itemID ~= nil and type(C.TIER_TOKENS[itemID]) == "table"
end

--- The slot a tier token makes and where it was read: the table's slot (`table`), else the
--- tooltip's (`tooltip`, asked of `readTooltip` only then), else nil.
--- @param facts table the token's facts (`itemID`)
--- @param readTooltip function|nil () -> "INVTYPE_*" | nil
--- @return string|nil slot, string|nil source
function TT.SlotOf(facts, readTooltip)
    if type(facts) ~= "table" then return nil end
    local listed = facts.itemID ~= nil and C.TIER_TOKENS[facts.itemID]
    local slot = type(listed) == "table" and validSlot(listed.slot, true)
    if slot then return slot, "table" end
    slot = type(readTooltip) == "function" and validSlot(readTooltip(), false)
    if slot then return slot, "tooltip" end
    return nil
end

-- The difference used to break a tie: an empty slot is the largest.
local function gain(res)
    if res.baselineSlot and not res.baseline then return math.huge end
    return type(res.ilvlDelta) == "number" and res.ilvlDelta or -math.huge
end

local function better(res, best)
    local a, b = RANK[res.verdict], best and RANK[best.verdict]
    if not a then return false end
    if not b then return true end
    if a ~= b then return a > b end
    return gain(res) > gain(best)
end

local function copyAs(facts, slot)
    local f = {}
    for k, v in pairs(facts) do f[k] = v end
    f.equipLoc, f.tokenSlot = slot, slot
    return f
end

--- An omni token judged in its best tier slot (see the header): `run` is the kernel's own
--- evaluation, `run(facts, candidate, opts)`. Answers that slot's evaluation, `tokenSlot` set; with
--- no slot ranked, the first slot's evaluation as it is.
--- @return table
function TT.Fold(facts, candidate, opts, run)
    local best, bestSlot, first
    for _, slot in ipairs(C.TIER_SLOTS) do
        local res = run(copyAs(facts, slot), candidate, opts)
        first = first or res
        if better(res, best) then best, bestSlot = res, slot end
    end
    if not best then return first end
    best.tokenSlot = bestSlot
    return best
end
