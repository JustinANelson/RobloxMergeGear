---
name: roblox-architecture
description: How this project is structured — Rojo layout, Service/Controller lifecycle, remotes contract, player data persistence, Wally packages. Use when adding a new system, remote, data field, or package, or when deciding where code belongs.
---
# Project architecture

## Where code goes
| Kind | Location |
|---|---|
| Authoritative logic, data, purchases | `src/server/Services/<Name>Service.luau` |
| Input, UI, camera, VFX, sound | `src/client/Controllers/<Name>Controller.luau` |
| Types, pure functions (both sides) | `src/shared/` |
| Tunables (costs, odds, timers) | `src/shared/Config/<Name>.luau` (frozen tables) |

Pure logic (e.g. merge rules) lives in `src/shared` so it is testable and the client can *predict* results — the server recomputes and is the only one that commits.

## Adding a system
1. Shared types/config. 2. Server service (`Init`: create remotes/state; `Start`: hook players).
3. Client controller. 4. One line each in `docs/ARCHITECTURE.md` (system row, remotes, data keys).
5. `selene src`; playtest via the `roblox-studio-mcp` skill or ask the user.

## Remotes contract
- Server creates remotes in `Init` under `ReplicatedStorage.Remotes.<System>.<Name>`; client gets them with `WaitForChild`. If a typed networking package is adopted later, migrate everything — never mix.
- Naming: `RequestX` (client→server intent), `XChanged` (server→client state). RemoteFunctions only client→server.
- Every handler: rate-limit → validate types → validate ranges/ownership → act → send authoritative state.
- Copy-ready validator + rate limiter: `references/remote-validation.md`.

## Player data
- One `DataService` owns persistence (recommended: **ProfileStore** for session locking + autosave). Others go through `DataService:GetProfile(player)` — never call DataStoreService directly.
- Schema/defaults in `src/shared/Config/DataTemplate.luau`; new keys get defaults (reconciled on load). Never rename keys without a migration.
- Replicate to client via attributes or a `DataChanged` remote with deltas.

## Packages (Wally)
Add to `wally.toml` → `wally install` → `rojo sourcemap -o sourcemap.json`. Require via `ReplicatedStorage.Packages.<Name>`.
