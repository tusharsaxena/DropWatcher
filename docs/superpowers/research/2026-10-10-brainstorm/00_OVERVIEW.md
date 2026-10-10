# New addon brainstorm: group loot upgrade and trade helper (2026-10-10)

This is research and a high-level design only. It contains no code and no repository, and no decision has
been taken. The owner reviews it, and then the build starts. When that happens, the spec and the plan move
to the new addon's own repository, following the single-repo rule in `CLAUDE.md`.

## The ask, in one line

Build a Ka0s addon that watches every drop in the group. It tells you whether each drop is an upgrade for
you and whether it is an upgrade for the person who looted it. It shows whether the looter can trade the
item, and gives you a polite one-click way to ask for it or to offer your own loot. The addon should
**look like DoYouNeedThat** (a compact dark table) and **work like WhoGotLoots** (inspect broker,
upgrade verdicts, track and stat breakdown, a "who could use this" panel for your own drops). It should
meet the full Ka0s standard.

Reference screenshots: `inputs/ref-doyouneedthat.png` and `inputs/ref-whogotloots.png`.

## Reading order

| File | What it holds |
|---|---|
| `00_OVERVIEW.md` | This page: the summary, headline findings and the decisions the owner needs to make |
| `01_LANDSCAPE.md` | The two reference addons, 20+ competitors, a feature matrix and the gaps in the market |
| `02_PLATFORM_CONSTRAINTS.md` | Midnight 12.x API facts and restrictions that shape the design, plus what still needs in-game verification |
| `03_FEATURES.md` | Each of the owner's nine features analysed, the extra features proposed, and MVP, v1 and later tiers |
| `04_HIGH_LEVEL_DESIGN.md` | Architecture, modules, the evaluation kernel, data model, UI, settings, slash commands and Ka0s compliance |
| `05_NAMES.md` | 34 name ideas (functional, quirky and witty) with a shortlist |
| `06_OPEN_QUESTIONS.md` | Decisions for the owner and facts to check in game before building |
| `inputs/` | The four raw research reports and the two reference screenshots |

## Headline findings

1. **The niche is crowded, but the incumbents are fragile.**
   - Personal Loot Helper (2.7M downloads) and PersoLootRoll (300K) both broke for months in 12.0.
   - DoYouNeedThat has been abandoned since 2020.
   - WhoGotLoots works, but it has real bugs: a mislabelled "BoP" flag, no real tradeability detection, a broken cross-realm whisper, and hard `error()` calls inside item callbacks.
   - The newest serious entrant, *Do You Need It?*, has 849 downloads.
   - So there is room for a carefully built addon that is robust on Midnight, works in any locale and is tested.
2. **Nobody combines everything you asked for.** No addon has all of these at once: a group drop feed, a looter inspect, your own upgrade with stat weights or Pawn, the looter's upgrade, a visible trade countdown, and asking and offering in both directions in both raids and M+. PersoLootRoll comes closest, but it is built around rolls rather than a feed you read.
3. **Midnight's addon restrictions are the main design driver.**
   - Blizzard's 12.1.0 API docs say `CHAT_MSG_LOOT` itself stays readable.
   - However, chat *sending*, addon comms and whisper *reading* are restricted during encounters and active keys.
   - So asks and offers must **queue and fire after the encounter ends**, and the UI must show that state honestly.
   - Details are in `02_PLATFORM_CONSTRAINTS.md`.
4. **Another player's tradeability can only be estimated.**
   - The trade timer exists only on the looter's own copy of the item.
   - For someone else's drop, the honest answer is one of four states (Yes, Likely, Unknown, No), each with a reason.
   - For your own drop, the timer is exact: it is read from the tooltip by line type.
5. **Ka0s already owns half the plumbing.**
   - LibKa0s supplies the skin, options, slash, launcher, debug console, diagnostics, perf, pool and item helpers.
   - Ka0s Loot History already has a locale-safe loot-chat parser, for your own loot only.
   - That parser now has a second consumer, so it is a candidate to promote into LibKa0s (see `04_HIGH_LEVEL_DESIGN.md` §9).
   - The new code needed is the inspect broker, the evaluation kernel, the trade estimator, the messaging queue and, later, addon comms. The Ka0s collection has no precedent for any of these.

## Recommended shape

- **One compact, skinned table window**, styled like DoYouNeedThat with a Ka0s skin.
  - It has two tabs: **Group drops** and **My drops**.
  - Rows can be expanded into a WhoGotLoots-style detail card showing track, stats, both comparisons and the reason for the trade estimate.
- **A pure evaluation kernel.** It takes an item, a candidate's gear, the candidate's class and spec, and the scoring source, and returns a verdict. It has no WoW calls, so it can be fully tested headless.
- **An inspect broker** that follows WhoGotLoots' good design: one job per player, roster warm-up, deference to other addons, a combat park and a cache with an age label.
- **Messaging that understands restrictions.** Templates use tokens; there is a one-ask-per-item guard; an encounter queue holds sends; every send goes through `pcall`; auto-whisper is off by default.
- **Phased delivery:**
  - MVP: feed, ilvl verdicts, equippability, trade estimate, ask and offer.
  - v1: stats, Pawn, sidegrades, track, own trade timers, history.
  - Later: wishlist, tier and catalyst, transmog, comms and interop.

## What the owner needs to decide (full list in `06_OPEN_QUESTIONS.md`)

1. Which name to use (`05_NAMES.md`).
2. **Title colour.** The Ka0s gold title from the shared skin, or the DoYouNeedThat coral-red title? The recommendation is the Ka0s skin with DoYouNeedThat's row and button layout.
3. Whether a standalone addon is right, rather than a feature of Ka0s Loot History. The recommendation is a standalone addon (see 06 §A3).
4. Scope of the MVP: confirm the cut in `03_FEATURES.md`.
5. Whether addon comms between users of this addon belong in v1, and whether to interoperate with PLH or PLR.
