local _, NS = ...
-- modules/OffSpecCells.lua — how off-spec looks (feedback-19 spec §1): a drop the current spec
-- cannot use (`cantUse`) that another spec of the class can (eval.offSpec, modules/OffSpec.lua)
-- shows as that spec's verdict, in the `offspec` cyan (C.TONE.offspec), followed by the spec's name:
--
--   Me cell  291 ▲20 Holy        compact  You 291 ▲20 Holy        detail chip  OFF-SPEC UPGRADE
--
-- THE CELL (OC.Verdict) is what NS.WindowCells.Verdict answers when its eval carries an off-spec
-- part: the off-spec glyph and difference (▲ ≈ ▼) in the offspec tone for every off-spec verdict;
-- `verdict` is the off-spec verdict, `offSpec` its spec id, `mainVerdict` the main `cantUse` and
-- `spec` the spec's name, which NS.SideCells writes after the difference. Its tooltip says what the
-- main spec cannot do and what the drop was compared with: "Off-spec upgrade for Holy",
-- "Protection can't use it: Its primary stat does not suit the spec.", "Compared with your best
-- Holy item: Bag Mace 291." (`their` on the looter's side), the comparison's grid row, the track and
-- the off-spec pass's own reasons.
--
-- THE GEAR HALF (OC.Eq) of the Me cell is the off-spec baseline, not your worn gear: the bag or worn
-- item the drop was compared with, or `empty`. A bag item carries no inventory slot, so its icon's
-- tooltip is read from its link (modules/WindowGroup.lua's paintSide).
--
-- THE CARDS. OC.SpecRow is the detail card's and the History card's Spec row, `Holy (off-spec):
-- Protection can't use it`; their chips and rows are modules/DetailCells.lua's and
-- modules/HistoryCard.lua's, read from the off-spec part.
--
-- THE ASK (feedback-19 spec §2). OC.AskTip is the Ask button's tooltip when it fills the
-- `askOffSpec` template: "Ask for it for your Holy off-spec."
--
-- PURE but for the spec names: plain tables in, plain tables out; a spec's name is read at call time
-- from NS.Compat.SpecName (the client's GetSpecializationInfoByID), with words when it gives none.
-- The marks are NS.TipMarks' with the offspec tone (TM.Mark / TM.ArrowCell's override).

NS.OffSpecCells = NS.OffSpecCells or {}
local OC = NS.OffSpecCells
local L  = NS.L
local WC = NS.WindowCells
local TM = NS.TipMarks

local TONE = "offspec"
OC.TONE = TONE

--- The legend's line (the Me column's tooltip, the Offer panel's Their eq).
OC.LEGEND = L["Cyan: an upgrade for another of your specs (off-spec); your current spec can't use it."]

local TITLE = {
    upgrade = L["Off-spec upgrade for %s"], sidegrade = L["Off-spec sidegrade for %s"],
    downgrade = L["Off-spec downgrade for %s"],
}

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- A spec's name (the client's), else `Off-spec`.
--- @param specID number|nil
--- @return string
function OC.SpecName(specID)
    return NS.Compat.SpecName(specID) or L["Off-spec"]
end

-- The main spec's name, else `Your spec`.
local function mainName(off)
    return NS.Compat.SpecName(off.mainSpecID) or L["Your spec"]
end

-- Why the main spec cannot use it: the first refusal that depends on the spec, in words.
local function refusal(eval)
    for _, r in ipairs(type(eval.reasons) == "table" and eval.reasons or {}) do
        if NS.OffSpec.SPEC_REASONS[r.key] then return WC.EVAL_REASON[r.key] end
    end
    return nil
end

local function cantLine(eval, off)
    local why = refusal(eval)
    if why then return L["%s can't use it: %s"]:format(mainName(off), why) end
    return L["%s can't use it."]:format(mainName(off))
end

-- What the drop was compared with: `Bag Mace 291`, `291`, or an empty slot. A History snapshot
-- keeps no baseline, only the difference, so its level is the drop's less that difference; with no
-- difference either, it was an empty slot.
local function baseWords(off, ilvl)
    local base, d = off.baseline, num(off.ilvlDelta)
    if type(base) ~= "table" then
        if d and ilvl then return tostring(math.floor(ilvl - d + 0.5)) end
        return d and "?" or L["an empty slot"]
    end
    local n = num(base.ilvl)
    local level = n and tostring(math.floor(n + 0.5)) or "?"
    local name = WC.ItemName(base.link)
    return name and ("%s %s"):format(name, level) or level
end

local function compareLine(side, spec, off, ilvl)
    local fmt = side == "me" and L["Compared with your best %s item: %s."] or L["Compared with their best %s item: %s."]
    return fmt:format(spec, baseWords(off, ilvl))
