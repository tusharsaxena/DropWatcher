local _, NS = ...
-- modules/WindowTitleBar.lua — the main window's title bar (design spec §11.1, boards 01, 06 A and
-- 06 E, as the owner's feedback spec §1 reshaped it to match Ka0s Loot History): the centered gold
-- title (no logo: the launcher and the TOC keep it), test mode's bright-red `TEST MODE` text, the
-- simulator's `SIM` text in its own color (simulator spec §6), each drawn only while minimized
-- or with no strip (the window's mode strips mark the mode otherwise), the `n new` counter, the
-- restriction badge, then the right-hand cluster: the lock button (RX-08, at the top right since
-- RX-14), the layout toggle (compact spec §1), minimize, the settings mark and the close mark, one
-- strip of LibKa0s-Widgets-1.0's HeaderButtons (TB.Marks, AD-86-DW, LibKa0s#86), which the Rolls
-- panel, the Offer panel and the Edit message box build theirs with too, plus the window's flat
-- button, which other frames borrow through NS.Window.TextButton (and paint through
-- NS.Window.SetButtonMark). Scan group is the Drops footer's mark in both layouts
-- (modules/DropsStrip.lua, feedback-7 spec §4, RX-24; compact's title-bar icon removed by feedback-16), and
-- the badge anchors to the lock button, the cluster's first.
--
-- Peeled out of modules/Window.lua (layout-§1's 1000-line notice band). The shell keeps everything
-- that writes state: geometry (the drag's start and stop come in as `host` callbacks), the
-- minimized flag, the `n new` count and the restriction reason, each read here through NS.Window's
-- public accessors at call time. BadgeText is PURE. Build and the Paint* functions are the frame
-- edge, called from the shell's build and its one repaint pass. The compact layout's title, words
-- and badge are modules/CompactChrome.lua's (compact spec §4), over these same controls.

NS.WindowTitleBar = NS.WindowTitleBar or {}
local TB = NS.WindowTitleBar
local K  = NS.Constants.WINDOW
local L  = NS.L

-- The restriction badge's words (design spec §11.1), keyed by RestrictionChanged's `reason`.
local REASON_LABEL = {
    encounter = L["Encounter"], challengeMode = L["Mythic+ key"], pvpMatch = L["PvP match"],
    chat = L["Chat restricted"], chatLockdown = L["Chat lockdown"], combat = L["Combat"],
}
-- Each restriction's rows (feedback-21): why, what it holds back, and what becomes of an ask.
local REASON_TIP = {
    encounter     = { { L["Why"], L["a boss encounter is in progress"] }, { L["Blocked"], L["whispers and inspects"] },
        { L["Asks"], L["wait in the queue, sent when it ends"] } },
    challengeMode = { { L["Why"], L["a Mythic+ key is running"] }, { L["Blocked"], L["addon chat"] },
        { L["Asks"], L["wait in the queue, sent when it ends"] } },
    pvpMatch      = { { L["Why"], L["a PvP match is in progress"] }, { L["Blocked"], L["addon chat"] },
        { L["Asks"], L["wait in the queue"] } },
    chat          = { { L["Why"], L["the client restricts addon chat"] }, { L["Asks"], L["wait in the queue, sent once it lifts"] } },
    chatLockdown  = { { L["Why"], L["chat messaging is locked down"] }, { L["Asks"], L["wait in the queue, sent once it lifts"] } },
    combat        = { { L["Why"], L["you are in combat"] }, { L["Waiting"], L["inspects and trades, until it ends"] },
        { L["Asks"], L["still sent"] } },
}
local KIND_LABEL = { ask = L["Ask"], offer = L["Offer"], announce = L["Announce"],
    askML = L["Ask the master looter"] }
local BADGE_LIST_MAX = 8

local lastTitleClick

-- ── pure labels ─────────────────────────────────────────────────────────────────────────────

--- The restriction badge's text: nil while nothing is restricted (the badge hides), else the
--- reason and, when asks wait, how many: `Encounter · 2 queued`.
--- @param reason string|nil RestrictionChanged's reason
--- @param queued number|nil
--- @return string|nil
function TB.BadgeText(reason, queued)
    if reason == nil then return nil end
    local label = REASON_LABEL[reason] or tostring(reason)
    local n = tonumber(queued) or 0
    if n > 0 then return L["%s · %d queued"]:format(label, n) end
    return label
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

local function queuedAsks()
    return NS.Asks and NS.Asks.Queued() or {}
end

local function badgeTooltip()
    local reason = NS.Window.RestrictionReason()
    local TM = NS.TipMarks
    local lines = { TB.BadgeText(reason, 0) or L["Not restricted"] }
    for _, r in ipairs(REASON_TIP[reason] or {}) do lines[#lines + 1] = TM.Row(r[1], r[2]) end
    local queued = queuedAsks()
    for i, a in ipairs(queued) do
        if i > BADGE_LIST_MAX then
            lines[#lines + 1] = TM.Row(L["Queued"], L["%d more"]:format(#queued - BADGE_LIST_MAX))
            break
        end
        lines[#lines + 1] = TM.Row(L["Queued"], L["%s to %s"]:format(KIND_LABEL[a.kind] or tostring(a.kind), tostring(a.target)))
    end
    return unpack(lines)
end

local function minimizeTip()
    local TM = NS.TipMarks
    if NS.Window.IsMinimized() then
        return L["Expand"], TM.Row(L["Shows"], L["the whole window again"]),
            TM.Hint(L["Double-clicking the title bar does the same."])
    end
    return L["Minimize"], TM.Row(L["Collapses"], L["the window to its title bar"]), TM.Row(L["Position"], L["kept"]),
        TM.Row(L["Counter"], L["the drops that arrive meanwhile"])
end

-- The lock button's tooltip (RX-08): what a click does, its verb and the setting it writes.
local function lockTip()
    local TM = NS.TipMarks
    if NS.Window.IsLocked() then
        return L["Unlock the window"], TM.Row(L["Lets"], L["it be dragged and resized again"]),
            TM.Row(L["Typed"], L["/dw unlock"]), TM.Row(L["Stored as"], L["Lock frame on General > Master controls"])
    end
    return L["Lock the window"], TM.Row(L["Keeps"], L["it from being dragged or resized"]),
        TM.Row(L["Typed"], L["/dw lock"]), TM.Row(L["Stored as"], L["Lock frame on General > Master controls"])
end

-- The layout toggle's tooltip: what a click switches to, and the setting that stores it.
local function modeTip()
    local WC, TM = NS.WindowCompact, NS.TipMarks
    local compact = WC.Mode() == "compact"
    local lines = compact
        and { L["Full view"], TM.Row(L["Shows"], L["the full window, every column of the drop tables"]),
            TM.Row(L["Typed"], L["/dw full"]) }
        or { L["Compact view"], TM.Row(L["Shows"], L["the window narrow, each drop a short card"]),
            TM.Row(L["Typed"], L["/dw compact"]) }
    lines[#lines + 1] = TM.Row(L["Stored as"], L["Window layout on Window > Layout > Mode"])
    if WC.InRun() then
        lines[#lines + 1] = TM.Row(L["Held compact"], L["until this run ends (Compact view when it auto-opens in a run)"])
    end
    return unpack(lines)
end

--- Scan group's tooltip, on the Drops footer's mark.
function TB.ScanTip()
    local TM = NS.TipMarks
    return L["Scan group"], TM.Row(L["Inspects"], L["every other member of your group"]),
        TM.Row(L["When"], L["one at a time, out of combat"]), TM.Row(L["So"], L["each drop is judged for its looter"])
end

local function newTip()
    return L["%d new"]:format(NS.Window.NewCount()), NS.TipMarks.Row(L["Arrived"], L["since you minimized the window"]),
        NS.TipMarks.Hint(L["Expand it to see them."])
end

--- Test mode's text color, the skin's test-mode red (Ka0s Default: Ka0s Loot History's bright red,
--- feedback spec §1, FB-3).
TB.TEST_TOKEN = "sem.modeTest"

--- The simulator's text color (simulator spec §6): the simulation strip's cyan at full opacity, its
--- rgb only (Ka0s Default 0.35, 0.80, 1.00), a cyan apart from every verdict tone.
TB.SIM_TOKEN = "strip.sim"

--- The gap between the title and a mode's text, as Ka0s Loot History sets it.
TB.MODE_GAP = 10

--- The SIM text's and the simulation strip's tooltip (simulator spec §6): the scenario and
--- what the simulation never does.
function TB.SimTip()
    local st = NS.SimHost.Status()
    local scenario = st.active and tostring(st.scenario) or L["none"]
    local TM = NS.TipMarks
    return L["SIM"],
        TM.Row(L["Scenario"], ("%s (%s)"):format(scenario, NS.WindowFooter.SituationLabel(st.situation))),
        TM.Row(L["Runs"], L["a made-up group session, through the real engine"]),
        TM.Row(L["Sent"], L["nothing"]), TM.Row(L["Your history"], L["not touched"]),
        TM.Hint(L["/dw sim lists its verbs; /dw sim stop ends it."])
end

--- Test mode's title text and banner (design spec §11.6, board 06 E) share one tooltip.
function TB.TestTip()
    local TM = NS.TipMarks
    return L["Test mode"],
        TM.Row(L["Shows"], L["sample drops of real items, in every state"]),
        TM.Row(L["Ask, Offer, Announce"], L["print in your chat frame, never sent"]),
        TM.Row(L["Ended by"], L["combat, /dw test, the launcher menu, Master controls"])
end

-- ── buttons ─────────────────────────────────────────────────────────────────────────────────

-- The mark for `icon` from the catalog, or `glyph` when the texture does not resolve.
local function setMark(b, icon, glyph)
    local path = NS.Icon(icon)
    b.art:SetTexture(path)
    b.art:SetShown(path ~= nil)
    b.glyph:SetText(glyph)
    b.glyph:SetShown(path == nil)
    b.mark = icon
end

--- A title-bar mark's rest and hover tokens (SR-DW, smoke round 1's ruling 4, LibKa0s SR-L3): every
--- title-bar control rests in the skin's `icon.tint` and lights `text.link` under the pointer, as
--- the library's own header marks do. The lock's state is its alpha and desaturation (PaintLock).
TB.MARK_REST, TB.MARK_HOT = "icon.tint", "text.link"

-- The mark's art and its glyph fallback in the rest or the hover token, read on every paint.
local function paintMark(b)
    local token = b.dwHot and TB.MARK_HOT or TB.MARK_REST
    b.art:SetVertexColor(NS.SkinColor(token))
    b.glyph:SetTextColor(NS.SkinColor(token))
end

local function markHot(b, on)
    b.dwHot = on
    paintMark(b)
end

local function iconButton(parent, icon, glyph, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(K.ICON, K.ICON)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.art:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    NS.Skin.Font(b.glyph)
    -- The mark (or its glyph) in TB.MARK_REST, TB.MARK_HOT under the pointer, repainted on a switch.
    NS.SkinPaint(b, paintMark)
    b:HookScript("OnEnter", function(self) markHot(self, true) end)
    b:HookScript("OnLeave", function(self) markHot(self, false) end)
    setMark(b, icon, glyph)
    b:SetScript("OnClick", onClick)
    return b
end

-- iconButton is the library-absent strip's mark (TB.Marks): the catalog's `icon` mark in
-- TB.MARK_REST (TB.MARK_HOT under the pointer), or `glyph` when the mark does not resolve; K.ICON
-- square. With the library, HeaderButtons builds the mark and TB.Marks gives it the same fields.

--- Change a title-bar extra's mark (TB.Marks): the catalog's `icon`, or `glyph` when it does not
--- resolve (the Rolls panel's toggle, RX-25; the minimize and layout marks).
--- @param b table an extra of TB.Marks
--- @param icon string a declared LibKa0s icon
--- @param glyph string the fallback text
TB.SetIconMark = setMark

-- The flat button's box is the skin's Button (FS-DW-FIX, cause A1), so `btn.borderStyle` and
-- `btn.borderSize` reach it, with the fill and edge remapped to the owner tokens `dw.btnBg` /
-- `dw.btnBorder` (Ka0s Default: today's 0.12 fill and the shared window edge's inner line). The
-- primitive does not know `b.label` or `b.art`, on purpose: they carry a state tone here (decision
-- D1, WindowGroup.ToneButton), so TB.PaintButtonLook draws them. paintTextButton is the degraded
-- arm's box, where S.Button draws nothing.
local BUTTON_OPTS = { tokens = { bg = "dw.btnBg", border = "dw.btnBorder" } }

local function paintTextButton(b)
    b:SetBackdropColor(NS.SkinColor("dw.btnBg"))
    b:SetBackdropBorderColor(NS.SkinColor("dw.btnBorder"))
end

--- An untoned flat button's look (cause L8): the label in `btn.text`, or `btn.hover` under the
--- pointer, the mark in `btn.icon`. A toned one is WindowGroup.ToneButton's, and keeps its tone
--- under the pointer (D1). Run at build, on the hover, on a skin switch and when a tone is dropped.
--- @param b table a TB.TextButton
function TB.PaintButtonLook(b)
    if b.tone then return end
    b.label:SetTextColor(NS.SkinColor(b.dwHot and "btn.hover" or "btn.text"))
    if b.art then b.art:SetVertexColor(NS.SkinColor("btn.icon")) end
end

local function buttonHot(b, on)
    b.dwHot = on
    TB.PaintButtonLook(b)
end

--- A flat button: the skin's fill and inner line, a label kept centered and a mark beside it
--- (standalone-windows: a wide action button keeps its label). NS.Window.TextButton is this. A
--- `scale` draws its height, mark, nudge and face that much larger (the upgrade toast's Ask, DW-05);
--- `width` is the caller's, already scaled.
--- @return table
function TB.TextButton(parent, width, icon, text, onClick, scale)
    scale = scale or 1
    local function px(n) return math.floor(n * scale + 0.5) end
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, px(K.CONTROL_H))
    local S = NS.SKIN
    if b.SetBackdrop and S.bgFile then
        b:SetBackdrop({ bgFile = S.bgFile, edgeFile = S.edgeFile, edgeSize = S.edgeSize })
        NS.SkinPaint(b, paintTextButton)
    end
    NS.Skin.Button(b, BUTTON_OPTS)
    b.markNudge = px(7)   -- the label's nudge right past the mark
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(px(12), px(12))
    b.art:SetPoint("LEFT", b, "LEFT", px(6), 0)
    b.art:SetTexture(NS.Icon(icon))
    b.label = NS.ScaledFontString(b, "OVERLAY", "GameFontHighlightSmall", scale)
    b.label:SetPoint("CENTER", b, "CENTER", b.markNudge, 0)
    NS.Skin.Font(b.label)   -- the skin's face; the color is the state's (WindowGroup.ToneButton)
    b.label:SetText(text)
    NS.SkinPaint(b.label, function() TB.PaintButtonLook(b) end)
    b:SetScript("OnClick", onClick)
    b:HookScript("OnEnter", function(self) buttonHot(self, true) end)
    b:HookScript("OnLeave", function(self) buttonHot(self, false) end)
    return b
end

--- A TextButton's label and catalog mark (feedback-7 spec §1): the text, the mark's texture (none
--- when `icon` is nil) and the label centered, nudged right past the mark when there is one. Every
--- button whose look follows a state paints through this. NS.Window.SetButtonMark is this.
--- @param b table a TB.TextButton
--- @param text string
--- @param icon string|nil a catalog name (NS.Icon)
function TB.SetButtonMark(b, text, icon)
    b.label:SetText(text)
    b.art:SetTexture(icon and NS.Icon(icon) or nil)
    b.art:SetShown(icon ~= nil)
    b.label:ClearAllPoints()
    b.label:SetPoint("CENTER", b, "CENTER", icon and (b.markNudge or 7) or 0, 0)
end

-- ── construction ────────────────────────────────────────────────────────────────────────────

-- The px a LEFT or RIGHT title stays clear of the bar's controls.
TB.TITLE_RESERVE = 8

-- What a LEFT or RIGHT title keeps clear of at each edge (RX-30), the table S.TitleBar's `place` is
-- given: the library re-reads it on every skin repaint, so NS.CompactChrome keeps it current (the
-- right-hand cluster, the badge beside it or, in compact, at the bar's left) and both agree.
TB.PLACE = { left = TB.TITLE_RESERVE, right = TB.TITLE_RESERVE }

local function widthOf(b)
    local w = b and b.GetWidth and b:GetWidth()
    return type(w) == "number" and w > 0 and w or K.ICON
end

-- ── the header marks (LibKa0s#86) ───────────────────────────────────────────────────────────

--- The strip's corner inset and its gap between marks: W.HEADER's PAD and GAP (6 and 6), which the
--- library-absent strip below keeps too.
TB.HEADER_PAD, TB.HEADER_GAP = 6, 6

-- The mark HeaderButtons built for an extra, given the fields iconButton's mark carries (`art`,
-- `glyph`, `mark`), so setMark, PaintLock and the TB.MARK_REST / TB.MARK_HOT paint keep working on
-- it: its art is the library's `icon` (or a hidden texture where the art did not resolve and the
-- library drew the glyph as its `label`), its glyph the library's `label` (or a hidden one).
--
-- Two paint paths, on purpose: the library's own OnEnter/OnLeave (and its skin-switch replay) paint
-- `icon` or `label` in `icon.tint` / `text.link`, and the host's paintMark below paints `art` and
-- `glyph` in TB.MARK_REST / TB.MARK_HOT. The host's path cannot go: setMark may show the hidden
-- texture or font string, which the library does not know. They agree because the host's tokens are
-- the library's (test_header_marks pins it), and both set only the color, so PaintLock's alpha and
-- desaturation survive either.
local function adoptMark(b, icon, glyph)
    if not b.art then
        b.art = b.icon or b:CreateTexture(nil, "ARTWORK")
        if not b.icon then
            b.art:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.art:SetSize(12, 12)
        end
    end
    if not b.glyph then
        b.glyph = b.label or b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if not b.label then
            b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
            NS.Skin.Font(b.glyph)
        end
    end
    NS.SkinPaint(b, paintMark)
    b:HookScript("OnEnter", function(self) markHot(self, true) end)
    b:HookScript("OnLeave", function(self) markHot(self, false) end)
    setMark(b, icon, glyph)
    return b
end

local function markOf(hb, key)
    if key == "close" then return hb.close end
    if key == "settings" then return hb.settings end
    return hb.extras[key]
end

-- The library-absent strip: the close (none without LibKa0s-Core) and the extras as iconButton marks,
-- on HeaderButtons' pitch and in its answer's shape. No settings mark: the opener is the library's.
local function hostMarks(bar, spec)
    local hb = { extras = {}, order = {}, offsets = {}, right = {} }
    local list = {}
    hb.close = spec.close ~= false and NS.MakeCloseButton(bar, spec.close) or nil
    if hb.close then list[1] = { key = "close", btn = hb.close } end
    local extras = spec.extras or {}
    for i = #extras, 1, -1 do
        local x = extras[i]
        hb.extras[x.key] = iconButton(bar, x.icon, x.glyph, x.onClick)
        list[#list + 1] = { key = x.key, btn = hb.extras[x.key] }
    end
    local point, off = spec.point or "RIGHT", TB.HEADER_PAD
    for _, e in ipairs(list) do
        e.btn:SetPoint(point, bar, point, -off, spec.y or 0)
        hb.offsets[e.key] = -off
        hb.right[#hb.right + 1] = { frame = e.btn, x = off }
        off = off + widthOf(e.btn) + TB.HEADER_GAP
    end
    for i = #list, 1, -1 do hb.order[#hb.order + 1] = list[i].key end
    return hb
end

--- A window's title-bar marks (AD-86-DW, LibKa0s#86; standalone-windows, *Title-bar controls*):
--- NS.HeaderButtons, right-aligned, left to right `spec.extras` · settings · close, each extra given
--- iconButton's fields (`art`, `glyph`, `mark`; TB.SetIconMark changes its mark) and painted in
--- TB.MARK_REST / TB.MARK_HOT. Without the library, the host's strip on the same pitch, with no
--- settings mark. `spec.frame.headerButtons` (else the bar's) is set to the answer, and the window
--- keeps the settings mark as `settingsButton`. The caller attaches each mark's tooltip.
--- @param bar table the frame the marks are parented and anchored to
--- `spec.companion` true marks a companion window (FB-DW-01): HeaderButtons builds no settings mark.
--- @param spec table { frame, close, settings, settingsOptOut, companion, extras = { { key, icon, glyph, onClick } }, point, y }
--- @return table HeaderButtons' answer { close, settings, extras, order, offsets, right, optOut }
function TB.Marks(bar, spec)
    local extras = {}
    for i, x in ipairs(spec.extras or {}) do
        extras[i] = { key = x.key, icon = x.icon, glyph = x.glyph, onClick = x.onClick }
    end
    local s = {}
    for k, v in pairs(spec) do s[k] = v end
    s.extras = extras
    local hb = NS.HeaderButtons(bar, s)
    if hb then
        for _, x in ipairs(spec.extras or {}) do
            if hb.extras[x.key] then adoptMark(hb.extras[x.key], x.icon, x.glyph) end
        end
    else
        hb = hostMarks(bar, s)
    end
    local host = spec.frame or bar
    host.headerButtons, host.settingsButton = hb, hb.settings
    return hb
end

--- The right-hand cluster's width from the bar's right edge (RX-30): the strip's leftmost mark's
--- offset plus its width (the lock, then the layout toggle, minimize, settings and close).
--- @param f table the window frame
--- @return number
function TB.ClusterWidth(f)
    local hb = f.headerButtons
    local first = hb and hb.order[1]
    if not first then return 0 end
    return -hb.offsets[first] + widthOf(markOf(hb, first))
end

-- A double-click on the bar expands a minimized window (board 06 A).
local function onTitleClick(_, button)
    if button ~= "LeftButton" then return end
    local now = GetTime()
    if lastTitleClick and now - lastTitleClick <= K.DOUBLE_CLICK and NS.Window.IsMinimized() then
        lastTitleClick = nil
        NS.Window.SetMinimized(false)
        return
    end
    lastTitleClick = now
end

local function buildBadge(bar)
    local b = CreateFrame("Frame", nil, bar)
    b:SetSize(170, K.CONTROL_H)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(12, 12)
    b.art:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.art:SetTexture(NS.Icon("lock"))
    NS.SkinPaint(b.art, function(t) t:SetVertexColor(NS.SkinColor("dw.restricted")) end)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b.art, "RIGHT", 4, 0)
    NS.Skin.Text(b.text, "dw.restricted")
    NS.Window.AttachTooltip(b, badgeTooltip, "chrome")
    b:Hide()
    return b
end

-- A mode word's color: its token's rgb at full opacity (the simulation strip's token is a wash at
-- 0.12, and the word is text), in the skin's face.
local function paintModeText(fs)
    local r, g, b = NS.Skin.Color(fs.dwToken)
    if r ~= nil then fs:SetTextColor(r, g, b) end
end

-- One mode's text beside the title, as Ka0s Loot History draws its TEST MODE: large text in its
-- tone (`token`), 10px right of the title, with no box or fill. A bare frame the size of the text
-- carries it so the words keep their tooltip.
local function buildModeText(bar, title, word, token, tip)
    local m = CreateFrame("Frame", nil, bar)
    m:SetPoint("LEFT", title, "RIGHT", TB.MODE_GAP, 0)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    m.text:SetPoint("LEFT", m, "LEFT", 0, 0)
    m.text:SetText(word)
    NS.Skin.Font(m.text)
    m.text.dwToken = token
    NS.SkinPaint(m.text, paintModeText)
    local w = m.text.GetStringWidth and m.text:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = #word * 11 end   -- before the font has loaded
    m:SetSize(w, K.CONTROL_H)
    NS.Window.AttachTooltip(m, tip, "chrome")
    m:Hide()
    return m
end

local function buildNewChip(f, bar)
    f.newChip = CreateFrame("Frame", nil, bar)
    f.newChip:SetSize(60, K.CONTROL_H)
    f.newChip:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.newChip.text = f.newChip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.newChip.text:SetPoint("LEFT", f.newChip, "LEFT", 0, 0)
    NS.Skin.Text(f.newChip.text, "text.highlight")
    NS.Window.AttachTooltip(f.newChip, newTip, "chrome")
    f.newChip:Hide()
end

--- The lock mark's strength while unlocked (RX-08): the catalog has no unlock mark, so the one
--- lock mark reads unlocked dimmed and desaturated, locked at full strength.
TB.UNLOCKED_ALPHA = 0.4

-- The right-hand cluster, the strip TB.Marks builds (AD-86-DW): left to right the lock, the layout
-- toggle, minimize, settings and close. The lock (RX-08, rolls UX design §3.7) is the cluster's
-- first, the same in both layouts (RX-14, the owner's smoke ruling); a click toggles `locked`
-- through the write seam (NS.ToggleLock, the launcher's and the Lock frame checkbox's write). Not the
-- restriction badge, which wears the same mark in the restricted tone and stands left of the cluster.
-- The layout toggle's mark follows the layout in force (compact spec §1, PaintMinimized). The
-- catalog's minimize mark's key is the library's spelling (tests/prose_waivers.lua). Settings opens
-- this addon's settings through the launcher's opener; the window is in the window tier, under the
-- settings panel, so it is not hidden first.
-- The Item Search magnifier (Item Search spec §4.5): on WoW Forever alone (C.FEATURE.itemSearch),
-- the cluster's first mark, left of the lock; a click opens the Item Search window or closes it.
local function searchTip()
    local TM = NS.TipMarks
    return L["Item Search"], TM.Row(L["Finds"], L["where an item drops, who sells it, its quests and recipes"]),
        TM.Row(L["Typed"], L["/dw search"])
end

local function controlSpecs(W)
    local extras = {
        { key = "lock", icon = "lock", glyph = "L", onClick = function() NS.ToggleLock() end },
        { key = "mode", icon = "fullscreen-exit", glyph = "><", onClick = function() NS.ToggleWindowMode() end },
        { key = "minimize", icon = "minimise", glyph = "-", onClick = function() W.ToggleMinimized() end },
    }
    if NS.Constants.FEATURE.itemSearch then
        table.insert(extras, 1, { key = "search", icon = "search", glyph = "?",
            onClick = function() NS.ItemSearchWindow.Toggle() end })
    end
    return extras
end

local function buildControls(f, bar)
    local W = NS.Window
    local hb = TB.Marks(bar, { frame = f, close = function() W.Close() end, extras = controlSpecs(W) })
    f.closeButton = hb.close
    f.lockButton, f.modeButton, f.minimizeButton = hb.extras.lock, hb.extras.mode, hb.extras.minimize
    f.searchButton = hb.extras.search
    W.AttachTooltip(f.lockButton, lockTip, "chrome")
    W.AttachTooltip(f.modeButton, modeTip, "chrome")
    W.AttachTooltip(f.minimizeButton, minimizeTip, "chrome")
    if f.searchButton then W.AttachTooltip(f.searchButton, searchTip, "chrome") end
    f.badge = buildBadge(bar)
    f.badge:SetPoint("RIGHT", f.lockButton, "LEFT", -8, 0)
end

--- Build the title bar into the window frame `f` (f.titleBar, f.title, f.testText, f.simText,
--- f.newChip, f.lockButton, f.closeButton, f.minimizeButton, f.modeButton, f.badge, f.divider, the body's hidden
--- anchor under the bar). The drag goes through `host`, the shell, which owns the geometry it writes.
--- @param f table the window frame
--- @param host table { onDragStart = fn, onDragStop = fn }
function TB.Build(f, host)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    bar:SetHeight(K.TITLE_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", host.onDragStart)
    bar:SetScript("OnDragStop", host.onDragStop)
    bar:SetScript("OnMouseUp", onTitleClick)
    f.titleBar = bar

    -- Gold and centered under Ka0s Default, as Ka0s Loot History's title. S.TitleBar places it by
    -- the skin's `title.height` and `title.align` (FS-DW-FIX, cause L9), clear of the controls.
    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("CENTER", bar, "CENTER", 0, 0)
    f.title:SetText(NS.BRAND)
    -- The bar's left is empty again (RX-14: the lock button joined the right-hand cluster).
    NS.Skin.TitleBar(bar, { text = f.title, place = TB.PLACE })

    f.testText = buildModeText(bar, f.title, L["TEST MODE"], TB.TEST_TOKEN, TB.TestTip)
    f.simText = buildModeText(bar, f.title, L["SIM"], TB.SIM_TOKEN, TB.SimTip)
    buildNewChip(f, bar)
    buildControls(f, bar)

    -- The body's anchor under the bar, never a line (R4-SEP of Ka0sAddonsCommonTasks
    -- docs/2026-11-03-SMOKE_ROUND4: no window draws a separator under its title, as the Skin
    -- Tester's showroom). Hidden here so the library-absent window draws none either; with the
    -- library, Core.ApplySkin hides it again on every call.
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
    f.divider:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    f.divider:Hide()
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

--- The restriction badge: the current reason and the queued asks' count, hidden when free. In the
--- compact layout its lock and the count alone (NS.CompactChrome.BadgeShort; the same tooltip).
--- @param f table the window frame
function TB.PaintBadge(f)
    local queued = #queuedAsks()
    local text = TB.BadgeText(NS.Window.RestrictionReason(), queued)
    if text and NS.WindowCompact.Mode() == "compact" then text = NS.CompactChrome.BadgeShort(queued) end
    f.badge.text:SetText(text or "")
    f.badge:SetShown(text ~= nil)
end

--- The TEST MODE or the SIM text beside the title (the two modes are exclusive), the
--- `n new` counter after it. The word shows only while its mode is on and its strip is not on
--- screen: minimized (the strip goes with the body) or with no strip (no Widgets library).
--- @param f table the window frame
function TB.PaintModeText(f)
    local test = NS.State.testMode == true
    local sim = not test and NS.Sim:IsActive()
    local min = NS.Window.IsMinimized()
    local showTest = test and (min or not f.banner)
    local showSim = sim and (min or not f.simBanner)
    f.testText:SetShown(showTest)
    f.simText:SetShown(showSim)
    f.newChip:ClearAllPoints()
    f.newChip:SetPoint("LEFT", (showTest and f.testText) or (showSim and f.simText) or f.title, "RIGHT", 8, 0)
end

--- The minimize mark (minus, or plus while minimized), the layout toggle's mark (shrink in the full
--- layout, enlarge in compact) and the `n new` counter, shown minimized only.
--- @param f table the window frame
--- @param minimized boolean
--- @param newCount number
function TB.PaintMinimized(f, minimized, newCount)
    if minimized then setMark(f.minimizeButton, "add", "+") else setMark(f.minimizeButton, "minimise", "-") end
    if NS.WindowCompact.Mode() == "compact" then
        setMark(f.modeButton, "fullscreen-enter", "<>")
    else
        setMark(f.modeButton, "fullscreen-exit", "><")
    end
    f.newChip.text:SetText(L["%d new"]:format(newCount))
    f.newChip:SetShown(minimized and newCount > 0)
end

--- The lock button's state (RX-08): the lock mark at full strength while locked, dimmed and
--- desaturated while unlocked. Its tooltip reads the state when shown.
--- @param f table the window frame
--- @param locked boolean
function TB.PaintLock(f, locked)
    local b = f.lockButton
    if not b or b.dwLocked == locked then return end
    b.dwLocked = locked
    b.art:SetAlpha(locked and 1 or TB.UNLOCKED_ALPHA)
    if b.art.SetDesaturated then b.art:SetDesaturated(not locked) end
    b.glyph:SetAlpha(locked and 1 or TB.UNLOCKED_ALPHA)
end
