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
| D14 | Drag uses a **local ghost + server confirmation**: the real item only moves when the server says so, and the client snaps back on timeout | No client authority over items, and rejected requests still look smooth |
| D15 | Ground item **positions aren't saved**; rejoining scatters them randomly on the pad | Keeps the save small (counts only); exact layout has little value |
| D16 | Merging A onto B keeps **B's spot**; A disappears | Matches the mental model of "drop this on that" |
| D17 | **Storage is unlimited** in the MVP | Simplest; the brief's Phase 4 "extra storage" purchase implies a cap later. It can be added as an upgrade/config value without a data change |
| D18 | Items displaced from a slot (equip over, unequip) always go to **storage**, never the ground | The ground can be full; storage can't, so nothing is ever lost |
| D19 | All UI is **built in code** (`client/Util/Ui`), not in Studio | Keeps UI in git and reviewable, consistent with the files-as-source-of-truth rule; can move to a UI library later |
| D20 | Drag a ground item **onto the Storage button** to store it, **onto your hero** to equip it | Reuses the drag interaction instead of adding per-item menus; works for mouse and touch |
| D13 | New saves get a **+1 starter set** (all 4 slots), granted once via the `starterKitGranted` flag (`server/Data/NewPlayer`); rebirth re-equips it | An empty-handed hero (5 DPS, 100 HP) couldn't survive Grunt +1. It can't go in the template: Reconcile recurses and would refill emptied slots on every join |
| D12 | ProfileStore is vendored at `src/server/Vendor` (official source, license in `ThirdParty/`) | Works without Wally; swap to `lm-loleris/profilestore` via Wally whenever you like |

## 1. Architecture

```
ReplicatedStorage.Shared         (src/shared)  — pure code + data, used by both sides
  Config/   Gear, Drops, Enemies, Upgrades, Castles, Rebirth, Economy, Map, ItemVisuals, DataTemplate  (data only)
  Types     shared type definitions (PlayerData, Item, Loadout, …)
  Formulas  every balancing formula (stats, gear score, costs, enemy scaling, drop rolls, capture odds, offline pay)
  Gear      item identity, merge rule, count helpers, plus → color
  Net       registry of every remote (server creates, client looks up)
  Util/     Signal, TableUtil, Format
ReplicatedStorage.Remotes        (created at runtime by Net.setup)
ServerScriptService.Server       (src/server)
  init.server   creates remotes, loads Services, runs Init on all, then Start on all
  Data/         Migrations (schema steps), NewPlayer (one-time grants)
  Loot/         ItemPool (creates/dresses/recycles ground item Parts)
  Util/         RateLimit (per-player remote cooldowns), Validate (remote-arg checks, reach)
  Vendor/       ProfileStore
  Services/
    DataService       ProfileStore sessions, migrations, replication, Changed signal        [M1] ✅
    MapService        builds the world from config; exposes zone + castle anchors          [M1] ✅
    ZoneService       assigns personal zones, spawns players in them                       [M1] ✅
    DebugService      Studio-only chat commands                                            [M1] ✅
    EnemyService      per-zone spawner, enemy AI (boss timer in M5)                        [M2] ✅
    CombatService     hero stats → Humanoid, auto-attack, damage, GearScore attribute      [M2] ✅
    EconomyService    only gold writer, coins, magnet (upgrades M5, offline M6)            [M2] ✅
    LootService       drops, ground cap/overflow, merge/move validation, rejoin restore    [M3] ✅
    InventoryService  storage ↔ ground ↔ equipped transfers (equip, unequip, store, withdraw) [M4] ✅
    CastleService     capture battles, ownership, income ticks                             [M6]
    RebirthService    eligibility + reset                                                  [M7]
StarterPlayerScripts.Client      (src/client)
  Util/Fx           client-only FX helpers (pop, floating text, tween-then-destroy)
  Util/Ui           UI construction helpers + theme (window, button, text, list)
  Controllers/
    DataController      read-only mirror of the player's save + change signals            [M1] ✅
    HudController       gold / gear score / drop tier                                      [M1] ✅
    CombatFxController  damage numbers, hit slashes, death puffs, coin pickup              [M2] ✅
    DragController      drag ground items → RequestMerge / RequestMove                     [M3] ✅
    LootFxController    drop and merge pops                                                [M3] ✅
    MenuController      left menu bar; opens one panel at a time; buttons double as drop targets [M4] ✅
    EquipmentController slots, per-item contribution, hero totals, Gear Score, Unequip    [M4] ✅
    StorageController   stored stacks with Equip / Take out, ground + storage counts      [M4] ✅
    (future panels)     Upgrades [M5], castle popup [M6], Rebirth + Index [M7]: one controller each, registered via MenuController:AddPanel
```