end

local function trackLine(td)
    if type(td) ~= "table" then return nil end
    if td.sign > 0 then return L["Upgrade track: a higher track or rank."] end
    if td.sign < 0 then return L["Upgrade track: a lower track or rank."] end
    return L["Upgrade track: the same track and rank."]
end

-- The comparison as one grid row, as the main verdict's, its arrow in the offspec tone.
local function gridLine(off, ilvl, who)
    local d = num(off.ilvlDelta)
    if not (d and ilvl) then return nil end
    local base = type(off.baseline) == "table" and off.baseline or {}
    local worn = { link = base.link, name = base.name, quality = base.quality, ilvl = ilvl - d }
    return TM.Grid(TM.GearRows(who or "?", { worn }, 0, TM.ArrowCell(off.verdict, d, TONE), worn))
end

local function tipOf(eval, off, side, title, ilvl, who, spec)
    local lines = { ("%s: %s"):format(title, TITLE[off.verdict]:format(spec)), cantLine(eval, off),
        compareLine(side, spec, off, ilvl) }
    lines[#lines + 1] = gridLine(off, ilvl, who)
    lines[#lines + 1] = trackLine(off.trackDelta)
    for _, r in ipairs(type(off.reasons) == "table" and off.reasons or {}) do
        lines[#lines + 1] = WC.EVAL_REASON[r.key] or tostring(r.key)
    end
    return lines
end

--- The verdict cell of a `cantUse` with an off-spec part (WindowCells.Verdict's shape, plus
--- `offSpec`, `mainVerdict` and `spec`).
--- @param eval table the main verdict (NS.Evaluate's, or a History snapshot)
--- @param off table its off-spec part (NS.OffSpec.Of)
--- @param side string `me` or `them`
--- @param title string the tooltip's subject (`For you`, `For Seta`)
--- @param ilvl number|nil the drop's item level
--- @param who string|nil the grid's name cell
--- @return table cell
function OC.Verdict(eval, off, side, title, ilvl, who)
    local d = num(off.ilvlDelta)
    local spec = OC.SpecName(off.specID)
    return {
        text = d and WC.Signed(d) or L["empty"], glyph = WC.GLYPH[off.verdict], tone = TONE,
        tip = tipOf(eval, off, side, title, ilvl, who, spec), verdict = off.verdict, who = who, delta = d,
        base = type(off.baseline) == "table" and off.baseline or nil,
        offSpec = off.specID, mainVerdict = eval.verdict, spec = spec,
    }
end

--- The Me cell's gear half for an off-spec cell: the item it was compared with (a bag item with no
--- inventory slot, a worn one with its own), else `empty slot`. WindowCells.MyEq's shape.
--- @param v table OC.Verdict's cell
--- @return table cell { text, tone, tip, items, empty, gridItems? }
function OC.Eq(v)
    local base = v.base
    local c = { text = L["empty slot"], tone = "muted", tip = { L["Your best %s item"]:format(v.spec) }, items = {}, empty = 1 }
    if type(base) ~= "table" then return c end
    c.empty = 0
    if type(base.link) == "string" then
        c.items[1] = { link = base.link, ilvl = base.ilvl, slot = num(base.slot) }
        c.text, c.tone = WC.Levels(c.items), "plain"
    else
        c.text, c.tone = WC.Levels({ base }), "plain"
        c.gridItems = { base }   -- a level known without its item: no icon, but a grid row
    end
    return c
end

--- The cards' Spec row: `Holy (off-spec): Protection can't use it`.
--- @param off table the off-spec part (NS.OffSpec.Of)
--- @return table row { key, label, text, tone, tip }
function OC.SpecRow(off)
    return { key = "spec", label = L["Spec"], tone = TONE,
        text = L["%s (off-spec): %s can't use it"]:format(OC.SpecName(off.specID), mainName(off)),
        tip = { L["Spec"], L["Your current spec can't use it, so it is judged for another spec of your class, on item level alone."] } }
end

--- The Ask button's tooltip for an off-spec ask (feedback-19 spec §2, NS.WindowCells.Ask's
--- `askOffSpec` template): it names the spec the drop is asked for.
--- @param drop table a feed record
--- @param who string the looter's short name
--- @return string title, string ...
function OC.AskTip(drop, who)
    local off = NS.OffSpec.Of(type(drop) == "table" and drop.me or nil)
    return L["Ask for off-spec"], L["Ask for it for your %s off-spec."]:format(OC.SpecName(off and off.specID)),
        L["Whisper %s your For off-spec template: your current spec can't use it."]:format(who),
        L["One ask per item per looter."]
end
