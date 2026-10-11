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
--   Settings.PageEditors.TemplatesTab  Messages › Templates: token chips, the four editors with
--                                      their live counters, the live preview and Reset templates.
--   Settings.PageEditors.WeightsTab    Comparison › Weights: a sub-strip of your class's specs,
--                                      then one slider per stat and the Pawn scale import box.
--   Settings.PageEditors.PrefsTab      Comparison › Preferences: the same sub-strip, then one
--                                      checkbox per item type your class's loot comes in.
--   Settings.PageEditors.QualityReadout  Feed › Quality's afterGroup: the threshold in force now.

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

-- ── Feed › Quality: the threshold in force now ──────────────────────────────────────────────

local function readoutText()
    local _, _, label = NS.WindowFilterBar.QualityReadout()
    local Sit = NS.Situations
    local cur = Sit.Current()
    local own = Sit.QualityOverride(cur) and NS.WindowFooter.SituationLabel(cur) or nil
    return E.ReadoutText(label, own)
end

--- The Quality tab's closing line: what the feed applies where you stand, repainted with every
--- write (the mode, the fixed minimum, the floor, or a situation's own setting).
--- @param ctx table
function P.QualityReadout(ctx)
    local w = H().TextRow(ctx, readoutText(), { fontObject = "GameFontHighlight" })
    if w then addRefresher(ctx, function() w:SetText(readoutText()) end) end
end

-- ── the spec sub-strip (Weights and Preferences) ────────────────────────────────────────────

local function classFile()
    local _, file = UnitClass("player")
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
    local host = h.AceGUI:Create("SimpleGroup")
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
            local box = h.AceGUI:Create("EditBox")
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

-- ── Comparison › Preferences ────────────────────────────────────────────────────────────────

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

--- Comparison › Preferences: the item types each spec never wants, written whole through the seam.
--- @param ctx table
function P.PrefsTab(ctx)
    local h = H()
    local spec = specStrip(ctx, L["Preferences"])
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

local function you()
    return { name = UnitName("player") or L["You"], guid = UnitGUID("player"), isSelf = true }
end

-- The drop a preview is written for: the feed on screen first, then test mode's placeholders.
local function sample(kind)
    local feed = NS.LootFeed.Drops(NS.State.testMode and "test" or nil)
    local rec, who = E.PreviewSample(kind, feed)
    if rec then return rec, who end
    return E.PreviewSample(kind, NS.TestMode.Placeholders(GetTime(), you()))
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
    local b = h.AceGUI:Create("Button")
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

--- Messages › Templates: the token chips, the four editors (Enter commits; the label counts as
--- you type), the preview of the template last edited over a real drop or a placeholder one, and
--- Reset templates.
--- @param ctx table
--- @param rows table the tab's schema rows (the four templates)
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
        tooltip = L["Put the four messages back to the shipped wording."],
        onClick = function() resetTemplates(rows or {}) end,
    })
end
