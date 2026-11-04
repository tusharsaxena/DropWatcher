local _, NS = ...
-- modules/ItemLists.lua — the Always watch and Never watch item lists (issue #13, categories design
-- spec §5.3): `feed.whitelist` and `feed.blacklist`, each a flat `{ [itemID] = true }` set.
--
-- THE ONE WRITER. The settings panel's Item lists tab (settings/ListEditors.lua) and the CLI's
-- `/dw whitelist|blacklist add|remove|list` (settings/SlashVerbs.lua) both call Add and Remove here,
-- and nothing else writes either list. A write copies the stored set, changes the copy and hands the
-- whole value to NS.SchemaRuntime.Set at the list's own path: the value route of architecture-§5,
-- so `/dw get`, the resets and the debug line see it as any other row's write.
--
-- THE LISTS EXCLUDE EACH OTHER. An ID on one list is refused by the other (`onOther`), never moved:
-- the player takes it off the first list by hand (the owner's call, plan #13). The schema's
-- `validate` checks the shape alone, so a profile copied in with an overlap keeps both lists, and
-- FeedFilter lets the Never watch list win at read time.
--
-- ParseId, Contains, List and WhyText read and never write; Add and Remove write through the seam.

NS.ItemLists = NS.ItemLists or {}
local IL = NS.ItemLists
local L = NS.L

--- The lists by name: the path each is stored at, its name as the panel and the chat say it, and
--- the other list.
IL.LISTS = {
    whitelist = { path = "feed.whitelist", name = L["Always watch"], other = "blacklist" },
    blacklist = { path = "feed.blacklist", name = L["Never watch"], other = "whitelist" },
}

local function positiveId(n)
    if type(n) ~= "number" or n ~= n or n < 1 or n ~= math.floor(n) or n >= 2 ^ 31 then return nil end
    return n
end

--- The itemID in `text`: a number, an item link, `item:<id>` or a number as text; nil otherwise.
--- Pure.
--- @param text any
--- @return number|nil
function IL.ParseId(text)
    if type(text) == "number" then return positiveId(text) end
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local id = NS.Item.ItemIDFromLink(text)
    if not id and text:match("^%d+$") then id = tonumber(text) end
    return positiveId(id)
end

-- The stored set of one list, as the seam answers it (read only: never written in place).
local function read(spec)
    local set = NS.Setting(spec.path)
    return type(set) == "table" and set or {}
end

--- Is `id` on `list`?
--- @param list string `whitelist` or `blacklist`
--- @param id any an itemID, or text ParseId reads
--- @return boolean
function IL.Contains(list, id)
    local spec, n = IL.LISTS[list], IL.ParseId(id)
    return spec ~= nil and n ~= nil and read(spec)[n] == true
end

--- The IDs on `list`, sorted; {} for an unknown list.
--- @param list string
--- @return table ids
function IL.List(list)
    local spec, out = IL.LISTS[list], {}
    if not spec then return out end
    for id, on in pairs(read(spec)) do
        if on == true and type(id) == "number" then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- The set with `id` set to `on` (true) or taken off (nil), as a copy written whole through the seam.
local function write(spec, id, on)
    local copy = {}
    for k, v in pairs(read(spec)) do copy[k] = v end
    copy[id] = on
    local ok = NS.SchemaRuntime.Set(spec.path, copy)
    return ok == true
end

--- Put `id` on `list`. Answers true, or false and why: `badList`, `badId`, `already`, `onOther`
--- (the ID is on the other list: refused, never moved) or `notStored` (the seam refused the write).
--- @param list string
--- @param id any
--- @return boolean ok, string|nil why
function IL.Add(list, id)
    local spec = IL.LISTS[list]
    if not spec then return false, "badList" end
    local n = IL.ParseId(id)
    if not n then return false, "badId" end
    if read(spec)[n] then return false, "already" end
    if read(IL.LISTS[spec.other])[n] then return false, "onOther" end
    if not write(spec, n, true) then return false, "notStored" end
    return true
end

--- Take `id` off `list`. Answers true, or false and why: `badList`, `badId`, `notListed` or
--- `notStored`.
--- @param list string
--- @param id any
--- @return boolean ok, string|nil why
function IL.Remove(list, id)
    local spec = IL.LISTS[list]
    if not spec then return false, "badList" end
    local n = IL.ParseId(id)
    if not n then return false, "badId" end
    if not read(spec)[n] then return false, "notListed" end
    if not write(spec, n, nil) then return false, "notStored" end
    return true
end

local WHY = {
    badId = L["That is not an item ID or an item link."],
    already = L["That item is already on %s."],
    onOther = L["That item is on %s: remove it there first."],
    notListed = L["That item is not on %s."],
    notStored = L["The list could not be saved."],
}

--- A refusal of Add or Remove on `list`, as the sentence the panel and the chat say.
--- @param list string
--- @param why string
--- @return string
function IL.WhyText(list, why)
    local spec = IL.LISTS[list] or IL.LISTS.whitelist
    if why == "onOther" then return WHY.onOther:format(IL.LISTS[spec.other].name) end
    local text = WHY[why] or WHY.badId
    return text:find("%s", 1, true) and text:format(spec.name) or text
end
