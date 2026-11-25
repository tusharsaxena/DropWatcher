-- tests/mock_tooltip_data.lua — an opt-in test double of the client's TooltipDataProcessor (Item
-- Search's tooltip block, modules/ItemSearchTip.lua, and its key's read of the shown item). The kit
-- (tests/_kit/) models no tooltip data processor, so this addon keeps its own, outside the vendored
-- folder.
--
--   local TDP = dofile("tests/mock_tooltip_data.lua")
--   local NS, _, m = T.enableAddon{ mock = function(mm) tdp = TDP.install(mm) end }
--   local tip = tdp.tooltip("GameTooltip")       -- a stand-in item tooltip (or ShoppingTooltip1, ...)
--   tdp.show(tip, 990101)                        -- the client fills it with item 990101
--   tdp.texts(tip)                               -- its lines' texts, left and right joined by " | "
--
-- WHAT IS MODELED, after the client (Retail's TooltipDataProcessor, which WoW Forever carries):
--   * TooltipDataProcessor.AddTooltipPostCall(type, fn) keeps `fn` for the data type; there is no
--     removal. handle.postCalls[type] lists them in order; Enum.TooltipDataType.Item is 0 when the
--     mock has none.
--   * handle.show(tip, itemID, data) is one fill: the tooltip is cleared (its lines emptied and its
--     OnTooltipCleared script run, as ClearLines does), shown, its one client line written (the
--     item's name), then every Item post call runs with (tip, data); data defaults to
--     { type = Item, id = itemID }. handle.refresh(tip, itemID) is the same fill again (the client
--     refreshes a bag item's tooltip this way). handle.repost(tip, itemID) runs the post calls
--     again WITHOUT a clear (another addon processing the same data twice).
--   * handle.hide(tip) hides it, running OnHide.
--   * tip:GetItem() answers the shown item as the client does (name, link, id): the item of the
--     last handle.show, nil while hidden (the Item Search key's read, modules/ItemSearchKey.lua).
--   * A stand-in tooltip (handle.tooltip(name)) is a tracked mock frame with a name, AddLine and
--     AddDoubleLine recording `__lines` ({ text, right, r, g, b }), NumLines, ClearLines, Show and
--     Hide, and IsForbidden answering `forbidden`.
-- Nothing else of a tooltip is modeled: neither reader reads a line's text, so none is offered.

local TDP = {}

local ITEM = 0

local function decorate(M, tip, name)
    tip.__name = name
    tip.__lines = {}
    tip.forbidden = false
    tip.GetName = function(self) return self.__name end
    tip.IsForbidden = function(self) return self.forbidden == true end
    tip.AddLine = function(self, text, r, g, b)
        self.__lines[#self.__lines + 1] = { text = text, r = r, g = g, b = b }
    end
    tip.AddDoubleLine = function(self, left, right, r, g, b)
        self.__lines[#self.__lines + 1] = { text = left, right = right, r = r, g = g, b = b }
    end
    tip.NumLines = function(self) return #self.__lines end
    tip.GetItem = function(self)
        if not (self.__shown and self.__item) then return nil end
        return "Item " .. self.__item, nil, self.__item
    end
    tip.ClearLines = function(self)
        self.__lines = {}
        self:__fire("OnTooltipCleared")
    end
    tip.HasScript = function() return true end
    tip.shows = 0
    tip.Show = function(self)
        self.__shown, self.shows = true, self.shows + 1
        return self
    end
    tip.Hide = function(self)
        if self.__shown then
            self.__shown = false
            self:__fire("OnHide")
        end
        return self
    end
    if name then M[name] = tip end
    return tip
end

--- Install the double on a finished mock; answers the handle (see the header).
--- @param M table the mock
--- @return table
function TDP.install(M)
    M.Enum = M.Enum or {}
    M.Enum.TooltipDataType = M.Enum.TooltipDataType or { Item = ITEM }
    local itemType = M.Enum.TooltipDataType.Item
    local h = { postCalls = {} }
    M.TooltipDataProcessor = {
        AddTooltipPostCall = function(kind, fn)
            h.postCalls[kind] = h.postCalls[kind] or {}
            local list = h.postCalls[kind]
            list[#list + 1] = fn
        end,
    }

    function h.tooltip(name)
        return decorate(M, M.__stubFrame(), name)
    end

    local function post(tip, itemID, data)
        data = data or { type = itemType, id = itemID }
        for _, fn in ipairs(h.postCalls[itemType] or {}) do fn(tip, data) end
    end

    function h.show(tip, itemID, data)
        tip.__item = itemID
        tip:ClearLines()
        tip:Show()
        tip:AddLine("Item " .. tostring(itemID))
        post(tip, itemID, data)
    end
    h.refresh = h.show

    function h.repost(tip, itemID, data)
        post(tip, itemID, data)
    end

    function h.hide(tip)
        tip:Hide()
    end

    function h.texts(tip)
        local out = {}
        for i, line in ipairs(tip.__lines) do
            out[i] = line.right and (tostring(line.text) .. " | " .. tostring(line.right)) or tostring(line.text)
        end
        return out
    end

    function h.count()
        return #(h.postCalls[itemType] or {})
    end

    return h
end

return TDP
