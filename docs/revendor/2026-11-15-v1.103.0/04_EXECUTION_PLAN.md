# 04 — Execution plan

Two pre-decided adoptions in one commit after the re-vendor commit (they share the window's chrome
geometry: the strip moves the body's top, the footer sets its foot, and `core/Constants.lua` loses both
copied heights together).

- Tests first: `tests/test_window.lua` pins `opts.dock = "title"`, the title bar and window in the
  strip's spec, both strips' anchors on the title bar's bottom edge, the body's top moving down by
  `BodyOffset` and back, and the chrome heights read from the library (`BANNER_H`, `STRIP_H` gone);
  `tests/test_compact_chrome.lua` the body (not the panes) moving by the strip in force in both modes
  and its two-line compact height; `tests/test_rolls_panel.lua` the strip docked on `p.titleBar` and
  the body under it; `tests/test_footer_row.lua` the footer built by `W.Footer` at `FOOTER.HEIGHT` with
  no fill, every tab row at that height, the grip on it in its corner, hidden while locked;
  `tests/test_skin_host.lua` no `S.Footer` band.
- Code: `core/WidgetsSetup.lua` (`NS.MakeTestStrip`'s `dock`, `NS.TestStripHeight`, `NS.MakeFooter`,
  `NS.FooterMetric`), `modules/Window.lua`, `modules/CompactChrome.lua`, `modules/RollsPanel.lua`,
  `modules/DropsStrip.lua`, `modules/WindowHistory.lua`, `modules/WindowInsights.lua`,
  `modules/WindowFooter.lua`, `modules/OfferPanel.lua`, `modules/CompactHistory.lua`,
  `core/Constants.lua`.
- Declaration: unchanged (no new catalog name).
- Gate: both kit profiles 0 failed, luacheck 0/0, perf 0 fail lines, the kit's complexity suite.
