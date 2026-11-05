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
-- modules/MineCells.lua's Offer, modules/OfferPanel.lua); CC.NO_INSPECT is the Why row of the detail
-- card's disabled Retry inspect (modules/DetailCells.lua).
--
-- TIER TOKENS (DW-CAT4, categories design spec §6.1). A token is judged as gear, not collected, but
-- its Slot and Type cells are its own: CC.TokenSlot reads `Token: Head`, `Token: any slot` (an omni
-- Curio) or `Token` (the slot not read), and CC.TokenType lists its classes in their colors, or
-- `Any class` for a Curio. CC.TokenMakes is the slot word and the class list the detail card's
-- `Makes:` chip reads (modules/DetailCells.lua).
--
-- THE OTHER SURFACES (DW-CAT7, categories design spec §6.1). A collectible's Slot cell is its kind
-- (`Mount`, `Pet`, `Toy`, `Recipe`, `Cosmetic`: CC.SlotOf, the one hook NS.WindowCells.Slot calls,
-- a token's included) and its Type cell a recipe's profession, else a dash (CC.TypeOf, the hook in
-- NS.WindowCells.ArmorType). The detail card's chips and rows: CC.Chip (`NEW TO COLLECTION`,
-- `COLLECTED`, `COLLECTION UNKNOWN`; a dash for the side judged for you alone), CC.CountChip (a
-- pet's `Collected 2/3`) and CC.DetailRows (Kind, Collection, a recipe's Profession), which the
-- History card takes from the stored verdict too. CC.KindRows are the item tooltip's Kind row and
-- its collection row (modules/RowTooltip.lua's AddKindRows); gear has none, its kind is the game's.
--
-- PURE: plain tables in, plain tables out; the rows are NS.TipMarks', taken at load. A class's name
-- is the client's (NS.Compat.ClassDisplayName), and NS.ClassData, NS.Collectibles (the verdict of
-- the facts, for CC.KindRows) and NS.WindowCells (the slot words) are read at call time.

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
CC.NO_INSPECT = L["collectibles are judged for you alone, not inspected"]

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
    if not colored and f.tokenSlot ~= "any" then   -- a History entry keeps no classes
        return { text = DASH, tone = "muted", known = false, tip = { title, TM.Row(L["Usable by"], L["not read"]) } }
    end
    if not colored then
        return { text = L["Any class"], tone = "plain", known = true, tip = { title, TM.Row(L["Usable by"], L["every class"]) } }
    end
    return { text = colored, tone = "plain", known = true, tip = { title, TM.Row(L["Usable by"], plain) } }
end

-- ── the Slot, Type and Kind of a collectible, the detail card (DW-CAT7) ─────────────────────

-- Each category's word: the Slot cell of a collectible, the Kind row.
local KIND = {
    equipment = L["Equipment"], tierToken = L["Tier token"], mount = L["Mount"], pet = L["Pet"], toy = L["Toy"],
    recipe = L["Recipe"], cosmetic = L["Cosmetic"],
}

--- A category's word (`Mount`, `Tier token`), or nil for a key that is none (the Insights tab's
--- Category dropdown and Slot breakdown read it too).
--- @param category string|nil
--- @return string|nil
function CC.KindLabel(category) return KIND[category] end

local COLLECTIBLE = { mount = true, pet = true, toy = true, recipe = true, cosmetic = true }
-- The profession a recipe is for, by its skill line (C.RECIPE_SKILL_LINE's values).
local PROFESSION = {
    [164] = L["Blacksmithing"], [165] = L["Leatherworking"], [171] = L["Alchemy"], [185] = L["Cooking"],
    [197] = L["Tailoring"], [202] = L["Engineering"], [333] = L["Enchanting"], [356] = L["Fishing"],
    [755] = L["Jewelcrafting"], [773] = L["Inscription"],
}
-- The detail card's verdict chip per collection verdict (the Me side's).
local CHIP = {
    newCollect = L["NEW TO COLLECTION"], collected = L["COLLECTED"], collectUnknown = L["COLLECTION UNKNOWN"],
    cantUse = L["CAN'T USE"], unknown = L["UNKNOWN"],
}

--- A category's word (`Mount`, `Tier token`), or nil for none.
--- @param category string|nil
--- @return string|nil
function CC.KindWord(category) return KIND[category] end

-- A collectible's facts: its category is one with a collection verdict.
local function collectible(f) return COLLECTIBLE[f.category] == true end

-- A recipe's profession in words and whether it is yours (true, false, or nil when not read).
local function professionOf(f)
    local collect = type(f.collect) == "table" and f.collect or {}
    local skillLine = collect.skillLine or NS.Constants.RECIPE_SKILL_LINE[f.subClassID]
    return PROFESSION[skillLine], collect.hasProfession
end

