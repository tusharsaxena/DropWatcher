local _, NS = ...
-- modules/WindowCells.lua — what each cell of a drop table says (design spec §11.2, boards 01 and
-- 03): the text, the verdict glyph, the tone and the reason tooltip of every column, for every
-- state a drop can be in. Nothing is ever blank: an unknown value says `?` or `–` and its tooltip
-- says why.
--
-- PURE. Every composer takes the drop record (modules/LootFeed.lua's shape) and plain inputs (an
-- inspect entry's gear, an ask's state, the clock) and answers a plain table; nothing here reads a
-- module's state, the client or a saved variable (only NS.TipMarks, at call time: a verdict
-- tooltip's gear grid takes the class and quality colors), so test_window_group drives each state
-- case by case.
-- The frame edge that paints them is modules/WindowGroup.lua; the detail card (DW-32) and the
-- compact cards take the same composers. The Me and Them cells merge two of them each (the worn gear,
-- then the verdict): modules/SideCells.lua.
--
-- THE ENTRIES (Entries, DW-B0: peeled out of modules/WindowGroup.lua) are the drop tables' rows in
-- order, under their group headers; the Drops table and its compact cards both take them.
--
--   cell = { text, glyph = "▲" | "≈" | "▼" | nil, tone = key of C.TONE, tip = { title, lines... } }
--
-- THE GEAR GRID (feedback-7 spec §3). A verdict tooltip shows the comparison as a grid row
-- (NS.TipMarks.Grid), `[who] [worn ilvl] [worn item] [▲diff]`, where it said `Item level 295 against
-- 289 (Speakeasy Shroud): +6.`; the gear halves (MyEq, TheirEq) list no items in their tooltips and
-- answer `items` and `empty` instead, which NS.SideCells lays out as the merged cell's grid.
--
-- THE TONES (C.TONE; feedback-4 spec §0). One tone per verdict, in the Me and the Them column
-- alike: an upgrade `good` (green), a sidegrade `yellow`, a downgrade `red`; an item that cannot be
-- used or is not wanted `bad` (gray) and an unknown one `muted`. Trade's No is `red` too.

NS.WindowCells = NS.WindowCells or {}
local WC = NS.WindowCells
local C  = NS.Constants
local L  = NS.L

local floor = math.floor

local DASH = "–"

-- The verdict glyphs (design spec §11.2), drawn in the monospace face: the client's default face
-- has none of them.
WC.GLYPH = { upgrade = "▲", sidegrade = "≈", downgrade = "▼" }

local VERDICT_WORD = {
    upgrade = L["Upgrade"], sidegrade = L["Sidegrade"], downgrade = L["Downgrade"],
    cantUse = L["Can't use"], doesntWant = L["Doesn't want"], unknown = L["Unknown"],
}
-- What a glyph-less verdict shows in its cell.
local VERDICT_SHORT = { cantUse = L["Can't use"], doesntWant = L["Not wanted"], unknown = "?" }
-- Board 03's explanation of each verdict, the line under every verdict tooltip's title.
local VERDICT_EXPLAIN = {
    upgrade    = L["A higher item level, and a higher score when scoring is on."],
    sidegrade  = L["Within the sidegrade band, or item level and score disagree."],
    downgrade  = L["A lower item level and no score gain."],
    cantUse    = L["The wrong armor type, weapon type or primary stat for the spec."],
    doesntWant = L["Usable, but excluded by your own preferences."],
    unknown    = L["No inspect yet, no spec, or a protected value."],
}
local VERDICT_TONE = {
    upgrade = "good", sidegrade = "yellow", downgrade = "red", cantUse = "bad", doesntWant = "bad", unknown = "muted",
}
-- NS.Evaluate's reason keys, in words.
local EVAL_REASON = {
    armorType = L["The wrong armor type for the class."],
    weaponType = L["A weapon type the class cannot use."],
    shield = L["The spec cannot use a shield."],
    offhand = L["The spec cannot use a held off hand."],
    dualWield = L["The spec cannot dual wield."],
    primaryStat = L["Its primary stat does not suit the spec."],
    classRestricted = L["The item is for other classes."],
    specList = L["The item is not for this spec."],
    tierToken = L["A tier token: the slot it makes is not read yet."],
    notGear = L["Not gear that is compared."],
    noBaseline = L["The item it would replace has not been read."],
    noIlvl = L["The item level has not been read."],
    emptySlot = L["The slot is empty, so anything is an upgrade."],
    uniqueEquipped = L["Unique-equipped: compared with the copy already worn."],
    vsTwoHand = L["Compared with the two-hander it would replace."],
    scorePending = L["The score is not ready yet; it is retried."],
    scoreDisagrees = L["Item level and score disagree, so it is a sidegrade."],
    heirloomProtected = L["The slot holds an heirloom you protect, so it is a sidegrade."],
    undesired = L["You marked this item type as not wanted for your spec."],
    badFacts = L["The item's details have not loaded."],
    badCandidate = L["No gear to compare with."],
    error = L["The comparison failed; /dw debug on logs why."],
}

local TRADE_LABEL = { yes = L["Yes"], likely = L["Likely"], unknown = L["Unknown"], no = L["No"] }
-- Trade's tones: Yes and Likely green, Unknown muted, No the palette's red (feedback-7 spec §2:
-- not the gray `bad` tone). The detail card's trade chip reads this table too.
local TRADE_TONE = { yes = "good", likely = "good", unknown = "muted", no = "red" }
WC.TRADE_TONE = TRADE_TONE

-- An inspect failure's reason, in words.
local FAILED_WORD = {
    identity = L["they could not be found"], timeout = L["no answer came"],
    empty = L["the read came back empty"], incomplete = L["some items did not load"],
}

