-- tests/wow_mock.lua
--
-- This addon's THIN EXTENDER over the shared kit's mock_base (testing-§1). The base owns everything
-- universal: LibStub with a real NewLibrary, the Ace fakes, AceDB's merge-in-place defaults, the
-- AceGUI recorder, the Settings registrars, the timer queue, the event dispatch and the recorders.
-- This file adds what Ka0s Drop Watcher reads that the base deliberately leaves out, as settable
-- fields on the mock so a suite seeds the client's answers before driving the addon.
--
-- Returns a BUILDER: each call is a fresh, isolated environment. `M._G = M`, so the table a suite
-- reads as `mock` and the table the addon's chunks read as `_G` are the same object.
--
-- Mock fields:
--   inCombat       InCombatLockdown()'s answer, and UnitAffectingCombat("player")'s
--   loadedAddons   the names C_AddOns.IsAddOnLoaded answers true for (this addon's own folder is in)
--   prints         every line handed to the Lua global `print` (the printer's sink)
--   popupsShown    every StaticPopup_Show(which, ...) call, in order
--   popupsHidden   every StaticPopup_Hide(which) call's `which`, in order
--   ldbObjects     LibDataBroker objects by name; minimapButtons LibDBIcon registrations by name
--   fireEvent      fireEvent(name, ...) dispatches a game event to AceEvent handlers
--   instance       GetInstanceInfo's name, difficultyID and instanceID (its eighth answer); the
--                  instance type and inInstance are the base's __context.instanceType /
--                  __context.inInstance (IsInInstance reads them)
--   challengeModeActive  C_ChallengeMode.IsChallengeModeActive()'s answer; challengeMaps[mapID] is
--                  the keystone dungeon's name C_ChallengeMode.GetMapUIInfo answers
--   lootHistory    C_LootHistory.GetSortedInfoForDrop's answers, keyed "encounterID:lootListID"
--                  ({ itemHyperlink, winner = { playerName, playerGUID, playerClass, isSelf } })
--   unknownDifficulties  ids GetDifficultyInfo answers nil for (a retired or renumbered difficulty);
--                  difficultyNames[id] is the name it answers for the rest (`Difficulty <id>` unlisted)
--   keystoneLevel  C_ChallengeMode.GetActiveKeystoneInfo()'s level (0: no active key);
--                  completionLevel is GetChallengeCompletionInfo().level (nil answers 0)
--   tooltips       C_TooltipInfo's answers: .bag["bag:slot"], .inventory["unit:slot"], .hyperlink[link]
--   chatSent       every C_ChatInfo.SendChatMessage call; chatLockdown is InChatMessagingLockdown()
--   instanceGroup  IsInGroup(LE_PARTY_CATEGORY_INSTANCE)'s answer (an instance group); IsInGroup()
--                  with no category stays the base's __context.inGroup
--   restrictionStates  C_RestrictedActions' state per Enum.AddOnRestrictionType value (absent = 0)
--   upgradeInfo, accountBound, accountBoundUE  C_Item's answers per link; bagGUIDs["bag:slot"]
--   items          the item cache C_Item reads: items[link] = { name, quality, ilvl, effectiveIlvl,
--                  equipLoc, classID, subClassID, bindType, setID, stats, specs, unique, transmog,
--                  loadsNeeded }; addItem(link, def) seeds one. While loadsNeeded > 0 the item is
--                  uncached (GetItemInfo answers nil) and each RequestLoadItemDataByID of its id
--                  counts it down on the next timer pass; loadRequests records those ids in order
--   tradeCalls     InitiateTrade calls, in order, as { name, unit };
--                  tradeFar[unit] = true makes CheckInteractDistance(unit, 2) false (trade range)
--   inventory      GetInventoryItemLink's answers: inventory[unit][slot] = link
--   bags           C_Container's bags: bags[bag] = { size = n, [slot] = link }; an absent bag has 0 slots
--   specID         GetSpecializationInfo's first return (the base's 250 by default)
--   units          the group's unit tokens: units[token] = { guid, name, realm, class, classFile,
--                  connected }; "player" is read from the base's __context unless set. setGroup()
--                  seeds a party or a raid. normalizedRealm is GetNormalizedRealmName()'s answer
--   inspect        the inspect surface (modules/Inspect.lua): inspect.notified lists every
--                  NotifyInspect(unit) call as { unit, at }; inspect.cleared counts ClearInspectPlayer;
--                  inspect.cannot[unit] = true makes CanInspect false; inspect.far[unit] = true makes
--                  CheckInteractDistance false; inspect.specs[unit] is GetInspectSpecialization's
--                  answer (0 when unset); inventoryIDs[unit][slot] is GetInventoryItemID's answer
--                  where no link is worn (an incomplete read); InspectFrame is nil until a case sets
--                  one. hooksecurefunc(name, fn) and hooksecurefunc(table, name, fn) really hook
--   C_Timer.NewTicker  a repeating ticker on the same queue and clock (modules/TradeTimer.lua)
--   advance        advance(seconds): the mocked clock. Moves GetTime() forward (and time(), which follows it
--                  in whole seconds from the load's epoch unless a case sets `time`) and runs every
--                  queued timer that falls due on the way, in due order, each at its own due time,
--                  through the kit's own __fireTimers (so a taken-back entry is skipped by its rule)
--                  (C_Timer entries are stamped with their due time when queued; AceTimer's carry
--                  `ends`); entries queued while it runs are honored too. __fireTimers still runs a
--                  whole pass regardless of the clock
--   itemIcons      C_Item.GetItemIconByID's answer per id or link (134400 when unset);
--                  RAID_CLASS_COLORS a few classes' colors; shift / ctrl are IsShiftKeyDown /
--                  IsControlKeyDown; chatLinks and dressUps record ChatEdit_InsertLink and
--                  DressUpItemLink; tooltipLinks every GameTooltip:SetHyperlink (the drop tables);
--                  tooltipSets every GameTooltip setter as "link:<link>", "bag:<bag>:<slot>" or
--                  "inventory:<unit>:<slot>" (the real game tooltip, in order);
--                  GameTooltip's SetOwner is recorded as `__owner` / `__anchor`, and its
--                  ClearAllPoints / SetPoint / GetPoint as on a window frame (where it is placed);
--                  its lines too: SetText starts `__lines` over with the title, AddLine appends
--                  { text, wrap }, NumLines counts them (a grid's reserved rows among them,
--                  modules/TipGrid.lua), and SetMinimumWidth / GetMinimumWidth keep `__minWidth`;
--                  bagItemReads["bag:slot"] = { ilvl, quality } is C_Item.GetCurrentItemLevel's and
--                  C_Item.GetItemQuality's answer on that bag slot's ItemLocation;
--                  specNames[specID] is GetSpecializationInfoByID's name (the detail card)
--   textCharWidth  opt-in measured text: a window font string's GetUnboundedStringWidth is its
--                  length times this, and GetStringWidth that bounded by `__boundWidth` (its
--                  anchored width, set by a case) or SetWidth's; nil (the default) answers nil
--   SOUNDKIT, sounds  the alert sound's SOUNDKIT entries; sounds records every PlaySound(id, channel)
--   tradeItems     the open trade window: tradeItems.player[i] / tradeItems.target[i] are
--                  GetTradePlayerItemLink(i) / GetTradeTargetItemLink(i); units.NPC is the partner;
--                  LE_GAME_ERR_TRADE_COMPLETE / ERR_TRADE_COMPLETE the completion message
--   journal        the Encounter Journal (core/Compat.lua's Journal* shims, modules/SimPool.lua):
--                  journal.tiers[i] = { dungeons = { { id, name } }, raids = { ... } };
--                  journal.loot[instanceID][difficulty] = { { itemID, link, encounterID, classes,
--                  loadsNeeded } } (classes = { [classID] = true } limits it under a class filter;
--                  while loadsNeeded > 0 the entry has no link); the selection is journal.tier,
--                  .instanceID, .encounterID, .difficulty, .classID, .specID, .slot; journal.selects
--                  counts EJ_SelectInstance calls and journal.reads every GetLootInfoByIndex.
--                  EncounterJournal (the frame) is nil until a case sets one; loadJournal() loads
--                  every entry and fires EJ_LOOT_DATA_RECIEVED once per entry it loaded;
--                  seedGearJournal() adds a newest tier whose one dungeon drops gear for every slot
--   Enum           the members core/Compat.lua resolves by name; the enUS GlobalStrings it parses
--                  and the LOOT_ITEM* lines modules/LootParser.lua reads (overwrite one to model a
--                  locale or a chat addon rewriting it)

local base = dofile("tests/_kit/mock_base.lua")

local WINDOW_NAME = "DropWatcherWindow"
local TOAST_NAME = "DropWatcherToast"
local SIM_PANEL_NAME = "DropWatcherSimPanel"

-- The main window and every frame built inside it, recorded (modules/Window.lua and the tabs it
-- hosts): the kit's frame answers every unmodeled getter with the frame itself, so "the window went
-- back to where it started" or "the badge reads `Encounter · 2 queued`" could not fail without this.
-- A frame is decorated when it is the window, the toast or the simulation panel, or when its parent
-- is decorated (`__dwTree`), so the whole tree is, and nothing outside it changes.

-- Text, color, font, texture, vertex color and check state, recorded on any widget or region of
-- the tree (a font string never given a font answers the game's default face at 10 points).
local function decorateText(f)
    f.SetText = function(self, t) self.__text = t; return self end
    f.GetText = function(self) return self.__text end
    f.SetFormattedText = function(self, fmt, ...) self.__text = fmt:format(...); return self end
    f.SetTextColor = function(self, r, g, b, a) self.__textColor = { r, g, b, a }; return self end
    f.GetTextColor = function(self)
        local c = self.__textColor or { 1, 1, 1, 1 }
        return c[1], c[2], c[3], c[4]
    end
    f.SetTexture = function(self, tex) self.__texture = tex; return self end
    f.GetTexture = function(self) return self.__texture end
    -- A texture's vertex color (a chevron's tint, feedback-5 spec §0); unset answers white.
    f.SetVertexColor = function(self, r, g, b, a) self.__vertex = { r, g, b, a or 1 }; return self end
    f.GetVertexColor = function(self)
        local c = self.__vertex or { 1, 1, 1, 1 }
        return c[1], c[2], c[3], c[4]
    end
    f.SetFont = function(self, file, size, flags) self.__font = { file, size, flags }; return self end
    f.GetFont = function(self)
        local font = self.__font or { "Fonts\\FRIZQT__.TTF", 10, "" }
        return font[1], font[2], font[3]
    end
    f.SetChecked = function(self, v) self.__checked = not not v; return self end
    f.GetChecked = function(self) return self.__checked == true end
    return f
end

-- Measured text on a font string, opt-in: with M.textCharWidth set, its one-line width is its text's
-- length times that, an inline texture escape counting two (GetUnboundedStringWidth), and GetStringWidth is that bounded by the width its
-- anchors give it (`__boundWidth`, which a case sets, else SetWidth's), as on Retail since 10.0.
-- Unset, both answer nil, as a font not yet loaded does.
local function measureText(M, r)
    r.GetUnboundedStringWidth = function(s)
        local cw = M.textCharWidth
        return cw and #((s.__text or ""):gsub("|T.-|t", "##")) * cw or nil
    end
    r.GetStringWidth = function(s)
        local w = s:GetUnboundedStringWidth()
        local bound = s.__boundWidth or s.__width
        if w and bound and bound > 0 then return math.min(w, bound) end
        return w
    end
end

local function decorateGeometry(M, f)
    f.__dwTree = true
    -- Regions are objects of their own here: the base answers CreateFontString with the frame
    -- itself, so hiding the banner would hide the window.
    f.__regions = {}
    local function region(kind)
        return function(self, _, layer, template)
            local r = M.__stubFrame()
            r.__objType = kind
            -- The draw layer and the font template it was made with (a case reads `__template`).
            r.__layer, r.__template = layer, template
            self.__regions[#self.__regions + 1] = r
            decorateText(r)
            if kind == "FontString" then measureText(M, r) end
            r.__points = {}
            r.SetPoint = function(s, ...) s.__points[#s.__points + 1] = { ... }; return s end
            r.ClearAllPoints = function(s) s.__points = {}; return s end
            return r
        end
    end
    f.CreateFontString = region("FontString")
    f.CreateTexture = region("Texture")
    f.__points = {}
    f.SetPoint = function(self, point, rel, relPoint, x, y)
        self.__points[#self.__points + 1] = { point, rel, relPoint, x, y }
        return self
    end
    f.ClearAllPoints = function(self) self.__points = {}; return self end
    f.GetPoint = function(self, i)
        local pt = self.__points[i or 1]
        if pt then return pt[1], pt[2], pt[3], pt[4], pt[5] end
    end
    -- The parent CreateFrame was given (the kit records it as `__parent`), and a reparent: the item
    -- tooltip walks up to the window it goes beside (modules/RowTooltip.lua, Place).
    f.GetParent = function(self) return self.__parent end
    f.SetParent = function(self, p) self.__parent = p; return self end
    f.SetSize = function(self, w, h) self.__width, self.__height = w, h; return self end
    f.SetWidth = function(self, w) self.__width = w; return self end
    f.SetHeight = function(self, h) self.__height = h; return self end
    f.GetWidth = function(self) return self.__width or 0 end
    f.GetHeight = function(self) return self.__height or 0 end
    f.SetScale = function(self, s) self.__scale = s; return self end
    f.GetScale = function(self) return self.__scale or 1 end
    f.SetAlpha = function(self, a) self.__alpha = a; return self end
    f.GetAlpha = function(self) return self.__alpha or 1 end
    -- The pointer: a case sets `__mouseOver` on a frame (the toast's hover pause).
    f.IsMouseOver = function(self) return self.__mouseOver == true end
    -- The flat skin (BackdropTemplate), an edit box's font and insets, and a check button's tick:
    -- recorded, so a case can compare a control's look with Ka0s Loot History's.
    f.SetBackdrop = function(self, b) self.__backdrop = b; return self end
    f.SetBackdropColor = function(self, ...) self.__backdropColor = { ... }; return self end
    f.SetBackdropBorderColor = function(self, ...) self.__backdropBorder = { ... }; return self end
    f.SetFontObject = function(self, font) self.__fontObject = font; return self end
    f.SetTextInsets = function(self, ...) self.__textInsets = { ... }; return self end
    f.SetCheckedTexture = function(self, tex) self.__checkedTexture = tex; return self end
    f.GetCheckedTexture = function(self) return self.__checkedTexture end
    f.SetHitRectInsets = function(self, ...) self.__hitInsets = { ... }; return self end
    decorateText(f)
    return f
end

-- The enUS GlobalStrings core/Compat.lua builds its patterns from. A case that models another
-- client language overwrites them on the mock after the load (Compat reads them at call time).
local GLOBAL_STRINGS = {
    BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to "
        .. "loot this item for the next %s.",
    INT_SPELL_DURATION_HOURS = "%d |4hour:hrs;",
    INT_SPELL_DURATION_MIN = "%d min",
    INT_SPELL_DURATION_SEC = "%d sec",
    TIME_UNIT_DELIMITER = " ",
    ITEM_LEVEL = "Item Level %d",
    ITEM_UPGRADE_TOOLTIP_FORMAT_STRING = "Upgrade Level: %s %d/%d",
    ITEM_CLASSES_ALLOWED = "Classes: %s",
    LIST_DELIMITER = ", ",
    -- The primary stat lines of an item's tooltip (`%c` is the sign).
    ITEM_MOD_STRENGTH = "%c%s Strength",
    ITEM_MOD_AGILITY = "%c%s Agility",
    ITEM_MOD_INTELLECT = "%c%s Intellect",
    -- The loot lines modules/LootParser.lua reads, and the echoes it rejects.
    LOOT_ITEM = "%s receives loot: %s.",
    LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d.",
    LOOT_ITEM_SELF = "You receive loot: %s.",
    LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
    LOOT_ITEM_BONUS_ROLL = "%s receives bonus loot: %s.",
    LOOT_ITEM_BONUS_ROLL_MULTIPLE = "%s receives bonus loot: %sx%d.",
    LOOT_ITEM_BONUS_ROLL_SELF = "You receive bonus loot: %s.",
    LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE = "You receive bonus loot: %sx%d.",
    LOOT_ITEM_PUSHED = "%s receives item: %s.",
    LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d.",
    LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.",
    CHANGED_OWN_ITEM = "Changed %s to %s.",
    LOOT_ITEM_CREATED_SELF = "You create: %s.",
    LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d.",
    CREATED_ITEM = "%s creates: %s.",
    CREATED_ITEM_MULTIPLE = "%s creates: %sx%d.",
}

-- The client's classFile -> localized class name maps, enUS (both genders spell the same here).
local CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock",
    MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}

-- The item cache behind C_Item's readers and the transmog collection (modules/ItemFacts.lua).
-- Each reader answers only for a cached item (loadsNeeded 0 or nil); GetItemInfo's seventeen
-- returns are the client's order.
local function cachedItem(M, link)
    local d = M.items[link]
    if not d or (d.loadsNeeded or 0) > 0 then return nil end
    return d
end

local function installItemCache(M)
    M.items, M.loadRequests = {}, {}
    local item = M.C_Item
    function M.addItem(link, def)
        def.itemID = tonumber(link:match("item:(%d+)"))
        M.items[link] = def
        return link
    end
    item.GetItemInfo = function(link)
        local d = cachedItem(M, link)
        if not d then return nil end
        return d.name, link, d.quality, d.ilvl, 1, "", "", 1, d.equipLoc or "", 0, 0, d.classID,
            d.subClassID, d.bindType or 0, 0, d.setID, false
    end
    -- Needs no cache, as in the client: any added item answers its id, equip slot and classes.
    item.GetItemInfoInstant = function(link)
        local d = M.items[link]
        if not d then return nil end
        return d.itemID, "", "", d.equipLoc or "", 0, d.classID, d.subClassID
    end
    item.GetDetailedItemLevelInfo = function(link)
        local d = cachedItem(M, link)
        if d then return d.effectiveIlvl or d.ilvl, false, d.ilvl end
    end
    item.GetItemStats = function(link)
        local d = cachedItem(M, link)
        return d and d.stats
    end
    item.GetItemSpecInfo = function(link)
        local d = cachedItem(M, link)
        return d and d.specs
    end
    -- unique = { isUnique, categoryName, categoryCount, categoryID }
    item.GetItemUniquenessByID = function(link)
        local d = cachedItem(M, link)
        if d and d.unique then return d.unique[1], d.unique[2], d.unique[3], d.unique[4] end
        return false
    end
    -- The data arrives later, as in the client: on the next timer pass, ahead of LoadItem's callback.
    item.RequestLoadItemDataByID = function(id)
        M.loadRequests[#M.loadRequests + 1] = id
        M.C_Timer.After(0, function()
            for _, d in pairs(M.items) do
                if d.itemID == id and (d.loadsNeeded or 0) > 0 then d.loadsNeeded = d.loadsNeeded - 1 end
            end
        end)
    end
    M.C_TransmogCollection = {
        PlayerHasTransmogByItemInfo = function(link)
            local d = cachedItem(M, link)
            if d then return d.transmog == true end
            return false
        end,
    }
    M.LOCALIZED_CLASS_NAMES_MALE, M.LOCALIZED_CLASS_NAMES_FEMALE = {}, {}
    for classFile, name in pairs(CLASS_NAMES) do
        M.LOCALIZED_CLASS_NAMES_MALE[classFile] = name
        M.LOCALIZED_CLASS_NAMES_FEMALE[classFile] = name
    end
end

-- What core/Compat.lua reaches, as controllable fakes. Enum values are this mock's own numbers;
-- the addon resolves every member by NAME, so a case that deletes a member models a client that
-- renamed it.
local function installCompatSurface(M)
    for k, v in pairs(GLOBAL_STRINGS) do M[k] = v end

    M.Enum = {
        TooltipDataLineType = { ItemBinding = 20, RestrictedRaceClass = 21, ItemUpgradeLevel = 32,
            TradeTimeRemaining = 36, ItemLevel = 41 },
        AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4,
            Chat = 5 },
        AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
    }

    -- C_TooltipInfo: the data a getter answers, keyed "bag:slot", "unit:slot" and by link.
    M.tooltips = { bag = {}, inventory = {}, hyperlink = {} }
    M.C_TooltipInfo = {
        GetBagItem = function(bag, slot) return M.tooltips.bag[bag .. ":" .. slot] end,
        GetInventoryItem = function(unit, slot) return M.tooltips.inventory[unit .. ":" .. slot] end,
        GetHyperlink = function(link) return M.tooltips.hyperlink[link] end,
    }

    -- C_ChatInfo: every SendChatMessage call is recorded in M.chatSent; chatLockdown is
    -- InChatMessagingLockdown's answer.
    M.chatSent, M.chatLockdown = {}, false
    M.C_ChatInfo = {
        SendChatMessage = function(text, chatType, languageID, target)
            M.chatSent[#M.chatSent + 1] = { text = text, chatType = chatType, languageID = languageID,
                target = target }
        end,
        InChatMessagingLockdown = function() return M.chatLockdown end,
    }

    -- C_RestrictedActions: restrictionStates[type] is the state; absent means Inactive.
    M.restrictionStates = {}
    M.C_RestrictedActions = {
        GetAddOnRestrictionState = function(rtype) return M.restrictionStates[rtype] or 0 end,
        IsAddOnRestrictionActive = function(rtype) return (M.restrictionStates[rtype] or 0) ~= 0 end,
    }

    -- C_Item: upgradeInfo[link], accountBound[link], accountBoundUE[link], bagGUIDs["bag:slot"].
    M.upgradeInfo, M.accountBound, M.accountBoundUE, M.bagGUIDs = {}, {}, {}, {}
    M.C_Item = {
        GetItemUpgradeInfo = function(link) return M.upgradeInfo[link] end,
        IsItemBindToAccount = function(link) return M.accountBound[link] == true end,
        IsItemBindToAccountUntilEquip = function(link) return M.accountBoundUE[link] == true end,
        DoesItemExist = function(loc) return M.bagGUIDs[loc.bag .. ":" .. loc.slot] ~= nil end,
        GetItemGUID = function(loc) return M.bagGUIDs[loc.bag .. ":" .. loc.slot] end,
        -- The exact reads at a location (core/CompatItem.lua): bagItemReads["bag:slot"] = { ilvl, quality }.
        GetCurrentItemLevel = function(loc)
            local r = M.bagItemReads[loc.bag .. ":" .. loc.slot]
            return r and r.ilvl
        end,
        GetItemQuality = function(loc)
            local r = M.bagItemReads[loc.bag .. ":" .. loc.slot]
            return r and r.quality
        end,
    }
    M.bagItemReads = {}
    M.ItemLocation = {
        CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end,
    }
    installItemCache(M)

    -- The trade action, recorded in order as { name, ... }.
    M.tradeCalls = {}
    local function recorder(name)
        return function(...) M.tradeCalls[#M.tradeCalls + 1] = { name, ... } end
    end
    M.C_Container = {}

    -- What the player wears and carries (modules/Gear.lua), and the spec the client answers.
    M.inventory, M.bags = { player = {} }, {}
    M.GetInventoryItemLink = function(unit, slot)
        local worn = M.inventory[unit]
        return worn and worn[slot]
    end
    M.C_Container.GetContainerNumSlots = function(bag)
        local b = M.bags[bag]
        return b and b.size or 0
    end
    M.C_Container.GetContainerItemLink = function(bag, slot)
        local b = M.bags[bag]
        return b and b[slot]
    end
    M.specID = 250
    M.GetSpecializationInfo = function() return M.specID, M.__context.spec end
    M.InitiateTrade = recorder("InitiateTrade")
end

-- The group's units (modules/Roster.lua). The player's row is the base's __context, read live, so
-- the perf context and the roster agree; any other token answers only when units[token] is set.
local PLAYER_GUID = "Player-1-00000001"

local function installUnits(M)
    M.units = {}
    M.normalizedRealm = "Testrealm"
    local function row(unit)
        local r = M.units[unit]
        if r or unit ~= "player" then return r end
        local c = M.__context
        return { guid = PLAYER_GUID, name = c.name, class = c.class, classFile = c.classToken,
            connected = true }
    end
    local baseExists = M.UnitExists
    M.UnitExists = function(unit) return row(unit) ~= nil or baseExists(unit) end
    M.UnitGUID = function(unit)
        local r = row(unit)
        return r and r.guid
    end
    M.UnitName = function(unit)
        local r = row(unit)
        if r then return r.name, r.realm end
    end
    M.UnitClass = function(unit)
        local r = row(unit)
        if r then return r.class, r.classFile end
    end
    M.UnitIsConnected = function(unit)
        local r = row(unit)
        return r ~= nil and r.connected ~= false
    end
    M.GetNormalizedRealmName = function() return M.normalizedRealm end
    M.UNKNOWNOBJECT = "Unknown"

    --- Seed a group: `others` are the rows besides the player, in unit order. A party gives the
    --- player "player" and the others party1..; a raid gives raid1 to the player, then the others.
    function M.setGroup(others, raid)
        M.units = {}
        local first = 1
        if raid then
            M.units.raid1 = row("player")
            first = 2
        end
        for i, r in ipairs(others) do
            local token = raid and ("raid" .. (i + first - 1)) or ("party" .. i)
            M.units[token] = r
        end
        M.__context.inGroup = #others > 0
        M.__context.inRaid = raid and true or false
        M.__context.groupSize = #others > 0 and #others + 1 or 0
    end

    -- IsInGroup(category): LE_PARTY_CATEGORY_INSTANCE answers instanceGroup (an instance group,
    -- the announce channel's INSTANCE_CHAT); any other category, or none, is the base's answer.
    M.LE_PARTY_CATEGORY_HOME, M.LE_PARTY_CATEGORY_INSTANCE = 1, 2
    M.instanceGroup = false
    local inGroup = M.IsInGroup
    M.IsInGroup = function(category)
        if category == M.LE_PARTY_CATEGORY_INSTANCE then return M.instanceGroup == true end
        return inGroup(category)
    end
end

-- The inspect surface (modules/Inspect.lua): every call recorded, every answer settable.
local function installInspect(M)
    M.inspect = { notified = {}, cleared = 0, cannot = {}, far = {}, specs = {} }
    M.inventoryIDs = {}
    M.NotifyInspect = function(unit)
        M.inspect.notified[#M.inspect.notified + 1] = { unit = unit, at = M.GetTime() }
    end
    M.ClearInspectPlayer = function() M.inspect.cleared = M.inspect.cleared + 1 end
    M.CanInspect = function(unit) return M.UnitExists(unit) and not M.inspect.cannot[unit] end
    -- Index 1 is the inspect range, index 2 the (shorter) trade range: far for inspect is far for both.
    M.tradeFar = {}
    M.CheckInteractDistance = function(unit, index)
        if index == 2 and M.tradeFar[unit] then return false end
        return not M.inspect.far[unit]
    end
    M.GetInspectSpecialization = function(unit) return M.inspect.specs[unit] or 0 end
    M.GetInventoryItemID = function(unit, slot)
        local link = M.GetInventoryItemLink(unit, slot)
        if link then return tonumber(link:match("item:(%d+)")) end
        local ids = M.inventoryIDs[unit]
        return ids and ids[slot]
    end
    -- A real hook: the original runs first, then the hook, with the same arguments.
    M.hooksecurefunc = function(a, b, c)
        local tbl, name, fn = M, a, b
        if type(a) == "table" then tbl, name, fn = a, b, c end
        local orig = tbl[name]
        if type(orig) ~= "function" then return end
        tbl[name] = function(...)
            orig(...)
            fn(...)
        end
    end
end

-- The mocked clock. C_Timer's two fakes are wrapped IN PLACE (a library that took the table at load
-- still reaches the wrappers) so each queue entry carries its due time.
local function dueOf(t)
    if t.due then return t.due end
    if t.timer and t.timer.ends then return t.timer.ends end
    return 0
end

local function earliestDue(M, limit)
    local best, at
    for i, t in ipairs(M.__timers) do
        local due = dueOf(t)
        if due <= limit + 1e-9 and (not best or due < at) then best, at = i, due end
    end
    return best, at
end

local function installClock(M)
    local after, newTimer = M.C_Timer.After, M.C_Timer.NewTimer
    M.C_Timer.After = function(delay, fn)
        after(delay, fn)
        M.__timers[#M.__timers].due = M.__now + (delay or 0)
    end
    M.C_Timer.NewTimer = function(delay, fn)
        local t = newTimer(delay, fn)
        t.due = M.__now + (delay or 0)
        return t
    end
    -- A repeating ticker: the handle is its own queue entry, queued again after each run (with the
    -- handle as the callback's argument, as the client passes it) until canceled or its
    -- `iterations` are spent. Cancel takes it off the queue, so M.__timers() stops counting it
    -- live; `ticker` marks it, `stopped` records the cancel.
    M.C_Timer.NewTicker = function(period, fn, iterations)
        local h = { delay = period, remaining = iterations, ticker = true, stopped = false }
        h.Cancel = function()
            h.stopped = true
            for i = #M.__timers, 1, -1 do
                if M.__timers[i] == h then table.remove(M.__timers, i) end
            end
        end
        local function queue()
            h.due = M.__now + period
            M.__timers[#M.__timers + 1] = h
        end
        h.fn = function()
            if h.stopped then return end
            fn(h)
            if h.remaining then
                h.remaining = h.remaining - 1
                if h.remaining <= 0 then h.stopped = true end
            end
            if not h.stopped then queue() end
        end
        queue()
        return h
    end
    function M.advance(seconds)
        local target = M.__now + seconds
        while true do
            local i, due = earliestDue(M, target)
            if not i then break end
            local rest = M.__timers
            local t = table.remove(rest, i)
            if due > M.__now then M.__now = due end
            -- Run through the kit's own pass, so its rule for a taken-back entry is the one applied;
            -- whatever the entry queues lands back on the remaining queue.
            M.__timers = setmetatable({ t }, getmetatable(rest))
            M.__fireTimers()
            for _, queued in ipairs(M.__timers) do rest[#rest + 1] = queued end
            M.__timers = rest
        end
        M.__now = target
    end
    -- time() moves with GetTime(), as the client's two clocks do (whole seconds from the load's
    -- epoch): the Drops tab's This session turns the stored login (time()) into the client clock
    -- (modules/Session.lua's StartClock, feedback-15 spec §1), which a still epoch would read as a
    -- login that keeps moving forward. A case that sets `time` itself replaces it.
    local epoch0 = os.time()
    M.time = function() return epoch0 + math.floor(M.__now) end
end

-- The drop tables' client surface (modules/WindowGroup.lua through core/Compat.lua): item icons,
-- class colors, the modifier keys, the chat link, the dressing room and the item tooltip.
local function installTableSurface(M)
    M.itemIcons = {}
    M.C_Item.GetItemIconByID = function(item) return M.itemIcons[item] or 134400 end
    M.RAID_CLASS_COLORS = {
        PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
        ROGUE = { r = 1, g = 0.96, b = 0.41 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    }
    M.shift, M.ctrl = false, false
    M.IsShiftKeyDown = function() return M.shift == true end
    M.IsControlKeyDown = function() return M.ctrl == true end
    M.chatLinks, M.dressUps = {}, {}
    M.ChatEdit_InsertLink = function(link) M.chatLinks[#M.chatLinks + 1] = link; return true end
    M.DressUpItemLink = function(link) M.dressUps[#M.dressUps + 1] = link; return true end
    M.tooltipLinks, M.tooltipSets = {}, {}
    local tip = M.GameTooltip
    tip.__points = {}
    tip.SetOwner = function(self, owner, anchor)
        self.__owner, self.__anchor, self.__points, self.__lines = owner, anchor, {}, {}
        return self
    end
    tip.__lines = {}
    tip.SetText = function(self, text)
        self.__lines = { { text = text } }
        return self
    end
    tip.AddLine = function(self, text, _, _, _, wrap)
        self.__lines[#self.__lines + 1] = { text = text, wrap = wrap }
        return self
    end
    tip.NumLines = function(self) return #self.__lines end
    tip.SetMinimumWidth = function(self, w) self.__minWidth = w; return self end
    tip.GetMinimumWidth = function(self) return self.__minWidth or 0 end
    tip.ClearAllPoints = function(self) self.__points = {}; return self end
    tip.SetPoint = function(self, point, rel, relPoint, x, y)
        self.__points[#self.__points + 1] = { point, rel, relPoint, x, y }
        return self
    end
    tip.GetPoint = function(self, i)
        local pt = self.__points[i or 1]
        if pt then return pt[1], pt[2], pt[3], pt[4], pt[5] end
    end
    M.GameTooltip.SetHyperlink = function(self, link)
        M.tooltipLinks[#M.tooltipLinks + 1] = link
        M.tooltipSets[#M.tooltipSets + 1] = "link:" .. tostring(link)
        return self
    end
    M.GameTooltip.SetBagItem = function(self, bag, slot)
        M.tooltipSets[#M.tooltipSets + 1] = ("bag:%s:%s"):format(tostring(bag), tostring(slot))
        return self
    end
    M.GameTooltip.SetInventoryItem = function(self, unit, slot)
        M.tooltipSets[#M.tooltipSets + 1] = ("inventory:%s:%s"):format(tostring(unit), tostring(slot))
        return self
    end
    -- The detail card's looter spec: GetSpecializationInfoByID's id and name.
    M.specNames = { [256] = "Discipline", [257] = "Holy", [258] = "Shadow", [250] = "Blood", [577] = "Havoc" }
    M.GetSpecializationInfoByID = function(id)
        local name = M.specNames[id]
        if name then return id, name end
        return nil
    end
end

-- The trade window's contents (core/Compat.lua's TradeItemLinks, the history's trade completion):
-- tradeItems.player[i] and tradeItems.target[i] are GetTradePlayerItemLink(i) and
-- GetTradeTargetItemLink(i). The partner is units.NPC (UnitName("NPC")), seeded by the case.
-- UI_INFO_MESSAGE's "Trade complete." is LE_GAME_ERR_TRADE_COMPLETE (a made-up number: the real
-- one is the client's) with ERR_TRADE_COMPLETE's text.
local function installTrade(M)
    M.LE_GAME_ERR_TRADE_COMPLETE = 238
    M.ERR_TRADE_COMPLETE = "Trade complete."
    M.tradeItems = { player = {}, target = {} }
    M.GetTradePlayerItemLink = function(i) return M.tradeItems.player[i] end
    M.GetTradeTargetItemLink = function(i) return M.tradeItems.target[i] end
end

-- The toast's alert (core/Compat.lua's PlayAlertSound): SOUNDKIT's two entries it reads, and every
-- PlaySound(id, channel) call recorded in `sounds`.
local function installSound(M)
    M.SOUNDKIT = { UI_EPICLOOT_TOAST = 31578, RAID_WARNING = 8959 }
    M.sounds = {}
    M.PlaySound = function(id, channel) M.sounds[#M.sounds + 1] = { id, channel } end
end

-- The Encounter Journal (core/Compat.lua's Journal* shims): one newest tier with what a case seeds.
-- The selection behaves as the client's: selecting a tier clears the instance, an instance clears
-- the encounter.
local function journalEntries(M)
    local j = M.journal
    local out = {}
    local list = ((j.loot[j.instanceID or 0] or {})[j.difficulty or 0]) or {}
    for _, e in ipairs(list) do
        if (j.classID or 0) == 0 or not e.classes or e.classes[j.classID] then out[#out + 1] = e end
    end
    return out
end

local function installJournal(M)
    local j = { tiers = { { dungeons = {}, raids = {} } }, loot = {}, tier = 1, difficulty = 1, classID = 0,
        specID = 0, slot = 15, selects = 0, reads = 0 }
    M.journal = j
    M.EJ_GetNumTiers = function() return #j.tiers end
    M.EJ_GetCurrentTier = function() return j.tier end
    M.EJ_SelectTier = function(t) j.tier, j.instanceID, j.encounterID = t, nil, nil end
    M.EJ_GetInstanceByIndex = function(i, isRaid)
        local row = (j.tiers[j.tier] or {})[isRaid and "raids" or "dungeons"] or {}
        local inst = row[i]
        if inst then return inst.id, inst.name end
    end
    M.EJ_SelectInstance = function(id) j.instanceID, j.encounterID, j.selects = id, nil, j.selects + 1 end
    M.EJ_SelectEncounter = function(id) j.encounterID = id end
    M.EJ_GetDifficulty = function() return j.difficulty end
    M.EJ_SetDifficulty = function(d) j.difficulty = d end
    M.EJ_GetLootFilter = function() return j.classID, j.specID end
    M.EJ_SetLootFilter = function(c, sp) j.classID, j.specID = c, sp end
    M.EJ_GetNumLoot = function() return #journalEntries(M) end
    M.C_EncounterJournal = {
        GetSlotFilter = function() return j.slot end,
        SetSlotFilter = function(v) j.slot = v end,
        ResetSlotFilter = function() j.slot = 15 end,
        GetLootInfoByIndex = function(i)
            j.reads = j.reads + 1
            local e = journalEntries(M)[i]
            if not e then return nil end
            local loaded = (e.loadsNeeded or 0) <= 0
            return { itemID = e.itemID, encounterID = e.encounterID, link = loaded and e.link or nil,
                name = loaded and "Item" or nil }
        end,
    }
    function M.loadJournal()
        local loaded = {}
        for _, byDifficulty in pairs(j.loot) do
            for _, list in pairs(byDifficulty) do
                for _, e in ipairs(list) do
                    if (e.loadsNeeded or 0) > 0 then
                        e.loadsNeeded = 0
                        loaded[#loaded + 1] = e.itemID
                    end
                end
            end
        end
        for _, id in ipairs(loaded) do M.__fireEvent("EJ_LOOT_DATA_RECIEVED", id) end
    end
end

-- A journal with gear for every slot (test mode's sample drops, modules/TestMode.lua): one dungeon,
-- "Test Vault" (901), in the newest tier, dropping two items per equip location at Mythic Keystone
-- (level 300), Mythic (290) and Heroic (280), every one cached, loaded and with its own icon.
local GEAR_SLOTS = {
    { "INVTYPE_HEAD", "Helm" }, { "INVTYPE_NECK", "Choker" }, { "INVTYPE_SHOULDER", "Pauldrons" },
    { "INVTYPE_CLOAK", "Cloak" }, { "INVTYPE_CHEST", "Breastplate" }, { "INVTYPE_WRIST", "Bracers" },
    { "INVTYPE_HAND", "Gloves" }, { "INVTYPE_WAIST", "Belt" }, { "INVTYPE_LEGS", "Greaves" },
    { "INVTYPE_FEET", "Boots" }, { "INVTYPE_FINGER", "Ring" }, { "INVTYPE_TRINKET", "Idol" },
    { "INVTYPE_WEAPON", "Sword" },
}
local GEAR_LEVELS = { { 8, 300 }, { 23, 290 }, { 2, 280 } }

local function seedGearJournal(M)
    local j = M.journal
    j.tiers[#j.tiers + 1] = { dungeons = { { id = 901, name = "Test Vault" } }, raids = {} }
    j.loot[901] = {}
    for d, row in ipairs(GEAR_LEVELS) do
        local list = {}
        for i, slot in ipairs(GEAR_SLOTS) do
            for copy = 1, 2 do
                local id = 70000 + i * 100 + copy * 10 + d
                local name = ("Vault %s %d"):format(slot[2], copy)
                local link = ("|cnIQ4:|Hitem:%d::::::::90:::::%d|h[%s]|h|r"):format(id, row[2], name)
                local weapon = slot[1] == "INVTYPE_WEAPON"
                M.addItem(link, { name = name, quality = 4, ilvl = row[2], equipLoc = slot[1],
                    classID = weapon and 2 or 4, subClassID = weapon and 7 or 4, bindType = 1, stats = {} })
                M.itemIcons[id], M.itemIcons[link] = 5000000 + id, 5000000 + id
                list[#list + 1] = { itemID = id, link = link, encounterID = 3000 + i }
            end
        end
        j.loot[901][row[1]] = list
    end
end

local function build()
    local M = base()
    M._G = M

    M.inCombat     = false
    M.prints       = {}
    M.popupsShown  = {}
    M.popupsHidden = {}
    M.loadedAddons = { DropWatcher = true }

    M.InCombatLockdown    = function() return M.inCombat == true end
    M.UnitAffectingCombat = function() return M.inCombat == true end

    -- The client's addon list; the base leaves C_AddOns out on purpose (its own NOTE).
    M.C_AddOns = {
        IsAddOnLoaded = function(name)
            local on = M.loadedAddons[name] == true
            return on, on
        end,
        GetAddOnMetadata = function() return nil end,
    }

    -- The chat sink core/CoreSetup.lua hands the printer: captured, so a suite can read it back.
    M.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        M.prints[#M.prints + 1] = table.concat(parts, " ")
    end

    M.StaticPopup_Show = function(which, ...) M.popupsShown[#M.popupsShown + 1] = { which, ... } end
    M.StaticPopup_Hide = function(which) M.popupsHidden[#M.popupsHidden + 1] = which end

    -- Where the player is (modules/Situations.lua). Outside an instance the client answers type
    -- "none" and difficulty 0; GetDifficultyInfo answers a name for any positive id not retired.
    M.instance = { name = "Silvermoon City", difficultyID = 0 }
    M.challengeModeActive = false
    M.unknownDifficulties = {}
    M.GetInstanceInfo = function()
        return M.instance.name, M.__context.instanceType, M.instance.difficultyID, M.instance.difficultyName,
            nil, nil, nil, M.instance.instanceID
    end
    M.difficultyNames = { [1] = "Normal", [2] = "Heroic", [8] = "Mythic Keystone", [14] = "Normal",
        [15] = "Heroic", [16] = "Mythic", [17] = "Looking For Raid", [23] = "Mythic", [24] = "Timewalking",
        [33] = "Timewalking", [205] = "Follower", [208] = "Delves" }
    M.GetDifficultyInfo = function(id)
        if type(id) ~= "number" or id <= 0 or M.unknownDifficulties[id] then return nil end
        return M.difficultyNames[id] or ("Difficulty " .. id)
    end
    M.challengeMaps = {}
    M.keystoneLevel = 0
    M.completionLevel = nil
    M.C_ChallengeMode = {
        IsChallengeModeActive = function() return M.challengeModeActive == true end,
        GetMapUIInfo = function(mapID) return M.challengeMaps[mapID], mapID end,
        GetActiveKeystoneInfo = function() return M.keystoneLevel, {}, false end,
        GetChallengeCompletionInfo = function() return { level = M.completionLevel or 0 } end,
    }

    -- C_LootHistory: lootHistory["encounterID:lootListID"] is GetSortedInfoForDrop's answer.
    M.lootHistory = {}
    M.C_LootHistory = {
        GetSortedInfoForDrop = function(encounterID, lootListID)
            return M.lootHistory[encounterID .. ":" .. lootListID]
        end,
    }

    M.fireEvent = function(event, ...) return M.__fireEvent(event, ...) end

    installCompatSurface(M)
    installUnits(M)
    installInspect(M)
    installClock(M)
    installTableSurface(M)
    installTrade(M)
    installSound(M)
    installJournal(M)
    M.seedGearJournal = function() seedGearJournal(M) end

    local baseCreateFrame = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if name == WINDOW_NAME or name == TOAST_NAME or name == SIM_PANEL_NAME
            or (type(parent) == "table" and parent.__dwTree) then
            decorateGeometry(M, f)
        end
        return f
    end

    -- The launcher's two libraries (launcher-§1), present by default because both are vendored and
    -- TOC-listed. Their whole surface as LibKa0s-Launcher-1.0 uses it; a case that wants the
    -- degraded install clears one through the loader's `mock` option.
    M.ldbObjects = {}
    M.__libs["LibDataBroker-1.1"] = {
        NewDataObject = function(_, name, tbl)
            if M.ldbObjects[name] then return nil end
            M.ldbObjects[name] = tbl
            return tbl
        end,
        GetDataObjectByName = function(_, name) return M.ldbObjects[name] end,
    }
    M.minimapButtons = {}
    M.__libs["LibDBIcon-1.0"] = {
        Register = function(_, name, object, db)
            M.minimapButtons[name] = { object = object, db = db, shown = not (db and db.hide) }
        end,
        IsRegistered = function(_, name) return M.minimapButtons[name] ~= nil end,
        Show = function(_, name)
            local b = M.minimapButtons[name]
            if b then b.shown = true end
        end,
        Hide = function(_, name)
            local b = M.minimapButtons[name]
            if b then b.shown = false end
        end,
        GetMinimapButton = function(_, name) return M.minimapButtons[name] end,
    }

    return M
end

return build
