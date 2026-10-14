# Ka0s Drop Watcher: owner feedback, twelfth session (M21) — History's outcomes in the action colors

- **Source:** the owner's note, 2026-10-14, after reviewing every action button's look
  (`docs/superpowers/research/2026-10-14-feedback-12/02-action-buttons.png`; the buttons stay as they are) and the
  History Outcome column (`01-outcome-today.png`): color the outcomes by the same convention, in both the full
  table and the compact cards. Then (`03-zero-shown-headers.png`): when the Character and Content filters leave a
  group with no row (`0 shown`), hide its header as well.
- **Plan:** items DW-L0 and DW-L1 on `feat/2026-10-13-drop-watcher-feedback-5`.

## 0. The outcome's tone (DW-L0)

`WindowHistory.Outcome` (the one composer the table and the compact cards read) takes the action buttons' tones
(`WindowCells.ActionTone`):

| Outcome | Tone | Why |
|---|---|---|
| Asked, Offered | yellow | it waited on someone else, as Asked/Offered/Queued |
| Received, Traded away | green (`good`) | done, as Traded |
| Expired | red | it fell through, as Retry |
| Seen, Declined | gray (`bad`) | nothing came of it, as No action |

Before: Seen and Declined muted, Asked and Offered plain, Expired gray. The words and tooltips do not change.
Owed in-game check FEED-73.

## 1. No `0 shown` header for Character (DW-L1)

`WindowCells.KeepsHeader` already left out a group that Search, Content or a Character choice of another
recorder hid whole. A drop with no recorder (kept before the Character dropdown, feedback-2 spec §4) was the
exception: Current hid it but its group kept a `n drops · 0 shown` header. That exception is gone: every
Character hide narrows, so such a group is left out under Current in the full table and the compact cards alike
(both read `WindowHistory.Entries`), and shows again under All. A group the View filter hid whole still keeps
its counted header (feedback-2 spec §0). Owed in-game check FEED-74.
