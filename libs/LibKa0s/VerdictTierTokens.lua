-- LibKa0s-Verdict-1.0 -- tier tokens judged as gear, as `lib.TierTokens`: which item is a token,
-- the slot a token makes, and the best slot of an omni token (a Curio, which makes any tier piece).
-- Moved from Ka0s Drop Watcher's modules/TierTokens.lua and the tier token parts of its
-- core/TextParse.lua (DropWatcher#19).
--
-- PURE, like the kernel it serves: plain tables in, plain tables out, no WoW API, no saved
-- variable, no state but the word lists it builds once per vocabulary. A facts reader calls Listed,
-- Users (which asks IsCurio and UseNamesClass) and SlotOf while it builds the facts, and hands
-- SlotOf the tooltip's slot line as a reader; the kernel's run calls Fold at call time, inside its
-- own pcall.
--
-- THE WORDS. A token's Use text and its name are read against English words a host's enUS locale
-- table holds: the class phrase ("appropriate for your class"), the slot template ("set %s item")
-- and its slot words, the slot nouns of an older token's name ("Gauntlets of the Foreseen
-- Conqueror"), and the word an omni Curio's name ends with. The library carries no locale, so every
-- word-reading member takes the host's locale table `L` as its last argument, read by the keys in
-- TT.WORDS (Drop Watcher's locale keys, unchanged); with no `L` each key is its own word, which is
-- the enUS table's answer. On another locale none of these words match, so a token with a class
-- line is read by its localized tooltip slot line where it has one, else judged in its best tier
-- slot (`any`); a Curio, or a token with no class line and no English Use phrase, is not seen as a
-- token at all (a documented localization deviation in each host).
--
-- THE SLOT (SlotOf), first rung that answers wins, with the rung that answered as its source:
--   1. `table`: the curated override, C.TIER_TOKENS[itemID].slot: one of C.TIER_SLOTS, or "any";
--   2. `use`: the token's own text: its Use text's "set <slot> item", else a tooltip line that is
--      exactly a slot's localized name (the reader, asked only then);
--   3. `name`: a slot noun in the item's name, as a whole word (cloaks are not a tier slot here);
--   4. `any`: nothing read: the token is judged in its best tier slot (the fold).
-- The facts reader then sets the facts' equipLoc to a concrete slot, so every gear reader works
-- unchanged.
--
-- THE FOLD (Fold) runs the kernel once per tier slot, each on a shallow copy of the facts with that
-- slot, and keeps the best answer: upgrade beats sidegrade beats downgrade, then the larger
-- ilvlDelta (an empty slot the largest), then the earlier slot in C.TIER_SLOTS. The chosen slot is
-- the answer's `tokenSlot`. With no slot ranked, the first slot's answer stands, with no
-- `tokenSlot` (a class refusal reads the same in every slot). The facts table is never written.
--
-- Depends on the Verdict shell (Verdict.lua) and VerdictConstants.lua, loaded before it.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.C then return end

local TIERTOKENS_MINOR = 1
local ORDER = 30   -- its place in LibKa0s.xml (Verdict.lua, lib.__Stale)
-- Minor 1 (DropWatcher#19, task B1): Drop Watcher's tier tokens, the words read from the host's
-- locale table per call.
if lib.__tierTokensMinor and lib.__tierTokensMinor >= TIERTOKENS_MINOR
  and lib.__tierTokensShellMinor == lib.MINOR and not lib.__Stale(ORDER) then return end
lib.__tierTokensMinor      = TIERTOKENS_MINOR
lib.__tierTokensShellMinor = lib.MINOR
lib.__Ran(ORDER)

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictTierTokens = TIERTOKENS_MINOR

local TT = {}
lib.TierTokens = TT
local C = lib.C

-- ---------------------------------------------------------------------------------------------
-- The text parsers (Drop Watcher's core/TextParse.lua, its tier token part)
-- ---------------------------------------------------------------------------------------------

-- A word: letters, digits and any UTF-8 byte, so a localized vocabulary reads whole words too.
local WORD = "[%w\128-\255]"

--- `s` with every Lua pattern magic character escaped.
--- @param s string
--- @return string
function TT.EscapePattern(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

--- A word list per key, `{ [key] = "Helm Crown Hood" }`, as one lowercase lookup,
--- `{ ["helm"] = key, ... }`. The lists are the caller's (localized vocabularies).
--- @param lists table
--- @return table
function TT.WordMap(lists)
  local out = {}
  for key, list in pairs(lists) do
    for word in list:lower():gmatch(WORD .. "+") do out[word] = key end
  end
  return out
end

--- The key the first whole word of `text` that `words` (a WordMap) knows maps to, or nil;
--- case-insensitive.
--- @return any
function TT.FirstWord(text, words)
  for word in text:lower():gmatch(WORD .. "+") do
    if words[word] ~= nil then return words[word] end
  end
  return nil
end

--- True when `text`'s last whole word is `word` (case-insensitive; trailing spaces ignored).
--- @return boolean
function TT.EndsWithWord(text, word)
  if word == "" then return false end
  local pattern = "%f" .. WORD .. TT.EscapePattern(word:lower()) .. "%s*$"
  return text:lower():find(pattern) ~= nil
end

--- The slot a tier token's Use text names, or nil. The text must carry `vocab.phrase` ("appropriate
--- for your class") and `vocab.template` ("set %s item") as whole words, whose `%s` word
--- `vocab.slots` (a WordMap) knows. Case-insensitive; every word is the caller's.
--- @param text string
--- @param vocab table { phrase, template, slots }
--- @return any
function TT.TokenUseSlot(text, vocab)
  local lower = text:lower()
  if not lower:find(vocab.phrase:lower(), 1, true) then return nil end
  local head, tail = vocab.template:lower():match("^(.-)%%s(.*)$")
  if not head then return nil end
  local pattern = "%f" .. WORD .. TT.EscapePattern(head) .. "(" .. WORD .. "+)"
    .. TT.EscapePattern(tail) .. "%f[^%w\128-\255]"
  local word = lower:match(pattern)
  return word and vocab.slots[word] or nil
end

-- ---------------------------------------------------------------------------------------------
-- The tokens
-- ---------------------------------------------------------------------------------------------

-- The verdicts the fold ranks, best first.
local RANK = { upgrade = 3, sidegrade = 2, downgrade = 1 }

local TIER_SLOT = {}
for _, slot in ipairs(C.TIER_SLOTS) do TIER_SLOT[slot] = true end

-- A slot a token may name: a tier slot, or "any" where `allowAny`.
local function validSlot(slot, allowAny)
  if type(slot) ~= "string" then return nil end
  if TIER_SLOT[slot] or (allowAny and slot == "any") then return slot end
  return nil
end

--- True when the curated table lists the item as a tier token (C.TIER_TOKENS).
--- @param itemID number|nil
--- @return boolean
function TT.Listed(itemID)
  return itemID ~= nil and type(C.TIER_TOKENS[itemID]) == "table"
end

--- The locale keys the words are read by, the host's table indexed by each (see the header).
TT.WORDS = {
  phrase = "appropriate for your class", template = "set %s item",
  useSlots = {
    INVTYPE_HEAD = "head", INVTYPE_SHOULDER = "shoulder shoulders", INVTYPE_CHEST = "chest",
    INVTYPE_HAND = "hand hands", INVTYPE_LEGS = "leg legs",
  },
  names = {
    INVTYPE_HEAD = "Helm Crown Hood Headpiece Circlet Cowl Helmet Faceguard",
    INVTYPE_SHOULDER = "Shoulders Shoulderpads Mantle Pauldrons Spaulders Shoulderguards Amice",
    INVTYPE_CHEST = "Chest Chestguard Chestpiece Breastplate Robe Robes Vest Tunic Raiment Hauberk Jerkin",
    INVTYPE_HAND = "Gauntlets Gloves Handguards Grips Handwraps Grasps",
    INVTYPE_LEGS = "Leggings Legguards Legplates Pants Kilt Trousers Breeches Legwraps",
  },
  curio = "Curio",
}

-- With no locale table, each key is its own word (the enUS table's answer).
local ENUS = setmetatable({}, { __index = function(_, k) return k end })

-- The words of each locale table, built on its first read (see the header). Weak-keyed, so a
-- host's table that goes away takes its words with it.
local cache = setmetatable({}, { __mode = "k" })

-- A key the host's table does not hold reads as its own word, as AceLocale's default locale
-- answers it, so a partial table never leaves a word nil.
local function word(L, key) return L[key] or key end

local function wordsOf(L, keys)
  local out = {}
  for slot, key in pairs(keys) do out[slot] = word(L, key) end
  return out
end

local function vocab(L)
  L = type(L) == "table" and L or ENUS
  local words = cache[L]
  if words then return words end
  local K = TT.WORDS
  words = {
    use = { phrase = word(L, K.phrase), template = word(L, K.template), slots = TT.WordMap(wordsOf(L, K.useSlots)) },
    names = TT.WordMap(wordsOf(L, K.names)),
    curio = word(L, K.curio),
  }
  cache[L] = words
  return words
end

local function plain(text) return type(text) == "string" and text ~= "" and text or nil end

--- True when a Use text says it makes a piece for the user's class ("appropriate for your class").
--- @param useText string|nil
--- @param L table|nil the host's locale table (see the header)
--- @return boolean
function TT.UseNamesClass(useText, L)
  useText = plain(useText)
  return useText ~= nil and useText:lower():find(vocab(L).use.phrase:lower(), 1, true) ~= nil
end

--- The tier slot a Use text names ("set hand item"), or nil.
--- @param useText string|nil
--- @param L table|nil the host's locale table
--- @return string|nil
function TT.UseSlot(useText, L)
  useText = plain(useText)
  return useText and TT.TokenUseSlot(useText, vocab(L).use) or nil
end

--- The tier slot a slot noun in an item's name names ("Gauntlets" -> INVTYPE_HAND), or nil.
--- @param name string|nil
--- @param L table|nil the host's locale table
--- @return string|nil
function TT.NameSlot(name, L)
  name = plain(name)
  return name and TT.FirstWord(name, vocab(L).names) or nil
end

-- Miscellaneous subclasses a Curio is never: the collectibles'.
local NOT_CURIO = { [C.MISC_SUBCLASS.MOUNT] = true, [C.MISC_SUBCLASS.COMPANION_PET] = true,
  [C.MISC_SUBCLASS.MOUNT_EQUIPMENT] = true }

-- Whether `loc` is gear on either client: a Curio is not gear on the client it is read on, and the
-- two clients' plans differ only in ranged rows no Curio carries.
local function isGearLoc(loc)
  return C.SLOT_PLANS.retail[loc] ~= nil or C.SLOT_PLANS.forever[loc] ~= nil
end

--- True for an omni Curio: an epic-or-better (quality 4+) Miscellaneous or Reagent item that is not
--- gear (no slot plan for its raw slot) and whose name ends with the word "Curio".
--- @param facts table `quality`, `classID`, `subClassID`, `rawEquipLoc`, `name`
--- @param L table|nil the host's locale table
--- @return boolean
function TT.IsCurio(facts, L)
  local IC = C.ITEM_CLASS
  if type(facts) ~= "table" or type(facts.quality) ~= "number" or facts.quality < 4 then return false end
  local misc = facts.classID == IC.MISCELLANEOUS and not NOT_CURIO[facts.subClassID]
  if not (misc or facts.classID == IC.REAGENT) or isGearLoc(facts.rawEquipLoc or "") then return false end
  local name = plain(facts.name)
  return name ~= nil and TT.EndsWithWord(name, vocab(L).curio)
end

--- Who may use a tier token that names no classes (the facts' `tokenUsers`): "every" for an omni
--- Curio or a C.TIER_TOKENS row of slot "any", "yours" for a token whose Use text makes a piece for
--- your class, else nil (not read). Nil for facts that carry a class list: those name their own.
--- @param facts table `classes`, `itemID`, `useText` and IsCurio's fields
--- @param L table|nil the host's locale table
--- @return string|nil
function TT.Users(facts, L)
  if type(facts) ~= "table" or facts.classes ~= nil then return nil end
  local listed = facts.itemID ~= nil and C.TIER_TOKENS[facts.itemID]
  if TT.IsCurio(facts, L) or (type(listed) == "table" and listed.slot == "any") then return "every" end
  if TT.UseNamesClass(facts.useText, L) then return "yours" end
  return nil
end

--- The slot a tier token makes and the rung that read it (see the header): the table's (`table`),
--- the token's Use text, else its tooltip slot line (`use`; `readTooltip` is asked only then), its
--- name (`name`), else `any`, `any`. Nil only for no facts.
--- @param facts table the token's facts (`itemID`, `useText`, `name`)
--- @param readTooltip function|nil () -> "INVTYPE_*" | nil
--- @param L table|nil the host's locale table
--- @return string|nil slot, string|nil source
function TT.SlotOf(facts, readTooltip, L)
  if type(facts) ~= "table" then return nil end
  local listed = facts.itemID ~= nil and C.TIER_TOKENS[facts.itemID]
  local slot = type(listed) == "table" and validSlot(listed.slot, true)
  if slot then return slot, "table" end
  slot = TT.UseSlot(facts.useText, L) or (type(readTooltip) == "function" and validSlot(readTooltip(), false))
  if slot then return slot, "use" end
  slot = TT.NameSlot(facts.name, L)
  if slot then return slot, "name" end
  return "any", "any"
end

-- The difference used to break a tie: an empty slot is the largest.
local function gain(res)
  if res.baselineSlot and not res.baseline then return math.huge end
  return type(res.ilvlDelta) == "number" and res.ilvlDelta or -math.huge
end

local function better(res, best)
  local a, b = RANK[res.verdict], best and RANK[best.verdict]
  if not a then return false end
  if not b then return true end
  if a ~= b then return a > b end
  return gain(res) > gain(best)
end

local function copyAs(facts, slot)
  local f = {}
  for k, v in pairs(facts) do f[k] = v end
  f.equipLoc, f.tokenSlot = slot, slot
  return f
end

--- An omni token judged in its best tier slot (see the header): `run` is the kernel's own
--- evaluation, `run(facts, candidate, opts)`. Answers that slot's evaluation, `tokenSlot` set; with
--- no slot ranked, the first slot's evaluation as it is.
--- @return table
function TT.Fold(facts, candidate, opts, run)
  local best, bestSlot, first
  for _, slot in ipairs(C.TIER_SLOTS) do
    local res = run(copyAs(facts, slot), candidate, opts)
    first = first or res
    if better(res, best) then best, bestSlot = res, slot end
  end
  if not best then return first end
  best.tokenSlot = bestSlot
  return best
end