local SLOT_LABEL = {
    INVTYPE_HEAD = L["Head"], INVTYPE_NECK = L["Neck"], INVTYPE_SHOULDER = L["Shoulder"],
    INVTYPE_CHEST = L["Chest"], INVTYPE_ROBE = L["Chest"], INVTYPE_WAIST = L["Waist"],
    INVTYPE_LEGS = L["Legs"], INVTYPE_FEET = L["Feet"], INVTYPE_WRIST = L["Wrist"],
    INVTYPE_HAND = L["Hands"], INVTYPE_CLOAK = L["Back"], INVTYPE_FINGER = L["Finger"],
    INVTYPE_TRINKET = L["Trinket"], INVTYPE_WEAPON = L["One-hand"], INVTYPE_WEAPONMAINHAND = L["Main hand"],
    INVTYPE_WEAPONOFFHAND = L["Off hand"], INVTYPE_SHIELD = L["Shield"], INVTYPE_HOLDABLE = L["Held in off hand"],
    INVTYPE_2HWEAPON = L["Two-hand"], INVTYPE_RANGED = L["Ranged"], INVTYPE_RANGEDRIGHT = L["Ranged"],
}

-- ── small helpers ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- A number that is not NaN, else nil (NS.SideCells shares it).
--- @param v any
--- @return number|nil
function WC.Num(v) return num(v) end

local function round(n) return floor(n + 0.5) end

--- A signed whole number: `+19`, `-13`, `+0`.
--- @param n number
--- @return string
function WC.Signed(n)
    local r = round(n)
    if r >= 0 then return "+" .. r end
    return tostring(r)
end

--- A short duration: `40s`, `6m`, `1h 59m`.
--- @param seconds number|nil
--- @return string
function WC.Duration(seconds)
    local s = math.max(0, floor(num(seconds) or 0))
    if s < 60 then return ("%ds"):format(s) end
    if s < 3600 then return ("%dm"):format(floor(s / 60)) end
    local m = floor((s % 3600) / 60)
    if m == 0 then return ("%dh"):format(floor(s / 3600)) end
    return ("%dh %dm"):format(floor(s / 3600), m)
end

--- A player's name without its realm, or `?`.
--- @param name string|nil
--- @return string
function WC.ShortName(name)
    if type(name) ~= "string" or name == "" then return "?" end
    return name:match("^([^%-]+)") or name
end

--- An item link's name, or nil.
--- @param link string|nil
--- @return string|nil
function WC.ItemName(link)
    if type(link) ~= "string" then return nil end
    return link:match("|h%[(.-)%]|h")
end

--- An equip location's display name, or nil.
--- @param equipLoc string|nil
--- @return string|nil
function WC.SlotLabel(equipLoc) return SLOT_LABEL[equipLoc] end

local function looterName(drop)
    local who = type(drop) == "table" and drop.looter
    return WC.ShortName(type(who) == "table" and who.name or nil)
end

local function facts(drop) return type(drop.facts) == "table" and drop.facts or {} end

local function cell(text, tone, title, ...)
    return { text = text, tone = tone, tip = { title, ... } }
end

-- ── the verdicts: Me and Them ───────────────────────────────────────────────────────────────

local function hasReasons(eval) return type(eval.reasons) == "table" end

local function trackLine(td)
    if type(td) ~= "table" then return nil end
    if td.sign > 0 then return L["Upgrade track: a higher track or rank."] end
    if td.sign < 0 then return L["Upgrade track: a lower track or rank."] end
    return L["Upgrade track: the same track and rank."]
end

