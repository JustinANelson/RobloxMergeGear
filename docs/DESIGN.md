# Gear-Merge Conquest — Design

Status: MVP planning done, Milestone 1 implemented. `docs/ARCHITECTURE.md` is the short system map; this is the reasoning behind it.

## 0. Decisions and assumptions (override any of these)

| # | Decision | Why |
|---|---|---|
| D1 | Hero **auto-attacks** the nearest enemy in range | Fits the merge/idle loop, works on mobile, and the same AI later drives mercenaries |
| D2 | Map is **generated from config** at server start (placeholder geometry) | Everything lives in git; art replaces visuals later at the same anchors |
| D3 | Ground drops are **server Parts, visible to all**; only the owner can drag them | Simple and cheap at 6 players × 40 items |
| D4 | Castles **revert to neutral** when the owner leaves; their income still counts toward that player's offline rate | Keeps castles contestable in a live server |
| D5 | Items are identified by **kind**, not slot. MVP kinds: Helmet, Armor, Boots, **Sword** (Weapon slot) | Phase 2 weapon types (Bow/Staff) become new kinds with no data migration |
| D6 | Quality is in the save from day one: `inventory[kind][quality][plus]`. MVP only uses `"Normal"` | Phase 3 quality tiers need no migration |
| D7 | **The save is valid at every moment**: no "on leave" save hooks. Ground items are mirrored in `data.ground`; `lastOnline` is stamped every 30 s | On shutdown ProfileStore saves on its own threads and leave handlers may not run |
| D8 | Enemy strength tracks the player's **Drop Tier** | Makes Drop Tier a real trade-off instead of a free upgrade |
| D9 | Drop Tier stored as an upgrade *level* (0-based); drop plus = level + 1 | Every upgrade has the same shape |
| D10 | Loot Magnet pulls **gold** only. Gear stays on the ground for merging | Gear on the ground is the core interaction |
| D11 | Rebirth requirement = any item reaching **+10 + 2 × rebirths** | Matches "first +10", scales after that |
| D12 | ProfileStore is vendored at `src/server/Vendor` (official source, license in `ThirdParty/`) | Works without Wally; swap to `lm-loleris/profilestore` via Wally whenever you like |

## 1. Architecture

```
ReplicatedStorage.Shared         (src/shared)  — pure code + data, used by both sides
  Config/   Gear, Drops, Enemies, Upgrades, Castles, Rebirth, Economy, Map, DataTemplate   (data only)
  Types     shared type definitions (PlayerData, Item, Loadout, …)
  Formulas  every balancing formula (stats, gear score, costs, enemy scaling, capture odds, offline pay)
  Gear      item identity, merge rule, count helpers
  Net       registry of every remote (server creates, client looks up)
  Util/     Signal, TableUtil, Format
ReplicatedStorage.Remotes        (created at runtime by Net.setup)
ServerScriptService.Server       (src/server)
  init.server   creates remotes, loads Services, runs Init on all, then Start on all
  Data/Migrations
  Vendor/ProfileStore
  Services/
    DataService       ProfileStore sessions, migrations, replicating saves to clients     [M1]
    MapService        builds the world from config; exposes zone + castle anchors          [M1]
    ZoneService       assigns personal zones, spawns players in them                       [M1]
    DebugService      Studio-only chat commands                                            [M1]
    EnemyService      per-zone spawner, enemy AI, boss timer                               [M2/M5]
    CombatService     hero auto-attack, damage, death; applies hero stats                  [M2/M4]
    EconomyService    gold (single entry point for adding/spending), coins, magnet, upgrades, offline [M2/M5/M6]
    LootService       physical ground items: pooling, cap, overflow, drag/merge validation  [M3]
    InventoryService  storage ↔ ground ↔ equipped transfers, index                         [M3/M4]
    CastleService     capture battles, ownership, income ticks                             [M6]
    RebirthService    eligibility + reset                                                  [M7]
StarterPlayerScripts.Client      (src/client)
  Controllers/
    DataController    read-only mirror of the player's save + change signals              [M1]
    HudController     gold / gear score / drop tier                                        [M1]
    DragController    picking, dragging, dropping items → RequestMerge / RequestMove       [M3]
    PanelsController  equipment, storage, upgrades, castle popup, rebirth, index panels   [M4+]
    CombatFxController  hit flashes, damage numbers, battle visuals                        [M2/M6]
```

**Lifecycle.** `Init()` sets up the module's own state, signals and remotes; it must not yield or call other services. `Start()` runs after every Init, so it may call other services, connect players and yield.

