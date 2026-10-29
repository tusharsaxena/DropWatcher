# Profiles — Ka0s Drop Watcher

AceDB profiles are user-visible: the Profiles page (`settings/Profiles.lua`) draws AceDBOptions'
table, and `/dw profile [name]` lists or switches profiles.

- Every setting lives in the profile except three account-wide ones in `global`: the minimap
  button (`global.minimap`, a per-installation preference, launcher-§3), the history and how long it is
  kept (`global.history`, its Keep history for in `global.history.retentionDays`; one log for all
  your characters) and auto-ask's one-time notice
  (`global.notices.autoAsk`).
- A profile switch, copy or reset takes a shown first-run skin picker down (unmarked), runs the
  migrations, applies the incoming profile's skin, scope and font and texture overrides
  (`NS.ApplySkinChoice`, a live repaint), refreshes the panels, re-reads the latch from
  the incoming profile's `enabled`, re-reads auto-ask's `enabled` (`NS.AutoAsk.OnProfileReloaded`:
  an incoming profile that turns it on counts drops from that moment, one that turns it off cancels
  the waiting asks), lets the toast re-read its settings (`NS.Toast.OnProfileReloaded`, the combat hold included), restarts the
  upgrade glows (`NS.Glow.Refresh`) and restyles every item icon (`NS.IconStyle.Refresh`) from the
  incoming profile, re-applies the window, and shows the skin picker again when the incoming profile has not closed it
  (`skin.pickerSeen`; a new or reset profile has not) (`core/DropWatcher.lua` `reloadProfile`). It is logged once, by the profile handler.
- Reset all settings is a profile reset (options-ui-§12): it resets the current profile only.

Per-situation profiles are deliberately not used: the design keeps per-situation settings inside one
profile (spec §12.1), so the player has one profile to manage.
