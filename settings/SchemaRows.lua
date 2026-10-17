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
-- editors (`skipRender`). General › When to show's per-situation rows (`situations.<key>.track`,
-- `.autoOpen`, `.quality`) are `skipRender` too: its table draws them, one line per situation. The
-- window's geometry, its minimized flag and the toast's position have no row: they are named
-- non-setting state (docs/schema.md -> State written outside the seam). Window › Upgrade glow's
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

-- A glow row repaints every glowing icon: the window's surfaces and the toast (modules/Glow.lua).
local function refreshGlow()
    local G = NS.Glow
    if G and G.Refresh then G.Refresh() end
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
-- LibCustomGlow-1.0's four effects, named as KickCD's glow style dropdown names them.
local GLOW_STYLES = choices{
    "button", L["Button (rotating rays)"], "proc", L["Proc (flipbook)"], "pixel", L["Pixel border"],
    "autocast", L["Auto cast sparkles"],
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

-- ── General › When to show (design spec §6.1) ───────────────────────────────────────────────

local function whenToShow()
    local at = { page = "general", group = L["When to show"] }
    bool("autoOpen", P.autoOpen, L["Auto-open the window"],
        L["Open the window whenever a drop is added to the feed in a situation set to auto-open, your own included. A minimized window stays minimized and counts it. Off, no situation opens it."], at)
    for _, s in ipairs(K.SITUATIONS) do
        local key, d = s.key, P.situations[s.key]
        local base = "situations." .. key .. "."
        -- Drawn by When to show's table (settings/PageEditors.lua SituationTable), one table row per
        -- situation: still schema rows, so the CLI, the resets and profiles reach them as before.
        local sit = { page = "general", group = L["When to show"], skipRender = true }
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
        L["Which drops the Drops tab lists when it opens: this instance's or this session's. History always opens on All."], filters)
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
    text("messages.templates.askOffSpec", M.templates.askOffSpec, L["Ask for off-spec"],
        L["What you whisper a looter to ask for a drop your current spec can't use but another of your specs gains from."], templates)
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
            bool("window.columns." .. col.key, W.columns[col.key], col.label, col.desc, columns)
        end
    end
    local layout = { page = "window", group = L["Layout"], onChange = repaintWindow }
    -- Compact mode (compact spec §1): the stored layout, and the run override's switch.
    pick("window.mode", W.mode, LAYOUTS, L["Layout"],
        L["Full shows the drop tables with every column. Compact shows the same drops in a narrow window, so it stays out of the way during a run. The title bar's toggle, /dw compact and /dw full switch it too."],
        with(layout, { onChange = function() NS.WindowCompact.OnModeChanged() end }))
    bool("window.compactInRuns", W.compactInRuns, L["Open in compact view during a run"],
        L["When the window opens by itself inside a dungeon, raid, Mythic+ key or delve, it opens in compact view, whatever the Layout. After the run ends it opens in the Layout again."],
        layout)
    slider("window.rowHeight", W.rowHeight, K.WINDOW.ROW_H_MIN, K.WINDOW.ROW_H_MAX, 1, L["Row height"],
        L["The height of one row in the drop tables: Drops and History. While the Trade window column shows, a Drops row adds room for its countdown bar."], layout)
    -- 0, all the way left, is Default: the template's own size, like Ka0s Loot History's table
    -- (feedback-2 spec §8, FB2-9); 1 to 7 read as the least size (modules/WindowRows.lua).
    slider("window.fontSize", W.fontSize, 0, K.WINDOW.FONT_MAX, 1, L["Font size"],
        L["The size of the drop tables' text, on both tabs. All the way left (0) is Default: the game's own small table font, as in Ka0s Loot History."],
        with(layout, { zeroText = L["Default"] }))

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

-- ── Window › Upgrade glow (feedback-21): the glow on an upgrade's icon ──────────────────────

-- The two glows, side by side: each knob is a main | off-spec pair, so the left column is the main
-- spec's glow and the right the off-spec's. The tab mixes kinds of control, so each block carries a
-- subsection heading (options-ui-§7), a style's heading its name in the Style dropdown.
local GLOWS = { "main", "offSpec" }

