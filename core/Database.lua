local _, NS = ...
-- core/Database.lua — the schemaVersion migration runner (savedvariables-§1).
--
-- The defaults tree is built by settings/Schema.lua's Settings.BuildDefaults (profile rows from the
-- schema, plus defaults/Profile.lua's tables) and handed to AceDB in OnInitialize, which runs this
-- runner straight after AceDB:New, before anything reads db.profile, and again from every profile
-- callback. global.schemaVersion defaults to 0, never the current version: AceDB strips a value
-- equal to its default at logout and would backfill it onto a legacy account.
--
-- The runner owns the stamp: it advances it to a step's `to` only after that step returned, so a
-- step that raises is retried on the next load. A `perProfile` step runs for EVERY stored profile
-- (the raw SavedVariables `profiles` table), not only the active one. Each step is idempotent
-- against a fresh default profile.

-- ── step 2: the settings rows (DW-40) ───────────────────────────────────────────────────────

-- The Lua type each declared row type stores.
local STORED_TYPE = { bool = "boolean", number = "number", string = "string", map = "table" }

-- Whether `row` refuses the stored `v`: the wrong type, or its own check says no.
local function refuses(row, v)
    local want = STORED_TYPE[row.type]
    if want and type(v) ~= want then return true end
    if type(row.validate) ~= "function" then return false end
    local ok, pass = pcall(row.validate, v)
    return not (ok and pass)
end

