local _, NS = ...
-- modules/Toast.lua — the upgrade toast (design spec §11.5, board 06 C; feedback-9 spec §0): an
-- opt-in alert for a drop someone else looted that is a big upgrade for you and likely tradeable.
--
-- FOUR ROWS BESIDE A FOUR-ROW ICON (feedback-9 spec §0, DW-I0). The item button spans all four:
--
--   [icon]  Big upgrade for you                                   [Ask] [x]
--           Nalorakk's Nightmare 295
--           Looted by Seta · You ▲19 · Them ▼13
--           Likely tradeable · not an upgrade for Seta
--
-- Row 2 is the item name in its quality color (NS.TipMarks.ItemName) and its item level after it in
-- a second, smaller muted FontString (NS.WindowRows' mark, as the looter's `[YOU]` is drawn): the
-- name is cut first, the level always shows. Row 3 is the looter in their class color
-- (NS.TipMarks.ClassName) and the drop judged for you and for them, each as the table's Me and Them
-- cells draw a verdict (NS.SideCells.Merge of WindowCells.Me / Them): the monospace glyph
-- (WindowCells.GLYPH, C.FONT_MONO) and the unsigned difference, both in the verdict's tone, or the
-- word (`Can't use`, `Not wanted`, `?`); a FontString has one face, so the row is segments laid
-- out left to right. On a ring, trinket or one-hand weapon with both worn items read, a verdict is
-- the cells' dual mark (NS.SideCells.Parts, feedback-21 H7), `You 321 ▼10 / 324 ▲3`: each worn
-- item's level, glyph and difference in its own tone; the toast then grows wider than WIDTH as far
-- as row 3 needs (Toast.WidthFor, measured at paint), so neither verdict is cut. Row 4 is the trade word in the Trade cell's tone (WindowCells.TRADE_TONE) and a
-- short reason, muted (cut with an ellipsis at the right inset); the toast's tooltip is the Trade
-- cell's, with the full reason (WindowCells.TradeReason). Only row 1 shares its width with Ask and
-- the close mark; rows 2 to 4 run to the right inset.
--
-- ON FOR A NEW PROFILE (`toast.enabled`; off until 2026-10-25, no migration, so an existing profile
-- keeps what it had). A drop toasts when it is not yours, its verdict for you is
-- `upgrade` with an item-level gain of at least `toast.minGain` (default 10), and its trade
-- estimate is `likely` or `yes` (Qualifies, pure). An upgrade into an empty slot (the kernel's
-- `emptySlot` reason, with no item-level change) clears any least gain and reads `empty`. Each drop
-- is considered on DropAdded and again on each DropUpdated until it has toasted once (an inspect can
-- turn its trade `likely` later).
--
-- OFF-SPEC (feedback-19 spec §2). A drop your spec can't use toasts the same way when another spec
-- of your class finds it an upgrade (NS.OffSpec.Of), the least gain tested on the off-spec
-- difference; Qualifies says so with a third value, `offSpec`, and row 1 reads `Off-spec upgrade
-- for you (Holy)`. Its Ask sends the off-spec template, which the shared ask path picks.
--
-- THE SHELL is LibKa0s-Toast-1.0 (built from this file's own shell, LibKa0s#60), through
-- core/ToastSetup.lua's NS.NewToast: the queue, the countdown and its hover pause, the close mark
-- and the right-click, the HIGH alert tier, the drag, the scale and the sound. This file keeps the
-- content (the builder below), the qualifier and the triggers, the combat hold, the settings it
-- reads and the saved point. Without the library the seam's stub answers and no toast shows.
--
-- ONE AT A TIME. Qualifying drops wait in the shell's queue, keyed by drop id (MAX_QUEUE, the oldest
-- dropped first); the next shows when the current one goes. A toast goes after `toast.duration`
-- seconds (default 8), when its close mark is clicked, or on a right-click anywhere on it, its icon
-- and its Ask included (the close mark's path: the drop is not asked for and does not toast again);
-- the countdown pauses while the pointer is over it and resumes with the time it had left. A drop
-- asked for meanwhile, or no longer qualifying, is skipped when its turn comes (the builder answers
-- false).
--
-- IT FOLLOWS ITS DROP AND ITS SWITCH. A drop that leaves the feed (a Clear or the cap's trim: the
-- feed's removal sink, Prune) takes its toast and its place in the queue with it (the shell's
-- Remove), and an Ask on a drop already gone only takes the toast down. Turning `toast.enabled` off
-- (its row's reaction, OnEnabledChanged) or switching to a profile with it off (OnProfileReloaded)
-- takes the toast down and empties the queue (the shell's Clear).
--
-- COMBAT. Unless `toast.inCombat` is set, nothing shows in combat: the shell's Hold on
-- PLAYER_REGEN_DISABLED (a toast on screen goes back to the head of the queue) and its Release on
-- PLAYER_REGEN_ENABLED, and the same hold is checked before each drop is queued and whenever
-- `toast.inCombat` can change (its row's reaction, a profile switch): syncHold, which leaves a toast
-- already on screen up and holds only what follows it, as the old live check did.
--
-- TEST MODE. Test mode's placeholders toast like live drops (with `toast.enabled` on), so the toast
-- can be seen and placed: only in test mode can it be dragged (with the left button; the shell's
-- `draggable`), and its position is saved in the profile's `toast.point` (named state, like the
-- window's point). A test drop's toast is sticky (the shell's Show with `sticky`): it stays until it
-- is closed or test mode ends, since placing it takes longer than its duration.
--
-- SCALE. `toast.scale` (0.5 to 2, Alerts › Toast's Scale, feedback-21 G10) is the frame's own scale,
-- read by the shell at each toast, by the row's reaction (ApplyScale, live on a toast on screen) and
-- on a profile reload (both the shell's Refresh). The saved point is kept in UIParent's units, not
-- the toast's: the shell hands a drag's offsets over times the scale and applies them divided by
-- it, so a scale change grows or shrinks the toast about the anchor the player placed and never
-- rewrites `toast.point`. Its shape, { point, relativePoint, x, y }, is the one this file always
-- stored, so no saved point needed a migration.
--
-- SOUND. With `toast.sound` on, each toast plays the client's alert sound (the shell's: SOUNDKIT's
-- UI_EPICLOOT_TOAST, else RAID_WARNING, on the Master channel).
--
-- PURE: Qualifies and Compose take a drop record and read nothing else (Compose answers the rows'
-- parts, not joined lines); test_toast drives them. The edge below reads the feed, the settings and
-- the asks; the shell builds its frame on the first toast, and the builder its rows.

NS.Toast = NS.Toast or {}
local Toast = NS.Toast
local C = NS.Constants
local L = NS.L

local TAG = "UI"

Toast.NAME = "DropWatcherToast"
Toast.MAX_QUEUE = 5
-- THE SCALE (DW-05, Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK Addendum 03): the
-- toast is as tall as DpsRace's new-best toast after DR-04 (its BestToast.HEIGHT, 90), every element
-- in it scaled to match. Each figure below is the first release's (in the comment) times SCALE, 90
-- over the first release's 74, rounded to the pixel; the faces are their font objects' heights times
-- SCALE (NS.ScaledFontString), the mono glyphs' 12 too, and Ask's height, mark and word with them.
Toast.SCALE = 90 / 74
local function px(n) return math.floor(n * Toast.SCALE + 0.5) end
-- The icon spans the four rows; the frame keeps INSET all round (feedback-9 spec §0). TEXT_GAP is
-- between the icon and the rows, ROW_Y each row's top under the icon's (row 4 sits on its bottom).
-- WIDTH was 350, not the spec's first 340: row 3 with a 12-character looter, an empty slot and a Them
-- word (`Not wanted`) needs 267 of the rows' width at the first size (test_toast). It is the least
-- width: two dual marks (feedback-21 H7) need more, and only such a toast is drawn wider
-- (Toast.WidthFor).
Toast.WIDTH, Toast.ICON, Toast.INSET, Toast.TEXT_GAP = px(350), px(56), px(9), px(8)   -- 426, 68, 11, 10
Toast.HEIGHT = Toast.ICON + 2 * Toast.INSET                                             -- 90
Toast.ROW_Y = { 0, px(-15), px(-30) }                                                   -- 0, -18, -36
-- Between row 3's and row 4's segments (a verdict after its label, a reason after its word), and
-- between a verdict's glyph and its difference (the window's NS.WindowGroup.SIDE.GLYPH_GAP, 3).
Toast.SEG_GAP, Toast.GLYPH_GAP = px(4), px(3)                                           -- 5, 4
-- Ask's width (64), and its gap to the close mark and to the title (6), or the corner's inset (4).
Toast.ASK_W, Toast.ASK_GAP, Toast.CORNER = px(64), px(6), px(4)                         -- 78, 7, 5
Toast.POINT = { "TOP", "TOP", 0, -160 }

local TRADE_WORD = { likely = L["Likely tradeable"], yes = L["Tradeable"] }

-- Row 4's reason, short (feedback-9 spec §0: one line) for the estimates a toast can carry; any
-- other is the Trade cell's own reason (WindowCells.TradeReason), cut at the row's end.
local SHORT_REASON = {
    notUpgrade = function(who) return L["not an upgrade for %s"]:format(who) end,
    groupLoot = function() return L["group loot: four hours to trade"] end,
    boe = function() return L["bind on equip"] end,
}

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

-- True when the verdict is an upgrade into an empty slot (design spec §5.2: no baseline item).
local function intoEmptySlot(eval)
    for _, r in ipairs(type(eval.reasons) == "table" and eval.reasons or {}) do
        if type(r) == "table" and r.key == "emptySlot" then return true end
    end
    return false
end

local function gainPasses(eval, minGain)
    local gain = num(eval.ilvlDelta)
    if not gain then return intoEmptySlot(eval) end
    return gain >= (num(minGain) or 0)
end

-- The verdict a drop qualifies through: your own `upgrade`, else (your spec can't use it) another
-- spec's off-spec upgrade (NS.OffSpec.Of, feedback-19 spec §2) and `offSpec`; nil when neither.
local function upgradeOf(me)
    if me.verdict == "upgrade" then return me end
    local off = NS.OffSpec.Of(me)
    if off and off.verdict == "upgrade" then return off, "offSpec" end
    return nil
end

--- Whether `drop` earns a toast: someone else's drop, an upgrade for you by at least `minGain` item
--- levels (or into an empty slot, whatever `minGain`), with a trade estimate of `likely` or `yes`.
--- A drop your spec can't use qualifies the same way through another spec's off-spec upgrade, its
--- gain tested on the off-spec difference; the third value then says so.
--- @param drop table a feed record
--- @param minGain number
--- @return boolean ok, string|nil why (`mine`, `notUpgrade`, `gain` or `trade`) when not,
--- string|nil how (`offSpec` when it qualifies through the off-spec result)
function Toast.Qualifies(drop, minGain)
    if type(drop) ~= "table" or drop.isMine then return false, "mine" end
    local eval, how = upgradeOf(type(drop.me) == "table" and drop.me or {})
    if not eval then return false, "notUpgrade" end
    if not gainPasses(eval, minGain) then return false, "gain" end
    local t = type(drop.trade) == "table" and drop.trade.state
    if not TRADE_WORD[t] then return false, "trade" end
    return true, nil, how
end

--- The width rows 2 to 4 have: the toast's, less the insets, the icon and the gap after it.
--- @return number
function Toast.RowWidth()
    return Toast.WIDTH - 2 * Toast.INSET - Toast.ICON - Toast.TEXT_GAP
end

-- A verdict as the table's Me and Them cells draw it with no gear part (NS.SideCells.Merge): the
-- glyph and the unsigned difference (or `empty`), else the word; one tone for both. On a two-item
-- slot with both worn items read (`gear`), the cells' dual mark too (NS.SideCells.Parts,
-- feedback-21 H7): `parts`, each worn item's level, glyph and difference.
local function verdictPart(cell, drop, gear)
    local c = NS.SideCells.Merge(cell)
    local WC = NS.WindowCells
    local slots = gear and WC.EqSlots(type(drop.facts) == "table" and drop.facts.equipLoc or nil)
    local parts
    if slots and #slots == 2 then
        local items, empty = WC.SlotItems(gear, slots)
        parts = NS.SideCells.Parts(cell, items, empty)
    end
    return { glyph = c.glyph, text = c.text, tone = c.tone, parts = parts }
end

local function shortReason(trade, who)
    local fn = SHORT_REASON[trade.reasonKey]
    if fn then return fn(who) end
    return (NS.WindowCells.TradeReason(trade, who):gsub("%.$", ""))
end

-- Row 1: `Big upgrade for you`, or for an off-spec upgrade `Off-spec upgrade for you (Holy)`.
local function titleOf(drop)
    local off, how = upgradeOf(type(drop.me) == "table" and drop.me or {})
    if how ~= "offSpec" then return L["Big upgrade for you"] end
    return L["Off-spec upgrade for you (%s)"]:format(NS.OffSpecCells.SpecName(off.specID))
end

--- The toast's parts for a qualifying drop (feedback-9 spec §0), each row's pieces apart:
--- { title, link, item, itemText (the name in its quality color), ilvl, looter, classFile,
--- looterText (in its class color), me, them ({ glyph, text, tone, parts } each: `parts` the dual
--- mark, feedback-21 H7), trade, tradeTone, reason (short), tip (the Trade cell's tooltip: its title
--- and the full reason) }.
--- @param drop table
--- @param equipped table|nil your worn gear (the gear snapshot's `equipped`), for your dual mark
--- @param gear table|nil the looter's inspect gear, for theirs
--- @return table
function Toast.Compose(drop, equipped, gear)
    local WC = NS.WindowCells
    local looter = type(drop.looter) == "table" and drop.looter or {}
    local who = WC.ShortName(looter.name)
    local f = type(drop.facts) == "table" and drop.facts or {}
    local name = WC.ItemName(drop.link) or "?"
    local trade = type(drop.trade) == "table" and drop.trade or {}
    return {
        title = titleOf(drop), link = drop.link,
        item = name, itemText = NS.TipMarks.ItemName(name, f.quality, drop.link), ilvl = num(f.ilvl),
        looter = who, classFile = looter.classFile, looterText = NS.TipMarks.ClassName(who, looter.classFile),
        me = verdictPart(WC.Me(drop), drop, equipped), them = verdictPart(WC.Them(drop), drop, not drop.isMine and gear or nil),
        trade = TRADE_WORD[trade.state] or "", tradeTone = WC.TRADE_TONE[trade.state] or "muted",
        reason = trade.reasonKey and shortReason(trade, who) or "", tip = WC.Trade(drop).tip,
    }
end

-- ── the edge's state ────────────────────────────────────────────────────────────────────────

local toasted = {}     -- drop ids already queued or shown this session: each toasts once
local toast            -- the shell's instance (NS.NewToast, core/ToastSetup.lua), made below

local function setting(key) return NS.Setting("toast." .. key) end

local function store()
    local db = NS.addon and NS.addon.db
    local p = db and db.profile
    if not p then return {} end
    if type(p.toast) ~= "table" then p.toast = {} end
    return p.toast
end

local function inCombat() return NS.Compat.InCombatLockdown() end

local function held()
    return inCombat() and setting("inCombat") ~= true
end

-- The drop on screen (its id is the payload and the key it was queued under), or nil.
local function shownId() return (toast:Current()) end

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

-- A row text in the skin's face. A fixed `tone` is painted now and again on a skin switch (the
-- toast lives off the window, so the window's repaint never reaches it); the others are toned on
-- each paint.
local function text(f, template, tone)
    local fs = NS.ScaledFontString(f, "OVERLAY", template, Toast.SCALE)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    NS.Skin.Font(fs)
    if tone then NS.SkinPaint(fs, function(s) setTone(s, tone) end) end
    return fs
end

-- A verdict's glyph, in the skin's monospace face (the default face has no ▲ ≈ ▼).
local function glyph(f)
    local fs = f:CreateFontString(nil, "OVERLAY")
    NS.SkinMono(fs, 12 * Toast.SCALE)
    fs:SetWordWrap(false)
    return fs
end

-- A row's top-left, ROW_Y under the icon's top, TEXT_GAP right of it.
local function atRow(fs, f, i)
    fs:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", Toast.TEXT_GAP, Toast.ROW_Y[i])
end

-- Rows 1 and 2: the gold title beside Ask; the item name (cut first) and its item level after it.
local function buildTop(f)
    f.title = text(f, "GameFontNormalSmall")
    NS.Skin.Text(f.title, "heading")   -- gold, in the skin's title face
    atRow(f.title, f, 1)
    f.title:SetPoint("RIGHT", f.ask, "LEFT", -Toast.ASK_GAP, 0)
    f.item = text(f, "GameFontHighlight")
    atRow(f.item, f, 2)
    f.ilvl = NS.WindowRows.NewMark(f, f.item, Toast.SCALE)
    NS.Skin.Text(f.ilvl, "muted")   -- the mark's own role replaced: muted, not the accent
end

-- A dual mark's first part, its `/` and the second part's worn level (feedback-21 H7), hidden
-- until a dual verdict is painted: { leadLevel, leadGlyph, leadText, sep } (WindowGroup.PaintLead's
-- pieces) and the level.
local function lead(f)
    local l = { leadLevel = text(f, "GameFontHighlightSmall"), leadGlyph = glyph(f),
        leadText = text(f, "GameFontHighlightSmall"), sep = text(f, "GameFontHighlightSmall") }
    for _, fs in pairs(l) do fs:Hide() end
    local level = text(f, "GameFontHighlightSmall")
    level:Hide()
    return l, level
end

-- Row 3: `Looted by Seta · You`, the Me verdict, `· Them`, the Them verdict (the segments are
-- placed on each paint: a verdict with no glyph takes no glyph's room; the last runs to the right
-- inset and is cut there, as row 4's reason is). A dual verdict's first part and its second part's
-- level go before its glyph (`meLead`, `meLevel`; `themLead`, `themLevel`).
local function buildVerdicts(f)
    f.looted = text(f, "GameFontHighlightSmall", "muted")
    atRow(f.looted, f, 3)
    f.meLead, f.meLevel = lead(f)
    f.meGlyph, f.meText = glyph(f), text(f, "GameFontHighlightSmall")
    f.themLabel = text(f, "GameFontHighlightSmall", "muted")
    f.themLead, f.themLevel = lead(f)
    f.themGlyph, f.themText = glyph(f), text(f, "GameFontHighlightSmall")
end

-- Row 4: the trade word, and the reason after it to the right inset (cut there).
local function buildTrade(f)
    f.trade = text(f, "GameFontHighlightSmall")
    f.trade:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", Toast.TEXT_GAP, 0)
    f.reason = text(f, "GameFontHighlightSmall", "muted")
    f.reason:SetPoint("LEFT", f.trade, "RIGHT", Toast.SEG_GAP, 0)
    f.reason:SetPoint("RIGHT", f, "RIGHT", -Toast.INSET, 0)
end

-- The rows, made once on the shell's frame (its first toast). The shell already made the close mark
-- (`f.close`, top-right; none without LibKa0s-Core's MakeCloseButton, and Ask takes its corner) and
-- wired the frame's own hover pause, right-click and drag; the icon and Ask are attached here so
-- hovering them holds the countdown and a right-click on them closes the toast too.
local function makeRows(f)
    f.icon = NS.WindowGroup.ItemButton(f, Toast.ICON)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", Toast.INSET, -Toast.INSET)
    f.ask = NS.Window.TextButton(f, Toast.ASK_W, "chat", L["Ask"], function() Toast.Ask() end, Toast.SCALE)
    if f.close then
        f.ask:SetPoint("RIGHT", f.close, "LEFT", -Toast.ASK_GAP, 0)
    else
        f.ask:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Toast.CORNER, -Toast.CORNER)
    end
    buildTop(f)
    buildVerdicts(f)
    buildTrade(f)
    -- The toast's tooltip is the Trade cell's: the full reason row 4 may cut (feedback-9 spec §0).
    NS.Window.AttachTooltip(f, function() return unpack(f.tipLines or {}) end)
    toast:Attach(f.icon)
    toast:Attach(f.ask)
end

local function askState(rec)
    local target = NS.AskTargetOf(rec)
    if not target then return "ready" end
    return NS.Asks.StateOf("ask", target, rec.id)
end

-- The Ask in the row's look: its state's word and mark (feedback-7 spec §1: `chat`, `clock`, ...).
local function paintAsk(f, rec)
    local a = NS.WindowCells.Ask(rec, askState(rec))
    local b = f.ask
    NS.Window.SetButtonMark(b, a.text, a.icon)
    b:SetEnabled(a.enabled == true)
end

-- A segment's drawn width on one line (unbounded: the last segment is anchored to the inset).
local function measure(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    return fn(fs) or 0
end

-- `fs` placed SEG_GAP (or `gap`) after `after`; answers it and the row's width so far.
local function place(fs, after, w, gap)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", after, "RIGHT", gap or Toast.SEG_GAP, 0)
    return fs, w + (gap or Toast.SEG_GAP) + measure(fs)
end

-- One verdict after `after`: its glyph (when it has one) and its difference or word, in its tone; a
-- dual mark (`part.parts`, feedback-21 H7) first draws the first worn item's level, glyph and
-- difference, the `/` and the second one's level. Answers the last segment placed and the row's
-- width so far (`w`, grown by what it placed).
local function paintVerdict(after, glyphFs, textFs, part, l, levelFs, w)
    local second = NS.WindowGroup.PaintLead(l, part.parts)
    local p = second or part
    levelFs:SetShown(second ~= nil)
    if second then
        local G = Toast.GLYPH_GAP
        after, w = place(l.leadLevel, after, w)
        after, w = place(l.leadGlyph, after, w)
        after, w = place(l.leadText, after, w, G)
        after, w = place(l.sep, after, w)
        levelFs:SetText(second.level or "")
        setTone(levelFs, "plain")
        after, w = place(levelFs, after, w)
    end
    textFs:ClearAllPoints()
    glyphFs:SetText(p.glyph or "")
    glyphFs:SetShown(p.glyph ~= nil)
    textFs:SetText(p.text or "")
    setTone(glyphFs, p.tone)
    setTone(textFs, p.tone)
    if p.glyph then
        after, w = place(glyphFs, after, w)
        return place(textFs, after, w, Toast.GLYPH_GAP)
    end
    glyphFs:ClearAllPoints()
    return place(textFs, after, w)
end

--- The toast's width for a row 3 `row3` pixels wide: Toast.WIDTH, or wider when a dual mark
--- (feedback-21 H7) makes row 3 longer than the rows' width there, so neither verdict is cut.
--- @param row3 number
--- @return number
function Toast.WidthFor(row3)
    return math.max(Toast.WIDTH, math.ceil(row3) + Toast.WIDTH - Toast.RowWidth())
end

local function paintRows(f, t)
    f.title:SetText(t.title)
    f.item:SetText(t.itemText)
    f.looted:SetText(L["Looted by %s · You"]:format(t.looterText))
    local last, w = paintVerdict(f.looted, f.meGlyph, f.meText, t.me, f.meLead, f.meLevel, measure(f.looted))
    f.themLabel:SetText(L["· Them"])
    last, w = place(f.themLabel, last, w)
    -- Row 3 ends with Them's verdict: its width counts too, or a widened toast cuts it.
    w = select(2, paintVerdict(last, f.themGlyph, f.themText, t.them, f.themLead, f.themLevel, w))
    f:SetWidth(Toast.WidthFor(w))
    f.themText:SetPoint("RIGHT", f, "RIGHT", -Toast.INSET, 0)
    NS.WindowRows.PlaceMark(f.item, f.ilvl, t.ilvl and tostring(t.ilvl) or nil, f:GetWidth() - Toast.WIDTH + Toast.RowWidth())
    f.trade:SetText(t.trade)
    setTone(f.trade, t.tradeTone)
    f.reason:SetText(t.reason ~= "" and ("· " .. t.reason) or "")
end

-- Your worn gear (the snapshot's; a sample's own) and the looter's (their inspect entry's), for the
-- dual marks (feedback-21 H7).
local function gearOf(rec)
    local snap = NS.Gear.Snapshot()
    local insp = NS.TestMode.InspectOf(rec)
    return NS.TestMode.GearOf(rec, snap and snap.equipped), insp and insp.gear
end

local function paint(f, rec)
    local t = Toast.Compose(rec, gearOf(rec))
    paintRows(f, t)
    f.tipLines = t.tip
    NS.WindowGroup.SetItem(f.icon, t.link, NS.WindowGroup.Where(rec))
    f.icon.dropId = nil
    paintAsk(f, rec)
end

-- Still worth showing when its turn comes: in the feed, qualifying, and not asked for yet.
local function wanted(id)
    local rec = NS.LootFeed.Get(id)
    if not rec or not Toast.Qualifies(rec, setting("minGain")) then return nil end
    local s = askState(rec)
    if s == "sent" or s == "queued" then return nil end
    return rec
end

-- The shell's builder: each time a drop's turn comes, its rows painted on the shell's frame, the
-- frame as wide as row 3 needs; `false` skips a drop no longer wanted, and the next one is tried.
local function build(f, id)
    local rec = wanted(id)
    if not rec then return false end
    if not f.ask then makeRows(f) end
    paint(f, rec)
    NS.Debug(TAG, "toast shown: drop %s %s", tostring(rec.id), tostring(rec.link))
    return f:GetWidth(), Toast.HEIGHT
end

-- ── the shell ───────────────────────────────────────────────────────────────────────────────

-- The saved point, a copy, so the shell never holds the profile's own table. It is { point,
-- relativePoint, x, y } in UIParent's units, as the shell hands it over and as it always was here.
local function getPosition()
    local pt = store().point
    if type(pt) ~= "table" then return nil end
    return { pt[1], pt[2], pt[3], pt[4] }
end

local function setPosition(pt)
    if type(pt) ~= "table" then
        store().point = nil
        return
    end
    store().point = { pt[1], pt[2], pt[3], pt[4] }
end

toast = NS.NewToast({
    name            = Toast.NAME,
    build           = build,
    width           = Toast.WIDTH,
    height          = Toast.HEIGHT,
    maxQueue        = Toast.MAX_QUEUE,
    defaultPosition = Toast.POINT,
    duration        = function() return setting("duration") end,
    scale           = function() return setting("scale") end,
    sound           = function() return setting("sound") end,
    -- Only in test mode can it be placed: its placeholders toast like live drops.
    draggable       = function() return NS.State.testMode == true end,
    getPosition     = getPosition,
    setPosition     = setPosition,
})

-- Combat holds the toast unless `toast.inCombat`: the shell's Hold and Release, set here before a
-- drop is queued and when `toast.inCombat` can change, as well as on the combat edges, so a drop met
-- in combat with no hold in place (a stand-down's or a switch's Clear released it) waits,
-- `toast.inCombat` turned on mid-combat shows what waits, and turned off mid-combat leaves the toast
-- on screen up (Hold(true)) while the next one waits for combat's end.
local function syncHold()
    local want = held()
    if want == toast:Stats().held then return end
    if want then toast:Hold(true) else toast:Release() end
end

-- ── the queue ───────────────────────────────────────────────────────────────────────────────

--- Consider a drop for a toast (DropAdded, DropUpdated): queued once when it qualifies. A test
--- drop's toast is sticky: it stays until it is closed or test mode ends.
--- @param id number
--- @return boolean queued
function Toast.Consider(id)
    if toasted[id] or setting("enabled") ~= true then return false end
    local rec = NS.LootFeed.Get(id)
    -- A drop restored after a reload (feedback-15 spec §0) was toasted, if ever, before it.
    if not rec or rec.source == "restore" or not Toast.Qualifies(rec, setting("minGain")) then return false end
    toasted[id] = true
    syncHold()
    NS.Debug(TAG, "toast queued: drop %s (%d waiting)%s", tostring(id),
        math.min(toast:Stats().waiting + 1, Toast.MAX_QUEUE), held() and ", held in combat" or "")
    toast:Show(id, { key = id, sticky = rec.test == true })
    return true
end

--- Take the toast off screen and show the next one.
function Toast.Dismiss() toast:Dismiss() end

--- The pointer is over the toast: its countdown stops, keeping the time it had left.
function Toast.Pause() toast:Pause() end

--- The pointer left the toast: its countdown resumes with the time it had left.
function Toast.Resume() toast:Resume() end

--- The toast's Ask: the shared host handler, so a second click cancels a queued ask.
function Toast.Ask()
    local id = shownId()
    if not id then return end
    if not NS.LootFeed.Get(id) then return Toast.Dismiss() end
    NS.PressAsk(id)
    local rec, f = NS.LootFeed.Get(id), toast:Frame()
    if rec and f then paintAsk(f, rec) end
end

-- ── edges ───────────────────────────────────────────────────────────────────────────────────

local function onUpdated(id)
    local f = toast:Frame()
    if id == shownId() and f then
        local rec = NS.LootFeed.Get(id)
        if rec then paintAsk(f, rec) end
    end
    Toast.Consider(id)
end

-- A skin switch (OnLooksChanged, after the palette is refilled): the toast on screen repaints its
-- rows' tones, which are set on each paint (the frame and its fixed tones the library and
-- NS.SkinPaint repaint themselves). The toast lives off the window, so the window's repaint never
-- reaches it (inventory R10).
NS.Skin.OnLooksChanged(function()
    local id, f = shownId(), toast and toast:Frame()
    local rec = id and f and f.ask and NS.LootFeed.Get(id)
    if rec then paint(f, rec) end
end)

--- PLAYER_REGEN_DISABLED: a toast on screen goes back to the head of the queue and nothing shows
--- until combat ends, unless toasts may show in combat.
function Toast.OnCombatStart()
    if setting("inCombat") == true then return end
    local id = shownId()
    toast:Hold()
    if id then NS.Debug(TAG, "toast held for combat: drop %s", tostring(id)) end
end

--- PLAYER_REGEN_ENABLED: what combat held shows now.
function Toast.OnCombatEnd()
    if held() then return end
    local s = toast:Stats()
    if s.waiting > 0 and not s.shown then NS.Debug(TAG, "toast: combat over, %d waiting", s.waiting) end
    toast:Release()
end

-- The drop ids waiting for a toast, oldest first: the shell's `keys`. A shell that names none (an
-- earlier copy of the same minor another addon registered first) gets every drop toasted this
-- session instead, in no order: Remove lets go only what waits or shows.
local function waitingIds(s)
    if type(s.keys) == "table" then return s.keys end
    local ids = {}
    for id in pairs(toasted) do ids[#ids + 1] = id end
    return ids
end

--- Drops gone from the feed leave the queue, and a toast whose drop is gone goes (the next one
--- shows). The feed's removal sink: a Clear or the cap's trim. Answers how many it let go.
--- @return number
function Toast.Prune()
    local s = toast:Stats()
    local ids = waitingIds(s)
    ids[#ids + 1] = s.key or false   -- the one on screen last, so the next one shown is never gone
    local n = 0
    for _, id in ipairs(ids) do
        if id and not NS.LootFeed.Get(id) then n = n + toast:Remove(id) end
    end
    if n > 0 then NS.Debug(TAG, "toast: %d gone with their drops", n) end
    return n
end

-- Toasts turned off: the one on screen goes and nothing waits.
local function stopAll(why)
    local s = toast:Stats()
    if s.waiting == 0 and not s.shown then return end
    toast:Clear()
    NS.Debug(TAG, "toast off (%s): queue emptied", why)
end

--- The `toast.enabled` row's reaction: off takes the toast down and empties the queue; on shows
--- nothing old (what was dropped stays dropped), and the next qualifying drop toasts.
--- @param on boolean
function Toast.OnEnabledChanged(on)
    if on ~= true then stopAll("setting") end
end

--- The `toast.inCombat` row's reaction: in combat, turned on shows what waits, and turned off
--- holds what follows the toast on screen (which stays up).
function Toast.OnInCombatChanged() syncHold() end

--- A profile switch, copy or reset (core/DropWatcher.lua's reloadProfile): no row reaction runs,
--- so the incoming `toast.enabled` and `toast.inCombat` are read here, and a built toast takes the
--- incoming scale and point.
function Toast.OnProfileReloaded()
    if setting("enabled") ~= true then stopAll("profile") end
    syncHold()
    toast:Refresh()   -- the incoming profile's scale and point
end

--- Test mode turned on or off (core/DropWatcher.lua NS.SetTestMode): turned off, a test drop's
--- toast goes, and the test drops leave the queue (their feed is already empty).
--- @param on boolean
function Toast.OnTestModeChanged(on)
    if on then return end
    Toast.Prune()
end

--- The `toast.scale` row's reaction: a built toast, on screen or not, takes the new scale about its
--- saved anchor (the point itself is unchanged). Before the first toast there is nothing to scale;
--- the build applies it.
function Toast.ApplyScale() toast:Refresh() end

--- Forget the saved position: the toast goes back under the top of the screen.
function Toast.ResetPosition() toast:ResetPosition() end

--- The toast's state, for the diagnostics report and the suites: { built, shown, dropId, waiting,
--- queue (the waiting drop ids, oldest first), held, point }.
--- @return table
function Toast.Stats()
    local s = toast:Stats()
    return { built = s.built, shown = s.shown, dropId = s.key, waiting = s.waiting, queue = s.keys or {},
        held = s.held, point = store().point }
end

--- The built frame, or nil before the first toast. For the suites.
function Toast.Frame() return toast:Frame() end

--- The shell's instance. For the suites.
function Toast.Shell() return toast end

local EVENTS = {
    { "PLAYER_REGEN_DISABLED", "OnToastCombatStart", Toast.OnCombatStart },
    { "PLAYER_REGEN_ENABLED", "OnToastCombatEnd", Toast.OnCombatEnd },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function() fn() end
end

-- Tracked, so the stand-down takes them down and the stand-up replays them. Without the bus
-- library it is a bare target, unregistered here instead (NS.Bus.tracked says which).
local target = NS.Bus:NewTarget()

-- Not a registration: a plain function the feed calls, so nothing to take down on the stand-down.
NS.LootFeed.AddRemovalSink(function() Toast.Prune() end)

local function listen()
    if not target then return end
    local M = NS.MSG
    target:RegisterMessage(M.DROP_ADDED, function(_, id) Toast.Consider(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function(_, id) onUpdated(id) end)
    target:RegisterMessage(M.ASK_STATE_CHANGED, function(_, id) if id == shownId() then onUpdated(id) end end)
end
listen()

-- The stand-down: the shell's Clear (nothing on screen, nothing waiting, no hold), and every drop
-- may toast again after the stand-up.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    toasted = {}
    toast:Clear()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
