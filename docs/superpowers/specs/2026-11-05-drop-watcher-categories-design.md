# DW #13 design: watching non-equipment drops (categories, collection verdict, tier tokens, item lists)

This is the spec for GitHub issue #13, milestone M3 of the run in `docs/superpowers/plans/2026-11-05-issues-10-14.md`. It was written against branch `feat/2026-11-05-issues-10-14` at `280cca2` and checked against the code at `655d19d`. The owner's decisions in that plan bind this spec. Where the spec decides something the owner did not, it says so and gives the reason. Section 15 lists the questions still open for the owner.

---

## 0. Summary

Today the feed watches only gear. `FeedFilter.Filter` reads `feed.gearOnly` (armor and weapons only) and `feed.includeTokens`, and it always drops cosmetics and heirlooms. Tier tokens currently skip the minimum item level check, because `Filter` returns before `ilvlCheck`. This change does five things:

1. **Every watched item gets a category.** The categories are `equipment`, `tierToken`, `mount`, `pet`, `toy`, `recipe` and `cosmetic`. A pure classifier, `NS.Collectibles.CategoryOf(facts)`, reads the item facts. The facts are filled through a new compat file, `core/CompatCollect.lua`.
2. **Seven `feed.categories.<key>` rows replace `feed.gearOnly` and `feed.includeTokens`.** Migration step 13 carries the old values over.
3. **Collectibles get a collection verdict.** Mount, pet, toy, recipe and cosmetic read `newCollect`, `collected` or `collectUnknown`. A recipe for a profession you do not have reads `cantUse`. Collectibles are **feed-only**: no Ask, toast, AutoAsk, Offer, Announce, Post my tradeables or glow, and no inspect is requested for them.
4. **Tier tokens are judged as gear.** ItemFacts works out the slot the token makes, and the kernel compares the token against what you wear in that slot. The existing gear machinery does the work.
5. **Two item-ID lists, `feed.whitelist` and `feed.blacklist`.** They are whole-value `map` rows through the write seam (the architecture-§5 value route). The panel draws them with the LibKa0s IdList control, and the CLI gets `/dw whitelist|blacklist add|remove|list`. An ID cannot sit on both lists, and the blacklist wins at read time.

Category toggles and list changes apply to **drops that arrive from then on**. A drop already in the feed is not filtered again. This matches how every feed filter behaves today, and the panel blurb says so.

---

## 1. Category triage

Enum values are resolved by name through `fromEnum` in `core/Constants.lua`, never by number (compat rules). The numbers in brackets are the current client's values, for reference only.

