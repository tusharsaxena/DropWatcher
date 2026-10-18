local _, NS = ...
-- modules/WindowFilterBar.lua — the main window's filter bar (design spec §11.1, board 01): View,
-- Quality, Content, Character and the search box, each tab's own filter state, and the pure
-- predicates the tabs' bodies filter and order their rows with.
--
-- ONE BAR, ONE STATE PER TAB. The bar is a single set of controls under the tab strip; each tab
-- keeps its own state (NS.State.windowFilters[tab], session-only), and selecting a tab puts its
-- state on the bar (Sync). A control a tab does not honor is grayed rather than hidden, so the bar
-- never reflows between tabs (Ka0s Loot History's pattern). A fresh tab's state is seeded from the
-- `feed.view.<value>`, `feed.content` and `feed.sort` rows (through the schema seam) when they hold
-- a valid value, else from DEFAULTS, which are those rows' defaults. History then takes its own
-- fixed defaults (TAB_FIXED: View, Content and Character all All, feedback-13 spec §0).
--
-- CONTENT IS PER TAB (feedback-15 spec §1, DW-Q1). Drops offers This instance and This session (its
-- feed holds this session's drops alone, so an All would be This session again); History adds All,
-- every kept day. The one Content dropdown takes the active tab's values on Sync, in both layouts
-- (the compact Filters panel holds the same control), and a value the tab does not offer is refused.
--
-- THE VIEW IS A SET (feedback-2 spec §1, FB2-1..3). Like Loot History's `Direction: 3 selected`
-- (../LootHistory/modules/BrowserFilterBar.lua) the View dropdown is multi-select: Interesting,
-- Likely tradeable, Usable by me and Upgrade for me combine as AND, and All (the empty set, the
-- default) clears them. The three checkboxes the bar had before are these values now. A tab grays
-- the values it does not use (History has no Likely tradeable: a kept drop's trade estimate is
-- long stale), and a grayed value neither toggles nor filters.
--
-- THE CHARACTER DROPDOWN (feedback-2 spec §4, FB2-6), like Loot History's: All, Current, then each
-- character Drop Watcher has a record for (modules/CharFilter.lua builds the rows and the
-- predicate). Multi-select, Current by default, on every tab. History filters its kept drops by who
-- saw them; Drops lists only you, and every drop on it is yours (`charScope` `session`), so its
-- filter never hides one.
--
-- THE QUALITY CONTROL IS NOT A VIEW FILTER: it shows the feed's minimum-quality mode in force (the
-- situation's override, else `feed.quality.mode`) with its threshold, `Quality: Rare+` (design spec
-- §6.2), and choosing a mode goes through NS.SetQualityMode (core/DropWatcher.lua), the handler the
-- settings row shares. It is the same on every tab, and only the Drops tab honors it.
--
-- OFF-SPEC (feedback-19 spec §1). A drop your current spec can't use but another of your specs can
-- (NS.OffSpec.Of on `me`) counts as an upgrade for Upgrade for me and Interesting when the off-spec
-- verdict is one, and as usable for Usable by me when it is an upgrade or a sidegrade. Gain sorts its
-- off-spec difference a hundredth below a main-spec upgrade of the same size, so main spec comes
-- first. The looter's off-spec changes nothing: a Can't use on their main spec still gives it.
--
-- PURE: IsInteresting, IsTradeableMine, Matches, HiddenBy, ViewLabel and Comparator take plain
-- tables and read nothing else, so the suites drive them case by case. Build, Sync and Layout are
-- the frame edge.
-- DEGRADED (no LibKa0s-Widgets-1.0): the four dropdowns are not drawn (core/WidgetsSetup.lua);
-- the search box still filters.
-- THE COMPACT LAYOUT (compact spec §4) keeps View and the search box on one row and moves Quality,
-- Content and Character into the Filters panel (modules/CompactChrome.lua); FB.Anchor puts them back.

NS.WindowFilterBar = NS.WindowFilterBar or {}
local FB    = NS.WindowFilterBar
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State

-- The View's values, in menu order after All (the empty set). Each is a `feed.view.<value>` row.
FB.VIEWS = { "interesting", "likely", "usable", "upgrade" }
local IS_VIEW = {}
for _, v in ipairs(FB.VIEWS) do IS_VIEW[v] = true end

-- Each single-select control's values, in menu order. Content's are per tab (FB.CONTENTS).
FB.VALUES = {
    sort    = { "newest", "oldest", "ilvl", "gain" },
}

-- Each tab's Content values, in menu order (feedback-15 spec §1): All on History only.
FB.CONTENTS = {
    group   = { "instance", "session" },
    history = { "instance", "session", "all" },
}

--- The Content values a tab offers, in menu order (Drops' for an unknown tab).
--- @param tab string|nil
--- @return table
function FB.ContentValues(tab)
    return FB.CONTENTS[tab] or FB.CONTENTS.group
end

-- Which controls each tab honors (the tab's Sort included). `views` is the View values the tab
-- uses; the rest are grayed in its menu and ignored by its filter.
local ALL_VIEWS = { interesting = true, likely = true, usable = true, upgrade = true }
-- `char` is the Character dropdown; `charScope` `session` marks a tab whose drops are all yours.
local ALL = { view = true, quality = true, content = true, search = true, sort = true, char = true,
    charScope = "session", views = ALL_VIEWS }
FB.HONORS = {
    group   = ALL,
    history = { view = true, content = true, search = true, sort = true, char = true,
                views = { interesting = true, usable = true, upgrade = true } },
}

local P = NS.C.PROFILE
local CF = NS.CharFilter
-- The Character default is Current (FB2-6): the CURRENT sentinel until your key is known.
local DEFAULTS = { view = {}, char = { [CF.CURRENT] = true }, content = P.feed.content, search = "",
    sort = P.feed.sort }
FB.DEFAULTS = DEFAULTS

-- Where a fresh tab's single values are seeded from: the setting's path.
local SEED = { content = "feed.content", sort = "feed.sort" }

-- Each View value's name, as its menu row and a one-value label show it.
FB.VIEW_NAMES = {
    interesting = L["Interesting"], likely = L["Likely tradeable"], usable = L["Usable by me"],
    upgrade = L["Upgrade for me"],
}
local VIEW_ALL = L["View: All"]

FB.LABELS = {
    content = {
        instance = L["Content: This instance"], session = L["Content: This session"], all = L["Content: All"],
    },
    sort = {
        newest = L["Sort: Newest"], oldest = L["Sort: Oldest"], ilvl = L["Sort: Item level"],
        gain = L["Sort: Biggest upgrade"],
    },
}
local QUALITY_MODE_LABEL = {
    fixed = L["Fixed minimum"], dynamicSlot = L["Match each slot"], dynamicCharacter = L["Match my gear"],
}

-- The View tooltip's rows (FB2-3, feedback-21): one per value, All first.
local VIEW_TIP = {
    { key = "all", name = L["All"], text = L["every drop past the situation and quality gates"] },
    { key = "interesting", name = L["Interesting"], text = L["an upgrade for you, or likely given away and tradeable"] },
    { key = "likely", name = L["Likely tradeable"], text = L["a trade estimate of yes or likely"] },
    { key = "usable", name = L["Usable by me"], text = L["you can use it, and its type is not unwanted"] },
    { key = "upgrade", name = L["Upgrade for me"], text = L["an upgrade over what you wear (or your best owned piece)"] },
}
-- Each control's tooltip: its title, then { label, value } rows (NS.TipMarks.Row at call time).
local TIPS = {
    content = { L["Content"], { L["This instance"], L["the drops since you entered it or started this key"] },
        { L["This session"], L["every drop since you logged in, kept over a /reload"] },
        { L["All"], L["every kept day (History only)"] } },
    search = { L["Search"], { L["Shows"], L["the drops whose item or looter name contains this text"] } },
    char = { L["Character"], { L["Shows"], L["the drops these characters saw"] },
        { L["History"], L["kept for every character on the account"] },
        { L["Drops"], L["this session's drops, only ever yours"] },
        { L["Not recorded"], L["a History drop kept before who saw it was recorded shows only under All"] } },
}
local GRAYED = { L["On this tab"], L["not used"] }

-- A TIPS entry as tooltip lines: its title, then a row per pair.
local function tipLines(t)
    local out = { t[1] }
    for i = 2, #t do out[i] = NS.TipMarks.Row(t[i][1], t[i][2]) end
    return out
end

local function grayedRow() return NS.TipMarks.Row(GRAYED[1], GRAYED[2]) end
local GRAY = { 0.5, 0.5, 0.5 }

local controls = {}     -- the built controls: view, quality, content, char (each a dropdown or nil), search
local syncing = false   -- Sync is writing the controls: their change handlers stand aside

-- ── state ───────────────────────────────────────────────────────────────────────────────────

local function inList(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- A View set: a table whose every key is a View value and every value true (empty is All).
local function validView(v)
    if type(v) ~= "table" then return false end
    for k, on in pairs(v) do
        if not IS_VIEW[k] or on ~= true then return false end
    end
    return true
end

-- A Character selection: a set of recorder keys (strings), each true (empty is All).
local function validChar(v)
    if type(v) ~= "table" then return false end
    for k, on in pairs(v) do
        if type(k) ~= "string" or on ~= true then return false end
    end
    return true
end

-- Whether `v` is a value `key` takes on `tab` (Content's values are the tab's own).
local function valid(key, v, tab)
    if key == "view" then return validView(v) end
    if key == "char" then return validChar(v) end
    if key == "search" then return type(v) == "string" end
    if key == "content" then return inList(FB.ContentValues(tab), v) end
    return FB.VALUES[key] ~= nil and inList(FB.VALUES[key], v)
end

local function copySet(set)
    local out = {}
    for k, on in pairs(set) do out[k] = on end
    return out
end

local function sameSet(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

local SETS = { view = true, char = true }

local function same(key, a, b)
    if SETS[key] then return type(a) == "table" and sameSet(a, b) end
    return a == b
end

-- The View set the profile seeds: each `feed.view.<value>` row that holds true.
local function seededView()
    local set = {}
    for _, v in ipairs(FB.VIEWS) do
        if NS.Setting("feed.view." .. v) == true then set[v] = true end
    end
    return set
end

-- A tab's defaults that no profile row seeds. History is a record of every session and character,
-- not a feed to act on: it opens on View: All, Content: All and Character: All (feedback-13 spec §0).
FB.TAB_FIXED = { history = { view = {}, content = "all", char = {} } }

--- A fresh tab's state: DEFAULTS, overridden by each seed the profile holds a valid value for, then
--- by the tab's FB.TAB_FIXED values.
--- @param tab string|nil
--- @return table
function FB.Defaults(tab)
    local d = {}
    for k, v in pairs(DEFAULTS) do d[k] = v end
    d.view = seededView()
    d.char = CF.Canonical(DEFAULTS.char, CF.CurrentKey())
    for k, path in pairs(SEED) do
        local v = NS.Setting(path)
        if valid(k, v, tab) then d[k] = v end
    end
    for k, v in pairs(FB.TAB_FIXED[tab] or {}) do d[k] = SETS[k] and copySet(v) or v end
    return d
end

--- A tab's filter state ({ view = { [value] = true }, char = { [key] = true }, content, search,
--- sort }), seeded on first
--- use. The table is the bar's own: read it, and change it through Set.
--- @param tab string
--- @return table
function FB.State(tab)
    local all = State.windowFilters
    if not all then
        all = {}
        State.windowFilters = all
    end
    if not all[tab] then all[tab] = FB.Defaults(tab) end
    return all[tab]
end

local function shown(key, value)
    if key == "char" then return CF.Label(value, CF.CurrentKey()) end
    if key ~= "view" then return tostring(value) end
    return FB.ViewLabel(value)
end

--- Change one control's value on one tab. An invalid value is refused (Content: one the tab does
--- not offer, FB.ContentValues); the window redraws the tab.
--- The View takes a set ({ [value] = true }, empty for All), stored as a copy; so does the Character
--- dropdown ({ [Name-Realm] = true }), the CURRENT sentinel swapped for your key when it is known.
--- @param tab string
--- @param key string `view`, `char`, `content`, `search` or `sort`
--- @param value any
--- @return boolean changed
function FB.Set(tab, key, value)
    if not valid(key, value, tab) then return false end
    if key == "char" then value = CF.Canonical(value, CF.CurrentKey()) end
    local st = FB.State(tab)
    if same(key, st[key], value) then return false end
    st[key] = SETS[key] and copySet(value) or value
    NS.Debug("UI", "filter %s.%s = %s", tab, key, shown(key, value))
    NS.Window.OnFilterChanged(tab)
    return true
end

--- The View's collapsed label for a set, as the dropdown words it: `View: All`, the one value's
--- name, or `View: n selected`.
--- @param set table|nil
--- @return string
function FB.ViewLabel(set)
    local n, only = 0, nil
    for _, v in ipairs(FB.VIEWS) do
        if type(set) == "table" and set[v] then n, only = n + 1, v end
    end
    if n == 0 then return VIEW_ALL end
    if n == 1 then return FB.VIEW_NAMES[only] end
    return L["View: %d selected"]:format(n)
end

-- ── the predicates (pure) ───────────────────────────────────────────────────────────────────

local TRADEABLE = { yes = true, likely = true }

local function tradeState(drop)
    local t = drop.trade
    return type(t) == "table" and t.state or nil
end

local function verdictOf(side)
    return type(side) == "table" and side.verdict or nil
end

-- The off-spec verdict a `cantUse` carries (feedback-19 spec §1), or nil.
local function offVerdictOf(side)
    local off = NS.OffSpec.Of(side)
    return off and off.verdict or nil
end

-- An upgrade for you: on your current spec, or on another of yours when this one can't use it.
local function upgradeForMe(drop)
    return verdictOf(drop.me) == "upgrade" or offVerdictOf(drop.me) == "upgrade"
end

-- The looter has no use for it: a downgrade, an item they cannot use, or one they would not want.
local LOOTER_GIVES = { downgrade = true, cantUse = true, doesntWant = true }

--- Interesting (brainstorm 03_FEATURES F1, board 01 note 5): a union, someone else's drop that is
--- an upgrade for you, or one its looter has no use for (a downgrade, can't use, doesn't want) and
--- can trade (`yes` or `likely`); or your own drop you can trade now.
--- @param drop table
--- @return boolean
function FB.IsInteresting(drop)
    if type(drop) ~= "table" then return false end
    local state = tradeState(drop)
    if drop.isMine then return TRADEABLE[state] == true end
    if upgradeForMe(drop) then return true end
    return LOOTER_GIVES[verdictOf(drop.them)] == true and TRADEABLE[state] == true
end

--- Your own drop whose trade estimate is `yes` or `likely` (what Post my tradeables posts).
--- @param drop table
--- @return boolean
function FB.IsTradeableMine(drop)
    return type(drop) == "table" and drop.isMine == true and TRADEABLE[tradeState(drop)] == true
end

local function itemName(drop)
    local link = drop.link
    if type(link) ~= "string" then return "" end
    return link:match("|h%[(.-)%]|h") or link
end

local function matchesSearch(drop, text)
    if type(text) ~= "string" or text == "" then return true end
    local needle = text:lower()
    local looter = type(drop.looter) == "table" and drop.looter.name or nil
    if itemName(drop):lower():find(needle, 1, true) then return true end
    return type(looter) == "string" and looter:lower():find(needle, 1, true) ~= nil
end

-- `instance`: the drops since the situation last changed (ctx.instanceSince); `session` the drops
-- since ctx.sessionSince, the login (modules/Session.lua): Drops' in the client clock
-- (Window.TabContext), History's in time() (modules/WindowHistory.lua); `all` (History only) passes
-- every drop.
local function matchesContent(drop, content, ctx)
    local since
    if content == "instance" then since = ctx and ctx.instanceSince end
    if content == "session" then since = ctx and ctx.sessionSince end
    if type(since) ~= "number" or type(drop.at) ~= "number" then return true end
    return drop.at >= since
end

-- Your verdict that Usable by me hides: you can't use it, or your own preferences exclude it.
local NOT_USABLE = { cantUse = true, doesntWant = true }
-- ... unless another of your specs takes it (feedback-19 spec §1).
local OFF_USABLE = { upgrade = true, sidegrade = true }

-- Each View value's test: true when the drop passes it.
local VIEW_PASS = {
    interesting = function(d) return FB.IsInteresting(d) end,
    likely      = function(d) return TRADEABLE[tradeState(d)] == true end,
    usable      = function(d) return not NOT_USABLE[verdictOf(d.me)] or OFF_USABLE[offVerdictOf(d.me)] == true end,
    upgrade     = function(d) return upgradeForMe(d) end,
}

-- The first selected View value the tab uses that the drop fails, in menu order, or nil.
local function viewHides(drop, set, honors)
    if not honors.view or type(set) ~= "table" then return nil end
    local uses = honors.views or ALL_VIEWS
    for _, v in ipairs(FB.VIEWS) do
        if set[v] and uses[v] and not VIEW_PASS[v](drop) then return v end
    end
    return nil
end

-- Whether the Character selection hides a drop: on a `session` tab every drop is yours; elsewhere
-- its recorder decides (none: only All shows it).
local function charHides(drop, set, ctx, honors)
    if not honors.char then return false end
    local by = honors.charScope == "session" and CF.CURRENT or drop.seenBy
    return not CF.Passes(by, set, ctx and ctx.current)
end

--- The first filter of a tab's state that hides a drop: a View value (`interesting`, `likely`,
--- `usable`, `upgrade`), `char`, `content` or `search`; nil when the drop passes them all. Only the
--- controls (and View values) the tab honors apply; anything not a drop answers `invalid`.
--- @param drop table
--- @param st table|nil the tab's state (DEFAULTS when nil)
--- @param ctx table|nil { instanceSince, sessionSince (GetTime() seconds), current (your recorder key) }
--- @param honors table|nil the tab's FB.HONORS row (every control when nil)
--- @return string|nil
function FB.HiddenBy(drop, st, ctx, honors)
    if type(drop) ~= "table" then return "invalid" end
    st, honors = st or DEFAULTS, honors or ALL
    local v = viewHides(drop, st.view, honors)
    if v then return v end
    if charHides(drop, st.char, ctx, honors) then return "char" end
    if honors.content and not matchesContent(drop, st.content, ctx) then return "content" end
    if honors.search and not matchesSearch(drop, st.search) then return "search" end
    return nil
end

--- Whether a drop passes a tab's filter (FB.HiddenBy answers nil).
--- @param drop table
--- @param st table|nil
--- @param ctx table|nil
--- @param honors table|nil
--- @return boolean
function FB.Matches(drop, st, ctx, honors)
    return FB.HiddenBy(drop, st, ctx, honors) == nil
end

--- The filter a FB.HiddenBy key names, for a group header's tooltip: `View: Interesting`,
--- `View: Usable by me`, `Character: Current`, `Content: This instance`, `Search`.
--- @param key string|nil
--- @param st table|nil the tab's state
--- @return string
function FB.ReasonLabel(key, st)
    st = type(st) == "table" and st or DEFAULTS
    if FB.VIEW_NAMES[key] then return L["View: %s"]:format(FB.VIEW_NAMES[key]) end
    if key == "char" then return CF.Label(st.char, CF.CurrentKey()) end
    local byValue = FB.LABELS[key]
    if byValue and byValue[st[key]] then return byValue[st[key]] end
    local tip = TIPS[key]
    if tip then return tip[1] end
    return L["the filters"]
end

local function num(v) return type(v) == "number" and v or nil end
local function atOf(d) return num(d.at) or 0 end
local function ilvlOf(d) return type(d.facts) == "table" and num(d.facts.ilvl) or -math.huge end
-- An off-spec difference sorts this much below a main-spec one of the same size (feedback-19 §1).
local OFF_SPEC_BELOW = 0.01
local function gainOf(d)
    local off = NS.OffSpec.Of(d.me)
    if off then return num(off.ilvlDelta) and off.ilvlDelta - OFF_SPEC_BELOW or -math.huge end
    return type(d.me) == "table" and num(d.me.ilvlDelta) or -math.huge
end

-- Each order's key, larger first; `oldest` turns the first round. Ties go to the newer id.
local ORDER = {
    newest = { key = atOf, desc = true },
    oldest = { key = atOf, desc = false },
    ilvl   = { key = ilvlOf, desc = true },
    gain   = { key = gainOf, desc = true },
}

--- A table.sort comparator for one Sort value (`newest` for anything unknown).
--- @param sort string|nil
--- @return function
function FB.Comparator(sort)
    local o = ORDER[sort] or ORDER.newest
    return function(a, b)
        local ka, kb = o.key(a), o.key(b)
        if ka ~= kb then
            if o.desc then return ka > kb end
            return ka < kb
        end
        return (num(a.id) or 0) > (num(b.id) or 0)
    end
end

-- ── the quality readout ─────────────────────────────────────────────────────────────────────

--- The minimum-quality mode in force, its threshold (nil for `dynamicSlot`, which differs per drop)
--- and the bar's label. Reads the feed's settings, the situation's override and, for
--- `dynamicCharacter`, your worn qualities.
--- @return string mode, number|nil threshold, string label
function FB.QualityReadout()
    local Q, cfg = NS.QualityGate, NS.LootFeed.Config()
    local mode = Q.ResolveMode(cfg.qualityMode, NS.Situations.QualityOverride())
    local threshold
    if mode ~= "dynamicSlot" then
        local gear = mode == "dynamicCharacter" and NS.Gear.Qualities() or nil
        threshold = Q.Threshold(mode, { fixed = cfg.fixed, floor = cfg.floor, gear = gear })
    end
    return mode, threshold, Q.ThresholdLabel(mode, threshold)
end

local function qualityTip()
    local mode, _, label = FB.QualityReadout()
    local TM = NS.TipMarks
    return label, TM.Row(L["Hides"], L["drops below this quality, unless an upgrade for you"]),
        TM.Row(L["A change"], L["applies to new drops"]), TM.Row(L["Mode"], QUALITY_MODE_LABEL[mode] or mode)
end

-- ── the View's menu and tooltip ─────────────────────────────────────────────────────────────

--- The View tooltip on one tab (FB2-3): the title, then a row per value (feedback-21), the ones the tab
--- does not use grayed and marked. A tab that uses no View says so instead.
--- @param tab string
--- @return table lines
function FB.ViewTip(tab)
    local honors = FB.HONORS[tab] or ALL
    if not honors.view then return { L["View"], grayedRow() } end
    local out = { L["View"] }
    for _, line in ipairs(VIEW_TIP) do
        if line.key ~= "all" and not honors.views[line.key] then
            out[#out + 1] = NS.TipMarks.Row(line.name, ("%s %s"):format(line.text, L["(not on this tab)"]), "bad")
        else
            out[#out + 1] = NS.TipMarks.Row(line.name, line.text)
        end
    end
    return out
end

local function usesOf(tab)
    return (FB.HONORS[tab] or ALL).views or ALL_VIEWS
end

--- The View menu's rows on one tab: All, then each value, grayed where the tab does not use it.
--- @param tab string
--- @return table rows { value, label, color? }
function FB.ViewOptions(tab)
    local uses = usesOf(tab)
    local out = { { value = "all", label = VIEW_ALL } }
    for _, v in ipairs(FB.VIEWS) do
        out[#out + 1] = { value = v, label = FB.VIEW_NAMES[v], color = not uses[v] and GRAY or nil }
    end
    return out
end

-- A grayed value's click: a preset that leaves the selection as it is (LibKa0s-Widgets presets).
local function noop() end

local function viewPresets(tab)
    local uses, out = usesOf(tab), {}
    for _, v in ipairs(FB.VIEWS) do
        if not uses[v] then out[v] = noop end
    end
    return out
end

-- ── the controls (frame edge) ───────────────────────────────────────────────────────────────

local function options(key, values)
    local out = {}
    for _, v in ipairs(values or FB.VALUES[key]) do out[#out + 1] = { value = v, label = FB.LABELS[key][v] } end
    return out
end

-- A tab's Content rows never change: built once per tab, so the bar's Sync writes them only on a
-- tab switch (putOptions).
local contentRows = {}  -- [tab] = options

local function contentOptions(tab)
    local rows = contentRows[tab]
    if not rows then
        rows = options("content", FB.ContentValues(tab))
        contentRows[tab] = rows
    end
    return rows
end

local function activeTab() return NS.Window.ActiveTab() end

local function grayedTip(key, t)
    return function()
        if not FB.HONORS[activeTab()][key] then return t[1], grayedRow() end
        return unpack(tipLines(t))
    end
end

local function viewDropdown(host, width)
    local dd = NS.MakeDropdown(host, width)
    if not dd then return nil end
    dd:SetMulti(true)
    dd:SetOptions(FB.ViewOptions("group"))
    dd.onMultiSelect = function(set)
        if not syncing then FB.Set(activeTab(), "view", copySet(set)) end
    end
    NS.Window.AttachTooltip(dd, function() return unpack(FB.ViewTip(activeTab())) end, "above")
    return dd
end

-- The Character menu's rows on one tab (FB2-6): History lists every recorder in the log in force,
-- the session tabs only you. The bar syncs on every repaint, so the rows are built once per scope
-- and kept while your key and the log's groups table are the same ones (a test mode or simulation
-- log in force is another table); FB.InvalidateChars drops History's on HistoryChanged.
local NO_GROUPS = {}
local charRows = {}     -- [scope] = { key, groups, rows }

-- A tab's Character scope and the log its rows come from: `session` lists you alone.
local function charSource(tab)
    if (FB.HONORS[tab] or ALL).charScope == "session" then return "session", NO_GROUPS end
    return "history", NS.History.Groups()
end

local function charOptions(tab)
    local me = CF.Recorder()
    local key, class = me and me.key, me and me.class
    local scope, groups = charSource(tab)
    local c = charRows[scope]
    if c and c.key == key and c.groups == groups then return c.rows end
    local rows = CF.Options(CF.Characters(groups, key, class), key, NS.Compat.ClassColor)
    charRows[scope] = { key = key, groups = groups, rows = rows }
    return rows
end

FB.CharOptions = charOptions

--- Drop the History tab's cached Character rows: its log changed (HistoryChanged), so a recorder
--- may have come or gone.
function FB.InvalidateChars() charRows.history = nil end

local function charDropdown(host, width)
    local dd = NS.MakeDropdown(host, width)
    if not dd then return nil end
    dd:SetMulti(true)
    dd:SetOptions(charOptions("group"))
    -- Current is a preset (Loot History's): it selects exactly you, never itself.
    dd.presets = { [CF.CURRENT] = function(self) self._selected = CF.Canonical({ [CF.CURRENT] = true }, CF.CurrentKey()) end }
    dd.onMultiSelect = function(set)
        if not syncing then FB.Set(activeTab(), "char", copySet(set)) end
    end
    NS.Window.AttachTooltip(dd, grayedTip("char", TIPS.char), "above")
    return dd
end

local function pickDropdown(host, key, width)
    local dd = NS.MakeDropdown(host, width)
    if not dd then return nil end
    dd:SetOptions(key == "content" and contentOptions("group") or options(key))
    dd.onSelect = function(v) FB.Set(activeTab(), key, v) end
    NS.Window.AttachTooltip(dd, grayedTip(key, TIPS[key]), "above")
    return dd
end

local function qualityDropdown(host, width)
    local dd = NS.MakeDropdown(host, width)
    if not dd then return nil end
    local opts = {}
    for _, mode in ipairs(C.QUALITY_MODES) do opts[#opts + 1] = { value = mode, label = QUALITY_MODE_LABEL[mode] } end
    dd:SetOptions(opts)
    dd.onSelect = function(mode)
        NS.SetQualityMode(mode)
        FB.Sync(activeTab())
    end
    NS.Window.AttachTooltip(dd, function()
        if not FB.HONORS[activeTab()].quality then return L["Quality"], grayedRow() end
        return qualityTip()
    end, "above")
    return dd
end

-- ── the flat skin: Ka0s Loot History's filter bar, side by side (ui spec §2, FB-5) ──────────
-- The search box is built the way ../LootHistory/modules/BrowserFilterBar.lua builds its own: a
-- BackdropTemplate frame with a square 1px WHITE8X8 border, the same fill and line as
-- LibKa0s-Widgets-1.0's dropdown beside it, so every control on the bar is one skin. LibKa0s has no
-- flat search box yet; the shared need is LibKa0s#52.
local FLAT = {
    edge  = "Interface\\Buttons\\WHITE8X8",
    fill  = { 0.1, 0.1, 0.12, 0.9 },
    line  = { 0.24, 0.24, 0.27, 0.9 },
    hover = { 1, 0.82, 0, 0.9 },       -- the gold Loot History lights a bar control with
}
FB.FLAT = FLAT

local function flatSkin(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile = FLAT.edge, edgeFile = FLAT.edge, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    f:SetBackdropColor(unpack(FLAT.fill))
    f:SetBackdropBorderColor(unpack(FLAT.line))
end

local function lineColor(f, c)
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(c)) end
end

local function buildSearch(host)
    local eb = CreateFrame("EditBox", nil, host, "BackdropTemplate")
    eb:SetSize(180, K.CONTROL_H)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextInsets(6, 6, 0, 0)
    flatSkin(eb)
    eb.hint = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    eb.hint:SetPoint("LEFT", eb, "LEFT", 6, 0)
    eb.hint:SetText(L["Filter looter or item…"])
    eb:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.hint:SetShown(text == "")
        if not syncing then FB.Set(activeTab(), "search", text) end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(self) lineColor(self, FLAT.hover) end)
    eb:SetScript("OnEditFocusLost", function(self) lineColor(self, FLAT.line) end)
    NS.Window.AttachTooltip(eb, grayedTip("search", TIPS.search), "above")
    return eb
end

-- Left to right: View, Quality, Content, Character; the search box on the right.
local WIDTH = { view = 132, quality = 190, content = 172, char = 168 }
local GAP = 8   -- Loot History's gap between filter-bar controls

-- The order the controls sit in, left to right.
local ROW = { "view", "quality", "content", "char" }

--- Build the bar's controls on `host` (the window's filter-bar frame). Once per window.
--- @param host table
function FB.Build(host)
    controls = { host = host }
    controls.view = viewDropdown(host, WIDTH.view)
    controls.quality = qualityDropdown(host, WIDTH.quality)
    controls.content = pickDropdown(host, "content", WIDTH.content)
    controls.char = charDropdown(host, WIDTH.char)
    controls.search = buildSearch(host)
    FB.Anchor()
end

--- Put every control at its place on the bar, left to right, then the search box from the bar's gap
--- after the last of them to the bar's right edge, with its full hint (the build, and the full
--- layout taking them back from the compact Filters panel, modules/CompactChrome.lua). Both its edges
--- are anchored, so it widens and narrows with the window, live while sizing (feedback-4 spec §4).
function FB.Anchor()
    local host = controls.host
    if not host then return end
    local prev
    for _, key in ipairs(ROW) do
        local w = controls[key]
        if w then
            w:SetParent(host)
            w:ClearAllPoints()
            w:SetWidth(WIDTH[key])
            if prev then w:SetPoint("LEFT", prev, "RIGHT", GAP, 0) else w:SetPoint("LEFT", host, "LEFT", 0, 0) end
            prev = w
        end
    end
    local eb = controls.search
    eb:ClearAllPoints()
    if prev then eb:SetPoint("LEFT", prev, "RIGHT", GAP, 0) else eb:SetPoint("LEFT", host, "LEFT", 0, 0) end
    eb:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    eb.hint:SetText(L["Filter looter or item…"])
end

--- The search box's width in a full window `width` pixels wide: what the bar's controls and their
--- gaps leave between the last of them and the bar's right edge (FB.Anchor's two anchors give it
--- that width on screen; pure, for the suites).
--- @param width number|nil the window's width
--- @return number
function FB.SearchWidth(width)
    local used = 2 * K.INSET
    for _, key in ipairs(ROW) do
        if controls[key] or not controls.host then used = used + WIDTH[key] + GAP end
    end
    return math.max((tonumber(width) or K.WIDTH) - used, 0)
end

--- Fit the bar to the window's width: the search box spans what the controls leave (its anchors,
--- FB.Anchor), and hides only when that is too little to type in. The compact layout's anchors size
--- it there instead.
--- @param width number|nil the window's width
function FB.Layout(width)
    local eb = controls.search
    if not eb or NS.WindowCompact.Mode() == "compact" then return end
    local room = FB.SearchWidth(width)
    eb:SetWidth(room)   -- what the anchors give it; the headless suites read it
    eb:SetShown(room >= 80)
end

local function setHonored(w, on)
    if not w then return end
    w:SetEnabled(on)
    w:SetAlpha(on and 1 or 0.4)
end

-- The bar syncs on every repaint (performance-§9: the refresh pair's ceiling), so a dropdown is
-- written only when what it shows would change: its rows when they are another list, its selection
-- when it differs from the tab's.
local function putOptions(dd, rows)
    if dd._options ~= rows then dd:SetOptions(rows) end
end

local function putSelected(dd, set)
    if type(dd._selected) == "table" and sameSet(dd._selected, set) then return end
    dd:SetSelected(set)
end

-- A tab's View rows and presets never change: built once per tab.
local viewRows = {}     -- [tab] = { options, presets }

-- The View on one tab: its rows grayed where the tab does not use them, its selection the tab's.
local function putView(tab, st)
    local dd = controls.view
    if not dd then return end
    local c = viewRows[tab]
    if not c then
        c = { options = FB.ViewOptions(tab), presets = viewPresets(tab) }
        viewRows[tab] = c
    end
    dd.presets = c.presets
    putOptions(dd, c.options)
    putSelected(dd, st.view)
end

-- The Character dropdown on one tab: its rows (History's recorders, else you), its selection the
-- tab's, the CURRENT sentinel swapped for your key once it is known.
local function putChar(tab, st)
    local dd = controls.char
    if not dd then return end
    local current = CF.CurrentKey()
    if current and st.char[CF.CURRENT] then st.char = CF.Canonical(st.char, current) end
    putOptions(dd, charOptions(tab))
    putSelected(dd, st.char)
end

-- Write one tab's state onto the controls; their change handlers stand aside meanwhile.
local function putState(tab, st)
    syncing = true
    putView(tab, st)
    putChar(tab, st)
    if controls.content then
        putOptions(controls.content, contentOptions(tab))
        controls.content:SelectValue(st.content)
    end
    if controls.quality then
        local mode, _, label = FB.QualityReadout()
        controls.quality:SetValue(mode, label)
    end
    if (controls.search:GetText() or "") ~= st.search then controls.search:SetText(st.search) end
    controls.search.hint:SetShown(st.search == "")
    syncing = false
end

--- Put `tab`'s state on the controls, gray what it does not honor, and refresh the quality label.
--- @param tab string
function FB.Sync(tab)
    if not controls.host then return end
    putState(tab, FB.State(tab))
    local honors = FB.HONORS[tab]
    for _, key in ipairs(ROW) do setHonored(controls[key], honors[key] == true) end
    setHonored(controls.search, honors.search == true)
end

--- The built controls, for the suites: { view, quality, content, char, search, host }.
--- @return table
function FB.Controls() return controls end
