local _, NS = ...
-- modules/WindowTitleBar.lua — the main window's title bar (design spec §11.1, boards 01, 06 A and
-- 06 E, as the owner's feedback spec §1 reshaped it to match Ka0s Loot History): the centered gold
-- title (no logo: the launcher and the TOC keep it), test mode's bright-red `TEST MODE` text, the
-- simulator's `SIMULATION` text in its own color (simulator spec §6), the `n new` counter, the
-- restriction badge, the layout toggle (compact spec §1), minimize and the close mark, plus the
-- window's flat and icon buttons, which other frames borrow through NS.Window.TextButton (and paint
-- through NS.Window.SetButtonMark). Scan group is the Drops strip's in both layouts
-- (modules/DropsStrip.lua, feedback-7 spec §4; compact's title-bar icon removed by feedback-16), and
-- the badge anchors to the layout toggle.
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
local KIND_LABEL = { ask = L["Ask"], offer = L["Offer"], announce = L["Announce"] }
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

-- The layout toggle's tooltip: what a click switches to, and the setting that stores it.
local function modeTip()
    local WC, TM = NS.WindowCompact, NS.TipMarks
    local compact = WC.Mode() == "compact"
    local lines = compact
        and { L["Full view"], TM.Row(L["Shows"], L["the full window, every column of the drop tables"]),
            TM.Row(L["Typed"], L["/dw full"]) }
        or { L["Compact view"], TM.Row(L["Shows"], L["the window narrow, each drop a short card"]),
            TM.Row(L["Typed"], L["/dw compact"]) }
    lines[#lines + 1] = TM.Row(L["Stored as"], L["Window settings, Layout"])
    if WC.InRun() then
        lines[#lines + 1] = TM.Row(L["Held compact"], L["until this run ends (Open in compact view during a run)"])
    end
    return unpack(lines)
end

--- Scan group's tooltip, on the Drops strip's button.
function TB.ScanTip()
    local TM = NS.TipMarks
    return L["Scan group"], TM.Row(L["Inspects"], L["every other member of your group"]),
        TM.Row(L["When"], L["one at a time, out of combat"]), TM.Row(L["So"], L["each drop is judged for its looter"])
end

local function newTip()
    return L["%d new"]:format(NS.Window.NewCount()), NS.TipMarks.Row(L["Arrived"], L["since you minimized the window"]),
        NS.TipMarks.Hint(L["Expand it to see them."])
end

--- Test mode's text color: Ka0s Loot History's bright red (feedback spec §1, FB-3).
TB.TEST_TONE = { r = 1.00, g = 0.15, b = 0.15 }

--- The simulator's text color (simulator spec §6): a cyan apart from every verdict tone.
TB.SIM_TONE = { r = 0.35, g = 0.80, b = 1.00 }

--- The gap between the title and a mode's text, as Ka0s Loot History sets it.
TB.MODE_GAP = 10

--- The SIMULATION text's tooltip (simulator spec §6): the scenario and what the simulation never does.
function TB.SimTip()
    local st = NS.Sim.Status()
    local scenario = st.active and tostring(st.scenario) or L["none"]
    local TM = NS.TipMarks
    return L["Simulation"],
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

local function iconButton(parent, icon, glyph, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(K.ICON, K.ICON)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.art:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    setMark(b, icon, glyph)
    b:SetScript("OnClick", onClick)
    return b
end

--- A flat button: the skin's fill and inner line, a label kept centered and a mark beside it
--- (standalone-windows: a wide action button keeps its label). NS.Window.TextButton is this.
--- @return table
function TB.TextButton(parent, width, icon, text, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, K.CONTROL_H)
    local S = NS.SKIN
    if b.SetBackdrop and S.bgFile then
        b:SetBackdrop({ bgFile = S.bgFile, edgeFile = S.edgeFile, edgeSize = S.edgeSize })
        b:SetBackdropColor(0.12, 0.12, 0.14, 1)
        b:SetBackdropBorderColor(unpack(S.innerBorder or S.border))
    end
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(12, 12)
    b.art:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.art:SetTexture(NS.Icon(icon))
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", b, "CENTER", 7, 0)
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
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
    b.label:SetPoint("CENTER", b, "CENTER", icon and 7 or 0, 0)
end

-- ── construction ────────────────────────────────────────────────────────────────────────────

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
    b.art:SetVertexColor(1, 0.6, 0.2)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b.art, "RIGHT", 4, 0)
    b.text:SetTextColor(1, 0.6, 0.2)
    NS.Window.AttachTooltip(b, badgeTooltip)
    b:Hide()
    return b
end

-- One mode's text beside the title, as Ka0s Loot History draws its TEST MODE: large text in its
-- tone, 10px right of the title, with no box or fill. A bare frame the size of the text carries it
-- so the words keep their tooltip.
local function buildModeText(bar, title, word, tone, tip)
    local m = CreateFrame("Frame", nil, bar)
    m:SetPoint("LEFT", title, "RIGHT", TB.MODE_GAP, 0)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    m.text:SetPoint("LEFT", m, "LEFT", 0, 0)
    m.text:SetText(word)
    m.text:SetTextColor(tone.r, tone.g, tone.b)
    local w = m.text.GetStringWidth and m.text:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = #word * 11 end   -- before the font has loaded
    m:SetSize(w, K.CONTROL_H)
    NS.Window.AttachTooltip(m, tip)
    m:Hide()
    return m
end

local function buildNewChip(f, bar)
    f.newChip = CreateFrame("Frame", nil, bar)
    f.newChip:SetSize(60, K.CONTROL_H)
    f.newChip:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.newChip.text = f.newChip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.newChip.text:SetPoint("LEFT", f.newChip, "LEFT", 0, 0)
    NS.Window.AttachTooltip(f.newChip, newTip)
    f.newChip:Hide()
end

local function buildControls(f, bar)
    local W = NS.Window
    f.closeButton = NS.MakeCloseButton(bar, function() W.Close() end)
    local right, rightPoint = bar, "RIGHT"
    if f.closeButton then
        f.closeButton:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
        right, rightPoint = f.closeButton, "LEFT"
    end
    -- The catalog's minimize mark; the key is the library's spelling (tests/prose_waivers.lua).
    f.minimizeButton = iconButton(bar, "minimise", "-", function() W.ToggleMinimized() end)
    f.minimizeButton:SetPoint("RIGHT", right, rightPoint, -4, 0)
    W.AttachTooltip(f.minimizeButton, minimizeTip)
    -- The layout toggle (compact spec §1); its mark follows the layout in force (PaintMinimized).
    f.modeButton = iconButton(bar, "fullscreen-exit", "><", function() NS.ToggleWindowMode() end)
    f.modeButton:SetPoint("RIGHT", f.minimizeButton, "LEFT", -4, 0)
    W.AttachTooltip(f.modeButton, modeTip)
    f.badge = buildBadge(bar)
    f.badge:SetPoint("RIGHT", f.modeButton, "LEFT", -8, 0)
end

--- Build the title bar into the window frame `f` (f.titleBar, f.title, f.testText, f.simText,
--- f.newChip, f.closeButton, f.minimizeButton, f.modeButton, f.badge, f.divider). The drag goes
--- through `host`, the shell, which owns the geometry it writes.
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

    -- Centered and gold (ApplySkin tints `frame.title`), as Ka0s Loot History's title.
    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("CENTER", bar, "CENTER", 0, 0)
    f.title:SetText(NS.BRAND)

    f.testText = buildModeText(bar, f.title, L["TEST MODE"], TB.TEST_TONE, TB.TestTip)
    f.simText = buildModeText(bar, f.title, L["SIMULATION"], TB.SIM_TONE, TB.SimTip)
    buildNewChip(f, bar)
    buildControls(f, bar)

    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
    f.divider:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
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

--- The TEST MODE or the SIMULATION text beside the title (the two modes are exclusive), the
--- `n new` counter after it.
--- @param f table the window frame
function TB.PaintModeText(f)
    local test = NS.State.testMode == true
    local sim = not test and NS.Sim.IsActive()
    f.testText:SetShown(test)
    f.simText:SetShown(sim)
    f.newChip:ClearAllPoints()
    f.newChip:SetPoint("LEFT", (test and f.testText) or (sim and f.simText) or f.title, "RIGHT", 8, 0)
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
