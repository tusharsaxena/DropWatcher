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

## Today: the situation

```
six events (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, CHALLENGE_MODE_START,
            CHALLENGE_MODE_COMPLETED, GROUP_ROSTER_UPDATE, PLAYER_DIFFICULTY_CHANGED)
  └─> DW.OnSituationEvent ─> Situations.Refresh
        ├─> ReadInputs: GetInstanceInfo, IsInInstance, C_ChallengeMode, IsInGroup / IsInRaid,
        │               GetDifficultyInfo (an unknown id reads as nil)
        ├─> Classify (pure) ─> key
        └─> key changed? ─> NS.State.situation ─> SituationChanged (key, previousKey)
```

`IsTracking`, `ShouldAutoOpen` and `QualityOverride` resolve the current key against
`profile.situations.<key>`, falling back to the spec defaults. The stand-down clears the key; the
stand-up re-reads the client and announces where the player is.

## Today: the roster

```
GROUP_ROSTER_UPDATE ─> DW:OnSharedFeatureEvent ─> DW.OnSituationEvent (above), then
  └─> DW.OnRosterEvent ─> Roster.Refresh
        ├─> tokens: raid1..N, or player + party1..N-1, or player alone
        ├─> per token: UnitGUID (secret or missing: skipped), UnitName (secret or Unknown: no
        │              name), UnitClass, UnitIsConnected; same-realm realm from
        │              Compat.NormalizedRealm
        └─> NS.State.roster = { byGUID, list }, each member's specID carried over

Roster.Resolve(GUID | "Name-Realm" | "Name", classFile?)
  ├─> GUID hit, else name (+ realm) match without case, realms normalized
  ├─> a tie: classFile narrows, then (bare name) the player's own realm
  └─> a miss: Refresh once, then try again; still none or still a tie: nil
```

The roster sends no message: a module that needs the fresh group declares `GROUP_ROSTER_UPDATE`
below `modules/Roster.lua` in the TOC and hears it after the roster's handler. The stand-down drops
the roster; the stand-up re-reads it.

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
