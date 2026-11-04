local _, NS = ...
-- modules/CollectCells.lua — how a collectible looks (issue #13, categories design spec §3.2, §6.1):
-- a mount, pet, toy, recipe or cosmetic is judged for your collection, not against your gear
-- (NS.Collectibles.Verdict), so its Me cell is a word, never a glyph and a difference:
--
--   Me cell  New   Collected   Collected 1/3   Known   New look   Look known   ?   Can't use
--
-- THE CELL (CC.Verdict) is what NS.WindowCells.Verdict answers for an evaluation carrying `collect`:
-- the word in its tone (TONE: new green, collected the gray `bad` tone `doesntWant` uses, unknown
-- muted, can't use, a recipe of a profession you lack, `redMuted`); a recipe's collected reads
-- Known and a cosmetic's New look or Look known; a pet with a count reads Collected 1/3. Its
-- tooltip is titled `For you: New to your collection`, then a Means row and a Why row per reason.
-- History's stored verdict (modules/History.lua's snapshot: `collect`, `category`, `count`,
-- `limit`, `reasonKey`) renders through the same cell.
--
-- THEM (CC.Them) on someone else's collectible is a dash: it is judged for you alone, so no inspect
-- is asked for and no `?` waits on one. Your own collectible's Them is CC.Nobody (no candidates).
--
-- THE REFUSALS' WORDS. A feed-only drop (NS.Collectibles.IsFeedOnly) has no action; CC.NO_ASK and
-- CC.NO_OFFER are the Why rows' values of its No action (modules/WindowCells.lua's Ask,
-- modules/MineCells.lua's Offer, modules/OfferPanel.lua).
--
-- TIER TOKENS (DW-CAT4, categories design spec §6.1). A token is judged as gear, not collected, but
-- its Slot and Type cells are its own: CC.TokenSlot reads `Token: Head`, `Token: any slot` (an omni
-- Curio) or `Token` (the slot not read), and CC.TokenType lists its classes in their colors, or
-- `Any class` for a Curio. CC.TokenMakes is the slot word and the class list the detail card's
-- `Makes:` chip reads (modules/DetailCells.lua).
--
-- PURE: plain tables in, plain tables out; the rows are NS.TipMarks', taken at load. A class's name
-- is the client's (NS.Compat.ClassDisplayName), and NS.ClassData and NS.WindowCells (the slot
-- words) are read at call time.

NS.CollectCells = NS.CollectCells or {}
local CC = NS.CollectCells
local L  = NS.L
local TM = NS.TipMarks

local DASH = "–"

CC.TONE = { newCollect = "good", collected = "bad", collectUnknown = "muted", cantUse = "redMuted", unknown = "muted" }

-- The cell's word per verdict, and the words a category says its own way.
local WORD = { newCollect = L["New"], collected = L["Collected"], collectUnknown = "?", cantUse = L["Can't use"], unknown = "?" }
local CATEGORY_WORD = {
    recipe = { collected = L["Known"] },
    cosmetic = { newCollect = L["New look"], collected = L["Look known"] },
}
-- The tooltip's title after `For you: `.
local TITLE = {
    newCollect = L["New to your collection"], collected = L["Already collected"],
    collectUnknown = L["Collection unknown"], cantUse = L["Can't use"], unknown = L["Unknown"],
}
-- The Means row under the title.
local MEANS = {
    newCollect = L["not in your collection yet"], collected = L["already in your collection"],
    collectUnknown = L["the game gave no collection answer yet"],
    cantUse = L["a recipe for a profession you don't have"], unknown = L["watched for you, never judged"],
}
-- NS.Collectibles' reason keys, in words: each a Why row's value.
local REASON = {
    collectNew = L["the game says you haven't collected it"],
    collectKnown = L["the game says you have it"],
    collectNoAnswer = L["no answer yet (read again when a collection changes or combat ends)"],
    notYourProfession = L["not one of your professions"],
    petPartial = L["you have %s"],
    whitelisted = L["on your Always watch list"],
}

CC.NO_ASK = L["collectibles are watched, not asked for"]
CC.NO_OFFER = L["collectibles are watched, not offered"]

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- The cell's word for a collection verdict: `New`, `Collected 1/3`, `Known`, `New look`, `?`.
--- @param eval table a collectible's evaluation (or History's stored one)
--- @return string
function CC.Text(eval)
    local v = eval.verdict
    local own = CATEGORY_WORD[eval.category]
    local word = own and own[v] or WORD[v] or "?"
    local count, limit = num(eval.count), num(eval.limit)
    if v == "collected" and count and limit then word = ("%s %d/%d"):format(word, count, limit) end
    return word
