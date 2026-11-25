local _, NS = ...
-- core/CompatSearch.lua — the client reads Item Search makes (DropWatcher#17, Item Search spec §4.2,
-- §4.3): who the player is (race and class ids, for a quest's masks), where a quest stands (in the
-- log, completed), the player's rank in each profession, an item the
-- client has cached, the client's build and the open profession window's recipes and reagents;
-- and the item tooltip's hook and reads (spec §4.4: the post call, the item a post call names, the
-- comparison tooltips, the bound key, Shift, a coin string).
-- WoW Forever's feature alone (C.FEATURE.itemSearch): modules/ItemSearch.lua,
-- modules/ItemSearchLearn.lua and modules/ItemSearchTip.lua are the callers, and on Retail nothing
-- calls these.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret meets
-- nothing but IsSecret first, a missing API answers its documented absent value and never raises.
--
-- THE CHOICES, from the kit's WoW Forever API set (Ketho's `forever` branch; best-effort, not
-- measured, so each read keeps a second rung where one exists and docs/forever-quirks.md marks them
-- assumed until probed):
--   * a profession's rank: C_SkillInfo's skill list (the set lists it, and not 1.12's
--     GetSkillLineInfo; Skill Master measured its struct on 1.60.1: name, isHeader, rank, skillID,
--     parentSkillLineID), then the professions' ranks (Compat.ProfessionRanks in
--     core/CompatCollect.lua, the one reader of GetProfessions; both clients' sets list it);
--   * a known spell: Compat.SpellKnown (core/CompatCollect.lua, the one reader of the spell
--     namespaces): IsPlayerSpell, then C_SpellBook.IsSpellKnown, then IsSpellKnown;
--   * the profession window: C_TradeSkillUI (WoW Forever draws Retail's ProfessionsFrame), its
--     GetAllRecipeIDs, GetRecipeInfo, GetRecipeSchematic and GetTradeSkillLineForRecipe. A recipe's
--     id is its spell id there, as the shipped table keys it.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local function plainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" or v ~= v then return nil end
    return v
end

-- A positive plain number (an item, quest, spell or skill-line id), or nil.
local function plainId(v)
    v = plainNumber(v)
    return v and v > 0 and v or nil
end

-- A plain table, or nil (a secret or anything else).
local function plainTable(v)
    if Compat.IsSecret(v) or type(v) ~= "table" then return nil end
    return v
end

-- ── who the player is ───────────────────────────────────────────────────────────────────────

--- The player's race and class ids (UnitRace's and Compat.UnitClass's third answers), each nil
--- when the client answers none: the bit positions of a quest's race and class masks. The class is
--- read through Compat.UnitClass, the world read the simulator answers.
--- @return number|nil raceID, number|nil classID
function Compat.PlayerRaceClassIDs()
    local race = type(UnitRace) == "function" and plainId((select(3, UnitRace("player")))) or nil
    local class = plainId((select(3, Compat.UnitClass("player"))))
    return race, class
end

-- ── quests ──────────────────────────────────────────────────────────────────────────────────

--- Whether a quest is in the player's log: C_QuestLog.GetLogIndexForQuestID answering an index,
--- else C_QuestLog.IsOnQuest; nil for no API or a secret answer.
--- @param questID number
--- @return boolean|nil
function Compat.QuestInLog(questID)
    local ql = C_QuestLog
    if not (plainId(questID) and type(ql) == "table") then return nil end
    if type(ql.GetLogIndexForQuestID) == "function" then
        local index = ql.GetLogIndexForQuestID(questID)
        if Compat.IsSecret(index) then return nil end
        if plainId(index) then return true end
        if type(ql.IsOnQuest) ~= "function" then return false end
    end
    if type(ql.IsOnQuest) == "function" then
        local on = ql.IsOnQuest(questID)
        if Compat.IsSecret(on) then return nil end
        return on == true
    end
    return nil
end

--- Whether the player has completed a quest (C_QuestLog.IsQuestFlaggedCompleted); nil for no API
--- or a secret answer.
--- @param questID number
--- @return boolean|nil
function Compat.QuestDone(questID)
    local ql = C_QuestLog
    if not (plainId(questID) and type(ql) == "table" and type(ql.IsQuestFlaggedCompleted) == "function") then
        return nil
    end
    local done = ql.IsQuestFlaggedCompleted(questID)
    if Compat.IsSecret(done) then return nil end
    return done == true
end

-- ── spells and professions ──────────────────────────────────────────────────────────────────

-- One C_SkillInfo line into `ranks`: its skill line and its parent's, the higher rank kept.
local function addSkillLine(ranks, info)
    if not plainTable(info) or info.isHeader == true then return end
    local rank = plainNumber(info.rank or info.skillRank)
    if not rank then return end
    for _, line in ipairs({ plainId(info.skillID or info.skillLineID), plainId(info.parentSkillLineID) }) do
        if not ranks[line] or ranks[line] < rank then ranks[line] = rank end
    end
end

local function ranksFromSkillInfo(ns)
    local n = plainNumber(ns.GetNumSkillLines())
    if not n then return nil end
    local ranks = {}
    for i = 1, n do addSkillLine(ranks, ns.GetSkillLineInfo(i)) end
    return ranks
end

--- The player's rank in each skill line: `{ [skillLineID] = rank }`. A WoW Forever child line also
--- answers under its parent (Leatherworking's child line under 165), so the shipped table's
--- vanilla ids find it. From C_SkillInfo's skill list, else the professions' ranks
--- (Compat.ProfessionRanks, core/CompatCollect.lua's GetProfessions reader); nil for neither.
--- @return table|nil
function Compat.SkillLineRanks()
    local ns = C_SkillInfo
    if type(ns) == "table" and type(ns.GetNumSkillLines) == "function" and type(ns.GetSkillLineInfo) == "function" then
        local ranks = ranksFromSkillInfo(ns)
        if ranks then return ranks end
    end
    return Compat.ProfessionRanks()
end

-- ── items and the client ────────────────────────────────────────────────────────────────────

--- An item the client has cached, by id: `{ id, name, link, quality, itemLevel, requiredLevel, icon,
--- classID, subclassID }` from C_Item.GetItemInfo; nil while it is not cached, for a secret answer
--- or no API.
--- @param itemID number
--- @return table|nil
function Compat.ItemInfoByID(itemID)
    local item = C_Item
    if not (plainId(itemID) and type(item) == "table" and type(item.GetItemInfo) == "function") then return nil end
    local name, link, quality, itemLevel, reqLevel, _, _, _, _, icon, _, classID, subclassID = item.GetItemInfo(itemID)
    name = plainString(name)
    if not name then return nil end
    return {
        id = itemID, name = name, link = plainString(link), quality = plainNumber(quality),
        itemLevel = plainNumber(itemLevel), requiredLevel = plainNumber(reqLevel),
        icon = plainNumber(icon) or plainString(icon), classID = plainNumber(classID),
        subclassID = plainNumber(subclassID),
    }
end

--- The client's version and build as one string (`1.60.1.70938`), from GetBuildInfo; nil without
--- it.
--- @return string|nil
function Compat.ClientBuild()
    if type(GetBuildInfo) ~= "function" then return nil end
    local version, build = GetBuildInfo()
    version, build = plainString(version), plainString(build)
    if not version then return nil end
    if build and build ~= "" then return version .. "." .. build end
    return version
end

-- ── the profession window ───────────────────────────────────────────────────────────────────

-- A recipe's skill line: GetTradeSkillLineForRecipe's parent line (a child line's vanilla id),
-- else its own line.
local function recipeSkillLine(ui, recipeID)
    if type(ui.GetTradeSkillLineForRecipe) ~= "function" then return nil end
    local line, _, parent = ui.GetTradeSkillLineForRecipe(recipeID)
    return plainId(parent) or plainId(line)
end

-- Whether a reagent slot is a basic one (Enum.CraftingReagentType.Basic, where the client has it).
local function basicSlot(slot)
    local enum = Enum and Enum.CraftingReagentType
    local basic = type(enum) == "table" and plainNumber(enum.Basic)
    local kind = plainNumber(slot.reagentType)
    return not (basic and kind and kind ~= basic)
end

-- A schematic's basic reagents as `{ [itemID] = count }`, or nil when it names none.
local function reagentsOf(schematic)
    local out, any = {}, false
    for _, slot in ipairs(plainTable(schematic.reagentSlotSchematics) or {}) do
        local reagents = plainTable(slot) and plainTable(slot.reagents)
        local first = reagents and plainTable(reagents[1])
        local item = first and plainId(first.itemID)
        local count = plainId(slot.quantityRequired)
        if item and count and basicSlot(slot) then out[item], any = (out[item] or 0) + count, true end
    end
    return any and out or nil
end

-- One listed recipe as `{ spell, name, skillLine, made, reagents }`, or nil without reagents.
local function recipeRow(ui, recipeID)
    local schematic = type(ui.GetRecipeSchematic) == "function" and plainTable(ui.GetRecipeSchematic(recipeID, false))
    local reagents = schematic and reagentsOf(schematic)
    if not reagents then return nil end
    local info = type(ui.GetRecipeInfo) == "function" and plainTable(ui.GetRecipeInfo(recipeID))
    return {
        spell = recipeID, reagents = reagents, made = plainId(schematic.outputItemID),
        name = plainString(info and info.name) or plainString(schematic.name),
        skillLine = recipeSkillLine(ui, recipeID),
    }
end

--- The recipes the open profession window lists, each `{ spell, name, skillLine, made, reagents =
--- { [itemID] = count } }` (a recipe with no basic reagent left out); `{}` when no window lists any,
--- nil for no C_TradeSkillUI.
--- @return table|nil
function Compat.TradeSkillRecipes()
    local ui = C_TradeSkillUI
    if not (type(ui) == "table" and type(ui.GetAllRecipeIDs) == "function") then return nil end
    local out = {}
    for _, id in ipairs(plainTable(ui.GetAllRecipeIDs()) or {}) do
        local recipeID = plainId(id)
        local row = recipeID and recipeRow(ui, recipeID)
        if row then out[#out + 1] = row end
    end
    return out
end

-- ── the item tooltip ────────────────────────────────────────────────────────────────────────

--- Register `fn(tooltip, data)` as a post call of every item tooltip:
--- TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn). The client keeps it
--- for the session (there is no removal), so the caller registers once. False when the client has
--- no TooltipDataProcessor or no item data type.
--- @param fn function
--- @return boolean
function Compat.HookItemTooltips(fn)
    local tdp = TooltipDataProcessor
    local types = Enum and Enum.TooltipDataType
    local item = type(types) == "table" and plainNumber(types.Item)
    if not (type(fn) == "function" and type(tdp) == "table" and type(tdp.AddTooltipPostCall) == "function"
        and item) then
        return false
    end
    tdp.AddTooltipPostCall(item, fn)
    return true
end

--- The item a tooltip post call's data names: its `id`, else the id in its `hyperlink`. Only those
--- two fields are read (a tooltip's line texts can be secret); nil for a secret or anything else.
--- @param data table|nil
--- @return number|nil
function Compat.TooltipItemID(data)
    data = plainTable(data)
    if not data then return nil end
    local id = plainId(data.id)
    if id then return id end
    local link = plainString(data.hyperlink)
    return link and plainId(tonumber(link:match("item:(%d+)")))
end

--- Whether a tooltip may be written to: a table, not forbidden.
--- @param tip table|nil
--- @return boolean
function Compat.TooltipWritable(tip)
    if not plainTable(tip) or type(tip.AddLine) ~= "function" then return false end
    if type(tip.IsForbidden) == "function" and tip:IsForbidden() == true then return false end
    return true
end

--- Whether a tooltip is one of the client's comparison tooltips (ShoppingTooltip1 / 2,
--- ItemRefShoppingTooltip1 / 2), by its frame name.
--- @param tip table
--- @return boolean
function Compat.IsComparisonTooltip(tip)
    local name = type(tip.GetName) == "function" and plainString(tip:GetName())
    return name ~= nil and name:find("ShoppingTooltip%d$") ~= nil
end

--- The first key bound to a binding command, as the client names it for display (GetBindingText:
--- `CTRL-ALT-D` reads `Ctrl-Alt-D` on an English client); nil when nothing is bound.
--- @param command string
--- @return string|nil
function Compat.BindingKeyText(command)
    if type(GetBindingKey) ~= "function" then return nil end
    local key = plainString((GetBindingKey(command)))
    if not key or key == "" then return nil end
    local text = type(GetBindingText) == "function" and plainString(GetBindingText(key)) or nil
    return (text and text ~= "") and text or key
end

--- Whether Shift is held (IsShiftKeyDown); false without it.
--- @return boolean
function Compat.ShiftDown()
    return type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
end

--- An amount of copper as the client's coin string (GetCoinTextureString); nil without it.
--- @param copper number
--- @return string|nil
function Compat.CoinText(copper)
    copper = plainNumber(copper)
    if not copper or type(GetCoinTextureString) ~= "function" then return nil end
    return plainString(GetCoinTextureString(copper))
end
