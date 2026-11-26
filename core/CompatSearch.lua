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

--- The player's side as ForeverDB's `nfac` writes it: "A" (Alliance) or "H" (Horde), from
--- UnitFactionGroup; nil for any other answer (a neutral Pandaren, a secret, no API).
--- @return string|nil
function Compat.PlayerFactionLetter()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local group = plainString((UnitFactionGroup("player")))
    if group == "Alliance" then return "A" end
    if group == "Horde" then return "H" end
    return nil
end

-- ── where the player stands (Item Search feedback spec §3's ranking) ─────────────────────────

-- The client's map types (Enum.UIMapType): Continent 2, Zone 3; a dungeon, micro or orphan map
-- (4 and up) sits under a zone.
local MAP_CONTINENT, MAP_ZONE, MAP_WALK = 2, 3, 8
local continentCache = {}

-- A map's `{ mapType, parentMapID }` (C_Map.GetMapInfo), or nil.
local function mapInfo(mapID)
    local map = C_Map
    if not (plainId(mapID) and type(map) == "table" and type(map.GetMapInfo) == "function") then return nil end
    local info = plainTable(map.GetMapInfo(mapID))
    if not info then return nil end
    return plainNumber(info.mapType), plainId(info.parentMapID)
end

-- Walk up from `mapID` to the first map of type `want` or less; nil when the walk finds none.
local function walkUp(mapID, want)
    for _ = 1, MAP_WALK do
        local mapType, parent = mapInfo(mapID)
        if not mapType then return nil end
        if mapType <= want then return mapType == want and mapID or nil end
        mapID = parent
        if not mapID then return nil end
    end
    return nil
end

--- The continent a map lies on (its first Continent ancestor, or itself), cached per map: maps never
--- move in a session. nil when the client names none.
--- @param mapID number
--- @return number|nil
function Compat.ContinentOf(mapID)
    if not plainId(mapID) then return nil end
    local hit = continentCache[mapID]
    if hit == nil then
        hit = walkUp(mapID, MAP_CONTINENT) or false
        continentCache[mapID] = hit
    end
    return hit or nil
end

--- The player's zone (C_Map.GetBestMapForUnit, a dungeon or micro map walked up to its zone) and
--- that zone's continent; nil for what the client does not answer.
--- @return number|nil zoneMapID, number|nil continentMapID
function Compat.PlayerZone()
    local map = C_Map
    if not (type(map) == "table" and type(map.GetBestMapForUnit) == "function") then return nil, nil end
    local best = plainId(map.GetBestMapForUnit("player"))
    if not best then return nil, nil end
    local zone = walkUp(best, MAP_ZONE) or best
    return zone, Compat.ContinentOf(zone)
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

-- One read of a quest-log API, in pcall: its first answer when it is a plain boolean, else nil (no
-- API, an error, a secret or any other shape).
local function plainFlag(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or Compat.IsSecret(v) or type(v) ~= "boolean" then return nil end
    return v
end

-- The 1.12-style log's complete flag (GetQuestLogIndexByID, then GetQuestLogTitle's sixth answer:
-- 1 complete, -1 failed, nil not yet), where the client has both; nil otherwise.
local function logTitleComplete(questID)
    local indexOf, titleOf = GetQuestLogIndexByID, GetQuestLogTitle
    if type(indexOf) ~= "function" or type(titleOf) ~= "function" then return nil end
    local ok, index = pcall(indexOf, questID)
    if not ok or not plainId(index) then return nil end
    local ok2, _, _, _, _, _, complete = pcall(titleOf, index)
    if not ok2 or Compat.IsSecret(complete) then return nil end
    return complete == 1 or complete == true
end

--- Whether a quest in the player's log is complete and only waits to be turned in (Item Search
--- round 3 spec §4.2, item 13): C_QuestLog.ReadyForTurnIn, then C_QuestLog.IsComplete, then the
--- log entry's complete flag through GetQuestLogIndexByID and GetQuestLogTitle where those exist.
--- The first rung that answers a plain boolean decides; each call is in pcall. Nil for unknown (no
--- API, an error or a secret answer). Which rung answers on WoW Forever is a smoke probe
--- (ITEM-SEARCH-35).
--- @param questID number
--- @return boolean|nil
function Compat.QuestReady(questID)
    if not plainId(questID) then return nil end
    local ql = type(C_QuestLog) == "table" and C_QuestLog or nil
    if ql then
        local ready = plainFlag(ql.ReadyForTurnIn, questID)
        if ready ~= nil then return ready end
        local complete = plainFlag(ql.IsComplete, questID)
        if complete ~= nil then return complete end
    end
    return logTitleComplete(questID)
