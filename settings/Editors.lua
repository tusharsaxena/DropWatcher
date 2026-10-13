local _, NS = ...
-- settings/Editors.lua — the pure halves of the settings pages' own editors (design spec §12.2).
--
-- Every page draws its rows through the library's flow engine. Five things on them are not its to
-- draw: the Comparison page's per-spec weights and unwanted item types (two whole-value `map` rows,
-- `skipRender`), General › When to show's table (the per-situation rows, `skipRender`, one table
-- row per situation), the Messages page's template editors (their live counters, the token chips
-- and the preview) and the Feed page's "in force now" readout. Their widgets are
-- settings/PageEditors.lua's; what they show and what they write is decided here, with no widget
-- and no client call, so the suites can pin it. A map write is always a fresh table: the seam
-- stores what it is handed, and an edit made in place on the stored table would skip the seam's
-- check and its announce.

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L
local K        = NS.Constants
local CD       = NS.ClassData

local E = {}
Settings.Editors = E

local function isTable(v) return type(v) == "table" end

local function copy(v)
    if not isTable(v) then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = copy(val) end
    return out
end

local function isEmpty(t)
    return next(t) == nil
end

-- ── the specs a page edits ──────────────────────────────────────────────────────────────────

--- A class's specializations, in specID order, as sub-tab entries: { key = specID, label }.
--- @param classFile string
--- @param nameOf function specID -> localized name or nil (Compat.SpecName)
--- @return table
function E.ClassSpecs(classFile, nameOf)
    local out = {}
    for _, specID in ipairs(CD.CLASS_SPECS[classFile] or {}) do
        local name = type(nameOf) == "function" and nameOf(specID) or nil
        out[#out + 1] = { key = specID, label = type(name) == "string" and name ~= "" and name or tostring(specID) }
    end
    return out
end

--- The spec a sub-strip shows: the remembered one while the list still has it, else the player's
--- own, else the first. Nil for an empty list.
--- @param list table E.ClassSpecs' answer
--- @param remembered number|nil
--- @param own number|nil
--- @return number|nil
function E.PickSpec(list, remembered, own)
    local has = {}
    for _, e in ipairs(list) do has[e.key] = true end
    if remembered and has[remembered] then return remembered end
    if own and has[own] then return own end
    return list[1] and list[1].key or nil
end

-- ── Comparison › Weights ────────────────────────────────────────────────────────────────────

-- The stat keys a weight is given for: GetItemStats' own keys, so the scorer (DW-50) multiplies
-- what the client reports without a translation table.
local SECONDARY = {
    "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY",
}
local PRIMARY = { CD.STAT.STRENGTH, CD.STAT.AGILITY, CD.STAT.INTELLECT }

-- The English name of each stat, for a client that does not answer the key's own GlobalString.
local STAT_LABEL = {
    ITEM_MOD_STRENGTH_SHORT = L["Strength"], ITEM_MOD_AGILITY_SHORT = L["Agility"],
    ITEM_MOD_INTELLECT_SHORT = L["Intellect"], ITEM_MOD_STAMINA_SHORT = L["Stamina"],
    ITEM_MOD_CRIT_RATING_SHORT = L["Critical Strike"], ITEM_MOD_HASTE_RATING_SHORT = L["Haste"],
    ITEM_MOD_MASTERY_RATING_SHORT = L["Mastery"], ITEM_MOD_VERSATILITY = L["Versatility"],
}

-- The slider's range: a Pawn scale's values sit well inside it.
E.WEIGHT_MIN, E.WEIGHT_MAX, E.WEIGHT_STEP = 0, 5, 0.05

--- The stats a spec's weights cover: its primary stat (all three when the spec is unknown), then
--- Stamina and the four secondaries.
--- @param specID number|nil
--- @return table stat keys
function E.StatsFor(specID)
    local row = CD.Spec(specID)
    local out = {}
    if row then out[1] = row.stat else for i, s in ipairs(PRIMARY) do out[i] = s end end
    for _, s in ipairs(SECONDARY) do out[#out + 1] = s end
    return out
end

--- A stat's display name: the client's own GlobalString for the key, else the English one.
--- @param key string
--- @param globals table|nil where to look the key up (_G in the client)
--- @return string
function E.StatLabel(key, globals)
    local own = isTable(globals) and globals[key] or nil
    if type(own) == "string" and own ~= "" then return own end
    return STAT_LABEL[key] or tostring(key)
end

--- One spec's weight for one stat, 0 when unset.
--- @return number
function E.Weight(map, specID, stat)
    local w = isTable(map) and map[specID]
    local v = isTable(w) and w[stat] or nil
    return type(v) == "number" and v or 0
end

--- The weights map with one weight changed: a fresh table. A weight of 0 (or not a number) removes
--- the stat, and a spec left with none is removed, so the stored map holds what was set.
--- @return table
function E.WithWeight(map, specID, stat, value)
    local out = isTable(map) and copy(map) or {}
    local w = isTable(out[specID]) and out[specID] or {}
    if type(value) == "number" and value == value and value ~= 0 then w[stat] = value else w[stat] = nil end
    out[specID] = not isEmpty(w) and w or nil
    return out
end

-- The import box's chat lines (modules/Scoring.lua's ImportInto answers the result or a reason).
local IMPORT_FAIL = {
    empty   = L["Paste a Pawn scale string first."],
    format  = L["That is not a Pawn scale string: it reads ( Pawn: v1: \"name\": Key=value, ... )."],
    noStats = L["That scale has no stat Drop Watcher scores, so nothing was imported."],
    noSpec  = L["Pick a specialization first."],
}

--- The chat line after an import: what was imported and what was left out, or why it failed.
--- @param result table|string ImportInto's result, or its reason
--- @param specLabel string the specialization's name
--- @return string
function E.ImportText(result, specLabel)
    if not isTable(result) then return IMPORT_FAIL[result] or IMPORT_FAIL.format end
    local n = 0
    for _ in pairs(result.weights or {}) do n = n + 1 end
    local text = L["Imported %s into %s: %d weights."]:format(result.name or "", tostring(specLabel), n)
    if result.skipped and #result.skipped > 0 then
        text = text .. " " .. L["Not scored: %s."]:format(table.concat(result.skipped, ", "))
    end
    return text
end

-- ── Comparison › Preferences ────────────────────────────────────────────────────────────────

-- The weapon types in the order a player reads them, with their English names. Ids from
-- NS.Constants (anti-pattern #37: never a localized type name).
local W = K.WEAPON_SUBCLASS
local WEAPON_ORDER = {
    { W.AXE_1H, L["One-handed axes"] }, { W.MACE_1H, L["One-handed maces"] },
    { W.SWORD_1H, L["One-handed swords"] }, { W.DAGGER, L["Daggers"] }, { W.FIST, L["Fist weapons"] },
    { W.WARGLAIVE, L["Warglaives"] }, { W.AXE_2H, L["Two-handed axes"] },
    { W.MACE_2H, L["Two-handed maces"] }, { W.SWORD_2H, L["Two-handed swords"] },
    { W.POLEARM, L["Polearms"] }, { W.STAFF, L["Staves"] }, { W.BOWS, L["Bows"] },
    { W.GUNS, L["Guns"] }, { W.CROSSBOW, L["Crossbows"] }, { W.WAND, L["Wands"] },
}

-- Whether any spec of the class carries a shield.
local function classHasShield(classFile)
    for _, specID in ipairs(CD.CLASS_SPECS[classFile] or {}) do
        if CD.Spec(specID).shield then return true end
    end
    return false
end

--- The item types a class can mark as unwanted: every weapon type its loot comes in, then shields
--- where a spec carries one. Each is { key = "<classID>:<subClassID>" (Evaluate.SubClassKey), label }.
--- Armor types are left out: a class's loot comes in one, and held off hands share their subclass
--- with rings, necks and trinkets.
--- @param classFile string
--- @return table
function E.UndesiredChoices(classFile)
    local out, usable = {}, CD.WEAPONS[classFile] or {}
    local weapon, armor = K.ITEM_CLASS.WEAPON, K.ITEM_CLASS.ARMOR
    for _, e in ipairs(WEAPON_ORDER) do
        if usable[e[1]] then out[#out + 1] = { key = NS.Evaluate.SubClassKey(weapon, e[1]), label = e[2] } end
    end
    if classHasShield(classFile) then
        out[#out + 1] = { key = NS.Evaluate.SubClassKey(armor, K.ARMOR_SUBCLASS.SHIELD), label = L["Shields"] }
    end
    return out
end

--- Whether a spec marked an item type unwanted.
--- @return boolean
function E.IsUndesired(map, specID, key)
    local set = isTable(map) and map[specID]
    return isTable(set) and set[key] == true or false
end

--- The unwanted-types map with one type marked or cleared: a fresh table, a spec left with none
--- removed.
--- @return table
function E.WithUndesired(map, specID, key, on)
    local out = isTable(map) and copy(map) or {}
    local set = isTable(out[specID]) and out[specID] or {}
    set[key] = on and true or nil
    out[specID] = not isEmpty(set) and set or nil
    return out
end

-- ── Messages › Templates ────────────────────────────────────────────────────────────────────

-- What each token fills in, for the chip's tooltip (design spec §9.1).
E.TOKEN_TIPS = {
    player = L["The player's name: the looter for an ask, the candidate for an offer."],
    item   = L["The item's link."],
    ilvl   = L["The item's level."],
    slot   = L["The slot the item goes in."],
    track  = L["The item's upgrade track."],
    gain   = L["The item levels the looter, or the candidate, would gain."],
    mygain = L["The item levels you would gain."],
}

-- Each template's editor label (design spec §9.1, board 08).
E.TEMPLATE_LABEL = {
    ask      = L["Ask (whisper to the looter)"],
    transmog = L["Ask for transmog (whisper to the looter)"],
    offer    = L["Offer (whisper to a candidate)"],
    announce = L["Announce (group, raid or instance)"],
}

-- A template's short name, for the preview's header.
E.KIND_NAME = { ask = L["Ask"], transmog = L["Ask for transmog"], offer = L["Offer"], announce = L["Announce"] }

local RED = "|cffff4040%s|r"

--- An editor's label with its live counter: `Ask (whisper to the looter)   104 / 255`, the
--- count red past the chat limit. Counted in bytes, which is what the limit counts.
--- @param kind string
--- @param text string|nil
--- @return string label, boolean over
function E.CounterLabel(kind, text)
    local n = type(text) == "string" and #text or 0
    local count = ("%d / %d"):format(n, K.MESSAGE_MAX_LEN)
    local over = n > K.MESSAGE_MAX_LEN
    if over then count = RED:format(count) end
    return ("%s   %s"):format(E.TEMPLATE_LABEL[kind] or kind, count), over
end

local function isMine(rec)
    return rec.isMine == true or (isTable(rec.looter) and rec.looter.isSelf == true)
end

-- The candidate an offer preview is written to: the one who gains most, ties by name.
local function bestCandidate(rec)
    local best, bestGain
    for guid, c in pairs(isTable(rec.candidates) and rec.candidates or {}) do
        local gain = isTable(c.eval) and type(c.eval.ilvlDelta) == "number" and c.eval.ilvlDelta or nil
        if gain and gain > 0 and (not best or gain > bestGain or (gain == bestGain and tostring(c.name) < tostring(best.name))) then
            best, bestGain = { name = c.name, guid = guid }, gain
        end
    end
    return best
end

local function myGain(rec)
    local d = isTable(rec.me) and rec.me.ilvlDelta or nil
    return type(d) == "number" and d or nil
end

-- Per kind, who a drop's preview is written to, or nil when the drop does not fit. `strict` asks for
-- the drop the message is written for (an ask: an upgrade for you); the second pass takes any.
local function lookMissing(rec)
    return isTable(rec.facts) and rec.facts.transmogKnown == false
end

local SAMPLE = {
    ask = function(rec, strict)
        if isMine(rec) or not isTable(rec.looter) then return nil end
        if strict and (myGain(rec) or 0) <= 0 then return nil end
        return { name = rec.looter.name, guid = rec.looter.guid }
    end,
    -- A drop whose look you have not collected, when there is one.
    transmog = function(rec, strict)
        if isMine(rec) or not isTable(rec.looter) then return nil end
        if strict and not lookMissing(rec) then return nil end
        return { name = rec.looter.name, guid = rec.looter.guid }
    end,
    offer = function(rec)
        if not isMine(rec) then return nil end
        return bestCandidate(rec)
    end,
    announce = function(rec)
        if not isMine(rec) then return nil end
        return {}
    end,
}

--- The drop a template's preview is written for, newest first: for an ask another member's drop
--- and its looter (one that is an upgrade for you when there is one; for the transmog ask one whose
--- look you have not collected), for an offer your own drop and the candidate who gains most, for an announce your
--- own drop. Nil when no drop in `drops` fits.
--- @param kind string
--- @param drops table drop records, oldest first
--- @return table|nil rec, table|nil who { name, guid }
function E.PreviewSample(kind, drops)
    local pick = SAMPLE[kind]
    if not (pick and isTable(drops)) then return nil, nil end
    for _, strict in ipairs({ true, false }) do
        for i = #drops, 1, -1 do
            local rec = drops[i]
            local who = isTable(rec) and pick(rec, strict) or nil
            if who then return rec, who end
        end
    end
    return nil, nil
end

--- The preview's three lines for a template over a sample: the header (`Preview: Ask, to Séta`),
--- the text as it would be sent (`To Séta: …`), and the status (its length against the limit, any
--- unknown token, `too long to send`).
--- @param kind string
--- @param template string
--- @param ctx table the token values (NS.Asks.TokenContext)
--- @param to string|nil who it goes to: a name, or the channel's name for an announce
--- @return table { header, body, status, tooLong, unknown }
function E.PreviewLines(kind, template, ctx, to)
    local p = NS.Messaging.Preview(template, ctx)
    local who = to or L["the group"]
    local parts = { ("%d / %d"):format(p.length, K.MESSAGE_MAX_LEN) }
    if p.tooLong then parts[#parts + 1] = RED:format(L["too long to send"]) end
    if #p.unknown > 0 then
        local names = {}
        for i, n in ipairs(p.unknown) do names[i] = "{" .. n .. "}" end
        parts[#parts + 1] = RED:format(L["unknown tokens, sent as typed: %s"]:format(table.concat(names, " ")))
    end
    return {
        header  = L["Preview: %s, to %s"]:format(E.KIND_NAME[kind] or kind, who),
        body    = L["To %s: %s"]:format(who, p.text),
        status  = table.concat(parts, "  \194\183  "),
        tooLong = p.tooLong, unknown = p.unknown,
    }
end

-- ── General › When to show ──────────────────────────────────────────────────────────────────

--- The table's three setting columns, in order: each one a field of `situations.<key>`.
E.SITUATION_FIELDS = { "track", "autoOpen", "quality" }

-- One cell: its schema row, the value stored at its path, and whether it is live. Live unless the
-- row's own `disabledIf` says otherwise (settings/SchemaRows.lua), so the table dims exactly what
-- the row dims and the rule has one home.
local function situationCell(findRow, read, path)
    local row = findRow(path)
    local off = row and type(row.disabledIf) == "function" and row.disabledIf() or false
    return { path = path, row = row, value = read(path), enabled = not off }
end

--- General › When to show's table: one entry per situation, in K.SITUATIONS order, carrying its
--- key, its label, whether it is tracked (`active`: an untracked row's label dims) and a cell per
--- E.SITUATION_FIELDS field.
--- @param findRow function path -> schema row (NS.SchemaRuntime.FindRow)
--- @param read function path -> stored value (NS.Setting)
--- @param labelOf function situation key -> display name (WindowFooter.SituationLabel)
--- @return table
function E.SituationRows(findRow, read, labelOf)
    local out = {}
    for _, s in ipairs(K.SITUATIONS) do
        local entry = { key = s.key, label = labelOf(s.key) }
        for _, field in ipairs(E.SITUATION_FIELDS) do
            entry[field] = situationCell(findRow, read, ("situations.%s.%s"):format(s.key, field))
        end
        entry.active = entry.track.value == true
        out[#out + 1] = entry
    end
    return out
end

-- ── Feed › Quality ──────────────────────────────────────────────────────────────────────────

--- The "in force now" line under the Quality tab: the threshold the feed applies where you are,
--- naming the situation when its own setting overrides the feed's mode.
--- @param label string the filter bar's label (WindowFilterBar.QualityReadout's third answer)
--- @param situationLabel string|nil the current situation's name when it overrides, else nil
--- @return string
function E.ReadoutText(label, situationLabel)
    if situationLabel then
        return L["In force now: %s (%s's own setting)"]:format(label, situationLabel)
    end
    return L["In force now: %s"]:format(label)
end

