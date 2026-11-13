local _, NS = ...
-- core/CompatClient.lua — the character on this client (Forever port design §4.1, §4.2): the reads
-- that answer differently on Retail and WoW Forever about who a character is and what it plays. The
-- player's realm, the trade partner's name, a spec's name, another unit's inspected spec, the
-- player's talent tree and the role it plays (LibKa0s-Role-1.0, its store this character's
-- db.char.role, as Ka0s Quick Comms keeps it).
--
-- WHY HERE. The client questions themselves (IsForever, IsRetail, ClientKey, ForClient) and the
-- character-name readers (UnitCharacterName, CharacterKey) are LibKa0s-Compat-1.0 members, so the
-- family's root, core/Compat.lua, routes them with their library-absent stubs (compat, "The root");
-- so does PlayerSpecID, through Role.Spec(). This file holds the hand-written shims of the same topic.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, namespaced rung first, a secret
-- dropped to nil before it is compared, and a missing API or library answers its documented absent
-- value, never a raise. Loaded straight after core/Compat.lua and before core/SimSetup.lua, which
-- wraps every member.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local RoleLib = LibStub and LibStub("LibKa0s-Role-1.0", true)

local VALID_ROLE = { TANK = true, HEALER = true, DAMAGER = true }

-- A plain (non-secret) string, or nil.
local function plainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

-- A plain (non-secret) number, or nil.
local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- ── The realm and names ─────────────────────────────────────────────────────────────────────

--- The player's realm as chat and unit names spell it: GetNormalizedRealmName (spaces and hyphens
--- dropped), which answers nil early in the login, then GetRealmName with the same characters
--- dropped. Nil when neither answers a plain, non-empty string.
--- @return string|nil
function Compat.NormalizedRealm()
    local realm = GetNormalizedRealmName and plainString(GetNormalizedRealmName())
    if realm and realm ~= "" then return realm end
    realm = GetRealmName and plainString(GetRealmName())
    realm = realm and realm:gsub("[%s%-]", "")
    if realm and realm ~= "" then return realm end
    return nil
end

--- The realm a same-realm `Name-Realm` carries (modules/Roster.lua's identity, the group roster's
--- and the cards' own-realm test, the simulator's members): NormalizedRealm on Retail, and nil with
--- regional names (WoW Forever, client-quirks-§5), where a character is its whole name and there
--- is no cross-realm play to put a realm on anyone.
--- @return string|nil
function Compat.NameRealm()
    if Compat.RegionalNames() then return nil end
    return Compat.NormalizedRealm()
end

