# RobloxMergeGear

Roblox merge game. Code lives in files (Rojo-synced), never authored inside Studio.

## Layout
- `src/server/Services/*.luau` → ServerScriptService.Server.Services (one service per system)
- `src/client/Controllers/*.luau` → StarterPlayerScripts.Client.Controllers
- `src/shared/` → ReplicatedStorage.Shared (types, config, pure logic, remotes)
- `Packages/` → Wally deps (ReplicatedStorage.Packages). Generated: don't edit.
- `docs/ARCHITECTURE.md` → system map. **Read it first instead of scanning `src/`.** Update it when adding/removing a system.

Services/Controllers are tables with optional `:Init()` (sync wiring, no yields) and `:Start()` (may yield).

## Commands
- `rokit install` – toolchain · `wally install` – deps
- `rojo serve` – live sync to Studio · `rojo sourcemap -o sourcemap.json` – for luau-lsp
- `selene src` – lint · `stylua src` – format (auto-run by hook on edit)
- `luau-lsp analyze --sourcemap=sourcemap.json src` – typecheck

## Rules
- `--!strict` in every file. Use `task.*`, never `wait/spawn/delay`.
- Server is authoritative: validate every remote arg (type, range, ownership, rate). Client only sends intents.
- Tunables go in `src/shared/Config/`, not inline magic numbers.
- Keep modules < ~300 lines; split by responsibility.

## Working efficiently (token budget)
- Load a skill only when the task needs it: `roblox-luau`, `roblox-architecture`, `roblox-studio-mcp`, `merge-game-design`.
- Find code with Grep/Glob for specific symbols; read line ranges, not whole files. Delegate broad searches to the `roblox-scout` agent.
- Studio MCP: query narrowly (one path, few properties). Never dump the whole DataModel or Workspace.
- Prefer editing files over MCP `execute_luau` for anything that should persist.
- Don't read `Packages/` beyond the one module whose API you need.