**Lifecycle.** `Init()` sets up the module's own state, signals and remotes; it must not yield or call other services. `Start()` runs after every Init, so it may call other services, connect players and yield.

**Communication.**
- Server ↔ server: direct calls through `require` for queries and commands (`DataService:GetData`), plus `Signal`s for events (`ZoneService.ZoneAssigned`, later `EnemyService.EnemyKilled → LootService/EconomyService`). Signals are synchronous, so ordering is deterministic.
- Client → server: `Request*` RemoteEvents only, expressing intent (for example `RequestMerge(itemIdA, itemIdB)`). Every handler applies a rate limit, type checks, ownership, distance/zone checks, and cooldowns, then acts.
- Server → client: player-private state goes through `DataSnapshot`/`DataChanged`, with dirty top-level keys batched once per frame. World state goes through Instances and attributes (enemy health, item `OwnerUserId`/`Kind`/`Plus`, castle owner). Cosmetic events use specific remotes (for example `BattleStarted`).
- Gold has a single writer, `EconomyService:AddGold(player, amount, source)`, which applies the rebirth multiplier and updates `stats.goldEarned`. Nothing else touches `data.gold`, apart from DebugService.

**Ground items (M3).**
- *Registry.* `LootService` keeps `entries[id] = { id, owner, item, part }` (ids are per-server integers). Parts come from `Loot/ItemPool`, pooled per kind and reparented to nil when idle. Each Part carries the attributes `ItemId`, `OwnerUserId`, `Kind`, `Quality` and `Plus`, which clients read. Items are anchored, can't be collided with, and can be raycast.
- *Invariant.* Every physical item is counted exactly once in `data.ground`, and each data change happens in the same step as the world change (`GiveItem`, merge, `Populate` overflow). Item positions aren't saved: on rejoin, `Populate` respawns items at random spots on the pad.
- *Drops.* On `EnemyKilled`, the kind is rolled from `Drops.KindWeights` (`Formulas.rollDropKind`), and the plus is the Drop Tier plus, + `BossPlusBonus` for bosses, + 1 with the rebirth bonus chance (`Formulas.rollDropPlus`). Each drop lands within `DropScatter` studs of the kill, clamped onto the pad. If the player already has `GroundCap` (40) physical items, the drop goes straight to `data.inventory` (storage). Every drop updates `index`.
- *Merge.* The client sends `RequestMerge(sourceId, targetId)`. The server checks rate limit → integer ids → both items exist and are owned by the sender → `Gear.canMerge` → the target is within `MaxInteractDistance` of the hero. Then: `ground` −1 source, −1 target, +1 result; the source Part is released; the target Part is re-dressed in place as the result; `stats.merges` +1; `index` updated.
- *Move.* The client sends `RequestMove(itemId, point)`. The server checks rate limit → id → Vector3 without NaN → owned item → point lies on the sender's pad → within reach, then re-places the Part. No data change.
- *Client (`DragController`).* It never moves the real Part. It hides the real Part locally (`LocalTransparencyModifier`) and drags a ghost copy. A Highlight shows green or red over a merge target. On release it predicts the outcome: an invalid merge or off-pad drop snaps back immediately without sending anything. Otherwise it sends the request and waits up to 1 s for the result to replicate (source Part removed, or Part moved), then snaps back if nothing arrives. Touch drags freeze the camera (`Scriptable`) so dragging doesn't also orbit it.

