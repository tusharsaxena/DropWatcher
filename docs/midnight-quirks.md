# Midnight quirks — Ka0s Drop Watcher

The client-version workarounds this addon carries of its own (documentation-§3, Tier 2). Each one
lives in `core/Compat.lua` ([`compat-layer.md`](compat-layer.md)) and is pinned by `test_compat`.
What is still unconfirmed in game is owed as a `COMPAT-*` check in
[`smoke-tests.md`](smoke-tests.md).

| Quirk | What the client does | What the addon does |
|---|---|---|
| Secret values (12.0) | During an encounter, a keystone or a PvP match, many payloads arrive as secret values that tainted code may store and pass but not compare, match or concatenate. | Every possibly-secret value meets `IsSecret` first: a secret tooltip line is skipped, a secret upgrade table is ignored, a secret bind answer reads as not bound. The guards come from `LibKa0s-Compat-1.0`, with the one-rung bodies re-implemented when the library is absent. |
| A secret answer to a yes/no gate | A secret boolean cannot be tested at all. | The cautious answer: a secret chat lockdown reads as locked and a secret restriction state as active, so a send is queued rather than attempted. |
| `SendChatMessage` deprecated (11.2.0) | The bare global moved to `C_ChatInfo.SendChatMessage`, with the same arguments. | `ChatSender()` takes the namespaced one first and the global second. |
| `PickupContainerItem` moved (10.0) | The bag functions moved to `C_Container`. | `PickupBagItem` takes `C_Container.PickupContainerItem` first and the global second. |
| Restriction state `Activating` | `ADDON_RESTRICTION_STATE_CHANGED` fires just before a restriction starts, with the state `Activating`. | Anything but `Inactive` counts as active, so the addon stops sending before the lockdown bites. |
| Enum numbers move | Blizzard renumbers enums between patches; the research's `TradeTimeRemaining = 36` and `ItemUpgradeLevel = 32` are one build's values. | Every enum member is resolved by name at call time. A client that lacks a tooltip line type falls back to matching the line's localized text. |
| Inspected links carry the unscaled item level | An item link read off an inspected player shows the base level, not the scaled one. | `InventoryItemLevel` reads the tooltip's `ItemLevel` line for the inspected unit (spec §8). |
| No upgrade-track API on some builds | `C_Item.GetItemUpgradeInfo` is in the 12.1.0 docs; whether it answers for another player's drop link is unconfirmed. | Falls back to the hyperlink tooltip's `ItemUpgradeLevel` line, read with the localized `ITEM_UPGRADE_TOOLTIP_FORMAT_STRING`. English is never parsed. |
| The trade timer is text | The remaining trade time exists only as a tooltip sentence on your own bag item. | The `TradeTimeRemaining` line (or the `BIND_TRADE_TIME_REMAINING` sentence) is decoded with the client's own duration globals, so it reads in every client language ([`compat-layer.md`](compat-layer.md#the-duration-decoder)). |
| Pawn's readiness | Pawn answers nil until it has initialized and until an item is cached. | Every Pawn call waits on `PawnIsInitialized`, runs under `pcall`, and a nil answer means "not ready yet". |