**Communication.**
- Server ↔ server: direct calls through `require` for queries and commands (`DataService:GetData`), plus `Signal`s for events (`ZoneService.ZoneAssigned`, later `EnemyService.EnemyKilled → LootService/EconomyService`). Signals are synchronous, so ordering is deterministic.
- Client → server: `Request*` RemoteEvents only, expressing intent (for example `RequestMerge(itemIdA, itemIdB)`). Every handler applies a rate limit, type checks, ownership, distance/zone checks, and cooldowns, then acts.
- Server → client: player-private state goes through `DataSnapshot`/`DataChanged`, with dirty top-level keys batched once per frame. World state goes through Instances and attributes (enemy health, item `OwnerUserId`/`Kind`/`Plus`, castle owner). Cosmetic events use specific remotes (for example `BattleStarted`).
- Gold has a single writer, `EconomyService:AddGold(player, amount, source)`, which applies the rebirth multiplier and updates `stats.goldEarned`. Nothing else touches `data.gold`, apart from DebugService.

**Ground items (M3).** The server keeps `items[id] = { owner, kind, quality, plus, part }`. Parts come from a pool (reparented to nil when idle). Clients drag a *local ghost*; on release they send `RequestMerge(a, b)` or `RequestMove(a, position)`. The server validates and then either merges (destroys one, upgrades the other, `data.ground` −2/+1) or rejects, in which case the client snaps the ghost back. Every change updates `data.ground` in the same step, so the save always matches the world.

## 2. Save schema (v1)

```lua
{
  schemaVersion = 1,
  gold = 0,
  inventory = { Helmet = { Normal = { ["3"] = 2 } }, Sword = { Normal = {} }, ... }, -- storage counts
  ground    = { ... same shape ... },          -- items lying in the zone right now (re-dropped on join)
  equipped  = { Weapon = { kind = "Sword", quality = "Normal", plus = 5 }, ... },  -- missing = empty
  upgrades  = { DropTier = 0, EnemyCap = 0, SpawnRate = 0, MagnetRange = 0 },     -- levels
  rebirths  = 0,
  index     = { Helmet = 0, Armor = 0, Weapon = 0, Boots = 0 },  -- highest plus per slot, survives rebirth
  stats     = { kills, bossKills, merges, castleCaptures, goldEarned },
  offline   = { lastOnline = <unix>, incomeRate = <gold/s> },
}
```
- Count keys are strings (`"5"`), because DataStore JSON doesn't keep sparse numeric keys.
- `Reconcile()` fills any new template key, so **adding** fields needs no migration. Renaming, moving or retyping a field needs a step in `server/Data/Migrations.luau` plus a bump to `schemaVersion`. A save from a newer build is refused rather than overwritten.

**How later phases fit in (all additive):**
| Phase | Field | Shape |
|---|---|---|
| 2 | `mercenaries` | `{ [mercId]: { classId, equipped: Loadout, garrisonCastle: string? } }`, using the same `Loadout` type as the hero and drawing from the shared `inventory` |
| 2 | `mercenarySlots` | number |
| 2 | new item kinds `Bow`, `Staff` | new keys in `inventory`/`ground`; `equipped.Weapon.kind` says which |
| 2 | `skills` | `{ [kind]: { [skillId]: level } }` |
| 2/4 | `pvp` | `{ rating, wins, losses, season, seasonRewardsClaimed = {} }` |
| 3 | quality | new keys under each kind: `inventory.Sword.Refined["7"]`. The merge rule already requires equal quality |
| 3 | `indexQuality` | `{ [slot]: { [quality]: highestPlus } }` |
| 4 | `purchases` | `{ receipts = { [purchaseId]: unix }, passes = {} }` for idempotent ProcessReceipt |
| 4 | `rebirthTier` | number, for additional rebirth layers |

Castle ownership, perks and garrisons stay per-server runtime state. Only their income lands in the save.

## 3. Config and pacing

All numbers live in `src/shared/Config/*.luau`; formulas live in `src/shared/Formulas.luau`.

