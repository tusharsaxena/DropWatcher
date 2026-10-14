# Ka0s Drop Watcher: owner feedback, eleventh session (M20) — pending once, full-width lines, No action

- **Extends:** feedback-10 spec §2 (the compact card), feedback-7 spec §1 (action icons), feedback-4 spec §1 (action
  tones).
- **Source:** the owner's note and screenshot, 2026-10-14: `docs/superpowers/research/2026-10-14-feedback-11/`
  (`01-pending-twice.png`: `(…)` after the name and `Them …` on the same card), and the owner's answers: drop the
  pending mark after the name; lines 1 and 3 use the full width; the placeholder reads `No action`, its buttons
  widened (and the window, if needed) so it fits.
- **Plan:** items DW-K0..DW-K2 on `feat/2026-10-13-drop-watcher-feedback-5`.

## 0. The compact card (DW-K0)

- **Pending once.** `CompactCards.FreshMark` leaves the pending read (`…`) out, as it does the dash: Them's `…`
  already says it. `(2m)`, `(cached)`, `(range)`, `(combat)`, `(!)` still show.
- **Full width on the lines without a button.** Line 1's name runs to the card's right inset before it is cut (as
  since feedback-10); line 3's Them half is bounded there too, its last piece cut with an ellipsis at the card's
  right inset rather than running past it. Line 2 alone stops short of the action button.

## 1. No action (DW-K1)

Where a drop has no action (cannot be traded, warbound, not an upgrade, the looter unknown, …), every view shows a
**placeholder action button** in its slot, never a dash or an empty slot: the label `No action`, LibKa0s' `ban`
icon (⊘), gray (`C.TONE.bad`) and dimmed like a disabled button, not clickable; its tooltip is titled `No action`
and gives the reason (the same reason the dash's tooltip gave).

- **Views:** the Drops table's Actions cell, the compact card's line 2, the detail card's first action (Ask, or
  Offer on your own drop), and each Offer panel row (a member it is not an upgrade or equal for, or a drop that
  cannot be traded).
- **One look:** `WindowCells.Ask` and `MineCells.OwnOffer` answer it (`offered` false, `text` `No action`, `icon`
  `ban`, `state` `none`, `tip` { `No action`, reason }); `WindowCells.ActionTone("none")` is gray.
- **Widths:** `No action` with its icon must fit every action button (tests/test_drops_layout's fit rule): the
  84-pixel `ASK_W` fits it; the Offer panel's `PANEL_BTN_W` grows 72 → 80 (its Actions column has the room).

## 2. Docs and record (DW-K2)
- README, ARCHITECTURE, module-map, data-flow, testing, smoke-tests (owed FEED-71..72), design readings' superseded
  notes; review fixes; the automated-test bundle.