**Inventory (M4).**
- *Three places an item can be:* `data.ground` (physical, LootService), `data.inventory` (storage counts), or `data.equipped` (one per slot). `InventoryService` moves items between them, and every move changes both sides in the same step (D7).
- *Requests:* `RequestEquipFromStorage(kind, quality, plus)`, `RequestEquipFromGround(itemId)`, `RequestUnequip(slot)`, `RequestStore(itemId)`, `RequestWithdraw(kind, quality, plus)`. Each one: rate limit → `Gear.isValidItem` / `Validate.isId` / slot check → ownership (has the count, or owns the ground item) → reach for ground items → act.
- *Displaced items always go to storage* (D18). Equipping over an occupied slot or unequipping moves the old item to storage, so nothing can be lost. Withdraw places the item about 5 studs from the hero (or at a random pad spot if the hero isn't on the pad) and fails, changing nothing, when the ground is full.
- *LootService API used here:* `PlaceOnGround(player, item, point?)` (false when full; no storage fallback, no index), `GetGroundItem(player, id)`, `TakeGroundItem(player, id)` (un-counts from `data.ground`; the caller must place the item elsewhere), `GroundCount(player)`. `GiveItem` (new items) is built on `PlaceOnGround` and falls back to storage.
- *Client:* `MenuController` owns the left menu bar (Gear, Storage) and opens one panel at a time. Panels are built in code with `Util/Ui` (D19). Dragging a ground item onto the **Storage** button stores it, and dragging it onto **your own hero** equips it (D20). `DragController` checks the button's on-screen bounds and raycasts against the local character. Panels compute stats with the same `Formulas` as the server, so the displayed numbers always match.

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
  starterKitGranted = false,                      -- one-time grant flag (D13)
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
| Enemies (T = drop plus) | HP 30 × 1.45^(T−1), dmg 2 × 1.4^(T−1) every 1.5 s, gold 3 × 1.5^(T−1); cap 6, one spawn per 2.0 s. With the +1 starter set you kill a Grunt +1 in about 2 s, while a full pack of 6 needs about 22 s to kill you |
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
| **3. Ground loot & merging** ✅ | Drops by weight at Drop Tier, item pool, ground cap/overflow, `data.ground` mirror + re-drop on join, DragController, server-validated merge, index | Drag +1 onto +1 → +2; invalid drops snap back; the 41st item goes to storage; rejoining restores ground items |
| **4. Equipment & storage** ✅ | InventoryService (equip/unequip/store/withdraw), menu bar, Equipment panel, Storage panel, drag-to-Storage and drag-to-hero. *Stats and the GearScore attribute were already done in M2* | Equipping a +5 Sword visibly speeds up kills; Boots raise speed; GS updates; Unequip → item appears in Storage; Take out → item lands next to you; drag onto Storage/hero works |
| **5. Upgrades & boss** | Upgrade shop UI + RequestUpgrade, enemy scaling by Drop Tier, boss timer with guaranteed high drop | Buying Drop Tier raises drop plus and enemy toughness; the boss appears every 3 min and drops +T+3 |
| **6. Castles & offline** | CastleService capture flow + battle visual, ownership flag, income ticks, attacking owned castles, castle popup, offline payout on join | Capture Oakhold at GS 150+, earn 4 g/s, a second player can attack it; leave and return → offline gold popup |
| **7. Rebirth, index, balance** | Rebirth screen + reset (re-equip the starter set via `NewPlayer.equipStarterKit`), multipliers, index panel, economy simulation script, tuning pass, security review of all remotes | Reach +10 → rebirth → gold ×1.5; the index keeps its records; the sim matches the pacing targets |

## 5. Known limitations / follow-ups

| Area | Limitation | Plan |
|---|---|---|
| Drag | If the server releases a source Part and re-acquires it for a new drop in the same frame, the client may not see it leave, so the merge looks rejected and snaps back (the data is correct) | Accept; revisit if seen in playtests (would need a merge-result remote) |
| Drag | Mouse and touch only; no gamepad dragging, and no keyboard shortcuts for the panels | Gamepad: select-then-select flow; add keybinds (G/B) when the menu grows |
| UI | When the server refuses a panel action (e.g. Take out when the ground is full) nothing tells the player why; the full-ground case is greyed out in advance | Add a small toast system |
| UI | The Storage list is rebuilt fully on each change while open | Fine at current sizes; switch to row reuse if storage gets large |
| Coins | Coins lying on the ground when the owner leaves are lost (D7) | Accept; worth very little |
| Enemies | Placeholder grunts have no walk/attack animation | Art pass |
| Items | Placeholder shapes; overlapping drops can stack on top of each other | Art pass; optional spread-out nudge |
| Typing | The Luau type solver widens union-keyed map keys, so code iterating `Loadout`/`index`/`inventory` uses string-keyed `:: any` views (see the comment in `Formulas`) | Revisit when the new type solver is default |
