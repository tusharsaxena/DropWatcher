local _, NS = ...
-- settings/SchemaRows.lua — every hand-written schema row of design spec §12.1.
--
-- One row per setting: its stored path, type, label, tooltip, the page and the tab it draws on
-- (design spec §12.2; `group` is the tab, options-ui-§13), its widget hints and the check the write
-- seam runs before storing it. Every `default` references defaults/Profile.lua (savedvariables-§2),
-- never a literal here. The composed Master controls rows are settings/Panel.lua's; these are
-- appended after them, so the General page's `Master controls` tab stays first.
--
-- Two `map` rows, `comparison.weights` and `comparison.undesired`, are whole-value tables keyed by
-- specID (architecture-§5's value route): written whole through the seam, drawn by their own
-- editors (`skipRender`). The window's geometry, its minimized flag and the toast's position have
-- no row: they are named non-setting state (docs/ARCHITECTURE.md -> Settings Schema).

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L
local K        = NS.Constants
local P        = NS.C.PROFILE

local Rows = {}
Settings.Rows = Rows

-- ── the checks ──────────────────────────────────────────────────────────────────────────────

local function isBool(v) return type(v) == "boolean" end

local function inRange(lo, hi)
    return function(v) return type(v) == "number" and v == v and v >= lo and v <= hi end
end

-- A value list in the ordered-array shape the Options dropdown and the Slash parser read.
local function choices(pairs_)
    local out = {}
    for i = 1, #pairs_, 2 do out[#out + 1] = { value = pairs_[i], text = pairs_[i + 1] } end
    return out
end

local function oneOf(list)
    local ok = {}
    for _, e in ipairs(list) do ok[e.value] = true end
    return function(v) return v ~= nil and ok[v] == true end
end

local function nonEmptyString(v) return type(v) == "string" and v:match("%S") ~= nil end

local function isSpecID(k) return type(k) == "number" and k > 0 and k == math.floor(k) end

-- weights: { [specID] = { [STAT_KEY] = number } }.
local function validWeights(v)
    if type(v) ~= "table" then return false end
    for spec, w in pairs(v) do
        if not isSpecID(spec) or type(w) ~= "table" then return false end
        for stat, n in pairs(w) do
            if type(stat) ~= "string" or type(n) ~= "number" or n ~= n then return false end
        end
    end
    return true
end

-- undesired: { [specID] = { ["<classID>:<subClassID>"] = true } }, Evaluate's prefs key.
local function validUndesired(v)
    if type(v) ~= "table" then return false end
    for spec, set in pairs(v) do
        if not isSpecID(spec) or type(set) ~= "table" then return false end
        for key, on in pairs(set) do
            if type(key) ~= "string" or not key:match("^%d+:%d+$") or on ~= true then return false end
        end
    end
    return true
end

-- ── the reactions ───────────────────────────────────────────────────────────────────────────

-- What the open window shows follows the row: its columns, its preset, its Quality label.
local function repaintWindow()
    local W = NS.Window
    if W and W.IsShown and W.IsShown() then W.Refresh() end
end

-- ── the value lists ─────────────────────────────────────────────────────────────────────────

local QUALITY_MODES = choices{
    "fixed", L["Fixed minimum"], "dynamicSlot", L["Match each slot"], "dynamicCharacter", L["Match my gear"],
}
local SITUATION_QUALITY = choices{
    "global", L["Use global"], "fixed", L["Fixed minimum"], "dynamicSlot", L["Match each slot"],
    "dynamicCharacter", L["Match my gear"],
}
local function qualityChoices(from, to)
    local out = {}
    for q = from, to do out[#out + 1] = { value = q, text = NS.QualityGate.QualityName(q) } end
    return out
end
local FIXED_QUALITIES = qualityChoices(K.QUALITY.UNCOMMON, K.QUALITY.LEGENDARY)
local FLOOR_QUALITIES = qualityChoices(K.QUALITY.COMMON, K.QUALITY.EPIC)
-- The View's values as rows: `feed.view.<key>` (modules/WindowFilterBar.lua FB.VIEWS).
local VIEW_ROWS = {
    { key = "interesting", label = L["View: Interesting"],
      tip = L["A fresh tab lists only the drops that are an upgrade for you, or that their looter is likely to give away and can trade."] },
    { key = "likely", label = L["View: Likely tradeable"],
      tip = L["A fresh tab lists only the drops whose trade estimate is yes or likely."] },
    { key = "usable", label = L["View: Usable by me"],
      tip = L["A fresh tab hides the drops you can't use and the item types you marked as unwanted."] },
    { key = "upgrade", label = L["View: Upgrade for me"],
      tip = L["A fresh tab lists only the drops that are an upgrade for you."] },
}
local CONTENTS = choices{ "instance", L["This instance"], "session", L["This session"], "all", L["All"] }
local SORTS    = choices{ "newest", L["Newest"], "oldest", L["Oldest"], "ilvl", L["Item level"], "gain", L["Gain"] }
local ILVL_MODES = choices{ "off", L["Off"], "absolute", L["Absolute"], "relative", L["Relative to my gear"] }
local SCORERS  = choices{ "auto", L["Automatic"], "pawn", L["Pawn"], "weights", L["My weights"], "none", L["None"] }
local CHANNELS = choices{
    "auto", L["Automatic"], "INSTANCE_CHAT", L["Instance"], "RAID", L["Raid"], "PARTY", L["Party"],
}
local RULES = choices{ "personal", L["Personal loot"], "group", L["Group loot"], "legacy", L["Legacy loot"] }

-- ── the dimming predicates ──────────────────────────────────────────────────────────────────

-- A row drawn disabled while it has nothing to do (the library's `disabledIf` predicate form): the
-- value is kept and the CLI still reaches it.
local function unless(path, want)
    return function() return NS.Setting(path) ~= want end
end

local function with(base, fields)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(fields) do out[k] = v end
    return out
end

-- ── the row makers ──────────────────────────────────────────────────────────────────────────

local function add(row)
    Rows[#Rows + 1] = row
    return row
end

local function bool(path, default, label, tip, extra)
    local row = { path = path, type = "bool", default = default, label = label, tooltip = tip,
                  validate = isBool }
    for k, v in pairs(extra or {}) do row[k] = v end
    return add(row)
end

local function pick(path, default, list, label, tip, extra)
    local row = { path = path, type = type(default) == "number" and "number" or "string",
                  default = default, values = list, label = label, tooltip = tip, validate = oneOf(list) }
    for k, v in pairs(extra or {}) do row[k] = v end
    return add(row)
end

local function slider(path, default, lo, hi, step, label, tip, extra)
    local row = { path = path, type = "number", default = default, min = lo, max = hi, step = step,
                  label = label, tooltip = tip, validate = inRange(lo, hi) }
    for k, v in pairs(extra or {}) do row[k] = v end
    return add(row)
end

local function text(path, default, label, tip, extra)
    local row = { path = path, type = "string", default = default, label = label, tooltip = tip,
                  validate = nonEmptyString, wide = true, dialogControl = "EditBox" }
    for k, v in pairs(extra or {}) do row[k] = v end
    return add(row)
end

local function map(path, default, validate, label, tip, extra)
    local row = { path = path, type = "map", default = default, label = label, tooltip = tip,
                  validate = validate, skipRender = true }
    for k, v in pairs(extra or {}) do row[k] = v end
    return add(row)
end

-- ── General › When to show (design spec §6.1) ───────────────────────────────────────────────

local function whenToShow()
    local at = { page = "general", group = L["When to show"] }
    bool("autoOpen", P.autoOpen, L["Auto-open the window"],
        L["Open the window whenever a drop is added to the feed in a situation set to auto-open, your own included. A minimized window stays minimized and counts it. Off, no situation opens it."], at)
    for _, s in ipairs(K.SITUATIONS) do
        local key, d = s.key, P.situations[s.key]
        local base = "situations." .. key .. "."
        local sit = { page = "general", group = L["When to show"], subgroup = NS.WindowFooter.SituationLabel(key) }
        local untracked = unless(base .. "track", true)
        bool(base .. "track", d.track, L["Track"],
            L["Watch the loot in this situation. Off, drops here are ignored and nobody is inspected for them."], sit)
        bool(base .. "autoOpen", d.autoOpen, L["Auto-open"],
            L["Open the window whenever a drop here is added to the feed."],
            with(sit, { disabledIf = function() return untracked() or NS.Setting("autoOpen") ~= true end }))
        pick(base .. "quality", d.quality, SITUATION_QUALITY, L["Quality"],
            L["The minimum quality here: the feed's own mode, or one of its own."],
            with(sit, { disabledIf = untracked }))
    end
end

-- ── Feed › Quality and Filters (design spec §6.2, §6.3) ─────────────────────────────────────

local function feed()
    local F, Q = P.feed, P.feed.quality
    local quality = { page = "feed", group = L["Quality"], onChange = repaintWindow }
    pick("feed.quality.mode", Q.mode, QUALITY_MODES, L["Minimum quality"],
        L["Fixed: one quality for every drop. Match each slot: the quality of what the drop would replace. Match my gear: the quality most of your gear is."], quality)
    pick("feed.quality.fixed", Q.fixed, FIXED_QUALITIES, L["Fixed minimum"],
        L["The least quality a drop needs in the fixed mode."],
        with(quality, { disabledIf = unless("feed.quality.mode", "fixed") }))
    pick("feed.quality.floor", Q.floor, FLOOR_QUALITIES, L["Floor"],
        L["The least quality the two matching modes ever ask for, and what an empty slot asks for."],
        with(quality, { disabledIf = function() return NS.Setting("feed.quality.mode") == "fixed" end }))
    bool("feed.quality.upgradeOverride", Q.upgradeOverride, L["Always show upgrades for me"],
        L["A drop below the minimum still shows when it is an upgrade for you."], quality)

    local filters = { page = "feed", group = L["Filters"] }
    -- The View a fresh tab opens on is a set (feedback-2 spec §1): one row per value, all off is
    -- All. They combine as AND, as the filter bar's multi-select View does.
    for _, v in ipairs(VIEW_ROWS) do
        bool("feed.view." .. v.key, F.view[v.key], v.label, v.tip, filters)
    end
    pick("feed.content", F.content, CONTENTS, L["Content"],
        L["Which drops a fresh tab lists: this instance's, this session's, or all of them."], filters)
    pick("feed.sort", F.sort, SORTS, L["Sort"], L["How a fresh tab sorts its rows."], filters)
    bool("feed.gearOnly", F.gearOnly, L["Gear only"],
        L["List armor, weapons, jewelry and trinkets only."], filters)
    bool("feed.includeTokens", F.includeTokens, L["Tier tokens"],
        L["List tier tokens too."], filters)
    pick("feed.minIlvlMode", F.minIlvlMode, ILVL_MODES, L["Minimum item level"],
        L["Off, absolute (the level below), or relative (how far under your average equipped level a drop may be)."], filters)
    slider("feed.minIlvl", F.minIlvl, 0, 1000, 1, L["Absolute minimum"],
        L["The least item level a drop needs in the absolute mode."],
        with(filters, { disabledIf = unless("feed.minIlvlMode", "absolute") }))
    slider("feed.relativeIlvl", F.relativeIlvl, 0, 100, 1, L["Levels under my average"],
        L["How far under your average equipped item level a drop may be in the relative mode."],
        with(filters, { disabledIf = unless("feed.minIlvlMode", "relative") }))
    bool("feed.showOwn", F.showOwn, L["Show my own loot in Group drops"],
        L["Off, your own loot shows on My drops only."], filters)
    bool("feed.clearOnBossKill", F.clearOnBossKill, L["Clear on boss kill"],
        L["Clear the session's drops when a boss dies."], filters)
end

-- ── Comparison › Scoring, Weights and Preferences (design spec §5) ──────────────────────────

local function comparison()
    local Cm = P.comparison
    local scoring = { page = "comparison", group = L["Scoring"] }
    pick("comparison.scorer", Cm.scorer, SCORERS, L["Score with"],
        L["Automatic uses Pawn once it has loaded and initialized, else your weights, else item level alone."], scoring)
    slider("comparison.sidegradeBand", Cm.sidegradeBand, 0, 20, 1, L["Sidegrade band"],
        L["Item levels either side of equal that still read as a sidegrade."], scoring)
    bool("comparison.compareOwned", Cm.compareOwned, L["Compare against items in my bags"],
        L["Judge a drop against the best of what you wear and what you carry."], scoring)
    bool("comparison.heirloomProtect", Cm.heirloomProtect, L["Protect heirlooms"],
        L["A drop for a slot that holds an heirloom is not called an upgrade."], scoring)
    map("comparison.weights", Cm.weights, validWeights, L["Stat weights"],
        L["Your stat weights for each specialization."], { page = "comparison", group = L["Weights"] })
    map("comparison.undesired", Cm.undesired, validUndesired, L["Unwanted item types"],
        L["The item types each specialization never wants."], { page = "comparison", group = L["Preferences"] })
end

-- ── Trade › Rules and Timers (design spec §7) ───────────────────────────────────────────────

local function trade()
    local T = P.trade
    for _, s in ipairs(K.SITUATIONS) do
        pick("trade.rules." .. s.key, T.rules[s.key], RULES, NS.WindowFooter.SituationLabel(s.key),
            L["The loot rule that decides whether a drop here can be traded."],
            { page = "trade", group = L["Rules"] })
    end
    local timers = { page = "trade", group = L["Timers"] }
    slider("trade.warnAt", T.warnAt, 0, 1800, 60, L["Warn before a trade window closes (seconds)"],
        L["Warn this many seconds before your own item stops being tradeable. 0 turns the warning off."], timers)
end

-- ── Messages › Templates, Sending and Auto-ask (design spec §9) ─────────────────────────────

local function messages()
    local M = P.messages
    local templates = { page = "messages", group = L["Templates"], maxLetters = K.MESSAGE_MAX_LEN }
    text("messages.templates.ask", M.templates.ask, L["Ask"],
        L["What you whisper a looter to ask for their drop."], templates)
    text("messages.templates.transmog", M.templates.transmog, L["Ask for transmog"],
        L["What you whisper a looter to ask for a drop that is no gain for you but whose look you have not collected."], templates)
    text("messages.templates.offer", M.templates.offer, L["Offer"],
        L["What you whisper someone your own drop would help."], templates)
    text("messages.templates.announce", M.templates.announce, L["Announce"],
        L["What you tell the group about a drop you can trade."], templates)

    local sending = { page = "messages", group = L["Sending"] }
    bool("messages.editFirst", M.editFirst, L["Edit before sending"],
        L["Open the message in an edit box before it is sent."], sending)
    bool("messages.transmogAsk", M.transmogAsk, L["Ask for transmog"],
        L["Also offer an ask on a drop that is no gain for you but whose look you have not collected, with the For transmog template."],
        sending)
    bool("messages.oneAsk", M.oneAsk, L["Ask once"],
        L["Send each ask or offer for a drop to a player once."], sending)
    pick("messages.announceChannel", M.announceChannel, CHANNELS, L["Announce channel"],
        L["Automatic picks the instance channel, then raid, then party. Never say or yell."], sending)

    local A = M.autoAsk
    local auto = { page = "messages", group = L["Auto-ask"] }
    local autoOff = with(auto, { disabledIf = unless("messages.autoAsk.enabled", true) })
    -- Turned on, the one-time notice and a fresh start; turned off, the waiting asks go (DW-54).
    bool("messages.autoAsk.enabled", A.enabled, L["Ask automatically"],
        L["Ask for a likely tradeable upgrade for you on your behalf, after a delay."],
        with(auto, { onChange = function(v) NS.AutoAsk.OnEnabledChanged(v) end }))
    slider("messages.autoAsk.delay", A.delay, 3, 30, 1, L["Delay (seconds)"],
        L["How long after the boss kill, or the drop, the ask waits."], autoOff)
    slider("messages.autoAsk.minGain", A.minGain, 1, 50, 1, L["Least gain (item levels)"],
        L["The least item-level gain for you an automatic ask needs."], autoOff)
end

-- ── Window › Columns, Layout and Toast (design spec §11) ────────────────────────────────────

local function window()
    local W = P.window
    local columns = { page = "window", group = L["Columns"], onChange = repaintWindow }
    for _, col in ipairs(NS.WindowGroup.COLUMNS) do
        if col.key ~= "item" then
            bool("window.columns." .. col.key, W.columns[col.key], col.label, col.tip, columns)
        end
    end
    local layout = { page = "window", group = L["Layout"], onChange = repaintWindow }
    bool("window.compact", W.compact, L["Compact"],
        L["Show Item and looter, Ilvl, Their eq, Me and Ask only."], layout)
    slider("window.rowHeight", W.rowHeight, 18, 40, 1, L["Row height"], L["The height of one row in the Group drops table."], layout)
    slider("window.fontSize", W.fontSize, 8, 20, 1, L["Font size"], L["The size of the Group drops table's text."], layout)

    local T = P.toast
    local toast = { page = "window", group = L["Toast"] }
    -- Turned off, the toast on screen goes and the queue empties (DW-62 review F-004).
    bool("toast.enabled", T.enabled, L["Show a toast"],
        L["Pop up a toast for a likely tradeable upgrade for you."],
        with(toast, { onChange = function(v) NS.Toast.OnEnabledChanged(v) end }))
    toast = with(toast, { disabledIf = unless("toast.enabled", true) })
    slider("toast.minGain", T.minGain, 1, 50, 1, L["Least gain (item levels)"],
        L["The least item-level gain for you a toast needs."], toast)
    slider("toast.duration", T.duration, 2, 30, 1, L["Duration (seconds)"],
        L["How long a toast stays on screen."], toast)
    bool("toast.inCombat", T.inCombat, L["Show in combat"], L["Show toasts in combat too."], toast)
    bool("toast.sound", T.sound, L["Play a sound"], L["Play a sound with each toast."], toast)
end

-- ── History (feedback-2 spec §5): kept by days, account-wide ────────────────────────────────

local function history()
    local row = pick(Settings.HISTORY_RETENTION_PATH, NS.C.GLOBAL_DEFAULTS.history.retentionDays,
        NS.HistoryRetention.Choices(), L["Keep history for"],
        L["How long the History tab keeps a group (an encounter or a run) after its last drop, on every character. A shorter time that would delete groups asks first."],
        { page = "window", group = L["Layout"], onChange = function(v)
            -- A shorter window that would delete something asks first (modules/HistoryRetention.lua).
            NS.HistoryRetention.OnChanged(v)
        end })
    Settings.StampClosureRows({ row })
end

whenToShow()
feed()
comparison()
trade()
messages()
window()
history()

NS.SchemaRuntime.AddRows(Rows)
