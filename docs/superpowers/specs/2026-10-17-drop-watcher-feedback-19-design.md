# Ka0s Drop Watcher: owner feedback, nineteenth session (M26): off-spec

- **Source:** the owner's session of 2026-10-17. A Protection paladin saw `Venom-Etched Crescent`, an Intellect
  one-handed axe (311), marked `⊘ Can't use`. Protection cannot use it, but Holy can, and nothing let them ask
  for it. The design was settled in conversation on 2026-10-17 and the owner auto-approved the rest:
  - every other spec of the class counts as an off-spec, with no setting;
  - the baseline is the best owned item for that spec;
  - off-spec gets its own whisper, and takes part in the toast, auto-ask and Offer;
  - main spec always comes first;
  - off-spec upgrades are coloured cyan, where main-spec upgrades are green.
- **Plan:** items DW-O0 … DW-O5 on `feat/2026-10-17-offspec`
  (`docs/superpowers/plans/2026-10-17-drop-watcher-feedback-19.md`).
- **Decisions this spec takes on the owner's behalf** (auto-approved) are marked *Decided*.

## 0. The off-spec verdict (DW-O0)

**When it applies.** Only when the main-spec verdict is `cantUse`, **and** one of the reasons it gives
depends on the spec: `primaryStat`, `specList`, `shield`, `offhand` or `dualWield`. A refusal on the
class (`armorType`, `weaponType`, `classRestricted`, `unknownClass`) rules out every spec, so the
off-spec pass is skipped for it. An item the main spec can use is judged on main spec alone, exactly as
today. The off-spec pass also needs a known `specID`. A looter whose spec is unknown already gets
`unknown` or a class-wide answer, so there is nothing to rescue.

**Which specs.** Every spec in `CD.CLASS_SPECS[classFile]` except the candidate's own. Each one is judged
with the same kernel, on a derived candidate:
- `specID = X`;
- `dualWield = CD.DualWieldFor(c, X)` and `titanGrip = CD.TitanGripFor(c, X)`, never copied from the main
  spec;
- `prefs.undesired` taken from that spec's own undesired list, when the candidate carries the per-spec
  lists;
- the gear for X (below);
- options: the same `sidegradeBand` and `heirloomProtect`, `compareOwned = false`, and **no scorer**.

*Decided:* off-spec is ilvl-only. A Pawn scale for the player is chosen per drop for the main spec, and an
off-spec score would need a scale the player may not have. An off-spec verdict therefore never waits on
`scorePending`.

**The best spec wins.** Upgrade beats sidegrade, which beats downgrade. Within the same verdict, the larger
`ilvlDelta` wins (an empty slot counts as the largest), then the lower spec id. `doesntWant`, `cantUse` and
`unknown` are never chosen. If no spec gives one of the three, there is no `offSpec`.

**The shape.** The main eval gains one field and changes nothing else:

```lua
eval.offSpec = {
  specID = 65, verdict = "upgrade" | "sidegrade" | "downgrade",
  ilvlDelta = n | nil, trackDelta = {..} | nil,
  baseline = facts | nil,      -- the item compared against; nil for an empty slot
  baselineSlot = n | nil,
  reasons = { { key = "emptySlot" }, ... },   -- the off-spec pass's own reasons
}
```

`eval.verdict` stays `"cantUse"`, and every existing reader that never looks at `offSpec` behaves as
before. That includes the trade estimate, which by design stays on the main verdict: the game's personal
loot rule compares item levels whatever the spec.

**Where the logic lives.** A new pure module, `modules/OffSpec.lua` (`NS.OffSpec`), is loaded after
`modules/Evaluate.lua`. `E.Evaluate`'s `run` calls `NS.OffSpec.Attach(out, facts, candidate, opts, run)`
after `protect`, and the kernel stays pure. The candidate brings its off-spec gear as a function,
`candidate.offSpecGear(specID)`, which returns the kernel's `gear` map for that spec (`false` = empty).
It is called inside `E.Evaluate`'s pcall, and a throw or a non-table result skips that spec. Its
undesired lists come as `candidate.undesiredBySpec = { [specID] = { [subClassKey] = true } }`.
`LootFeed.lua` (992 lines) gains at most one line, the per-spec undesired lists on `myCandidate`. Gear and
Inspect build everything else.

**The player's off-spec gear** (`modules/Gear.lua`).
- The snapshot keeps every gear item it reads, worn and in bags, **before** the main-spec filter, as
  `snap.pool`.
- `G.OffSpecGear(specID)` filters that pool with `Evaluate.Equippability(e, whoX) == "ok"` for the spec's
  derived candidate, places it with the existing `fitsOf` / `bestFor` (`readOwned` run with `whoX`), and
  returns a `gear` map: the best item per slot, `false` where nothing fits, and nil only while items are
  still loading.
