local _, NS = ...
-- modules/TierTokens.lua — tier tokens judged as gear (issue #13, categories design spec §7): which
-- item is a token, the slot a token makes, and the best slot of an omni token (a Curio, which makes
-- any tier piece).
--
-- PURE, like the kernel it serves: plain tables in, plain tables out, no WoW API, no saved
-- variable, no state but the word lists it builds once from NS.L. modules/ItemFacts.lua calls
-- Listed, UseNamesClass, IsCurio and SlotOf while it builds the facts, and hands SlotOf the tooltip's
-- slot line as a reader (NS.Compat.TierTokenSlot); NS.Evaluate's run calls Fold at call time,
-- inside its own pcall.
--
-- THE WORDS (TT-1). A token's Use text and its name are read against English words the enUS locale
-- table holds (locales/enUS.lua, the TT-1 block), parsed by core/TextParse.lua: the class phrase
-- ("appropriate for your class"), the slot template ("set %s item") and its slot words, the slot
-- nouns of an older token's name ("Gauntlets of the Foreseen Conqueror"), and the word an omni
-- Curio's name ends with. A documented localization-§4 deviation (docs/ARCHITECTURE.md): on another
-- locale nothing matches, so every token is judged in its best tier slot (`any`), never a wrong one.
--
-- THE SLOT (SlotOf), first rung that answers wins, with the rung that answered as its source:
--   1. `table`: the curated override, C.TIER_TOKENS[itemID].slot: one of C.TIER_SLOTS, or "any";
--   2. `use`: the token's own text: its Use text's "set <slot> item", else a tooltip line that is
--      exactly a slot's localized name (the reader, asked only then);
--   3. `name`: a slot noun in the item's name, as a whole word (cloaks are not a tier slot here);
--   4. `any`: nothing read: the token is judged in its best tier slot (the fold).
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

-- The words, from the enUS locale table, built on the first read (see the header).
local words
local function vocab()
    if words then return words end
    local L, TP = NS.L, NS.TextParse
    words = {
        use = {
            phrase = L["appropriate for your class"], template = L["set %s item"],
            slots = TP.WordMap({
                INVTYPE_HEAD = L["head"], INVTYPE_SHOULDER = L["shoulder shoulders"], INVTYPE_CHEST = L["chest"],
                INVTYPE_HAND = L["hand hands"], INVTYPE_LEGS = L["leg legs"],
            }),
        },
        names = TP.WordMap({
            INVTYPE_HEAD = L["Helm Crown Hood Headpiece Circlet Cowl Helmet Faceguard"],
            INVTYPE_SHOULDER = L["Shoulders Shoulderpads Mantle Pauldrons Spaulders Shoulderguards Amice"],
            INVTYPE_CHEST = L["Chest Chestguard Chestpiece Breastplate Robe Robes Vest Tunic Raiment Hauberk Jerkin"],
            INVTYPE_HAND = L["Gauntlets Gloves Handguards Grips Handwraps Grasps"],
            INVTYPE_LEGS = L["Leggings Legguards Legplates Pants Kilt Trousers Breeches Legwraps"],
        }),
        curio = L["Curio"],
    }
    return words
end

local function plain(text) return type(text) == "string" and text ~= "" and text or nil end

--- True when a Use text says it makes a piece for the user's class ("appropriate for your class").
--- @param useText string|nil
--- @return boolean
function TT.UseNamesClass(useText)
    useText = plain(useText)
    return useText ~= nil and useText:lower():find(vocab().use.phrase:lower(), 1, true) ~= nil
end

--- The tier slot a Use text names ("set hand item"), or nil.
--- @param useText string|nil
--- @return string|nil
function TT.UseSlot(useText)
    useText = plain(useText)
    return useText and NS.TextParse.TokenUseSlot(useText, vocab().use) or nil
end

--- The tier slot a slot noun in an item's name names ("Gauntlets" -> INVTYPE_HAND), or nil.
--- @param name string|nil
--- @return string|nil
function TT.NameSlot(name)
    name = plain(name)
    return name and NS.TextParse.FirstWord(name, vocab().names) or nil
end

-- Miscellaneous subclasses a Curio is never: the collectibles'.
local NOT_CURIO = { [C.MISC_SUBCLASS.MOUNT] = true, [C.MISC_SUBCLASS.COMPANION_PET] = true,
    [C.MISC_SUBCLASS.MOUNT_EQUIPMENT] = true }

--- True for an omni Curio: an epic-or-better (quality 4+) Miscellaneous or Reagent item that is not
--- gear (no slot plan for its raw slot) and whose name ends with the word "Curio".
--- @param facts table `quality`, `classID`, `subClassID`, `rawEquipLoc`, `name`
--- @return boolean
function TT.IsCurio(facts)
    local IC = C.ITEM_CLASS
    if type(facts) ~= "table" or type(facts.quality) ~= "number" or facts.quality < 4 then return false end
    local misc = facts.classID == IC.MISCELLANEOUS and not NOT_CURIO[facts.subClassID]
    if not (misc or facts.classID == IC.REAGENT) or C.SLOT_PLAN[facts.rawEquipLoc or ""] then return false end
    local name = plain(facts.name)
    return name ~= nil and NS.TextParse.EndsWithWord(name, vocab().curio)
end

--- The slot a tier token makes and the rung that read it (see the header): the table's (`table`),
--- the token's Use text, else its tooltip slot line (`use`; `readTooltip` is asked only then), its
--- name (`name`), else `any`, `any`. Nil only for no facts.
--- @param facts table the token's facts (`itemID`, `useText`, `name`)
--- @param readTooltip function|nil () -> "INVTYPE_*" | nil
--- @return string|nil slot, string|nil source
function TT.SlotOf(facts, readTooltip)
    if type(facts) ~= "table" then return nil end
    local listed = facts.itemID ~= nil and C.TIER_TOKENS[facts.itemID]
    local slot = type(listed) == "table" and validSlot(listed.slot, true)
    if slot then return slot, "table" end
    slot = TT.UseSlot(facts.useText) or (type(readTooltip) == "function" and validSlot(readTooltip(), false))
    if slot then return slot, "use" end
    slot = TT.NameSlot(facts.name)
    if slot then return slot, "name" end
    return "any", "any"
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
