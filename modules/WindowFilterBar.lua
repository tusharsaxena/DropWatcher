local _, NS = ...
-- modules/WindowFilterBar.lua — the main window's filter bar (design spec §11.1, board 01): View,
-- Quality, Content and the search box, each tab's own filter state, and the pure predicates the
-- tabs' bodies filter and order their rows with.
--
-- ONE BAR, ONE STATE PER TAB. The bar is a single set of controls under the tab strip; each tab
-- keeps its own state (NS.State.windowFilters[tab], session-only), and selecting a tab puts its
-- state on the bar (Sync). A control a tab does not honor is grayed rather than hidden, so the bar
-- never reflows between tabs (Ka0s Loot History's pattern). A fresh tab's state is seeded from the
-- `feed.view.<value>`, `feed.content` and `feed.sort` rows (through the schema seam) when they hold
-- a valid value, else from DEFAULTS, which are those rows' defaults.
--
-- THE VIEW IS A SET (feedback-2 spec §1, FB2-1..3). Like Loot History's `Direction: 3 selected`
-- (../LootHistory/modules/BrowserFilterBar.lua) the View dropdown is multi-select: Interesting,
-- Likely tradeable, Usable by me and Upgrade for me combine as AND, and All (the empty set, the
-- default) clears them. The three checkboxes the bar had before are these values now. A tab grays
-- the values it does not use (History has no Likely tradeable: a kept drop's trade estimate is
-- long stale), and a grayed value neither toggles nor filters.
--
-- THE QUALITY CONTROL IS NOT A VIEW FILTER: it shows the feed's minimum-quality mode in force (the
-- situation's override, else `feed.quality.mode`) with its threshold, `Quality: Rare+` (design spec
-- §6.2), and choosing a mode goes through NS.SetQualityMode (core/DropWatcher.lua), the handler the
-- settings row shares. It is the same on every tab, and only the Group drops tab honors it.
--
-- PURE: IsInteresting, IsTradeableMine, Matches, HiddenBy, ViewLabel and Comparator take plain
-- tables and read nothing else, so the suites drive them case by case. Build, Sync and Layout are
-- the frame edge.
-- DEGRADED (no LibKa0s-Widgets-1.0): the three dropdowns are not drawn (core/WidgetsSetup.lua);
-- the search box still filters.

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

-- Each single-select control's values, in menu order.
FB.VALUES = {
    content = { "instance", "session", "all" },
    sort    = { "newest", "oldest", "ilvl", "gain" },
}

