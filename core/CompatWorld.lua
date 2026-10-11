local _, NS = ...
-- core/CompatWorld.lua — the stable world reads, published on NS.Compat so the simulator's answer
-- seam (core/SimSeam.lua, simulator spec §2) answers them too: the group's size and kind, a unit's
-- GUID, name, class and connection, where the player is (the instance, its difficulty, a keystone
-- run in progress), whether the player is fighting, and the GlobalStrings (the LOOT_ITEM* lines).
--
-- WHY HERE. None of these APIs is version-variant, so the compat rule does not need them in
-- core/Compat.lua (which stays the only caller of the variant ones, under its 1000-line cap). They
-- are members of NS.Compat all the same, because the seam wraps every NS.Compat member: a module
-- that read the global directly would bypass a running simulation and see the real, empty group.
-- Every module reads them here (sim feedback §0, DW-90: tests/test_sim_e2e.lua fails a module that
-- names one of these globals itself).
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a missing API answers its
-- documented absent value and never raises. These members answer the client's raw values, secrets
-- included, exactly as the global would: each caller already guards them (IsSecret, IsSafeKey).

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

--- GetNumGroupMembers(): the group's size counting you, 0 outside a group.
--- @return number
function Compat.GroupSize()
    if not GetNumGroupMembers then return 0 end
    return GetNumGroupMembers() or 0
end

--- IsInRaid() as a plain boolean.
--- @return boolean
function Compat.InRaid()
    return IsInRaid ~= nil and IsInRaid() == true
end

--- IsInGroup(category) as a plain boolean; `category` is an LE_PARTY_CATEGORY_* value or nil (any).
--- @param category number|nil
--- @return boolean
function Compat.InGroup(category)
    return IsInGroup ~= nil and IsInGroup(category) == true
end

--- The party category of an instance group (LE_PARTY_CATEGORY_INSTANCE, 2 without the global).
--- @return number
function Compat.InstanceGroupCategory()
    return LE_PARTY_CATEGORY_INSTANCE or 2
end

--- UnitGUID(unit), raw (it may be secret). Nil without the API.
--- @param unit string
--- @return any
function Compat.UnitGUID(unit)
    if not UnitGUID then return nil end
    return UnitGUID(unit)
end

--- UnitName(unit): name, realm, raw (either may be secret; realm is nil on your own realm).
--- @param unit string
--- @return any name, any realm
function Compat.UnitName(unit)
    if not UnitName then return nil end
    return UnitName(unit)
end

--- UnitClass(unit): localized name, classFile, classID, raw.
--- @param unit string
--- @return any, any, any
function Compat.UnitClass(unit)
    if not UnitClass then return nil end
    return UnitClass(unit)
end

--- UnitIsConnected(unit), raw (it may be secret). True without the API.
--- @param unit string
--- @return any
function Compat.UnitIsConnected(unit)
    if not UnitIsConnected then return true end
    return UnitIsConnected(unit)
end

--- IsInInstance(): inInstance (a plain boolean), instanceType ("none", "party", "raid", ...).
--- @return boolean, string|nil
function Compat.InstanceState()
    if not IsInInstance then return false, nil end
    local inInstance, instanceType = IsInInstance()
    return inInstance == true, instanceType
end

--- GetInstanceInfo(): name, instanceType, difficultyID, raw. Nil without the API.
--- @return any, any, any
function Compat.InstanceInfo()
    if not GetInstanceInfo then return nil end
    local name, instanceType, difficultyID = GetInstanceInfo()
    return name, instanceType, difficultyID
end

--- Whether the client knows difficulty `id` (GetDifficultyInfo answers for it). False for a
--- retired or renumbered id, a non-positive one, or no API.
--- @param id any
--- @return boolean
function Compat.DifficultyKnown(id)
    if type(id) ~= "number" or id <= 0 or type(GetDifficultyInfo) ~= "function" then return false end
    return GetDifficultyInfo(id) ~= nil
end

--- C_ChallengeMode.IsChallengeModeActive() as a plain boolean (a keystone run in progress).
--- @return boolean
function Compat.ChallengeModeActive()
    local cm = C_ChallengeMode
    return cm ~= nil and type(cm.IsChallengeModeActive) == "function" and cm.IsChallengeModeActive() == true
end

--- InCombatLockdown() as a plain boolean (false without the API).
--- @return boolean
function Compat.InCombatLockdown()
    return InCombatLockdown ~= nil and InCombatLockdown() == true
end

--- UnitAffectingCombat("player") as a plain boolean (false without the API).
--- @return boolean
function Compat.PlayerInCombat()
    return UnitAffectingCombat ~= nil and UnitAffectingCombat("player") and true or false
end

--- The client's GlobalString `name` (a LOOT_ITEM* line, an INVTYPE_* slot name, a chat type's
--- label), raw, read at call time; nil for a non-string name.
--- @param name any
--- @return any
function Compat.GlobalString(name)
    if type(name) ~= "string" then return nil end
    return _G[name]
end
