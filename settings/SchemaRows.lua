local _, NS = ...
-- settings/SchemaRows.lua — every hand-written schema row of design spec §12.1.
--
-- One row per setting: its stored path, type, label, tooltip, the page and the tab it draws on
-- (design spec §12.2; `group` is the tab, options-ui-§13), its widget hints and the check the write
-- seam runs before storing it. Every `default` references defaults/Profile.lua (savedvariables-§2),
-- never a literal here. The composed Master controls rows are settings/Panel.lua's; these are
-- appended after them, so the General page's `Master controls` tab stays first. Within a page, a
-- tab's place in the strip is its first row's place here, so the makers below run in page order
-- (feedback-24 regrouped the pages; item 020 folded Situations into Drops: Drops, Comparison,
-- Messages, Window, Alerts).
-- Window › Icons' composed border block is settings/ComposedRows.lua's, appended after these (it
-- needs the Options instance, made after this file), so it follows this file's Zoom row on that
-- tab; it takes this file's checks from Settings.Checks.
--
-- Two `map` rows, `comparison.weights` and `comparison.undesired`, are whole-value tables keyed by
-- specID (architecture-§5's value route): written whole through the seam, drawn by their own
-- editors (`skipRender`). Drops › Situations' per-situation rows (`situations.<key>.track`,
-- `.autoOpen`, `.quality` and `trade.rules.<key>`) are `skipRender` too: its table draws them, one
-- line per situation. The window's geometry, its minimized flag and the toast's position have no
-- row: they are named non-setting state (docs/schema.md -> State written outside the seam). Alerts › Upgrade glow's
-- `glow.<main|offSpec>.color` rows are typed `color`, stored {r=,g=,b=,a=} (the library's codec).

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

local function unit(n) return type(n) == "number" and n == n and n >= 0 and n <= 1 end

-- A color in the library's default {r=,g=,b=,a=} shape, each channel 0 to 1 (alpha optional).
local function isColor(v)
    return type(v) == "table" and unit(v.r) and unit(v.g) and unit(v.b) and (v.a == nil or unit(v.a))
end

local function isSpecID(k) return type(k) == "number" and k > 0 and k == math.floor(k) end

-- The checks a composed block's rows take too (settings/ComposedRows.lua): the composer emits none.
Settings.Checks = { isBool = isBool, inRange = inRange, nonEmptyString = nonEmptyString, isColor = isColor }

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

-- What the open window shows follows the row: its columns, its layout, its Quality label.
local function repaintWindow()
    local W = NS.Window
    if W and W.IsShown and W.IsShown() then W.Refresh() end
end
Settings.RepaintWindow = repaintWindow   -- settings/ComposedRows.lua's tables font block too

-- A glow row repaints every glowing icon: the window's surfaces (modules/Glow.lua).
local function refreshGlow()
    local G = NS.Glow
    if G and G.Refresh then G.Refresh() end
end

-- A Window › Icons row gives every item icon its new look (modules/IconStyle.lua).
local function refreshIcons()
    local IS = NS.IconStyle
    if IS and IS.Refresh then IS.Refresh() end
end
Settings.RefreshIcons = refreshIcons

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
-- The View's values as rows: `feed.view.<key>` (modules/WindowFilterBar.lua FB.VIEWS), each labeled
-- by its value alone under Window › Starting view's View subsection (feedback-24).
local VIEW_ROWS = {
    { key = "interesting", label = L["Interesting"],
      tip = L["A fresh tab lists only the drops that are an upgrade for you, or that their looter is likely to give away and can trade. With none ticked, a fresh tab lists every drop."] },
    { key = "likely", label = L["Likely tradeable"],
      tip = L["A fresh tab lists only the drops whose trade estimate is yes or likely. With none ticked, a fresh tab lists every drop."] },
    { key = "usable", label = L["Usable by me"],
      tip = L["A fresh tab hides the drops you can't use and the item types you marked as unwanted. With none ticked, a fresh tab lists every drop."] },
    { key = "upgrade", label = L["Upgrade for me"],
      tip = L["A fresh tab lists only the drops that are an upgrade for you. With none ticked, a fresh tab lists every drop."] },
}
-- Drops' Content values (feedback-15 spec §1): History's All is no Drops value, so no seed.
local CONTENTS = choices{ "instance", L["This instance"], "session", L["This session"] }
local SORTS    = choices{ "newest", L["Newest"], "oldest", L["Oldest"], "ilvl", L["Item level"], "gain", L["Gain"] }
local ILVL_MODES = choices{ "off", L["Off"], "absolute", L["Absolute"], "relative", L["Relative to my gear"] }
local SCORERS  = choices{ "auto", L["Automatic"], "pawn", L["Pawn"], "weights", L["My weights"], "none", L["None"] }
local CHANNELS = choices{
    "auto", L["Automatic"], "INSTANCE_CHAT", L["Instance"], "RAID", L["Raid"], "PARTY", L["Party"],
}
local LAYOUTS = choices{ "full", L["Full"], "compact", L["Compact"] }
local RULES = choices{ "personal", L["Personal loot"], "group", L["Group loot"], "legacy", L["Legacy loot"] }
-- LibCustomGlow-1.0's four effects, named as KickCD's glow style dropdown names them, in the order
-- the Upgrade glow tab's style subsections read (Pixel border first, feedback-24; the default is
-- Proc since DW-03, D-18, and the order did not move).
local GLOW_STYLES = choices{
    "pixel", L["Pixel border"], "autocast", L["Auto cast sparkles"], "button", L["Button (rotating rays)"],
    "proc", L["Proc (flipbook)"],
}

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

