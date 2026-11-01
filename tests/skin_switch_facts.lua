-- tests/skin_switch_facts.lua — this addon's painted surfaces, for the kit's skin-switch suite
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). `reset` gives each surface a fresh
-- enabled instance, because a registered skin and a drawn window are per instance. Every surface
-- answers the objects that draw, so a failure names one thing and not the whole window.
--
-- A surface with a `companion` is on that row's skin half and leaves the second pass. `scope` marks
-- what Ignore settings panel or Ignore fonts keeps stock. `paint` is the redraw a mock has no
-- listener for: a table text is restyled by the next repaint, and an item's glow by the next pass.

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"

--- The facts, for `enableAddon`, the runner's factory.
return function(enableAddon, withPlayer)
    local NS, m

    local function fresh()
        local env
        NS, env, m = enableAddon()
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
    local function glowSurface(offSpec)
        return function()
            local out, paint = glowOf(glowDrop(offSpec))
            glowPaint = paint
            return out
        end
    end

    return {
        owner = "DropWatcher",
        skin  = function() return m.LibStub("LibKa0s-Skin-1.0") end,
        reset = fresh,
        surfaces = {
            { name = "the window's title bar", build = function() return window().titleBar end },
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
            { name = "the summary strip's rule", build = function() return window().panes.group.summary.line end },
            { name = "the detail card's box", build = function() return window().panes.group.card.trade end },
            { name = "the footer band", build = function() return window().footerHost end },
            { name = "a Drops row's stripe and tone", build = function()
                local _, row = listed()
                return row.stripe, row.cells.level and row.cells.level.text or row.cells.ilvl.text
            end, paint = redraw },
            -- The tables' face is not a surface here: the harness has no LibSharedMedia, so every
            -- skin's face resolves to the client's and a string's SetFont never moves.
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
end
