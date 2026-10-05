---
name: roblox-studio-mcp
description: Driving Roblox Studio through the `roblox-studio` MCP server (inspect the DataModel, run Luau, playtest) without blowing the token budget. Use when you need to see or verify state inside Studio, run a playtest, or build non-script content (parts, models, UI) in the place.
---
# Studio MCP usage

Requires Studio open with the place loaded and MCP enabled (Assistant → Manage MCP Servers). Registered in `.mcp.json`. If calls fail, ask the user to check Studio — don't retry in a loop.

## Source of truth
- **Scripts:** files in `src/` (Rojo). Never create/edit scripts via MCP — Rojo overwrites them and they're not in git.
- **Non-script content** (map, models, UI layouts) lives in the place file; MCP is fine for these.

## Token-efficient queries
- One path, few properties, shallow depth. Have Luau return a compact string:
  ```luau
  local out = {}
  for _, c in workspace.Map:GetChildren() do
  	table.insert(out, c.Name .. ":" .. c.ClassName)
  end
  return string.sub(table.concat(out, ","), 1, 2000)
  ```
- Never dump `game`, `workspace`, or full descendant trees. Count first (`#x:GetDescendants()`), then drill down.
- When checking playtest output, filter to errors/warnings.

## Verifying a feature
1. Confirm `rojo serve` is running and Studio is connected (ask if unsure).
2. Start playtest → reproduce → read errors only → stop playtest.
3. Fix in files, not in Studio.

## Safety
`execute_luau` in Edit context mutates the place. Tell the user before destructive changes (mass delete/reparent) and set a `ChangeHistoryService` waypoint so they can undo.