-- ── Drops › Situations (design spec §6.1, §7; feedback-24, item 020) ───────────────────────

-- Everything set per situation, on one tab: the global Auto-open, then a table line per situation
-- (Track, Auto-open, Quality and its loot rule). General › When to show and Trade › Rules until
-- feedback-24; its own Situations page until item 020, which made it the Drops page's first tab (it
-- runs before feed(), so it lands first in the strip).
local function situations()
    local at = { page = "feed", group = L["Situations"] }
    bool("autoOpen", P.autoOpen, L["Auto-open the window"],
        L["Open the window whenever a drop is added to the feed in a situation set to auto-open, your own included. A minimized window stays minimized and counts it. Off, no situation opens it."], at)
    local T = P.trade
    for _, s in ipairs(K.SITUATIONS) do
        local key, d = s.key, P.situations[s.key]
        local base = "situations." .. key .. "."
        -- Drawn by the Situations table (settings/PageEditors.lua SituationTable), one table row per
        -- situation: still schema rows, so the CLI, the resets and profiles reach them as before.
        local sit = { page = "feed", group = L["Situations"], skipRender = true }
        local untracked = unless(base .. "track", true)
        bool(base .. "track", d.track, L["Track"],
            L["Watch the loot in this situation. Off, drops here are ignored and nobody is inspected for them."], sit)
        bool(base .. "autoOpen", d.autoOpen, L["Auto-open"],
            L["Open the window whenever a drop here is added to the feed."],
            with(sit, { disabledIf = function() return untracked() or NS.Setting("autoOpen") ~= true end }))
        pick(base .. "quality", d.quality, SITUATION_QUALITY, L["Quality"],
            L["The minimum quality here: the feed's own mode, or one of its own."],
            with(sit, { disabledIf = untracked }))
        -- Its label stays the situation's name: `/dw list` reads it under the Drops page's `feed` section.
        pick("trade.rules." .. key, T.rules[key], RULES, NS.WindowFooter.SituationLabel(key),
            L["The loot rule that decides whether a drop here can be traded."],
            with(sit, { disabledIf = untracked }))
    end
end

-- ── History (feedback-2 spec §5): kept by days, account-wide ────────────────────────────────

local function history(at)
    local row = pick(Settings.HISTORY_RETENTION_PATH, NS.C.GLOBAL_DEFAULTS.history.retentionDays,
        NS.HistoryRetention.Choices(), L["Keep history for"],
        L["Account-wide: shared by every profile. How long the History tab keeps a group (an encounter or a run) after its last drop, on every character. A shorter time that would delete groups asks first."],
        with(at, { onChange = function(v)
            -- A shorter window that would delete something asks first (modules/HistoryRetention.lua).
            NS.HistoryRetention.OnChanged(v)
        end }))
    Settings.StampClosureRows({ row })
end

-- ── Drops › Quality, Items and Retention (design spec §6.2, §6.3; feedback-24) ──────────────
--
-- What the addon lists at all, and how long it keeps it. Each mode's dependents share the line
-- under it: Fixed minimum and Floor (never live together), Absolute minimum and Levels under my
-- average (feedback-24). The View, Content and Sort a fresh tab opens on are Window › Starting view's.

