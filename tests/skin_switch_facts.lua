-- tests/skin_switch_facts.lua — this addon's painted surfaces, for the kit's skin-switch suite
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). `reset` gives each surface a fresh
-- enabled instance, because a registered skin and a drawn window are per instance. Every surface
-- answers the objects that draw, so a failure names one thing and not the whole window.
--
-- A surface with a `companion` is on that row's skin half and leaves the second pass. `scope` marks
-- what Ignore settings panel or Ignore fonts keeps stock. `paint` is the redraw a mock has no
-- listener for: a table text is restyled by the next repaint, and an item's glow by the next pass.
--
-- From kit revision 58 (LibKa0s v1.108.0) each setter family a surface draws has to move on its own,
-- so a surface holds one part, or parts painted from one token: two parts from two tokens in one
-- surface would let one stop following while the other moved. `expect = "texture"` marks a data fill
-- drawn in the skin's bar texture. SD-SK-DW.1 of the skin-defaults audit (LibKa0s#97) declared the
-- surfaces the list left out (`addMissing`): the Rolls panel, a roll popup's side card, the History,
-- Rolling now and compact rows, the compact Filters button, the Edit message box, the trade window's
-- countdown bar and track, the Drops empty state, and the Drops and History scrollbars' corridor and
-- knob (the template's bar stubbed by `installScrollBar`). No surface holds a family: the flat countdown
-- bars (skinning-§9's Leave class "flat thin bars", A7) draw no bar texture, and the texture family is
-- asked of a plain Texture only under `expect`.

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"

-- THE LIBSHAREDMEDIA FAKE (kit revision 58, skinning-§9: "a host harness needs such a fake"). The
-- headless client has no LibSharedMedia, so without one every skin's face and bar texture resolve to
-- the same fallback and a string's SetFont never moves under the probe, which the per-family check
-- now reports. The fake answers every key with a path of its own ("Interface\AddOns\DWSwitch\
-- <kind>\<key>"), so each skin's `font.*`, `hud.font` and `bar.texture` draw a distinct path, the
-- probe skin's too. A key registered at load (modules/IconStyle.lua's Solid edge, LibKa0s-Media's
-- faces) answers its registered path, and only a registered key is valid, so registration and the
-- settings lists behave as with the real library. Installed through the kit mock's library seam
-- (`M.__libs`, by LibStub) before any source loads, on the switch suite's instances only.
local function installLsm(m)
    local LSM = m.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    local registered = {}
    LSM.MediaType = { BACKGROUND = "background", BORDER = "border", FONT = "font", STATUSBAR = "statusbar", SOUND = "sound" }
    LSM.Register = function(_, kind, key, path)
        registered[kind] = registered[kind] or {}
        registered[kind][key] = path
        return true
    end
    LSM.Fetch = function(_, kind, key)
        if type(key) ~= "string" or key == "" then return nil end
        local own = registered[kind] and registered[kind][key]
        return own or ("Interface\\AddOns\\DWSwitch\\" .. tostring(kind) .. "\\" .. key)
    end
    LSM.IsValid = function(_, kind, key) return registered[kind] ~= nil and registered[kind][key] ~= nil end
    LSM.HashTable = function(_, kind) return registered[kind] or {} end
    LSM.List = function(_, kind)
        local out = {}
        for key in pairs(registered[kind] or {}) do out[#out + 1] = key end
        table.sort(out)
        return out
    end
    function LSM.RegisterCallback() end
end

-- THE TEMPLATE'S SCROLL BAR. The headless UIPanelScrollFrameTemplate makes no children, so the
-- modules' `rawget(scroll, "ScrollBar")` finds none and S.ScrollBar never runs. Here a scroll frame
-- from that template gets the bar the client gives it, a Slider whose GetThumbTexture answers a
-- thumb region, so the skin lays its corridor (`scroll.track`) and knob (`scroll.thumb`) and the
-- panes' scrollbars can be declared (SD-SK-DW.1). Built in a decorated tree, both are real regions.
local function installScrollBar(m)
    local create = m.CreateFrame
    m.CreateFrame = function(frameType, name, parent, template)
        local f = create(frameType, name, parent, template)
        if frameType == "ScrollFrame" and template == "UIPanelScrollFrameTemplate" then
            local bar = create("Slider", nil, f)
            local thumb = bar:CreateTexture(nil, "ARTWORK")
            bar.GetThumbTexture = function() return thumb end
            rawset(f, "ScrollBar", bar)
        end
        return f
    end
end

--- The facts, for `enableAddon`, the runner's factory.
return function(enableAddon, withPlayer)
    local NS, m

    local function fresh()
        local env
        -- `__decorateUIParent`: a frame parented to UIParent (a roll popup's side card) answers real
        -- regions, as tests/test_roll_popup.lua builds it, so its strings and band can be declared.
        NS, env, m = enableAddon({ mock = function(mock)
            installLsm(mock)
            mock.__decorateUIParent = true
            installScrollBar(mock)
        end })
        return env
    end
    fresh()

    local function drop()
        return {
            id = 1, link = LINK, itemID = 212, isMine = false,
            looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
            facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} },
            them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
            trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
            inspect = { status = "fresh", at = 60 },
        }
    end

    --- The window on the Drops tab, one drop listed. Answers the frame and the row.
    local function listed(mode)
        local d = drop()
        m.__now = 100
        withPlayer(m)
        NS.LootFeed.Groups = function()
            return { { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { d.id } } }
        end
        NS.LootFeed.Get = function(id) return id == d.id and d or nil end
        NS.LootFeed.Drops = function() return { d } end
        NS.WindowFilterBar.Set("group", "view", "all")
        if mode then NS.SetWindowMode(mode) end
        NS.ShowWindow()
        return NS.Window.Frame(), NS.WindowGroup.Drawn().rows[1]
    end

    local function window()
        NS.ShowWindow()
        return NS.Window.Frame()
    end

    local function setting(path)
        return function(on) assert(NS.SchemaRuntime.Set(path, on), path) end
    end

    --- A string the tables drew and a stand-in that hears only `setters` of it, so the case reads
    --- that half of the look and not the string's color or the other half.
    local function tableHalf(...)
        local setters = { ... }
        return function()
            local _, row = listed()
            local fs, heard = row.cells.ilvl.text, {}
            for _, name in ipairs(setters) do
                local own = fs[name]
                heard[name] = function() end
                fs[name] = function(self, ...)
                    heard[name](heard, ...)
                    return own(self, ...)
                end
            end
            return heard
        end
    end

    local function redraw() NS.Window.Refresh() end

    --- The window on Insights over a one-drop history: an upgrade traded to you, so the cards, the
    --- bars and a strip all draw. Answers the tab's drawn pane.
    local function insights()
        local now = m.time()
        NS.History.Store().groups = { { key = "k", label = "Boss 3", kind = "encounter", instance = "Ruby Life Pools",
            situation = "raid", at = now - 60, drops = { { itemLink = LINK, itemID = 212, looter = "Seta-Testrealm",
            class = "PRIEST", outcome = "received", settledAt = now, at = now - 60, quality = 4,
            equipLoc = "INVTYPE_HEAD", me = { verdict = "upgrade", ilvlDelta = 9 }, trade = { state = "yes" } } } } }
        NS.ShowWindow()
        NS.Window.SelectTab("insights")
        return NS.WindowInsights.Drawn()
    end

    --- A button whose GlowLib start writes the color the glow was handed to an object a spy reads.
    local function glowOf(d)
        local out = { SetVertexColor = function() end }
        NS.GlowLib = { Start = function(_, _, cfg) out:SetVertexColor(unpack(cfg.color)); return true end,
                       Stop = function() end }
        local button = m.CreateFrame("Button")
        local paint = function() NS.Glow.Apply(button, d) end
        paint()
        return out, paint
    end

    local function glowDrop(offSpec)
        local d = { id = 1, isMine = false, trade = { state = "yes" }, me = { verdict = "upgrade" } }
        if offSpec then
            d.me = { verdict = "downgrade", offSpec = { verdict = "upgrade" } }
            NS.OffSpec.Of = function(me) return me.offSpec end
        end
        return d
    end

    local glowPaint, tipSpot

    --- Test mode on over the window, shown mid-screen on a 1920-wide screen: its sample roll fills the
    --- Rolls panel, Drops' Rolling now and a roll popup's side card (RX-19, RX-22), its History the
    --- History tab. Prints are quietened.
    local function testMode()
        m.seedGearJournal()
        NS.ShowWindow()
        local win = NS.Window.Frame()
        win.GetLeft = function() return 200 end
        win.GetRight = function() return 800 end
        win.GetHeight = function() return 400 end
        m.UIParent.GetWidth = function() return 1920 end
        local p0 = m.print
        m.print = function() end
        NS.SetTestMode(true)
        m.print = p0
        return win
    end

    --- One of yours on Drops with its trade window running and the Trade window column shown.
    local function tradeWindowRow()
        local d = drop()
        d.isMine = true
        d.looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true }
        d.trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = 100 + 600 }
        m.__now = 100
        withPlayer(m)
        NS.LootFeed.Groups = function()
            return { { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } } }
        end
        NS.LootFeed.Get = function(id) return id == 1 and d or nil end
        NS.LootFeed.Drops = function() return { d } end
        NS.WindowFilterBar.Set("group", "view", "all")
        NS.ShowWindow()
        return NS.WindowGroup.Drawn().rows[1].cells.tradeWindow
    end

    -- Each part its own surface: the family check is per surface, so two parts painted from two
    -- tokens in one surface would let one of them stop following while the other moved.
    local function parts(list, build, paint, ...)
        for _, part in ipairs({ ... }) do
            list[#list + 1] = { name = part[1], build = function() return build()[part[2]] end, paint = paint }
        end
    end

    -- SD-SK-DW.1 (the skin-defaults audit, LibKa0s#97): the painted surfaces the declaration left out.
    local function addMissing(list)
        local function rollsPanel()
            testMode()
            local d = NS.RollsPanel.Drawn()
            local h, line = d.headers[1], d.lines[1]
            return { panel = d.panel, fill = h.fill, chevron = h.chevron, bar = h.bar, stripe = line.stripe, wash = line.wash }
        end
        parts(list, rollsPanel, function() NS.RollsPanel.Refresh() end,
            { "the Rolls panel", "panel" }, { "a Rolls panel header's band", "fill" },
            { "a Rolls panel header's chevron", "chevron" }, { "a Rolls panel header's countdown bar", "bar" },
            { "a Rolls panel line's stripe", "stripe" }, { "a Rolls panel line's winner wash", "wash" })
        local function sideCard()
            testMode()
            local o = NS.RollPopup.Overlay(NS.RollPopup.StandInKey(1))
            return { card = o, title = o.header.title }
        end
        parts(list, sideCard, function() NS.RollPopup.Refresh() end,
            { "a roll popup's side card", "card" }, { "a roll popup card's header title", "title" })
        -- The header's band, as the window's title bar: the backdrop is clear under every skin that
        -- sets a gradient, so the band is its gradient region (the AF-DW-ROLLHDR header).
        list[#list + 1] = { name = "a roll popup card's header band", build = function()
            local h = sideCard().card.header
            return h, m.LibStub("LibKa0s-Skin-1.0").painted[h].regions.grad
        end, paint = function() NS.RollPopup.Refresh() end }
        local function historyRow()
            insights()
            NS.Window.SelectTab("history")
            return NS.WindowHistory.Drawn().rows[1]
        end
        parts(list, historyRow, redraw, { "a History row's stripe", "stripe" },
            { "a History row's expanded wash", "selected" }, { "a History row's chevron", "chevron" })
        local function pendingRow()
            local win = testMode()
            NS.Window.SelectTab("group")
            return NS.WindowPending.Drawn(win.panes.group).rows[1]
        end
        parts(list, pendingRow, redraw, { "a Rolling now row's stripe", "stripe" },
            { "a Rolling now row's expanded wash", "selected" }, { "a Rolling now row's chevron", "chevron" })
        local function compactCard()
            local _, card = listed("compact")
            return card
        end
        parts(list, compactCard, redraw, { "a compact card's stripe", "stripe" },
            { "a compact card's expanded wash", "selected" })
        local function filtersButton()
            listed("compact")
            local b = NS.CompactChrome.Parts().filters
            return { box = b, label = b.label, arrow = b.arrow }
        end
        parts(list, filtersButton, nil, { "the compact Filters button's box", "box" },
            { "the compact Filters button's label", "label" }, { "the compact Filters button's arrow", "arrow" })
        -- The Edit message box: its shell, its title and its typed text (the owner's U-19 of 2026-11-20).
        local function editBox()
            listed()
            NS.Asks.Preview = function() return { text = "Hi", length = 2 } end
            local e = NS.DetailCard.OpenEditor(1, "ask")
            return { shell = e, title = e.title, box = e.box }
        end
        parts(list, editBox, nil, { "the Edit message box", "shell" }, { "the Edit message box's title", "title" },
            { "the Edit message box's text", "box" })
        -- The countdown bar and its track are flat thin bars (skinning-§9's Leave class, A7, owner ruling
        -- of 2026-11-01): their colors follow the skin, and no bar texture is drawn.
        parts(list, tradeWindowRow, redraw, { "the trade window's countdown bar", "bar" },
            { "the trade window's countdown track", "barBg" })
        local function emptyState()
            NS.LootFeed.Drops = function() return {} end
            NS.LootFeed.Groups = function() return {} end
            return window().panes.group.emptyState
        end
        parts(list, emptyState, nil, { "the Drops empty state's title", "title" },
            { "the Drops empty state's text", "text" })
        -- The panes' scrollbars through S.ScrollBar: its corridor and its knob, each its own surface
        -- (two tokens). Drops' and History's; every other pane's bar is the same call.
        local function scrollParts(open)
            return function()
                local bar = rawget(open().scroll, "ScrollBar")
                local regions = m.LibStub("LibKa0s-Skin-1.0").painted[bar].regions
                return { track = regions.track, knob = regions.knob }
            end
        end
        parts(list, scrollParts(function() return window().panes.group end), nil,
            { "the Drops scrollbar's corridor", "track" }, { "the Drops scrollbar's knob", "knob" })
        parts(list, scrollParts(function()
            NS.Window.SelectTab("history")
            return window().panes.history
        end), nil, { "the History scrollbar's corridor", "track" }, { "the History scrollbar's knob", "knob" })
    end
    local function glowSurface(offSpec)
        return function()
            local out, paint = glowOf(glowDrop(offSpec))
            glowPaint = paint
            return out
        end
    end

    local facts = {
        owner = "DropWatcher",
        skin  = function() return m.LibStub("LibKa0s-Skin-1.0") end,
        reset = fresh,
        surfaces = {
            -- The band's backdrop and its gradient: Ka0s Default's band is a gradient since R4-L2,
            -- so the backdrop is clear under every skin that sets one and only the gradient moves.
            { name = "the window's title bar", build = function()
                local bar = window().titleBar
                return bar, m.LibStub("LibKa0s-Skin-1.0").painted[bar].regions.grad
            end },
            { name = "the active tab", build = function() return window().tabs.group.label end },
            { name = "the idle tab", build = function() return window().tabs.history.label end },
            { name = "the restricted badge", build = function()
                local f = window()
                return f.badge.text, f.badge.art
            end },
            { name = "the test mode word", build = function() return window().testText.text end },
            { name = "a flat button", build = function()
                local b = NS.Window.TextButton(window(), 80, "chat", "Ask", function() end)
                return b, b.label, b.art
            end },
            { name = "a row chevron", build = function() return NS.WindowGroup.RowChevron(window()) end },
            { name = "a column head", build = function() return window().panes.group.colHead.labels.item.text end },
            { name = "the column head band", build = function() return window().panes.group.colHead end },
            { name = "the detail card's box", build = function() return window().panes.group.card.trade end },
            { name = "the footer's hairline", build = function() return window().footerHost.line end },
            { name = "a Drops row's stripe and tone", build = function()
                local _, row = listed()
                return row.stripe, row.cells.level and row.cells.level.text or row.cells.ilvl.text
            end, paint = redraw },
            -- The tables' face moves with the skin through the LibSharedMedia fake above, so the
            -- Drops row's text asks it of every family; the shadow is its own surface for its companion.
            { name = "the tables' shadow", companion = setting("window.tableFontShadowFromSkin"),
              scope = "fonts", build = tableHalf("SetShadowColor", "SetShadowOffset"), paint = redraw },
            { name = "an item's icon border", companion = function(on)
                setting("icons.borderStyleFromSkin")(on)
                setting("icons.borderColorFromSkin")(on)
              end, build = function()
                local art = { SetTexCoord = function() end }
                local b = { art = art, GetFrameLevel = function() return 5 end }
                NS.IconStyle.Apply(b, LINK)
                return b.iconBorderFrame
              end },
            { name = "the main spec's glow", companion = setting("glow.main.colorFromSkin"),
              build = glowSurface(false), paint = function() glowPaint() end },
            { name = "the off-spec glow", companion = setting("glow.offSpec.colorFromSkin"),
              build = glowSurface(true), paint = function() glowPaint() end },
            { name = "a group header", build = function()
                listed()
                local h = NS.WindowGroup.Drawn().headers[1]
                return h.fill, h.chevron, h.text
            end },
            { name = "History's column head", build = function()
                NS.Window.SelectTab("history")
                local f = window()
                NS.Window.SelectTab("history")
                return f.panes.history.colHead, f.panes.history.colHead.labels.item.text
            end },
            { name = "the Offer panel", build = function()
                local d = drop()
                d.isMine = true
                d.looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true }
                d.candidates = { ["Player-1-S"] = { guid = "Player-1-S", name = "Seta-Realm", classFile = "PRIEST",
                    status = "ready", eval = { verdict = "upgrade", ilvlDelta = 14, reasons = {} } } }
                m.__now = 100
                withPlayer(m)
                NS.LootFeed.Groups = function()
                    return { { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } } }
                end
                NS.LootFeed.Get = function(id) return id == 1 and d or nil end
                NS.LootFeed.Drops = function() return { d } end
                NS.WindowFilterBar.Set("group", "view", "all")
                NS.ShowWindow()
                NS.OfferPanel.Open(1)
                local drawn = NS.OfferPanel.Drawn()
                return drawn.panel.title, drawn.panel.kind, drawn.rows[1].stripe
            end },
            { name = "a tooltip's title and lines", build = function()
                local spot = m.CreateFrame("Frame", nil, window())
                NS.Window.AttachTooltip(spot, function() return "Title", "A line" end)
                tipSpot = spot
                spot:GetScript("OnEnter")(spot)
                return m.GameTooltip
            end, paint = function() tipSpot:GetScript("OnEnter")(tipSpot) end },
            { name = "an Insights card", build = function()
                local card = insights().cards[1]
                return card.frame, card.value, card.label
            end },
            { name = "an Insights section heading and divider", build = function()
                local d = insights()
                return d.headers.verdicts, d.dividers.loot.fs, d.dividers.loot.rules[1]
            end },
            -- A data fill on a Texture, drawn in the skin's bar texture through S.BarTexture (kit
            -- revision 58: `expect = "texture"`, so a fill that stops following fails on its own).
            { name = "an Insights bar in a host color", expect = "texture", build = function()
                local bar = insights().ctx:Pool("verdicts").active[1]
                return bar.fill
            end, paint = redraw },
            { name = "an Insights strip column", expect = "texture", build = function()
                local d = insights()
                return d.ctx:Pool("drops").active[1].fill, d.strips.drops.axisLine
            end, paint = redraw },
            { name = "the toast", build = function()
                local d = drop()
                NS.LootFeed.Get = function(id) return id == 1 and d or nil end
                assert(NS.SchemaRuntime.Set("toast.enabled", true))
                NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
                local f = NS.Toast.Frame()
                return f, f.title, f.meText
            end },
        },
    }
    addMissing(facts.surfaces)
    -- The off-spec glow and the Trade window column (its countdown bar and track) are Retail's alone
    -- (Forever port design §4.4; C.FEATURE_CLIENTS.tradeTimer): on WoW Forever they are no surface.
    if _G.DW_TEST.forever then
        local retailOnly = { ["the off-spec glow"] = true, ["the trade window's countdown bar"] = true,
                             ["the trade window's countdown track"] = true }
        for i = #facts.surfaces, 1, -1 do
            if retailOnly[facts.surfaces[i].name] then table.remove(facts.surfaces, i) end
        end
    end
    return facts
end
