# Architecture map

One line per system. Read this instead of crawling `src/`. Reasoning, schema, decisions and roadmap: `docs/DESIGN.md`.

| System | Server | Client | Shared | Notes |
|---|---|---|---|---|
| Bootstrap | `server/init.server` | `client/init.client` | `Net` | Init (own state, no yields) → Start (cross-service, may yield) |
| Data | `Services/DataService`, `Data/Migrations`, `Data/NewPlayer`, `Vendor/ProfileStore` | `Controllers/DataController` | `Config/DataTemplate`, `Types` | Save v2; valid at every moment, no leave hooks. `GetData` + `MarkDirty(key)`; server-side `Changed(player, key)` signal. Migrations use raw table ops only |
| Map | `Services/MapService` | | `Config/Map`, `Config/Castles` | Generates the placeholder world; exposes zone + castle anchors |
| Zones | `Services/ZoneService` | | | One zone per player; `ZoneIndex` player attribute; `ZoneAssigned`/`ZoneReleased` signals |
| Enemies | `Services/EnemyService` | | `Config/Enemies` | Per-zone spawner + AI tick (0.2 s). Owner-only enemies. `GetEnemies`, `Damage`; signals `EnemyKilled(owner, enemy)`, `EnemyAttacked(enemy, target)` |
| Combat | `Services/CombatService` | `Controllers/CombatFxController` | `Config/Gear` (Hero) | Hero stats → Humanoid (HP, speed), `GearScore` player attribute, auto-attack on Heartbeat, applies enemy hits. No remotes: FX derive from replicated Humanoid health |
| Economy | `Services/EconomyService` | | `Config/Drops` (Gold) | Only gold writer: `AddGold(player, amount, source)`, `SpendGold`. Owner-only coins + magnet loop; auto-credit after 30 s |
| Loot | `Services/LootService` | `Controllers/LootFxController` | `Formulas` (drop rolls), `Config/Drops`, `Config/ItemVisuals` | Kill → roll → `GiveItem(player, item, fromPosition?)` → bag + index + `ItemGained` cue. No items in the world |
| Forge / equipment | `Services/InventoryService`, `Util/Validate`, `Util/RateLimit` | `Controllers/ForgeController`, `Controllers/EquipmentController`, `Controllers/MenuController` | `Gear` (`mergeStack`, `upgradeEquipped`, `mergeAll`, `bestStored`, `stacks`, `recordIndex`) | Merge one stack / all (cascade, equipped first), upgrade equipped, equip, equip best, unequip. Displaced items → bag |
| Notifications | (any service) `Net.event("Notify"):FireClient(player, msg, tone)` | `Controllers/NotifyController`, `Util/Toast` | | Toasts under the HUD; tone `info` / `good` / `bad` |
| HUD | | `Controllers/HudController` | `Formulas`, `Util/Format` | Gold, Gear Score (client-side from `equipped`), Drop Tier |
| Client UI kit | | `Util/Ui` | | `new`, `window`, `button`, `text`, `list`, `stat`, `Theme`. New panels: build with these, register via `MenuController:AddPanel(name, order, window, onOpen?)` |
| Client FX | | `Util/Fx` | | Client-only helpers (`part`, `pop`, `floatingText`, `tweenThenDestroy`) in `workspace.ClientFx` |
| Debug | `Services/DebugService` | | | Studio-only: `/gold [n]`, `/droptier <n>`, `/equip <kind> <plus>`, `/unequip` (→ bag), `/drop <kind> <plus> [count]` (→ bag), `/resetdata` |
| Balance | | | `Config/*`, `Formulas`, `Gear` | Config = numbers only; Formulas = all curves; Gear = item rules |

## World folders (server-created)
`workspace.Map` (MapService) · `workspace.Enemies` (models carry `OwnerUserId`, `Tier`) · `workspace.Coins` (parts carry `OwnerUserId`, `Amount`) · `workspace.ClientFx` (client-only)

## Remotes
| Name | Dir | Payload | Owner / checks |
|---|---|---|---|
| DataSnapshot | S→C | full PlayerData | DataService |
| DataChanged | S→C | `{ [topKey]: value }` per frame | DataService |
| ItemGained | S→C | `(kind, quality, plus, fromPosition?)` | LootService; cosmetic loot-fly cue |
| Notify | S→C | `(message, tone)` | any service; toast |
| RequestMergeStack | C→S | `(kind, quality, plus)` | InventoryService: rate → isValidItem → count ≥ 2 → merge pairs |
| RequestMergeAll | C→S | `()` | InventoryService: rate → `Gear.mergeAll` |
| RequestUpgradeEquipped | C→S | `(slot)` | InventoryService: rate → isSlot → equipped + stored copy → +1 |
| RequestEquipFromStorage | C→S | `(kind, quality, plus)` | InventoryService: rate → isValidItem → has count → equip (old → bag) |
| RequestEquipBest | C→S | `()` | InventoryService: rate → per slot, equip highest stored if better |
| RequestUnequip | C→S | `(slot)` | InventoryService: rate → isSlot → equipped item → bag |

## Data (player save, v2)
`gold, inventory[kind][quality][plus]=n (the bag), equipped[slot]=Item, upgrades{DropTier,EnemyCap,SpawnRate,MagnetRange}, rebirths, starterKitGranted, index[slot], stats{…}, offline{lastOnline,incomeRate}`
