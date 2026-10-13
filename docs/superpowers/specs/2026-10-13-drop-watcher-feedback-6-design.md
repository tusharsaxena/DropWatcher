# Ka0s Drop Watcher: owner feedback, sixth session (M15)

- **Extends:** `2026-10-13-drop-watcher-feedback-5-design.md` (M14) and the earlier specs.
- **Source:** the owner's notes and screenshots, 2026-10-13, after looking at M14 in game. The evidence is in
  `docs/superpowers/research/2026-10-13-feedback-6/`.
- **Plan:** `docs/superpowers/plans/2026-10-13-drop-watcher-feedback-6.md`. Items DW-F0..DW-F4, on the same unmerged
  branch `feat/2026-10-13-drop-watcher-feedback-5` (the owner has not merged M14 yet; M15 rides with it).
- **Both layouts.** Every change that applies to both the full and the compact layout lands in both.

## 0. The Trade window column fits its widest text (DW-F0)

**Evidence.** `01-trade-window-wide.png`: the 104px column leaves a wide empty margin right of every countdown.

- The column is as wide as the widest text its cell can show, measured, not guessed: every `MC.TradeWindow` answer
  (`~1:57:43`, `1:49:43`, `Their upgrade`, `Your upgrade`, `No limit (BoE)`, `Bonus roll`, `Window passed`,
  `Legacy loot`, `Warbound`, `Not loaded`, `Checking`, `Not tradeable`) in the row font, plus the cell's own padding.
  The owner named `Their upgrade` as the widest; if another answer is wider, the widest wins and the spec's intent
  (no empty margin, nothing cut) holds. A test pins the width against that list at the harness's character
  measure.
- The bar spans the narrower column. The least width is recomputed (§1's merge also moves it; one recompute after
  both, in DW-F1).

## 1. My eq merged into Me, Their eq into Them (DW-F1)

**Evidence.** `02-eq-and-verdict-columns.png`: My eq, Their eq, Me and Them as four columns, the verdict a column
away from the gear it compares.

**Rule.** Two columns where there were four, on Drops and on History (History's Me and Them gain the gear the same
way when its record has it; where History has no worn-item data the cell is the verdict alone, as today).
- **The cell reads** `[icon(s)] [item level] [arrow][difference]`: the worn item's icon (two for rings, trinkets and
  one-hand weapons, as My eq drew them), its item level (`321`, `321/308` for two), then the verdict's glyph and the
  absolute item-level difference with no sign: `▲6`, `▽8`, `≈1`, `≈0`. The glyph and number take the verdict tone
  (green up, yellow side, red down); the item level stays plain. Glyphs keep the monospace face.
- **The words stay words:** `Can't use` and `Not wanted` (gray) replace the arrow and number after the gear;
  an unknown verdict (`?`) is dropped from the cell when the gear part already says why (`range`, `…`, `–`,
  `combat`, `!`), and shown alone when it does not.
- **Nothing worn in the slot:** the gear part reads `empty` (muted) and the verdict follows.
- **Your own drop's Them** reads `(Details)` (renamed from `(Multiple)`, §3), in its tones, with its tooltip.
- **Labels:** the merged columns keep the verdict columns' labels, `Me` and `Them`; their tooltips describe both
  halves. The `window.columns` toggles `myEq` and `theirEq` are retired (a migration step removes the stored keys,
  as `RetireShowOwn` did); `me` and `them` toggle the merged columns.
- **Tooltips merge too:** the cell's tooltip is the gear tooltip's lines (each worn item, the inspect age for Them)
  followed by the verdict's reasons, so nothing either old tooltip said is lost.
- **Width:** each merged column is as wide as its worst case (two icons, `321/308`, `▽13`), measured; the shed
  order drops the merged columns where the old verdict columns sat; the full least width is recomputed so no
  column sheds at the least width (Drops and History), exactly as M13 and M14 did.
- **Compact:** line 3 reads the same way without icons: `You 321/308 ▽8` and `Them 276 ▲12`, `Them (Details)` on
  your own card.

## 2. Offer in cyan (DW-F2)

**Evidence.** `03-offer-red.png`: Offer in the same red as Ask, though it is a different kind of action.

- A new tone `C.TONE.cyan` (about `0.35, 0.82, 0.95`, a cyan in the palette's saturation and brightness) for
  **Offer while it is your move** (no offer sent). Offered/Queued stay yellow and Traded stays green, as M13 set.
- Everywhere Offer is drawn: the Drops row, the compact card, the detail card, and the Offer panel's per-member
  Offer buttons. Ask and Retry stay red. The Offer panel's Announce to group is unchanged.

## 3. The (Details) tooltip: readable and richer (DW-F3)

**Evidence.** `04-details-tooltip-boxes.png`: `Butterz □ +11 · wears 276 (Speakeasy Shroud)`, the arrow drawn as a
box (the tooltip font has no verdict glyphs) and the line wrapping.

- **Rename** `(Multiple)` to `(Details)` everywhere (table, compact card, detail card).
- **One line per member it upgrades,** ranked by gain:
  `[Name in class color] wears [item level] [Item name in its quality color] [arrow][difference]`. The arrow is an
  inline texture (`|T…|t`, LibKa0s media `arrow-up`, tinted green through the escape's color fields), never a font
  glyph; the difference has no sign. Two worn items (rings, trinkets, one-hand weapons) name the one it would
  replace (the lower).
- **Fits its content:** these lines do not wrap; the tooltip grows to the longest line instead of wrapping at the
  default width. Explanatory lines (keep? rule, checking, nobody's upgrade, solo) keep wrapping.
- **No glyph boxes anywhere in a tooltip.** Every tooltip line that carries `▲`, `▽`, `≈` or `⊘` (column header
  tips, verdict tips, the Trade count line) is audited: a verdict mark in a tooltip is the inline texture (up and
  down arrows; sidegrade a texture from the same set, e.g. `transfer`, or the word) or is removed. Table cells and
  compact lines keep the monospace glyphs, which render.

## 4. Review, docs and record (DW-F4)

- An independent review of M15's diff; findings fixed.
- Docs synced (README, ARCHITECTURE, module-map, schema for the retired toggles and the migration step,
  settings-panel, data-flow, design readings' superseded notes); smoke checks FEED-48.. owed for each section above.
- The automated-test bundle, `docs/test-cases.md` and the README badge; push.
