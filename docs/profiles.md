# Profiles — Ka0s Drop Watcher

AceDB profiles are user-visible: the Profiles page (`settings/Profiles.lua`) draws AceDBOptions'
table, and `/dw profile [name]` lists or switches profiles.

- Every setting lives in the profile except three account-wide ones in `global`: the minimap
  button (`global.minimap`, a per-installation preference, launcher-§3), the history and its cap
  (`global.history`, one log for all your characters) and auto-ask's one-time notice
  (`global.notices.autoAsk`).
- A profile switch, copy or reset runs the migrations, refreshes the panels, re-reads the latch from
  the incoming profile's `enabled`, re-reads auto-ask's `enabled` (`NS.AutoAsk.OnProfileReloaded`:
  an incoming profile that turns it on counts drops from that moment, one that turns it off cancels
  the waiting asks), and re-applies the window (`core/DropWatcher.lua` `reloadProfile`). It is logged once, by the profile handler.
- Reset all settings is a profile reset (options-ui-§12): it resets the current profile only.

Per-situation profiles are deliberately not used: the design keeps per-situation settings inside one
profile (spec §12.1), so the player has one profile to manage.