local function feed()
    local F, Q = P.feed, P.feed.quality
    local quality = { page = "feed", group = L["Quality"], onChange = repaintWindow }
    pick("feed.quality.mode", Q.mode, QUALITY_MODES, L["Minimum quality"],
        L["Fixed: one quality for every drop. Match each slot: the quality of what the drop would replace. Match my gear: the quality most of your gear is."], quality)
    bool("feed.quality.upgradeOverride", Q.upgradeOverride, L["Always show upgrades for me"],
        L["A drop below the minimum still shows when it is an upgrade for you."], quality)
    pick("feed.quality.fixed", Q.fixed, FIXED_QUALITIES, L["Fixed minimum"],
        L["The least quality a drop needs in the fixed mode."],
        with(quality, { disabledIf = unless("feed.quality.mode", "fixed") }))
    pick("feed.quality.floor", Q.floor, FLOOR_QUALITIES, L["Quality floor"],
        L["The least quality the two matching modes ever ask for, and what an empty slot asks for."],
        with(quality, { disabledIf = function() return NS.Setting("feed.quality.mode") == "fixed" end }))

    local kinds = { page = "feed", group = L["Items"], subgroup = L["Item kinds"] }
    bool("feed.gearOnly", F.gearOnly, L["Gear only"],
        L["List armor, weapons, jewelry and trinkets only."], kinds)
    bool("feed.includeTokens", F.includeTokens, L["Include tier tokens"],
        L["List tier tokens too."], kinds)
    local ilvl = with(kinds, { subgroup = L["Item level"] })
    pick("feed.minIlvlMode", F.minIlvlMode, ILVL_MODES, L["Minimum item level"],
        L["Off, absolute (the level below), or relative (how far under your average equipped level a drop may be)."],
        with(ilvl, { solo = true }))
    slider("feed.minIlvl", F.minIlvl, 0, 1000, 1, L["Absolute minimum"],
        L["The least item level a drop needs in the absolute mode."],
        with(ilvl, { disabledIf = unless("feed.minIlvlMode", "absolute") }))
    slider("feed.relativeIlvl", F.relativeIlvl, 0, 100, 1, L["Levels under my average"],
        L["How far under your average equipped item level a drop may be in the relative mode."],
        with(ilvl, { disabledIf = unless("feed.minIlvlMode", "relative") }))

    -- Keep history for first, so it is alone on its line and Clear history takes the right half
    -- (settings/Pages.lua pairWith); Window › Layout's until feedback-24.
    local retention = { page = "feed", group = L["Retention"], subgroup = L["History"] }
    history(retention)
    bool("feed.clearOnBossKill", F.clearOnBossKill, L["Clear this session's drops on boss kill"],
        L["Clear the session's drops when a boss dies."], with(retention, { subgroup = L["Session"] }))
end

-- ── Comparison › Scoring, Weights and Unwanted types (design spec §5) ───────────────────────

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
        L["The item types each specialization never wants."], { page = "comparison", group = L["Unwanted types"] })
end

-- ── Messages › Sending, Auto-ask and Templates (design spec §9) ─────────────────────────────
--
-- The switches first, the template editors last (feedback-24).

