local _, NS = ...
-- modules/WindowFilterBar.lua — the main window's filter bar (design spec §11.1, board 01): View,
-- Quality, Content, Likely tradeable only and the search box, each tab's own filter state, and the
-- pure predicates the tabs' bodies filter and order their rows with.
--
-- ONE BAR, ONE STATE PER TAB. The bar is a single set of controls under the tab strip; each tab
-- keeps its own state (NS.State.windowFilters[tab], session-only), and selecting a tab puts its
-- state on the bar (Sync). A control a tab does not honor is grayed rather than hidden, so the bar
-- never reflows between tabs (Ka0s Loot History's pattern). A fresh tab's state is seeded from the
-- profile's `feed.view`, `feed.content`, `feed.sort` and `trade.likelyOnly` when they hold a valid
-- value (the rows DW-40 adds), else from DEFAULTS.
--
-- THE QUALITY CONTROL IS NOT A VIEW FILTER: it shows the feed's minimum-quality mode in force (the
-- situation's override, else `feed.quality.mode`) with its threshold, `Quality: Rare+` (design spec
-- §6.2), and choosing a mode goes through NS.SetQualityMode (core/DropWatcher.lua), the handler the
-- settings row shares. It is the same on every tab, and only the Group drops tab honors it.
--
-- PURE: IsInteresting, IsTradeableMine, Matches and Comparator take plain tables and read nothing
-- else, so test_window drives them case by case. Build, Sync and Layout are the frame edge.
-- DEGRADED (no LibKa0s-Widgets-1.0): the three dropdowns are not drawn (core/WidgetsSetup.lua);
-- the checkbox and the search box still filter.

NS.WindowFilterBar = NS.WindowFilterBar or {}
local FB    = NS.WindowFilterBar
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State

-- Each control's values, in menu order.
FB.VALUES = {
    view    = { "interesting", "all" },
    content = { "instance", "session", "all" },
    sort    = { "newest", "oldest", "ilvl", "gain" },
}