-- The comparison as one grid row (feedback-7 spec §3): `[who] [worn ilvl] [worn item] [▲diff]`.
local function compareLines(eval, ilvl, lines, who)
    local base = type(eval.baseline) == "table" and eval.baseline or nil
    local d = num(eval.ilvlDelta)
    if d and ilvl then
        local TM = NS.TipMarks
        local worn = { link = base and base.link, name = base and base.name, quality = base and base.quality, ilvl = ilvl - d }
        lines[#lines + 1] = TM.Grid(TM.GearRows(who or "?", { worn }, 0, TM.ArrowCell(eval.verdict, d), worn))
    end
    lines[#lines + 1] = trackLine(eval.trackDelta)
    local sd = num(eval.scoreDelta)
    if sd then lines[#lines + 1] = L["Score: %+.1f."]:format(sd) end
end

-- The tooltip of one verdict: its title, board 03's explanation, then the comparison (a grid row)
-- and the kernel's reasons.
local function verdictTip(title, eval, ilvl, who)
    local v = eval.verdict
    local lines = { title, VERDICT_EXPLAIN[v] or VERDICT_EXPLAIN.unknown }
    compareLines(eval, ilvl, lines, who)
    if hasReasons(eval) then
        for _, r in ipairs(eval.reasons) do lines[#lines + 1] = EVAL_REASON[r.key] or tostring(r.key) end
    end
    return lines
end

-- The cell's text and glyph: the signed item-level change beside ▲ ≈ ▼, or a word.
local function verdictText(eval)
    local v = eval.verdict
    local glyph = WC.GLYPH[v]
    if not glyph then return VERDICT_SHORT[v] or "?", nil end
    local d = num(eval.ilvlDelta)
    if d then return WC.Signed(d), glyph end
    return L["empty"], glyph
end

--- One verdict cell (the Me or the Them column; both take the same tones). Its tooltip's comparison
--- is a grid row naming `who`; the cell keeps `who`, `delta` and `base` (the worn item it was judged
--- against) for NS.SideCells, which lays the worn gear out in that grid.
--- @param eval table|nil NS.Evaluate's answer
--- @param _side string `me` or `them`
--- @param title string the tooltip's subject (`For you`, `For Seta`)
--- @param ilvl number|nil the drop's item level
--- @param who string|nil the grid's name cell, colored (NS.TipMarks.ClassName)
--- @return table cell
function WC.Verdict(eval, _side, title, ilvl, who)
    if type(eval) ~= "table" or type(eval.verdict) ~= "string" then
        eval = { verdict = "unknown", reasons = {} }
    end
    local text, glyph = verdictText(eval)
    local v = eval.verdict
    local tip = verdictTip(("%s: %s"):format(title, VERDICT_WORD[v] or v), eval, ilvl, who)
    return { text = text, glyph = glyph, tone = VERDICT_TONE[v] or "muted", tip = tip, verdict = v,
        who = who, delta = num(eval.ilvlDelta), base = type(eval.baseline) == "table" and eval.baseline or nil }
end

--- The Me verdict: the drop judged for you (NS.SideCells puts it after your worn gear). The grid
--- names you `You`, in your class color: `classFile`, else the looter's on your own drop.
--- @param drop table
--- @param classFile string|nil your class (the gear snapshot's)
--- @return table cell
function WC.Me(drop, classFile)
    local mine = drop.isMine and type(drop.looter) == "table" and drop.looter.classFile or nil
    local who = NS.TipMarks.ClassName(L["You"], classFile or mine)
    return WC.Verdict(drop.me, "me", L["For you"], num(facts(drop).ilvl), who)
end

-- Why the looter's verdict is not known, from the drop's inspect state.
local function inspectWhy(insp, who, now)
    local status = type(insp) == "table" and insp.status or "pending"
    if status == "pending" then return L["Waiting to inspect %s: one inspect at a time."]:format(who) end
    if status == "combatParked" then return L["The inspect of %s waits for combat to end."]:format(who) end
    if status == "outOfRange" then return L["Couldn't inspect %s (out of range). It is retried when in range."]:format(who) end
    if status == "unavailable" then return L["%s is not in your group, so their gear can't be read."]:format(who) end
    if status == "failed" then
        return L["Couldn't inspect %s: %s. Retry from the detail card."]:format(who, FAILED_WORD[insp.reason] or tostring(insp.reason))
    end
    local at = num(insp.at)
    if at and num(now) then return L["Inspected %s ago, but the item it would replace was not read."]:format(WC.Duration(now - at)) end
    return L["The item it would replace was not read."]
end

--- The Them verdict: the drop judged for its looter (the Me verdict's tones), `–` on your own drop
--- (the Drops table shows MineCells.Details's `Upgrade for N` there instead: feedback-5 spec §2), `?`
--- while their gear is not read. NS.SideCells puts it after the looter's worn gear.
--- @param drop table
--- @param now number|nil GetTime()
--- @return table cell
function WC.Them(drop, now)
    local who = looterName(drop)
    if drop.isMine then
        return cell(DASH, "muted", L["Them"], L["Your own drop: Offer shows who it would help."])
    end
    local named = NS.TipMarks.ClassName(who, type(drop.looter) == "table" and drop.looter.classFile or nil)
    if type(drop.them) ~= "table" then
        local c = cell("?", "muted", L["For %s: Unknown"]:format(who), inspectWhy(drop.inspect, who, now))
        c.verdict, c.who = "unknown", named   -- the tooltip grid's name while their gear is read but not judged
        return c
    end
    return WC.Verdict(drop.them, "them", L["For %s"]:format(who), num(facts(drop).ilvl), named)
end

-- ── the Trade column ────────────────────────────────────────────────────────────────────────

local NO_INSPECT_WORD = {
    pending = L["waiting for the inspect"], combatParked = L["waiting for combat to end"],
    outOfRange = L["out of range"], failed = L["the inspect failed"], unavailable = L["not in your group"],
    notInGroup = L["not in your group"], noBaseline = L["the item they wear there was not read"],
}

local TRADE_REASON = {
    boe = function() return L["Bind on equip: anyone can trade this."] end,
    warbound = function() return L["Warbound: it can't be traded."] end,
    bonusRoll = function() return L["Bonus roll loot can't be traded."] end,
    legacy = function() return L["Loot from this content can't be traded."] end,
    groupLoot = function() return L["Group loot: its winner may trade it for four hours."] end,
    badFacts = function() return L["The item's details have not loaded yet."] end,
    expired = function(a) return L["The trade window (%s) has passed."]:format(WC.Duration(a[2])) end,
    timer = function(a) return L["Your own item: %s left to trade it."]:format(WC.Duration(a[1])) end,
    error = function(a) return L["The estimate failed: %s"]:format(tostring(a[1])) end,
}

function TRADE_REASON.notUpgrade(a, who)
    local ilvl, theirs = num(a[1]), num(a[2])
    if ilvl and theirs then
        return L["Personal loot: %d is not an upgrade over the %d %s wears, so they may trade it."]:format(ilvl, round(theirs), who)
    end
    return L["Personal loot: it is not an upgrade for %s, so they may trade it."]:format(who)
end

function TRADE_REASON.upgradeForLooter(a, who)
    local ilvl, theirs = num(a[1]), num(a[2])
    if ilvl and theirs then
        return L["%d is an upgrade over the %d %s wears, so the game won't let them trade it."]:format(ilvl, round(theirs), who)
    end
    return L["It fills an empty slot for %s, so the game won't let them trade it."]:format(who)
end

function TRADE_REASON.noInspect(a, who)
    local why = NO_INSPECT_WORD[a[1]] or tostring(a[1] or "?")
    return L["The game's rule needs %s's gear, which is not read yet (%s)."]:format(who, why)
end

--- The trade estimate's reason, in words.
--- @param trade table NS.TradeRules' answer
--- @param who string the looter's short name
--- @return string
function WC.TradeReason(trade, who)
    local fn = TRADE_REASON[trade.reasonKey]
    if not fn then return tostring(trade.reasonKey or "?") end
    return fn(type(trade.args) == "table" and trade.args or {}, who)
end

--- The Trade column: Yes, Likely, Unknown or No, with the reason (board 03).
--- @param drop table
--- @return table cell
function WC.Trade(drop)
    local t = drop.trade
    if type(t) ~= "table" or not TRADE_LABEL[t.state] then
        return cell(TRADE_LABEL.unknown, "muted", L["Trade: Unknown"], L["Not estimated yet."])
    end
    local label = TRADE_LABEL[t.state]
    local c = cell(label, TRADE_TONE[t.state], L["Trade: %s"]:format(label), WC.TradeReason(t, looterName(drop)))
    if num(t.age) then c.tip[#c.tip + 1] = L["Inspected %s ago."]:format(WC.Duration(t.age)) end
    if not drop.isMine and t.basis ~= "bind" then
        c.tip[#c.tip + 1] = L["Another player's drop can only be estimated."]
    end
    c.state = t.state
    return c
end

-- ── the gear halves of the Me and Them cells ────────────────────────────────────────────────
-- Both show the worn item(s) for the drop's slot (two for rings, trinkets and one-hand weapons):
-- the icons are the edge's, the text is their item levels (`311`, `300/296`), and the cell answers
-- `items` and `empty` (slots worn empty), which NS.SideCells lays out as its tooltip's gear grid
-- (feedback-7 spec §3; the tooltip named each item on a line before). Their inspect age is in Them's tooltip (feedback spec §3, FB-7); a state with
-- no data keeps its reason word (`…`, `range`, `combat`, `!`, `–`). They were the My eq and Their
-- eq columns until feedback-6 spec §1 put each before its verdict (modules/SideCells.lua).

-- The worn slots a drop is compared with: both rings, both trinkets, both hands for a weapon.
local function eqSlots(equipLoc)
    local plan = C.SLOT_PLAN[equipLoc]
    if not plan then return nil end
    if plan.kind == "single" or plan.kind == "offhand" then return { plan.slots[1] } end
    return plan.slots
end

--- The inventory slots a drop's equip location is compared with, or nil for an item not worn.
--- @param equipLoc string|nil
--- @return table|nil
function WC.EqSlots(equipLoc) return eqSlots(equipLoc) end

-- What `gear` holds in `slots`: each read item as { link, ilvl, slot }; `empty` counts the slots
-- read as empty (false), `unread` the ones not read at all (absent).
local function slotItems(gear, slots)
    local items, empty, unread = {}, 0, 0
    gear = type(gear) == "table" and gear or {}
    for _, slot in ipairs(slots) do
        local g = gear[slot]
        if type(g) == "table" and type(g.link) == "string" then
            items[#items + 1] = { link = g.link, ilvl = g.ilvl, slot = slot }
        elseif g == false then
            empty = empty + 1
        else
            unread = unread + 1
        end
    end
    return items, empty, unread
end

--- What `gear` holds in `slots` (the Them cell's rule, shared with the Offer panel's Their eq):
--- the read items { link, ilvl, slot }, the slots read as empty (false) and the slots not read.
--- @param gear table|nil { [slot] = { link, ilvl } | false }
--- @param slots table
--- @return table items, number empty, number unread
function WC.SlotItems(gear, slots) return slotItems(gear, slots) end

local function levelOf(item)
    local n = num(item.ilvl)
    return n and tostring(round(n)) or "?"
end

--- The item levels of worn items, `311` or `300/296`.
--- @param items table { { ilvl }, ... }
--- @return string
function WC.Levels(items)
    local parts = {}
    for i, it in ipairs(items) do parts[i] = levelOf(it) end
    return table.concat(parts, "/")
end

local function eqCellOf(text, tone, title, items, empty)
    local c = cell(text, tone, title)
    c.items, c.empty = items, empty
    return c
end


--- What you wear in the drop's slot (the Me cell's gear half), from your gear snapshot (NS.Gear), so it is
--- always fresh; `empty slot` when you wear nothing there, `…` while your gear is still loading.
--- @param drop table
--- @param equipped table|nil the snapshot's `equipped` ({ [slot] = entry | false })
--- @return table cell, with `items` = { { link, ilvl, slot }, ... } and `empty` (slots worn empty)
function WC.MyEq(drop, equipped)
    local title = L["You wear"]
    local slots = eqSlots(facts(drop).equipLoc)
    if not slots then
        local c = eqCellOf(DASH, "muted", title, {}, 0)
        c.tip[2] = L["Not an item that is worn, or its details have not loaded."]
        return c
    end
    local items, empty, unread = slotItems(equipped, slots)
    local c
    if #items > 0 then
        c = eqCellOf(WC.Levels(items), "plain", title, items, empty)
    elseif unread > 0 then
        c = eqCellOf("…", "muted", title, items, empty)
    else
        c = eqCellOf(L["empty slot"], "muted", title, items, empty)
    end
    if unread > 0 then c.tip[#c.tip + 1] = L["Your gear is still loading."] end
    return c
end

-- The cell's short status when no item is shown (board 03's inspect freshness).
local STATUS_TEXT = { pending = "…", combatParked = L["combat"], outOfRange = L["range"], failed = "!" }

local function readOk(insp)
    return type(insp) == "table" and (insp.status == "fresh" or insp.status == "cached")
end

--- Whether an inspect read's gear may be shown: it is fresh, or the cache's.
--- @param insp table|nil the read (NS.Inspect.Get's)
--- @return boolean
function WC.ReadOk(insp) return readOk(insp) end

-- The tooltip's line on how old the read is: `Inspected 2m ago.`, or the cache's.
local function ageLine(insp, now)
    local at = num(insp.at)
    local age = at and num(now) and WC.Duration(now - at) or nil
    if insp.status == "cached" then
        if age then return L["From the inspect cache, read %s ago."]:format(age) end
        return L["From the inspect cache."]
    end
    if age then return L["Inspected %s ago."]:format(age) end
    return L["Inspected."]
end

-- The text and tone when no item is shown: `empty slot` once the read says so, else the state.
local function theirStatus(insp, empty, unread)
    if readOk(insp) then
        if empty > 0 and unread == 0 then return L["empty slot"], "muted" end
        return DASH, "muted"
    end
    return STATUS_TEXT[type(insp) == "table" and insp.status] or DASH, "muted"
end

--- What the looter wears (the Them cell's gear half): their worn item(s) for the drop's slot (two for rings, trinkets and
--- weapons) and their item levels; the inspect's age (or why there is no read) in the tooltip.
--- Another player's drop only: your own drop's Them cell is MineCells.Details's (SideCells.Them).
--- @param drop table
--- @param gear table|nil the looter's inspect entry's `gear` ({ [slot] = { link, ilvl } | false })
--- @param now number|nil GetTime()
--- @return table cell, with `items` = { { link, ilvl, slot }, ... } and `empty` (slots worn empty)
function WC.TheirEq(drop, gear, now)
    local who = looterName(drop)
    local title = L["%s wears"]:format(who)
    local slots = eqSlots(facts(drop).equipLoc) or {}
    local items, empty, unread = slotItems(gear, slots)
    local c
    if #items > 0 then
        c = eqCellOf(WC.Levels(items), "plain", title, items, empty)
    else
        local text, tone = theirStatus(drop.inspect, empty, unread)
        c = eqCellOf(text, tone, title, items, empty)
    end
    if #items == 0 and empty == 0 then c.tip[#c.tip + 1] = L["Nothing read for this slot yet."] end
    c.tip[#c.tip + 1] = WC.InspectLine(drop.inspect, who, now)
    return c
end

--- How fresh the looter's inspect is, in words (the Them gear half's last tooltip line, and compact mode's
--- freshness tooltip, modules/CompactCards.lua): how old a good read is, else why there is none.
--- @param insp table|nil the drop's inspect state { status, at, reason }
--- @param who string the looter's short name
--- @param now number|nil GetTime()
--- @return string
function WC.InspectLine(insp, who, now)
    if readOk(insp) then return ageLine(insp, now) end
    return inspectWhy(insp, who, now)
end

-- ── Item, Ilvl, Slot, Looter ────────────────────────────────────────────────────────────────

--- The Item column's name (the item button is the edge's): the link's name, or `?`.
--- @param drop table
--- @return table cell, with `link`
function WC.Item(drop)
    local name = WC.ItemName(drop.link) or "?"
    local c = cell(name, "plain", name, L["Shift-click the icon to link it in chat; ctrl-click to try it on."])
    c.link = drop.link
    return c
end

--- The Ilvl column: the drop's item level and its upgrade track.
--- @param drop table
--- @return table cell
function WC.Ilvl(drop)
    local f = facts(drop)
    local ilvl = num(f.ilvl)
    if not ilvl then return cell("?", "muted", L["Item level"], L["The item's details have not loaded yet."]) end
    local tr = type(f.track) == "table" and f.track or nil
    local line = L["No upgrade track."]
    if tr and tr.name then line = L["Upgrade track: %s %s/%s."]:format(tr.name, tostring(tr.rank or "?"), tostring(tr.max or "?")) end
    return cell(tostring(ilvl), "plain", L["Item level %d"]:format(ilvl), line)
end

--- The Slot column.
--- @param drop table
--- @return table cell
function WC.Slot(drop)
    local loc = facts(drop).equipLoc
    local label = SLOT_LABEL[loc]
    if not label then return cell(DASH, "muted", L["Slot"], L["Not an item that is worn, or its details have not loaded."]) end
    local plan = C.SLOT_PLAN[loc]
    local line = L["Compared with what is worn there."]
    if plan and plan.kind ~= "single" then line = L["Compared with the lower of the two items that could be replaced."] end
    return cell(label, "plain", label, line)
end

-- ── the Type column (feedback-4 spec §3) ────────────────────────────────────────────────────
-- What kind of item it is, from its equip location first and then its armor subclass (stable ids,
-- never a localized type name): the four armor types, Jewelry, Trinkets, Cloak or Weapons.

local ARMOR_WORD = {
    [C.ARMOR_SUBCLASS.CLOTH] = L["Cloth"], [C.ARMOR_SUBCLASS.LEATHER] = L["Leather"],
    [C.ARMOR_SUBCLASS.MAIL] = L["Mail"], [C.ARMOR_SUBCLASS.PLATE] = L["Plate"],
}
-- Equip locations whose type is the location's, whatever the subclass: { word, tooltip line }.
local LOC_TYPE = {
    INVTYPE_NECK    = { L["Jewelry"], L["A neck: jewelry any class can wear."] },
    INVTYPE_FINGER  = { L["Jewelry"], L["A ring: jewelry any class can wear."] },
    INVTYPE_TRINKET = { L["Trinkets"], L["A trinket any class can wear."] },
    -- Every class wears a cloak, so the cloth the game files it under would mislead.
    INVTYPE_CLOAK   = { L["Cloak"], L["A cloak: every class wears one."] },
}
local WEAPON_LOC = {
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
}

local function typeTitle(word) return L["Type: %s"]:format(word) end

--- The Type column (feedback-4 spec §3): `Cloth`, `Leather`, `Mail` or `Plate` for an armor piece,
--- `Jewelry` for a neck or ring, `Trinkets`, `Cloak`, `Weapons` for anything held in a hand (a
--- shield and an off hand too), else `–` with why. The detail card's chip and the compact cards
--- read the same answer.
--- @param drop table
--- @return table cell, with `known` (false for the dash)
function WC.ArmorType(drop)
    local f = facts(drop)
    local loc = f.equipLoc
    local fixed = LOC_TYPE[loc]
    if fixed then
        local c = cell(fixed[1], "plain", typeTitle(fixed[1]), fixed[2]); c.known = true; return c
    end
    if WEAPON_LOC[loc] then
        local w = L["Weapons"]
        local c = cell(w, "plain", typeTitle(w), L["Held in a hand: a weapon, a shield or an off hand."]); c.known = true
        return c
    end
    if C.ARMOR_TYPED_EQUIPLOC[loc] then
        local word = f.classID == C.ITEM_CLASS.ARMOR and ARMOR_WORD[f.subClassID] or nil
        if word then
            local c = cell(word, "plain", typeTitle(word), L["Only classes that wear %s are judged able to use it."]:format(word))
            c.known = true
            return c
        end
        local c = cell(DASH, "muted", L["Type"], L["An armor piece with no armor type, or its details have not loaded."])
        c.known = false
        return c
    end
    local c = cell(DASH, "muted", L["Type"], L["Not an item that is worn (a token, say), or its details have not loaded."])
    c.known = false
    return c
end

local SOURCE_WORD = { chat = L["chat"], encounter = L["the encounter"], history = L["the loot history"], manual = L["/dw add"] }

--- The Looter column: the short name (the edge colors it by class) and, on your own drop, `you`:
--- the ` [YOU]` mark the edge draws after the name in gold, never cut (feedback-7 spec §2).
--- @param drop table
--- @return table cell, with `classFile` and `you` (nil on another player's drop)
function WC.Looter(drop)
    local who = type(drop.looter) == "table" and drop.looter or {}
    local name = WC.ShortName(who.name)
    local from = {}
    for src in pairs(type(drop.sources) == "table" and drop.sources or {}) do from[#from + 1] = SOURCE_WORD[src] or src end
    table.sort(from)
    local line = drop.isMine and L["You looted it."] or L["Looted by %s."]:format(tostring(who.name or "?"))
    local c = cell(name, "plain", name, line)
    if #from > 0 then c.tip[#c.tip + 1] = L["Reported by %s."]:format(table.concat(from, ", ")) end
    c.classFile = who.classFile
    if drop.isMine then c.you = L["[YOU]"] end
    return c
end

-- ── the Ask button ──────────────────────────────────────────────────────────────────────────

-- Why no ask is offered for `drop`, or nil when one is; the template it fills when one is
-- (NS.Messaging.AskTemplate: `ask`, or `transmog` for a look you lack with `transmogAsk` on).
local function noAskReason(drop, transmogAsk)
    if drop.isMine then return L["Your own drop: Offer shows who it would help."] end
    if type(drop.trade) == "table" and drop.trade.state == "no" then
        return L["Its looter can't trade it: %s"]:format(WC.TradeReason(drop.trade, looterName(drop)))
    end
    local template = NS.Messaging.AskTemplate(drop, transmogAsk)
    if not template then return L["It is not an upgrade for you."] end
    if looterName(drop) == "?" then return L["The looter is not known."] end
    return nil, template
end

-- Every state carries an icon (feedback-7 spec §1): `chat` for Ask, a whisper to the looter.
local ASK_LOOK = {
    ready  = { text = L["Ask"], icon = "chat", enabled = true },
    traded = { text = L["Traded"], icon = "confirm", enabled = false },
    queued = { text = L["Queued"], icon = "clock", enabled = true },
    sent   = { text = L["Asked"], icon = "confirm", enabled = false },
    failed = { text = L["Retry"], icon = "reset", enabled = true },
}
WC.ASK_LOOK = ASK_LOOK   -- read by the suites: every state has an icon

-- NO ACTION (feedback-11 spec §1): where a drop has no action, every view's action slot shows this
-- placeholder button, gray, dimmed and not clickable, never a dash or an empty slot; its tooltip
-- is titled `No action` and gives the reason.
WC.NO_ACTION = { text = L["No action"], icon = "ban" }

--- The placeholder action (feedback-11 spec §1) in WindowCells.Ask's shape: `offered` false, the
--- `No action` label and `ban` mark, state `none` (gray, WC.ActionTone), the reason in its tooltip.
--- @param reason string why the drop has no action
--- @return table { offered = false, text, icon, enabled = false, tip, state = "none" }
function WC.NoAction(reason)
    return { offered = false, text = WC.NO_ACTION.text, icon = WC.NO_ACTION.icon, enabled = false,
        tip = { L["No action"], reason }, state = "none" }
end

-- WHOSE MOVE IT IS (feedback-4 spec §1): an action button's tone by its state. Your move is red
-- (Ask, Retry, an Announce not yet sent), waiting on someone else yellow (Asked, Queued, Offered,
-- Announced), done green (Traded, traded away).
local ACTION_TONE = {
    ready = "red", failed = "red", queued = "yellow", sent = "yellow", traded = "good", tradedAway = "good",
    none = "bad",   -- No action, gray (feedback-11 spec §1)
}

-- OFFER IN CYAN (feedback-6 spec §2): a button of kind `offer` (one that reads Offer) is cyan while it
-- is your move, not Ask's red; its other states take ACTION_TONE's.
local OFFER_TONE = { ready = "cyan", failed = "cyan" }

--- An action button's tone for its state: `red` your move (`cyan` for an Offer), `yellow` waiting,
--- `good` done; nil for a state that is none of them (the button keeps its own color).
--- @param state string|nil an ask state (`ready`, `queued`, `sent`, `failed`), `traded` or `tradedAway`
--- @param kind string|nil `offer` for a button that reads Offer (MineCells.OwnOffer, OfferButton)
--- @return string|nil a key of C.TONE
function WC.ActionTone(state, kind)
    return kind == "offer" and OFFER_TONE[state] or ACTION_TONE[state]
end

local function askTip(state, who, reason, template)
    if state == "queued" then
        return L["Queued"], L["Chat is restricted right now: the ask to %s is sent when it lifts."]:format(who), L["Click to cancel it."]
    end
    if state == "traded" then return L["Traded"], L["A completed trade gave you this item."] end
    if state == "sent" then return L["Asked"], L["You asked %s. One ask per item per looter, so it cannot be sent twice by accident."]:format(who) end
    if state == "failed" then return L["Retry"], L["The ask to %s was not sent: %s."]:format(who, tostring(reason or "?")), L["Click to try again."] end
    if template == "transmog" then
        return L["Ask for transmog"], L["Whisper %s your For transmog template: it is no gain for you, but you have not collected its look."]:format(who),
            L["One ask per item per looter."]
    end
    return L["Ask"], L["Whisper %s your ask template for this item."]:format(who), L["One ask per item per looter."]
end

--- The Ask button's look: `offered` false is WC.NoAction's (the gray No action with the reason,
--- feedback-11 spec §1); else the label, the
--- catalog mark (`chat` ask, `clock` queued, `confirm` asked or traded, `reset` retry) and whether
--- it can be clicked.
--- @param drop table
--- @param state string|nil NS.Asks.StateOf's state (`ready`, `queued`, `sent`, `failed`), or
--- `traded` once the history settled the drop received (NS.History.AskState)
--- @param reason string|nil its reason
--- @param transmogAsk boolean|nil the `messages.transmogAsk` setting: an ask is also offered for a
--- drop that is no gain for you but whose look you have not collected (`template` "transmog")
--- @return table { offered, text, icon, enabled, tip, state, template }
function WC.Ask(drop, state, reason, transmogAsk)
    local no, template = noAskReason(drop, transmogAsk)
    if no and state ~= "traded" then return WC.NoAction(no) end
    local look = ASK_LOOK[state] or ASK_LOOK.ready
    local s = ASK_LOOK[state] and state or "ready"
    return { offered = true, text = look.text, icon = look.icon, enabled = look.enabled,
        tip = { askTip(s, looterName(drop), reason, template) }, state = s, template = template or "ask" }
end

-- ── the encounter header ────────────────────────────────────────────────────────────────────

local KIND_LINE = {
    encounter = L["Drops from one boss encounter."], run = L["Drops from one Mythic+ run, the chest included."],
    area = L["Drops from this area, outside any boss encounter."],
}

-- At most this many hidden drops are named in a header's tooltip; the rest are counted.
WC.HIDDEN_TIP_LINES = 8

-- The filters that narrow WHICH groups the player asked for: a group they hide whole is left out.
local NARROWING = { search = true, content = true, char = true }

-- Whether a hidden drop is the player's narrowing question. A drop with no recorder (kept before
-- the Character dropdown) is too: Current hides it with the rest (feedback-12 spec §1).
local function narrowed(h)
    return NARROWING[h.why] == true
end

--- Whether a group keeps its header (feedback-2 spec §0, nothing hidden silently): when a drop is
--- shown under it, or when one the View filter hid is there to count (`n drops · 0 shown`, the
--- tooltip naming the filter). A group that Search, Content or the Character filter hides whole is
--- left out, since that is the question the player asked (a drop with no recorder too, feedback-12
--- spec §1).
--- @param shown number the drops shown under it
--- @param hidden table|nil { { drop, why }, ... }
--- @return boolean
function WC.KeepsHeader(shown, hidden)
    if (tonumber(shown) or 0) > 0 then return true end
    for _, h in ipairs(type(hidden) == "table" and hidden or {}) do
        if not narrowed(h) then return true end
    end
    return false
end

--- A group header's count (feedback-2 spec §0): every drop the group holds for the tab, and, while
--- a filter hides some, how many are shown: `2 drops · 1 shown`.
--- @param shown number the drops shown under it
--- @param hidden table|nil { { drop, why }, ... } the ones the filter hid
--- @return string
function WC.DropCount(shown, hidden)
    local nHidden = type(hidden) == "table" and #hidden or 0
    local total = (tonumber(shown) or 0) + nHidden
    local text = total == 1 and L["1 drop"] or L["%d drops"]:format(total)
    if nHidden > 0 then text = text .. " · " .. L["%d shown"]:format(shown) end
    return text
end

--- A header tooltip's lines for the drops a filter hid: each drop, its looter and the filter that
--- hid it (FB.ReasonLabel), the first WC.HIDDEN_TIP_LINES of them, then how many more.
--- @param hidden table|nil { { drop, why }, ... }
--- @param filter table|nil the tab's filter state
--- @return table lines (empty when nothing is hidden)
function WC.HiddenLines(hidden, filter)
    local out = {}
    if type(hidden) ~= "table" or #hidden == 0 then return out end
    out[1] = L["Hidden by the filters:"]
    for i, h in ipairs(hidden) do
        if i > WC.HIDDEN_TIP_LINES then
            out[#out + 1] = L["and %d more"]:format(#hidden - WC.HIDDEN_TIP_LINES)
            break
        end
        local who = type(h.drop.looter) == "table" and h.drop.looter.name or nil
        out[#out + 1] = L["%s (%s): %s"]:format(WC.ItemName(h.drop.link) or "?", WC.ShortName(who),
            NS.WindowFilterBar.ReasonLabel(h.why, filter))
    end
    return out
end

--- A group header's place and recorder (feedback-3 spec §4, modules/GroupPlace.lua): the instance,
--- the boss and the difficulty (the situation word without one), and the character that saw it in
--- its class color, nil when the group names none.
--- @param group table
--- @param situationLabel string|nil
--- @return table parts, string|nil who
function WC.Place(group, situationLabel)
    local GP = NS.GroupPlace
    return GP.Parts(group, situationLabel), GP.Who(group, NS.Compat.ClassColor)
end

--- A header tooltip: the title, the kind's line, the `Group: ...` line (the party, class-colored;
--- feedback-3 spec §4), the hidden drops' lines, then the click hint.
--- @param title string
--- @param line string
--- @param hidden table|nil
--- @param filter table|nil
--- @param collapsed boolean
--- @param roster table|nil the group's roster
--- @return table
function WC.HeaderTip(title, line, hidden, filter, collapsed, roster)
    local tip = { title, line }
    tip[#tip + 1] = NS.GroupRoster.TipLine(roster, NS.Compat.ClassColor)
    for _, l in ipairs(WC.HiddenLines(hidden, filter)) do tip[#tip + 1] = l end
    tip[#tip + 1] = collapsed and L["Click to expand this group."] or L["Click to collapse this group."]
    return tip
end

--- An encounter header's text and tooltip: `Instance · Boss · Difficulty · 2m ago · 4 drops · You`
--- (feedback-3 spec §4: the place, WC.Place, then the character that saw it, class-colored), or
--- `... · 2 drops · 1 shown · ...` while the filter hides some, the tooltip naming the party on one
--- line and each hidden drop.
--- @param group table a feed group { key, label, kind, situation, at, instance, difficulty, seenBy,
---   seenByClass, roster }
--- @param shown number the drops shown under it
--- @param now number|nil GetTime()
--- @param situationLabel string|nil the group's situation, in words
--- @param collapsed boolean
--- @param hidden table|nil { { drop, why }, ... } the group's drops the filter hid
--- @param filter table|nil the tab's filter state, to name the filters
--- @return table { text, tip }
function WC.Header(group, shown, now, situationLabel, collapsed, hidden, filter)
    local parts, who = WC.Place(group, situationLabel)
    if num(group.at) and num(now) then parts[#parts + 1] = L["%s ago"]:format(WC.Duration(now - group.at)) end
    parts[#parts + 1] = WC.DropCount(shown, hidden)
    parts[#parts + 1] = who
    local text = table.concat(parts, " · ")
    if collapsed then text = text .. " " .. L["(collapsed)"] end
    local title = tostring(group.label or "?")
    return { text = text, tip = WC.HeaderTip(title, KIND_LINE[group.kind] or KIND_LINE.area, hidden, filter, collapsed,
        group.roster) }
end

-- ── the table's entries (pure; peeled out of modules/WindowGroup.lua) ───────────────────────

-- A group's drops for the tab, split into those shown and those its filter hid ({ drop, why },
-- why the control's key, else `filter`). Every drop is the tab's (feedback-5 spec §2).
local function visibleDrops(group, get, ctx)
    local shown, hidden = {}, {}
    for _, id in ipairs(group.drops or {}) do
        local d = get(id)
        if d then
            if ctx.matches(d) then
                shown[#shown + 1] = d
            else
                hidden[#hidden + 1] = { drop = d, why = ctx.hiddenBy and ctx.hiddenBy(d) or "filter" }
            end
        end
    end
    table.sort(shown, ctx.compare)
    return shown, hidden
end

-- One group's header, then its shown drops unless it is collapsed.
local function appendGroup(out, g, drops, hidden, filter, c)
    out[#out + 1] = { kind = "header", group = g, count = #drops, total = #drops + #hidden,
        hidden = hidden, filter = filter, collapsed = c }
    if c then return end
    for _, d in ipairs(drops) do out[#out + 1] = { kind = "drop", drop = d } end
end

local function collapsedOf(collapsed, key, first)
    local v = collapsed[key]
    if v == nil then return not first end
    return v
end

--- The table's entries, top to bottom: { kind = "header", group, count, total, hidden, filter,
--- collapsed } and { kind = "drop", drop }. `count` is the drops shown, `total` every drop of the
--- group the tab lists, `hidden` the ones the filter hid ({ drop, why }), so the header can say
--- `2 drops · 1 shown` (feedback-2 spec §0). Your own drops are listed with the others (feedback-5
--- spec §2).
--- Groups newest first (oldest first under Sort: Oldest); a group with no drop passing the filter keeps an open header with count 0 unless KeepsHeader says no, and
--- does not take the first group's open default; a collapsed group's drops left out.
--- @param groups table the feed's groups, oldest first (NS.LootFeed.Groups)
--- @param get function id -> drop (NS.LootFeed.Get)
--- @param ctx table { matches = fn(drop), compare = fn(a, b), filter = { sort }, hiddenBy }
--- @param state table|nil { collapsed } (NS.State.windowGroup)
--- @return table
function WC.Entries(groups, get, ctx, state)
    state = state or {}
    local collapsed = state.collapsed or {}
    local oldest = type(ctx.filter) == "table" and ctx.filter.sort == "oldest"
    local from, to, step = #groups, 1, -1
    if oldest then from, to, step = 1, #groups, 1 end
    local out, first = {}, true
    for i = from, to, step do
        local g = groups[i]
        local drops, hidden = visibleDrops(g, get, ctx)
        if #drops > 0 then
            local c = collapsedOf(collapsed, g.key, first)
            first = false
            appendGroup(out, g, drops, hidden, ctx.filter, c)
        elseif WC.KeepsHeader(0, hidden) then
            appendGroup(out, g, drops, hidden, ctx.filter, false)
        end
    end
    return out
end