local function messages()
    local M = P.messages
    -- The two per-send switches share line one, then Announce channel | Offer transmog asks (item 020,
    -- DRO-L08): each line one thought.
    local sending = { page = "messages", group = L["Sending"] }
    bool("messages.oneAsk", M.oneAsk, L["Ask once"],
        L["Send each ask or offer for a drop to a player once."], sending)
    bool("messages.editFirst", M.editFirst, L["Edit before sending"],
        L["Open the message in an edit box before it is sent."], sending)
    pick("messages.announceChannel", M.announceChannel, CHANNELS, L["Announce channel"],
        L["Automatic picks the instance channel, then raid, then party. Never say or yell."], sending)
    bool("messages.transmogAsk", M.transmogAsk, L["Offer transmog asks"],
        L["Also offer an ask on a drop that is no gain for you but whose look you have not collected, with the Ask for transmog template."],
        sending)

    local A = M.autoAsk
    local auto = { page = "messages", group = L["Auto-ask"] }
    local autoOff = with(auto, { disabledIf = unless("messages.autoAsk.enabled", true) })
    -- Turned on, the one-time notice and a fresh start; turned off, the waiting asks go (DW-54).
    -- Alone on its line, its two knobs paired under it (feedback-24).
    bool("messages.autoAsk.enabled", A.enabled, L["Ask automatically"],
        L["Ask for a likely tradeable upgrade for you on your behalf, after a delay."],
        with(auto, { solo = true, onChange = function(v) NS.AutoAsk.OnEnabledChanged(v) end }))
    slider("messages.autoAsk.delay", A.delay, 3, 30, 1, L["Delay (seconds)"],
        L["How long after the boss kill, or the drop, the ask waits."], autoOff)
    slider("messages.autoAsk.minGain", A.minGain, 1, 50, 1, L["Least gain (item levels)"],
        L["The least item-level gain for you an automatic ask needs."], autoOff)

    local templates = { page = "messages", group = L["Templates"], maxLetters = K.MESSAGE_MAX_LEN }
    text("messages.templates.ask", M.templates.ask, L["Ask"],
        L["What you whisper a looter to ask for their drop."], templates)
    text("messages.templates.transmog", M.templates.transmog, L["Ask for transmog"],
        L["What you whisper a looter to ask for a drop that is no gain for you but whose look you have not collected."], templates)
    text("messages.templates.askOffSpec", M.templates.askOffSpec, L["Ask for off-spec"],
        L["What you whisper a looter to ask for a drop your current spec can't use but another of your specs gains from."], templates)
    text("messages.templates.offer", M.templates.offer, L["Offer"],
        L["What you whisper someone your own drop would help."], templates)
    text("messages.templates.announce", M.templates.announce, L["Announce"],
        L["What you tell the group about a drop you can trade."], templates)
end

-- ── Window › Layout, Columns and Starting view (design spec §11; feedback-24) ───────────────