end

-- The reasons: the evaluation's list, else History's one stored key.
local function reasonsOf(eval)
    if type(eval.reasons) == "table" then return eval.reasons end
    if type(eval.reasonKey) == "string" then return { { key = eval.reasonKey } } end
    return {}
end

local function reasonRows(eval, lines)
    for _, r in ipairs(reasonsOf(eval)) do
        local word = REASON[r.key] or tostring(r.key)
        if r.key == "petPartial" then word = word:format(tostring(r.detail or "?")) end
        lines[#lines + 1] = TM.Row(L["Why"], word)
    end
end

--- One collection verdict cell (the Me column), in WindowCells.Verdict's shape: `collect` true.
--- @param eval table the evaluation (`collect` set)
--- @param side string `me` (a collectible has no Them verdict)
--- @param title string the tooltip's subject (`For you`)
--- @return table cell { text, tone, tip, verdict, collect, side }
function CC.Verdict(eval, side, title)
    local v = eval.verdict
    local lines = { ("%s: %s"):format(title, TITLE[v] or tostring(v)) }
    lines[#lines + 1] = TM.Row(L["Means"], MEANS[v] or MEANS.unknown)
    reasonRows(eval, lines)
    return { text = CC.Text(eval), tone = CC.TONE[v] or "muted", tip = lines, verdict = v, collect = true, side = side }
end

--- The Them cell on someone else's collectible: a dash, judged for you alone.
--- @return table cell
function CC.Them()
    return { text = DASH, tone = "muted", verdict = "unknown", collect = true,
        tip = { L["Them"], TM.Hint(L["Collectibles are judged for you alone."]) } }
end

--- Them on your own collectible (NS.MineCells.Details): a dash, nobody judged for it.
--- @param title string the tooltip's title
--- @return table cell
function CC.Nobody(title)
    return { text = DASH, tone = "muted", collect = true, tip = { title, TM.Hint(L["Collectible: nobody is judged for it."]) } }
end

-- ── tier tokens (DW-CAT4) ───────────────────────────────────────────────────────────────────

-- The token's classes in the client's class order, each in its color, and the plain names.
local function tokenClasses(f)
    if type(f.classes) ~= "table" then return nil end
    local ids, files = NS.ClassData.CLASS_ID, {}
    for classFile in pairs(f.classes) do
        if type(classFile) == "string" then files[#files + 1] = classFile end
    end
    if #files == 0 then return nil end
    table.sort(files, function(a, b) return (ids[a] or 99) < (ids[b] or 99) end)
    local colored, plain = {}, {}
    for i, classFile in ipairs(files) do
        plain[i] = NS.Compat.ClassDisplayName(classFile) or classFile
        colored[i] = TM.ClassName(plain[i], classFile)
    end
    return table.concat(colored, ", "), table.concat(plain, ", ")
end

--- What a tier token makes: the slot's word (`Head`, `any slot`, or nil when not read) and its
--- classes, colored (nil for a Curio, which names none).
--- @param f table the token's facts
--- @return string|nil slot, string|nil classes
function CC.TokenMakes(f)
    local slot = f.tokenSlot
    local word = slot == "any" and L["any slot"] or (slot and NS.WindowCells.SlotLabel(slot)) or nil
    return word, (tokenClasses(f))
end

--- The Slot column of a tier token: `Token: Head`, `Token: any slot`, or a muted `Token`.
--- @param f table the token's facts
--- @return table cell { text, tone, tip }
function CC.TokenSlot(f)
    local word = CC.TokenMakes(f)
    if not word then
        return { text = L["Token"], tone = "muted", tip = { L["Tier token"], TM.Row(L["Makes"], L["a slot that could not be read"]) } }
    end
    local text = L["Token: %s"]:format(word)
    local with = f.tokenSlot == "any" and L["the tier slot it helps most"] or L["what is worn there"]
    return { text = text, tone = "plain", tip = { text, TM.Row(L["Makes"], word), TM.Row(L["Compared with"], with) } }
end

--- The Type column of a tier token: its classes in their colors, or `Any class` for a Curio.
--- @param f table the token's facts
--- @return table cell { text, tone, tip, known = true }
function CC.TokenType(f)
    local colored, plain = tokenClasses(f)
    local title = L["Type: %s"]:format(L["Tier token"])
    if not colored then
        return { text = L["Any class"], tone = "plain", known = true, tip = { title, TM.Row(L["Usable by"], L["every class"]) } }
    end
    return { text = colored, tone = "plain", known = true, tip = { title, TM.Row(L["Usable by"], plain) } }
end
