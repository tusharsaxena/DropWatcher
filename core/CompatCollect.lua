local _, NS = ...
-- core/CompatCollect.lua — the collection reads (issue #13, categories design spec §2): mounts,
-- battle pets, toys, the cosmetic flag, a recipe's "Already known" line and the player's
-- professions, published on NS.Compat like the rest of the compat family, split out of
-- core/Compat.lua to keep it under the 1000-line band. modules/Collectibles.lua is the one caller.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises. GlobalStrings are read through Compat.GlobalString. The recipe line is read through the
-- ratified tooltip reader, Compat.ReadTooltipLine (library-stack-§7: a new consumer, not a new
-- reader); core/Compat.lua's tooltipData helper is file-local, so this compat file asks
-- C_TooltipInfo.GetHyperlink itself.

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