local function window()
    local W, F = P.window, P.feed
    local layout = { page = "window", group = L["Layout"], onChange = repaintWindow }
    -- Compact mode (compact spec §1): the stored layout, and the run override's switch.
    -- Two subjects on one tab (options-ui-§7, item 020 DRO-L07): Mode, the layout and its run
    -- override; Tables, the drop tables' row height and font. The row order is unchanged.
    layout = with(layout, { subgroup = L["Mode"] })
    pick("window.mode", W.mode, LAYOUTS, L["Window layout"],
        L["Full shows the drop tables with every column. Compact shows the same drops in a narrow window, so it stays out of the way during a run. The title bar's toggle, /dw compact and /dw full switch it too."],
        with(layout, { onChange = function() NS.WindowCompact.OnModeChanged() end }))
    bool("window.compactInRuns", W.compactInRuns, L["Compact view when it auto-opens in a run"],
        L["When the window opens by itself inside a dungeon, raid, Mythic+ key or delve, it opens in compact view, whatever the Layout. After the run ends it opens in the Layout again."],
        layout)
    layout = with(layout, { subgroup = L["Tables"] })
    slider("window.rowHeight", W.rowHeight, K.WINDOW.ROW_H_MIN, K.WINDOW.ROW_H_MAX, 1, L["Row height"],
        L["The height of one row in the drop tables: Drops and History. While the Trade window column shows, a Drops row adds room for its countdown bar."], layout)
    -- The tables' font follows Row height: the whole font setting (DW-01, the lead's ruling on
    -- D-07), the library's composed block, so settings/ComposedRows.lua declares it (it needs the
    -- Options instance). `window.fontSize` keeps its path, its 0 (Default) and its range there.

    -- The full layout's Drops table columns, then the Trade window column's ending-soon mark (Trade ›
    -- Timers until feedback-24: it tints that column's countdown on your own drops, nothing else).
    local columns = { page = "window", group = L["Columns"], subgroup = L["Shown columns"], onChange = repaintWindow }
    for _, col in ipairs(NS.WindowGroup.COLUMNS) do
        if col.key ~= "item" then
            bool("window.columns." .. col.key, W.columns[col.key], col.label, col.desc, columns)
        end
    end
    slider("trade.warnAt", P.trade.warnAt, 0, 1800, 60, L["Mark a trade window ending within (seconds)"],
        L["Your own drop's Trade window countdown turns to its warning color this many seconds before the item stops being tradeable. 0 turns the mark off."],
        { page = "window", group = L["Columns"], subgroup = L["Trade window"] })

    -- What a fresh Drops tab opens on (Feed › Filters until feedback-24): the View, a set
    -- (feedback-2 spec §1: one row per value, all off is All, combined as AND, as the filter bar's
    -- multi-select View does), then Content and Sort.
    local start = { page = "window", group = L["Starting view"], subgroup = L["View"] }
    for _, v in ipairs(VIEW_ROWS) do
        bool("feed.view." .. v.key, F.view[v.key], v.label, v.tip, start)
    end
    start = with(start, { subgroup = L["Content and sort"] })
    pick("feed.content", F.content, CONTENTS, L["Content"],
        L["Which drops the Drops tab lists when it opens: this instance's or this session's. History always opens on All."], start)
    pick("feed.sort", F.sort, SORTS, L["Sort"], L["How a fresh tab sorts its rows."], start)
end

-- ── Alerts › Toast (design spec §11; Window › Toast until feedback-24) ──────────────────────

local function toast()
    local T = P.toast
    local at = { page = "alerts", group = L["Toast"] }
    -- Turned off, the toast on screen goes and the queue empties (DW-62 review F-004). Alone on its
    -- line, its knobs paired under it (feedback-24).
    bool("toast.enabled", T.enabled, L["Show a toast"],
        L["Pop up a toast for a likely tradeable upgrade for you."],
        with(at, { solo = true, onChange = function(v) NS.Toast.OnEnabledChanged(v) end }))
    at = with(at, { disabledIf = unless("toast.enabled", true) })
    slider("toast.minGain", T.minGain, 1, 50, 1, L["Least gain (item levels)"],
        L["The least item-level gain for you a toast needs."], at)
    slider("toast.duration", T.duration, 2, 30, 1, L["Duration (seconds)"],
        L["How long a toast stays on screen."], at)
    -- Live in combat: on shows what waits, off holds what follows the toast on screen (AT-A3).
    bool("toast.inCombat", T.inCombat, L["Show in combat"], L["Show toasts in combat too."],
        with(at, { onChange = function() NS.Toast.OnInCombatChanged() end }))
    bool("toast.sound", T.sound, L["Play a sound"], L["Play a sound with each toast."], at)
    -- 50 to 200 %, about the toast's saved anchor; live on a toast on screen (feedback-21 G10).
    slider("toast.scale", T.scale, 0.5, 2, 0.05, L["Scale"],
        L["The toast's size, from half to double. It grows or shrinks about the place you put it."],
        with(at, { isPercent = true, onChange = function() NS.Toast.ApplyScale() end }))
end

-- ── Alerts › Upgrade glow (feedback-21; Window's until feedback-24): the glow on an upgrade's icon

-- The two glows, side by side: each knob is a main | off-spec pair, so the left column is the main
-- spec's glow and the right the off-spec's. The tab mixes kinds of control, so each block carries a
-- subsection heading (options-ui-§7), a style's heading its name in the Style dropdown.
local GLOWS = { "main", "offSpec" }

-- Each style's knobs, with its ranges and the styles it applies to; the defaults are
-- defaults/Profile.lua's. `labels` is { main, off-spec }. Offset first, as it applies to three of the
-- four styles, then each style's own in the Style dropdown's order (feedback-24; the feedback-21
-- plan's knob table had Offset last).
local GLOW_KNOBS = {
    { key = "xOffset", kind = "slider", min = -10, max = 10, step = 1,
      styles = { pixel = true, autocast = true, proc = true },
      heading = L["Offset"], labels = { L["Main spec X offset"], L["Off-spec X offset"] },
      tip = L["How far the glow reaches past the icon's sides, in pixels. Pixel, Proc and Auto cast styles."] },
    { key = "yOffset", kind = "slider", min = -10, max = 10, step = 1,
      styles = { pixel = true, autocast = true, proc = true },
      heading = L["Offset"], labels = { L["Main spec Y offset"], L["Off-spec Y offset"] },
      tip = L["How far the glow reaches past the icon's top and bottom, in pixels. Pixel, Proc and Auto cast styles."] },
    { key = "pixelLines", kind = "slider", min = 1, max = 20, step = 1, styles = { pixel = true },
      heading = L["Pixel border"], labels = { L["Main spec lines"], L["Off-spec lines"] },
      tip = L["How many lines run around the icon. Pixel style only."] },
    { key = "pixelFrequency", kind = "slider", min = 0.05, max = 2, step = 0.05, styles = { pixel = true },
      heading = L["Pixel border"], labels = { L["Main spec frequency"], L["Off-spec frequency"] },
      tip = L["How fast the lines run around the icon. Higher is faster. Pixel style only."] },
    { key = "pixelLength", kind = "slider", min = 0, max = 20, step = 1, styles = { pixel = true },
      zeroText = L["Automatic"], heading = L["Pixel border"],
      labels = { L["Main spec line length (0 = automatic)"], L["Off-spec line length (0 = automatic)"] },
      tip = L["How long each line is, in pixels. 0 sizes the lines from the icon. Pixel style only."] },
    { key = "pixelThickness", kind = "slider", min = 1, max = 6, step = 1, styles = { pixel = true },
      heading = L["Pixel border"], labels = { L["Main spec thickness"], L["Off-spec thickness"] },
      tip = L["How thick each line is, in pixels. Pixel style only."] },
    { key = "pixelBorder", kind = "bool", styles = { pixel = true },
      heading = L["Pixel border"], labels = { L["Main spec dark border"], L["Off-spec dark border"] },
      tip = L["Draw a dark border inside the lines. Pixel style only."] },
    { key = "autocastParticles", kind = "slider", min = 1, max = 12, step = 1, styles = { autocast = true },
      heading = L["Auto cast sparkles"], labels = { L["Main spec particles"], L["Off-spec particles"] },
      tip = L["How many sparkles circle the icon in each ring. Auto cast style only."] },
    { key = "autocastFrequency", kind = "slider", min = 0.05, max = 2, step = 0.05, styles = { autocast = true },
      heading = L["Auto cast sparkles"], labels = { L["Main spec frequency"], L["Off-spec frequency"] },
      tip = L["How fast the sparkles circle the icon. Higher is faster. Auto cast style only."] },
    { key = "autocastScale", kind = "slider", min = 0.5, max = 3, step = 0.1, styles = { autocast = true },
      heading = L["Auto cast sparkles"], labels = { L["Main spec scale"], L["Off-spec scale"] },
      tip = L["How big the sparkles are. Auto cast style only."] },
    { key = "buttonFrequency", kind = "slider", min = 0.05, max = 2, step = 0.05, styles = { button = true },
      heading = L["Button (rotating rays)"], labels = { L["Main spec frequency"], L["Off-spec frequency"] },
      tip = L["How fast the rays turn. Higher is faster. Button style only."] },
    { key = "procDuration", kind = "slider", min = 0.25, max = 3, step = 0.25, styles = { proc = true },
      heading = L["Proc (flipbook)"], labels = { L["Main spec duration (seconds)"], L["Off-spec duration (seconds)"] },
      tip = L["How many seconds one loop of the flipbook takes. Proc style only."] },
    { key = "procStartAnim", kind = "bool", styles = { proc = true },
      heading = L["Proc (flipbook)"], labels = { L["Main spec start animation"], L["Off-spec start animation"] },
      tip = L["Play the burst that opens the proc glow when it starts. Proc style only."] },
}
Settings.GLOW_KNOBS = GLOW_KNOBS

local function glow()
    local G = P.glow
    local at = { page = "alerts", group = L["Upgrade glow"], subgroup = L["Effect"], onChange = refreshGlow }
    -- A glow's style is dimmed while it is off; a knob also while its glow is in a style the knob
    -- does not apply to. Its color pair never is (below).
    local function off(key) return unless("glow." .. key .. ".enabled", true) end
    local function knobOff(key, styles)
        local isOff = off(key)
        return function() return isOff() or not styles[NS.Setting("glow." .. key .. ".type")] end
    end
    bool("glow.main.enabled", G.main.enabled, L["Main spec glow"],
        L["Glow a drop's icon when it is an upgrade for your current spec: in the drop table, the compact card and the drop's card."], at)
    bool("glow.offSpec.enabled", G.offSpec.enabled, L["Off-spec glow"],
        L["Glow a drop's icon when your current spec can't use it but another of your specs gains from it: in the drop table, the compact card and the drop's card."], at)
    pick("glow.main.type", G.main.type, GLOW_STYLES, L["Main spec style"],
        L["How the main spec glow looks."], with(at, { disabledIf = off("main") }))
    pick("glow.offSpec.type", G.offSpec.type, GLOW_STYLES, L["Off-spec style"],
        L["How the off-spec glow looks."], with(at, { disabledIf = off("offSpec") }))
    -- Main spec left, off-spec right on every line, the colors too (feedback-21 H6, the owner's
    -- choice): the two swatches share a line and their Use class color companions the next,
    --     [Main spec color]             | [Off-spec color]
    --     [Use class color (main spec)] | [Use class color (off-spec)]
    -- so each companion sits BELOW its swatch, not immediately to its right: a documented deviation
    -- from options-ui-§17 (docs/ARCHITECTURE.md -> Documented deviations). `startsLine` on each
    -- left-column row keeps a line from shifting by one, written out here because this file loads
    -- before the Options instance exists.
    -- PLAYER-SCOPED: the glow says a drop is an upgrade for you, whoever looted it. Never dimmed,
    -- even while the glow is off: a color and its companion carry no `disabledIf` (anti-pattern
    -- #74, the swatch's alpha is read under either mode).
    local CLASS_COLOR = {
        main    = { L["Use class color (main spec)"],
                    L["Glow in your class color instead of Main spec color, the swatch above. The swatch's alpha still applies."] },
        offSpec = { L["Use class color (off-spec)"],
                    L["Glow in your class color instead of Off-spec color, the swatch above. The swatch's alpha still applies."] },
    }
    for i, key in ipairs(GLOWS) do
        add{ path = "glow." .. key .. ".color", type = "color", default = G[key].color, hasAlpha = true,
             label = i == 1 and L["Main spec color"] or L["Off-spec color"],
             tooltip = L["The glow's color. Its alpha makes the glow fainter. Not read while Use class color is on, except for its opacity, which always applies."],
             validate = isColor, startsLine = i == 1 or nil, classColorSource = "player",
             page = at.page, group = at.group, subgroup = at.subgroup, onChange = refreshGlow }
    end
    for i, key in ipairs(GLOWS) do
        bool("glow." .. key .. ".useClassColor", G[key].useClassColor, CLASS_COLOR[key][1], CLASS_COLOR[key][2],
            with(at, { classColorSource = "player", startsLine = i == 1 or nil }))
    end
    -- A style's section is drawn only while EITHER glow's style selects it (DW-04, owner ruling D-17,
    -- image-40/41; LibKa0s OptionsSwitch minor 1's `shownWhen = { any = ... }`): both rows of every
    -- main | off-spec pair carry the same OR switch, so the pairing never breaks. It follows the
    -- style alone, never the on/off box: a glow turned off still opens its section, dimmed by
    -- knobOff, which also keeps dimming the column whose glow is in the other style. The Offset
    -- rows serve three styles and are not one style's section (D-17 names the four), so they keep
    -- the dimming alone. The hidden rows stay schema rows: `/dw set` and Defaults still reach them.
    local function chosen(styles)
        local list = {}
        for style in pairs(styles) do list[#list + 1] = style end
        table.sort(list)
        return { any = { { path = "glow.main.type", equals = list }, { path = "glow.offSpec.type", equals = list } } }
    end
    for _, knob in ipairs(GLOW_KNOBS) do
        local switch = knob.heading ~= L["Offset"] and chosen(knob.styles) or nil
        for i, key in ipairs(GLOWS) do
            local path = "glow." .. key .. "." .. knob.key
            local extra = with(at, { subgroup = knob.heading, disabledIf = knobOff(key, knob.styles),
                                     zeroText = knob.zeroText, shownWhen = switch })
            if knob.kind == "bool" then
                bool(path, G[key][knob.key], knob.labels[i], knob.tip, extra)
            else
                slider(path, G[key][knob.key], knob.min, knob.max, knob.step, knob.labels[i], knob.tip, extra)
            end
        end
    end
end

-- ── Window › Icons (feedback-21 G11): every item icon's look ────────────────────────────────

-- The zoom, KickCD's shape (0 to 0.25 cropped off each side); 0 is the icons as they always were,
-- 0.1 the default (feedback-21 H6) trims the edge baked into most item icons. The tab's Border block
-- is composed (settings/ComposedRows.lua) and follows it.
local function icons()
    slider("icons.zoom", P.icons.zoom, 0, 0.25, 0.01, L["Icon zoom"],
        L["Crop each item icon's edges: 0 shows the whole icon, 0.25 crops a quarter off each side. A little zoom trims the dark edge baked into most item icons."],
        { page = "window", group = L["Icons"], subgroup = L["Zoom"], onChange = refreshIcons })
end

-- ── General › Simulator (feedback-2 spec §8): the simulator's pace ─────────────────────────────

local function simulation()
    local SC = NS.SimScenario
    slider("sim.stepDelay", P.sim.stepDelay, SC.STEP_DELAY_MIN, SC.STEP_DELAY_MAX, SC.STEP_DELAY_STEP,
        L["Simulation step delay (seconds)"],
        L["Paces /dw sim: how many seconds the simulator waits between steps as it plays. A change takes effect from the next step."],
        { page = "general", group = L["Simulator"], validate = SC.ValidStepDelay })
end

-- ── General › Skin (skinning-§2/§3): the skin this addon wears ──────────────────────────────
--
-- Per addon, per profile. The tab is the library's O.AppearanceTab (settings/Panel.lua), which
-- draws every row below as its own choice grids, check boxes and dropdowns, so each row carries
-- `skipRender`; they stay schema rows so the defaults resolve, the global reset reaches them, and
-- `/dw get|set skin.skin` validates against `values`. Their group is "Appearance", the library
-- tab's key, so the tab takes the group's place in the strip: after Simulator, before Keybindings.
--
-- Each onChange moves ONLY its own half (core/SkinSetup.lua says why): the tab and another addon's
-- "Copy to every Ka0s addon" call Skin:SetChoice before they write, so the write is a no-op, and a
-- bare `/dw set` still repaints. Nothing here sends SettingsChanged.
local SKIN_GROUP = "Appearance"

local function isString(v) return type(v) == "string" end

local function skin()
    local at = { page = "general", group = SKIN_GROUP, skipRender = true }
    pick("skin.source", P.skin.source, NS.SKIN_SOURCE_OPTIONS, L["Skin source"],
        L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."],
        with(at, { onChange = function(v) NS.ApplySkinChoice(v, nil) end }))
    pick("skin.skin", P.skin.skin, NS.SKIN_OPTIONS, L["Skin"],
        L["The Ka0s skin this addon wears. Changes every window and panel right away."],
        with(at, { onChange = function(v) NS.ApplySkinChoice(nil, v) end }))
    -- The Scope's two exceptions, drawn by the same tab as check boxes.
    bool("skin.ignorePanel", P.skin.ignorePanel, L["Ignore settings panel"],
        L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."],
        with(at, { onChange = function(v) NS.ApplySkinIgnore(v, nil) end }))
    bool("skin.ignoreFonts", P.skin.ignoreFonts, L["Ignore fonts"],
        L["Keep every font in this addon as the game draws it. The skin still colors the text."],
        with(at, { onChange = function(v) NS.ApplySkinIgnore(nil, v) end }))
    -- The Font and texture section's two overrides, drawn by the same tab as dropdowns of
    -- LibSharedMedia keys; "" is the skin's own. Free text rather than a `values` list: a media pack
    -- may register its keys after this file loads, and `/dw set` takes any key.
    add(with(at, { path = "skin.font", type = "string", default = P.skin.font, label = L["Font"],
        tooltip = L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."],
        validate = isString, onChange = function(v) NS.ApplySkinOverride(v, nil) end }))
    add(with(at, { path = "skin.texture", type = "string", default = P.skin.texture, label = L["Texture"],
        tooltip = L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."],
        validate = isString, onChange = function(v) NS.ApplySkinOverride(nil, v) end }))
    -- The Font outline (LibKa0s-Skin-1.0 minor 9, ruling D-06), drawn by the same tab as its "Font
    -- outline" dropdown: where the skin outlines this addon's text. The library's three modes, in
    -- its order; `/dw set skin.outline` validates against them.
    pick("skin.outline", P.skin.outline, NS.SKIN_OUTLINE_OPTIONS, L["Font outline"],
        L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere. The window, the cards and the toast are window text."],
        with(at, { onChange = function(v) NS.ApplySkinOutline(v) end }))
    -- The first-run skin picker's memory: set when the picker closes, so it shows once per
    -- profile (O3). Drawn by nothing; a reset puts it back to false.
    bool("skin.pickerSeen", P.skin.pickerSeen, L["Skin picker seen"],
        L["Whether the first-run skin picker was closed on this profile."], at)
end

simulation()
skin()
situations()
feed()
comparison()
messages()
window()
icons()
toast()
glow()

NS.SchemaRuntime.AddRows(Rows)