| Category | In scope | Default | Detection (in precedence order) | Collected or known check (12.x API) | Secret, taint, combat | How it renders |
|---|---|---|---|---|---|---|
| **Tier tokens** | yes (exists today) | **on** (keeps the stored `includeTokens`) | 1. `C.TIER_TOKENS[itemID]`, a curated table. It also covers the omni "Curio" tokens, which carry no class line. 2. The existing rule: a `RestrictedRaceClass` tooltip line (`Compat.ItemClassRestriction`) and no `C.SLOT_PLAN` entry for the client's **raw** `equipLoc`. The class is usually Miscellaneous [15] › Junk [0] or Reagent [1]. | n/a. Judged as gear (section 7). | The tooltip is read through `C_TooltipInfo.GetHyperlink`. A secret line reads as nil and leaves the slot unknown. No protected calls. | Slot column: `Token: Head`. Type column: the class list. Me and Them: the usual ▲ ≈ ▼ cells. |
| **Equipment** | yes (exists today) | **on** | `classID == Enum.ItemClass.Armor [4]` or `Weapon [2]`, and not a tier token. Excluded: `Enum.ItemArmorSubclass.Cosmetic [5]` and any item where `C_Item.IsCosmeticItem(link)` is true. Cosmetic *weapons* are Weapon-class and need the flag check. | n/a (gear verdict) | unchanged | unchanged |
| **Mounts** | yes | **on** | 1. `C_MountJournal.GetMountFromItem(itemID)` answers a mountID. 2. Fallback: `classID == Miscellaneous [15]` and `subClassID == Enum.ItemMiscellaneousSubclass.Mount [5]`, with no journal answer (the verdict is then `collectUnknown`). Mount Equipment [6] is out of scope. | `C_MountJournal.GetMountInfoByID(mountID)`: the 11th return, `isCollected` | Not restricted in 12.0, but every answer is checked with `IsSecret`. Journal data can be missing just after login, which answers nil (`collectUnknown`). The drop is read again on `NEW_MOUNT_ADDED`. | `New` (green) or `Collected` (gray). Slot column `Mount`. |
| **Battle pets / companion items** | yes | **on** | 1. `C_PetJournal.GetPetInfoByItemID(itemID)` answers a `speciesID` (its 13th return). 2. Fallback: Miscellaneous [15] › `CompanionPet [2]`. `Enum.ItemClass.Battlepet [17]` items arrive only as `|Hbattlepet:` links, which never reach the feed, so they are not a detection rung. | `C_PetJournal.GetNumCollectedInfo(speciesID)` gives `numCollected, limit`. `numCollected == 0` is `newCollect`. Above 0 it is `collected`, and the tooltip shows `n/limit`. | As above. Read again on `NEW_PET_ADDED`. | `New` or `Collected 1/3`. Slot column `Pet`. **Limitation:** a caged pet arrives as a `|Hbattlepet:` link, which `LootFeed.validItem` refuses (`notItem`). Only companion *items* are watched. |
| **Toys** | yes | **on** | `C_ToyBox.GetToyInfo(itemID)` answers non-nil. No class rule exists, because toys are spread over many classes and subclasses. The facts are read only after the item is cached, so the cache miss that makes `GetToyInfo` answer nil does not arise here. | `PlayerHasToy(itemID)` (global) | As above. Read again on `NEW_TOY_ADDED`. | `New` or `Collected`. Slot column `Toy`. |
| **Recipes / patterns / formulas** | yes | **on** | `classID == Enum.ItemClass.Recipe [9]`. The subclass (`Enum.ItemRecipeSubclass`) maps to a skill line through `C.RECIPE_SKILL_LINE`: Leatherworking 165, Tailoring 197, Engineering 202, Blacksmithing 164, Cooking 185, Alchemy 171, Enchanting 333, Fishing 356, Jewelcrafting 755, Inscription 773. Book and FirstAid map to nil (First Aid is retired), so the profession is not checked for them. | **Known:** a hyperlink tooltip line whose left text equals the localized `ITEM_SPELL_KNOWN` ("Already known"), read through the existing `Compat.ReadTooltipLine`. **Profession:** `GetProfessions()` gives indices (cooking and fishing included), and `GetProfessionInfo(i)` has `skillLine` as its 7th return. A profession you lack reads `cantUse` with the reason `notYourProfession`. | Tooltip text can be secret under an addon restriction. It then reads as nil (`collectUnknown`). Read again on `NEW_RECIPE_LEARNED` and `SKILL_LINES_CHANGED`. | `New`, `Known`, or `Can't use` (not your profession). Slot column `Recipe`. Type column: the profession. |
| **Cosmetics / transmog-only** | yes | **off** | `Armor [4]` › `Cosmetic [5]`, or `C_Item.IsCosmeticItem(link)` is true on an armor or weapon item. Cosmetics come off `FeedFilter`'s always-out list. | The existing `Compat.PlayerHasTransmog` (CanIMogIt first, then `C_TransmogCollection.PlayerHasTransmogByItemInfo`), through the existing `facts.transmogKnown` | Unchanged. Read again on `TRANSMOG_COLLECTION_UPDATED` (the handler already exists). | `New look` or `Look known`. The detail card reuses the existing transmog chip. |
| Quest starters | **no** (owner) | — | — | — | — | not watched (`notWatched`) |
| Reagents, including high quality | **no** (owner) | — | — | — | — | not watched |
| Containers | **no** (owner) | — | — | — | — | not watched |
| Keystones | **no** (owner) | — | — | — | — | not watched (`Enum.ItemClass.Key [13]`; keystones are `|Hkeystone:` links anyway) |
| Currencies | **no** (owner) | — | — | — | — | never reach the feed: they are not `|Hitem:` loot lines |
| Profession tools and accessories, gems, trade goods, item enhancements, consumables | **no** (implied by the owner's list) | — | — | — | — | not watched. `gearOnly = true` already hides them today. |
| Housing decor (12.x) | **no** (not in the owner's list) | — | — | — | — | not watched. A follow-up candidate. |

**Precedence in `CategoryOf`:** `tierToken`, then `equipment`, then `mount`, then `pet`, then `toy`, then `recipe`, then `cosmetic`, then nil. Cosmetic comes after the collectibles, so a toy or mount that happens to carry the cosmetic flag keeps its own category. Equipment excludes cosmetic-flagged items, so a cosmetic weapon is `cosmetic`, not gear.

**Probe cost.** `ItemFacts.Read` runs the mount, pet, toy and recipe probes only for items that are neither armor nor weapons. The cosmetic flag check runs on armor and weapons. Facts are cached by link, so each link pays once. The recipe "known" read is one more `C_TooltipInfo.GetHyperlink` call, for recipes only. `readClasses` and `ItemPrimaryStats` already read that tooltip for every item. Run `lua tests/perf.lua` before C1's commit to confirm the offline scenarios stay within their budgets.

---

## 2. Compat: `core/CompatCollect.lua` (new)

`core/Compat.lua` is at 999 lines, against the compat family's 1000-line split rule (layout-§1's `Compat<Topic>.lua`), so it must not grow. The new file publishes on `NS.Compat`.

**Load-bearing.** In the TOC, the new file goes after `core/CompatJournal.lua` and before `core/SimSetup.lua`, so the simulator seam wraps its members. `test_sim_e2e` pins this: `NS.SimSeam:Unwrapped()` must be empty. Three places need updating in the same commit:

- the new TOC line, with its own `# LOAD-BEARING:` annotation, worded like the CompatJournal line;
- the TOC annotation above `core\SimSetup.lua`, which names the compat files it wraps;
- the `core/SimSetup.lua` header, which names the same files.

New members:

| Member | Wraps | Absent value |
|---|---|---|
| `Compat.MountFromItem(itemID)` | `C_MountJournal.GetMountFromItem` | nil |
| `Compat.MountCollected(mountID)` | `C_MountJournal.GetMountInfoByID`, 11th return | nil |
| `Compat.PetSpeciesFromItem(itemID)` | `C_PetJournal.GetPetInfoByItemID`, 13th return | nil |
| `Compat.PetCollected(speciesID)` | `C_PetJournal.GetNumCollectedInfo` → `count, limit` | nil, nil |
| `Compat.IsToy(itemID)` | `C_ToyBox.GetToyInfo` is non-nil | false |
| `Compat.ToyCollected(itemID)` | `PlayerHasToy` | nil |
| `Compat.IsCosmeticItem(link)` | `C_Item.IsCosmeticItem` | false |
| `Compat.RecipeKnown(link)` | `Compat.ReadTooltipLine(C_TooltipInfo.GetHyperlink(link), "None", parse)`, where `parse` answers true when the left text **equals** `Compat.GlobalString("ITEM_SPELL_KNOWN")` | nil |
| `Compat.ProfessionSkillLines()` | `GetProfessions` + `GetProfessionInfo` → `{ [skillLine] = true }` | `{}` |
| `Compat.TierTokenSlot(link)` (C4) | `Compat.ReadTooltipLine` over the hyperlink tooltip, rung 2 of section 7.1 | nil |

The rules are `core/Compat.lua`'s:

- Globals are read bare at call time.
- `IsSecret` comes first on every answer.
- No member raises.
- GlobalStrings are read through `Compat.GlobalString`. The `globalString` and `tooltipData` helpers are file-local to `core/Compat.lua` and cannot be reached from here, so the new file calls `C_TooltipInfo.GetHyperlink` itself. That is allowed: it is a compat-family file.

`docs/compat-layer.md` gets a table row for each member. Its count line ("59, 18, 5 and 5") gains "and `core/CompatCollect.lua` 9" in C1, which becomes 10 in C4.

**Standard note (library-stack-§7 / anti-pattern #47).** `RecipeKnown` and `TierTokenSlot` are built on the existing `Compat.ReadTooltipLine`. They are new *consumers* of the tooltip reader the register already ratifies, not new readers, as `ItemClassRestriction` and `GetItemUpgradeInfo` already are. The deviation row's re-check trigger names a second *roster addon*, so it does not fire. The register needs no change. See section 13, flag 1.

---

## 3. Data model

### 3.1 Facts (`modules/ItemFacts.lua`)

New fields on `facts`:

- `category`: `"equipment" | "tierToken" | "mount" | "pet" | "toy" | "recipe" | "cosmetic" | nil`.
- `collect`: `{ kind, mountID?, speciesID?, known = true|false|nil, count?, limit?, skillLine?, hasProfession? } | nil`. It is filled for collectibles only. Like `transmogKnown`, it is dynamic and is read again on collection events (section 4.6).
- `tokenSlot`: an `INVTYPE_*` value, `"any"` or nil. `tokenSlotSource` says `"table"` or `"tooltip"`.
- `rawEquipLoc`: the client's own `equipLoc`, kept on every item.

**The order inside `IF.Read` is load-bearing:**

1. Build the facts with `equipLoc = info.equipLoc`, set `rawEquipLoc = info.equipLoc`, and read `transmogKnown` from the raw slot. A token has no appearance.
2. `readClasses` sets `isTierToken` from the **raw** `equipLoc` (unchanged rule), or to true when `C.TIER_TOKENS[itemID]` lists the item. The second case covers the Curio tokens, which have no class line.
3. `NS.TierTokens.SlotOf(facts)` (C4) sets `tokenSlot`. For a **concrete** slot, ItemFacts then sets `facts.equipLoc = tokenSlot`. The kernel's header already documents this: "A tier token's equipLoc is the slot the token makes." The quality gate's `dynamicSlot`, the Slot column, the Me and Them gear cells, the SideCells grid, the toast's slot text, the ask template's slot text and the detail card then all work unchanged.
4. `NS.Collectibles.Read(facts)` fills `category` and `collect` through Compat. It is an **edge** function: it calls Compat. ItemFacts, currently 295 lines, stays small.

**The transmog handler.** `NS.addon.OnTransmogCollectionUpdated` today reads `readTransmog(link, facts.equipLoc)`. It must read `facts.rawEquipLoc`. Otherwise, after the override, a token would be asked about the appearance of the slot it makes.

**The cache's write contract.** "The tables answered are the cache's own: read them, never write them." Only ItemFacts writes cached facts. The collection re-read is therefore `IF.RereadCollections()` in ItemFacts. It runs `Collectibles.Read` again on every cached collectible, as the transmog handler does for `transmogKnown`. `Collectibles` calls it and never writes facts itself.

### 3.2 Verdicts (`NS.Collectibles.Verdict(facts, forced)`, pure)

`rec.me` for a collectible is:

```
{ verdict = "newCollect" | "collected" | "collectUnknown" | "cantUse",
  equip = "collect", collect = true, category,
  count?, limit?, reasons = { { key = ... } } }
```

The reason keys are `collectNew`, `collectKnown`, `collectNoAnswer`, `notYourProfession`, `petPartial` (with a `count/limit` detail) and `whitelisted`. `rec.them` stays nil and `rec.candidates` is `{}`.

An item that is whitelisted but has no category (for example a reagent) gets `{ verdict = "unknown", equip = "collect", collect = true, reasons = { { key = "whitelisted" } } }`. It is shown, and it is feed-only.

**Tones** go in a `CollectCells` table, not in WindowCells' `VERDICT_TONE`:

- `newCollect` uses `good` (green).
- `collected` uses `bad`, the gray tone `doesntWant` already uses (see Q1).
- `collectUnknown` uses `muted`.
- `cantUse` keeps `redMuted`.

There is no new glyph. The cells show words (`New`, `Collected`, `?`), because the mono face has no glyph we can rely on for these.

### 3.3 History snapshot (`modules/History.lua`)

- **The entry** gains `category` (nil on old entries, which read as `equipment`) and `tokenSlot`. `H.Snapshot` sets both from `rec.facts`. `equipLoc` already stores the token's made slot, through the override.
- **`verdictSnap` must grow.** Today it keeps only `verdict`, `ilvlDelta`, `scoreDelta` and `offSpec`, so a stored collectible would lose `collect`, `count`, `limit` and the `notYourProfession` reason. It gains `collect = eval.collect or nil`, `count`, `limit` (plain numbers only), and `reasonKey` for `notYourProfession`. `sameSnap` compares one level of fields, so the new scalar fields need no change to it.
- **History cells** key on `entry.category` and `me.collect`. They never assume a collectible has a live `rec.me`.
- **The format:** `v` stays 1. The fields are additive and `Normalize` tolerates their absence.
- **#12 (Insights)** needs `category` to break drops down by category, so `category` is mandatory on every new entry.
- **Re-judging:** an entry keeps the verdict the drop had while it was live in the session, including re-reads during that session. Older entries are a record and are not judged again.

---

## 4. The feed pipeline

### 4.1 `FeedFilter.Filter(facts, cfg, ctx)`, the new order (pure)

The signature stays `pass, reasonKey`, plus a **third return value**, `forced` (true when the whitelist let the item through). `Filter` does not write to `ctx`.

1. Not a table: pass (unchanged: facts that could not be read pass).
2. `cfg.blacklist[itemID]`: hide with reason `blacklist`. This beats equipment and the whitelist, and covers an overlap that slipped in through a profile copy.
3. `cfg.whitelist[itemID]`: answer `true, nil, true`.
4. Heirloom: hide with reason `heirloom`. This stays always-out, but the whitelist beats it (section 4.2).
5. `category == nil`: hide with reason `notWatched`. This replaces `notGear`.
6. `cfg.categories[category] == false`: hide with reason `category`. FeedCounts logs `category=<key>`.
7. `equipment` or `tierToken`: run `ilvlCheck`. Tier tokens now have a meaningful level, so the minimum item level applies to them too (Q3). Collectibles skip it: a mount's item level is meaningless.

The reasons `cosmetic`, `token` and `notGear` leave the set. The words for hidden reasons live in `modules/SimReport.lua`'s reason map and in the reason list of the `modules/FeedCounts.lua` header. `docs/module-map.md` follows. `WC.HiddenLines` shows the **filter bar's** reasons (`FB.ReasonLabel`), not the feed's, so it does not change.

In `LootFeed.judge`, the third value is stored as `rec.forced`.

### 4.2 What the whitelist overrides (decided here, as the owner asked)

The whitelist **does** override the category toggles, the heirloom always-out rule, the minimum item level and the quality gate. All four answer the question *what* to watch, and the whitelist is the player's explicit answer for one item.

The whitelist **does not** override:

- the situation gate. That answers *where* to watch, a context the player also set explicitly. Overriding it would leak solo or PvP drops into a feed the player switched off there.
- the blacklist (exclusive, and it wins).
- the stand-down.

Restored drops (`source == "restore"`) and test drops skip `FeedFilter`, as they do today. A drop restored after a reload is therefore not hidden by a blacklist entry added since.

### 4.3 The quality gate

- `QualityGate.Passes` treats `ctx.verdict == "newCollect"` like `upgrade` for `feed.quality.upgradeOverride`.
- `ctx.forced` (from `rec.forced`, passed in `LootFeed`'s `qualityGate`) answers `true, threshold, "whitelisted"`.
- Collectibles have no slot. In `dynamicSlot` mode, `planQuality` answers nil, so the threshold is the floor with the source `emptySlot`. That is the existing behavior when there is no `equipLoc`, though the readout's word is slightly off. In `dynamicCharacter` mode, a collected collectible below your gear's quality is hidden, and a new one passes through the override.
- The row's tooltip changes to: "A drop below the minimum still shows when it is an upgrade for you or new to your collection."

### 4.4 `LootFeed` (keep the diff small: the file is at 1041 lines, on notice)

- **`LF.Config`** gains `categories` (a loop over `C.CATEGORIES` reading `feed.categories.<key>`, shaped like `tradeRules()`), `whitelist` and `blacklist`. `gearOnly` and `includeTokens` go.
- **`judge`** stores `rec.forced` from `Filter`'s third return value.
- **`judgeMe`** is the one hook. If `NS.Collectibles.IsCollectible(rec.facts)` is true, or the item is uncategorized and `cfg.whitelist[itemID]` is set, then `rec.me = NS.Collectibles.Verdict(rec.facts, forced)`. Otherwise it evaluates as today. `judgeMe` reads `rec.forced`, the Always watch answer the drop was admitted with, so every later re-judge (the score retry, `OnGearChanged`, `LF.Refresh`, a restored drop) keeps it; a list change applies to new drops only (M3 review, 32d84f6).
- **`judgeCandidates`** gets a guard: when `rec.me.collect`, set `rec.candidates = {}` and request nothing. `judgeCandidates` is reached from `judgeLooter` and also from `reestimate`, when your own drop's trade moves off `no`. A guard only in `judgeLooter` would miss the second path.
- **`judgeLooter`**: when `rec.me.collect` on someone else's drop, request no looter inspect and leave `rec.them` nil.
- **`estimate`** passes `ctx.collectible = rec.me and rec.me.collect`.
- **`mayChange`** excludes *other players'* collectibles (`not rec.isMine and rec.me.collect`). Their `unknown` trade would otherwise keep the 30-second trade sweep ticking for the whole session. Your own collectibles stay in the sweep, so the trade timer's exact read (`FoldTimer`, basis `timer`) shows whether your mount can really be traded. That read is also the in-game evidence for `COLL-6`.

### 4.5 Trade (`modules/TradeRules.lua`, pure)

With `ctx.collectible`, the estimate keeps its order: the bind checks (warbound `no`, bonus roll `no`, BoE `yes`), then the rule's `legacy`, `expired` and `groupLoot` answers. The **looter's item-level check alone** is replaced by `unknown`, reason `collectible`, basis `rule`. It makes no `likely` claim we cannot back. Your own drop's timer fold then overrides with the exact window when one is read.

### 4.6 Reading collections again (`modules/Collectibles.lua`, edge half)

- **Events.** The module adds rows to `NS.FEATURE_EVENTS` for `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, `NEW_TOY_ADDED`, `NEW_RECIPE_LEARNED`, `SKILL_LINES_CHANGED` and `PLAYER_REGEN_ENABLED`. The dispatcher already fans one event out to several handlers: `PLAYER_REGEN_ENABLED` already has rows from `core/DropWatcher.lua`, Gear and Inspect. `TRANSMOG_COLLECTION_UPDATED` stays ItemFacts' handler, which gains a call to `Collectibles.Changed()` after it reads `transmogKnown` again. `PET_JOURNAL_LIST_UPDATE` is not used: it fires too often.
- **The re-read.** The events are coalesced on one `C_Timer.After(0.5)`. When it fires, the module calls `NS.ItemFacts.RereadCollections()`. Then, for each live drop with `rec.me.collect` whose new verdict differs, it calls the existing **`LF.Refresh(rec, "collection")`**. That already re-requests the cached facts, runs `judgeMe` and `judgeLooter` through `rejudge`, and sends `DropUpdated(id, "collection")`. No new `LF.Rejudge` is needed. The regen pass handles only drops still at `collectUnknown`.
- **Consumers.** History, Toast, AutoAsk and Window consume `DropUpdated` without branching on the cause, so the new cause needs no consumer change.
- **The stand-down** cancels the timer (an `NS.STAND_DOWN` row).
- **Docs.** `docs/ARCHITECTURE.md`'s message table gains the `collection` cause.

---

## 5. Settings, migration, CLI

### 5.1 Rows

All rows are written through `NS.SchemaRuntime.Set`. Their defaults live in `defaults/Profile.lua` under `feed.categories`, `feed.whitelist = {}`, `feed.blacklist = {}` and `feed.view.newCollect = false`. The rows are declared in `settings/SchemaRows.lua`'s `feed()` maker (page `feed`, titled Drops). A row's `group` is its tab.

| Path | Type | Default | Page › tab (group) › subgroup | Label | Tooltip |
|---|---|---|---|---|---|
| `feed.categories.equipment` | bool | true | Drops › Items › Item kinds | Equipment | Armor, weapons, jewelry and trinkets. |
| `feed.categories.tierToken` | bool | true | same | Tier tokens | Tokens you turn in for a tier piece, judged against what you wear in that slot. |
| `feed.categories.mount` | bool | true | same | Mounts | Mount items, marked new or already collected. |
| `feed.categories.pet` | bool | true | same | Battle pets | Companion pet items, marked new or already collected. |
| `feed.categories.toy` | bool | true | same | Toys | Toys, marked new or already collected. |
| `feed.categories.recipe` | bool | true | same | Recipes and patterns | Recipes, patterns and formulas, marked new or known, and can't use when you lack the profession. |
| `feed.categories.cosmetic` | bool | **false** | same | Cosmetics | Cosmetic armor and weapons: a look to collect, never gear. |
| `feed.whitelist` | map `{[itemID]=true}` | `{}` | Drops › Item lists | Always watch | The items always watched, whatever their kind. |
| `feed.blacklist` | map | `{}` | Drops › Item lists | Never watch | The items never watched, gear included. |
| `feed.view.newCollect` | bool | false | Window › Starting view › View | New to my collection | A fresh tab lists only the drops new to your collection. With none ticked, a fresh tab lists every drop. |

Collectibles are feed-only, so none of these toggles has an AutoAsk or toast counterpart.

- **Map rows** use the existing `map()` maker (`skipRender = true`). Their `group` is `L["Item lists"]`, and they are declared after the Items rows inside `feed()`. "Within a page, a tab's place in the strip is its first row's place," so the Item lists tab lands after Items and before Retention.
- **Map validation** checks shape only: every key a positive integer, every value `true`. Exclusivity is **not** checked in `validate`. If it were, migration step 2 (`RepairStoredSettings`) would drop a whole list from a hand-edited profile with one overlapping ID. Exclusivity is enforced in the one writer (section 5.3) and at read time (the blacklist wins).
- **Panel layout.** The seven toggles sit in two columns under the existing Item kinds subgroup, replacing Gear only and Include tier tokens.
- **The Item lists tab** is a host tab on the Drops page, in `settings/Pages.lua`: `tabs = { { key = L["Item lists"], render = function(ctx) LE.ItemListsTab(ctx) end } }`. The Drops page has no `tabs` entry today. It carries a secondary strip, **Always watch | Never watch**, through the library's SubTabStrip, with `ctx.activeSubTab[<tab key>]` as session state (options-ui-§13, as in BankLedger's Filters tab). Each sub-tab draws `Settings.Helpers.IdList` with these fields. `Settings.Helpers` *is* the LibKa0s-Options instance, so this is the control BankLedger calls `O.IdList`.
  - `kind = "item"`, `columns = 2`, `removeStyle = "icon"`
  - `label`, and a `tooltip` that names shift-clicking a link
  - `entries = function() return the sorted list as IdList entries end`
  - `candidates`: both lists' IDs plus the live feed's item IDs
  - `strings = { nameHint = ... }`
  - `emptyText`: `NS.SkinPanelEscape("text.disabled") .. "(none)|r"`
  - `onAdd` and `onRemove`, which call `NS.ItemLists.Add` and `NS.ItemLists.Remove`. The page's repaint is held off for the call and a refusal is raised again (the BankLedger `filterWrite` pattern, anti-pattern #39).
  - `ctx.rebuild` pointed at this page's re-render.

  Each blurb closes with: "Applies to drops from now on. An item can be on one list only: remove it from the other first." `O.IdInput`, inside IdList, resolves a shift-clicked link. `H.IdList` and `H.SubTabStrip` already have library-absent stubs in `settings/OptionsSetup.lua`. Any other Helpers member the editor touches needs one too: `test_surface_parity` checks the degradation stubs.
- **The Drops page Defaults button** resets the rest of the page but **keeps both lists**: the two map rows are reset-exempt (run plan, Q9). The Defaults tooltip says "The item lists are kept."

### 5.2 Migration step 13 (`core/Database.lua`)

Take the next free step: 13, unless an earlier item of this run took it. The plan's #14 rows (DW-T2) add no migration. Check `NS.MIGRATIONS` at implementation time. The entry uses the runner's per-profile signature:

```lua
{ to = 13, perProfile = true,        -- 12 -> 13: Gear only and Include tier tokens become the item kinds
  run = function(_, profile) NS.MigrateItemKinds(profile) end },
```

```lua
-- Frozen: the categories as of step 13. A category added later is not turned on by this step.
local STEP13_CATEGORIES = { "equipment", "tierToken", "mount", "pet", "toy", "recipe", "cosmetic" }

function NS.MigrateItemKinds(profile)
    local feed = type(profile) == "table" and profile.feed
    if type(feed) ~= "table" then return end
    local cats = type(feed.categories) == "table" and feed.categories or {}
    if feed.gearOnly == false then
        for _, key in ipairs(STEP13_CATEGORIES) do cats[key] = true end   -- cosmetic too (owner)
    end
    if feed.includeTokens ~= nil then cats.tierToken = feed.includeTokens == true end
    if next(cats) then feed.categories = cats end
    feed.gearOnly, feed.includeTokens = nil, nil
end
```

The key list is a frozen literal, not `NS.Constants.CATEGORIES`, so a later category cannot change what this step did. The step is idempotent. On a fresh profile it does nothing: AceDB strips default values, so only a stored `false` is ever present. `includeTokens` is applied after the `gearOnly` sweep, so a stored `includeTokens = false` still turns tokens off. `test_database` already pins `SCHEMA_VERSION == MIGRATIONS[#MIGRATIONS].to`.

**Behavior notes for the owner:**

1. A profile with `gearOnly = false` used to let every item class through (consumables, reagents and the rest). Out-of-scope classes are now not watched. The owner's out-of-scope list implies this.
2. The same profile now also gets cosmetics turned on. Before, cosmetics were always out. This follows "every category on".
3. A profile imported later from a backup made before step 13 keeps an orphaned `gearOnly` key that nothing reads. That is harmless.

### 5.3 The one list writer and the CLI

A new module, `modules/ItemLists.lua`, is the only writer of the two lists. The panel and the CLI share it, so anti-pattern #78 does not apply.

- `IL.Add(list, id)` answers `ok, why`. `why` is one of:
  - `badId`
  - `already`
  - `onOther`: "That item is on Never watch: remove it there first." (or the reverse, as the owner decided: refuse, never move)

  On success it copies the list, sets `[id] = true`, and writes the whole value through `NS.SchemaRuntime.Set("feed.whitelist" | "feed.blacklist", copy)`.
- `IL.Remove(list, id)` answers `ok`, or `notListed`.
- `IL.List(list)` answers the sorted IDs.
- `IL.Contains(list, id)`.
- `IL.ParseId(text)` accepts a number, an `|Hitem:` link or `item:<id>`, read through `NS.Item.ItemIDFromLink` (it matches `|?H?item:(%d+)`), else `tonumber`.

The panel's `onAdd` raises `error(msg, 0)` on a refusal. IdList then keeps the typed text and prints the line.

CLI verbs are added to `NS.COMMANDS` in `settings/Slash.lua` and answered in `settings/SlashVerbs.lua`. They are feature verbs, so the dispatcher refuses them while the addon is disabled (slash-commands-§2). No live verb is added, so there is no deviation.

- `/dw whitelist add <id|link>`, `/dw whitelist remove <id|link>`, `/dw whitelist list` (a bare `/dw whitelist` lists too)
- `/dw blacklist add|remove|list`, the same way

`list` prints one line per entry: `12345 [Name]` (the link once cached, else `item 12345`), or `(none)`.

`/dw list` and `/dw get` show the map rows as `{n}` through `Settings.FormatValue`. Whatever `/dw set feed.whitelist …` answers today for a map row stays as it is; pin it in `test_slash`.

`docs/slash-dispatch.md` gets the two verb rows.

---

## 6. Surfaces

### 6.1 Surfaces that learn the collection verdict

A new file, `modules/CollectCells.lua`, follows the pattern of `OffSpecCells.lua`. It keeps `WindowCells.lua` (1165 lines, on notice) from growing. It holds the words, means, tones, chips, the Slot and Type text, and the tooltip rows. `WC.Verdict` delegates to it when `eval.collect`, a three-line hook like the `OffSpec.Of` hook already there.

| Surface | File(s) | What changes |
|---|---|---|
| Feed rows: Me cell | `WindowCells.lua` (`WC.Verdict` hook), `CollectCells.lua` | `New` / `Collected` / `Known` / `Collected 1/3` / `?`. The tooltip title is `For you: New to your collection`. Means and Why rows come from the reasons. |
| Feed rows: Them cell | `WindowCells.lua` (`WC.Them` hook, **before** its `drop.them == nil` branch, which would otherwise show `?` and "waiting (one inspect at a time)") | A dash. Tooltip: "Collectibles are judged for you alone." |
| Your own drop's Details and candidates | `MineCells.lua` (`MC.Details`, `MC.Candidates`) | No `Upgrade for N` and no candidate list. "Collectible: nobody is judged for it." |
| Me and Them gear parts, gear grid | `SideCells.lua`, `WindowCells.lua` `eqSlots` | No slot, so there is nothing to show (dash). A token with a concrete slot works as gear. |
| Slot column | `WC.Slot` → `CollectCells.SlotText` | `Mount`, `Pet`, `Toy`, `Recipe`, `Cosmetic`, `Token: Head`, `Token: any slot` |
| Type column | `WC.ArmorType` → `CollectCells.TypeText` | The recipe's profession. For a token, its classes, colored (`NS.TipMarks.ClassName`). |
| Compact cards | `CompactCards.lua` | **No code change.** `WORD_VERDICT` is what adds the ⊘ glyph, so the new verdicts must stay out of it. `CC.Verdict` passes the cell's text and tone through, so `New` shows in green with no glyph. A test pins that no ⊘ appears. |
| Detail card | `DetailCells.lua` `VERDICT_CHIP` | `NEW TO COLLECTION` / `COLLECTED` / `COLLECTION UNKNOWN`. Collection chip: `Collected 2/3` for pets, and the profession for recipes. A token's chip: `Makes: Head · <classes>`. Cosmetics keep the transmog chip. |
| Row tooltip | `RowTooltip.lua` | A Kind row (the category word), then the collection rows from `CollectCells`. |
| History cards and rows | `HistoryCard.lua`, `WindowHistory.lua` | The same cells, fed from the snapshot (section 3.3). Entries with no `category` read as `equipment`. |
| Filter bar View | `WindowFilterBar.lua`, `settings/SchemaRows.lua` (`VIEW_ROWS`), `defaults/Profile.lua` | `newCollect` is added to `FB.VIEWS`, `ALL_VIEWS`, `FB.HONORS.history.views`, `FB.VIEW_NAMES`, `VIEW_TIP` and `VIEW_PASS`, plus a `VIEW_ROWS` entry and `F.view.newCollect`. `upgrade` fails collectibles. `interesting` fails collectibles explicitly, **before** `FB.IsInteresting`'s `isMine` branch (otherwise your own BoE mount would pass through `TRADEABLE`): the view is the set of drops you can act on, and collectibles have no action. `usable` fails `cantUse` collectibles (wrong profession) and passes the rest. `likely` is unchanged. A category filter belongs to #12 (Insights). |
| Counts and diagnostics words | `FeedCounts.lua` (header), `SimReport.lua` (reason map) | The hidden reasons `blacklist`, `category` and `notWatched` get words. `token`, `cosmetic` and `notGear` go. The diagnostics `Parts` line reads `category=n`, and the FEED debug line names the category key. |
| Drops strip | `DropsStrip.lua` | Its summary counts `n new` for collectibles at `newCollect`, beside the upgrade count. |
| Diagnostics | `Diagnostics.lua` | A `collect:` line with the categories that are on and the list sizes. |

### 6.2 Surfaces that refuse collectibles (defense in depth)

The owner's decision names no Ask, no toast and no AutoAsk. **Decided here:** Offer, Announce and Post my tradeables are refused too, because "feed-only" leaves a collectible with no action at all (Q8).

| Surface | Where | Refusal |
|---|---|---|
| Ask button | `WindowCells.lua` local `noAskReason` (right after the `isMine` check, before the trade check) | No action. Why: "collectibles are watched, not asked for" |
| Ask template | `Messaging.AskTemplate` | Answers nil when `drop.me.collect`. This also blocks the transmog fallback for cosmetics. |
| Send seam | `Asks.Request` / `Asks.Press` | Refuses the kinds `ask`, `offer` and `announce` with `collectible` for a drop whose `me.collect` is set. Debug line under `ASK`. |
| Toast | `Toast.Qualifies` | `false, "collectible"` as its first check after `mine`, so the queued revalidation drops it too |
| AutoAsk | through `Toast.Qualifies` | `notQualifying`. A test pins it. |
| Offer panel | `OfferPanel.lua` local `noOffer`, `OP.Open` | The panel does not open. `/dw offer` prints "Collectibles are watched, not offered." |
| Own-drop Offer and Announce | `MineCells.lua` (`MC.OwnOffer`, `MC.AnnounceButton`'s caller) | No action, with the same reason |
| Post my tradeables | `FB.IsTradeableMine` | Excludes collectibles |
| Upgrade glow | `Glow.lua` | No code change: the verdict is never `upgrade`. A test pins it. |

Tier tokens are **not** refused. They are judged as gear, so Ask, toast, AutoAsk and Offer work for them as they do for gear.

---

## 7. Tier tokens (DW-CAT4)

### 7.1 Which slot the token makes (`NS.TierTokens.SlotOf`, called from ItemFacts)

The rungs run in order, and the first that answers wins:

1. **The curated table.** `C.TIER_TOKENS[itemID] = { slot = "INVTYPE_HEAD" | … | "any" }` in `core/Constants.lua`. It is data, kept up per season. `docs/common-tasks.md` gets an "Add a season's tier tokens" task. The `any` value covers the omni Curio tokens, which have no class line, and makes them tier tokens even though `classes` is nil (section 3.1, step 2).
2. **The tooltip.** `Compat.TierTokenSlot(link)`, through `Compat.ReadTooltipLine`: a tooltip line whose left text **equals** one of the localized `INVTYPE_HEAD`, `INVTYPE_SHOULDER`, `INVTYPE_CHEST`, `INVTYPE_HAND` or `INVTYPE_LEGS` GlobalStrings. It is matched as a whole string, never as a substring of arbitrary lines. Whether the client's token tooltip carries such a line is smoke check `ITEM-6`. If it does not, this rung returns nil and stays inert.
3. **Nothing.** `tokenSlot = nil`. The verdict stays the kernel's `unknown` with the reason `tierToken`, as today.

**Amendment 2026-11-05 (TT-1, owner request): the slot read from the token's own text, no per-season table.** The rungs above are replaced by these, the first that answers winning, each naming itself as `tokenSlotSource`:

1. **`table`.** `C.TIER_TOKENS[itemID]`, unchanged in shape, is now an override for an oddity the text misreads, empty by default and no longer kept up per season.
2. **`use`.** The token's Use text (`Compat.ItemUseText`: `C_Item.GetItemSpell` and `C_Spell.GetSpellDescription`, else the tooltip's line behind `ITEM_SPELL_TRIGGER_ONUSE`), read once when the facts are built, for an item that is not gear only. It must carry the class phrase `appropriate for your class` and `set <slot> item` as whole words, case-insensitively, any raid name before `set` allowed (Midnight's `Create a soulbound set hand item appropriate for your class.`, `Synthesize a soulbound Manaforge Omega set leg item ...`); `head`, `shoulder(s)`, `chest`, `hand(s)`, `leg(s)` map to the five tier slots. When the Use text names none, the old tooltip read (`Compat.TierTokenSlot`, a line that equals a localized slot name) runs as this rung's second read.
3. **`name`.** A slot noun in the item's name as a whole word (`Gauntlets of the Foreseen Conqueror`: hand; `Helm of the Forgotten Vanquisher`: head; `Shoulders of the Foreseen Protector`: shoulder), for the older class-group tokens whose Use text names no slot (`Create a soulbound Tier 19 item appropriate for your class.`). Cloak tokens are not a tier slot here.
4. **`any`.** Nothing read: `tokenSlot = "any"`, judged by `NS.TierTokens.Fold` across the five tier slots, as a Curio is. The `unknown` / `tierToken` verdict stays only for facts without a slot (an old History entry). The Slot cell reads `Token: any slot`.

Which item is a token (section 3.1) widens, every earlier rule kept: an item that is not gear is also a token when its Use text carries the class phrase without a parsed class line, or when it is an omni Curio, an epic-or-better (quality 4+) Miscellaneous or Reagent item whose name ends with the word `Curio` (judged `any`, every class). Gear, recipes, mounts, pets, toys and a Curio-named item below epic are not tokens. Every word (the class phrase, the template, the slot words, the name nouns, `Curio`, the `Use:` fallback) lives in the enUS locale table (`locales/enUS.lua`), parsed by `core/TextParse.lua`: a documented localization-§4 deviation (`docs/ARCHITECTURE.md`, Documented deviations), which degrades on another locale to every token judged `any`, and no Curio seen without an override. The diagnostics' drop line names a token's slot and source. Smoke check `ITEM-6` is rewritten for it.

### 7.2 The verdict (`modules/Evaluate.lua`, plus the pure `modules/TierTokens.lua`)

- **Class.** If `facts.classes` lacks the candidate's class, the verdict is `cantUse` / `classRestricted` (existing code).
- **`usable()` changes.** Its `isTierToken` branch today answers `ok` only when `classes` is a table, else `unknown` / `tierToken`. It must also answer `ok` when `facts.tokenSlot` is set. Otherwise a Curio (no class line) never gets past step 1.
- **A concrete slot.** `equipLoc` is already the slot (section 3.1), so `usable` answers `ok`, and `compare` and `planFor` run unchanged against `SLOT_PLAN[equipLoc]`. The token's piece suits the class, so armor type and primary stat are not checked: the branch returns before them, as today.
- **The scorer is skipped.** Pawn cannot value a token. The skip lives inside `compare`: `out.scoreDelta = not facts.isTierToken and scoreDelta(...) or nil`. The kernel is pure and must not mutate the caller's `opts`. The verdict comes from item level alone, with the sidegrade band.
- **`any` (Curio).** At the start of `run`, `if facts.tokenSlot == "any" and NS.TierTokens then return NS.TierTokens.Fold(facts, candidate, opts, run) end`. This is read at call time, like the `NS.OffSpec.Attach` hook. `Fold` runs the kernel once per tier slot (`C.TIER_SLOTS`: head, shoulder, chest, hands, legs), each on a shallow copy of the facts with that `equipLoc`. It keeps the best answer: upgrade beats sidegrade beats downgrade, then the largest `ilvlDelta`, using `OffSpec`'s RANK idiom. The chosen slot is set as `out.tokenSlot`, and the Me cell names it ("best in Legs"). The cache's facts table is never written.
- **Item level.** `levelOf` already falls back to the detailed level for non-gear. A token with no level reads `unknown` / `noIlvl`.
- **The looter and candidates** are evaluated on their own class and inspected gear through the same `Evaluate`. Them, the Offer candidates, the trade estimate's looter check, the toast and the ask template's slot text (`slotText(equipLoc)`) all work.
- **The `tierToken` reason text** in `WindowCells.lua`'s `EVAL_REASON` ("a tier token whose slot is not read yet") changes to "a tier token whose slot could not be read".
- **`docs/known-limitations.md`.** The tier-token bullet changes from "slot not read" to "slot read from a per-season table and the tooltip; an unlisted token whose tooltip names no slot stays unknown".

---

## 8. Simulator and test mode (DW-CAT6)

- **SimPool.** It drops non-gear journal entries today (`C.SLOT_PLAN[e.equipLoc]` filters, lines 121 and 152). It now keeps them in an `extras` bucket keyed by category: `EJ_GetLootInfoByIndex` lists mounts, pets, toys and recipes with an empty slot. `P.COLLECTIBLE_SAMPLES` is a curated item-ID list per category, plus tier tokens, used when the journal yields none. **Verify every ID in the client with `/dw add item:<id>` at implementation.** IDs must not be guessed into the code. Sim drops run through the real engine, so their facts come from ItemFacts and CompatCollect. The seam's live fallback answers the collection reads.
- **SimEvents loot bursts.** `E.Plan` draws one drop in eight from `extras` when it is non-empty, through the simulation's own random source.
- **A new host verb.** `/dw sim drop <category> [player|me]`, where the category is one of `equipment`, `token`, `mount`, `pet`, `toy`, `recipe` or `cosmetic`. It is parsed and run in `settings/SimVerbs.lua`, with its `USAGE` and `WHY` lines. It answers `noSample` when neither the pool nor the curated list has an entry for the category. The SimVerbs header's "five verbs" becomes six, and `docs/slash-dispatch.md`'s `sim` row and `docs/ARCHITECTURE.md`'s simulator section follow.
- **TestData and TestMode.** Test drops are never judged ("verdicts … are the spec's"), so each new row supplies its own `me` through TestData's `ev`, extended to carry `collect`, `category`, `count` and `limit`. Its facts carry `category` and `collect`, as rows already set `transmogKnown` through `row.look`. Six new sample rows:
  - a mount at `newCollect`, looted by someone else (its Ask reads No action)
  - a pet at `collected 1/3`
  - a toy at `collectUnknown`
  - a recipe at `cantUse` / `notYourProfession`
  - a cosmetic with a New look (its Ask must not offer the transmog ask)
  - a tier token: Head, ▲ +7, Ask offered

  The test history log gains one group with a `newCollect` entry and a `collected` entry.

---

## 9. Tests per file

New suite files must be added to the explicit list in `tests/run.lua`, which `Kit.assertSuiteInventory` checks in both directions. `test_compat` (1053 lines) and `test_settings_pages` (1052 lines) already sit in the 1000–1500 band, so the new cases go in new files.

| File | Cases |
|---|---|
| `tests/wow_mock_collect.lua` (new helper, loaded from `wow_mock.lua`, which is at 991 lines) | `C_MountJournal`, `C_PetJournal`, `C_ToyBox`, `PlayerHasToy`, `C_Item.IsCosmeticItem`, `GetProfessions` / `GetProfessionInfo`, `ITEM_SPELL_KNOWN` tooltip lines, the `NEW_*` and `SKILL_LINES_CHANGED` events, and the `Enum.ItemClass.Recipe`, `Enum.ItemMiscellaneousSubclass` and `Enum.ItemRecipeSubclass` values |
| `tests/test_compat_collect.lua` (new) | Every member: its answer, its absent value with the API missing, a secret answer reading nil, no raise. The recipe known line matched only by full text. The token slot line matched only by full text. |
| `test_sim_e2e.lua` | Unchanged. `Unwrapped()` stays empty with the new file (the TOC order guard). |
| `tests/test_collectibles.lua` (new) | `CategoryOf`: each category; the precedence (a toy flagged cosmetic stays a toy, a cosmetic armor or **weapon** is not equipment, a tier token beats equipment); out-of-scope classes answering nil. `Verdict`: new, collected, unknown, pet partial, recipe without the profession, whitelisted with no category. The collection events: coalescing into one re-read, `IF.RereadCollections` the only cache writer, `LF.Refresh(rec, "collection")` sending `DropUpdated(id, "collection")` only for a moved verdict, the regen pass for `collectUnknown` only, a stand-down cancelling the timer. |
| `tests/test_item_lists.lua` (new) | `ParseId` (number, link, `item:`, garbage). Add, Remove, List. The `onOther` refusal both ways, `already`, `notListed`. Writes go through the seam (spy on `SchemaRuntime.Set`) as whole values copied on write. CLI output lines. The verbs refused while disabled. The panel's `onAdd` raising on a refusal. |
| `tests/test_item_lists_panel.lua` (new) | The Item lists host tab placed after Items, its secondary strip and `activeSubTab` healing, IdList drawn with `entries` / `candidates` / `onAdd` / `onRemove`, one repaint per add (`filterWrite`), the Defaults button keeping both lists (Q9). |
| `tests/test_tier_token.lua` (new) | Slot from the table and from the tooltip; none leaving `unknown`; a concrete slot giving upgrade, sidegrade or downgrade against worn gear; the wrong class giving `cantUse`; a Curio with no class line reaching `ok`; the `any` fold picking the best slot; the scorer skipped and the caller's `opts` untouched; the looter's Them verdict; the facts cache untouched. |
| `test_feed.lua` | The new `FeedFilter` order: the blacklist beats the whitelist and equipment; the whitelist beats category, heirloom, min ilvl and quality, and answers `forced`, but not the situation gate; a category off giving `category`; no category giving `notWatched`; min ilvl applying to tokens and not to collectibles. `judgeCandidates` requesting no inspect for your own collectible, including through `reestimate`. `mayChange` keeping your own collectible and dropping others'. Replace the `gearOnly` and `includeTokens` cases (lines 534–538). |
| `test_item_facts.lua` | `category`, `collect`, `tokenSlot` and `rawEquipLoc` filled; a token's `equipLoc` override; `isTierToken` from the raw slot; `transmogKnown` read from the raw slot, also in `OnTransmogCollectionUpdated`; collectible probes not run for armor or weapons, while the cosmetic flag check is. |
| `test_evaluate.lua` | The token path. Keep the current case at line 592 (class list, `INVTYPE_HEAD`). |
| `test_gear.lua` | Line 213 (`isTierToken` on a class-restricted non-gear link) still holds. |
| `test_quality_gate.lua` | `newCollect` honoring `upgradeOverride`; a forced drop answering `whitelisted`. |
| `test_trade_rules.lua` | `ctx.collectible`: BoE `yes`, warbound `no`, legacy and expired kept, otherwise `unknown` / `collectible` instead of the looter check. |
| `test_feed_counts.lua`, `test_sim_report.lua` | The new reasons and their words. Rewrite line 140 (`gearOnly = false`) on `categories`. |
| `test_database.lua` | Step 13: `gearOnly = false` turning all seven on (cosmetic included); `includeTokens = false` carried over, also beside `gearOnly = false`; both keys removed; idempotent; a fresh profile untouched; every stored profile visited. |
| `test_schema_rows.lua` | The new paths in the inventory (line 24), their types and defaults (lines 506–507 replaced), map shape validation refusing bad keys and values, `feed.view.newCollect`. |
| `test_settings_pages.lua` | Rewrite lines 835–843 on a category row. The panel cases themselves go in `test_item_lists_panel.lua`. |
| `test_toast.lua`, `test_auto_ask.lua`, `test_messaging.lua`, `test_asks.lua`, `test_offer_panel.lua`, `test_own_drops.lua`, `test_mine_cells.lua`, `test_glow.lua`, `test_transmog.lua` | Each refusal in section 6.2, cosmetics included (no transmog ask). A tier token still qualifies. |
| `test_history.lua`, `test_history_card.lua` | `category`, `tokenSlot`, `collect`, `count` and `limit` in the snapshot; the collection verdict refreshed on `DropUpdated`; old entries reading as equipment. |
| `test_window.lua`, `test_window_group.lua`, `test_side_cells.lua`, `test_compact_cards.lua` (no ⊘ on the new words), `test_detail_card.lua`, `test_row_tooltip.lua`, `test_drops_strip.lua`, `test_diagnostics.lua` | Each cell and chip in section 6.1, the `WC.Them` dash, the `newCollect` view and the other views' answers for collectibles (`interesting` failing your own BoE mount). |
| `test_sim_pool.lua`, `test_sim_events.lua`, `test_test_mode.lua` | The `extras` bucket and the fallback samples, the burst mix, the `drop <category>` verb and its refusals, the test-mode rows. |
| `test_slash.lua` | The `whitelist` and `blacklist` verbs in `NS.COMMANDS` and in help; refused while disabled; `/dw get feed.whitelist` printing `{n}`. |
| `test_locale.lua`, `test_surface_parity.lua` | Run unchanged. `test_locale` catches missing `L[...]` entries. `test_surface_parity` checks that every Helpers member the new editor touches has a library-absent stub. |

---

## 10. Docs to update

| Doc | Update |
|---|---|
| `docs/ARCHITECTURE.md` | Module Map: `CompatCollect`, `Collectibles`, `CollectCells`, `TierTokens`, `ItemLists`, `ListEditors`. Settings Schema: the two lists as **values** on the whole-value route, with `NS.ItemLists` as the writer both surfaces share. Slash Commands table. Event Subscriptions (the `NEW_*` events, `SKILL_LINES_CHANGED`, the extra `PLAYER_REGEN_ENABLED` row). The `DROP_UPDATED` row's `collection` cause. Known Limitations (caged battle-pet links). The simulator verb count. |
| `docs/schema.md` | Line 108 replaced by the seven category rows, the two lists (the value route) and `feed.view.newCollect`; migration step 13. |
| `docs/settings-panel.md` | Line 205: Drops › Items › Item kinds gets seven toggles. A new Drops › Item lists tab with its secondary strip. The Drops Defaults tooltip. |
| `docs/data-flow.md` | The new filter order and `forced`, the collectible judge path (no inspect, no candidates, the trade sweep), the collection re-read, the refusals. |
| `docs/module-map.md` | Rows 40 (FeedFilter), 42 (FeedCounts reasons), 43 (Messaging), 49 (ItemFacts), plus the new modules. |
| `docs/compat-layer.md` | The CompatCollect member table and the counts. |
| `docs/slash-dispatch.md` | The `whitelist` and `blacklist` rows; `sim`'s six host verbs. |
| `docs/known-limitations.md` | The tier-token bullet (section 7.2), caged pets, recipe "known" depending on the `ITEM_SPELL_KNOWN` GlobalString, list and toggle changes applying to new drops only. |
| `docs/midnight-quirks.md` | Any secret or missing answer the smoke round finds on the new APIs. |
| `docs/scope.md` | The watched categories and the out-of-scope list. |
| `docs/common-tasks.md` | "Add a season's tier tokens" (`C.TIER_TOKENS`, checked with `/dump`). |
| `docs/testing.md`, `docs/test-cases.md` | The new suites and cases. |
| `docs/smoke-tests.md` | A new `## Collectibles` section (`COLL-1` to `COLL-8`) with its Index row; `ITEM-6` and `ITEM-7` under Item facts (the Index row's range becomes `ITEM-1..7`); SIM and SLASH rows for the new verbs. Details below. |
| `README.md` | Features and Usage: the categories, the lists, the new verbs. |
| Locales | `enUS.lua` (cell words, reason words), `enUS_Settings.lua` (rows, tab, blurbs), `enUS_Tooltips.lua` (means and why rows). They must pass `test_locale` and the prose checks (`tests/prose_waivers.lua`). |

The smoke-test checks:

- **COLL-1:** the `/dump` shapes of each new Compat API.
- **COLL-2:** a mount drop at `newCollect`; learning it flips the verdict to `collected`.
- **COLL-3:** a pet's count.
- **COLL-4:** a toy.
- **COLL-5:** a recipe, known, and one without the profession.
- **COLL-6:** the tradeability of a bound collectible: your own drop's trade timer read, and someone else's `unknown`.
- **COLL-7:** the whitelist and blacklist from the panel (shift-click) and the CLI; the refusals; the blacklist hiding gear; the Defaults button keeping both (Q9).
- **COLL-8:** each `/dw sim drop <category>`, and test mode's rows.
- **ITEM-6:** what the token's tooltip carries.
- **ITEM-7:** a token judged against your worn piece; a Curio's best slot.

---

## 11. Implementation breakdown

Each item is one commit that passes the gate, with the subject opening `DW-Cn: `. They run in order.

The original C3 touched about 20 modules and their suites, too much for one reviewable commit, so it is split. This needs **one new row in `items.tsv`, `DW-CAT7`**, and two dependency corrections. Those are the orchestrator's edits:

- `DW-CAT7`: milestone M3, depends on `DW-CAT3`.
- `DW-CAT4` depends on `DW-CAT3`, not `DW-CAT2`: it extends `CollectCells`.
- `DW-CAT5` depends on `DW-CAT3`: the whitelisted uncategorized verdict needs `CollectCells` to render.
- `DW-CAT6` depends on `DW-CAT3,DW-CAT4,DW-CAT5,DW-CAT7`.

**DW-CAT1: triage, detection, Compat**
- Add `core/CompatCollect.lua` (nine members: everything but `TierTokenSlot`), with its TOC line before `core/SimSetup.lua` and its LOAD-BEARING annotation. Update the SimSetup TOC annotation and the `core/SimSetup.lua` header.
- `core/Constants.lua`: `ITEM_CLASS.RECIPE`, `MISC_SUBCLASS`, `RECIPE_SUBCLASS`, `RECIPE_SKILL_LINE`, `CATEGORIES` (the ordered `{ key, collectible }` list), `TIER_SLOTS` and an empty `TIER_TOKENS`.
- Add `modules/Collectibles.lua` with `CategoryOf`, `Verdict` and `IsCollectible` (pure) and `Read` (edge), and its TOC line and annotation after `ItemFacts`.
- `modules/ItemFacts.lua`: `rawEquipLoc`, the call to `Collectibles.Read`, the transmog handler on `rawEquipLoc`, and the header comment.
- Tests: `tests/wow_mock_collect.lua`, `tests/test_compat_collect.lua`, `tests/test_collectibles.lua` (the pure half and `Read`), `tests/test_item_facts.lua`, `tests/run.lua`. Run `tests/perf.lua`.
- Docs: `docs/compat-layer.md`, `docs/scope.md` (the triage table).
- No behavior changes yet: the category is computed but not read.

**DW-CAT2: category toggles replacing gearOnly, migration, FeedFilter, CLI parity**
- Rows: `defaults/Profile.lua`, `settings/SchemaRows.lua`.
- The migration step in `core/Database.lua`.
- `modules/FeedFilter.lua`: the category part of section 4.1. The lists come in C5.
- `modules/LootFeed.lua`: `Config` only.
- `modules/FeedCounts.lua` (header) and `modules/SimReport.lua` (reason words).
- `locales/enUS_Settings.lua` and `locales/enUS.lua`.
- Tests: `test_feed.lua`, `test_feed_counts.lua`, `test_sim_report.lua`, `test_database.lua`, `test_schema_rows.lua`, `test_settings_pages.lua`.
- Docs: `docs/schema.md`, `docs/settings-panel.md`, `docs/module-map.md`.
- **The interim state.** In this commit collectibles pass the filter but are still judged by `Evaluate`, so they read `unknown` / `notGear`. Ask stays off because `AskTemplate` finds no useful verdict. That is acceptable on the branch: with the default categories, mounts and the rest show as `unknown`. If an interim build must never show them, set the four collectible defaults to off in C2 and on in C3 (Q6).

**DW-CAT3: the collection verdict in the judge path, feed-only refusals, Me and Them cells, history**
- The edge half of `modules/Collectibles.lua` (events, coalescing, `Changed`), and `IF.RereadCollections` in `modules/ItemFacts.lua`.
- `modules/LootFeed.lua`: the `judgeMe`, `judgeCandidates`, `judgeLooter`, `estimate` and `mayChange` hooks, about 20 lines.
- `modules/TradeRules.lua` and `modules/QualityGate.lua` (`newCollect` override).
- Add `modules/CollectCells.lua` (TOC after `OffSpecCells`) with the words, tones and Me/Them tooltip rows.
- `modules/WindowCells.lua`: the `WC.Verdict` and `WC.Them` hooks. `modules/SideCells.lua`, `modules/MineCells.lua` (Details and Candidates).
- The refusals: `modules/Messaging.lua`, `modules/Asks.lua`, `modules/Toast.lua`, `modules/OfferPanel.lua`, `modules/MineCells.lua` (Offer and Announce), `FB.IsTradeableMine`.
- `modules/History.lua`: the snapshot and `verdictSnap`.
- Locales.
- Tests: the C3 rows of section 9, except the surfaces C7 owns.
- Docs: `docs/data-flow.md`, `docs/ARCHITECTURE.md` (events, the `collection` cause).

**DW-CAT7: the remaining surfaces and the View**
- `modules/CollectCells.lua`: Slot and Type text, chips.
- `WC.Slot` and `WC.ArmorType` hooks, `modules/DetailCells.lua`, `modules/RowTooltip.lua`, `modules/HistoryCard.lua`, `modules/WindowHistory.lua`, `modules/DropsStrip.lua`, `modules/Diagnostics.lua`.
- `modules/WindowFilterBar.lua`: the `newCollect` view and the other views' answers for collectibles.
- The `feed.view.newCollect` row (`VIEW_ROWS` in `settings/SchemaRows.lua`) and its default.
- Locales.
- Tests: `test_window*.lua`, `test_side_cells.lua`, `test_compact_cards.lua`, `test_detail_card.lua`, `test_row_tooltip.lua`, `test_history_card.lua`, `test_drops_strip.lua`, `test_diagnostics.lua`, `test_schema_rows.lua`.
- Docs: `docs/settings-panel.md` (the View row), `docs/module-map.md`.

**DW-CAT4: tier token slot, class and level verdict**
- Add `modules/TierTokens.lua` (pure: `SlotOf`, `Fold`; TOC before `Evaluate`, with its annotation).
- `modules/ItemFacts.lua`: `tokenSlot`, `isTierToken` from the table, and the `equipLoc` override, in the order of section 3.1.
- `modules/Evaluate.lua`: the `usable` token branch, the scorer skip in `compare`, and the `any` fold hook in `run`.
- `core/CompatCollect.lua`: `TierTokenSlot`.
- `core/Constants.lua`: `TIER_TOKENS` seeded only with IDs checked in the client (Q4).
- `modules/FeedFilter.lua`: min ilvl on tokens (Q3).
- `modules/CollectCells.lua`: the token's Slot and Type text. `modules/DetailCells.lua`: the Makes chip. `modules/WindowCells.lua`: the `tierToken` reason text.
- Tests: `tests/test_tier_token.lua`, `test_evaluate.lua`, `test_item_facts.lua`, `test_feed.lua`, `test_gear.lua` (line 213 still holds).
- Docs: `docs/known-limitations.md`, `docs/common-tasks.md`, `docs/compat-layer.md` (the count, now 10).

**DW-CAT5: whitelist and blacklist**
- Add `modules/ItemLists.lua`.
- Add `settings/ListEditors.lua`: the IdList host tab with its secondary strip. It stays out of `PageEditors.lua` (593 lines) and goes in the TOC after it, with its annotation.
- `settings/Pages.lua`: the Drops page's `tabs` and its Defaults tooltip.
- `settings/SchemaRows.lua` and `defaults/Profile.lua`: the map rows, group `Item lists`.
- `modules/FeedFilter.lua`: blacklist and whitelist precedence, and the `forced` return value.
- `modules/LootFeed.lua`: `Config` gains the lists, `judge` stores `rec.forced`, `judgeMe` reads `rec.forced`, and the quality gate gets `forced`.
- `modules/QualityGate.lua`: the forced pass.
- `settings/Slash.lua` and `settings/SlashVerbs.lua`: the verbs.
- Locales.
- Tests: `tests/test_item_lists.lua`, `tests/test_item_lists_panel.lua`, `test_feed.lua`, `test_quality_gate.lua`, `test_slash.lua`, `test_schema_rows.lua`, `tests/run.lua`.
- Docs: `docs/schema.md` (the value route), `docs/settings-panel.md`, `docs/slash-dispatch.md`, `docs/ARCHITECTURE.md` (Slash Commands, Settings Schema).

**DW-CAT6: simulator and test-mode samples, smoke tests, docs**
- `modules/SimPool.lua` (`extras`, `COLLECTIBLE_SAMPLES`), `modules/SimEvents.lua` (the burst mix), `settings/SimVerbs.lua` (`drop`), `modules/TestData.lua` (`ev` carrying the collect fields; the six rows and the history group), `modules/TestMode.lua`.
- Tests: `test_sim_pool.lua`, `test_sim_events.lua`, `test_test_mode.lua`.
- Docs: `docs/smoke-tests.md` (`COLL-*`, `ITEM-6..7`, the Index), `docs/testing.md`, `docs/test-cases.md`, `README.md`, `docs/ARCHITECTURE.md` and `docs/slash-dispatch.md` (the sim verb count).

---

## 12. Line caps (layout-§1: 1500 is the cap, 1000–1500 is on notice)

| File | Now | Plan |
|---|---|---|
| `core/Compat.lua` | 999 | Do not touch. All new reads go in `core/CompatCollect.lua` (compat family split). |
| `modules/WindowCells.lua` | 1165 (on notice) | Hooks only (`WC.Verdict`, `WC.Them`, `WC.Slot`, `WC.ArmorType`, the reason text), about 12 lines. Words and cells go in `modules/CollectCells.lua`. |
| `modules/WindowGroup.lua` | 1156 (on notice) | No change expected. Column descriptions are in-file strings; if the Slot or Type help text must change, edit it in place, net 0. |
| `modules/LootFeed.lua` | 1041 (on notice) | At most about 25 lines. All collectible logic is in `Collectibles`. |
| `modules/Window.lua` | 1025 | untouched |
| `tests/wow_mock.lua` | 991 | New mocks go in `tests/wow_mock_collect.lua`, so the file stays out of the band. |
| `tests/test_compat.lua` 1053, `tests/test_settings_pages.lua` 1052 | on notice | New cases go in new suite files. |
| `modules/WindowFilterBar.lua` 838, `modules/TestData.lua` 823, `modules/Toast.lua` 727, `modules/History.lua` 757, `modules/SchemaRows.lua` 682, `modules/MineCells.lua` 588 | under 1000 | Each grows by under 60 lines and stays under 1000. |

No file crosses 1500. The census in `docs/ARCHITECTURE.md` stays "Nothing is over the cap today".

---

## 13. Standard conformance flags

1. **library-stack-§7 / anti-pattern #47: covered by the existing deviation row, nothing to register.** `Compat.RecipeKnown` and `Compat.TierTokenSlot` are built on the ratified `Compat.ReadTooltipLine`, as `ItemClassRestriction`, `InventoryItemLevel` and `GetItemUpgradeInfo` already are. They add no tooltip reader. The row's re-check trigger (a second *roster addon* reading tooltip lines) does not fire. If implementation needs a reader that does **not** go through `ReadTooltipLine`, STOP and bring it to the owner as a new deviation.
2. **architecture-§5: compliant, nothing to register.** The two lists are flat ID sets written whole at one path through the helper, which is the value route. `docs/schema.md` must say so and name `NS.ItemLists` as the writer both surfaces share. BankLedger took the registry-writer route for the same control; both routes are compliant.
3. **slash-commands-§2: compliant.** `whitelist` and `blacklist` are feature verbs, refused while disabled. No live verb is added.
4. **options-ui-§13: compliant.** The Item lists tab uses a secondary strip for like subjects, with `ctx.activeSubTab` as session state. `addonName` is already passed on the descriptor, so IdList's help marks get the art. The degradation stubs cover every Helpers member used (testing-§8).
5. **compat rules: compliant.** Enums are resolved by name, globals are read at call time, `IsSecret` comes first, GlobalStrings are read through `Compat.GlobalString`, and the new members are wrapped by the simulator seam (TOC order, LOAD-BEARING annotations).
6. **savedvariables-§1: compliant.** The perProfile migration step is idempotent, frozen (a literal key list) and the runner owns the stamp.
7. **TOC annotations.** Every new TOC line carries its load annotation, as every existing line does.
8. **Run coordination, not the standard.** The migration step number depends on the other items of this run: #14 adds toast rows and no migration, as far as the plan says. #12 reads `category` from history. `items.tsv` needs `DW-CAT7` and the dependency fixes of section 11.

---

## 14. Known limitations this change records

- Caged battle pets (`|Hbattlepet:` links) are never watched.
- The recipe "known" state depends on the client's `ITEM_SPELL_KNOWN` line. Under an addon restriction it can read secret. The drop then reads `collectUnknown` and is read again when combat ends.
- Tier tokens missing from `C.TIER_TOKENS` whose tooltip names no slot stay `unknown`.
- Category toggles and list changes apply to new drops only. A restored drop is not filtered by a blacklist entry added after it dropped.
- The Drops page's Defaults button keeps both item lists (Q9).
- History entries recorded before this change have no category and read as Equipment.
- Someone else's bound collectible reads trade `unknown`. Your own reads the trade timer's exact answer once its bag item is matched.

---

## 15. Open questions for the owner

Each has a recommended default, which the implementation uses if the owner gives no other answer.

- **Q1. The collected tone.** "Greyed like a downgrade", but a downgrade is red today. *Default:* `collected` uses the gray `bad` tone that `doesntWant` uses, and `newCollect` uses green.
- **Q2. A recipe for a profession you lack.** *Default:* the existing `cantUse` verdict (redMuted) with the reason "not your profession", rather than a fourth collection state.
- **Q3. The minimum item level on tier tokens.** Today tokens skip it. *Default:* apply it, since the token's level is now compared.
- **Q4. Seeding `C.TIER_TOKENS`.** It needs the current season's token item IDs, checked in the client (`ITEM-6`). *Default:* ship the table empty plus the tooltip rung, and seed it during smoke round 8 from in-game `/dump`s.
- **Q5. The whitelist and heirlooms.** *Default:* the whitelist beats heirloom always-out and the quality gate, but not the situation gate (section 4.2).
- **Q6. The interim C2 state.** *Default:* collectible categories are on from C2. They read `unknown` until C3 lands, on the branch only.
- **Q7. (Withdrawn.)** No deviation-row change is needed (section 13, flag 1).
- **Q8. Offer, Announce and Post my tradeables for collectibles.** The owner named no Ask, toast or AutoAsk. *Default:* refuse Offer, Announce and Post as well, so a collectible has no action at all, which is what "feed-only" means.
- **Q9. The Defaults button and the lists.** *Decided (run plan):* the two map rows are excluded from the page reset, so Drops' Defaults keeps both lists.

---

## Critic notes

These are the changes the review made to the original draft, checked against the code at `655d19d` and issue #13.

1. **`FeedFilter` stays pure.** `ctx.forced = true` mutated an input. It is now a third return value, stored as `rec.forced`. `judgeMe` reads `rec.forced`, so the score retry, `OnGearChanged`, `LF.Refresh` and restored drops keep the admission answer (4.1, 4.4; M3 review).
2. **`LF.Refresh(rec, cause)` already re-judges.** It calls `rejudge`, which runs `judgeMe` and `judgeLooter` and sends `DropUpdated(id, cause)`. The proposed `LF.Rejudge` was dropped in favor of `LF.Refresh(rec, "collection")` (4.6).
3. **The cache write contract.** ItemFacts says its cached tables are never written by others. The re-read moved into `IF.RereadCollections()` (3.1, 4.6).
4. **The transmog handler** reads `facts.equipLoc`. After the token override that would ask about the made slot's appearance, so it must read `rawEquipLoc`. The order inside `IF.Read` is spelled out (3.1).
5. **`Evaluate.usable`** answers `unknown/tierToken` for a token without `classes`, so a Curio could never reach the fold. A `tokenSlot` branch was added. The scorer skip moved into `compare` instead of mutating `opts` (7.2).
6. **Cosmetic weapons** are Weapon-class. Equipment now excludes `IsCosmeticItem`, and the flag probe runs on weapons too (1).
7. **Missed inspect path.** `reestimate` calls `judgeCandidates(rec, cfg, true)` when your own drop's trade leaves `no`. The guard moved into `judgeCandidates` itself (4.4).
8. **`mayChange`** now excludes only other players' collectibles. Your own stay in the sweep, so the trade timer's exact read applies and gives COLL-6 its evidence (4.4).
9. **TradeRules** keeps the legacy, expired and groupLoot rule answers. Only the looter's item-level check is replaced for collectibles (4.5).
10. **`verdictSnap`** keeps only `verdict`, `ilvlDelta`, `scoreDelta` and `offSpec`. It now also stores `collect`, `count`, `limit` and the profession reason, so history can render collectibles (3.3).
11. **Missed surfaces.** `WC.Them` shows `?` and "waiting (one inspect…)" when `them` is nil, so it needs its own hook. `MineCells.Details` and `MC.Candidates` for your own drop, `SideCells`, and `FB.IsInteresting`'s `isMine` branch (it would pass your own BoE mount) were added. The full list of places the `newCollect` view touches is now named (6.1).
12. **CompactCards.** `WORD_VERDICT` is what adds the ⊘ glyph. Adding the new verdicts to it contradicted the draft's own intent, so CompactCards needs no change (6.1).
13. **`WC.HiddenLines`** shows the filter bar's reasons, not the feed's. The feed's reason words live in `SimReport.lua` and the `FeedCounts.lua` header. WindowCells was removed from C2 (4.1, 11).
14. **`test_surface_parity`** checks degradation stubs, not CLI parity. `H.IdList` and `H.SubTabStrip` already have stubs. The description was corrected (9, 5.1).
15. **IdList spec fields** were corrected to BankLedger's real usage: `entries`, `strings = { nameHint }`, `label`/`tooltip`, `ctx.rebuild`. `Settings.Helpers` is the Options instance. Map rows need `group = L["Item lists"]` and their declaration place sets the tab order. Defaults keeps the lists (Q9) (5.1).
16. **Migration.** Uses the runner's `run = function(_, profile)` signature, and a frozen literal key list instead of `NS.Constants.CATEGORIES` (5.2).
17. **The deviation flag was downgraded.** The new tooltip reads go through the ratified `Compat.ReadTooltipLine`, so no new reader and no register change. Q7 was withdrawn, with a STOP condition if a non-`ReadTooltipLine` reader turns out to be needed (2, 13).
18. **TOC and SimSetup.** The SimSetup TOC annotation and the `core/SimSetup.lua` header both name the wrapped compat files and must be updated. Every new TOC line needs its annotation (2, 13).
19. **TestData** rows are never judged, so the collect verdict must be in `me` (through `ev`), not only in the facts (8).
20. **Smoke IDs.** `TOKEN-*` became `ITEM-6..7`, continuing the Item facts range. Index rows were added, along with `docs/slash-dispatch.md` and `docs/midnight-quirks.md` (10).
21. **Commit size.** C3 was too large and was split into DW-CAT3 and the new DW-CAT7. C4 and C5 depend on C3 (`CollectCells`). The `items.tsv` changes are flagged for the orchestrator (11, 13).
22. **Smaller fixes.** `Config` builds `categories` like `tradeRules()`. Filtering applies to new drops only, and restored drops skip the filter (0, 4.2, 14). First Aid maps to nil. Profession tools, gems and other classes were added to the out-of-scope list. `Battlepet [17]` was dropped as a detection rung. The `dynamicSlot` reason `emptySlot` and the `dynamicCharacter` behavior for collectibles are noted (4.3). A perf run was added to C1. Q8 was added, because Offer, Announce and Post go beyond the owner's "no Ask, toast, AutoAsk".
