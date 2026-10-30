local _, NS = ...
-- settings/PageEditors.lua — the widgets of the settings pages' own editors (design spec §12.2).
--
-- Drawn through the library's own seams, never a panel of their own: a host tab handed to
-- RenderTabbedSchema (`opts.tabs`, keyed by the group it draws, so the strip stays one tab per
-- group) or an `afterGroup` hook. What each shows and writes is settings/Editors.lua's, pure; this
-- file only lays widgets out and wires them. Every write goes through the schema seam, so the CLI,
-- the resets and the window see it as they see a checkbox; every widget drawn here has its refresher
-- on the page's list (options-ui-§11), and nothing is left on a pooled widget's frame (§19).
--
--   Settings.PageEditors.TemplatesTab  Messages › Templates: token chips, the five editors with
--                                      their live counters, the live preview and Reset templates.
--   Settings.PageEditors.WeightsTab    Comparison › Weights: a sub-strip of your class's specs,
--                                      then one slider per stat and the Pawn scale import box.
--   Settings.PageEditors.PrefsTab      Comparison › Unwanted types: the same sub-strip, then one
--                                      checkbox per item type your class's loot comes in.
--   Settings.PageEditors.QualityReadout  Drops › Quality's afterGroup: the threshold in force now,
--                                      and where a situation's own setting overrides it.
--   Settings.PageEditors.ClearHistoryButton  Drops › Retention: Clear history, beside Keep history
--                                      for (pairWith; feedback-15 spec §3, DW-Q3).
--   Settings.PageEditors.ColumnsNote   Window's chrome: on the Columns tab, the table they change.
--   Settings.PageEditors.SituationTable  Drops › Situations' afterGroup: one table line per situation
--                                      (Track, Auto-open, Quality, Loot rule), pooled for the session;
--                                      ParkSituationTable takes it off its placeholder before a render.

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L
local K        = NS.Constants
local E        = Settings.Editors

local P = {}
Settings.PageEditors = P

local WEIGHTS_PATH   = "comparison.weights"
local UNDESIRED_PATH = "comparison.undesired"

local function H() return Settings.Helpers end

local function set(path, value) return NS.SchemaRuntime.Set(path, value) end

local function addRefresher(ctx, fn)
    ctx.refreshers[#ctx.refreshers + 1] = fn
end

-- Every AceGUI widget this file acquires itself, painted for this addon's skin (skinning-§3).
-- H().AceGUI is normally the Options instance's owner proxy, which paints on Create already; the
-- explicit NS.SkinPaintAce repaints in place for the same owner, so a widget is painted whichever
-- handle made it. Nothing is painted while the Scope's Ignore settings panel is on, and the release
-- hands the widget back to AceGUI's shared pool stock (the library chains its restore onto the
-- widget's own OnRelease).
local function acquire(wtype)
    local w = H().AceGUI:Create(wtype)
    NS.SkinPaintAce(w)
    return w
end

-- ── Drops › Quality: the threshold in force now ─────────────────────────────────────────────

local function readoutText()
    local _, _, label = NS.WindowFilterBar.QualityReadout()
    local Sit = NS.Situations
    local cur = Sit.Current()
    local own = Sit.QualityOverride(cur) and NS.WindowFooter.SituationLabel(cur) or nil
    return E.ReadoutText(label, own)
end

--- The Quality tab's closing lines: what the feed applies where you stand, repainted with every
--- write (the mode, the fixed minimum, the floor, or a situation's own setting), then where a
--- situation overrides it (feedback-24).
--- @param ctx table
function P.QualityReadout(ctx)
    local h = H()
    local w = h.TextRow(ctx, readoutText(), { fontObject = "GameFontHighlight" })
    if w then addRefresher(ctx, function() w:SetText(readoutText()) end) end
    h.TextRow(ctx, L["A situation can set a quality of its own: the Quality column on the Situations tab."],
        { fontObject = "GameFontHighlightSmall" })
end

-- ── Window › Columns: which table they apply to (feedback-24) ───────────────────────────────

--- The Window page's chrome (drawn under the strip, before the tab's rows): on the Columns tab
--- only, the one line that says which table the column checkboxes change.
--- @param ctx table
function P.ColumnsNote(ctx)
    if ctx.activeTab ~= L["Columns"] then return end
    local h = H()
    h.TextRow(ctx, L["The full layout's Drops table. History shows every column; the compact cards show every fact."],
        { fontObject = "GameFontHighlightSmall" })
    h.AddSpacer(h.EnsureScroll(ctx), 6)
end

-- ── Drops › Retention: Clear history (feedback-15 spec §3, DW-Q3) ───────────────────────────

--- Keep history for's right half (the flow engine's pairWith seam, options-ui-§6): Clear history,
--- an action rather than a setting, so no schema row. A cell-filling button takes the library's
--- inset width rather than a flush half. Its confirmation is the History module's (H.AskClear),
--- which clears test mode's or a simulation's session-only log while one is on.
--- @param line table the flow line Keep history for sits alone on
function P.ClearHistoryButton(_, line)
    local h = H()
    local b = acquire("Button")
    b:SetText(L["Clear history"])
    b:SetRelativeWidth(h.BUTTON_PAIR_REL)
    b:SetCallback("OnClick", function() NS.History.AskClear() end)
    h.AttachTooltip(b, L["Clear history"], L["Empty the drop history on every character, after a confirmation."])
    line:AddChild(b)
    return b