- It is memoized on the snapshot (`snap.bySpec[X]`), so a rebuild drops it.
- `G.Candidate()` adds `offSpecGear = G.OffSpecGear` and keeps `gear`/`owned` exactly as before
  (test_gear pins them by identity).
- The snapshot signature folds in the pool's links and levels. A bag change that touches only an
  off-spec item therefore still sends `GEAR_CHANGED`, and `LF.OnGearChanged` re-judges.
- A spec change already re-judges.

**The looter's off-spec gear** (`modules/Inspect.lua`). Worn gear only, because an inspect cannot see bags.
`I.Candidate(guid)` adds `offSpecGear = function(X)`, which returns each worn slot's item when that spec
could wear it, `false` when it could not (so the slot reads as empty), and nil while the slot is still
loading.

**Perf.** The pass runs only on `cantUse` drops, and per spec it is one extra `run`. The `evaluate` bucket
already brackets it. `tests/perf.lua`'s ceilings must still hold.

## 1. How off-spec looks (DW-O1)

**The tone.** `C.TONE.offspec`, cyan, `{ r = 0.30, g = 0.85, b = 0.85 }`. *Decided:* it gets its own token
rather than reusing `C.TONE.cyan`, which is the Offer button's "your move" colour. The two are close by the
owner's choice, and the token lets them be told apart later without touching Offer.

**The cell.** One branch in `WC.Verdict`. When `eval.verdict == "cantUse"` and `eval.offSpec` is
present, the cell is built from the off-spec result:
- it uses the off-spec glyph and difference (▲ ≈ ▼), in the `offspec` tone for every off-spec verdict;
- its `verdict` is the off-spec verdict, and it carries `offSpec = specID`;
- the main verdict is kept as `mainVerdict = "cantUse"`.

The cell text reads like the main-spec one, followed by the spec name: `▲20 Holy`. In the compact view the
line reads `You 311 ▲20 Holy`. The tooltip says what the main spec cannot do. Example: "Off-spec upgrade
for Holy: Protection cannot use it (its primary stat does not suit the spec). Compared with your best Holy
item: <item> <ilvl>, or an empty slot."

**The gear half.** `SC.Me` shows the off-spec baseline item when the cell is off-spec: the bag or worn item
compared against, or `empty`. A bag item's icon tooltip is read from its link, never from an inventory
slot.

**The arrow and marks.** `TM.Mark`, `TM.ArrowCell` and the glyph tables accept a tone override, so the
off-spec arrow is cyan.

**The detail card.** The FOR YOU box takes its chip and rows from the off-spec result when present:
- the chip is `OFF-SPEC UPGRADE` / `OFF-SPEC SIDEGRADE` / `OFF-SPEC DOWNGRADE`;
- a **Spec** row reads `Holy (off-spec): Protection can't use it`;
- Replaces, Item level, Track and Stats come from the off-spec baseline. A bag item's Replaces row
  sets no `wornSlot`.

The History card does the same from the snapshot.

**History.** `verdictSnap` keeps `offSpec = { specID, verdict, ilvlDelta }` when present, with no
baseline and no reasons, since test_history forbids both. `sameSnap` compares the off-spec part field by
field, so an unchanged off-spec part never reports a change.

**The filter bar** (`modules/WindowFilterBar.lua`). *Decided:*
- The **Upgrades** view and `FB.IsInteresting` count an off-spec upgrade.
- **Usable by me** counts an off-spec upgrade or sidegrade as usable.
- **Gain** sorting uses the off-spec difference below every main-spec upgrade of the same size, so the main
  spec sorts first.
- `LOOTER_GIVES` is unchanged: a looter who cannot use the item on their main spec still counts as giving
  it.

**Legends.** The Me column tooltip and the Offer panel legend add the cyan line: "Cyan: an upgrade for
another of your specs (off-spec); your current spec can't use it."

## 2. Ask, the whisper and the toast (DW-O2)

**Askable.** `M.AskTemplate` checks in this order: the main spec's `upgrade`/`sidegrade` gives `ask`, the
off-spec's `upgrade`/`sidegrade` gives `askOffSpec`, then the transmog fallback, then nil. The one-ask
key is unchanged, so an off-spec ask is still the drop's one ask. The kind stays `ask`, exactly as with the
transmog precedent.

**The template.**
- `C.MESSAGE_TEMPLATES` gains `askOffSpec`.
- The default text is: `Hi {player}, if you don't need {item}, could I have it for my off-spec? It'd be
  +{mygain} for me. No worries if not!`
- A new schema row `messages.templates.askOffSpec` sits after the transmog row. It is editable on the
  Templates tab and has its label, kind name and preview sample in `settings/Editors.lua`.
- No migration is needed, because AceDB backfills the default (the DW-53 precedent).
- The Templates tab's "four messages" wording becomes "five".