-- Which controls each tab honors (the footer's Sort included). `views` is the View values the tab
-- uses; the rest are grayed in its menu and ignored by its filter.
local ALL_VIEWS = { interesting = true, likely = true, usable = true, upgrade = true }
local ALL = { view = true, quality = true, content = true, search = true, sort = true, views = ALL_VIEWS }
FB.HONORS = {
    group   = ALL,
    mine    = { content = true, search = true, sort = true, views = {} },
    history = { view = true, content = true, search = true, sort = true,
                views = { interesting = true, usable = true, upgrade = true } },
}

local P = NS.C.PROFILE
local DEFAULTS = { view = {}, content = P.feed.content, search = "", sort = P.feed.sort }
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

-- The View tooltip's bullet lines (FB2-3): one per value, All first.
local VIEW_TIP = {
    { key = "all", text = L["All: every drop that passed the situation and quality gates."] },
    { key = "interesting", text = L["Interesting: an upgrade for you, or a drop its looter is likely to give away and that can be traded."] },
    { key = "likely", text = L["Likely tradeable: the trade estimate is yes or likely."] },
    { key = "usable", text = L["Usable by me: you can use it, and you have not marked its type as unwanted."] },
    { key = "upgrade", text = L["Upgrade for me: an upgrade over what you wear (or your best owned piece)."] },
}
local TIPS = {
    content = { L["Content"], L["This instance shows the drops since the situation last changed (entering an instance, starting a key). This session shows every drop since login. All shows every drop, and on the History tab the earlier sessions' too."] },
    search = { L["Search"], L["Show only the drops whose item or looter name contains this text."] },
}
local GRAYED = L["This tab does not use this filter."]
local GRAY = { 0.5, 0.5, 0.5 }

local controls = {}     -- the built controls: view, quality, content (each a dropdown or nil), search
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

local function valid(key, v)
    if key == "view" then return validView(v) end
    if key == "search" then return type(v) == "string" end
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

local function same(key, a, b)
    if key == "view" then return type(a) == "table" and sameSet(a, b) end
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

--- A fresh tab's state: DEFAULTS, overridden by each seed the profile holds a valid value for.
--- @return table
function FB.Defaults()
    local d = {}
    for k, v in pairs(DEFAULTS) do d[k] = v end
    d.view = seededView()
    for k, path in pairs(SEED) do
        local v = NS.Setting(path)
        if valid(k, v) then d[k] = v end
    end
    return d
end

--- A tab's filter state ({ view = { [value] = true }, content, search, sort }), seeded on first
--- use. The table is the bar's own: read it, and change it through Set.
--- @param tab string
--- @return table
function FB.State(tab)
    local all = State.windowFilters
    if not all then
        all = {}
        State.windowFilters = all
    end
    if not all[tab] then all[tab] = FB.Defaults() end
    return all[tab]
end

local function shown(key, value)
    if key ~= "view" then return tostring(value) end
    return FB.ViewLabel(value)
end

--- Change one control's value on one tab. An invalid value is refused; the window redraws the tab.
--- The View takes a set ({ [value] = true }, empty for All), stored as a copy.
--- @param tab string
--- @param key string `view`, `content`, `search` or `sort`
--- @param value any
--- @return boolean changed
function FB.Set(tab, key, value)
    if not valid(key, value) then return false end
    local st = FB.State(tab)
    if same(key, st[key], value) then return false end
    st[key] = key == "view" and copySet(value) or value
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
    if verdictOf(drop.me) == "upgrade" then return true end
    return LOOTER_GIVES[verdictOf(drop.them)] == true and TRADEABLE[state] == true
end

--- Whether a drop belongs in the Group drops table: someone else's always, your own only with
--- `feed.showOwn` on (design spec §6.3: off by default, own loot goes to My drops).
--- @param drop table
--- @param showOwn boolean|nil
--- @return boolean
function FB.InGroup(drop, showOwn)
    return type(drop) == "table" and (not drop.isMine or showOwn == true)
end

--- Your own drop whose trade estimate is `yes` or `likely` (the `My drops · n` count).
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
-- since ctx.sessionSince, which only the History tab sets (modules/WindowHistory.lua: a live feed
-- holds this session's drops alone); `all` passes every drop.
local function matchesContent(drop, content, ctx)
    local since
    if content == "instance" then since = ctx and ctx.instanceSince end
    if content == "session" then since = ctx and ctx.sessionSince end
    if type(since) ~= "number" or type(drop.at) ~= "number" then return true end
    return drop.at >= since
end

-- Your verdict that Usable by me hides: you can't use it, or your own preferences exclude it.
local NOT_USABLE = { cantUse = true, doesntWant = true }

-- Each View value's test: true when the drop passes it.
local VIEW_PASS = {
    interesting = function(d) return FB.IsInteresting(d) end,
    likely      = function(d) return TRADEABLE[tradeState(d)] == true end,
    usable      = function(d) return not NOT_USABLE[verdictOf(d.me)] end,
    upgrade     = function(d) return verdictOf(d.me) == "upgrade" end,
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

--- The first filter of a tab's state that hides a drop: a View value (`interesting`, `likely`,
--- `usable`, `upgrade`), `content` or `search`; nil when the drop passes them all. Only the
--- controls (and View values) the tab honors apply; anything not a drop answers `invalid`.
--- @param drop table
--- @param st table|nil the tab's state (DEFAULTS when nil)
--- @param ctx table|nil { instanceSince, sessionSince } (GetTime() seconds)
--- @param honors table|nil the tab's FB.HONORS row (every control when nil)
--- @return string|nil
function FB.HiddenBy(drop, st, ctx, honors)
    if type(drop) ~= "table" then return "invalid" end
    st, honors = st or DEFAULTS, honors or ALL
    local v = viewHides(drop, st.view, honors)
    if v then return v end
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
--- `View: Usable by me`, `Content: This instance`, `Search`.
--- @param key string|nil
--- @param st table|nil the tab's state
--- @return string
function FB.ReasonLabel(key, st)
    st = type(st) == "table" and st or DEFAULTS
    if FB.VIEW_NAMES[key] then return L["View: %s"]:format(FB.VIEW_NAMES[key]) end
    local byValue = FB.LABELS[key]
    if byValue and byValue[st[key]] then return byValue[st[key]] end
    local tip = TIPS[key]
    if tip then return tip[1] end
    return L["the filters"]
end

local function num(v) return type(v) == "number" and v or nil end
local function atOf(d) return num(d.at) or 0 end
local function ilvlOf(d) return type(d.facts) == "table" and num(d.facts.ilvl) or -math.huge end
local function gainOf(d) return type(d.me) == "table" and num(d.me.ilvlDelta) or -math.huge end

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
    return label, L["Drops below this quality are hidden from the feed unless they are an upgrade for you. A change applies to new drops."],
        L["Mode: %s"]:format(QUALITY_MODE_LABEL[mode] or mode)
end

-- ── the View's menu and tooltip ─────────────────────────────────────────────────────────────

local GRAY_CODE = "|cff808080"

--- The View tooltip on one tab (FB2-3): the title, then a bullet line per value, the ones the tab
--- does not use grayed and marked. A tab that uses no View says so instead.
--- @param tab string
--- @return table lines
function FB.ViewTip(tab)
    local honors = FB.HONORS[tab] or ALL
    if not honors.view then return { L["View"], GRAYED } end
    local out = { L["View"] }
    for _, line in ipairs(VIEW_TIP) do
        local text = "• " .. line.text
        if line.key ~= "all" and not honors.views[line.key] then
            text = GRAY_CODE .. text .. " " .. L["(not on this tab)"] .. "|r"
        end
        out[#out + 1] = text
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

local function options(key)
    local out = {}
    for _, v in ipairs(FB.VALUES[key]) do out[#out + 1] = { value = v, label = FB.LABELS[key][v] } end
    return out
end

local function activeTab() return NS.Window.ActiveTab() end

local function grayedTip(key, lines)
    return function()
        if not FB.HONORS[activeTab()][key] then return lines[1], GRAYED end
        return unpack(lines)
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
    NS.Window.AttachTooltip(dd, function() return unpack(FB.ViewTip(activeTab())) end)
    return dd
end

local function pickDropdown(host, key, width)
    local dd = NS.MakeDropdown(host, width)
    if not dd then return nil end
    dd:SetOptions(options(key))
    dd.onSelect = function(v) FB.Set(activeTab(), key, v) end
    NS.Window.AttachTooltip(dd, grayedTip(key, TIPS[key]))
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
        if not FB.HONORS[activeTab()].quality then return L["Quality"], GRAYED end
        return qualityTip()
    end)
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
    NS.Window.AttachTooltip(eb, grayedTip("search", TIPS.search))
    return eb
end

-- Left to right: View, Quality, Content; the search box on the right.
local WIDTH = { view = 132, quality = 190, content = 172 }
local GAP = 8   -- Loot History's gap between filter-bar controls

-- The order the controls sit in, left to right.
local ROW = { "view", "quality", "content" }

--- Build the bar's controls on `host` (the window's filter-bar frame). Once per window.
--- @param host table
function FB.Build(host)
    controls = { host = host }
    controls.view = viewDropdown(host, WIDTH.view)
    controls.quality = qualityDropdown(host, WIDTH.quality)
    controls.content = pickDropdown(host, "content", WIDTH.content)
    controls.search = buildSearch(host)
    local prev
    for _, key in ipairs(ROW) do
        local w = controls[key]
        if w then
            if prev then w:SetPoint("LEFT", prev, "RIGHT", GAP, 0) else w:SetPoint("LEFT", host, "LEFT", 0, 0) end
            prev = w
        end
    end
    controls.search:SetPoint("RIGHT", host, "RIGHT", 0, 0)
end

--- Fit the bar to the window's width: the search box takes what the controls leave, and hides when
--- that is too little to type in.
--- @param width number|nil the window's width
function FB.Layout(width)
    local eb = controls.search
    if not eb then return end
    local used = 2 * K.INSET
    for _, key in ipairs(ROW) do
        if controls[key] then used = used + GAP + WIDTH[key] end
    end
    local room = (tonumber(width) or K.WIDTH) - used
    eb:SetWidth(math.min(220, math.max(room, 0)))
    eb:SetShown(room >= 80)
end

local function setHonored(w, on)
    if not w then return end
    w:SetEnabled(on)
    w:SetAlpha(on and 1 or 0.4)
end

-- The View on one tab: its rows grayed where the tab does not use them, its selection the tab's.
local function putView(tab, st)
    local dd = controls.view
    if not dd then return end
    dd.presets = viewPresets(tab)
    dd:SetOptions(FB.ViewOptions(tab))
    dd:SetSelected(st.view)
end

-- Write one tab's state onto the controls; their change handlers stand aside meanwhile.
local function putState(tab, st)
    syncing = true
    putView(tab, st)
    if controls.content then controls.content:SelectValue(st.content) end
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

--- The built controls, for the suites: { view, quality, content, search, host }.
--- @return table
function FB.Controls() return controls end
