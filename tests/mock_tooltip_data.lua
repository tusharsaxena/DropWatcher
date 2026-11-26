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
--   * ITS GEOMETRY, for the block's separator (Item Search round 3 spec §4.2): GetTop answers
--     `__top` (500; nil before layout), and line n's left font string is the client's global
--     `<name>TextLeft<n>` (and `<name>TextRight<n>`, R5-DW-10), made on the line's first write, its GetTop / GetBottom
--     `__top - PAD - (n - 1) * LINE_H` and that less FONT_H (nil while `__top` is). The client keeps
--     a tooltip's font strings across a clear, and so does the double. OnSizeChanged is fired by
--     handle.resize(tip). CreateTexture answers a recording Texture of the tooltip's own (its
--     texture, alpha, vertex color, points, height and shown state;
--     handle.textures(tip) lists them), where the base mock answers the frame itself; and
--     CreateFontString a recording FontString (text, color, points, shown state, and a stand-in
--     GetStringWidth: TDP.FONT_W a visible character, TDP.ICON_W a texture escape).
-- Nothing else of a tooltip is modeled: neither reader reads a line's text, so none is offered.

local TDP = {}

local ITEM = 0

TDP.TOP, TDP.PAD, TDP.LINE_H, TDP.FONT_H = 500, 10, 14, 12

-- A recording Texture: what it was told, and nothing else.
local function newTexture(owner, layer)
    local t = { __owner = owner, __layer = layer, __shown = true, __points = {} }
    function t:SetTexture(path) self.__texture = path end
    function t:SetAlpha(a) self.__alpha = a end
    function t:GetAlpha() return self.__alpha or 1 end
    function t:SetVertexColor(r, g, b, a) self.__vertex = { r, g, b, a or 1 } end
    function t:SetPoint(...) self.__points[#self.__points + 1] = { ... } end
    function t:ClearAllPoints() self.__points = {} end
    function t:GetNumPoints() return #self.__points end
    function t:GetPoint(i) return unpack(self.__points[i or 1] or {}) end
    function t:SetHeight(h) self.__h = h end
    function t:GetHeight() return self.__h or 0 end
    function t:SetWidth(w) self.__w = w end
    function t:GetWidth() return self.__w or 0 end
    function t:SetSize(w, h) self.__w, self.__h = w, h end
    function t:SetTexCoord(...) self.__coords = { ... } end
    function t:SetSnapToPixelGrid(v) self.__snap = not not v end
    function t:SetTexelSnappingBias(v) self.__bias = v end
    function t:Show() self.__shown = true end
    function t:Hide() self.__shown = false end
    function t:IsShown() return self.__shown end
    return t
end

-- A recording FontString of the tooltip's own (the badge's word and score, R4-DW-07): its text,
-- color, points and shown state. GetStringWidth answers FONT_W a visible character plus ICON_W a
-- texture escape (color codes are not drawn), a stand-in for the client's measure.
TDP.FONT_W, TDP.ICON_W = 7, 14

local function stringWidth(text)
    local icons = 0
    text = tostring(text or ""):gsub("|T.-|t", function() icons = icons + 1; return "" end)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #text * TDP.FONT_W + icons * TDP.ICON_W
end

local function newFontString(owner, layer, template)
    local fs = { __owner = owner, __layer = layer, __template = template, __shown = true, __points = {} }
    function fs:SetText(v) self.__text = v end
    function fs:GetText() return self.__text end
    function fs:GetStringWidth() return stringWidth(self.__text) end
    function fs:SetTextColor(r, g, b, a) self.__color = { r, g, b, a or 1 } end
    function fs:SetFontObject(o) self.__font = o end
    function fs:SetJustifyH(v) self.__justify = v end
    function fs:SetWidth(w) self.__w = w end
    function fs:GetWidth() return self.__w or 0 end
    function fs:SetWordWrap(v) self.__wrap = v end
    function fs:SetFont(path, size, flags) self.__face = { path, size, flags } end
    function fs:GetFont() return unpack(self.__face or {}) end
    function fs:SetShadowOffset(x, y) self.__shadow = { x, y } end
    function fs:SetShadowColor(r, g, b, a) self.__shadowColor = { r, g, b, a } end
    function fs:SetPoint(...) self.__points[#self.__points + 1] = { ... } end
    function fs:ClearAllPoints() self.__points = {} end
    function fs:GetPoint(i) return unpack(self.__points[i or 1] or {}) end
    function fs:Show() self.__shown = true end
    function fs:Hide() self.__shown = false end
    function fs:IsShown() return self.__shown end
    return fs
end

-- Line n's left and right font strings, the client's globals for a named tooltip, made once.
local function lineString(M, tip, n)
    if not tip.__name then return end
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
        local key = tip.__name .. side .. n
        if not M[key] then
            local fs = {}
            function fs.GetTop() return tip.__top and (tip.__top - TDP.PAD - (n - 1) * TDP.LINE_H) or nil end
            function fs.GetBottom() return tip.__top and (tip.__top - TDP.PAD - (n - 1) * TDP.LINE_H - TDP.FONT_H) or nil end
            M[key] = fs
        end
    end
end

local function decorate(M, tip, name)
    tip.__name = name
    tip.__lines = {}
    tip.__textures = {}
    tip.__strings = {}
    tip.__top = TDP.TOP
    tip.forbidden = false
    tip.GetName = function(self) return self.__name end
    tip.GetTop = function(self) return self.__top end
    tip.IsForbidden = function(self) return self.forbidden == true end
    tip.CreateTexture = function(self, _, layer)
        local t = newTexture(self, layer)
        self.__textures[#self.__textures + 1] = t
        return t
    end
    tip.CreateFontString = function(self, _, layer, template)
        local f = newFontString(self, layer, template)
        self.__strings[#self.__strings + 1] = f
        return f
    end
    tip.AddLine = function(self, text, r, g, b)
        self.__lines[#self.__lines + 1] = { text = text, r = r, g = g, b = b }
        lineString(M, self, #self.__lines)
    end
    tip.AddDoubleLine = function(self, left, right, r, g, b)
        self.__lines[#self.__lines + 1] = { text = left, right = right, r = r, g = g, b = b }
        lineString(M, self, #self.__lines)
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

    function h.resize(tip)
        tip:__fire("OnSizeChanged")
    end

    function h.textures(tip)
        return tip.__textures
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