end

-- ── Situations: the situations table ────────────────────────────────────────────────────────
--
-- Ka0s Loot History's Price sources table (its settings/Panel.lua buildAuctionTable), without the
-- drag handle, the reorder list and the status column: gold column headers in a band above fixed-
-- height rows, every second row striped as the window's tables are, the cells' text in
-- GameFontHighlightSmall, the panel's own CheckBox and Dropdown widgets. No hover highlight, as there.
-- Five columns since feedback-24 added the loot rule, so the cells sit closer than the four did.
-- Measured since DW-02 (owner ruling D-18, image-38): the Loot rule dropdown ran past the panel's
-- scroll gutter (it ended at 610 units, about 600 usable), so the columns moved left and Quality
-- narrowed to Loot rule's 150: the table ends at 574, with room to spare in every skin's face. The
-- longest label, "Follower dungeon", still clears Track, and "Auto-open" clears Quality.

local SIT_COL = { situation = 8, track = 128, autoOpen = 188, quality = 262, rule = 424 }
local SIT_QUALITY_W, SIT_RULE_W = 150, 150
local SIT_TABLE_W = 576   -- the table's right edge: the Loot rule cell's, plus 2
-- Published for the suite (tests/test_settings_pages.lua holds the fit).
P.SIT_COL, P.SIT_TABLE_W = SIT_COL, SIT_TABLE_W
P.SIT_WIDTHS = { quality = SIT_QUALITY_W, rule = SIT_RULE_W }
local SIT_ROW_H, SIT_HEAD_H, SIT_HEAD_Y = 28, 30, -6
-- The colors are the skin's (the table is a raw frame the page owns, built once a session, so each
-- paint is recorded with NS.SkinPaint and follows a skin switch without a re-render): the headers in
-- `text.headingAlt` (Loot History's header gold), a label in `text.bodyAlt` live and `text.disabled`
-- inactive (its label grays), a stripe `list.stripe`. Ka0s Default: exactly the values typed before.
-- Read through NS.SkinPanelColor, so with the Scope's Ignore settings panel on they draw Ka0s
-- Default's, as the table's own CheckBox and Dropdown cells go back stock (SetIgnore fires
-- OnLooksChanged, so NS.SkinRepaint moves them live).
local function paintHeader(fs) fs:SetTextColor(NS.SkinPanelColor("text.headingAlt")) end
local function paintLabel(fs) fs:SetTextColor(NS.SkinPanelColor(fs.dwActive and "text.bodyAlt" or "text.disabled")) end
local function paintStripe(t) t:SetColorTexture(NS.SkinPanelColor("list.stripe")) end

local function situationEntries()
    return E.SituationRows(NS.SchemaRuntime.FindRow, NS.Setting, NS.WindowFooter.SituationLabel)
end

-- Repaint every slot from the stored values: the values, the dimmed label and the disabled cells.
local function paintSituations(t)
    for i, e in ipairs(situationEntries()) do
        local r = t.rows[i]
        r.label:SetText(e.label)
        r.label.dwActive = e.active and true or false
        NS.SkinPaint(r.label, paintLabel)
        r.track:SetValue(e.track.value == true)
        r.track:SetDisabled(not e.track.enabled)
        r.autoOpen:SetValue(e.autoOpen.value == true)
        r.autoOpen:SetDisabled(not e.autoOpen.enabled)
        r.quality:SetValue(e.quality.value)
        r.quality:SetDisabled(not e.quality.enabled)
        r.rule:SetValue(e.rule.value)
        r.rule:SetDisabled(not e.rule.enabled)
    end
end

-- A write through the seam, then the repaint (the seam's announce repaints too; this covers a
-- refused value, which announces nothing).
local function writeCell(t, path, value)
    set(path, value)
    paintSituations(t)
end

local function tipOf(path)
    local row = NS.SchemaRuntime.FindRow(path)
    return row and row.label, row and row.tooltip
end

local function situationCheck(t, rf, x, path)
    local h = H()
    local cb = acquire("CheckBox")
    cb:SetLabel("")
    cb.frame:SetParent(rf)
    cb.frame:ClearAllPoints()
    cb.frame:SetPoint("LEFT", rf, "LEFT", x, 0)
    cb.frame:SetWidth(26)
    cb.frame:Show()
    cb:SetCallback("OnValueChanged", function(_, _, v) writeCell(t, path, v and true or false) end)
    h.AttachTooltip(cb, tipOf(path))
    return cb
end

local function situationPick(t, rf, path, x, width)
    local h = H()
    local dd = acquire("Dropdown")
    dd:SetLabel("")
    local row = NS.SchemaRuntime.FindRow(path)
    local items, order = {}, {}
    for i, v in ipairs(row and row.values or {}) do items[v.value], order[i] = v.text, v.value end
    dd:SetList(items, order)
    dd:SetWidth(width)
    dd.frame:SetParent(rf)
    dd.frame:ClearAllPoints()
    dd.frame:SetPoint("LEFT", rf, "LEFT", x, 0)
    dd.frame:Show()
    dd:SetCallback("OnValueChanged", function(_, _, v) writeCell(t, path, v) end)
    h.AttachTooltip(dd, tipOf(path))
    return dd
end

-- The Situation cell: its text, and a mouse target over it for the situation's tooltip.
local function situationLabel(rf, key)
    local fs = rf:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", rf, "LEFT", SIT_COL.situation, 0)
    fs:SetJustifyH("LEFT")
    local hit = CreateFrame("Frame", nil, rf)
    hit:SetPoint("TOPLEFT", rf, "TOPLEFT", SIT_COL.situation, 0)
    hit:SetPoint("BOTTOMRIGHT", rf, "BOTTOMLEFT", SIT_COL.track - 8, 0)
    hit:EnableMouse(true)
    H().AttachTooltip(hit, NS.WindowFooter.SituationLabel(key), nil)
    return fs
end

-- One slot, for the situation at index `i`: the slots follow K.SITUATIONS, so a slot's paths are
-- fixed and only its values and states are repainted.
local function situationSlot(t, i, key)
    local rf = CreateFrame("Frame", nil, t.host)
    local y = -(SIT_HEAD_H + (i - 1) * SIT_ROW_H)
    rf:SetPoint("TOPLEFT", t.host, "TOPLEFT", 0, y)
    rf:SetPoint("TOPRIGHT", t.host, "TOPRIGHT", 0, y)
    rf:SetHeight(SIT_ROW_H)
    local stripe = rf:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(rf)
    NS.SkinPaint(stripe, paintStripe)
    stripe:SetShown(i % 2 == 0)
    local base = "situations." .. key .. "."
    return {
        frame = rf, stripe = stripe, label = situationLabel(rf, key),
        track = situationCheck(t, rf, SIT_COL.track, base .. "track"),
        autoOpen = situationCheck(t, rf, SIT_COL.autoOpen, base .. "autoOpen"),
        quality = situationPick(t, rf, base .. "quality", SIT_COL.quality, SIT_QUALITY_W),
        rule = situationPick(t, rf, "trade.rules." .. key, SIT_COL.rule, SIT_RULE_W),
    }
end

local function situationHeader(host, x, text)
    local fs = host:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", host, "TOPLEFT", x, SIT_HEAD_Y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    NS.SkinPaint(fs, paintHeader)
    return fs
end

-- Every situations table built this session (one per Drops page; weak, so a collected one drops
-- out). Its CheckBox and Dropdown cells are acquired ONCE and parented to raw row frames, never
-- released, so the library's re-render on a skin switch never reaches them: the listener below
-- repaints each in the new skin, or hands it back stock when the Scope's Ignore settings panel is
-- turned on (a refused PaintAce restores what this owner painted).
local situationTables = setmetatable({}, { __mode = "k" })
local CELLS = { "track", "autoOpen", "quality", "rule" }

local function repaintSituationCells()
    for t in pairs(situationTables) do
        for _, r in ipairs(t.rows) do
            for _, key in ipairs(CELLS) do NS.SkinPaintAce(r[key]) end
        end
    end
end
if NS.Skin and NS.Skin.OnLooksChanged then NS.Skin.OnLooksChanged(repaintSituationCells) end

-- The host, its headers and its slots, once per session. A raw frame the page owns rather than an
-- AceGUI child: ClearScroll hands every scroll child back to AceGUI's pool on each render of the
-- tab, and the slots' widgets are parented to their rows, never to the scroll, so it reclaims none.
local function buildSituationTable(ctx)
    local t = { host = CreateFrame("Frame", nil, ctx.panel), rows = {} }
    situationTables[t] = true
    t.headers = {
        situationHeader(t.host, SIT_COL.situation, L["Situation"]),
        situationHeader(t.host, SIT_COL.track, L["Track"]),
        situationHeader(t.host, SIT_COL.autoOpen, L["Auto-open"]),
        situationHeader(t.host, SIT_COL.quality, L["Quality"]),
        situationHeader(t.host, SIT_COL.rule, L["Loot rule"]),
    }
    for i, s in ipairs(K.SITUATIONS) do t.rows[i] = situationSlot(t, i, s.key) end
    return t
end

--- Take the table off the placeholder it was hosted on and park it, hidden, on the panel. The
--- placeholder's OnRelease calls it (options-ui-§19, the canonical undo): a release hands the
--- placeholder back to AceGUI's pool, and a table left on it would ride the frame into whatever it
--- is handed out for next, on whichever tab is drawn. The Drops page's renderer also calls it
--- before its ClearScroll, belt-and-braces; parking twice is harmless.
--- @param ctx table
function P.ParkSituationTable(ctx)
    local t = ctx.dwSituations
    if not t then return end
    t.host:Hide()
    t.host:SetParent(ctx.panel)
    t.host:ClearAllPoints()
end

--- The Situations tab's afterGroup: the per-situation rows as one table, a line per situation
--- (Situation, Track, Auto-open, Quality, Loot rule). Built once and re-parented to a fresh
--- placeholder on each render of the tab; repainted on each render and after every write (a toggle, the global
--- Auto-open, Defaults, a profile switch).
--- @param ctx table
function P.SituationTable(ctx)
    local h = H()
    local scroll = h.EnsureScroll(ctx)
    if not scroll then return end
    h.AddSpacer(scroll, 4)
    local holder = acquire("SimpleGroup")
    holder:SetLayout(nil)
    holder:SetFullWidth(true)
    holder:SetHeight(SIT_HEAD_H + SIT_ROW_H * #K.SITUATIONS + 8)
    scroll:AddChild(holder)
    local t = ctx.dwSituations or buildSituationTable(ctx)
    ctx.dwSituations = t
    -- The undo of the reparent below, on the widget's own release (options-ui-§19). Guarded on the
    -- host still sitting on THIS placeholder, so an old one released late never pulls it off a new one.
    -- CHAINED onto the widget's OnRelease (NS.SkinOnRelease, the library's Skin:OnRelease) rather
    -- than taking AceGUI's one OnRelease callback, so this undo and the skin's restore both run.
    NS.SkinOnRelease(holder, function(w)
        if t.host:GetParent() == w.frame then P.ParkSituationTable(ctx) end
    end)
    t.host:SetParent(holder.frame)
    t.host:ClearAllPoints()
    t.host:SetAllPoints(holder.frame)
    t.host:Show()
    paintSituations(t)
    addRefresher(ctx, function() paintSituations(t) end)
end

-- ── the spec sub-strip (Weights and Unwanted types) ───────────────────────────────────────

local function classFile()
    local _, file = NS.Compat.UnitClass("player")
    return file
end

-- Draws the strip of your class's specs at the top of `tabKey`'s content and answers the spec it
-- shows. The selection is session state per primary tab (ctx.activeSubTab, options-ui-§13); a
-- click re-renders the page, which the library refuses in combat.
local function specStrip(ctx, tabKey)
    local h = H()
    local scroll = h.EnsureScroll(ctx)
    local list = E.ClassSpecs(classFile(), NS.Compat.SpecName)
    if not scroll or #list == 0 then return nil end
    ctx.activeSubTab = ctx.activeSubTab or {}
    local spec = E.PickSpec(list, ctx.activeSubTab[tabKey], NS.Compat.PlayerSpecID())
    ctx.activeSubTab[tabKey] = spec
    local host = acquire("SimpleGroup")
    host:SetLayout(nil)
    host:SetFullWidth(true)
    scroll:AddChild(host)
    local _, height = h.SubTabStrip(ctx, host.frame, {
        tabs = list, value = spec,
        onSelect = function(k)
            if k == ctx.activeSubTab[tabKey] then return end
            ctx.activeSubTab[tabKey] = k
            h.RefreshPanel(ctx, true)
        end,
    })
    host:SetHeight(height or 0)
    h.AddSpacer(scroll, 6)
    return spec
end

-- ── Comparison › Weights ────────────────────────────────────────────────────────────────────

local function weightRow(spec, stat)
    return {
        type = "number", min = E.WEIGHT_MIN, max = E.WEIGHT_MAX, step = E.WEIGHT_STEP,
        label = E.StatLabel(stat, _G),
        tooltip = L["What one point of this stat is worth to this specialization. 0 leaves it out."],
        get = function() return E.Weight(NS.Setting(WEIGHTS_PATH), spec, stat) end,
        set = function(v) set(WEIGHTS_PATH, E.WithWeight(NS.Setting(WEIGHTS_PATH), spec, stat, v)) end,
    }
end

local function specLabel(spec)
    local name = NS.Compat.SpecName(spec)
    return type(name) == "string" and name ~= "" and name or tostring(spec)
end

-- Enter in the import box: the pasted Pawn scale replaces this spec's weights through the seam,
-- the chat says what came in, and the page redraws its sliders.
local function importScale(ctx, spec, text, box)
    local map, result = NS.Scoring.ImportInto(NS.Setting(WEIGHTS_PATH), spec, text)
    NS.Print(E.ImportText(result, specLabel(spec)))
    if not map then return end
    set(WEIGHTS_PATH, map)
    box:SetText("")
    H().RefreshPanel(ctx, true)
end

local function importLine(spec)
    return {
        wide = true,
        make = function(ctx, into)
            local h = H()
            local box = acquire("EditBox")
            box:SetLabel(L["Import a Pawn scale"])
            box:SetFullWidth(true)
            box:SetCallback("OnEnterPressed", function(_, _, text) importScale(ctx, spec, text, box) end)
            h.AttachTooltip(box, L["Import a Pawn scale"],
                L["Paste a Pawn scale string and press Enter: it replaces this specialization's weights."])
            into:AddChild(box)
        end,
    }
end

--- Comparison › Weights: your weights per spec, written whole through the seam, and the box a
--- Pawn scale string is imported through (design spec §5.4).
--- @param ctx table
function P.WeightsTab(ctx)
    local h = H()
    local spec = specStrip(ctx, L["Weights"])
    if not spec then return end
    h.TextRow(ctx, L["Used when Score with is My weights, or Automatic without Pawn: a drop's score is each stat times its weight."],
        { fontObject = "GameFontHighlightSmall" })
    h.AddSpacer(h.EnsureScroll(ctx), 6)
    local items = {}
    for _, stat in ipairs(E.StatsFor(spec)) do items[#items + 1] = weightRow(spec, stat) end
    items[#items + 1] = importLine(spec)
    h.RenderGrid(ctx, items)
end

-- ── Comparison › Unwanted types ─────────────────────────────────────────────────────────────

local function undesiredRow(spec, choice)
    return {
        type = "bool", label = choice.label,
        tooltip = L["Never call a drop of this type an upgrade for this specialization."],
        get = function() return E.IsUndesired(NS.Setting(UNDESIRED_PATH), spec, choice.key) end,
        set = function(v)
            set(UNDESIRED_PATH, E.WithUndesired(NS.Setting(UNDESIRED_PATH), spec, choice.key, v))
        end,
    }
end

--- Comparison › Unwanted types: the item types each spec never wants, written whole through the seam.
--- @param ctx table
function P.PrefsTab(ctx)
    local h = H()
    local spec = specStrip(ctx, L["Unwanted types"])
    if not spec then return end
    h.TextRow(ctx, L["Ticked types are never called an upgrade for this specialization."],
        { fontObject = "GameFontHighlightSmall" })
    h.AddSpacer(h.EnsureScroll(ctx), 6)
    local items = {}
    for _, choice in ipairs(E.UndesiredChoices(classFile())) do items[#items + 1] = undesiredRow(spec, choice) end
    h.RenderGrid(ctx, items)
end

-- ── Messages › Templates ────────────────────────────────────────────────────────────────────

local function kindOf(row) return row.path:match("([^.]+)$") end

-- The drop a preview is written for: the feed on screen first, then test mode's samples.
local function sample(kind)
    local feed = NS.LootFeed.Drops(NS.State.testMode and "test" or nil)
    local rec, who = E.PreviewSample(kind, feed)
    if rec then return rec, who end
    return E.PreviewSample(kind, NS.TestMode.PreviewSpecs())
end

local CHANNEL_NAME = { INSTANCE_CHAT = L["Instance"], RAID = L["Raid"], PARTY = L["Party"] }

local function recipient(kind, who)
    if kind == "announce" then return CHANNEL_NAME[NS.Asks.AnnounceChannel()] end
    return who and who.name
end

-- The preview's lines for the template being edited: the box's live text when there is a box.
local function previewLines(st)
    local kind = st.ctx.dwTemplateKind
    local box = st.boxes[kind]
    local template = box and box:GetText() or NS.Setting("messages.templates." .. kind)
    local rec, who = sample(kind)
    return E.PreviewLines(kind, template, NS.Asks.TokenContext(kind, rec, who), recipient(kind, who))
end

local function paintPreview(st)
    local w = st.preview
    if not w then return end
    local lines = previewLines(st)
    w.header:SetText(lines.header)
    w.body:SetText(lines.body)
    w.status:SetText(lines.status)
end

-- The chip's insert: at the cursor of the template last edited (Ask until one is), written through
-- the seam at once.
local function insertToken(st, token)
    local kind = st.ctx.dwTemplateKind
    local box = st.boxes[kind]
    if not box then return end
    local edit = box.editbox
    if edit and edit.Insert then edit:Insert(token) else box:SetText((box:GetText() or "") .. token) end
    set("messages.templates." .. kind, box:GetText())
end

local function chip(h, st, name)
    local b = acquire("Button")
    local token = "{" .. name .. "}"
    b:SetText(token)
    b:SetRelativeWidth(0.13)
    b:SetCallback("OnClick", function() insertToken(st, token) end)
    h.AttachTooltip(b, token, E.TOKEN_TIPS[name])
    return b
end

local function chipsLine(st)
    return {
        wide = true,
        make = function(_, into)
            local h = H()
            for _, name in ipairs(K.MESSAGE_TOKENS) do into:AddChild(chip(h, st, name)) end
        end,
    }
end

local function editorLine(st, row)
    local kind = kindOf(row)
    return {
        wide = true,
        make = function(ctx, into)
            local box = H().RenderField(ctx, row, into)
            if not box then return false end
            st.boxes[kind] = box
            box:SetLabel(E.CounterLabel(kind, box:GetText()))
            box:SetCallback("OnTextChanged", function(_, _, text)
                st.ctx.dwTemplateKind = kind
                box:SetLabel(E.CounterLabel(kind, text))
                paintPreview(st)
            end)
            addRefresher(ctx, function() box:SetLabel(E.CounterLabel(kind, box:GetText())) end)
        end,
    }
end

local function previewBlock(ctx, st)
    local h = H()
    h.Section(ctx, L["Preview"])
    st.preview = {
        header = h.TextRow(ctx, "", { fontObject = "GameFontNormal" }),
        body   = h.TextRow(ctx, "", { fontObject = "GameFontHighlight" }),
        status = h.TextRow(ctx, "", { fontObject = "GameFontHighlightSmall" }),
    }
    if not (st.preview.header and st.preview.body and st.preview.status) then
        st.preview = nil
        return
    end
    paintPreview(st)
    addRefresher(ctx, function() paintPreview(st) end)
end

local function resetTemplates(rows)
    for _, row in ipairs(rows) do NS.SchemaRuntime.ApplyDefault(row) end
    local h = H()
    if h.RefreshScalars then h.RefreshScalars() end
end

--- Messages › Templates: the token chips, the five editors (Enter commits; the label counts as
--- you type), the preview of the template last edited over a real drop or a placeholder one, and
--- Reset templates.
--- @param ctx table
--- @param rows table the tab's schema rows (the five templates)
function P.TemplatesTab(ctx, rows)
    local h = H()
    -- Per render: the boxes this render drew. The template being edited (the chips' target and the
    -- preview's subject) is the page's session state, so a tab switch and back keeps it.
    ctx.dwTemplateKind = ctx.dwTemplateKind or "ask"
    local st = { ctx = ctx, boxes = {} }
    h.Section(ctx, L["Tokens"])
    h.TextRow(ctx, L["Click a token to put it in the message you last edited. Each is filled in when the message is sent."],
        { fontObject = "GameFontHighlightSmall" })
    h.RenderGrid(ctx, { chipsLine(st) })
    h.Section(ctx, L["Your messages"])
    local lines = {}
    for _, row in ipairs(rows or {}) do lines[#lines + 1] = editorLine(st, row) end
    h.RenderGrid(ctx, lines)
    previewBlock(ctx, st)
    h.InlineButtonPair(ctx, {
        text = L["Reset templates"],
        tooltip = L["Put the five messages back to the shipped wording."],
        onClick = function() resetTemplates(rows or {}) end,
    })
end