--- The player as the stored records name a character (a drop's and a History entry's `seenBy`,
--- the Character dropdown's key): with regional names (WoW Forever) the character key, "First
--- Surname" (CharacterKey, else the whole name UnitCharacterName reads), so two alts who share a
--- first name never collide; otherwise `Name-Realm` over the normalized realm, the key History has
--- stored since v1, kept so a Retail log stays the same character's. Nil while the client does not
--- know the name (or, on Retail, the realm) yet.
--- @return string|nil
function Compat.PlayerRecordKey()
    if Compat.RegionalNames() then
        return Compat.CharacterKey() or Compat.UnitCharacterName("player")
    end
    local name, realm = Compat.UnitCharacterName("player"), Compat.NormalizedRealm()
    if not (name and realm) then return nil end
    if name:find("-", 1, true) then return name end
    return name .. "-" .. realm
end

--- Whom you are trading with (the trade window's partner unit, "NPC"), through UnitCharacterName:
--- the whole name with regional names (WoW Forever: "Traxex Silentshot", never "Traxex-Silentshot"),
--- else `Name-Realm` when the client names a realm, else `Name`. Nil for a secret or missing name.
--- @return string|nil
function Compat.TradePartnerName()
    local name, realm = Compat.UnitCharacterName("NPC")
    if not name then return nil end
    if realm then return name .. "-" .. realm end
    return name
end

-- ── Specs ───────────────────────────────────────────────────────────────────────────────────

--- A specialization's localized name (the detail card's looter spec): GetSpecializationInfoByID's
--- second return. Nil for no API, an unknown or non-number id, or a secret or empty answer.
--- @param specID number
--- @return string|nil
function Compat.SpecName(specID)
    if type(specID) ~= "number" or Compat.IsSecret(specID) then return nil end
    local fn = GetSpecializationInfoByID
    if not fn then return nil end
    local _, name = fn(specID)
    if Compat.IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

--- The inspected unit's specialization id, or nil: 0 (not known), a secret answer or no API.
--- C_SpecializationInfo.GetInspectSpecialization first, the global second: on Retail the global
--- exists only under a deprecation CVar (Forever port research R4 §3.2).
--- @param unit string
--- @return number|nil
function Compat.InspectSpecID(unit)
    local si = C_SpecializationInfo
    local fn = si and si.GetInspectSpecialization or GetInspectSpecialization
    if not fn then return nil end
    local id = plainNumber(fn(unit))
    if not id or id <= 0 then return nil end
    return id
end

--- The player's talent tree on WoW Forever: the group of LibKa0s Role.Groups() with the most
--- points spent, as `{ index, name }` (index in the tree's display order). Nil on Retail (Role has
--- no groups there), on a tie for the most points, with no points spent, and without the library.
--- @return table|nil
function Compat.PlayerTalentTree()
    if not (RoleLib and RoleLib.Groups) then return nil end
    local best, tied
    for _, group in ipairs(RoleLib.Groups()) do
        local spent = plainNumber(group.spent) or 0
        if spent > 0 and (not best or spent > best.spent) then
            best, tied = { index = group.index, name = plainString(group.name), spent = spent }, false
        elseif best and spent == best.spent then
            tied = true
        end
    end
    if not best or tied then return nil end
    return { index = best.index, name = best.name }
end

--- The player's talent trees' names on WoW Forever, by their index in display order (LibKa0s
--- Role.Groups()): `{ [index] = name }`, a name the client does not give left out. Empty on Retail,
--- and without the library (the Comparison page's strip, Forever port design §4.3).
--- @return table
function Compat.TalentTreeNames()
    local out = {}
    if not (RoleLib and RoleLib.Groups) then return out end
    for _, group in ipairs(RoleLib.Groups()) do
        local name = plainString(group.name)
        if type(group.index) == "number" and name and name ~= "" then out[group.index] = name end
    end
    return out
end

-- ── The role (LibKa0s-Role-1.0) ─────────────────────────────────────────────────────────────

--- This character's role store (`db.char.role`: the player's override and the last answer),
--- made on first use; nil before the database exists.
--- @return table|nil
function Compat.RoleStore()
    local db = NS.addon and NS.addon.db
    local char = db and db.char
    if type(char) ~= "table" then return nil end
    if type(char.role) ~= "table" then char.role = {} end
    return char.role
end

-- The library-absent ladder: the player's override, then the group's assignment.
local function fallbackRole(store)
    local override = store and store.override
    if VALID_ROLE[override] then return override, "override", nil end
    local assigned = UnitGroupRolesAssigned and plainString(UnitGroupRolesAssigned("player")) or nil
    if VALID_ROLE[assigned] then return assigned, "assigned", nil end
    return nil, nil, nil
end

--- The role the player plays: role ("TANK", "HEALER", "DAMAGER" or nil), source ("override",
--- "assigned", "talents", "spec", "saved" or nil) and detail (the talent group's or the spec's
--- name, or nil): LibKa0s Role.Resolve over this character's store.
--- @return string|nil role, string|nil source, string|nil detail
function Compat.PlayerRole()
    local store = Compat.RoleStore()
    if RoleLib and RoleLib.Resolve then return RoleLib.Resolve(store) end
    return fallbackRole(store)
end

--- Set the player's pick ("TANK", "HEALER" or "DAMAGER"), or nil for Automatic: LibKa0s
--- Role.SetOverride on this character's store. False when there is no store yet or the role is
--- not one of the three.
--- @param role string|nil
--- @return boolean
function Compat.SetRoleOverride(role)
    local store = Compat.RoleStore()
    if not store or (role ~= nil and not VALID_ROLE[role]) then return false end
    if RoleLib and RoleLib.SetOverride then
        RoleLib.SetOverride(store, role)
    else
        store.override = role
    end
    return true
end
