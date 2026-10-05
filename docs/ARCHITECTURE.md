# Architecture map

One line per system. Read this instead of crawling `src/`. Reasoning, schema and roadmap: `docs/DESIGN.md`.

| System | Server | Client | Shared | Notes |
|---|---|---|---|---|
| Bootstrap | `server/init.server` | `client/init.client` | `Net` | Init (own state, no yields) → Start (cross-service, may yield) |
| Data | `Services/DataService`, `Data/Migrations`, `Vendor/ProfileStore` | `Controllers/DataController` | `Config/DataTemplate`, `Types` | Save is valid at every moment; no leave hooks. `GetData` + `MarkDirty(key)`; server-side `Changed(player, key)` signal |
| Map | `Services/MapService` | | `Config/Map`, `Config/Castles` | Generates the placeholder world; exposes zone + castle anchors |
| Zones | `Services/ZoneService` | | | One zone per player; `ZoneIndex` player attribute; `ZoneAssigned`/`ZoneReleased` signals |
| Enemies | `Services/EnemyService` | | `Config/Enemies` | Per-zone spawner + AI tick (0.2 s). Owner-only enemies. `GetEnemies`, `Damage`; signals `EnemyKilled(owner, enemy)`, `EnemyAttacked(enemy, target)` |
| Combat | `Services/CombatService` | `Controllers/CombatFxController` | `Config/Gear` (Hero) | Hero stats → Humanoid (HP, speed), `GearScore` player attribute, auto-attack on Heartbeat, applies enemy hits. No remotes: FX derive from replicated Humanoid health |
| Economy | `Services/EconomyService` | | `Config/Drops` (Gold) | Only gold writer: `AddGold(player, amount, source)`, `SpendGold`. Owner-only coins + magnet loop; auto-credit after 30 s |
| HUD | | `Controllers/HudController` | `Formulas`, `Util/Format` | Gold, Gear Score (client-side from `equipped`), Drop Tier |
| Debug | `Services/DebugService` | | | Studio-only: `/gold /droptier /equip /unequip /resetdata` |
| Balance | | | `Config/*`, `Formulas`, `Gear` | Config = numbers only; Formulas = all curves; Gear = merge rule + count helpers |

## World folders (server-created)
`workspace.Map` (MapService) · `workspace.Enemies` (models carry `OwnerUserId`, `Tier`) · `workspace.Coins` (parts carry `OwnerUserId`, `Amount`) · `workspace.ClientFx` (client-only)

## Remotes
| Name | Dir | Payload | Owner |
|---|---|---|---|
| DataSnapshot | S→C | full PlayerData | DataService |
| DataChanged | S→C | `{ [topKey]: value }` per frame | DataService |

## Data (player save, v1)
`gold, inventory[kind][quality][plus]=n, ground (same shape), equipped[slot]=Item, upgrades{DropTier,EnemyCap,SpawnRate,MagnetRange}, rebirths, index[slot], stats{…}, offline{lastOnline,incomeRate}`
