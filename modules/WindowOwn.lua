local _, NS = ...
-- modules/WindowOwn.lua — your own drops on the Drops tab (feedback-5 spec §2): the session's
-- reveal state, the tone states of a drop's Offer and Announce, the message buttons' look, and the
-- reads that turn your own drop's cells into what the table, the compact card and the detail card
-- paint.
--
-- ALWAYS LISTED. Drops lists every drop, your own included (`feed.showOwn` is retired; a
-- stored value is ignored). On your own drop the Trade cell's tooltip counts the members it
-- upgrades, Them reads `Upgrade for N` with every upgrade in its tooltip (feedback-7 spec §2), and Actions
-- is Offer, which opens the Offer panel (modules/OfferPanel.lua) and reveals the drop. What each
-- says is NS.MineCells' (pure: OwnTrade, Details, OwnOffer; NS.SideCells.Them takes Details into
-- the Them cell); this file reads the state they take.
--
-- THE KEEP? RULE. An upgrade for you is offered to nobody until you open its Offer panel: until then
-- its count is not said and Them reads `Hidden`. Opening the panel reveals it for the session
-- (WO.Reveal, NS.State.windowOwn).
--
-- THE TONES (feedback-4 spec §1). Offer is toned by the furthest offer sent for the drop (cyan
-- while it is your move, feedback-6 spec §2), Announce by its own state; both green once you traded
-- the drop away (MineCells.ToneState). WO.ToneStates
-- answers both, for the Drops table, the detail card, the compact card and the Offer panel.
--
-- THE BUTTONS' LOOK. WO.SetButtonLook paints a message button (the Offer panel's Offer and
-- Announce to group) by its ask state: label, catalog mark, whether it clicks, and its tone.
--
-- THE CLICK. Every action button that may be an Ask or an Offer goes through WO.PressAction: Offer
-- (`b.offer`) opens the panel, anything else is the Ask (NS.PressAsk).

NS.WindowOwn = NS.WindowOwn or {}
local WO    = NS.WindowOwn
local State = NS.State
local MC    = NS.MineCells

local function view()
    local v = State.windowOwn
    if not v then
        v = { revealed = {} }
        State.windowOwn = v
    end
    return v
end

--- Reveal who drop `id` would help: the player chose to offer it (its Offer panel opened).
--- @param id number
function WO.Reveal(id)
    if id ~= nil then view().revealed[id] = true end
end

--- Whether drop `id` was revealed this session.
--- @param id number
--- @return boolean
function WO.IsRevealed(id) return id ~= nil and view().revealed[id] == true end

--- The states drop `drop`'s Offer and Announce are toned by (feedback-4 spec §1): Offer by the
--- furthest offer sent for it, Announce by its own state; both `tradedAway` once you traded it
--- away (MineCells.ToneState).
--- @param drop table
--- @return string offer, string announce
function WO.ToneStates(drop)
    local outcome = NS.History.OutcomeOf(drop.id)
    return MC.ToneState(outcome, NS.Asks.FurthestStateOf("offer", drop.id)),
        MC.ToneState(outcome, NS.Asks.StateOf("announce", nil, drop.id))
end

--- The Trade cell for any drop: your own drop's counts its upgrades (MineCells.OwnTrade).
--- @param drop table
--- @return table cell
function WO.Trade(drop)
    if drop.isMine then return MC.OwnTrade(drop, WO.IsRevealed(drop.id)) end
    return NS.WindowCells.Trade(drop)
end

--- Your own drop's Offer (MineCells.OwnOffer), toned by the offer half of WO.ToneStates.
--- @param drop table one of your drops
--- @return table WindowCells.Ask's shape, with `offer` true
function WO.Offer(drop)
    return MC.OwnOffer(drop, (WO.ToneStates(drop)))
end

--- A flat button whose look follows an ask's state (MineCells.OfferButton's or AnnounceButton's):
--- label, catalog mark, whether it clicks, its tooltip and its tone (`look.toneState`, else the
--- state: whose move it is, feedback-4 spec §1).
--- @param b table a Window.TextButton
--- @param look table { text, icon, enabled, tip, state, toneState, kind }
function WO.SetButtonLook(b, look)
    b.label:SetText(look.text)
    b.art:SetTexture(look.icon and NS.Icon(look.icon) or nil)
    b.art:SetShown(look.icon ~= nil)
    b.label:ClearAllPoints()
    b.label:SetPoint("CENTER", b, "CENTER", look.icon and 7 or 0, 0)
    b:SetEnabled(look.enabled)
    b:SetAlpha(look.enabled and 1 or 0.6)
    b.tipLines, b.state = look.tip, look.state
    NS.WindowGroup.ToneButton(b, look.toneState or look.state, look.kind)
end

--- An action button's click: Offer opens the Offer panel (`b.offer`), else it is the Ask.
--- @param b table the button (`b.dropId`, `b.offer`)
function WO.PressAction(b)
    if b.offer then
        NS.OfferPanel.Open(b.dropId)
    else
        NS.PressAsk(b.dropId)
    end
end
