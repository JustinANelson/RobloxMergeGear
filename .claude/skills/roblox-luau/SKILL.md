---
name: roblox-luau
description: Luau language and Roblox engine API correctness — strict typing, task library, deprecated-API avoidance, common engine gotchas. Use when writing or fixing any .luau code in this project.
---
# Roblox Luau

## Non-negotiables
- `--!strict` header. Type every function signature and module export; export shared types from `src/shared/Types.luau`.
- `task.wait/spawn/defer/delay`, never `wait/spawn/delay`. `os.clock()` for timing, `workspace:GetServerTimeNow()` for synced time.
- Generalized iteration: `for _, x in t do` (no `pairs/ipairs` needed).
- `game:GetService("X")` once at top of the file. Use `workspace`, not `game.Workspace`.
- Instance creation: set properties **before** `Parent` (parent last).
- `:WaitForChild` only across replication boundaries (client waiting on server objects); server code indexes directly.
- Deprecated → modern: `Instance.new(c, parent)` → set Parent last · `BodyVelocity/BodyPosition` → `LinearVelocity/AlignPosition` · `:connect` → `:Connect` · `Humanoid:LoadAnimation` → `Animator:LoadAnimation`. Player-entered text must go through `TextService` filtering.
- String building in loops: `table.concat` / `buffer`, not `..` accumulation.

## Service / Controller shape
```luau
--!strict
local Players = game:GetService("Players")

local MyService = {}

function MyService:Init() end -- wire state/remotes; must not yield
function MyService:Start() end -- may yield

return MyService
```
- Cleanup: store connections per player; disconnect on `Players.PlayerRemoving`. `Instance:Destroy()` disconnects its events.
- Wrap failable yielding engine calls (DataStore, MarketplaceService, HttpService, TeleportService) in `pcall` with retry + backoff.
- `table.freeze` config tables.

## References (read only if needed)
- `references/gotchas.md` — replication, streaming, physics ownership, characters, UI, DataStore limits, receipts.
- `references/types.md` — strict-mode type idioms (generics, class typing, casts, remote-arg refinement).
