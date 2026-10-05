--!strict
-- Item identity, merge rules, and count-based storage helpers. Pure: operates on plain tables.
local Types = require(script.Parent.Types)
local GearConfig = require(script.Parent.Config.Gear)

local Gear = {}

function Gear.slotOf(kind: Types.ItemKind): Types.Slot
	return GearConfig.Kinds[kind].slot
end

function Gear.isValidKind(kind: unknown): boolean
	return type(kind) == "string" and GearConfig.Kinds[kind :: any] ~= nil
end

-- Two items merge when kind, quality and plus all match and the result stays within MaxPlus.
function Gear.canMerge(a: Types.Item, b: Types.Item): boolean
	return a.kind == b.kind and a.quality == b.quality and a.plus == b.plus and a.plus < GearConfig.MaxPlus
end

function Gear.mergeResult(a: Types.Item): Types.Item
	return { kind = a.kind, quality = a.quality, plus = a.plus + 1 }
end

-- Storage counts ---------------------------------------------------------------

local function bucket(inventory: Types.Inventory, item: Types.Item): Types.CountMap
	local byQuality = inventory[item.kind]
	if not byQuality then
		byQuality = {}
		inventory[item.kind] = byQuality
	end
	local counts = byQuality[item.quality]
	if not counts then
		counts = {}
		byQuality[item.quality] = counts
	end
	return counts
end

function Gear.count(inventory: Types.Inventory, item: Types.Item): number
	return bucket(inventory, item)[tostring(item.plus)] or 0
end

-- Adds (or with negative delta, removes) items. Returns false without changing anything if
-- that would make the count negative. Zero counts are removed to keep saves small.
function Gear.addCount(inventory: Types.Inventory, item: Types.Item, delta: number): boolean
	local counts = bucket(inventory, item)
	local key = tostring(item.plus)
	local new = (counts[key] or 0) + delta
	if new < 0 then
		return false
	end
	(counts :: any)[key] = if new == 0 then nil else new
	return true
end

return Gear
