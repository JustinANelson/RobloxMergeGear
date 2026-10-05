# Strict-mode type idioms

```luau
export type Item = { id: string, tier: number, kind: "Gear" | "Booster" }

-- Generic
local function first<T>(list: { T }): T?
	return list[1]
end

-- Class pattern
local Grid = {}
Grid.__index = Grid
export type Grid = typeof(setmetatable({} :: { cells: { [number]: Item? }, size: number }, Grid))

function Grid.new(size: number): Grid
	return setmetatable({ cells = {}, size = size }, Grid)
end

function Grid.get(self: Grid, i: number): Item?
	return self.cells[i]
end

-- Casts / refinement
local part = workspace:FindFirstChild("Spawn")
if part and part:IsA("BasePart") then
	-- part is BasePart here
end
```
- Dynamic requires: `(require :: any)(module)`.
- Remote args arrive as `unknown`: refine with `typeof(x) == "number"`, reject NaN (`x ~= x`), infinities (`math.abs(x) == math.huge`), non-integers (`x % 1 ~= 0`) where relevant.
- Maps `{ [K]: V }`, arrays `{ T }`, optional fields `field: T?`.
