local _, NS = ...
-- settings/SlashVerbs.lua — the handlers of the design spec's feature verbs (§12.3) that only the
-- slash surface reaches: `clear`, `history`, `insights`, `situation`, `offer <link>` and
-- `add <link> [player]`, plus the confirmation line `compact` and `full` print around the shared
-- layout handlers. The verbs another surface shares (`show`, `hide`, `toggle`, `test`, `scan`,
-- `compact`, `full`) call the host
-- handlers in core/DropWatcher.lua, so each surface runs the same function; so do `whitelist` and
-- `blacklist` (issue #13), whose writer NS.ItemLists the settings panel's Item lists tab shares.
-- settings/Slash.lua lists every verb in NS.COMMANDS; this file only answers them.
--
-- SplitLink is PURE (test_slash drives it). The handlers read the feed, the situation edge and the
-- bags through their owners, and print through NS.Print. The dispatcher refuses every verb here
-- while disabled, so no handler checks the switch again.

NS.SlashVerbs = NS.SlashVerbs or {}
local V = NS.SlashVerbs
local L = NS.L

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function usage(form)
    NS.Print(L["Usage: |cffFFFF00%s|r"]:format(NS.SLASH .. " " .. form))
end

--- Split a verb's argument into its leading item link and what follows (`/dw add <link> [player]`).
--- An item's name holds spaces, so the link runs to its closing `|h`, and the `|r` after it when
--- the link is colored. Pure.
--- @param rest string|nil
--- @return string|nil link the item link, or nil when the argument does not start with one
--- @return string tail the rest, trimmed (the whole argument when there is no link)
function V.SplitLink(rest)
    rest = trim(rest)
    local link, tail = rest:match("^(|c.-|H.-|h.-|h|r)(.*)$")
    if not link then link, tail = rest:match("^(|H.-|h.-|h)(.*)$") end
    if not (link and link:find("|Hitem:", 1, true)) then return nil, rest end
    return link, trim(tail)
end

-- ── clear ───────────────────────────────────────────────────────────────────────────────────

--- `/dw clear`: empty the live feed (this session's drops). The repaint closes an Offer panel
--- whose drop is gone; test mode's placeholders and the history are left alone.
function V.Clear()
    NS.LootFeed.Clear("live")
    if NS.Window then NS.Window.Refresh() end
    NS.Print(L["Cleared this session's drops."])
end

-- ── compact, full ───────────────────────────────────────────────────────────────────────────

-- The layout now, since the window may be closed and show nothing.
local function printLayout()
    NS.Print(NS.WindowCompact.Mode() == "compact" and L["Compact view."] or L["Full view."])
end

--- `/dw compact`: the shared toggle (NS.ToggleWindowMode, over the `window.mode` row), then the
--- layout now (compact spec §1).
function V.Compact()
    NS.ToggleWindowMode()
    printLayout()
end

--- `/dw full`: back to the full layout (NS.SetWindowMode), then the layout now.
function V.Full()
    NS.SetWindowMode("full")
    printLayout()
end

-- ── history, offer ──────────────────────────────────────────────────────────────────────────

--- Open the window, expanded, on one tab (`/dw history`, `/dw insights`; Drops for `/dw mine` and
--- `/dw offer`).
--- @param key string `group`, `history` or `insights`
--- @return boolean shown whether the window is on screen now
function V.OpenTab(key)
    local W = NS.Window
    NS.ShowWindow()
    if W.IsMinimized() then W.SetMinimized(false) end
    W.SelectTab(key)
    if W.IsShown() then return true end
    NS.Print(L["The window stays hidden: its Visibility setting does not allow it now."])
    return false
end

-- ── situation ───────────────────────────────────────────────────────────────────────────────

local function yesNo(v) return v and L["yes"] or L["no"] end

--- `/dw situation`'s lines (design spec §6.1): the situation, its settings and the classifier's
--- inputs, read live. The edge only reads, so this is safe in combat and while stood down.
--- @return table lines
function V.SituationLines()
    local Sit = NS.Situations
    local i = Sit.ReadInputs()
    local key = Sit.Classify(i)
    local s = Sit.Settings(key)
    return {
        L["Situation: %s (%s) · Track %s · Auto-open %s · Quality %s"]:format(
            NS.WindowFooter.SituationLabel(key), key, yesNo(s.track), yesNo(s.autoOpen),
            s.quality or L["global"]),
        L["Inputs: in instance %s · type %s · difficulty %s · keystone %s"]:format(
            yesNo(i.inInstance), tostring(i.instanceType), tostring(i.difficultyID or L["none"]),
            yesNo(i.isChallengeModeActive)),
        L["Inputs: delve %s · follower dungeon %s · group %s · raid %s · PvP %s"]:format(
            yesNo(i.isDelve), yesNo(i.isFollowerDungeon), yesNo(i.inGroup), yesNo(i.inRaid), yesNo(i.isPvP)),
    }
end

function V.Situation()
    for _, line in ipairs(V.SituationLines()) do NS.Print(line) end
end

-- ── add ─────────────────────────────────────────────────────────────────────────────────────

local REFUSAL = {
    notItem = L["that is not an item link"],
    stoodDown = L["the addon is stood down"],
    quality = L["below the minimum quality"],
}

local function refusalText(why) return REFUSAL[why] or L["the feed's filters (%s)"]:format(tostring(why)) end

-- What one Add answered, as the line to print.
local function addedLine(link, who, id, status)
    if status == "loading" then
        return L["Added %s for %s: its item data is loading, and the drop shows once it loads."]:format(link, who)
    end
    if status == "added" or status == "merged" then
        return L["Added %s for %s (drop %s)."]:format(link, who, tostring(id))
    end
    return L["Not added: %s."]:format(refusalText(status))
end

--- `/dw add <link> [player]`: inject a drop, for development and smoke testing. The looter is
--- you when no player is named; one outside the group is judged without an inspect (LF.Add).
--- @param rest string
--- @return number|nil id, string|nil status (as NS.LootFeed.Add)
function V.Add(rest)
    local link, player = V.SplitLink(rest)
    if not link then return usage("add <item link> [player]") end
    local looter = player ~= "" and player or nil
    local id, status = NS.LootFeed.Add(link, looter)
    NS.Print(addedLine(link, looter or L["you"], id, status))
    return id, status
end

-- ── offer ───────────────────────────────────────────────────────────────────────────────────

-- Your newest live drop of an item, or nil.
local function newestMine(itemID)
    local drops = NS.LootFeed.Drops("live")
    for i = #drops, 1, -1 do
        local d = drops[i]
        if d.isMine and d.itemID == itemID then return d end
    end
    return nil
end

-- The bag item's own link when the item is in your bags, or nil.
local function bagLink(itemID)
    local Compat = NS.Compat
    for _, bag in ipairs(NS.Constants.BAG_IDS) do
        for slot = 1, Compat.BagSlotCount(bag) do
            local link = Compat.BagItemLink(bag, slot)
            if link and NS.Item.ItemIDFromLink(link) == itemID then return link end
        end
    end
    return nil
end

-- Is the item feed-only by itself (a collectible, or an item of no kind on Always watch and not
-- on Never watch)? Asked before a bag item is adopted, so a refused offer adds no drop.
local function feedOnlyItem(itemID, link)
    local facts = NS.ItemFacts.Get(bagLink(itemID) or link)
    if type(facts) ~= "table" then return false end
    if NS.Collectibles.IsCollectible(facts) then return true end
    local IL = NS.ItemLists
    return facts.category == nil and IL.Contains("whitelist", itemID) and not IL.Contains("blacklist", itemID)
end

-- A bag item the feed never saw becomes one of your drops (a manual one), so the panel has a
-- drop to judge candidates for. Answers its record, or nil once the reason is printed.
local function adopt(itemID, link)
    local inBag = bagLink(itemID)
    if not inBag then
        NS.Print(L["%s is not in your bags."]:format(link))
        return nil
    end
    local id, status = NS.LootFeed.Add(inBag)
    if status == "loading" then
        NS.Print(L["%s is loading: run |cffFFFF00%s|r again in a moment."]:format(inBag, NS.SLASH .. " offer"))
        return nil
    end
    local drop = id and NS.LootFeed.Get(id)
    if not drop then NS.Print(L["Not added: %s."]:format(refusalText(status))) end
    return drop
end

--- `/dw offer <link>`: open the Offer panel for a bag item. Your drop of that item when the feed
--- holds one; otherwise the bag item is added as a drop of yours first. Refused, with the reason,
--- while no other player is in your group (DW-07, NS.WindowOwn.Alone), and for a collectible
--- (feed-only, issue #13): a bag item is judged from its own facts first, so a refused one is never
--- adopted into the feed.
--- @param rest string
--- @return boolean opened
function V.Offer(rest)
    local link = V.SplitLink(rest)
    local itemID = link and NS.Item.ItemIDFromLink(link)
    if not itemID then
        usage("offer <item link>")
        return false
    end
    if NS.WindowOwn.Alone() then
        NS.Print(L["Not offered: %s"]:format(L["There is no other player in your group."]))
        return false
    end
    local drop = newestMine(itemID)
    if not drop and not feedOnlyItem(itemID, link) then
        drop = adopt(itemID, link)
        if not drop then return false end
    end
    if not drop or NS.Collectibles.IsFeedOnly(drop) then
        NS.Print(L["Collectibles are watched, not offered."])
        return false
    end
    if not V.OpenTab("group") then return false end
    return NS.OfferPanel.Open(drop.id) ~= nil
end

-- ── whitelist, blacklist ────────────────────────────────────────────────────────────────────

-- An entry as `list` prints it: `12345 [Name]` once the item is cached, else `item 12345`.
local function entryLine(id)
    local info = NS.Compat.GetItemInfo("item:" .. id)
    if info and info.name then return ("%d [%s]"):format(id, info.name) end
    return L["item %d"]:format(id)
end

--- The lines `/dw whitelist list` (or `blacklist`) prints: the list's name and size, then one line
--- per entry in ID order, or `(none)`.
--- @param list string `whitelist` or `blacklist`
--- @return table lines
function V.ItemListLines(list)
    local IL = NS.ItemLists
    local ids = IL.List(list)
    local lines = { L["%s (%d)"]:format(IL.LISTS[list].name, #ids) }
    for _, id in ipairs(ids) do lines[#lines + 1] = "  " .. entryLine(id) end
    if #ids == 0 then lines[2] = "  " .. L["(none)"] end
    return lines
end

local LIST_ACTS = {
    add = { run = "Add", done = L["Added %s to %s."] },
    remove = { run = "Remove", done = L["Removed %s from %s."] },
}

--- `/dw whitelist|blacklist add <id|link>`, `remove <id|link>` and `list` (a bare verb lists too):
--- the Always watch and Never watch lists, written through their one writer (NS.ItemLists), which
--- the settings panel's Item lists tab shares. A refusal says why; an open settings page redraws.
--- @param list string `whitelist` or `blacklist`
--- @param rest string
--- @return boolean|nil ok nil when it only listed or printed the usage
function V.ItemList(list, rest)
    local sub, arg = trim(rest):match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    if sub == "" or sub == "list" then
        for _, line in ipairs(V.ItemListLines(list)) do NS.Print(line) end
        return nil
    end
    local act, IL = LIST_ACTS[sub], NS.ItemLists
    if not act then return usage(list .. " add|remove|list <item id or link>") end
    local ok, why = IL[act.run](list, arg)
    if not ok then
        NS.Print(IL.WhyText(list, why))
        return false
    end
    NS.Print(act.done:format(entryLine(IL.ParseId(arg)), IL.LISTS[list].name))
    local H = NS.addon.Settings and NS.addon.Settings.Helpers
    if H and H.RefreshAllPanels then H.RefreshAllPanels() end
    return true
end