-- Clears one row's stored leaf in a raw profile when the row refuses it; answers 1 when it did.
local function repairLeaf(profile, row)
    local parts = {}
    for seg in row.path:gmatch("[^.]+") do parts[#parts + 1] = seg end
    local node = profile
    for i = 1, #parts - 1 do
        node = node[parts[i]]
        if type(node) ~= "table" then return 0 end
    end
    local leaf = parts[#parts]
    local v = node[leaf]
    if v == nil or not refuses(row, v) then return 0 end
    node[leaf] = nil
    return 1
end

-- The rows whose storage is a profile path: not session-only, no closure of their own.
local function profileRows()
    local S = NS.addon and NS.addon.Settings
    local out = {}
    for _, row in ipairs(S and S.Schema or {}) do
        if type(row) == "table" and type(row.path) == "string" and not row.sessionOnly
            and type(row.set) ~= "function" then
            out[#out + 1] = row
        end
    end
    return out
end

--- Step 2's work on one stored profile. Before the settings rows existed, a few paths were written
--- straight onto the profile (`feed.quality.mode`, `window.compact`) and others were read with
--- forgiving fallbacks (`trade.rules`, `messages.*`, `situations.*`): a stored value the row now
--- refuses is dropped, so the default shows and the next write goes through the seam's checks. A
--- valid value, and every default, passes through unchanged.
--- @param profile table a raw stored profile
--- @return number the leaves cleared
function NS.RepairStoredSettings(profile)
    if type(profile) ~= "table" then return 0 end
    local cleared = 0
    for _, row in ipairs(profileRows()) do cleared = cleared + repairLeaf(profile, row) end
    return cleared
end

-- ── step 3: the View becomes a set (DW-A1, feedback-2 spec §1) ──────────────────────────────

-- The three filter bar checkboxes that became View values: where each was stored, and its value.
local FOLDED = {
    { parent = "trade", leaf = "likelyOnly", view = "likely" },
    { parent = "feed", leaf = "usableOnly", view = "usable" },
    { parent = "feed", leaf = "upgradeOnly", view = "upgrade" },
}

-- The set an old `feed.view` string stands for. AceDB strips a value equal to its default at
-- logout, so a stored `interesting` (the old default) is rare: kept when it is there, and a profile
-- that only inherited the old default stores nothing and opens on the new one, All.
local function viewFrom(old)
    if type(old) == "table" then return old end
    return old == "interesting" and { interesting = true } or {}
end

-- Moves each folded checkbox that was on into the set, and drops its old leaf.
local function foldChecks(profile, set)
    for _, f in ipairs(FOLDED) do
        local parent = profile[f.parent]
        if type(parent) == "table" then
            if parent[f.leaf] == true then set[f.view] = true end
            parent[f.leaf] = nil
        end
    end
end

--- Step 3's work on one stored profile: `feed.view` becomes a set ({ [value] = true }), and
--- `trade.likelyOnly`, `feed.usableOnly` and `feed.upgradeOnly` fold into it, so each player keeps
--- the choices they had. Idempotent: a profile already in the new shape passes through.
--- @param profile table a raw stored profile
function NS.MigrateViewSet(profile)
    if type(profile) ~= "table" then return end
    local feed = type(profile.feed) == "table" and profile.feed or nil
    local set = viewFrom(feed and feed.view)
    foldChecks(profile, set)
    if next(set) == nil then
        if feed and type(feed.view) ~= "table" then feed.view = nil end
        return
    end
    profile.feed = feed or {}
    profile.feed.view = set
end

--- Step 4's work: the History's group cap, `global.history.maxGroups`, is retired (feedback-2 spec
--- §5: the History is kept by days now). Only the key goes; nothing is pruned here.
--- @param sv table|nil the raw SavedVariables
function NS.RetireHistoryCap(sv)
    local g = type(sv) == "table" and sv.global
    local h = type(g) == "table" and g.history
    if type(h) == "table" then h.maxGroups = nil end
end

-- ── step 5: compact mode (DW-C0, compact spec §1) ───────────────────────────────────────────

-- The geometry the single-layout window stored straight on `window`, now the full layout's.
local GEOMETRY_KEYS = { "point", "width", "height" }

-- Moves `window.point`, `width` and `height` into `window.geometry.full`, keeping any value
-- already there.
local function moveGeometry(w)
    local full
    for _, k in ipairs(GEOMETRY_KEYS) do
        if w[k] ~= nil then
            if type(w.geometry) ~= "table" then w.geometry = {} end
            full = full or (type(w.geometry.full) == "table" and w.geometry.full) or {}
            if full[k] == nil then full[k] = w[k] end
            w[k] = nil
        end
    end
    if full then w.geometry.full = full end
end

--- Step 5's work on one stored profile: the retired compact preset (`window.compact = true`)
--- becomes the compact layout (`window.mode = "compact"`) and its key goes; the window's single
--- geometry becomes the full layout's (`window.geometry.full`). The preset decides the layout even
--- over a `mode` already there: AceDB's defaults can answer `full` for a key the player never set,
--- and a profile that held the preset never chose a layout. Idempotent: the preset's key goes, so a
--- profile already in the new shape passes through.
--- @param profile table a raw stored profile
function NS.MigrateWindowMode(profile)
    local w = type(profile) == "table" and profile.window
    if type(w) ~= "table" then return end
    if w.compact == true then w.mode = "compact" end
    w.compact = nil
    moveGeometry(w)
end

-- ── step 6: own drops always listed (DW-E2, feedback-5 spec §2) ─────────────────────────────

--- Step 6's work on one stored profile: `feed.showOwn` (Show my own loot in Group drops) is retired,
--- since Drops always lists your own drops; only the key goes.
--- @param profile table a raw stored profile
function NS.RetireShowOwn(profile)
    local feed = type(profile) == "table" and profile.feed
    if type(feed) == "table" then feed.showOwn = nil end
end

-- ── step 7: My eq and Their eq merged into Me and Them (DW-F1, feedback-6 spec §1) ──────────

--- Step 7's work on one stored profile: the `window.columns` toggles `myEq` and `theirEq` are
--- retired, since the worn gear now shows in the Me and Them cells (which `me` and `them` toggle);
--- only the two keys go.
--- @param profile table a raw stored profile
function NS.RetireEqColumns(profile)
    local w = type(profile) == "table" and profile.window
    local cols = type(w) == "table" and w.columns
    if type(cols) == "table" then cols.myEq, cols.theirEq = nil, nil end
end

-- ── step 8: Content: All is History's alone (DW-Q1, feedback-15 spec §1) ────────────────────

--- Step 8's work on one stored profile: `feed.content` no longer offers `all` (the Drops tab holds
--- this session's drops alone; History opens on All by itself), so a stored `all` becomes
--- `session`, the row's default. Idempotent: anything else passes through.
--- @param profile table a raw stored profile
function NS.MigrateContentAll(profile)
    local feed = type(profile) == "table" and profile.feed
    if type(feed) == "table" and feed.content == "all" then feed.content = "session" end
end

-- ── step 9: the simulation panel's position is session-only (DW-04, LibKa0s#54) ─────────────

--- Step 9's work on one stored profile: `simPanel` (the dragged simulation panel's point) is
--- retired. It was window state absent from defaults, written only by DropWatcher's own panel,
--- which LibKa0s-Sim-1.0's replaced; that panel holds a dragged point for the session alone
--- (OWNER_SCOPE C.11), so a simulation writes nothing to SavedVariables. Idempotent: only the key
--- goes.
--- @param profile table a raw stored profile
function NS.RetireSimPanelPoint(profile)
    if type(profile) == "table" and profile.simPanel ~= nil then profile.simPanel = nil end
end

-- ── step 10: the item icon's border follows the skin, once (DW-03, the rollout's O2) ─────────

-- The one key the reset puts back on the skin: the border's style, whose companion
-- (`icons.borderStyleFromSkin`, the composer's `fromSkin = "icon"`) governs the thickness too. Only
-- that (the rollout's X4): the color stays the player's, `borderSize` would take the FROM_SKIN
-- sentinel into a number row, and `borderShow` (a bool) would be switched ON.
NS.HUD_SKIN_KEYS = { "borderStyle" }

--- Step 10's work on one stored profile (Ka0sAddonsCommonTasks docs/2026-10-29-SKINNING_ROLLOUT,
--- the owner's O2, skinning-§6): every player meets the icon border's skin once per profile.
--- LibKa0s-Skin-1.0's `ResetToSkin` turns the companion on and leaves the stored pick where it was,
--- so turning the companion off later brings the player's own style straight back; the stamp the
--- runner writes after it is what keeps that later "off" from being stomped at the next login.
--- AceDB strips a value equal to its default from the stored table, so the companion may be absent;
--- `{ companions = true }` (Skin minor 8, LibKa0s v1.81.0) sets every listed pick's companion,
--- stored or not, so the reset always lands on the companion, never the FROM_SKIN sentinel in the
--- LSM key. A profile that never stored `icons` keeps the defaults, whose companion is already TRUE
--- (X3). Without the library the companion is set directly, which is what ResetToSkin does.
--- Idempotent.
--- @param profile table a raw stored profile
function NS.ResetIconBorderToSkin(profile)
    local icons = type(profile) == "table" and profile.icons
    if type(icons) ~= "table" then return end
    local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    if Skin and type(Skin.ResetToSkin) == "function" then
        Skin.ResetToSkin(icons, NS.HUD_SKIN_KEYS, { companions = true })
    else
        for _, key in ipairs(NS.HUD_SKIN_KEYS) do icons[key .. "FromSkin"] = true end
    end
end

-- ── step 11: everything the skin can draw follows it, once (FS-DW-FLIP) ─────────────────────

-- Every companion by name, dotted from the profile root, and the one flags key whose reader is on
-- S.FontFlags (modules/WindowRows.lua). Never a stored color or pick, a class or quality color's
-- toggle, or font size: those stay exactly as stored, for a player who turns a companion off.
NS.FULL_SKIN_KEYS = {
    "window.tableFontFromSkin", "window.tableFontShadowFromSkin", "window.tableFontFlags",
    "icons.borderStyleFromSkin", "icons.borderColorFromSkin",
    "glow.main.colorFromSkin",
}
-- The off-spec glow is Retail's alone (C.FEATURE.offSpec, Forever port design §4.4): on WoW Forever
-- the walk never writes a table its profile has no default for.
if NS.Constants.FEATURE.offSpec then NS.FULL_SKIN_KEYS[#NS.FULL_SKIN_KEYS + 1] = "glow.offSpec.colorFromSkin" end

--- The hand-written walk, for the no-Skin-major arm only: the listed keys' same write. A path through
--- a missing table is skipped, and no table is made on the way.
local function followByHand(profile)
    for _, path in ipairs(NS.FULL_SKIN_KEYS) do
        local node, leaf = profile, nil
        for seg, rest in path:gmatch("([^.]+)(%.?)") do
            if rest == "" then leaf = seg
            else
                node = type(node) == "table" and node[seg] or nil
            end
        end
        if type(node) == "table" then
            node[leaf] = leaf:match("FromSkin$") and true or "@skin"
        end
    end
end

--- Step 11's work on one profile (the owner's rulings of 2026-11-01: existing profiles follow the
--- skin). The account's stamp cannot say which profiles went through it and following the skin leaves
--- no shape to read, so the profile keeps its own record, `skin.fullSkinReset`, through
--- Skin.FollowOnce; it runs from the ladder and after it on every load and profile event, so a
--- profile that arrives with no record takes it and a companion turned off afterwards stays off. A
--- profile reset runs it again against defaults, which shows nothing. Answers true when it ran.
--- @param profile table a stored profile
--- @return boolean
function NS.ResetProfileToSkin(profile)
    if type(profile) ~= "table" then return false end
    local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    if Skin and type(Skin.FollowOnce) == "function" then
        return Skin.FollowOnce(profile, NS.FULL_SKIN_KEYS)
    end
    if type(profile.skin) == "table" and profile.skin.fullSkinReset == true then return false end
    followByHand(profile)
    if type(profile.skin) ~= "table" then profile.skin = {} end
    profile.skin.fullSkinReset = true
    return true
end

-- ── step 12: the deleted Friz becomes Ka0s Ubuntu (R3-FRIZ) ─────────────────────────────────
--
-- LibKa0s v1.85.0 deleted Ka0s Friz Quadrata TT (R3-L7) and WoW Default draws Ka0s Ubuntu in its place
-- (R3-L6). Every stored string naming the deleted face, at any depth (the table font, the skin's Font
-- override), moves to its successor. Blizzard's own "Friz Quadrata TT" is another key and stays.
local RETIRED_FONTS = { ["Ka0s Friz Quadrata TT"] = "Ka0s Ubuntu" }

--- Moves every string naming a retired face, at any depth of `t`, to its successor. Answers how many moved.
function NS.RetireFonts(t)
    local n = 0
    for k, v in pairs(t) do
        if type(v) == "table" then
            n = n + NS.RetireFonts(v)
        elseif RETIRED_FONTS[v] then
            t[k], n = RETIRED_FONTS[v], n + 1
        end
    end
    return n
end

-- ── step 13: Gear only and Include tier tokens become the item kinds (DW-CAT2, issue #13) ────

-- Frozen: the categories as of step 13. A category added later is not turned on by this step.
local STEP13_CATEGORIES = { "equipment", "tierToken", "mount", "pet", "toy", "recipe", "cosmetic" }

--- Step 13's work on one stored profile (categories design spec §5.2): `feed.gearOnly` and
--- `feed.includeTokens` are replaced by the `feed.categories.<key>` rows. A stored `gearOnly =
--- false` (every item class let through) turns every category on, cosmetics too (the owner's call:
--- every category on); a stored `includeTokens` then carries into the Tier tokens kind, so a stored
--- `false` still turns tokens off. Both keys go. Idempotent; a fresh profile, which stores neither
--- (AceDB strips a default), passes through unchanged.
--- @param profile table a raw stored profile
function NS.MigrateItemKinds(profile)
    local feed = type(profile) == "table" and profile.feed
    if type(feed) ~= "table" then return end
    local cats = type(feed.categories) == "table" and feed.categories or {}
    if feed.gearOnly == false then
        for _, key in ipairs(STEP13_CATEGORIES) do cats[key] = true end
    end
    if feed.includeTokens ~= nil then cats.tierToken = feed.includeTokens == true end
    if next(cats) then feed.categories = cats end
    feed.gearOnly, feed.includeTokens = nil, nil
end

-- ── step 14: a picked table text color keeps drawing (SD-RV-DW, LibKa0s v1.108.0) ──────────

-- The channels compared against the swatch's default, as modules/WindowRows.lua compared them before.
local TABLE_COLOR_CHANNELS = { "r", "g", "b", "a" }

--- Step 14's work on one stored profile. LibKa0s v1.108.0's composer gives Window › Layout ›
--- Tables' Font color its Use the skin's color companion, `window.tableFontColorFromSkin`, on by
--- default (OptionsCompose minor 20; skinning-§9, Every option default follows the skin, the owner's
--- R-2). Until then the swatch at its default stood for the skin's color and any other value was a
--- pick, so a profile that stored a pick gets the companion off, once, and its pick still draws; a
--- profile at the default, or with no stored swatch, keeps the new default and follows the skin. A
--- channel AceDB stripped as equal to its default reads as the default. Nothing else is written. No
--- profile stored the companion before this step (it had no row), and AceDB has already copied its
--- default into the active profile, so a stored companion is not read: the runner's stamp is what
--- keeps a companion the player turns on later from being turned off again. Idempotent.
--- @param profile table a raw stored profile
function NS.KeepTableFontColorPick(profile)
    local w = type(profile) == "table" and profile.window
    local stored = type(w) == "table" and w.tableFontColor
    if type(stored) ~= "table" then return end
    local default = NS.C.PROFILE.window.tableFontColor
    for _, k in ipairs(TABLE_COLOR_CHANNELS) do
        local v = tonumber(stored[k])
        if v ~= nil and math.abs(v - default[k]) > 0.002 then
            w.tableFontColorFromSkin = false
            return
        end
    end
end

-- ── step 15: the detail card's Sources chip is retired (IS-DW-07, Item Search spec §4.8) ─────

--- Step 15's work on one stored profile: SF-DW-01's Show where it comes from switch
--- (`window.itemSources`, WoW Forever's alone) goes with the chip, which Item Search replaced
--- (DropWatcher#17). Nothing else is written; a Retail profile, which never stored it, passes
--- through unchanged. Idempotent.
--- @param profile table a raw stored profile
function NS.RetireItemSources(profile)
    local w = type(profile) == "table" and profile.window
    if type(w) == "table" then w.itemSources = nil end
end

-- ── step 16: the tooltip's rows per section (ISF-DW-03, Item Search feedback spec §7) ──────

local STEP16_ROWS = 5

--- Step 16's work on one stored profile: the drops-only `itemSearch.tooltip.dropsShown` (1 to 10)
--- becomes `itemSearch.tooltip.rows` (every section's cap, 1 to 20). A stored count is carried
--- across, whole and in range, unless the profile already stores a `rows` of its own (one off the
--- default); the old key goes either way. A profile that never stored it (the default, 3) takes the
--- new default, 5. Idempotent. STEP16_ROWS is the default as of this step (frozen): a `rows` equal
--- to it may be AceDB's default read through, never the player's choice beside a stored dropsShown.
--- @param profile table a raw stored profile
function NS.MigrateTipRows(profile)
    local is = type(profile) == "table" and profile.itemSearch
    local tip = type(is) == "table" and is.tooltip
    if type(tip) ~= "table" or tip.dropsShown == nil then return end
    local v = tonumber(tip.dropsShown)
    if (tip.rows == nil or tip.rows == STEP16_ROWS) and v then tip.rows = math.max(1, math.min(20, math.floor(v))) end
    tip.dropsShown = nil
end

-- ── step 17: the Item Search window's retired rows (ISF-DW-05, Item Search feedback spec §5) ──

-- The window's rows that went with ISF-DW-05: the recent searches' switch (§5.2, W4), and the
-- window's own density, font size and zone-and-level-columns switch, which the window no longer
-- reads (§5.1: every text takes the main window's table font and row height; §5.4: every tab draws
-- all its columns, so no switch sheds one).
local STEP17_WINDOW_KEYS = { "recent", "density", "fontSize", "columns" }

--- Step 17's work: every stored profile's retired Item Search window rows, and the account-wide
--- recent searches (`global.itemSearch.recent`, the list W4 removed). The lock had no stored value
--- of the window's own (it read the main window's shared `locked`, which stays), so nothing of it is
--- deleted. A Retail account, which never stored any of it, passes through unchanged. Idempotent.
--- @param sv table the raw SavedVariables table
function NS.RetireItemSearchRows(sv)
    if type(sv) ~= "table" then return end
    local g = sv.global
    local gi = type(g) == "table" and g.itemSearch
    if type(gi) == "table" then
        gi.recent = nil
        if next(gi) == nil then g.itemSearch = nil end
    end
    for _, profile in pairs(type(sv.profiles) == "table" and sv.profiles or {}) do
        local is = type(profile) == "table" and profile.itemSearch
        local w = type(is) == "table" and is.window
        if type(w) == "table" then
            for _, k in ipairs(STEP17_WINDOW_KEYS) do w[k] = nil end
        end
    end
end

-- ── step 18: the tooltip's Gathered from section (ISR3-DW-03, Item Search round 3 spec §5) ──

--- Step 18's work on one stored profile: a stored tooltip section order (`itemSearch.tooltip.order`,
--- written whole by the page's drag list) that lacks the new "gathered" section gets it right after
--- "drops", or at the end when "drops" is not in it. A profile with no stored order reads the new
--- default, which has it, and is not written. Nothing else changes. Idempotent.
--- @param profile table a raw stored profile
function NS.MigrateGatheredSection(profile)
    local is = type(profile) == "table" and profile.itemSearch
    local tip = type(is) == "table" and is.tooltip
    local order = type(tip) == "table" and tip.order
    if type(order) ~= "table" then return end
    local at
    for i, key in ipairs(order) do
        if key == "gathered" then return end
        if key == "drops" then at = i end
    end
    table.insert(order, (at or #order) + 1, "gathered")
end

-- ── the steps ───────────────────────────────────────────────────────────────────────────────

NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself; nothing to reshape
    { to = 2, perProfile = true,         -- 1 -> 2: every setting has a row; drop what it refuses
      run = function(_, profile) NS.RepairStoredSettings(profile) end },
    { to = 3, perProfile = true,         -- 2 -> 3: the View is a set; its checkboxes fold into it
      run = function(_, profile) NS.MigrateViewSet(profile) end },
    { to = 4, run = function(sv) NS.RetireHistoryCap(sv) end },   -- 3 -> 4: History by days
    { to = 5, perProfile = true,         -- 4 -> 5: compact mode; the window's geometry per layout
      run = function(_, profile) NS.MigrateWindowMode(profile) end },
    { to = 6, perProfile = true,         -- 5 -> 6: own drops always listed; their switch goes
      run = function(_, profile) NS.RetireShowOwn(profile) end },
    { to = 7, perProfile = true,         -- 6 -> 7: the eq columns merged into Me and Them; toggles go
      run = function(_, profile) NS.RetireEqColumns(profile) end },
    { to = 8, perProfile = true,         -- 7 -> 8: Content: All is History's alone; a stored one is session
      run = function(_, profile) NS.MigrateContentAll(profile) end },
    { to = 9, perProfile = true,         -- 8 -> 9: the simulation panel's position is session-only
      run = function(_, profile) NS.RetireSimPanelPoint(profile) end },
    { to = 10, perProfile = true,        -- 9 -> 10: the icon border follows the skin, once (O2)
      run = function(_, profile) NS.ResetIconBorderToSkin(profile) end },
    { to = 11, perProfile = true,        -- 10 -> 11: the border's color, the glows and the shadow too
      run = function(_, profile) NS.ResetProfileToSkin(profile) end },
    { to = 12, perProfile = true,        -- 11 -> 12: a stored Ka0s Friz Quadrata TT becomes Ka0s Ubuntu
      run = function(_, profile) NS.RetireFonts(profile) end },
    { to = 13, perProfile = true,        -- 12 -> 13: Gear only and Include tier tokens become the item kinds
      run = function(_, profile) NS.MigrateItemKinds(profile) end },
    { to = 14, perProfile = true,        -- 13 -> 14: a picked table text color keeps drawing under its companion
      run = function(_, profile) NS.KeepTableFontColorPick(profile) end },
    { to = 15, perProfile = true,        -- 14 -> 15: the detail card's Sources chip goes; its switch too
      run = function(_, profile) NS.RetireItemSources(profile) end },
    { to = 16, perProfile = true,        -- 15 -> 16: the tooltip's drop count becomes its rows per section
      run = function(_, profile) NS.MigrateTipRows(profile) end },
    { to = 17, run = function(sv) NS.RetireItemSearchRows(sv) end },   -- 16 -> 17: Item Search's retired rows
    { to = 18, perProfile = true,        -- 17 -> 18: a stored tooltip section order gains Gathered from
      run = function(_, profile) NS.MigrateGatheredSection(profile) end },
}

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = NS.MIGRATIONS[#NS.MIGRATIONS].to

local function runStep(db, step)
    local sv = db.sv
    if not step.perProfile then return step.run(sv) end
    local profiles = type(sv) == "table" and sv.profiles
    for _, profile in pairs(type(profiles) == "table" and profiles or {}) do
        if type(profile) == "table" then step.run(sv, profile) end
    end
end

function NS:RunMigrations()
    local db = self.db
    local g = db and db.global
    if not g then return end
    local from = g.schemaVersion or 0
    for _, step in ipairs(NS.MIGRATIONS) do
        if (g.schemaVersion or 0) < step.to then
            runStep(db, step)
            g.schemaVersion = step.to   -- the runner owns the stamp; reached only if the step returned
        end
    end
    local D = NS.DebugLog
    if from ~= g.schemaVersion and D and D.DebugAtEnable then
        D.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
    -- Past the ladder, step 11's record still answers for the active profile: one that arrived with
    -- no record, restored from a backup or new since the stamp moved.
    NS.ResetProfileToSkin(db.profile)
end
