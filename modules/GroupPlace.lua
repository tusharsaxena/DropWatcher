local _, NS = ...
-- modules/GroupPlace.lua — where a group's drops came from and who saw them (feedback-3 spec §4,
-- DW-B4): the instance and the difficulty the client names, captured when a group opens and kept on
-- it (and on its History group), and the header's words for them and for its recorder.
--
--   group = { ..., instance, difficulty, seenBy, seenByClass }
--
-- `instance` is the instance's name (a dungeon, raid, delve, battleground or arena) while you are in
-- one, else nil. `difficulty` is the difficulty's name as the client gives it (GetInstanceInfo's own
-- difficultyName when it names one, else GetDifficultyInfo's: Timewalking, Normal, Heroic, Mythic,
-- Looking For Raid, Delves, ...), or `Mythic+ 12` for a keystone run (the active key's level, else
-- the completed run's; `Mythic+` when neither answers); nil outside an instance. A delve's tier is
-- not read: neither call is known to name it (both give `Delves` for difficulty 208), so a delve
-- header reads `Delves` until SMOKE FEED-30 shows what the client gives (a known limitation). Both come through NS.Compat (core/CompatWorld.lua), so a simulation's seam
-- answers them. `seenBy` and `seenByClass` are the recorder of the group's first drop
-- (modules/CharFilter.lua's stamp).
--
-- THE CAPTURE. modules/LootFeed.lua stamps the place on the spec of the group a drop received now
-- joins (Stamp); modules/FeedRecords.lua's Materialize copies it, with the drop's recorder, onto the
-- group it makes, so a group keeps the place it opened in. A test drop's spec carries its own
-- (modules/TestData.lua). modules/History.lua keeps all four on the History group.
--
-- THE HEADER. Parts names the place: the instance, the label (the boss or encounter; a key run's
-- and an area's label is the instance itself, so it is named once), then the difficulty. A group
-- with no difficulty name (the open world, a client that gives none, a History group kept before
-- DW-B4) falls back to the generic situation word, so an older group keeps its current label. Who
-- names the recorder alone, its short name in its class color: you on Drops, the
-- character that saw it on History. The party is no longer named in the header; its tooltip keeps
-- one `Group: ...` line (modules/GroupRoster.lua's TipLine).
--
-- PURE: DifficultyName, Parts, Recorder and Who take plain values (and a color function) and read
-- nothing else; test_group_place drives them. Read and Stamp are the edge: they read NS.Compat at
-- call time.

NS.GroupPlace = NS.GroupPlace or {}
local GP = NS.GroupPlace
local C  = NS.Constants
local L  = NS.L

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function plain(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

local function same(a, b)
    return a ~= nil and b ~= nil and a:lower() == b:lower()
end

--- The difficulty's name for a header: `Mythic+ <level>` for a keystone run (`Mythic+` without a
--- level), else the client's name. Nil when the client gives none.
--- @param id number|nil the difficulty id
--- @param name string|nil GetDifficultyInfo's name
--- @param keyLevel number|nil the keystone's level
--- @return string|nil
function GP.DifficultyName(id, name, keyLevel)
    if id == C.DIFFICULTY.MYTHIC_KEYSTONE then
        local level = tonumber(keyLevel)
        if level and level > 0 then return L["Mythic+ %d"]:format(level) end
        return L["Mythic+"]
    end
    return plain(name)
end

--- A header's place, in order: the instance (an encounter's only), the label, then the difficulty
--- or, without one, `situationLabel`. A part the one before it already says is left out.
--- @param group table { label, kind, instance, difficulty }
--- @param situationLabel string|nil the generic situation word
--- @return table parts
function GP.Parts(group, situationLabel)
    local out = {}
    local function push(v)
        if v and not same(v, out[#out]) then out[#out + 1] = v end
    end
    if group.kind == "encounter" then push(plain(group.instance)) end
    push(plain(group.label) or "?")
    push(plain(group.difficulty) or plain(situationLabel))
    return out
end

--- The character that saw a group: its own recorder, else (a History group kept before DW-B4) the
--- first of its entries that has one. Nil, nil when none does.
--- @param group table
--- @return string|nil key Name-Realm, string|nil classFile
function GP.Recorder(group)
    if plain(group.seenBy) then return group.seenBy, plain(group.seenByClass) end
    for _, e in ipairs(type(group.drops) == "table" and group.drops or {}) do
        if type(e) == "table" and plain(e.seenBy) then return e.seenBy, plain(e.seenByClass) end
    end
    return nil, nil
end

--- The recorder's short name for a header, in its class color; nil when the group names none.
--- @param group table
--- @param colorOf function|nil classFile -> r, g, b
--- @return string|nil
function GP.Who(group, colorOf)
    local key, class = GP.Recorder(group)
    if not key then return nil end
    local name = key:match("^([^%-]+)") or key
    if not class or type(colorOf) ~= "function" then return name end
    return NS.GroupRoster.Colored(name, colorOf(class))
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local function plainString(v)
    if NS.Compat.IsSecret(v) then return nil end
    return plain(v)
end

local function plainNumber(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

--- Where you are now: { instance, difficulty }, both nil outside an instance.
--- @return table
function GP.Read()
    local Compat = NS.Compat
    if not Compat.InstanceState() then return {} end
    local name, _, id, diffName = Compat.InstanceInfo()
    id = plainNumber(id)
    local out = { instance = plainString(name) }
    if id and id > 0 then
        local level = id == C.DIFFICULTY.MYTHIC_KEYSTONE and Compat.KeystoneLevel() or nil
        out.difficulty = GP.DifficultyName(id, plainString(diffName) or Compat.DifficultyName(id), level)
    end
    return out
end

--- Stamp where you are now on a group spec that names no place yet (modules/LootFeed.lua's).
--- @param spec table { key, label, kind, ... }
--- @return table spec
function GP.Stamp(spec)
    if spec.instance == nil and spec.difficulty == nil then
        local p = GP.Read()
        spec.instance, spec.difficulty = p.instance, p.difficulty
    end
    return spec
end
