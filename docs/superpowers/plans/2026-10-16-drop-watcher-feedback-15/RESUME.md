# Resuming the feedback-15 run (M25)

Run `./resume-state.sh -v` in this folder. Items land on `feat/2026-10-16-drop-watcher-feedback-15`, in order
DW-Q0 → DW-Q4 (see the plan). Keep the green gate. Push after each item; never merge without the owner's go-ahead.

## Log
- 2026-10-16 — spec and plan written; branch cut from master `1c82395`; suite green (1429/0/1), lint 0/0.
- 2026-10-16 — DW-Q0 landed: Session.lua and FeedRestore.lua (TOC), LF.Restore, H.Adopt, beforeExpired undo, This instance across a reload; restored drops skip auto-open, toast and auto-ask; suite green (1439/0/1), lint 0/0.
- 2026-10-16 — DW-Q0 review fixes: area group keys unique across a reload (drop time suffix), restored drops not counted `n new` on a minimized window; suite green (1441/0/1), lint 0/0.
- 2026-10-16 — DW-Q1 landed: Content per tab (Drops This instance and This session, History adds All, both layouts), Drops' This session from the stored login, the new tooltip, feed.content two values and step 8; suite green (1447/0/1), lint 0/0.
