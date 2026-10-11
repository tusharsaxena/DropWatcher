local _, NS = ...
-- modules/WindowTitleBar.lua — the main window's title bar (design spec §11.1, boards 01, 06 A and
-- 06 E, as the owner's feedback spec §1 reshaped it to match Ka0s Loot History): the centered gold
-- title (no logo: the launcher and the TOC keep it), test mode's bright-red `TEST MODE` text, the
-- simulator's `SIMULATION` text in its own color (simulator spec §6), the `n new` counter, the restriction badge, Scan group, minimize and the close mark, plus
-- the window's flat and icon buttons, which other frames borrow through NS.Window.TextButton.
--
-- Peeled out of modules/Window.lua (layout-§1's 1000-line notice band). The shell keeps everything
-- that writes state: geometry (the drag's start and stop come in as `host` callbacks), the
-- minimized flag, the `n new` count and the restriction reason, each read here through NS.Window's
-- public accessors at call time. BadgeText is PURE. Build and the Paint* functions are the frame
-- edge, called from the shell's build and its one repaint pass.

NS.WindowTitleBar = NS.WindowTitleBar or {}
local TB = NS.WindowTitleBar
local K  = NS.Constants.WINDOW
local L  = NS.L

-- The restriction badge's words (design spec §11.1), keyed by RestrictionChanged's `reason`.
local REASON_LABEL = {
    encounter = L["Encounter"], challengeMode = L["Mythic+ key"], pvpMatch = L["PvP match"],
    chat = L["Chat restricted"], chatLockdown = L["Chat lockdown"], combat = L["Combat"],
}
local REASON_TIP = {
    encounter     = L["A boss encounter is in progress: addons cannot whisper or inspect until it ends. Asks wait in the queue and are sent then."],
    challengeMode = L["A Mythic+ key is running: addon chat is restricted until it ends. Asks wait in the queue and are sent then."],
    pvpMatch      = L["A PvP match is in progress: addon chat is restricted until it ends. Asks wait in the queue."],
    chat          = L["The client restricts addon chat right now. Asks wait in the queue and are sent once it lifts."],
    chatLockdown  = L["Chat messaging is locked down right now. Asks wait in the queue and are sent once it lifts."],
    combat        = L["You are in combat: inspects and trades wait until it ends. Asks are still sent."],
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
    local lines = { TB.BadgeText(reason, 0) or L["Not restricted"] }
    if REASON_TIP[reason] then lines[2] = REASON_TIP[reason] end
    local queued = queuedAsks()
    for i, a in ipairs(queued) do
        if i > BADGE_LIST_MAX then
            lines[#lines + 1] = L["and %d more"]:format(#queued - BADGE_LIST_MAX)
            break
        end
        lines[#lines + 1] = L["Queued: %s to %s"]:format(KIND_LABEL[a.kind] or tostring(a.kind), tostring(a.target))
    end
    return unpack(lines)
end

local function minimizeTip()
    if NS.Window.IsMinimized() then
        return L["Expand"], L["Show the whole window again. Double-clicking the title bar does the same."]
    end
    return L["Minimize"], L["Collapse the window to its title bar. Its position is kept, and a counter shows the drops that arrive meanwhile."]
end

local function scanTip()
    return L["Scan group"], L["Inspects every other member of your group, one at a time and out of combat, so each drop can be judged for its looter."]
end

local function newTip()
    return L["%d new"]:format(NS.Window.NewCount()), L["Drops that arrived since you minimized the window. Expand it to see them."]
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
    return L["Simulation"],
        L["Scenario: %s (%s)"]:format(scenario, NS.WindowFooter.SituationLabel(st.situation)),
        L["A made-up group session runs through the real engine: nothing is sent, and your saved history is not touched."],
        L["/dw sim lists its verbs; /dw sim stop ends it."]
end

--- Test mode's title text and banner (design spec §11.6, board 06 E) share one tooltip.
function TB.TestTip()
    return L["Test mode"],
        L["Sample drops of real items show every verdict, trade, inspect and ask state, so the layout can be checked anywhere."],
        L["Ask, Offer and Announce print their text in your chat frame instead of sending it."],
        L["Combat ends it, and so do /dw test, the launcher menu and the Master controls checkbox."]
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
    f.scanButton = TB.TextButton(bar, 96, "people", L["Scan group"], function() NS.ScanGroup() end)
    f.scanButton:SetPoint("RIGHT", f.minimizeButton, "LEFT", -6, 0)
    W.AttachTooltip(f.scanButton, scanTip)
    f.badge = buildBadge(bar)
    f.badge:SetPoint("RIGHT", f.scanButton, "LEFT", -8, 0)
end

--- Build the title bar into the window frame `f` (f.titleBar, f.title, f.testText, f.simText,
--- f.newChip, f.closeButton, f.minimizeButton, f.scanButton, f.badge, f.divider). The drag goes
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

--- The restriction badge: the current reason and the queued asks' count, hidden when free.
--- @param f table the window frame
function TB.PaintBadge(f)
    local text = TB.BadgeText(NS.Window.RestrictionReason(), #queuedAsks())
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

--- The minimize mark (minus, or plus while minimized) and the `n new` counter, shown minimized only.
--- @param f table the window frame
--- @param minimized boolean
--- @param newCount number
function TB.PaintMinimized(f, minimized, newCount)
    if minimized then setMark(f.minimizeButton, "add", "+") else setMark(f.minimizeButton, "minimise", "-") end
    f.newChip.text:SetText(L["%d new"]:format(newCount))
    f.newChip:SetShown(minimized and newCount > 0)
end
