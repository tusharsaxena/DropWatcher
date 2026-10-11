# 06: Open questions

## A. Decisions for the owner

| # | Question | Options | Recommendation |
|---|---|---|---|
| A1 | Name | See `05_NAMES.md` | Hand-Me-Ups, or Loot Lens if a safe functional name is wanted |
| A2 | MVP scope | Cut as in `03_FEATURES.md` Part C, or move stats and Pawn (F5) into the MVP | Keep F5 in v1. ilvl verdicts plus trade and ask are the core loop. Stats add a lot of UI. |
| A3 | Standalone addon, or a feature of Ka0s Loot History? | Standalone or LH module | **Standalone.** Different purpose: live group trading vs your personal record. Different events: other players' loot, inspect, whispers. Folding it in would put LH's file cap and scope at risk. Link them later (X19). |
| A4 | Promote shared pieces to LibKa0s before scaffolding? | Loot parser, restriction tracker, ChatSender, tooltip line reader | Yes for the parser and the restriction tracker, as a small cross-repo bundle first. The others can follow when needed. |
| A5 | Addon comms between users of this addon | v1 or Later | Later. Encounter lockdown limits its value, and it is the most complex part. |
| A6 | PLH or PLR protocol interop | Never, read-only, or full | Decide after the MVP. Check both licences first. |
| A7 | Built-in stat-weight presets | Ship presets per spec, or Pawn plus user weights only | Pawn plus user weights plus an import string. Shipping presets creates a maintenance burden every season. |
| A8 | Auto-ask | Never, or opt-in with a delay | Opt-in (v1), with a delay after the encounter ends and cancel rules. |
| A9 | Default visibility | Always, instances only, or only when something is interesting | Instances only, and auto-open on the first interesting drop. |

## B. UX questions

| # | Question | Notes |
|---|---|---|
| B1 | Title colour: Ka0s gold or DYNT coral `#FF6B6B` | The standard's skin tints the title gold. Coral would need a documented deviation. Recommend gold. |
| B2 | Font: Roboto (DYNT) or `GameFont*` | Ka0s ships only JetBrains Mono. Bundling Roboto adds media and an LSM registration. Recommend `GameFont*` for consistency with the collection. |
| B3 | Compact (DYNT) or detailed columns by default | Recommend compact by default, with the detailed preset one click away. |
| B4 | Detail card: inline expand, or a hover tooltip | Inline expand (WGL-like information, DYNT-like frame). The tooltip stays for item comparison. |
| B5 | Should rows age out (WGL 60s), or persist for the session? | Recommend persisting, grouped by encounter or run, with dismiss and clear. |

## C. Facts to verify in game (before v1; some before the MVP)

1. Whether `CHAT_MSG_LOOT` text can be read during an encounter and an active key. Test with `/console addonChatRestrictionsForced 1`. *(MVP blocker)*
2. Whether a whisper sent from a button click during an encounter succeeds. *(MVP: decides whether the queue is always or only on failure)*
3. The Midnight Season 2 raid loot mode, and whether the ilvl trade rule applies in raid. *(v1)*
4. Whether the personal-loot trade rule compares against equipped items only or equipped plus bags, and whether by slot or by item type. *(v1)*
5. Whether `C_Item.GetItemUpgradeInfo(link)` works on another player's drop link. *(MVP: decides the track fallback)*
6. Whether `ENCOUNTER_LOOT_RECEIVED` fires for M+ end-of-run personal loot. *(MVP: affects dedupe)*
7. Whether the inspect ilvl from the `C_TooltipInfo.GetInventoryItem` ItemLevel line is still needed, or whether `C_PaperDollInfo.GetInspectItemLevel` and the links are now scaled correctly. *(MVP)*

## D. Next steps once the owner signs off

1. Choose the name, and settle A2–A9 and B1–B5.
2. Optional: a small bundle here, `docs/<date>-LIBKA0S_LOOT_SURFACES/`, to land the loot parser and the restriction tracker in LibKa0s.
3. Create the repo, with `.gitattributes` as the first commit, then run `/dev-copilot:wow-new-addon`.
4. In the new repo, write `docs/superpowers/specs/<date>-mvp-design.md` and `docs/superpowers/plans/<date>-mvp.md`, building on this bundle. The single-repo rule applies from that point on.
5. Build the MVP test-first: the kernel suites first, then the broker and the parser, then the UI.
6. Owner smoke tests in a dungeon and a raid; add the row to `ADDONS.md`.