-- Each style's knobs, in the feedback-21 plan's knob table order, with its ranges and the styles
-- it applies to; the defaults are defaults/Profile.lua's. `labels` is { main, off-spec }.
local GLOW_KNOBS = {
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
    { key = "xOffset", kind = "slider", min = -10, max = 10, step = 1,
      styles = { pixel = true, autocast = true, proc = true },
      heading = L["Offset"], labels = { L["Main spec X offset"], L["Off-spec X offset"] },
      tip = L["How far the glow reaches past the icon's sides, in pixels. Pixel, Proc and Auto cast styles."] },
    { key = "yOffset", kind = "slider", min = -10, max = 10, step = 1,
      styles = { pixel = true, autocast = true, proc = true },
      heading = L["Offset"], labels = { L["Main spec Y offset"], L["Off-spec Y offset"] },
      tip = L["How far the glow reaches past the icon's top and bottom, in pixels. Pixel, Proc and Auto cast styles."] },
}
Settings.GLOW_KNOBS = GLOW_KNOBS

local function glow()
    local G = P.glow
    local at = { page = "window", group = L["Upgrade glow"], subgroup = L["Effect"], onChange = refreshGlow }
    -- A glow's style and color are dimmed while it is off; a knob also while its glow is in a style
    -- the knob does not apply to.
    local function off(key) return unless("glow." .. key .. ".enabled", true) end
    local function knobOff(key, styles)
        local isOff = off(key)
        return function() return isOff() or not styles[NS.Setting("glow." .. key .. ".type")] end
    end
    bool("glow.main.enabled", G.main.enabled, L["Main spec glow"],
        L["Glow a drop's icon when it is an upgrade for your current spec: in the drop table, the compact card, the drop's card and the toast."], at)
    bool("glow.offSpec.enabled", G.offSpec.enabled, L["Off-spec glow"],
        L["Glow a drop's icon when your current spec can't use it but another of your specs gains from it: in the drop table, the compact card, the drop's card and the toast."], at)
    pick("glow.main.type", G.main.type, GLOW_STYLES, L["Main spec style"],
        L["How the main spec glow looks."], with(at, { disabledIf = off("main") }))
    pick("glow.offSpec.type", G.offSpec.type, GLOW_STYLES, L["Off-spec style"],
        L["How the off-spec glow looks."], with(at, { disabledIf = off("offSpec") }))
    for i, key in ipairs(GLOWS) do
        add{ path = "glow." .. key .. ".color", type = "color", default = G[key].color,
             label = i == 1 and L["Main spec color"] or L["Off-spec color"],
             tooltip = L["The glow's color. Its alpha makes the glow fainter."], validate = isColor,
             page = at.page, group = at.group, subgroup = at.subgroup, onChange = refreshGlow,
             disabledIf = off(key) }
    end
    for _, knob in ipairs(GLOW_KNOBS) do
        for i, key in ipairs(GLOWS) do
            local path = "glow." .. key .. "." .. knob.key
            local extra = with(at, { subgroup = knob.heading, disabledIf = knobOff(key, knob.styles),
                                     zeroText = knob.zeroText })
            if knob.kind == "bool" then
                bool(path, G[key][knob.key], knob.labels[i], knob.tip, extra)
            else
                slider(path, G[key][knob.key], knob.min, knob.max, knob.step, knob.labels[i], knob.tip, extra)
            end
        end
    end
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

-- ── General › Simulation (feedback-2 spec §8): the simulator's automatic run ─────────────────

local function simulation()
    local SC = NS.SimScenario
    slider("sim.stepDelay", P.sim.stepDelay, SC.STEP_DELAY_MIN, SC.STEP_DELAY_MAX, SC.STEP_DELAY_STEP,
        L["Simulation step delay"],
        L["How many seconds the simulator's automatic run (Run all, `/dw sim run`) waits between steps. A change takes effect from the next step."],
        { page = "general", group = L["Simulation"], validate = SC.ValidStepDelay })
end

whenToShow()
simulation()
feed()
comparison()
trade()
messages()
window()
history()
glow()

NS.SchemaRuntime.AddRows(Rows)
