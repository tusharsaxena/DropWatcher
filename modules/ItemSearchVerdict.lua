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
--   { verdict = "keep" | "hold" | "sell" | "toss", score = 0..100, confidence = 0..100,
--     tier = "high" | "medium" | "low", reasons = { text, ... }, hint = text | nil }
-- THE SCORE is clamp(sum, 0, 100) of the parts in C.ITEM_SEARCH.VERDICT, each one noting a reason: a
-- new collectible is 100 and nothing else is worked out; a quest in your log (or ready to turn in)
-- that needs the item +60 each, one you can pick up (its minimum level at most yours + 3) +35, a
-- quest the item starts +50, the quests together at most 80; a known recipe in a profession you have
-- by its skill-up color (orange 30, yellow 20, green 8, gray 0), an unknown one your rank is below
-- the gray of +10, those together at most 50; +3 a recipe of a profession you lack (at most 9, and
-- only once your skills are read); gear +70 an upgrade, +20 a sidegrade. Then the dampers: -20 when
-- it is easy to buy again (3 or more vendors, or one at 500 copper or less a unit), -15 when every
-- use it has is gray or done. A poor-quality item stays at 15 or under unless a quest wants it; a
-- quest item (class 12, or bind type 4) no quest part counted is floored at 20, a Hold: it cannot
-- be sold and is risky to delete.
-- THE VERDICT WORD: Keep at 50 and up, Hold at 20 and up; under 20, Sell when a vendor buys it, Toss
-- when none does, Hold while the sell price is not known. A Low confidence never says Toss: it holds
-- instead, so the addon never tells a player to delete what it could not judge.
-- THE CONFIDENCE is not the score: it is how much of what the score needs was answered, by weight
-- (C.ITEM_SEARCH.VERDICT.WEIGHT): ForeverDB loaded 3, the quest states 3 (needed with a quest row, or
-- without ForeverDB), the profession ranks 3 (needed with a recipe row), the client's item info 2
-- (its quality and sell price), the gear verdict 2 (needed for gear), ForeverDB knowing the item 1.
-- High at 80 and up, Medium at 50 and up, else Low; under High the `hint` names the heaviest
-- unanswered input's fix. The reasons are the top C.ITEM_SEARCH.VERDICT.REASONS by points (either
-- sign), a Sell's or a Toss's price reason always first.
--
-- `item`: { quality, classID, subclassID, equippable, sellPrice, bindType, gear, newCollect, inDB },
-- every field optional: `gear` the gear kernel's verdict for you ("upgrade", "sidegrade", ...; nil
-- when there is none or Pawn is still scoring), `newCollect` the collection verdict's, `inDB` whether
-- ForeverDB has the item's row.
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

local V = C.ITEM_SEARCH.VERDICT
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

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
        note(acc, V.QUEST_LOG, L["In your quest log: %s"]:format(titleOf(q)))
        return V.QUEST_LOG
    end
    if state == "ready" then
        note(acc, V.QUEST_LOG, L["Ready to turn in: %s"]:format(titleOf(q)))
        return V.QUEST_LOG
    end
    if state == "todo" and canPickUp(q, num(me.level)) then
        note(acc, V.QUEST_CAN, L["Quest you can pick up: %s"]:format(titleOf(q)))
        return V.QUEST_CAN
    end
    return 0
end

local IN_HAND = { done = true, log = true, ready = true }

local function questPart(facts, me, acc)
    local total = 0
    for _, q in ipairs(list(facts.quests)) do
        if type(q) == "table" then total = total + questRow(q, me, acc) end
    end
    local starts = facts.startsQuest
    if type(starts) == "table" and not IN_HAND[questStateOf(starts, me) or ""] then
        note(acc, V.STARTS, L["Starts a quest: %s"]:format(titleOf(starts)))
        total = total + V.STARTS
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
        if points > t.bestPoints then t.best, t.bestPoints = c, points end
    elseif num(c.gray) and rank < c.gray then
        t.learn = t.learn + V.LEARN
        t.learnRow = t.learnRow or c
    end
end

-- The tally is one scratch table, filled again on each call (a cold hover builds no table for it):
-- read straight after, never kept.
local tally = {}

local function craftTally(rows, read)
    local t = tally
    t.known, t.learn, t.others, t.best, t.bestPoints, t.learnRow = 0, 0, 0, nil, 0, nil
    for _, c in ipairs(rows) do
        if type(c) == "table" then tallyRow(t, c, read) end
    end
    return t
end

local function craftPart(facts, me, acc)
    local t = craftTally(list(facts.crafting), IS.SkillsRead(me.ranks))
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
        note(acc, V.UPGRADE, L["Upgrade for you"])
        return V.UPGRADE
    end
    if item.gear == "sidegrade" then
        note(acc, V.SIDEGRADE, L["Sidegrade"])
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

local function scoreOf(facts, me, item, acc)
    local quests = questPart(facts, me, acc)
    local sum = quests + craftPart(facts, me, acc) + gearPart(item, acc)
    if rebuyable(facts) then
        note(acc, V.REBUY, L["Easy to buy again"])
        sum = sum + V.REBUY
    end
    if trivial(facts, me) then
        note(acc, V.TRIVIAL, L["Every use is gray or done"])
        sum = sum + V.TRIVIAL
    end
    local score = max(0, min(100, sum))
    if num(item.quality) == 0 and quests == 0 then score = min(score, V.POOR_CAP) end
    if questItem(item) and quests == 0 and score < V.QUEST_FLOOR then
        note(acc, V.QUEST_FLOOR - score, L["Quest item"])
        score = V.QUEST_FLOOR
    end
    return score
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
    if key == "ranks" then return L["open your profession window to rank recipes"] end
    if key == "item" then return L["item info is still loading"] end
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

