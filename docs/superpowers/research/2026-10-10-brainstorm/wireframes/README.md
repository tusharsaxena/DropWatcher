# Ka0s Drop Watcher: wireframes (approved 2026-10-10)

These are greyscale, low-fidelity wireframes. They are not in-game mockups. The owner approved them on
2026-10-10 as the basis for the build.

The live canvas is https://claude.ai/artifact/66FgCdy9d5txRSBkcLKrNw. It is private and owned by the owner.

| # | Board | PNG | Source |
|---|---|---|---|
| 01 | Main window, Group drops tab | `Main.png` | `Main.dc.html` |
| 02 | Expanded row (detail card) | `DetailCard.png` | `DetailCard.dc.html` |
| 03 | States and reasons (component sheet) | `States.png` | `States.dc.html` |
| 04 | My drops and the Offer panel | `MyDrops.png` | `MyDrops.dc.html` |
| 05 | Key interactions: the Ask and Offer storyboards | `AskFlow.png` | `AskFlow.dc.html` |
| 06 | Window modes: minimised, compact, toast, empty, test mode, launcher | `WindowModes.png` | `WindowModes.dc.html` |
| 07 | Settings: General (Master controls) | `SettingsGeneral.png` | `SettingsGeneral.dc.html` |
| 08 | Settings: Messages | `SettingsMessages.png` | `SettingsMessages.dc.html` |

`canvas.json` is the canvas index: the board positions and titles.

**Viewing offline.** Open any `*.dc.html` in a browser. `support.js` is a small offline renderer for the
canvas format.

**Regenerating the PNGs.** Load each file in headless Chromium at 1440×900 and take a screenshot.

**Rendering artefacts.** The PNGs come from the offline renderer, so they have two small artefacts:
- some callout dots overlap labels
- the ⏱ glyph is missing from the font

The canvas has neither.

**Added after approval:**
- **Situations** (where the addon is active)
- **Dynamic minimum quality**

Both live in Settings › Feed and Settings › General › When to show. They are specified in the addon's design
spec rather than drawn here.
