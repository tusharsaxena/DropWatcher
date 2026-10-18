local _, NS = ...
-- modules/DetailCells.lua — what the detail card says (design spec §11.3, board 02): the item
-- header's chips, the For you and For the looter comparisons, the trade estimate box and the
-- actions, each with its reason tooltip. Nothing is ever blank: a value not known says `–` or `?`
-- and its tooltip says why.
--
-- PURE. Every composer takes the drop record (modules/LootFeed.lua's shape) and plain inputs (the
-- clock, the looter's inspect entry and spec name, the ask's state, the trade guard's answer) and
-- answers plain tables; nothing here reads a module, the client or a saved variable, so
-- test_detail_card drives each state case by case. The frame edge that paints them is
-- modules/DetailCard.lua. The verdict, trade and ask wording is modules/WindowCells.lua's, so the
-- card and the row it expands never disagree; on your own drop (feedback-5 spec §2) the Them row's
-- `Upgrade for N` (feedback-7 spec §2) and the Offer in place of Ask are modules/MineCells.lua's, as the row's are.
--
-- OFF-SPEC (feedback-19 spec §1). A `cantUse` with an off-spec part (NS.OffSpec.Of) takes its FOR
-- YOU chip (`OFF-SPEC UPGRADE`, in the offspec cyan) and its Replaces, Item level, Track and Stats
-- rows from that part, with a Spec row first (NS.OffSpecCells.SpecRow); a bag item it was compared
-- with sets no `wornSlot`, so its tooltip is read from its link. The score row says off-spec is
-- judged on item level alone. The looter's side does the same from their off-spec part, its Spec
-- row keyed `offSpec` ahead of their own inspected `spec` row.
--
-- NO GLYPHS. The card draws in the default face, which has no `→` and no `▲ ≈ ▼` (feedback-6 spec
-- §3, DW-F5): the verdict chip's mark, the Item level and Track rows' arrow and the Track row's mark
-- are NS.TipMarks' inline textures (TM.Mark, TM.Arrow), never the table cells' monospace glyphs.
--
--   chip = { text, tone?, tip = { title, lines... } }
--   side = { title, verdict = { text, tone, tip }, rows = { { key, label, text, tone, tip, link, classFile, you } } }
--     (`classFile` and `you`: your own drop's Looter row, the name in class color and ` [YOU]` in gold)
--   box  = { chip = { text, tone }, text, meta, tip }
--   act  = { key, text, icon, enabled, tip }

NS.DetailCells = NS.DetailCells or {}
local DC = NS.DetailCells
local C  = NS.Constants
local L  = NS.L
local WC = NS.WindowCells
local MC = NS.MineCells
local TM = NS.TipMarks

local floor, abs = math.floor, math.abs

local DASH = "–"

-- The stats a chip or a stat line names, by C_Item.GetItemStats key.
local PRIMARY = {
    ITEM_MOD_STRENGTH_SHORT = L["Str"], ITEM_MOD_AGILITY_SHORT = L["Agi"], ITEM_MOD_INTELLECT_SHORT = L["Int"],
}
local PRIMARY_ORDER = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT" }
local SECONDARY = {
    ITEM_MOD_CRIT_RATING_SHORT = L["Crit"], ITEM_MOD_HASTE_RATING_SHORT = L["Haste"],
    ITEM_MOD_MASTERY_RATING_SHORT = L["Mastery"], ITEM_MOD_VERSATILITY = L["Vers"],
}
local SECONDARY_ORDER = {
    "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY",
}
local TERTIARY = {
    ITEM_MOD_CR_LIFESTEAL_SHORT = L["Leech"], ITEM_MOD_CR_SPEED_SHORT = L["Speed"],
    ITEM_MOD_CR_AVOIDANCE_SHORT = L["Avoidance"], ITEM_MOD_CR_STURDINESS_SHORT = L["Indestructible"],
}
local TERTIARY_ORDER = {
    "ITEM_MOD_CR_LIFESTEAL_SHORT", "ITEM_MOD_CR_SPEED_SHORT", "ITEM_MOD_CR_AVOIDANCE_SHORT", "ITEM_MOD_CR_STURDINESS_SHORT",
}


-- Each bind's chip: { word, its Binds row's value, its Tradeable row's value or nil }.
local BIND_CHIP = {
    [C.BIND.ON_ACQUIRE] = { L["BoP"], L["on pickup, to whoever loots it"] },
    [C.BIND.ON_EQUIP] = { L["BoE"], L["on equip"], L["until someone wears it"] },
    [C.BIND.ON_USE] = { L["BoU"], L["on use"], L["until someone uses it"] },
    [C.BIND.QUEST] = { L["Quest"], L["a quest item"] },
}

local VERDICT_CHIP = {
    upgrade = L["UPGRADE"], sidegrade = L["SIDEGRADE"], downgrade = L["DOWNGRADE"],
    cantUse = L["CAN'T USE"], doesntWant = L["DOESN'T WANT"], unknown = L["UNKNOWN"],
}

-- An off-spec verdict's chip (feedback-19 spec §1).
local OFF_SPEC_CHIP = {
    upgrade = L["OFF-SPEC UPGRADE"], sidegrade = L["OFF-SPEC SIDEGRADE"], downgrade = L["OFF-SPEC DOWNGRADE"],
}

local TRADE_CHIP = {
    yes = L["TRADEABLE"], likely = L["LIKELY TRADEABLE"], unknown = L["TRADE UNKNOWN"], no = L["NOT TRADEABLE"],
}
local TRADE_TONE = WC.TRADE_TONE   -- the Trade column's tones (No red, feedback-7 spec §2)
local RULE_WORD = { personal = L["personal loot"], group = L["group loot"], legacy = L["legacy loot"] }
local BASIS_WORD = { bind = L["the item's bind"], rule = L["the content's rule"], inspect = L["inspect"], timer = L["your bag's timer"] }

-- ── small helpers ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function round(n) return floor(n + 0.5) end

local function facts(drop) return type(drop.facts) == "table" and drop.facts or {} end

local function looterName(drop)
    local who = type(drop.looter) == "table" and drop.looter or {}
    return WC.ShortName(who.name)
end

local function chip(text, title, ...)
    return { text = text, tip = { title, ... } }
end

local function row(key, label, text, tone, title, ...)
    return { key = key, label = label, text = text, tone = tone or "plain", tip = { title, ... } }
end

-- One tooltip row and the closing hint (NS.TipMarks, feedback-21).
local function trow(label, value, tone) return TM.Row(label, value, tone) end
local function hint(text) return TM.Hint(text) end

-- ── the header's chips ──────────────────────────────────────────────────────────────────────

local function slotChip(f)
    local label = WC.SlotLabel(f.equipLoc)
    if not label then return chip(DASH, L["Slot"], trow(L["Item"], L["not worn, or not loaded"])) end
    return chip(label, L["Slot"], trow(L["Worn in"], label))
end

-- The Type column's answer as a chip (feedback-4 spec §3: Cloth … Plate, Jewelry, Trinkets, Cloak,
-- Weapons); none when the type is not known.
local function armorChip(f)
    local t = WC.ArmorType({ facts = f })
    if not t.known then return nil end
    return chip(t.text, L["Type"], t.tip[2])
end

local function bindChip(f)
    if f.warbound then
        return chip(L["Warbound"], L["Bind"], trow(L["Binds"], L["to the account"]), trow(L["Tradeable"], L["no"]))
    end
    local b = BIND_CHIP[f.bindType]
    if not b then return nil end
    local c = chip(b[1], L["Bind"], trow(L["Binds"], b[2]))
    c.tip[3] = b[3] and trow(L["Tradeable"], b[3]) or nil
    return c
end

-- `Hero 2/6`, or nil for no track.
local function trackText(tr)
    if type(tr) ~= "table" or not tr.name then return nil end
    return ("%s %s/%s"):format(tr.name, tostring(tr.rank or "?"), tostring(tr.max or "?"))
end

local function trackChip(f)
    local text, ilvl = trackText(f.track), num(f.ilvl)
    if not text then
        if not ilvl then return nil end
        return chip(tostring(ilvl), L["Item level %d"]:format(ilvl), trow(L["Upgrade track"], L["none"]))
    end
    local c = chip(ilvl and ("%s · %d"):format(text, ilvl) or text, L["Upgrade track"], trow(L["Track and rank"], text))
    c.tip[3] = ilvl and trow(L["Item level"], ilvl) or nil
    return c
end

-- The look: `New look` when you have not collected the appearance, `Look known` when you have,
-- nothing when it is not known or the item has none (design spec §4, transmog-known).
local function transmogChip(f)
    if f.transmogKnown == false then
        local c = chip(L["New look"], L["Transmog"], trow(L["Appearance"], L["not collected yet"], "good"))
        c.tone = "good"
        return c
    end
    if f.transmogKnown == true then
        local c = chip(L["Look known"], L["Transmog"], trow(L["Appearance"], L["already collected"]))
        c.tone = "muted"
        return c
    end
    return nil
end

local function primaryChip(stats)
    local names = {}
    for _, key in ipairs(PRIMARY_ORDER) do
        if num(stats[key]) then names[#names + 1] = PRIMARY[key] end
    end
    if #names == 0 then return nil end
    local text = table.concat(names, "/")
    return chip(text, L["Primary stat"], trow(L["Carries"], text), trow(L["Usable by"], L["specs of that primary stat"]))
end

local function hasSocket(stats)
    for key, v in pairs(stats) do
        if type(key) == "string" and key:find("^EMPTY_SOCKET_") and num(v) then return true end
    end
    return false
end

local function extraChips(stats, out)
    if hasSocket(stats) then out[#out + 1] = chip(L["Socket"], L["Socket"], trow(L["Has"], L["a gem socket"])) end
    for _, key in ipairs(TERTIARY_ORDER) do
        if num(stats[key]) then
            out[#out + 1] = chip(TERTIARY[key], L["Tertiary stat"], trow(L["Carries"], TERTIARY[key]))
        end
    end
end

--- The item header's chips (board 02, callout 1): slot, armor type, bind, track and rank, the look
--- (transmog), primary stat, socket and tertiary stats. A chip with nothing to say is left out; the
--- slot always shows.
--- @param drop table
--- @return table list of chips
function DC.Chips(drop)
    local f = facts(drop)
    local stats = type(f.stats) == "table" and f.stats or {}
    local out = { slotChip(f) }
    for _, fn in ipairs({ armorChip, bindChip, trackChip, transmogChip }) do
        local c = fn(f)
        if c then out[#out + 1] = c end
    end
    out[#out + 1] = primaryChip(stats)
    extraChips(stats, out)
    return out
end

-- ── the comparison rows ─────────────────────────────────────────────────────────────────────

local function baseOf(eval)
    return type(eval) == "table" and type(eval.baseline) == "table" and eval.baseline or nil
end

local function emptySlot(eval)
    if type(eval) ~= "table" or type(eval.reasons) ~= "table" then return false end
    for _, r in ipairs(eval.reasons) do if r.key == "emptySlot" then return true end end
    return false
end

-- `mine`: the item is yours, so its slot is kept for the real tooltip (`wornSlot`, DW-80).
local function replacesRow(eval, whose, mine)
    local base = baseOf(eval)
    if base then
        local name = WC.ItemName(base.link) or "?"
        local r = row("replaces", L["Replaces"], ("%s · %s"):format(name, tostring(num(base.ilvl) or "?")), "plain",
            L["Replaces"], trow(L["Takes off"], L["the item %s wears there"]:format(whose)),
            trow(L["Of two"], L["the lower"]))
        r.link = base.link
        r.wornSlot = mine and num(base.slot) or nil
        return r
    end
    if emptySlot(eval) then
        return row("replaces", L["Replaces"], L["Empty slot"], "good", L["Replaces"], trow(L["Slot"], L["empty (anything is an upgrade)"]))
    end
    return row("replaces", L["Replaces"], DASH, "muted", L["Replaces"], trow(L["Worn item"], L["not read"]))
end

local function ilvlRow(eval, ilvl, tone)
    local d = type(eval) == "table" and num(eval.ilvlDelta) or nil
    if not (d and ilvl) then
        return row("ilvl", L["Item level"], ilvl and tostring(ilvl) or "?", "muted", L["Item level"],
            trow(L["Change"], L["nothing to compare with yet"]))
    end
    local from = round(ilvl - d)
    return row("ilvl", L["Item level"], ("%d %s %d · %s"):format(from, TM.Arrow(), ilvl, WC.Signed(d)), tone, L["Item level"],
        trow(L["This item"], ilvl), trow(L["Worn"], from), trow(L["Change"], WC.Signed(d), tone))
end

local TRACK_MARK = { [1] = "upgrade", [0] = "sidegrade", [-1] = "downgrade" }   -- TM.Mark's verdicts

-- Shown even within one track (board 02, callout 2): a rank change is still a change.
local function missingTrack(to)
    if to then return row("track", L["Track"], to, "muted", L["Track"], trow(L["This item"], to), trow(L["Worn"], L["not read"])) end
    return row("track", L["Track"], DASH, "muted", L["Track"], trow(L["This item"], L["no upgrade track"]))
end

local function trackRow(eval, dropTrack)
    local base = baseOf(eval)
    local to, from = trackText(dropTrack), trackText(base and base.track)
    if not (to and from) then return missingTrack(to) end
    local td = type(eval.trackDelta) == "table" and eval.trackDelta or nil
    if not td then
        return row("track", L["Track"], ("%s %s %s"):format(from, TM.Arrow(), to), "plain", L["Track"],
            trow(L["This item"], to), trow(L["Worn"], from), trow(L["Ranked"], L["no, the tracks don't compare"]))
    end
    return row("track", L["Track"], ("%s %s %s %s"):format(from, TM.Arrow(), to, TM.Mark(TRACK_MARK[td.sign])), "plain", L["Track"],
        trow(L["This item"], to), trow(L["Worn"], from), WC.TrackRow(td))
end

--- The secondary-stat change from `base` to `item`, the largest first: `+130 Haste -119 Mastery`,
--- or nil when neither carries a secondary stat.
--- @param item table|nil the drop's facts.stats
--- @param base table|nil the replaced item's facts.stats
--- @return string|nil
function DC.StatChange(item, base)
    item, base = type(item) == "table" and item or {}, type(base) == "table" and base or {}
    local parts = {}
    for _, key in ipairs(SECONDARY_ORDER) do
        local d = (num(item[key]) or 0) - (num(base[key]) or 0)
        if d ~= 0 then parts[#parts + 1] = { d = d, label = SECONDARY[key] } end
    end
    if #parts == 0 then return nil end
    table.sort(parts, function(a, b) return abs(a.d) > abs(b.d) end)
    local out = {}
    for _, p in ipairs(parts) do out[#out + 1] = ("%s %s"):format(WC.Signed(p.d), p.label) end
    return table.concat(out, " ")
end

local function statsRow(eval, dropStats)
    local base = baseOf(eval)
    if not base then
        return row("stats", L["Stats"], DASH, "muted", L["Stats"], trow(L["Worn item"], L["not read"]))
    end
    local text = DC.StatChange(dropStats, base.stats)
    if not text then return row("stats", L["Stats"], L["no change"], "plain", L["Stats"], trow(L["Secondary stats"], L["the same"])) end
    return row("stats", L["Stats"], text, "plain", L["Stats"], trow(L["Secondary stats"], text))
end

-- The score line by the scorer in use (modules/Scoring.lua's InUse): its label, and why there is
-- no score when there is none.
local SCORER_LINE = {
    pawn    = { label = L["Pawn"], none = { L["not scored by Pawn yet"] } },
    weights = { label = L["Weights"],
                none = { L["your weights score nothing for this spec"], L["Set them in Settings, Comparison."] } },
    none    = { label = L["Score"], none = { L["no scorer in use (item level alone)"] } },
}

local function scoreRow(eval, scorer, offSpec)
    if scorer == true then scorer = "pawn" end
    local line = SCORER_LINE[scorer] or SCORER_LINE.none
    if offSpec then
        return row("score", line.label, DASH, "muted", L["Score"], trow(L["Off-spec"], L["judged on item level alone"]))
    end
    local sd = type(eval) == "table" and num(eval.scoreDelta) or nil
    if sd then
        return row("score", line.label, ("%+.1f"):format(sd), sd >= 0 and "good" or "bad", L["Score"],
            trow(L["Scorer"], line.label), trow(L["Change"], ("%+.1f"):format(sd), sd >= 0 and "good" or "bad"))
    end
    local r = row("score", line.label, DASH, "muted", L["Score"], trow(L["Score"], line.none[1]))
    r.tip[3] = line.none[2] and hint(line.none[2]) or nil
    return r
end

-- The looter's spec and the read's age. A looter who left the group (`left`) keeps the read the
-- drop was judged with, and the row says they are gone; with no read it says so in place of
-- `spec unknown`, since no inspect can reach them now (feedback-21 H2).
local function specRow(drop, inspect, specName, now, left)
    local who = looterName(drop)
    local spec = specName or (left and L["not in your group"]) or L["spec unknown"]
    local gone = left and trow(L["Looter"], L["not in your group"]) or nil
    local at = type(inspect) == "table" and num(inspect.at) or nil
    if not (at and num(now)) then
        return row("spec", L["Spec"], spec, "muted", L["Spec"], trow(L["Inspected"], L["not yet"]), gone)
    end
    local age = WC.Duration(now - at)
    return row("spec", L["Spec"], L["%s · inspected %s ago"]:format(spec, age), "plain", L["Spec"],
        trow(L["%s's spec"]:format(who), spec), trow(L["Inspected"], L["%s ago"]:format(age)), gone)
end

local function verdictChip(cell)
    -- The arrow first (feedback-4 spec §0), as a texture: the chip's face has no glyph (DW-F5).
    local mark = cell.glyph and TM.Mark(cell.verdict, cell.offSpec and cell.tone) or ""
    if mark ~= "" then mark = mark .. " " end
    local words = cell.offSpec and OFF_SPEC_CHIP or VERDICT_CHIP
    return { text = mark .. (words[cell.verdict] or VERDICT_CHIP.unknown), tone = cell.tone, tip = cell.tip }
end
DC.VerdictChip = verdictChip   -- the History card's verdicts too (modules/HistoryCard.lua)

local function sideRows(eval, f, tone, whose, mine)
    local ilvl = num(f.ilvl)
    return { replacesRow(eval, whose, mine), ilvlRow(eval, ilvl, tone), trackRow(eval, f.track), statsRow(eval, f.stats) }
end

--- The For you column (board 02, callouts 2 and 3).
--- @param drop table
--- @param scorer string|boolean the scorer in use, "pawn" | "weights" | "none" (true reads "pawn")
--- @param classFile string|nil your class (the gear snapshot's): the verdict tooltip's grid names you in it
--- @return table side
function DC.ForYou(drop, scorer, classFile)
    local cell = WC.Me(drop, classFile)
    local off = NS.OffSpec.Of(drop.me)
    local rows = sideRows(off or drop.me, facts(drop), cell.tone, L["you"], true)
    if off then table.insert(rows, 1, NS.OffSpecCells.SpecRow(off)) end
    rows[#rows + 1] = scoreRow(drop.me, scorer, off ~= nil)
    return { title = L["FOR YOU"], verdict = verdictChip(cell), rows = rows }
end

-- The box's rows under Them: one per member it upgrades, the last saying how many more when they
-- do not all fit (the box has OWN_MEMBER_ROWS under Them).
local OWN_MEMBER_ROWS = 4

-- One member it upgrades: their name in their class color as the label, the worn item it would
-- replace as the icon, and `300 → 311 · +11` in green (the For you box's Item level, for them).
local function memberRow(e, ilvl)
    local base, gain = e.baseline, num(e.gain)
    local from = base and num(base.ilvl)
    local text = (from and ilvl) and ("%d %s %d · %s"):format(round(from), TM.Arrow(), ilvl, WC.Signed(gain or ilvl - from))
        or L["Empty slot"]
    local worn = from and trow(L["Replaces"], ("%s · %d"):format(WC.ItemName(base.link) or "?", round(from)))
        or trow(L["Slot"], L["empty (anything is an upgrade)"])
    local r = row("member", e.short or "?", text, "good", e.short or "?", worn,
        gain and trow(L["Upgrade"], WC.Signed(gain), "good") or nil)
    r.labelClassFile, r.link = e.classFile, base and base.link
    return r
end

-- Your own drop's side (feedback-5 spec §2): the Them row reads `Upgrade for N` with every member
-- it upgrades in its tooltip (MineCells.Details), as the row's Them cell does, then a row per
-- member it upgrades, best first (MineCells.Upgrades, feedback-20). No Looter row: the group is
-- everyone but you, and the card's line 2 already reads `Name [YOU]`.
local function ownSide(drop, revealed)
    local m = MC.Details(drop, revealed, L["Them"])
    local tip = m.tip
    local rows = { { key = "them", label = L["Them"], text = m.text, tone = m.tone, tip = tip } }
    local ups, ilvl = MC.Upgrades(drop, revealed), num(facts(drop).ilvl)
    local shown = #ups > OWN_MEMBER_ROWS and OWN_MEMBER_ROWS - 1 or #ups
    for i = 1, shown do rows[#rows + 1] = memberRow(ups[i], ilvl) end
    if shown < #ups then
        rows[#rows + 1] = row("more", "", L["and %d more: Offer shows all"]:format(#ups - shown), "muted",
            L["Them"], trow(L["Not shown"], L["%d more"]:format(#ups - shown)), hint(L["Offer lists every member it upgrades."]))
    end
    return { title = L["FOR THE GROUP"], verdict = { text = m.text, tone = m.tone, tip = tip }, rows = rows }
end

--- The For the looter column (board 02, callout 4): the same comparison against their inspected
--- gear, and their spec with the read's age. On your own drop: the Them row's `Upgrade for N`.
--- @param drop table
--- @param inspect table|nil the looter's inspect entry (NS.Inspect.Get)
--- @param specName string|nil the looter's spec, in words
--- @param now number|nil GetTime()
--- @param revealed boolean|nil your own drop's Offer panel was opened this session (WindowOwn)
--- @param left boolean|nil the looter is no longer in your group (`inspect` is then the drop's own copy)
--- @return table side
function DC.ForLooter(drop, inspect, specName, now, revealed, left)
    if drop.isMine then return ownSide(drop, revealed) end
    local who = looterName(drop)
    local title = L["FOR %s (LOOTER)"]:format(who:upper())
    local cell = WC.Them(drop, now)
    local off = NS.OffSpec.Of(drop.them)
    local rows = sideRows(off or drop.them, facts(drop), cell.tone, who)
    if off then table.insert(rows, 1, NS.OffSpecCells.SpecRow(off, "them")) end
    rows[#rows + 1] = specRow(drop, inspect, specName, now, left)
    return { title = title, verdict = verdictChip(cell), rows = rows }
end

-- ── the trade box ───────────────────────────────────────────────────────────────────────────

local function metaLine(t, situationLabel)
    local parts = {}
    local rule = RULE_WORD[t.rule]
    if rule then
        parts[#parts + 1] = situationLabel and L["Rule: %s, %s"]:format(rule, situationLabel) or L["Rule: %s"]:format(rule)
    end
    local basis = BASIS_WORD[t.basis]
    if basis then
        local age = num(t.age)
        parts[#parts + 1] = age and L["Basis: %s %s ago"]:format(basis, WC.Duration(age)) or L["Basis: %s"]:format(basis)
    end
    if #parts == 0 then return L["Not estimated yet."] end
    return table.concat(parts, " · ")
end

--- The trade estimate box (board 02, callout 5): the state, the reason in plain words, the rule in
--- force and how fresh the data is.
--- @param drop table
--- @param situationLabel string|nil the drop's situation, in words
--- @return table box
function DC.TradeBox(drop, situationLabel)
    local t = drop.trade
    local cell = WC.Trade(drop)
    if type(t) ~= "table" or not TRADE_CHIP[t.state] then
        return { chip = { text = TRADE_CHIP.unknown, tone = "muted" }, text = L["Not estimated yet."],
            meta = L["The estimate is made once the item's details load."], tip = cell.tip }
    end
    -- The Trade cell's tooltip (the reason as rows, the read's age, the basis), so the box and the
    -- row never disagree; your own drop's basis is your bag's timer.
    local tip = {}
    for i, l in ipairs(cell.tip) do tip[i] = l end
    if drop.isMine then tip[#tip + 1] = trow(L["Basis"], L["your bag's trade timer"]) end
    -- The cell's Can't use (a Yes or Likely none of your specs can use, feedback-21) is the chip's
    -- too, so the chip agrees with its tooltip and with the row; the reason stays the trade's.
    local face = { text = TRADE_CHIP[t.state], tone = TRADE_TONE[t.state] }
    if cell.tone == "redMuted" then face = { text = L["CAN'T USE"], tone = "redMuted" } end
    return { chip = face, text = WC.TradeReason(t, looterName(drop)), meta = metaLine(t, situationLabel), tip = tip }
end

-- ── the actions ─────────────────────────────────────────────────────────────────────────────

local function act(key, text, icon, enabled, title, ...)
    return { key = key, text = text, icon = icon, enabled = enabled and true or false, tip = { title, ... } }
end

-- Your own drop's Offer in the Ask's place (feedback-5 spec §2): it opens the Offer panel. Its mark
-- is its state's (feedback-7 spec §1: `external-link` while it reads Offer, feedback-10 spec §1), as
-- on the row; Trade keeps `transfer`, so the two never share a mark.
local function offerAction(o)
    local a = act("ask", o.text, o.icon or "external-link", o.offered, unpack(o.tip))
    a.state, a.offer, a.kind = o.state, true, o.kind
    return a
end

-- The Ask, its mark its state's (feedback-7 spec §1: `chat`, `clock`, `confirm`, `reset`), as on the row.
local function askAction(drop, ask)
    local who = looterName(drop)
    if not ask.offered then   -- No action, gray, its reason (feedback-11 spec §1)
        local a = act("ask", ask.text, ask.icon, false, unpack(ask.tip))
        a.state = ask.state
        return a
    end
    local text = ask.state == "ready" and L["Ask %s"]:format(who) or ask.text
    local a = act("ask", text, ask.icon or "chat", ask.enabled, unpack(ask.tip))
    a.state = ask.state
    return a
end

local EDITABLE = { ready = true, failed = true }

local function editAction(ask)
    local title = L["Edit message"]
    if not ask.offered then return act("edit", title, "edit", false, title, unpack(ask.tip, 2)) end
    if not EDITABLE[ask.state] then
        return act("edit", title, "edit", false, title, trow(L["Ask"], L["already %s"]:format(ask.text:lower())))
    end
    return act("edit", title, "edit", true, title, trow(L["Opens"], L["the ask, filled in, in a box you can change"]),
        trow(L["When"], L["before it is sent"]))
end

local function linkAction(drop)
    local title = L["Link in chat"]
    if type(drop.link) ~= "string" then return act("link", title, "link-intact", false, title, trow(L["Link"], L["not known"])) end
    return act("link", title, "link-intact", true, title, trow(L["Puts"], L["the item's link in the chat box"]))
end

local RETRY_BUSY = { pending = true, combatParked = true }
local RETRY_GOOD = { fresh = true, cached = true }

-- The age of a read the broker still counts good (it would not inspect again), or nil.
local function goodReadAge(inspect, now)
    if type(inspect) ~= "table" or not RETRY_GOOD[inspect.status] or inspect.stale then return nil end
    local at = num(inspect.at)
    return at and num(now) and now - at or nil
end

-- Why a retry would do nothing (its tooltip rows), or nil when it would queue the looter.
local function noRetryReason(drop, inspect, now)
    if drop.isMine then return { trow(L["Why"], L["your own drop"]), trow(L["Your gear"], L["always read"]) } end
    local guid = type(drop.looter) == "table" and drop.looter.guid or nil
    if not guid then return { trow(L["Why"], L["the looter is not known well enough to inspect"]) } end
    if type(inspect) == "table" and RETRY_BUSY[inspect.status] then return { trow(L["Inspect"], L["already queued"]) } end
    local age = goodReadAge(inspect, now)
    if age then
        return { trow(L["Inspected"], L["%s ago"]:format(WC.Duration(age))), trow(L["Read again"], L["when it changes or grows old"]) }
    end
    return nil
end

local function retryAction(drop, inspect, now)
    local title = L["Retry inspect"]
    local why = noRetryReason(drop, inspect, now)
    if why then return act("retry", title, "reset", false, title, unpack(why)) end
    return act("retry", title, "reset", true, title, trow(L["Inspects"], looterName(drop)),
        trow(L["When"], L["now, ahead of the warm-up queue"]))
end

-- The disabled Trade button's short reason (board 02: `Trade · out of range`).
local TRADE_SHORT = {
    combat = L["in combat"], range = L["out of range"], offline = L["offline"], noTarget = L["not in group"],
    self = L["your own"], stoodDown = L["disabled"], noApi = L["unavailable"],
}

local function tradeAction(drop, trade)
    local title = L["Trade"]
    if drop.isMine then
        return act("trade", title, "transfer", false, title, trow(L["Why"], L["your own drop"]),
            hint(L["Offer shows who it would help, with an Offer for each."]))
    end
    if type(drop.trade) == "table" and drop.trade.state == "no" then
        return act("trade", L["Trade · can't"], "transfer", false, title, trow(L["Why"], L["its looter can't trade it"]))
    end
    trade = type(trade) == "table" and trade or {}
    if not trade.ok then
        local text = TRADE_SHORT[trade.reason] and L["Trade · %s"]:format(TRADE_SHORT[trade.reason]) or title
        return act("trade", text, "transfer", false, title, trow(L["Why"], TRADE_SHORT[trade.reason] or trade.text or L["a trade can't be opened now"]))
    end
    return act("trade", title, "transfer", true, title, trow(L["Opens"], L["a trade with %s"]:format(looterName(drop))),
        trow(L["Then"], L["they put the item in"]))
end

--- The card's actions (board 02, callout 6), left to right: Ask (Offer on your own drop, with
--- `offer` set: feedback-5 spec §2), Edit message, Link in chat, Retry inspect and Trade. A
--- disabled one says why in its tooltip. Nothing hides a drop (feedback-4 spec §2).
--- @param drop table
--- @param ctx table { askState, askReason, inspect (the looter's entry), now, trade = { ok, reason, text },
--- transmogAsk (the `messages.transmogAsk` setting), offerTone (your own drop's: WindowOwn.ToneStates) }
--- @return table list of actions
function DC.Actions(drop, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local ask = WC.Ask(drop, ctx.askState, ctx.askReason, ctx.transmogAsk)
    local first = drop.isMine and offerAction(MC.OwnOffer(drop, ctx.offerTone)) or askAction(drop, ask)
    return {
        first, editAction(ask), linkAction(drop),
        retryAction(drop, ctx.inspect, ctx.now), tradeAction(drop, ctx.trade),
    }
end
