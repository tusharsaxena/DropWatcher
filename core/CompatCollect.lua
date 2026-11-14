local _, NS = ...
-- core/CompatCollect.lua — the collection reads (issue #13, categories design spec §2): mounts,
-- battle pets, toys, the cosmetic flag, a recipe's "Already known" line and the player's
-- professions, published on NS.Compat like the rest of the compat family, split out of
-- core/Compat.lua to keep it under the 1000-line band. modules/Collectibles.lua is the one caller of
-- those; the tier-token reads (the slot a token's tooltip names, an item's use text, a class's name) are
-- modules/ItemFacts.lua's and modules/CollectCells.lua's (categories design spec §7.1, DW-CAT4), and
-- the link of a curated sample's id is modules/SimPool.lua's (spec §8, DW-CAT6).
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises. GlobalStrings are read through Compat.GlobalString. The recipe line and the token's slot
-- and use lines are read through the ratified tooltip reader, Compat.ReadTooltipLine (library-stack-§7:
-- new consumers, not a new reader); core/Compat.lua's tooltipData helper is file-local, so this
-- compat file asks C_TooltipInfo.GetHyperlink itself. An item's use text (ItemUseText, TT-1) is its
-- use spell's description (C_Item.GetItemSpell, C_Spell.GetSpellDescription), else that use line;
-- a description not loaded yet is asked for (RequestSpellLoad, C_Spell.RequestLoadSpellData).

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local function plainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function plainBool(v)
    if Compat.IsSecret(v) or type(v) ~= "boolean" then return nil end
    return v
end

-- A positive plain number (an item, mount or species id), or nil.
local function plainId(v)
    v = plainNumber(v)
    return v and v > 0 and v or nil
end

-- ── Mounts ──────────────────────────────────────────────────────────────────────────────────

--- The mount an item teaches (C_MountJournal.GetMountFromItem), or nil: no API, not a mount item,
--- or a secret answer.
--- @param itemID number
--- @return number|nil
function Compat.MountFromItem(itemID)
    local mj = C_MountJournal
    if not (plainId(itemID) and mj and mj.GetMountFromItem) then return nil end
    return plainId(mj.GetMountFromItem(itemID))
end

--- Whether the account has collected a mount (C_MountJournal.GetMountInfoByID's 11th return,
--- isCollected), or nil: no API, an unknown mount (journal data not loaded yet) or a secret answer.
--- @param mountID number
--- @return boolean|nil
function Compat.MountCollected(mountID)
    local mj = C_MountJournal
    if not (plainId(mountID) and mj and mj.GetMountInfoByID) then return nil end
    return plainBool((select(11, mj.GetMountInfoByID(mountID))))
end

-- ── Battle pets ─────────────────────────────────────────────────────────────────────────────

--- The battle pet species a companion item teaches (C_PetJournal.GetPetInfoByItemID's 13th
--- return, speciesID), or nil.
--- @param itemID number
--- @return number|nil
function Compat.PetSpeciesFromItem(itemID)
    local pj = C_PetJournal
    if not (plainId(itemID) and pj and pj.GetPetInfoByItemID) then return nil end
    return plainId((select(13, pj.GetPetInfoByItemID(itemID))))
end

--- How many of a species the account has, and how many it may have
--- (C_PetJournal.GetNumCollectedInfo), or nil, nil: no API, or a secret or missing answer.
--- @param speciesID number
--- @return number|nil count, number|nil limit
function Compat.PetCollected(speciesID)
    local pj = C_PetJournal
    if not (plainId(speciesID) and pj and pj.GetNumCollectedInfo) then return nil, nil end
    local count, limit = pj.GetNumCollectedInfo(speciesID)
    count, limit = plainNumber(count), plainNumber(limit)
    if not count then return nil, nil end
    return count, limit
end

-- ── Toys ────────────────────────────────────────────────────────────────────────────────────

--- True when an item is a toy (C_ToyBox.GetToyInfo answers it); false for no API, not a toy, or a
--- secret answer.
--- @param itemID number
--- @return boolean
function Compat.IsToy(itemID)
    local tb = C_ToyBox
    if not (plainId(itemID) and tb and tb.GetToyInfo) then return false end
    local id = tb.GetToyInfo(itemID)
    if Compat.IsSecret(id) then return false end
    return id ~= nil
end

--- Whether the account has a toy (the PlayerHasToy global), or nil: no API or a secret answer.
--- @param itemID number
--- @return boolean|nil
function Compat.ToyCollected(itemID)
    if not (plainId(itemID) and PlayerHasToy) then return nil end
    return plainBool(PlayerHasToy(itemID))
end

-- ── Cosmetics ───────────────────────────────────────────────────────────────────────────────

--- True when the client flags an item cosmetic (C_Item.IsCosmeticItem: cosmetic armor, and the
--- cosmetic weapons, which are Weapon-class); false for no API, a secret or a non-string link.
--- @param link string
--- @return boolean
function Compat.IsCosmeticItem(link)
    local item = C_Item
    if not (plainString(link) and item and item.IsCosmeticItem) then return false end
    return plainBool(item.IsCosmeticItem(link)) == true
end

-- ── Recipes and professions ─────────────────────────────────────────────────────────────────

-- True when any of the tooltip's lines carries a secret left text: the reader skips such a line,
-- so "no Already known line" could not be told from "a line we may not read".
local function anySecretLine(data)
    for _, line in ipairs(data.lines) do
        if type(line) == "table" and Compat.IsSecret(line.leftText) then return true end
    end
    return false
end

--- Whether a recipe is already known: true when its hyperlink tooltip carries a line whose left
--- text EQUALS the localized ITEM_SPELL_KNOWN ("Already known"), false when the tooltip was read
--- and has none, nil for no API, no GlobalString, a missing or malformed tooltip or a secret line.
--- @param link string
--- @return boolean|nil
function Compat.RecipeKnown(link)
    local tip, known = C_TooltipInfo, plainString(Compat.GlobalString("ITEM_SPELL_KNOWN"))
    if not (plainString(link) and known and known ~= "" and tip and tip.GetHyperlink) then return nil end
    local data = tip.GetHyperlink(link)
    if Compat.IsSecret(data) or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    if anySecretLine(data) then return nil end
    local found = Compat.ReadTooltipLine(data, "None", function(text) return text == known or nil end)
    return found == true
end

--- The skill lines of the player's professions (GetProfessions' indices, cooking and fishing
--- included; GetProfessionInfo's 7th return), as { [skillLine] = true }: empty for a character
--- with no profession, nil for no answer (no API, or a slot whose index or skill line is secret or
--- unreadable), so "none of yours" is never claimed from a read that could not be made.
--- @return table|nil
function Compat.ProfessionSkillLines()
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local indices, out = { GetProfessions() }, {}
    for i = 1, 5 do
        if indices[i] ~= nil then
            local index = plainId(indices[i])
            local line = index and plainId((select(7, GetProfessionInfo(index))))
            if not line then return nil end
            out[line] = true
        end
    end
    return out
end

-- ── Tier tokens (DW-CAT4) ───────────────────────────────────────────────────────────────────

-- An item's hyperlink tooltip data (C_TooltipInfo.GetHyperlink), or nil: no API, a secret link or
-- a secret or malformed answer.
local function hyperlinkData(link)
    local tip = C_TooltipInfo
    if not (plainString(link) and tip and tip.GetHyperlink) then return nil end
    local data = tip.GetHyperlink(link)
    if Compat.IsSecret(data) or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    return data
end

-- The slots a tier token can make, by the GlobalString that names each on a tooltip.
local TOKEN_SLOT_STRINGS = { "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_HAND", "INVTYPE_LEGS" }

-- The slot names as the client writes them now: { [localized name] = "INVTYPE_*" }.
local function tokenSlotNames()
    local out = {}
    for _, key in ipairs(TOKEN_SLOT_STRINGS) do
        local text = plainString(Compat.GlobalString(key))
        if text and text ~= "" then out[text] = key end
    end
    return out
end

--- The slot a tier token's tooltip names, or nil: the INVTYPE_* key of the first line whose left
--- text EQUALS one of the localized INVTYPE_HEAD, _SHOULDER, _CHEST, _HAND or _LEGS GlobalStrings
--- (never a substring of another line); nil for no API, no such line, or a secret or malformed
--- answer (categories design spec §7.1; NS.TierTokens.SlotOf's `use` rung, after the Use text).
--- @param link string
--- @return string|nil
function Compat.TierTokenSlot(link)
    local data = hyperlinkData(link)
    if not data then return nil end
    local names = tokenSlotNames()
    return Compat.ReadTooltipLine(data, "None", function(text) return names[text] end)
end

--- Whether an item opens (RX-04, rolls UX design §3.5): `locked` when its hyperlink tooltip carries
--- a line whose left text EQUALS the localized LOCKED ("Locked", a lockbox), `opens` for one that
--- equals ITEM_OPENABLE ("<Right Click to Open>"), false once the tooltip was read with neither; nil
--- for no API, no GlobalString, a secret link, a missing or malformed tooltip or a secret line.
--- modules/Collectibles.lua asks it of Miscellaneous Junk alone, the class a lockbox has.
--- @param link string
--- @return string|false|nil
function Compat.ItemOpens(link)
    local locked = plainString(Compat.GlobalString("LOCKED"))
    local openable = plainString(Compat.GlobalString("ITEM_OPENABLE"))
    local data = (locked or openable) and hyperlinkData(link)
    if not data or anySecretLine(data) then return nil end
    return Compat.ReadTooltipLine(data, "None", function(text)
        if text == locked then return "locked" end
        if text == openable then return "opens" end
        return nil
    end) or false
end

-- The text of an item's use spell (C_Item.GetItemSpell, then C_Spell.GetSpellDescription): the
-- text, false for an item with no use spell, or nil when it could not be read (no API, a secret
-- or empty answer). An empty description is a spell the client has not loaded yet: its id is the
-- second return then.
local function spellUseText(link)
    local item, spell = C_Item, C_Spell
    if not (item and item.GetItemSpell and spell and spell.GetSpellDescription) then return nil end
    local _, spellID = item.GetItemSpell(link)
    if Compat.IsSecret(spellID) then return nil end
    if spellID == nil then return false end
    spellID = plainId(spellID)
    local text = spellID and plainString(spell.GetSpellDescription(spellID))
    if text == "" then return nil, spellID end
    return text
end

-- The rest of the tooltip's first line that starts with the client's ITEM_SPELL_TRIGGER_ONUSE
-- ("Use:", the locale table's when unreadable), case-insensitively; nil for none.
local function tooltipUseText(link)
    local data = hyperlinkData(link)
    if not data then return nil end
    local prefix = (plainString(Compat.GlobalString("ITEM_SPELL_TRIGGER_ONUSE")) or NS.L["Use:"]):lower()
    return Compat.ReadTooltipLine(data, "None", function(text)
        if text:lower():sub(1, #prefix) ~= prefix then return nil end
        local rest = text:sub(#prefix + 1):match("^%s*(.-)%s*$")
        return rest ~= "" and rest or nil
    end)
end

--- What an item does when used, as the client writes it, without the "Use:" prefix (TT-1: a tier
--- token's "Create a soulbound set hand item appropriate for your class."), or nil: no use spell,
--- or none readable. The use spell's description first; when that cannot be read, the tooltip's
--- use line. With no text, the second return is the use spell's id when its description came back
--- empty: a spell the client has not loaded yet (Compat.RequestSpellLoad, then read again; the
--- caller is modules/ItemFacts.lua).
--- @param link string
--- @return string|nil text, number|nil loadingSpellID
function Compat.ItemUseText(link)
    if not plainString(link) then return nil end
    local text, loading = spellUseText(link)
    if text == false then return nil end
    text = text or tooltipUseText(link)
    if text then return text end
    return nil, loading
end

--- True when the client can be asked to load a spell's data and a timer can wait for it
--- (C_Spell.RequestLoadSpellData, C_Timer.After).
--- @return boolean
function Compat.CanRequestSpellLoad()
    local spell, timer = C_Spell, C_Timer
    return (spell and spell.RequestLoadSpellData and timer and timer.After) and true or false
end

--- Ask the client to load a spell's data (its description then answers on a later read, and
--- SPELL_TEXT_UPDATE fires). Answers whether it asked: false for no API or no plain id.
--- @param spellID number
--- @return boolean
function Compat.RequestSpellLoad(spellID)
    local spell = C_Spell
    spellID = plainId(spellID)
    if not (spellID and spell and spell.RequestLoadSpellData) then return false end
    spell.RequestLoadSpellData(spellID)
    return true
end

--- A class's name as the client writes it (LOCALIZED_CLASS_NAMES_MALE), or nil: no table, an
--- unknown class or a secret answer. A tier token's Type cell lists its classes by these names.
--- @param classFile string
--- @return string|nil
function Compat.ClassDisplayName(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    if not (plainString(classFile) and type(names) == "table") then return nil end
    return plainString(names[classFile])
end

-- ── The simulator's samples (DW-CAT6) ───────────────────────────────────────────────────────

--- An item's link from its id (C_Item.GetItemInfo's second return), or nil: no API, an item the
--- client has not cached yet, or a secret answer. The simulator's curated collectible samples
--- (NS.SimPool.COLLECTIBLE_SAMPLES) are ids, and a loot line needs the link.
--- @param itemID number
--- @return string|nil
function Compat.ItemLinkByID(itemID)
    local item = C_Item
    if not (plainId(itemID) and item and item.GetItemInfo) then return nil end
    local _, link = item.GetItemInfo(itemID)
    link = plainString(link)
    if not (link and link:find("|Hitem:", 1, true)) then return nil end
    return link
end
