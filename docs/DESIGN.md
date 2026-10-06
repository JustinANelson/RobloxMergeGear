# Gear-Merge Conquest — Design

Status: Milestones 1–4 implemented (M3/M4 reworked into the **Forge** model, see §6). `docs/ARCHITECTURE.md` is the short system map; this is the reasoning behind it.

## 0. Decisions and assumptions (override any of these)

Superseded decisions are kept, struck through, so the reasoning trail survives.

| # | Decision | Why |
|---|---|---|
| D1 | Hero **auto-attacks** the nearest enemy in range | Fits the merge/idle loop, works on mobile, and the same AI later drives mercenaries |
| D2 | Map is **generated from config** at server start (placeholder geometry) | Everything lives in git; art replaces visuals later at the same anchors |
| ~~D3~~ | ~~Ground drops are server Parts, visible to all~~ | Superseded by D21 |
| D4 | Castles **revert to neutral** when the owner leaves; their income still counts toward that player's offline rate | Keeps castles contestable in a live server |
| D5 | Items are identified by **kind**, not slot. MVP kinds: Helmet, Armor, Boots, **Sword** (Weapon slot) | Phase 2 weapon types (Bow/Staff) become new kinds with no data migration |
| D6 | Quality is in the save from day one: `inventory[kind][quality][plus]`. MVP only uses `"Normal"` | Phase 3 quality tiers need no migration |
| D7 | **The save is valid at every moment**: no "on leave" save hooks; `lastOnline` is stamped every 30 s | On shutdown ProfileStore saves on its own threads and leave handlers may not run |
| D8 | Enemy strength tracks the player's **Drop Tier** | Makes Drop Tier a real trade-off instead of a free upgrade |
| D9 | Drop Tier stored as an upgrade *level* (0-based); drop plus = level + 1 | Every upgrade has the same shape |
| D10 | Loot Magnet pulls **gold** only (items are collected instantly, D21) | Keeps the upgrade meaningful |
| D11 | Rebirth requirement = any item reaching **+10 + 2 × rebirths** | Matches "first +10", scales after that |
| D12 | ProfileStore is vendored at `src/server/Vendor` (official source, license in `ThirdParty/`) | Works without Wally; swap to `lm-loleris/profilestore` via Wally whenever you like |
| D13 | New saves get a **+1 starter set** (all 4 slots), granted once via the `starterKitGranted` flag (`server/Data/NewPlayer`); rebirth re-equips it | An empty-handed hero (5 DPS, 100 HP) couldn't survive Grunt +1. It can't go in the template: Reconcile recurses and would refill emptied slots on every join |
| ~~D14–D16~~ | ~~Ghost drag with server confirmation; ground positions not saved; merge keeps the target's spot~~ | Superseded by D21 (no ground items) |
| D17 | **Storage (the bag) is unlimited** in the MVP | Simplest; the brief's Phase 4 "extra storage" purchase implies a cap later, which can be added as config without a data change |
| D18 | Items displaced from a slot (equip over, unequip) always go to **storage** | Storage can't overflow, so nothing is ever lost |
| D19 | All UI is **built in code** (`client/Util/Ui`), not in Studio | Keeps UI in git and reviewable, consistent with files-as-source-of-truth; can move to a UI library later |
| ~~D20~~ | ~~Drag onto the Storage button / hero~~ | Superseded by D21 |
| D21 | **Collect + Forge.** Drops go straight into the bag (the client plays a loot-fly effect); merging happens in the Forge panel by stack: **Merge** (one stack, all pairs), **Upgrade** (equipped item absorbs a matching copy), **Merge All** (cascades upward, equipped included), **Equip Best** | Pairwise drag-merging needed 2^(n−1) − 1 actions per +n item (511 for a +10), the ground was hard to read, and the equipped item sat outside the merge loop. See §6 |
| D22 | **Cascade only on Merge All**; a row's Merge does one plus level | One-tap "do everything" while still allowing deliberate, partial merges |
| D23 | In Merge All, at each plus level the **equipped item absorbs a matching copy before pairs form** | Keeps the equipped item as high as possible, which is what players want from "merge everything" |
| D24 | Server → player feedback goes through one generic **`Notify`** toast remote | One small system covers merge results, refusals and future events (castles, rebirth) |

## 1. Architecture

