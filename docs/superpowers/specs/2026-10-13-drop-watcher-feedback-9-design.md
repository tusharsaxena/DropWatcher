# Ka0s Drop Watcher: owner feedback, ninth session (M18) — the toast

- **Extends:** design spec §11.5 (the upgrade toast) and feedback-6 §3/DW-F5 (the toast's texture mark).
- **Source:** the owner's note and screenshots, 2026-10-13: `docs/superpowers/research/2026-10-13-feedback-9/`
  `01-toast-today.png` (the toast: the item name plain, `Looted by Seta · +19 ↑ · Likely trad…` cut) and
  `02-table-verdict-marks.png` (the Me/Them cells' `≈1` and `▲6`, the look the owner wants).
- **Plan:** item DW-I0 (build, review, docs) on `feat/2026-10-13-drop-watcher-feedback-5`.

## 0. The toast (DW-I0)

**Four rows beside a four-row icon** (owner, second note): the item icon grows to span all four rows (the toast's
height grows with it; the frame keeps its insets), and the rows read:

| Row | Reads | Notes |
|---|---|---|
| 1 | `Big upgrade for you` | gold title, as today; Ask and the close mark at the right of this row only |
| 2 | `Nalorakk's Nightmare 295` | the item name in its quality color (`NS.TipMarks.ItemName`); its item level right after it in smaller text (`GameFontHighlightSmall`, muted). The name is cut first; the item level always shows (two FontStrings, as the looter's `[YOU]` mark is drawn) |
| 3 | `Looted by Seta · You ▲19 · Them ▽13` | the looter's name in its class color (`NS.TipMarks.ClassName`); **the drop judged for you and for the looter**, each as the table's Me/Them cells draw a verdict: the monospace glyph (`▲`, `≈`, `▽`; WindowCells.GLYPH, `C.FONT_MONO`) then the unsigned difference, **both** in the verdict tone (green, yellow, red); a verdict the table says in a word keeps the word (`Can't use`, `Not wanted`, `?`, gray/muted); an upgrade into an empty slot reads `empty` in the upgrade tone. `You`, `Them` and the separators muted |
| 4 | `Likely tradeable · not an upgrade for Seta` | the trade word in the Trade cell's tone (green for yes/likely) and, after it, **the reason** the estimate gives (WindowCells.TradeReason, the Trade cell's tooltip reason, shortened to one line), muted |

- The texture arrow (TM.Mark) and the signed `+19` are gone from the toast. Since a FontString has one face, row 3 is
  drawn as segments (default-face text, mono glyphs, numbers) laid out left to right.
- **Nothing is cut while the toast has room:** rows 2–4 span to the toast's right inset (only row 1 shares its width
  with Ask and the close mark); the toast widens (Toast.WIDTH) only if a test shows the longest rows (a 12-character
  looter, two two-digit verdicts; `Likely tradeable` with the longest reason) still do not fit at 340. A reason too
  long for row 4 is cut with an ellipsis and the full reason is in the toast's tooltip.

- **A right-click anywhere on the toast closes it,** as its close mark does (the drop is not asked for and does not
  toast again). A left-click keeps today's behavior; in test mode the drag still works with the left button.

`Toast.Compose` stays pure: it answers the parts (item name and color, item level, looter name and class, the Me and
Them verdict parts, the trade word, tone and reason) rather than pre-joined lines; test_toast pins them and the
painted rows.

## 1. Docs and record
- docs (README's toast lines, ARCHITECTURE/module-map rows for Toast, design readings' superseded note on the
  toast's line), an owed smoke check after the last FEED- id; the automated-test bundle covers it with M16 and M17.