--- The Slot column of a token or a collectible (NS.WindowCells.Slot's hook): `Token: Head`, or the
--- collectible's kind (`Mount`); nil for gear, whose slot is its own.
--- @param f table the drop's facts
--- @return table|nil cell { text, tone, tip }
function CC.SlotOf(f)
    if f.isTierToken then return CC.TokenSlot(f) end
    if not collectible(f) then return nil end
    local word = KIND[f.category]
    local worn = f.category == "cosmetic" and NS.WindowCells.SlotLabel(f.equipLoc) or nil
    local tip = { word, TM.Row(L["Compared with"], L["your collection, not your gear"]) }
    tip[3] = TM.Row(L["Worn in"], worn)   -- a cosmetic's slot; nil leaves no row
    return { text = word, tone = "plain", tip = tip }
end

--- The Type column of a token or a collectible (NS.WindowCells.ArmorType's hook): a token's classes,
--- a recipe's profession, else a dash (a collectible has no armor or weapon type); nil for gear.
--- @param f table the drop's facts
--- @return table|nil cell { text, tone, tip, known }
function CC.TypeOf(f)
    if f.isTierToken then return CC.TokenType(f) end
    if not collectible(f) then return nil end
    local title = L["Type: %s"]:format(KIND[f.category])
    local word, yours = professionOf(f)
    if f.category == "recipe" and word then
        local mine = yours == true and L["yes"] or yours == false and L["no"] or nil
        return { text = word, tone = yours == false and "redMuted" or "plain", known = true,
            tip = { title, TM.Row(L["Profession"], word), TM.Row(L["Yours"], mine) } }
    end
    local why = f.category == "recipe" and L["no profession named, or not read"] or L["a collectible: no armor or weapon type"]
    return { text = DASH, tone = "muted", known = false, tip = { title, TM.Row(L["Item"], why) } }
end

--- The detail card's verdict chip of a collection cell: the Me side's words (`NEW TO COLLECTION`),
--- a dash for a side judged for you alone (CC.Them, CC.Nobody).
--- @param cell table CC.Verdict's, CC.Them's or CC.Nobody's
--- @return table chip { text, tone, tip }
function CC.Chip(cell)
    local text = cell.side == "me" and (CHIP[cell.verdict] or CHIP.unknown) or DASH
    return { text = text, tone = cell.tone, tip = cell.tip }
end

--- A pet's `Collected 2/3` chip, or nil (no count read, or not a pet).
--- @param f table the drop's facts
--- @return table|nil chip { text, tone, tip }
function CC.CountChip(f)
    local collect = type(f.collect) == "table" and f.collect or {}
    local count, limit = num(collect.count), num(collect.limit)
    if f.category ~= "pet" or not (count and limit) then return nil end
    local text = L["Collected %d/%d"]:format(count, limit)
    return { text = text, tone = count > 0 and "bad" or "good", tip = { L["Collection"], TM.Row(L["You have"], text) } }
end

--- The detail card's rows of a collection verdict (a live drop's or History's stored one), in
--- NS.DetailCells' row shape: Kind, Collection and, for a recipe, its Profession.
--- @param eval table the collection verdict (`collect` set)
--- @param f table the drop's facts (a History entry's carry no profession)
--- @return table rows
function CC.DetailRows(eval, f)
    local kind = KIND[eval.category or f.category] or L["Watched item"]
    local v = eval.verdict
    local means = MEANS[v] or MEANS.unknown
    local rows = {
        { key = "kind", label = L["Kind"], text = kind, tone = "plain", tip = { L["Kind"], TM.Row(L["Item"], kind) } },
        { key = "collection", label = L["Collection"], text = CC.Text(eval), tone = CC.TONE[v] or "muted",
          tip = { L["Collection"], TM.Row(L["Means"], means) } },
    }
    local word, yours = professionOf(f)
    if (eval.category or f.category) == "recipe" and word then
        rows[3] = { key = "profession", label = L["Profession"], text = word, tone = yours == false and "redMuted" or "plain",
            tip = { L["Profession"], TM.Row(L["Yours"], yours == true and L["yes"] or yours == false and L["no"] or nil) } }
    end
    return rows
end

--- The item tooltip's rows (modules/RowTooltip.lua's AddKindRows): the Kind and, for a collectible,
--- its collection verdict now (NS.Collectibles.Verdict of the facts); a token's made slot. Gear
--- has none (the game's tooltip names its kind).
--- @param f table|nil the item's facts
--- @return table lines
function CC.KindRows(f)
    if type(f) ~= "table" or not (f.isTierToken or collectible(f)) then return {} end
    local lines = { TM.Row(L["Kind"], KIND[f.category] or L["Tier token"]) }
    if f.isTierToken then
        lines[2] = TM.Row(L["Makes"], (CC.TokenMakes(f)) or L["a slot that could not be read"])
        return lines
    end
    local eval = NS.Collectibles.Verdict(f)
    if eval then lines[2] = TM.Row(L["Collection"], CC.Text(eval), CC.TONE[eval.verdict]) end
    return lines
end
