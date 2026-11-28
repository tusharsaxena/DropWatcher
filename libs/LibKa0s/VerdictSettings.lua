-- LibKa0s-Verdict-1.0 -- VerdictSettings.lua: the Comparison section a consumer drops into its own
-- settings panel, as `lib.Settings`.
--
-- ── WHAT IT IS ───────────────────────────────────────────────────────────────────────────────
--
-- The verdict's six settings (owner ruling R10 of Ka0s Drop Watcher's
-- docs/superpowers/specs/2026-11-27-itemsearch-split-design.md): the scorer, the sidegrade band,
-- compare owned, protect heirlooms, the per-spec stat weights and the per-spec unwanted item types,
-- with the two editors the two per-spec maps need. Moved from Drop Watcher: the six `comparison.*`
-- rows of its settings/SchemaRows.lua, the defaults of its defaults/Profile.lua `comparison` block,
-- the editors' pure halves of its settings/Editors.lua and their widgets of its
-- settings/PageEditors.lua (WeightsTab, PrefsTab). A file of the Verdict major, paired on
-- Verdict.lua's minor the way CalloutSettings.lua is on Callout's; a payload without this file
-- loads whole and has no lib.Settings.
--
-- ── THE HOST OWNS THE VALUES ─────────────────────────────────────────────────────────────────
--
-- As WaypointArrowSettings' rows: the library stores nothing. Every call takes the host's `spec`:
--
--   spec = { root = "comparison",          -- the six paths are root .. "." .. key
--            L = table | nil,               -- the host's locale, read by Drop Watcher's keys
--            client = "retail" | "forever", -- the class list the editors read (Retail's when nil)
--            get = function(path) -> value, -- the host's stored value (nil reads as the default)
--            set = function(path, value),   -- the host's write seam; an editor hands it a fresh map
--            page = string | nil,           -- Rows: every row's `page`
--            print = function(line) | nil,  -- the import's chat line, prefixed (none when nil)
--            reads = { [member] = fn } | nil }  -- overrides of lib.Reads for the player's class,
--                                               -- spec and talent trees, as host.reads
--
-- `Rows(spec)` answers the six as ordinary schema rows (architecture-§5) for the host to register:
-- `path`, `key`, `type`, `default` (DEFAULTS' value, a map row's a fresh table), `label`, `tooltip`,
-- `validate`, `group` (Scoring, Weights, Unwanted types: options-ui-§13's tabs), `values` or
-- `min` / `max` / `step`. The two map rows are `skipRender`: their editors draw them.
--
-- ── THE DRAWN SECTION ────────────────────────────────────────────────────────────────────────
--
-- `Section(ctx, O, spec, tab)` draws on the host's LibKa0s-Options-1.0 instance `O` (the page ctx
-- its CreatePanel answers, or a RenderTabbedSchema host tab's ctx), every control its own, in the
-- host's skin. `tab` picks one part: "scoring" (the four scalar rows, path-less and written through
-- spec.set), "weights" (a sub-strip of your class's specs, one slider per stat and the Pawn scale
-- import box) or "undesired" (the same strip, then one checkbox per item type your class's loot
-- comes in). With no tab the three draw one under another, each under its heading, and the two
-- editors share one strip. `Tabs(O, spec)` answers the two editor tabs for the host's
-- RenderTabbedSchema (`opts.tabs`), keyed by their rows' group, the shape Drop Watcher's Comparison
-- page draws (its Scoring tab is the scalar rows, drawn by the flow engine itself).
--
-- An editor write is always a fresh table (an edit in place on the stored map would skip the
-- host's check and its announce). The strip's selection is session state per tab key,
-- `ctx.activeSubTab[<tab's label>]` (options-ui-§13), and opens on your own spec; a click
-- re-renders the page (O.RefreshPanel), which the library refuses in combat.
--
-- ── WORDS ────────────────────────────────────────────────────────────────────────────────────
--
-- Every word is US English, keyed by itself, Drop Watcher's locale keys (as VerdictTierTokens'
-- words): `spec.L[word]`, read with rawget, else the word. `lib.Settings.WORDS` lists them.
--
-- Depends on the Verdict shell, VerdictConstants.lua, VerdictClassData.lua, VerdictEvaluate.lua
-- (SubClassKey), VerdictReads.lua and VerdictScore.lua (ImportInto); the Options instance is the
-- host's, handed per call.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.ClassData or not lib.C or not lib.SubClassKey or not lib.Score then return end

local SETTINGS_MINOR = 1
local ORDER = 100   -- its place in LibKa0s.xml (Verdict.lua, lib.__Stale)
-- Minor 1 (DropWatcher#19, task B3): Drop Watcher's six comparison rows, their defaults and the
-- weights and unwanted-types editors.
if lib.__settingsMinor and lib.__settingsMinor >= SETTINGS_MINOR
  and lib.__settingsShellMinor == lib.MINOR and not lib.__Stale(ORDER) then return end
lib.__settingsMinor      = SETTINGS_MINOR
lib.__settingsShellMinor = lib.MINOR
lib.__Ran(ORDER)

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictSettings = SETTINGS_MINOR

local St = {}
lib.Settings = St

local C = lib.C

local function isTable(v) return type(v) == "table" end

local function copy(v)
  if not isTable(v) then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = copy(val) end
  return out
end

local function word(L, key)
  local v = isTable(L) and rawget(L, key) or nil
  if type(v) == "string" and v ~= "" then return v end
  return key
end

local function rootOf(spec)
  local r = isTable(spec) and spec.root or nil
  if type(r) ~= "string" or r == "" then r = "comparison" end
  return (r:gsub("%.$", ""))
end

local function pathOf(spec, key) return rootOf(spec) .. "." .. key end

-- ── the defaults ─────────────────────────────────────────────────────────────────────────────

--- The six defaults, Drop Watcher's out-of-box verdicts (its defaults/Profile.lua). Read only:
--- `Defaults()` answers a copy to store.
St.DEFAULTS = {
  scorer          = "auto",   -- auto | pawn | weights | none
  weights         = {},       -- [specKey] = { STAT_KEY = weight }
  sidegradeBand   = 0,        -- item levels either side of equal that read as a sidegrade
  compareOwned    = false,    -- compare against the best of worn and owned
  heirloomProtect = true,     -- a slot holding an heirloom is not called an upgrade
  undesired       = {},       -- [specKey] = { ["<classID>:<subClassID>"] = true }
}

--- The six keys, in the rows' order.
St.KEYS = { "scorer", "sidegradeBand", "compareOwned", "heirloomProtect", "weights", "undesired" }

--- The scorers, in the dropdown's order, with their words.
St.SCORERS = { { "auto", "Automatic" }, { "pawn", "Pawn" }, { "weights", "My weights" }, { "none", "None" } }

--- A fresh copy of DEFAULTS, for a host's defaults table.
--- @return table
function St.Defaults() return copy(St.DEFAULTS) end

-- ── the checks (Drop Watcher's settings/SchemaRows.lua) ──────────────────────────────────────

local function isSpecID(k) return type(k) == "number" and k > 0 and k == math.floor(k) end

-- A per-spec map's key: a specID (Retail), or WoW Forever's "<classFile>:<tree>".
local function isSpecKey(k)
  return isSpecID(k) or (type(k) == "string" and k:match("^%u+:%d+$") ~= nil)
end

local function validWeights(v)
  if not isTable(v) then return false end
  for spec, w in pairs(v) do
    if not isSpecKey(spec) or not isTable(w) then return false end
    for stat, n in pairs(w) do
      if type(stat) ~= "string" or type(n) ~= "number" or n ~= n then return false end
    end
  end
  return true
end

local function validUndesired(v)
  if not isTable(v) then return false end
  for spec, set in pairs(v) do
    if not isSpecKey(spec) or not isTable(set) then return false end
    for key, on in pairs(set) do
      if type(key) ~= "string" or not key:match("^%d+:%d+$") or on ~= true then return false end
    end
  end
  return true
end

local function isBool(v) return type(v) == "boolean" end

local BAND_MIN, BAND_MAX, BAND_STEP = 0, 20, 1

local function validBand(v) return type(v) == "number" and v == v and v >= BAND_MIN and v <= BAND_MAX end

local function validScorer(v) return lib.Score.SCORERS[v] == true end

--- The rows' checks, by key.
St.Checks = {
  scorer = validScorer, sidegradeBand = validBand, compareOwned = isBool, heirloomProtect = isBool,
  weights = validWeights, undesired = validUndesired,
}

-- ── the rows ─────────────────────────────────────────────────────────────────────────────────

local function scorerValues(L)
  local out = {}
  for i, e in ipairs(St.SCORERS) do out[i] = { value = e[1], text = word(L, e[2]) } end
  return out
end

-- Each row's own fields, by key: its type, words, group and widget hints.
local ROW = {
  scorer = { type = "string", label = "Score with", group = "Scoring",
    tooltip = "Automatic uses Pawn once it has loaded and initialized, else your weights, else item level alone." },
  sidegradeBand = { type = "number", label = "Sidegrade band", group = "Scoring",
    min = BAND_MIN, max = BAND_MAX, step = BAND_STEP,
    tooltip = "Item levels either side of equal that still read as a sidegrade." },
  compareOwned = { type = "bool", label = "Compare against items in my bags", group = "Scoring",
    tooltip = "Judge a drop against the best of what you wear and what you carry." },
  heirloomProtect = { type = "bool", label = "Protect heirlooms", group = "Scoring",
    tooltip = "A drop for a slot that holds an heirloom is not called an upgrade." },
  weights = { type = "map", label = "Stat weights", group = "Weights", skipRender = true,
    tooltip = "Your stat weights for each specialization." },
  undesired = { type = "map", label = "Unwanted item types", group = "Unwanted types", skipRender = true,
    tooltip = "The item types each specialization never wants." },
}

local function baseRow(spec, key)
  local L, d = isTable(spec) and spec.L or nil, ROW[key]
  local row = { key = key, type = d.type, label = word(L, d.label), tooltip = word(L, d.tooltip),
    group = word(L, d.group), default = copy(St.DEFAULTS[key]), validate = St.Checks[key],
    min = d.min, max = d.max, step = d.step, skipRender = d.skipRender }
  if key == "scorer" then row.values = scorerValues(L) end
  return row
end

--- The six settings as schema rows at the host's root (see the header), in Drop Watcher's order.
--- @param spec table
--- @return table rows
function St.Rows(spec)
  local out = {}
  for i, key in ipairs(St.KEYS) do
    local row = baseRow(spec, key)
    row.path = pathOf(spec, key)
    if isTable(spec) and spec.page ~= nil then row.page = spec.page end
    out[i] = row
  end
  return out
end

-- ── the editors' pure halves (Drop Watcher's settings/Editors.lua) ───────────────────────────

--- The name of a spec key for the strip: a specID's (`specName`, Reads.SpecName), or for WoW
--- Forever's "<classFile>:<tree>" the talent tree's (`treeNames[tree]`, Reads.TalentTreeNames),
--- else "Talent tree <n>". Answers the `nameOf` ClassSpecs takes.
--- @return function
function St.SpecNamer(specName, treeNames, L)
  return function(key)
    local tree = type(key) == "string" and tonumber(key:match(":(%d+)$"))
    if not tree then return type(specName) == "function" and specName(key) or nil end
    local name = isTable(treeNames) and treeNames[tree] or nil
    if type(name) == "string" and name ~= "" then return name end
    return word(L, "Talent tree %d"):format(tree)
  end
end

--- A class's specializations in spec key order, as sub-tab entries `{ key, label }`, from
--- `client`'s class list: the specID on Retail, "<classFile>:<tree>" on WoW Forever.
--- @return table
function St.ClassSpecs(classFile, nameOf, client)
  local CD, out = lib.ClassData.ForClient(client), {}
  for _, key in ipairs(type(classFile) == "string" and CD.CLASS_SPECS[classFile] or {}) do
    local name = type(nameOf) == "function" and nameOf(key) or nil
    out[#out + 1] = { key = key, label = type(name) == "string" and name ~= "" and name or tostring(key) }
  end
  return out
end

--- The spec a sub-strip shows: the remembered one while the list still has it, else the player's
--- own, else the first. Nil for an empty list.
function St.PickSpec(list, remembered, own)
  local has = {}
  for _, e in ipairs(list) do has[e.key] = true end
  if remembered ~= nil and has[remembered] then return remembered end
  if own ~= nil and has[own] then return own end
  return list[1] and list[1].key or nil
end

-- The stat keys a weight is given for: GetItemStats' own keys, the scorer's.
local SECONDARY = {
  "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT",
  "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY",
}
local STAT = lib.ClassData.STAT
local PRIMARY = { STAT.STRENGTH, STAT.AGILITY, STAT.INTELLECT }

-- Each stat's English name, for a client that does not answer the key's own GlobalString.
local STAT_LABEL = {
  ITEM_MOD_STRENGTH_SHORT = "Strength", ITEM_MOD_AGILITY_SHORT = "Agility",
  ITEM_MOD_INTELLECT_SHORT = "Intellect", ITEM_MOD_STAMINA_SHORT = "Stamina",
  ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike", ITEM_MOD_HASTE_RATING_SHORT = "Haste",
  ITEM_MOD_MASTERY_RATING_SHORT = "Mastery", ITEM_MOD_VERSATILITY = "Versatility",
}

--- The slider's range: a Pawn scale's values sit well inside it.
St.WEIGHT_MIN, St.WEIGHT_MAX, St.WEIGHT_STEP = 0, 5, 0.05

--- The stats a spec's weights cover: its primary stat (all three when `client`'s list does not
--- know the spec), then Stamina and the four secondaries.
--- @return table stat keys
function St.StatsFor(specKey, client)
  local row = lib.ClassData.ForClient(client).Spec(specKey)
  local out = {}
  if row then out[1] = row.stat else for i, s in ipairs(PRIMARY) do out[i] = s end end
  for _, s in ipairs(SECONDARY) do out[#out + 1] = s end
  return out
end

--- A stat's display name: the client's own GlobalString for the key (`globals`, _G in the
--- client), else the English one in the host's words.
--- @return string
function St.StatLabel(key, globals, L)
  local own = isTable(globals) and globals[key] or nil
  if type(own) == "string" and own ~= "" then return own end
  return STAT_LABEL[key] and word(L, STAT_LABEL[key]) or tostring(key)
end

--- One spec's weight for one stat, 0 when unset.
function St.Weight(map, specKey, stat)
  local w = isTable(map) and map[specKey]
  local v = isTable(w) and w[stat] or nil
  return type(v) == "number" and v or 0
end

--- The weights map with one weight changed: a fresh table. A weight of 0 (or not a number) removes
--- the stat, and a spec left with none is removed.
function St.WithWeight(map, specKey, stat, value)
  local out = isTable(map) and copy(map) or {}
  local w = isTable(out[specKey]) and out[specKey] or {}
  if type(value) == "number" and value == value and value ~= 0 then w[stat] = value else w[stat] = nil end
  out[specKey] = next(w) ~= nil and w or nil
  return out
end

-- The import's chat lines when it fails (lib.Score.ImportInto's reasons).
local IMPORT_FAIL = {
  empty   = "Paste a Pawn scale string first.",
  format  = "That is not a Pawn scale string: it reads ( Pawn: v1: \"name\": Key=value, ... ).",
  noStats = "That scale has no stat the verdict scores, so nothing was imported.",
  noSpec  = "Pick a specialization first.",
}

--- The chat line after an import: what was imported and what was left out, or why it failed.
--- @param result table|string ImportInto's result, or its reason
--- @return string
function St.ImportText(result, specLabel, L)
  if not isTable(result) then return word(L, IMPORT_FAIL[result] or IMPORT_FAIL.format) end
  local n = 0
  for _ in pairs(result.weights or {}) do n = n + 1 end
  local text = word(L, "Imported %s into %s: %d weights."):format(result.name or "", tostring(specLabel), n)
  if result.skipped and #result.skipped > 0 then
    text = text .. " " .. word(L, "Not scored: %s."):format(table.concat(result.skipped, ", "))
  end
  return text
end

-- The weapon types in the order a player reads them, with their English names (ids, never a
-- localized type name).
local W = C.WEAPON_SUBCLASS
local WEAPON_ORDER = {
  { W.AXE_1H, "One-handed axes" }, { W.MACE_1H, "One-handed maces" },
  { W.SWORD_1H, "One-handed swords" }, { W.DAGGER, "Daggers" }, { W.FIST, "Fist weapons" },
  { W.WARGLAIVE, "Warglaives" }, { W.AXE_2H, "Two-handed axes" },
  { W.MACE_2H, "Two-handed maces" }, { W.SWORD_2H, "Two-handed swords" },
  { W.POLEARM, "Polearms" }, { W.STAFF, "Staves" }, { W.BOWS, "Bows" },
  { W.GUNS, "Guns" }, { W.CROSSBOW, "Crossbows" }, { W.WAND, "Wands" },
}

local function classHasShield(CD, classFile)
  for _, key in ipairs(CD.CLASS_SPECS[classFile] or {}) do
    if CD.Spec(key).shield then return true end
  end
  return false
end

--- The item types a class can mark unwanted, from `client`'s class list: every weapon type its
--- loot comes in, then shields where a spec carries one, each `{ key = SubClassKey, label }`.
--- Armor types are left out: a class's loot comes in one, and held off hands share their subclass
--- with rings, necks and trinkets.
--- @return table
function St.UndesiredChoices(classFile, client, L)
  local CD, out = lib.ClassData.ForClient(client), {}
  if type(classFile) ~= "string" then return out end
  local usable = CD.WEAPONS[classFile] or {}
  for _, e in ipairs(WEAPON_ORDER) do
    if usable[e[1]] then out[#out + 1] = { key = lib.SubClassKey(C.ITEM_CLASS.WEAPON, e[1]), label = word(L, e[2]) } end
  end
  if classHasShield(CD, classFile) then
    out[#out + 1] = { key = lib.SubClassKey(C.ITEM_CLASS.ARMOR, C.ARMOR_SUBCLASS.SHIELD), label = word(L, "Shields") }
  end
  return out
end

--- Whether a spec marked an item type unwanted.
function St.IsUndesired(map, specKey, key)
  local set = isTable(map) and map[specKey]
  return isTable(set) and set[key] == true or false
end

--- The unwanted-types map with one type marked or cleared: a fresh table, a spec left with none
--- removed.
function St.WithUndesired(map, specKey, key, on)
  local out = isTable(map) and copy(map) or {}
  local set = isTable(out[specKey]) and out[specKey] or {}
  set[key] = on and true or nil
  out[specKey] = next(set) ~= nil and set or nil
  return out
end

-- ── the drawn section ────────────────────────────────────────────────────────────────────────

-- The reads the strip makes: spec.reads' member, else lib.Reads'.
local function read(spec, name, ...)
  local own = isTable(spec.reads) and spec.reads[name] or nil
  local fn = own or (lib.Reads and lib.Reads[name])
  if type(fn) ~= "function" then return nil end
  return fn(...)
end

local function getter(spec, key)
  local path = pathOf(spec, key)
  return function()
    local v = type(spec.get) == "function" and spec.get(path) or nil
    if v == nil then return copy(St.DEFAULTS[key]) end
    return v
  end
end

local function write(spec, key, value)
  if type(spec.set) == "function" then spec.set(pathOf(spec, key), value) end
end

local function classFile(spec)
  local _, file = read(spec, "UnitClass", "player")
  return type(file) == "string" and file or nil
end

local function specNamer(spec)
  return St.SpecNamer(function(id) return read(spec, "SpecName", id) end, read(spec, "TalentTreeNames"), spec.L)
end

-- Your own spec key: the specID on Retail, your top talent tree's "<classFile>:<tree>" on Forever.
local function ownSpecKey(spec, file)
  local talents = read(spec, "PlayerTalentTree")
  local specID = read(spec, "PlayerSpecID")
  local CD = lib.ClassData.ForClient(spec.client)
  return CD.SpecKey(file, specID, isTable(talents) and talents.index or nil) or specID
end

local function note(O, ctx, text)
  O.TextRow(ctx, text, { fontObject = "GameFontHighlightSmall" })
  O.AddSpacer(O.EnsureScroll(ctx), 6)
end

-- The strip of your class's specs (on WoW Forever its talent trees) at the top of the tab's
-- content; answers the spec key it shows. The selection is ctx.activeSubTab[tabKey].
local function specStrip(O, ctx, spec, tabKey, file)
  local scroll = O.EnsureScroll(ctx)
  local list = St.ClassSpecs(file, specNamer(spec), spec.client)
  if not scroll or #list == 0 then return nil end
  ctx.activeSubTab = ctx.activeSubTab or {}
  local shown = St.PickSpec(list, ctx.activeSubTab[tabKey], ownSpecKey(spec, file))
  ctx.activeSubTab[tabKey] = shown
  local holder = O.AceGUI:Create("SimpleGroup")
  holder:SetLayout(nil)
  holder:SetFullWidth(true)
  scroll:AddChild(holder)
  local _, height = O.SubTabStrip(ctx, holder.frame, {
    tabs = list, value = shown,
    onSelect = function(k)
      if k == ctx.activeSubTab[tabKey] then return end
      ctx.activeSubTab[tabKey] = k
      O.RefreshPanel(ctx, true)
    end,
  })
  holder:SetHeight(height or 0)
  O.AddSpacer(scroll, 6)
  return shown
end

local function specLabel(spec, key)
  local name = specNamer(spec)(key)
  return type(name) == "string" and name ~= "" and name or tostring(key)
end

local function weightRow(spec, key, stat)
  local get = getter(spec, "weights")
  return {
    type = "number", min = St.WEIGHT_MIN, max = St.WEIGHT_MAX, step = St.WEIGHT_STEP,
    label = St.StatLabel(stat, _G, spec.L),
    tooltip = word(spec.L, "What one point of this stat is worth to this specialization. 0 leaves it out."),
    get = function() return St.Weight(get(), key, stat) end,
    set = function(v) write(spec, "weights", St.WithWeight(get(), key, stat, v)) end,
  }
end

-- Enter in the import box: the pasted Pawn scale replaces this spec's weights through spec.set,
-- the chat says what came in (through spec.print, the host's prefixed printer; with none, no line:
-- the prefix is the host's brand, slash-commands-§4), and the page redraws its sliders.
local function importScale(O, ctx, spec, key, text, box)
  local map, result = lib.Score.ImportInto(getter(spec, "weights")(), key, text)
  if type(spec.print) == "function" then spec.print(St.ImportText(result, specLabel(spec, key), spec.L)) end
  if not map then return end
  write(spec, "weights", map)
  box:SetText("")
  O.RefreshPanel(ctx, true)
end

local function importLine(O, spec, key)
  local label = word(spec.L, "Import a Pawn scale")
  return {
    wide = true,
    make = function(ctx, into)
      local box = O.AceGUI:Create("EditBox")
      box:SetLabel(label)
      box:SetFullWidth(true)
      box:SetCallback("OnEnterPressed", function(_, _, text) importScale(O, ctx, spec, key, text, box) end)
      O.AttachTooltip(box, label,
        word(spec.L, "Paste a Pawn scale string and press Enter: it replaces this specialization's weights."))
      into:AddChild(box)
    end,
  }
end

local function weightsBody(O, ctx, spec, key)
  note(O, ctx, word(spec.L, "Used when Score with is My weights, or Automatic without Pawn: a drop's score is each stat times its weight."))
  local items = {}
  for _, stat in ipairs(St.StatsFor(key, spec.client)) do items[#items + 1] = weightRow(spec, key, stat) end
  items[#items + 1] = importLine(O, spec, key)
  O.RenderGrid(ctx, items)
end

local function undesiredRow(spec, key, choice)
  local get = getter(spec, "undesired")
  return {
    type = "bool", label = choice.label,
    tooltip = word(spec.L, "Never call a drop of this type an upgrade for this specialization."),
    get = function() return St.IsUndesired(get(), key, choice.key) end,
    set = function(v) write(spec, "undesired", St.WithUndesired(get(), key, choice.key, v)) end,
  }
end

local function undesiredBody(O, ctx, spec, key, file)
  note(O, ctx, word(spec.L, "Ticked types are never called an upgrade for this specialization."))
  local items = {}
  for _, choice in ipairs(St.UndesiredChoices(file, spec.client, spec.L)) do
    items[#items + 1] = undesiredRow(spec, key, choice)
  end
  O.RenderGrid(ctx, items)
end

-- The four scalar rows, path-less, read and written through spec.get / spec.set.
local function scoringRows(spec)
  local out = {}
  for _, key in ipairs(St.KEYS) do
    if ROW[key].type ~= "map" then
      local row = baseRow(spec, key)
      row.validate, row.default = nil, nil
      row.get = getter(spec, key)
      row.set = function(v) write(spec, key, v) end
      out[#out + 1] = row
    end
  end
  return out
end

-- Each part's drawer: (O, ctx, spec, file, view, shared).
local PARTS = {}

function PARTS.scoring(O, ctx, spec, _, view, whole)
  view.rows = scoringRows(spec)
  O.RenderRows(ctx, view.rows, nil, nil, { noHeadings = not whole })
end

function PARTS.weights(O, ctx, spec, file, view, whole)
  local tabKey = word(spec.L, "Weights")
  if whole then O.Section(ctx, tabKey) end
  view.spec = specStrip(O, ctx, spec, tabKey, file)
  if view.spec ~= nil then weightsBody(O, ctx, spec, view.spec) end
end

function PARTS.undesired(O, ctx, spec, file, view, whole)
  local tabKey = word(spec.L, "Unwanted types")
  if whole then
    O.Section(ctx, tabKey)
  else
    view.spec = specStrip(O, ctx, spec, tabKey, file)
  end
  if view.spec ~= nil then undesiredBody(O, ctx, spec, view.spec, file) end
end

-- What the section calls on the host's Options instance, each checked before anything is drawn.
local MEMBERS = { "EnsureScroll", "RenderGrid", "RenderRows", "SubTabStrip", "TextRow", "AddSpacer",
  "AttachTooltip", "Section", "RefreshPanel" }

local function usable(O)
  if not isTable(O) or not O.AceGUI then return false end
  for _, member in ipairs(MEMBERS) do
    if type(O[member]) ~= "function" then return false end
  end
  return true
end

--- Draw the section, or one part of it (`tab`: "scoring", "weights" or "undesired"), on the host's
--- Options instance `O` into its page `ctx` (see the header). Answers a view `{ kind, tab, rows,
--- spec }` (the scalar rows drawn, the spec key the editors show), or nil when there is nothing to
--- draw into, `O` lacks a member it calls, or `tab` names no part.
--- @return table|nil view
function St.Section(ctx, O, spec, tab)
  if not isTable(ctx) or not usable(O) then return nil end
  if tab ~= nil and not PARTS[tab] then return nil end
  spec = isTable(spec) and spec or {}
  local scroll = O.EnsureScroll(ctx)
  if not scroll then return nil end
  local view, file = { kind = "options", tab = tab }, classFile(spec)
  if tab then
    PARTS[tab](O, ctx, spec, file, view, false)
  else
    PARTS.scoring(O, ctx, spec, file, view, true)
    PARTS.weights(O, ctx, spec, file, view, true)
    PARTS.undesired(O, ctx, spec, file, view, true)
  end
  if scroll.DoLayout then scroll:DoLayout() end
  return view
end

--- The two editor tabs for the host's RenderTabbedSchema (`opts.tabs`): `{ key, label, render }`
--- each, keyed by its map row's group (Weights, Unwanted types, in the host's words), so the strip
--- keeps one tab per group; each draws its part through Section.
--- @return table tabs
function St.Tabs(O, spec)
  local L = isTable(spec) and spec.L or nil
  local out = {}
  for i, part in ipairs({ { "weights", "Weights" }, { "undesired", "Unwanted types" } }) do
    local label = word(L, part[2])
    out[i] = { key = label, label = label, render = function(ctx) St.Section(ctx, O, spec, part[1]) end }
  end
  return out
end

--- Every word this file draws, for a host's locale (Drop Watcher's keys).
St.WORDS = {}
do
  local seen = {}
  local function add(w) if w and not seen[w] then seen[w] = true; St.WORDS[#St.WORDS + 1] = w end end
  for _, key in ipairs(St.KEYS) do add(ROW[key].label); add(ROW[key].tooltip); add(ROW[key].group) end
  for _, e in ipairs(St.SCORERS) do add(e[2]) end
  for _, k in ipairs({ "empty", "format", "noStats", "noSpec" }) do add(IMPORT_FAIL[k]) end
  for _, e in ipairs(WEAPON_ORDER) do add(e[2]) end
  for _, k in ipairs({ "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY" }) do add(STAT_LABEL[k]) end
  for _, w in ipairs({ "Shields", "Talent tree %d", "Imported %s into %s: %d weights.", "Not scored: %s.",
    "Import a Pawn scale", "Paste a Pawn scale string and press Enter: it replaces this specialization's weights.",
    "What one point of this stat is worth to this specialization. 0 leaves it out.",
    "Used when Score with is My weights, or Automatic without Pawn: a drop's score is each stat times its weight.",
    "Never call a drop of this type an upgrade for this specialization.",
    "Ticked types are never called an upgrade for this specialization." }) do add(w) end
end
