local _, NS = ...
-- modules/ItemSearchVerdict.lua — the item tooltip's Keep / Hold / Sell / Toss badge (round 3 spec
-- §4.5, item 14c). WoW Forever's alone, as the tooltip block is (C.FEATURE.itemSearch, clients-§4).
-- The formula is Drop Watcher's own, from the round 3 recon's "Proposal" sections: no other addon's
-- code or logic is in it.
--
-- THE VERDICT (IS.Verdict, pure: every input is an argument, so a case drives it with invented
-- values). From the item's facts (NS.ItemSearch.Get's: its quests, recipes, vendors), the ranking's
-- context `me` (NS.ItemSearch.Me's: level, ranks, quest states) and the client's facts about the item
-- (`item`, below), it answers
--   { verdict = "keep" | "hold" | "sell" | "toss", score = 0..100, use = the use value,
--     confidence = 0..100, tier = "high" | "medium" | "low", reasons = { text, ... }, hint = text | nil }
-- THE USE VALUE (`use`) is the sum of the parts in C.ITEM_SEARCH.VERDICT, never clamped (R6-DW-07:
-- a disposal's may be under 0, a Keep's over 100), each one noting a reason: a
-- new collectible is 100 and nothing else is worked out; a quest in your log (or ready to turn in)
-- that needs the item +60 each, one you can pick up (its minimum level at most yours + 3) +35 (one
-- reason and one breakdown line for them all, "Quests you could pick up (N)", R5-DW-03), a
-- quest the item starts +50, the quests together at most 80; a known recipe in a profession you have
-- by its skill-up color (orange 30, yellow 20, green 8, gray 0), an unknown one your rank is below
-- the gray of +10, those together at most 50; +3 a recipe of a profession you lack (at most 9, and
-- only once your skills are read); gear +70 an upgrade, +20 a sidegrade. Then the dampers: -20 when
-- it is easy to buy again (3 or more vendors, or one at 500 copper or less a unit), -15 when every
-- use it has is gray or done. A poor-quality item stays at 15 or under unless a quest wants it; a
-- quest item (class 12, or bind type 4) no quest part counted is floored at 20, a Hold: it cannot
-- be sold and is risky to delete.
-- THE VERDICT WORD, from the use value: Keep at 50 and up, Hold at 20 and up; under 20, Sell when a vendor buys it, Toss
-- when none does, Hold while the sell price is not known. A Low confidence never says Toss: it holds
-- instead, so the addon never tells a player to delete what it could not judge. Nor does gear whose
-- gear verdict has not answered (Pawn still scoring), at any confidence: that part alone could add
-- +70, so a Toss would rest on the one input that could overturn it. An item no vendor buys that
-- would Toss (or hold for Low or unjudged gear) is a Sell said as Auction instead when an auction
-- brings anything after the cut and the deposit (R6-DW-06, NS.ItemSearchAuction's IAU.Via against a
-- vendor price of 0), at any confidence: an auction deletes nothing.
-- THE SCORE (R6-DW-07, the owner: "a normalized score from 0-100; higher is more confident; should
-- work across all verdicts") is the number on the badge: how sure Drop Watcher is of the word, never
-- how useful the item is. IS.Score: round(100 x E x D), D the confidence below as a fraction, E the
-- evidence for the word (C.ITEM_SEARCH.VERDICT.SURE, with the owner-approved design it cites): a
-- call on its band's edge 0.5, a clear one 1, a Hold only because too little is known 0.25; an
-- Auction's, a Vendor's or a Toss's the weaker of how far the use value is under 20 and the money
-- part (NS.ItemSearchAuction's IAU.Money: how far the auction beats, or falls short of, the margin).
-- Nothing ranks or sorts on it: Item Search's "Best for you" ranks an item's sources, never a verdict.
-- THE CONFIDENCE is not the use value: it is how much of what the verdict needs was answered, by weight
-- (C.ITEM_SEARCH.VERDICT.WEIGHT): ForeverDB loaded 3, the quest states 3 (needed with a quest row, or
-- without ForeverDB), the profession ranks 3 (needed with a recipe row), the client's item info 2
-- (its quality and sell price), the gear verdict 2 (needed for gear), ForeverDB knowing the item 1.
-- High at 80 and up, Medium at 50 and up, else Low; under High the `hint` names the heaviest
-- unanswered input's fix. The reasons are the top C.ITEM_SEARCH.VERDICT.REASONS by points (either
-- sign), a Sell's or a Toss's price reason always first, and then the largest negative part when
-- none is among them (round 4, R4-DW-07: a damper is never hidden, so the parts shown explain the
-- use value). The tier is never shown (the owner); it is kept so that Low never says Toss.
--
-- THE BREAKDOWN (IS.Breakdown, round 4 addendum A1, R4-DW-11: the Item Search window's verdict
-- panel). The same parts, worked out by the same code, as lines in the order the use value adds them:
-- each quest that counted; the known recipes by skill-up color, the recipes you could learn and the
-- other professions; gear; the dampers; then every bound that moved the sum, as its own line with
-- the points it took or gave (a hit cap, the poor-quality cap, the quest item's floor). The lines
-- add up to the use value, a part worth 0 is left out, and `from` is the line the
-- verdict word comes from, in plain words (R5-DW-06; since R6-DW-08 the use value and its band, "Use
-- value 60 (Keep at 50 or more)"), and `sure` the score's lines (How sure, R6-DW-08: the use value's
-- part, a disposal's money part, the evidence, the data known, the score). No confidence tier; the
-- fix (`hint`) is the confidence's, below High. The tooltip's hover asks for no breakdown and builds no line, so the
-- panel and the badge's reasons can never disagree and the hover pays nothing for it.
--
-- `item`: { quality, classID, subclassID, equippable, sellPrice, bindType, gear, newCollect, inDB,
-- stackCount, auctionPrice, auctionRule, auctionator }, every field optional: `gear` the gear
-- kernel's verdict for you ("upgrade", "sidegrade", ...; nil when there is none or Pawn is still
-- scoring), `newCollect` the collection verdict's, `inDB` whether ForeverDB has the item's row, the
-- last four the Auction or Vendor rule's (NS.ItemSearchAuction), `auctionator` whether Auctionator
-- was loaded (the score's money part with no price).
--
-- THE EDGE (IVD.For). The tooltip asks for the verdict on every hover, so it is kept per item id and
-- every kept verdict goes stale (IVD.Bump) when what it read can have moved: a quest log update or a
-- turn-in, the skill lines, the profession window, a level gained, a recipe, mount, pet or toy
-- learned, and Item Search's own cache emptied (ForeverDB or ForeverDB_Full loading, a recipe
-- learned, a vendor's price recorded). A gear verdict is worked out again when your gear's snapshot
-- moved, and a verdict whose item info or gear verdict was still loading is worked out again
-- C.ITEM_SEARCH.VERDICT.RETRY seconds on. A warm hover reads the memo and builds no table. The
-- client's facts come from NS.Compat.ItemInfoByID (the sell price and the bind type) and, for the
-- gear and collection verdicts, NS.ItemFacts and the feed's own judge of you (NS.LootFeed.JudgeMe).

NS.ItemSearch = NS.ItemSearch or {}
local IS = NS.ItemSearch
NS.ItemSearchVerdict = NS.ItemSearchVerdict or {}
local IVD = NS.ItemSearchVerdict
local C = NS.Constants
local L = NS.L

local IAU = NS.ItemSearchAuction
local V = C.ITEM_SEARCH.VERDICT
local floor, min, abs = math.floor, math.min, math.abs

local EMPTY = {}

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function list(v)
    return type(v) == "table" and v or EMPTY
end

-- ── the parts (each notes its reasons on `acc`) ─────────────────────────────────────────────

local function note(acc, points, text)
    acc[#acc + 1] = { text = text, points = points, n = #acc + 1 }
end

-- A breakdown line (IS.Breakdown) onto `acc.bd`, set only while a breakdown is asked for: the
-- hover's verdict builds none. A line worth 0 is left out (A1: zero parts hidden).
local function step(acc, kind, points, text)
    local bd = acc.bd
    if bd and points ~= 0 then bd[#bd + 1] = { kind = kind, points = points, text = text } end
end

-- A part that is both a reason and a breakdown line, in the same words.
local function both(acc, kind, points, text)
    note(acc, points, text)
    step(acc, kind, points, text)
end

local function titleOf(q)
    return q.title or L["Quest %d"]:format(num(q.id) or 0)
end

local function questStateOf(q, me)
    if q.state ~= nil then return q.state end
    if type(me.questState) == "function" and num(q.id) then return me.questState(q.id) end
    return nil
end

local function canPickUp(q, level)
    local minLevel = num(q.minLevel)
    return not (minLevel and level) or minLevel <= level + V.QUEST_CAN_ABOVE
end

local function questRow(q, me, acc)
    local state = questStateOf(q, me)
    if state == "log" then
        both(acc, "quest", V.QUEST_LOG, L["In your quest log: %s"]:format(titleOf(q)))
        return V.QUEST_LOG
    end
    if state == "ready" then
        both(acc, "quest", V.QUEST_LOG, L["Ready to turn in: %s"]:format(titleOf(q)))
        return V.QUEST_LOG
    end
    if state == "todo" and canPickUp(q, num(me.level)) then return V.QUEST_CAN, true end
    return 0
end

local IN_HAND = { done = true, log = true, ready = true }

local function questPart(facts, me, acc)
    local total, can = 0, 0
    for _, q in ipairs(list(facts.quests)) do
        if type(q) == "table" then
            local points, pickUp = questRow(q, me, acc)
            total = total + points
            if pickUp then can = can + 1 end
        end
    end
    -- the quests you could pick up as one count, like the recipes you could learn (R5-DW-03)
    if can > 0 then both(acc, "quest", can * V.QUEST_CAN, L["Quests you could pick up (%d)"]:format(can)) end
    local starts = facts.startsQuest
    if type(starts) == "table" and not IN_HAND[questStateOf(starts, me) or ""] then
        both(acc, "quest", V.STARTS, L["Starts a quest: %s"]:format(titleOf(starts)))
        total = total + V.STARTS
    end
    if total > V.QUESTS_CAP then
        step(acc, "cap", V.QUESTS_CAP - total, L["Quests count %d at most"]:format(V.QUESTS_CAP))
    end
    return min(total, V.QUESTS_CAP)
end

local function professionOf(row)
    local tip = NS.ItemSearchTip
    local name = tip and tip.ProfessionName and tip.ProfessionName(row.skillLine) or nil
    return name or L["A profession"]
end

local function colorWord(color)
    if color == "orange" then return L["orange"] end
    if color == "yellow" then return L["yellow"] end
    return L["green"]
end

-- One recipe onto the tally `t`: what a known one in your professions adds (and the best of them),
-- what an unknown one you could learn adds (and the first), and one in a profession you lack
-- (counted only once your skills are read: before that no profession is known to be missing).
local function tallyRow(t, c, read)
    local rank = num(c.rank)
    if not rank then
        if read then t.others = t.others + 1 end
        return
    end
    if c.known then
        local points = V.CRAFT[c.color] or 0
        t.known = t.known + points
        if points > 0 then t.byColor[c.color] = t.byColor[c.color] + 1 end
        if points > t.bestPoints then t.best, t.bestPoints = c, points end
    elseif num(c.gray) and rank < c.gray then
        t.learn = t.learn + V.LEARN
        t.learnRow = t.learnRow or c
    end
end

-- The tally is one scratch table, filled again on each call (a cold hover builds no table for it):
-- read straight after, never kept.
local tally = { byColor = {} }

-- The skill-up colors worth points, in the breakdown's order.
local COLORS = { "orange", "yellow", "green" }

local function craftTally(rows, read)
    local t = tally
    t.known, t.learn, t.others, t.best, t.bestPoints, t.learnRow = 0, 0, 0, nil, 0, nil
    for _, color in ipairs(COLORS) do t.byColor[color] = 0 end
    for _, c in ipairs(rows) do
        if type(c) == "table" then tallyRow(t, c, read) end
    end
    return t
end

-- The crafting part's breakdown lines (only while one is asked for): the known recipes by color, the
-- recipes you could learn, the crafting cap when hit, the other professions and their cap when hit.
local function craftSteps(acc, t)
    if not acc.bd then return end
    for _, color in ipairs(COLORS) do
        local n = t.byColor[color]
        step(acc, "craft", n * V.CRAFT[color], L["Known recipes, %s skill-up (%d)"]:format(colorWord(color), n))
    end
    step(acc, "craft", t.learn, L["Recipes you could learn (%d)"]:format(floor(t.learn / V.LEARN)))
    local own = t.known + t.learn
    if own > V.CRAFT_CAP then step(acc, "cap", V.CRAFT_CAP - own, L["Crafting counts %d at most"]:format(V.CRAFT_CAP)) end
    local raw = t.others * V.OTHERS
    step(acc, "craft", raw, L["Other professions use it (%d recipes)"]:format(t.others))
    if raw > V.OTHERS_CAP then
        step(acc, "cap", V.OTHERS_CAP - raw, L["Other professions count %d at most"]:format(V.OTHERS_CAP))
    end
end

local function craftPart(facts, me, acc)
    local t = craftTally(list(facts.crafting), IS.SkillsRead(me.ranks))
    craftSteps(acc, t)
    if t.best then
        note(acc, t.known, L["%s skill-up (%s)"]:format(professionOf(t.best), colorWord(t.best.color)))
    end
    if t.learnRow then note(acc, t.learn, L["%s recipe you could learn"]:format(professionOf(t.learnRow))) end
    local others = min(t.others * V.OTHERS, V.OTHERS_CAP)
    if t.others > 0 then note(acc, others, L["Other professions use it (%d recipes)"]:format(t.others)) end
    return min(t.known + t.learn, V.CRAFT_CAP) + others
end

local function gearPart(item, acc)
    if not item.equippable then return 0 end
    if item.gear == "upgrade" then
        both(acc, "gear", V.UPGRADE, L["Upgrade for you"])
        return V.UPGRADE
    end
    if item.gear == "sidegrade" then
        both(acc, "gear", V.SIDEGRADE, L["Sidegrade"])
        return V.SIDEGRADE
    end
    return 0
end

local function rebuyable(facts)
    local vendors = list(facts.vendors)
    if #vendors >= V.REBUY_VENDORS then return true end
    for _, v in ipairs(vendors) do
        local price = type(v) == "table" and IS.UnitPrice(v) or nil
        if price and price <= V.REBUY_PRICE then return true end
    end
    return false
end

-- Whether the item has a use and every one is gray or done: its quests (and the quest it starts)
-- all turned in, its recipes in your professions all gray.
local function trivial(facts, me)
    local uses, spent = 0, 0
    for _, q in ipairs(list(facts.quests)) do
        uses = uses + 1
        if type(q) == "table" and questStateOf(q, me) == "done" then spent = spent + 1 end
    end
    local starts = facts.startsQuest
    if type(starts) == "table" then
        uses = uses + 1
        if questStateOf(starts, me) == "done" then spent = spent + 1 end
    end
    for _, c in ipairs(list(facts.crafting)) do
        if type(c) == "table" and c.color then
            uses = uses + 1
            if c.color == "gray" then spent = spent + 1 end
        end
    end
    return uses > 0 and spent == uses
end

local function questItem(item)
    return num(item.classID) == 12 or num(item.bindType) == 4
end

-- The use value: the parts summed, with no 0..100 clamp (R6-DW-07: the shown score is the
-- sureness, so a disposal's use value may go below 0 and a Keep's above 100).
local function useOf(facts, me, item, acc)
    local quests = questPart(facts, me, acc)
    local sum = quests + craftPart(facts, me, acc) + gearPart(item, acc)
    if rebuyable(facts) then
        both(acc, "damper", V.REBUY, L["Easy to buy again"])
        sum = sum + V.REBUY
    end
    if trivial(facts, me) then
        both(acc, "damper", V.TRIVIAL, L["Every use is gray or done"])
        sum = sum + V.TRIVIAL
    end
    if num(item.quality) == 0 and quests == 0 and sum > V.POOR_CAP then
        step(acc, "cap", V.POOR_CAP - sum, L["Poor quality counts %d at most"]:format(V.POOR_CAP))
        sum = V.POOR_CAP
    end
    if questItem(item) and quests == 0 and sum < V.QUEST_FLOOR then
        note(acc, V.QUEST_FLOOR - sum, L["Quest item"])
        step(acc, "floor", V.QUEST_FLOOR - sum, L["A quest item counts %d at least"]:format(V.QUEST_FLOOR))
        sum = V.QUEST_FLOOR
    end
    return sum
end

-- ── the confidence ──────────────────────────────────────────────────────────────────────────

local function loaded(f) return f.fdb == "loaded" end
local function always() return true end

local function questsNeeded(f)
    return #list(f.quests) > 0 or not loaded(f)
end

local function questsAnswered(f)
    if not loaded(f) then return false end
    for _, q in ipairs(list(f.quests)) do
        if type(q) ~= "table" or q.state == nil then return false end
    end
    return true
end

-- Heaviest first; each input's weight key, when it is needed, when it is answered, and its fix.
local INPUTS = {
    { key = "fdb", needed = always, answered = loaded, hint = "fdb" },
    { key = "quests", needed = questsNeeded, answered = questsAnswered },
    { key = "ranks", needed = function(f) return #list(f.crafting) > 0 end,
      answered = function(_, me) return IS.SkillsRead(me.ranks) end, hint = "ranks" },
    { key = "item", needed = always,
      answered = function(_, _, item) return num(item.quality) ~= nil and num(item.sellPrice) ~= nil end, hint = "item" },
    { key = "gear", needed = function(_, _, item) return item.equippable == true end,
      answered = function(_, _, item) return item.gear ~= nil end, hint = "gear" },
    { key = "source", needed = always, answered = function(f, _, item) return loaded(f) and item.inDB == true end },
}

local function hintText(key)
    if key == "fdb" then return L["ForeverDB is not loaded"] end
    if key == "ranks" then return L["Open your profession window to rank recipes"] end
    if key == "item" then return L["Item info is still loading"] end
    return L["Pawn is still scoring"]
end

--- A confidence's tier: "high" at C.ITEM_SEARCH.VERDICT.HIGH (80) and up, "medium" at MEDIUM (50)
--- and up, else "low".
--- @param confidence number
--- @return string
function IS.ConfidenceTier(confidence)
    if confidence >= V.HIGH then return "high" end
    if confidence >= V.MEDIUM then return "medium" end
    return "low"
end

--- How much of what the verdict needs was answered (see the header): the confidence (0 to 100), its
--- tier ("high", "medium" or "low") and, under High, the heaviest unanswered input's fix (nil when
--- that input has none). Pure.
--- @param facts table NS.ItemSearch.Get's answer
--- @param me table NS.ItemSearch.Me's answer
--- @param item table the client's facts (see the header)
--- @return number confidence, string tier, string|nil hint
function IS.Confidence(facts, me, item)
    facts, me, item = facts or EMPTY, me or EMPTY, item or EMPTY
    local needed, answered, fix = 0, 0, nil
    for _, input in ipairs(INPUTS) do
        if input.needed(facts, me, item) then
            local w = V.WEIGHT[input.key]
            needed = needed + w
            if input.answered(facts, me, item) then
                answered = answered + w
            elseif not fix and input.hint then
                fix = input.hint
            end
        end
    end
    local confidence = floor(100 * answered / needed + 0.5)
    local tier = IS.ConfidenceTier(confidence)
    if tier == "high" or not fix then return confidence, tier, nil end
    return confidence, tier, hintText(fix)
end

-- The parts' notes go on one scratch list, emptied on each call: only the reasons shown are kept.
local notes = {}

local function scratchReasons(bd)
    for i = #notes, 1, -1 do notes[i] = nil end
    notes.bd = bd
    return notes
end

-- ── the verdict ─────────────────────────────────────────────────────────────────────────────

-- `unjudged`: an input that could overturn a Toss has not answered (gear with no gear verdict yet).
-- Answers the verdict and why: the key of the breakdown's `from` line (fromText).
local function decide(use, tier, sellPrice, unjudged)
    if use >= V.KEEP then return "keep", "keep" end
    if use >= V.HOLD then return "hold", "hold" end
    if not sellPrice then return "hold", "price" end
    if sellPrice > 0 then return "sell", "sell" end
    if tier == "low" or unjudged then return "hold", "unjudged" end
    return "toss", "toss"
end

-- The line the verdict word comes from, by decide's why, in plain words (R5-DW-06: "Keep from 50"
-- meant the score is 50 or more, so the word is Keep; the owner asked what it meant): since R6-DW-08
-- the use value and its band, "Use value -26 (Auction, Vendor or Toss under 20)" (the score being
-- how sure, the money's part of a disposal is in How sure).
local function fromText(why, use)
    if why == "keep" then return L["Use value %d (Keep at %d or more)"]:format(use, V.KEEP) end
    if why == "hold" then return L["Use value %d (Hold from %d to %d)"]:format(use, V.HOLD, V.KEEP - 1) end
    if why == "price" then
        return L["Use value %d (under %d, but the sell price is not known yet: Hold)"]:format(use, V.HOLD)
    end
    if why == "unjudged" then
        return L["Use value %d (under %d, but too little is known to toss it: Hold)"]:format(use, V.HOLD)
    end
    return L["Use value %d (Auction, Vendor or Toss under %d)"]:format(use, V.HOLD)
end

local function before(a, b)
    local pa, pb = abs(a.points), abs(b.points)
    if pa ~= pb then return pa > pb end
    return a.n < b.n
end

-- The reasons shown: a Sell's or a Toss's price reason first, then the parts with the most points
-- (either sign; a part worth nothing is left out), C.ITEM_SEARCH.VERDICT.REASONS in all, then the
-- largest negative part when none of those is negative (R4-DW-07), onto
-- `buf` (emptied first) when given. Without `buf`, no reason at all answers the one shared empty
-- list (read, never changed).
local NO_REASONS = {}

-- The parts with the most points onto `out`, up to C.ITEM_SEARCH.VERDICT.REASONS lines in all:
-- whether one of them is negative, and the last one shown.
local function topParts(acc, out)
    local negative, shown = false, nil
    for _, r in ipairs(acc) do
        if #out >= V.REASONS then break end
        if r.points ~= 0 then
            out[#out + 1], shown = r.text, r
            negative = negative or r.points < 0
        end
    end
    return negative, shown
end

-- The largest negative part past `shown` onto `out` (acc runs by size, so the first one found).
local function largestNegative(acc, shown, out)
    local past = shown == nil
    for _, r in ipairs(acc) do
        if past and r.points < 0 then out[#out + 1] = r.text; return end
        if r == shown then past = true end
    end
end

local function topReasons(acc, verdict, sellPrice, buf, via, net)
    if not buf and #acc == 0 and verdict ~= "sell" and verdict ~= "toss" then return NO_REASONS end
    local out = buf or {}
    for i = #out, 1, -1 do out[i] = nil end
    if verdict == "sell" then
        out[1] = IAU.Reason(via, sellPrice, net)
    elseif verdict == "toss" then
        out[1] = L["No use found, and no vendor buys it"]
    end
    table.sort(acc, before)
    local negative, shown = topParts(acc, out)
    if not negative then largestNegative(acc, shown, out) end
    return out
end

-- ── the score: how sure (R6-DW-07) ─────────────────────────────────────────────────────────

local SURE = V.SURE

local function part(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

-- The use value's part of the evidence, 0 to 1, for the word decide answered (`why`): how far into
-- its band the use value is. Nil for a fallback Hold (too little known), which has no part.
local function usePart(why, use)
    if why == "keep" then return part((use - V.KEEP) / SURE.KEEP_FULL) end
    if why == "hold" then return part(min(use - V.HOLD, V.KEEP - use) / SURE.HOLD_FULL) end
    if why == "price" or why == "unjudged" then return nil end
    return part((V.HOLD - use) / SURE.USE_FULL)
end

--- The score shown on the badge (R6-DW-07, C.ITEM_SEARCH.VERDICT.SURE): how sure the word is,
--- round(100 x E x D), D the confidence as a fraction and E the evidence for the word, EDGE plus
--- the rest times how clear the call is (a Keep's or a Hold's use part; a disposal's weaker of its
--- use part and `money`, NS.ItemSearchAuction's IAU.Money), FALLBACK for a Hold only because too
--- little is known. Answers the score, E, and the use part (nil for a fallback Hold). Pure.
--- @param why string decide's: "keep", "hold", "price", "unjudged", "sell" or "toss"
--- @param use number the use value
--- @param confidence number 0 to 100
--- @param money number|nil a disposal's money part, 0 to 1
--- @return number score, number evidence, number|nil usePart
function IS.Score(why, use, confidence, money)
    local p = usePart(why, use)
    local evidence = SURE.FALLBACK
    if p then
        local clear = p
        if (why == "sell" or why == "toss") and money then clear = min(p, money) end
        evidence = SURE.EDGE + (1 - SURE.EDGE) * clear
    end
    return floor(evidence * confidence + 0.5), evidence, p
end

-- The verdict worked out once for IS.Verdict and IS.Breakdown alike, onto the one scratch `res`
-- (read straight after, never kept): the breakdown's lines go onto `bd` when given. Fills the
-- verdict, why, the use value, the confidence, its tier, the fix, the sell price and the parts'
-- notes (`acc`), then a Sell's Auction or Vendor answer (`via`, NS.ItemSearchAuction's IAU.Via on
-- `item.auctionRule`), the net and the auction price it was judged on (R5-DW-14), and the score
-- (R6-DW-07): its evidence, use part, money part and the money's key and ratio (IAU.Money).
local res = {}

local function judge(facts, me, item, bd)
    local r = res
    local confidence, tier, hint = IS.Confidence(facts, me, item)
    local acc, use = scratchReasons(bd), V.COLLECT
    if item.newCollect then
        both(acc, "collect", V.COLLECT, L["New to your collection"])
    else
        use = useOf(facts, me, item, acc)
    end
    local sellPrice = num(item.sellPrice)
    local verdict, why = decide(use, tier, sellPrice, item.equippable == true and item.gear == nil)
    acc.bd = nil
    local via, net, price
    if verdict == "sell" then
        via, net, price = IAU.Via(item, item.auctionRule)
    elseif why == "toss" or why == "unjudged" then
        -- no vendor buys it (R6-DW-06, the owner): an auction that brings anything after the cut and
        -- the deposit is an Auction, at any confidence (it is not destructive); else Toss or Hold
        via, net, price = IAU.Via(item, item.auctionRule)
        if via == "auction" then verdict, why = "sell", "sell" else via = nil end
    end
    local money, moneyKey, ratio
    if why == "sell" or why == "toss" then money, moneyKey, ratio = IAU.Money(via or "toss", item, net) end
    r.verdict, r.why, r.use, r.confidence, r.tier, r.hint, r.sellPrice, r.acc = verdict, why, use, confidence,
        tier, hint, sellPrice, acc
    -- the net and the price a Sell carries (nil for every other verdict, R5-DW-15); a Toss's
    -- comparison is kept apart (`seenPrice`) for the panel's prices
    r.via, r.net, r.price = via, verdict == "sell" and net or nil, verdict == "sell" and price or nil
    r.seenNet, r.seenPrice = why == "toss" and net or nil, why == "toss" and price or nil
    r.money, r.moneyKey, r.ratio = money, moneyKey, ratio
    r.score, r.evidence, r.usePart = IS.Score(why, use, confidence, money)
    return r
end

--- The item's verdict for the player now (see the header): `{ verdict, score, use, confidence, tier,
--- reasons, hint, sellVia, auctionNet, auctionPrice }` (`score` how sure, IS.Score's; `use` the use
--- value the word comes from, R6-DW-07), a new table (`reasons` a shared empty list
--- when there is none). A Sell keeps the verdict "sell" and says how in `sellVia`, "auction" or
--- "vendor", with the net and the auction price it was judged on (nil when there was no
--- comparison); the three are nil for every other verdict (R5-DW-15). Pure: every
--- input is an argument. `into`, when given, is filled and answered instead, its reasons written
--- onto its own `into.reasons` list (the memo's scratch: see IVD.For).
--- @param facts table NS.ItemSearch.Get's answer
--- @param me table NS.ItemSearch.Me's answer
--- @param item table the client's facts (see the header)
--- @param into table|nil
--- @return table
function IS.Verdict(facts, me, item, into)
    facts, me, item = facts or EMPTY, me or EMPTY, item or EMPTY
    local r = judge(facts, me, item)
    local verdict, via, net = r.verdict, r.via, r.net
    if not into then
        return { verdict = verdict, score = r.score, use = r.use, confidence = r.confidence, tier = r.tier,
            reasons = topReasons(r.acc, verdict, r.sellPrice, nil, via, net), hint = r.hint,
            sellVia = via, auctionNet = net, auctionPrice = r.price }
    end
    into.verdict, into.score, into.use, into.confidence, into.tier, into.hint = verdict, r.score, r.use,
        r.confidence, r.tier, r.hint
    into.reasons = topReasons(r.acc, verdict, r.sellPrice, into.reasons or {}, via, net)
    into.sellVia, into.auctionNet, into.auctionPrice = via, net, r.price
    return into
end

-- ── How sure: the score's lines (R6-DW-08) ─────────────────────────────────────────────────

local function pct(x)
    return ("%d%%"):format(floor(100 * x + 0.5))
end

-- The word on the badge for a worked-out verdict: Keep, Hold, Auction, Vendor or Toss.
local function wordOf(r)
    if r.verdict == "sell" then return IAU.Word(r.via) end
    if r.verdict == "keep" then return L["Keep"] end
    if r.verdict == "toss" then return L["Toss"] end
    return L["Hold"]
end

-- The use value's evidence line: where in its band it sits (a full part says "well past" or "well
-- under", as the design's "Use value well under 20").
local function useLine(r)
    local use, p = r.use, r.usePart
    if r.why == "keep" then
        if p >= 1 then return L["Use value well past Keep's %d"]:format(V.KEEP) end
        return L["Use value %d, %d past Keep's %d"]:format(use, use - V.KEEP, V.KEEP)
    end
    if r.why == "hold" then
        return L["Use value %d, %d inside Hold's %d to %d"]:format(use, min(use - V.HOLD, V.KEEP - use), V.HOLD, V.KEEP - 1)
    end
    if p >= 1 then return L["Use value well under %d"]:format(V.HOLD) end
    return L["Use value %d, %d under %d"]:format(use, V.HOLD - use, V.HOLD)
end

-- How sure's lines, `{ text, right }` each: the use value's part, a disposal's money part (with the
-- margin it was judged against, IAU.MoneyLine), the evidence for the word, the data known and the
-- score. A Hold only because too little is known has no part: its evidence line says so.
local function sureRows(r, item)
    local out = {}
    if r.usePart then
        out[#out + 1] = { text = useLine(r), right = pct(r.usePart) }
        if r.money then
            local margin = type(item.auctionRule) == "table" and item.auctionRule.margin or C.ITEM_SEARCH.AUCTION.MARGIN
            out[#out + 1] = { text = IAU.MoneyLine(r.moneyKey, r.ratio, margin, r.net), right = pct(r.money) }
        end
        out[#out + 1] = { text = L["Evidence for %s"]:format(wordOf(r)), right = pct(r.evidence) }
    else
        out[#out + 1] = { text = L["Evidence for Hold, too little known to say more"], right = pct(r.evidence) }
    end
    out[#out + 1] = { text = L["Data known"], right = ("%d%%"):format(r.confidence) }
    out[#out + 1] = { text = L["Score"], right = tostring(r.score) }
    return out
end

--- The verdict's breakdown (see the header; round 4 addendum A1, R4-DW-11): `{ verdict, score, use, lines,
--- from, hint, sure, sellVia, sellPrice, auctionPrice, auctionNet, auctionOn }` (the last five a Sell's
--- or a Toss's, R5-DW-15: the verdict panel shows both prices; `sure` How sure's `{ text, right }`
--- lines, R6-DW-08), `lines` each `{ kind, points, text }` in the order the use value adds them (`kind`
--- "quest", "craft", "gear", "damper", "collect", or a bound: "cap", "floor"), adding up to
--- `use`; `from` the line the verdict word comes from; `hint` the confidence's fix below High, or
--- nil. No confidence or tier fields (How sure words the data known). The same verdict and score as IS.Verdict's for the same inputs. A new
--- table each call (the window's verdict panel asks for it, never a hover). Pure.
--- @param facts table NS.ItemSearch.Get's answer
--- @param me table NS.ItemSearch.Me's answer
--- @param item table the client's facts (see the header)
--- @return table
function IS.Breakdown(facts, me, item)
    facts, me, item = facts or EMPTY, me or EMPTY, item or EMPTY
    local lines = {}
    local r = judge(facts, me, item, lines)
    local verdict, sellPrice = r.verdict, r.sellPrice
    local b = { verdict = verdict, score = r.score, use = r.use, lines = lines, from = fromText(r.why, r.use),
        hint = r.hint, sure = sureRows(r, item) }
    if verdict == "sell" or verdict == "toss" then
        b.sellVia, b.sellPrice, b.auctionPrice, b.auctionNet = r.via, sellPrice, r.price or r.seenPrice, r.net or r.seenNet
        -- whether a price was looked for: the comparison on and the item auctionable
        b.auctionOn = type(item.auctionRule) == "table" and item.auctionRule.on == true and IAU.Auctionable(item.bindType)
    end
    return b
end

-- ── how the score works, explained (R5-DW-07) ───────────────────────────────────────────────

-- The help's sections (R6-DW-03, the owner: "Add bullet points and coloring of section header and
-- some more spacing between sections"): a blank line, the header in muted gold (the tooltip block's
-- section headers' tone), then each entry bulleted as the tooltip's reason lines are (two spaces and
-- a muted gold dot). GameTooltip wraps a long entry from the line's left edge: it has no hanging indent.
local function helpGold(text)
    local t = C.TONE.mutedGold
    return NS.GroupRoster.Colored(text, t.r, t.g, t.b)
end

local function helpSection(out, header, entries)
    out[#out + 1] = " "
    out[#out + 1] = helpGold(header)
    local dot = "  " .. helpGold("·") .. " "
    for _, entry in ipairs(entries) do out[#out + 1] = dot .. entry end
end

--- How the verdict and its score work, for the verdict panel's (?) icon (R5-DW-07; R6-DW-08): the
--- title and one line on the two numbers (the use value picks the word, the score says how sure),
--- then the sections The use value adds, The use value takes away, The word and The score (R6-DW-03:
--- each after a blank line, its header in muted gold, its entries bulleted), every number read from
--- C.ITEM_SEARCH.VERDICT (never copied by hand), so the help moves with the scorer, and the Auction
--- or Vendor rule and the score's money part from the live settings (IAU.HelpLines, R5-DW-15;
--- IAU.ScoreHelp). The data-known rule keeps its hint and never-Toss bars. A new list each call (a
--- hover's, never the tooltip block's).
--- @return table lines
function IVD.ScoringHelp()
    local c = V.CRAFT
    local cheap = NS.Compat.CoinText(V.REBUY_PRICE) or tostring(V.REBUY_PRICE)
    local out = {
        L["How the verdict and score work"],
        L["The word comes from the use value: what the item is still good for to this character. The score, 0 to 100, is how sure Drop Watcher is of that word."],
    }
    helpSection(out, L["The use value adds:"], {
        L["A quest in your log or ready to hand in: +%d each"]:format(V.QUEST_LOG),
        L["A quest you could pick up (up to %d levels above you): +%d each"]:format(V.QUEST_CAN_ABOVE, V.QUEST_CAN),
        L["A quest it starts: +%d (quests count %d at most)"]:format(V.STARTS, V.QUESTS_CAP),
        L["Your recipe by skill-up: orange +%d, yellow +%d, green +%d"]:format(c.orange, c.yellow, c.green),
        L["A recipe you could learn: +%d (your recipes count %d at most)"]:format(V.LEARN, V.CRAFT_CAP),
        L["Another profession's recipe: +%d (%d at most)"]:format(V.OTHERS, V.OTHERS_CAP),
        L["Gear: an upgrade +%d, a sidegrade +%d"]:format(V.UPGRADE, V.SIDEGRADE),
        L["New to your collection: %d"]:format(V.COLLECT),
    })
    helpSection(out, L["The use value takes away:"], {
        L["Easy to buy again (%d or more vendors, or %s or less): %d"]:format(V.REBUY_VENDORS, cheap, V.REBUY),
        L["Every use gray or done: %d"]:format(V.TRIVIAL),
        L["Poor quality counts %d at most, unless a quest wants it; a quest item %d at least"]:format(V.POOR_CAP,
            V.QUEST_FLOOR),
    })
    local word = { L["Keep: a use value of %d or more. Hold: %d to %d."]:format(V.KEEP, V.HOLD, V.KEEP - 1) }
    for _, line in ipairs(IAU.HelpLines(V.HOLD)) do word[#word + 1] = line end
    helpSection(out, L["The word:"], word)
    local edge = floor(SURE.EDGE * 100 + 0.5)
    helpSection(out, L["The score:"], {
        L["Score = evidence for the word x data known, 0 to 100."],
        L["Evidence: %d%% for a call on its band's edge, 100%% for a clear one: a Keep at a use value of %d or more, a Hold at %d."]
            :format(edge, V.KEEP + SURE.KEEP_FULL, V.HOLD + SURE.HOLD_FULL),
        L["Auction, Vendor or Toss: the weaker of how far the use value is under %d (100%% at %d or less) and how clear the money is."]
            :format(V.HOLD, V.HOLD - SURE.USE_FULL),
        IAU.ScoreHelp(),
        L["A Hold only because too little is known: %d%%."]:format(floor(SURE.FALLBACK * 100 + 0.5)),
        L["Data known is how much of what the verdict needs is known. Under %d%% a hint says what is missing; under %d%% it never says Toss, and holds instead."]:format(V.HIGH, V.MEDIUM),
    })
    return out
end

-- ── the edge: the client's facts and the memo ───────────────────────────────────────────────

-- Per item id: `{ gen, answer, retryAt, gearSig }`. An entry under an older generation is stale;
-- it is filled again in place (a cold hover builds no new entry for an item seen before).
local memo, generation = {}, 0

--- Make every kept verdict stale: what a verdict read can have moved (see the header). Also the
--- suites' handle.
function IVD.Bump()
    generation = generation + 1
end

--- The memo's generation: it moves on every IVD.Bump, so a caller that keeps what it drew from a
--- verdict (the window's verdict panel) knows when to work it out again.
--- @return number
function IVD.Generation()
    return generation
end

local function now()
    return type(GetTime) == "function" and GetTime() or 0
end

-- Your gear snapshot's signature (NS.Gear): a gear verdict kept under another one is stale.
local function gearSignature()
    local G = NS.Gear
    local snap = G and G.Snapshot and G.Snapshot() or nil
    return type(snap) == "table" and snap.signature or false
end

-- Whether a judge of you says Pawn (or another scorer) has not answered yet.
local function scorePending(me)
    for _, r in ipairs(list(me.reasons)) do
        if type(r) == "table" and r.key == "scorePending" then return true end
    end
    return false
end

-- The gear verdict and the collection verdict for you, from the feed's own judge (a cold path: the
-- memo keeps the answer). Nil gear while the scorer is pending or the verdict is unknown.
local function judgeOf(link)
    local IF, LF = NS.ItemFacts, NS.LootFeed
    if not (link and IF and LF and type(IF.Get) == "function" and type(LF.JudgeMe) == "function") then return nil, nil end
    local ok, facts = pcall(IF.Get, link)
    if not ok or type(facts) ~= "table" then return nil, nil end
    local judged, me = pcall(LF.JudgeMe, facts, false)
    if not judged or type(me) ~= "table" then return nil, nil end
    if me.collect then return nil, me.verdict == "newCollect" end
    if scorePending(me) or me.verdict == "unknown" then return nil, false end
    return me.verdict, false
end

--- The client's facts IS.Verdict reads for `itemID` (see the header), and whether the client had the
--- item cached. Without it the quality and classes come from ForeverDB's row (`facts.item`) and the
--- sell price stays unknown. `inDB` is the static facts' (`facts.item.inDB`): no second read.
--- `into`, when given, is filled and answered in place of a new table (the hover's one scratch).
--- @param itemID number
--- @param facts table NS.ItemSearch.Get's answer
--- @param into table|nil
--- @return table item, boolean cached
function IVD.ClientFacts(itemID, facts, into)
    local row = type(facts) == "table" and type(facts.item) == "table" and facts.item or EMPTY
    local item = into or {}
    item.inDB = row.inDB == true
    local info = NS.Compat.ItemInfoByID(itemID)
    if not info then
        item.quality, item.classID, item.subclassID = num(row.quality), num(row.classID), num(row.subclassID)
        item.sellPrice, item.bindType, item.equippable, item.gear, item.newCollect = nil, nil, nil, nil, nil
        item.stackCount, item.auctionPrice, item.auctionRule, item.auctionator = nil, nil, nil, nil
        return item, false
    end
    item.quality, item.classID, item.subclassID = info.quality, info.classID, info.subclassID
    item.sellPrice, item.bindType, item.stackCount = info.sellPrice, info.bindType, info.stackCount
    -- A Sell's Auction or Vendor answer (R5-DW-13): the live settings, and Auctionator's price only
    -- while the comparison is on (NS.Compat.AuctionPrice: nil without Auctionator).
    local rule = IAU.Rule()
    item.auctionRule = rule
    item.auctionPrice = rule.on and NS.Compat.AuctionPrice(info.link, itemID) or nil
    -- whether Auctionator is loaded: with no price, the score's money part (R6-DW-07, IAU.Money)
    item.auctionator = NS.Compat.AuctionatorLoaded()
    item.equippable = C.SLOT_PLAN[info.equipLoc or ""] ~= nil
    item.gear, item.newCollect = judgeOf(info.link)
    return item, true
end

--- Your gear snapshot's signature now (NS.Gear's), false when there is none: a caller that keeps a
--- gear item's breakdown (the window's verdict panel) works it out again when it moved, as the memo
--- does (IVD.For).
--- @return string|boolean
function IVD.GearSignature()
    return gearSignature()
end

--- The breakdown on `itemID` now (IS.Breakdown over the client's facts, IVD.ClientFacts'), worked out
--- afresh: for the window's verdict panel, never a hover. Also whether it is settled: false while the
--- client had not cached the item or the gear verdict had not answered (IVD.For's retry case). And,
--- for gear, the gear signature it was judged under (IVD.GearSignature's; nil for an item that is not
--- gear), the memo's own stale rule.
--- @param itemID number
--- @param facts table NS.ItemSearch.Get's answer
--- @param me table NS.ItemSearch.Me's answer
--- @return table breakdown, boolean settled, string|boolean|nil gearSig
function IVD.Breakdown(itemID, facts, me)
    local item, cached = IVD.ClientFacts(itemID, facts)
    local gearSig = item.equippable and gearSignature() or nil
    return IS.Breakdown(facts, me, item), cached and not (item.equippable and item.gear == nil), gearSig
end

-- The client's facts and the answer for the verdict being worked out: one table each, filled again
-- each time. The answer is kept as a copy only when it differs from the item's last one, so the
-- many QUEST_LOG_UPDATE bumps that change nothing leave no garbage and the same answer (and so the
-- same badge) stands.
local clientScratch = {}
local answerScratch = { reasons = {} }

local function sameAnswer(a, b)
    if a.verdict ~= b.verdict or a.score ~= b.score or a.use ~= b.use or a.confidence ~= b.confidence or a.tier ~= b.tier
        or a.hint ~= b.hint or #a.reasons ~= #b.reasons or a.sellVia ~= b.sellVia
        or a.auctionNet ~= b.auctionNet or a.auctionPrice ~= b.auctionPrice then
        return false
    end
    for i = 1, #a.reasons do
        if a.reasons[i] ~= b.reasons[i] then return false end
    end
    return true
end

local function copyAnswer(a)
    local reasons = NO_REASONS
    if #a.reasons > 0 then
        reasons = {}
        for i, text in ipairs(a.reasons) do reasons[i] = text end
    end
    return { verdict = a.verdict, score = a.score, use = a.use, confidence = a.confidence, tier = a.tier, reasons = reasons,
        hint = a.hint, sellVia = a.sellVia, auctionNet = a.auctionNet, auctionPrice = a.auctionPrice }
end

local function stale(e)
    if e.gen ~= generation then return true end
    if e.retryAt and now() >= e.retryAt then return true end
    return e.gearSig ~= nil and gearSignature() ~= e.gearSig
end

--- The verdict on `itemID` for the tooltip's hover (IS.Verdict's answer), kept per item until the
--- memo empties (IVD.Bump), your gear moves (gear only), or, while its item info or gear verdict
--- was still loading, C.ITEM_SEARCH.VERDICT.RETRY seconds on. A kept answer is the same table, and
--- so is one worked out again to the same verdict, score, use value, confidence, reasons, fix and
--- prices (the score's every input among them, R6-DW-07).
--- @param itemID number
--- @param facts table NS.ItemSearch.Get's answer
--- @param me table NS.ItemSearch.Me's answer
--- @return table
function IVD.For(itemID, facts, me)
    local e = memo[itemID]
    if e and not stale(e) then return e.answer end
    local item, cached = IVD.ClientFacts(itemID, facts, clientScratch)
    e = e or {}
    local fresh = IS.Verdict(facts, me, item, answerScratch)
    if not (e.answer and sameAnswer(e.answer, fresh)) then e.answer = copyAnswer(fresh) end
    e.gen = generation
    e.retryAt = (not cached or (item.equippable and item.gear == nil)) and now() + V.RETRY or nil
    e.gearSig = item.equippable and gearSignature() or nil
    memo[itemID] = e
    return e.answer
end

-- ── events ──────────────────────────────────────────────────────────────────────────────────

-- WoW Forever's alone; each event is shared with its other rows through core/DropWatcher.lua's
-- dispatcher.
for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW",
    "PLAYER_LEVEL_UP", "NEW_RECIPE_LEARNED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED",
    -- Auctionator's prices move while the auction house is open (its scans): read again once it shuts
    -- (R5-DW-13).
    "AUCTION_HOUSE_CLOSED" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnItemSearchVerdictEvent", clients = { "forever" } }
end

function NS.addon.OnItemSearchVerdictEvent()
    IVD.Bump()
end