-- Which controls each tab honors (the footer's Sort included).
local ALL = { view = true, quality = true, content = true, likelyOnly = true, search = true, sort = true }
FB.HONORS = {
    group   = ALL,
    mine    = { content = true, search = true, sort = true },
    history = { view = true, content = true, search = true, sort = true },
}

local DEFAULTS = { view = "interesting", content = "instance", likelyOnly = false, search = "", sort = "newest" }
FB.DEFAULTS = DEFAULTS

-- Where a fresh tab's state is seeded from: { profile section, key }.
local SEED = {
    view = { "feed", "view" }, content = { "feed", "content" }, sort = { "feed", "sort" },
    likelyOnly = { "trade", "likelyOnly" },
}

FB.LABELS = {
    view = { interesting = L["View: Interesting"], all = L["View: All"] },
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
local TIPS = {
    view = { L["View"], L["Interesting shows the drops that are an upgrade for you and that their looter may still trade, and your own drops you can trade. All shows everything."] },
    content = { L["Content"], L["This instance shows the drops since the situation last changed (entering an instance, starting a key). This session shows every drop since login. All includes the history."] },
    likelyOnly = { L["Likely tradeable only"], L["Hide the drops whose trade estimate is Unknown or No."] },
    search = { L["Search"], L["Show only the drops whose item or looter name contains this text."] },
}
local GRAYED = L["This tab does not use this filter."]

local controls = {}     -- the built controls: view, quality, content (each a dropdown or nil), likelyOnly, search
local syncing = false   -- Sync is writing the controls: their change handlers stand aside

-- ── state ───────────────────────────────────────────────────────────────────────────────────

local function inList(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function valid(key, v)
    if key == "likelyOnly" then return type(v) == "boolean" end
    if key == "search" then return type(v) == "string" end
    return FB.VALUES[key] ~= nil and inList(FB.VALUES[key], v)
end

local function stored(section, key)
    local p = NS.db and NS.db.profile
    local t = p and p[section]
    if type(t) ~= "table" then return nil end
    return t[key]
end

--- A fresh tab's state: DEFAULTS, overridden by each seed the profile holds a valid value for.
--- @return table
function FB.Defaults()
    local d = {}
    for k, v in pairs(DEFAULTS) do d[k] = v end
    for k, path in pairs(SEED) do
        local v = stored(path[1], path[2])
        if valid(k, v) then d[k] = v end
    end
    return d
end

--- A tab's filter state ({ view, content, likelyOnly, search, sort }), seeded on first use. The
--- table is the bar's own: read it, and change it through Set.
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

--- Change one control's value on one tab. An invalid value is refused; the window redraws the tab.
--- @param tab string
--- @param key string `view`, `content`, `likelyOnly`, `search` or `sort`
--- @param value any
--- @return boolean changed
function FB.Set(tab, key, value)
    if not valid(key, value) then return false end
    local st = FB.State(tab)
    if st[key] == value then return false end
    st[key] = value
    NS.Debug("UI", "filter %s.%s = %s", tab, key, tostring(value))
    NS.Window.OnFilterChanged(tab)
    return true
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

-- `instance`: the drops since the situation last changed (ctx.instanceSince); `session` and `all`
-- pass every live drop (History, DW-51, tells its earlier sessions apart with ctx.sessionSince).
local function matchesContent(drop, content, ctx)
    local since
    if content == "instance" then since = ctx and ctx.instanceSince end
    if content == "session" then since = ctx and ctx.sessionSince end
    if type(since) ~= "number" or type(drop.at) ~= "number" then return true end
    return drop.at >= since
end

-- Each control's test, in the order Matches asks them: true when the drop passes it.
local CHECKS = {
    { key = "view", pass = function(d, st) return st.view ~= "interesting" or FB.IsInteresting(d) end },
    { key = "likelyOnly", pass = function(d, st) return not st.likelyOnly or TRADEABLE[tradeState(d)] == true end },
    { key = "content", pass = function(d, st, ctx) return matchesContent(d, st.content, ctx) end },
    { key = "search", pass = function(d, st) return matchesSearch(d, st.search) end },
}

--- Whether a drop passes a tab's filter. Only the controls the tab honors apply.
--- @param drop table
--- @param st table|nil the tab's state (DEFAULTS when nil)
--- @param ctx table|nil { instanceSince, sessionSince } (GetTime() seconds)
--- @param honors table|nil the tab's FB.HONORS row (every control when nil)
--- @return boolean
function FB.Matches(drop, st, ctx, honors)
    if type(drop) ~= "table" then return false end
    st, honors = st or DEFAULTS, honors or ALL
    for _, c in ipairs(CHECKS) do
        if honors[c.key] and not c.pass(drop, st, ctx) then return false end
    end
    return true
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

local function viewDropdown(host, key, width)
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

local function buildCheck(host)
    local cb = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
    cb:SetSize(K.CONTROL_H + 2, K.CONTROL_H + 2)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(L["Likely tradeable only"])
    cb:SetScript("OnClick", function(self)
        if not syncing then FB.Set(activeTab(), "likelyOnly", self:GetChecked() and true or false) end
    end)
    NS.Window.AttachTooltip(cb, grayedTip("likelyOnly", TIPS.likelyOnly))
    return cb
end

local function buildSearch(host)
    local eb = CreateFrame("EditBox", nil, host, "InputBoxTemplate")
    eb:SetSize(180, K.CONTROL_H)
    eb:SetAutoFocus(false)
    eb.hint = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    eb.hint:SetPoint("LEFT", eb, "LEFT", 4, 0)
    eb.hint:SetText(L["Filter looter or item…"])
    eb:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.hint:SetShown(text == "")
        if not syncing then FB.Set(activeTab(), "search", text) end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    NS.Window.AttachTooltip(eb, grayedTip("search", TIPS.search))
    return eb
end

-- Left to right: View, Quality, Content, the checkbox; the search box on the right.
local WIDTH = { view = 132, quality = 190, content = 172 }
local GAP = 6

--- Build the bar's controls on `host` (the window's filter-bar frame). Once per window.
--- @param host table
function FB.Build(host)
    controls = { host = host }
    controls.view = viewDropdown(host, "view", WIDTH.view)
    controls.quality = qualityDropdown(host, WIDTH.quality)
    controls.content = viewDropdown(host, "content", WIDTH.content)
    controls.likelyOnly = buildCheck(host)
    controls.search = buildSearch(host)
    local prev
    for _, key in ipairs({ "view", "quality", "content", "likelyOnly" }) do
        local w = controls[key]
        if w then
            if prev then w:SetPoint("LEFT", prev, "RIGHT", GAP, 0) else w:SetPoint("LEFT", host, "LEFT", 0, 0) end
            prev = key == "likelyOnly" and w.label or w
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
    local used = 150 + 4 * GAP + 2 * K.INSET
    for key, w in pairs(WIDTH) do if controls[key] then used = used + w end end
    local room = (tonumber(width) or K.WIDTH) - used
    eb:SetWidth(math.min(220, math.max(room, 0)))
    eb:SetShown(room >= 80)
end

local function setHonored(w, on)
    if not w then return end
    w:SetEnabled(on)
    w:SetAlpha(on and 1 or 0.4)
end

-- Write one tab's state onto the controls; their change handlers stand aside meanwhile.
local function putState(st)
    syncing = true
    if controls.view then controls.view:SelectValue(st.view) end
    if controls.content then controls.content:SelectValue(st.content) end
    if controls.quality then
        local mode, _, label = FB.QualityReadout()
        controls.quality:SetValue(mode, label)
    end
    controls.likelyOnly:SetChecked(st.likelyOnly)
    if (controls.search:GetText() or "") ~= st.search then controls.search:SetText(st.search) end
    controls.search.hint:SetShown(st.search == "")
    syncing = false
end

--- Put `tab`'s state on the controls, gray what it does not honor, and refresh the quality label.
--- @param tab string
function FB.Sync(tab)
    if not controls.host then return end
    putState(FB.State(tab))
    local honors = FB.HONORS[tab]
    for _, key in ipairs({ "view", "quality", "content", "likelyOnly", "search" }) do
        setHonored(controls[key], honors[key] == true)
    end
end

--- The built controls, for the suites: { view, quality, content, likelyOnly, search, host }.
--- @return table
function FB.Controls() return controls end
