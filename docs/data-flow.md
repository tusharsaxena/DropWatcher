# Data flow — Ka0s Drop Watcher

## Today: a setting changes

```
panel checkbox ─┐
/dw set|lock ───┼─> NS.SchemaRuntime.Set(path, v) ─> store ─> [Set] line ─> row.onChange ─> announce
launcher entry ─┘                                                   │                    │
                                                    Settings.REACTIONS[path]       panel refresh
                                                    (enabled → latch, visibility/scale/alpha/locked
                                                     → Window.ApplySettings)
```

## Today: the window's show decision

`Window.UpdateVisibility` reads one ladder: stood down → hidden; `visibility` says no (never, or the
combat condition fails) → hidden; the player opened it → shown. Turning test mode on opens a closed
window and remembers that it did, and turning it off closes the window again only in that case, so
Close, Toggle and Escape always win over test mode. It runs on every open and close, on test mode,
on both combat edges (`PLAYER_REGEN_DISABLED` / `_ENABLED`, which pass the edge itself rather than
re-reading `UnitAffectingCombat`), on the stand-down and stand-up, and on a profile change.

## Today: enable and disable

`enabled = false` → `Lifecycle:Set("disabled", true)` → `NS.StandDown`: feature events unregistered,
tracked bus registrations taken down, test mode ended, each module's teardown, window hidden. The
stand-up re-registers and re-applies the window from current settings. The perf harness's suspend
takes the same latch's `perf` hold.

## The design's loot pipeline (spec §3)

```
 CHAT_MSG_LOOT ─┐                         ┌─> Window (Group drops / My drops / History)
 ENCOUNTER_LOOT ├─> LootParser ─> LootFeed ┼─> DetailCard, OfferPanel, Toast
 LOOT_HISTORY  ─┘                     │    └─> History
   Situations ──gate──────────────────┤
   QualityGate ──gate─────────────────┼─> ItemFacts ─> Evaluate ─> verdicts
                                      ├─> TradeRules ─> trade estimate
                                      └─> TradeTimer (own bag items)
 Restrictions ──> Messaging queue ──> Compat.ChatSender (pcall)
```

Modules talk over the `NS.MSG` catalog in `core/Bus.lua`, one sender per message; the UI only
listens. Each stage lands with its plan item, and this page grows with it.
