local _, NS = ...
-- modules/SideCells.lua — the Me and Them cells of the drop tables (feedback-6 spec §1, DW-F1): what
-- you (or the looter) wear in the drop's slot and the verdict on the drop, in one cell where My eq,
-- Their eq, Me and Them were four columns:
--
--   [icon(s)] [item level] [glyph][difference]      321/308 ▼8 · 276 ▲12 · 311 ≈0 · 334 Can't use
--
-- THE GEAR PART is WindowCells.MyEq's or TheirEq's answer: the worn items (the icons are the
-- edge's; two for rings, trinkets and one-hand weapons) and their item levels (`321`, `321/308`) in
-- the plain tone, else a muted word: `empty` when nothing is worn there, or the state that keeps the
-- gear unread (`…`, `range`, `combat`, `!`, `–`).
-- THE VERDICT PART is WindowCells.Me's or Them's answer: the glyph and the absolute item-level
-- difference with no sign (the glyph says which way), both in the verdict's tone (green up, yellow
-- side, red down); `Can't use` and `Not wanted` stay words (gray). An unknown verdict's `?` is left
-- out when the gear part already says why (a state word), and shown when it does not. A dash in the
-- gear part goes when the verdict part has something to say.
-- OFF-SPEC (feedback-19 spec §1): a verdict cell of NS.OffSpecCells (`offSpec` set) is followed by
-- its spec's name, `▲20 Holy`, in the offspec cyan, and the Me cell's gear part is the item it was
-- compared with (OffSpecCells.Eq: a bag item, a worn one or `empty`), not what you wear.
-- YOUR OWN DROP'S THEM is MineCells.Details's `Upgrade for N` (or `No upgrades`, `Hidden`), its tones and its tooltip.
-- History keeps no worn items, so its cells are the verdict part alone (SC.Merge with no gear).
-- THE OFFER PANEL'S THEIR EQ (feedback-7 spec §0) is the same cell for one candidate (SC.Candidate):
-- what they wear from their inspect read (else the worn item their verdict was judged against), and
-- the verdict on your drop for them; `…` while checking, `Unavailable` when nothing could be read.
-- An off-spec candidate (feedback-19 spec §3) is that spec's cell, `311 ▲14 Holy` in the offspec
-- cyan, beside the item it was judged against.
--
-- THE TOOLTIP (feedback-7 spec §3) is the verdict's title, then the worn gear as a grid
-- (NS.TipMarks.GearRows: `[Name] [ilvl] [worn item] [▲diff]`, a row per worn item, the arrow on the
-- one the drop would replace, `empty` for a slot worn empty), then the gear's own lines (the
-- inspect's age, or why nothing was read) and the verdict's (its explanation, the track, the score
-- and the reasons). The verdict's own one-row grid gives way to the gear's; with no gear listed it
-- stays. A line already said is not said twice.
--
-- PURE. Every composer takes the drop record and plain inputs and answers a plain table; nothing here
-- reads a module's state, the client or a saved variable. The full tables paint it
-- (modules/WindowGroup.lua, modules/WindowHistory.lua) and the compact cards' line 3 reads it
-- (modules/CompactCards.lua).
--
--   cell = { items, level, levelTone, glyph, text, tone, tip, verdict, upgrades, hidden,
--            offSpec, mainVerdict }   (the last two an off-spec cell's)
--   (`level` nil with no gear part; `text` "" when the verdict part is left out)

NS.SideCells = NS.SideCells or {}
local SC = NS.SideCells
local L  = NS.L
local WC = NS.WindowCells
local MC = NS.MineCells
local TM = NS.TipMarks
local OC = NS.OffSpecCells

local DASH = "–"

-- The gear part's words that already say why a verdict is unknown.
local EXPLAINS = { ["…"] = true, [DASH] = true, ["!"] = true, [L["range"]] = true, [L["combat"]] = true }
SC.EXPLAINS = EXPLAINS

-- The gear part: the worn levels (plain; also a level known without its item), else the muted
-- word; `empty slot` reads `empty`.
local function gearPart(eq)
    if type(eq) ~= "table" then return nil, nil end
    if (type(eq.items) == "table" and #eq.items > 0) or eq.tone == "plain" then return eq.text, "plain" end
    if eq.text == L["empty slot"] then return L["empty"], "muted" end
    return eq.text, "muted"
end

-- The verdict part: the glyph and the unsigned difference, a word, or "" for an unknown verdict
-- the gear part explains.
local function verdictPart(v, level)
    local text = v.text or ""
    if v.glyph then
        local n = text:match("^[%+%-]?(%d+)$")
        if n then return v.glyph, n end
        return v.glyph, level and "" or text   -- no difference (an empty slot): the gear part says so
    end
    if v.verdict == "unknown" and level and EXPLAINS[level] then return nil, "" end
    return nil, text
end

-- The worn gear as a grid, or nil when the gear part lists none (a state word, no gear part).
local function gearGrid(eq, v)
    if type(eq) ~= "table" then return nil end
    local items = eq.gridItems or (type(eq.items) == "table" and eq.items) or {}
    local empty = eq.empty or 0
    if #items == 0 and empty == 0 then return nil end
    return TM.Grid(TM.GearRows(v.who or "?", items, empty, TM.ArrowCell(v.verdict, v.delta, v.offSpec and v.tone), v.base))
end

-- The verdict's title, the gear grid (else the verdict's own), the gear's lines after its title,
-- then the verdict's; a line already said is not said twice.
local function mergedTip(eq, v)
    local out, seen = {}, {}
    local vt = type(v.tip) == "table" and v.tip or {}
    local grid = gearGrid(eq, v)
    local function add(l, from)
        if from == "verdict" and grid and TM.IsGrid(l) then return end
        if type(l) == "table" or not seen[l] then
            seen[l] = true
            out[#out + 1] = l
        end
    end
    if vt[1] ~= nil then add(vt[1]) end
    if grid then add(grid) end
    local et = type(eq) == "table" and type(eq.tip) == "table" and eq.tip or {}
    for i = 2, #et do add(et[i]) end
    for i = 2, #vt do add(vt[i], "verdict") end
    return out
end

--- One merged cell: a verdict cell (WindowCells.Me, Them or Verdict; MineCells.Details) after an
--- equipment cell (WindowCells.MyEq or TheirEq; nil for the verdict alone).
--- @param v table the verdict cell
--- @param eq table|nil the equipment cell
--- @return table cell
function SC.Merge(v, eq)
    local level, levelTone = gearPart(eq)
    local glyph, text = verdictPart(v, level)
    if level == DASH and (glyph or text ~= "") then level, levelTone = nil, nil end
    if v.spec then text = text == "" and v.spec or ("%s %s"):format(text, v.spec) end   -- `▲20 Holy`
    return { items = type(eq) == "table" and eq.items or {}, level = level, levelTone = levelTone,
        glyph = glyph, text = text, tone = v.tone, tip = mergedTip(eq, v), verdict = v.verdict,
        upgrades = v.upgrades, hidden = v.hidden, offSpec = v.offSpec, mainVerdict = v.mainVerdict }
end

--- The Me cell: what you wear in the drop's slot (your gear snapshot's) and the drop judged for you;
--- for an off-spec verdict, the item it was compared with in place of what you wear.
--- @param drop table
--- @param equipped table|nil the gear snapshot's `equipped`
--- @param classFile string|nil your class (the snapshot's), for the tooltip grid's `You`
--- @return table cell
function SC.Me(drop, equipped, classFile)
    local v = WC.Me(drop, classFile)
    return SC.Merge(v, v.offSpec and OC.Eq(v) or WC.MyEq(drop, equipped))
end

--- The Them cell: what the looter wears there (their inspect read's) and the drop judged for them;
--- on your own drop `Upgrade for N` (MineCells.Details), every member it upgrades in the tooltip.
--- @param drop table
--- @param gear table|nil the looter's inspect gear
--- @param now number|nil GetTime()
--- @param revealed boolean|nil your own drop's Offer panel was opened this session
--- @return table cell
function SC.Them(drop, gear, now, revealed)
    if drop.isMine then return SC.Merge(MC.Details(drop, revealed, L["Them"])) end
    return SC.Merge(WC.Them(drop, now), WC.TheirEq(drop, gear, now))
end

-- ── the Offer panel's Their eq (feedback-7 spec §0) ─────────────────────────────────────────

local num = WC.Num

-- The item their verdict was judged against stands in when the read gave nothing: as a row with
-- its icon when its link is known, else as its level alone (a grid row with no icon).
local function fromBaseline(c, base)
    if type(base.link) == "string" then
        c.items[1] = { link = base.link, ilvl = base.ilvl }
        c.text, c.tone = WC.Levels(c.items), "plain"
    elseif num(base.ilvl) then
        c.text, c.tone = WC.Levels({ base }), "plain"
        c.gridItems = { base }   -- a level known without its item: no icon, but a grid row
    end
end

-- The gear part of one candidate: their read (WindowCells.SlotItems, the Them cell's rule: both
-- rings, both trinkets, a slot read empty counted), else the item their verdict was judged against.
-- An off-spec candidate (feedback-19 spec §3) shows only the item the off-spec verdict was judged
-- against (MineCells' `baseline`, the off-spec one), else an empty slot: what the main spec wears
-- there is not what the drop was compared with.
-- `items` and `empty` are the tooltip grid's rows (SC.Merge); its other lines, the read's age.
local function candidateEq(drop, e, insp, now)
    local slots = WC.EqSlots(type(drop.facts) == "table" and drop.facts.equipLoc or nil) or {}
    local ok = WC.ReadOk(insp)
    local offSpec = NS.OffSpec.Of(e.eval) ~= nil
    local items, empty = WC.SlotItems(ok and not offSpec and insp.gear or nil, slots)
    local c = { items = items, empty = empty, tone = "muted", tip = { L["%s wears"]:format(e.short) } }
    if #items > 0 then
        c.text, c.tone = WC.Levels(items), "plain"
    elseif empty == 0 and e.baseline then
        fromBaseline(c, e.baseline)
    end
    if not c.text then
        if empty > 0 or (e.eval and NS.OffSpec.EvalFor(e.eval).verdict == "upgrade") then
            c.text, c.empty = L["empty slot"], math.max(empty, 1)
        else
            c.text = DASH
        end
    end
    if ok then c.tip[#c.tip + 1] = WC.InspectLine(insp, e.short, now) end
    return c
end

-- The verdict part of one candidate: WindowCells.Verdict's for a judged one, else `…` or
-- `Unavailable`; the status's explanation (MineCells.Candidates' `explain`) under the title.
local UNREAD = { checking = { "…", L["Checking"] }, unavailable = { L["Unavailable"], L["Unavailable"] } }

local function candidateVerdict(drop, e)
    local w = UNREAD[e.status]
    local v
    if w then
        v = { text = w[1], tone = "muted", verdict = e.status, tip = { ("%s: %s"):format(e.short, w[2]) } }
    else
        v = WC.Verdict(e.eval, "them", L["For %s"]:format(e.short), num(type(drop.facts) == "table" and drop.facts.ilvl),
            TM.ClassName(e.short, e.classFile))
    end
    if e.explain then table.insert(v.tip, 2, e.explain) end
    return v
end

--- The Offer panel's Their eq cell (feedback-7 spec §0): one candidate (an entry of
--- MineCells.Candidates) in the Them cell's look, `276 ▲19`, `321/308 ▼4`, `311 ≈0`, `Can't use`,
--- `…` while checking, `Unavailable` when nothing could be read, `empty ▲` into an empty slot.
--- @param drop table one of your drops
--- @param e table the candidate (MineCells.Candidates' entry)
--- @param insp table|nil their inspect entry (NS.Inspect.Get), whose `gear` gives both worn items
--- @param now number|nil GetTime(), for the read's age
--- @return table cell
function SC.Candidate(drop, e, insp, now)
    local v = candidateVerdict(drop, e)
    if UNREAD[e.status] then return SC.Merge(v) end
    local eq = candidateEq(drop, e, insp, now)
    if v.verdict == "unknown" and eq.text == DASH then v.text, eq.text = L["Unavailable"], nil end
    return SC.Merge(v, eq)
end