**Tokens.** `{mygain}` and the empty-slot "new slot" wording read the off-spec result when the main one is
`cantUse` (`Asks.lua` `gainOf`). One shared helper, `NS.OffSpec.EvalFor(eval)`, returns the off-spec
result when it is the one that counts and the eval itself otherwise, and every gain reader uses it.
*Decided:* no `{spec}` token. It would add an eighth chip and break the pinned token count for little
gain, because the whisper says "off-spec".

**The Ask button tooltip** names the off-spec: "Ask for it for your Holy off-spec."

**The toast.**
- `Toast.Qualifies(drop, minGain)` keeps its two-value contract and adds a third value, `"offSpec"`, when
  it qualifies through the off-spec result. In that case the gain test runs on the off-spec result.
- `Toast.Compose` titles an off-spec toast `Off-spec upgrade for you (Holy)`.
- Its Ask button sends the off-spec template through the same `Asks` path.

**Auto-ask.** `Toast.Qualifies` already makes off-spec upgrades eligible. Main spec goes first:
- `AA.Consider` marks an off-spec pending ask;
- `AA.DueAt` takes an optional lag, and an off-spec ask is due `AA.OFFSPEC_LAG` (5 s) after its main-spec
  due time;
- `AA.Fire` re-arms an off-spec ask while any main-spec ask is still pending.

`minGain` applies to both. *Decided:* there is no separate on/off setting, because the owner wants
off-spec in auto-ask.

## 3. Offer (DW-O3)

`MineCells` gains two candidate statuses, `offSpecUpgrade` and `offSpecSidegrade`, for a candidate whose
main verdict is `cantUse` and whose off-spec verdict is an upgrade or a sidegrade. `RANK` becomes:

| Status | Rank |
|---|---|
| upgrade | 1 |
| sidegrade | 2 |
| offSpecUpgrade | 3 |
| offSpecSidegrade | 4 |
| downgrade | 5 |
| cantUse, doesntWant | 6 |
| unknown | 7 |
| checking | 8 |
| unavailable | 9 |

- Both new statuses are `offerable`.
- `gainOf` reads the off-spec difference, so `byRank` sorts by gain within each tier.
- The candidate cell is cyan with the spec name: `Kaelith 311 ▲14 Holy`.
- **Upgrade for N** and the keep-hidden rule stay main-spec only.
- The Offer whisper is unchanged. The offer text already says the drop is up for grabs, and `{gain}` reads
  the off-spec gain.
- `EXPLAIN` gains: "An upgrade for one of their other specs (off-spec)" and the sidegrade line.

## 4. Samples, docs and smoke checks (DW-O4)

**Test mode.**
- `TD.SESSION` gains an off-spec sample without changing its counts. The Crescent shape goes on an existing
  `cantUse` row, rewritten as `reason = "primaryStat"` with `off = { 65, "upgrade", 20 }`.
- One Offer candidate becomes an off-spec upgrade.
- `TD.HISTORY` gains an off-spec snapshot.
- `TM.GearOf` returns the off-spec baseline gear for an off-spec sample (`testOffGear`).
- `ev` and `cand` read the new `off` tuple.
- The test-mode coverage asserts that an off-spec verdict is shown.

**Docs.**
- `docs/schema.md`: the template row, `feed.view` definitions and the History snapshot.
- `docs/settings-panel.md`: Templates, five messages.
- `docs/data-flow.md`: the evaluation, the tones and the ask precedence.
- `docs/module-map.md` and `ARCHITECTURE.md`'s Module Map: the new `modules/OffSpec.lua`.
- `docs/known-limitations.md`: a looter's off-spec is judged on worn gear only, and off-spec is
  item-level only.
- `docs/scope.md`: the verdicts.
- `README.md`: Me/Them, Offer, toast and auto-ask lines, after a `/humanize` pass.

**Smoke checks**, all pending:
- FEED-80: an off-spec upgrade shows cyan with the spec name, and its detail card shows the off-spec chip
  and Spec row.
- ASK-11: Ask on an off-spec drop sends the off-spec whisper.
- TOAST-5: the off-spec toast title, and auto-ask sends main spec first.
- FEED-81: an off-spec groupmate ranks below main-spec upgrades in the Offer panel.

The Index's Feed row also moves from `FEED-1..78` to `FEED-1..81`; it was already stale, since
FEED-79 exists.

**STATE-3** lists the off-spec verdict among the verdicts test mode shows.

## 5. Review (DW-O5)

The branch diff is reviewed against this spec and the Ka0s standard. Every file stays under 1000 lines,
with no new function above CCN 15. `tests/perf.lua`'s ceilings hold. Fixes land as `DW-O5:` commits. The
README test badge and `docs/test-cases.md` are regenerated.