end

-- ── spells and professions ──────────────────────────────────────────────────────────────────

-- Keep the higher of `rank` and what `ranks` already has for `line` (nil: no line).
local function keepRank(ranks, line, rank)
    if line and (not ranks[line] or ranks[line] < rank) then ranks[line] = rank end
end

-- One C_SkillInfo line into `ranks`: its skill line and its parent's, the higher rank kept (no
-- table per line: Item Search reads the ranks on every tooltip hover).
local function addSkillLine(ranks, info)
    if not plainTable(info) or info.isHeader == true then return end
    local rank = plainNumber(info.rank or info.skillRank)
    if not rank then return end
    keepRank(ranks, plainId(info.skillID or info.skillLineID), rank)
    keepRank(ranks, plainId(info.parentSkillLineID), rank)
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
--- classID, subclassID, equipLoc, sellPrice, bindType }` from C_Item.GetItemInfo (returns 1 to 5, 9
--- to 14; `sellPrice` in copper, 0 for an item no vendor buys; `bindType` 4 a quest item; the round 3
--- spec §4.5's verdict reads those two); nil while it is not cached, for a secret answer or no API.
--- @param itemID number
--- @return table|nil
function Compat.ItemInfoByID(itemID)
    local item = C_Item
    if not (plainId(itemID) and type(item) == "table" and type(item.GetItemInfo) == "function") then return nil end
    local name, link, quality, itemLevel, reqLevel, _, _, _, equipLoc, icon, sellPrice, classID, subclassID,
        bindType = item.GetItemInfo(itemID)
    name = plainString(name)
    if not name then return nil end
    return {
        id = itemID, name = name, link = plainString(link), quality = plainNumber(quality),
        itemLevel = plainNumber(itemLevel), requiredLevel = plainNumber(reqLevel),
        icon = plainNumber(icon) or plainString(icon), classID = plainNumber(classID),
        subclassID = plainNumber(subclassID), equipLoc = plainString(equipLoc), sellPrice = plainNumber(sellPrice),
        bindType = plainNumber(bindType),
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
--- `ALT-CTRL-D` reads `Alt-Ctrl-D` on an English client); nil when nothing is bound.
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

-- The coins drawn by hand (R5-DW-11): the client's MoneyFrame icons, which both clients ship, each
-- after its count, an empty denomination left out and nothing at all read as 0 copper.
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
local COINS = { { 10000, COIN:format("Gold") }, { 100, COIN:format("Silver") }, { 1, COIN:format("Copper") } }

local function handCoins(copper)
    copper = math.floor(copper)
    local out
    for _, c in ipairs(COINS) do
        local n = math.floor(copper / c[1])
        copper = copper - n * c[1]
        if n > 0 then out = (out and (out .. " ") or "") .. n .. c[2] end
    end
    return out or ("0" .. COINS[3][2])
end

-- The client's own coin string: C_CurrencyInfo's, else a bare global where one exists. Neither
-- client has the bare GetCoinTextureString (BankLedger's probe P9), which is why "Sells for 30"
-- read as a bare number before R5-DW-11.
local function clientCoins(copper)
    local ci = C_CurrencyInfo
    local fn = type(ci) == "table" and ci.GetCoinTextureString or nil
    if type(fn) ~= "function" and type(GetCoinTextureString) == "function" then fn = GetCoinTextureString end
    if type(fn) ~= "function" then return nil end
    local ok, text = pcall(fn, copper)
    return ok and plainString(text) or nil
end

--- An amount of copper with gold, silver and copper coins (R5-DW-11): the client's coin string when
--- it has one, else the coins drawn by hand from the MoneyFrame icons (`1<silver> 20<copper>`).
--- Nil only for no amount.
--- @param copper number
--- @return string|nil
function Compat.CoinText(copper)
    copper = plainNumber(copper)
    if not copper then return nil end
    return clientCoins(copper) or handCoins(copper)
end

--- A day as the Sold by tab writes it (`2026-11-26`), from the client's date(); nil for no time or
--- no API.
--- @param t number|nil time()
--- @return string|nil
function Compat.DateText(t)
    t = plainNumber(t)
    if not t or type(date) ~= "function" then return nil end
    local ok, text = pcall(date, "%Y-%m-%d", t)
    return ok and plainString(text) or nil
end

-- ── the Item Search window and its key (spec §4.5, §4.6) ────────────────────────────────────

--- A map's name (C_Map.GetMapInfo(mapID).name); nil for no API, no such map or a secret answer.
--- @param mapID number
--- @return string|nil
function Compat.MapName(mapID)
    local map = C_Map
    if not (plainId(mapID) and type(map) == "table" and type(map.GetMapInfo) == "function") then return nil end
    local info = plainTable(map.GetMapInfo(mapID))
    return info and plainString(info.name) or nil
end

-- TomTom's AddWaypoint, when TomTom is installed and loaded.
local function tomTom()
    local tt = TomTom
    if type(tt) == "table" and type(tt.AddWaypoint) == "function" then return tt end
    return nil
end

--- Whether TomTom is loaded (its AddWaypoint answers). The client's own user waypoint
--- (C_Map.SetUserWaypoint) is no longer used (Item Search feedback spec §6): it draws no arrow on
--- WoW Forever, so a pin is TomTom's or Drop Watcher's arrow (modules/ItemSearchWaypoint.lua).
--- @return boolean
function Compat.TomTomLoaded()
    return tomTom() ~= nil
end

--- Add a TomTom waypoint at `x`, `y` (0..1) on `mapID`, named `title`. Answers true when TomTom
--- took it; false with no TomTom, no plain map or point, or an AddWaypoint that raised.
--- @param mapID number
--- @param x number
--- @param y number
--- @param title string|nil
--- @return boolean
function Compat.AddTomTomWaypoint(mapID, x, y, title)
    local tt = tomTom()
    x, y = plainNumber(x), plainNumber(y)
    if not (tt and plainId(mapID) and x and y) then return false end
    local ok = pcall(tt.AddWaypoint, tt, mapID, x, y, { title = title, from = NS.BRAND })
    return ok == true
end

--- The item a shown tooltip holds now (its GetItem: name, link, id), else nil: hidden, forbidden,
--- no item, or a secret answer. Only the item fields are read, never a line's text.
--- @param tip table|nil
--- @return number|nil
function Compat.ShownTooltipItemID(tip)
    tip = plainTable(tip)
    if not (tip and type(tip.IsShown) == "function" and tip:IsShown() == true) then return nil end
    if type(tip.IsForbidden) == "function" and tip:IsForbidden() == true then return nil end
    if type(tip.GetItem) ~= "function" then return nil end
    local _, link, id = tip:GetItem()
    id = plainId(id)
    if id then return id end
    link = plainString(link)
    return link and plainId(tonumber(link:match("item:(%d+)"))) or nil
end

--- The item the first shown item tooltip among the named ones holds (`names`, global frame names
--- in order), or nil: the key's "is an item tooltip showing" read.
--- @param names table
--- @return number|nil
function Compat.ShownItemTooltipItemID(names)
    for _, name in ipairs(type(names) == "table" and names or {}) do
        local id = Compat.ShownTooltipItemID(_G[name])
        if id then return id end
    end
    return nil
end

--- Ask the client to load an item's data (C_Item.RequestLoadItemDataByID). True when asked.
--- @param itemID number
--- @return boolean
function Compat.RequestItem(itemID)
    local item = C_Item
    if not (plainId(itemID) and type(item) == "table" and type(item.RequestLoadItemDataByID) == "function") then
        return false
    end
    item.RequestLoadItemDataByID(itemID)
    return true
end

--- An item class's and subclass's names (C_Item.GetItemClassInfo / GetItemSubClassInfo), each nil
--- where the client names none.
--- @param classID number|nil
--- @param subclassID number|nil
--- @return string|nil className, string|nil subclassName
function Compat.ItemClassNames(classID, subclassID)
    local item = C_Item
    classID, subclassID = plainNumber(classID), plainNumber(subclassID)
    if not (classID and type(item) == "table") then return nil, nil end
    local class = type(item.GetItemClassInfo) == "function" and plainString(item.GetItemClassInfo(classID)) or nil
    local sub = subclassID and type(item.GetItemSubClassInfo) == "function"
        and plainString(item.GetItemSubClassInfo(classID, subclassID)) or nil
    return class, sub
end

--- An item quality's name (the client's ITEM_QUALITY<n>_DESC global), or nil.
--- @param quality number|nil
--- @return string|nil
function Compat.QualityName(quality)
    quality = plainNumber(quality)
    if not quality then return nil end
    return plainString(_G["ITEM_QUALITY" .. quality .. "_DESC"])
end

-- ── the key binding's one-time default (spec §4.6) ──────────────────────────────────────────

--- The command bound to `key` now (GetBindingAction), "" for a free key; nil without the API.
--- @param key string
--- @return string|nil
function Compat.BindingAction(key)
    if type(GetBindingAction) ~= "function" or type(key) ~= "string" then return nil end
    local action = GetBindingAction(key)
    if Compat.IsSecret(action) then return nil end
    return type(action) == "string" and action or ""
end

--- Whether `command` has any key bound (GetBindingKey); nil without the API.
--- @param command string
--- @return boolean|nil
function Compat.HasBinding(command)
    if type(GetBindingKey) ~= "function" then return nil end
    local key = plainString((GetBindingKey(command)))
    return key ~= nil and key ~= ""
end

--- Bind `key` to `command` and save the set in force (SetBinding, then
--- SaveBindings(GetCurrentBindingSet())). True when both ran; out of combat only (the caller asks).
--- @param key string
--- @param command string
--- @return boolean
function Compat.BindKey(key, command)
    if not (type(SetBinding) == "function" and type(SaveBindings) == "function"
        and type(GetCurrentBindingSet) == "function") then
        return false
    end
    if not SetBinding(key, command) then return false end
    SaveBindings(GetCurrentBindingSet())
    return true
end

-- ── the merchant window (round 3 spec §4.4: the prices Drop Watcher records) ───────────────

-- One call in pcall: its answers, or nothing on an error or without the function.
local function tryCall(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

--- The npc id of the merchant the player has open: the creature id in Compat.UnitGUID("npc")
--- ("Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>", and "Vehicle-" alike). Nil for no
--- merchant, a GUID of another kind (a player, an object), a secret, an error or no API: such a visit
--- is not recorded.
--- @return number|nil
function Compat.MerchantNpcID()
    local ok, guid = pcall(Compat.UnitGUID, "npc")
    if not ok or Compat.IsSecret(guid) or type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return plainId(tonumber(id))
end

-- One merchant slot's price, quantity and whether it costs something else than copper: from
-- C_MerchantFrame.GetItemInfo's table where the client has it, else GetMerchantItemInfo's answers.
local function slotInfo(i)
    local mf = C_MerchantFrame
    if type(mf) == "table" and type(mf.GetItemInfo) == "function" then
        local ok, info = pcall(mf.GetItemInfo, i)
        info = ok and plainTable(info) or nil
        if not info then return nil end
        return plainNumber(info.price), plainNumber(info.stackCount), info.hasExtendedCost == true
    end
    local ok, _, _, price, quantity, _, _, _, extended = tryCall(GetMerchantItemInfo, i)
    if not ok then return nil end
    return plainNumber(price), plainNumber(quantity), extended == true
end

--- What the open merchant sells for copper: `{ { item, price, quantity } }`, price in copper for
--- `quantity` (the stack the slot sells). A slot with an extended cost and no copper price (a token
--- vendor's) is left out, as is one the client does not answer plainly. `{}` with no merchant open.
--- @return table
function Compat.MerchantItems()
    local out = {}
    local ok, n = tryCall(GetMerchantNumItems)
    n = ok and plainNumber(n) or nil
    for i = 1, n or 0 do
        local okID, item = tryCall(GetMerchantItemID, i)
        item = okID and plainId(item) or nil
        local price, quantity, extended = slotInfo(i)
        if item and price and price >= 0 and not (extended and price == 0) then
            out[#out + 1] = { item = item, price = price, quantity = (quantity and quantity > 0) and quantity or 1 }
        end
    end
    return out
end
