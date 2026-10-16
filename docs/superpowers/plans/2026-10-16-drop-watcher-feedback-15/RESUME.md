# Resuming the feedback-15 run (M25)

Run `./resume-state.sh -v` in this folder. Items land on `feat/2026-10-16-drop-watcher-feedback-15`, in order
DW-Q0 → DW-Q4 (see the plan). Keep the green gate. Push after each item; never merge without the owner's go-ahead.

## Log
- 2026-10-16 — spec and plan written; branch cut from master `1c82395`; suite green (1429/0/1), lint 0/0.
- 2026-10-16 — DW-Q0 landed: Session.lua and FeedRestore.lua (TOC), LF.Restore, H.Adopt, beforeExpired undo, This instance across a reload; restored drops skip auto-open, toast and auto-ask; suite green (1439/0/1), lint 0/0.
- 2026-10-16 — DW-Q0 review fixes: area group keys unique across a reload (drop time suffix), restored drops not counted `n new` on a minimized window; suite green (1441/0/1), lint 0/0.
- 2026-10-16 — DW-Q1 landed: Content per tab (Drops This instance and This session, History adds All, both layouts), Drops' This session from the stored login, the new tooltip, feed.content two values and step 8; suite green (1447/0/1), lint 0/0.
- 2026-10-16 — DW-Q2 landed: one footer button kind (FOOTER_BUTTON_W, modules/FooterRow.lua), Expand all / Collapse all on both tabs and layouts, the compact Drops strip always shown (Clear history stays on the strips at the one width until DW-Q3); suite green (1455/0/1), lint 0/0.
- 2026-10-16 — DW-Q3 landed: Clear history off both footers, its confirmation in History (`H.AskClear`), a Clear history button beside Keep history for on Settings › Window › Layout (pairWith); suite green (1457/0/1), lint 0/0.
- 2026-10-16 — DW-Q4 landed: the History tab's detail card from the snapshot (modules/HistoryCard.lua), rows and compact cards expand one entry with the Drops chevron; Link in chat, Mark / Clear declined, Show in Drops; suite green (1472/0/1), lint 0/0.
- 2026-10-16 — DW-Q4 final review fixes: a restored asked drop reads Asked (History.AskState), cleared drops stay cleared across a reload (char.session.cleared, FeedRestore.Pick), ARCHITECTURE's migration count eight, offers across a reload in known-limitations; run complete, awaiting the owner's merge go-ahead; suite green (1474/0/1), lint 0/0.
- 2026-10-16 — review leftovers: the History card's outcome chip drops the row-menu hint; stale README, defaults comment, smoke index and design-readings supersession synced; suite green (1474/0/1), lint 0/0.
- 2026-10-16 — compact headers (Drops and History) left aligned (WindowGroup.NewHeader SetJustifyH LEFT); suite green (1474/0/1), lint 0/0.