--- How much of what the score needs was answered (see the header): the confidence (0 to 100), its
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

local function scratchReasons()
    for i = #notes, 1, -1 do notes[i] = nil end
    return notes
end

-- ── the verdict ─────────────────────────────────────────────────────────────────────────────

local function decide(score, tier, sellPrice)
    if score >= V.KEEP then return "keep" end
    if score >= V.HOLD or not sellPrice then return "hold" end
    if sellPrice > 0 then return "sell" end
    return tier == "low" and "hold" or "toss"
end

local function before(a, b)
    local pa, pb = abs(a.points), abs(b.points)
    if pa ~= pb then return pa > pb end
    return a.n < b.n
end

-- The reasons shown: a Sell's or a Toss's price reason first, then the parts with the most points
-- (either sign; a part worth nothing is left out), C.ITEM_SEARCH.VERDICT.REASONS in all, onto
-- `buf` (emptied first) when given. Without `buf`, no reason at all answers the one shared empty
-- list (read, never changed).
local NO_REASONS = {}

local function topReasons(acc, verdict, sellPrice, buf)
    if not buf and #acc == 0 and verdict ~= "sell" and verdict ~= "toss" then return NO_REASONS end
    local out = buf or {}
    for i = #out, 1, -1 do out[i] = nil end
    if verdict == "sell" then
        out[1] = L["Sells for %s"]:format(NS.Compat.CoinText(sellPrice) or tostring(sellPrice))
    elseif verdict == "toss" then
        out[1] = L["No use found, and no vendor buys it"]
    end
    table.sort(acc, before)
    for _, r in ipairs(acc) do
        if #out >= V.REASONS then break end
        if r.points ~= 0 then out[#out + 1] = r.text end
    end
    return out
end

--- The item's verdict for the player now (see the header): `{ verdict, score, confidence, tier,
--- reasons, hint }`, a new table (`reasons` a shared empty list when there is none). Pure: every
--- input is an argument. `into`, when given, is filled and answered instead, its reasons written
--- onto its own `into.reasons` list (the memo's scratch: see IVD.For).
--- @param facts table NS.ItemSearch.Get's answer
--- @param me table NS.ItemSearch.Me's answer
--- @param item table the client's facts (see the header)
--- @param into table|nil
--- @return table
function IS.Verdict(facts, me, item, into)
    facts, me, item = facts or EMPTY, me or EMPTY, item or EMPTY
    local confidence, tier, hint = IS.Confidence(facts, me, item)
    local acc, score = scratchReasons(), 100
    if item.newCollect then
        note(acc, 100, L["New to your collection"])
    else
        score = scoreOf(facts, me, item, acc)
    end
    local sellPrice = num(item.sellPrice)
    local verdict = decide(score, tier, sellPrice)
    if not into then
        return { verdict = verdict, score = score, confidence = confidence, tier = tier,
            reasons = topReasons(acc, verdict, sellPrice), hint = hint }
    end
    into.verdict, into.score, into.confidence, into.tier, into.hint = verdict, score, confidence, tier, hint
    into.reasons = topReasons(acc, verdict, sellPrice, into.reasons or {})
    return into
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
        return item, false
    end
    item.quality, item.classID, item.subclassID = info.quality, info.classID, info.subclassID
    item.sellPrice, item.bindType = info.sellPrice, info.bindType
    item.equippable = C.SLOT_PLAN[info.equipLoc or ""] ~= nil
    item.gear, item.newCollect = judgeOf(info.link)
    return item, true
end

-- The client's facts and the answer for the verdict being worked out: one table each, filled again
-- each time. The answer is kept as a copy only when it differs from the item's last one, so the
-- many QUEST_LOG_UPDATE bumps that change nothing leave no garbage and the same answer (and so the
-- same badge) stands.
local clientScratch = {}
local answerScratch = { reasons = {} }

local function sameAnswer(a, b)
    if a.verdict ~= b.verdict or a.score ~= b.score or a.confidence ~= b.confidence or a.tier ~= b.tier
        or a.hint ~= b.hint or #a.reasons ~= #b.reasons then
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
    return { verdict = a.verdict, score = a.score, confidence = a.confidence, tier = a.tier, reasons = reasons,
        hint = a.hint }
end

local function stale(e)
    if e.gen ~= generation then return true end
    if e.retryAt and now() >= e.retryAt then return true end
    return e.gearSig ~= nil and gearSignature() ~= e.gearSig
end

--- The verdict on `itemID` for the tooltip's hover (IS.Verdict's answer), kept per item until the
--- memo empties (IVD.Bump), your gear moves (gear only), or, while its item info or gear verdict
--- was still loading, C.ITEM_SEARCH.VERDICT.RETRY seconds on. A kept answer is the same table, and
--- so is one worked out again to the same verdict, score, confidence, reasons and fix.
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
    "PLAYER_LEVEL_UP", "NEW_RECIPE_LEARNED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnItemSearchVerdictEvent", clients = { "forever" } }
end

function NS.addon.OnItemSearchVerdictEvent()
    IVD.Bump()
end