```
ReplicatedStorage.Shared         (src/shared)  — pure code + data, used by both sides
  Config/   Gear, Drops, Enemies, Upgrades, Castles, Rebirth, Economy, Map, ItemVisuals, DataTemplate  (data only)
  Types     shared type definitions (PlayerData, Item, Loadout, …)
  Formulas  every balancing formula (stats, gear score, costs, enemy scaling, drop rolls, capture odds, offline pay)
  Gear      item identity, count helpers, Forge operations (mergeStack, upgradeEquipped, mergeAll, bestStored), index, plus → color
  Net       registry of every remote (server creates, client looks up)
  Util/     Signal, TableUtil, Format
ReplicatedStorage.Remotes        (created at runtime by Net.setup)
ServerScriptService.Server       (src/server)
  init.server   creates remotes, loads Services, runs Init on all, then Start on all
  Data/         Migrations (schema steps), NewPlayer (one-time grants)
  Util/         RateLimit (per-player remote cooldowns), Validate (isId, isSlot, isFiniteVector3, withinReach)
  Vendor/       ProfileStore
  Services/
    DataService       ProfileStore sessions, migrations, replication, Changed signal        [M1] ✅
    MapService        builds the world from config; exposes zone + castle anchors          [M1] ✅
    ZoneService       assigns personal zones, spawns players in them                       [M1] ✅
    DebugService      Studio-only chat commands                                            [M1] ✅
    EnemyService      per-zone spawner, enemy AI (boss timer in M5)                        [M2] ✅
    CombatService     hero stats → Humanoid, auto-attack, damage, GearScore attribute      [M2] ✅
    EconomyService    only gold writer, coins, magnet (upgrades M5, offline M6)            [M2] ✅
    LootService       drop rolls → bag + index, ItemGained effect cue; GiveItem API       [M3] ✅
    InventoryService  the Forge: merge stack / all, upgrade equipped, equip, equip best, unequip [M4] ✅
    CastleService     capture battles, ownership, income ticks                             [M6]
    RebirthService    eligibility + reset                                                  [M7]
StarterPlayerScripts.Client      (src/client)
  Util/Fx           client-only FX helpers (pop, floating text, tween-then-destroy)
  Util/Ui           UI construction helpers + theme (window, button, text, list)
  Util/Toast        stacked, auto-fading messages under the HUD
  Controllers/
    DataController      read-only mirror of the player's save + change signals            [M1] ✅
    HudController       gold / gear score / drop tier                                      [M1] ✅
    CombatFxController  damage numbers, hit slashes, death puffs, coin pickup              [M2] ✅
    LootFxController    loot-fly effect on ItemGained                                      [M3] ✅
    NotifyController    Notify remote → Toast                                              [M4] ✅
    MenuController      left menu bar; opens one panel at a time                           [M4] ✅
    EquipmentController slots, per-item contribution, hero totals, Gear Score, Unequip    [M4] ✅
    ForgeController     bag by slot: Upgrade / Merge / Equip per row, Merge All, Equip Best [M4] ✅
    (future panels)     Upgrades [M5], castle popup [M6], Rebirth + Index [M7]: one controller each, registered via MenuController:AddPanel
```

**Lifecycle.** `Init()` sets up the module's own state, signals and remotes; it must not yield or call other services. `Start()` runs after every Init, so it may call other services, connect players and yield.

**Communication.**
- Server ↔ server: direct calls through `require` for queries and commands (`DataService:GetData`, `LootService:GiveItem`), plus `Signal`s for events (`ZoneService.ZoneAssigned`, `EnemyService.EnemyKilled → LootService/EconomyService`, `DataService.Changed`). Signals are synchronous, so ordering is deterministic.
- Client → server: `Request*` RemoteEvents only, expressing intent. Every handler starts with `RateLimit.check`, then validates its arguments (`Gear.isValidItem`, `Validate.*`) and ownership before acting.
- Server → client: player-private state goes through `DataSnapshot`/`DataChanged`, with dirty top-level keys batched once per frame. World state goes through Instances and attributes (enemy health, coins, castle owner). Cosmetic cues and messages use specific remotes (`ItemGained`, `Notify`).
- Gold has a single writer, `EconomyService:AddGold/SpendGold`; items change only through `LootService:GiveItem` (new items) and `InventoryService` (moves and merges). DebugService is the only exception.