| Area | First-pass values |
|---|---|
| Hero | 100 HP, 4 dmg unarmed, 16 speed, attack every 0.8 s, range 8 |
| Weapon dmg | 8 × 1.4^(p−1): +1 8, +5 31, +10 165 |
| Armor | HP 40 × 1.35^(p−1), Def 2 × 1.3^(p−1) |
| Helmet | HP 25 × 1.35^(p−1), Def 1.5 × 1.3^(p−1) |
| Boots | +1 speed per plus (capped at +14), Def 1 × 1.3^(p−1) |
| Defense | taken = raw × 50 / (50 + def) |
| Gear Score | Σ weight × 10 × 1.5^(p−1); weights W 1.5, A 1.2, H 1.0, B 0.8. All +4 ≈ 150, all +7 ≈ 510, all +10 ≈ 1730 |
| Drop weights | 25 each kind; ground cap 40; boss drop = Drop Tier + 3 |
| Enemies (T = drop plus) | HP 30 × 1.45^(T−1), dmg 5 × 1.4^(T−1), gold 3 × 1.5^(T−1); cap 6, one spawn per 2.0 s |
| Boss | ×12 HP, ×3 dmg, ×15 gold, every 180 s |
| Upgrades | Drop Tier 150 × 2.6^L (max 29) · Enemy Cap 40 × 1.6^L (+1, max 14) · Spawn Rate 60 × 1.65^L (×0.93 interval, max 15) · Magnet 25 × 1.5^L (+2 studs, max 15) |
| Castles | T1 GS 150 → 4 g/s (×2) · T2 500 → 15 g/s (×2) · T3 1500 → 50 g/s · T4 4000 → 150 g/s |
| Capture odds | 1 / (1 + (def/power)^4), clamped 5–95%: equal power = 50%, 1.5× = 84%. Owned castles defend at the owner's capture-time GS × 1.1 |
| Rebirth | needs +10 (then +12, +14 …); gold × (1 + 0.5n); +5% chance per rebirth that a drop comes one plus higher (capped at 50%) |
| Offline | (castle g/s + 25% of estimated zone farm g/s) × 50%, capped at 8 h |

**Intended pacing (first session; to verify in M7 with an economy sim plus playtests):**
- First upgrade in under 1 min. Early kills take about 3 s for about 3 gold, so 50–60 gold/min.
- First +5 item at about 8–10 min. That's 16 drops of one kind from +1, fewer after one or two Drop Tier levels.
- First castle (T1, GS 150 ≈ every slot at +4) at about 10–15 min. Its 4 g/s roughly doubles income at that point.
- T2 castle at about 25–30 min.
- First rebirth (+10 item) at about 45–60 min, mostly gated by reaching Drop Tier 6–7. That takes about 29k gold cumulative.
- Each Drop Tier costs ×2.6 while enemy gold grows ×1.5, so each tier takes about 1.7× longer than the last. Castles and rebirth multipliers flatten that.

## 4. Milestones

| M | Builds | Testable in Studio when… |
|---|---|---|
| **1. Foundation** ✅ | Rojo layout, Net, ProfileStore data + migrations + replication, generated map, zone assignment, HUD, debug commands | You spawn in your own named zone, the HUD shows gold/GS/Drop Tier, `/gold` and `/equip` update it, and gold persists across sessions. A 2-player test server gives each player a different zone |
| **2. Enemies & combat** ✅ | EnemyService spawner (cap, interval), chase-and-hit AI, hero auto-attack, HP/death/respawn, gold coins + magnet, EconomyService.AddGold. *Pulled forward from M4: gear stats are applied to the Humanoid and `GearScore` is a player attribute* | Enemies stream in, you kill them automatically, gold rises; you can die and respawn |
| **3. Ground loot & merging** | Drops by weight at Drop Tier, item pool, ground cap/overflow, `data.ground` mirror + re-drop on join, DragController, server-validated merge, index | Drag +1 onto +1 → +2; invalid drops snap back; the 41st item goes to storage; rejoining restores ground items |
| **4. Equipment & storage** | Storage panel (to ground / equip), equipment panel, stats applied (damage, HP, defense, speed), server-side GearScore attribute | Equipping a +5 Sword visibly speeds up kills; Boots raise speed; GS updates |
| **5. Upgrades & boss** | Upgrade shop UI + RequestUpgrade, enemy scaling by Drop Tier, boss timer with guaranteed high drop | Buying Drop Tier raises drop plus and enemy toughness; the boss appears every 3 min and drops +T+3 |
| **6. Castles & offline** | CastleService capture flow + battle visual, ownership flag, income ticks, attacking owned castles, castle popup, offline payout on join | Capture Oakhold at GS 150+, earn 4 g/s, a second player can attack it; leave and return → offline gold popup |
| **7. Rebirth, index, balance** | Rebirth screen + reset, multipliers, index panel, economy simulation script, tuning pass, security review of all remotes | Reach +10 → rebirth → gold ×1.5; the index keeps its records; the sim matches the pacing targets |
