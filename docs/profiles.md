# Profiles — Ka0s Drop Watcher

AceDB profiles are user-visible: the Profiles page (`settings/Profiles.lua`) draws AceDBOptions'
table, and `/dw profile [name]` lists or switches profiles.

- Every setting except the minimap button lives in the profile. The minimap button is a
  per-installation preference in `global.minimap` (launcher-§3).
- A profile switch, copy or reset runs the migrations, refreshes the panels, re-reads the latch from
  the incoming profile's `enabled`, and re-applies the window (`core/DropWatcher.lua`
  `reloadProfile`). It is logged once, by the profile handler.
- Reset all settings is a profile reset (options-ui-§12): it resets the current profile only.

Per-situation profiles are deliberately not used: the design keeps per-situation settings inside one
profile (spec §12.1), so the player has one profile to manage.
