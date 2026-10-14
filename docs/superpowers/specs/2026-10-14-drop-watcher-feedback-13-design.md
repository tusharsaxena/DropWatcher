# Ka0s Drop Watcher: owner feedback, thirteenth session (M22) — each tab's default filters

- **Source:** the owner's note, 2026-10-14, with two screenshots of the filter bar
  (`docs/superpowers/research/2026-10-14-feedback-13/01-drops-defaults.png`, `02-history-defaults.png`): the default
  filters for both tabs should be as shown.
- **Plan:** item DW-M0 on `feat/2026-10-14-drop-watcher-feedback-13`.

## 0. The defaults (DW-M0)

| Tab | View | Quality | Content | Character |
|---|---|---|---|---|
| Drops | All | Rare+ (the feed's mode, a readout) | This session | Current |
| History | All | Rare+ (grayed: History does not honor it) | All | All |

- **Drops.** The `feed.content` row's default goes from `instance` to `session`. A profile that stored a Content
  choice keeps it; the row still seeds the Drops tab.
- **History.** `WindowFilterBar.TAB_FIXED.history` gives the tab View: All, Content: All and Character: All when
  its state is made, whatever the profile seeds. It replaces the old seeding in `WindowHistory` (View and Content
  put on the tab the first time it was shown each session); Character was Current there (feedback-2 spec §4).
- **Compact.** The Filters button counts a control off the tab's own default, so History at its defaults reads
  `Filters` with no count (it read `Filters · 1` for Content: All), and any Character choice on History counts.
- The Content row's tooltip now says it is the Drops tab's and that History always opens on All.

Owed in-game check FEED-75.