**Loot (M3, reworked).** On `EnemyKilled`, with `Drops.DropChance` (bosses always drop), the kind is rolled from `Drops.KindWeights` (`Formulas.rollDropKind`) and the plus is Drop Tier plus + `BossPlusBonus` for bosses + 1 with the rebirth bonus chance (`Formulas.rollDropPlus`). `LootService:GiveItem` adds it to `data.inventory`, updates `index`, and fires `ItemGained(kind, quality, plus, fromPosition)` to the owner. The client (`LootFxController`) plays the effect: the item pops up where the enemy died, shows "+N" in its plus color, and flies into the hero. Nothing item-related exists in the world, so there's no world/save state to keep in sync.

**The Forge (M4, reworked).** Items live in two places: `data.inventory` (the bag, counts) and `data.equipped` (one per slot). The rules are pure functions in `Shared/Gear`. The server applies them; the client uses the same functions only to preview.
- `Gear.mergeStack(inv, item)`: every pair in one stack becomes plus + 1 (count // 2 made). No cascade.
- `Gear.upgradeEquipped(inv, equipped, slot)`: a stored copy equal to the equipped item merges into it (equipped +n → +n+1).
- `Gear.mergeAll(inv, equipped)`: per kind/quality, walks from the lowest stored plus upward to MaxPlus − 1. At each level the equipped item first absorbs a matching copy (D23), then the rest pair up. Results created at one level are merged at the next, so it cascades in a single pass. Returns `{ merges, made }` for the index and the toast.
- `Gear.bestStored(inv, slot)`: the highest-plus stored item for a slot (used by Equip Best).
- Requests (`InventoryService`): `RequestMergeStack(kind, quality, plus)`, `RequestMergeAll()`, `RequestUpgradeEquipped(slot)`, `RequestEquipFromStorage(kind, quality, plus)`, `RequestEquipBest()`, `RequestUnequip(slot)`. Each: rate limit → argument validation → ownership (the counts must exist) → apply → `stats.merges` and `index` updated → `Notify` toast ("Merged 9× → Sword +6, Helmet +5"). Displaced equipped items always go to the bag (D18).
- Client: `ForgeController` lists the bag by slot. Each slot header shows the equipped item and an **Upgrade → +n+1** button when a matching copy is stored. Stack rows show "×count", a preview ("2 pairs → +4 ×2"), "▲ better than equipped", and **Merge** / **Equip**. The header has **Equip Best** and **Merge All**. It's rebuilt from replicated data only while open.

## 2. Save schema (v2)

```lua
{
  schemaVersion = 2,
  gold = 0,
  inventory = { Helmet = { Normal = { ["3"] = 2 } }, Sword = { Normal = {} }, ... }, -- the bag (counts)
  equipped  = { Weapon = { kind = "Sword", quality = "Normal", plus = 5 }, ... },  -- missing = empty
  upgrades  = { DropTier = 0, EnemyCap = 0, SpawnRate = 0, MagnetRange = 0 },     -- levels
  rebirths  = 0,
  starterKitGranted = false,                      -- one-time grant flag (D13)
  index     = { Helmet = 0, Armor = 0, Weapon = 0, Boots = 0 },  -- highest plus per slot, survives rebirth
  stats     = { kills, bossKills, merges, castleCaptures, goldEarned },
  offline   = { lastOnline = <unix>, incomeRate = <gold/s> },
}
```
- Count keys are strings (`"5"`), because DataStore JSON doesn't keep sparse numeric keys.
- `Reconcile()` fills any new template key, so **adding** fields needs no migration. Renaming, moving, removing or retyping a field needs a step in `server/Data/Migrations.luau` plus a bump to `schemaVersion`. A save from a newer build is refused rather than overwritten.
- Migration steps use raw table operations only (never `Gear`/`Formulas`), so a shipped step keeps behaving the same even when shared code changes.

**Migration history**
| Step | Version | Change |
|---|---|---|
| 1 | v1 → v2 | Forge rework (D21): `ground` counts are folded into `inventory`, then `ground` is removed |

**How later phases fit in (all additive):**
| Phase | Field | Shape |
|---|---|---|
| 2 | `mercenaries` | `{ [mercId]: { classId, equipped: Loadout, garrisonCastle: string? } }`, using the same `Loadout` type as the hero and drawing from the shared bag. The Forge's "Upgrade" generalizes to any loadout |
| 2 | `mercenarySlots` | number |
| 2 | new item kinds `Bow`, `Staff` | new keys in `inventory`; `equipped.Weapon.kind` says which |
| 2 | `skills` | `{ [kind]: { [skillId]: level } }` |
| 2/4 | `pvp` | `{ rating, wins, losses, season, seasonRewardsClaimed = {} }` |
| 3 | quality | new keys under each kind: `inventory.Sword.Refined["7"]`. The merge rules already require equal quality |
| 3 | `indexQuality` | `{ [slot]: { [quality]: highestPlus } }` |
| 4 | `purchases` | `{ receipts = { [purchaseId]: unix }, passes = {} }` for idempotent ProcessReceipt |
| 4 | `rebirthTier` | number, for additional rebirth layers |
| 4 | `bagCap` / Auto-Merge flag | bag cap (D17) and the Auto-Merge pass (merge automatically on pickup) |

Castle ownership, perks and garrisons stay per-server runtime state. Only their income lands in the save.

## 3. Config and pacing

All numbers live in `src/shared/Config/*.luau`; formulas live in `src/shared/Formulas.luau`.

| Area | First-pass values |
|---|---|
| Hero | 100 HP, 4 dmg unarmed, 16 speed, attack every 0.8 s, range 8; +1 starter set (D13) |
| Weapon dmg | 8 × 1.4^(p−1): +1 8, +5 31, +10 165 |
| Armor | HP 40 × 1.35^(p−1), Def 2 × 1.3^(p−1) |
| Helmet | HP 25 × 1.35^(p−1), Def 1.5 × 1.3^(p−1) |
| Boots | +1 speed per plus (capped at +14), Def 1 × 1.3^(p−1) |
| Defense | taken = raw × 50 / (50 + def) |
| Gear Score | Σ weight × 10 × 1.5^(p−1); weights W 1.5, A 1.2, H 1.0, B 0.8. All +4 ≈ 150, all +7 ≈ 510, all +10 ≈ 1730 |
| Drops | DropChance 1 (every kill); 25 weight each kind; boss drop = Drop Tier + 3 |
| Enemies (T = drop plus) | HP 30 × 1.45^(T−1), dmg 2 × 1.4^(T−1) every 1.5 s, gold 3 × 1.5^(T−1); cap 6, one spawn per 2.0 s. With the +1 starter set you kill a Grunt +1 in about 2 s, while a full pack of 6 needs about 22 s to kill you |
| Boss | ×12 HP, ×3 dmg, ×15 gold, every 180 s |
| Upgrades | Drop Tier 150 × 2.6^L (max 29) · Enemy Cap 40 × 1.6^L (+1, max 14) · Spawn Rate 60 × 1.65^L (×0.93 interval, max 15) · Magnet 25 × 1.5^L (+2 studs, max 15) |
| Castles | T1 GS 150 → 4 g/s (×2) · T2 500 → 15 g/s (×2) · T3 1500 → 50 g/s · T4 4000 → 150 g/s |
| Capture odds | 1 / (1 + (def/power)^4), clamped 5–95%: equal power = 50%, 1.5× = 84%. Owned castles defend at the owner's capture-time GS × 1.1 |
| Rebirth | needs +10 (then +12, +14 …); gold × (1 + 0.5n); +5% chance per rebirth that a drop comes one plus higher (capped at 50%) |
| Offline | (castle g/s + 25% of estimated zone farm g/s) × 50%, capped at 8 h |

**Intended pacing (first session; to verify in M7 with an economy sim plus playtests):**
- First upgrade in under 1 min. Early kills take about 2–3 s for about 3 gold, so 50–60 gold/min.
- First +5 item at about 8–10 min. That's 16 drops of one kind from +1, fewer after one or two Drop Tier levels. With the Forge this is now drop-limited, not click-limited.
- First castle (T1, GS 150 ≈ every slot at +4) at about 10–15 min. Its 4 g/s roughly doubles income at that point.
- T2 castle at about 25–30 min.
- First rebirth (+10 item) at about 45–60 min, mostly gated by reaching Drop Tier 6–7. That takes about 29k gold cumulative.
- Each Drop Tier costs ×2.6 while enemy gold grows ×1.5, so each tier takes about 1.7× longer than the last. Castles and rebirth multipliers flatten that.
- Because merging is now one tap, gear progression may run faster than these estimates in practice. If so, lower `DropChance` together with richer drops rather than reintroducing friction.

## 4. Milestones

| M | Builds | Testable in Studio when… |
|---|---|---|
| **1. Foundation** ✅ | Rojo layout, Net, ProfileStore data + migrations + replication, generated map, zone assignment, HUD, debug commands | You spawn in your own named zone, the HUD shows gold/GS/Drop Tier, `/gold` and `/equip` update it, and gold persists across sessions. A 2-player test server gives each player a different zone |
| **2. Enemies & combat** ✅ | EnemyService spawner (cap, interval), chase-and-hit AI, hero auto-attack, HP/death/respawn, gold coins + magnet, EconomyService.AddGold. *Pulled forward from M4: gear stats are applied to the Humanoid and `GearScore` is a player attribute* | Enemies stream in, you kill them automatically, gold rises; you can die and respawn |
| **3. Loot** ✅ *(reworked, §6)* | Drop rolls by weight at Drop Tier → bag + index; loot-fly effect | Each kill shows an item popping out and flying into you; the Forge shows it |
| **4. Forge & equipment** ✅ *(reworked, §6)* | InventoryService Forge requests, toasts, menu bar, Gear panel, Forge panel | `/drop sword 1 7` → Merge on the +1 row gives +2 ×3; Merge All cascades and upgrades the equipped Sword; Equip Best picks the highest; Unequip → item back in the bag; toasts describe each result |
| **5. Upgrades & boss** | Upgrade shop UI + RequestUpgrade, enemy scaling by Drop Tier, boss timer with guaranteed high drop | Buying Drop Tier raises drop plus and enemy toughness; the boss appears every 3 min and drops +T+3 |
| **6. Castles & offline** | CastleService capture flow + battle visual, ownership flag, income ticks, attacking owned castles, castle popup, offline payout on join | Capture Oakhold at GS 150+, earn 4 g/s, a second player can attack it; leave and return → offline gold toast |
| **7. Rebirth, index, balance** | Rebirth screen + reset (re-equip the starter set via `NewPlayer.equipStarterKit`), multipliers, index panel, economy simulation script, tuning pass, security review of all remotes | Reach +10 → rebirth → gold ×1.5; the index keeps its records; the sim matches the pacing targets |

## 5. Known limitations / follow-ups

| Area | Limitation | Plan |
|---|---|---|
| UI | No gamepad navigation or keyboard shortcuts for the panels | Add keybinds (G = Gear, F = Forge) and gamepad selection when the menu grows |
| UI | The Forge list is rebuilt fully on each change while open | Fine at current sizes; switch to row reuse if the bag gets large |
| Forge | No "keep N spares" option; Merge All merges everything it can | Add per-kind locks if players ask for spares (e.g. for mercenaries in Phase 2) |
| Coins | Coins lying on the ground when the owner leaves are lost (D7) | Accept; worth very little |
| Enemies | Placeholder grunts have no walk/attack animation | Art pass |
| Typing | The Luau type solver widens union-keyed map keys and loop variables over union arrays, so code iterating `Loadout`/`index`/`inventory`/`Slots` uses `:: any` views or casts (see the comment in `Formulas`) | Revisit when the new type solver is default |

## 6. Design changes

**Ground merging → Collect + Forge (after M4 playtest).**
- *Problem:* drops piled up on the floor and were hard to tell apart; about 20 drops a minute made sorting a chore; building a +n by dragging pairs took 2^(n−1) − 1 actions (511 for a +10); and upgrading the equipped item meant unequip → find a match → drag → re-equip.
- *Options considered:* (A) a tidy in-world tile board with stacking and click-to-merge-stack; (B) collect into the bag and merge in a Forge panel; (C) fully automatic merging and equipping.
- *Chosen:* B (D21), with cascade only on Merge All (D22). It fixes all four problems, is the most mobile-friendly, keeps the player's decisions (when to merge, which slot to push, when to raise Drop Tier), and leaves Auto-Merge as an honest convenience purchase in Phase 4 rather than a fix for a chore.
- *Removed:* ground item Parts and pooling (`server/Loot/ItemPool`), `DragController`, `StorageController`, `data.ground` (migration step 1), and the requests `RequestMerge`, `RequestMove`, `RequestStore`, `RequestWithdraw`, `RequestEquipFromGround`.
